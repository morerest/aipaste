import XCTest
@testable import clipai

final class IgnoreRuleStoreTests: XCTestCase {
    func testDefaultContainsKeychain() {
        let defaults = UserDefaults(suiteName: "com.eden.clipai.tests.ignore.\(UUID().uuidString)")!
        let store = IgnoreRuleStore(defaults: defaults, seedIfNeeded: true)
        XCTAssertTrue(store.isIgnored(bundleId: "com.apple.keychainaccess"))
    }

    func testAddAndRemove() {
        let defaults = UserDefaults(suiteName: "com.eden.clipai.tests.ignore.\(UUID().uuidString)")!
        let store = IgnoreRuleStore(defaults: defaults, seedIfNeeded: false)
        store.add(bundleId: "com.example.app")
        XCTAssertTrue(store.isIgnored(bundleId: "com.example.app"))
        store.remove(bundleId: "com.example.app")
        XCTAssertFalse(store.isIgnored(bundleId: "com.example.app"))
    }
}
