import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?
    /// Retained for the lifetime of the window so `@ObservedObject` stays alive.
    private var model: PreferencesViewModel?

    func show(
        preferences: AppPreferences,
        ignoreRules: IgnoreRuleStore,
        store: SnippetStore,
        onHotKeyChanged: @escaping (HotKeyConfig) -> Bool = { _ in true },
        onQuit: @escaping () -> Void = {}
    ) {
        let model = PreferencesViewModel(
            preferences: preferences,
            ignoreRules: ignoreRules,
            store: store,
            onHotKeyChanged: onHotKeyChanged,
            onQuit: onQuit
        )
        self.model = model
        let view = PreferencesView(model: model)
        let hosting = NSHostingController(rootView: view)

        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 600),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = L10n.settings(preferences.appLanguage).windowTitle
            window.titlebarAppearsTransparent = false
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.isMovableByWindowBackground = false
            window.contentViewController = hosting
            window.setContentSize(NSSize(width: 520, height: 600))
            window.center()
            self.window = window
        } else {
            window?.title = L10n.settings(preferences.appLanguage).windowTitle
            window?.contentViewController = hosting
            window?.setContentSize(NSSize(width: 520, height: 600))
        }

        guard let window else { return }

        // Accessory (LSUIElement) apps need an explicit activation to surface windows.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.accessory)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }
}
