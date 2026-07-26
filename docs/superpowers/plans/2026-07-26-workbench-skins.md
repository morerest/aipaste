# Workbench Skins Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve the current clipboard workbench as the default skin and add five persistent, immediately switchable skins: Warm Paper, Moss Garden, Graphite, Mist Blue, and Rose Ash.

**Architecture:** Define one stable `WorkbenchTheme` enum and one immutable `WorkbenchThemeStyle` token set, persist only the enum raw value in `UserDefaults`, and pass the selected theme through existing controllers and view models. SwiftUI views consume semantic theme tokens; layout, keyboard routing, clipboard data, and paste behavior remain unchanged.

**Tech Stack:** Swift 5, SwiftUI, AppKit, Combine, UserDefaults, XCTest, XcodeGen, macOS 13+

## Global Constraints

- Keep the existing workbench as `.systemGlass` without visual changes.
- Add exactly five custom skins, for six total themes.
- Custom skins may change color, material, radii, shadows, limited typography, and selection treatment only.
- Do not change panel size, toolbar placement, card size, horizontal gallery layout, keyboard behavior, storage, or paste flow.
- The default skin follows macOS appearance; the five custom skins preserve their fixed visual identities.
- The skin applies only to the history workbench, not Settings, the menu-bar icon, the app icon, or system dialogs.
- Destructive actions remain system red and favorites remain system orange.
- Support Reduce Transparency, Increase Contrast, keyboard selection, and VoiceOver.
- Add no third-party dependency, network access, database migration, downloadable theme, or user-authored theme format.
- Follow local repository policy: do not execute commit, push, PR, or merge commands unless the user explicitly authorizes them. Commit commands below are checkpoints to use only after that authorization.

## File Map

**Create**

- `aipaste/UI/History/WorkbenchTheme.swift` — stable theme IDs and centralized visual tokens.
- `aipaste/UI/Preferences/WorkbenchThemePreview.swift` — static, accessible preview tile used only in Settings.
- `aipasteTests/WorkbenchThemeTests.swift` — theme catalog, token, fallback, and persistence tests.
- `aipasteTests/WorkbenchThemeHostingTests.swift` — hosts all six themed workbenches and chrome components in real AppKit windows.

**Modify**

- `aipaste/App/AppConstants.swift` — add the `workbenchTheme` defaults key.
- `aipaste/Preferences/AppPreferences.swift` — read and write the selected theme with safe fallback.
- `aipaste/Localization/L10n.swift` — Appearance section and six bilingual theme names/help strings.
- `aipaste/UI/Preferences/PreferencesViewModel.swift` — publish the selected theme and notify the app when it changes.
- `aipaste/UI/Preferences/PreferencesWindowController.swift` — forward the theme-change callback.
- `aipaste/UI/Preferences/PreferencesView.swift` — add the 2 × 3 Appearance picker.
- `aipaste/App/AppState.swift` — provide the initial theme and route live changes to the history panel.
- `aipaste/UI/History/HistoryPanelController.swift` — accept and apply theme changes without recreating data state.
- `aipaste/UI/History/HistoryViewModel.swift` — publish presentation-only theme state.
- `aipaste/UI/History/GlassChrome.swift` — render system glass or fixed theme surfaces with accessibility fallbacks.
- `aipaste/UI/History/BrandWordmark.swift` — accept an optional themed accent while preserving its current default.
- `aipaste/UI/History/HistoryView.swift` — consume semantic tokens for shell, toolbar, filters, status pills, and empty state.
- `aipaste/UI/History/HistoryCardView.swift` — consume semantic tokens for card, text, image, divider, metadata, and selection.
- `aipasteTests/HistoryViewModelTests.swift` — verify theme changes preserve workbench state.
- `aipasteTests/PreferencesViewHostingTests.swift` — verify the expanded settings view hosts successfully.
- `README.md` — document the six skins and selection path.
- `scripts/manual-smoke.md` — add the visual and accessibility skin matrix.

---

### Task 1: Create the stable theme catalog and visual token model

**Files:**

- Create: `aipaste/UI/History/WorkbenchTheme.swift`
- Create: `aipasteTests/WorkbenchThemeTests.swift`

**Interfaces:**

- Produces: `enum WorkbenchTheme: String, CaseIterable, Identifiable, Codable`
- Produces: `struct WorkbenchThemeStyle`
- Produces: `var WorkbenchTheme.style: WorkbenchThemeStyle`
- Produces: `var WorkbenchTheme.isSystemAdaptive: Bool`
- Consumes: SwiftUI `Color`, AppKit `NSColor`, and `CGFloat` only.

- [ ] **Step 1: Write failing catalog and metric tests**

Create `aipasteTests/WorkbenchThemeTests.swift`:

```swift
import XCTest
@testable import aipaste

final class WorkbenchThemeTests: XCTestCase {
    func testCatalogHasStableOrderAndRawValues() {
        XCTAssertEqual(
            WorkbenchTheme.allCases,
            [.systemGlass, .warmPaper, .mossGarden, .graphite, .mistBlue, .roseAsh]
        )
        XCTAssertEqual(WorkbenchTheme.systemGlass.rawValue, "systemGlass")
        XCTAssertEqual(WorkbenchTheme.warmPaper.rawValue, "warmPaper")
        XCTAssertEqual(WorkbenchTheme.mossGarden.rawValue, "mossGarden")
        XCTAssertEqual(WorkbenchTheme.graphite.rawValue, "graphite")
        XCTAssertEqual(WorkbenchTheme.mistBlue.rawValue, "mistBlue")
        XCTAssertEqual(WorkbenchTheme.roseAsh.rawValue, "roseAsh")
    }

    func testOnlyDefaultThemeFollowsSystemAppearance() {
        XCTAssertTrue(WorkbenchTheme.systemGlass.isSystemAdaptive)
        XCTAssertTrue(
            WorkbenchTheme.allCases
                .filter { $0 != .systemGlass }
                .allSatisfy { !$0.isSystemAdaptive }
        )
    }

    func testEveryThemeCodableRoundTrips() throws {
        for theme in WorkbenchTheme.allCases {
            let data = try JSONEncoder().encode(theme)
            XCTAssertEqual(try JSONDecoder().decode(WorkbenchTheme.self, from: data), theme)
        }
    }

    func testThemeGeometryMatchesApprovedDesign() {
        XCTAssertEqual(WorkbenchTheme.systemGlass.style.panelCornerRadius, 24)
        XCTAssertEqual(WorkbenchTheme.systemGlass.style.cardCornerRadius, 16)
        XCTAssertEqual(WorkbenchTheme.warmPaper.style.panelCornerRadius, 17)
        XCTAssertEqual(WorkbenchTheme.warmPaper.style.cardCornerRadius, 10)
        XCTAssertEqual(WorkbenchTheme.mossGarden.style.panelCornerRadius, 26)
        XCTAssertEqual(WorkbenchTheme.mossGarden.style.cardCornerRadius, 18)
        XCTAssertEqual(WorkbenchTheme.graphite.style.panelCornerRadius, 14)
        XCTAssertEqual(WorkbenchTheme.graphite.style.cardCornerRadius, 7)
        XCTAssertEqual(WorkbenchTheme.mistBlue.style.panelCornerRadius, 23)
        XCTAssertEqual(WorkbenchTheme.mistBlue.style.cardCornerRadius, 15)
        XCTAssertEqual(WorkbenchTheme.roseAsh.style.panelCornerRadius, 19)
        XCTAssertEqual(WorkbenchTheme.roseAsh.style.cardCornerRadius, 11)
    }

    func testGraphiteTypographyAndAllThemesUseBorderOnlySelection() {
        for theme in WorkbenchTheme.allCases {
            XCTAssertEqual(theme.style.usesMonospacedMetadata, theme == .graphite)
            XCTAssertEqual(theme.style.selectionLeadingBarWidth, 0, theme.rawValue)
        }
    }

    func testEveryThemeProvidesACompleteValidStyle() {
        for theme in WorkbenchTheme.allCases {
            let style = theme.style
            XCTAssertEqual(style.theme, theme)
            XCTAssertEqual(style.panelColors.count, 2)
            XCTAssertGreaterThan(style.panelGradientOpacity, 0)
            XCTAssertLessThanOrEqual(style.panelGradientOpacity, 1)
            XCTAssertGreaterThan(style.panelCornerRadius, 0)
            XCTAssertGreaterThan(style.controlCornerRadius, 0)
            XCTAssertGreaterThan(style.cardCornerRadius, 0)
            XCTAssertGreaterThan(style.imageCornerRadius, 0)
            XCTAssertGreaterThan(style.selectionLineWidth, 0)
            XCTAssertGreaterThanOrEqual(style.selectionLeadingBarWidth, 0)
            XCTAssertGreaterThanOrEqual(style.panelShadow.radius, 0)
            XCTAssertGreaterThanOrEqual(style.cardShadow.radius, 0)
        }
    }
}
```

- [ ] **Step 2: Run the focused tests and confirm the expected failure**

Run:

```bash
./scripts/generate-project.sh
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test -only-testing:aipasteTests/WorkbenchThemeTests
```

Expected: compilation fails because `WorkbenchTheme` and `WorkbenchThemeStyle` do not exist.

- [ ] **Step 3: Implement the catalog and token types**

Create `aipaste/UI/History/WorkbenchTheme.swift` with these public-to-the-module interfaces:

```swift
import AppKit
import SwiftUI

enum WorkbenchTheme: String, CaseIterable, Identifiable, Codable {
    case systemGlass
    case warmPaper
    case mossGarden
    case graphite
    case mistBlue
    case roseAsh

    var id: String { rawValue }
    var isSystemAdaptive: Bool { self == .systemGlass }
    var style: WorkbenchThemeStyle { WorkbenchThemeStyle.make(for: self) }
}

struct ThemeShadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

struct WorkbenchThemeStyle {
    let theme: WorkbenchTheme
    let usesSystemGlass: Bool
    let panelColors: [Color]
    let panelGradientOpacity: Double
    let opaquePanelColor: Color
    let cardColor: Color
    let selectedCardColor: Color
    let controlColor: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let borderColor: Color
    let dividerColor: Color
    let panelCornerRadius: CGFloat
    let controlCornerRadius: CGFloat
    let cardCornerRadius: CGFloat
    let imageCornerRadius: CGFloat
    let selectionLineWidth: CGFloat
    let selectionLeadingBarWidth: CGFloat
    let usesMonospacedMetadata: Bool
    let panelShadow: ThemeShadow
    let cardShadow: ThemeShadow

    var panelGradient: LinearGradient {
        LinearGradient(colors: panelColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func make(for theme: WorkbenchTheme) -> Self {
        switch theme {
        case .systemGlass: return .systemGlass
        case .warmPaper: return .warmPaper
        case .mossGarden: return .mossGarden
        case .graphite: return .graphite
        case .mistBlue: return .mistBlue
        case .roseAsh: return .roseAsh
        }
    }
}
```

Define six private static styles with the following exact tokens:

| Theme | Panel colors / opacity | Opaque panel | Card / selected card | Control | Primary | Secondary | Accent | Panel/control/card/image radii | Selection / leading bar | Border/divider opacity | Panel shadow `(opacity,radius,y)` | Card shadow `(opacity,radius,y)` | Mono metadata |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| System Glass | dynamic `windowBackgroundColor` pair / `1.0` | `windowBackgroundColor` | `controlBackgroundColor` / same | existing `.ultraThinMaterial` branch | `labelColor` | `secondaryLabelColor` | existing indigo `0.48,0.52,1.0` | `24/12/16/10` | `2/0` | `.10/.08` | `.18,28,12` | `.04,2,1` | false |
| Warm Paper | `#EFE8DA`, `#E8DFCE` / `.97` | `#E8DFCE` | `#FFFAF0` / `#FFF7E9` | `#FFFAF0` at `.58` | `#3D352B` | `#8B7D69` | `#BD6642` | `17/8/10/7` | `1.5/0` | `.13/.10` | `.14,18,10` | `.08,4,2` | false |
| Moss Garden | `#DCE4D7`, `#CBD7CA` / `.94` | `#CBD7CA` | `#F6F9F2` at `.96` / `#FBFFF9` | `#FAFCF6` at `.50` | `#26352C` | `#6D7E71` | `#3E7655` | `26/13/18/12` | `1.5/0` | `.11/.09` | `.15,22,12` | `.07,5,2` | false |
| Graphite | `#1A1B1D`, `#25272A` / `.96` | `#202225` | `#2C2E31` / `#303633` | `#151618` | `#F2F3F3` | `#A2A5A7` | `#67DCA3` | `14/6/7/5` | `1/0` | `.09/.09` | `.35,22,12` | `.00,0,0` | true |
| Mist Blue | `#DCE6EB`, `#BDCDD7` / `.88` | `#D5E0E5` | `#FAFDFE` at `.94` / `#F5FBFD` | white at `.42` | `#24343E` | `#738590` | `#4D819B` | `23/11/15/10` | `1.5/0` | `.10/.08` | `.16,22,12` | `.06,6,2` | false |
| Rose Ash | `#E5DADD`, `#D8C9CD` / `.95` | `#DED1D4` | `#FCF8F7` / `#FAF2F2` | `#FFF8F7` at `.44` | `#3D3135` | `#8B747A` | `#9A6170` | `19/8/11/7` | `1/0` | `.10/.08` | `.16,22,12` | `.06,5,2` | false |

Use this exact private color helper in the same file:

```swift
private extension Color {
    init(hex: Int, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255,
            opacity: opacity
        )
    }
}
```

For fixed themes, derive `borderColor` and `dividerColor` from `primaryText` using the exact opacities in the table. Derive each shadow color from black except Moss Garden (`#2B4630`), Mist Blue (`#283F4C`), and Rose Ash (`#4E3139`). The System Glass view branch must retain its two additional existing short shadows alongside the table's primary shadow so the default remains visually unchanged.

- [ ] **Step 4: Run the focused tests**

Run:

```bash
./scripts/generate-project.sh
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test -only-testing:aipasteTests/WorkbenchThemeTests
```

Expected: all catalog, Codable, geometry, typography, selection, and completeness tests pass.

- [ ] **Step 5: Review the boundary before continuing**

Confirm `WorkbenchTheme.swift` contains no `UserDefaults`, clipboard, database, controller, localized display text, or view state references.

- [ ] **Step 6: Commit only if explicitly authorized**

```bash
git add aipaste/UI/History/WorkbenchTheme.swift aipasteTests/WorkbenchThemeTests.swift
git commit -m "feat: add workbench theme catalog"
```

### Task 2: Persist the selected theme with safe fallback

**Files:**

- Modify: `aipaste/App/AppConstants.swift`
- Modify: `aipaste/Preferences/AppPreferences.swift`
- Modify: `aipasteTests/WorkbenchThemeTests.swift`

**Interfaces:**

- Consumes: `WorkbenchTheme(rawValue:)`
- Produces: `AppConstants.DefaultsKey.workbenchTheme: String`
- Produces: `AppPreferences.workbenchTheme: WorkbenchTheme`

- [ ] **Step 1: Add failing preference tests**

Append to `WorkbenchThemeTests`:

```swift
func testPreferencesDefaultToSystemGlass() {
    let suite = "aipaste.theme.default.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    XCTAssertEqual(AppPreferences(defaults: defaults).workbenchTheme, .systemGlass)
}

func testPreferencesRoundTripEveryTheme() {
    let suite = "aipaste.theme.roundtrip.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = AppPreferences(defaults: defaults)

    for theme in WorkbenchTheme.allCases {
        preferences.workbenchTheme = theme
        XCTAssertEqual(AppPreferences(defaults: defaults).workbenchTheme, theme)
    }
}

func testUnknownStoredThemeFallsBackToSystemGlass() {
    let suite = "aipaste.theme.unknown.\(UUID())"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    defaults.set("removed-theme", forKey: AppConstants.DefaultsKey.workbenchTheme)
    XCTAssertEqual(AppPreferences(defaults: defaults).workbenchTheme, .systemGlass)
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test -only-testing:aipasteTests/WorkbenchThemeTests
```

Expected: compilation fails because the defaults key and preference property are missing.

- [ ] **Step 3: Add the defaults key and preference property**

In `AppConstants.DefaultsKey` add:

```swift
static let workbenchTheme = "workbenchTheme"
```

Include this key in `AppPreferences.migrateFromBrokenSuiteIfNeeded(into:)` so users affected by the existing suite migration keep their selection.

Add to `AppPreferences`:

```swift
var workbenchTheme: WorkbenchTheme {
    get {
        guard let raw = defaults.string(forKey: AppConstants.DefaultsKey.workbenchTheme),
              let theme = WorkbenchTheme(rawValue: raw)
        else { return .systemGlass }
        return theme
    }
    set {
        defaults.set(newValue.rawValue, forKey: AppConstants.DefaultsKey.workbenchTheme)
    }
}
```

- [ ] **Step 4: Run all `WorkbenchThemeTests`**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test -only-testing:aipasteTests/WorkbenchThemeTests
```

Expected: all persistence and catalog tests pass.

- [ ] **Step 5: Commit only if explicitly authorized**

```bash
git add aipaste/App/AppConstants.swift aipaste/Preferences/AppPreferences.swift aipasteTests/WorkbenchThemeTests.swift
git commit -m "feat: persist workbench theme preference"
```

### Task 3: Add localized Appearance settings and accessible preview tiles

**Files:**

- Modify: `aipaste/Localization/L10n.swift`
- Modify: `aipaste/UI/Preferences/PreferencesViewModel.swift`
- Create: `aipaste/UI/Preferences/WorkbenchThemePreview.swift`
- Modify: `aipaste/UI/Preferences/PreferencesView.swift`
- Modify: `aipasteTests/PreferencesViewHostingTests.swift`

**Interfaces:**

- Consumes: `WorkbenchTheme.allCases`, `WorkbenchTheme.style`, `AppPreferences.workbenchTheme`
- Produces: `PreferencesViewModel.workbenchTheme: WorkbenchTheme`
- Produces: `PreferencesViewModel.setWorkbenchTheme(_:)`
- Produces: `WorkbenchThemePreview(theme:isSelected:label:selectedLabel:onSelect:)`
- Produces: `SettingsStrings.workbenchThemeName(_:)`

- [ ] **Step 1: Extend the hosting test with the theme state**

In `PreferencesViewHostingTests`, before constructing the view:

```swift
model.setWorkbenchTheme(.graphite)
XCTAssertEqual(model.workbenchTheme, .graphite)
XCTAssertEqual(prefs.workbenchTheme, .graphite)
```

After `hosting.view.layoutSubtreeIfNeeded()`, assert the view has a non-zero fitting height:

```swift
XCTAssertGreaterThan(hosting.view.fittingSize.height, 0)
```

- [ ] **Step 2: Run the hosting test and verify compilation fails**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test -only-testing:aipasteTests/PreferencesViewHostingTests
```

Expected: compilation fails because the view model theme API is missing.

- [ ] **Step 3: Publish and save the setting in `PreferencesViewModel`**

Add:

```swift
@Published var workbenchTheme: WorkbenchTheme
private let onThemeChanged: (WorkbenchTheme) -> Void
```

Extend the initializer with:

```swift
onThemeChanged: @escaping (WorkbenchTheme) -> Void = { _ in }
```

Initialize both values:

```swift
self.onThemeChanged = onThemeChanged
workbenchTheme = preferences.workbenchTheme
```

Add:

```swift
func setWorkbenchTheme(_ theme: WorkbenchTheme) {
    guard workbenchTheme != theme else { return }
    workbenchTheme = theme
    preferences.workbenchTheme = theme
    onThemeChanged(theme)
}
```

- [ ] **Step 4: Add complete bilingual copy**

Add to `SettingsStrings`:

```swift
var appearanceSection: String { t(en: "Appearance", zh: "外观") }
var appearanceFooter: String {
    t(en: "Changes the clipboard workbench only.", zh: "仅改变剪贴板工作台的外观。")
}
var selectedThemeA11y: String { t(en: "Selected", zh: "已选择") }

func workbenchThemeName(_ theme: WorkbenchTheme) -> String {
    switch theme {
    case .systemGlass: return t(en: "Default", zh: "默认")
    case .warmPaper: return t(en: "Warm Paper", zh: "暖纸")
    case .mossGarden: return t(en: "Moss Garden", zh: "苔庭")
    case .graphite: return t(en: "Graphite", zh: "石墨")
    case .mistBlue: return t(en: "Mist Blue", zh: "雾蓝")
    case .roseAsh: return t(en: "Rose Ash", zh: "樱灰")
    }
}
```

- [ ] **Step 5: Implement `WorkbenchThemePreview`**

Create a `Button`-backed preview that takes `theme`, `isSelected`, `label`, and `onSelect`. Its thumbnail must render:

- the theme panel gradient or System Glass neutral surface;
- three miniature cards using `style.cardColor`;
- one selected miniature card using `style.accent` and `style.selectionLeadingBarWidth`;
- a checkmark in the top-right only when selected;
- the localized label below the thumbnail.

Use this structure:

```swift
struct WorkbenchThemePreview: View {
    let theme: WorkbenchTheme
    let isSelected: Bool
    let label: String
    let selectedLabel: String
    let onSelect: () -> Void

    private var style: WorkbenchThemeStyle { theme.style }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 7) {
                previewSurface
                    .frame(height: 72)
                HStack {
                    Text(label).font(.caption.weight(.medium))
                    Spacer()
                    if isSelected { Image(systemName: "checkmark.circle.fill") }
                }
            }
            .padding(8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? selectedLabel : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
```

Implement the two private building blocks without external assets:

```swift
private var previewSurface: some View {
    let shape = RoundedRectangle(cornerRadius: min(style.panelCornerRadius, 12), style: .continuous)
    return ZStack {
        shape.fill(style.opaquePanelColor)
        if !style.usesSystemGlass {
            shape.fill(style.panelGradient).opacity(style.panelGradientOpacity)
        }
        HStack(spacing: 5) {
            miniCard(selected: false)
            miniCard(selected: true)
            miniCard(selected: false)
        }
        .padding(8)
    }
    .clipShape(shape)
}

private func miniCard(selected: Bool) -> some View {
    RoundedRectangle(cornerRadius: min(style.cardCornerRadius, 5), style: .continuous)
        .fill(selected ? style.selectedCardColor : style.cardColor)
        .overlay {
            RoundedRectangle(cornerRadius: min(style.cardCornerRadius, 5), style: .continuous)
                .strokeBorder(selected ? style.accent : style.borderColor, lineWidth: selected ? 1.5 : 0.5)
        }
        .overlay(alignment: .leading) {
            if selected && style.selectionLeadingBarWidth > 0 {
                Capsule()
                    .fill(style.accent)
                    .frame(width: min(style.selectionLeadingBarWidth, 2))
                    .padding(.vertical, 3)
            }
        }
}
```

Apply a 1.5pt system-accent outer stroke when selected and a 1pt `Color.primary.opacity(0.08)` stroke otherwise. Do not change the Settings window background based on the selected theme.

- [ ] **Step 6: Insert the Appearance section at the top of Settings**

Add `appearanceSection` before `historySection` in `PreferencesView.body`. Inside a `SettingsCard` with `systemImage: "paintpalette.fill"`, use:

```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
    ForEach(WorkbenchTheme.allCases) { theme in
        WorkbenchThemePreview(
            theme: theme,
            isSelected: model.workbenchTheme == theme,
            label: s.workbenchThemeName(theme),
            selectedLabel: s.selectedThemeA11y,
            onSelect: { model.setWorkbenchTheme(theme) }
        )
    }
}
Text(s.appearanceFooter)
    .font(.caption)
    .foregroundStyle(.secondary)
```

The surrounding `ScrollView` already handles the added height; keep the window at 520 × 600.

- [ ] **Step 7: Run the hosting and theme tests**

Run `./scripts/generate-project.sh` first so the new preview source is added to the project, then run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/PreferencesViewHostingTests \
  -only-testing:aipasteTests/WorkbenchThemeTests
```

Expected: the expanded Preferences view hosts without a SwiftUI graph crash and persistence assertions pass.

- [ ] **Step 8: Commit only if explicitly authorized**

```bash
git add aipaste/Localization/L10n.swift aipaste/UI/Preferences/PreferencesViewModel.swift aipaste/UI/Preferences/WorkbenchThemePreview.swift aipaste/UI/Preferences/PreferencesView.swift aipasteTests/PreferencesViewHostingTests.swift
git commit -m "feat: add workbench skin picker"
```

### Task 4: Propagate live theme changes to the history panel

**Files:**

- Modify: `aipaste/UI/Preferences/PreferencesWindowController.swift`
- Modify: `aipaste/App/AppState.swift`
- Modify: `aipaste/UI/History/HistoryPanelController.swift`
- Modify: `aipaste/UI/History/HistoryViewModel.swift`
- Modify: `aipasteTests/HistoryViewModelTests.swift`

**Interfaces:**

- Consumes: `PreferencesViewModel(onThemeChanged:)`
- Produces: `HistoryViewModel.init(..., theme: WorkbenchTheme = .systemGlass)`
- Produces: `HistoryViewModel.setTheme(_:)`
- Produces: `HistoryPanelController.configure(..., initialTheme:)`
- Produces: `HistoryPanelController.setTheme(_:)`

- [ ] **Step 1: Add a failing state-preservation test**

Append to `HistoryViewModelTests`:

```swift
func testThemeChangePreservesQueryFiltersAndSelection() {
    model.query = "new"
    model.setFavoritesOnly(true)
    let selected = model.selectedID

    model.setTheme(.graphite)

    XCTAssertEqual(model.theme, .graphite)
    XCTAssertEqual(model.query, "new")
    XCTAssertTrue(model.favoritesOnly)
    XCTAssertEqual(model.selectedID, selected)
}
```

- [ ] **Step 2: Run the focused test and confirm it fails to compile**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test -only-testing:aipasteTests/HistoryViewModelTests
```

Expected: `HistoryViewModel` has no `theme` or `setTheme` API.

- [ ] **Step 3: Add presentation-only theme state to `HistoryViewModel`**

Add:

```swift
@Published private(set) var theme: WorkbenchTheme
```

Extend the initializer:

```swift
init(
    store: SnippetStore,
    pasteEngine: PasteEngine,
    theme: WorkbenchTheme = .systemGlass,
    thumbnailLoader: ThumbnailLoader? = nil
) {
    self.theme = theme
    self.store = store
    self.pasteEngine = pasteEngine
    self.thumbnailLoader = thumbnailLoader ?? { snippet in
        guard let data = try? store.mediaData(for: snippet) else {
            return nil
        }
        return Self.downsampledPNGData(from: data)
    }
}
```

Add:

```swift
func setTheme(_ theme: WorkbenchTheme) {
    guard self.theme != theme else { return }
    self.theme = theme
}
```

Do not call `reload()` from `setTheme`; a visual change must not re-query SQLite or disturb selection.

- [ ] **Step 4: Wire the initial theme and live callback**

Change `HistoryPanelController.configure` to accept `initialTheme: WorkbenchTheme` and construct its model with that theme. Add:

```swift
func setTheme(_ theme: WorkbenchTheme) {
    model?.setTheme(theme)
}
```

Change `PreferencesWindowController.show` to accept `onThemeChanged: @escaping (WorkbenchTheme) -> Void = { _ in }` and pass it to `PreferencesViewModel`.

In `AppState.bootstrap`, pass:

```swift
initialTheme: preferences.workbenchTheme
```

In `AppState.showPreferences`, pass:

```swift
onThemeChanged: { [weak self] theme in
    self?.historyPanel.setTheme(theme)
}
```

- [ ] **Step 5: Run `HistoryViewModelTests` and `PreferencesViewHostingTests`**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/HistoryViewModelTests \
  -only-testing:aipasteTests/PreferencesViewHostingTests
```

Expected: both test classes pass, and all existing initializer call sites continue compiling because the new `theme` argument has a default.

- [ ] **Step 6: Commit only if explicitly authorized**

```bash
git add aipaste/UI/Preferences/PreferencesWindowController.swift aipaste/App/AppState.swift aipaste/UI/History/HistoryPanelController.swift aipaste/UI/History/HistoryViewModel.swift aipasteTests/HistoryViewModelTests.swift
git commit -m "feat: propagate workbench skin changes"
```

### Task 5: Theme the workbench shell, toolbar, and brand

**Files:**

- Modify: `aipaste/UI/History/GlassChrome.swift`
- Modify: `aipaste/UI/History/BrandWordmark.swift`
- Modify: `aipaste/UI/History/HistoryView.swift`
- Create: `aipasteTests/WorkbenchThemeHostingTests.swift`

**Interfaces:**

- Consumes: `HistoryViewModel.theme`, `WorkbenchTheme.style`
- Produces: `WorkbenchGlassBackground(style:reduceTransparency:increaseContrast:)`
- Produces: `BrandWordmark(fontSize:themeStyle:)` with a default `nil` style for existing Settings usage.

- [ ] **Step 1: Add a failing all-theme hosting test**

Create `aipasteTests/WorkbenchThemeHostingTests.swift` using the same temporary database setup as `PreferencesViewHostingTests`. For every theme:

```swift
for theme in WorkbenchTheme.allCases {
    let chrome = WorkbenchGlassBackground(
        style: theme.style,
        reduceTransparency: false,
        increaseContrast: false
    )
    let brand = BrandWordmark(fontSize: 14, themeStyle: theme.style)
    let chromeHost = NSHostingController(
        rootView: VStack { chrome.frame(height: 80); brand }
    )
    chromeHost.loadView()

    let model = HistoryViewModel(
        store: store,
        pasteEngine: PasteEngine(store: store),
        theme: theme
    )
    model.reload()
    let view = HistoryView(
        model: model,
        onClose: {},
        onPasteAndClose: {},
        onShowPreferences: {},
        onClearHistory: {},
        onQuit: {}
    )
    let hosting = NSHostingController(rootView: view)
    hosting.loadView()
    hosting.view.frame = NSRect(x: 0, y: 0, width: 960, height: 285)
    hosting.view.layoutSubtreeIfNeeded()
    XCTAssertGreaterThan(hosting.view.fittingSize.width, 0, theme.rawValue)
}
```

Insert at least one text snippet before the loop so the gallery and cards render rather than only the empty state.

Use this exact seed:

```swift
try store.upsert(
    Snippet.makeText(
        body: "Theme hosting content",
        hash: "theme-hosting-content",
        sourceAppName: "Notes"
    )
)
```

- [ ] **Step 2: Run the hosting test before visual integration**

Run:

```bash
./scripts/generate-project.sh
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test -only-testing:aipasteTests/WorkbenchThemeHostingTests
```

Expected: compilation fails because `WorkbenchGlassBackground` does not accept `style`, `reduceTransparency`, or `increaseContrast`, and `BrandWordmark` does not accept `themeStyle`.

- [ ] **Step 3: Make `WorkbenchGlassBackground` theme-aware**

Change its inputs to:

```swift
struct WorkbenchGlassBackground: View {
    let style: WorkbenchThemeStyle
    let reduceTransparency: Bool
    let increaseContrast: Bool
}
```

Rendering rules:

- `.systemGlass`: preserve the existing `VibrancyBackground`, `.ultraThinMaterial`, depth wash, and specular edge.
- Custom theme with normal transparency: retain a subtle `VibrancyBackground(material: .popover)` beneath `style.panelGradient.opacity(style.panelGradientOpacity)` so each approved fixed color identity stays stable.
- Custom theme with Reduce Transparency: render `style.opaquePanelColor` only; do not instantiate vibrancy or SwiftUI Material.
- Increase Contrast: raise the outer stroke from the style default to at least 20% primary-text opacity and 1pt.
- Use `style.panelCornerRadius` for all clips and strokes.

- [ ] **Step 4: Make `BrandWordmark` optionally consume a theme style**

Use:

```swift
struct BrandWordmark: View {
    var fontSize: CGFloat = 15
    var themeStyle: WorkbenchThemeStyle? = nil
}
```

When `themeStyle == nil` or the theme is `.systemGlass`, preserve `BrandPalette.aiGradient` and `BrandPalette.pasteStyle`. For a custom skin, use `themeStyle.accent` for “ai” and `themeStyle.primaryText.opacity(0.78)` for “paste”. This keeps the About section unchanged while theming the workbench brand.

- [ ] **Step 5: Replace shell and toolbar literals with semantic tokens**

In `HistoryView` add:

```swift
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency
@Environment(\.accessibilityContrast) private var accessibilityContrast

private var themeStyle: WorkbenchThemeStyle { model.theme.style }
private var increaseContrast: Bool { accessibilityContrast == .increased }
```

Then apply tokens to:

- the outer panel radius and shadow;
- `BrandWordmark`;
- filter cluster background, border, glow, divider, and corner radius;
- favorites and app-filter active backgrounds;
- overflow control background and border;
- status pills and empty-state text.

Preserve the current values exactly when `model.theme == .systemGlass`. Use `themeStyle.accent` only for selection/focus/success. Keep favorite orange, destructive red, and accessibility warning orange.

- [ ] **Step 6: Run the hosting test and full compilation**

Run:

```bash
./scripts/generate-project.sh
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test -only-testing:aipasteTests/WorkbenchThemeHostingTests
```

Expected: all six themes host without crashing; Settings About still compiles with `BrandWordmark(fontSize:)` and retains the existing gradient.

- [ ] **Step 7: Commit only if explicitly authorized**

```bash
git add aipaste/UI/History/GlassChrome.swift aipaste/UI/History/BrandWordmark.swift aipaste/UI/History/HistoryView.swift aipasteTests/WorkbenchThemeHostingTests.swift
git commit -m "feat: theme workbench chrome"
```

### Task 6: Theme cards without changing their layout or behavior

**Files:**

- Modify: `aipaste/UI/History/HistoryCardView.swift`
- Modify: `aipaste/UI/History/HistoryView.swift`
- Modify: `aipasteTests/WorkbenchThemeHostingTests.swift`

**Interfaces:**

- Consumes: `HistoryCardView(theme: WorkbenchTheme)`
- Preserves: all existing card callbacks and the fixed `210 × 190` frame.

- [ ] **Step 1: Extend the hosting test to render text, image, favorite, and selected states**

Seed the temporary store with:

- a long text snippet created with `Snippet.makeText(body:hash:sourceAppName:)`;
- a pinned text snippet, then call `store.setPinned(id:pinned:)` and `store.setPinNote(id:note:)` with note `"Work"`;
- a 1 × 1 PNG image snippet using the bitmap fixture pattern already present in `HistoryViewModelTests`.

Mixed-content rendering remains in the manual matrix because creating it is pasteboard-ingestion behavior outside this visual task's unit-test boundary.

For each theme, select a non-first card and host the view. Assert the hosting view has a positive fitting size and that `model.selectedID` remains unchanged after layout.

- [ ] **Step 2: Add a required theme argument to `HistoryCardView`**

Add:

```swift
let theme: WorkbenchTheme
private var style: WorkbenchThemeStyle { theme.style }
```

Pass `model.theme` from the sole `HistoryCardView` call in `HistoryView`.

- [ ] **Step 3: Replace card visual literals with tokens**

Keep `.padding(12)` and `.frame(width: 210, height: 190)` unchanged. Replace only:

- card fill with `isSelected ? style.selectedCardColor : style.cardColor`;
- primary text with `style.primaryText`;
- metadata and fallback icons with `style.secondaryText`;
- card, image, and source-icon radii with style radii;
- divider with `style.dividerColor`;
- normal border with `style.borderColor`;
- selected border with `style.accent` and `style.selectionLineWidth`;
- card shadow with `style.cardShadow`.

Keep `style.selectionLeadingBarWidth` at `0` for every theme. Selected cards use only the complete accent border and selected-card fill; no theme renders a leading marker.

- [ ] **Step 4: Apply limited theme typography**

- Keep every card body in the current system proportional font; this phase does not introduce a code-content classifier.
- When `style.usesMonospacedMetadata` is true, render source and relative time with `.system(size: 10, design: .monospaced)`.
- Do not change line limits, spacing, metadata order, accessibility labels, gestures, or context-menu actions.

- [ ] **Step 5: Run hosting, history-model, and preferences tests**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/WorkbenchThemeHostingTests \
  -only-testing:aipasteTests/HistoryViewModelTests \
  -only-testing:aipasteTests/PreferencesViewHostingTests
```

Expected: all pass; theme rendering must not change selection, thumbnail loading, filters, favorites, copy, paste, or delete behavior.

- [ ] **Step 6: Commit only if explicitly authorized**

```bash
git add aipaste/UI/History/HistoryCardView.swift aipaste/UI/History/HistoryView.swift aipasteTests/WorkbenchThemeHostingTests.swift
git commit -m "feat: theme clipboard cards"
```

### Task 7: Complete accessibility behavior, documentation, and end-to-end verification

**Files:**

- Modify: `aipaste/UI/Preferences/WorkbenchThemePreview.swift`
- Modify: `aipaste/UI/History/GlassChrome.swift`
- Modify: `aipaste/UI/History/HistoryView.swift`
- Modify: `aipaste/UI/History/HistoryCardView.swift`
- Modify: `README.md`
- Modify: `scripts/manual-smoke.md`

**Interfaces:**

- Consumes: all theme and settings APIs from Tasks 1–6.
- Produces: no new runtime API; this task closes accessibility, documentation, and release verification gaps.

- [ ] **Step 1: Audit accessibility semantics**

Verify and correct these exact outcomes:

- every Settings preview is a button with the localized theme name;
- the current theme exposes `.isSelected` and a visible checkmark;
- Increase Contrast strengthens preview, control, card, and panel strokes;
- Reduce Transparency removes material/vibrancy from the workbench background;
- theme selection never changes the existing accessibility labels for filters, cards, favorites, menus, or status messages;
- all six accent/foreground pairs remain readable for normal and selected cards.

- [ ] **Step 2: Update README feature and usage copy**

Add a feature bullet:

```markdown
- Six workbench skins: Default, Warm Paper, Moss Garden, Graphite, Mist Blue, and Rose Ash
```

Under Settings, add:

```markdown
- Workbench skin selection with immediate preview and persistence
```

State that skins affect only the clipboard workbench and do not alter stored clipboard data.

- [ ] **Step 3: Add a concrete manual smoke matrix**

Append to `scripts/manual-smoke.md`:

```markdown
## Workbench skins

- [ ] Settings shows six previews in this order: Default, Warm Paper, Moss Garden, Graphite, Mist Blue, Rose Ash.
- [ ] Selecting each preview updates the next opened workbench without restarting the app.
- [ ] The selected skin survives quit and relaunch.
- [ ] Search text, filters, and selected card survive a live skin change.
- [ ] Default still follows macOS Light and Dark appearances.
- [ ] Each custom skin keeps its approved identity after switching macOS appearance.
- [ ] Text, image, mixed, favorite-note, selected, and empty states remain readable in every skin.
- [ ] Reduce Transparency replaces glass with an opaque theme surface.
- [ ] Increase Contrast strengthens panel, control, and card outlines.
- [ ] Keyboard and VoiceOver can identify and choose every skin preview.
```

- [ ] **Step 4: Regenerate the Xcode project**

Run:

```bash
./scripts/generate-project.sh
```

Expected: XcodeGen completes and the two new source files plus two new test files appear in the generated project.

- [ ] **Step 5: Run focused tests**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test \
  -only-testing:aipasteTests/WorkbenchThemeTests \
  -only-testing:aipasteTests/WorkbenchThemeHostingTests \
  -only-testing:aipasteTests/PreferencesViewHostingTests \
  -only-testing:aipasteTests/HistoryViewModelTests
```

Expected: all focused tests pass with zero failures.

- [ ] **Step 6: Run the full test suite**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' test
```

Expected: the entire existing suite and all new theme tests pass.

- [ ] **Step 7: Build the application**

Run:

```bash
xcodebuild -project aipaste.xcodeproj -scheme aipaste -destination 'platform=macOS' build
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 8: Perform the manual smoke matrix**

Run the app from Xcode, complete the new skin checklist in `scripts/manual-smoke.md`, and compare the five custom skins with the approved companion mockups. Record any contrast or readability deviation before declaring the feature complete.

- [ ] **Step 9: Inspect the final diff**

Run:

```bash
git status --short
git diff --check
git diff --stat
```

Expected: only the planned source, test, documentation, and generated Xcode project files are changed; `.superpowers/` remains untracked and must not be staged; `git diff --check` prints nothing.

- [ ] **Step 10: Commit only if explicitly authorized**

```bash
git add README.md scripts/manual-smoke.md \
  aipaste/App/AppConstants.swift \
  aipaste/App/AppState.swift \
  aipaste/Preferences/AppPreferences.swift \
  aipaste/Localization/L10n.swift \
  aipaste/UI/Preferences/PreferencesViewModel.swift \
  aipaste/UI/Preferences/PreferencesWindowController.swift \
  aipaste/UI/Preferences/PreferencesView.swift \
  aipaste/UI/Preferences/WorkbenchThemePreview.swift \
  aipaste/UI/History/WorkbenchTheme.swift \
  aipaste/UI/History/HistoryPanelController.swift \
  aipaste/UI/History/HistoryViewModel.swift \
  aipaste/UI/History/GlassChrome.swift \
  aipaste/UI/History/BrandWordmark.swift \
  aipaste/UI/History/HistoryView.swift \
  aipaste/UI/History/HistoryCardView.swift \
  aipasteTests/WorkbenchThemeTests.swift \
  aipasteTests/WorkbenchThemeHostingTests.swift \
  aipasteTests/HistoryViewModelTests.swift \
  aipasteTests/PreferencesViewHostingTests.swift \
  aipaste.xcodeproj/project.pbxproj
git commit -m "feat: add workbench skins"
```

Do not push or create a pull request unless the user separately requests it.
