# Clipboard Gallery Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the centered clipboard list with a bottom horizontal card gallery, make Enter/double-click the primary paste action, and expose aipaste through a visible menu-bar icon that toggles the gallery directly.

**Architecture:** Keep the existing AppKit `NSPanel` shell and SwiftUI content. Move deterministic selection, deletion, copy status, and thumbnail access into `HistoryViewModel`; route window-level keyboard events and panel positioning through `HistoryPanelController`; keep app lifecycle actions in `AppState`; render the gallery through focused SwiftUI views.

**Tech Stack:** Swift 5, SwiftUI, AppKit, XCTest, XcodeGen, macOS 13+

## Global Constraints

- Preserve macOS 13.0 as the deployment target.
- Preserve the default global shortcut `⇧⌘V`.
- Preserve local-only SQLite/media persistence and the existing schema.
- Keep the app as an `LSUIElement` menu-bar accessory with no Dock icon.
- Do not add third-party dependencies, AI, cloud sync, favorites, or file clipboard support.
- Do not create a Git commit, push, PR, or branch unless the user explicitly asks.
- Generated `aipaste.xcodeproj/` remains untracked; regenerate it after source/test additions.

---

## File Map

- Create `aipaste/UI/History/HistoryCardView.swift`: render one text or image card, selected styling, double-click, and context menu.
- Create `aipasteTests/HistoryViewModelTests.swift`: cover selection movement, neighbor selection after delete, clear-all, and image decoding.
- Modify `aipaste/UI/History/HistoryViewModel.swift`: deterministic gallery actions, non-blocking status, accessibility state, and thumbnail loading.
- Modify `aipaste/UI/History/HistoryView.swift`: bottom-gallery toolbar, horizontal scroll view, empty state, status banner, and overflow menu.
- Modify `aipaste/UI/History/HistoryPanelController.swift`: bottom placement, borderless material panel, keyboard routing, and non-modal paste degradation.
- Modify `aipaste/App/MenuBarController.swift`: replace the text/menu status item with a template SF Symbol and direct toggle action.
- Modify `aipaste/App/AppState.swift`: wire preferences, clear/quit callbacks, and the new menu-bar behavior.
- Modify `scripts/manual-smoke.md`: document the new click, keyboard, card, thumbnail, and accessibility flows.

---

### Task 1: Make gallery selection and actions deterministic

**Files:**
- Create: `aipasteTests/HistoryViewModelTests.swift`
- Modify: `aipaste/UI/History/HistoryViewModel.swift`

**Interfaces:**
- Consumes: `SnippetStore.list(query:limit:)`, `SnippetStore.delete(id:)`, `SnippetStore.deleteAll()`, `SnippetStore.mediaData(for:)`, and `PasteEngine.perform(_:mode:)`.
- Produces: `selectPrevious()`, `selectNext()`, `clearHistory()`, `image(for:) -> NSImage?`, `requestAccessibilitySettings()`, and published `requiresAccessibility`.

- [ ] **Step 1: Add a focused test fixture and failing navigation tests**

Create `aipasteTests/HistoryViewModelTests.swift` with an isolated SQLite/media root and three dated snippets:

```swift
import AppKit
import XCTest
@testable import aipaste

@MainActor
final class HistoryViewModelTests: XCTestCase {
    private var tempRoot: URL!
    private var store: SnippetStore!
    private var model: HistoryViewModel!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("aipaste-history-model-\(UUID().uuidString)", isDirectory: true)
        let paths = AppPaths(root: tempRoot)
        try paths.ensureDirectories()
        store = SnippetStore(
            database: try Database(path: paths.databaseFile),
            mediaStore: MediaStore(directory: paths.mediaDirectory),
            maxSnippetCount: 20
        )
        try store.upsert(Snippet.makeText(body: "old", hash: "old", updatedAt: Date(timeIntervalSince1970: 1)))
        try store.upsert(Snippet.makeText(body: "middle", hash: "middle", updatedAt: Date(timeIntervalSince1970: 2)))
        try store.upsert(Snippet.makeText(body: "new", hash: "new", updatedAt: Date(timeIntervalSince1970: 3)))
        model = HistoryViewModel(store: store, pasteEngine: PasteEngine(store: store))
        model.reload()
    }

    override func tearDownWithError() throws {
        model = nil
        store = nil
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testSelectionMovesWithinBounds() {
        XCTAssertEqual(model.selectedID, model.snippets[0].id)
        model.selectNext()
        XCTAssertEqual(model.selectedID, model.snippets[1].id)
        model.selectNext()
        model.selectNext()
        XCTAssertEqual(model.selectedID, model.snippets[2].id)
        model.selectPrevious()
        XCTAssertEqual(model.selectedID, model.snippets[1].id)
    }

    func testDeleteSelectsNearestRemainingCard() {
        model.selectNext()
        model.deleteSelected()
        XCTAssertEqual(model.snippets.map(\.textBody), ["new", "old"])
        XCTAssertEqual(model.selectedID, model.snippets[1].id)
    }

    func testClearHistoryResetsSelection() {
        model.clearHistory()
        XCTAssertTrue(model.snippets.isEmpty)
        XCTAssertNil(model.selectedID)
    }
}
```

- [ ] **Step 2: Regenerate the project and prove the new tests fail**

Run:

```bash
./scripts/generate-project.sh
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' \
  -only-testing:aipasteTests/HistoryViewModelTests test
```

Expected: compile failure because `selectNext()`, `selectPrevious()`, and `clearHistory()` do not exist.

- [ ] **Step 3: Implement navigation, neighbor-preserving deletion, and clear-all**

Add these behaviors to `HistoryViewModel`:

```swift
@Published var requiresAccessibility = false

private var selectedIndex: Int? {
    guard let selectedID else { return nil }
    return snippets.firstIndex { $0.id == selectedID }
}

func selectPrevious() {
    guard !snippets.isEmpty else { return }
    let index = max(0, (selectedIndex ?? 0) - 1)
    selectedID = snippets[index].id
}

func selectNext() {
    guard !snippets.isEmpty else { return }
    let index = min(snippets.count - 1, (selectedIndex ?? -1) + 1)
    selectedID = snippets[index].id
}

func deleteSelected() {
    guard let id = selectedID, let oldIndex = selectedIndex else { return }
    do {
        try store.delete(id: id)
        snippets = try store.list(query: query.isEmpty ? nil : query, limit: AppConstants.listLimit)
        selectedID = snippets.isEmpty ? nil : snippets[min(oldIndex, snippets.count - 1)].id
        showStatus("Deleted")
    } catch {
        showStatus(error.localizedDescription, autoDismiss: false)
    }
}

func clearHistory() {
    do {
        try store.deleteAll()
        snippets = []
        selectedID = nil
        showStatus("History cleared")
    } catch {
        showStatus(error.localizedDescription, autoDismiss: false)
    }
}
```

Use a cancellable `Task` so success messages disappear after 1.5 seconds, while errors remain visible:

```swift
private var statusResetTask: Task<Void, Never>?

private func showStatus(_ message: String, autoDismiss: Bool = true) {
    statusResetTask?.cancel()
    statusMessage = message
    guard autoDismiss else { return }
    statusResetTask = Task { [weak self] in
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        guard !Task.isCancelled else { return }
        self?.statusMessage = nil
    }
}
```

Replace the paste result handling with:

```swift
switch try pasteEngine.perform(snippet, mode: .paste) {
case .pasted:
    requiresAccessibility = false
    statusMessage = nil
case .copiedOnly(let reason):
    switch reason {
    case .modeCopyOnly:
        showStatus("Copied")
    case .accessibilityDenied:
        requiresAccessibility = true
        showStatus("Copied — enable Accessibility to paste automatically", autoDismiss: false)
    }
}
```

Remove `try?` swallowing from copy/delete paths. Do not call `AccessibilityPermission.openSystemSettings()` automatically.

- [ ] **Step 4: Add and test thumbnail decoding**

Add this method:

```swift
func image(for snippet: Snippet) -> NSImage? {
    guard snippet.kind == .image else { return nil }
    do {
        guard let data = try store.mediaData(for: snippet) else { return nil }
        return NSImage(data: data)
    } catch {
        return nil
    }
}

func requestAccessibilitySettings() {
    AccessibilityPermission.openSystemSettings()
}
```

Extend the test file with a 1×1 image test:

```swift
func testImageLoadsFromMediaStore() throws {
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 1,
        pixelsHigh: 1,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 4,
        bitsPerPixel: 32
    )!
    let png = bitmap.representation(using: .png, properties: [:])!
    let snippet = Snippet.makeImage(
        hash: "image",
        byteSize: png.count,
        mediaPath: "unused.png",
        previewText: "Image (1×1)"
    )
    try store.upsert(snippet, imageData: png)
    model.reload()

    let stored = try XCTUnwrap(model.snippets.first { $0.id == snippet.id })
    XCTAssertNotNil(model.image(for: stored))
}
```

- [ ] **Step 5: Run the focused tests**

Run the same `-only-testing:aipasteTests/HistoryViewModelTests` command.

Expected: all `HistoryViewModelTests` pass with zero failures.

---

### Task 2: Render real clipboard cards and the horizontal gallery

**Files:**
- Create: `aipaste/UI/History/HistoryCardView.swift`
- Modify: `aipaste/UI/History/HistoryView.swift`

**Interfaces:**
- Consumes: `HistoryViewModel.snippets`, `selectedID`, `image(for:)`, `copySelected()`, `deleteSelected()`, and callbacks supplied by the panel controller.
- Produces: `HistoryCardView` and a redesigned `HistoryView` initializer with `onPasteAndClose`, `onClose`, `onShowPreferences`, and `onQuit` closures.

- [ ] **Step 1: Create the reusable card view**

Implement a fixed-size card with text/image branches and selected styling:

```swift
struct HistoryCardView: View {
    let snippet: Snippet
    let image: NSImage?
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if snippet.kind == .image {
                imageContent
            } else {
                Text(snippet.textBody ?? snippet.previewText)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(7)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            Divider()
            HStack {
                Text(snippet.sourceAppName ?? "Unknown app")
                Spacer()
                Text(snippet.updatedAt, style: .relative)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(width: 210, height: 190)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
        }
        .scaleEffect(isSelected ? 1.025 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(count: 2, perform: onPaste)
        .onTapGesture(perform: onSelect)
        .contextMenu {
            Button("Copy", action: onCopy)
            Button("Delete", role: .destructive, action: onDelete)
        }
        .animation(.easeOut(duration: 0.14), value: isSelected)
    }
}
```

Implement `imageContent` without macOS 14-only APIs:

```swift
@ViewBuilder
private var imageContent: some View {
    if let image {
        Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    } else {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: 30))
            Text("Image unavailable")
                .font(.caption)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 2: Replace the list and footer with the gallery shell**

Rewrite `HistoryView` as:

```swift
VStack(spacing: 14) {
    toolbar
    if model.snippets.isEmpty {
        emptyState
    } else {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(model.snippets) { snippet in
                        HistoryCardView(
                            snippet: snippet,
                            image: model.image(for: snippet),
                            isSelected: model.selectedID == snippet.id,
                            onSelect: { model.selectedID = snippet.id },
                            onPaste: {
                                model.selectedID = snippet.id
                                onPasteAndClose()
                            },
                            onCopy: {
                                model.selectedID = snippet.id
                                model.copySelected()
                            },
                            onDelete: {
                                model.selectedID = snippet.id
                                model.deleteSelected()
                            }
                        )
                            .id(snippet.id)
                    }
                }
                .padding(.horizontal, 4)
            }
            .onChange(of: model.selectedID) { id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }
    statusBanner
}
.padding(16)
.background(.ultraThinMaterial)
```

The toolbar must show the name/count, a rounded search field, and a `Menu` containing Settings, Clear History, and Quit. Clear History must use a SwiftUI `confirmationDialog` before calling `model.clearHistory()`.

- [ ] **Step 3: Add focus, empty, and accessibility states**

Use `@FocusState private var searchFocused: Bool`, focus the search field on first appearance, show “No clipboard history yet” versus “No results” based on the query, and render a compact status banner. When `requiresAccessibility` is true, include an “Open Settings” button that calls `model.requestAccessibilitySettings()`.

- [ ] **Step 4: Build the app target**

Run:

```bash
./scripts/generate-project.sh
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **` with no Swift compile errors.

---

### Task 3: Turn the history window into a bottom keyboard-driven panel

**Files:**
- Modify: `aipaste/UI/History/HistoryPanelController.swift`

**Interfaces:**
- Consumes: the redesigned `HistoryView`, `HistoryViewModel` navigation/actions, and callbacks from `AppState`.
- Produces: `configure(store:pasteEngine:onShowPreferences:onQuit:)`, bottom-screen positioning, and panel-scoped keyboard routing.

- [ ] **Step 1: Expand configuration callbacks**

Store closures for preferences and quit:

```swift
private var onShowPreferences: (() -> Void)?
private var onQuit: (() -> Void)?
private var keyMonitor: Any?

func configure(
    store: SnippetStore,
    pasteEngine: PasteEngine,
    onShowPreferences: @escaping () -> Void,
    onQuit: @escaping () -> Void
) {
    model = HistoryViewModel(store: store, pasteEngine: pasteEngine)
    self.onShowPreferences = onShowPreferences
    self.onQuit = onQuit
}
```

Pass these closures into `HistoryView` and hide the panel before showing Preferences.

- [ ] **Step 2: Create a borderless floating panel**

Use a clear, shadowed panel:

```swift
let panel = NSPanel(
    contentRect: NSRect(x: 0, y: 0, width: 960, height: 285),
    styleMask: [.borderless, .nonactivatingPanel],
    backing: .buffered,
    defer: false
)
panel.isFloatingPanel = true
panel.level = .floating
panel.isOpaque = false
panel.backgroundColor = .clear
panel.hasShadow = true
panel.hidesOnDeactivate = false
panel.isReleasedWhenClosed = false
```

Keep SwiftUI responsible for material and rounded clipping.

- [ ] **Step 3: Position the panel on the active screen**

Resolve the screen containing `NSEvent.mouseLocation`, falling back to `NSScreen.main`. Compute width as `min(max(visibleFrame.width * 0.8, 720), 1120)`, height as `285`, center horizontally, and set `y` to `visibleFrame.minY + 24` so the panel clears the Dock-visible area.

- [ ] **Step 4: Route panel keyboard events**

Install one local key-down monitor while the panel is visible:

```swift
keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
    guard let self, self.panel?.isKeyWindow == true, let model = self.model else { return event }
    if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
       event.charactersIgnoringModifiers?.lowercased() == "c" {
        model.copySelected()
        return nil
    }
    switch event.keyCode {
    case 123: model.selectPrevious(); return nil
    case 124: model.selectNext(); return nil
    case 36, 76: self.pasteSelectedThenHide(); return nil
    case 51, 117: model.deleteSelected(); return nil
    case 53: self.hide(); return nil
    default: return event
    }
}
```

Remove the monitor in `hide()` and `deinit`, and reinstall it in `show()` so monitors never accumulate.

- [ ] **Step 5: Remove the modal accessibility alert**

Keep the existing “hide, wait 0.05 seconds, paste” ordering, but delete the `NSAlert` branch. Accessibility failure must be represented only by the ViewModel status state when the panel is next shown.

- [ ] **Step 6: Build and manually check panel geometry**

Run the app with `⌘R`, invoke `⇧⌘V`, and verify the panel is centered above the bottom of the active screen. Resize the active display arrangement if available and reopen the panel to confirm geometry recalculates on every show.

---

### Task 4: Replace the invisible text entry with a direct-action menu-bar icon

**Files:**
- Modify: `aipaste/App/MenuBarController.swift`
- Modify: `aipaste/App/AppState.swift`

**Interfaces:**
- Consumes: `AppState.historyPanel.toggle()`, `showPreferences()`, and `quit()`.
- Produces: a square `NSStatusItem` with a template image and direct click action.

- [ ] **Step 1: Add a direct menu-bar toggle action**

Change `MenuBarController.install()` to:

```swift
func install() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let button = item.button {
        if let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "aipaste") {
            image.isTemplate = true
            button.image = image
        } else {
            button.title = "aipaste"
        }
        button.toolTip = "aipaste clipboard history (⇧⌘V)"
        button.target = self
        button.action = #selector(toggleHistory)
    }
    statusItem = item
}

@objc private func toggleHistory() {
    appState.historyPanel.toggle()
}
```

Remove the attached `NSMenu` and obsolete selector methods. Keep the strong `statusItem` property so the icon remains registered.

- [ ] **Step 2: Wire the new panel callbacks in `AppState`**

Replace the existing configure call with:

```swift
historyPanel.configure(
    store: store,
    pasteEngine: pasteEngine,
    onShowPreferences: { [weak self] in self?.showPreferences() },
    onQuit: { [weak self] in self?.quit() }
)
```

Keep the global hotkey callback unchanged so both entry paths call the same panel controller.

- [ ] **Step 3: Build and inspect the live menu bar**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **`. Launch from Xcode, verify the monochrome clipboard icon is visible in both light and dark appearances, then click it twice to confirm direct open/close behavior.

---

### Task 5: Regression tests, documentation, and visual acceptance

**Files:**
- Modify: `scripts/manual-smoke.md`
- Verify: all source and test files above

**Interfaces:**
- Consumes: the completed gallery, panel, ViewModel, and menu-bar behavior.
- Produces: repeatable verification evidence and an updated manual checklist.

- [ ] **Step 1: Update the manual smoke checklist**

Replace the old list/button expectations with explicit checks for:

```markdown
- [ ] Menu bar shows a monochrome clipboard icon in light and dark mode
- [ ] Clicking the icon directly opens and closes the history gallery
- [ ] ⇧⌘V opens a bottom horizontal card strip on the active screen
- [ ] Text cards show content/source/time and image cards show real thumbnails
- [ ] Left/Right changes selection and scrolls the selected card into view
- [ ] Enter and double-click paste and close the gallery
- [ ] Command-C copies without closing; Delete removes; Esc closes
- [ ] Card context menu supports Copy and Delete
- [ ] Missing Accessibility permission degrades to copy with an in-panel action
- [ ] Settings, Clear History, and Quit are reachable from the overflow menu
```

- [ ] **Step 2: Run the complete unit-test suite**

Run:

```bash
./scripts/generate-project.sh
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test
```

Expected: `** TEST SUCCEEDED **` and zero failed tests.

- [ ] **Step 3: Run a clean app build**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' clean build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Perform the visual and interaction checklist**

Run from Xcode and verify every new item in `scripts/manual-smoke.md` with at least one text record and one image record. Specifically test the Accessibility-granted and Accessibility-denied paths, because they produce different paste outcomes.

- [ ] **Step 5: Inspect the final workspace without committing**

Run:

```bash
git status --short
git diff --check
git diff --stat
```

Expected: only the intended source, tests, docs, and existing generated `aipaste.xcodeproj/` appear; `git diff --check` produces no output. Leave all changes in the working tree for user review.
