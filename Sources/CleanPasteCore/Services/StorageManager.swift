import Foundation
import AppKit
import ImageIO

public struct PersistedStore: Codable {
    public var items: [ClipItem]
    public var pinboards: [Pinboard]
    public var settings: AppSettings

    public init(items: [ClipItem], pinboards: [Pinboard], settings: AppSettings) {
        self.items = items
        self.pinboards = pinboards
        self.settings = settings
    }
}

public final class StorageManager: @unchecked Sendable {
    public let baseDirectory: URL
    public let blobsDirectory: URL
    public let stateFileURL: URL

    private let thumbnailCache = NSCache<NSString, NSImage>()
    private let fullImageCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let saveQueue = DispatchQueue(label: "com.cleanroom.CleanPaste.storage", qos: .utility)
    private var pendingSaveWorkItem: DispatchWorkItem?

    public init(baseDirectory: URL? = nil) {
        if let baseDirectory {
            self.baseDirectory = baseDirectory
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            self.baseDirectory = appSupport.appendingPathComponent("CleanPaste", isDirectory: true)
        }
        self.blobsDirectory = self.baseDirectory.appendingPathComponent("Blobs", isDirectory: true)
        self.stateFileURL = self.baseDirectory.appendingPathComponent("state.json", isDirectory: false)

        thumbnailCache.countLimit = 400
        fullImageCache.countLimit = 24

        ensureDirectories()
    }

    private func ensureDirectories() {
        try? fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: blobsDirectory, withIntermediateDirectories: true)
    }

    public func load() -> PersistedStore {
        ensureDirectories()
        guard fileManager.fileExists(atPath: stateFileURL.path),
              let data = try? Data(contentsOf: stateFileURL) else {
            let starterPinboard = Pinboard(name: "Pinned", color: .blue)
            return PersistedStore(items: [], pinboards: [starterPinboard], settings: AppSettings())
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let store = try? decoder.decode(PersistedStore.self, from: data) {
            return store
        }
        let starterPinboard = Pinboard(name: "Pinned", color: .blue)
        return PersistedStore(items: [], pinboards: [starterPinboard], settings: AppSettings())
    }

    public func scheduleSave(_ store: PersistedStore) {
        pendingSaveWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.writeStoreSync(store)
        }
        pendingSaveWorkItem = work
        saveQueue.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    public func saveImmediately(_ store: PersistedStore) {
        pendingSaveWorkItem?.cancel()
        writeStoreSync(store)
    }

    private func writeStoreSync(_ store: PersistedStore) {
        ensureDirectories()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(store) else { return }
        try? data.write(to: stateFileURL, options: [.atomic])
    }

    // MARK: - Blob Paths & Storage

    public func itemDirectory(for itemID: UUID) -> URL {
        blobsDirectory.appendingPathComponent(itemID.uuidString, isDirectory: true)
    }

    private func ensureItemDirectory(for itemID: UUID) -> URL {
        let dir = itemDirectory(for: itemID)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public func saveImageData(_ data: Data, for itemID: UUID) -> (width: Int?, height: Int?, format: String?) {
        let dir = ensureItemDirectory(for: itemID)
        let imageURL = dir.appendingPathComponent("image.dat")
        try? data.write(to: imageURL, options: [.atomic])

        var width: Int?
        var height: Int?
        var format: String?

        if let source = CGImageSourceCreateWithData(data as CFData, nil) {
            if let typeUTI = CGImageSourceGetType(source) as String? {
                if typeUTI.contains("png") { format = "PNG" }
                else if typeUTI.contains("jpeg") || typeUTI.contains("jpg") { format = "JPEG" }
                else if typeUTI.contains("tiff") { format = "TIFF" }
                else if typeUTI.contains("gif") { format = "GIF" }
                else if typeUTI.contains("heic") { format = "HEIC" }
                else if typeUTI.contains("webp") { format = "WEBP" }
                else { format = "IMG" }
            }
            if let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] {
                width = props[kCGImagePropertyPixelWidth] as? Int
                height = props[kCGImagePropertyPixelHeight] as? Int
            }
            // Generate fast downsampled thumbnail
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 560,
                kCGImageSourceCreateThumbnailWithTransform: true
            ]
            if let cgThumb = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                let thumbImage = NSImage(cgImage: cgThumb, size: NSSize(width: cgThumb.width, height: cgThumb.height))
                thumbnailCache.setObject(thumbImage, forKey: cacheKey(itemID, "thumb"))
                if let tiff = thumbImage.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: tiff),
                   let png = rep.representation(using: .png, properties: [:]) {
                    try? png.write(to: dir.appendingPathComponent("thumbnail.png"), options: [.atomic])
                }
            }
        }
        return (width, height, format)
    }

    public func loadImageData(for itemID: UUID) -> Data? {
        let url = itemDirectory(for: itemID).appendingPathComponent("image.dat")
        return try? Data(contentsOf: url)
    }

    public func loadFullImage(for itemID: UUID) -> NSImage? {
        let key = cacheKey(itemID, "full")
        if let cached = fullImageCache.object(forKey: key) {
            return cached
        }
        guard let data = loadImageData(for: itemID),
              let image = NSImage(data: data) else {
            return nil
        }
        fullImageCache.setObject(image, forKey: key)
        return image
    }

    public func loadThumbnail(for itemID: UUID) -> NSImage? {
        let key = cacheKey(itemID, "thumb")
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        let thumbURL = itemDirectory(for: itemID).appendingPathComponent("thumbnail.png")
        if let thumb = NSImage(contentsOf: thumbURL) {
            thumbnailCache.setObject(thumb, forKey: key)
            return thumb
        }
        if let full = loadFullImage(for: itemID) {
            thumbnailCache.setObject(full, forKey: key)
            return full
        }
        return nil
    }

    public func saveRTFData(_ data: Data, for itemID: UUID) {
        let dir = ensureItemDirectory(for: itemID)
        try? data.write(to: dir.appendingPathComponent("rtf.dat"), options: [.atomic])
    }

    public func loadRTFData(for itemID: UUID) -> Data? {
        try? Data(contentsOf: itemDirectory(for: itemID).appendingPathComponent("rtf.dat"))
    }

    public func saveHTMLData(_ data: Data, for itemID: UUID) {
        let dir = ensureItemDirectory(for: itemID)
        try? data.write(to: dir.appendingPathComponent("html.dat"), options: [.atomic])
    }

    public func loadHTMLData(for itemID: UUID) -> Data? {
        try? Data(contentsOf: itemDirectory(for: itemID).appendingPathComponent("html.dat"))
    }

    public func saveLinkIcon(_ image: NSImage, for itemID: UUID) {
        saveAuxImage(image, name: "link_icon.png", cacheSuffix: "linkIcon", for: itemID)
    }

    public func loadLinkIcon(for itemID: UUID) -> NSImage? {
        loadAuxImage(name: "link_icon.png", cacheSuffix: "linkIcon", for: itemID)
    }

    public func saveLinkPreviewImage(_ image: NSImage, for itemID: UUID) {
        saveAuxImage(image, name: "link_preview.png", cacheSuffix: "linkPreview", for: itemID)
    }

    public func loadLinkPreviewImage(for itemID: UUID) -> NSImage? {
        loadAuxImage(name: "link_preview.png", cacheSuffix: "linkPreview", for: itemID)
    }

    public func saveFileThumbnail(_ image: NSImage, for itemID: UUID) {
        saveAuxImage(image, name: "file_thumb.png", cacheSuffix: "fileThumb", for: itemID)
    }

    public func loadFileThumbnail(for itemID: UUID) -> NSImage? {
        loadAuxImage(name: "file_thumb.png", cacheSuffix: "fileThumb", for: itemID)
    }

    private func saveAuxImage(_ image: NSImage, name: String, cacheSuffix: String, for itemID: UUID) {
        let dir = ensureItemDirectory(for: itemID)
        thumbnailCache.setObject(image, forKey: cacheKey(itemID, cacheSuffix))
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            try? png.write(to: dir.appendingPathComponent(name), options: [.atomic])
        }
    }

    private func loadAuxImage(name: String, cacheSuffix: String, for itemID: UUID) -> NSImage? {
        let key = cacheKey(itemID, cacheSuffix)
        if let cached = thumbnailCache.object(forKey: key) {
            return cached
        }
        let url = itemDirectory(for: itemID).appendingPathComponent(name)
        if let img = NSImage(contentsOf: url) {
            thumbnailCache.setObject(img, forKey: key)
            return img
        }
        return nil
    }

    public func deleteBlobs(for itemID: UUID) {
        for suffix in ["thumb", "full", "linkIcon", "linkPreview", "fileThumb"] {
            thumbnailCache.removeObject(forKey: cacheKey(itemID, suffix))
            fullImageCache.removeObject(forKey: cacheKey(itemID, suffix))
        }
        let dir = itemDirectory(for: itemID)
        try? fileManager.removeItem(at: dir)
    }

    public func pruneOrphanBlobs(activeIDs: Set<UUID>) {
        guard let contents = try? fileManager.contentsOfDirectory(at: blobsDirectory, includingPropertiesForKeys: nil) else {
            return
        }
        for url in contents {
            if let uuid = UUID(uuidString: url.lastPathComponent), !activeIDs.contains(uuid) {
                try? fileManager.removeItem(at: url)
            }
        }
    }

    private func cacheKey(_ id: UUID, _ suffix: String) -> NSString {
        "\(id.uuidString)-\(suffix)" as NSString
    }
}
