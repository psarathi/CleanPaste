import XCTest
@testable import CleanPasteCore

@MainActor
final class AppStateTests: XCTestCase {
    private var tempDir: URL!
    private var storage: StorageManager!
    private var monitor: ClipboardMonitor!
    private var appState: AppState!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("CleanPasteTests-\(UUID().uuidString)", isDirectory: true)
        storage = StorageManager(baseDirectory: tempDir)
        monitor = ClipboardMonitor(initialChangeCount: 0)
        appState = AppState(storage: storage, monitor: monitor, startBackgroundServices: false)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func makeTextPayload(_ text: String, appName: String = "Notes") -> CapturedPayload {
        let hash = monitor.sha256Hex(Data(("text:" + text).utf8))
        let item = ClipItem(
            type: .text,
            textContent: text,
            byteSize: Int64(text.utf8.count),
            contentHash: hash,
            sourceAppName: appName
        )
        return CapturedPayload(item: item, imageData: nil, rtfData: nil, htmlData: nil)
    }

    func testDeduplicationMovesItemToTopAndPreservesPinboards() {
        appState.ingestPayload(makeTextPayload("First"))
        appState.ingestPayload(makeTextPayload("Second"))

        let firstID = appState.items.last!.id
        let boardID = appState.pinboards.first!.id
        appState.pinItem(firstID, to: boardID)
        appState.renameItem(firstID, customTitle: "Greeting")

        // Copy "First" again
        appState.ingestPayload(makeTextPayload("First"))

        XCTAssertEqual(appState.items.count, 2)
        XCTAssertEqual(appState.items.first?.id, firstID)
        XCTAssertEqual(appState.items.first?.customTitle, "Greeting")
        XCTAssertEqual(appState.items.first?.pinboardIDs, [boardID])
    }

    func testClearHistoryPreservesPinnedItems() {
        appState.ingestPayload(makeTextPayload("Ephemeral"))
        appState.ingestPayload(makeTextPayload("Permanent"))

        let permanentID = appState.items.first!.id
        let boardID = appState.pinboards.first!.id
        appState.pinItem(permanentID, to: boardID)

        appState.clearHistory()

        XCTAssertEqual(appState.items.count, 1)
        XCTAssertEqual(appState.items.first?.id, permanentID)
        XCTAssertFalse(appState.items.first!.isInHistory)
        XCTAssertEqual(appState.visibleItems.count, 0) // History tab is empty

        appState.selectedTab = .pinboard(boardID)
        XCTAssertEqual(appState.visibleItems.count, 1)
    }

    func testSearchAndTypeFilter() {
        appState.ingestPayload(makeTextPayload("let x = 42", appName: "Xcode"))

        let linkItem = ClipItem(
            type: .link,
            textContent: "https://swift.org",
            urlString: "https://swift.org",
            linkTitle: "Swift.org",
            contentHash: "hash-link",
            sourceAppName: "Safari"
        )
        appState.ingestPayload(CapturedPayload(item: linkItem, imageData: nil, rtfData: nil, htmlData: nil))

        let colorItem = ClipItem(
            type: .color,
            textContent: "#FF5733",
            parsedColor: ColorParser.parse("#FF5733"),
            contentHash: "hash-color",
            sourceAppName: "Figma"
        )
        appState.ingestPayload(CapturedPayload(item: colorItem, imageData: nil, rtfData: nil, htmlData: nil))

        XCTAssertEqual(appState.visibleItems.count, 3)

        appState.activeFilter = .links
        XCTAssertEqual(appState.visibleItems.map(\.type), [.link])

        appState.activeFilter = .all
        appState.searchQuery = "Figma"
        XCTAssertEqual(appState.visibleItems.map(\.type), [.color])

        appState.searchQuery = "let x"
        XCTAssertEqual(appState.visibleItems.map(\.type), [.text])
    }

    func testPasteStackFIFOAndLIFOOrdering() {
        appState.updateSettings { $0.pasteStackOrder = .fifo }
        appState.isPasteStackActive = true

        appState.ingestPayload(makeTextPayload("One"))
        appState.ingestPayload(makeTextPayload("Two"))
        appState.ingestPayload(makeTextPayload("Three"))

        XCTAssertEqual(appState.pasteStackItems.map(\.textContent), ["One", "Two", "Three"])

        appState.clearPasteStack()
        appState.updateSettings { $0.pasteStackOrder = .lifo }
        appState.ingestPayload(makeTextPayload("A"))
        appState.ingestPayload(makeTextPayload("B"))

        XCTAssertEqual(appState.pasteStackItems.map(\.textContent), ["B", "A"])
    }

    func testDeleteAndUndoRestoresClip() {
        appState.ingestPayload(makeTextPayload("Alpha"))
        appState.ingestPayload(makeTextPayload("Beta"))
        let betaID = appState.items.first!.id

        appState.deleteItem(betaID)
        XCTAssertEqual(appState.items.count, 1)
        XCTAssertEqual(appState.items.first?.textContent, "Alpha")

        appState.undoLastDelete()
        XCTAssertEqual(appState.items.count, 2)
        XCTAssertEqual(appState.items.first?.textContent, "Beta")
    }

    func testRetentionPolicyPrunesExpiredHistoryButNotPinned() {
        let oldDate = Date().addingTimeInterval(-86_400 * 10)
        let expired = ClipItem(
            type: .text,
            timestamp: oldDate,
            textContent: "Old History",
            contentHash: "old-1",
            isInHistory: true
        )
        let boardID = appState.pinboards.first!.id
        let expiredPinned = ClipItem(
            type: .text,
            timestamp: oldDate,
            textContent: "Old Pinned",
            contentHash: "old-2",
            isInHistory: true,
            pinboardIDs: [boardID]
        )
        appState.items = [expired, expiredPinned]

        appState.updateSettings { $0.retentionPolicy = .week }

        XCTAssertEqual(appState.items.count, 1)
        XCTAssertEqual(appState.items.first?.textContent, "Old Pinned")
        XCTAssertFalse(appState.items.first!.isInHistory)
    }

    func testLegacySettingsDecodesWithPasteBoardMenuBarIconDefault() throws {
        let legacyJSON = """
        {
          "directPaste": false,
          "soundEffectsEnabled": false
        }
        """
        let decoded = try JSONDecoder().decode(AppSettings.self, from: Data(legacyJSON.utf8))
        XCTAssertFalse(decoded.directPaste)
        XCTAssertFalse(decoded.soundEffectsEnabled)
        XCTAssertEqual(decoded.menuBarIconStyle, .pasteboard)
        XCTAssertFalse(decoded.singleClickToPaste)
        XCTAssertTrue(decoded.terminalSafePaste)
    }

    func testTerminalSafePasteTrimsTrailingNewlinesOnlyForTerminals() {
        let term = PasteService.sanitizedTextForTarget(
            "ls -la\n\r\n",
            targetBundleID: "com.apple.Terminal",
            terminalSafePaste: true
        )
        XCTAssertEqual(term.text, "ls -la")
        XCTAssertTrue(term.trimmedNewlines)

        let iterm = PasteService.sanitizedTextForTarget(
            "echo 1\necho 2\n",
            targetBundleID: "com.googlecode.iterm2",
            terminalSafePaste: true
        )
        XCTAssertEqual(iterm.text, "echo 1\necho 2")
        XCTAssertTrue(iterm.trimmedNewlines)

        let notes = PasteService.sanitizedTextForTarget(
            "ls -la\n",
            targetBundleID: "com.apple.Notes",
            terminalSafePaste: true
        )
        XCTAssertEqual(notes.text, "ls -la\n")
        XCTAssertFalse(notes.trimmedNewlines)

        let disabled = PasteService.sanitizedTextForTarget(
            "ls -la\n",
            targetBundleID: "com.apple.Terminal",
            terminalSafePaste: false
        )
        XCTAssertEqual(disabled.text, "ls -la\n")
        XCTAssertFalse(disabled.trimmedNewlines)
    }

    func testTimedPauseSetsAndAutoResumes() {
        appState.pause(for: 0.08)
        XCTAssertTrue(appState.isPaused)
        XCTAssertNotNil(appState.pauseUntil)

        let deadline = Date().addingTimeInterval(6.0)
        while appState.isPaused && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        XCTAssertFalse(appState.isPaused)
        XCTAssertNil(appState.pauseUntil)

        appState.pause(for: 60)
        XCTAssertTrue(appState.isPaused)
        XCTAssertNotNil(appState.pauseUntil)
        appState.resumeRecording()
        XCTAssertFalse(appState.isPaused)
        XCTAssertNil(appState.pauseUntil)
    }
}
