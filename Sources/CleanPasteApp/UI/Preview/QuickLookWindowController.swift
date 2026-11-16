import SwiftUI
import AppKit
import CleanPasteCore

final class QuickLookPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class QuickLookWindowController {
    private let appState: AppState
    private var panel: QuickLookPanel?
    private var hostingView: NSHostingView<AnyView>?

    var window: NSWindow? { panel }

    init(appState: AppState) {
        self.appState = appState
        appState.onRequestOpenQuickLook = { [weak self] in
            self?.showOrUpdate()
        }
        appState.onRequestCloseQuickLook = { [weak self] in
            self?.close()
        }
    }

    func showOrUpdate() {
        guard appState.selectedItem != nil else {
            close()
            return
        }

        if panel == nil {
            let p = QuickLookPanel(
                contentRect: NSRect(x: 0, y: 0, width: 580, height: 420),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = true
            p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 4)
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            p.isMovableByWindowBackground = true

            let hosting = NSHostingView(
                rootView: AnyView(
                    QuickLookPreviewView(onClose: { [weak self] in self?.close() })
                        .environmentObject(appState)
                )
            )
            p.contentView = hosting
            self.hostingView = hosting
            self.panel = p
        }

        guard let panel else { return }
        if !panel.isVisible {
            let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
                ?? NSScreen.main
                ?? NSScreen.screens.first
            if let screen {
                let width: CGFloat = 580
                let height: CGFloat = 420
                let x = screen.frame.midX - width / 2
                // Place cleanly centered right above the bottom shelf
                let y = min(screen.frame.maxY - height - 40, screen.frame.minY + 376)
                panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
            }
            panel.alphaValue = 0
            panel.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.16
                panel.animator().alphaValue = 1
            }
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
        appState.isQuickLookOpen = true
    }

    func close() {
        appState.isQuickLookOpen = false
        panel?.orderOut(nil)
    }
}

struct QuickLookPreviewView: View {
    @EnvironmentObject var appState: AppState
    var onClose: () -> Void
    @State private var forceMonospace: Bool = false

    var body: some View {
        if let item = appState.selectedItem {
            let headerColor = Color(nsColor: item.defaultHeaderColor)
            let appIcon = AppColorExtractor.shared.appIcon(for: item.sourceAppBundleID)

            VStack(spacing: 0) {
                // Header
                HStack(spacing: 10) {
                    if let appIcon {
                        Image(nsImage: appIcon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 28, height: 28)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.headerTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("\(item.sourceAppName ?? "Clipboard") • \(item.footerMetadata)")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.white.opacity(0.84))
                    }
                    Spacer()
                    if item.type == .text {
                        Button {
                            forceMonospace.toggle()
                        } label: {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(6)
                                .background(Circle().fill(.white.opacity(forceMonospace ? 0.30 : 0.14)))
                        }
                        .buttonStyle(.plain)
                        .help("Toggle Monospace Font")
                    }
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Circle().fill(.white.opacity(0.20)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .frame(height: 52)
                .background(headerColor)

                // Body
                previewBody(for: item)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))

                Divider()

                // Action Footer
                HStack(spacing: 8) {
                    if item.type == .text || item.type == .link || item.type == .color {
                        Button("Edit (⌘E)") {
                            appState.onRequestOpenEdit?(item)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    if item.type == .image {
                        Button("Save Image...") {
                            saveImage(item: item)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    if item.type == .link, let urlStr = item.urlString, let url = URL(string: urlStr) {
                        Button("Open in Browser") {
                            NSWorkspace.shared.open(url)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    if item.type == .file, !item.filePaths.isEmpty {
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting(item.filePaths.map { URL(fileURLWithPath: $0) })
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Spacer()

                    Button("Copy (⌘C)") {
                        appState.copyItem(item)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Paste Plain Text (⇧↩)") {
                        appState.pasteItem(item, plainTextOnly: true, pasteDirectly: true)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Paste (↩)") {
                        appState.pasteItem(item, plainTextOnly: false, pasteDirectly: true)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color(nsColor: .controlBackgroundColor))
            }
            .frame(width: 580, height: 420)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.32), radius: 22, y: 10)
        }
    }

    @ViewBuilder
    private func previewBody(for item: ClipItem) -> some View {
        switch item.type {
        case .text:
            ScrollView {
                Text(item.textContent ?? "")
                    .font(
                        (forceMonospace || item.looksLikeCode)
                            ? .system(size: 13, design: .monospaced)
                            : .system(size: 13.5)
                    )
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(16)
            }

        case .image:
            let fullImage = appState.storage.loadFullImage(for: item.id)
            ZStack {
                CheckerboardBackground(squareSize: 12)
                    .opacity(0.35)
                if let fullImage {
                    Image(nsImage: fullImage)
                        .resizable()
                        .scaledToFit()
                        .padding(14)
                }
            }

        case .link:
            let previewImg = item.hasLinkPreviewImage ? appState.storage.loadLinkPreviewImage(for: item.id) : nil
            let iconImg = item.hasLinkIcon ? appState.storage.loadLinkIcon(for: item.id) : nil
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let previewImg {
                        Image(nsImage: previewImg)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    HStack(spacing: 10) {
                        if let iconImg {
                            Image(nsImage: iconImg)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.linkTitle ?? item.linkHost ?? "Web Link")
                                .font(.system(size: 16, weight: .semibold))
                            if let host = item.linkHost {
                                Text(host)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text(item.urlString ?? "")
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(Color.accentColor)
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                }
                .padding(18)
            }

        case .color:
            let c = item.parsedColor ?? ParsedColor(red: 0.25, green: 0.55, blue: 0.95)
            let swiftStr = String(format: "Color(red: %.3f, green: %.3f, blue: %.3f)", c.red, c.green, c.blue)
            VStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: c.nsColor))
                    .frame(height: 150)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )

                VStack(spacing: 8) {
                    colorRow(label: "HEX", value: c.hexString)
                    colorRow(label: "RGB", value: c.rgbString)
                    colorRow(label: "HSL", value: c.hslString)
                    colorRow(label: "SwiftUI", value: swiftStr)
                }
            }
            .padding(18)

        case .file:
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(item.filePaths, id: \.self) { path in
                        let exists = FileManager.default.fileExists(atPath: path)
                        let icon = NSWorkspace.shared.icon(forFile: path)
                        HStack(spacing: 12) {
                            Image(nsImage: icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(URL(fileURLWithPath: path).lastPathComponent)
                                    .font(.system(size: 13.5, weight: .semibold))
                                Text(path)
                                    .font(.system(size: 11.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                if !exists {
                                    Text("File moved or deleted")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.red)
                                }
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.05)))
                    }
                }
                .padding(16)
            }
        }
    }

    private func colorRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.system(size: 12.5, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
            Button("Copy") {
                appState.copyCustomString(value, label: label)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }

    private func saveImage(item: ClipItem) {
        guard let data = appState.storage.loadImageData(for: item.id) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "ClipImage.png"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }
}
