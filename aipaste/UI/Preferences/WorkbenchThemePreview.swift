import SwiftUI

struct WorkbenchThemePreview: View {
    @Environment(\.colorSchemeContrast) private var accessibilityContrast

    let theme: WorkbenchTheme
    let isSelected: Bool
    let label: String
    let selectedLabel: String
    let onSelect: () -> Void

    private var style: WorkbenchThemeStyle { theme.style }
    private var increaseContrast: Bool { accessibilityContrast == .increased }

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
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(
                    previewBorderColor,
                    lineWidth: workbenchOutlineWidth(
                        isSelected ? 1.5 : 1,
                        increaseContrast: increaseContrast
                    )
                )
        }
        .accessibilityLabel(label)
        .accessibilityValue(isSelected ? selectedLabel : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

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
                    .strokeBorder(
                        selected ? style.accent : miniCardBorderColor,
                        lineWidth: workbenchOutlineWidth(
                            selected ? 1.5 : 0.5,
                            increaseContrast: increaseContrast
                        )
                    )
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

    private var previewBorderColor: Color {
        if isSelected { return Color.accentColor }
        return Color.primary.opacity(increaseContrast ? 0.22 : 0.08)
    }

    private var miniCardBorderColor: Color {
        increaseContrast ? style.primaryText.opacity(0.20) : style.borderColor
    }
}
