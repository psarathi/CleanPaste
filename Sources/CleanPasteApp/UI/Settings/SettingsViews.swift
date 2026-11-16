import SwiftUI
import AppKit
import Combine
import ServiceManagement
import UniformTypeIdentifiers
import CleanPasteCore

struct SettingsRootView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            RulesSettingsView()
                .tabItem {
                    Label("Rules", systemImage: "hand.raised")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 560, height: 470)
    }
}

// MARK: - General

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var launchAtLogin: Bool = (SMAppService.mainApp.status == .enabled)
    @State private var showClearAlert: Bool = false
    private let axPollTimer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section("Behavior") {
                Toggle("Direct Paste (automatically paste into active app)", isOn: Binding(
                    get: { appState.settings.directPaste },
                    set: { val in appState.updateSettings { $0.directPaste = val } }
                ))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(appState.accessibilityGranted ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Text(
                            appState.accessibilityGranted
                                ? "Accessibility permission granted for Direct Paste & Paste Stack."
                                : "Accessibility permission needed to automatically send ⌘V."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        Spacer()
                        if !appState.accessibilityGranted {
                            Button("Grant Access") {
                                PasteService.shared.promptAccessibilityPermission()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    appState.refreshAccessibilityStatus()
                                }
                            }
                            .controlSize(.small)
                            Button("Reveal App") {
                                NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                            }
                            .controlSize(.small)
                            Button("System Settings") {
                                PasteService.shared.openAccessibilitySettings()
                            }
                            .controlSize(.small)
                        } else {
                            Button("Refresh") {
                                appState.refreshAccessibilityStatus()
                            }
                            .controlSize(.small)
                        }
                    }

                    if !appState.accessibilityGranted {
                        Text("If CleanPaste already appears ON in System Settings from an earlier build, select it and click (−) to remove it, then click Reveal App and drag CleanPaste.app into the Accessibility list.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Always paste as plain text", isOn: Binding(
                    get: { appState.settings.pasteAsPlainTextByDefault },
                    set: { val in appState.updateSettings { $0.pasteAsPlainTextByDefault = val } }
                ))

                Toggle("Move duplicate copies to the front", isOn: Binding(
                    get: { appState.settings.moveDuplicatesToTop },
                    set: { val in appState.updateSettings { $0.moveDuplicatesToTop = val } }
                ))

                Toggle("Sound effects", isOn: Binding(
                    get: { appState.settings.soundEffectsEnabled },
                    set: { val in appState.updateSettings { $0.soundEffectsEnabled = val } }
                ))

                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { enabled in
                        launchAtLogin = enabled
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = (SMAppService.mainApp.status == .enabled)
                        }
                    }
                ))
            }

            Section("Appearance & Stack") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Menu Bar Icon")
                        .font(.system(size: 13))

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 112), spacing: 8)], spacing: 8) {
                        ForEach(MenuBarIconStyle.allCases) { style in
                            let isSelected = appState.settings.menuBarIconStyle == style
                            Button {
                                appState.updateSettings { $0.menuBarIconStyle = style }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(nsImage: MenuBarIconRenderer.image(for: style, size: 18))
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)

                                    Text(style.rawValue)
                                        .font(.system(size: 11.5, weight: isSelected ? .semibold : .regular))
                                        .lineLimit(1)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.primary.opacity(0.05))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.10), lineWidth: isSelected ? 1.5 : 0.75)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 2)

                Picker("Shelf Appearance", selection: Binding(
                    get: { appState.settings.shelfAppearance },
                    set: { val in appState.updateSettings { $0.shelfAppearance = val } }
                )) {
                    ForEach(ShelfAppearance.allCases) { appearance in
                        Text(appearance.rawValue).tag(appearance)
                    }
                }

                Picker("Paste Stack Order", selection: Binding(
                    get: { appState.settings.pasteStackOrder },
                    set: { val in appState.updateSettings { $0.pasteStackOrder = val } }
                )) {
                    ForEach(PasteStackOrder.allCases) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
            }

            Section("History Retention") {
                HStack {
                    Picker("Keep history for", selection: Binding(
                        get: { appState.settings.retentionPolicy },
                        set: { val in appState.updateSettings { $0.retentionPolicy = val } }
                    )) {
                        ForEach(RetentionPolicy.allCases) { policy in
                            Text(policy.rawValue).tag(policy)
                        }
                    }

                    Spacer()

                    Button("Clear History...", role: .destructive) {
                        showClearAlert = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            appState.refreshAccessibilityStatus()
        }
        .onReceive(axPollTimer) { _ in
            appState.refreshAccessibilityStatus()
        }
        .alert("Clear Clipboard History?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                appState.clearHistory()
            }
        } message: {
            Text("Removes all unpinned history items. Items saved in Pinboards remain untouched.")
        }
    }
}

// MARK: - Shortcuts

struct ShortcutsSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Global Shortcuts") {
                HStack {
                    Text("Show / Hide CleanPaste")
                    Spacer()
                    ShortcutRecorderButton(
                        shortcut: Binding(
                            get: { appState.settings.openShelfShortcut },
                            set: { spec in appState.updateSettings { $0.openShelfShortcut = spec } }
                        )
                    )
                }

                HStack {
                    Text("Activate / Deactivate Paste Stack")
                    Spacer()
                    ShortcutRecorderButton(
                        shortcut: Binding(
                            get: { appState.settings.pasteStackShortcut },
                            set: { spec in appState.updateSettings { $0.pasteStackShortcut = spec } }
                        )
                    )
                }

                HStack {
                    Text("Paste Next from Stack")
                    Spacer()
                    ShortcutRecorderButton(
                        shortcut: Binding(
                            get: { appState.settings.pasteNextShortcut },
                            set: { spec in appState.updateSettings { $0.pasteNextShortcut = spec } }
                        )
                    )
                }

                HStack {
                    Spacer()
                    Button("Reset Defaults") {
                        appState.updateSettings {
                            $0.openShelfShortcut = .defaultOpenShelf
                            $0.pasteStackShortcut = .defaultPasteStack
                            $0.pasteNextShortcut = .defaultPasteNext
                        }
                    }
                    .controlSize(.small)
                }
            }

            Section("Shelf Navigation Shortcuts") {
                shortcutGuideRow("Quick Paste item 1–9", keys: "⌘1 … ⌘9")
                shortcutGuideRow("Quick Paste item 1–9 as Plain Text", keys: "⇧⌘1 … ⇧⌘9")
                shortcutGuideRow("Paste / Paste Plain Text", keys: "↩ / ⇧↩")
                shortcutGuideRow("Preview (Quick Look)", keys: "Space")
                shortcutGuideRow("Navigate Cards / Switch Pinboards", keys: "← → / ⌘← ⌘→")
                shortcutGuideRow("Edit / Rename / Copy / Delete", keys: "⌘E / ⌘R / ⌘C / ⌫")
            }
        }
        .formStyle(.grouped)
    }

    private func shortcutGuideRow(_ title: String, keys: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 12.5))
            Spacer()
            Text(keys)
                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.07)))
        }
    }
}

struct ShortcutRecorderButton: View {
    @Binding var shortcut: ShortcutSpec
    @State private var isRecording: Bool = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } label: {
            Text(isRecording ? "Press Shortcut..." : shortcut.displayString)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .frame(minWidth: 110)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isRecording ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(isRecording ? Color.accentColor : Color.primary.opacity(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape cancels recording
                stopRecording()
                return nil
            }
            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !flags.isEmpty else {
                NSSound.beep()
                return nil
            }
            let carbonMods = ShortcutSpec.carbonModifiers(from: flags)
            shortcut = ShortcutSpec(keyCode: UInt32(event.keyCode), carbonModifiers: carbonMods)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}

// MARK: - Rules / Privacy

struct RulesSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Privacy") {
                Toggle("Ignore confidential & password manager clips", isOn: Binding(
                    get: { appState.settings.ignoreSensitiveContent },
                    set: { val in appState.updateSettings { $0.ignoreSensitiveContent = val } }
                ))
                Text("Automatically skips clipboard content marked concealed or transient by password managers.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Excluded Applications") {
                List {
                    ForEach(appState.settings.excludedBundleIDs, id: \.self) { bundleID in
                        HStack(spacing: 10) {
                            if let icon = AppColorExtractor.shared.appIcon(for: bundleID) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 20, height: 20)
                            } else {
                                Image(systemName: "app.dashed")
                                    .frame(width: 20, height: 20)
                                    .foregroundStyle(.secondary)
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                Text(appName(for: bundleID))
                                    .font(.system(size: 12.5, weight: .medium))
                                Text(bundleID)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                appState.updateSettings { s in
                                    s.excludedBundleIDs.removeAll { $0 == bundleID }
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 180)

                HStack {
                    Button("Add Application...") {
                        browseForApp()
                    }
                    Menu("Add Running App") {
                        let running = NSWorkspace.shared.runningApplications
                            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
                            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
                        ForEach(running, id: \.processIdentifier) { app in
                            if let bid = app.bundleIdentifier,
                               bid != Bundle.main.bundleIdentifier {
                                Button(app.localizedName ?? bid) {
                                    appState.updateSettings { s in
                                        if !s.excludedBundleIDs.contains(bid) {
                                            s.excludedBundleIDs.append(bid)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
    }

    private func appName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
            return name
        }
        return bundleID.components(separatedBy: ".").last ?? bundleID
    }

    private func browseForApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK,
           let url = panel.url,
           let bundle = Bundle(url: url),
           let bundleID = bundle.bundleIdentifier {
            appState.updateSettings { s in
                if !s.excludedBundleIDs.contains(bundleID) {
                    s.excludedBundleIDs.append(bundleID)
                }
            }
        }
    }
}

// MARK: - About

struct AboutSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)

            Text("CleanPaste")
                .font(.system(size: 20, weight: .bold))

            Text("Version 1.0.0 — Clean-room macOS clipboard manager")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Text("\(appState.items.count) clips stored")
                Text("•")
                Text("\(appState.pinboards.count) pinboards")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Button("Open Data Folder in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([appState.storage.baseDirectory])
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .padding(.top, 4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
