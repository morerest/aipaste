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
    let normalCardLineWidth: CGFloat
    let selectionLineWidth: CGFloat
    let selectionLeadingBarWidth: CGFloat
    let usesMonospacedMetadata: Bool
    let panelShadow: ThemeShadow
    let cardShadow: ThemeShadow

    /// Native SwiftUI/AppKit controls still resolve placeholder, menu, and button
    /// foregrounds from a color scheme. Fixed skins must supply the scheme that
    /// matches their surface; System Glass continues to inherit macOS appearance.
    var interfaceColorScheme: ColorScheme? {
        switch theme {
        case .systemGlass: nil
        case .graphite: .dark
        case .warmPaper, .mossGarden, .mistBlue, .roseAsh: .light
        }
    }

    var panelGradient: LinearGradient {
        LinearGradient(colors: panelColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Small card labels need stronger contrast than the decorative secondary token.
    /// A little translucency preserves the metadata hierarchy without dropping below 4.5:1.
    var cardMetadataText: Color { primaryText.opacity(0.72) }
    var mixedBadgeText: Color { primaryText.opacity(0.72) }
    var mixedBadgeBackground: Color { accent.opacity(0.12) }

    /// Readable secondary text for compact workbench chrome. Keep it visually quieter
    /// than primary content, but strengthen it when macOS Increase Contrast is enabled.
    func compactChromeText(increaseContrast: Bool) -> Color {
        primaryText.opacity(increaseContrast ? 1 : 0.80)
    }

    /// Selected compact controls keep their themed accent in the background and border;
    /// their normal-sized label uses a readable semantic foreground.
    func selectedCompactChromeText(increaseContrast: Bool) -> Color {
        compactChromeText(increaseContrast: increaseContrast)
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

private extension WorkbenchThemeStyle {
    static let systemGlass = WorkbenchThemeStyle(
        theme: .systemGlass,
        usesSystemGlass: true,
        panelColors: [
            Color(nsColor: .windowBackgroundColor),
            Color(nsColor: .windowBackgroundColor)
        ],
        panelGradientOpacity: 1.0,
        opaquePanelColor: Color(nsColor: .windowBackgroundColor),
        cardColor: Color(nsColor: .controlBackgroundColor),
        selectedCardColor: Color(nsColor: .controlBackgroundColor),
        controlColor: Color(nsColor: .controlBackgroundColor),
        primaryText: Color(nsColor: .labelColor),
        secondaryText: Color(nsColor: .secondaryLabelColor),
        accent: Color(red: 0.48, green: 0.52, blue: 1.0),
        borderColor: Color(nsColor: .labelColor).opacity(0.10),
        dividerColor: Color(nsColor: .labelColor).opacity(0.08),
        panelCornerRadius: 24,
        controlCornerRadius: 12,
        cardCornerRadius: 16,
        imageCornerRadius: 10,
        normalCardLineWidth: 2,
        selectionLineWidth: 2,
        selectionLeadingBarWidth: 0,
        usesMonospacedMetadata: false,
        panelShadow: ThemeShadow(color: .black.opacity(0.18), radius: 28, y: 12),
        cardShadow: ThemeShadow(color: .black.opacity(0.04), radius: 2, y: 1)
    )

    static let warmPaper = makeFixedStyle(
        theme: .warmPaper,
        panelColors: [Color(hex: 0xEFE8DA), Color(hex: 0xE8DFCE)],
        panelGradientOpacity: 0.97,
        opaquePanelColor: Color(hex: 0xE8DFCE),
        cardColor: Color(hex: 0xFFFAF0),
        selectedCardColor: Color(hex: 0xFFF7E9),
        controlColor: Color(hex: 0xFFFAF0, opacity: 0.58),
        primaryText: Color(hex: 0x3D352B),
        secondaryText: Color(hex: 0x8B7D69),
        accent: Color(hex: 0xBD6642),
        radii: (17, 8, 10, 7),
        selection: (1.5, 0),
        borderOpacity: 0.13,
        dividerOpacity: 0.10,
        panelShadow: (Color.black, 0.14, 18, 10),
        cardShadow: (Color.black, 0.08, 4, 2)
    )

    static let mossGarden = makeFixedStyle(
        theme: .mossGarden,
        panelColors: [Color(hex: 0xDCE4D7), Color(hex: 0xCBD7CA)],
        panelGradientOpacity: 0.94,
        opaquePanelColor: Color(hex: 0xCBD7CA),
        cardColor: Color(hex: 0xF6F9F2, opacity: 0.96),
        selectedCardColor: Color(hex: 0xFBFFF9),
        controlColor: Color(hex: 0xFAFCF6, opacity: 0.50),
        primaryText: Color(hex: 0x26352C),
        secondaryText: Color(hex: 0x6D7E71),
        accent: Color(hex: 0x3E7655),
        radii: (26, 13, 18, 12),
        selection: (1.5, 0),
        borderOpacity: 0.11,
        dividerOpacity: 0.09,
        panelShadow: (Color(hex: 0x2B4630), 0.15, 22, 12),
        cardShadow: (Color(hex: 0x2B4630), 0.07, 5, 2)
    )

    static let graphite = makeFixedStyle(
        theme: .graphite,
        panelColors: [Color(hex: 0x1A1B1D), Color(hex: 0x25272A)],
        panelGradientOpacity: 0.96,
        opaquePanelColor: Color(hex: 0x202225),
        cardColor: Color(hex: 0x2C2E31),
        selectedCardColor: Color(hex: 0x303633),
        controlColor: Color(hex: 0x151618),
        primaryText: Color(hex: 0xF2F3F3),
        secondaryText: Color(hex: 0xA2A5A7),
        accent: Color(hex: 0x67DCA3),
        radii: (14, 6, 7, 5),
        selection: (1, 0),
        borderOpacity: 0.09,
        dividerOpacity: 0.09,
        panelShadow: (Color.black, 0.35, 22, 12),
        cardShadow: (Color.black, 0, 0, 0),
        usesMonospacedMetadata: true
    )

    static let mistBlue = makeFixedStyle(
        theme: .mistBlue,
        panelColors: [Color(hex: 0xDCE6EB), Color(hex: 0xBDCDD7)],
        panelGradientOpacity: 0.88,
        opaquePanelColor: Color(hex: 0xD5E0E5),
        cardColor: Color(hex: 0xFAFDFE, opacity: 0.94),
        selectedCardColor: Color(hex: 0xF5FBFD),
        controlColor: Color.white.opacity(0.42),
        primaryText: Color(hex: 0x24343E),
        secondaryText: Color(hex: 0x738590),
        accent: Color(hex: 0x4D819B),
        radii: (23, 11, 15, 10),
        selection: (1.5, 0),
        borderOpacity: 0.10,
        dividerOpacity: 0.08,
        panelShadow: (Color(hex: 0x283F4C), 0.16, 22, 12),
        cardShadow: (Color(hex: 0x283F4C), 0.06, 6, 2)
    )

    static let roseAsh = makeFixedStyle(
        theme: .roseAsh,
        panelColors: [Color(hex: 0xE5DADD), Color(hex: 0xD8C9CD)],
        panelGradientOpacity: 0.95,
        opaquePanelColor: Color(hex: 0xDED1D4),
        cardColor: Color(hex: 0xFCF8F7),
        selectedCardColor: Color(hex: 0xFAF2F2),
        controlColor: Color(hex: 0xFFF8F7, opacity: 0.44),
        primaryText: Color(hex: 0x3D3135),
        secondaryText: Color(hex: 0x8B747A),
        accent: Color(hex: 0x9A6170),
        radii: (19, 8, 11, 7),
        selection: (1, 0),
        borderOpacity: 0.10,
        dividerOpacity: 0.08,
        panelShadow: (Color(hex: 0x4E3139), 0.16, 22, 12),
        cardShadow: (Color(hex: 0x4E3139), 0.06, 5, 2)
    )

    static func makeFixedStyle(
        theme: WorkbenchTheme,
        panelColors: [Color],
        panelGradientOpacity: Double,
        opaquePanelColor: Color,
        cardColor: Color,
        selectedCardColor: Color,
        controlColor: Color,
        primaryText: Color,
        secondaryText: Color,
        accent: Color,
        radii: (CGFloat, CGFloat, CGFloat, CGFloat),
        selection: (CGFloat, CGFloat),
        borderOpacity: Double,
        dividerOpacity: Double,
        panelShadow: (Color, Double, CGFloat, CGFloat),
        cardShadow: (Color, Double, CGFloat, CGFloat),
        usesMonospacedMetadata: Bool = false
    ) -> WorkbenchThemeStyle {
        WorkbenchThemeStyle(
            theme: theme,
            usesSystemGlass: false,
            panelColors: panelColors,
            panelGradientOpacity: panelGradientOpacity,
            opaquePanelColor: opaquePanelColor,
            cardColor: cardColor,
            selectedCardColor: selectedCardColor,
            controlColor: controlColor,
            primaryText: primaryText,
            secondaryText: secondaryText,
            accent: accent,
            borderColor: primaryText.opacity(borderOpacity),
            dividerColor: primaryText.opacity(dividerOpacity),
            panelCornerRadius: radii.0,
            controlCornerRadius: radii.1,
            cardCornerRadius: radii.2,
            imageCornerRadius: radii.3,
            normalCardLineWidth: 1,
            selectionLineWidth: selection.0,
            selectionLeadingBarWidth: selection.1,
            usesMonospacedMetadata: usesMonospacedMetadata,
            panelShadow: ThemeShadow(color: panelShadow.0.opacity(panelShadow.1), radius: panelShadow.2, y: panelShadow.3),
            cardShadow: ThemeShadow(color: cardShadow.0.opacity(cardShadow.1), radius: cardShadow.2, y: cardShadow.3)
        )
    }
}

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
