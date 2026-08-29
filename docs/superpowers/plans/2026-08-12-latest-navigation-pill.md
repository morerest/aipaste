# Back to Latest Navigation Pill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the weak gray Back to Latest text treatment with the approved B-style shallow-blue navigation pill.

**Architecture:** A focused `BackToLatestButtonStyle.swift` owns the approved symbol, geometry, state opacities, and SwiftUI button rendering. `HistoryView` continues owning visibility, placement, hover state, animation, and `selectLatest()` behavior; only its label and button style change.

**Tech Stack:** Swift 5, SwiftUI, XCTest, Xcode/macOS 13+

## Global Constraints

- Use SF Symbol `arrow.left`; remove the typographic `‹` glyph.
- Use 26pt height, 7pt continuous corner radius, 5pt icon/text spacing, and 9pt horizontal padding.
- Default state uses accent-colored foreground, 10% accent background, and 20% accent border.
- Hover state uses 16% accent background; pressed state uses 20% accent background and `-0.04` brightness without scaling.
- Increase Contrast uses a 36% accent border and `workbenchOutlineWidth(0.5, increaseContrast:)`.
- System Glass consumes the existing system accent; fixed skins consume `themeStyle.accent` through `selectionAccent`.
- Preserve the existing 70pt visibility threshold, brand-side placement, 160ms transition, Reduce Motion behavior, accessibility label, and click action.
- Do not alter filtering, scrolling, storage, or selection semantics.
- Do not commit, push, create a PR, or merge; leave changes in the current `main` working tree.

---

### Task 1: Testable navigation-pill tokens and rendering

**Files:**
- Create: `aipaste/UI/History/BackToLatestButtonStyle.swift`
- Modify: `aipaste/UI/History/HistoryView.swift:162-190`
- Modify: `aipaste/Localization/L10n.swift:247-252`
- Modify: `aipasteTests/HistoryViewModelTests.swift:231-235`
- Modify: `aipasteTests/WorkbenchThemeTests.swift`
- Verify: `aipasteTests/WorkbenchThemeHostingTests.swift`

**Interfaces:**
- Produces: `BackToLatestButtonTokens.symbolName`, `height`, `cornerRadius`, `contentSpacing`, `horizontalPadding`, `backgroundOpacity(isHovered:isPressed:)`, `borderOpacity(increaseContrast:)`, and `pressedBrightness(isPressed:)`.
- Produces: `BackToLatestButtonStyle(accent:isHovered:increaseContrast:)`.
- Consumes: `selectionAccent`, `latestButtonHovered`, `increaseContrast`, and existing localized `backToLatestHelp`.

- [x] **Step 1: Replace the obsolete glyph test with failing visual-token tests**

Delete `testBackToLatestUsesApprovedTypographicGlyphInEveryLanguage` from `HistoryViewModelTests`. Add this test to `WorkbenchThemeTests`:

```swift
func testBackToLatestNavigationPillMatchesApprovedDesign() {
    XCTAssertEqual(BackToLatestButtonTokens.symbolName, "arrow.left")
    XCTAssertEqual(BackToLatestButtonTokens.height, 26)
    XCTAssertEqual(BackToLatestButtonTokens.cornerRadius, 7)
    XCTAssertEqual(BackToLatestButtonTokens.contentSpacing, 5)
    XCTAssertEqual(BackToLatestButtonTokens.horizontalPadding, 9)
    XCTAssertEqual(
        BackToLatestButtonTokens.backgroundOpacity(isHovered: false, isPressed: false),
        0.10
    )
    XCTAssertEqual(
        BackToLatestButtonTokens.backgroundOpacity(isHovered: true, isPressed: false),
        0.16
    )
    XCTAssertEqual(
        BackToLatestButtonTokens.backgroundOpacity(isHovered: false, isPressed: true),
        0.20
    )
    XCTAssertEqual(BackToLatestButtonTokens.borderOpacity(increaseContrast: false), 0.20)
    XCTAssertEqual(BackToLatestButtonTokens.borderOpacity(increaseContrast: true), 0.36)
    XCTAssertEqual(BackToLatestButtonTokens.pressedBrightness(isPressed: false), 0)
    XCTAssertEqual(BackToLatestButtonTokens.pressedBrightness(isPressed: true), -0.04)
}
```

- [x] **Step 2: Run the focused test and verify RED**

Run:

```bash
xcodebuild test -project aipaste.xcodeproj -scheme aipaste \
  -destination 'platform=macOS' -derivedDataPath /tmp/aipaste-derived \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -only-testing:aipasteTests/WorkbenchThemeTests/testBackToLatestNavigationPillMatchesApprovedDesign
```

Expected: compilation fails with `cannot find 'BackToLatestButtonTokens' in scope`.

- [x] **Step 3: Add the tested tokens and button style**

Create `BackToLatestButtonStyle.swift`:

```swift
import SwiftUI

enum BackToLatestButtonTokens {
    static let symbolName = "arrow.left"
    static let height: CGFloat = 26
    static let cornerRadius: CGFloat = 7
    static let contentSpacing: CGFloat = 5
    static let horizontalPadding: CGFloat = 9

    static func backgroundOpacity(isHovered: Bool, isPressed: Bool) -> Double {
        if isPressed { return 0.20 }
        return isHovered ? 0.16 : 0.10
    }

    static func borderOpacity(increaseContrast: Bool) -> Double {
        increaseContrast ? 0.36 : 0.20
    }

    static func pressedBrightness(isPressed: Bool) -> Double {
        isPressed ? -0.04 : 0
    }
}

struct BackToLatestButtonStyle: ButtonStyle {
    let accent: Color
    let isHovered: Bool
    let increaseContrast: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: BackToLatestButtonTokens.cornerRadius,
            style: .continuous
        )

        configuration.label
            .foregroundStyle(accent)
            .padding(.horizontal, BackToLatestButtonTokens.horizontalPadding)
            .frame(height: BackToLatestButtonTokens.height)
            .background {
                shape.fill(
                    accent.opacity(
                        BackToLatestButtonTokens.backgroundOpacity(
                            isHovered: isHovered,
                            isPressed: configuration.isPressed
                        )
                    )
                )
            }
            .overlay {
                shape.strokeBorder(
                    accent.opacity(
                        BackToLatestButtonTokens.borderOpacity(
                            increaseContrast: increaseContrast
                        )
                    ),
                    lineWidth: workbenchOutlineWidth(
                        0.5,
                        increaseContrast: increaseContrast
                    )
                )
            }
            .brightness(
                BackToLatestButtonTokens.pressedBrightness(
                    isPressed: configuration.isPressed
                )
            )
            .contentShape(shape)
    }
}
```

- [x] **Step 4: Render the approved arrow and label in HistoryView**

Replace the contextual button label with:

```swift
HStack(spacing: BackToLatestButtonTokens.contentSpacing) {
    Image(systemName: BackToLatestButtonTokens.symbolName)
        .font(.system(size: 11, weight: .semibold))
        .accessibilityHidden(true)

    Text(s.backToLatestHelp)
        .font(.system(size: 11, weight: .medium))
}
```

Remove the label's old foreground, padding, frame, background, and content-shape modifiers. Replace `.buttonStyle(.plain)` with:

```swift
.buttonStyle(
    BackToLatestButtonStyle(
        accent: selectionAccent,
        isHovered: latestButtonHovered,
        increaseContrast: increaseContrast
    )
)
```

Delete `WorkbenchStrings.backToLatestGlyph`; keep `.accessibilityLabel(s.backToLatestHelp)`, hover handling, help, and transition unchanged.

- [x] **Step 5: Regenerate the Xcode project and verify GREEN**

Run:

```bash
./scripts/generate-project.sh
xcodebuild test -project aipaste.xcodeproj -scheme aipaste \
  -destination 'platform=macOS' -derivedDataPath /tmp/aipaste-derived \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  -only-testing:aipasteTests/WorkbenchThemeTests/testBackToLatestNavigationPillMatchesApprovedDesign \
  -only-testing:aipasteTests/WorkbenchThemeHostingTests
```

Expected: token test and all-theme hosting tests pass with zero failures.

- [x] **Step 6: Run final verification**

Run:

```bash
xcodebuild test -project aipaste.xcodeproj -scheme aipaste \
  -destination 'platform=macOS' -derivedDataPath /tmp/aipaste-derived \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild clean build -project aipaste.xcodeproj -scheme aipaste \
  -destination 'platform=macOS' -derivedDataPath /tmp/aipaste-derived \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
git diff --check
git status --short
```

Expected: complete XCTest suite reports `** TEST SUCCEEDED **`, clean build reports `** BUILD SUCCEEDED **`, diff check exits 0, and changes remain uncommitted on `main`.
