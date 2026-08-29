# Return to Latest Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a one-click gallery control that selects the newest visible clipboard card and scrolls it to the left edge.

**Architecture:** `HistoryViewModel` owns the selection intent and publishes a dedicated monotonically increasing scroll token. `HistoryView` renders the overlay control and translates token changes into `ScrollViewProxy.scrollTo(_:anchor:)` with a leading anchor, preserving the existing centered keyboard-navigation behavior.

**Tech Stack:** Swift 5, SwiftUI, AppKit, Combine, XCTest, Xcode 16/macOS 13+

## Global Constraints

- The first element of `HistoryViewModel.snippets` is the newest card in the current search/filter result.
- Use SF Symbol `arrow.left.to.line` and localized copy `Back to Latest` / `回到最新`.
- Do not show the control for an empty result.
- Keep the control actionable even when the newest card is already selected, because manual scrolling does not change selection.
- Do not change database ordering, clipboard writes, paste behavior, filtering, or existing direction-key centering.
- Do not add dependencies or raise the macOS 13 deployment target.
- Do not commit, push, create a PR, or merge; leave changes in the working tree.

## File Map

- `aipaste/UI/History/HistoryViewModel.swift` — expose the return-to-latest intent and dedicated scroll token.
- `aipasteTests/HistoryViewModelTests.swift` — prove selection, repeated-request, and empty-list behavior.
- `aipaste/UI/History/HistoryView.swift` — render the trailing overlay button and perform leading-edge scrolling.
- `aipaste/Localization/L10n.swift` — provide English and Simplified Chinese button copy.
- `README.md` — document the new gallery action.
- `scripts/manual-smoke.md` — record manual interaction, theme, and accessibility checks.

---

### Task 1: Model the return-to-latest intent

**Files:**
- Modify: `aipasteTests/HistoryViewModelTests.swift`
- Modify: `aipaste/UI/History/HistoryViewModel.swift`

**Interfaces:**
- Consumes: `HistoryViewModel.snippets: [Snippet]` ordered newest first.
- Produces: `@Published private(set) var latestScrollToken: UInt` and `func selectLatest()`.

- [ ] **Step 1: Read the test quality rules before changing tests**

Read `/Users/wangqd/.codex/plugins/cache/openai-curated-remote/superpowers/6.2.0/skills/test-driven-development/writing-good-tests.md` completely. The production change making the first two tests fail must be the missing `latestScrollToken` / `selectLatest()` API.

- [ ] **Step 2: Write failing tests for non-empty and repeated requests**

Add next to `testSelectionMovesWithinBounds()`:

```swift
func testSelectLatestSelectsFirstSnippetAndRequestsLeadingScroll() {
    model.selectNext()
    let tokenBefore = model.latestScrollToken

    model.selectLatest()

    XCTAssertEqual(model.selectedID, model.snippets.first?.id)
    XCTAssertEqual(model.latestScrollToken, tokenBefore &+ 1)
}

func testSelectLatestRequestsScrollWhenFirstSnippetIsAlreadySelected() {
    XCTAssertEqual(model.selectedID, model.snippets.first?.id)
    let tokenBefore = model.latestScrollToken

    model.selectLatest()

    XCTAssertEqual(model.selectedID, model.snippets.first?.id)
    XCTAssertEqual(model.latestScrollToken, tokenBefore &+ 1)
}

func testSelectLatestDoesNothingForEmptyHistory() {
    model.clearHistory()
    let tokenBefore = model.latestScrollToken

    model.selectLatest()

    XCTAssertNil(model.selectedID)
    XCTAssertEqual(model.latestScrollToken, tokenBefore)
}
```

- [ ] **Step 3: Run the focused tests and verify RED**

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/HistoryViewModelTests/testSelectLatestSelectsFirstSnippetAndRequestsLeadingScroll \
  -only-testing:aipasteTests/HistoryViewModelTests/testSelectLatestRequestsScrollWhenFirstSnippetIsAlreadySelected
```

Expected: compilation fails because `HistoryViewModel` has no `selectLatest()` member and no `latestScrollToken` property. This proves all three tests observe the missing production behavior before implementation.

- [ ] **Step 4: Implement the minimal non-empty behavior**

Add beside `keyboardScrollToken`:

```swift
/// Bumped for explicit “Back to Latest” requests so the gallery can use a leading anchor.
@Published private(set) var latestScrollToken: UInt = 0
```

Add beside `selectPrevious()` / `selectNext()`:

```swift
func selectLatest() {
    guard let id = snippets.first?.id else { return }
    selectedID = id
    latestScrollToken &+= 1
}
```

- [ ] **Step 5: Run the focused tests and verify GREEN**

Run the command from Step 3 again. Expected: both tests pass with zero failures.

- [ ] **Step 6: Run the empty-list edge-case test**

Run the test already added in Step 2:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/HistoryViewModelTests/testSelectLatestDoesNothingForEmptyHistory
```

Expected: PASS. The guard written during the preceding RED/GREEN cycle encodes this approved edge case; do not add more production code.

- [ ] **Step 7: Run all ViewModel tests**

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/HistoryViewModelTests
```

Expected: all `HistoryViewModelTests` pass with zero failures.

### Task 2: Add the localized trailing gallery control

**Files:**
- Modify: `aipaste/Localization/L10n.swift`
- Modify: `aipaste/UI/History/HistoryView.swift`

**Interfaces:**
- Consumes: `HistoryViewModel.selectLatest()`, `HistoryViewModel.latestScrollToken`, and `WorkbenchStrings.backToLatestHelp`.
- Produces: a visible button for non-empty galleries and a leading-edge scroll request for each click.

- [ ] **Step 1: Add localized button copy**

Under `WorkbenchStrings` search/filter strings, add:

```swift
var backToLatestHelp: String {
    t(en: "Back to Latest", zh: "回到最新")
}
```

- [ ] **Step 2: Wrap the gallery in a trailing overlay container**

Keep `ScrollViewReader` as the outer coordinator. Immediately before the current
`ScrollView(.horizontal, showsIndicators: false)`, insert
`ZStack(alignment: .trailing) {`. After the `ScrollView`'s closing brace and before
its current keyboard-token `.onChange` modifier, insert this trailing sibling and
close the `ZStack`:

```swift
backToLatestButton
    .padding(.trailing, 6)
}
```

Move the current keyboard-token `.onChange` modifier onto the resulting `ZStack`.
Do not edit the `LazyHStack`, `ForEach`, `HistoryCardView` callbacks, card `.id`, or
thumbnail `.task` inside the horizontal scroll view.

The `gallery` view is only used when `model.snippets` is non-empty, so the button is absent for empty and filtered-empty states.

- [ ] **Step 3: Add the themed button**

Add near the Gallery section:

```swift
private var backToLatestButton: some View {
    Button {
        model.selectLatest()
    } label: {
        Image(systemName: "arrow.left.to.line")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(themeStyle.primaryText)
            .frame(width: 34, height: 34)
            .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .background { backToLatestBackground }
    .overlay {
        Circle()
            .strokeBorder(overflowBorderColor, lineWidth: overflowBorderWidth)
    }
    .clipShape(Circle())
    .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
    .help(s.backToLatestHelp)
    .accessibilityLabel(s.backToLatestHelp)
}

@ViewBuilder
private var backToLatestBackground: some View {
    if themeStyle.usesSystemGlass && !reduceTransparency {
        Circle().fill(.regularMaterial)
    } else {
        Circle().fill(themeStyle.controlColor)
    }
}
```

- [ ] **Step 4: Translate latest requests into leading-edge scrolls**

Keep the keyboard-token listener unchanged and add a separate listener to the `ZStack`:

```swift
.onChange(of: model.latestScrollToken) { _ in
    guard let id = model.selectedID else { return }
    withAnimation(.easeOut(duration: 0.1)) {
        proxy.scrollTo(id, anchor: .leading)
    }
}
```

The listeners must remain separate because keyboard movement uses `.center` while this action uses `.leading`.

- [ ] **Step 5: Build the SwiftUI integration**

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **` with no new warnings or errors.

### Task 3: Document and verify the completed behavior

**Files:**
- Modify: `README.md`
- Modify: `scripts/manual-smoke.md`
- Verify: all files changed by Tasks 1–2

**Interfaces:**
- Consumes: the completed button and scroll behavior.
- Produces: user-facing instructions and repeatable verification evidence.

- [ ] **Step 1: Update the README action table**

Add after “Select a card”:

```markdown
| Return to the latest card | Click the right-side `←|` button |
```

- [ ] **Step 2: Extend the manual smoke checklist**

Under “Keyboard, pointer, and card actions”, add:

```markdown
- [ ] After scrolling to older cards, clicking Back to Latest selects the newest card and places it at the left edge
- [ ] Back to Latest still repositions the gallery when the newest card was already selected before manual scrolling
- [ ] The Back to Latest button is readable in all six skins, Light/Dark appearance, Reduce Transparency, and Increase Contrast
- [ ] VoiceOver announces Back to Latest / 回到最新 in the selected app language
```

- [ ] **Step 3: Run the complete automated test suite**

```bash
./scripts/generate-project.sh
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test
```

Expected: generation succeeds and XCTest reports `** TEST SUCCEEDED **` with zero failures.

- [ ] **Step 4: Run a clean build**

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' clean build
```

Expected: `** BUILD SUCCEEDED **` with no new warnings or errors.

- [ ] **Step 5: Inspect the working-tree diff**

```bash
git status --short
git diff --check
git diff -- aipaste/UI/History/HistoryViewModel.swift aipasteTests/HistoryViewModelTests.swift aipaste/UI/History/HistoryView.swift aipaste/Localization/L10n.swift README.md scripts/manual-smoke.md
```

Expected: only the approved feature files plus its design/plan documents are changed; `git diff --check` prints nothing. Leave all changes uncommitted.
