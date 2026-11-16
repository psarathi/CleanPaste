import SwiftUI
import AppKit
import Combine
import CleanPasteCore

struct PasteStackShelfStrip: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        let stackItems = appState.pasteStackItems

        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                Text("Paste Stack")
                    .font(.system(size: 12, weight: .semibold))
                Text("•")
                    .foregroundStyle(.tertiary)
                Button {
                    appState.updateSettings { s in
                        s.pasteStackOrder = (s.pasteStackOrder == .fifo) ? .lifo : .fifo
                    }
                } label: {
                    Text(appState.settings.pasteStackOrder.shortLabel)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .help("Toggle Queue Order (FIFO / LIFO)")
            }

            if stackItems.isEmpty {
                Text("Copy items (⌘C) to add them to the queue, then paste sequentially with ⌘V")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(stackItems.enumerated()), id: \.element.id) { idx, item in
                            HStack(spacing: 5) {
                                Text("\(idx + 1)")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Circle().fill(idx == 0 ? Color.accentColor : Color.secondary.opacity(0.6)))

                                Text(stackPreviewLabel(item))
                                    .font(.system(size: 11.5))
                                    .lineLimit(1)
                                    .frame(maxWidth: 130, alignment: .leading)

                                Button {
                                    appState.removeFromPasteStack(id: item.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.9))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(idx == 0 ? Color.accentColor.opacity(0.65) : Color.primary.opacity(0.10), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            Spacer(minLength: 4)

            if !stackItems.isEmpty {
                Button("Paste Next") {
                    appState.pasteNextFromStackTrigger()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Clear") {
                    appState.clearPasteStack()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Button {
                appState.togglePasteStack()
            } label: {
                Text("Done")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .frame(height: 36)
        .background(Color.accentColor.opacity(0.08))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.4)
        }
    }

    private func stackPreviewLabel(_ item: ClipItem) -> String {
        if let title = item.customTitle, !title.isEmpty { return title }
        switch item.type {
        case .text, .link, .color:
            return (item.textContent ?? item.headerTitle).replacingOccurrences(of: "\n", with: " ")
        case .image:
            return "Image"
        case .file:
            return item.filePaths.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File"
        }
    }
}

struct PasteStackFloatingHUDView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        let stackItems = appState.pasteStackItems

        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(Color.accentColor)
                Text("Paste Stack")
                    .font(.system(size: 12.5, weight: .semibold))
                Text("(\(stackItems.count))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    appState.updateSettings { s in
                        s.pasteStackOrder = (s.pasteStackOrder == .fifo) ? .lifo : .fifo
                    }
                } label: {
                    Text(appState.settings.pasteStackOrder.shortLabel)
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Button {
                    appState.togglePasteStack()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if stackItems.isEmpty {
                Text("Copy items with ⌘C to queue them here.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(stackItems.prefix(5).enumerated()), id: \.element.id) { idx, item in
                        HStack(spacing: 7) {
                            Text("\(idx + 1)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .frame(width: 17, height: 17)
                                .background(Circle().fill(idx == 0 ? Color.accentColor : Color.secondary.opacity(0.55)))

                            Text(shortLabel(item))
                                .font(.system(size: 11.5))
                                .lineLimit(1)
                            Spacer()
                            Button {
                                appState.removeFromPasteStack(id: item.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(idx == 0 ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.05))
                        )
                    }
                    if stackItems.count > 5 {
                        Text("+ \(stackItems.count - 5) more queued")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }

                if !appState.accessibilityGranted {
                    HStack(spacing: 5) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                        Text("Use \(appState.settings.pasteNextShortcut.displayString) or grant Accessibility for auto-advance on ⌘V")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .onTapGesture {
                        PasteService.shared.promptAccessibilityPermission()
                    }
                } else {
                    Text("Next item auto-loads on ⌘V (or press \(appState.settings.pasteNextShortcut.displayString))")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(width: 268)
        .background(
            VisualEffectMaterialView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.24), radius: 14, y: 6)
    }

    private func shortLabel(_ item: ClipItem) -> String {
        if let title = item.customTitle, !title.isEmpty { return title }
        switch item.type {
        case .text, .link, .color:
            return (item.textContent ?? item.headerTitle).replacingOccurrences(of: "\n", with: " ")
        case .image:
            return "Image"
        case .file:
            return item.filePaths.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File"
        }
    }
}

@MainActor
final class PasteStackHUDController {
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private unowned let appState: AppState

    init(appState: AppState) {
        self.appState = appState
        Publishers.CombineLatest(appState.$isPasteStackActive, appState.$isShelfVisible)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stackActive, shelfVisible in
                self?.updateVisibility(shouldShow: stackActive && !shelfVisible)
            }
            .store(in: &cancellables)
    }

    private func updateVisibility(shouldShow: Bool) {
        if shouldShow {
            show()
        } else {
            panel?.orderOut(nil)
        }
    }

    private func show() {
        if panel == nil {
            let p = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 268, height: 220),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.isOpaque = false
            p.backgroundColor = .clear
            p.hasShadow = false
            p.level = .floating
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
            p.isMovableByWindowBackground = true

            let hosting = NSHostingView(
                rootView: PasteStackFloatingHUDView()
                    .environmentObject(appState)
            )
            hosting.translatesAutoresizingMaskIntoConstraints = false
            p.contentView = hosting
            self.panel = p
        }

        guard let panel else { return }
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main {
            let size = panel.contentView?.fittingSize ?? NSSize(width: 268, height: 140)
            let x = screen.visibleFrame.maxX - size.width - 18
            let y = screen.visibleFrame.minY + 18
            panel.setFrame(NSRect(x: x, y: y, width: size.width, height: max(size.height, 96)), display: true)
        }
        panel.orderFrontRegardless()
    }
}
