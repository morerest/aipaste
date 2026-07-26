# Remove Selection Leading Bars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the left-side selected-card marker from Graphite and Rose Ash while preserving their selection border and selected fill.

**Architecture:** Keep the existing semantic `selectionLeadingBarWidth` token and set it to zero for every theme. Existing card and preview rendering already omit the marker when the token is zero, so no view-layout change is required.

**Tech Stack:** Swift 5, SwiftUI, XCTest, Xcode.

## Global Constraints

- Preserve card size, layout, gestures, context menus, selected border, and selected background.
- Do not change colors, radii, shadows, or typography.
- Do not commit, stage, push, or create a PR without explicit user authorization.

---

### Task 1: Use border-only card selection in every skin

**Files:**
- Modify: `aipaste/UI/History/WorkbenchTheme.swift`
- Test: `aipasteTests/WorkbenchThemeTests.swift`

**Interfaces:**
- Consumes: `WorkbenchThemeStyle.selectionLeadingBarWidth: CGFloat`
- Produces: `selectionLeadingBarWidth == 0` for every `WorkbenchTheme`

- [ ] **Step 1: Write the failing regression test**

Replace the existing leading-bar expectations with:

```swift
func testGraphiteTypographyAndAllThemesUseBorderOnlySelection() {
    for theme in WorkbenchTheme.allCases {
        XCTAssertEqual(theme.style.usesMonospacedMetadata, theme == .graphite)
        XCTAssertEqual(theme.style.selectionLeadingBarWidth, 0, theme.rawValue)
    }
}
```

- [ ] **Step 2: Verify the regression test fails**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/WorkbenchThemeTests/testGraphiteTypographyAndAllThemesUseBorderOnlySelection
```

Expected: failure because Graphite is `3` and Rose Ash is `2`.

- [ ] **Step 3: Remove the two leading-marker token values**

In `WorkbenchTheme.swift`, change Graphite and Rose Ash to:

```swift
selection: (1, 0)
```

Keep all other theme tokens unchanged.

- [ ] **Step 4: Verify the fix and related rendering**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/WorkbenchThemeTests \
  -only-testing:aipasteTests/WorkbenchThemeHostingTests
```

Expected: all selected tests pass with zero failures.

- [ ] **Step 5: Inspect the working-tree diff**

Run `git diff --check` and confirm only the approved token, test, design, and plan changes were introduced for this adjustment. Leave all changes uncommitted and unstaged.
