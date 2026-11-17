import SwiftUI
import AppKit
import UniformTypeIdentifiers
import CleanPasteCore

@MainActor
final class DragCoordinator {
    static let shared = DragCoordinator()
    var draggingItemID: UUID?
    private init() {}
}

struct ClipCardView: View {
    @EnvironmentObject var appState: AppState
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    var onRequestNewPinboardForItem: (UUID) -> Void

    @State private var isHovered: Bool = false

    private static let cardWidth: CGFloat = 242
    private static let cardHeight: CGFloat = 256

    var body: some View {
        let headerColor = Color(nsColor: item.defaultHeaderColor)
        let appIcon = AppColorExtractor.shared.appIcon(for: item.sourceAppBundleID)
        let pinnedBoards = appState.pinboards.filter { item.pinboardIDs.contains($0.id) }

        VStack(spacing: 0) {
            // MARK: Colored Card Header
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.headerTitle)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        Text(relativeTimestamp(from: item.timestamp, now: context.date))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.84))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 4)

                if let appIcon {
                    Image(nsImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(.white.opacity(0.20))
                            .frame(width: 30, height: 30)
                        Image(systemName: item.type.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 54)
            .background(
                LinearGradient(
                    colors: [
                        headerColor.opacity(0.95),
                        headerColor
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // MARK: Card Body
            CardBodyView(item: item, storage: appState.storage)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .controlBackgroundColor))

            // MARK: Card Footer
            HStack(spacing: 6) {
                Text(item.footerMetadata)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if item.isSensitiveSecret {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        .help("Sensitive secret detected")
                }

                if item.hasDynamicPlaceholders && appState.settings.expandDynamicSnippets {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.accentColor)
                        .help("Dynamic snippet placeholders active")
                }

                if !pinnedBoards.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(pinnedBoards.prefix(4)) { board in
                            Circle()
                                .fill(board.color.swiftUIColor)
                                .frame(width: 7, height: 7)
                                .help("Pinned in \(board.name)")
                        }
                    }
                }

                if index < 9 {
                    Text("⌘\(index + 1)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.primary.opacity(0.07))
                        )
                }
            }
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(Color(nsColor: .controlBackgroundColor))
            .overlay(alignment: .top) {
                Divider().opacity(0.45)
            }
        }
        .frame(width: Self.cardWidth, height: Self.cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(
                    isSelected
                        ? Color.accentColor
                        : (isHovered ? Color.primary.opacity(0.24) : Color.primary.opacity(0.10)),
                    lineWidth: isSelected ? 3 : 1
                )
        )
        .shadow(
            color: isSelected
                ? Color.accentColor.opacity(0.32)
                : Color.black.opacity(isHovered ? 0.22 : 0.14),
            radius: isSelected ? 12 : (isHovered ? 10 : 6),
            x: 0,
            y: isSelected ? 4 : 3
        )
        .scaleEffect(isSelected ? 1.015 : 1.0)
        .animation(.spring(response: 0.20, dampingFraction: 0.82), value: isSelected)
        .onHover { hovering in
            isHovered = hovering
        }
        .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .modifier(CardTapGestureModifier(
            singleClickToPaste: appState.settings.singleClickToPaste,
            onSelect: {
                appState.selectedItemID = item.id
                if appState.isQuickLookOpen {
                    appState.onRequestOpenQuickLook?()
                }
            },
            onPaste: { shiftHeld in
                appState.selectedItemID = item.id
                appState.pasteItem(item, plainTextOnly: shiftHeld ? true : nil, pasteDirectly: true)
            },
            isQuickLookOpen: appState.isQuickLookOpen
        ))
        .onDrag {
            DragCoordinator.shared.draggingItemID = item.id
            return makeDragItemProvider()
        }
        .contextMenu {
            cardContextMenu
        }
    }

    @ViewBuilder
    private var cardContextMenu: some View {
        Button {
            appState.pasteItem(item, plainTextOnly: false, pasteDirectly: true)
        } label: {
            Label("Paste", systemImage: "doc.on.clipboard")
        }

        Button {
            appState.pasteItem(item, plainTextOnly: true, pasteDirectly: true)
        } label: {
            Label("Paste as Plain Text", systemImage: "text.alignleft")
        }

        Button {
            appState.copyItem(item, plainTextOnly: false)
        } label: {
            Label("Copy to Clipboard", systemImage: "doc.on.doc")
        }

        if item.type == .text || item.type == .link,
           let rawText = item.textContent ?? item.urlString,
           !rawText.isEmpty {
            let transforms = TextTransformService.availableTransforms(for: rawText, isLink: item.type == .link)
            Menu {
                ForEach(transforms) { transform in
                    Button(transform.rawValue) {
                        appState.pasteTransformed(item, transform: transform, pasteDirectly: true)
                    }
                }
            } label: {
                Label("Transform & Paste", systemImage: "wand.and.stars")
            }

            Menu {
                ForEach(transforms) { transform in
                    Button(transform.rawValue) {
                        appState.pasteTransformed(item, transform: transform, pasteDirectly: false)
                    }
                }
            } label: {
                Label("Transform & Copy", systemImage: "doc.badge.gearshape")
            }
        }

        if item.type == .color, let color = item.parsedColor {
            Menu("Copy Color As") {
                Button("HEX (\(color.hexString))") {
                    appState.copyCustomString(color.hexString, label: "HEX")
                }
                Button("RGB (\(color.rgbString))") {
                    appState.copyCustomString(color.rgbString, label: "RGB")
                }
                Button("HSL (\(color.hslString))") {
                    appState.copyCustomString(color.hslString, label: "HSL")
                }
            }
        }

        Divider()

        Button {
            appState.selectedItemID = item.id
            appState.onRequestOpenQuickLook?()
        } label: {
            Label("Preview", systemImage: "eye")
        }

        Button {
            appState.enqueueIntoPasteStack(item)
        } label: {
            Label("Add to Paste Stack", systemImage: "square.stack.3d.up")
        }

        Menu {
            ForEach(appState.pinboards) { board in
                let isPinned = item.pinboardIDs.contains(board.id)
                Button {
                    if isPinned {
                        appState.unpinItem(item.id, from: board.id)
                    } else {
                        appState.pinItem(item.id, to: board.id)
                    }
                } label: {
                    HStack {
                        Text(board.name)
                        if isPinned {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            if !appState.pinboards.isEmpty {
                Divider()
            }
            Button("New Pinboard...") {
                onRequestNewPinboardForItem(item.id)
            }
        } label: {
            Label("Pin to", systemImage: "pin")
        }

        Divider()

        if item.type == .text || item.type == .link || item.type == .color {
            Button {
                appState.onRequestOpenEdit?(item)
            } label: {
                Label("Edit...", systemImage: "pencil")
            }
        }

        Button {
            appState.onRequestOpenRename?(item)
        } label: {
            Label("Rename...", systemImage: "tag")
        }

        if item.type == .link, let urlStr = item.urlString, let url = URL(string: urlStr) {
            Button {
                NSWorkspace.shared.open(url)
            } label: {
                Label("Open Link in Browser", systemImage: "safari")
            }
        }

        if item.type == .file, let firstPath = item.filePaths.first {
            Button {
                let urls = item.filePaths.map { URL(fileURLWithPath: $0) }
                NSWorkspace.shared.activateFileViewerSelecting(urls)
            } label: {
                Label(
                    FileManager.default.fileExists(atPath: firstPath) ? "Reveal in Finder" : "File Unavailable",
                    systemImage: "folder"
                )
            }
        }

        Divider()

        if case .pinboard(let boardID) = appState.selectedTab {
            Button(role: .destructive) {
                appState.unpinItem(item.id, from: boardID)
            } label: {
                Label("Remove from Pinboard", systemImage: "pin.slash")
            }
        } else {
            Button(role: .destructive) {
                appState.deleteItem(item.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func makeDragItemProvider() -> NSItemProvider {
        switch item.type {
        case .text, .color:
            let str = item.textContent ?? item.parsedColor?.hexString ?? ""
            return NSItemProvider(object: str as NSString)
        case .link:
            let str = item.urlString ?? item.textContent ?? ""
            if let url = URL(string: str) {
                let provider = NSItemProvider(object: url as NSURL)
                provider.registerObject(str as NSString, visibility: .all)
                return provider
            }
            return NSItemProvider(object: str as NSString)
        case .image:
            if let img = appState.storage.loadFullImage(for: item.id) {
                return NSItemProvider(object: img)
            }
            return NSItemProvider(object: (item.headerTitle as NSString))
        case .file:
            if let first = item.filePaths.first {
                return NSItemProvider(object: URL(fileURLWithPath: first) as NSURL)
            }
            return NSItemProvider(object: (item.headerTitle as NSString))
        }
    }

    private func relativeTimestamp(from date: Date, now: Date) -> String {
        let diff = now.timeIntervalSince(date)
        if diff < 15 { return "Just now" }
        if diff < 60 { return "\(Int(diff))s ago" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

private struct CardTapGestureModifier: ViewModifier {
    let singleClickToPaste: Bool
    let onSelect: () -> Void
    let onPaste: (Bool) -> Void
    let isQuickLookOpen: Bool

    func body(content: Content) -> some View {
        if singleClickToPaste {
            content
                .onTapGesture(count: 1) {
                    let mods = NSEvent.modifierFlags
                    if isQuickLookOpen || mods.contains(.option) {
                        onSelect()
                    } else {
                        onPaste(mods.contains(.shift))
                    }
                }
        } else {
            content
                .onTapGesture(count: 2) {
                    onPaste(NSEvent.modifierFlags.contains(.shift))
                }
                .onTapGesture(count: 1) {
                    onSelect()
                }
        }
    }
}
