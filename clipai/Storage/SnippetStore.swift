import Foundation
import SQLite3

final class SnippetStore: @unchecked Sendable {
    private let database: Database
    private let mediaStore: MediaStore
    private let queue = DispatchQueue(label: "com.eden.clipai.store")
    private var maxSnippetCount: Int

    init(database: Database, mediaStore: MediaStore, maxSnippetCount: Int = AppConstants.defaultMaxSnippetCount) {
        self.database = database
        self.mediaStore = mediaStore
        self.maxSnippetCount = maxSnippetCount
    }

    func setMaxSnippetCount(_ value: Int) {
        queue.sync { maxSnippetCount = max(1, value) }
    }

    func upsert(_ snippet: Snippet, imageData: Data? = nil) throws {
        try queue.sync {
            if let existingID = try fetchID(kind: snippet.kind, hash: snippet.contentHash) {
                try database.withStatement(
                    """
                    UPDATE snippets SET updated_at = ?, source_bundle_id = ?, source_app_name = ?
                    WHERE id = ?;
                    """
                ) { stmt in
                    sqlite3_bind_double(stmt, 1, snippet.updatedAt.timeIntervalSince1970)
                    bindOptionalText(stmt, 2, snippet.sourceBundleId)
                    bindOptionalText(stmt, 3, snippet.sourceAppName)
                    bindText(stmt, 4, existingID)
                    guard sqlite3_step(stmt) == SQLITE_DONE else {
                        throw DatabaseError.stepFailed("update failed")
                    }
                }
                return
            }

            var toInsert = snippet
            if snippet.kind == .image, let imageData {
                let rel = try mediaStore.writeImage(id: snippet.id, data: imageData)
                toInsert.mediaPath = rel
                toInsert.byteSize = imageData.count
            }

            try database.withStatement(
                """
                INSERT INTO snippets
                (id, created_at, updated_at, kind, content_hash, preview_text, text_body, media_path, byte_size, source_bundle_id, source_app_name)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
            ) { stmt in
                bindText(stmt, 1, toInsert.id)
                sqlite3_bind_double(stmt, 2, toInsert.createdAt.timeIntervalSince1970)
                sqlite3_bind_double(stmt, 3, toInsert.updatedAt.timeIntervalSince1970)
                bindText(stmt, 4, toInsert.kind.rawValue)
                bindText(stmt, 5, toInsert.contentHash)
                bindText(stmt, 6, toInsert.previewText)
                bindOptionalText(stmt, 7, toInsert.textBody)
                bindOptionalText(stmt, 8, toInsert.mediaPath)
                sqlite3_bind_int64(stmt, 9, Int64(toInsert.byteSize))
                bindOptionalText(stmt, 10, toInsert.sourceBundleId)
                bindOptionalText(stmt, 11, toInsert.sourceAppName)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DatabaseError.stepFailed("insert failed")
                }
            }
            try enforceCapacityUnlocked()
        }
    }

    func list(query: String?, limit: Int) throws -> [Snippet] {
        try queue.sync {
            let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if trimmed.isEmpty {
                return try database.withStatement(
                    """
                    SELECT id, created_at, updated_at, kind, content_hash, preview_text, text_body, media_path, byte_size, source_bundle_id, source_app_name
                    FROM snippets ORDER BY updated_at DESC LIMIT ?;
                    """
                ) { stmt in
                    sqlite3_bind_int(stmt, 1, Int32(limit))
                    return try readAll(stmt)
                }
            }
            let pattern = "%\(trimmed)%"
            return try database.withStatement(
                """
                SELECT id, created_at, updated_at, kind, content_hash, preview_text, text_body, media_path, byte_size, source_bundle_id, source_app_name
                FROM snippets
                WHERE preview_text LIKE ? OR IFNULL(text_body, '') LIKE ?
                ORDER BY updated_at DESC LIMIT ?;
                """
            ) { stmt in
                bindText(stmt, 1, pattern)
                bindText(stmt, 2, pattern)
                sqlite3_bind_int(stmt, 3, Int32(limit))
                return try readAll(stmt)
            }
        }
    }

    func delete(id: String) throws {
        try queue.sync {
            if let media = try fetchMediaPath(id: id) {
                try mediaStore.delete(relativePath: media)
            }
            try database.withStatement("DELETE FROM snippets WHERE id = ?;") { stmt in
                bindText(stmt, 1, id)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DatabaseError.stepFailed("delete failed")
                }
            }
        }
    }

    func deleteAll() throws {
        try queue.sync {
            try database.exec("DELETE FROM snippets;")
            try mediaStore.deleteAll()
        }
    }

    func mediaData(for snippet: Snippet) throws -> Data? {
        guard let rel = snippet.mediaPath else { return nil }
        return try mediaStore.read(relativePath: rel)
    }

    // MARK: - private

    private func enforceCapacityUnlocked() throws {
        let count: Int = try database.withStatement("SELECT COUNT(*) FROM snippets;") { stmt in
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
        }
        guard count > maxSnippetCount else { return }
        let overflow = count - maxSnippetCount
        let victims: [(String, String?)] = try database.withStatement(
            """
            SELECT id, media_path FROM snippets
            ORDER BY updated_at ASC LIMIT ?;
            """
        ) { stmt in
            sqlite3_bind_int(stmt, 1, Int32(overflow))
            var rows: [(String, String?)] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = columnText(stmt, 0)
                let media: String? = sqlite3_column_type(stmt, 1) == SQLITE_NULL
                    ? nil : columnText(stmt, 1)
                rows.append((id, media))
            }
            return rows
        }
        for (id, media) in victims {
            if let media { try mediaStore.delete(relativePath: media) }
            try database.withStatement("DELETE FROM snippets WHERE id = ?;") { stmt in
                bindText(stmt, 1, id)
                _ = sqlite3_step(stmt)
            }
        }
    }

    private func fetchID(kind: SnippetKind, hash: String) throws -> String? {
        try database.withStatement(
            "SELECT id FROM snippets WHERE kind = ? AND content_hash = ? LIMIT 1;"
        ) { stmt in
            bindText(stmt, 1, kind.rawValue)
            bindText(stmt, 2, hash)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            return columnText(stmt, 0)
        }
    }

    private func fetchMediaPath(id: String) throws -> String? {
        try database.withStatement("SELECT media_path FROM snippets WHERE id = ?;") { stmt in
            bindText(stmt, 1, id)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            if sqlite3_column_type(stmt, 0) == SQLITE_NULL { return nil }
            return columnText(stmt, 0)
        }
    }

    private func readAll(_ stmt: OpaquePointer) throws -> [Snippet] {
        var result: [Snippet] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            result.append(readRow(stmt))
        }
        return result
    }

    private func readRow(_ stmt: OpaquePointer) -> Snippet {
        Snippet(
            id: columnText(stmt, 0),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
            kind: SnippetKind(rawValue: columnText(stmt, 3)) ?? .text,
            contentHash: columnText(stmt, 4),
            previewText: columnText(stmt, 5),
            textBody: optionalColumnText(stmt, 6),
            mediaPath: optionalColumnText(stmt, 7),
            byteSize: Int(sqlite3_column_int64(stmt, 8)),
            sourceBundleId: optionalColumnText(stmt, 9),
            sourceAppName: optionalColumnText(stmt, 10)
        )
    }
}

private func columnText(_ stmt: OpaquePointer, _ index: Int32) -> String {
    guard let ptr = sqlite3_column_text(stmt, index) else { return "" }
    return String(cString: ptr)
}

private func optionalColumnText(_ stmt: OpaquePointer, _ index: Int32) -> String? {
    if sqlite3_column_type(stmt, index) == SQLITE_NULL { return nil }
    return columnText(stmt, index)
}

// SQLite text bind helper (transient)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private func bindText(_ stmt: OpaquePointer, _ idx: Int32, _ value: String) {
    sqlite3_bind_text(stmt, idx, value, -1, SQLITE_TRANSIENT)
}

private func bindOptionalText(_ stmt: OpaquePointer, _ idx: Int32, _ value: String?) {
    if let value {
        bindText(stmt, idx, value)
    } else {
        sqlite3_bind_null(stmt, idx)
    }
}
