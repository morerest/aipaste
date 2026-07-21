import Foundation
import SQLite3

enum DatabaseError: Error {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case notFound
}

final class Database: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()

    init(path: URL) throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path.path, &db, flags, nil) != SQLITE_OK {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        try exec("""
        CREATE TABLE IF NOT EXISTS snippets (
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
        CREATE UNIQUE INDEX IF NOT EXISTS idx_snippets_kind_hash
          ON snippets(kind, content_hash);
        CREATE INDEX IF NOT EXISTS idx_snippets_updated
          ON snippets(updated_at DESC);
        """)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    func exec(_ sql: String) throws {
        lock.lock()
        defer { lock.unlock() }
        var err: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &err) != SQLITE_OK {
            let message = err.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(err)
            throw DatabaseError.stepFailed(message)
        }
    }

    func withStatement<T>(_ sql: String, _ body: (OpaquePointer) throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        return try body(stmt)
    }
}
