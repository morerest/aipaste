import Foundation
import AppKit

protocol SnippetStoring: AnyObject {
    func upsert(_ snippet: Snippet, imageData: Data?) throws
}

extension SnippetStore: SnippetStoring {}

final class PasteboardIngester {
    private let store: SnippetStoring
    private let ignoreRules: IgnoreRuleStore
    private let gate: InternalPasteboardWriteGate

    init(store: SnippetStoring,
         ignoreRules: IgnoreRuleStore,
         gate: InternalPasteboardWriteGate = .shared) {
        self.store = store
        self.ignoreRules = ignoreRules
        self.gate = gate
    }

    /// Returns true if something was written/updated.
    @discardableResult
    func handlePasteboardChange(pasteboard: NSPasteboard = .general) throws -> Bool {
        if gate.isInternalWrite { return false }
        guard let payload = PasteboardReader.read(pasteboard) else { return false }

        let source = FrontmostAppInfo.current()
        if ignoreRules.isIgnored(bundleId: source.bundleId) { return false }

        switch payload.kind {
        case .text(let raw):
            let body = truncateText(raw)
            let hash = ContentHasher.hashText(body)
            let snippet = Snippet.makeText(
                body: body,
                hash: hash,
                sourceBundleId: source.bundleId,
                sourceAppName: source.name
            )
            try store.upsert(snippet, imageData: nil)
            return true
        case .image(let data, let preview):
            if data.count > AppConstants.maxImageBytes { return false }
            let hash = ContentHasher.hashImage(data)
            let id = UUID().uuidString
            let snippet = Snippet.makeImage(
                hash: hash,
                byteSize: data.count,
                mediaPath: "\(id).png",
                previewText: preview,
                id: id,
                sourceBundleId: source.bundleId,
                sourceAppName: source.name
            )
            try store.upsert(snippet, imageData: data)
            return true
        }
    }

    private func truncateText(_ text: String) -> String {
        let bytes = Data(text.utf8)
        guard bytes.count > AppConstants.maxTextUTF8Bytes else { return text }
        let sliced = bytes.prefix(AppConstants.maxTextUTF8Bytes)
        return String(data: Data(sliced), encoding: .utf8).map { $0 + "…" } ?? text
    }
}
