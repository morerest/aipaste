import XCTest
@testable import clipai

final class SnippetStoreTests: XCTestCase {
    var tempRoot: URL!
    var store: SnippetStore!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipai-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let paths = AppPaths(root: tempRoot)
        try paths.ensureDirectories()
        let db = try Database(path: paths.databaseFile)
        let media = MediaStore(directory: paths.mediaDirectory)
        store = SnippetStore(database: db, mediaStore: media, maxSnippetCount: 3)
    }

    override func tearDownWithError() throws {
        store = nil
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testUpsertTextAndList() throws {
        let s = Snippet.makeText(body: "hello", hash: "h1")
        try store.upsert(s)
        let list = try store.list(query: nil, limit: 10)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].textBody, "hello")
    }

    func testDedupeRefreshesUpdatedAtNotDuplicate() throws {
        var first = Snippet.makeText(body: "same", hash: "same-hash")
        first.updatedAt = Date(timeIntervalSince1970: 1000)
        try store.upsert(first)
        Thread.sleep(forTimeInterval: 0.01)
        let second = Snippet.makeText(body: "same", hash: "same-hash")
        try store.upsert(second)
        let list = try store.list(query: nil, limit: 10)
        XCTAssertEqual(list.count, 1)
        XCTAssertGreaterThan(list[0].updatedAt, first.updatedAt)
    }

    func testSearchByPreview() throws {
        try store.upsert(Snippet.makeText(body: "alpha one", hash: "a"))
        try store.upsert(Snippet.makeText(body: "beta two", hash: "b"))
        let list = try store.list(query: "beta", limit: 10)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].textBody, "beta two")
    }

    func testCapacityPrunesOldest() throws {
        try store.upsert(Snippet.makeText(body: "1", hash: "1", updatedAt: Date(timeIntervalSince1970: 1)))
        try store.upsert(Snippet.makeText(body: "2", hash: "2", updatedAt: Date(timeIntervalSince1970: 2)))
        try store.upsert(Snippet.makeText(body: "3", hash: "3", updatedAt: Date(timeIntervalSince1970: 3)))
        try store.upsert(Snippet.makeText(body: "4", hash: "4", updatedAt: Date(timeIntervalSince1970: 4)))
        let list = try store.list(query: nil, limit: 10)
        XCTAssertEqual(list.count, 3)
        XCTAssertFalse(list.contains { $0.contentHash == "1" })
    }

    func testDeleteRemovesRow() throws {
        let s = Snippet.makeText(body: "x", hash: "x")
        try store.upsert(s)
        try store.delete(id: s.id)
        XCTAssertTrue(try store.list(query: nil, limit: 10).isEmpty)
    }
}
