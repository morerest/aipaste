import XCTest
@testable import aipaste

final class IgnoreRuleStoreTests: XCTestCase {
    func testStartsEmptyWithoutPresets() {
        let defaults = UserDefaults(suiteName: "com.eden.aipaste.tests.ignore.\(UUID().uuidString)")!
        let store = IgnoreRuleStore(defaults: defaults)
        XCTAssertTrue(store.list().isEmpty)
        XCTAssertFalse(store.isIgnored(bundleId: "com.apple.keychainaccess"))
        XCTAssertFalse(store.isIgnored(bundleId: "com.1password.1password"))
    }

    func testAddAndRemove() {
        let defaults = UserDefaults(suiteName: "com.eden.aipaste.tests.ignore.\(UUID().uuidString)")!
        let store = IgnoreRuleStore(defaults: defaults)
        store.add(bundleId: "com.example.app")
        XCTAssertTrue(store.isIgnored(bundleId: "com.example.app"))
        store.remove(bundleId: "com.example.app")
        XCTAssertFalse(store.isIgnored(bundleId: "com.example.app"))
    }

    func testPersistsDisplayName() {
        let defaults = UserDefaults(suiteName: "com.eden.aipaste.tests.ignore.\(UUID().uuidString)")!
        let store = IgnoreRuleStore(defaults: defaults)
        store.add(bundleId: "com.example.chat", displayName: "Chat App")
        XCTAssertEqual(store.displayName(for: "com.example.chat"), "Chat App")
        store.remove(bundleId: "com.example.chat")
        // After remove, falls back to resolver (unknown → raw ID).
        XCTAssertEqual(store.displayName(for: "com.example.chat"), "com.example.chat")
    }
}
