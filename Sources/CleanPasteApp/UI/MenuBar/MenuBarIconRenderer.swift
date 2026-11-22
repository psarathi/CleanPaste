import AppKit
import CleanPasteCore

@MainActor
enum MenuBarIconRenderer {
    static func image(for style: MenuBarIconStyle, size: CGFloat = 18) -> NSImage {
        switch style {
        case .pasteboard:
            return loadPasteBoardIcon(size: size)
        case .coralCards:
            return drawCoralCards(size: size)
        case .spectrumCards:
            return drawSpectrumFan(size: size)
        case .sapphireMini:
            return drawSapphireMini(size: size)
        case .tealClipboard:
            return drawTealClipboard(size: size)
        case .indigoCyan:
            return drawIndigoCyanCards(size: size)
        case .monochrome:
            return drawMonochromeTemplate(size: size)
        }
    }

    private static func loadPasteBoardIcon(size: CGFloat) -> NSImage {
        if let mainImg = Bundle.main.image(forResource: "MenuBarIcon") {
            let copy = mainImg.copy() as? NSImage ?? mainImg
            copy.size = NSSize(width: size, height: size)
            copy.isTemplate = false
            return copy
        }
        // Fallback matching PasteBoard's pink-purple clipboard gradient
        return drawClipboard(
            size: size,
            topColor: NSColor(srgbRed: 0.96, green: 0.49, blue: 0.72, alpha: 1.0),
            bottomColor: NSColor(srgbRed: 0.67, green: 0.45, blue: 0.95, alpha: 1.0),
            clipColor: NSColor(srgbRed: 0.19, green: 0.22, blue: 0.29, alpha: 1.0)
        )
    }

    private static func drawCoralCards(size: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width
            let tile = NSBezierPath(
                roundedRect: rect.insetBy(dx: s * 0.06, dy: s * 0.06),
                xRadius: s * 0.24,
                yRadius: s * 0.24
            )
            let gradient = NSGradient(colors: [
                NSColor(srgbRed: 1.00, green: 0.44, blue: 0.20, alpha: 1.0),
                NSColor(srgbRed: 0.98, green: 0.26, blue: 0.34, alpha: 1.0)
            ])!
            gradient.draw(in: tile, angle: -55)

            // Back tilted card
            NSGraphicsContext.saveGraphicsState()
            let t1 = NSAffineTransform()
            t1.translateX(by: s * 0.50, yBy: s * 0.50)
            t1.rotate(byDegrees: 10)
            t1.translateX(by: -s * 0.50, yBy: -s * 0.50)
            t1.concat()
            let back = NSBezierPath(
                roundedRect: NSRect(x: s * 0.28, y: s * 0.23, width: s * 0.46, height: s * 0.52),
                xRadius: s * 0.08,
                yRadius: s * 0.08
            )
            NSColor.white.withAlphaComponent(0.38).setFill()
            back.fill()
            NSGraphicsContext.restoreGraphicsState()

            // Front card
            NSGraphicsContext.saveGraphicsState()
            let t2 = NSAffineTransform()
            t2.translateX(by: s * 0.48, yBy: s * 0.50)
            t2.rotate(byDegrees: -6)
            t2.translateX(by: -s * 0.48, yBy: -s * 0.50)
            t2.concat()
            let front = NSBezierPath(
                roundedRect: NSRect(x: s * 0.25, y: s * 0.22, width: s * 0.46, height: s * 0.52),
                xRadius: s * 0.08,
                yRadius: s * 0.08
            )
            NSColor.white.withAlphaComponent(0.96).setFill()
            front.fill()
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        img.isTemplate = false
        return img
    }

    private static func drawSpectrumFan(size: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width
            let cards: [(angle: CGFloat, dx: CGFloat, dy: CGFloat, color: NSColor)] = [
                (15, s * 0.10, 0, NSColor(srgbRed: 0.95, green: 0.29, blue: 0.30, alpha: 1.0)),
                (0, 0, s * 0.02, NSColor(srgbRed: 0.19, green: 0.74, blue: 0.40, alpha: 1.0)),
                (-14, -s * 0.10, -s * 0.01, NSColor(srgbRed: 0.16, green: 0.50, blue: 0.98, alpha: 1.0))
            ]

            for item in cards {
                NSGraphicsContext.saveGraphicsState()
                let t = NSAffineTransform()
                t.translateX(by: s * 0.50 + item.dx, yBy: s * 0.48 + item.dy)
                t.rotate(byDegrees: item.angle)
                t.translateX(by: -(s * 0.50 + item.dx), yBy: -(s * 0.48 + item.dy))
                t.concat()

                let cardRect = NSRect(
                    x: s * 0.29 + item.dx,
                    y: s * 0.18 + item.dy,
                    width: s * 0.42,
                    height: s * 0.60
                )
                let path = NSBezierPath(roundedRect: cardRect, xRadius: s * 0.09, yRadius: s * 0.09)
                item.color.setFill()
                path.fill()
                NSColor.white.withAlphaComponent(0.45).setStroke()
                path.lineWidth = max(0.8, s * 0.035)
                path.stroke()
                NSGraphicsContext.restoreGraphicsState()
            }
            return true
        }
        img.isTemplate = false
        return img
    }

    private static func drawSapphireMini(size: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width
            let tile = NSBezierPath(
                roundedRect: rect.insetBy(dx: s * 0.06, dy: s * 0.06),
                xRadius: s * 0.24,
                yRadius: s * 0.24
            )
            let bg = NSGradient(colors: [
                NSColor(srgbRed: 0.14, green: 0.56, blue: 0.98, alpha: 1.0),
                NSColor(srgbRed: 0.25, green: 0.31, blue: 0.90, alpha: 1.0)
            ])!
            bg.draw(in: tile, angle: -65)

            NSGraphicsContext.saveGraphicsState()
            let t = NSAffineTransform()
            t.translateX(by: s * 0.50, yBy: s * 0.50)
            t.rotate(byDegrees: -6)
            t.translateX(by: -s * 0.50, yBy: -s * 0.50)
            t.concat()

            let cardRect = NSRect(x: s * 0.24, y: s * 0.22, width: s * 0.52, height: s * 0.56)
            let card = NSBezierPath(roundedRect: cardRect, xRadius: s * 0.09, yRadius: s * 0.09)
            NSColor.white.setFill()
            card.fill()

            card.addClip()
            NSColor(srgbRed: 0.13, green: 0.72, blue: 0.62, alpha: 1.0).setFill()
            NSBezierPath(rect: NSRect(
                x: cardRect.minX,
                y: cardRect.maxY - s * 0.16,
                width: cardRect.width,
                height: s * 0.16
            )).fill()
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        img.isTemplate = false
        return img
    }

    private static func drawTealClipboard(size: CGFloat) -> NSImage {
        drawClipboard(
            size: size,
            topColor: NSColor(srgbRed: 0.13, green: 0.78, blue: 0.70, alpha: 1.0),
            bottomColor: NSColor(srgbRed: 0.05, green: 0.58, blue: 0.65, alpha: 1.0),
            clipColor: NSColor(srgbRed: 0.96, green: 0.63, blue: 0.14, alpha: 1.0)
        )
    }

    private static func drawClipboard(
        size: CGFloat,
        topColor: NSColor,
        bottomColor: NSColor,
        clipColor: NSColor
    ) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width
            let bodyRect = NSRect(x: s * 0.14, y: s * 0.08, width: s * 0.72, height: s * 0.80)
            let body = NSBezierPath(roundedRect: bodyRect, xRadius: s * 0.16, yRadius: s * 0.16)
            NSGradient(colors: [topColor, bottomColor])!.draw(in: body, angle: -90)

            let clipRect = NSRect(x: s * 0.34, y: s * 0.80, width: s * 0.32, height: s * 0.14)
            let clip = NSBezierPath(roundedRect: clipRect, xRadius: s * 0.05, yRadius: s * 0.05)
            clipColor.setFill()
            clip.fill()

            NSColor.white.withAlphaComponent(0.92).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: s * 0.27, y: s * 0.44, width: s * 0.46, height: s * 0.10),
                xRadius: s * 0.05,
                yRadius: s * 0.05
            ).fill()
            NSBezierPath(
                roundedRect: NSRect(x: s * 0.27, y: s * 0.27, width: s * 0.31, height: s * 0.10),
                xRadius: s * 0.05,
                yRadius: s * 0.05
            ).fill()
            return true
        }
        img.isTemplate = false
        return img
    }

    private static func drawIndigoCyanCards(size: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width
            // Back indigo card
            NSGraphicsContext.saveGraphicsState()
            let t1 = NSAffineTransform()
            t1.translateX(by: s * 0.56, yBy: s * 0.52)
            t1.rotate(byDegrees: 10)
            t1.translateX(by: -s * 0.56, yBy: -s * 0.52)
            t1.concat()
            let back = NSBezierPath(
                roundedRect: NSRect(x: s * 0.28, y: s * 0.18, width: s * 0.52, height: s * 0.64),
                xRadius: s * 0.11,
                yRadius: s * 0.11
            )
            NSColor(srgbRed: 0.39, green: 0.40, blue: 0.95, alpha: 1.0).setFill()
            back.fill()
            NSGraphicsContext.restoreGraphicsState()

            // Front cyan card
            NSGraphicsContext.saveGraphicsState()
            let t2 = NSAffineTransform()
            t2.translateX(by: s * 0.42, yBy: s * 0.46)
            t2.rotate(byDegrees: -8)
            t2.translateX(by: -s * 0.42, yBy: -s * 0.46)
            t2.concat()
            let front = NSBezierPath(
                roundedRect: NSRect(x: s * 0.18, y: s * 0.14, width: s * 0.54, height: s * 0.66),
                xRadius: s * 0.11,
                yRadius: s * 0.11
            )
            NSColor(srgbRed: 0.06, green: 0.72, blue: 0.84, alpha: 1.0).setFill()
            front.fill()

            NSColor.white.withAlphaComponent(0.9).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: s * 0.26, y: s * 0.50, width: s * 0.36, height: s * 0.08),
                xRadius: s * 0.04,
                yRadius: s * 0.04
            ).fill()
            NSBezierPath(
                roundedRect: NSRect(x: s * 0.26, y: s * 0.36, width: s * 0.26, height: s * 0.08),
                xRadius: s * 0.04,
                yRadius: s * 0.04
            ).fill()
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        img.isTemplate = false
        return img
    }

    private static func drawMonochromeTemplate(size: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let s = rect.width
            NSColor.black.setStroke()
            NSColor.black.setFill()

            // Back tilted card outline
            NSGraphicsContext.saveGraphicsState()
            let t1 = NSAffineTransform()
            t1.translateX(by: s * 0.56, yBy: s * 0.54)
            t1.rotate(byDegrees: 11)
            t1.translateX(by: -s * 0.56, yBy: -s * 0.54)
            t1.concat()
            let back = NSBezierPath(
                roundedRect: NSRect(x: s * 0.30, y: s * 0.20, width: s * 0.48, height: s * 0.62),
                xRadius: s * 0.10,
                yRadius: s * 0.10
            )
            back.lineWidth = max(1.2, s * 0.075)
            NSColor.black.withAlphaComponent(0.55).setStroke()
            back.stroke()
            NSGraphicsContext.restoreGraphicsState()

            // Front card solid with cutout lines
            NSGraphicsContext.saveGraphicsState()
            let t2 = NSAffineTransform()
            t2.translateX(by: s * 0.42, yBy: s * 0.46)
            t2.rotate(byDegrees: -7)
            t2.translateX(by: -s * 0.42, yBy: -s * 0.46)
            t2.concat()
            let front = NSBezierPath(
                roundedRect: NSRect(x: s * 0.18, y: s * 0.14, width: s * 0.52, height: s * 0.64),
                xRadius: s * 0.10,
                yRadius: s * 0.10
            )
            NSColor.black.setFill()
            front.fill()

            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(
                roundedRect: NSRect(x: s * 0.26, y: s * 0.50, width: s * 0.34, height: s * 0.08),
                xRadius: s * 0.04,
                yRadius: s * 0.04
            ).fill()
            NSBezierPath(
                roundedRect: NSRect(x: s * 0.26, y: s * 0.35, width: s * 0.24, height: s * 0.08),
                xRadius: s * 0.04,
                yRadius: s * 0.04
            ).fill()
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        img.isTemplate = true
        return img
    }
}
