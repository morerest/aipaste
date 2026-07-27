import AppKit
import SwiftUI

/// Appearance picker: current-skin summary + horizontal swatch strip (layout A).
struct WorkbenchThemePicker: View {
    let selected: WorkbenchTheme
    let name: (WorkbenchTheme) -> String
    let tagline: (WorkbenchTheme) -> String
    let currentBadge: String
    let selectedA11y: String
    let onSelect: (WorkbenchTheme) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            WorkbenchThemeSummary(
                theme: selected,
                name: name(selected),
                tagline: tagline(selected),
                currentBadge: currentBadge
            )

            HStack(spacing: 10) {
                ForEach(WorkbenchTheme.allCases) { theme in
                    WorkbenchThemeSwatch(
                        theme: theme,
                        isSelected: selected == theme,
                        name: name(theme),
                        selectedA11y: selectedA11y,
                        onSelect: { onSelect(theme) }
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Current skin summary

private struct WorkbenchThemeSummary: View {
    @Environment(\.colorSchemeContrast) private var accessibilityContrast

    let theme: WorkbenchTheme
    let name: String
    let tagline: String
    let currentBadge: String

    private var style: WorkbenchThemeStyle { theme.style }
    private var increaseContrast: Bool { accessibilityContrast == .increased }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            WorkbenchThemeMiniSurface(style: style, increaseContrast: increaseContrast)
                .frame(width: 120, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(style.usesSystemGlass ? Color.primary : style.primaryText)

                    Text(currentBadge)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(style.usesSystemGlass ? Color.accentColor : style.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            (style.usesSystemGlass ? Color.accentColor : style.accent)
                                .opacity(0.14),
                            in: Capsule(style: .continuous)
                        )
                }

                Text(tagline)
                    .font(.caption)
                    .foregroundStyle(style.usesSystemGlass ? Color.secondary : style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(style.usesSystemGlass
                      ? Color(nsColor: .controlBackgroundColor).opacity(0.55)
                      : style.cardColor.opacity(0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    style.usesSystemGlass
                        ? Color.primary.opacity(increaseContrast ? 0.16 : 0.08)
                        : style.borderColor,
                    lineWidth: workbenchOutlineWidth(1, increaseContrast: increaseContrast)
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(currentBadge). \(tagline)")
    }
}

// MARK: - Swatch

private struct WorkbenchThemeSwatch: View {
    @Environment(\.colorSchemeContrast) private var accessibilityContrast
    @State private var isHovered = false

    let theme: WorkbenchTheme
    let isSelected: Bool
    let name: String
    let selectedA11y: String
    let onSelect: () -> Void

    private var style: WorkbenchThemeStyle { theme.style }
    private var increaseContrast: Bool { accessibilityContrast == .increased }

    var body: some View {
        // Not a SwiftUI `Button`: the first control in Settings grabs keyboard focus
        // and draws a thick system focus ring around circle+label (looks broken).
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(swatchFill)
                    .overlay {
                        if !style.usesSystemGlass {
                            Circle()
                                .fill(style.panelGradient)
                                .opacity(style.panelGradientOpacity)
                        }
                    }
                    .overlay {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(checkmarkColor)
                        } else {
                            // Tiny card fleck so unselected swatches stay distinct.
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(style.cardColor)
                                .frame(width: 12, height: 9)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .strokeBorder(style.accent.opacity(0.85), lineWidth: 1)
                                }
                        }
                    }
                    .frame(width: 34, height: 34)
                    .overlay {
                        Circle()
                            .strokeBorder(
                                ringColor,
                                lineWidth: workbenchOutlineWidth(
                                    isSelected ? 2.5 : 1,
                                    increaseContrast: increaseContrast
                                )
                            )
                    }
                    .shadow(
                        color: isSelected
                            ? style.accent.opacity(0.28)
                            : .black.opacity(isHovered ? 0.10 : 0.04),
                        radius: isSelected ? 5 : 2,
                        y: 1
                    )
            }

            Text(name)
                .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(labelColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .help(name)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(isSelected ? selectedA11y : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction(named: Text(name), onSelect)
    }

    private var swatchFill: Color {
        style.usesSystemGlass
            ? Color(nsColor: .windowBackgroundColor)
            : style.opaquePanelColor
    }

    private var ringColor: Color {
        if isSelected {
            return style.usesSystemGlass ? Color.accentColor : style.accent
        }
        return style.usesSystemGlass
            ? Color.primary.opacity(increaseContrast ? 0.22 : 0.12)
            : style.borderColor
    }

    /// Graphite needs a light check; light skins use the accent on the wash.
    private var checkmarkColor: Color {
        if style.interfaceColorScheme == .dark {
            return style.accent
        }
        return style.usesSystemGlass ? Color.accentColor : style.accent
    }

    private var labelColor: Color {
        if isSelected {
            return style.usesSystemGlass ? Color.primary : style.primaryText
        }
        return style.usesSystemGlass ? Color.secondary : style.secondaryText
    }
}

// MARK: - Shared mini workbench surface

struct WorkbenchThemeMiniSurface: View {
    let style: WorkbenchThemeStyle
    let increaseContrast: Bool

    var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: min(style.panelCornerRadius, 12),
            style: .continuous
        )
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
        .overlay {
            shape.strokeBorder(
                increaseContrast
                    ? style.primaryText.opacity(0.20)
                    : style.borderColor,
                lineWidth: workbenchOutlineWidth(1, increaseContrast: increaseContrast)
            )
        }
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

    private var miniCardBorderColor: Color {
        increaseContrast ? style.primaryText.opacity(0.20) : style.borderColor
    }
}

// MARK: - Legacy grid card (kept for hosting tests / previews)

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
                WorkbenchThemeMiniSurface(style: style, increaseContrast: increaseContrast)
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
                    isSelected ? Color.accentColor : Color.primary.opacity(increaseContrast ? 0.22 : 0.08),
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
}
