import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: HistoryViewModel
    let onClose: () -> Void
    let onPasteAndClose: () -> Void
    let onShowPreferences: () -> Void
    let onClearHistory: () -> Void
    let onQuit: () -> Void

    @FocusState private var searchFocused: Bool

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

    private let workbenchCornerRadius: CGFloat = 24
    private let clusterHeight: CGFloat = 34
    private let clusterCornerRadius: CGFloat = 12

    private var s: WorkbenchStrings { L10n.workbench(model.language) }

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
            WorkbenchGlassBackground(cornerRadius: workbenchCornerRadius)
        }
        .clipShape(RoundedRectangle(cornerRadius: workbenchCornerRadius, style: .continuous))
        // Soft lift so the floating strip separates from the desktop without a hard slab.
        .shadow(color: .black.opacity(0.10), radius: 2, y: 1)
        .shadow(color: .black.opacity(0.18), radius: 28, y: 12)
        .shadow(color: .black.opacity(0.06), radius: 1, y: 0)
        .padding(2)
        // Rebuild chrome when Settings language changes (picked up on reload/show).
        .id(model.language)
        .onAppear {
            searchFocused = true
        }
        .task(id: "\(model.query)|\(model.sourceAppFilter ?? "")|\(model.favoritesOnly)") {
            await Task.yield()
            guard !Task.isCancelled else { return }
            model.reload()
        }
    }

    // MARK: - Toolbar

    /// Brand · Spacer · unified filter cluster · Spacer · overflow
    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                brandHeader
                toolbarSuccessPill
            }

            Spacer(minLength: 8)

            filterCluster

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                toolbarAccessibilityPill
                overflowMenu
            }
        }
        .animation(.easeInOut(duration: 0.18), value: model.statusMessage)
        .animation(.easeInOut(duration: 0.18), value: model.requiresAccessibility)
        .animation(.easeInOut(duration: 0.14), value: model.hasActiveFilters)
        .animation(.easeInOut(duration: 0.14), value: model.favoritesOnly)
        .animation(.easeInOut(duration: 0.14), value: model.sourceAppFilter)
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

            BrandWordmark(fontSize: 14)
                .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(AppConstants.displayName), \(model.snippets.count) items")
        .help(AppConstants.displayName)
    }

    // MARK: - Unified filter cluster

    /// Single chrome: search input + count + favorites star + app filter (+ clear).
    private var filterCluster: some View {
        HStack(spacing: 0) {
            clusterInput

            clusterDivider

            favoritesClusterButton

            clusterDivider

            appFilterMenu
        }
        .frame(minWidth: 360, idealWidth: 500, maxWidth: 560)
        .frame(height: clusterHeight)
        .background { clusterBackground }
        .overlay { clusterBorder }
        .clipShape(RoundedRectangle(cornerRadius: clusterCornerRadius, style: .continuous))
        .shadow(
            color: searchFocused
                ? BrandPalette.aiColors[1].opacity(0.18)
                : .black.opacity(0.03),
            radius: searchFocused ? 10 : 1,
            y: searchFocused ? 1 : 0
        )
        .animation(.easeInOut(duration: 0.16), value: searchFocused)
        .animation(.easeInOut(duration: 0.14), value: model.query.isEmpty)
        .help(s.filterHelp)
    }

    private var clusterInput: some View {
        HStack(spacing: 7) {
            searchMagnifier

            TextField(s.searchPlaceholder, text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .focused($searchFocused)

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(s.clearSearchHelp)
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }

            Text("\(model.snippets.count)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(searchFocused ? Color.primary.opacity(0.72) : Color.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(searchFocused ? 0.10 : 0.06))
                )
                .help(model.hasActiveFilters ? s.matchingItemsHelp : s.itemsInHistoryHelp)
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { searchFocused = true }
    }

    /// Favorites toggle — icon only (no "Favorites" / "All" label).
    private var favoritesClusterButton: some View {
        Button {
            model.toggleFavoritesFilter()
        } label: {
            Image(systemName: model.favoritesOnly ? "star.fill" : "star")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(model.favoritesOnly ? Color.orange : Color.secondary)
                .frame(width: 36, height: clusterHeight)
                .contentShape(Rectangle())
                .background(
                    model.favoritesOnly
                        ? Color.orange.opacity(0.14)
                        : Color.clear
                )
        }
        .buttonStyle(.plain)
        .help(model.favoritesOnly ? s.favoritesFilterOnHelp : s.favoritesFilterOffHelp)
        .accessibilityLabel(model.favoritesOnly ? s.favoritesFilterOnA11y : s.favoritesFilterOffA11y)
    }

    private var appFilterMenu: some View {
        Menu {
            Button {
                model.setSourceAppFilter(nil)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 10, weight: .medium))
                        .frame(width: 14, height: 14)
                    Text(s.allApps)
                }
            }

            if !model.availableSourceApps.isEmpty {
                Divider()
                ForEach(model.availableSourceApps) { app in
                    Button {
                        model.setSourceAppFilter(app.name)
                    } label: {
                        HStack(spacing: 6) {
                            sourceAppMenuIcon(bundleId: app.bundleId, pointSize: 14)
                            Text(app.name)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                if let selected = selectedSourceAppOption {
                    sourceAppMenuIcon(bundleId: selected.bundleId, pointSize: 12)
                    Text(shortAppName(selected.name))
                        .lineLimit(1)
                } else {
                    Image(systemName: "app.badge")
                        .font(.system(size: 10, weight: .medium))
                    Text(s.apps)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .opacity(0.55)
            }
            .font(.system(size: 11, weight: model.sourceAppFilter == nil ? .medium : .semibold))
            .foregroundStyle(model.sourceAppFilter == nil ? Color.secondary : Color.accentColor)
            .padding(.horizontal, 10)
            .frame(height: clusterHeight)
            .contentShape(Rectangle())
            .background(
                model.sourceAppFilter == nil
                    ? Color.clear
                    : Color.accentColor.opacity(0.08)
            )
        }
        .font(.system(size: 12))
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
        .help(s.filterByAppHelp)
    }

    private var clusterDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1)
            .padding(.vertical, 7)
    }

    private var clusterBackground: some View {
        RoundedRectangle(cornerRadius: clusterCornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: clusterCornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(searchFocused ? 0.05 : 0.02))
            }
            .overlay {
                if searchFocused {
                    RoundedRectangle(cornerRadius: clusterCornerRadius, style: .continuous)
                        .fill(
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
    }

    @ViewBuilder
    private var clusterBorder: some View {
        if searchFocused {
            RoundedRectangle(cornerRadius: clusterCornerRadius, style: .continuous)
                .strokeBorder(BrandPalette.aiStrokeGradient, lineWidth: 1.5)
        } else if model.hasActiveFilters {
            RoundedRectangle(cornerRadius: clusterCornerRadius, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.28), lineWidth: 1)
        } else {
            RoundedRectangle(cornerRadius: clusterCornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var searchMagnifier: some View {
        if searchFocused {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(BrandPalette.aiGradient)
        } else {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var selectedSourceAppOption: SourceAppOption? {
        guard let name = model.sourceAppFilter else { return nil }
        return model.availableSourceApps.first { $0.name == name }
    }

    /// Compact label for the cluster tail (e.g. "Google Chrome" → "Chrome").
    private func shortAppName(_ name: String) -> String {
        if name.hasPrefix("Google ") {
            return String(name.dropFirst("Google ".count))
        }
        if name.count > 14 {
            return String(name.prefix(12)) + "…"
        }
        return name
    }

    /// Menu icons need an explicit `NSImage.size` — SwiftUI frames are ignored by NSMenu.
    @ViewBuilder
    private func sourceAppMenuIcon(bundleId: String?, pointSize: CGFloat) -> some View {
        if let icon = SourceAppIconCache.menuIcon(forBundleId: bundleId, pointSize: pointSize) {
            Image(nsImage: icon)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: pointSize * 0.72))
                .foregroundStyle(.secondary)
                .frame(width: pointSize, height: pointSize)
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
                .foregroundStyle(.secondary)
                .frame(width: clusterHeight, height: clusterHeight)
                .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .help(s.moreHelp)
        .accessibilityLabel(s.moreHelp)
    }

    // MARK: - Gallery

    private var gallery: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
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
                            language: model.language
                        )
                        .id(snippet.id)
                        .task(id: snippet.id) {
                            await model.loadThumbnail(for: snippet)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            }
            // Only keyboard ←/→ should auto-scroll. Mouse click selects in place
            // (centering every click felt laggy even when the card was already visible).
            .onChange(of: model.keyboardScrollToken) { _ in
                guard let id = model.selectedID else { return }
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo(id, anchor: .center)
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
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateTitle: String {
        if model.favoritesOnly && model.query.isEmpty && model.sourceAppFilter == nil {
            return s.emptyNoFavoritesTitle
        }
        return model.hasActiveFilters ? s.emptyNoResultsTitle : s.emptyNoHistoryTitle
    }

    private var emptyStateBody: String {
        if model.favoritesOnly && model.query.isEmpty && model.sourceAppFilter == nil {
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
                .foregroundStyle(Color.accentColor)
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(.thinMaterial))
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .fixedSize(horizontal: true, vertical: false)
        .help(message)
    }

    /// Informational permission chip — neutral frost + link-style blue CTA.
    private func accessibilityStatusPill(message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "hand.raised.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.accentColor.opacity(0.9))
                .symbolRenderingMode(.hierarchical)

            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Button {
                model.requestAccessibilitySettings()
            } label: {
                Text(s.openSettingsLink)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help(s.openAccessibilityHelp)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background {
            Capsule(style: .continuous)
                .fill(.thinMaterial)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .fixedSize(horizontal: true, vertical: false)
        .help(message)
    }
}
