import Foundation
import SQLite3

final class SnippetStore: @unchecked Sendable {
    private let database: Database
    private let mediaStore: MediaStore
    private let queue = DispatchQueue(label: "com.eden.aipaste.store")
    private var maxSnippetCount: Int
    private var maxFavoriteCount: Int

    init(
        database: Database,
        mediaStore: MediaStore,
        maxSnippetCount: Int = AppConstants.defaultMaxSnippetCount,
        maxFavoriteCount: Int = AppConstants.defaultMaxFavoriteCount
    ) {
        self.database = database
        self.mediaStore = mediaStore
        self.maxSnippetCount = max(1, maxSnippetCount)
        self.maxFavoriteCount = max(1, maxFavoriteCount)
    }

    /// Re-marks an existing snippet as the newest copy, so `list` puts it first.
    /// Used after app-initiated pasteboard writes (the write itself is a copy);
    /// provenance fields stay untouched, unlike the external dedup path.
    func touch(id: String, date: Date = Date()) throws {
        try queue.sync {
            try database.withStatement(
                "UPDATE snippets SET updated_at = ? WHERE id = ?;"
            ) { stmt in
                sqlite3_bind_double(stmt, 1, date.timeIntervalSince1970)
                bindText(stmt, 2, id)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DatabaseError.stepFailed("touch failed")
                }
            }
        }
    }

    func setMaxSnippetCount(_ value: Int) {
        queue.sync { maxSnippetCount = max(1, value) }
    }

    func setMaxFavoriteCount(_ value: Int) {
        queue.sync { maxFavoriteCount = max(1, value) }
    }

    func upsert(
        _ snippet: Snippet,
        imageData: Data? = nil,
        pasteboardSnapshot: PasteboardSnapshot.Items? = nil
    ) throws {
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
            if snippet.hasImage, let imageData {
                let rel = try mediaStore.writeImage(id: snippet.id, data: imageData)
                toInsert.mediaPath = rel
                if snippet.kind == .mixed {
                    toInsert.byteSize = imageData.count + (snippet.textBody?.utf8.count ?? 0)
                } else {
                    toInsert.byteSize = imageData.count
                }
            }

            if let pasteboardSnapshot, !pasteboardSnapshot.isEmpty {
                let encoded = try PasteboardSnapshot.encode(pasteboardSnapshot)
                _ = try mediaStore.writeSnapshot(id: snippet.id, data: encoded)
            }

            try database.withStatement(
                """
                INSERT INTO snippets
                (id, created_at, updated_at, kind, content_hash, preview_text, text_body, media_path, byte_size,
                 source_bundle_id, source_app_name, is_pinned, pinned_at, pin_note)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
                sqlite3_bind_int(stmt, 12, toInsert.isPinned ? 1 : 0)
                if let pinnedAt = toInsert.pinnedAt {
                    sqlite3_bind_double(stmt, 13, pinnedAt.timeIntervalSince1970)
                } else {
                    sqlite3_bind_null(stmt, 13)
                }
                bindOptionalText(stmt, 14, Snippet.normalizedPinNote(toInsert.pinNote))
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DatabaseError.stepFailed("insert failed")
                }
            }
            try enforceCapacityUnlocked()
        }
    }

    /// - Parameters:
    ///   - query: optional text search (preview, body, source app name, or favorite note).
    ///   - sourceAppName: optional exact source app display name filter.
    ///   - favoritesOnly: when true, only pinned items (ordered by pin time).
    ///   - kind: optional exact content-kind filter.
    func list(
        query: String?,
        sourceAppName: String? = nil,
        favoritesOnly: Bool = false,
        kind: SnippetKind? = nil,
        limit: Int
    ) throws -> [Snippet] {
        try queue.sync {
            let trimmed = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let app = sourceAppName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // Favorites: most recently pinned first; history: most recently updated.
            let order = favoritesOnly
                ? "ORDER BY IFNULL(pinned_at, updated_at) DESC"
                : "ORDER BY updated_at DESC"

            var conditions = [favoritesOnly ? "is_pinned = 1" : "1=1"]
            var bindings: [String] = []

            if !app.isEmpty {
                conditions.append("source_app_name = ?")
                bindings.append(app)
            }
            if let kind {
                conditions.append("kind = ?")
                bindings.append(kind.rawValue)
            }
            if !trimmed.isEmpty {
                conditions.append(
                    """
                    (
                      preview_text LIKE ? COLLATE NOCASE
                      OR IFNULL(text_body, '') LIKE ? COLLATE NOCASE
                      OR IFNULL(source_app_name, '') LIKE ? COLLATE NOCASE
                      OR IFNULL(pin_note, '') LIKE ? COLLATE NOCASE
                    )
                    """
                )
                let pattern = "%\(trimmed)%"
                bindings.append(contentsOf: Array(repeating: pattern, count: 4))
            }

            let sql = """
            SELECT id, created_at, updated_at, kind, content_hash, preview_text, text_body, media_path, byte_size,
                   source_bundle_id, source_app_name, is_pinned, pinned_at, pin_note
            FROM snippets
            WHERE \(conditions.joined(separator: " AND "))
            \(order) LIMIT ?;
            """

            return try database.withStatement(sql) { stmt in
                for (offset, value) in bindings.enumerated() {
                    bindText(stmt, Int32(offset + 1), value)
                }
                sqlite3_bind_int(stmt, Int32(bindings.count + 1), Int32(limit))
                return try readAll(stmt)
            }
        }
    }

    /// Distinct source apps (display name + latest bundle id), most recently used first.
    func distinctSourceApps(limit: Int = 40) throws -> [SourceAppOption] {
        try queue.sync {
            try database.withStatement(
                """
                SELECT
                    source_app_name,
                    (
                        SELECT s2.source_bundle_id
                        FROM snippets s2
                        WHERE s2.source_app_name = snippets.source_app_name
                        ORDER BY s2.updated_at DESC
                        LIMIT 1
                    ) AS bundle_id,
                    MAX(updated_at) AS last_seen
                FROM snippets
                WHERE source_app_name IS NOT NULL AND TRIM(source_app_name) != ''
                GROUP BY source_app_name
                ORDER BY last_seen DESC
                LIMIT ?;
                """
            ) { stmt in
                sqlite3_bind_int(stmt, 1, Int32(limit))
                var apps: [SourceAppOption] = []
                while sqlite3_step(stmt) == SQLITE_ROW {
                    guard let name = optionalColumnText(stmt, 0), !name.isEmpty else { continue }
                    apps.append(
                        SourceAppOption(
                            name: name,
                            bundleId: optionalColumnText(stmt, 1)
                        )
                    )
                }
                return apps
            }
        }
    }

    func pinnedCount() throws -> Int {
        try queue.sync {
            try database.withStatement("SELECT COUNT(*) FROM snippets WHERE is_pinned = 1;") { stmt in
                guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
                return Int(sqlite3_column_int(stmt, 0))
            }
        }
    }

    /// Toggle or set pin. Returns the new pin state.
    @discardableResult
    func setPinned(id: String, pinned: Bool) throws -> Bool {
        try queue.sync {
            guard try fetchExists(id: id) else { throw PinError.notFound }
            if pinned {
                let alreadyPinned: Bool = try database.withStatement(
                    "SELECT is_pinned FROM snippets WHERE id = ?;"
                ) { stmt in
                    bindText(stmt, 1, id)
                    guard sqlite3_step(stmt) == SQLITE_ROW else { return false }
                    return sqlite3_column_int(stmt, 0) != 0
                }
                if !alreadyPinned {
                    let count: Int = try database.withStatement(
                        "SELECT COUNT(*) FROM snippets WHERE is_pinned = 1;"
                    ) { stmt in
                        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
                        return Int(sqlite3_column_int(stmt, 0))
                    }
                    if count >= maxFavoriteCount {
                        throw PinError.favoritesFull(limit: maxFavoriteCount)
                    }
                }
                try database.withStatement(
                    "UPDATE snippets SET is_pinned = 1, pinned_at = ? WHERE id = ?;"
                ) { stmt in
                    sqlite3_bind_double(stmt, 1, Date().timeIntervalSince1970)
                    bindText(stmt, 2, id)
                    guard sqlite3_step(stmt) == SQLITE_DONE else {
                        throw DatabaseError.stepFailed("pin failed")
                    }
                }
                return true
            } else {
                // Drop note with unpin so labels stay favorites-only.
                try database.withStatement(
                    "UPDATE snippets SET is_pinned = 0, pinned_at = NULL, pin_note = NULL WHERE id = ?;"
                ) { stmt in
                    bindText(stmt, 1, id)
                    guard sqlite3_step(stmt) == SQLITE_DONE else {
                        throw DatabaseError.stepFailed("unpin failed")
                    }
                }
                // After unpin, history capacity may need to prune again.
                try enforceCapacityUnlocked()
                return false
            }
        }
    }

    /// Set or clear a short favorite note (max `AppConstants.maxPinNoteLength` characters).
    /// Item should be pinned; if not pinned, pin is required first by the UI.
    func setPinNote(id: String, note: String?) throws {
        try queue.sync {
            guard try fetchExists(id: id) else { throw PinError.notFound }
            let normalized = Snippet.normalizedPinNote(note)
            try database.withStatement(
                "UPDATE snippets SET pin_note = ? WHERE id = ?;"
            ) { stmt in
                bindOptionalText(stmt, 1, normalized)
                bindText(stmt, 2, id)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DatabaseError.stepFailed("set pin note failed")
                }
            }
        }
    }

    func delete(id: String) throws {
        try queue.sync {
            let media = try fetchMediaPath(id: id)
            try mediaStore.deleteMediaBundle(snippetID: id, mediaPath: media)
            try database.withStatement("DELETE FROM snippets WHERE id = ?;") { stmt in
                bindText(stmt, 1, id)
                guard sqlite3_step(stmt) == SQLITE_DONE else {
                    throw DatabaseError.stepFailed("delete failed")
                }
            }
        }
    }

    /// Deletes every snippet including favorites (full wipe).
    func deleteAll() throws {
        try queue.sync {
            try database.exec("DELETE FROM snippets;")
            try mediaStore.deleteAll()
        }
    }

    /// Clears history but **keeps favorites** (V1 product default).
    func deleteUnpinned() throws {
        try queue.sync {
            let victims: [(String, String?)] = try database.withStatement(
                "SELECT id, media_path FROM snippets WHERE is_pinned = 0;"
            ) { stmt in
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
                try mediaStore.deleteMediaBundle(snippetID: id, mediaPath: media)
                try database.withStatement("DELETE FROM snippets WHERE id = ?;") { stmt in
                    bindText(stmt, 1, id)
                    _ = sqlite3_step(stmt)
                }
            }
        }
    }

    func mediaData(for snippet: Snippet) throws -> Data? {
        guard let rel = snippet.mediaPath else { return nil }
        return try mediaStore.read(relativePath: rel)
    }

    /// Full original pasteboard flavors, if captured at ingest time.
    /// Returns nil on missing/corrupt snapshot — never throws (paste must still work).
    func pasteboardSnapshot(for snippet: Snippet) -> PasteboardSnapshot.Items? {
        let rel = mediaStore.snapshotRelativePath(forSnippetID: snippet.id)
        let url = mediaStore.absoluteURL(relativePath: rel)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let data = try? mediaStore.read(relativePath: rel) else { return nil }
        return try? PasteboardSnapshot.decode(data)
    }

    // MARK: - private

    /// Capacity applies only to **unpinned** history items.
    private func enforceCapacityUnlocked() throws {
        let unpinnedCount: Int = try database.withStatement(
            "SELECT COUNT(*) FROM snippets WHERE is_pinned = 0;"
        ) { stmt in
            guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
            return Int(sqlite3_column_int(stmt, 0))
        }
        guard unpinnedCount > maxSnippetCount else { return }
        let overflow = unpinnedCount - maxSnippetCount
        let victims: [(String, String?)] = try database.withStatement(
            """
            SELECT id, media_path FROM snippets
            WHERE is_pinned = 0
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
            try mediaStore.deleteMediaBundle(snippetID: id, mediaPath: media)
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

    private func fetchExists(id: String) throws -> Bool {
        try database.withStatement("SELECT 1 FROM snippets WHERE id = ? LIMIT 1;") { stmt in
            bindText(stmt, 1, id)
            return sqlite3_step(stmt) == SQLITE_ROW
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
        let pinned = sqlite3_column_int(stmt, 11) != 0
        let pinnedAt: Date? = {
            if sqlite3_column_type(stmt, 12) == SQLITE_NULL { return nil }
            return Date(timeIntervalSince1970: sqlite3_column_double(stmt, 12))
        }()
        return Snippet(
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
            sourceAppName: optionalColumnText(stmt, 10),
            isPinned: pinned,
            pinnedAt: pinnedAt,
            pinNote: optionalColumnText(stmt, 13)
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
