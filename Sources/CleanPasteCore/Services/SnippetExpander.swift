import Foundation

public enum SnippetExpander {
    public static let supportedPlaceholders: [String] = [
        "{{date}}",
        "{{time}}",
        "{{datetime}}",
        "{{uuid}}",
        "{{clipboard}}"
    ]

    public static func containsPlaceholder(_ text: String) -> Bool {
        supportedPlaceholders.contains { text.contains($0) }
    }

    public static func expand(
        _ text: String,
        now: Date = Date(),
        timeZone: TimeZone = .current,
        uuidProvider: () -> String = { UUID().uuidString },
        clipboardProvider: () -> String? = { nil }
    ) -> String {
        guard containsPlaceholder(text) else { return text }

        var result = text

        if result.contains("{{date}}") {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = timeZone
            df.dateFormat = "yyyy-MM-dd"
            result = result.replacingOccurrences(of: "{{date}}", with: df.string(from: now))
        }

        if result.contains("{{time}}") {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = timeZone
            df.dateFormat = "HH:mm"
            result = result.replacingOccurrences(of: "{{time}}", with: df.string(from: now))
        }

        if result.contains("{{datetime}}") {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.timeZone = timeZone
            df.dateFormat = "yyyy-MM-dd HH:mm"
            result = result.replacingOccurrences(of: "{{datetime}}", with: df.string(from: now))
        }

        while result.contains("{{uuid}}") {
            if let range = result.range(of: "{{uuid}}") {
                result.replaceSubrange(range, with: uuidProvider())
            }
        }

        if result.contains("{{clipboard}}") {
            let clip = clipboardProvider() ?? ""
            result = result.replacingOccurrences(of: "{{clipboard}}", with: clip)
        }

        return result
    }
}
