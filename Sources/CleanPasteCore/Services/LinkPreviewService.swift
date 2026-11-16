import Foundation
import AppKit
import LinkPresentation
import QuickLookThumbnailing
import UniformTypeIdentifiers

public struct LinkMetadataResult: Sendable {
    public let title: String?
    public let iconData: Data?
    public let imageData: Data?
}

public final class LinkPreviewService {
    public static let shared = LinkPreviewService()
    private init() {}

    @MainActor
    public func fetchMetadata(
        for urlString: String,
        itemID: UUID,
        storage: StorageManager,
        completion: @escaping @MainActor (String?, Bool, Bool) -> Void
    ) {
        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return
        }

        let provider = LPMetadataProvider()
        provider.timeout = 8.0
        provider.startFetchingMetadata(for: url) { metadata, _ in
            guard let metadata else { return }
            let title = metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)

            let group = DispatchGroup()
            var fetchedIcon: NSImage?
            var fetchedImage: NSImage?

            if let iconProvider = metadata.iconProvider {
                group.enter()
                Self.loadImage(from: iconProvider) { img in
                    fetchedIcon = img
                    group.leave()
                }
            }

            if let imageProvider = metadata.imageProvider {
                group.enter()
                Self.loadImage(from: imageProvider) { img in
                    fetchedImage = img
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                let iconToSave = fetchedIcon
                let previewToSave = fetchedImage
                Task { @MainActor in
                    var hasIcon = false
                    var hasPreview = false

                    if let icon = iconToSave {
                        storage.saveLinkIcon(icon, for: itemID)
                        hasIcon = true
                    }
                    if let preview = previewToSave {
                        storage.saveLinkPreviewImage(preview, for: itemID)
                        hasPreview = true
                    }
                    completion(title, hasIcon, hasPreview)
                }
            }
        }
    }

    private static func loadImage(from itemProvider: NSItemProvider, completion: @escaping (NSImage?) -> Void) {
        if itemProvider.canLoadObject(ofClass: NSImage.self) {
            itemProvider.loadObject(ofClass: NSImage.self) { object, _ in
                completion(object as? NSImage)
            }
            return
        }
        itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            if let data, let image = NSImage(data: data) {
                completion(image)
            } else {
                completion(nil)
            }
        }
    }

    public func generateFileThumbnail(
        for filePath: String,
        itemID: UUID,
        storage: StorageManager,
        completion: @escaping @MainActor (Bool) -> Void
    ) {
        let url = URL(fileURLWithPath: filePath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let size = CGSize(width: 240, height: 240)
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: .thumbnail
        )

        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            guard let cgImage = representation?.cgImage else { return }
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            DispatchQueue.main.async {
                storage.saveFileThumbnail(image, for: itemID)
                completion(true)
            }
        }
    }
}
