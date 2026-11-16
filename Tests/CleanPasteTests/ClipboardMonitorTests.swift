import XCTest
import AppKit
@testable import CleanPasteCore

private final class MockPasteboard: PasteboardReadable {
    var strings: [NSPasteboard.PasteboardType: String] = [:]
    var datas: [NSPasteboard.PasteboardType: Data] = [:]
    var extraTypes: [NSPasteboard.PasteboardType] = []
    var urls: [URL] = []

    var pasteboardTypes: [NSPasteboard.PasteboardType] {
        Array(Set(Array(strings.keys) + Array(datas.keys) + extraTypes))
    }

    func string(forType dataType: NSPasteboard.PasteboardType) -> String? {
        strings[dataType]
    }

    func data(forType dataType: NSPasteboard.PasteboardType) -> Data? {
        datas[dataType]
    }

    func fileURLs() -> [URL] {
        urls
    }
}

@MainActor
final class ClipboardMonitorTests: XCTestCase {
    private var monitor: ClipboardMonitor!

    override func setUp() {
        super.setUp()
        monitor = ClipboardMonitor(initialChangeCount: 0)
    }

    func testExtractsLinkOverPlainText() {
        let pb = MockPasteboard()
        pb.strings[.string] = "https://developer.apple.com/documentation"
        let payload = monitor.extractPayload(from: pb, sourceBundleID: "com.apple.Safari", sourceAppName: "Safari")
        XCTAssertEqual(payload?.item.type, .link)
        XCTAssertEqual(payload?.item.urlString, "https://developer.apple.com/documentation")
    }

    func testExtractsColor() {
        let pb = MockPasteboard()
        pb.strings[.string] = "#3A86FF"
        let payload = monitor.extractPayload(from: pb, sourceBundleID: nil, sourceAppName: "Figma")
        XCTAssertEqual(payload?.item.type, .color)
        XCTAssertEqual(payload?.item.parsedColor?.hexString, "#3A86FF")
    }

    func testExtractsPlainAndRTFText() {
        let pb = MockPasteboard()
        let rtf = Data("{\\rtf1\\ansi Hello}".utf8)
        pb.strings[.string] = "Hello"
        pb.datas[.rtf] = rtf

        let payload = monitor.extractPayload(from: pb, sourceBundleID: nil, sourceAppName: "TextEdit")
        XCTAssertEqual(payload?.item.type, .text)
        XCTAssertEqual(payload?.item.textContent, "Hello")
        XCTAssertEqual(payload?.item.hasRTF, true)
        XCTAssertEqual(payload?.rtfData, rtf)
    }

    func testExtractsFileURL() throws {
        let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("cleanpaste-test-\(UUID().uuidString).txt")
        try "sample".write(to: tmpFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tmpFile) }

        let pb = MockPasteboard()
        pb.urls = [tmpFile]
        pb.strings[.string] = tmpFile.lastPathComponent

        let payload = monitor.extractPayload(from: pb, sourceBundleID: "com.apple.finder", sourceAppName: "Finder")
        XCTAssertEqual(payload?.item.type, .file)
        XCTAssertEqual(payload?.item.filePaths, [tmpFile.path])
    }

    func testExtractsImageData() {
        let img = NSImage(size: NSSize(width: 40, height: 40))
        img.lockFocus()
        NSColor.systemBlue.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: 40, height: 40)).fill()
        img.unlockFocus()

        let tiff = img.tiffRepresentation!
        let rep = NSBitmapImageRep(data: tiff)!
        let png = rep.representation(using: .png, properties: [:])!

        let pb = MockPasteboard()
        pb.datas[.png] = png
        let payload = monitor.extractPayload(from: pb, sourceBundleID: nil, sourceAppName: "Preview")
        XCTAssertEqual(payload?.item.type, .image)
        XCTAssertEqual(payload?.imageData, png)
    }

    func testIgnoresSensitiveConcealedContent() {
        let pb = MockPasteboard()
        pb.strings[.string] = "super-secret-password"
        pb.extraTypes = [NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")]

        let skipped = monitor.extractPayload(from: pb, sourceBundleID: nil, sourceAppName: "1Password", ignoreSensitive: true)
        XCTAssertNil(skipped)

        let allowed = monitor.extractPayload(from: pb, sourceBundleID: nil, sourceAppName: "1Password", ignoreSensitive: false)
        XCTAssertNotNil(allowed)
    }
}
