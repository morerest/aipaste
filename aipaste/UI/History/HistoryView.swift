import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: HistoryViewModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var accessibilityContrast
    @Environment(\.colorScheme) private var systemColorScheme

    let onClose: () -> Void
    let onPasteAndClose: () -> Void
    let onShowPreferences: () -> Void
    let onClearHistory: () -> Void
    let onQuit: () -> Void

    @FocusState private var searchFocused: Bool
    @State private var isFilterPopoverPresented = false
    @State private var isAwayFromLatest = false
    @State private var latestButtonHovered = false

    init(
        model: HistoryViewModel,
        onClose: @escaping () -> Void,
        onPasteAndClose: @escaping () -> Void,
        onShowPreferences: @escaping () -> Void,
        onClearHistory: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        self.model = model
        self.onClose = onClose
        self.onPasteAndClose = onPasteAndClose
        self.onShowPreferences = onShowPreferences
        self.onClearHistory = onClearHistory
        self.onQuit = onQuit
    }

    private let clusterHeight: CGFloat = 34

    private var s: WorkbenchStrings { L10n.workbench(model.language) }
    private var themeStyle: WorkbenchThemeStyle { model.theme.style }
    private var increaseContrast: Bool { accessibilityContrast == .increased }

    /// Retain the existing macOS tint for System Glass while custom skins use their fixed accent.
    private var selectionAccent: Color {
        themeStyle.usesSystemGlass ? Color.accentColor : themeStyle.accent
    }

    var body: some View {
        VStack(spacing: 14) {
            toolbar

            if model.snippets.isEmpty {
                emptyState
            } else {
                gallery
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background {
            WorkbenchGlassBackground(
                style: themeStyle,
                reduceTransparency: reduceTransparency,
                increaseContrast: increaseContrast
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: themeStyle.panelCornerRadius, style: .continuous))
        // Soft lift so the floating strip separates from the desktop without a hard slab.
        .shadow(
            color: themeStyle.usesSystemGlass ? .black.opacity(0.10) : .clear,
            radius: themeStyle.usesSystemGlass ? 2 : 0,
            y: themeStyle.usesSystemGlass ? 1 : 0
        )
        .shadow(
            color: themeStyle.panelShadow.color,
            radius: themeStyle.panelShadow.radius,
            y: themeStyle.panelShadow.y
        )
        .shadow(
            color: themeStyle.usesSystemGlass ? .black.opacity(0.06) : .clear,
            radius: themeStyle.usesSystemGlass ? 1 : 0,
            y: 0
        )
        .padding(2)
        .environment(
            \.colorScheme,
            themeStyle.interfaceColorScheme ?? systemColorScheme
        )
        // Rebuild chrome when Settings language changes (picked up on reload/show).
        .id(model.language)
        .onAppear {
            searchFocused = true
        }
        .onChange(of: model.snippets.isEmpty) { isEmpty in
            if isEmpty {
                isAwayFromLatest = false
            }
        }
        .task(
            id: "\(model.query)|\(model.sourceAppFilter ?? "")|\(model.favoritesOnly)|\(model.contentKindFilter.rawValue)"
        ) {
            await Task.yield()
            guard !Task.isCancelled else { return }
            model.reload()
        }
    }

    // MARK: - Toolbar

    /// Brand / overflow on the edges; filter cluster truly centered (not Spacer-balanced).
    /// Edge chrome uses fixedSize so borderless Menus cannot eat residual width on older macOS.
    private var toolbar: some View {
        ZStack {
            HStack(spacing: 12) {
                HStack(spacing: 8) {
                    brandHeader
                    contextualLatestButton
                    toolbarSuccessPill
                }
                .fixedSize(horizontal: true, vertical: false)

                Spacer(minLength: 8)

                HStack(spacing: 8) {
                    toolbarAccessibilityPill
                    overflowMenu
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            filterCluster
        }
        .animation(.easeInOut(duration: 0.18), value: model.statusMessage)
        .animation(.easeInOut(duration: 0.18), value: model.requiresAccessibility)
        .animation(.easeInOut(duration: 0.14), value: model.hasActiveFilters)
        .animation(.easeInOut(duration: 0.14), value: model.favoritesOnly)
        .animation(.easeInOut(duration: 0.14), value: model.sourceAppFilter)
        .animation(.easeInOut(duration: 0.14), value: model.contentKindFilter)
        .animation(.easeOut(duration: 0.16), value: isAwayFromLatest)
    }

    /// App icon + wordmark; count lives in the filter cluster.
    private var brandHeader: some View {
        HStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .clipShape(RoundedRectangle(cornerRadius: 4.5, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 1, y: 0.5)

            BrandWordmark(fontSize: 14, themeStyle: themeStyle)
                .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(AppConstants.displayName), \(model.snippets.count) items")
        .help(AppConstants.displayName)
    }

    @ViewBuilder
    private var contextualLatestButton: some View {
        if isAwayFromLatest && !model.snippets.isEmpty {
            Button {
                model.selectLatest()
            } label: {
                HStack(spacing: BackToLatestButtonTokens.contentSpacing) {
                    latestButtonIcon

                    Text(s.backToLatestHelp)
                        .font(.system(
                            size: BackToLatestButtonTokens.labelFontSize,
                            weight: .medium
                        ))
                        .foregroundStyle(
                            themeStyle.compactChromeText(
                                increaseContrast: increaseContrast || latestButtonHovered
                            )
                        )
                }
            }
            .buttonStyle(
                BackToLatestButtonStyle(
                    themeStyle: themeStyle,
                    isHovered: latestButtonHovered,
                    increaseContrast: increaseContrast,
                    reduceTransparency: reduceTransparency
                )
            )
            .onHover { latestButtonHovered = $0 }
            .help(s.backToLatestHelp)
            .accessibilityLabel(s.backToLatestHelp)
            .transition(latestButtonTransition)
        }
    }

    private var latestButtonTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .offset(x: -4))
    }

    @ViewBuilder
    private var latestButtonIcon: some View {
        if themeStyle.usesSystemGlass {
            Image(systemName: BackToLatestButtonTokens.symbolName)
                .font(.system(size: BackToLatestButtonTokens.iconFontSize, weight: .semibold))
                .foregroundStyle(BrandPalette.aiGradient)
                .accessibilityHidden(true)
        } else {
            Image(systemName: BackToLatestButtonTokens.symbolName)
                .font(.system(size: BackToLatestButtonTokens.iconFontSize, weight: .semibold))
                .foregroundStyle(themeStyle.accent)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Unified filter cluster

    /// Search stays dominant; lower-frequency structured filters live in one popover.
    private var filterCluster: some View {
        HStack(spacing: 0) {
            clusterInput

            clusterDivider

            favoritesFilterButton

            clusterDivider

            filterPopoverButton
        }
        .frame(minWidth: 360, idealWidth: 500, maxWidth: 560)
        .frame(height: clusterHeight)
        .background { clusterBackground }
        .overlay { clusterBorder }
        .clipShape(RoundedRectangle(cornerRadius: themeStyle.controlCornerRadius, style: .continuous))
        .shadow(
            color: searchFocused
                ? (themeStyle.usesSystemGlass
                    ? BrandPalette.aiColors[1].opacity(0.18)
                    : themeStyle.accent.opacity(0.18))
                : (themeStyle.usesSystemGlass ? .black.opacity(0.03) : .clear),
            radius: searchFocused ? 10 : 1,
            y: searchFocused ? 1 : 0
        )
        .animation(.easeInOut(duration: 0.16), value: searchFocused)
        .animation(.easeInOut(duration: 0.14), value: model.query.isEmpty)
        .help(s.filterHelp)
    }

    private var favoritesFilterButton: some View {
        Button {
            model.toggleFavoritesFilter()
        } label: {
            Image(systemName: model.favoritesOnly ? "star.fill" : "star")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(
                    model.favoritesOnly
                        ? selectionAccent
                        : themeStyle.compactChromeText(increaseContrast: increaseContrast)
                )
                .frame(minWidth: 38, minHeight: clusterHeight)
                .background(model.favoritesOnly ? selectionAccent.opacity(0.08) : .clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .help(model.favoritesOnly ? s.favoritesFilterOnHelp : s.favoritesFilterOffHelp)
        .accessibilityLabel(s.favoritesOnly)
        .accessibilityValue(
            model.favoritesOnly ? s.favoritesFilterOnA11y : s.favoritesFilterOffA11y
        )
        .accessibilityAddTraits(model.favoritesOnly ? .isSelected : [])
    }

    private var filterPopoverButton: some View {
        Button {
            isFilterPopoverPresented.toggle()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 11, weight: .semibold))

                Text(s.filtersTitle)
                    .font(.system(size: 12, weight: .medium))

                FilterCountBadge(
                    count: model.popoverFilterCount,
                    accent: selectionAccent
                )

                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .opacity(0.55)
            }
            .foregroundStyle(
                model.hasPopoverFilters
                    ? themeStyle.selectedCompactChromeText(increaseContrast: increaseContrast)
                    : themeStyle.compactChromeText(increaseContrast: increaseContrast)
            )
            .padding(.horizontal, 10)
            .frame(height: clusterHeight)
            .contentShape(Rectangle())
            .background(model.hasPopoverFilters ? selectionAccent.opacity(0.08) : .clear)
        }
        .buttonStyle(.plain)
        .fixedSize(horizontal: true, vertical: false)
        .help(s.filterHelp)
        .accessibilityLabel(s.filtersTitle)
        .accessibilityValue(
            model.popoverFilterCount > 0
                ? "\(model.popoverFilterCount) \(s.activeFiltersA11y)"
                : ""
        )
        .popover(isPresented: $isFilterPopoverPresented, arrowEdge: .bottom) {
            HistoryFilterPopover(model: model)
        }
    }

    private var clusterInput: some View {
        HStack(spacing: 7) {
            searchMagnifier

            TextField(s.searchPlaceholder, text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(themeStyle.primaryText)
                .focused($searchFocused)

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(themeStyle.secondaryText)
                }
                .buttonStyle(.plain)
                .help(s.clearSearchHelp)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Text("\(model.snippets.count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(themeStyle.compactChromeText(increaseContrast: increaseContrast))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(themeStyle.primaryText.opacity(searchFocused ? 0.10 : 0.06))
                )
                .help(model.hasActiveFilters ? s.matchingItemsHelp : s.itemsInHistoryHelp)
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
    }

    private var clusterDivider: some View {
        Rectangle()
            .fill(themeStyle.dividerColor)
            .frame(width: 1)
            .padding(.vertical, 7)
    }

    @ViewBuilder
    private var clusterBackground: some View {
        let shape = RoundedRectangle(
            cornerRadius: themeStyle.controlCornerRadius,
            style: .continuous
        )

        if themeStyle.usesSystemGlass && !reduceTransparency {
            shape
                .fill(.ultraThinMaterial)
                .overlay {
                    shape.fill(Color.primary.opacity(searchFocused ? 0.05 : 0.02))
                }
                .overlay {
                    if searchFocused {
                        shape.fill(
                            RadialGradient(
                                colors: [
                                    BrandPalette.aiColors[0].opacity(0.10),
                                    BrandPalette.aiColors[2].opacity(0.03),
                                    .clear,
                                ],
                                center: .topLeading,
                                startRadius: 4,
                                endRadius: 140
                            )
                        )
                    }
                }
        } else {
            shape
                .fill(themeStyle.controlColor)
                .overlay {
                    if searchFocused {
                        shape.fill(themeStyle.accent.opacity(0.08))
                    }
                }
        }
    }

    @ViewBuilder
    private var clusterBorder: some View {
        let shape = RoundedRectangle(
            cornerRadius: themeStyle.controlCornerRadius,
            style: .continuous
        )

        if searchFocused {
            if themeStyle.usesSystemGlass {
                shape.strokeBorder(
                    BrandPalette.aiStrokeGradient,
                    lineWidth: workbenchOutlineWidth(1.5, increaseContrast: increaseContrast)
                )
            } else {
                shape.strokeBorder(
                    themeStyle.accent.opacity(increaseContrast ? 0.85 : 0.58),
                    lineWidth: workbenchOutlineWidth(1.5, increaseContrast: increaseContrast)
                )
            }
        } else if model.hasActiveFilters {
            shape.strokeBorder(
                selectionAccent.opacity(increaseContrast ? 0.60 : 0.28),
                lineWidth: workbenchOutlineWidth(1, increaseContrast: increaseContrast)
            )
        } else {
            shape.strokeBorder(
                increaseContrast
                    ? themeStyle.primaryText.opacity(0.20)
                    : (themeStyle.usesSystemGlass
                        ? Color.primary.opacity(0.08)
                        : themeStyle.borderColor),
                lineWidth: workbenchOutlineWidth(1, increaseContrast: increaseContrast)
            )
        }
    }

    @ViewBuilder
    private var searchMagnifier: some View {
        if searchFocused {
            if themeStyle.usesSystemGlass {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(BrandPalette.aiGradient)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(themeStyle.accent)
            }
        } else {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(themeStyle.secondaryText)
        }
    }

    // MARK: - Overflow

    private var overflowMenu: some View {
        Menu {
            Button(s.settingsMenu, action: onShowPreferences)
            Divider()
            Button(s.clearHistoryMenu, role: .destructive, action: onClearHistory)
            Button(s.quitMenu, action: onQuit)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(themeStyle.secondaryText)
                .frame(width: clusterHeight, height: clusterHeight)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        // Ventura-era borderless Menu expands to fill free HStack space without this.
        .fixedSize(horizontal: true, vertical: false)
        .background { overflowBackground }
        .overlay {
            RoundedRectangle(cornerRadius: overflowCornerRadius, style: .continuous)
                .strokeBorder(overflowBorderColor, lineWidth: overflowBorderWidth)
        }
        .help(s.moreHelp)
        .accessibilityLabel(s.moreHelp)
    }

    private var overflowCornerRadius: CGFloat {
        themeStyle.usesSystemGlass ? 10 : themeStyle.controlCornerRadius
    }

    @ViewBuilder
    private var overflowBackground: some View {
        let shape = RoundedRectangle(cornerRadius: overflowCornerRadius, style: .continuous)
        if themeStyle.usesSystemGlass && !reduceTransparency {
            shape.fill(.thinMaterial)
        } else {
            shape.fill(themeStyle.controlColor)
        }
    }

    private var overflowBorderColor: Color {
        if increaseContrast {
            return themeStyle.primaryText.opacity(0.20)
        }
        return themeStyle.usesSystemGlass ? Color.primary.opacity(0.08) : themeStyle.borderColor
    }

    private var overflowBorderWidth: CGFloat {
        workbenchOutlineWidth(
            themeStyle.usesSystemGlass ? 0.5 : 1,
            increaseContrast: increaseContrast
        )
    }

    // MARK: - Gallery

    private var gallery: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: true) {
                LazyHStack(spacing: 14) {
                    ForEach(model.snippets) { snippet in
                        HistoryCardView(
                            snippet: snippet,
                            image: model.thumbnail(for: snippet),
                            isSelected: model.selectedID == snippet.id,
                            onSelect: {
                                guard model.selectedID != snippet.id else { return }
                                // No animation transaction — selection highlight must feel instant.
                                var transaction = Transaction()
                                transaction.disablesAnimations = true
                                withTransaction(transaction) {
                                    model.selectedID = snippet.id
                                }
                            },
                            onPaste: {
                                model.selectedID = snippet.id
                                onPasteAndClose()
                            },
                            onCopy: {
                                model.selectedID = snippet.id
                                model.copySelected()
                            },
                            onToggleFavorite: {
                                model.selectedID = snippet.id
                                model.togglePin(id: snippet.id)
                            },
                            onEditNote: {
                                model.selectedID = snippet.id
                                model.editPinNote(id: snippet.id)
                            },
                            onDelete: {
                                model.selectedID = snippet.id
                                model.deleteSelected()
                            },
                            language: model.language,
                            theme: model.theme
                        )
                        .id(snippet.id)
                        .task(id: snippet.id) {
                            await model.loadThumbnail(for: snippet)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background {
                    GalleryScrollOffsetObserver { horizontalOffset in
                        let shouldShow = GalleryScrollMetrics.shouldShowBackToLatest(
                            leadingX: -max(0, horizontalOffset),
                            hasResults: !model.snippets.isEmpty
                        )
                        guard shouldShow != isAwayFromLatest else { return }
                        isAwayFromLatest = shouldShow
                    }
                }
            }
            // Only keyboard ←/→ should auto-scroll. Mouse click selects in place
            // (centering every click felt laggy even when the card was already visible).
            .onChange(of: model.keyboardScrollToken) { _ in
                guard let id = model.selectedID else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(id, anchor: .center)
                }
            }
            .onChange(of: model.latestScrollToken) { _ in
                guard let id = model.selectedID else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(id, anchor: .leading)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: model.hasActiveFilters ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 28, weight: .light))
            Text(emptyStateTitle)
                .font(.headline)
            Text(emptyStateBody)
                .font(.caption)
        }
        .foregroundStyle(themeStyle.compactChromeText(increaseContrast: increaseContrast))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateTitle: String {
        if model.favoritesOnly
            && model.query.isEmpty
            && model.sourceAppFilter == nil
            && model.contentKindFilter == .all {
            return s.emptyNoFavoritesTitle
        }
        return model.hasActiveFilters ? s.emptyNoResultsTitle : s.emptyNoHistoryTitle
    }

    private var emptyStateBody: String {
        if model.favoritesOnly
            && model.query.isEmpty
            && model.sourceAppFilter == nil
            && model.contentKindFilter == .all {
            return s.emptyNoFavoritesBody
        }
        return model.hasActiveFilters ? s.emptyNoResultsBody : s.emptyNoHistoryBody
    }

    // MARK: - Status pills

    /// Success / neutral toasts (Copied, Deleted, …) after the wordmark.
    @ViewBuilder
    private var toolbarSuccessPill: some View {
        if let status = model.statusMessage, !isAccessibilityStatus {
            successStatusPill(message: status)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .leading)))
        }
    }

    /// Permission hint sits to the left of the overflow menu.
    @ViewBuilder
    private var toolbarAccessibilityPill: some View {
        if let status = model.statusMessage, isAccessibilityStatus {
            accessibilityStatusPill(message: status)
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .leading)))
        }
    }

    /// True when the current toast is the accessibility / paste-permission message.
    private var isAccessibilityStatus: Bool {
        model.statusIsAccessibilityHint && model.statusMessage != nil
    }

    /// Quiet confirmation — checkmark + secondary label (macOS HUD-like).
    private func successStatusPill(message: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(selectionAccent)
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(themeStyle.compactChromeText(increaseContrast: increaseContrast))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background { statusPillBackground }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(statusPillBorderColor, lineWidth: statusPillBorderWidth)
        }
        .fixedSize(horizontal: true, vertical: false)
        .help(message)
    }

    /// Informational permission chip — neutral frost + link-style blue CTA.
    private func accessibilityStatusPill(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.orange.opacity(0.9))
                .symbolRenderingMode(.hierarchical)

            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(themeStyle.compactChromeText(increaseContrast: increaseContrast))
                .lineLimit(1)

            Button {
                model.requestAccessibilitySettings()
            } label: {
                Text(s.openSettingsLink)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accessibilityActionColor)
            }
            .buttonStyle(.plain)
            .help(s.openAccessibilityHelp)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background { statusPillBackground }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(statusPillBorderColor, lineWidth: statusPillBorderWidth)
        }
        .fixedSize(horizontal: true, vertical: false)
        .help(message)
    }

    @ViewBuilder
    private var statusPillBackground: some View {
        let capsule = Capsule(style: .continuous)
        if themeStyle.usesSystemGlass && !reduceTransparency {
            capsule.fill(.thinMaterial)
        } else {
            capsule.fill(themeStyle.controlColor)
        }
    }

    private var statusPillBorderColor: Color {
        if increaseContrast {
            return themeStyle.primaryText.opacity(0.20)
        }
        return themeStyle.usesSystemGlass ? Color.primary.opacity(0.08) : themeStyle.borderColor
    }

    private var statusPillBorderWidth: CGFloat {
        workbenchOutlineWidth(
            themeStyle.usesSystemGlass ? 0.5 : 1,
            increaseContrast: increaseContrast
        )
    }

    private var accessibilityActionColor: Color {
        themeStyle.usesSystemGlass ? Color.accentColor : themeStyle.primaryText
    }
}

struct FilterCountBadge: View {
    let count: Int
    let accent: Color

    private var isVisible: Bool { count > 0 }

    var body: some View {
        Text("\(max(count, 0))")
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.white)
            .frame(width: 16, height: 16)
            .background(Circle().fill(accent))
            .opacity(isVisible ? 1 : 0)
            .accessibilityHidden(true)
    }
}
