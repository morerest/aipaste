import XCTest
@testable import clipai

final class SmokeTests: XCTestCase {
    func testConstants() {
        XCTAssertEqual(AppConstants.bundleID, "com.eden.clipai")
    }
}
