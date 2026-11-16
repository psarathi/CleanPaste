import Foundation
import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
public final class PasteService {
    public static let shared = PasteService()
    private init() {}

    public func isAccessibilityGranted() -> Bool {
        AXIsProcessTrusted()
    }

    public func promptAccessibilityPermission() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    public func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    public func writeToPasteboard(
        item: ClipItem,
        plainTextOnly: Bool,
        storage: StorageManager,
        monitor: ClipboardMonitor
    ) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        switch item.type {
        case .text:
            if plainTextOnly {
                if let text = item.textContent {
                    pasteboard.setString(text, forType: .string)
                }
            } else {
                var types: [NSPasteboard.PasteboardType] = []
                if item.textContent != nil { types.append(.string) }
                let rtfData = item.hasRTF ? storage.loadRTFData(for: item.id) : nil
                let htmlData = item.hasHTML ? storage.loadHTMLData(for: item.id) : nil
                if rtfData != nil { types.append(.rtf) }
                if htmlData != nil { types.append(.html) }
                pasteboard.declareTypes(types, owner: nil)
                if let text = item.textContent {
                    pasteboard.setString(text, forType: .string)
                }
                if let rtfData {
                    pasteboard.setData(rtfData, forType: .rtf)
                }
                if let htmlData {
                    pasteboard.setData(htmlData, forType: .html)
                }
            }

        case .link:
            let urlStr = item.urlString ?? item.textContent ?? ""
            if plainTextOnly {
                pasteboard.setString(urlStr, forType: .string)
            } else {
                pasteboard.declareTypes([.URL, .string], owner: nil)
                pasteboard.setString(urlStr, forType: .URL)
                pasteboard.setString(urlStr, forType: .string)
            }

        case .color:
            let colorText = item.textContent ?? item.parsedColor?.hexString ?? ""
            pasteboard.setString(colorText, forType: .string)

        case .image:
            if let data = storage.loadImageData(for: item.id),
               let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            }

        case .file:
            if plainTextOnly {
                pasteboard.setString(item.filePaths.joined(separator: "\n"), forType: .string)
            } else {
                let urls = item.filePaths.map { URL(fileURLWithPath: $0) as NSURL }
                pasteboard.writeObjects(urls)
            }
        }

        monitor.markInternalWrite(changeCount: pasteboard.changeCount)
    }

    public func writeCustomString(
        _ string: String,
        monitor: ClipboardMonitor
    ) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        monitor.markInternalWrite(changeCount: pasteboard.changeCount)
    }

    public func simulateCommandV() {
        guard isAccessibilityGranted() else { return }
        let source = CGEventSource(stateID: .combinedSessionState) ?? CGEventSource(stateID: .hidSystemState)
        let vKeyCode = CGKeyCode(kVK_ANSI_V)
        // Include both device-independent Command flag and left-Command device mask for Terminal/Electron/AppKit compatibility
        let cmdFlags = CGEventFlags(rawValue: CGEventFlags.maskCommand.rawValue | 0x000008)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: vKeyCode, keyDown: false) else {
            return
        }
        keyDown.flags = cmdFlags
        keyUp.flags = cmdFlags
        keyDown.post(tap: .cgSessionEventTap)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.012) {
            keyUp.post(tap: .cgSessionEventTap)
        }
    }
}
