import Foundation
import AppKit
import Combine

public enum BoardSelection: Equatable, Hashable {
    case history
    case pinboard(UUID)
}

public struct DeletedItemSnapshot {
    public let item: ClipItem
    public let index: Int
}

@MainActor
public final class AppState: ObservableObject {
    public static let shared = AppState()

    @Published public var items: [ClipItem] = []
    @Published public var pinboards: [Pinboard] = []
    @Published public var settings: AppSettings

    @Published public var selectedTab: BoardSelection = .history {
        didSet {
            ensureValidSelection()
        }
    }
    @Published public var searchQuery: String = "" {
        didSet {
            ensureValidSelection()
        }
    }
    @Published public var isSearchVisible: Bool = false
    @Published public var activeFilter: ClipFilter = .all {
        didSet {
            ensureValidSelection()
        }
    }
    @Published public var selectedItemID: UUID?
    @Published public var isShelfVisible: Bool = false
    @Published public var isPaused: Bool = false {
        didSet {
            monitor.isPaused = isPaused
        }
    }
    @Published public var isPasteStackActive: Bool = false {
        didSet {
            if backgroundServicesEnabled {
                HotkeyManager.shared.setMonitoringCommandV(isPasteStackActive && !pasteStackItemIDs.isEmpty)
            }
        }
    }
    @Published public var pasteStackItemIDs: [UUID] = [] {
        didSet {
            if backgroundServicesEnabled {
                HotkeyManager.shared.setMonitoringCommandV(isPasteStackActive && !pasteStackItemIDs.isEmpty)
            }
        }
    }
    @Published public var isQuickLookOpen: Bool = false
    @Published public var toastMessage: String?
    @Published public var accessibilityGranted: Bool = false

    public let storage: StorageManager
    public let monitor: ClipboardMonitor

    private let backgroundServicesEnabled: Bool
    private var undoStack: [DeletedItemSnapshot] = []
    private var toastWorkItem: DispatchWorkItem?
    private var suppressStackAdvanceUntil: Date = .distantPast

    /// Callbacks wired by ShelfWindowController / UI
    public var onRequestToggleShelf: (() -> Void)?
    public var onRequestDismissAndPaste: ((_ shouldSimulateCmdV: Bool) -> Void)?
    public var onRequestOpenQuickLook: (() -> Void)?
    public var onRequestCloseQuickLook: (() -> Void)?
    public var onRequestOpenEdit: ((ClipItem) -> Void)?
    public var onRequestOpenRename: ((ClipItem) -> Void)?
    public var onRequestOpenSettings: (() -> Void)?

    public init(
        storage: StorageManager = StorageManager(),
        monitor: ClipboardMonitor? = nil,
        startBackgroundServices: Bool = true
    ) {
        self.storage = storage
        self.monitor = monitor ?? ClipboardMonitor(initialChangeCount: startBackgroundServices ? nil : 0)
        self.backgroundServicesEnabled = startBackgroundServices

        let loaded = storage.load()
        self.items = loaded.items
        self.pinboards = loaded.pinboards
        self.settings = loaded.settings
        self.accessibilityGranted = startBackgroundServices ? PasteService.shared.isAccessibilityGranted() : false

        applyRetentionPolicy(saveAfter: false)
        ensureValidSelection()

        if startBackgroundServices {
            wireServices()
        }
    }

    private func wireServices() {
        monitor.onCapture = { [weak self] payload in
            self?.ingestPayload(payload)
        }
        monitor.start { [weak self] in
            self?.settings ?? AppSettings()
        }

        HotkeyManager.shared.onToggleShelf = { [weak self] in
            self?.onRequestToggleShelf?()
        }
        HotkeyManager.shared.onTogglePasteStack = { [weak self] in
            self?.togglePasteStack()
        }
        HotkeyManager.shared.onPasteNextFromStack = { [weak self] in
            self?.pasteNextFromStackTrigger()
        }
        HotkeyManager.shared.onExternalCommandVDetected = { [weak self] in
            self?.handleExternalCommandV()
        }
        HotkeyManager.shared.start(settings: settings)
    }

    public func refreshAccessibilityStatus() {
        accessibilityGranted = PasteService.shared.isAccessibilityGranted()
    }

    // MARK: - Filtering & Selection

    public var visibleItems: [ClipItem] {
        items.filter { item in
            switch selectedTab {
            case .history:
                guard item.isInHistory else { return false }
            case .pinboard(let id):
                guard item.pinboardIDs.contains(id) else { return false }
            }
            guard activeFilter.matches(item.type) else { return false }
            guard item.matchesSearch(searchQuery) else { return false }
            return true
        }
    }

    public var selectedItem: ClipItem? {
        if let selectedItemID, let match = visibleItems.first(where: { $0.id == selectedItemID }) {
            return match
        }
        return visibleItems.first
    }

    public var pasteStackItems: [ClipItem] {
        pasteStackItemIDs.compactMap { id in
            items.first(where: { $0.id == id })
        }
    }

    public func ensureValidSelection() {
        let visible = visibleItems
        if let selectedItemID, visible.contains(where: { $0.id == selectedItemID }) {
            return
        }
        selectedItemID = visible.first?.id
    }

    public func moveSelection(by delta: Int) {
        let visible = visibleItems
        guard !visible.isEmpty else {
            selectedItemID = nil
            return
        }
        guard let currentID = selectedItemID,
              let idx = visible.firstIndex(where: { $0.id == currentID }) else {
            selectedItemID = visible.first?.id
            return
        }
        let nextIndex = min(max(idx + delta, 0), visible.count - 1)
        selectedItemID = visible[nextIndex].id
    }

    public func selectTab(byDelta delta: Int) {
        let allTabs: [BoardSelection] = [.history] + pinboards.map { .pinboard($0.id) }
        guard !allTabs.isEmpty else { return }
        guard let currentIdx = allTabs.firstIndex(of: selectedTab) else {
            selectedTab = .history
            return
        }
        let nextIdx = (currentIdx + delta + allTabs.count) % allTabs.count
        selectedTab = allTabs[nextIdx]
    }

    // MARK: - Capture & Deduplication

    public func ingestPayload(_ payload: CapturedPayload) {
        var newItem = payload.item

        if settings.moveDuplicatesToTop,
           let existingIdx = items.firstIndex(where: { $0.contentHash == newItem.contentHash && $0.type == newItem.type }) {
            var existing = items.remove(at: existingIdx)
            existing.timestamp = Date()
            existing.isInHistory = true
            existing.sourceAppBundleID = newItem.sourceAppBundleID ?? existing.sourceAppBundleID
            existing.sourceAppName = newItem.sourceAppName ?? existing.sourceAppName
            if existing.headerColorRGB == nil {
                existing.headerColorRGB = newItem.headerColorRGB
            }
            items.insert(existing, at: 0)
            if selectedTab == .history {
                selectedItemID = existing.id
            }
            handlePostCapture(item: existing, isNew: false)
            return
        }

        // Persist blobs before inserting
        if let imageData = payload.imageData {
            let meta = storage.saveImageData(imageData, for: newItem.id)
            newItem.imageWidth = meta.width
            newItem.imageHeight = meta.height
            newItem.imageFormat = meta.format
        }
        if let rtfData = payload.rtfData {
            storage.saveRTFData(rtfData, for: newItem.id)
        }
        if let htmlData = payload.htmlData {
            storage.saveHTMLData(htmlData, for: newItem.id)
        }

        items.insert(newItem, at: 0)
        if selectedTab == .history {
            selectedItemID = newItem.id
        }

        // Async metadata enrichment
        if newItem.type == .link, let urlStr = newItem.urlString {
            let itemID = newItem.id
            LinkPreviewService.shared.fetchMetadata(for: urlStr, itemID: itemID, storage: storage) { [weak self] title, hasIcon, hasPreview in
                guard let self, let idx = self.items.firstIndex(where: { $0.id == itemID }) else { return }
                if let title, !title.isEmpty {
                    self.items[idx].linkTitle = title
                }
                self.items[idx].hasLinkIcon = hasIcon
                self.items[idx].hasLinkPreviewImage = hasPreview
                self.persist()
            }
        } else if newItem.type == .file, let firstPath = newItem.filePaths.first {
            let itemID = newItem.id
            LinkPreviewService.shared.generateFileThumbnail(for: firstPath, itemID: itemID, storage: storage) { [weak self] _ in
                self?.objectWillChange.send()
            }
        }

        applyRetentionPolicy(saveAfter: false)
        handlePostCapture(item: newItem, isNew: true)
    }

    private func handlePostCapture(item: ClipItem, isNew _: Bool) {
        if isPasteStackActive {
            switch settings.pasteStackOrder {
            case .fifo:
                pasteStackItemIDs.append(item.id)
            case .lifo:
                pasteStackItemIDs.insert(item.id, at: 0)
            }
            syncHeadOfStackToPasteboard()
            SoundManager.shared.play(.stackAdd, enabled: settings.soundEffectsEnabled)
        } else {
            SoundManager.shared.play(.capture, enabled: settings.soundEffectsEnabled)
        }
        persist()
    }

    // MARK: - Paste & Copy Actions

    public func pasteItem(_ item: ClipItem, plainTextOnly: Bool? = nil, pasteDirectly: Bool = true) {
        let stripFormatting = plainTextOnly ?? settings.pasteAsPlainTextByDefault
        PasteService.shared.writeToPasteboard(
            item: item,
            plainTextOnly: stripFormatting,
            storage: storage,
            monitor: monitor
        )
        SoundManager.shared.play(.paste, enabled: settings.soundEffectsEnabled)

        refreshAccessibilityStatus()
        let shouldCmdV = pasteDirectly && settings.directPaste && accessibilityGranted
        if !shouldCmdV {
            if pasteDirectly && settings.directPaste && !accessibilityGranted {
                showToast("Copied — Re-enable CleanPaste in Accessibility")
            } else {
                showToast(stripFormatting ? "Copied as Plain Text" : "Copied to Clipboard")
            }
        }
        onRequestDismissAndPaste?(shouldCmdV)
    }

    public func copyItem(_ item: ClipItem, plainTextOnly: Bool = false) {
        PasteService.shared.writeToPasteboard(
            item: item,
            plainTextOnly: plainTextOnly,
            storage: storage,
            monitor: monitor
        )
        SoundManager.shared.play(.paste, enabled: settings.soundEffectsEnabled)
        showToast(plainTextOnly ? "Copied as Plain Text" : "Copied to Clipboard")
    }

    public func copyCustomString(_ text: String, label: String) {
        PasteService.shared.writeCustomString(text, monitor: monitor)
        SoundManager.shared.play(.paste, enabled: settings.soundEffectsEnabled)
        showToast("Copied \(label)")
    }

    public func quickPaste(index: Int, plainTextOnly: Bool = false) {
        let visible = visibleItems
        guard index >= 0, index < visible.count else { return }
        pasteItem(visible[index], plainTextOnly: plainTextOnly, pasteDirectly: true)
    }

    // MARK: - Paste Stack

    public func togglePasteStack() {
        isPasteStackActive.toggle()
        if isPasteStackActive {
            SoundManager.shared.play(.stackAdd, enabled: settings.soundEffectsEnabled)
            showToast("Paste Stack Active — Copy items to queue")
        } else {
            pasteStackItemIDs.removeAll()
            showToast("Paste Stack Off")
        }
    }

    public func clearPasteStack() {
        pasteStackItemIDs.removeAll()
    }

    public func removeFromPasteStack(id: UUID) {
        let wasHead = pasteStackItemIDs.first == id
        pasteStackItemIDs.removeAll { $0 == id }
        if wasHead {
            syncHeadOfStackToPasteboard()
        }
    }

    public func enqueueIntoPasteStack(_ item: ClipItem) {
        if !isPasteStackActive {
            isPasteStackActive = true
        }
        switch settings.pasteStackOrder {
        case .fifo:
            pasteStackItemIDs.append(item.id)
        case .lifo:
            pasteStackItemIDs.insert(item.id, at: 0)
        }
        syncHeadOfStackToPasteboard()
        SoundManager.shared.play(.stackAdd, enabled: settings.soundEffectsEnabled)
        showToast("Added to Paste Stack")
    }

    public func syncHeadOfStackToPasteboard() {
        guard backgroundServicesEnabled else { return }
        guard let headID = pasteStackItemIDs.first,
              let headItem = items.first(where: { $0.id == headID }) else { return }
        PasteService.shared.writeToPasteboard(
            item: headItem,
            plainTextOnly: settings.pasteAsPlainTextByDefault,
            storage: storage,
            monitor: monitor
        )
    }

    private func handleExternalCommandV() {
        guard isPasteStackActive, !pasteStackItemIDs.isEmpty else { return }
        guard Date() >= suppressStackAdvanceUntil else { return }
        // Wait briefly so the foreground app completes reading the current pasteboard before we swap to the next item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.popAndLoadNextStackItem()
        }
    }

    public func pasteNextFromStackTrigger() {
        guard isPasteStackActive, let headID = pasteStackItemIDs.first,
              let headItem = items.first(where: { $0.id == headID }) else {
            return
        }
        PasteService.shared.writeToPasteboard(
            item: headItem,
            plainTextOnly: settings.pasteAsPlainTextByDefault,
            storage: storage,
            monitor: monitor
        )
        suppressStackAdvanceUntil = Date().addingTimeInterval(0.35)
        refreshAccessibilityStatus()
        if settings.directPaste && accessibilityGranted {
            PasteService.shared.simulateCommandV()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak self] in
                self?.popAndLoadNextStackItem()
            }
        } else {
            popAndLoadNextStackItem()
            showToast("Next stack item ready on Clipboard")
        }
    }

    private func popAndLoadNextStackItem() {
        guard !pasteStackItemIDs.isEmpty else { return }
        pasteStackItemIDs.removeFirst()
        if pasteStackItemIDs.isEmpty {
            SoundManager.shared.play(.stackDone, enabled: settings.soundEffectsEnabled)
            showToast("Paste Stack Complete")
        } else {
            syncHeadOfStackToPasteboard()
            SoundManager.shared.play(.paste, enabled: settings.soundEffectsEnabled)
        }
    }

    // MARK: - Item Mutations

    public func pinItem(_ itemID: UUID, to pinboardID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        if !items[idx].pinboardIDs.contains(pinboardID) {
            items[idx].pinboardIDs.append(pinboardID)
            persist()
            if let board = pinboards.first(where: { $0.id == pinboardID }) {
                showToast("Pinned to \(board.name)")
            }
        }
    }

    public func unpinItem(_ itemID: UUID, from pinboardID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].pinboardIDs.removeAll { $0 == pinboardID }
        if !items[idx].isInHistory && items[idx].pinboardIDs.isEmpty {
            let removed = items.remove(at: idx)
            storage.deleteBlobs(for: removed.id)
        }
        ensureValidSelection()
        persist()
    }

    public func renameItem(_ itemID: UUID, customTitle: String?) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        let cleaned = customTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        items[idx].customTitle = (cleaned?.isEmpty == true) ? nil : cleaned
        persist()
    }

    public func editItemText(_ itemID: UUID, newText: String) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[idx].textContent = newText
        items[idx].hasRTF = false
        items[idx].hasHTML = false
        items[idx].byteSize = Int64(newText.utf8.count)
        if items[idx].type == .link {
            items[idx].urlString = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let parsed = ColorParser.parse(newText) {
            items[idx].type = .color
            items[idx].parsedColor = parsed
        } else if items[idx].type == .color {
            items[idx].type = .text
            items[idx].parsedColor = nil
        }
        items[idx].contentHash = monitor.sha256Hex(Data(("text:" + newText).utf8))
        persist()
    }

    public func deleteItem(_ itemID: UUID) {
        guard let idx = items.firstIndex(where: { $0.id == itemID }) else { return }
        switch selectedTab {
        case .pinboard(let boardID):
            items[idx].pinboardIDs.removeAll { $0 == boardID }
            if !items[idx].isInHistory && items[idx].pinboardIDs.isEmpty {
                let removed = items.remove(at: idx)
                undoStack.append(DeletedItemSnapshot(item: removed, index: idx))
            }
        case .history:
            if items[idx].pinboardIDs.isEmpty {
                let removed = items.remove(at: idx)
                undoStack.append(DeletedItemSnapshot(item: removed, index: idx))
            } else {
                // Keep item alive in its Pinboards, remove from History only
                items[idx].isInHistory = false
            }
        }
        pasteStackItemIDs.removeAll { $0 == itemID }
        SoundManager.shared.play(.delete, enabled: settings.soundEffectsEnabled)
        ensureValidSelection()
        persist()
    }

    public func undoLastDelete() {
        guard let snapshot = undoStack.popLast() else { return }
        let targetIndex = min(snapshot.index, items.count)
        items.insert(snapshot.item, at: targetIndex)
        selectedItemID = snapshot.item.id
        persist()
        showToast("Restored Clip")
    }

    public func clearHistory() {
        var remaining: [ClipItem] = []
        for var item in items {
            if !item.pinboardIDs.isEmpty {
                item.isInHistory = false
                remaining.append(item)
            } else {
                storage.deleteBlobs(for: item.id)
            }
        }
        items = remaining
        pasteStackItemIDs.removeAll { id in !items.contains(where: { $0.id == id }) }
        ensureValidSelection()
        persist()
        showToast("History Cleared")
    }

    // MARK: - Pinboard CRUD

    @discardableResult
    public func createPinboard(name: String, color: PinboardColor) -> Pinboard {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let board = Pinboard(name: trimmed.isEmpty ? "Untitled" : trimmed, color: color)
        pinboards.append(board)
        persist()
        return board
    }

    public func updatePinboard(_ id: UUID, name: String, color: PinboardColor) {
        guard let idx = pinboards.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            pinboards[idx].name = trimmed
        }
        pinboards[idx].color = color
        persist()
    }

    public func deletePinboard(_ id: UUID) {
        pinboards.removeAll { $0.id == id }
        var kept: [ClipItem] = []
        for var item in items {
            item.pinboardIDs.removeAll { $0 == id }
            if item.isInHistory || !item.pinboardIDs.isEmpty {
                kept.append(item)
            } else {
                storage.deleteBlobs(for: item.id)
            }
        }
        items = kept
        if selectedTab == .pinboard(id) {
            selectedTab = .history
        }
        persist()
    }

    // MARK: - Retention & Persistence

    public func applyRetentionPolicy(saveAfter: Bool = true) {
        guard let maxAge = settings.retentionPolicy.timeInterval else {
            if saveAfter { persist() }
            return
        }
        let cutoff = Date().addingTimeInterval(-maxAge)
        var changed = false
        var kept: [ClipItem] = []
        for var item in items {
            if item.isInHistory && item.timestamp < cutoff {
                item.isInHistory = false
                changed = true
            }
            if item.isInHistory || !item.pinboardIDs.isEmpty {
                kept.append(item)
            } else {
                storage.deleteBlobs(for: item.id)
                changed = true
            }
        }
        if changed {
            items = kept
            ensureValidSelection()
            if saveAfter { persist() }
        }
    }

    public func updateSettings(_ mutate: (inout AppSettings) -> Void) {
        let oldShortcuts = (settings.openShelfShortcut, settings.pasteStackShortcut, settings.pasteNextShortcut)
        mutate(&settings)
        if oldShortcuts != (settings.openShelfShortcut, settings.pasteStackShortcut, settings.pasteNextShortcut) {
            HotkeyManager.shared.reconfigure(settings: settings)
        }
        applyRetentionPolicy(saveAfter: false)
        persist()
    }

    public func persist() {
        storage.scheduleSave(PersistedStore(items: items, pinboards: pinboards, settings: settings))
    }

    public func saveImmediately() {
        storage.saveImmediately(PersistedStore(items: items, pinboards: pinboards, settings: settings))
    }

    // MARK: - Toast Helper

    public func showToast(_ message: String) {
        toastWorkItem?.cancel()
        toastMessage = message
        let work = DispatchWorkItem { [weak self] in
            self?.toastMessage = nil
        }
        toastWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }
}
