# Desktop Browser

A minimal iOS browser that renders websites at **desktop resolution** — not just a mobile page with a desktop user-agent string — and makes it effortless to **capture and share full-page screenshots**.

## Why

Mobile Safari's "Request Desktop Site" flips the user-agent but still lays the
page out at phone width, so responsive sites often serve a hybrid that isn't
the real desktop experience. Desktop Browser lays each page out at a true
**1280pt desktop viewport** and scales that surface to fit your device, so
sites pick their desktop breakpoints and you see the full desktop layout.

## Features

- **True desktop layout** — pages render at a fixed 1280pt width and are
  visually scaled to fit, combined with a desktop Safari user-agent and
  `.desktop` content mode.
- **Address bar** — type a URL or a search query; bare domains get `https://`,
  everything else becomes a Google search.
- **Navigation** — back/forward (incl. edge-swipe gestures), reload/stop, home,
  and a live page-load progress bar.
- **One-tap screenshot → share** — capture the full scrollable page and send it
  through the native iOS share sheet (Messages, Mail, AirDrop, etc.).
- **Save to Photos** — capture straight to your photo library.

## Build

Requires Xcode 17+ and [XcodeGen](https://github.com/yonom/XcodeGen).

```sh
brew install xcodegen      # if not already installed
xcodegen generate          # regenerates DesktopBrowser.xcodeproj from project.yml
open DesktopBrowser.xcodeproj
```

Or from the command line:

```sh
xcodegen generate
xcodebuild -project DesktopBrowser.xcodeproj -scheme DesktopBrowser \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

## Project layout

| Path | Purpose |
|------|---------|
| `project.yml` | XcodeGen project spec (the `.xcodeproj` is generated, not committed) |
| `Sources/DesktopBrowserApp.swift` | App entry point |
| `Sources/BrowserModel.swift` | Owns the `WKWebView`, navigation state, desktop UA, and screenshot capture |
| `Sources/DesktopWebView.swift` | `UIViewRepresentable` that lays the web view out at desktop width and scales it to fit |
| `Sources/ContentView.swift` | Address bar, progress bar, and bottom toolbar |
| `Sources/ShareSheet.swift` | Native `UIActivityViewController` wrapper |

## How desktop layout works

Two independent levers, both applied:

1. **User-agent + content mode** — a macOS Safari UA string and
   `preferredContentMode = .desktop` make servers send the desktop variant.
2. **Desktop-width rendering** — the web view is sized to 1280pt wide and a
   `CGAffineTransform` scales it down to the device width, so responsive CSS
   evaluates against a desktop-class viewport. See `DesktopWebView.ContainerView`.
