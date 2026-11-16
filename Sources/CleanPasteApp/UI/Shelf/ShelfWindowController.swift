import SwiftUI
import AppKit
import Combine
import Carbon.HIToolbox
import CleanPasteCore

final class ShelfPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class ShelfWindowController: NSObject {
    private let appState: AppState
    private var panel: ShelfPanel?
    private var hostingView: NSHostingView<AnyView>?

    private var previousFrontApp: NSRunningApplication?
    private var localKeyMonitor: Any?
    private var globalMouseMonitor: Any?
    private var workspaceObserver: NSObjectProtocol?
    private var isSearchFocusedStorage: Bool = false
    private var cancellables = Set<AnyCancellable>()

    private var currentShelfHeight: CGFloat {
        appState.isPasteStackActive ? 398 : 362
    }

    var quickLookWindowProvider: (() -> NSWindow?)?
    var isModalOpenProvider: (() -> Bool)?

    init(appState: AppState) {
        self.appState = appState
        super.init()
        captureCurrentExternalFrontApp()
        observeWorkspaceActivation()
        wireCallbacks()
        appState.$isPasteStackActive
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.adjustHeightIfVisible()
            }
            .store(in: &cancellables)
    }

    private func captureCurrentExternalFrontApp() {
        if let front = NSWorkspace.shared.frontmostApplication,
           front.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousFrontApp = front
        }
    }

    private func observeWorkspaceActivation() {
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            Task { @MainActor in
                if app.bundleIdentifier != Bundle.main.bundleIdentifier {
                    self?.previousFrontApp = app
                }
            }
        }
    }

    private func adjustHeightIfVisible() {
        guard appState.isShelfVisible, let panel else { return }
        let targetHeight = currentShelfHeight
        var frame = panel.frame
        if abs(frame.height - targetHeight) > 0.5 {
            frame.size.height = targetHeight
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                panel.animator().setFrame(frame, display: true)
            }
        }
    }

    private func wireCallbacks() {
        appState.onRequestToggleShelf = { [weak self] in
            self?.toggle()
        }
        appState.onRequestDismissAndPaste = { [weak self] shouldSimulateCmdV in
            self?.dismissAndPaste(shouldSimulateCmdV: shouldSimulateCmdV)
        }
    }

    func toggle() {
        if appState.isShelfVisible {
            hide(restorePreviousApp: true)
        } else {
            show()
        }
    }

    func show() {
        guard !appState.isShelfVisible else { return }

        captureCurrentExternalFrontApp()
        if NSApp.isHidden {
            NSApp.unhideWithoutActivation()
        }

        ensurePanel()
        guard let panel else { return }

        appState.refreshAccessibilityStatus()
        appState.ensureValidSelection()
        appState.isShelfVisible = true

        let targetScreen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
            ?? NSScreen.main
            ?? NSScreen.screens.first

        guard let screen = targetScreen else { return }

        let screenFrame = screen.frame
        let height = currentShelfHeight
        let finalFrame = NSRect(
            x: screenFrame.minX,
            y: screenFrame.minY,
            width: screenFrame.width,
            height: height
        )
        let startFrame = NSRect(
            x: screenFrame.minX,
            y: screenFrame.minY - height,
            width: screenFrame.width,
            height: height
        )

        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.21
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(finalFrame, display: true)
            panel.animator().alphaValue = 1.0
        }

        installMonitors()
    }

    func hide(restorePreviousApp: Bool = false, completion: (() -> Void)? = nil) {
        guard appState.isShelfVisible else {
            completion?()
            return
        }

        appState.isShelfVisible = false
        appState.onRequestCloseQuickLook?()
        isSearchFocusedStorage = false
        rebuildRootView()
        removeMonitors()

        guard let panel else {
            if restorePreviousApp, let target = previousFrontApp {
                activateTargetApp(target)
            }
            completion?()
            return
        }

        let currentFrame = panel.frame
        let offscreenFrame = NSRect(
            x: currentFrame.minX,
            y: currentFrame.minY - currentFrame.height,
            width: currentFrame.width,
            height: currentFrame.height
        )

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.13
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().setFrame(offscreenFrame, display: true)
            panel.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                panel.orderOut(nil)
                if restorePreviousApp, let target = self?.previousFrontApp {
                    self?.activateTargetApp(target)
                }
                completion?()
            }
        })
    }

    private func hideImmediately() {
        appState.isShelfVisible = false
        appState.onRequestCloseQuickLook?()
        isSearchFocusedStorage = false
        rebuildRootView()
        removeMonitors()
        panel?.alphaValue = 0
        panel?.orderOut(nil)
    }

    private func activateTargetApp(_ app: NSRunningApplication) {
        guard !app.isTerminated else { return }
        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: app)
            _ = app.activate(from: NSRunningApplication.current, options: [])
        } else {
            _ = app.activate(options: .activateIgnoringOtherApps)
        }
    }

    private func dismissAndPaste(shouldSimulateCmdV: Bool) {
        let targetApp = previousFrontApp
        if shouldSimulateCmdV {
            hideImmediately()
            if let targetApp, !targetApp.isTerminated {
                activateTargetApp(targetApp)
                waitUntilFrontmostAndPaste(targetApp: targetApp, attempt: 0)
            } else {
                if isModalOpenProvider?() != true {
                    NSApp.hide(nil)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    PasteService.shared.simulateCommandV()
                }
            }
        } else {
            hide(restorePreviousApp: targetApp != nil)
        }
    }

    private func waitUntilFrontmostAndPaste(targetApp: NSRunningApplication, attempt: Int) {
        let isFront = NSWorkspace.shared.frontmostApplication?.processIdentifier == targetApp.processIdentifier
        if isFront {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.045) {
                PasteService.shared.simulateCommandV()
            }
            return
        }

        if attempt == 3 {
            // Re-yield or hide CleanPaste if cooperative activation hasn't transferred yet
            activateTargetApp(targetApp)
            if isModalOpenProvider?() != true && NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier {
                NSApp.hide(nil)
            }
        }

        if attempt >= 24 {
            // Max ~360ms elapsed; attempt paste if target isn't CleanPaste
            if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier {
                PasteService.shared.simulateCommandV()
            }
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.015) { [weak self] in
            self?.waitUntilFrontmostAndPaste(targetApp: targetApp, attempt: attempt + 1)
        }
    }

    private func ensurePanel() {
        if panel != nil { return }

        let p = ShelfPanel(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: currentShelfHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        // Float cleanly above dock and active app windows
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 2)
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false

        self.panel = p
        rebuildRootView()
    }

    private func rebuildRootView() {
        guard let panel else { return }
        let searchBinding = Binding<Bool>(
            get: { [weak self] in self?.isSearchFocusedStorage ?? false },
            set: { [weak self] newValue in
                self?.isSearchFocusedStorage = newValue
            }
        )
        let root = AnyView(
            ShelfView(isSearchFocused: searchBinding)
                .environmentObject(appState)
        )
        if let hostingView {
            hostingView.rootView = root
        } else {
            let hosting = NSHostingView(rootView: root)
            hosting.translatesAutoresizingMaskIntoConstraints = false
            panel.contentView = hosting
            self.hostingView = hosting
        }
    }

    private func updateSearchFocus(_ focused: Bool) {
        isSearchFocusedStorage = focused
        rebuildRootView()
        if !focused {
            panel?.makeFirstResponder(nil)
        }
    }

    // MARK: - Event Monitors

    private func installMonitors() {
        removeMonitors()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleLocalKeyDown(event)
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.appState.isShelfVisible else { return }
                if self.isModalOpenProvider?() == true { return }
                self.hide(restorePreviousApp: false)
            }
        }
    }

    private func removeMonitors() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    private func handleLocalKeyDown(_ event: NSEvent) -> NSEvent? {
        guard appState.isShelfVisible else { return event }
        if isModalOpenProvider?() == true { return event }

        let keyWindow = NSApp.keyWindow
        let qlWindow = quickLookWindowProvider?()
        let isShelfOrQLKey = (keyWindow === panel) || (qlWindow != nil && keyWindow === qlWindow)
        guard isShelfOrQLKey else { return event }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let keyCode = event.keyCode

        // 1. Escape
        if keyCode == UInt16(kVK_Escape) {
            if appState.isQuickLookOpen {
                appState.onRequestCloseQuickLook?()
                return nil
            }
            if !appState.searchQuery.isEmpty {
                appState.searchQuery = ""
                return nil
            }
            if appState.isSearchVisible || isSearchFocusedStorage {
                appState.isSearchVisible = false
                updateSearchFocus(false)
                return nil
            }
            hide(restorePreviousApp: true)
            return nil
        }

        // 2. Cmd+1..9 Quick Paste (with optional Shift for plain text)
        let quickPasteKeyCodes: [UInt16] = [
            UInt16(kVK_ANSI_1), UInt16(kVK_ANSI_2), UInt16(kVK_ANSI_3),
            UInt16(kVK_ANSI_4), UInt16(kVK_ANSI_5), UInt16(kVK_ANSI_6),
            UInt16(kVK_ANSI_7), UInt16(kVK_ANSI_8), UInt16(kVK_ANSI_9)
        ]
        if flags.contains(.command),
           !flags.contains(.control),
           !flags.contains(.option),
           let idx = quickPasteKeyCodes.firstIndex(of: keyCode) {
            appState.quickPaste(index: idx, plainTextOnly: flags.contains(.shift))
            return nil
        }

        // 3. Cmd+F -> Focus Search
        if flags == .command && keyCode == UInt16(kVK_ANSI_F) {
            appState.isSearchVisible = true
            updateSearchFocus(true)
            return nil
        }

        // 4. Cmd+Left / Cmd+Right -> Switch Pinboard Tabs
        if flags.contains(.command) && !flags.contains(.shift) && !flags.contains(.option) {
            if keyCode == UInt16(kVK_LeftArrow) {
                appState.selectTab(byDelta: -1)
                return nil
            }
            if keyCode == UInt16(kVK_RightArrow) {
                appState.selectTab(byDelta: 1)
                return nil
            }
        }

        // 5. Return / Enter -> Paste Selected Card (Shift+Return = Plain Text)
        if keyCode == UInt16(kVK_Return) || keyCode == UInt16(kVK_ANSI_KeypadEnter) {
            if let selected = appState.selectedItem {
                appState.pasteItem(selected, plainTextOnly: flags.contains(.shift) ? true : nil, pasteDirectly: true)
                return nil
            }
        }

        // Check whether Search field text editor currently has focus
        let isEditingSearch = (panel?.firstResponder is NSTextView)

        // 6. Navigation & Card Commands when not typing inside Search
        if !isEditingSearch {
            switch Int(keyCode) {
            case kVK_LeftArrow:
                appState.moveSelection(by: -1)
                if appState.isQuickLookOpen { appState.onRequestOpenQuickLook?() }
                return nil
            case kVK_RightArrow:
                appState.moveSelection(by: 1)
                if appState.isQuickLookOpen { appState.onRequestOpenQuickLook?() }
                return nil
            case kVK_Home:
                appState.selectedItemID = appState.visibleItems.first?.id
                if appState.isQuickLookOpen { appState.onRequestOpenQuickLook?() }
                return nil
            case kVK_End:
                appState.selectedItemID = appState.visibleItems.last?.id
                if appState.isQuickLookOpen { appState.onRequestOpenQuickLook?() }
                return nil
            case kVK_Space:
                if appState.isQuickLookOpen {
                    appState.onRequestCloseQuickLook?()
                } else if appState.selectedItem != nil {
                    appState.onRequestOpenQuickLook?()
                }
                return nil
            case kVK_Delete, kVK_ForwardDelete:
                if let selected = appState.selectedItem {
                    appState.deleteItem(selected.id)
                }
                return nil
            default:
                break
            }

            if flags == .command {
                switch Int(keyCode) {
                case kVK_ANSI_C:
                    if let selected = appState.selectedItem {
                        appState.copyItem(selected)
                    }
                    return nil
                case kVK_ANSI_E:
                    if let selected = appState.selectedItem,
                       selected.type == .text || selected.type == .link || selected.type == .color {
                        appState.onRequestOpenEdit?(selected)
                    }
                    return nil
                case kVK_ANSI_R:
                    if let selected = appState.selectedItem {
                        appState.onRequestOpenRename?(selected)
                    }
                    return nil
                case kVK_ANSI_Z:
                    appState.undoLastDelete()
                    return nil
                case kVK_Delete:
                    if let selected = appState.selectedItem {
                        appState.deleteItem(selected.id)
                    }
                    return nil
                default:
                    break
                }
            }

            // 7. Type-to-Search: any printable character starts searching immediately
            if !flags.contains(.command),
               !flags.contains(.control),
               !flags.contains(.option),
               keyCode != UInt16(kVK_Tab),
               let chars = event.characters,
               !chars.isEmpty,
               chars.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) && $0.value < 0xF700 }) {
                appState.isSearchVisible = true
                appState.searchQuery.append(chars)
                updateSearchFocus(true)
                return nil
            }
        } else {
            // While editing Search: allow Up/Down arrows to leave search focus so user can arrow through cards
            if keyCode == UInt16(kVK_DownArrow) || keyCode == UInt16(kVK_UpArrow) {
                updateSearchFocus(false)
                return nil
            }
        }

        return event
    }
}
