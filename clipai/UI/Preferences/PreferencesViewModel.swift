import Foundation
import Combine

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var maxSnippetCount: Int
    @Published var launchAtLogin: Bool
    @Published var ignored: [String]
    @Published var newIgnore: String = ""
    @Published var accessibilityLabel: String

    private let preferences: AppPreferences
    private let ignoreRules: IgnoreRuleStore
    private let store: SnippetStore

    init(preferences: AppPreferences, ignoreRules: IgnoreRuleStore, store: SnippetStore) {
        self.preferences = preferences
        self.ignoreRules = ignoreRules
        self.store = store
        maxSnippetCount = preferences.maxSnippetCount
        launchAtLogin = preferences.launchAtLogin
        ignored = ignoreRules.list()
        accessibilityLabel = preferences.accessibilityTrusted
            ? "Accessibility: enabled"
            : "Accessibility: not enabled (paste degrades to copy)"
    }

    func applyCapacity() {
        preferences.maxSnippetCount = maxSnippetCount
        store.setMaxSnippetCount(maxSnippetCount)
    }

    func applyLaunch() {
        preferences.launchAtLogin = launchAtLogin
    }

    func addIgnore() {
        let id = newIgnore.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        ignoreRules.add(bundleId: id)
        ignored = ignoreRules.list()
        newIgnore = ""
    }

    func removeIgnore(_ id: String) {
        ignoreRules.remove(bundleId: id)
        ignored = ignoreRules.list()
    }

    func clearHistory() {
        try? store.deleteAll()
    }

    func refreshAccessibilityLabel() {
        accessibilityLabel = preferences.accessibilityTrusted
            ? "Accessibility: enabled"
            : "Accessibility: not enabled (paste degrades to copy)"
    }
}
