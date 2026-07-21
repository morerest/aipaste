import AppKit

@MainActor
final class MenuBarController: NSObject {
    private let appState: AppState
    private var statusItem: NSStatusItem?

    init(appState: AppState) {
        self.appState = appState
        super.init()
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.title = "clipai"
            button.toolTip = "clipai clipboard history"
        }
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show History", action: #selector(showHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences…", action: #selector(showPrefs), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit clipai", action: #selector(quit), keyEquivalent: "q"))
        for menuItem in menu.items {
            menuItem.target = self
        }
        item.menu = menu
        statusItem = item
    }

    @objc private func showHistory() { appState.showHistory() }
    @objc private func showPrefs() { appState.showPreferences() }
    @objc private func quit() { appState.quit() }
}
