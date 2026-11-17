import SwiftUI
import UniformTypeIdentifiers
import CleanPasteCore

struct ShelfHeaderBar: View {
    @EnvironmentObject var appState: AppState
    @Binding var isSearchFocused: Bool
    @Binding var showNewPinboardPopover: Bool
    @Binding var editingPinboard: Pinboard?
    @Binding var pendingPinItemID: UUID?

    @State private var dropTargetBoardID: UUID?
    @State private var showClearConfirm: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            // MARK: Search Button / Inline Search Bar
            searchSection

            // MARK: Filter Chips (shown when searching or non-All filter active)
            if appState.isSearchVisible || !appState.searchQuery.isEmpty || appState.activeFilter != .all {
                filterChipsSection
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            // MARK: Pinboard Tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    historyTabButton

                    ForEach(appState.pinboards) { board in
                        pinboardTabButton(board)
                    }

                    Button {
                        pendingPinItemID = nil
                        showNewPinboardPopover = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(Color.primary.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                    .help("New Pinboard")
                    .popover(isPresented: $showNewPinboardPopover, arrowEdge: .bottom) {
                        PinboardEditorSheet(
                            title: "New Pinboard",
                            name: "",
                            selectedColor: .blue,
                            onCancel: {
                                pendingPinItemID = nil
                                showNewPinboardPopover = false
                            },
                            onSave: { name, color in
                                let created = appState.createPinboard(name: name, color: color)
                                if let itemID = pendingPinItemID {
                                    appState.pinItem(itemID, to: created.id)
                                } else {
                                    appState.selectedTab = .pinboard(created.id)
                                }
                                pendingPinItemID = nil
                                showNewPinboardPopover = false
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // MARK: Right Controls (Accessibility Hint, Paused, Paste Stack, Overflow Menu)
            HStack(spacing: 8) {
                if appState.settings.directPaste && !appState.accessibilityGranted {
                    Button {
                        appState.onRequestOpenSettings?()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.raised.circle.fill")
                                .font(.system(size: 11.5))
                            Text("Enable Accessibility")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .help("Accessibility trust is required for Direct Paste. Click to open Preferences.")
                }

                if appState.isPaused {
                    Button {
                        appState.resumeRecording()
                    } label: {
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            HStack(spacing: 5) {
                                Image(systemName: "pause.circle.fill")
                                    .font(.system(size: 12))
                                Text(pausedBadgeLabel(now: context.date))
                                    .font(.system(size: 11.5, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                    }
                    .buttonStyle(.plain)
                    .help("Clipboard recording is paused. Click to resume.")
                }

                Button {
                    appState.togglePasteStack()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.stack.3d.up.fill")
                            .font(.system(size: 12))
                        if appState.isPasteStackActive {
                            Text("Stack \(appState.pasteStackItemIDs.count)")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                    }
                    .foregroundStyle(appState.isPasteStackActive ? .white : .secondary)
                    .padding(.horizontal, appState.isPasteStackActive ? 10 : 8)
                    .frame(height: 28)
                    .background(
                        Capsule()
                            .fill(appState.isPasteStackActive ? Color.accentColor : Color.primary.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)
                .help("Toggle Paste Stack (\(appState.settings.pasteStackShortcut.displayString))")

                Menu {
                    Button {
                        appState.togglePasteStack()
                    } label: {
                        Label(
                            appState.isPasteStackActive ? "Turn Off Paste Stack" : "Start Paste Stack",
                            systemImage: "square.stack.3d.up"
                        )
                    }

                    if appState.isPaused {
                        Button {
                            appState.resumeRecording()
                        } label: {
                            Label("Resume Recording", systemImage: "play.circle")
                        }
                    } else {
                        Menu {
                            Button("Pause for 15 Minutes") {
                                appState.pause(for: 15 * 60)
                            }
                            Button("Pause for 1 Hour") {
                                appState.pause(for: 60 * 60)
                            }
                            Divider()
                            Button("Pause Until Resumed") {
                                appState.pause(for: nil)
                            }
                        } label: {
                            Label("Pause Recording", systemImage: "pause.circle")
                        }
                    }

                    Divider()

                    Menu("Filter by Type") {
                        ForEach(ClipFilter.allCases) { filter in
                            Button {
                                appState.activeFilter = filter
                            } label: {
                                HStack {
                                    Text(filter.rawValue)
                                    if appState.activeFilter == filter {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear Clipboard History...", systemImage: "trash")
                    }

                    Divider()

                    Button {
                        appState.onRequestOpenSettings?()
                    } label: {
                        Label("Preferences...", systemImage: "gearshape")
                    }

                    Button {
                        NSApplication.shared.terminate(nil)
                    } label: {
                        Label("Quit CleanPaste", systemImage: "power")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("More Actions")
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 46)
        .animation(.easeInOut(duration: 0.18), value: appState.isSearchVisible)
        .alert("Clear Clipboard History?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear History", role: .destructive) {
                appState.clearHistory()
            }
        } message: {
            Text("All unpinned items in Clipboard History will be permanently removed. Items saved in Pinboards will be kept.")
        }
        .popover(item: $editingPinboard, arrowEdge: .bottom) { board in
            PinboardEditorSheet(
                title: "Edit Pinboard",
                name: board.name,
                selectedColor: board.color,
                onCancel: { editingPinboard = nil },
                onSave: { name, color in
                    appState.updatePinboard(board.id, name: name, color: color)
                    editingPinboard = nil
                }
            )
        }
    }

    @ViewBuilder
    private var searchSection: some View {
        if appState.isSearchVisible || !appState.searchQuery.isEmpty {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)

                SearchTextField(
                    text: $appState.searchQuery,
                    isFocused: $isSearchFocused,
                    onSubmit: {
                        if let selected = appState.selectedItem {
                            let shiftHeld = NSEvent.modifierFlags.contains(.shift)
                            appState.pasteItem(selected, plainTextOnly: shiftHeld ? true : nil, pasteDirectly: true)
                        }
                    },
                    onCancel: {
                        if !appState.searchQuery.isEmpty {
                            appState.searchQuery = ""
                        } else {
                            appState.isSearchVisible = false
                            isSearchFocused = false
                        }
                    }
                )
                .frame(width: 190, height: 20)

                if !appState.searchQuery.isEmpty || appState.isSearchVisible {
                    Button {
                        appState.searchQuery = ""
                        appState.isSearchVisible = false
                        isSearchFocused = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isSearchFocused ? Color.accentColor.opacity(0.6) : Color.primary.opacity(0.10), lineWidth: 1)
            )
        } else {
            Button {
                appState.isSearchVisible = true
                isSearchFocused = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Search (⌘F or just start typing)")
        }
    }

    private var filterChipsSection: some View {
        HStack(spacing: 4) {
            ForEach(ClipFilter.allCases) { filter in
                let isSelected = appState.activeFilter == filter
                Button {
                    appState.activeFilter = filter
                } label: {
                    Text(filter.rawValue)
                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .medium))
                        .foregroundStyle(isSelected ? .white : .secondary)
                        .padding(.horizontal, 8)
                        .frame(height: 24)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.accentColor : Color.primary.opacity(0.07))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var historyTabButton: some View {
        let isSelected = appState.selectedTab == .history
        return Button {
            appState.selectedTab = .history
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 12, weight: .semibold))
                Text("Clipboard History")
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(isSelected ? Color(nsColor: .controlBackgroundColor).opacity(0.95) : Color.clear)
                    .shadow(color: isSelected ? .black.opacity(0.10) : .clear, radius: 3, y: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func pinboardTabButton(_ board: Pinboard) -> some View {
        let isSelected = appState.selectedTab == .pinboard(board.id)
        let isDropHover = dropTargetBoardID == board.id

        return Button {
            appState.selectedTab = .pinboard(board.id)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(board.color.swiftUIColor)
                    .frame(width: 8, height: 8)
                Text(board.name)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .primary : .secondary)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(
                Capsule()
                    .fill(
                        isDropHover
                            ? board.color.swiftUIColor.opacity(0.28)
                            : (isSelected ? Color(nsColor: .controlBackgroundColor).opacity(0.95) : Color.clear)
                    )
                    .shadow(color: isSelected ? .black.opacity(0.10) : .clear, radius: 3, y: 1)
            )
            .overlay(
                Capsule()
                    .strokeBorder(isDropHover ? board.color.swiftUIColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .onDrop(
            of: [UTType.data, UTType.plainText, UTType.text, UTType.url, UTType.fileURL, UTType.image],
            isTargeted: Binding(
                get: { dropTargetBoardID == board.id },
                set: { targeted in
                    dropTargetBoardID = targeted ? board.id : (dropTargetBoardID == board.id ? nil : dropTargetBoardID)
                }
            )
        ) { _ in
            if let draggedID = DragCoordinator.shared.draggingItemID {
                appState.pinItem(draggedID, to: board.id)
                DragCoordinator.shared.draggingItemID = nil
                return true
            }
            return false
        }
        .contextMenu {
            Button("Edit Pinboard...") {
                editingPinboard = board
            }
            Divider()
            Button("Delete Pinboard", role: .destructive) {
                appState.deletePinboard(board.id)
            }
        }
    }

    private func pausedBadgeLabel(now: Date) -> String {
        guard let until = appState.pauseUntil else { return "Paused" }
        let remaining = max(0, until.timeIntervalSince(now))
        let mins = Int(ceil(remaining / 60))
        return mins > 0 ? "Paused • \(mins)m" : "Paused"
    }
}
