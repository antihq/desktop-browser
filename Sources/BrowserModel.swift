import Foundation
import WebKit
import SwiftUI

/// Owns the single WKWebView and exposes its navigation state to SwiftUI.
///
/// "Desktop browsing" is achieved with two independent levers, both needed:
///  1. A desktop user-agent string + `.desktop` page content mode, so servers
///     send the desktop variant of the site (the "Request Desktop Site" path).
///  2. Laying the web content out at a fixed DESKTOP WIDTH (1280pt) and visually
///     scaling that surface down to fit the device — so responsive sites pick
///     their desktop breakpoints instead of reflowing to a phone layout. This
///     lever lives in the view layer (DesktopWebView); this model just holds
///     the configured web view and drives navigation.
@MainActor
final class BrowserModel: ObservableObject {
    @Published var urlString: String = ""
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var pageTitle: String = ""

    /// The desktop width the page is laid out at, in points. 1280 is the
    /// classic desktop breakpoint that triggers full desktop layouts on
    /// virtually every responsive site. User-adjustable from the toolbar.
    @Published var desktopWidth: CGFloat = 1280

    /// Safari 17 macOS UA — makes sites serve their desktop experience.
    private let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/17.4.1 Safari/605.1.15"

    let webView: WKWebView

    private var observations: [NSKeyValueObservation] = []

    init() {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.preferredContentMode = .desktop
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = desktopUserAgent
        wv.allowsBackForwardNavigationGestures = true
        wv.isInspectable = true
        // We host the web view edge-to-edge under the status bar; don't let
        // WebKit add a top safe-area inset that produces a blank strip above
        // the page content.
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        self.webView = wv

        observe()
    }

    private func observe() {
        observations = [
            webView.observe(\.canGoBack, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.canGoBack = wv.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.canGoForward = wv.canGoForward }
            },
            webView.observe(\.isLoading, options: [.initial, .new]) { [weak self] wv, _ in
                Task { @MainActor in self?.isLoading = wv.isLoading }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] wv, _ in
                Task { @MainActor in self?.progress = wv.estimatedProgress }
            },
            webView.observe(\.url, options: [.new]) { [weak self] wv, _ in
                Task { @MainActor in
                    if let u = wv.url?.absoluteString { self?.urlString = u }
                }
            },
            webView.observe(\.title, options: [.new]) { [weak self] wv, _ in
                Task { @MainActor in self?.pageTitle = wv.title ?? "" }
            },
        ]
    }

    // MARK: - Navigation

    /// Normalize a raw address-bar string into a URL: add https:// if a host
    /// was typed, otherwise treat it as a web search.
    func load(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let url: URL
        if let asURL = URL(string: trimmed),
           asURL.scheme == "http" || asURL.scheme == "https" {
            url = asURL
        } else if looksLikeDomain(trimmed) {
            url = URL(string: "https://\(trimmed)")!
        } else {
            let q = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
            url = URL(string: "https://www.google.com/search?q=\(q)")!
        }
        webView.load(URLRequest(url: url))
    }

    private func looksLikeDomain(_ s: String) -> Bool {
        guard !s.contains(" ") else { return false }
        // A bare token with a dot and no spaces is treated as a domain
        // (e.g. "example.com", "news.ycombinator.com").
        let host = s.split(separator: "/").first.map(String.init) ?? s
        return host.contains(".") && !host.hasPrefix(".") && !host.hasSuffix(".")
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }

    // MARK: - History

    /// Back history in reverse chronological order (most recent first), which
    /// is the order Safari shows in its long-press history menu.
    var backList: [WKBackForwardListItem] {
        webView.backForwardList.backList.reversed()
    }

    /// Forward history in the order it would be re-visited.
    var forwardList: [WKBackForwardListItem] {
        webView.backForwardList.forwardList
    }

    func go(to item: WKBackForwardListItem) {
        webView.go(to: item)
    }

    func reloadOrStop() {
        if isLoading { webView.stopLoading() } else { webView.reload() }
    }

    func loadHome() {
        load("https://www.google.com")
    }

    // MARK: - Screenshot

    /// Capture the full visible desktop-rendered page as an image.
    ///
    /// Uses `takeSnapshot` over the web view's full content size so the image
    /// reflects what the page looks like at desktop width, scaled for sharing.
    func captureScreenshot() async -> UIImage? {
        let config = WKSnapshotConfiguration()
        config.afterScreenUpdates = true
        // Snapshot the full scrollable content, not just the visible viewport.
        let contentSize = webView.scrollView.contentSize
        if contentSize.width > 0, contentSize.height > 0 {
            config.rect = CGRect(origin: .zero, size: contentSize)
        }
        return await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: config) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
}

extension WKBackForwardListItem {
    /// Page title if present, otherwise the URL — used as the label in the
    /// long-press history menu.
    var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        return url.absoluteString
    }
}
