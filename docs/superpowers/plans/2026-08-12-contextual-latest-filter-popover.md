# Contextual Latest Navigation and Filter Popover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the always-visible latest icon and flattened content segments with a contextual “Back to Latest” text action and one structured macOS filter popover.

**Architecture:** `HistoryViewModel` owns structured-filter count and reset behavior. A testable `GalleryScrollMetrics` helper combines with a native `NSClipView` bounds observer to drive contextual-navigation visibility reliably during live macOS scrolling. `HistoryView` keeps search/filter centered while a new `HistoryFilterPopover` owns content type, favorites, source app, and clear-filter controls.

**Tech Stack:** Swift 5, SwiftUI, AppKit, Combine, XCTest, Xcode/macOS 13+

## Global Constraints

- Keep the search/filter task group fixed at the horizontal center when contextual navigation appears or disappears.
- Show “Back to Latest” only when the gallery has results and its horizontal offset exceeds `70pt`.
- Use a 160ms fade plus 4pt horizontal entrance unless Reduce Motion is enabled.
- The 280pt popover contains content type, favorites-only, source app, and Clear Filters.
- Filter badge count includes content type, favorites, and source app, but never search text.
- Clear Filters preserves search text.
- Keep native horizontal scroll indicators and all existing query semantics.
- Do not change database schema or add dependencies.
- Do not commit, push, create a PR, or merge; leave changes in the current `main` working tree.

---

### Task 1: Structured filter state

**Files:**
- Modify: `aipasteTests/HistoryViewModelTests.swift`
- Modify: `aipaste/UI/History/HistoryViewModel.swift`

**Interfaces:**
- Produces: `HistoryViewModel.activeFilterCount: Int`, `hasStructuredFilters: Bool`, and `clearStructuredFilters()`.

- [x] Add failing tests proving counts 0–3, search exclusion, and structured reset preserving `query`.
- [x] Run the focused tests and verify compilation fails because the new API is absent.
- [x] Implement `activeFilterCount` by summing non-default content kind, favorites-only, and non-nil source app; derive `hasStructuredFilters` from the count.
- [x] Implement `clearStructuredFilters()` to reset only those three properties.
- [x] Run focused and complete `HistoryViewModelTests` and verify zero failures.

### Task 2: Testable gallery-position threshold

**Files:**
- Create: `aipaste/UI/History/GalleryScrollMetrics.swift`
- Modify: `aipasteTests/HistoryViewModelTests.swift`

**Interfaces:**
- Produces: `GalleryScrollMetrics.shouldShowBackToLatest(leadingX:hasResults:) -> Bool`, `threshold = 70`, and `GalleryScrollOffsetObserver`.

- [x] Add failing boundary tests for `0`, `-70`, below `-70`, and empty results.
- [x] Regenerate the Xcode project and run focused tests to verify the missing type fails compilation.
- [x] Implement the pure threshold helper and a native scroll-offset observer with exact `leadingX < -70 && hasResults` semantics.
- [x] Run focused tests and verify zero failures.

### Task 3: Structured filter popover

**Files:**
- Create: `aipaste/UI/History/HistoryFilterPopover.swift`
- Modify: `aipaste/Localization/L10n.swift`
- Modify: `aipaste/UI/History/HistoryView.swift`

**Interfaces:**
- Consumes: `SnippetKindFilter`, `availableSourceApps`, filter setters, `activeFilterCount`, and `clearStructuredFilters()`.
- Produces: a 280pt filter popover and a single toolbar `Filters` button.

- [x] Add localized strings for Filters, Favorites, Favorites Only, Source App, Clear Filters, and active-filter accessibility text.
- [x] Build `HistoryFilterPopover` with a vertical content-type picker, favorites Toggle, source-app Menu, dividers, and conditional Clear Filters button.
- [x] Keep the popover open while conditions change; bind all controls directly to the shared ViewModel state.
- [x] Remove flattened content segments, standalone favorites, and standalone app controls from the toolbar.
- [x] Keep only search/count plus one Filters button in the centered cluster; display a `1...3` badge when filters are active.
- [x] Run the six-theme hosting test and verify the new popover content can be hosted without failure.

### Task 4: Contextual latest navigation

**Files:**
- Modify: `aipaste/UI/History/HistoryView.swift`

**Interfaces:**
- Consumes: `GalleryScrollMetrics`, `GalleryScrollOffsetObserver`, `model.selectLatest()`, and `latestScrollToken`.
- Produces: contextual `chevron.left + Back to Latest` navigation in the left brand group.

- [x] Observe the enclosing native `NSClipView` bounds so live trackpad and scrollbar scrolling always report position changes.
- [x] Update local `isAwayFromLatest` from the native horizontal offset and reset it when results become empty.
- [x] Replace the square icon with a plain localized text action shown only when the threshold helper returns true.
- [x] Apply a 160ms fade/4pt move transition, switching to fade-only or no movement under Reduce Motion.
- [x] Preserve `.leading` latest scrolling, `.center` keyboard scrolling, and the native scroll indicator.
- [x] Build and run all-theme hosting tests.

### Task 5: Documentation and final verification

**Files:**
- Modify: `README.md`
- Modify: `scripts/manual-smoke.md`

**Interfaces:**
- Produces: accurate product instructions and final build evidence.

- [x] Update README to describe contextual Back to Latest and the unified Filters popover.
- [x] Update manual checks for the 70pt threshold, fixed centered search, badge semantics, continuous popover interaction, and search-preserving clear.
- [x] Regenerate the project with `./scripts/generate-project.sh`.
- [x] Run the complete XCTest suite and require `** TEST SUCCEEDED **` with zero failures.
- [x] Run `xcodebuild ... clean build` and require both clean and build success.
- [x] Run `git diff --check`, inspect `git status --short` and the focused diff, and leave all changes uncommitted on `main`.
