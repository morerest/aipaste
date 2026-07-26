import Foundation
import SQLite3

enum DatabaseError: LocalizedError {
    case openFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .openFailed(let message): return "Database open failed: \(message)"
        case .prepareFailed(let message): return "Database prepare failed: \(message)"
        case .stepFailed(let message): return "Database error: \(message)"
        case .notFound: return "Database record not found"
        }
    }
}

final class Database: @unchecked Sendable {
    private var db: OpaquePointer?
    private let lock = NSLock()

    init(path: URL) throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(path.path, &db, flags, nil) != SQLITE_OK {
            throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(db)))
        }
        // 1) Ensure table exists. Existing installs keep their old column set
        //    (CREATE IF NOT EXISTS is a no-op); new installs get the full schema.
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
          source_app_name TEXT,
          is_pinned INTEGER NOT NULL DEFAULT 0,
          pinned_at REAL,
          pin_note TEXT
        );
        """)
        // 2) Migrate older DBs before indexes that reference new columns.
        try migrateIfNeeded()
        // 3) Indexes (safe once pin columns exist).
        try exec("""
        CREATE UNIQUE INDEX IF NOT EXISTS idx_snippets_kind_hash
          ON snippets(kind, content_hash);
        CREATE INDEX IF NOT EXISTS idx_snippets_updated
          ON snippets(updated_at DESC);
        CREATE INDEX IF NOT EXISTS idx_snippets_pinned
          ON snippets(is_pinned, pinned_at DESC);
        """)
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    /// Adds pin / note columns for databases created before those features shipped.
    private func migrateIfNeeded() throws {
        let columns = try tableColumns(named: "snippets")
        if !columns.contains("is_pinned") {
            try exec("ALTER TABLE snippets ADD COLUMN is_pinned INTEGER NOT NULL DEFAULT 0;")
        }
        if !columns.contains("pinned_at") {
            try exec("ALTER TABLE snippets ADD COLUMN pinned_at REAL;")
        }
        if !columns.contains("pin_note") {
            try exec("ALTER TABLE snippets ADD COLUMN pin_note TEXT;")
        }
    }

    private func tableColumns(named table: String) throws -> Set<String> {
        // PRAGMA cannot bind table names; `table` is always a fixed internal identifier.
        try withStatement("PRAGMA table_info(\(table));") { stmt in
            var names = Set<String>()
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let ptr = sqlite3_column_text(stmt, 1) {
                    names.insert(String(cString: ptr))
                }
            }
            return names
        }
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
