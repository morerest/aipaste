import AppKit
import SwiftUI

private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class HistoryPanelController: NSObject {
    private var panel: NSPanel?
    private var model: HistoryViewModel?
    private var onShowPreferences: (() -> Void)?
    private var onClearHistory: (() -> Void)?
    private var onQuit: (() -> Void)?
    private var keyMonitor: Any?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    func configure(
        store: SnippetStore,
        pasteEngine: PasteEngine,
        initialTheme: WorkbenchTheme,
        onShowPreferences: @escaping () -> Void,
        onClearHistory: @escaping () -> Void = {},
        onQuit: @escaping () -> Void = {}
    ) {
        model = HistoryViewModel(store: store, pasteEngine: pasteEngine, theme: initialTheme)
        self.onShowPreferences = onShowPreferences
        self.onClearHistory = onClearHistory
        self.onQuit = onQuit
    }

    func setTheme(_ theme: WorkbenchTheme) {
        model?.setTheme(theme)
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let model else { return }
        model.reload()
        if panel == nil {
            let panel = KeyablePanel(
                contentRect: NSRect(x: 0, y: 0, width: 960, height: 285),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            // SwiftUI draws layered shadows on the glass chrome; keep AppKit shadow light.
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            // Let wallpaper / apps show through for true frosted-glass blur.
            panel.appearance = NSApp.effectiveAppearance
            let root = HistoryView(
                model: model,
                onClose: { [weak self] in self?.hide() },
                onPasteAndClose: { [weak self] in
                    // Spec: hide panel first so ⌘V targets the previous app, not aipaste.
                    self?.pasteSelectedThenHide()
                },
                onShowPreferences: { [weak self] in
                    // Dismiss gallery first; open settings on the next turn so the
                    // floating panel does not steal activation from the prefs window.
                    self?.hide()
                    DispatchQueue.main.async {
                        self?.onShowPreferences?()
                    }
                },
                onClearHistory: { [weak self] in
                    self?.hide()
                    DispatchQueue.main.async {
                        self?.onClearHistory?()
                    }
                },
                onQuit: { [weak self] in
                    self?.hide()
                    DispatchQueue.main.async {
                        self?.onQuit?()
                    }
                }
            )
            let hosting = NSHostingController(rootView: root)
            hosting.view.wantsLayer = true
            hosting.view.layer?.backgroundColor = NSColor.clear.cgColor
            panel.contentViewController = hosting
            self.panel = panel
        }
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        if let screen, let panel {
            let visibleFrame = screen.visibleFrame
            // Always 90% of the active screen's visible width; no min/max clamp.
            let width = visibleFrame.width * 0.9
            let frame = NSRect(
                x: visibleFrame.midX - width / 2,
                y: visibleFrame.minY + 24,
                width: width,
                height: 285
            )
            panel.setFrame(frame, display: false)
        }
        // Become key so search / Enter / Esc work without an extra click.
        panel?.makeKeyAndOrderFront(nil)
        installKeyMonitor()
        installOutsideClickMonitors()
    }

    func hide() {
        removeKeyMonitor()
        removeOutsideClickMonitors()
        panel?.orderOut(nil)
    }

    /// Hide first, yield to the previous app, then paste (write + optional ⌘V).
    private func pasteSelectedThenHide() {
        guard let model, model.hasPasteableSelection else { return }
        hide()
        // Delay lets the previously focused app reclaim first responder before ⌘V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            model.pasteSelected()
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel?.isKeyWindow == true, let model = self.model else { return event }
            let meaningfulModifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
            if meaningfulModifiers == .command,
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                model.copySelected()
                return nil
            }
            // ⌘P toggles favorite without conflicting with search typing.
            if meaningfulModifiers == .command,
               event.charactersIgnoringModifiers?.lowercased() == "p" {
                model.togglePinSelected()
                return nil
            }
            guard meaningfulModifiers.isEmpty else { return event }
            switch event.keyCode {
            case 123: model.selectPrevious(); return nil
            case 124: model.selectNext(); return nil
            case 36, 76: self.pasteSelectedThenHide(); return nil
            case 117: model.deleteSelected(); return nil
            case 53: self.hide(); return nil
            default: return event
            }
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    /// Dismiss when the user clicks outside the gallery (other apps or other windows).
    private func installOutsideClickMonitors() {
        removeOutsideClickMonitors()

        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            if self.panel?.isVisible == true, !self.isClickInsidePanelChrome(event) {
                self.hide()
            }
            return event
        }

        // Clicks that activate another app never enter local monitors.
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.panel?.isVisible == true else { return }
            // Global events have no reliable window; use screen location.
            if let panel = self.panel, !panel.frame.contains(NSEvent.mouseLocation) {
                DispatchQueue.main.async {
                    self.hide()
                }
            }
        }
    }

    private func removeOutsideClickMonitors() {
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
            self.localMouseMonitor = nil
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
            self.globalMouseMonitor = nil
        }
    }

    /// Keep the panel for in-panel clicks and for menus/dialogs spawned from it.
    private func isClickInsidePanelChrome(_ event: NSEvent) -> Bool {
        guard let panel else { return false }
        if let window = event.window {
            if window === panel { return true }
            if window.parent === panel { return true }
            // SwiftUI Menu / context menu / confirmation dialog windows.
            if window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue { return true }
        }
        return panel.frame.contains(NSEvent.mouseLocation)
    }

    func reloadIfVisible() {
        guard panel?.isVisible == true else { return }
        model?.reload()
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
    }
}
