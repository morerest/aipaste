import SwiftUI

@main
struct ClipAIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar app: no main window scene required.
        Settings {
            EmptyView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Wired in Task 6/7 (AppState). Keep empty until then.
        NSApp.setActivationPolicy(.accessory)
    }
}
