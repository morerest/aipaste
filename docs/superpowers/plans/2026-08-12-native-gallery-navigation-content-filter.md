# Native Gallery Navigation and Content Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the card-overlapping return control with native macOS toolbar navigation, restore the system horizontal scroll indicator, and add an adaptive single-choice All/Text/Images/Mixed filter.

**Architecture:** `SnippetStore` accepts an optional `SnippetKind` and builds one parameterized query from condition and binding arrays, avoiding an eight-branch query matrix. `HistoryViewModel` owns a UI-facing `SnippetKindFilter`; `HistoryView` renders the same state as either a native segmented picker or a compact menu via `ViewThatFits`, while the existing dedicated scroll token continues to drive leading-edge navigation.

**Tech Stack:** Swift 5, SwiftUI, AppKit, Combine, SQLite3, XCTest, Xcode/macOS 13+

## Global Constraints

- Keep `SnippetKind` storage values exactly `text`, `image`, and `mixed`.
- Content filtering is single-choice: `All / Text / Images / Mixed` and `全部 / 文字 / 图片 / 图文`.
- Content type intersects with text search, source app, and favorites-only filtering.
- Remove the circular card-area overlay; no custom scrollbar, paging arrows, or edge gradient.
- Use the native macOS horizontal scroll indicator and respect the system scrollbar preference.
- Keep keyboard navigation centered and Back to Latest leading-aligned.
- Back to Latest remains in a stable toolbar position and is disabled, not hidden, when results are empty.
- Do not change database schema, paste/copy/delete/favorite behavior, thumbnail loading, or the macOS 13 deployment target.
- Do not add dependencies.
- Do not commit, push, create a PR, or merge; leave changes in the current `main` working tree.

## File Map

- `aipaste/Storage/Models.swift` — define the UI-facing `SnippetKindFilter` and its optional storage-kind mapping.
- `aipaste/Storage/SnippetStore.swift` — apply an optional kind to the parameterized history query.
- `aipasteTests/SnippetStoreTests.swift` — prove kind-only and combined query behavior.
- `aipaste/UI/History/HistoryViewModel.swift` — own content-filter state and pass it into storage.
- `aipasteTests/HistoryViewModelTests.swift` — prove default, reload, active-filter, and clear-all behavior.
- `aipaste/Localization/L10n.swift` — provide localized filter labels and help text.
- `aipaste/UI/History/HistoryView.swift` — move Back to Latest into the toolbar, add adaptive filtering, and restore native scroll indicators.
- `aipasteTests/WorkbenchThemeHostingTests.swift` — continue hosting the finished toolbar in all six themes.
- `README.md` and `scripts/manual-smoke.md` — document the final UI and manual checks.
- `docs/superpowers/specs/2026-08-12-native-gallery-navigation-content-filter-design.md` — approved design source.

---

### Task 1: Add parameterized content-kind storage filtering

**Files:**
- Modify: `aipasteTests/SnippetStoreTests.swift`
- Modify: `aipaste/Storage/SnippetStore.swift`

**Interfaces:**
- Consumes: existing `Snippet.kind: SnippetKind` persisted in the `kind` column.
- Produces: `SnippetStore.list(query:sourceAppName:favoritesOnly:kind:limit:) throws -> [Snippet]` with `kind` defaulting to `nil`.

- [ ] **Step 1: Read the test-quality rules**

Read `/Users/wangqd/.codex/plugins/cache/openai-curated-remote/superpowers/6.2.0/skills/test-driven-development/writing-good-tests.md` completely. The production break each test catches is a missing or incorrectly combined SQL `kind = ?` condition.

- [ ] **Step 2: Write failing kind-only tests with real stored snippets**

Add to `SnippetStoreTests`:

```swift
func testFilterByEachSnippetKind() throws {
    let png = Self.onePixelPNG()
    try store.upsert(Snippet.makeText(body: "text only", hash: "kind-text"))
    try store.upsert(
        Snippet.makeImage(
            hash: "kind-image",
            byteSize: png.count,
            mediaPath: "kind-image.png",
            previewText: "Image"
        ),
        imageData: png
    )
    try store.upsert(
        Snippet.makeMixed(
            body: "mixed caption",
            imageHash: "kind-mixed",
            byteSize: png.count,
            mediaPath: "kind-mixed.png",
            imagePreview: "Image"
        ),
        imageData: png
    )

    XCTAssertEqual(try store.list(query: nil, kind: .text, limit: 10).map(\.kind), [.text])
    XCTAssertEqual(try store.list(query: nil, kind: .image, limit: 10).map(\.kind), [.image])
    XCTAssertEqual(try store.list(query: nil, kind: .mixed, limit: 10).map(\.kind), [.mixed])
    XCTAssertEqual(Set(try store.list(query: nil, kind: nil, limit: 10).map(\.kind)), [.text, .image, .mixed])
}
```

- [ ] **Step 3: Write a failing all-conditions intersection test**

Add:

```swift
func testKindCombinesWithSearchAppAndFavorites() throws {
    let png = Self.onePixelPNG()
    let matching = Snippet.makeMixed(
        body: "project alpha",
        imageHash: "combo-matching",
        byteSize: png.count,
        mediaPath: "combo-matching.png",
        imagePreview: "Image",
        sourceAppName: "Notes"
    )
    let wrongKind = Snippet.makeText(
        body: "project alpha",
        hash: "combo-text",
        sourceAppName: "Notes"
    )
    let wrongApp = Snippet.makeMixed(
        body: "project alpha",
        imageHash: "combo-app",
        byteSize: png.count,
        mediaPath: "combo-app.png",
        imagePreview: "Image",
        sourceAppName: "Preview"
    )
    try store.upsert(matching, imageData: png)
    try store.upsert(wrongKind)
    try store.upsert(wrongApp, imageData: png)
    _ = try store.setPinned(id: matching.id, pinned: true)
    _ = try store.setPinned(id: wrongKind.id, pinned: true)
    _ = try store.setPinned(id: wrongApp.id, pinned: true)

    let result = try store.list(
        query: "alpha",
        sourceAppName: "Notes",
        favoritesOnly: true,
        kind: .mixed,
        limit: 10
    )

    XCTAssertEqual(result.map(\.id), [matching.id])
}
```

- [ ] **Step 4: Run focused tests and verify RED**

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/SnippetStoreTests/testFilterByEachSnippetKind \
  -only-testing:aipasteTests/SnippetStoreTests/testKindCombinesWithSearchAppAndFavorites
```

Expected: compilation fails because `SnippetStore.list` has no `kind` argument.

- [ ] **Step 5: Replace the query branch matrix with one parameterized query**

Change the signature to:

```swift
func list(
    query: String?,
    sourceAppName: String? = nil,
    favoritesOnly: Bool = false,
    kind: SnippetKind? = nil,
    limit: Int
) throws -> [Snippet]
```

Inside `queue.sync`, retain the existing trimmed query/app values and ordering, then replace the four-way switch with:

```swift
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
    let searchClause = """
    (
      preview_text LIKE ? COLLATE NOCASE
      OR IFNULL(text_body, '') LIKE ? COLLATE NOCASE
      OR IFNULL(source_app_name, '') LIKE ? COLLATE NOCASE
      OR IFNULL(pin_note, '') LIKE ? COLLATE NOCASE
    )
    """
    conditions.append(searchClause)
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
```

Update the method documentation to include `kind` as an optional exact content-kind filter.

- [ ] **Step 6: Run focused tests and verify GREEN**

Run the Step 4 command again. Expected: both tests pass.

- [ ] **Step 7: Run all storage tests**

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/SnippetStoreTests
```

Expected: every `SnippetStoreTests` test passes with zero failures.

### Task 2: Add content-filter state to the ViewModel

**Files:**
- Modify: `aipaste/Storage/Models.swift`
- Modify: `aipasteTests/HistoryViewModelTests.swift`
- Modify: `aipaste/UI/History/HistoryViewModel.swift`

**Interfaces:**
- Consumes: `SnippetStore.list(..., kind: SnippetKind?, limit:)` from Task 1.
- Produces: `SnippetKindFilter`, `HistoryViewModel.contentKindFilter`, and `setContentKindFilter(_:)`.

- [ ] **Step 1: Write failing ViewModel tests**

Add to `HistoryViewModelTests`:

```swift
func testContentKindFilterDefaultsToAllAndLoadsMatchingKind() throws {
    let png = Self.tinyPNGData()
    let image = Snippet.makeImage(
        hash: "filter-image",
        byteSize: png.count,
        mediaPath: "filter-image.png",
        previewText: "Image"
    )
    try store.upsert(image, imageData: png)
    model.reload()

    XCTAssertEqual(model.contentKindFilter, .all)

    model.setContentKindFilter(.image)
    model.reload()

    XCTAssertFalse(model.snippets.isEmpty)
    XCTAssertTrue(model.snippets.allSatisfy { $0.kind == .image })
    XCTAssertTrue(model.hasActiveFilters)
}

func testClearAllFiltersAlsoResetsContentKind() {
    model.query = "new"
    model.setSourceAppFilter("Notes")
    model.setFavoritesOnly(true)
    model.setContentKindFilter(.mixed)

    model.clearAllFilters()

    XCTAssertEqual(model.query, "")
    XCTAssertNil(model.sourceAppFilter)
    XCTAssertFalse(model.favoritesOnly)
    XCTAssertEqual(model.contentKindFilter, .all)
    XCTAssertFalse(model.hasActiveFilters)
}
```

- [ ] **Step 2: Run focused tests and verify RED**

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/HistoryViewModelTests/testContentKindFilterDefaultsToAllAndLoadsMatchingKind \
  -only-testing:aipasteTests/HistoryViewModelTests/testClearAllFiltersAlsoResetsContentKind
```

Expected: compilation fails because `SnippetKindFilter`, `contentKindFilter`, and `setContentKindFilter` do not exist.

- [ ] **Step 3: Define the UI-facing filter enum**

Add after `SnippetKind` in `Models.swift`:

```swift
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
```

- [ ] **Step 4: Implement minimal ViewModel state and data flow**

Add:

```swift
@Published var contentKindFilter: SnippetKindFilter = .all
```

Update `reload()` to call:

```swift
let loaded = try store.list(
    query: query.isEmpty ? nil : query,
    sourceAppName: sourceAppFilter,
    favoritesOnly: favoritesOnly,
    kind: contentKindFilter.snippetKind,
    limit: AppConstants.listLimit
)
```

Add:

```swift
func setContentKindFilter(_ filter: SnippetKindFilter) {
    contentKindFilter = filter
}
```

Extend `hasActiveFilters` with `|| contentKindFilter != .all`, and add `contentKindFilter = .all` to `clearAllFilters()`.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the Step 2 command again. Expected: both tests pass.

- [ ] **Step 6: Run all ViewModel tests**

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/HistoryViewModelTests
```

Expected: all ViewModel tests, including the existing Back to Latest tests, pass.

### Task 3: Replace the overlay with native toolbar navigation and adaptive filtering

**Files:**
- Modify: `aipaste/Localization/L10n.swift`
- Modify: `aipaste/UI/History/HistoryView.swift`
- Verify: `aipasteTests/WorkbenchThemeHostingTests.swift`

**Interfaces:**
- Consumes: `SnippetKindFilter.allCases`, `model.contentKindFilter`, `model.setContentKindFilter(_:)`, `model.selectLatest()`, and `model.latestScrollToken`.
- Produces: a stable toolbar navigation item, native segmented/menu filter presentation, and native horizontal scroll indicators.

- [ ] **Step 1: Add localized filter strings**

Add to `WorkbenchStrings`:

```swift
var contentTypeHelp: String { t(en: "Content Type", zh: "内容类型") }
var contentTypeAll: String { t(en: "All", zh: "全部") }
var contentTypeText: String { t(en: "Text", zh: "文字") }
var contentTypeImages: String { t(en: "Images", zh: "图片") }
var contentTypeMixed: String { t(en: "Mixed", zh: "图文") }
```

- [ ] **Step 2: Add one label mapping used by both presentations**

Add to `HistoryView`:

```swift
private func contentKindLabel(_ filter: SnippetKindFilter) -> String {
    switch filter {
    case .all: return s.contentTypeAll
    case .text: return s.contentTypeText
    case .image: return s.contentTypeImages
    case .mixed: return s.contentTypeMixed
    }
}
```

- [ ] **Step 3: Move Back to Latest into the unified filter cluster**

At the start of `filterCluster`'s `HStack`, before `clusterInput`, insert:

```swift
backToLatestToolbarButton
clusterDivider
```

Replace the current circular `backToLatestButton` and `backToLatestBackground` properties with:

```swift
private var backToLatestToolbarButton: some View {
    Button {
        model.selectLatest()
    } label: {
        Image(systemName: "arrow.left.to.line")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(
                model.snippets.isEmpty
                    ? themeStyle.secondaryText.opacity(0.55)
                    : themeStyle.secondaryText
            )
            .frame(width: 36, height: clusterHeight)
            .contentShape(Rectangle())
    }
    .buttonStyle(.borderless)
    .disabled(model.snippets.isEmpty)
    .help(s.backToLatestHelp)
    .accessibilityLabel(s.backToLatestHelp)
}
```

Delete `.overlay(alignment: .trailing) { ... }` from the gallery so no control covers a card.

- [ ] **Step 4: Add native wide and compact content controls**

Add to `HistoryView`:

```swift
private var contentKindFilterControl: some View {
    ViewThatFits(in: .horizontal) {
        contentKindSegmentedPicker
        contentKindMenu
    }
    .help(s.contentTypeHelp)
}

private var contentKindSegmentedPicker: some View {
    Picker(s.contentTypeHelp, selection: $model.contentKindFilter) {
        ForEach(SnippetKindFilter.allCases) { filter in
            Text(contentKindLabel(filter)).tag(filter)
        }
    }
    .labelsHidden()
    .pickerStyle(.segmented)
    .fixedSize(horizontal: true, vertical: false)
    .accessibilityLabel(s.contentTypeHelp)
}

private var contentKindMenu: some View {
    Menu {
        ForEach(SnippetKindFilter.allCases) { filter in
            Button {
                model.setContentKindFilter(filter)
            } label: {
                if model.contentKindFilter == filter {
                    Label(contentKindLabel(filter), systemImage: "checkmark")
                } else {
                    Text(contentKindLabel(filter))
                }
            }
        }
    } label: {
        HStack(spacing: 5) {
            Image(systemName: "line.3.horizontal.decrease.circle")
            Text(contentKindLabel(model.contentKindFilter))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .opacity(0.55)
        }
        .font(.system(size: 11, weight: model.contentKindFilter == .all ? .medium : .semibold))
        .foregroundStyle(themeStyle.compactChromeText(increaseContrast: increaseContrast))
        .padding(.horizontal, 8)
        .frame(height: clusterHeight)
        .contentShape(Rectangle())
    }
    .menuStyle(.borderlessButton)
    .fixedSize(horizontal: true, vertical: false)
    .accessibilityLabel(s.contentTypeHelp)
}
```

- [ ] **Step 5: Place the adaptive filter in the cluster and allow enough width**

Insert before `appFilterMenu`:

```swift
contentKindFilterControl
clusterDivider
```

Update the cluster sizing to:

```swift
.frame(minWidth: 500, idealWidth: 760, maxWidth: 840)
```

The `Picker` is first in `ViewThatFits`, so it is used when its intrinsic width fits; otherwise SwiftUI uses the compact menu.

- [ ] **Step 6: Make content-filter changes reload the gallery**

Extend the existing view task identity so direct segmented-picker bindings and compact-menu changes both reload the query:

```swift
.task(id: "\(model.query)|\(model.sourceAppFilter ?? "")|\(model.favoritesOnly)|\(model.contentKindFilter.rawValue)") {
    model.reload()
}
```

- [ ] **Step 7: Restore the system horizontal scroll indicator**

Change:

```swift
ScrollView(.horizontal, showsIndicators: false)
```

to:

```swift
ScrollView(.horizontal, showsIndicators: true)
```

Keep the existing keyboard-token `.center` and latest-token `.leading` listeners unchanged.

- [ ] **Step 8: Build and run the all-theme hosting test**

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/WorkbenchThemeHostingTests
```

Expected: the project compiles and every theme hosts the finished workbench with zero failures.

### Task 4: Update documentation and verify the final tree

**Files:**
- Modify: `README.md`
- Modify: `scripts/manual-smoke.md`
- Verify: all files from Tasks 1–3

**Interfaces:**
- Consumes: the completed native toolbar, content filter, and native scrollbar behavior.
- Produces: accurate user instructions and final verification evidence.

- [ ] **Step 1: Update README features and action table**

Add `Content-type filtering for text, images, and mixed cards` to Features. Replace the previous Back to Latest action row with:

```markdown
| Return to the latest card | Click `←|` in the search/filter toolbar |
| Filter by content type | Choose All, Text, Images, or Mixed in the toolbar |
```

- [ ] **Step 2: Replace obsolete manual checks**

Remove manual items that describe a right-side circular/overlay button. Under “Gallery and menu bar” and “Keyboard, pointer, and card actions”, add:

```markdown
- [ ] The card area has no floating navigation button and no card is covered by toolbar chrome
- [ ] Horizontal scrolling uses the native macOS indicator and follows the system scrollbar preference
- [ ] Wide layouts show All / Text / Images / Mixed as a segmented control; narrow layouts show the equivalent menu
- [ ] Content type combines correctly with search, source-app, and favorites filters
- [ ] Back to Latest remains in the toolbar, disables for empty results, and restores the newest result to the left edge
- [ ] VoiceOver announces Back to Latest, Content Type, and all four localized choices
```

- [ ] **Step 3: Regenerate the Xcode project**

```bash
./scripts/generate-project.sh
```

Expected: `Generated aipaste.xcodeproj`.

- [ ] **Step 4: Run the complete XCTest suite**

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test
```

Expected: `** TEST SUCCEEDED **` with zero failures.

- [ ] **Step 5: Run a clean build**

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' clean build
```

Expected: `** CLEAN SUCCEEDED **` and `** BUILD SUCCEEDED **`. Existing unrelated project warnings may remain; this feature must add no compile errors or new warnings.

- [ ] **Step 6: Inspect the final working tree**

```bash
git diff --check
git status --short
git diff --stat
git diff -- aipaste/Storage/Models.swift aipaste/Storage/SnippetStore.swift aipaste/UI/History/HistoryViewModel.swift aipaste/UI/History/HistoryView.swift aipaste/Localization/L10n.swift aipasteTests/SnippetStoreTests.swift aipasteTests/HistoryViewModelTests.swift aipasteTests/WorkbenchThemeHostingTests.swift README.md scripts/manual-smoke.md
```

Expected: `git diff --check` prints nothing; only the approved native-navigation/content-filter feature and its design/plan documents are present. Leave every change uncommitted on `main`.
