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
                maxSnippetCount: preferences.maxSnippetCount
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
            historyPanel.configure(store: store, pasteEngine: pasteEngine)
            menuBar = MenuBarController(appState: self)
            menuBar?.install()
            hotKeys = HotKeyManager()
            hotKeys?.onToggleHistory = { [weak self] in
                self?.historyPanel.toggle()
            }
            hotKeys?.registerDefault()
            monitor.start()
        } catch {
            NSLog("clipai bootstrap failed: \(error)")
            let alert = NSAlert()
            alert.messageText = "clipai failed to start"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    func showHistory() { historyPanel.show() }

    func showPreferences() { /* Task 7 */ }

    func quit() {
        monitor?.stop()
        NSApp.terminate(nil)
    }
}
