import Foundation

public enum SecretHandlingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case maskPreview = "Mask Preview"
    case skipCapture = "Ignore & Skip"
    case off = "Off"

    public var id: String { rawValue }
}

public enum SecretDetector {
    private struct Rule {
        let kind: String
        let regex: NSRegularExpression
    }

    private static let rules: [Rule] = {
        let specs: [(String, String)] = [
            ("Private Key", #"-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----"#),
            ("GitHub Token", #"\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}\b|\bgithub_pat_[A-Za-z0-9_]{20,}\b"#),
            ("AWS Access Key", #"\b(AKIA|ASIA)[0-9A-Z]{16}\b"#),
            ("Slack Token", #"\bxox[baprs]-[A-Za-z0-9-]{10,}\b"#),
            ("API Key", #"\b(sk-ant-[A-Za-z0-9_-]{20,}|sk-[A-Za-z0-9_-]{20,}|sk_live_[A-Za-z0-9]{16,}|rk_live_[A-Za-z0-9]{16,})\b"#),
            ("JWT Token", #"\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"#),
            ("Bearer Token", #"^Bearer\s+[A-Za-z0-9._~+/=-]{24,}$"#)
        ]
        return specs.compactMap { kind, pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
            return Rule(kind: kind, regex: regex)
        }
    }()

    public static func detectSecretKind(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 16_384 else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        for rule in rules {
            if rule.regex.firstMatch(in: trimmed, options: [], range: range) != nil {
                return rule.kind
            }
        }
        return nil
    }
}
