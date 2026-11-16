import AppKit
import CleanPasteCore

@main
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var shelfController: ShelfWindowController?
    private var quickLookController: QuickLookWindowController?
    private var editController: EditClipWindowController?
    private var settingsController: SettingsWindowController?
    private var pasteStackHUDController: PasteStackHUDController?
    private var menuBarController: MenuBarController?

    private static let showNotification = Notification.Name("com.cleanroom.CleanPaste.ShowShelf")

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // If another instance with the same bundle identifier is already running, bring up its shelf and exit cleanly
        if let bundleID = Bundle.main.bundleIdentifier {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            if !others.isEmpty {
                DistributedNotificationCenter.default().postNotificationName(
                    Self.showNotification,
                    object: nil,
                    userInfo: nil,
                    deliverImmediately: true
                )
                NSApp.terminate(nil)
                return
            }
        }

        let appState = AppState.shared

        let shelf = ShelfWindowController(appState: appState)
        let quickLook = QuickLookWindowController(appState: appState)
        let edit = EditClipWindowController(appState: appState)
        let settings = SettingsWindowController(appState: appState)
        let stackHUD = PasteStackHUDController(appState: appState)
        let menuBar = MenuBarController(appState: appState)

        shelf.quickLookWindowProvider = { [weak quickLook] in
            quickLook?.window
        }
        shelf.isModalOpenProvider = { [weak edit, weak settings] in
            (edit?.isOpen == true) || (settings?.isVisible == true)
        }

        self.shelfController = shelf
        self.quickLookController = quickLook
        self.editController = edit
        self.settingsController = settings
        self.pasteStackHUDController = stackHUD
        self.menuBarController = menuBar

        DistributedNotificationCenter.default().addObserver(
            forName: Self.showNotification,
            object: nil,
            queue: .main
        ) { [weak shelf] _ in
            Task { @MainActor in
                shelf?.show()
            }
        }

        // Show shelf once on launch so the user sees CleanPaste immediately
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            shelf.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.saveImmediately()
    }
}
