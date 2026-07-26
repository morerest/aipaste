import XCTest
@testable import aipaste

final class SmokeTests: XCTestCase {
    func testConstants() {
        XCTAssertEqual(AppConstants.bundleID, "com.eden.aipaste")
    }
}
