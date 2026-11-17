import XCTest
import AppKit
@testable import CleanPasteCore

final class Phase3ServicesTests: XCTestCase {
    func testImageOCRRecognizesRenderedText() throws {
        let width = 640
        let height = 180
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ) else {
            XCTFail("Could not allocate bitmap")
            return
        }

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.white.setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: NSColor.black
        ]
        ("HELLO OCR 2026" as NSString).draw(at: NSPoint(x: 40, y: 60), withAttributes: attrs)
        NSGraphicsContext.restoreGraphicsState()

        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        let recognized = ImageOCRService.recognizeTextSync(from: png)
        XCTAssertNotNil(recognized)
        XCTAssertTrue(recognized?.localizedCaseInsensitiveContains("HELLO") == true)
        XCTAssertTrue(recognized?.localizedCaseInsensitiveContains("2026") == true)
    }

    func testClipItemMatchesOCRTextAndDecodesLegacyJSON() throws {
        let imgItem = ClipItem(
            type: .image,
            contentHash: "img-ocr",
            ocrText: "Invoice Total $420.00"
        )
        XCTAssertTrue(imgItem.hasOCRText)
        XCTAssertTrue(imgItem.matchesSearch("invoice"))
        XCTAssertTrue(imgItem.matchesSearch("420"))
        XCTAssertFalse(imgItem.matchesSearch("unrelated"))

        let legacyJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000002",
          "type": "image",
          "timestamp": "2026-11-15T12:00:00Z",
          "contentHash": "abc"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ClipItem.self, from: Data(legacyJSON.utf8))
        XCTAssertNil(decoded.ocrText)
        XCTAssertFalse(decoded.hasOCRText)
    }

    func testDateFilterMatching() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let sameDay = now.addingTimeInterval(-3600)
        let threeDaysAgo = now.addingTimeInterval(-3 * 86_400)
        let fifteenDaysAgo = now.addingTimeInterval(-15 * 86_400)
        let sixtyDaysAgo = now.addingTimeInterval(-60 * 86_400)

        XCTAssertTrue(DateFilter.today.matches(sameDay, relativeTo: now, calendar: cal))
        XCTAssertFalse(DateFilter.today.matches(threeDaysAgo, relativeTo: now, calendar: cal))

        XCTAssertTrue(DateFilter.last7Days.matches(threeDaysAgo, relativeTo: now, calendar: cal))
        XCTAssertFalse(DateFilter.last7Days.matches(fifteenDaysAgo, relativeTo: now, calendar: cal))

        XCTAssertTrue(DateFilter.last30Days.matches(fifteenDaysAgo, relativeTo: now, calendar: cal))
        XCTAssertFalse(DateFilter.last30Days.matches(sixtyDaysAgo, relativeTo: now, calendar: cal))

        XCTAssertTrue(DateFilter.anyTime.matches(sixtyDaysAgo, relativeTo: now, calendar: cal))
    }

    @MainActor
    func testAppStateSourceAppAndDateFiltering() {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanPastePhase3Tests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let storage = StorageManager(baseDirectory: tempDir)
        let monitor = ClipboardMonitor(initialChangeCount: 0)
        let appState = AppState(storage: storage, monitor: monitor, startBackgroundServices: false)

        let now = Date()
        let old = now.addingTimeInterval(-12 * 86_400)

        appState.items = [
            ClipItem(
                type: .text,
                timestamp: now,
                textContent: "Recent Xcode snippet",
                contentHash: "1",
                sourceAppBundleID: "com.apple.dt.Xcode",
                sourceAppName: "Xcode"
            ),
            ClipItem(
                type: .text,
                timestamp: old,
                textContent: "Older Safari quote",
                contentHash: "2",
                sourceAppBundleID: "com.apple.Safari",
                sourceAppName: "Safari"
            )
        ]

        XCTAssertEqual(appState.availableSourceApps.map(\.name), ["Safari", "Xcode"])
        XCTAssertEqual(appState.visibleItems.count, 2)

        appState.activeSourceAppBundleID = "com.apple.dt.Xcode"
        XCTAssertEqual(appState.visibleItems.map(\.textContent), ["Recent Xcode snippet"])

        appState.activeSourceAppBundleID = nil
        appState.activeDateFilter = .last7Days
        XCTAssertEqual(appState.visibleItems.map(\.textContent), ["Recent Xcode snippet"])

        appState.resetAllFilters()
        XCTAssertFalse(appState.hasActiveFilters)
        XCTAssertEqual(appState.visibleItems.count, 2)
    }
}
