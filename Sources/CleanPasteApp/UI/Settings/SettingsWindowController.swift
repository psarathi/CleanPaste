import SwiftUI
import AppKit
import CleanPasteCore

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let appState: AppState
    private var window: NSWindow?

    var isVisible: Bool {
        window?.isVisible == true
    }

    init(appState: AppState) {
        self.appState = appState
        super.init()
        appState.onRequestOpenSettings = { [weak self] in
            self?.show()
        }
    }

    func show() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 510),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.title = "CleanPaste Preferences"
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.contentView = NSHostingView(
                rootView: SettingsRootView()
                    .environmentObject(appState)
            )
            win.center()
            self.window = win
        }

        guard let window else { return }
        appState.refreshAccessibilityStatus()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
