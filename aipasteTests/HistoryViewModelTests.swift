import AppKit
import XCTest
@testable import aipaste

@MainActor
final class HistoryViewModelTests: XCTestCase {
    private var tempRoot: URL!
    private var store: SnippetStore!
    private var model: HistoryViewModel!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("aipaste-history-model-\(UUID().uuidString)", isDirectory: true)
        let paths = AppPaths(root: tempRoot)
        try paths.ensureDirectories()
        store = SnippetStore(
            database: try Database(path: paths.databaseFile),
            mediaStore: MediaStore(directory: paths.mediaDirectory),
            maxSnippetCount: 20
        )
        try store.upsert(Snippet.makeText(body: "old", hash: "old", updatedAt: Date(timeIntervalSince1970: 1)))
        try store.upsert(Snippet.makeText(body: "middle", hash: "middle", updatedAt: Date(timeIntervalSince1970: 2)))
        try store.upsert(Snippet.makeText(body: "new", hash: "new", updatedAt: Date(timeIntervalSince1970: 3)))
        model = HistoryViewModel(store: store, pasteEngine: PasteEngine(store: store))
        model.reload()
    }

    override func tearDownWithError() throws {
        model = nil
        store = nil
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testSelectionMovesWithinBounds() {
        XCTAssertEqual(model.selectedID, model.snippets[0].id)
        model.selectNext()
        XCTAssertEqual(model.selectedID, model.snippets[1].id)
        model.selectNext()
        model.selectNext()
        XCTAssertEqual(model.selectedID, model.snippets[2].id)
        model.selectPrevious()
        XCTAssertEqual(model.selectedID, model.snippets[1].id)
    }

    func testSelectLatestSelectsFirstSnippetAndRequestsLeadingScroll() {
        model.selectNext()
        let tokenBefore = model.latestScrollToken

        model.selectLatest()

        XCTAssertEqual(model.selectedID, model.snippets.first?.id)
        XCTAssertEqual(model.latestScrollToken, tokenBefore &+ 1)
    }

    func testSelectLatestRequestsScrollWhenFirstSnippetIsAlreadySelected() {
        XCTAssertEqual(model.selectedID, model.snippets.first?.id)
        let tokenBefore = model.latestScrollToken

        model.selectLatest()

        XCTAssertEqual(model.selectedID, model.snippets.first?.id)
        XCTAssertEqual(model.latestScrollToken, tokenBefore &+ 1)
    }

    func testSelectLatestDoesNothingForEmptyHistory() {
        model.clearHistory()
        let tokenBefore = model.latestScrollToken

        model.selectLatest()

        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.latestScrollToken, tokenBefore)
    }

    func testDeleteSelectsNearestRemainingCard() {
        model.selectNext()
        model.deleteSelected()
        XCTAssertEqual(model.snippets.map(\.textBody), ["new", "old"])
        XCTAssertEqual(model.selectedID, model.snippets[1].id)
    }

    func testClearHistoryResetsSelection() {
        model.clearHistory()
        XCTAssertTrue(model.snippets.isEmpty)
        XCTAssertNil(model.selectedID)
    }

    func testClearHistoryKeepsFavorites() throws {
        let keepID = model.snippets[0].id
        try store.setPinned(id: keepID, pinned: true)
        model.clearHistory()
        XCTAssertEqual(model.snippets.count, 1)
        XCTAssertEqual(model.snippets[0].id, keepID)
        XCTAssertTrue(model.snippets[0].isPinned)
    }

    func testFavoritesFilterAndTogglePin() throws {
        model.selectedID = model.snippets[0].id
        model.togglePinSelected()
        XCTAssertTrue(model.snippets.contains { $0.id == model.selectedID && $0.isPinned })

        model.setFavoritesOnly(true)
        model.reload()
        XCTAssertTrue(model.snippets.allSatisfy(\.isPinned))
        XCTAssertFalse(model.snippets.isEmpty)
    }

    func testEmptyHistoryHasNoPasteableSelection() {
        model.clearHistory()

        XCTAssertFalse(model.hasPasteableSelection)
    }

    func testStaleSelectionIsNotPasteable() {
        model.selectedID = "missing-id"

        XCTAssertFalse(model.hasPasteableSelection)
    }

    func testSourceAppFilterLimitsVisibleSnippets() throws {
        try store.upsert(
            Snippet.makeText(body: "wechat body", hash: "wx", sourceAppName: "微信")
        )
        try store.upsert(
            Snippet.makeText(body: "notes body", hash: "nt", sourceAppName: "Notes")
        )
        model.reload()
        XCTAssertTrue(model.availableSourceApps.contains { $0.name == "微信" })
        XCTAssertTrue(model.availableSourceApps.contains { $0.name == "Notes" })

        model.setSourceAppFilter("微信")
        model.reload()

        XCTAssertEqual(model.sourceAppFilter, "微信")
        XCTAssertTrue(model.snippets.allSatisfy { $0.sourceAppName == "微信" })
        XCTAssertTrue(model.hasActiveFilters)

        model.setSourceAppFilter(nil)
        model.reload()
        XCTAssertNil(model.sourceAppFilter)
        XCTAssertGreaterThanOrEqual(model.snippets.count, 2)
    }

    func testContentKindFilterDefaultsToAllAndLoadsMatchingKind() throws {
        let png = Self.tinyPNGData()
        let image = Snippet.makeImage(
            hash: "filter-image",
            byteSize: png.count,
            mediaPath: "filter-image.png",
            previewText: "Image"
        )
        try store.upsert(image, imageData: png)
        model.reload()

        XCTAssertEqual(model.contentKindFilter, .all)

        model.setContentKindFilter(.image)
        model.reload()

        XCTAssertFalse(model.snippets.isEmpty)
        XCTAssertTrue(model.snippets.allSatisfy { $0.kind == .image })
        XCTAssertTrue(model.hasActiveFilters)
    }

    func testClearAllFiltersAlsoResetsContentKind() {
        model.query = "new"
        model.setSourceAppFilter("Notes")
        model.setFavoritesOnly(true)
        model.setContentKindFilter(.mixed)

        model.clearAllFilters()

        XCTAssertEqual(model.query, "")
        XCTAssertNil(model.sourceAppFilter)
        XCTAssertFalse(model.favoritesOnly)
        XCTAssertEqual(model.contentKindFilter, .all)
        XCTAssertFalse(model.hasActiveFilters)
    }

    func testActiveFilterCountTracksStructuredFiltersButNotSearch() {
        XCTAssertEqual(model.activeFilterCount, 0)

        model.query = "new"
        XCTAssertEqual(model.activeFilterCount, 0)

        model.setContentKindFilter(.image)
        XCTAssertEqual(model.activeFilterCount, 1)

        model.setFavoritesOnly(true)
        XCTAssertEqual(model.activeFilterCount, 2)

        model.setSourceAppFilter("Notes")
        XCTAssertEqual(model.activeFilterCount, 3)
        XCTAssertTrue(model.hasStructuredFilters)
    }

    func testPopoverFilterCountTracksOnlyContentTypeAndSourceApp() {
        XCTAssertEqual(model.popoverFilterCount, 0)

        model.query = "new"
        model.setFavoritesOnly(true)
        XCTAssertEqual(model.popoverFilterCount, 0)

        model.setContentKindFilter(.image)
        XCTAssertEqual(model.popoverFilterCount, 1)

        model.setSourceAppFilter("Notes")
        XCTAssertEqual(model.popoverFilterCount, 2)
        XCTAssertTrue(model.hasPopoverFilters)
    }

    func testClearPopoverFiltersPreservesSearchAndFavorites() {
        model.query = "new"
        model.setFavoritesOnly(true)
        model.setContentKindFilter(.mixed)
        model.setSourceAppFilter("Notes")

        model.clearPopoverFilters()

        XCTAssertEqual(model.query, "new")
        XCTAssertTrue(model.favoritesOnly)
        XCTAssertEqual(model.contentKindFilter, .all)
        XCTAssertNil(model.sourceAppFilter)
        XCTAssertEqual(model.popoverFilterCount, 0)
        XCTAssertFalse(model.hasPopoverFilters)
        XCTAssertTrue(model.hasActiveFilters)
    }

    func testClearStructuredFiltersPreservesSearch() {
        model.query = "new"
        model.setContentKindFilter(.mixed)
        model.setFavoritesOnly(true)
        model.setSourceAppFilter("Notes")

        model.clearStructuredFilters()

        XCTAssertEqual(model.query, "new")
        XCTAssertEqual(model.contentKindFilter, .all)
        XCTAssertFalse(model.favoritesOnly)
        XCTAssertNil(model.sourceAppFilter)
        XCTAssertEqual(model.activeFilterCount, 0)
        XCTAssertFalse(model.hasStructuredFilters)
        XCTAssertTrue(model.hasActiveFilters)
    }

    func testGalleryScrollMetricsShowsBackToLatestOnlyPastThreshold() {
        XCTAssertFalse(
            GalleryScrollMetrics.shouldShowBackToLatest(leadingX: 0, hasResults: true)
        )
        XCTAssertFalse(
            GalleryScrollMetrics.shouldShowBackToLatest(leadingX: -70, hasResults: true)
        )
        XCTAssertTrue(
            GalleryScrollMetrics.shouldShowBackToLatest(leadingX: -70.1, hasResults: true)
        )
    }

    func testGalleryScrollMetricsHidesBackToLatestWithoutResults() {
        XCTAssertFalse(
            GalleryScrollMetrics.shouldShowBackToLatest(leadingX: -200, hasResults: false)
        )
    }

    func testClearAllFiltersResetsQueryAppAndFavorites() throws {
        try store.setPinned(id: model.snippets[0].id, pinned: true)
        model.query = "body"
        model.setSourceAppFilter("微信")
        model.setFavoritesOnly(true)
        XCTAssertTrue(model.hasActiveFilters)

        model.clearAllFilters()

        XCTAssertEqual(model.query, "")
        XCTAssertNil(model.sourceAppFilter)
        XCTAssertFalse(model.favoritesOnly)
        XCTAssertFalse(model.hasActiveFilters)
    }

    func testThemeChangePreservesQueryFiltersAndSelection() {
        model.query = "new"
        model.setFavoritesOnly(true)
        let selected = model.selectedID

        model.setTheme(.graphite)

        XCTAssertEqual(model.theme, .graphite)
        XCTAssertEqual(model.query, "new")
        XCTAssertTrue(model.favoritesOnly)
        XCTAssertEqual(model.selectedID, selected)
    }

    func testImageLoadsFromMediaStoreAsynchronously() async throws {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4,
            bitsPerPixel: 32
        )!
        let png = bitmap.representation(using: .png, properties: [:])!
        let snippet = Snippet.makeImage(
            hash: "image",
            byteSize: png.count,
            mediaPath: "unused.png",
            previewText: "Image (1×1)"
        )
        try store.upsert(snippet, imageData: png)
        model.reload()

        let stored = try XCTUnwrap(model.snippets.first { $0.id == snippet.id })
        await model.loadThumbnail(for: stored)

        XCTAssertNotNil(model.thumbnail(for: stored))
    }

    func testFirstAsyncThumbnailLoadPopulatesCache() async throws {
        let counter = InvocationCounter()
        let stored = try makeStoredImage()
        let png = Self.tinyPNGData()
        model = HistoryViewModel(
            store: store,
            pasteEngine: PasteEngine(store: store),
            thumbnailLoader: { _ in
                counter.increment()
                return png
            }
        )
        model.reload()

        await model.loadThumbnail(for: stored)

        XCTAssertNotNil(model.thumbnail(for: stored))
        XCTAssertEqual(counter.value, 1)
    }

    func testConcurrentThumbnailLoadsInvokeLoaderOnce() async throws {
        let counter = InvocationCounter()
        let stored = try makeStoredImage()
        let png = Self.tinyPNGData()
        model = HistoryViewModel(
            store: store,
            pasteEngine: PasteEngine(store: store),
            thumbnailLoader: { _ in
                counter.increment()
                Thread.sleep(forTimeInterval: 0.05)
                return png
            }
        )
        model.reload()

        let first = Task { await model.loadThumbnail(for: stored) }
        let second = Task { await model.loadThumbnail(for: stored) }
        await first.value
        await second.value

        XCTAssertNotNil(model.thumbnail(for: stored))
        XCTAssertEqual(counter.value, 1)
    }

    func testFilteredThenReaddedIDNeverRunsConcurrentThumbnailLoaders() async throws {
        let loader = ControllableThumbnailLoader(pngData: Self.tinyPNGData())
        let stored = try makeStoredImage()
        model = HistoryViewModel(
            store: store,
            pasteEngine: PasteEngine(store: store),
            thumbnailLoader: { snippet in loader.load(snippet) }
        )
        model.reload()

        let first = Task { await model.loadThumbnail(for: stored) }
        // Wait off the main actor so loadThumbnail can start without deadlock.
        let enteredFirst = await Task.detached {
            loader.waitForCallCount(1)
        }.value
        XCTAssertTrue(enteredFirst)

        model.query = "no-matching-image"
        model.reload()
        model.query = ""
        model.reload()

        let second = Task { await model.loadThumbnail(for: stored) }
        let secondStartedBeforeFirstFinished = await Task.detached {
            loader.waitForCallCount(2, timeout: 0.2)
        }.value
        loader.release(upTo: 3)
        await first.value
        await second.value

        XCTAssertFalse(secondStartedBeforeFirstFinished)
        XCTAssertEqual(loader.maximumActiveCount, 1)
        XCTAssertNotNil(model.thumbnail(for: stored))
    }

    func testDeleteRemovesCachedThumbnail() async throws {
        let stored = try makeStoredImage()
        let png = Self.tinyPNGData()
        model = HistoryViewModel(
            store: store,
            pasteEngine: PasteEngine(store: store),
            thumbnailLoader: { _ in png }
        )
        model.reload()
        model.selectedID = stored.id
        await model.loadThumbnail(for: stored)
        XCTAssertNotNil(model.thumbnail(for: stored))

        model.deleteSelected()

        XCTAssertNil(model.thumbnail(for: stored))
    }

    func testClearHistoryRemovesCachedThumbnails() async throws {
        let stored = try makeStoredImage()
        let png = Self.tinyPNGData()
        model = HistoryViewModel(
            store: store,
            pasteEngine: PasteEngine(store: store),
            thumbnailLoader: { _ in png }
        )
        model.reload()
        await model.loadThumbnail(for: stored)
        XCTAssertNotNil(model.thumbnail(for: stored))

        model.clearHistory()

        XCTAssertNil(model.thumbnail(for: stored))
    }

    private func makeStoredImage() throws -> Snippet {
        let snippet = Snippet.makeImage(
            hash: UUID().uuidString,
            byteSize: 1,
            mediaPath: "unused.png",
            previewText: "Image"
        )
        try store.upsert(snippet, imageData: Data([0]))
        return snippet
    }

    private static func tinyPNGData() -> Data {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 8,
            pixelsHigh: 8,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 32,
            bitsPerPixel: 32
        )!
        return bitmap.representation(using: .png, properties: [:])!
    }
}

private final class InvocationCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = 0

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func increment() {
        lock.lock()
        storage += 1
        lock.unlock()
    }
}

private final class ControllableThumbnailLoader: @unchecked Sendable {
    private let condition = NSCondition()
    private let gate = DispatchSemaphore(value: 0)
    private let pngData: Data
    private var callCount = 0
    private var activeCount = 0
    private var maximumActive = 0

    init(pngData: Data) {
        self.pngData = pngData
    }

    var maximumActiveCount: Int {
        condition.lock()
        defer { condition.unlock() }
        return maximumActive
    }

    func load(_ snippet: Snippet) -> Data? {
        condition.lock()
        callCount += 1
        activeCount += 1
        maximumActive = max(maximumActive, activeCount)
        condition.broadcast()
        condition.unlock()

        gate.wait()

        condition.lock()
        activeCount -= 1
        condition.broadcast()
        condition.unlock()
        return pngData
    }

    func waitForCallCount(_ expected: Int, timeout: TimeInterval = 1) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        condition.lock()
        defer { condition.unlock() }
        while callCount < expected {
            guard condition.wait(until: deadline) else { return false }
        }
        return true
    }

    func release(upTo count: Int) {
        for _ in 0..<count {
            gate.signal()
        }
    }
}
