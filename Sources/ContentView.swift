import SwiftUI

struct ContentView: View {
    @StateObject private var model = BrowserModel()
    @State private var addressText: String = ""
    @State private var addressFocusedOnce = false
    @FocusState private var addressFocused: Bool

    @State private var capturedImage: UIImage?
    @State private var showShareSheet = false
    @State private var capturing = false
    @State private var toast: String?

    var body: some View {
        VStack(spacing: 0) {
            addressBar
            progressBar
            DesktopWebView(model: model)
                .ignoresSafeArea(edges: .bottom)
            toolbar
        }
        .overlay(alignment: .top) { toastView }
        .sheet(isPresented: $showShareSheet) {
            if let img = capturedImage {
                ShareSheet(items: [img])
            }
        }
        .onChange(of: model.urlString) { _, newValue in
            if !addressFocused { addressText = newValue }
        }
        .onAppear {
            if addressText.isEmpty { addressText = model.urlString }
        }
    }

    // MARK: - Address bar

    private var addressBar: some View {
        HStack(spacing: 8) {
            Image(systemName: model.urlString.hasPrefix("https") ? "lock.fill" : "globe")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            TextField("Search or enter website", text: $addressText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .focused($addressFocused)
                .onSubmit {
                    model.load(addressText)
                    addressFocused = false
                }
                .onChange(of: addressFocused) { _, focused in
                    if focused {
                        // Select-all behavior: show the full URL ready to replace.
                        addressText = model.urlString
                    }
                }

            if addressFocused && !addressText.isEmpty {
                Button {
                    addressText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            } else {
                Button {
                    model.reloadOrStop()
                } label: {
                    Image(systemName: model.isLoading ? "xmark" : "arrow.clockwise")
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
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

    // MARK: - Bottom toolbar

    private var toolbar: some View {
        HStack {
            Button(action: model.goBack) {
                Image(systemName: "chevron.backward")
            }
            .disabled(!model.canGoBack)

            Spacer()

            Button(action: model.goForward) {
                Image(systemName: "chevron.forward")
            }
            .disabled(!model.canGoForward)

            Spacer()

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

            Spacer()

            Button {
                Task { await captureToPhotos() }
            } label: {
                Image(systemName: "square.and.arrow.down")
            }
            .disabled(capturing)

            Spacer()

            Button(action: model.loadHome) {
                Image(systemName: "house")
            }
        }
        .font(.system(size: 20))
        .padding(.horizontal, 28)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
    }

    // MARK: - Toast

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
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation { toast = nil }
        }
    }

    // MARK: - Screenshot actions

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

    private func captureToPhotos() async {
        capturing = true
        defer { capturing = false }
        guard let image = await model.captureScreenshot() else {
            flash("Couldn't capture page")
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        flash("Saved to Photos")
    }
}

#Preview {
    ContentView()
}
