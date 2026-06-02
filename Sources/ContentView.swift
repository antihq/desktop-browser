import SwiftUI
import WebKit

struct ContentView: View {
    @StateObject private var model = BrowserModel()
    @State private var addressText: String = ""
    @State private var addressFocused: Bool = false

    @State private var capturedImage: UIImage?
    @State private var showShareSheet = false
    @State private var capturing = false
    @State private var toast: String?

    @State private var showCustomWidthPrompt = false
    @State private var customWidthText: String = ""

    private let widthPresets: [CGFloat] = [1024, 1280, 1440, 1680, 1920]

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            progressBar
            DesktopWebView(model: model)
                .ignoresSafeArea(edges: .bottom)
        }
            .overlay(alignment: .top) { toastView }
            .sheet(isPresented: $showShareSheet) {
                if let img = capturedImage {
                    ShareSheet(items: [img])
                }
            }
            .alert("Desktop width", isPresented: $showCustomWidthPrompt) {
                TextField("Width in pt", text: $customWidthText)
                    .keyboardType(.numberPad)
                Button("Cancel", role: .cancel) {}
                Button("Set") {
                    if let w = Int(customWidthText), w >= 320 && w <= 10000 {
                        model.desktopWidth = CGFloat(w)
                    }
                }
            } message: {
                Text("Enter a width between 320 and 10000 pt.")
            }
            .onChange(of: model.urlString) { _, newValue in
                if !addressFocused { addressText = newValue }
            }
            .onAppear {
                if addressText.isEmpty { addressText = model.urlString }
            }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            historyMenu(items: model.backList,
                        icon: "chevron.backward",
                        enabled: model.canGoBack,
                        primary: model.goBack)

            historyMenu(items: model.forwardList,
                        icon: "chevron.forward",
                        enabled: model.canGoForward,
                        primary: model.goForward)

            addressField

            Button {
                Task { await captureAndShare() }
            } label: {
                if capturing {
                    ProgressView()
                } else {
                    Image(systemName: "camera.viewfinder")
                }
            }
            .disabled(capturing)

            widthMenu
        }
        .font(.system(size: 15))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func historyMenu(
        items: [WKBackForwardListItem],
        icon: String,
        enabled: Bool,
        primary: @escaping () -> Void
    ) -> some View {
        Menu {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button(item.displayTitle) { model.go(to: item) }
            }
        } label: {
            Image(systemName: icon)
        } primaryAction: {
            primary()
        }
        .disabled(!enabled)
    }

    private var addressField: some View {
        HStack(spacing: 6) {
            Image(systemName: model.urlString.hasPrefix("https") ? "lock.fill" : "globe")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            URLField(
                text: $addressText,
                isFocused: $addressFocused,
                placeholder: "Search or enter website",
                onSubmit: {
                    model.load(addressText)
                    addressFocused = false
                }
            )

            if addressFocused && !addressText.isEmpty {
                Button {
                    addressText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    model.reloadOrStop()
                } label: {
                    Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 13))
                }
            }
        }
        .toolbarPill(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var widthMenu: some View {
        Menu {
            ForEach(widthPresets, id: \.self) { w in
                Button {
                    model.desktopWidth = w
                } label: {
                    if w == model.desktopWidth {
                        Label("\(Int(w)) pt", systemImage: "checkmark")
                    } else {
                        Text("\(Int(w)) pt")
                    }
                }
            }
            Divider()
            Button("Custom…") {
                customWidthText = String(Int(model.desktopWidth))
                showCustomWidthPrompt = true
            }
        } label: {
            HStack(spacing: 2) {
                Text("\(Int(model.desktopWidth))")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(.primary)
            .toolbarPill(Capsule())
        }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            if model.isLoading {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * model.progress, height: 2)
                    .animation(.easeOut(duration: 0.2), value: model.progress)
            }
        }
        .frame(height: 2)
    }

    @ViewBuilder private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Capsule().fill(.thinMaterial))
                .overlay(Capsule().strokeBorder(.quaternary))
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func flash(_ message: String) {
        withAnimation { toast = message }
        Task {
            try? await Task.sleep(for: .milliseconds(1800))
            withAnimation { toast = nil }
        }
    }

    private func captureAndShare() async {
        capturing = true
        defer { capturing = false }
        guard let image = await model.captureScreenshot() else {
            flash("Couldn't capture page")
            return
        }
        capturedImage = image
        showShareSheet = true
    }
}

private struct ToolbarPill<S: Shape>: ViewModifier {
    let shape: S
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(shape.fill(.quaternary.opacity(0.5)))
    }
}

private extension View {
    func toolbarPill<S: Shape>(_ shape: S) -> some View {
        modifier(ToolbarPill(shape: shape))
    }
}

#Preview {
    ContentView()
}
