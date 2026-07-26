import Foundation

final class IgnoreRuleStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = AppConstants.DefaultsKey.ignoredBundleIds
    private let namesKey = AppConstants.DefaultsKey.ignoredAppDisplayNames

    /// Former Phase 1 password-manager seeds — stripped once so existing installs match “no presets”.
    private static let legacyPresetBundleIds: Set<String> = [
        "com.apple.keychainaccess",
        "com.1password.1password",
        "com.1password.1password-launcher",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.bitwarden.desktop.safari",
        "org.keepassxc.keepassxc",
        "com.lastpass.LastPass",
    ]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // One-time migration from the invalid suiteName == bundleID domain (never worked reliably).
        Self.migrateFromBrokenSuiteIfNeeded(into: defaults)
        Self.removeLegacyPresetsIfNeeded(from: defaults)
    }

    /// Drop old auto-seeded password-manager IDs; keep anything the user added themselves.
    private static func removeLegacyPresetsIfNeeded(from defaults: UserDefaults) {
        let flag = "didRemoveIgnorePresets"
        guard defaults.bool(forKey: flag) == false else { return }
        defaults.set(true, forKey: flag)

        let key = AppConstants.DefaultsKey.ignoredBundleIds
        let namesKey = AppConstants.DefaultsKey.ignoredAppDisplayNames
        let current = defaults.stringArray(forKey: key) ?? []
        guard !current.isEmpty else { return }

        let kept = current.filter { !legacyPresetBundleIds.contains($0) }
        defaults.set(kept, forKey: key)

        if var names = defaults.dictionary(forKey: namesKey) as? [String: String] {
            for id in legacyPresetBundleIds {
                names.removeValue(forKey: id)
            }
            defaults.set(names, forKey: namesKey)
        }
    }

    /// Older builds used `UserDefaults(suiteName: com.eden.aipaste)`, which macOS rejects.
    private static func migrateFromBrokenSuiteIfNeeded(into defaults: UserDefaults) {
        let flag = "didMigrateIgnoreFromBundleSuite"
        guard defaults.bool(forKey: flag) == false else { return }
        defer { defaults.set(true, forKey: flag) }

        guard let suite = UserDefaults(suiteName: AppConstants.bundleID) else { return }
        if defaults.object(forKey: AppConstants.DefaultsKey.ignoredBundleIds) == nil,
           let ids = suite.stringArray(forKey: AppConstants.DefaultsKey.ignoredBundleIds) {
            defaults.set(ids, forKey: AppConstants.DefaultsKey.ignoredBundleIds)
        }
        if defaults.object(forKey: AppConstants.DefaultsKey.ignoredAppDisplayNames) == nil,
           let names = suite.dictionary(forKey: AppConstants.DefaultsKey.ignoredAppDisplayNames) {
            defaults.set(names, forKey: AppConstants.DefaultsKey.ignoredAppDisplayNames)
        }
        let prefKeys = [
            AppConstants.DefaultsKey.maxSnippetCount,
            AppConstants.DefaultsKey.launchAtLogin,
            AppConstants.DefaultsKey.appLanguage,
            AppConstants.DefaultsKey.toggleHistoryHotKey,
        ]
        for k in prefKeys where defaults.object(forKey: k) == nil {
            if let value = suite.object(forKey: k) {
                defaults.set(value, forKey: k)
            }
        }
    }

    func list() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func isIgnored(bundleId: String?) -> Bool {
        guard let bundleId, !bundleId.isEmpty else { return false }
        return Set(list()).contains(bundleId)
    }

    func add(bundleId: String, displayName: String? = nil) {
        var set = Set(list())
        set.insert(bundleId)
        defaults.set(Array(set).sorted(), forKey: key)

        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            var names = storedDisplayNames()
            names[bundleId] = name
            defaults.set(names, forKey: namesKey)
        }
    }

    func remove(bundleId: String) {
        defaults.set(list().filter { $0 != bundleId }, forKey: key)
        var names = storedDisplayNames()
        if names.removeValue(forKey: bundleId) != nil {
            defaults.set(names, forKey: namesKey)
        }
    }

    /// Best display name: user/picker-provided → installed app → known seed → raw ID.
    func displayName(for bundleId: String) -> String {
        if let stored = storedDisplayNames()[bundleId] {
            let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return AppIdentityResolver.displayName(forBundleId: bundleId)
    }

    private func storedDisplayNames() -> [String: String] {
        defaults.dictionary(forKey: namesKey) as? [String: String] ?? [:]
    }
}
