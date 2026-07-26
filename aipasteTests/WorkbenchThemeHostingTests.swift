import AppKit
import SwiftUI
import XCTest
@testable import aipaste

@MainActor
final class WorkbenchThemeHostingTests: XCTestCase {
    func testEveryThemeCanHostWorkbenchChromeAndHistory() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("aipaste-theme-host-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try autoreleasepool {
            try assertEveryThemeHosts(in: tempRoot)
        }
        RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }

    private func assertEveryThemeHosts(in tempRoot: URL) throws {
        let paths = AppPaths(root: tempRoot)
        try paths.ensureDirectories()
        let db = try Database(path: paths.databaseFile)
        let store = SnippetStore(
            database: db,
            mediaStore: MediaStore(directory: paths.mediaDirectory)
        )
        let longText = Snippet.makeText(
            body: String(repeating: "Theme hosting content stays proportional and wraps across the card. ", count: 8),
            hash: "theme-hosting-long-text",
            updatedAt: Date(timeIntervalSince1970: 3),
            sourceAppName: "Notes"
        )
        let pinnedText = Snippet.makeText(
            body: "Favorite theme hosting content",
            hash: "theme-hosting-pinned-text",
            updatedAt: Date(timeIntervalSince1970: 2),
            sourceAppName: "Safari"
        )
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: 1,
            pixelsHigh: 1,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 4,
            bitsPerPixel: 32
        )!
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        let image = Snippet.makeImage(
            hash: "theme-hosting-image",
            byteSize: png.count,
            mediaPath: "unused.png",
            previewText: "Image (1×1)",
            updatedAt: Date(timeIntervalSince1970: 1),
            sourceAppName: "Preview"
        )

        try store.upsert(longText)
        try store.upsert(pinnedText)
        try store.setPinned(id: pinnedText.id, pinned: true)
        try store.setPinNote(id: pinnedText.id, note: "Work")
        try store.upsert(image, imageData: png)

        for theme in WorkbenchTheme.allCases {
            let chrome = WorkbenchGlassBackground(
                style: theme.style,
                reduceTransparency: false,
                increaseContrast: false
            )
            let brand = BrandWordmark(fontSize: 14, themeStyle: theme.style)
            let chromeHost = NSHostingController(
                rootView: VStack { chrome.frame(height: 80); brand }
            )
            chromeHost.loadView()

            let model = HistoryViewModel(
                store: store,
                pasteEngine: PasteEngine(store: store),
                theme: theme
            )
            model.reload()
            XCTAssertEqual(model.snippets.count, 3, theme.rawValue)
            let imageSnippet = try XCTUnwrap(
                model.snippets.first { $0.kind == .image },
                theme.rawValue
            )
            let decodedImage = try XCTUnwrap(NSImage(data: png), theme.rawValue)
            let selectedID = imageSnippet.id
            XCTAssertNotEqual(selectedID, model.snippets.first?.id, theme.rawValue)
            model.selectedID = selectedID

            let card = HistoryCardView(
                snippet: imageSnippet,
                image: decodedImage,
                isSelected: true,
                onSelect: {},
                onPaste: {},
                onCopy: {},
                onToggleFavorite: {},
                onEditNote: {},
                onDelete: {},
                language: model.language,
                theme: theme
            )
            let cardHost = NSHostingController(rootView: card)
            cardHost.loadView()
            cardHost.view.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(cardHost.view.fittingSize.width, 0, theme.rawValue)
            XCTAssertGreaterThan(cardHost.view.fittingSize.height, 0, theme.rawValue)

            let view = HistoryView(
                model: model,
                onClose: {},
                onPasteAndClose: {},
                onShowPreferences: {},
                onClearHistory: {},
                onQuit: {}
            )
            let hosting = NSHostingController(rootView: view)
            hosting.loadView()
            hosting.view.frame = NSRect(x: 0, y: 0, width: 960, height: 285)
            hosting.view.layoutSubtreeIfNeeded()
            XCTAssertGreaterThan(hosting.view.fittingSize.width, 0, theme.rawValue)
            XCTAssertGreaterThan(hosting.view.fittingSize.height, 0, theme.rawValue)
            XCTAssertEqual(model.selectedID, selectedID, theme.rawValue)
        }
    }
}
