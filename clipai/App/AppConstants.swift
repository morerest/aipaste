import Foundation

enum AppConstants {
    static let bundleID = "com.eden.clipai"
    static let appSupportFolderName = "clipai"
    static let databaseFileName = "clipai.sqlite"
    static let mediaFolderName = "media"
    static let dbFolderName = "db"

    static let monitorInterval: TimeInterval = 0.3
    static let defaultMaxSnippetCount = 500
    static let listLimit = 100
    static let maxTextUTF8Bytes = 200_000
    static let maxImageBytes = 20 * 1024 * 1024

    /// UserDefaults keys (suite = bundleID when using suiteName)
    enum DefaultsKey {
        static let maxSnippetCount = "maxSnippetCount"
        static let ignoredBundleIds = "ignoredBundleIds"
        static let launchAtLogin = "launchAtLogin"
        static let hasSeededIgnoreList = "hasSeededIgnoreList"
    }
}
