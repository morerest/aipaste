import XCTest
@testable import aipaste

final class PasteEngineTests: XCTestCase {
    private var tempRoot: URL!
    private var store: SnippetStore!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("aipaste-paste-engine-\(UUID().uuidString)", isDirectory: true)
        let paths = AppPaths(root: tempRoot)
        try paths.ensureDirectories()
        store = SnippetStore(
            database: try Database(path: paths.databaseFile),
            mediaStore: MediaStore(directory: paths.mediaDirectory)
        )
    }

    override func tearDownWithError() throws {
        store = nil
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testPasteDeniedAccessibilityCopiesWithoutPromptingOrPostingCommandV() throws {
        var requestedPrompts: [Bool] = []
        var postedCommandVCount = 0
        let engine = PasteEngine(
            store: store,
            accessibilityCheck: { prompt in
                requestedPrompts.append(prompt)
                return false
            },
            commandVAction: {
                postedCommandVCount += 1
            }
        )
        let snippet = Snippet.makeText(body: "denied", hash: "denied")

        let result = try engine.perform(snippet, mode: .paste)

        XCTAssertEqual(result, .copiedOnly(reason: .accessibilityDenied))
        XCTAssertEqual(requestedPrompts, [false])
        XCTAssertEqual(postedCommandVCount, 0)
    }
}
