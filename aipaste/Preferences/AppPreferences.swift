import Foundation
import ServiceManagement

final class AppPreferences {
    private let defaults: UserDefaults

    /// Uses `.standard` — `UserDefaults(suiteName: bundleID)` is invalid on macOS
    /// ("will not work") and can make settings appear broken.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        Self.migrateFromBrokenSuiteIfNeeded(into: defaults)
        if defaults.object(forKey: AppConstants.DefaultsKey.maxSnippetCount) == nil {
            defaults.set(AppConstants.defaultMaxSnippetCount, forKey: AppConstants.DefaultsKey.maxSnippetCount)
        }
        if defaults.object(forKey: AppConstants.DefaultsKey.maxFavoriteCount) == nil {
            defaults.set(AppConstants.defaultMaxFavoriteCount, forKey: AppConstants.DefaultsKey.maxFavoriteCount)
        }
    }

    private static func migrateFromBrokenSuiteIfNeeded(into defaults: UserDefaults) {
        let flag = "didMigratePrefsFromBundleSuite"
        guard defaults.bool(forKey: flag) == false else { return }
        defer { defaults.set(true, forKey: flag) }
        guard let suite = UserDefaults(suiteName: AppConstants.bundleID) else { return }
        let keys = [
            AppConstants.DefaultsKey.maxSnippetCount,
            AppConstants.DefaultsKey.maxFavoriteCount,
            AppConstants.DefaultsKey.launchAtLogin,
            AppConstants.DefaultsKey.appLanguage,
            AppConstants.DefaultsKey.toggleHistoryHotKey,
            AppConstants.DefaultsKey.workbenchTheme,
        ]
        for key in keys where defaults.object(forKey: key) == nil {
            if let value = suite.object(forKey: key) {
                defaults.set(value, forKey: key)
            }
        }
    }

    var maxSnippetCount: Int {
        get {
            let v = defaults.integer(forKey: AppConstants.DefaultsKey.maxSnippetCount)
            return v > 0 ? v : AppConstants.defaultMaxSnippetCount
        }
        set { defaults.set(max(1, newValue), forKey: AppConstants.DefaultsKey.maxSnippetCount) }
    }

    /// Maximum number of pinned favorites (default 30).
    var maxFavoriteCount: Int {
        get {
            let v = defaults.integer(forKey: AppConstants.DefaultsKey.maxFavoriteCount)
            return v > 0 ? v : AppConstants.defaultMaxFavoriteCount
        }
        set { defaults.set(max(1, min(200, newValue)), forKey: AppConstants.DefaultsKey.maxFavoriteCount) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: AppConstants.DefaultsKey.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: AppConstants.DefaultsKey.launchAtLogin)
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    NSLog("aipaste launch-at-login error: \(error)")
                }
            }
        }
    }

    var accessibilityTrusted: Bool {
        AccessibilityPermission.isTrusted(prompt: false)
    }

    /// UI language for Settings (and other in-app chrome). Defaults to English.
    var appLanguage: AppLanguage {
        get {
            AppLanguage.resolve(stored: defaults.string(forKey: AppConstants.DefaultsKey.appLanguage))
        }
        set {
            defaults.set(newValue.rawValue, forKey: AppConstants.DefaultsKey.appLanguage)
        }
    }

    /// Global shortcut that toggles the clipboard workbench. Defaults to ⇧⌘V.
    var toggleHistoryHotKey: HotKeyConfig {
        get {
            guard
                let data = defaults.data(forKey: AppConstants.DefaultsKey.toggleHistoryHotKey),
                let config = try? JSONDecoder().decode(HotKeyConfig.self, from: data)
            else {
                return .default
            }
            return config
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: AppConstants.DefaultsKey.toggleHistoryHotKey)
            }
        }
    }

    var workbenchTheme: WorkbenchTheme {
        get {
            guard let raw = defaults.string(forKey: AppConstants.DefaultsKey.workbenchTheme),
                  let theme = WorkbenchTheme(rawValue: raw)
            else { return .systemGlass }
            return theme
        }
        set {
            defaults.set(newValue.rawValue, forKey: AppConstants.DefaultsKey.workbenchTheme)
        }
    }
}
