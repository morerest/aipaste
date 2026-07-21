import Foundation

enum SnippetKind: String, Codable, Sendable {
    case text
    case image
}

struct Snippet: Identifiable, Equatable, Sendable {
    var id: String
    var createdAt: Date
    var updatedAt: Date
    var kind: SnippetKind
    var contentHash: String
    var previewText: String
    var textBody: String?
    var mediaPath: String?
    var byteSize: Int
    var sourceBundleId: String?
    var sourceAppName: String?

    static func makeText(
        body: String,
        hash: String,
        id: String = UUID().uuidString,
        updatedAt: Date = Date(),
        sourceBundleId: String? = nil,
        sourceAppName: String? = nil
    ) -> Snippet {
        let preview = body.count > 200 ? String(body.prefix(200)) : body
        return Snippet(
            id: id,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            kind: .text,
            contentHash: hash,
            previewText: preview,
            textBody: body,
            mediaPath: nil,
            byteSize: body.utf8.count,
            sourceBundleId: sourceBundleId,
            sourceAppName: sourceAppName
        )
    }

    static func makeImage(
        hash: String,
        byteSize: Int,
        mediaPath: String,
        previewText: String,
        id: String = UUID().uuidString,
        updatedAt: Date = Date(),
        sourceBundleId: String? = nil,
        sourceAppName: String? = nil
    ) -> Snippet {
        Snippet(
            id: id,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            kind: .image,
            contentHash: hash,
            previewText: previewText,
            textBody: nil,
            mediaPath: mediaPath,
            byteSize: byteSize,
            sourceBundleId: sourceBundleId,
            sourceAppName: sourceAppName
        )
    }
}
