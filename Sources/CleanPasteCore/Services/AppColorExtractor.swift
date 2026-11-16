import Foundation
import AppKit

public final class AppColorExtractor {
    public static let shared = AppColorExtractor()

    private var iconCache: [String: NSImage] = [:]
    private var colorCache: [String: RGBColor] = [:]

    private init() {}

    public func appIcon(for bundleID: String?) -> NSImage? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        if let cached = iconCache[bundleID] {
            return cached
        }
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: 64, height: 64)
            iconCache[bundleID] = icon
            return icon
        }
        return nil
    }

    public func dominantHeaderColor(for bundleID: String?) -> RGBColor? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        if let cached = colorCache[bundleID] {
            return cached
        }
        guard let icon = appIcon(for: bundleID) else {
            return nil
        }
        if let extracted = extractVibrantColor(from: icon) {
            colorCache[bundleID] = extracted
            return extracted
        }
        return nil
    }

    /// Samples a downscaled 24x24 bitmap of the app icon and finds the most prominent saturated hue,
    /// adjusting brightness/saturation so white header text remains crisp and readable.
    public func extractVibrantColor(from image: NSImage) -> RGBColor? {
        let sampleSize = 24
        guard let bitmapRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: sampleSize,
            pixelsHigh: sampleSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: sampleSize * 4,
            bitsPerPixel: 32
        ) else {
            return nil
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmapRep)
        image.draw(
            in: NSRect(x: 0, y: 0, width: sampleSize, height: sampleSize),
            from: .zero,
            operation: .copy,
            fraction: 1.0
        )
        NSGraphicsContext.restoreGraphicsState()

        // Bucket hues into 18 sectors (20° each) weighted by saturation & non-neutrality
        struct Bucket {
            var weight: Double = 0
            var rSum: Double = 0
            var gSum: Double = 0
            var bSum: Double = 0
        }
        var buckets = Array(repeating: Bucket(), count: 18)
        var fallbackWeight = 0.0
        var fallbackR = 0.0
        var fallbackG = 0.0
        var fallbackB = 0.0

        for y in 0..<sampleSize {
            for x in 0..<sampleSize {
                guard let color = bitmapRep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                let a = color.alphaComponent
                if a < 0.35 { continue }

                var h: CGFloat = 0
                var s: CGFloat = 0
                var b: CGFloat = 0
                var alphaOut: CGFloat = 0
                color.getHue(&h, saturation: &s, brightness: &b, alpha: &alphaOut)

                let r = Double(color.redComponent)
                let g = Double(color.greenComponent)
                let bl = Double(color.blueComponent)

                // Ignore near-white and near-black background pixels
                if b < 0.14 || (s < 0.12 && b > 0.85) {
                    fallbackWeight += Double(a) * 0.25
                    fallbackR += r * Double(a) * 0.25
                    fallbackG += g * Double(a) * 0.25
                    fallbackB += bl * Double(a) * 0.25
                    continue
                }

                let vibrancy = Double(s) * (0.4 + 0.6 * Double(b)) * Double(a)
                let sector = min(17, max(0, Int(Double(h) * 18.0)))
                buckets[sector].weight += vibrancy + 0.05
                buckets[sector].rSum += r * (vibrancy + 0.05)
                buckets[sector].gSum += g * (vibrancy + 0.05)
                buckets[sector].bSum += bl * (vibrancy + 0.05)
            }
        }

        if let best = buckets.max(by: { $0.weight < $1.weight }), best.weight > 0.2 {
            let avgColor = NSColor(
                srgbRed: best.rSum / best.weight,
                green: best.gSum / best.weight,
                blue: best.bSum / best.weight,
                alpha: 1.0
            )
            return normalizeForHeaderContrast(avgColor)
        }

        if fallbackWeight > 0 {
            let avg = NSColor(
                srgbRed: fallbackR / fallbackWeight,
                green: fallbackG / fallbackWeight,
                blue: fallbackB / fallbackWeight,
                alpha: 1.0
            )
            return normalizeForHeaderContrast(avg)
        }

        return nil
    }

    private func normalizeForHeaderContrast(_ color: NSColor) -> RGBColor {
        guard let srgb = color.usingColorSpace(.sRGB) else {
            return RGBColor(red: 0.24, green: 0.49, blue: 0.91)
        }
        var h: CGFloat = 0
        var s: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        srgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // Ensure white text has strong contrast against the header color
        let adjustedSaturation = s < 0.12 ? s : min(max(s, 0.50), 0.88)
        let adjustedBrightness = min(max(b, 0.30), 0.72)

        // Yellows/bright greens need slightly lower brightness for white text legibility
        let isBrightHue = (h > 0.10 && h < 0.38)
        let finalBrightness = isBrightHue ? min(adjustedBrightness, 0.60) : adjustedBrightness

        let tuned = NSColor(hue: h, saturation: adjustedSaturation, brightness: finalBrightness, alpha: 1.0)
            .usingColorSpace(.sRGB) ?? srgb
        return RGBColor(
            red: Double(tuned.redComponent),
            green: Double(tuned.greenComponent),
            blue: Double(tuned.blueComponent)
        )
    }
}
