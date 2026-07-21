import Foundation
import ServiceManagement

final class AppPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppConstants.bundleID) ?? .standard) {
        self.defaults = defaults
        if defaults.object(forKey: AppConstants.DefaultsKey.maxSnippetCount) == nil {
            defaults.set(AppConstants.defaultMaxSnippetCount, forKey: AppConstants.DefaultsKey.maxSnippetCount)
        }
    }

    var maxSnippetCount: Int {
        get {
            let v = defaults.integer(forKey: AppConstants.DefaultsKey.maxSnippetCount)
            return v > 0 ? v : AppConstants.defaultMaxSnippetCount
        }
        set { defaults.set(max(1, newValue), forKey: AppConstants.DefaultsKey.maxSnippetCount) }
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
                    NSLog("clipai launch-at-login error: \(error)")
                }
            }
        }
    }

    var accessibilityTrusted: Bool {
        AccessibilityPermission.isTrusted(prompt: false)
    }
}
