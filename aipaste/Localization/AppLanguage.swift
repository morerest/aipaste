import Foundation

/// In-app UI language. Defaults to English; user can switch in Settings.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    /// Segmented control / menu labels (always bilingual so either locale can find the switch).
    var displayName: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    static func resolve(stored: String?) -> AppLanguage {
        guard let stored, let language = AppLanguage(rawValue: stored) else {
            return .english
        }
        return language
    }
}
