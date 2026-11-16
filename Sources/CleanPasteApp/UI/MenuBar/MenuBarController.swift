import AppKit
import Combine
import CleanPasteCore

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()

    init(appState: AppState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        menu.delegate = self
        statusItem.menu = menu
        updateStatusButton()

        Publishers.CombineLatest4(
            appState.$isPaused,
            appState.$isPasteStackActive,
            appState.$pasteStackItemIDs,
            appState.$settings
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _, _, _, _ in
            self?.updateStatusButton()
        }
        .store(in: &cancellables)
    }

    private func updateStatusButton() {
        statusItem.isVisible = appState.settings.showMenuBarIcon
        guard let button = statusItem.button else { return }

        let iconImage = MenuBarIconRenderer.image(for: appState.settings.menuBarIconStyle, size: 18)
        iconImage.accessibilityDescription = "CleanPaste"
        button.image = iconImage

        button.appearsDisabled = appState.isPaused
        button.alphaValue = appState.isPaused ? 0.45 : 1.0
        if appState.isPasteStackActive {
            button.title = appState.pasteStackItemIDs.isEmpty ? " •" : " \(appState.pasteStackItemIDs.count)"
            button.imagePosition = .imageLeft
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
        button.toolTip = appState.isPaused ? "CleanPaste (Paused)" : "CleanPaste (\(appState.settings.openShelfShortcut.displayString))"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let showItem = NSMenuItem(
            title: "Show CleanPaste",
            action: #selector(toggleShelfAction),
            keyEquivalent: ""
        )
        showItem.target = self
        menu.addItem(showItem)

        let stackTitle = appState.isPasteStackActive
            ? "Stop Paste Stack (\(appState.pasteStackItemIDs.count))"
            : "Start Paste Stack"
        let stackItem = NSMenuItem(
            title: stackTitle,
            action: #selector(toggleStackAction),
            keyEquivalent: ""
        )
        stackItem.target = self
        menu.addItem(stackItem)

        menu.addItem(.separator())

        // Recent Clips Quick Submenu
        let recentMenuItem = NSMenuItem(title: "Recent Clips", action: nil, keyEquivalent: "")
        let recentSubmenu = NSMenu()
        let recentClips = Array(appState.items.filter { $0.isInHistory }.prefix(8))
        if recentClips.isEmpty {
            let emptyItem = NSMenuItem(title: "No clips yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            recentSubmenu.addItem(emptyItem)
        } else {
            for (idx, clip) in recentClips.enumerated() {
                let label = Self.menuTitle(for: clip)
                let item = NSMenuItem(title: label, action: #selector(pasteRecentAction(_:)), keyEquivalent: idx < 9 ? "\(idx + 1)" : "")
                item.target = self
                item.representedObject = clip.id
                recentSubmenu.addItem(item)
            }
        }
        recentMenuItem.submenu = recentSubmenu
        menu.addItem(recentMenuItem)

        menu.addItem(.separator())

        let pauseItem = NSMenuItem(
            title: appState.isPaused ? "Resume Recording" : "Pause Recording",
            action: #selector(togglePauseAction),
            keyEquivalent: ""
        )
        pauseItem.target = self
        menu.addItem(pauseItem)

        let clearItem = NSMenuItem(
            title: "Clear Clipboard History",
            action: #selector(clearHistoryAction),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPrefsAction),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        let quitItem = NSMenuItem(
            title: "Quit CleanPaste",
            action: #selector(quitAction),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private static func menuTitle(for clip: ClipItem) -> String {
        let raw: String
        if let custom = clip.customTitle, !custom.isEmpty {
            raw = custom
        } else {
            switch clip.type {
            case .text, .link, .color:
                raw = clip.textContent ?? clip.urlString ?? clip.headerTitle
            case .image:
                raw = "Image (\(clip.footerMetadata))"
            case .file:
                raw = clip.filePaths.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File"
            }
        }
        let cleaned = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.count > 42 {
            return String(cleaned.prefix(42)) + "…"
        }
        return cleaned.isEmpty ? clip.headerTitle : cleaned
    }

    @objc private func toggleShelfAction() {
        appState.onRequestToggleShelf?()
    }

    @objc private func toggleStackAction() {
        appState.togglePasteStack()
    }

    @objc private func pasteRecentAction(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID,
              let clip = appState.items.first(where: { $0.id == id }) else { return }
        appState.pasteItem(clip, plainTextOnly: false, pasteDirectly: true)
    }

    @objc private func togglePauseAction() {
        appState.isPaused.toggle()
    }

    @objc private func clearHistoryAction() {
        appState.clearHistory()
    }

    @objc private func openPrefsAction() {
        appState.onRequestOpenSettings?()
    }

    @objc private func quitAction() {
        appState.saveImmediately()
        NSApplication.shared.terminate(nil)
    }
}
