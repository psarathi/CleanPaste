#!/usr/bin/env swift
import AppKit

func drawIcon(size: Int) -> Data? {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: size * 4,
        bitsPerPixel: 32
    ) else { return nil }
    rep.size = NSSize(width: size, height: size)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    let s = CGFloat(size)
    let inset = s * 0.08
    let squircleRect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = s * 0.21
    let squircle = NSBezierPath(roundedRect: squircleRect, xRadius: radius, yRadius: radius)

    // Drop shadow behind icon tile
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.02)
    shadow.shadowBlurRadius = s * 0.04
    shadow.set()
    NSColor.black.setFill()
    squircle.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Gradient background (sleek vibrant sapphire -> indigo)
    NSGraphicsContext.saveGraphicsState()
    squircle.addClip()
    let bgGradient = NSGradient(colors: [
        NSColor(srgbRed: 0.14, green: 0.56, blue: 0.98, alpha: 1.0),
        NSColor(srgbRed: 0.25, green: 0.31, blue: 0.90, alpha: 1.0)
    ])!
    bgGradient.draw(in: squircleRect, angle: -65)
    NSGraphicsContext.restoreGraphicsState()

    // Back tilted card
    NSGraphicsContext.saveGraphicsState()
    let backTransform = NSAffineTransform()
    backTransform.translateX(by: s * 0.50, yBy: s * 0.50)
    backTransform.rotate(byDegrees: 10)
    backTransform.translateX(by: -s * 0.50, yBy: -s * 0.50)
    backTransform.concat()

    let backCardRect = NSRect(x: s * 0.28, y: s * 0.24, width: s * 0.48, height: s * 0.52)
    let backCard = NSBezierPath(roundedRect: backCardRect, xRadius: s * 0.065, yRadius: s * 0.065)
    NSColor.white.withAlphaComponent(0.32).setFill()
    backCard.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Front floating card
    NSGraphicsContext.saveGraphicsState()
    let frontTransform = NSAffineTransform()
    frontTransform.translateX(by: s * 0.49, yBy: s * 0.50)
    frontTransform.rotate(byDegrees: -5)
    frontTransform.translateX(by: -s * 0.49, yBy: -s * 0.50)
    frontTransform.concat()

    let frontRect = NSRect(x: s * 0.25, y: s * 0.24, width: s * 0.49, height: s * 0.53)
    let frontPath = NSBezierPath(roundedRect: frontRect, xRadius: s * 0.068, yRadius: s * 0.068)

    let cardShadow = NSShadow()
    cardShadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    cardShadow.shadowOffset = NSSize(width: 0, height: -s * 0.015)
    cardShadow.shadowBlurRadius = s * 0.035
    cardShadow.set()

    NSColor.white.withAlphaComponent(0.96).setFill()
    frontPath.fill()

    // Colored header band on the front card
    NSGraphicsContext.saveGraphicsState()
    frontPath.addClip()
    let headerRect = NSRect(x: frontRect.minX, y: frontRect.maxY - s * 0.135, width: frontRect.width, height: s * 0.135)
    NSColor(srgbRed: 0.13, green: 0.72, blue: 0.62, alpha: 1.0).setFill()
    NSBezierPath(rect: headerRect).fill()

    // Subtle text line bars inside front card
    let lineColor = NSColor(srgbRed: 0.76, green: 0.80, blue: 0.88, alpha: 1.0)
    lineColor.setFill()
    let lineH = s * 0.032
    let lineX = frontRect.minX + s * 0.065
    NSBezierPath(roundedRect: NSRect(x: lineX, y: frontRect.minY + s * 0.27, width: s * 0.34, height: lineH), xRadius: lineH / 2, yRadius: lineH / 2).fill()
    NSBezierPath(roundedRect: NSRect(x: lineX, y: frontRect.minY + s * 0.19, width: s * 0.27, height: lineH), xRadius: lineH / 2, yRadius: lineH / 2).fill()
    NSBezierPath(roundedRect: NSRect(x: lineX, y: frontRect.minY + s * 0.11, width: s * 0.20, height: lineH), xRadius: lineH / 2, yRadius: lineH / 2).fill()

    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

func appendUInt32BE(_ data: inout Data, _ value: UInt32) {
    var be = value.bigEndian
    withUnsafeBytes(of: &be) { data.append(contentsOf: $0) }
}

let args = CommandLine.arguments
let outPath = args.count > 1 ? args[1] : "AppIcon.icns"

let chunks: [(String, Int)] = [
    ("icp4", 16),
    ("ic11", 32),
    ("icp5", 32),
    ("ic12", 64),
    ("icp6", 64),
    ("ic07", 128),
    ("ic13", 256),
    ("ic08", 256),
    ("ic14", 512),
    ("ic09", 512),
    ("ic10", 1024)
]

var renderedBySize: [Int: Data] = [:]
var body = Data()

for (tag, px) in chunks {
    let pngData = renderedBySize[px] ?? drawIcon(size: px)!
    renderedBySize[px] = pngData

    body.append(contentsOf: tag.utf8)
    appendUInt32BE(&body, UInt32(8 + pngData.count))
    body.append(pngData)
}

var icns = Data()
icns.append(contentsOf: "icns".utf8)
appendUInt32BE(&icns, UInt32(8 + body.count))
icns.append(body)

let outURL = URL(fileURLWithPath: outPath)
try FileManager.default.createDirectory(at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
try icns.write(to: outURL, options: [.atomic])
print("Generated \(outURL.path) (\(icns.count) bytes)")
