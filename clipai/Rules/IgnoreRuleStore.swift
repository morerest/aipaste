import Foundation

final class IgnoreRuleStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = AppConstants.DefaultsKey.ignoredBundleIds
    private let seededKey = AppConstants.DefaultsKey.hasSeededIgnoreList

    init(defaults: UserDefaults = UserDefaults(suiteName: AppConstants.bundleID) ?? .standard,
         seedIfNeeded: Bool = true) {
        self.defaults = defaults
        if seedIfNeeded, defaults.bool(forKey: seededKey) == false {
            defaults.set(DefaultIgnoreList.bundleIds, forKey: key)
            defaults.set(true, forKey: seededKey)
        }
    }

    func list() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func isIgnored(bundleId: String?) -> Bool {
        guard let bundleId, !bundleId.isEmpty else { return false }
        return Set(list()).contains(bundleId)
    }

    func add(bundleId: String) {
        var set = Set(list())
        set.insert(bundleId)
        defaults.set(Array(set).sorted(), forKey: key)
    }

    func remove(bundleId: String) {
        defaults.set(list().filter { $0 != bundleId }, forKey: key)
    }
}
