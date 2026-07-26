import AppKit
import SQLite3
import XCTest
@testable import aipaste

final class SnippetStoreTests: XCTestCase {
    var tempRoot: URL!
    var store: SnippetStore!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("aipaste-tests-\(UUID().uuidString)", isDirectory: true)
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

    func testFilterBySourceAppName() throws {
        try store.upsert(Snippet.makeText(body: "from wechat", hash: "w", sourceAppName: "微信"))
        try store.upsert(Snippet.makeText(body: "from notes", hash: "n", sourceAppName: "Notes"))
        try store.upsert(Snippet.makeText(body: "unknown", hash: "u"))

        let wechat = try store.list(query: nil, sourceAppName: "微信", limit: 10)
        XCTAssertEqual(wechat.map(\.textBody), ["from wechat"])

        let notes = try store.list(query: nil, sourceAppName: "Notes", limit: 10)
        XCTAssertEqual(notes.map(\.textBody), ["from notes"])
    }

    func testSearchAndAppFilterCombine() throws {
        try store.upsert(Snippet.makeText(body: "alpha from wechat", hash: "w1", sourceAppName: "微信"))
        try store.upsert(Snippet.makeText(body: "beta from wechat", hash: "w2", sourceAppName: "微信"))
        try store.upsert(Snippet.makeText(body: "alpha from notes", hash: "n1", sourceAppName: "Notes"))

        let list = try store.list(query: "alpha", sourceAppName: "微信", limit: 10)
        XCTAssertEqual(list.map(\.textBody), ["alpha from wechat"])
    }

    func testDistinctSourceAppsOrderedByRecent() throws {
        try store.upsert(
            Snippet.makeText(body: "old", hash: "1", updatedAt: Date(timeIntervalSince1970: 1), sourceAppName: "Notes")
        )
        try store.upsert(
            Snippet.makeText(body: "new", hash: "2", updatedAt: Date(timeIntervalSince1970: 2), sourceAppName: "微信")
        )
        XCTAssertEqual(try store.distinctSourceApps().map(\.name), ["微信", "Notes"])
    }

    func testTextSearchMatchesSourceAppName() throws {
        try store.upsert(Snippet.makeText(body: "payload", hash: "p", sourceAppName: "飞书"))
        let list = try store.list(query: "飞书", limit: 10)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].sourceAppName, "飞书")
    }

    func testMixedSnippetStoresTextAndImage() throws {
        let png = Self.onePixelPNG()
        let id = UUID().uuidString
        let snippet = Snippet.makeMixed(
            body: "caption with image",
            imageHash: ContentHasher.hashMixed(text: "caption with image", imageData: png),
            byteSize: png.count,
            mediaPath: "\(id).png",
            imagePreview: "Image",
            id: id
        )
        try store.upsert(snippet, imageData: png)

        let list = try store.list(query: nil, limit: 10)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].kind, .mixed)
        XCTAssertEqual(list[0].textBody, "caption with image")
        XCTAssertNotNil(list[0].mediaPath)
        let data = try store.mediaData(for: list[0])
        XCTAssertEqual(data, png)
    }

    private static func onePixelPNG() -> Data {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        return rep.representation(using: .png, properties: [:])!
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

    func testPinSurvivesCapacityPrune() throws {
        let pinned = Snippet.makeText(body: "keep", hash: "keep", updatedAt: Date(timeIntervalSince1970: 1))
        try store.upsert(pinned)
        _ = try store.setPinned(id: pinned.id, pinned: true)

        try store.upsert(Snippet.makeText(body: "2", hash: "2", updatedAt: Date(timeIntervalSince1970: 2)))
        try store.upsert(Snippet.makeText(body: "3", hash: "3", updatedAt: Date(timeIntervalSince1970: 3)))
        try store.upsert(Snippet.makeText(body: "4", hash: "4", updatedAt: Date(timeIntervalSince1970: 4)))
        // max=3 unpinned; pinned is extra. Unpinned should be 3 newest: 2,3,4? Wait we have keep(pinned)+2+3+4 = 4 unpinned if keep not pinned... keep is pinned so unpinned are 2,3,4 = 3, no prune of keep.
        let all = try store.list(query: nil, limit: 20)
        XCTAssertTrue(all.contains { $0.contentHash == "keep" && $0.isPinned })
        XCTAssertEqual(all.filter { !$0.isPinned }.count, 3)
    }

    func testFavoritesOnlyFilter() throws {
        let a = Snippet.makeText(body: "a", hash: "a")
        let b = Snippet.makeText(body: "b", hash: "b")
        try store.upsert(a)
        try store.upsert(b)
        _ = try store.setPinned(id: a.id, pinned: true)

        let fav = try store.list(query: nil, favoritesOnly: true, limit: 10)
        XCTAssertEqual(fav.map(\.contentHash), ["a"])
        XCTAssertTrue(fav[0].isPinned)
    }

    func testDeleteUnpinnedKeepsFavorites() throws {
        let a = Snippet.makeText(body: "a", hash: "a")
        let b = Snippet.makeText(body: "b", hash: "b")
        try store.upsert(a)
        try store.upsert(b)
        _ = try store.setPinned(id: a.id, pinned: true)
        try store.deleteUnpinned()
        let list = try store.list(query: nil, limit: 10)
        XCTAssertEqual(list.map(\.contentHash), ["a"])
        XCTAssertTrue(list[0].isPinned)
    }

    func testFavoritesCap() throws {
        store.setMaxFavoriteCount(2)
        let a = Snippet.makeText(body: "a", hash: "a")
        let b = Snippet.makeText(body: "b", hash: "b")
        let c = Snippet.makeText(body: "c", hash: "c")
        try store.upsert(a)
        try store.upsert(b)
        try store.upsert(c)
        _ = try store.setPinned(id: a.id, pinned: true)
        _ = try store.setPinned(id: b.id, pinned: true)
        XCTAssertThrowsError(try store.setPinned(id: c.id, pinned: true)) { error in
            XCTAssertEqual(error as? PinError, .favoritesFull(limit: 2))
        }
    }

    func testPinNoteCappedAndClearedOnUnpin() throws {
        let s = Snippet.makeText(body: "body", hash: "note-h")
        try store.upsert(s)
        _ = try store.setPinned(id: s.id, pinned: true)
        try store.setPinNote(id: s.id, note: "一二三四五六七八九十超额")
        var list = try store.list(query: nil, favoritesOnly: true, limit: 5)
        XCTAssertEqual(list.first?.pinNote?.count, AppConstants.maxPinNoteLength)
        XCTAssertEqual(list.first?.pinNote, "一二三四五六七八九十")

        _ = try store.setPinned(id: s.id, pinned: false)
        list = try store.list(query: nil, limit: 5)
        XCTAssertNil(list.first(where: { $0.id == s.id })?.pinNote)
    }

    /// Existing installs have a snippets table without pin columns; opening must migrate.
    func testMigratesLegacySchemaWithoutPinColumns() throws {
        let legacyRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("aipaste-legacy-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: legacyRoot) }

        let dbDir = legacyRoot.appendingPathComponent("db", isDirectory: true)
        try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("aipaste.sqlite")

        // Pre-favorites schema (no is_pinned / pinned_at).
        let raw = try Database(path: dbPath)
        // Force a clean old table by reusing the file after manual recreate would be complex;
        // instead open via sqlite3 through a side file we write with the legacy DDL.
        _ = raw
        try? FileManager.default.removeItem(at: dbPath)

        var cHandle: OpaquePointer?
        XCTAssertEqual(sqlite3_open(dbPath.path, &cHandle), SQLITE_OK)
        defer { sqlite3_close(cHandle) }
        let legacySQL = """
        CREATE TABLE snippets (
          id TEXT PRIMARY KEY,
          created_at REAL NOT NULL,
          updated_at REAL NOT NULL,
          kind TEXT NOT NULL,
          content_hash TEXT NOT NULL,
          preview_text TEXT NOT NULL DEFAULT '',
          text_body TEXT,
          media_path TEXT,
          byte_size INTEGER NOT NULL DEFAULT 0,
          source_bundle_id TEXT,
          source_app_name TEXT
        );
        INSERT INTO snippets
        (id, created_at, updated_at, kind, content_hash, preview_text, text_body, media_path, byte_size, source_bundle_id, source_app_name)
        VALUES ('legacy-1', 1, 1, 'text', 'h1', 'hello', 'hello', NULL, 5, NULL, NULL);
        """
        XCTAssertEqual(sqlite3_exec(cHandle, legacySQL, nil, nil, nil), SQLITE_OK)
        sqlite3_close(cHandle)
        cHandle = nil

        // App open path: Database init must migrate + index without failing.
        let media = MediaStore(directory: legacyRoot.appendingPathComponent("media", isDirectory: true))
        try FileManager.default.createDirectory(at: media.directory, withIntermediateDirectories: true)
        let migrated = try Database(path: dbPath)
        let store = SnippetStore(database: migrated, mediaStore: media, maxSnippetCount: 50)
        let list = try store.list(query: nil, limit: 10)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].textBody, "hello")
        XCTAssertFalse(list[0].isPinned)
        _ = try store.setPinned(id: list[0].id, pinned: true)
        XCTAssertEqual(try store.pinnedCount(), 1)
    }
}
