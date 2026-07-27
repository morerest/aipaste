import AppKit
import Carbon
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var model: PreferencesViewModel
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var isShowingClearConfirmation = false

    private var s: SettingsStrings { model.strings }
    private var themeStyle: WorkbenchThemeStyle { model.workbenchTheme.style }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                appearanceSection
                historySection
                privacySection
                systemSection
                aboutSection
            }
            .padding(20)
        }
        .frame(width: 520, height: 600)
        .background { settingsWindowBackground }
        .tint(themeStyle.accent)
        .environment(\.colorScheme, themeStyle.interfaceColorScheme ?? systemColorScheme)
        .onAppear { model.refreshAccessibilityLabel() }
        .background(WindowTitleSetter(title: s.windowTitle))
        .background(SettingsWindowChromeSync(theme: model.workbenchTheme))
        .confirmationDialog(
            s.clearConfirmTitle,
            isPresented: $isShowingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(s.clearConfirmAction, role: .destructive) {
                model.clearHistory()
            }
            Button(s.clearConfirmCancel, role: .cancel) {}
        } message: {
            Text(s.clearConfirmMessage)
        }
        // Language only: force string refresh. Do NOT key on theme — rebuilding the
        // whole tree on skin change (or re-open) has caused blank white content.
        .id(model.language)
    }

    @ViewBuilder
    private var settingsWindowBackground: some View {
        if themeStyle.usesSystemGlass {
            Color(nsColor: .windowBackgroundColor)
        } else {
            ZStack {
                themeStyle.opaquePanelColor
                themeStyle.panelGradient.opacity(themeStyle.panelGradientOpacity * 0.55)
            }
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        SettingsCard(
            title: s.appearanceSection,
            systemImage: "paintpalette.fill",
            style: themeStyle
        ) {
            VStack(alignment: .leading, spacing: 12) {
                WorkbenchThemePicker(
                    selected: model.workbenchTheme,
                    name: { s.workbenchThemeName($0) },
                    tagline: { s.workbenchThemeTagline($0) },
                    currentBadge: s.currentThemeBadge,
                    selectedA11y: s.selectedThemeA11y,
                    onSelect: { model.setWorkbenchTheme($0) }
                )
                Text(s.appearanceFooter)
                    .font(.caption)
                    .foregroundStyle(settingsSecondaryText)
            }
        }
    }

    private var historySection: some View {
        SettingsCard(
            title: s.historySection,
            systemImage: "clock.arrow.circlepath",
            style: themeStyle
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.maxItemsTitle)
                            .font(.body)
                        Text(s.maxItemsFooter)
                            .font(.caption)
                            .foregroundStyle(settingsSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Stepper(value: $model.maxSnippetCount, in: 50...5000, step: 50) {
                        Text("\(model.maxSnippetCount)")
                            .font(.body.monospacedDigit().weight(.medium))
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                    .fixedSize()
                    .onChange(of: model.maxSnippetCount) { _ in model.applyCapacity() }
                }

                Divider()
                    .overlay(themeStyle.dividerColor)

                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.maxFavoritesTitle)
                            .font(.body)
                        Text(s.maxFavoritesFooter)
                            .font(.caption)
                            .foregroundStyle(settingsSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Stepper(value: $model.maxFavoriteCount, in: 5...200, step: 5) {
                        Text("\(model.maxFavoriteCount)")
                            .font(.body.monospacedDigit().weight(.medium))
                            .frame(minWidth: 44, alignment: .trailing)
                    }
                    .fixedSize()
                    .onChange(of: model.maxFavoriteCount) { _ in model.applyFavoriteCapacity() }
                }

                Divider()
                    .overlay(themeStyle.dividerColor)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.clearHistoryTitle)
                            .font(.body)
                        Text(s.clearHistoryFooter)
                            .font(.caption)
                            .foregroundStyle(settingsSecondaryText)
                    }
                    Spacer(minLength: 12)
                    Button(s.clearHistoryButton, role: .destructive) {
                        isShowingClearConfirmation = true
                    }
                    .controlSize(.regular)
                }
            }
        }
    }

    private var privacySection: some View {
        SettingsCard(
            title: s.privacySection,
            systemImage: "hand.raised.fill",
            style: themeStyle,
            tint: Color(red: 0.95, green: 0.40, blue: 0.30)
        ) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.ignoredAppsTitle)
                        .font(.body)
                    Text(s.ignoredAppsFooter)
                        .font(.caption)
                        .foregroundStyle(settingsSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 0) {
                    if model.ignoredApps.isEmpty {
                        Text(s.ignoredAppsEmpty)
                            .font(.callout)
                            .foregroundStyle(settingsSecondaryText.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 12)
                    } else {
                        ForEach(Array(model.ignoredApps.enumerated()), id: \.element.id) { index, item in
                            IgnoreAppRow(
                                displayName: item.displayName,
                                bundleId: item.bundleId,
                                removeHelp: s.removeHelp,
                                secondaryText: settingsSecondaryText
                            ) {
                                model.removeIgnore(item.bundleId)
                            }
                            if index < model.ignoredApps.count - 1 {
                                Divider()
                                    .overlay(themeStyle.dividerColor)
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(settingsWellFill)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(themeStyle.borderColor, lineWidth: 1)
                }

                HStack(spacing: 8) {
                    // AppKit menu avoids SwiftUI Menu body evaluation crashes on some macOS builds.
                    AddIgnoredAppMenuButton(
                        title: s.addAppButton,
                        runningSectionTitle: s.runningAppsSection,
                        historySectionTitle: s.historyAppsSection,
                        noRunningTitle: s.noRunningApps,
                        noHistoryTitle: s.noHistoryApps,
                        runningApps: { model.runningAppCandidates },
                        historyApps: { model.historyAppCandidates },
                        onPick: { app in
                            model.addIgnore(bundleId: app.bundleId, preferredName: app.name)
                        }
                    )
                    .frame(height: 24)

                    Button {
                        model.showManualBundleEntry.toggle()
                    } label: {
                        Text(model.showManualBundleEntry ? s.hideBundleIdButton : s.enterBundleIdButton)
                    }
                    .controlSize(.regular)
                }

                if model.showManualBundleEntry {
                    HStack(spacing: 8) {
                        TextField(
                            "",
                            text: $model.newIgnore,
                            prompt: Text(s.bundleIdPrompt)
                        )
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit { model.addIgnoreFromTextField() }

                        Button(s.addButton) {
                            model.addIgnoreFromTextField()
                        }
                        .disabled(model.newIgnore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if let message = model.ignoreStatusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(settingsSecondaryText)
                        .transition(.opacity)
                }
            }
        }
    }

    private var systemSection: some View {
        SettingsCard(
            title: s.systemSection,
            systemImage: "gearshape.fill",
            style: themeStyle
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.languageTitle)
                            .font(.body)
                        Text(s.languageFooter)
                            .font(.caption)
                            .foregroundStyle(settingsSecondaryText)
                    }
                    Spacer(minLength: 12)
                    Picker("", selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }

                Divider()
                    .overlay(themeStyle.dividerColor)

                hotkeyRow

                Divider()
                    .overlay(themeStyle.dividerColor)

                Toggle(isOn: $model.launchAtLogin) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.launchAtLoginTitle)
                            .font(.body)
                        Text(s.launchAtLoginFooter)
                            .font(.caption)
                            .foregroundStyle(settingsSecondaryText)
                    }
                }
                .toggleStyle(.switch)
                .onChange(of: model.launchAtLogin) { _ in model.applyLaunch() }

                Divider()
                    .overlay(themeStyle.dividerColor)

                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(model.isAccessibilityTrusted ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.accessibilityTitle)
                            .font(.body)
                        Text(model.accessibilityDetail)
                            .font(.caption)
                            .foregroundStyle(settingsSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    Button(s.accessibilityOpen) {
                        AccessibilityPermission.openSystemSettings()
                        model.refreshAccessibilityLabel()
                    }
                }
            }
        }
    }

    private var hotkeyRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.hotkeyTitle)
                        .font(.body)
                    Text(s.hotkeyFooter)
                        .font(.caption)
                        .foregroundStyle(settingsSecondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                HotKeyRecorderControl(
                    display: model.hotKey.displayString,
                    isRecording: model.isRecordingHotKey,
                    recordPrompt: s.hotkeyRecordPrompt,
                    idleHint: s.hotkeyClickToRecord,
                    accent: themeStyle.accent,
                    primaryText: settingsPrimaryText,
                    onStartRecording: { model.beginHotKeyRecording() },
                    onCancelRecording: { model.cancelHotKeyRecording() },
                    onCapture: { model.applyHotKey($0) }
                )

                Button(s.hotkeyReset) {
                    model.resetHotKey()
                }
                .disabled(model.hotKey == .default || model.isRecordingHotKey)
            }

            if let message = model.hotKeyStatusMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var aboutSection: some View {
        SettingsCard(
            title: s.aboutSection,
            systemImage: "info.circle.fill",
            style: themeStyle
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            BrandWordmark(fontSize: 16, themeStyle: themeStyle)
                            Text("Phase 1")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(settingsSecondaryText)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(settingsPrimaryText.opacity(0.06), in: Capsule())
                        }
                        Text(s.aboutTagline)
                            .font(.caption)
                            .foregroundStyle(settingsSecondaryText)
                    }
                }

                Divider()
                    .overlay(themeStyle.dividerColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(s.dataDirectory)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(settingsSecondaryText)
                    Text("~/Library/Application Support/aipaste/")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(settingsPrimaryText.opacity(0.85))
                        .textSelection(.enabled)
                }

                Divider()
                    .overlay(themeStyle.dividerColor)

                // Same row layout as Clear History; force a solid red control —
                // plain `role: .destructive` renders as muted gray on recent macOS.
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(s.quitTitle)
                            .font(.body)
                        Text(s.quitFooter)
                            .font(.caption)
                            .foregroundStyle(settingsSecondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 12)
                    Button {
                        model.quitApp()
                    } label: {
                        Text(s.quitButton)
                            .fontWeight(.medium)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.90, green: 0.28, blue: 0.28))
                    .controlSize(.regular)
                }
            }
        }
    }

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { model.language },
            set: { model.setLanguage($0) }
        )
    }

    private var settingsPrimaryText: Color {
        themeStyle.usesSystemGlass ? Color.primary : themeStyle.primaryText
    }

    private var settingsSecondaryText: Color {
        themeStyle.usesSystemGlass ? Color.secondary : themeStyle.secondaryText
    }

    private var settingsWellFill: Color {
        themeStyle.usesSystemGlass
            ? Color(nsColor: .controlBackgroundColor)
            : themeStyle.controlColor.opacity(0.85)
    }
}

// MARK: - Building blocks

/// AppKit button + `NSMenu` — builds candidates only when the user clicks (not during SwiftUI body).
private struct AddIgnoredAppMenuButton: NSViewRepresentable {
    let title: String
    let runningSectionTitle: String
    let historySectionTitle: String
    let noRunningTitle: String
    let noHistoryTitle: String
    let runningApps: () -> [AppIdentity]
    let historyApps: () -> [AppIdentity]
    let onPick: (AppIdentity) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: title, target: context.coordinator, action: #selector(Coordinator.showMenu(_:)))
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        button.controlSize = .regular
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.parent = self
        context.coordinator.button = button
        if button.title != title {
            button.title = title
        }
    }

    final class Coordinator: NSObject {
        var parent: AddIgnoredAppMenuButton
        weak var button: NSButton?

        init(parent: AddIgnoredAppMenuButton) {
            self.parent = parent
        }

        @objc func showMenu(_ sender: NSButton) {
            let menu = NSMenu()
            menu.autoenablesItems = false

            addHeader(parent.runningSectionTitle, to: menu)
            let running = parent.runningApps()
            if running.isEmpty {
                addDisabled(parent.noRunningTitle, to: menu)
            } else {
                for app in running {
                    menu.addItem(makeItem(for: app))
                }
            }

            menu.addItem(.separator())

            addHeader(parent.historySectionTitle, to: menu)
            let history = parent.historyApps()
            if history.isEmpty {
                addDisabled(parent.noHistoryTitle, to: menu)
            } else {
                for app in history {
                    menu.addItem(makeItem(for: app))
                }
            }

            let point = NSPoint(x: 0, y: sender.bounds.height + 2)
            menu.popUp(positioning: nil, at: point, in: sender)
        }

        private func addHeader(_ title: String, to menu: NSMenu) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        private func addDisabled(_ title: String, to menu: NSMenu) {
            let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }

        private func makeItem(for app: AppIdentity) -> NSMenuItem {
            let item = NSMenuItem(
                title: app.name,
                action: #selector(pick(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = app
            item.toolTip = app.bundleId
            item.isEnabled = true
            if let icon = SourceAppIconCache.menuIcon(forBundleId: app.bundleId, pointSize: 14) {
                item.image = icon
            }
            return item
        }

        @objc func pick(_ sender: NSMenuItem) {
            guard let app = sender.representedObject as? AppIdentity else { return }
            parent.onPick(app)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    let style: WorkbenchThemeStyle
    var tint: Color? = nil
    @ViewBuilder let content: Content

    private var iconTint: Color { tint ?? style.accent }

    private var cardFill: Color {
        style.usesSystemGlass
            ? Color(nsColor: .controlBackgroundColor)
            : style.cardColor
    }

    private var titleColor: Color {
        style.usesSystemGlass ? Color.primary : style.primaryText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(iconTint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(title)
                    .font(.headline)
                    .foregroundStyle(titleColor)
            }

            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(cardFill)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(style.borderColor, lineWidth: 1)
                }
        }
    }
}

private struct IgnoreAppRow: View {
    let displayName: String
    let bundleId: String
    let removeHelp: String
    var secondaryText: Color = .secondary
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            appIcon
                .frame(width: 26, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text(displayName)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)

                // Hide duplicate monospaced line when name resolution fell back to the ID.
                if displayName != bundleId {
                    Text(bundleId)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .help("\(displayName)\n\(bundleId)")

            Spacer(minLength: 8)

            Button(role: .destructive, action: onRemove) {
                Image(systemName: "minus.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(secondaryText)
                    .font(.system(size: 15))
            }
            .buttonStyle(.plain)
            .help(removeHelp)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var appIcon: some View {
        if let icon = SourceAppIconCache.icon(forBundleId: bundleId) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(secondaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    secondaryText.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
        }
    }
}

/// Keeps the hosting NSWindow title in sync with the selected language.
private struct WindowTitleSetter: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.title = title
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            nsView.window?.title = title
        }
    }
}

/// Syncs the AppKit window chrome (title bar appearance + background) with the workbench skin.
private struct SettingsWindowChromeSync: NSViewRepresentable {
    let theme: WorkbenchTheme

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { Self.apply(theme, to: view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { Self.apply(theme, to: nsView.window) }
    }

    private static func apply(_ theme: WorkbenchTheme, to window: NSWindow?) {
        guard let window else { return }
        let style = theme.style
        if style.usesSystemGlass {
            window.appearance = nil
            window.backgroundColor = .windowBackgroundColor
            return
        }
        switch style.interfaceColorScheme {
        case .dark:
            window.appearance = NSAppearance(named: .darkAqua)
        case .light:
            window.appearance = NSAppearance(named: .aqua)
        default:
            window.appearance = nil
        }
        window.backgroundColor = NSColor(style.opaquePanelColor)
    }
}

/// Click to record a global shortcut; Esc cancels.
private struct HotKeyRecorderControl: View {
    let display: String
    let isRecording: Bool
    let recordPrompt: String
    let idleHint: String
    var accent: Color = .accentColor
    var primaryText: Color = .primary
    let onStartRecording: () -> Void
    let onCancelRecording: () -> Void
    let onCapture: (HotKeyConfig) -> Void

    @State private var monitor: Any?

    var body: some View {
        Button {
            if isRecording {
                onCancelRecording()
            } else {
                onStartRecording()
            }
        } label: {
            Text(isRecording ? recordPrompt : display)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(primaryText)
                .frame(minWidth: 108)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(primaryText.opacity(isRecording ? 0.12 : 0.06))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isRecording ? accent.opacity(0.7) : primaryText.opacity(0.10),
                            lineWidth: isRecording ? 1.5 : 1
                        )
                }
        }
        .buttonStyle(.plain)
        .help(isRecording ? recordPrompt : idleHint)
        .onChange(of: isRecording) { recording in
            if recording {
                installMonitor()
            } else {
                removeMonitor()
            }
        }
        .onDisappear {
            removeMonitor()
            if isRecording {
                onCancelRecording()
            }
        }
    }

    private func installMonitor() {
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc cancels recording.
            if event.keyCode == UInt16(kVK_Escape) {
                onCancelRecording()
                return nil
            }
            if let config = HotKeyConfig.from(event: event) {
                onCapture(config)
                return nil
            }
            // Swallow other keys while recording so they don't type into fields.
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
