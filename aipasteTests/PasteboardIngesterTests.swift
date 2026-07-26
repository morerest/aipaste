import XCTest
@testable import aipaste

private final class FakeStore: SnippetStoring {
    var items: [Snippet] = []
    func upsert(
        _ snippet: Snippet,
        imageData: Data?,
        pasteboardSnapshot: PasteboardSnapshot.Items?
    ) throws {
        if let idx = items.firstIndex(where: { $0.kind == snippet.kind && $0.contentHash == snippet.contentHash }) {
            items[idx].updatedAt = snippet.updatedAt
        } else {
            items.append(snippet)
        }
    }
}

final class PasteboardIngesterTests: XCTestCase {
    func testIgnoresWhenGateInternal() throws {
        let store = FakeStore()
        let defaults = UserDefaults(suiteName: "t-\(UUID().uuidString)")!
        let rules = IgnoreRuleStore(defaults: defaults)
        let gate = InternalPasteboardWriteGate()
        let ingester = PasteboardIngester(store: store, ignoreRules: rules, gate: gate)
        gate.begin()
        // Cannot easily inject pasteboard content without AppKit pasteboard;
        // gate short-circuit still returns false even with empty read.
        XCTAssertFalse(try ingester.handlePasteboardChange())
        gate.end()
        XCTAssertTrue(store.items.isEmpty)
    }
}
