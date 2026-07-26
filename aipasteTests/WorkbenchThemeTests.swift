import AppKit
import SwiftUI
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

    func testNativeControlColorSchemeMatchesFixedThemeIdentity() {
        XCTAssertNil(WorkbenchTheme.systemGlass.style.interfaceColorScheme)
        XCTAssertEqual(WorkbenchTheme.graphite.style.interfaceColorScheme, .dark)

        for theme in [
            WorkbenchTheme.warmPaper,
            .mossGarden,
            .mistBlue,
            .roseAsh,
        ] {
            XCTAssertEqual(theme.style.interfaceColorScheme, .light, theme.rawValue)
        }
    }

    func testEveryThemeCodableRoundTrips() throws {
        for theme in WorkbenchTheme.allCases {
            let data = try JSONEncoder().encode(theme)
            XCTAssertEqual(try JSONDecoder().decode(WorkbenchTheme.self, from: data), theme)
        }
    }

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
            XCTAssertGreaterThan(style.normalCardLineWidth, 0)
            XCTAssertGreaterThan(style.selectionLineWidth, 0)
            XCTAssertGreaterThanOrEqual(style.selectionLeadingBarWidth, 0)
            XCTAssertGreaterThanOrEqual(style.panelShadow.radius, 0)
            XCTAssertGreaterThanOrEqual(style.cardShadow.radius, 0)
        }
    }

    func testSystemGlassCardLineWidthsPreserveBaseline() {
        let style = WorkbenchTheme.systemGlass.style

        XCTAssertEqual(style.normalCardLineWidth, 2)
        XCTAssertEqual(style.selectionLineWidth, 2)
        XCTAssertEqual(
            workbenchOutlineWidth(style.normalCardLineWidth, increaseContrast: true),
            2.5
        )
        XCTAssertEqual(
            workbenchOutlineWidth(style.selectionLineWidth, increaseContrast: true),
            2.5
        )
    }

    func testCustomThemeNormalCardBordersRemainSubtle() {
        for theme in WorkbenchTheme.allCases where theme != .systemGlass {
            XCTAssertEqual(theme.style.normalCardLineWidth, 1, theme.rawValue)
        }
    }

    func testIncreaseContrastStrengthensWorkbenchOutlineWidths() {
        XCTAssertEqual(workbenchOutlineWidth(0.5, increaseContrast: false), 0.5)
        XCTAssertEqual(workbenchOutlineWidth(1, increaseContrast: false), 1)
        XCTAssertEqual(workbenchOutlineWidth(1.5, increaseContrast: false), 1.5)

        XCTAssertEqual(workbenchOutlineWidth(0.5, increaseContrast: true), 1)
        XCTAssertEqual(workbenchOutlineWidth(1, increaseContrast: true), 1.5)
        XCTAssertEqual(workbenchOutlineWidth(1.5, increaseContrast: true), 2)
        XCTAssertEqual(workbenchOutlineWidth(2, increaseContrast: true), 2.5)
    }

    func testSmallCardTextMeetsContrastOnNormalAndSelectedSurfaces() throws {
        for theme in WorkbenchTheme.allCases {
            let appearances: [NSAppearance.Name] = theme.isSystemAdaptive
                ? [.aqua, .darkAqua]
                : [.aqua]

            for appearanceName in appearances {
                let appearance = try XCTUnwrap(NSAppearance(named: appearanceName))
                var resolutionError: Error?
                appearance.performAsCurrentDrawingAppearance {
                    do {
                        let style = theme.style
                        let panelColors = style.panelColors + [style.opaquePanelColor]

                        for panelColor in panelColors {
                            let panel = try RGBAColor(panelColor)
                            for cardColor in [style.cardColor, style.selectedCardColor] {
                                let card = try RGBAColor(cardColor).composited(over: panel)
                                let metadata = try RGBAColor(style.cardMetadataText)
                                    .composited(over: card)
                                XCTAssertGreaterThanOrEqual(
                                    metadata.contrastRatio(with: card),
                                    4.5,
                                    "\(theme.rawValue) metadata on \(appearanceName.rawValue)"
                                )

                                let badgeBackground = try RGBAColor(style.mixedBadgeBackground)
                                    .composited(over: card)
                                let badgeText = try RGBAColor(style.mixedBadgeText)
                                    .composited(over: badgeBackground)
                                XCTAssertGreaterThanOrEqual(
                                    badgeText.contrastRatio(with: badgeBackground),
                                    4.5,
                                    "\(theme.rawValue) badge on \(appearanceName.rawValue)"
                                )
                            }
                        }
                    } catch {
                        resolutionError = error
                    }
                }
                if let resolutionError { throw resolutionError }
            }
        }
    }

    func testRenderedCompactChromeStatesMeetContrastAndStrengthenForIncreaseContrast() throws {
        for theme in WorkbenchTheme.allCases {
            let appearances: [NSAppearance.Name] = theme.isSystemAdaptive
                ? [.aqua, .darkAqua]
                : [.aqua]

            for appearanceName in appearances {
                let appearance = try XCTUnwrap(NSAppearance(named: appearanceName))
                var resolutionError: Error?
                appearance.performAsCurrentDrawingAppearance {
                    do {
                        let style = theme.style
                        let normalText = try RGBAColor(style.compactChromeText(increaseContrast: false))
                        let increasedText = try RGBAColor(style.compactChromeText(increaseContrast: true))
                        let normalSelectedText = try RGBAColor(
                            style.selectedCompactChromeText(increaseContrast: false)
                        )
                        let increasedSelectedText = try RGBAColor(
                            style.selectedCompactChromeText(increaseContrast: true)
                        )
                        let primaryText = try RGBAColor(style.primaryText)
                        let accent = try RGBAColor(
                            style.usesSystemGlass ? Color.accentColor : style.accent
                        )

                        for (surfaceName, panel) in try renderedPanelSurfaces(style: style) {
                            assertCompactTextContrast(
                                normalText: normalText,
                                increasedText: increasedText,
                                background: panel,
                                context: "\(theme.rawValue) empty state on \(surfaceName), \(appearanceName.rawValue)"
                            )

                            let control = try RGBAColor(style.controlColor).composited(over: panel)
                            assertCompactTextContrast(
                                normalText: normalText,
                                increasedText: increasedText,
                                background: control,
                                context: "\(theme.rawValue) status on \(surfaceName), \(appearanceName.rawValue)"
                            )

                            for searchFocused in [false, true] {
                                let cluster = renderedClusterSurface(
                                    style: style,
                                    control: control,
                                    primaryText: primaryText,
                                    accent: accent,
                                    searchFocused: searchFocused
                                )

                                assertCompactTextContrast(
                                    normalText: normalText,
                                    increasedText: increasedText,
                                    background: cluster,
                                    context: "\(theme.rawValue) inactive filter, focused \(searchFocused), \(surfaceName), \(appearanceName.rawValue)"
                                )

                                let countCapsule = primaryText
                                    .applyingOpacity(searchFocused ? 0.10 : 0.06)
                                    .composited(over: cluster)
                                assertCompactTextContrast(
                                    normalText: normalText,
                                    increasedText: increasedText,
                                    background: countCapsule,
                                    context: "\(theme.rawValue) count, focused \(searchFocused), \(surfaceName), \(appearanceName.rawValue)"
                                )

                                let selectedFilter = accent
                                    .applyingOpacity(0.08)
                                    .composited(over: cluster)
                                assertCompactTextContrast(
                                    normalText: normalSelectedText,
                                    increasedText: increasedSelectedText,
                                    background: selectedFilter,
                                    context: "\(theme.rawValue) selected filter, focused \(searchFocused), \(surfaceName), \(appearanceName.rawValue)"
                                )
                            }
                        }
                    } catch {
                        resolutionError = error
                    }
                }
                if let resolutionError { throw resolutionError }
            }
        }
    }

    private func renderedPanelSurfaces(
        style: WorkbenchThemeStyle
    ) throws -> [(String, RGBAColor)] {
        let opaquePanel = try RGBAColor(style.opaquePanelColor)
        let gradientSurfaces = try style.panelColors.enumerated().map { index, color in
            let gradientColor = try RGBAColor(color)
            let rendered = style.usesSystemGlass
                ? gradientColor
                : gradientColor
                    .applyingOpacity(style.panelGradientOpacity)
                    .composited(over: opaquePanel)
            return ("panel gradient \(index)", rendered)
        }
        return gradientSurfaces + [("opaque panel", opaquePanel)]
    }

    private func renderedClusterSurface(
        style: WorkbenchThemeStyle,
        control: RGBAColor,
        primaryText: RGBAColor,
        accent: RGBAColor,
        searchFocused: Bool
    ) -> RGBAColor {
        if style.usesSystemGlass {
            return primaryText
                .applyingOpacity(searchFocused ? 0.05 : 0.02)
                .composited(over: control)
        }
        guard searchFocused else { return control }
        return accent.applyingOpacity(0.08).composited(over: control)
    }

    private func assertCompactTextContrast(
        normalText: RGBAColor,
        increasedText: RGBAColor,
        background: RGBAColor,
        context: String
    ) {
        let normalContrast = normalText.composited(over: background).contrastRatio(with: background)
        let increasedContrast = increasedText.composited(over: background).contrastRatio(with: background)

        XCTAssertGreaterThanOrEqual(normalContrast, 4.5, "normal \(context)")
        XCTAssertGreaterThanOrEqual(increasedContrast, 4.5, "increased \(context)")
        XCTAssertGreaterThan(increasedContrast, normalContrast, "Increase Contrast \(context)")
    }
}

private struct RGBAColor {
    let red: CGFloat
    let green: CGFloat
    let blue: CGFloat
    let alpha: CGFloat

    init(_ color: Color) throws {
        let resolved = try XCTUnwrap(NSColor(color).usingColorSpace(.sRGB))
        red = resolved.redComponent
        green = resolved.greenComponent
        blue = resolved.blueComponent
        alpha = resolved.alphaComponent
    }

    private init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    func composited(over background: RGBAColor) -> RGBAColor {
        let outputAlpha = alpha + background.alpha * (1 - alpha)
        guard outputAlpha > 0 else {
            return RGBAColor(red: 0, green: 0, blue: 0, alpha: 0)
        }
        return RGBAColor(
            red: (red * alpha + background.red * background.alpha * (1 - alpha)) / outputAlpha,
            green: (green * alpha + background.green * background.alpha * (1 - alpha)) / outputAlpha,
            blue: (blue * alpha + background.blue * background.alpha * (1 - alpha)) / outputAlpha,
            alpha: outputAlpha
        )
    }

    func applyingOpacity(_ opacity: CGFloat) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: alpha * opacity)
    }

    func contrastRatio(with other: RGBAColor) -> CGFloat {
        let lighter = max(relativeLuminance, other.relativeLuminance)
        let darker = min(relativeLuminance, other.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private var relativeLuminance: CGFloat {
        0.2126 * linearized(red) + 0.7152 * linearized(green) + 0.0722 * linearized(blue)
    }

    private func linearized(_ component: CGFloat) -> CGFloat {
        component <= 0.04045
            ? component / 12.92
            : pow((component + 0.055) / 1.055, 2.4)
    }
}
