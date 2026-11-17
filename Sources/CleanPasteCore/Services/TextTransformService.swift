import Foundation

public enum ClipTransform: String, CaseIterable, Identifiable, Sendable {
    case uppercase = "UPPERCASE"
    case lowercase = "lowercase"
    case titleCase = "Title Case"
    case camelCase = "camelCase"
    case snakeCase = "snake_case"
    case trimWhitespace = "Trim Whitespace"
    case joinLines = "Join Lines"
    case prettyJSON = "Pretty-Print JSON"
    case minifyJSON = "Minify JSON"
    case base64Encode = "Base64 Encode"
    case base64Decode = "Base64 Decode"
    case stripTrackingParams = "Clean URL (Remove Tracking)"

    public var id: String { rawValue }
}

public enum TextTransformService {
    private static let trackingParamExactKeys: Set<String> = [
        "fbclid", "gclid", "dclid", "gbraid", "wbraid",
        "mc_cid", "mc_eid", "igshid", "mkt_tok",
        "_hsenc", "_hsmi", "yclid", "vero_id", "oly_anon_id", "oly_enc_id"
    ]

    public static func availableTransforms(for text: String, isLink: Bool) -> [ClipTransform] {
        var list: [ClipTransform] = []
        if isLink || URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))?.scheme?.lowercased().hasPrefix("http") == true {
            list.append(.stripTrackingParams)
        }
        if isValidJSON(text) {
            list.append(.prettyJSON)
            list.append(.minifyJSON)
        }
        list.append(contentsOf: [
            .uppercase,
            .lowercase,
            .titleCase,
            .camelCase,
            .snakeCase,
            .trimWhitespace,
            .joinLines,
            .base64Encode
        ])
        if apply(.base64Decode, to: text) != nil {
            list.append(.base64Decode)
        }
        return list
    }

    public static func isValidJSON(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (trimmed.hasPrefix("{") && trimmed.hasSuffix("}")) ||
              (trimmed.hasPrefix("[") && trimmed.hasSuffix("]")),
              let data = trimmed.data(using: .utf8) else {
            return false
        }
        return (try? JSONSerialization.jsonObject(with: data, options: [])) != nil
    }

    public static func apply(_ transform: ClipTransform, to input: String) -> String? {
        switch transform {
        case .uppercase:
            return input.uppercased()
        case .lowercase:
            return input.lowercased()
        case .titleCase:
            return input.localizedCapitalized
        case .camelCase:
            let words = splitIntoWords(input)
            guard let first = words.first else { return "" }
            let rest = words.dropFirst().map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            return ([first.lowercased()] + rest).joined()
        case .snakeCase:
            return splitIntoWords(input).map { $0.lowercased() }.joined(separator: "_")
        case .trimWhitespace:
            return input.trimmingCharacters(in: .whitespacesAndNewlines)
        case .joinLines:
            return input
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        case .prettyJSON:
            return formatJSON(input, pretty: true)
        case .minifyJSON:
            return formatJSON(input, pretty: false)
        case .base64Encode:
            return Data(input.utf8).base64EncodedString()
        case .base64Decode:
            return decodeBase64(input)
        case .stripTrackingParams:
            return cleanURL(input)
        }
    }

    private static func splitIntoWords(_ input: String) -> [String] {
        // Insert spaces at camelCase boundaries, then split on non-alphanumeric separators
        var spaced = ""
        var prev: Character?
        for ch in input {
            if let p = prev,
               (p.isLowercase || p.isNumber) && ch.isUppercase {
                spaced.append(" ")
            }
            spaced.append(ch)
            prev = ch
        }
        return spaced
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private static func formatJSON(_ input: String, pretty: Bool) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }
        var opts: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes, .fragmentsAllowed]
        if pretty {
            opts.insert(.prettyPrinted)
        }
        guard let outData = try? JSONSerialization.data(withJSONObject: obj, options: opts) else {
            return nil
        }
        return String(data: outData, encoding: .utf8)
    }

    private static func decodeBase64(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 4 else { return nil }
        var normalized = trimmed
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder == 1 { return nil }
        if remainder > 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: normalized),
              let decoded = String(data: data, encoding: .utf8),
              !decoded.isEmpty else {
            return nil
        }
        return decoded
    }

    private static func cleanURL(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return nil
        }
        if let queryItems = components.queryItems {
            let filtered = queryItems.filter { item in
                let name = item.name.lowercased()
                if name.hasPrefix("utm_") { return false }
                return !trackingParamExactKeys.contains(name)
            }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }
        return components.string ?? trimmed
    }
}
