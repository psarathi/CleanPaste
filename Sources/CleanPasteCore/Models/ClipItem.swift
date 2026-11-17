import Foundation
import AppKit
import SwiftUI

public enum ClipType: String, Codable, CaseIterable, Sendable {
    case text
    case link
    case image
    case file
    case color

    public var displayName: String {
        switch self {
        case .text: return "Text"
        case .link: return "Link"
        case .image: return "Image"
        case .file: return "File"
        case .color: return "Color"
        }
    }

    public var systemImage: String {
        switch self {
        case .text: return "doc.text"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "folder"
        case .color: return "paintpalette"
        }
    }
}

public enum ClipFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case text = "Text"
    case links = "Links"
    case images = "Images"
    case files = "Files"
    case colors = "Colors"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .all: return "square.grid.2x2"
        case .text: return "doc.text"
        case .links: return "link"
        case .images: return "photo"
        case .files: return "doc"
        case .colors: return "paintpalette"
        }
    }

    public func matches(_ type: ClipType) -> Bool {
        switch self {
        case .all: return true
        case .text: return type == .text
        case .links: return type == .link
        case .images: return type == .image
        case .files: return type == .file
        case .colors: return type == .color
        }
    }
}

public enum PinboardColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case blue
    case purple
    case pink
    case red
    case orange
    case yellow
    case green
    case teal
    case gray

    public var id: String { rawValue }

    public var displayName: String {
        rawValue.capitalized
    }

    public var nsColor: NSColor {
        switch self {
        case .blue: return NSColor(srgbRed: 0.16, green: 0.50, blue: 0.98, alpha: 1.0)
        case .purple: return NSColor(srgbRed: 0.62, green: 0.34, blue: 0.96, alpha: 1.0)
        case .pink: return NSColor(srgbRed: 0.95, green: 0.28, blue: 0.56, alpha: 1.0)
        case .red: return NSColor(srgbRed: 0.94, green: 0.27, blue: 0.26, alpha: 1.0)
        case .orange: return NSColor(srgbRed: 0.97, green: 0.51, blue: 0.14, alpha: 1.0)
        case .yellow: return NSColor(srgbRed: 0.93, green: 0.72, blue: 0.10, alpha: 1.0)
        case .green: return NSColor(srgbRed: 0.19, green: 0.74, blue: 0.39, alpha: 1.0)
        case .teal: return NSColor(srgbRed: 0.14, green: 0.70, blue: 0.74, alpha: 1.0)
        case .gray: return NSColor(srgbRed: 0.49, green: 0.52, blue: 0.57, alpha: 1.0)
        }
    }

    public var swiftUIColor: Color {
        Color(nsColor: nsColor)
    }
}

public struct Pinboard: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var color: PinboardColor
    public var createdAt: Date

    public init(id: UUID = UUID(), name: String, color: PinboardColor, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.color = color
        self.createdAt = createdAt
    }
}

public struct RGBColor: Codable, Hashable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: 1.0)
    }

    public var swiftUIColor: Color {
        Color(nsColor: nsColor)
    }
}

public struct ClipItem: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var type: ClipType
    public var timestamp: Date
    public var customTitle: String?
    public var textContent: String?
    public var urlString: String?
    public var linkTitle: String?
    public var linkDescription: String?
    public var hasLinkIcon: Bool
    public var hasLinkPreviewImage: Bool
    public var parsedColor: ParsedColor?
    public var filePaths: [String]
    public var imageWidth: Int?
    public var imageHeight: Int?
    public var imageFormat: String?
    public var byteSize: Int64
    public var hasRTF: Bool
    public var hasHTML: Bool
    public var contentHash: String
    public var sourceAppBundleID: String?
    public var sourceAppName: String?
    public var headerColorRGB: RGBColor?
    public var isInHistory: Bool
    public var pinboardIDs: [UUID]
    public var isSensitiveSecret: Bool
    public var secretKind: String?

    public init(
        id: UUID = UUID(),
        type: ClipType,
        timestamp: Date = Date(),
        customTitle: String? = nil,
        textContent: String? = nil,
        urlString: String? = nil,
        linkTitle: String? = nil,
        linkDescription: String? = nil,
        hasLinkIcon: Bool = false,
        hasLinkPreviewImage: Bool = false,
        parsedColor: ParsedColor? = nil,
        filePaths: [String] = [],
        imageWidth: Int? = nil,
        imageHeight: Int? = nil,
        imageFormat: String? = nil,
        byteSize: Int64 = 0,
        hasRTF: Bool = false,
        hasHTML: Bool = false,
        contentHash: String,
        sourceAppBundleID: String? = nil,
        sourceAppName: String? = nil,
        headerColorRGB: RGBColor? = nil,
        isInHistory: Bool = true,
        pinboardIDs: [UUID] = [],
        isSensitiveSecret: Bool = false,
        secretKind: String? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.customTitle = customTitle
        self.textContent = textContent
        self.urlString = urlString
        self.linkTitle = linkTitle
        self.linkDescription = linkDescription
        self.hasLinkIcon = hasLinkIcon
        self.hasLinkPreviewImage = hasLinkPreviewImage
        self.parsedColor = parsedColor
        self.filePaths = filePaths
        self.imageWidth = imageWidth
        self.imageHeight = imageHeight
        self.imageFormat = imageFormat
        self.byteSize = byteSize
        self.hasRTF = hasRTF
        self.hasHTML = hasHTML
        self.contentHash = contentHash
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceAppName = sourceAppName
        self.headerColorRGB = headerColorRGB
        self.isInHistory = isInHistory
        self.pinboardIDs = pinboardIDs
        self.isSensitiveSecret = isSensitiveSecret
        self.secretKind = secretKind
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.type = try container.decode(ClipType.self, forKey: .type)
        self.timestamp = try container.decode(Date.self, forKey: .timestamp)
        self.customTitle = try container.decodeIfPresent(String.self, forKey: .customTitle)
        self.textContent = try container.decodeIfPresent(String.self, forKey: .textContent)
        self.urlString = try container.decodeIfPresent(String.self, forKey: .urlString)
        self.linkTitle = try container.decodeIfPresent(String.self, forKey: .linkTitle)
        self.linkDescription = try container.decodeIfPresent(String.self, forKey: .linkDescription)
        self.hasLinkIcon = try container.decodeIfPresent(Bool.self, forKey: .hasLinkIcon) ?? false
        self.hasLinkPreviewImage = try container.decodeIfPresent(Bool.self, forKey: .hasLinkPreviewImage) ?? false
        self.parsedColor = try container.decodeIfPresent(ParsedColor.self, forKey: .parsedColor)
        self.filePaths = try container.decodeIfPresent([String].self, forKey: .filePaths) ?? []
        self.imageWidth = try container.decodeIfPresent(Int.self, forKey: .imageWidth)
        self.imageHeight = try container.decodeIfPresent(Int.self, forKey: .imageHeight)
        self.imageFormat = try container.decodeIfPresent(String.self, forKey: .imageFormat)
        self.byteSize = try container.decodeIfPresent(Int64.self, forKey: .byteSize) ?? 0
        self.hasRTF = try container.decodeIfPresent(Bool.self, forKey: .hasRTF) ?? false
        self.hasHTML = try container.decodeIfPresent(Bool.self, forKey: .hasHTML) ?? false
        self.contentHash = try container.decode(String.self, forKey: .contentHash)
        self.sourceAppBundleID = try container.decodeIfPresent(String.self, forKey: .sourceAppBundleID)
        self.sourceAppName = try container.decodeIfPresent(String.self, forKey: .sourceAppName)
        self.headerColorRGB = try container.decodeIfPresent(RGBColor.self, forKey: .headerColorRGB)
        self.isInHistory = try container.decodeIfPresent(Bool.self, forKey: .isInHistory) ?? true
        self.pinboardIDs = try container.decodeIfPresent([UUID].self, forKey: .pinboardIDs) ?? []
        self.isSensitiveSecret = try container.decodeIfPresent(Bool.self, forKey: .isSensitiveSecret) ?? false
        self.secretKind = try container.decodeIfPresent(String.self, forKey: .secretKind)
    }

    public var hasDynamicPlaceholders: Bool {
        guard !pinboardIDs.isEmpty, let text = textContent else { return false }
        return SnippetExpander.containsPlaceholder(text)
    }

    public var headerTitle: String {
        if let customTitle = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !customTitle.isEmpty {
            return customTitle
        }
        switch type {
        case .text:
            return hasRTF || hasHTML ? "Rich Text" : (looksLikeCode ? "Code" : "Text")
        case .link:
            return "Link"
        case .image:
            return "Image"
        case .file:
            return filePaths.count > 1 ? "\(filePaths.count) Files" : "File"
        case .color:
            return "Color"
        }
    }

    public var linkHost: String? {
        guard let urlString, let url = URL(string: urlString) else { return nil }
        return url.host?.replacingOccurrences(of: "^www\\.", with: "", options: .regularExpression)
    }

    public var looksLikeCode: Bool {
        guard let text = textContent, text.count >= 8 else { return false }
        let codeSignals = ["{", "}", "=>", "->", "func ", "def ", "const ", "let ", "var ", "import ", "SELECT ", "return ", "</", "/>", "class ", "struct ", "#include", "package "]
        let hitCount = codeSignals.reduce(0) { count, signal in
            count + (text.contains(signal) ? 1 : 0)
        }
        return hitCount >= 2 || (text.contains("\n") && (text.contains("    ") || text.contains("\t")) && text.contains(";"))
    }

    public var footerMetadata: String {
        switch type {
        case .text:
            let chars = textContent?.count ?? 0
            let lines = max(1, (textContent?.components(separatedBy: .newlines).count ?? 1))
            if lines > 1 {
                return "\(chars) chars • \(lines) lines"
            }
            return "\(chars) chars"
        case .link:
            return linkHost ?? "URL"
        case .image:
            let fmt = imageFormat?.uppercased() ?? "IMG"
            if let w = imageWidth, let h = imageHeight {
                return "\(fmt) • \(w)×\(h)"
            }
            return fmt
        case .file:
            let sizeStr = ByteCountFormatter.string(fromByteCount: byteSize, countStyle: .file)
            if filePaths.count > 1 {
                return "\(filePaths.count) items • \(sizeStr)"
            }
            if let first = filePaths.first {
                let ext = URL(fileURLWithPath: first).pathExtension.uppercased()
                if !ext.isEmpty {
                    return "\(ext) • \(sizeStr)"
                }
            }
            return sizeStr
        case .color:
            return parsedColor?.hexString ?? "Color"
        }
    }

    public var defaultHeaderColor: NSColor {
        if let headerColorRGB {
            return headerColorRGB.nsColor
        }
        if type == .color, let parsedColor {
            return parsedColor.nsColor
        }
        switch type {
        case .text: return NSColor(srgbRed: 0.24, green: 0.49, blue: 0.91, alpha: 1.0)
        case .link: return NSColor(srgbRed: 0.12, green: 0.62, blue: 0.85, alpha: 1.0)
        case .image: return NSColor(srgbRed: 0.60, green: 0.35, blue: 0.86, alpha: 1.0)
        case .file: return NSColor(srgbRed: 0.20, green: 0.66, blue: 0.50, alpha: 1.0)
        case .color: return NSColor(srgbRed: 0.90, green: 0.36, blue: 0.48, alpha: 1.0)
        }
    }

    public func matchesSearch(_ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        let fields: [String?] = [
            customTitle,
            textContent,
            urlString,
            linkTitle,
            linkDescription,
            parsedColor?.hexString,
            parsedColor?.rgbString,
            sourceAppName,
            sourceAppBundleID
        ]
        for field in fields {
            if let field, field.localizedCaseInsensitiveContains(q) {
                return true
            }
        }
        for path in filePaths {
            if URL(fileURLWithPath: path).lastPathComponent.localizedCaseInsensitiveContains(q) ||
                path.localizedCaseInsensitiveContains(q) {
                return true
            }
        }
        return false
    }
}

public enum RetentionPolicy: String, Codable, CaseIterable, Identifiable, Sendable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    case unlimited = "Unlimited"

    public var id: String { rawValue }

    public var timeInterval: TimeInterval? {
        switch self {
        case .day: return 86_400
        case .week: return 86_400 * 7
        case .month: return 86_400 * 30
        case .year: return 86_400 * 365
        case .unlimited: return nil
        }
    }
}

public enum ShelfAppearance: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto = "System"
    case light = "Light"
    case dark = "Dark"

    public var id: String { rawValue }
}

public enum PasteStackOrder: String, Codable, CaseIterable, Identifiable, Sendable {
    case fifo = "First In, First Out"
    case lifo = "Last In, First Out"

    public var id: String { rawValue }

    public var shortLabel: String {
        switch self {
        case .fifo: return "FIFO"
        case .lifo: return "LIFO"
        }
    }
}

public struct ShortcutSpec: Codable, Equatable, Hashable, Sendable {
    public var keyCode: UInt32
    /// Carbon modifier mask (cmdKey, shiftKey, optionKey, controlKey)
    public var carbonModifiers: UInt32

    public init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    // Default shortcuts matching Paste:
    // Shift + Command + V (keyCode 9 = V, shiftKey 512 + cmdKey 256 = 768)
    public static let defaultOpenShelf = ShortcutSpec(keyCode: 9, carbonModifiers: 768)
    // Shift + Command + C (keyCode 8 = C, shiftKey 512 + cmdKey 256 = 768)
    public static let defaultPasteStack = ShortcutSpec(keyCode: 8, carbonModifiers: 768)
    // Option + Command + V (keyCode 9 = V, optionKey 2048 + cmdKey 256 = 2304)
    public static let defaultPasteNext = ShortcutSpec(keyCode: 9, carbonModifiers: 2304)

    public var displayString: String {
        var result = ""
        // Standard Carbon modifier bits: controlKey = 4096, optionKey = 2048, shiftKey = 512, cmdKey = 256
        if (carbonModifiers & 4096) != 0 { result += "⌃" }
        if (carbonModifiers & 2048) != 0 { result += "⌥" }
        if (carbonModifiers & 512) != 0 { result += "⇧" }
        if (carbonModifiers & 256) != 0 { result += "⌘" }
        result += Self.keyName(for: keyCode)
        return result
    }

    public static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= 256 }
        if flags.contains(.shift) { mask |= 512 }
        if flags.contains(.option) { mask |= 2048 }
        if flags.contains(.control) { mask |= 4096 }
        return mask
    }

    public static func keyName(for keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "⇥", 49: "Space", 50: "`",
            51: "⌫", 53: "⎋",
            123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return map[keyCode] ?? "Key(\(keyCode))"
    }
}

public enum MenuBarIconStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case pasteboard = "PasteBoard"
    case coralCards = "Coral Cards"
    case spectrumCards = "Spectrum Fan"
    case sapphireMini = "Sapphire Mini"
    case tealClipboard = "Teal Clipboard"
    case indigoCyan = "Indigo & Cyan"
    case monochrome = "Monochrome"

    public var id: String { rawValue }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var directPaste: Bool
    public var singleClickToPaste: Bool
    public var terminalSafePaste: Bool
    public var pasteAsPlainTextByDefault: Bool
    public var soundEffectsEnabled: Bool
    public var moveDuplicatesToTop: Bool
    public var ignoreSensitiveContent: Bool
    public var secretHandling: SecretHandlingMode
    public var expandDynamicSnippets: Bool
    public var showMenuBarIcon: Bool
    public var menuBarIconStyle: MenuBarIconStyle
    public var retentionPolicy: RetentionPolicy
    public var shelfAppearance: ShelfAppearance
    public var pasteStackOrder: PasteStackOrder
    public var excludedBundleIDs: [String]
    public var openShelfShortcut: ShortcutSpec
    public var pasteStackShortcut: ShortcutSpec
    public var pasteNextShortcut: ShortcutSpec

    public init(
        directPaste: Bool = true,
        singleClickToPaste: Bool = false,
        terminalSafePaste: Bool = true,
        pasteAsPlainTextByDefault: Bool = false,
        soundEffectsEnabled: Bool = true,
        moveDuplicatesToTop: Bool = true,
        ignoreSensitiveContent: Bool = true,
        secretHandling: SecretHandlingMode = .maskPreview,
        expandDynamicSnippets: Bool = true,
        showMenuBarIcon: Bool = true,
        menuBarIconStyle: MenuBarIconStyle = .pasteboard,
        retentionPolicy: RetentionPolicy = .month,
        shelfAppearance: ShelfAppearance = .auto,
        pasteStackOrder: PasteStackOrder = .fifo,
        excludedBundleIDs: [String] = AppSettings.defaultExcludedBundleIDs,
        openShelfShortcut: ShortcutSpec = .defaultOpenShelf,
        pasteStackShortcut: ShortcutSpec = .defaultPasteStack,
        pasteNextShortcut: ShortcutSpec = .defaultPasteNext
    ) {
        self.directPaste = directPaste
        self.singleClickToPaste = singleClickToPaste
        self.terminalSafePaste = terminalSafePaste
        self.pasteAsPlainTextByDefault = pasteAsPlainTextByDefault
        self.soundEffectsEnabled = soundEffectsEnabled
        self.moveDuplicatesToTop = moveDuplicatesToTop
        self.ignoreSensitiveContent = ignoreSensitiveContent
        self.secretHandling = secretHandling
        self.expandDynamicSnippets = expandDynamicSnippets
        self.showMenuBarIcon = showMenuBarIcon
        self.menuBarIconStyle = menuBarIconStyle
        self.retentionPolicy = retentionPolicy
        self.shelfAppearance = shelfAppearance
        self.pasteStackOrder = pasteStackOrder
        self.excludedBundleIDs = excludedBundleIDs
        self.openShelfShortcut = openShelfShortcut
        self.pasteStackShortcut = pasteStackShortcut
        self.pasteNextShortcut = pasteNextShortcut
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.directPaste = try container.decodeIfPresent(Bool.self, forKey: .directPaste) ?? true
        self.singleClickToPaste = try container.decodeIfPresent(Bool.self, forKey: .singleClickToPaste) ?? false
        self.terminalSafePaste = try container.decodeIfPresent(Bool.self, forKey: .terminalSafePaste) ?? true
        self.pasteAsPlainTextByDefault = try container.decodeIfPresent(Bool.self, forKey: .pasteAsPlainTextByDefault) ?? false
        self.soundEffectsEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEffectsEnabled) ?? true
        self.moveDuplicatesToTop = try container.decodeIfPresent(Bool.self, forKey: .moveDuplicatesToTop) ?? true
        self.ignoreSensitiveContent = try container.decodeIfPresent(Bool.self, forKey: .ignoreSensitiveContent) ?? true
        self.secretHandling = try container.decodeIfPresent(SecretHandlingMode.self, forKey: .secretHandling) ?? .maskPreview
        self.expandDynamicSnippets = try container.decodeIfPresent(Bool.self, forKey: .expandDynamicSnippets) ?? true
        self.showMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        self.menuBarIconStyle = try container.decodeIfPresent(MenuBarIconStyle.self, forKey: .menuBarIconStyle) ?? .pasteboard
        self.retentionPolicy = try container.decodeIfPresent(RetentionPolicy.self, forKey: .retentionPolicy) ?? .month
        self.shelfAppearance = try container.decodeIfPresent(ShelfAppearance.self, forKey: .shelfAppearance) ?? .auto
        self.pasteStackOrder = try container.decodeIfPresent(PasteStackOrder.self, forKey: .pasteStackOrder) ?? .fifo
        self.excludedBundleIDs = try container.decodeIfPresent([String].self, forKey: .excludedBundleIDs) ?? AppSettings.defaultExcludedBundleIDs
        self.openShelfShortcut = try container.decodeIfPresent(ShortcutSpec.self, forKey: .openShelfShortcut) ?? .defaultOpenShelf
        self.pasteStackShortcut = try container.decodeIfPresent(ShortcutSpec.self, forKey: .pasteStackShortcut) ?? .defaultPasteStack
        self.pasteNextShortcut = try container.decodeIfPresent(ShortcutSpec.self, forKey: .pasteNextShortcut) ?? .defaultPasteNext
    }

    public static let defaultExcludedBundleIDs: [String] = [
        "com.apple.keychainaccess",
        "com.apple.Passwords",
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.bitwarden.desktop",
        "com.lastpass.LastPass",
        "com.dashlane.Dashlane"
    ]
}
