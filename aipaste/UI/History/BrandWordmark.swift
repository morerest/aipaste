import SwiftUI

/// Shared brand accents used by the wordmark and focused search chrome.
enum BrandPalette {
    static let aiColors: [Color] = [
        Color(red: 0.22, green: 0.86, blue: 1.0),
        Color(red: 0.48, green: 0.52, blue: 1.0),
        Color(red: 0.72, green: 0.40, blue: 0.98),
    ]

    /// Calm indigo-slate for "paste" — same family as ai, without shouting.
    static let pasteInk = Color(red: 0.36, green: 0.42, blue: 0.58)

    static var aiGradient: LinearGradient {
        LinearGradient(
            colors: aiColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var aiStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [
                aiColors[0].opacity(0.95),
                aiColors[1].opacity(0.85),
                aiColors[2].opacity(0.90),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Soft cool wash for "paste" so it pairs with the ai gradient in light/dark.
    static var pasteStyle: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.42, green: 0.48, blue: 0.66),
                Color(red: 0.32, green: 0.38, blue: 0.55),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Split product wordmark: "ai" (gradient accent) + "paste" (cool indigo).
/// Keeps lettering crisp at toolbar size and adapts to light/dark appearance.
struct BrandWordmark: View {
    var fontSize: CGFloat = 15
    var themeStyle: WorkbenchThemeStyle? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            aiWordmark
            pasteWordmark
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppConstants.displayName)
    }

    private var aiLabel: some View {
        Text("ai")
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .tracking(-0.2)
    }

    @ViewBuilder
    private var aiWordmark: some View {
        if let themeStyle, !themeStyle.usesSystemGlass {
            aiLabel
                .foregroundStyle(themeStyle.accent)
        } else {
            aiLabel
                .foregroundStyle(BrandPalette.aiGradient)
                .shadow(color: Color.cyan.opacity(0.28), radius: 3, y: 0)
        }
    }

    private var pasteLabel: some View {
        Text("paste")
            .font(.system(size: fontSize, weight: .semibold, design: .rounded))
            .tracking(-0.3)
    }

    @ViewBuilder
    private var pasteWordmark: some View {
        if let themeStyle, !themeStyle.usesSystemGlass {
            pasteLabel
                .foregroundStyle(themeStyle.primaryText.opacity(0.78))
        } else {
            pasteLabel
                .foregroundStyle(BrandPalette.pasteStyle)
        }
    }
}
