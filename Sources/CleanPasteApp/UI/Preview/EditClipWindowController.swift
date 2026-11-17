import SwiftUI
import AppKit
import CleanPasteCore

@MainActor
final class EditClipWindowController {
    private let appState: AppState
    private var activeWindow: NSWindow?

    var isOpen: Bool {
        activeWindow?.isVisible == true
    }

    init(appState: AppState) {
        self.appState = appState
        appState.onRequestOpenEdit = { [weak self] item in
            self?.showEdit(item: item)
        }
        appState.onRequestOpenRename = { [weak self] item in
            self?.showRename(item: item)
        }
    }

    func showEdit(item: ClipItem) {
        close()
        let view = EditTextClipView(
            initialText: item.textContent ?? item.urlString ?? "",
            onCancel: { [weak self] in self?.close() },
            onSave: { [weak self] newText in
                self?.appState.editItemText(item.id, newText: newText)
                self?.close()
            }
        )
        presentWindow(title: "Edit Clip", width: 500, height: 340, rootView: AnyView(view))
    }

    func showRename(item: ClipItem) {
        close()
        let view = RenameClipView(
            initialTitle: item.customTitle ?? "",
            placeholder: item.headerTitle,
            onCancel: { [weak self] in self?.close() },
            onSave: { [weak self] newTitle in
                self?.appState.renameItem(item.id, customTitle: newTitle)
                self?.close()
            }
        )
        presentWindow(title: "Rename Clip", width: 340, height: 140, rootView: AnyView(view))
    }

    private func presentWindow(title: String, width: CGFloat, height: CGFloat, rootView: AnyView) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 6)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: rootView)
        panel.center()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        self.activeWindow = panel
    }

    func close() {
        activeWindow?.orderOut(nil)
        activeWindow = nil
    }
}

private struct EditTextClipView: View {
    @State private var text: String
    var onCancel: () -> Void
    var onSave: (String) -> Void

    init(initialText: String, onCancel: @escaping () -> Void, onSave: @escaping (String) -> Void) {
        self._text = State(initialValue: initialText)
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 12) {
            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .textBackgroundColor)))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(text.count) characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Pinned snippets support {{date}}, {{time}}, {{datetime}}, {{uuid}}, {{clipboard}}")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Save Changes") {
                    onSave(text)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
    }
}

private struct RenameClipView: View {
    @State private var title: String
    let placeholder: String
    var onCancel: () -> Void
    var onSave: (String?) -> Void

    init(initialTitle: String, placeholder: String, onCancel: @escaping () -> Void, onSave: @escaping (String?) -> Void) {
        self._title = State(initialValue: initialTitle)
        self.placeholder = placeholder
        self.onCancel = onCancel
        self.onSave = onSave
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField(placeholder, text: $title)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    onSave(title)
                }

            HStack {
                if !title.isEmpty {
                    Button("Clear Title") {
                        onSave(nil)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.escape, modifiers: [])
                Button("Rename") {
                    onSave(title)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
    }
}
