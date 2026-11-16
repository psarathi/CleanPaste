import SwiftUI
import AppKit

struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var placeholder: String = "Search history, apps, links..."
    var onSubmit: () -> Void
    var onCancel: () -> Void
    var onMoveSelection: ((Int) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = NSFont.systemFont(ofSize: 13.5, weight: .regular)
        field.textColor = .labelColor
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.lineBreakMode = .byTruncatingTail
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        if isFocused, let window = nsView.window, window.firstResponder !== nsView.currentEditor() {
            DispatchQueue.main.async {
                if window.firstResponder !== nsView.currentEditor() {
                    window.makeFirstResponder(nsView)
                    if let editor = nsView.currentEditor() {
                        let len = (nsView.stringValue as NSString).length
                        editor.selectedRange = NSRange(location: len, length: 0)
                    }
                }
            }
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchTextField

        init(_ parent: SearchTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidBeginEditing(_ obj: Notification) {
            if !parent.isFocused {
                parent.isFocused = true
            }
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            if parent.isFocused {
                parent.isFocused = false
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
                parent.onCancel()
                return true
            }
            if commandSelector == #selector(NSResponder.moveDown(_:)) {
                parent.isFocused = false
                control.window?.makeFirstResponder(nil)
                return true
            }
            return false
        }
    }
}
