import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let appState: AppState
    private var statusItem: NSStatusItem?

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func install() {
        // Drop any previous item so reinstall never leaves a second entry.
        uninstall()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.title = ""
            button.image = nil
            button.imagePosition = .imageOnly

            if let image = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: AppConstants.displayName
            ) {
                image.isTemplate = true
                button.image = image
                item.length = NSStatusItem.squareLength
            } else {
                item.length = NSStatusItem.variableLength
                button.imagePosition = .noImage
                button.title = AppConstants.displayName
            }
            button.toolTip = Self.toolTip(hotKeyDisplay: "⇧⌘V")
            // Left-click: toggle workbench. Right-click: app menu (Settings / Clear / Quit).
            button.target = self
            button.action = #selector(statusItemPrimaryAction(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item
    }

    func updateToolTip(hotKeyDisplay: String) {
        statusItem?.button?.toolTip = Self.toolTip(hotKeyDisplay: hotKeyDisplay)
    }

    /// Screen frame of the menu-bar button — used to anchor the launch toast.
    var statusItemScreenFrame: NSRect? {
        guard let button = statusItem?.button, let window = button.window else { return nil }
        let boundsInWindow = button.convert(button.bounds, to: nil)
        return window.convertToScreen(boundsInWindow)
    }

    private static func toolTip(hotKeyDisplay: String) -> String {
        "\(AppConstants.displayName) — click to open history (\(hotKeyDisplay)); right-click for menu"
    }

    func uninstall() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    @objc private func statusItemPrimaryAction(_ sender: Any?) {
        guard let event = NSApp.currentEvent else {
            appState.historyPanel.toggle()
            return
        }
        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            appState.historyPanel.toggle()
        }
    }

    private func showStatusMenu() {
        guard let statusItem else { return }
        let menu = NSMenu()
        menu.delegate = self

        let s = L10n.workbench
        menu.addItem(NSMenuItem(
            title: s.showHistoryMenu,
            action: #selector(showHistory),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: s.settingsMenu,
            action: #selector(openSettings),
            keyEquivalent: ","
        ))
        menu.addItem(.separator())
        let clear = NSMenuItem(
            title: s.clearHistoryMenu,
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        menu.addItem(clear)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: s.quitMenu,
            action: #selector(quitApp),
            keyEquivalent: "q"
        ))

        for item in menu.items {
            item.target = self
        }

        // Attach temporarily so popUp works from the status item.
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func showHistory() {
        appState.historyPanel.show()
    }

    @objc private func openSettings() {
        appState.showPreferences()
    }

    @objc private func clearHistory() {
        appState.confirmAndClearHistory()
    }

    @objc private func quitApp() {
        appState.quit()
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
    }

    deinit {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
    }
}
