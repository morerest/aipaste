import SwiftUI

struct HistoryFilterPopover: View {
    @ObservedObject var model: HistoryViewModel
    @Environment(\.colorSchemeContrast) private var accessibilityContrast

    private let contentTypeColumns = Array(
        repeating: GridItem(.flexible(), spacing: 2),
        count: 4
    )
    private let sourceAppColumns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    private var s: WorkbenchStrings { L10n.workbench(model.language) }
    private var themeStyle: WorkbenchThemeStyle { model.theme.style }
    private var increaseContrast: Bool { accessibilityContrast == .increased }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(s.contentTypeHelp)

            LazyVGrid(columns: contentTypeColumns, spacing: 2) {
                ForEach(SnippetKindFilter.allCases) { filter in
                    contentTypeRow(filter)
                }
            }
            .padding(3)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(themeStyle.controlColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(
                        increaseContrast
                            ? themeStyle.primaryText.opacity(0.22)
                            : themeStyle.borderColor,
                        lineWidth: workbenchOutlineWidth(1, increaseContrast: increaseContrast)
                    )
            }
            .padding(.horizontal, 6)

            sectionDivider

            sectionTitle(s.sourceAppTitle)
            sourceAppGrid

            if model.hasPopoverFilters {
                sectionDivider

                Button {
                    model.clearPopoverFilters()
                } label: {
                    Text(s.clearFilters)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(themeStyle.accent)
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .suppressPopoverFocusRing()
                .accessibilityLabel(s.clearFilters)
            }
        }
        .padding(10)
        .frame(width: 360, alignment: .leading)
        .foregroundStyle(themeStyle.primaryText)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(themeStyle.secondaryText)
            .padding(.horizontal, 6)
            .padding(.bottom, 5)
    }

    private var sectionDivider: some View {
        Divider()
            .overlay(themeStyle.dividerColor)
            .padding(.vertical, 9)
    }

    private func contentTypeRow(_ filter: SnippetKindFilter) -> some View {
        let isSelected = model.contentKindFilter == filter

        return Button {
            model.setContentKindFilter(filter)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(themeStyle.accent)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)

                Text(contentTypeLabel(filter))
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 28)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(
                        isSelected
                            ? themeStyle.accent.opacity(increaseContrast ? 0.18 : 0.10)
                            : Color.clear
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .suppressPopoverFocusRing()
        .accessibilityLabel(contentTypeLabel(filter))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var sourceAppGrid: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVGrid(columns: sourceAppColumns, spacing: 4) {
                sourceAppRow(name: nil, bundleId: nil, label: s.allApps)

                ForEach(model.availableSourceApps) { app in
                    sourceAppRow(name: app.name, bundleId: app.bundleId, label: app.name)
                }
            }
            .padding(.trailing, 2)
        }
        .padding(.horizontal, 6)
        .frame(maxHeight: 232)
        .accessibilityLabel(s.sourceAppTitle)
    }

    private func sourceAppRow(
        name: String?,
        bundleId: String?,
        label: String
    ) -> some View {
        let isSelected = model.sourceAppFilter == name

        return Button {
            model.setSourceAppFilter(name)
        } label: {
            HStack(spacing: 7) {
                if name == nil {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(themeStyle.secondaryText)
                        .frame(width: 16, height: 16)
                } else {
                    sourceAppIcon(bundleId: bundleId, pointSize: 16)
                }

                Text(label)
                    .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 4)

                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(themeStyle.accent)
                    .opacity(isSelected ? 1 : 0)
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isSelected
                            ? themeStyle.accent.opacity(increaseContrast ? 0.18 : 0.10)
                            : Color.clear
                    )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .suppressPopoverFocusRing()
        .help(label)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func contentTypeLabel(_ filter: SnippetKindFilter) -> String {
        switch filter {
        case .all: return s.contentTypeAll
        case .text: return s.contentTypeText
        case .image: return s.contentTypeImages
        case .mixed: return s.contentTypeMixed
        }
    }

    @ViewBuilder
    private func sourceAppIcon(bundleId: String?, pointSize: CGFloat) -> some View {
        if let icon = SourceAppIconCache.menuIcon(forBundleId: bundleId, pointSize: pointSize) {
            Image(nsImage: icon)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: pointSize * 0.72))
                .foregroundStyle(themeStyle.secondaryText)
                .frame(width: pointSize, height: pointSize)
        }
    }
}

extension View {
    @ViewBuilder
    func suppressPopoverFocusRing() -> some View {
        if #available(macOS 14.0, *) {
            focusEffectDisabled()
        } else {
            focusable(false)
        }
    }
}
