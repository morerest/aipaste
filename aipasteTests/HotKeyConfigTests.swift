import XCTest
@testable import aipaste

final class HotKeyConfigTests: XCTestCase {
    func testDefaultDisplayStringIsShiftCommandV() {
        XCTAssertEqual(HotKeyConfig.default.displayString, "⇧⌘V")
    }

    func testRequiresModifier() {
        var bare = HotKeyConfig(keyCode: HotKeyConfig.default.keyCode, carbonModifiers: 0)
        XCTAssertFalse(bare.hasRequiredModifier)

        XCTAssertTrue(HotKeyConfig.default.hasRequiredModifier)
    }
}
