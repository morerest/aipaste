import AppKit
import Combine

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    private(set) var store: SnippetStore!
    private(set) var ignoreRules: IgnoreRuleStore!
    private(set) var pasteEngine: PasteEngine!
    private(set) var monitor: ClipboardMonitor!
    private(set) var preferences: AppPreferences!

    let historyPanel = HistoryPanelController()
    let preferencesWindow = PreferencesWindowController()
    private let launchToast = LaunchToastController()
    private var menuBar: MenuBarController?
    private var hotKeys: HotKeyManager?
    private var bootstrapped = false

    private init() {}

    func bootstrap() {
        guard !bootstrapped else { return }
        bootstrapped = true
        do {
            let paths = try AppPaths.defaultPaths()
            try paths.ensureDirectories()
            let db = try Database(path: paths.databaseFile)
            let media = MediaStore(directory: paths.mediaDirectory)
            preferences = AppPreferences()
            store = SnippetStore(
                database: db,
                mediaStore: media,
                maxSnippetCount: preferences.maxSnippetCount,
                maxFavoriteCount: preferences.maxFavoriteCount
            )
            ignoreRules = IgnoreRuleStore()
            pasteEngine = PasteEngine(store: store)
            let ingester = PasteboardIngester(store: store, ignoreRules: ignoreRules)
            monitor = ClipboardMonitor(ingester: ingester)
            monitor.onIngested = { [weak self] in
                Task { @MainActor in
                    self?.historyPanel.reloadIfVisible()
                }
            }
            historyPanel.configure(
                store: store,
                pasteEngine: pasteEngine,
                initialTheme: preferences.workbenchTheme,
                onShowPreferences: { [weak self] in self?.showPreferences() },
                onClearHistory: { [weak self] in self?.confirmAndClearHistory() },
                onQuit: { [weak self] in self?.quit() }
            )
            menuBar = MenuBarController(appState: self)
            menuBar?.install()
            hotKeys = HotKeyManager()
            hotKeys?.onToggleHistory = { [weak self] in
                self?.historyPanel.toggle()
            }
            hotKeys?.register(preferences.toggleHistoryHotKey)
            menuBar?.updateToolTip(hotKeyDisplay: preferences.toggleHistoryHotKey.displayString)
            monitor.start()
            // Menu-bar accessory has no Dock bounce — confirm a successful start.
            showLaunchReadyToast()
        } catch {
            NSLog("aipaste bootstrap failed: \(error)")
            let alert = NSAlert()
            alert.messageText = "\(AppConstants.displayName) failed to start"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    /// Brief HUD under the status item so cold launch is obviously successful.
    private func showLaunchReadyToast() {
        guard let preferences else { return }
        // Let the status item land in the menu bar before measuring its frame.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.launchToast.show(
                hotKeyDisplay: preferences.toggleHistoryHotKey.displayString,
                theme: preferences.workbenchTheme,
                anchorScreenFrame: self.menuBar?.statusItemScreenFrame
            )
        }
    }

    func showHistory() { historyPanel.show() }

    func showPreferences() {
        guard let preferences, let ignoreRules, let store else { return }
        preferencesWindow.show(
            preferences: preferences,
            ignoreRules: ignoreRules,
            store: store,
            onHotKeyChanged: { [weak self] (config: HotKeyConfig) in
                guard let self, let hotKeys = self.hotKeys else { return false }
                let ok = hotKeys.tryRegister(config)
                if ok {
                    self.menuBar?.updateToolTip(hotKeyDisplay: config.displayString)
                }
                return ok
            },
            onThemeChanged: { [weak self] theme in
                self?.historyPanel.setTheme(theme)
            },
            onQuit: { [weak self] in
                self?.quit()
            }
        )
    }

    func quit() {
        monitor?.stop()
        menuBar?.uninstall()
        NSApp.terminate(nil)
    }

    /// Status-bar / app-level clear with native confirmation.
    /// Favorites (pinned) are kept by default.
    func confirmAndClearHistory() {
        guard let store else { return }
        let s = L10n.workbench
        let alert = NSAlert()
        alert.messageText = s.clearConfirmTitle
        alert.informativeText = s.clearConfirmMessage
        alert.alertStyle = .warning
        alert.addButton(withTitle: s.clearConfirmAction)
        alert.addButton(withTitle: s.clearConfirmCancel)
        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        do {
            try store.deleteUnpinned()
            historyPanel.reloadIfVisible()
        } catch {
            let err = NSAlert(error: error)
            err.runModal()
        }
    }
}
