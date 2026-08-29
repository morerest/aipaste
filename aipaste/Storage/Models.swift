import Foundation

enum SnippetKind: String, Codable, Sendable {
    case text
    case image
    /// Plain text + image from the same pasteboard change (restore both on paste).
    case mixed
}

/// Single-choice content-kind filter used by the history UI.
enum SnippetKindFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case text
    case image
    case mixed

    var id: String { rawValue }

    var snippetKind: SnippetKind? {
        switch self {
        case .all: return nil
        case .text: return .text
        case .image: return .image
        case .mixed: return .mixed
        }
    }
}

/// Distinct source app for the history filter menu.
struct SourceAppOption: Identifiable, Hashable, Sendable {
    var id: String { name }
    let name: String
    let bundleId: String?
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
    /// User-pinned favorite; exempt from capacity prune and default clear-history.
    var isPinned: Bool
    /// When the item was last pinned (for favorites ordering).
    var pinnedAt: Date?
    /// Short user label on a favorite (≤ `AppConstants.maxPinNoteLength` characters).
    var pinNote: String?

    static func makeText(
        body: String,
        hash: String,
        id: String = UUID().uuidString,
        updatedAt: Date = Date(),
        sourceBundleId: String? = nil,
        sourceAppName: String? = nil,
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        pinNote: String? = nil
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
            sourceAppName: sourceAppName,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            pinNote: pinNote
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
        sourceAppName: String? = nil,
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        pinNote: String? = nil
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
            sourceAppName: sourceAppName,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            pinNote: pinNote
        )
    }

    static func makeMixed(
        body: String,
        imageHash: String,
        byteSize: Int,
        mediaPath: String,
        imagePreview: String,
        id: String = UUID().uuidString,
        updatedAt: Date = Date(),
        sourceBundleId: String? = nil,
        sourceAppName: String? = nil,
        isPinned: Bool = false,
        pinnedAt: Date? = nil,
        pinNote: String? = nil
    ) -> Snippet {
        let textPreview = body.count > 120 ? String(body.prefix(120)) + "…" : body
        let preview = textPreview.isEmpty ? imagePreview : textPreview
        return Snippet(
            id: id,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            kind: .mixed,
            contentHash: imageHash,
            previewText: preview,
            textBody: body,
            mediaPath: mediaPath,
            byteSize: byteSize + body.utf8.count,
            sourceBundleId: sourceBundleId,
            sourceAppName: sourceAppName,
            isPinned: isPinned,
            pinnedAt: pinnedAt,
            pinNote: pinNote
        )
    }

    /// Normalize a pin note: trim, cap length, empty → nil.
    static func normalizedPinNote(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= AppConstants.maxPinNoteLength {
            return trimmed
        }
        return String(trimmed.prefix(AppConstants.maxPinNoteLength))
    }

    var hasImage: Bool {
        kind == .image || kind == .mixed
    }

    var hasText: Bool {
        kind == .text || kind == .mixed
    }
}

enum PinError: LocalizedError, Equatable {
    case notFound
    case favoritesFull(limit: Int)

    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Item not found"
        case .favoritesFull(let limit):
            return "Favorites full (\(limit)). Unpin one first."
        }
    }
}
