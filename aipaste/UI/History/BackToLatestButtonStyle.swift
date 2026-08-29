import SwiftUI

enum BackToLatestButtonTokens {
    static let symbolName = "arrow.left.to.line"
    static let height: CGFloat = 28
    static let contentSpacing: CGFloat = 5
    static let horizontalPadding: CGFloat = 10
    static let iconFontSize: CGFloat = 11
    static let labelFontSize: CGFloat = 12

    static func backgroundOpacity(isHovered: Bool, isPressed: Bool) -> Double {
        if isPressed { return 0.08 }
        return isHovered ? 0.06 : 0.03
    }

    static func borderOpacity(increaseContrast: Bool) -> Double {
        increaseContrast ? 0.20 : 0.08
    }

    static func pressedBrightness(isPressed: Bool) -> Double {
        isPressed ? -0.02 : 0
    }

    static func borderColor(
        themeStyle: WorkbenchThemeStyle,
        increaseContrast: Bool
    ) -> Color {
        if increaseContrast {
            return themeStyle.primaryText.opacity(borderOpacity(increaseContrast: true))
        }
        if themeStyle.usesSystemGlass {
            return Color.primary.opacity(borderOpacity(increaseContrast: false))
        }
        return themeStyle.borderColor
    }
}

/// Quiet glass capsule in the same chrome family as the unfocused search cluster.
struct BackToLatestButtonStyle: ButtonStyle {
    let themeStyle: WorkbenchThemeStyle
    let isHovered: Bool
    let increaseContrast: Bool
    let reduceTransparency: Bool

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(
            cornerRadius: themeStyle.controlCornerRadius,
            style: .continuous
        )

        configuration.label
            .padding(.horizontal, BackToLatestButtonTokens.horizontalPadding)
            .frame(height: BackToLatestButtonTokens.height)
            .background {
                buttonBackground(shape: shape, isPressed: configuration.isPressed)
            }
            .overlay {
                shape.strokeBorder(
                    BackToLatestButtonTokens.borderColor(
                        themeStyle: themeStyle,
                        increaseContrast: increaseContrast
                    ),
                    lineWidth: workbenchOutlineWidth(1, increaseContrast: increaseContrast)
                )
            }
            .brightness(
                BackToLatestButtonTokens.pressedBrightness(
                    isPressed: configuration.isPressed
                )
            )
            .contentShape(shape)
    }

    @ViewBuilder
    private func buttonBackground(
        shape: RoundedRectangle,
        isPressed: Bool
    ) -> some View {
        let washOpacity = BackToLatestButtonTokens.backgroundOpacity(
            isHovered: isHovered,
            isPressed: isPressed
        )

        if themeStyle.usesSystemGlass && !reduceTransparency {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(Color.primary.opacity(washOpacity))
                }
        } else {
            shape
                .fill(themeStyle.controlColor)
                .overlay {
                    shape.fill(themeStyle.primaryText.opacity(washOpacity))
                }
        }
    }
}
