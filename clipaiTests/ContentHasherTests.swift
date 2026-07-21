import XCTest
@testable import clipai

final class ContentHasherTests: XCTestCase {
    func testTextHashStable() {
        let a = ContentHasher.hashText("hello")
        let b = ContentHasher.hashText("hello")
        XCTAssertEqual(a, b)
        XCTAssertFalse(a.isEmpty)
    }

    func testTextHashDiffers() {
        XCTAssertNotEqual(ContentHasher.hashText("a"), ContentHasher.hashText("b"))
    }

    func testImageHashStable() {
        let data = Data([0x01, 0x02, 0x03])
        XCTAssertEqual(ContentHasher.hashImage(data), ContentHasher.hashImage(data))
    }
}
