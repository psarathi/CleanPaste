import XCTest
import AppKit
@testable import CleanPasteCore

private final class Phase2MockPasteboard: PasteboardReadable {
    var strings: [NSPasteboard.PasteboardType: String] = [:]
    var pasteboardTypes: [NSPasteboard.PasteboardType] { Array(strings.keys) }
    func string(forType dataType: NSPasteboard.PasteboardType) -> String? { strings[dataType] }
    func data(forType dataType: NSPasteboard.PasteboardType) -> Data? { nil }
    func fileURLs() -> [URL] { [] }
}

final class Phase2ServicesTests: XCTestCase {
    func testTextCaseAndLineTransforms() {
        XCTAssertEqual(TextTransformService.apply(.uppercase, to: "Hello"), "HELLO")
        XCTAssertEqual(TextTransformService.apply(.lowercase, to: "Hello"), "hello")
        XCTAssertEqual(TextTransformService.apply(.camelCase, to: "hello_world-foo bar"), "helloWorldFooBar")
        XCTAssertEqual(TextTransformService.apply(.snakeCase, to: "helloWorldFoo"), "hello_world_foo")
        XCTAssertEqual(TextTransformService.apply(.trimWhitespace, to: "  hi \n "), "hi")
        XCTAssertEqual(TextTransformService.apply(.joinLines, to: "one\n  two \n\n three"), "one two three")
    }

    func testJSONAndBase64Transforms() {
        let rawJSON = "{\"b\":2,\"a\":1}"
        XCTAssertTrue(TextTransformService.isValidJSON(rawJSON))
        let pretty = TextTransformService.apply(.prettyJSON, to: rawJSON)
        XCTAssertNotNil(pretty)
        XCTAssertTrue(pretty?.contains("\n") == true)
        XCTAssertEqual(TextTransformService.apply(.minifyJSON, to: pretty ?? ""), "{\"a\":1,\"b\":2}")

        XCTAssertFalse(TextTransformService.isValidJSON("not json"))
        XCTAssertNil(TextTransformService.apply(.prettyJSON, to: "not json"))

        let encoded = TextTransformService.apply(.base64Encode, to: "CleanPaste")
        XCTAssertEqual(encoded, "Q2xlYW5QYXN0ZQ==")
        XCTAssertEqual(TextTransformService.apply(.base64Decode, to: encoded ?? ""), "CleanPaste")
        XCTAssertNil(TextTransformService.apply(.base64Decode, to: "!!!"))
    }

    func testStripTrackingParamsFromURL() {
        let dirty = "https://example.com/post?utm_source=x&q=swift&fbclid=12345&page=2"
        XCTAssertEqual(
            TextTransformService.apply(.stripTrackingParams, to: dirty),
            "https://example.com/post?q=swift&page=2"
        )

        let onlyTracking = "https://example.com/post?utm_campaign=launch&gclid=abc"
        XCTAssertEqual(
            TextTransformService.apply(.stripTrackingParams, to: onlyTracking),
            "https://example.com/post"
        )
    }

    func testSecretDetectorRules() {
        let fakeGitHub = "ghp_" + String(repeating: "a", count: 24)
        let fakeAWS = "AKIA" + String(repeating: "1", count: 16)
        let fakeJWT = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.abcDEF123456"
        let fakePEM = "-----BEGIN RSA PRIVATE KEY-----\nabc\n-----END RSA PRIVATE KEY-----"

        XCTAssertEqual(SecretDetector.detectSecretKind(in: fakeGitHub), "GitHub Token")
        XCTAssertEqual(SecretDetector.detectSecretKind(in: fakeAWS), "AWS Access Key")
        XCTAssertEqual(SecretDetector.detectSecretKind(in: fakeJWT), "JWT Token")
        XCTAssertEqual(SecretDetector.detectSecretKind(in: fakePEM), "Private Key")
        XCTAssertNil(SecretDetector.detectSecretKind(in: "let greeting = \"hello world\""))
    }

    @MainActor
    func testClipboardMonitorSecretHandlingModes() {
        let monitor = ClipboardMonitor(initialChangeCount: 0)
        let pb = Phase2MockPasteboard()
        pb.strings[.string] = "ghp_" + String(repeating: "Z", count: 24)

        let masked = monitor.extractPayload(from: pb, sourceBundleID: nil, sourceAppName: "Terminal", secretHandling: .maskPreview)
        XCTAssertEqual(masked?.item.isSensitiveSecret, true)
        XCTAssertEqual(masked?.item.secretKind, "GitHub Token")

        let skipped = monitor.extractPayload(from: pb, sourceBundleID: nil, sourceAppName: "Terminal", secretHandling: .skipCapture)
        XCTAssertNil(skipped)

        let off = monitor.extractPayload(from: pb, sourceBundleID: nil, sourceAppName: "Terminal", secretHandling: .off)
        XCTAssertEqual(off?.item.isSensitiveSecret, false)
        XCTAssertNil(off?.item.secretKind)
    }

    @MainActor
    func testDynamicSnippetExpansionOnlyForPinnedItems() {
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)
        let tz = TimeZone(secondsFromGMT: 0)!
        let expanded = SnippetExpander.expand(
            "Date={{date}} Time={{time}} DT={{datetime}} ID={{uuid}} Clip={{clipboard}}",
            now: fixedDate,
            timeZone: tz,
            uuidProvider: { "UUID-123" },
            clipboardProvider: { "hello" }
        )
        XCTAssertEqual(expanded, "Date=2023-11-14 Time=22:13 DT=2023-11-14 22:13 ID=UUID-123 Clip=hello")

        let unpinned = ClipItem(type: .text, textContent: "Today is {{date}}\n", contentHash: "h1", pinboardIDs: [])
        let pinned = ClipItem(type: .text, textContent: "Today is {{date}}\n", contentHash: "h2", pinboardIDs: [UUID()])

        let unpinnedResult = PasteService.prepareTextForPaste(
            item: unpinned,
            rawText: unpinned.textContent!,
            expandDynamicSnippets: true,
            targetBundleID: "com.apple.Notes",
            terminalSafePaste: true,
            now: fixedDate
        )
        XCTAssertFalse(unpinnedResult.expandedSnippet)
        XCTAssertEqual(unpinnedResult.text, "Today is {{date}}\n")

        let pinnedResult = PasteService.prepareTextForPaste(
            item: pinned,
            rawText: pinned.textContent!,
            expandDynamicSnippets: true,
            targetBundleID: "com.apple.Terminal",
            terminalSafePaste: true,
            now: fixedDate
        )
        XCTAssertTrue(pinnedResult.expandedSnippet)
        XCTAssertTrue(pinnedResult.trimmedNewlines)
        XCTAssertFalse(pinnedResult.text.contains("{{date}}"))
        XCTAssertFalse(pinnedResult.text.hasSuffix("\n"))
    }

    func testLegacyClipItemAndSettingsDecodePhase2Defaults() throws {
        let legacyClipJSON = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "type": "text",
          "timestamp": "2026-11-15T12:00:00Z",
          "textContent": "hello",
          "contentHash": "abc"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let item = try decoder.decode(ClipItem.self, from: Data(legacyClipJSON.utf8))
        XCTAssertFalse(item.isSensitiveSecret)
        XCTAssertNil(item.secretKind)
        XCTAssertTrue(item.isInHistory)
        XCTAssertEqual(item.pinboardIDs, [])

        let settings = try JSONDecoder().decode(AppSettings.self, from: Data("{}".utf8))
        XCTAssertEqual(settings.secretHandling, .maskPreview)
        XCTAssertTrue(settings.expandDynamicSnippets)
    }
}
