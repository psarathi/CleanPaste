import Foundation
import AppKit
import Carbon.HIToolbox

@MainActor
public final class HotkeyManager {
    public static let shared = HotkeyManager()

    public var onToggleShelf: (() -> Void)?
    public var onTogglePasteStack: (() -> Void)?
    public var onPasteNextFromStack: (() -> Void)?
    public var onExternalCommandVDetected: (() -> Void)?

    private var eventHandlerRef: EventHandlerRef?
    private var openShelfHotKeyRef: EventHotKeyRef?
    private var pasteStackHotKeyRef: EventHotKeyRef?
    private var pasteNextHotKeyRef: EventHotKeyRef?

    private var pasteTap: CFMachPort?
    private var pasteTapRunLoopSource: CFRunLoopSource?
    private var isMonitoringCommandV: Bool = false

    private enum HotKeyID: UInt32 {
        case openShelf = 1
        case pasteStack = 2
        case pasteNext = 3
    }

    private init() {}

    public func start(settings: AppSettings) {
        installCarbonHandlerIfNeeded()
        registerHotKeys(settings: settings)
    }

    public func reconfigure(settings: AppSettings) {
        unregisterAllHotKeys()
        registerHotKeys(settings: settings)
    }

    public func setMonitoringCommandV(_ active: Bool) {
        if active == isMonitoringCommandV { return }
        isMonitoringCommandV = active
        if active {
            startCommandVTapIfPermitted()
        } else {
            stopCommandVTap()
        }
    }

    private func installCarbonHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, userData -> OSStatus in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let err = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            guard err == noErr else { return err }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            let rawID = hotKeyID.id
            Task { @MainActor in
                manager.handleHotKey(id: rawID)
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func handleHotKey(id: UInt32) {
        switch HotKeyID(rawValue: id) {
        case .openShelf:
            onToggleShelf?()
        case .pasteStack:
            onTogglePasteStack?()
        case .pasteNext:
            onPasteNextFromStack?()
        case .none:
            break
        }
    }

    private func registerHotKeys(settings: AppSettings) {
        registerHotKey(spec: settings.openShelfShortcut, id: .openShelf, ref: &openShelfHotKeyRef)
        registerHotKey(spec: settings.pasteStackShortcut, id: .pasteStack, ref: &pasteStackHotKeyRef)
        registerHotKey(spec: settings.pasteNextShortcut, id: .pasteNext, ref: &pasteNextHotKeyRef)
    }

    private func registerHotKey(spec: ShortcutSpec, id: HotKeyID, ref: inout EventHotKeyRef?) {
        let signature: OSType = 0x434C5053 // 'CLPS'
        let hotKeyID = EventHotKeyID(signature: signature, id: id.rawValue)
        var outRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            spec.keyCode,
            spec.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &outRef
        )
        if status == noErr {
            ref = outRef
        }
    }

    private func unregisterAllHotKeys() {
        if let ref = openShelfHotKeyRef { UnregisterEventHotKey(ref); openShelfHotKeyRef = nil }
        if let ref = pasteStackHotKeyRef { UnregisterEventHotKey(ref); pasteStackHotKeyRef = nil }
        if let ref = pasteNextHotKeyRef { UnregisterEventHotKey(ref); pasteNextHotKeyRef = nil }
    }

    // MARK: - Passive CGEventTap for Auto-Advance Paste Stack on Cmd+V

    private func startCommandVTapIfPermitted() {
        guard pasteTap == nil else { return }
        guard AXIsProcessTrusted() else { return }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userData -> Unmanaged<CGEvent>? in
            guard let userData else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = manager.pasteTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passUnretained(event)
            }

            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            let isCmdOnly = flags.contains(.maskCommand)
                && !flags.contains(.maskShift)
                && !flags.contains(.maskAlternate)
                && !flags.contains(.maskControl)

            if keyCode == Int64(kVK_ANSI_V) && isCmdOnly {
                Task { @MainActor in
                    // Ignore Cmd+V synthesized by CleanPaste itself or inside CleanPaste UI
                    if NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier {
                        manager.onExternalCommandVDetected?()
                    }
                }
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.pasteTap = tap
        self.pasteTapRunLoopSource = source
    }

    private func stopCommandVTap() {
        if let source = pasteTapRunLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            pasteTapRunLoopSource = nil
        }
        if let tap = pasteTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            pasteTap = nil
        }
    }
}
