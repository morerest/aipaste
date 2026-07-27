import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?
    /// Retained for the lifetime of the window so `@ObservedObject` stays alive.
    private var model: PreferencesViewModel?
    /// Reuse the same hosting controller — replacing `contentViewController` on every
    /// open is a common cause of blank/white SwiftUI content on the 2nd+ show.
    private var hostingController: NSHostingController<PreferencesView>?

    func show(
        preferences: AppPreferences,
        ignoreRules: IgnoreRuleStore,
        store: SnippetStore,
        onHotKeyChanged: @escaping (HotKeyConfig) -> Bool = { _ in true },
        onThemeChanged: @escaping (WorkbenchTheme) -> Void = { _ in },
        onQuit: @escaping () -> Void = {}
    ) {
        let model = PreferencesViewModel(
            preferences: preferences,
            ignoreRules: ignoreRules,
            store: store,
            onHotKeyChanged: onHotKeyChanged,
            onThemeChanged: onThemeChanged,
            onQuit: onQuit
        )
        self.model = model

        let root = PreferencesView(model: model)

        if let hostingController {
            hostingController.rootView = root
        } else {
            let hosting = NSHostingController(rootView: root)
            hostingController = hosting
        }

        guard let hostingController else { return }

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
            window.contentViewController = hostingController
            window.setContentSize(NSSize(width: 520, height: 600))
            window.center()
            self.window = window
        } else {
            window?.title = L10n.settings(preferences.appLanguage).windowTitle
            // Keep the same contentViewController instance; only the rootView changed.
            if window?.contentViewController !== hostingController {
                window?.contentViewController = hostingController
            }
            window?.setContentSize(NSSize(width: 520, height: 600))
        }

        guard let window else { return }
        present(window)
    }

    private func present(_ window: NSWindow) {
        // Accessory (LSUIElement) apps need an explicit activation to surface windows.
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.accessory)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Re-show after close can leave the hosting view with zero laid-out content
        // until the next run-loop pass — force a layout so we never flash blank white.
        window.layoutIfNeeded()
        hostingController?.view.needsLayout = true
        hostingController?.view.layoutSubtreeIfNeeded()
        DispatchQueue.main.async { [weak self, weak window] in
            window?.layoutIfNeeded()
            self?.hostingController?.view.needsLayout = true
            self?.hostingController?.view.layoutSubtreeIfNeeded()
        }
    }
}
