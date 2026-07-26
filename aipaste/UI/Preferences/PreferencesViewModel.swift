import Foundation
import Combine

/// One row in the ignored-apps list (display name + bundle ID).
struct IgnoredAppItem: Identifiable, Hashable, Sendable {
    var id: String { bundleId }
    let bundleId: String
    let displayName: String
}

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var maxSnippetCount: Int
    @Published var maxFavoriteCount: Int
    @Published var launchAtLogin: Bool
    @Published var ignoredApps: [IgnoredAppItem]
    @Published var newIgnore: String = ""
    @Published var showManualBundleEntry = false
    @Published var ignoreStatusMessage: String?
    @Published var isAccessibilityTrusted: Bool
    @Published var language: AppLanguage
    @Published var hotKey: HotKeyConfig
    @Published var isRecordingHotKey = false
    @Published var hotKeyStatusMessage: String?
    @Published var workbenchTheme: WorkbenchTheme

    private let preferences: AppPreferences
    private let ignoreRules: IgnoreRuleStore
    private let store: SnippetStore
    private let onHotKeyChanged: (HotKeyConfig) -> Bool
    private let onThemeChanged: (WorkbenchTheme) -> Void
    private let onQuit: () -> Void
    private var ignoreStatusResetTask: Task<Void, Never>?

    var strings: SettingsStrings {
        L10n.settings(language)
    }

    var accessibilityDetail: String {
        strings.accessibilityDetail(trusted: isAccessibilityTrusted)
    }

    /// Running apps that can still be added to the ignore list.
    var runningAppCandidates: [AppIdentity] {
        AppIdentityResolver.runningApps(excludingBundleIds: Set(ignoredApps.map(\.bundleId)))
    }

    /// Apps that appeared as clipboard sources and are not yet ignored.
    var historyAppCandidates: [AppIdentity] {
        let ignored = Set(ignoredApps.map(\.bundleId))
        let apps = (try? store.distinctSourceApps()) ?? []
        var seen = Set<String>()
        var result: [AppIdentity] = []
        for app in apps {
            guard let bid = app.bundleId?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !bid.isEmpty,
                  bid != AppConstants.bundleID,
                  !ignored.contains(bid),
                  !seen.contains(bid)
            else { continue }
            seen.insert(bid)
            result.append(AppIdentityResolver.identity(bundleId: bid, preferredName: app.name))
        }
        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    init(
        preferences: AppPreferences,
        ignoreRules: IgnoreRuleStore,
        store: SnippetStore,
        onHotKeyChanged: @escaping (HotKeyConfig) -> Bool = { _ in true },
        onThemeChanged: @escaping (WorkbenchTheme) -> Void = { _ in },
        onQuit: @escaping () -> Void = {}
    ) {
        self.preferences = preferences
        self.ignoreRules = ignoreRules
        self.store = store
        self.onHotKeyChanged = onHotKeyChanged
        self.onThemeChanged = onThemeChanged
        self.onQuit = onQuit
        maxSnippetCount = preferences.maxSnippetCount
        maxFavoriteCount = preferences.maxFavoriteCount
        launchAtLogin = preferences.launchAtLogin
        ignoredApps = Self.makeIgnoredItems(from: ignoreRules.list(), ignoreRules: ignoreRules)
        language = preferences.appLanguage
        hotKey = preferences.toggleHistoryHotKey
        workbenchTheme = preferences.workbenchTheme
        isAccessibilityTrusted = preferences.accessibilityTrusted
    }

    func quitApp() {
        onQuit()
    }

    func applyCapacity() {
        preferences.maxSnippetCount = maxSnippetCount
        store.setMaxSnippetCount(maxSnippetCount)
    }

    func applyFavoriteCapacity() {
        preferences.maxFavoriteCount = maxFavoriteCount
        store.setMaxFavoriteCount(maxFavoriteCount)
    }

    func applyLaunch() {
        preferences.launchAtLogin = launchAtLogin
    }

    func applyLanguage() {
        preferences.appLanguage = language
    }

    func setLanguage(_ language: AppLanguage) {
        guard self.language != language else { return }
        self.language = language
        applyLanguage()
    }

    func setWorkbenchTheme(_ theme: WorkbenchTheme) {
        guard workbenchTheme != theme else { return }
        workbenchTheme = theme
        preferences.workbenchTheme = theme
        onThemeChanged(theme)
    }

    func beginHotKeyRecording() {
        hotKeyStatusMessage = nil
        isRecordingHotKey = true
    }

    func cancelHotKeyRecording() {
        isRecordingHotKey = false
    }

    /// Apply a newly captured shortcut. Returns false if registration failed.
    @discardableResult
    func applyHotKey(_ config: HotKeyConfig) -> Bool {
        isRecordingHotKey = false
        guard config.hasRequiredModifier else {
            hotKeyStatusMessage = strings.hotkeyNeedModifier
            return false
        }
        let previous = hotKey
        if !onHotKeyChanged(config) {
            // Re-register previous if new one failed.
            _ = onHotKeyChanged(previous)
            hotKeyStatusMessage = strings.hotkeyRegisterFailed
            return false
        }
        hotKey = config
        preferences.toggleHistoryHotKey = config
        hotKeyStatusMessage = nil
        return true
    }

    func resetHotKey() {
        applyHotKey(.default)
    }

    /// Add by bundle ID (picker or manual entry).
    @discardableResult
    func addIgnore(bundleId: String, preferredName: String? = nil) -> Bool {
        let id = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return false }

        if id == AppConstants.bundleID {
            showIgnoreStatus(strings.cannotIgnoreSelf)
            return false
        }
        if ignoreRules.isIgnored(bundleId: id) {
            showIgnoreStatus(strings.alreadyIgnored)
            return false
        }

        let name = preferredName?.trimmingCharacters(in: .whitespacesAndNewlines)
        ignoreRules.add(
            bundleId: id,
            displayName: (name?.isEmpty == false) ? name : nil
        )
        refreshIgnored()
        newIgnore = ""
        let display = ignoreRules.displayName(for: id)
        showIgnoreStatus(strings.addedIgnore(display))
        return true
    }

    /// Manual text-field path (legacy / advanced).
    func addIgnoreFromTextField() {
        addIgnore(bundleId: newIgnore)
    }

    func removeIgnore(_ id: String) {
        ignoreRules.remove(bundleId: id)
        refreshIgnored()
    }

    func clearHistory() {
        // Keep favorites — same policy as status-bar clear.
        try? store.deleteUnpinned()
    }

    func refreshAccessibilityLabel() {
        isAccessibilityTrusted = preferences.accessibilityTrusted
    }

    func refreshIgnored() {
        ignoredApps = Self.makeIgnoredItems(from: ignoreRules.list(), ignoreRules: ignoreRules)
    }

    private func showIgnoreStatus(_ message: String, duration: TimeInterval = 2.5) {
        ignoreStatusResetTask?.cancel()
        ignoreStatusMessage = message
        ignoreStatusResetTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            ignoreStatusMessage = nil
        }
    }

    private static func makeIgnoredItems(
        from bundleIds: [String],
        ignoreRules: IgnoreRuleStore
    ) -> [IgnoredAppItem] {
        bundleIds
            .map {
                IgnoredAppItem(
                    bundleId: $0,
                    displayName: ignoreRules.displayName(for: $0)
                )
            }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }
}
