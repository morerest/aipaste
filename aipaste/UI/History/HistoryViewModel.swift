import Foundation
import Combine
import AppKit
import ImageIO

@MainActor
final class HistoryViewModel: ObservableObject {
    /// Background loaders must return immutable thumbnail bytes (PNG preferred).
    /// `NSImage` is created only on the main actor after the load completes.
    typealias ThumbnailLoader = @Sendable (Snippet) -> Data?

    @Published var snippets: [Snippet] = []
    /// Search text; self-clears with all other filters after
    /// `filterAutoResetInterval` idle seconds so a stale filtered view never
    /// greets the next hotkey open.
    @Published var query: String = "" {
        didSet { scheduleFilterAutoReset() }
    }
    /// Exact source app display name; `nil` means all apps.
    @Published var sourceAppFilter: String?
    /// When true, only pinned favorites are listed.
    @Published var favoritesOnly = false
    /// Single-choice content type; `.all` maps to no storage-kind condition.
    @Published var contentKindFilter: SnippetKindFilter = .all
    /// Distinct apps from history for the filter menu (most recent first).
    @Published private(set) var availableSourceApps: [SourceAppOption] = []
    @Published var selectedID: String?
    /// Bumped only for keyboard ←/→ so the gallery can scroll without doing so on mouse click.
    @Published private(set) var keyboardScrollToken: UInt = 0
    /// Bumped for explicit “Back to Latest” requests so the gallery can use a leading anchor.
    @Published private(set) var latestScrollToken: UInt = 0
    @Published var statusMessage: String?
    @Published var requiresAccessibility = false
    /// True only while the active toast is the accessibility / auto-paste hint.
    @Published private(set) var statusIsAccessibilityHint = false
    /// Tracks Settings language so the panel chrome refreshes after a switch.
    @Published private(set) var language: AppLanguage = L10n.language
    @Published private(set) var theme: WorkbenchTheme
    @Published private var thumbnails: [String: NSImage] = [:]

    private var s: WorkbenchStrings { L10n.workbench(language) }

    private let store: SnippetStore
    private let pasteEngine: PasteEngine
    private let thumbnailLoader: ThumbnailLoader
    private var statusResetTask: Task<Void, Never>?
    private var thumbnailLoadTasks: [String: Task<Void, Never>] = [:]
    /// Idle seconds before the whole filtered view (search + quick filters)
    /// resets to the default state; keeps ticking while the panel is hidden.
    private let filterAutoResetInterval: TimeInterval
    private var filterAutoResetTask: Task<Void, Never>?

    private var selectedIndex: Int? {
        guard let selectedID else { return nil }
        return snippets.firstIndex { $0.id == selectedID }
    }

    var hasPasteableSelection: Bool {
        guard let selectedID else { return false }
        return snippets.contains { $0.id == selectedID }
    }

    var hasActiveFilters: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || sourceAppFilter != nil
            || favoritesOnly
            || contentKindFilter != .all
    }

    var activeFilterCount: Int {
        (contentKindFilter == .all ? 0 : 1)
            + (favoritesOnly ? 1 : 0)
            + (sourceAppFilter == nil ? 0 : 1)
    }

    var hasStructuredFilters: Bool {
        activeFilterCount > 0
    }

    /// Filters represented inside the Filters popover. Search and the
    /// independent favorites button deliberately do not contribute.
    var popoverFilterCount: Int {
        (contentKindFilter == .all ? 0 : 1)
            + (sourceAppFilter == nil ? 0 : 1)
    }

    var hasPopoverFilters: Bool {
        popoverFilterCount > 0
    }

    init(
        store: SnippetStore,
        pasteEngine: PasteEngine,
        theme: WorkbenchTheme = .systemGlass,
        thumbnailLoader: ThumbnailLoader? = nil,
        filterAutoResetInterval: TimeInterval = 180
    ) {
        self.theme = theme
        self.store = store
        self.pasteEngine = pasteEngine
        self.filterAutoResetInterval = filterAutoResetInterval
        self.thumbnailLoader = thumbnailLoader ?? { snippet in
            guard let data = try? store.mediaData(for: snippet) else {
                return nil
            }
            return Self.downsampledPNGData(from: data)
        }
    }

    func setTheme(_ theme: WorkbenchTheme) {
        guard self.theme != theme else { return }
        self.theme = theme
    }

    func reload() {
        language = L10n.language
        do {
            availableSourceApps = try store.distinctSourceApps()
            // Drop stale filter if that app no longer appears in history.
            if let sourceAppFilter, !availableSourceApps.contains(where: { $0.name == sourceAppFilter }) {
                self.sourceAppFilter = nil
            }
            let loaded = try store.list(
                query: query.isEmpty ? nil : query,
                sourceAppName: sourceAppFilter,
                favoritesOnly: favoritesOnly,
                kind: contentKindFilter.snippetKind,
                limit: AppConstants.listLimit
            )
            snippets = loaded
            pruneThumbnails(keeping: Set(loaded.map(\.id)))
            if selectedID == nil || !loaded.contains(where: { $0.id == selectedID }) {
                selectedID = loaded.first?.id
            }
        } catch {
            showStatus(s.displayError(error), duration: 3.0)
        }
    }

    func setSourceAppFilter(_ name: String?) {
        let normalized = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        sourceAppFilter = (normalized?.isEmpty == false) ? normalized : nil
        scheduleFilterAutoReset()
    }

    func setFavoritesOnly(_ enabled: Bool) {
        favoritesOnly = enabled
        scheduleFilterAutoReset()
    }

    func setContentKindFilter(_ filter: SnippetKindFilter) {
        contentKindFilter = filter
        scheduleFilterAutoReset()
    }

    func toggleFavoritesFilter() {
        favoritesOnly.toggle()
        scheduleFilterAutoReset()
    }

    /// Clears search text, source-app, favorites-only, and content-type filters.
    func clearAllFilters() {
        query = ""
        clearStructuredFilters()
    }

    func clearStructuredFilters() {
        sourceAppFilter = nil
        favoritesOnly = false
        contentKindFilter = .all
        scheduleFilterAutoReset()
    }

    /// Clears only the conditions exposed by `HistoryFilterPopover`.
    func clearPopoverFilters() {
        sourceAppFilter = nil
        contentKindFilter = .all
        scheduleFilterAutoReset()
    }

    /// Restarts the idle countdown on every filter interaction; a fully
    /// default state stops it.
    private func scheduleFilterAutoReset() {
        filterAutoResetTask?.cancel()
        guard hasActiveFilters else { return }
        let interval = filterAutoResetInterval
        filterAutoResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.resetExpiredFilters()
        }
    }

    /// Idle expiry: drop every filter and re-list the unfiltered history.
    private func resetExpiredFilters() {
        guard hasActiveFilters else { return }
        query = ""
        clearStructuredFilters()
        reload()
    }

    func selectPrevious() {
        guard !snippets.isEmpty else { return }
        let index = max(0, (selectedIndex ?? 0) - 1)
        let id = snippets[index].id
        selectedID = id
        keyboardScrollToken &+= 1
    }

    func selectNext() {
        guard !snippets.isEmpty else { return }
        let index = min(snippets.count - 1, (selectedIndex ?? -1) + 1)
        let id = snippets[index].id
        selectedID = id
        keyboardScrollToken &+= 1
    }

    func selectLatest() {
        guard let id = snippets.first?.id else { return }
        selectedID = id
        latestScrollToken &+= 1
    }

    func pasteSelected() {
        guard let id = selectedID, let snippet = snippets.first(where: { $0.id == id }) else { return }
        do {
            switch try pasteEngine.perform(snippet, mode: .paste) {
            case .pasted:
                requiresAccessibility = false
                statusIsAccessibilityHint = false
                statusMessage = nil
            case .copiedOnly(let reason):
                switch reason {
                case .modeCopyOnly:
                    showStatus(s.statusCopied)
                case .accessibilityDenied:
                    // Sticky flag for styling the toast; message itself auto-dismisses
                    // so the toolbar does not keep a permanent banner.
                    requiresAccessibility = true
                    showStatus(
                        s.copiedAccessibilityNeeded,
                        duration: 60.0,
                        accessibilityHint: true
                    )
                }
            }
        } catch {
            showStatus(s.displayError(error), duration: 3.0)
        }
    }

    func copySelected() {
        guard let id = selectedID, let snippet = snippets.first(where: { $0.id == id }) else { return }
        do {
            _ = try pasteEngine.perform(snippet, mode: .copyOnly)
            // The copied card is now the latest — re-list so it sits leftmost,
            // then anchor the gallery to it like an explicit "Back to Latest".
            // Favorites ordering is pin-time based, so only scroll when the
            // card actually became the first row.
            reload()
            if snippets.first?.id == id {
                selectLatest()
            }
            showStatus(s.statusCopied)
        } catch {
            showStatus(s.displayError(error), duration: 3.0)
        }
    }

    func deleteSelected() {
        guard let id = selectedID, let oldIndex = selectedIndex else { return }
        do {
            try store.delete(id: id)
            try refreshListPreservingSelection(preferredIndex: oldIndex)
            removeThumbnail(forID: id)
            showStatus(s.statusDeleted)
        } catch {
            showStatus(s.displayError(error), duration: 3.0)
        }
    }

    /// Pin / unpin the selected card (⌘P).
    func togglePinSelected() {
        guard let id = selectedID else { return }
        togglePin(id: id)
    }

    func togglePin(id: String) {
        let currentlyPinned = snippets.first(where: { $0.id == id })?.isPinned ?? false
        let next = !currentlyPinned
        do {
            _ = try store.setPinned(id: id, pinned: next)
            showStatus(next ? s.statusFavorited : s.statusUnfavorited)
            // Keep selection; favorites filter may drop unpinned items from the list.
            reload()
            if snippets.contains(where: { $0.id == id }) {
                selectedID = id
            }
        } catch {
            showStatus(s.displayError(error), duration: 3.0)
        }
    }

    /// Edit favorite note via a small AppKit prompt (max 10 characters).
    /// Shows a read-only preview of the card content above the note field.
    func editPinNote(id: String) {
        selectedID = id
        // Ensure pinned before noting.
        if snippets.first(where: { $0.id == id })?.isPinned != true {
            do {
                _ = try store.setPinned(id: id, pinned: true)
                reload()
            } catch {
                showStatus(s.displayError(error), duration: 3.0)
                return
            }
        }

        guard let snippet = snippets.first(where: { $0.id == id }) else { return }
        let existing = snippet.pinNote ?? ""

        let alert = NSAlert()
        alert.messageText = s.noteAlertTitle
        alert.informativeText = s.noteAlertMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: s.noteAlertSave)
        alert.addButton(withTitle: s.noteAlertCancel)

        let accessory = Self.makeNoteEditorAccessory(
            snippet: snippet,
            existingNote: existing,
            thumbnail: thumbnail(for: snippet),
            strings: s
        )
        alert.accessoryView = accessory.container
        alert.window.initialFirstResponder = accessory.noteField

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        do {
            try store.setPinNote(id: id, note: accessory.noteField.stringValue)
            reload()
            if snippets.contains(where: { $0.id == id }) {
                selectedID = id
            }
            let note = Snippet.normalizedPinNote(accessory.noteField.stringValue)
            showStatus(note == nil ? s.statusNoteCleared : s.statusNoteSaved)
        } catch {
            showStatus(s.displayError(error), duration: 3.0)
        }
    }

    /// Vertical stack: content preview (optional image) + note field.
    private static func makeNoteEditorAccessory(
        snippet: Snippet,
        existingNote: String,
        thumbnail: NSImage?,
        strings: WorkbenchStrings
    ) -> (container: NSView, noteField: NSTextField) {
        let width: CGFloat = 320
        let previewText = noteEditorPreviewText(for: snippet, strings: strings)

        let contentLabel = NSTextField(labelWithString: strings.noteAlertContentLabel)
        contentLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        contentLabel.textColor = .secondaryLabelColor

        let previewField = NSTextField(wrappingLabelWithString: previewText)
        previewField.font = .systemFont(ofSize: 12)
        previewField.textColor = .labelColor
        previewField.maximumNumberOfLines = 6
        previewField.lineBreakMode = .byTruncatingTail
        previewField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        previewField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let previewBox = NSBox()
        previewBox.boxType = .custom
        previewBox.borderWidth = 0.5
        previewBox.borderColor = NSColor.separatorColor
        previewBox.fillColor = NSColor.controlBackgroundColor
        previewBox.cornerRadius = 8
        previewBox.titlePosition = .noTitle
        previewBox.contentViewMargins = NSSize(width: 8, height: 8)

        let previewStack = NSStackView()
        previewStack.orientation = .horizontal
        previewStack.alignment = .top
        previewStack.spacing = 8
        previewStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

        if snippet.hasImage, let thumbnail {
            let imageView = NSImageView(image: thumbnail)
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 4
            imageView.layer?.masksToBounds = true
            imageView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 48),
                imageView.heightAnchor.constraint(equalToConstant: 48),
            ])
            previewStack.addArrangedSubview(imageView)
        }

        previewStack.addArrangedSubview(previewField)
        previewBox.contentView = previewStack

        let noteLabel = NSTextField(labelWithString: strings.noteAlertNoteLabel)
        noteLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        noteLabel.textColor = .secondaryLabelColor

        let noteField = NSTextField(frame: .zero)
        noteField.stringValue = existingNote
        noteField.placeholderString = strings.noteAlertPlaceholder
        noteField.isEditable = true
        noteField.isBezeled = true
        noteField.bezelStyle = .roundedBezel
        noteField.maximumNumberOfLines = 1
        noteField.font = .systemFont(ofSize: 13)
        noteField.translatesAutoresizingMaskIntoConstraints = false
        noteField.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 6
        root.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(contentLabel)
        root.addArrangedSubview(previewBox)
        root.addArrangedSubview(noteLabel)
        root.addArrangedSubview(noteField)

        // Outer container with fixed width so NSAlert sizes accessory correctly.
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 1))
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            root.topAnchor.constraint(equalTo: container.topAnchor),
            root.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: width),
            previewBox.widthAnchor.constraint(equalTo: root.widthAnchor),
            noteField.widthAnchor.constraint(equalTo: root.widthAnchor),
            // Keep preview readable but bounded.
            previewBox.heightAnchor.constraint(greaterThanOrEqualToConstant: 56),
            previewBox.heightAnchor.constraint(lessThanOrEqualToConstant: 120),
        ])

        container.layoutSubtreeIfNeeded()
        let fitting = container.fittingSize
        container.frame = NSRect(x: 0, y: 0, width: width, height: max(fitting.height, 120))

        return (container, noteField)
    }

    private static func noteEditorPreviewText(
        for snippet: Snippet,
        strings: WorkbenchStrings
    ) -> String {
        let raw: String
        switch snippet.kind {
        case .text, .mixed:
            let body = snippet.textBody?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !body.isEmpty {
                raw = body
            } else if !snippet.previewText.isEmpty {
                raw = snippet.previewText
            } else if snippet.kind == .mixed {
                raw = strings.noteAlertImageOnly
            } else {
                raw = snippet.previewText
            }
        case .image:
            let preview = snippet.previewText.trimmingCharacters(in: .whitespacesAndNewlines)
            raw = preview.isEmpty ? strings.noteAlertImageOnly : preview
        }
        // Soft cap for dialog readability (character count, CJK-friendly).
        let limit = 280
        if raw.count <= limit { return raw }
        return String(raw.prefix(limit)) + "…"
    }

    /// Clears unpinned history; **keeps favorites**.
    func clearHistory() {
        do {
            try store.deleteUnpinned()
            sourceAppFilter = nil
            // Stay on favorites filter if it was on; otherwise show remaining (favorites).
            reload()
            if snippets.isEmpty {
                selectedID = nil
                thumbnailLoadTasks.values.forEach { $0.cancel() }
                thumbnailLoadTasks.removeAll()
                thumbnails.removeAll()
            }
            showStatus(s.statusHistoryCleared)
        } catch {
            showStatus(s.displayError(error), duration: 3.0)
        }
    }

    private func refreshListPreservingSelection(preferredIndex: Int) throws {
        availableSourceApps = try store.distinctSourceApps()
        snippets = try store.list(
            query: query.isEmpty ? nil : query,
            sourceAppName: sourceAppFilter,
            favoritesOnly: favoritesOnly,
            limit: AppConstants.listLimit
        )
        pruneThumbnails(keeping: Set(snippets.map(\.id)))
        if snippets.isEmpty {
            selectedID = nil
        } else {
            selectedID = snippets[min(preferredIndex, snippets.count - 1)].id
        }
    }

    func thumbnail(for snippet: Snippet) -> NSImage? {
        thumbnails[snippet.id]
    }

    func loadThumbnail(for snippet: Snippet) async {
        guard snippet.hasImage else { return }

        // Loop so a cancelled in-flight load (e.g. temporary search filter) can
        // be retried once the snippet is visible again — never overlapping.
        while true {
            if thumbnails[snippet.id] != nil { return }
            guard snippets.contains(where: { $0.id == snippet.id }) else { return }

            if let existingTask = thumbnailLoadTasks[snippet.id] {
                await existingTask.value
                continue
            }

            let id = snippet.id
            let loader = thumbnailLoader
            let task = Task { [weak self] in
                let pngData = await Task.detached(priority: .utility) {
                    loader(snippet)
                }.value
                guard let self else { return }
                defer { self.thumbnailLoadTasks[id] = nil }
                // Drop cancelled/stale work; a later loadThumbnail will retry.
                guard !Task.isCancelled else { return }
                guard self.snippets.contains(where: { $0.id == id }) else { return }
                guard let pngData, let image = NSImage(data: pngData) else { return }
                self.thumbnails[id] = image
            }
            thumbnailLoadTasks[id] = task
            await task.value
            return
        }
    }

    func requestAccessibilitySettings() {
        AccessibilityPermission.openSystemSettings()
    }

    /// - Parameter duration: seconds before the toast clears. `nil` keeps it until replaced.
    /// - Parameter accessibilityHint: styles the toast as the accessibility permission chip.
    private func showStatus(
        _ message: String,
        duration: TimeInterval? = 1.5,
        accessibilityHint: Bool = false
    ) {
        statusResetTask?.cancel()
        statusIsAccessibilityHint = accessibilityHint
        statusMessage = message
        guard let duration else { return }
        let nanos = UInt64(max(0.3, duration) * 1_000_000_000)
        statusResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanos)
            guard !Task.isCancelled else { return }
            self?.statusMessage = nil
            self?.statusIsAccessibilityHint = false
        }
    }

    private func pruneThumbnails(keeping validIDs: Set<String>) {
        thumbnails = thumbnails.filter { validIDs.contains($0.key) }
        // Cancel obsolete work but keep the Task in the map until it finishes.
        // Removing it early would let a re-add start a concurrent loader.
        let obsoleteIDs = thumbnailLoadTasks.keys.filter { !validIDs.contains($0) }
        for id in obsoleteIDs {
            thumbnailLoadTasks[id]?.cancel()
        }
    }

    private func removeThumbnail(forID id: String) {
        thumbnailLoadTasks[id]?.cancel()
        // Keep the cancelled task entry until completion so concurrent callers
        // await it instead of starting a second loader for the same id.
        thumbnails[id] = nil
    }

    nonisolated private static func downsampledPNGData(from data: Data) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 420
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        let mutable = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            mutable,
            "public.png" as CFString,
            1,
            nil
        ) else {
            return nil
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutable as Data
    }
}
