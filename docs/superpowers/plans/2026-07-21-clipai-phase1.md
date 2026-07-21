# clipai Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a personal-daily-use macOS menu-bar clipboard history app (**clipai**) that records **text + images**, supports search/select/paste (with Accessibility degrade), ignore rules, capacity prune, and local SQLite persistence—no AI, sync, files, or pinboards.

**Architecture:** Single-process modular menu-bar app (`LSUIElement`). Unidirectional flow: `ClipboardMonitor` → `PasteboardIngester` → `SnippetStore`; UI and `PasteEngine` read/write store and pasteboard. Internal-write flag prevents paste loops. Data under `~/Library/Application Support/clipai/`.

**Tech Stack:** Swift 5.9+, AppKit + SwiftUI (history/prefs views in `NSPanel`), SQLite3 (system `SQLite3` module), CryptoKit (SHA256), Carbon/AppKit global hotkey, XCTest. Bundle ID `com.eden.clipai`. Prefer **XcodeGen** (`project.yml`) to generate `clipai.xcodeproj`.

**Spec:** `docs/superpowers/specs/2026-07-20-clipai-design.md`

**Defaults locked in this plan:**
- Hotkey: **⇧⌘V** (keyCode `9` + `shiftKey` + `cmdKey`)
- `maxSnippetCount`: **500**
- Monitor interval: **0.3s**
- Text max: **200_000** UTF-8 bytes (truncate)
- Image max: **20 * 1024 * 1024** bytes (skip)
- UI: SwiftUI hosted in nonactivating `NSPanel`

**Prerequisite:** Full **Xcode** app installed and selected (`xcode-select -s /Applications/Xcode.app/Contents/Developer`). Command Line Tools alone cannot run the app target reliably.

---

## File map (create during tasks)

```text
/Users/wangqd/restart/clipai/
├── README.md
├── project.yml                          # XcodeGen
├── scripts/
│   ├── generate-project.sh
│   └── manual-smoke.md
├── clipai/
│   ├── App/
│   │   ├── ClipAIApp.swift
│   │   ├── AppState.swift
│   │   ├── AppConstants.swift
│   │   ├── MenuBarController.swift
│   │   └── HotKeyManager.swift
│   ├── Clipboard/
│   │   ├── ClipboardMonitor.swift
│   │   ├── PasteboardIngester.swift
│   │   ├── PasteboardReader.swift
│   │   ├── ContentHasher.swift
│   │   └── InternalPasteboardWriteGate.swift
│   ├── Storage/
│   │   ├── Models.swift
│   │   ├── AppPaths.swift
│   │   ├── Database.swift
│   │   ├── MediaStore.swift
│   │   └── SnippetStore.swift
│   ├── Paste/
│   │   ├── PasteboardWriter.swift
│   │   ├── PasteEngine.swift
│   │   └── AccessibilityPermission.swift
│   ├── Rules/
│   │   ├── DefaultIgnoreList.swift
│   │   └── IgnoreRuleStore.swift
│   ├── Preferences/
│   │   └── AppPreferences.swift
│   ├── UI/
│   │   ├── History/
│   │   │   ├── HistoryPanelController.swift
│   │   │   ├── HistoryView.swift
│   │   │   └── HistoryViewModel.swift
│   │   └── Preferences/
│   │       ├── PreferencesWindowController.swift
│   │       └── PreferencesView.swift
│   └── Resources/
│       ├── Info.plist
│       ├── clipai.entitlements
│       └── Assets.xcassets
└── clipaiTests/
    ├── ContentHasherTests.swift
    ├── IgnoreRuleStoreTests.swift
    ├── SnippetStoreTests.swift
    └── PasteboardIngesterTests.swift
```

---

### Task 1: Repo skeleton + XcodeGen project + constants

**Files:**
- Create: `project.yml`
- Create: `scripts/generate-project.sh`
- Create: `clipai/App/AppConstants.swift`
- Create: `clipai/App/ClipAIApp.swift` (minimal `@main` stub)
- Create: `clipai/Resources/Info.plist`
- Create: `clipai/Resources/clipai.entitlements`
- Create: `README.md` (stub)
- Modify: (none required beyond existing `.gitignore` / docs)

- [ ] **Step 1: Write `AppConstants.swift`**

```swift
import Foundation

enum AppConstants {
    static let bundleID = "com.eden.clipai"
    static let appSupportFolderName = "clipai"
    static let databaseFileName = "clipai.sqlite"
    static let mediaFolderName = "media"
    static let dbFolderName = "db"

    static let monitorInterval: TimeInterval = 0.3
    static let defaultMaxSnippetCount = 500
    static let listLimit = 100
    static let maxTextUTF8Bytes = 200_000
    static let maxImageBytes = 20 * 1024 * 1024

    /// UserDefaults keys (suite = bundleID when using suiteName)
    enum DefaultsKey {
        static let maxSnippetCount = "maxSnippetCount"
        static let ignoredBundleIds = "ignoredBundleIds"
        static let launchAtLogin = "launchAtLogin"
        static let hasSeededIgnoreList = "hasSeededIgnoreList"
    }
}
```

- [ ] **Step 2: Write minimal `ClipAIApp.swift`**

```swift
import SwiftUI

@main
struct ClipAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar app: no main window scene required.
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wired in Task 6/7 (AppState). Keep empty until then.
        NSApp.setActivationPolicy(.accessory)
    }
}
```

- [ ] **Step 3: Write `Info.plist` (menu bar accessory)**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleName</key>
    <string>clipai</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © eden. Local clipboard history. No cloud upload in Phase 1.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
```

- [ ] **Step 4: Write empty entitlements (non-sandboxed personal build)**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Phase 1: do not enable App Sandbox -->
</dict>
</plist>
```

- [ ] **Step 5: Write `project.yml` for XcodeGen**

```yaml
name: clipai
options:
  bundleIdPrefix: com.eden
  deploymentTarget:
    macOS: "13.0"
  createIntermediateGroups: true
settings:
  base:
    SWIFT_VERSION: "5.0"
    MACOSX_DEPLOYMENT_TARGET: "13.0"
targets:
  clipai:
    type: application
    platform: macOS
    sources:
      - path: clipai
        excludes:
          - "**/*.md"
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.eden.clipai
        PRODUCT_NAME: clipai
        INFOPLIST_FILE: clipai/Resources/Info.plist
        CODE_SIGN_ENTITLEMENTS: clipai/Resources/clipai.entitlements
        CODE_SIGN_STYLE: Automatic
        COMBINE_HIDPI_IMAGES: YES
        LD_RUNPATH_SEARCH_PATHS: "@executable_path/../Frameworks"
        ENABLE_HARDENED_RUNTIME: YES
        GENERATE_INFOPLIST_FILE: NO
    scheme:
      testTargets:
        - clipaiTests
  clipaiTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - path: clipaiTests
    dependencies:
      - target: clipai
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.eden.clipai.tests
        GENERATE_INFOPLIST_FILE: YES
```

- [ ] **Step 6: Write `scripts/generate-project.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Install XcodeGen: brew install xcodegen" >&2
  exit 1
fi
xcodegen generate
echo "Generated clipai.xcodeproj"
```

- [ ] **Step 7: Write README stub**

```markdown
# clipai

Local macOS clipboard history (Phase 1). Bundle ID: `com.eden.clipai`.

## Requirements

- macOS 13+
- Full Xcode (not only Command Line Tools)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Generate & run

```bash
./scripts/generate-project.sh
open clipai.xcodeproj
# Product → Run (⌘R)
```

## Data

`~/Library/Application Support/clipai/`

## Docs

- Spec: `docs/superpowers/specs/2026-07-20-clipai-design.md`
- Plan: `docs/superpowers/plans/2026-07-21-clipai-phase1.md`

Phase 1 does **not** upload clipboard contents.
```

- [ ] **Step 8: Create empty Assets + test placeholder, generate project**

```bash
mkdir -p clipai/Resources/Assets.xcassets/AppIcon.appiconset
mkdir -p clipaiTests
cat > clipai/Resources/Assets.xcassets/Contents.json <<'EOF'
{"info":{"author":"xcode","version":1}}
EOF
cat > clipai/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json <<'EOF'
{"images":[],"info":{"author":"xcode","version":1}}
EOF
cat > clipaiTests/SmokeTests.swift <<'EOF'
import XCTest
@testable import clipai

final class SmokeTests: XCTestCase {
    func testConstants() {
        XCTAssertEqual(AppConstants.bundleID, "com.eden.clipai")
    }
}
EOF
chmod +x scripts/generate-project.sh
./scripts/generate-project.sh
```

Expected: `clipai.xcodeproj` exists.

- [ ] **Step 9: Build smoke (requires full Xcode)**

```bash
xcodebuild -project clipai.xcodeproj -scheme clipai -destination 'platform=macOS' build
```

Expected: **BUILD SUCCEEDED**

- [ ] **Step 10: Commit**

```bash
git add project.yml scripts/generate-project.sh clipai clipaiTests README.md
git commit -m "chore: scaffold clipai XcodeGen project and constants"
```

---

### Task 2: Models, paths, SQLite, media, SnippetStore (+ tests)

**Files:**
- Create: `clipai/Storage/Models.swift`
- Create: `clipai/Storage/AppPaths.swift`
- Create: `clipai/Storage/Database.swift`
- Create: `clipai/Storage/MediaStore.swift`
- Create: `clipai/Storage/SnippetStore.swift`
- Create: `clipaiTests/SnippetStoreTests.swift`

- [ ] **Step 1: Write failing store tests first**

```swift
import XCTest
@testable import clipai

final class SnippetStoreTests: XCTestCase {
    var tempRoot: URL!
    var store: SnippetStore!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("clipai-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        let paths = AppPaths(root: tempRoot)
        try paths.ensureDirectories()
        let db = try Database(path: paths.databaseFile)
        let media = MediaStore(directory: paths.mediaDirectory)
        store = SnippetStore(database: db, mediaStore: media, maxSnippetCount: 3)
    }

    override func tearDownWithError() throws {
        store = nil
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testUpsertTextAndList() throws {
        let s = Snippet.makeText(body: "hello", hash: "h1")
        try store.upsert(s)
        let list = try store.list(query: nil, limit: 10)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].textBody, "hello")
    }

    func testDedupeRefreshesUpdatedAtNotDuplicate() throws {
        var first = Snippet.makeText(body: "same", hash: "same-hash")
        first.updatedAt = Date(timeIntervalSince1970: 1000)
        try store.upsert(first)
        Thread.sleep(forTimeInterval: 0.01)
        let second = Snippet.makeText(body: "same", hash: "same-hash")
        try store.upsert(second)
        let list = try store.list(query: nil, limit: 10)
        XCTAssertEqual(list.count, 1)
        XCTAssertGreaterThan(list[0].updatedAt, first.updatedAt)
    }

    func testSearchByPreview() throws {
        try store.upsert(Snippet.makeText(body: "alpha one", hash: "a"))
        try store.upsert(Snippet.makeText(body: "beta two", hash: "b"))
        let list = try store.list(query: "beta", limit: 10)
        XCTAssertEqual(list.count, 1)
        XCTAssertEqual(list[0].textBody, "beta two")
    }

    func testCapacityPrunesOldest() throws {
        try store.upsert(Snippet.makeText(body: "1", hash: "1", updatedAt: Date(timeIntervalSince1970: 1)))
        try store.upsert(Snippet.makeText(body: "2", hash: "2", updatedAt: Date(timeIntervalSince1970: 2)))
        try store.upsert(Snippet.makeText(body: "3", hash: "3", updatedAt: Date(timeIntervalSince1970: 3)))
        try store.upsert(Snippet.makeText(body: "4", hash: "4", updatedAt: Date(timeIntervalSince1970: 4)))
        let list = try store.list(query: nil, limit: 10)
        XCTAssertEqual(list.count, 3)
        XCTAssertFalse(list.contains { $0.contentHash == "1" })
    }

    func testDeleteRemovesRow() throws {
        let s = Snippet.makeText(body: "x", hash: "x")
        try store.upsert(s)
        try store.delete(id: s.id)
        XCTAssertTrue(try store.list(query: nil, limit: 10).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests — expect FAIL (types missing)**

```bash
./scripts/generate-project.sh
xcodebuild -project clipai.xcodeproj -scheme clipai -destination 'platform=macOS' test
```

Expected: compile errors for missing `SnippetStore` / `Snippet`.

- [ ] **Step 3: Implement `Models.swift`**

```swift
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
```

- [ ] **Step 4: Implement `AppPaths.swift`**

```swift
import Foundation

struct AppPaths: Sendable {
    let root: URL

    init(root: URL) {
        self.root = root
    }

    static func defaultPaths() throws -> AppPaths {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return AppPaths(root: base.appendingPathComponent(AppConstants.appSupportFolderName, isDirectory: true))
    }

    var databaseDirectory: URL {
        root.appendingPathComponent(AppConstants.dbFolderName, isDirectory: true)
    }

    var databaseFile: URL {
        databaseDirectory.appendingPathComponent(AppConstants.databaseFileName)
    }

    var mediaDirectory: URL {
        root.appendingPathComponent(AppConstants.mediaFolderName, isDirectory: true)
    }

    func ensureDirectories() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
    }
}
```

- [ ] **Step 5: Implement `Database.swift` (SQLite3)**

```swift
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
```

- [ ] **Step 6: Implement `MediaStore.swift`**

```swift
import Foundation

final class MediaStore: @unchecked Sendable {
    let directory: URL
    private let fm = FileManager.default

    init(directory: URL) {
        self.directory = directory
    }

    func absoluteURL(relativePath: String) -> URL {
        directory.appendingPathComponent(relativePath)
    }

    /// Returns relative file name stored in DB.
    func writeImage(id: String, data: Data, fileExtension: String = "png") throws -> String {
        let name = "\(id).\(fileExtension)"
        let url = absoluteURL(relativePath: name)
        try data.write(to: url, options: .atomic)
        return name
    }

    func read(relativePath: String) throws -> Data {
        try Data(contentsOf: absoluteURL(relativePath: relativePath))
    }

    func delete(relativePath: String) throws {
        let url = absoluteURL(relativePath: relativePath)
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    func deleteAll() throws {
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in contents {
            try fm.removeItem(at: url)
        }
    }
}
```

- [ ] **Step 7: Implement `SnippetStore.swift`**

```swift
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
                    sqlite3_bind_text(stmt, 4, existingID, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
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
                let id = String(cString: sqlite3_column_text(stmt, 0))
                let media: String? = sqlite3_column_type(stmt, 1) == SQLITE_NULL
                    ? nil : String(cString: sqlite3_column_text(stmt, 1))
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
            return String(cString: sqlite3_column_text(stmt, 0))
        }
    }

    private func fetchMediaPath(id: String) throws -> String? {
        try database.withStatement("SELECT media_path FROM snippets WHERE id = ?;") { stmt in
            bindText(stmt, 1, id)
            guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
            if sqlite3_column_type(stmt, 0) == SQLITE_NULL { return nil }
            return String(cString: sqlite3_column_text(stmt, 0))
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
        func text(_ i: Int32) -> String { String(cString: sqlite3_column_text(stmt, i)) }
        func optText(_ i: Int32) -> String? {
            sqlite3_column_type(stmt, i) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(stmt, i))
        }
        return Snippet(
            id: text(0),
            createdAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 1)),
            updatedAt: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 2)),
            kind: SnippetKind(rawValue: text(3)) ?? .text,
            contentHash: text(4),
            previewText: text(5),
            textBody: optText(6),
            mediaPath: optText(7),
            byteSize: Int(sqlite3_column_int64(stmt, 8)),
            sourceBundleId: optText(9),
            sourceAppName: optText(10)
        )
    }
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
```

- [ ] **Step 8: Run tests — expect PASS**

```bash
./scripts/generate-project.sh
xcodebuild -project clipai.xcodeproj -scheme clipai -destination 'platform=macOS' test
```

Expected: all `SnippetStoreTests` **passed**.

- [ ] **Step 9: Commit**

```bash
git add clipai/Storage clipaiTests/SnippetStoreTests.swift
git commit -m "feat: add SQLite SnippetStore with dedupe and capacity"
```

---

### Task 3: ContentHasher, Ignore rules, PasteboardReader, Ingester (+ tests)

**Files:**
- Create: `clipai/Clipboard/ContentHasher.swift`
- Create: `clipai/Rules/DefaultIgnoreList.swift`
- Create: `clipai/Rules/IgnoreRuleStore.swift`
- Create: `clipai/Clipboard/PasteboardReader.swift`
- Create: `clipai/Clipboard/PasteboardIngester.swift`
- Create: `clipai/Clipboard/InternalPasteboardWriteGate.swift`
- Create: `clipaiTests/ContentHasherTests.swift`
- Create: `clipaiTests/IgnoreRuleStoreTests.swift`
- Create: `clipaiTests/PasteboardIngesterTests.swift`

- [ ] **Step 1: Write hasher + ignore tests**

```swift
// ContentHasherTests.swift
import XCTest
@testable import clipai

final class ContentHasherTests: XCTestCase {
    func testTextHashStable() {
        let a = ContentHasher.hashText("hello")
        let b = ContentHasher.hashText("hello")
        XCTAssertEqual(a, b)
        XCTAssertFalse(a.isEmpty)
    }

    func testTextHashDiffers() {
        XCTAssertNotEqual(ContentHasher.hashText("a"), ContentHasher.hashText("b"))
    }

    func testImageHashStable() {
        let data = Data([0x01, 0x02, 0x03])
        XCTAssertEqual(ContentHasher.hashImage(data), ContentHasher.hashImage(data))
    }
}
```

```swift
// IgnoreRuleStoreTests.swift
import XCTest
@testable import clipai

final class IgnoreRuleStoreTests: XCTestCase {
    func testDefaultContainsKeychain() {
        let defaults = UserDefaults(suiteName: "com.eden.clipai.tests.ignore.\(UUID().uuidString)")!
        let store = IgnoreRuleStore(defaults: defaults, seedIfNeeded: true)
        XCTAssertTrue(store.isIgnored(bundleId: "com.apple.keychainaccess"))
    }

    func testAddAndRemove() {
        let defaults = UserDefaults(suiteName: "com.eden.clipai.tests.ignore.\(UUID().uuidString)")!
        let store = IgnoreRuleStore(defaults: defaults, seedIfNeeded: false)
        store.add(bundleId: "com.example.app")
        XCTAssertTrue(store.isIgnored(bundleId: "com.example.app"))
        store.remove(bundleId: "com.example.app")
        XCTAssertFalse(store.isIgnored(bundleId: "com.example.app"))
    }
}
```

- [ ] **Step 2: Implement hasher + ignore list + store**

```swift
// ContentHasher.swift
import Foundation
import CryptoKit

enum ContentHasher {
    static func hashText(_ text: String) -> String {
        let payload = Data(("text:" + text).utf8)
        return sha256Hex(payload)
    }

    static func hashImage(_ data: Data) -> String {
        var combined = Data("image:".utf8)
        combined.append(data)
        return sha256Hex(combined)
    }

    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
```

```swift
// DefaultIgnoreList.swift
import Foundation

enum DefaultIgnoreList {
    static let bundleIds: [String] = [
        "com.apple.keychainaccess",
        "com.1password.1password",
        "com.1password.1password-launcher",
        "com.agilebits.onepassword7",
        "com.bitwarden.desktop",
        "com.bitwarden.desktop.safari",
        "org.keepassxc.keepassxc",
        "com.lastpass.LastPass",
    ]
}
```

```swift
// IgnoreRuleStore.swift
import Foundation

final class IgnoreRuleStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = AppConstants.DefaultsKey.ignoredBundleIds
    private let seededKey = AppConstants.DefaultsKey.hasSeededIgnoreList

    init(defaults: UserDefaults = UserDefaults(suiteName: AppConstants.bundleID) ?? .standard,
         seedIfNeeded: Bool = true) {
        self.defaults = defaults
        if seedIfNeeded, defaults.bool(forKey: seededKey) == false {
            defaults.set(DefaultIgnoreList.bundleIds, forKey: key)
            defaults.set(true, forKey: seededKey)
        }
    }

    func list() -> [String] {
        defaults.stringArray(forKey: key) ?? []
    }

    func isIgnored(bundleId: String?) -> Bool {
        guard let bundleId, !bundleId.isEmpty else { return false }
        return Set(list()).contains(bundleId)
    }

    func add(bundleId: String) {
        var set = Set(list())
        set.insert(bundleId)
        defaults.set(Array(set).sorted(), forKey: key)
    }

    func remove(bundleId: String) {
        defaults.set(list().filter { $0 != bundleId }, forKey: key)
    }
}
```

```swift
// InternalPasteboardWriteGate.swift
import Foundation

/// Shared flag so Monitor ignores changes caused by PasteEngine.
final class InternalPasteboardWriteGate: @unchecked Sendable {
    static let shared = InternalPasteboardWriteGate()
    private let lock = NSLock()
    private var depth = 0

    var isInternalWrite: Bool {
        lock.lock(); defer { lock.unlock() }
        return depth > 0
    }

    func begin() {
        lock.lock(); depth += 1; lock.unlock()
    }

    func end() {
        lock.lock(); depth = max(0, depth - 1); lock.unlock()
    }

    func perform(_ body: () throws -> Void) rethrows {
        begin()
        defer { end() }
        try body()
    }
}
```

- [ ] **Step 3: Implement reader + ingester**

```swift
// PasteboardReader.swift
import AppKit

struct PasteboardPayload: Equatable {
    enum Kind: Equatable {
        case text(String)
        case image(Data, preview: String)
    }
    let kind: Kind
}

enum PasteboardReader {
    static func read(_ pasteboard: NSPasteboard = .general) -> PasteboardPayload? {
        if let image = readImage(pasteboard) {
            return PasteboardPayload(kind: .image(image.data, preview: image.preview))
        }
        if let str = pasteboard.string(forType: .string), !str.isEmpty {
            return PasteboardPayload(kind: .text(str))
        }
        return nil
    }

    private static func readImage(_ pasteboard: NSPasteboard) -> (data: Data, preview: String)? {
        if let tiff = pasteboard.data(forType: .tiff), !tiff.isEmpty {
            let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) ?? tiff
            if data.count > AppConstants.maxImageBytes { return nil }
            let preview = previewLabel(for: data)
            return (data, preview)
        }
        if let png = pasteboard.data(forType: .png), !png.isEmpty {
            if png.count > AppConstants.maxImageBytes { return nil }
            return (png, previewLabel(for: png))
        }
        return nil
    }

    private static func previewLabel(for data: Data) -> String {
        if let rep = NSBitmapImageRep(data: data) {
            return "Image (\(rep.pixelsWide)×\(rep.pixelsHigh))"
        }
        return "Image"
    }
}

enum FrontmostAppInfo {
    static func current() -> (bundleId: String?, name: String?) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.bundleIdentifier, app?.localizedName)
    }
}
```

```swift
// PasteboardIngester.swift
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
```

- [ ] **Step 4: Write ingester unit test with fake store**

```swift
// PasteboardIngesterTests.swift
import XCTest
@testable import clipai

private final class FakeStore: SnippetStoring {
    var items: [Snippet] = []
    func upsert(_ snippet: Snippet, imageData: Data?) throws {
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
        let rules = IgnoreRuleStore(defaults: defaults, seedIfNeeded: false)
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
```

- [ ] **Step 5: Run tests**

```bash
./scripts/generate-project.sh
xcodebuild -project clipai.xcodeproj -scheme clipai -destination 'platform=macOS' test
```

Expected: **TEST SUCCEEDED**

- [ ] **Step 6: Commit**

```bash
git add clipai/Clipboard clipai/Rules clipaiTests
git commit -m "feat: add hasher, ignore rules, and pasteboard ingester"
```

---

### Task 4: ClipboardMonitor

**Files:**
- Create: `clipai/Clipboard/ClipboardMonitor.swift`

- [ ] **Step 1: Implement monitor**

```swift
import AppKit

final class ClipboardMonitor {
    private let ingester: PasteboardIngester
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let interval: TimeInterval
    var onIngested: (() -> Void)?

    init(ingester: PasteboardIngester, interval: TimeInterval = AppConstants.monitorInterval) {
        self.ingester = ingester
        self.interval = interval
    }

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        do {
            if try ingester.handlePasteboardChange(pasteboard: pb) {
                onIngested?()
            }
        } catch {
            NSLog("clipai ingest error: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 2: Manual verify later with app run (Task 6). Commit monitor alone.**

```bash
git add clipai/Clipboard/ClipboardMonitor.swift
git commit -m "feat: add clipboard changeCount monitor"
```

---

### Task 5: PasteEngine (write + ⌘V degrade)

**Files:**
- Create: `clipai/Paste/AccessibilityPermission.swift`
- Create: `clipai/Paste/PasteboardWriter.swift`
- Create: `clipai/Paste/PasteEngine.swift`

- [ ] **Step 1: Implement accessibility helper**

```swift
import ApplicationServices
import AppKit

enum AccessibilityPermission {
    static func isTrusted(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemSettings() {
        // macOS 13+ Privacy → Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
```

- [ ] **Step 2: Implement writer + engine**

```swift
// PasteboardWriter.swift
import AppKit

enum PasteboardWriter {
    static func write(_ snippet: Snippet, imageData: Data?, gate: InternalPasteboardWriteGate = .shared) throws {
        try gate.perform {
            let pb = NSPasteboard.general
            pb.clearContents()
            switch snippet.kind {
            case .text:
                pb.setString(snippet.textBody ?? snippet.previewText, forType: .string)
            case .image:
                guard let imageData else {
                    throw PasteError.missingImageData
                }
                pb.setData(imageData, forType: .png)
                if let img = NSImage(data: imageData) {
                    pb.writeObjects([img])
                }
            }
        }
    }
}

enum PasteError: Error {
    case missingImageData
}
```

```swift
// PasteEngine.swift
import AppKit
import Carbon.HIToolbox

enum PasteMode {
    case paste
    case copyOnly
}

enum PasteResult: Equatable {
    case pasted
    case copiedOnly(reason: CopyOnlyReason)

    enum CopyOnlyReason: Equatable {
        case modeCopyOnly
        case accessibilityDenied
    }
}

final class PasteEngine {
    private let store: SnippetStore
    private let gate: InternalPasteboardWriteGate

    init(store: SnippetStore, gate: InternalPasteboardWriteGate = .shared) {
        self.store = store
        self.gate = gate
    }

    @discardableResult
    func perform(_ snippet: Snippet, mode: PasteMode) throws -> PasteResult {
        let imageData = try store.mediaData(for: snippet)
        try PasteboardWriter.write(snippet, imageData: imageData, gate: gate)

        if mode == .copyOnly {
            return .copiedOnly(reason: .modeCopyOnly)
        }
        guard AccessibilityPermission.isTrusted(prompt: true) else {
            return .copiedOnly(reason: .accessibilityDenied)
        }
        postCommandV()
        return .pasted
    }

    private func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyV: CGKeyCode = 9 // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add clipai/Paste
git commit -m "feat: add paste engine with Accessibility degrade"
```

---

### Task 6: AppState, menu bar, hotkey, history panel

**Files:**
- Create: `clipai/App/AppState.swift`
- Create: `clipai/App/MenuBarController.swift`
- Create: `clipai/App/HotKeyManager.swift`
- Create: `clipai/UI/History/HistoryViewModel.swift`
- Create: `clipai/UI/History/HistoryView.swift`
- Create: `clipai/UI/History/HistoryPanelController.swift`
- Modify: `clipai/App/ClipAIApp.swift` (wire AppDelegate → AppState)

- [ ] **Step 1: Implement `AppState` composition root**

```swift
import AppKit
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let store: SnippetStore
    let ignoreRules: IgnoreRuleStore
    let pasteEngine: PasteEngine
    let monitor: ClipboardMonitor
    let preferences: AppPreferences

    let historyPanel = HistoryPanelController()
    private var menuBar: MenuBarController?
    private var hotKeys: HotKeyManager?

    private init() {
        // Temporary placeholders if prefs not yet ready — Task 7 adds AppPreferences fully.
        // For Task 6, inline minimal prefs using UserDefaults suite.
        fatalError("Use bootstrap() — see Step 2 full file")
    }
}
```

Replace with full non-fatal bootstrap (complete file):

```swift
import AppKit
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    private(set) var store: SnippetStore!
    private(set) var ignoreRules: IgnoreRuleStore!
    private(set) var pasteEngine: PasteEngine!
    private(set) var monitor: ClipboardMonitor!
    private(set) var preferences: AppPreferences!

    let historyPanel = HistoryPanelController()
    private var menuBar: MenuBarController?
    private var hotKeys: HotKeyManager?
    private var bootstrapped = false

    func bootstrap() {
        guard !bootstrapped else { return }
        bootstrapped = true
        do {
            let paths = try AppPaths.defaultPaths()
            try paths.ensureDirectories()
            let db = try Database(path: paths.databaseFile)
            let media = MediaStore(directory: paths.mediaDirectory)
            preferences = AppPreferences()
            store = SnippetStore(
                database: db,
                mediaStore: media,
                maxSnippetCount: preferences.maxSnippetCount
            )
            ignoreRules = IgnoreRuleStore()
            pasteEngine = PasteEngine(store: store)
            let ingester = PasteboardIngester(store: store, ignoreRules: ignoreRules)
            monitor = ClipboardMonitor(ingester: ingester)
            monitor.onIngested = { [weak self] in
                Task { @MainActor in
                    self?.historyPanel.reloadIfVisible()
                }
            }
            historyPanel.configure(store: store, pasteEngine: pasteEngine)
            menuBar = MenuBarController(appState: self)
            menuBar?.install()
            hotKeys = HotKeyManager()
            hotKeys?.onToggleHistory = { [weak self] in
                self?.historyPanel.toggle()
            }
            hotKeys?.registerDefault()
            monitor.start()
        } catch {
            NSLog("clipai bootstrap failed: \(error)")
            let alert = NSAlert()
            alert.messageText = "clipai failed to start"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    func showHistory() { historyPanel.show() }
    func showPreferences() { /* Task 7 */ }
    func quit() {
        monitor?.stop()
        NSApp.terminate(nil)
    }
}
```

Note: `AppPreferences` is introduced in Task 7 Step 1 — **implement Task 7 Step 1 before compiling Task 6**, or temporarily hardcode `maxSnippetCount: 500` and add preferences in Task 7. **Preferred order when coding:** implement `AppPreferences.swift` (Task 7 Step 1) first, then rest of Task 6.

- [ ] **Step 2: Implement HotKeyManager (⇧⌘V)**

```swift
import AppKit
import Carbon

final class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var onToggleHistory: (() -> Void)?

    func registerDefault() {
        // keyCode 9 = V, cmd + shift
        var hotKeyID = EventHotKeyID(signature: OSType(0x434C4950), /* 'CLIP' */ id: 1)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else {
            NSLog("clipai hotkey register failed: \(status)")
            return
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), { (_, event, userData) -> OSStatus in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            var hk = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
            if hk.id == 1 {
                DispatchQueue.main.async { manager.onToggleHistory?() }
            }
            return noErr
        }, 1, &eventType, userData, &handler)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
    }
}
```

- [ ] **Step 3: Menu bar**

```swift
import AppKit

@MainActor
final class MenuBarController {
    private let appState: AppState
    private var statusItem: NSStatusItem?

    init(appState: AppState) {
        self.appState = appState
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "clipai"
            button.toolTip = "clipai clipboard history"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show History", action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(showPrefs), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit clipai", action: #selector(quit), keyEquivalent: "q"))
        for item in menu.items {
            item.target = self
        }
        item.menu = menu
        statusItem = item
    }

    @objc private func showHistory() { appState.showHistory() }
    @objc private func showPrefs() { appState.showPreferences() }
    @objc private func quit() { appState.quit() }
}
```

- [ ] **Step 4: History ViewModel + SwiftUI + Panel**

```swift
// HistoryViewModel.swift
import Foundation
import Combine
import AppKit

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var query: String = ""
    @Published var selectedID: String?
    @Published var statusMessage: String?

    private let store: SnippetStore
    private let pasteEngine: PasteEngine

    init(store: SnippetStore, pasteEngine: PasteEngine) {
        self.store = store
        self.pasteEngine = pasteEngine
    }

    func reload() {
        do {
            snippets = try store.list(query: query.isEmpty ? nil : query, limit: AppConstants.listLimit)
            if selectedID == nil { selectedID = snippets.first?.id }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func pasteSelected() {
        guard let id = selectedID, let snippet = snippets.first(where: { $0.id == id }) else { return }
        do {
            let result = try pasteEngine.perform(snippet, mode: .paste)
            switch result {
            case .pasted:
                statusMessage = nil
            case .copiedOnly(let reason):
                switch reason {
                case .modeCopyOnly:
                    statusMessage = "Copied."
                case .accessibilityDenied:
                    statusMessage = "Copied. Enable Accessibility for clipai to auto-paste, then ⌘V."
                    AccessibilityPermission.openSystemSettings()
                }
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func copySelected() {
        guard let id = selectedID, let snippet = snippets.first(where: { $0.id == id }) else { return }
        _ = try? pasteEngine.perform(snippet, mode: .copyOnly)
        statusMessage = "Copied."
    }

    func deleteSelected() {
        guard let id = selectedID else { return }
        try? store.delete(id: id)
        reload()
    }
}
```

```swift
// HistoryView.swift
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: HistoryViewModel
    var onClose: () -> Void
    var onPasteAndClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .padding(8)
                .onChange(of: model.query) { _ in model.reload() }

            List(selection: $model.selectedID) {
                ForEach(model.snippets) { snippet in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snippet.previewText.isEmpty ? snippet.kind.rawValue : snippet.previewText)
                                .lineLimit(2)
                            HStack {
                                if let name = snippet.sourceAppName {
                                    Text(name).font(.caption).foregroundStyle(.secondary)
                                }
                                Text(snippet.updatedAt, style: .time)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(snippet.kind == .image ? "🖼" : "Aa")
                    }
                    .tag(snippet.id)
                }
            }
            .frame(minHeight: 240)

            if let status = model.statusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal)
            }

            HStack {
                Button("Paste") { onPasteAndClose() }
                    .keyboardShortcut(.defaultAction)
                Button("Copy") { model.copySelected() }
                Button("Delete") { model.deleteSelected() }
                Spacer()
                Button("Close") { onClose() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(8)
        }
        .frame(width: 420, height: 360)
        .onAppear { model.reload() }
    }
}
```

```swift
// HistoryPanelController.swift
import AppKit
import SwiftUI

@MainActor
final class HistoryPanelController: NSObject {
    private var panel: NSPanel?
    private var model: HistoryViewModel?

    func configure(store: SnippetStore, pasteEngine: PasteEngine) {
        model = HistoryViewModel(store: store, pasteEngine: pasteEngine)
    }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    func show() {
        guard let model else { return }
        model.reload()
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.title = "clipai"
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            let root = HistoryView(
                model: model,
                onClose: { [weak self] in self?.hide() },
                onPasteAndClose: { [weak self] in
                    model.pasteSelected()
                    self?.hide()
                }
            )
            panel.contentViewController = NSHostingController(rootView: root)
            self.panel = panel
        }
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel!.frame.size
            let origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2
            )
            panel?.setFrameOrigin(origin)
        }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func reloadIfVisible() {
        guard panel?.isVisible == true else { return }
        model?.reload()
    }
}
```

- [ ] **Step 5: Wire AppDelegate**

```swift
// ClipAIApp.swift
import SwiftUI

@main
struct ClipAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in
            AppState.shared.bootstrap()
        }
    }
}
```

- [ ] **Step 6: Build & manual smoke**

```bash
./scripts/generate-project.sh
xcodebuild -project clipai.xcodeproj -scheme clipai -destination 'platform=macOS' build
```

Run from Xcode: copy text → open history from menu → Paste.

- [ ] **Step 7: Commit**

```bash
git add clipai/App clipai/UI
git commit -m "feat: menu bar, hotkey, and history panel"
```

---

### Task 7: Preferences, launch at login, permission UX

**Files:**
- Create: `clipai/Preferences/AppPreferences.swift`
- Create: `clipai/UI/Preferences/PreferencesView.swift`
- Create: `clipai/UI/Preferences/PreferencesWindowController.swift`
- Modify: `clipai/App/AppState.swift` (`showPreferences`)
- Modify: `clipai/App/MenuBarController.swift` if needed

- [ ] **Step 1: `AppPreferences`**

```swift
import Foundation
import ServiceManagement

final class AppPreferences {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = UserDefaults(suiteName: AppConstants.bundleID) ?? .standard) {
        self.defaults = defaults
        if defaults.object(forKey: AppConstants.DefaultsKey.maxSnippetCount) == nil {
            defaults.set(AppConstants.defaultMaxSnippetCount, forKey: AppConstants.DefaultsKey.maxSnippetCount)
        }
    }

    var maxSnippetCount: Int {
        get {
            let v = defaults.integer(forKey: AppConstants.DefaultsKey.maxSnippetCount)
            return v > 0 ? v : AppConstants.defaultMaxSnippetCount
        }
        set { defaults.set(max(1, newValue), forKey: AppConstants.DefaultsKey.maxSnippetCount) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: AppConstants.DefaultsKey.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: AppConstants.DefaultsKey.launchAtLogin)
            if #available(macOS 13.0, *) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    NSLog("clipai launch-at-login error: \(error)")
                }
            }
        }
    }

    var accessibilityTrusted: Bool {
        AccessibilityPermission.isTrusted(prompt: false)
    }
}
```

- [ ] **Step 2: Preferences UI**

```swift
import SwiftUI

struct PreferencesView: View {
    @ObservedObject var model: PreferencesViewModel

    var body: some View {
        Form {
            Section("History") {
                Stepper(value: $model.maxSnippetCount, in: 50...5000, step: 50) {
                    Text("Max items: \(model.maxSnippetCount)")
                }
                .onChange(of: model.maxSnippetCount) { model.applyCapacity() }
                Button("Clear All History…") { model.clearHistory() }
            }
            Section("Privacy") {
                Text("Ignored apps (bundle IDs)")
                List {
                    ForEach(model.ignored, id: \.self) { id in
                        HStack {
                            Text(id).font(.system(.body, design: .monospaced))
                            Spacer()
                            Button("Remove") { model.removeIgnore(id) }
                        }
                    }
                }
                .frame(minHeight: 120)
                HStack {
                    TextField("com.example.app", text: $model.newIgnore)
                    Button("Add") { model.addIgnore() }
                }
            }
            Section("System") {
                Toggle("Launch at login", isOn: $model.launchAtLogin)
                    .onChange(of: model.launchAtLogin) { model.applyLaunch() }
                HStack {
                    Text(model.accessibilityLabel)
                    Spacer()
                    Button("Open Accessibility Settings") {
                        AccessibilityPermission.openSystemSettings()
                    }
                }
            }
            Section("About") {
                Text("clipai Phase 1 — local only, no cloud upload.")
                Text("Data: ~/Library/Application Support/clipai/")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(width: 480, height: 420)
    }
}

@MainActor
final class PreferencesViewModel: ObservableObject {
    @Published var maxSnippetCount: Int
    @Published var launchAtLogin: Bool
    @Published var ignored: [String]
    @Published var newIgnore: String = ""
    @Published var accessibilityLabel: String

    private let preferences: AppPreferences
    private let ignoreRules: IgnoreRuleStore
    private let store: SnippetStore

    init(preferences: AppPreferences, ignoreRules: IgnoreRuleStore, store: SnippetStore) {
        self.preferences = preferences
        self.ignoreRules = ignoreRules
        self.store = store
        maxSnippetCount = preferences.maxSnippetCount
        launchAtLogin = preferences.launchAtLogin
        ignored = ignoreRules.list()
        accessibilityLabel = preferences.accessibilityTrusted
            ? "Accessibility: enabled"
            : "Accessibility: not enabled (paste degrades to copy)"
    }

    func applyCapacity() {
        preferences.maxSnippetCount = maxSnippetCount
        store.setMaxSnippetCount(maxSnippetCount)
    }

    func applyLaunch() {
        preferences.launchAtLogin = launchAtLogin
    }

    func addIgnore() {
        let id = newIgnore.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { return }
        ignoreRules.add(bundleId: id)
        ignored = ignoreRules.list()
        newIgnore = ""
    }

    func removeIgnore(_ id: String) {
        ignoreRules.remove(bundleId: id)
        ignored = ignoreRules.list()
    }

    func clearHistory() {
        try? store.deleteAll()
    }
}
```

```swift
// PreferencesWindowController.swift
import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?

    func show(preferences: AppPreferences, ignoreRules: IgnoreRuleStore, store: SnippetStore) {
        let model = PreferencesViewModel(preferences: preferences, ignoreRules: ignoreRules, store: store)
        let view = PreferencesView(model: model)
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "clipai Preferences"
            window.contentViewController = NSHostingController(rootView: view)
            window.center()
            self.window = window
        } else {
            window?.contentViewController = NSHostingController(rootView: view)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 3: Wire `AppState.showPreferences`**

Add property `let preferencesWindow = PreferencesWindowController()` and:

```swift
func showPreferences() {
    preferencesWindow.show(preferences: preferences, ignoreRules: ignoreRules, store: store)
}
```

- [ ] **Step 4: Build + run prefs manually**

```bash
xcodebuild -project clipai.xcodeproj -scheme clipai -destination 'platform=macOS' build
```

- [ ] **Step 5: Commit**

```bash
git add clipai/Preferences clipai/UI/Preferences clipai/App
git commit -m "feat: preferences, ignore editor, launch at login"
```

---

### Task 8: README complete + manual smoke script + spec status

**Files:**
- Modify: `README.md`
- Create: `scripts/manual-smoke.md`
- Modify: `docs/superpowers/specs/2026-07-20-clipai-design.md` (status → Approved)

- [ ] **Step 1: Expand README**

Include: requirements, generate/run, hotkey ⇧⌘V, Accessibility steps, data path, privacy sentence, test command, link to spec/plan, Phase 1 non-goals.

- [ ] **Step 2: Write `scripts/manual-smoke.md`**

Checklist mirroring design §6.4:

1. Launch clipai (menu bar shows `clipai`)  
2. Copy three different text snippets → open history (menu or ⇧⌘V) → all three listed  
3. Search finds one → Paste into TextEdit  
4. Copy same text twice → still one row (updated time)  
5. Screenshot → image row → paste into Preview/Notes  
6. Add ignore for current test app bundle → copy → not ingested  
7. Turn off Accessibility → Paste says copied / guide  
8. Clear all → list empty  
9. Quit and relaunch → history still present (if not cleared)  
10. Set max items low → oldest pruned  

- [ ] **Step 3: Run unit tests final**

```bash
xcodebuild -project clipai.xcodeproj -scheme clipai -destination 'platform=macOS' test
```

Expected: **TEST SUCCEEDED**

- [ ] **Step 4: Commit**

```bash
git add README.md scripts/manual-smoke.md docs/superpowers/specs/2026-07-20-clipai-design.md
git commit -m "docs: complete Phase 1 README and manual smoke checklist"
```

---

## Self-review (plan vs spec)

| Spec requirement | Task |
|------------------|------|
| Text + image history | 2, 3, 4 |
| Dedupe by hash | 2, 3 |
| Search | 2, 6 |
| Paste + Accessibility degrade | 5, 6 |
| Copy only | 5, 6 |
| Delete / clear | 2, 6, 7 |
| Ignore apps | 3, 7 |
| Capacity 500 | 2, 7 |
| Monitor 0.3s + loop guard | 3, 4, 5 |
| Menu bar + hotkey ⇧⌘V | 6 |
| Launch at login | 7 |
| Local path + privacy docs | 1, 8 |
| Unit tests hash/dedupe/capacity/ignore | 2, 3 |
| No AI / sync / files / pinboard | Out of all tasks |

**Placeholder scan:** No TBD/TODO left for Phase 1 core path. Hotkey rebinding UI deferred (fixed ⇧⌘V) — acceptable Phase 1; note in README.

**Type consistency:** `Snippet`, `SnippetStore.upsert(_:imageData:)`, `PasteMode`, `AppConstants` used uniformly across tasks.

**Implementation note:** Task 6 depends on `AppPreferences` from Task 7 Step 1 — implement that type before compiling AppState, or merge Task 7 Step 1 into the start of Task 6 execution.

---

## Out of plan (Phase 2+)

Pinboard, files, plain-text paste mode polish, FTS5, AI, iCloud, MAS, hotkey recorder UI.
