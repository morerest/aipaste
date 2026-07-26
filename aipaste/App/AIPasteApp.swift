import AppKit
import SwiftUI

@main
struct AIPasteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // SwiftUI lifecycle requires a scene. ⌘, opens this; we forward to the
        // real AppKit preferences window (menu-bar apps should not rely on EmptyView).
        Settings {
            PreferencesSettingsBridge()
        }
    }
}

/// Host for the system Settings scene. Opens the real preferences window.
private struct PreferencesSettingsBridge: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Opening Settings…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(width: 280, height: 100)
        .onAppear {
            DispatchQueue.main.async {
                AppState.shared.showPreferences()
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Task { @MainActor in
            AppState.shared.bootstrap()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            Task { @MainActor in
                AppState.shared.showPreferences()
            }
        }
        return true
    }
}
