import SwiftUI
import UIKit

/// UIKit-backed URL field. SwiftUI's `TextField` inside a compact HStack with
/// a custom background can drop double-tap/triple-tap/magnifier gestures;
/// using a real `UITextField` guarantees full native text-selection behavior
/// and lets us trigger Safari-style select-all on focus.
struct URLField: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String
    var onSubmit: () -> Void

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = placeholder
        tf.font = .systemFont(ofSize: 15)
        tf.autocapitalizationType = .none
        tf.autocorrectionType = .no
        tf.spellCheckingType = .no
        tf.keyboardType = .webSearch
        tf.returnKeyType = .go
        tf.clearButtonMode = .never
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator,
                     action: #selector(Coordinator.editingChanged(_:)),
                     for: .editingChanged)
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return tf
    }

    // Without this, SwiftUI proposes the full available height and
    // UITextField stretches to fill it, blowing the toolbar to hundreds of
    // points tall. Pin the height to the field's intrinsic content size.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        CGSize(
            width: proposal.width ?? UIView.noIntrinsicMetric,
            height: uiView.intrinsicContentSize.height
        )
    }

    func updateUIView(_ uiView: UITextField, context: Context) {
        // Keep the coordinator's captured `self` fresh so its callbacks see
        // the latest closures/bindings, not the ones from `makeCoordinator`.
        context.coordinator.parent = self

        if uiView.text != text {
            uiView.text = text
        }

        if isFocused && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                guard !uiView.isFirstResponder else { return }
                uiView.becomeFirstResponder()
            }
        } else if !isFocused && uiView.isFirstResponder {
            DispatchQueue.main.async {
                guard uiView.isFirstResponder else { return }
                uiView.resignFirstResponder()
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: URLField
        init(_ parent: URLField) { self.parent = parent }

        @objc func editingChanged(_ tf: UITextField) {
            parent.text = tf.text ?? ""
        }

        func textFieldDidBeginEditing(_ tf: UITextField) {
            parent.isFocused = true
            DispatchQueue.main.async { tf.selectAll(nil) }
        }

        func textFieldDidEndEditing(_ tf: UITextField) {
            parent.isFocused = false
        }

        func textFieldShouldReturn(_ tf: UITextField) -> Bool {
            parent.onSubmit()
            tf.resignFirstResponder()
            return true
        }
    }
}
