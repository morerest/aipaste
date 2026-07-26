import AppKit
import SwiftUI
import XCTest
@testable import aipaste

@MainActor
final class PreferencesViewHostingTests: XCTestCase {
    func testPreferencesViewCanHostWithoutCrash() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("aipaste-host-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let paths = AppPaths(root: tempRoot)
        try paths.ensureDirectories()
        let db = try Database(path: paths.databaseFile)
        let store = SnippetStore(
            database: db,
            mediaStore: MediaStore(directory: paths.mediaDirectory)
        )
        let defaults = UserDefaults(suiteName: "com.eden.aipaste.tests.host.\(UUID().uuidString)")!
        let prefs = AppPreferences(defaults: defaults)
        let ignore = IgnoreRuleStore(defaults: defaults)

        let model = PreferencesViewModel(
            preferences: prefs,
            ignoreRules: ignore,
            store: store
        )
        model.setWorkbenchTheme(.graphite)
        XCTAssertEqual(model.workbenchTheme, .graphite)
        XCTAssertEqual(prefs.workbenchTheme, .graphite)

        // Force candidate evaluation (menu body paths).
        _ = model.runningAppCandidates
        _ = model.historyAppCandidates
        _ = model.ignoredApps
        XCTAssertTrue(model.ignoredApps.isEmpty) // no presets

        let view = PreferencesView(model: model)
        let hosting = NSHostingController(rootView: view)
        hosting.loadView()
        hosting.view.frame = NSRect(x: 0, y: 0, width: 520, height: 600)
        hosting.view.layoutSubtreeIfNeeded()
        XCTAssertGreaterThan(hosting.view.fittingSize.height, 0)

        // Open a real window like PreferencesWindowController does.
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.makeKeyAndOrderFront(nil)
        // Spin the run loop briefly so SwiftUI can commit the graph.
        RunLoop.current.run(until: Date().addingTimeInterval(0.3))
        window.orderOut(nil)
    }
}
