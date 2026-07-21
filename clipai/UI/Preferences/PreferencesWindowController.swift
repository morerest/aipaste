import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?

    func show(preferences: AppPreferences, ignoreRules: IgnoreRuleStore, store: SnippetStore) {
        let model = PreferencesViewModel(preferences: preferences, ignoreRules: ignoreRules, store: store)
        let view = PreferencesView(model: model)
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "clipai Preferences"
            window.contentViewController = NSHostingController(rootView: view)
            window.center()
            self.window = window
        } else {
            window?.contentViewController = NSHostingController(rootView: view)
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
