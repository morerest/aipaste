import Foundation

enum AppConstants {
    static let bundleID = "com.eden.aipaste"
    /// User-facing product name (spaced for readability). Technical IDs stay `aipaste`.
    static let displayName = "ai paste"
    static let appSupportFolderName = "aipaste"
    static let databaseFileName = "aipaste.sqlite"
    static let mediaFolderName = "media"
    static let dbFolderName = "db"

    static let monitorInterval: TimeInterval = 0.3
    static let defaultMaxSnippetCount = 500
    /// Default cap for user favorites (pinned snippets).
    static let defaultMaxFavoriteCount = 30
    static let listLimit = 100
    /// Max length for a favorite pin note (Swift `Character` count — CJK counts as 1).
    static let maxPinNoteLength = 10
    static let maxTextUTF8Bytes = 200_000
    static let maxImageBytes = 20 * 1024 * 1024

    /// UserDefaults keys
    enum DefaultsKey {
        static let maxSnippetCount = "maxSnippetCount"
        static let maxFavoriteCount = "maxFavoriteCount"
        static let ignoredBundleIds = "ignoredBundleIds"
        /// Optional friendly names keyed by bundle ID (picker / history), parallel to `ignoredBundleIds`.
        static let ignoredAppDisplayNames = "ignoredAppDisplayNames"
        static let launchAtLogin = "launchAtLogin"
        /// App UI language: `en` (default) or `zh-Hans`.
        static let appLanguage = "appLanguage"
        /// JSON-encoded `HotKeyConfig` for toggle-history global shortcut.
        static let toggleHistoryHotKey = "toggleHistoryHotKey"
    }
}
