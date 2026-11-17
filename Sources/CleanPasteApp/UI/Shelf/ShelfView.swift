import SwiftUI
import AppKit
import CleanPasteCore

struct VisualEffectMaterialView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var state: NSVisualEffectView.State = .active

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

struct ShelfView: View {
    @EnvironmentObject var appState: AppState
    @Binding var isSearchFocused: Bool

    @State private var showNewPinboardPopover: Bool = false
    @State private var editingPinboard: Pinboard?
    @State private var pendingPinItemID: UUID?

    private var colorSchemeOverride: ColorScheme? {
        switch appState.settings.shelfAppearance {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some View {
        let visible = appState.visibleItems

        ZStack(alignment: .bottom) {
            VisualEffectMaterialView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ShelfHeaderBar(
                    isSearchFocused: $isSearchFocused,
                    showNewPinboardPopover: $showNewPinboardPopover,
                    editingPinboard: $editingPinboard,
                    pendingPinItemID: $pendingPinItemID
                )
                .padding(.top, 4)

                if appState.isPasteStackActive {
                    PasteStackShelfStrip()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                if visible.isEmpty {
                    emptyStateView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                                    ClipCardView(
                                        item: item,
                                        index: index,
                                        isSelected: appState.selectedItem?.id == item.id,
                                        onRequestNewPinboardForItem: { itemID in
                                            pendingPinItemID = itemID
                                            showNewPinboardPopover = true
                                        }
                                    )
                                    .id(item.id)
                                }
                            }
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)
                        }
                        .onChange(of: appState.selectedItemID) { _, newID in
                            guard let newID else { return }
                            withAnimation(.easeOut(duration: 0.16)) {
                                proxy.scrollTo(newID, anchor: .center)
                            }
                        }
                        .onChange(of: appState.selectedTab) { _, _ in
                            if let firstID = appState.visibleItems.first?.id {
                                proxy.scrollTo(firstID, anchor: .leading)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 1)
            }

            if let toast = appState.toastMessage {
                Text(toast)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color.black.opacity(0.78)))
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .allowsHitTesting(false)
            }
        }
        .preferredColorScheme(colorSchemeOverride)
        .animation(.easeOut(duration: 0.18), value: appState.toastMessage)
        .animation(.easeInOut(duration: 0.18), value: appState.isPasteStackActive)
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            if appState.hasActiveFilters {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
                Text("No matching items")
                    .font(.system(size: 15, weight: .semibold))
                Text("Try clearing your search query or changing the active filters.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                Button("Reset Search & Filters") {
                    appState.resetAllFilters()
                    isSearchFocused = false
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 2)
            } else if case .pinboard(let boardID) = appState.selectedTab {
                let boardName = appState.pinboards.first(where: { $0.id == boardID })?.name ?? "Pinboard"
                Image(systemName: "pin")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
                Text("\(boardName) is empty")
                    .font(.system(size: 15, weight: .semibold))
                Text("Drag any card onto this tab or right-click a card → Pin to save items permanently.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Your Clipboard History is Empty")
                    .font(.system(size: 15, weight: .semibold))
                Text("Copy text, links, images, colors, or files anywhere on your Mac and they'll appear here.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 24)
    }
}
