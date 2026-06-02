import SwiftUI
import WebKit

/// Hosts the shared WKWebView and lays it out at a fixed desktop width,
/// visually scaling that surface to fit the device.
///
/// THE DESKTOP-LAYOUT TRICK: instead of letting the web view size to the
/// device (which makes responsive sites pick phone breakpoints despite the
/// desktop UA), we size the web view to `desktopWidth` (1280pt) and apply a
/// CGAffineTransform scale so the wide surface fits the screen. The page
/// genuinely believes it has a desktop-class viewport and lays out
/// accordingly; the user sees the whole desktop page scaled to fit, and can
/// pinch/scroll within it.
struct DesktopWebView: UIViewRepresentable {
    @ObservedObject var model: BrowserModel

    func makeUIView(context: Context) -> ContainerView {
        let container = ContainerView()
        container.webView = model.webView
        container.desktopWidth = model.desktopWidth
        model.webView.navigationDelegate = context.coordinator
        model.webView.uiDelegate = context.coordinator
        container.addSubview(model.webView)
        if model.webView.url == nil {
            model.loadHome()
        }
        return container
    }

    func updateUIView(_ uiView: ContainerView, context: Context) {
        uiView.desktopWidth = model.desktopWidth
        uiView.setNeedsLayout()
    }

    func makeCoordinator() -> Coordinator { Coordinator(model: model) }

    // MARK: - Container that scales a desktop-width web view to fit

    final class ContainerView: UIView {
        weak var webView: WKWebView?
        var desktopWidth: CGFloat = 1280

        override func layoutSubviews() {
            super.layoutSubviews()
            guard let webView, bounds.width > 0 else { return }

            let scale = bounds.width / desktopWidth
            // The web view is laid out at desktop width and the full device
            // height divided by the scale (so after scaling it fills height).
            let unscaledHeight = bounds.height / scale
            webView.transform = .identity
            webView.frame = CGRect(x: 0, y: 0, width: desktopWidth, height: unscaledHeight)
            webView.transform = CGAffineTransform(scaleX: scale, y: scale)
            // After scaling, anchor top-left to the container origin.
            webView.frame.origin = .zero
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        let model: BrowserModel
        init(model: BrowserModel) { self.model = model }

        // Open target=_blank links in the same web view instead of dropping them.
        func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                webView.load(URLRequest(url: url))
            }
            return nil
        }
    }
}
