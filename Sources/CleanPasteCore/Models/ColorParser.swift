import Foundation
import AppKit

public struct ParsedColor: Equatable, Hashable, Codable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = min(max(red, 0), 1)
        self.green = min(max(green, 0), 1)
        self.blue = min(max(blue, 0), 1)
        self.alpha = min(max(alpha, 0), 1)
    }

    public var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    public var isLight: Bool {
        // Perceived luminance blended over white background when alpha < 1
        let r = red * alpha + (1 - alpha)
        let g = green * alpha + (1 - alpha)
        let b = blue * alpha + (1 - alpha)
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return luminance > 0.62
    }

    public var hexString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        if alpha < 0.999 {
            let a = Int(round(alpha * 255))
            return String(format: "#%02X%02X%02X%02X", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    public var rgbString: String {
        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))
        if alpha < 0.999 {
            return String(format: "rgba(%d, %d, %d, %.2f)", r, g, b, alpha)
        }
        return "rgb(\(r), \(g), \(b))"
    }

    public var hslString: String {
        let (h, s, l) = hslComponents
        if alpha < 0.999 {
            return String(format: "hsla(%d, %d%%, %d%%, %.2f)", h, s, l, alpha)
        }
        return "hsl(\(h), \(s)%, \(l)%)"
    }

    public var hslComponents: (h: Int, s: Int, l: Int) {
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        let delta = maxC - minC
        let l = (maxC + minC) / 2.0

        var h: Double = 0
        var s: Double = 0

        if delta > 0.0001 {
            s = l > 0.5 ? delta / (2.0 - maxC - minC) : delta / (maxC + minC)
            if maxC == red {
                h = ((green - blue) / delta) + (green < blue ? 6.0 : 0.0)
            } else if maxC == green {
                h = ((blue - red) / delta) + 2.0
            } else {
                h = ((red - green) / delta) + 4.0
            }
            h /= 6.0
        }

        return (Int(round(h * 360)) % 360, Int(round(s * 100)), Int(round(l * 100)))
    }
}

public enum ColorParser {
    public static func parse(_ raw: String) -> ParsedColor? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 64 else { return nil }

        if trimmed.hasPrefix("#") {
            return parseHex(String(trimmed.dropFirst()))
        }
        let lower = trimmed.lowercased()
        if lower.hasPrefix("0x") {
            return parseHex(String(trimmed.dropFirst(2)))
        }
        if lower.hasPrefix("rgb(") || lower.hasPrefix("rgba(") {
            return parseRGB(lower)
        }
        if lower.hasPrefix("hsl(") || lower.hasPrefix("hsla(") {
            return parseHSL(lower)
        }
        return nil
    }

    private static func parseHex(_ hex: String) -> ParsedColor? {
        let chars = Array(hex)
        guard chars.allSatisfy({ $0.isHexDigit }) else { return nil }

        switch chars.count {
        case 3:
            guard let r = hexVal(chars[0], chars[0]),
                  let g = hexVal(chars[1], chars[1]),
                  let b = hexVal(chars[2], chars[2]) else { return nil }
            return ParsedColor(red: r, green: g, blue: b)
        case 4:
            guard let r = hexVal(chars[0], chars[0]),
                  let g = hexVal(chars[1], chars[1]),
                  let b = hexVal(chars[2], chars[2]),
                  let a = hexVal(chars[3], chars[3]) else { return nil }
            return ParsedColor(red: r, green: g, blue: b, alpha: a)
        case 6:
            guard let r = hexVal(chars[0], chars[1]),
                  let g = hexVal(chars[2], chars[3]),
                  let b = hexVal(chars[4], chars[5]) else { return nil }
            return ParsedColor(red: r, green: g, blue: b)
        case 8:
            guard let r = hexVal(chars[0], chars[1]),
                  let g = hexVal(chars[2], chars[3]),
                  let b = hexVal(chars[4], chars[5]),
                  let a = hexVal(chars[6], chars[7]) else { return nil }
            return ParsedColor(red: r, green: g, blue: b, alpha: a)
        default:
            return nil
        }
    }

    private static func hexVal(_ c1: Character, _ c2: Character) -> Double? {
        guard let v = Int(String([c1, c2]), radix: 16) else { return nil }
        return Double(v) / 255.0
    }

    private static func extractFunctionArgs(_ str: String, prefix: String) -> [String]? {
        guard str.hasPrefix(prefix), str.hasSuffix(")") else { return nil }
        let start = str.index(str.startIndex, offsetBy: prefix.count)
        let end = str.index(before: str.endIndex)
        let inner = String(str[start..<end])
        // Support comma or space/slash separated CSS Color Level 4 syntax
        let normalized = inner.replacingOccurrences(of: "/", with: ",")
        let parts = normalized
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts
    }

    private static func parseRGB(_ lower: String) -> ParsedColor? {
        let prefix = lower.hasPrefix("rgba(") ? "rgba(" : "rgb("
        guard let parts = extractFunctionArgs(lower, prefix: prefix),
              parts.count == 3 || parts.count == 4 else { return nil }

        func parseChannel(_ token: String) -> Double? {
            if token.hasSuffix("%"), let pct = Double(token.dropLast()) {
                return min(max(pct / 100.0, 0), 1)
            }
            guard let v = Double(token) else { return nil }
            return min(max(v / 255.0, 0), 1)
        }

        func parseAlpha(_ token: String) -> Double? {
            if token.hasSuffix("%"), let pct = Double(token.dropLast()) {
                return min(max(pct / 100.0, 0), 1)
            }
            guard let v = Double(token) else { return nil }
            return min(max(v, 0), 1)
        }

        guard let r = parseChannel(parts[0]),
              let g = parseChannel(parts[1]),
              let b = parseChannel(parts[2]) else { return nil }
        let a = parts.count == 4 ? parseAlpha(parts[3]) : 1.0
        guard let alpha = a else { return nil }
        return ParsedColor(red: r, green: g, blue: b, alpha: alpha)
    }

    private static func parseHSL(_ lower: String) -> ParsedColor? {
        let prefix = lower.hasPrefix("hsla(") ? "hsla(" : "hsl("
        guard let parts = extractFunctionArgs(lower, prefix: prefix),
              parts.count == 3 || parts.count == 4 else { return nil }

        let hRawStr = parts[0].replacingOccurrences(of: "deg", with: "")
        guard let hRaw = Double(hRawStr) else { return nil }
        let h = ((hRaw.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) / 360.0

        guard let sPct = Double(parts[1].replacingOccurrences(of: "%", with: "")),
              let lPct = Double(parts[2].replacingOccurrences(of: "%", with: "")) else { return nil }
        let s = min(max(sPct / 100.0, 0), 1)
        let l = min(max(lPct / 100.0, 0), 1)

        var alpha = 1.0
        if parts.count == 4 {
            if parts[3].hasSuffix("%"), let pct = Double(parts[3].dropLast()) {
                alpha = min(max(pct / 100.0, 0), 1)
            } else if let a = Double(parts[3]) {
                alpha = min(max(a, 0), 1)
            } else {
                return nil
            }
        }

        let (r, g, b) = hslToRGB(h: h, s: s, l: l)
        return ParsedColor(red: r, green: g, blue: b, alpha: alpha)
    }

    private static func hslToRGB(h: Double, s: Double, l: Double) -> (Double, Double, Double) {
        if s == 0 { return (l, l, l) }
        func hue2rgb(_ p: Double, _ q: Double, _ tInput: Double) -> Double {
            var t = tInput
            if t < 0 { t += 1 }
            if t > 1 { t -= 1 }
            if t < 1.0 / 6.0 { return p + (q - p) * 6.0 * t }
            if t < 0.5 { return q }
            if t < 2.0 / 3.0 { return p + (q - p) * (2.0 / 3.0 - t) * 6.0 }
            return p
        }
        let q = l < 0.5 ? l * (1.0 + s) : l + s - l * s
        let p = 2.0 * l - q
        return (
            hue2rgb(p, q, h + 1.0 / 3.0),
            hue2rgb(p, q, h),
            hue2rgb(p, q, h - 1.0 / 3.0)
        )
    }
}
