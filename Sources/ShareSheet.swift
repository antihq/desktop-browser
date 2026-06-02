import SwiftUI
import UIKit

/// Thin wrapper over UIActivityViewController so screenshots can be shared
/// via the native iOS share sheet (Messages, Mail, Save to Photos, AirDrop…).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
