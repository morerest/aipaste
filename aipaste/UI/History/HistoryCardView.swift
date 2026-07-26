import AppKit
import SwiftUI

struct HistoryCardView: View {
    let snippet: Snippet
    let image: NSImage?
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onCopy: () -> Void
    let onToggleFavorite: () -> Void
    let onEditNote: () -> Void
    let onDelete: () -> Void
    /// Settings language; defaults to current preference when not passed.
    var language: AppLanguage = L10n.language

    /// Ensures we only select once per press (DragGesture.onChanged fires repeatedly).
    @State private var selectSentForCurrentPress = false

    private var s: WorkbenchStrings { L10n.workbench(language) }

    var body: some View {
        cardContent
            // No Button: AppKit/SwiftUI button styles flash opacity on press/release.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !selectSentForCurrentPress else { return }
                        selectSentForCurrentPress = true
                        onSelect()
                    }
                    .onEnded { _ in
                        selectSentForCurrentPress = false
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2).onEnded { onPaste() }
            )
            .contextMenu {
                Button(s.copy, action: onCopy)
                Button(
                    snippet.isPinned ? s.removeFavorite : s.addToFavorites,
                    action: onToggleFavorite
                )
                if snippet.isPinned {
                    Button(
                        (snippet.pinNote?.isEmpty == false) ? s.editNote : s.addNote,
                        action: onEditNote
                    )
                }
                Button(s.delete, role: .destructive, action: onDelete)
            }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                switch snippet.kind {
                case .image:
                    imageContent
                case .mixed:
                    mixedContent
                case .text:
                    textContent
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            HStack(spacing: 5) {
                sourceAppIcon
                // With a pin note: keep app icon, replace app name with the note label.
                if let note = displayPinNote {
                    Text(note)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.orange)
                        .lineLimit(1)
                        .help(metaSourceHelp)
                        .accessibilityLabel(s.noteA11y(note: note, source: sourceAppDisplayName))
                } else {
                    Text(sourceAppDisplayName)
                        .lineLimit(1)
                }
                if snippet.kind == .mixed {
                    Text(s.mixedBadge)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                }
                Spacer(minLength: 4)
                if snippet.isPinned {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.orange)
                        .accessibilityLabel(s.favoriteA11y)
                }
                Text(Self.relativeLabel(for: snippet.updatedAt))
                    .lineLimit(1)
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 210, height: 190)
        // Fill never depends on selection — only the border color does.
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.accentColor : Color.primary.opacity(0.10),
                    lineWidth: 2
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var textContent: some View {
        Text(snippet.textBody ?? snippet.previewText)
            .font(.system(size: 12, weight: .regular))
            .lineSpacing(1)
            .lineLimit(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Thumbnail on top + text excerpt — signals mixed clipboard content.
    private var mixedContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            imageContent
                .frame(maxHeight: 96)
            Text(snippet.textBody ?? snippet.previewText)
                .font(.system(size: 11, weight: .regular))
                .lineSpacing(1)
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var imageContent: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 30))
                Text(s.imageUnavailable)
                    .font(.caption)
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Non-empty pin note shown in the meta row (favorites only).
    private var displayPinNote: String? {
        guard snippet.isPinned,
              let note = snippet.pinNote?.trimmingCharacters(in: .whitespacesAndNewlines),
              !note.isEmpty
        else { return nil }
        return note
    }

    private var sourceAppDisplayName: String {
        snippet.sourceAppName ?? s.unknownApp
    }

    /// Tooltip when note replaces the app name — source remains discoverable.
    private var metaSourceHelp: String {
        s.sourceHelp(sourceAppDisplayName)
    }

    @ViewBuilder
    private var sourceAppIcon: some View {
        if let icon = SourceAppIconCache.icon(forBundleId: snippet.sourceBundleId) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: 12, height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 2.5, style: .continuous))
                .help(metaSourceHelp)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(width: 12, height: 12)
                .help(metaSourceHelp)
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    private static func relativeLabel(for date: Date) -> String {
        relativeFormatter.localizedString(for: date, relativeTo: Date())
    }
}

/// Resolves macOS app icons by bundle ID with a small process-wide cache.
enum SourceAppIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(forBundleId bundleId: String?) -> NSImage? {
        guard let bundleId, !bundleId.isEmpty else { return nil }
        let key = bundleId as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        cache.setObject(icon, forKey: key)
        return icon
    }

    /// Sized copy for `NSMenu` / SwiftUI `Menu` (frames alone do not shrink menu icons).
    static func menuIcon(forBundleId bundleId: String?, pointSize: CGFloat) -> NSImage? {
        guard let base = icon(forBundleId: bundleId) else { return nil }
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        base.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: base.size),
            operation: .sourceOver,
            fraction: 1.0
        )
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
}
