import AppKit
import Foundation

/// A macOS app identity used in ignore rules and pickers.
struct AppIdentity: Identifiable, Hashable, Sendable {
    var id: String { bundleId }
    let bundleId: String
    let name: String
}

/// Resolves friendly display names for bundle IDs (installed apps, known seeds, fallback).
enum AppIdentityResolver {
    /// Fallbacks when the app is not installed (default ignore seeds, uninstalled apps).
    private static let knownDisplayNames: [String: String] = [
        "com.apple.keychainaccess": "Keychain Access",
        "com.1password.1password": "1Password",
        "com.1password.1password-launcher": "1Password",
        "com.agilebits.onepassword7": "1Password 7",
        "com.bitwarden.desktop": "Bitwarden",
        "com.bitwarden.desktop.safari": "Bitwarden",
        "org.keepassxc.keepassxc": "KeePassXC",
        "com.lastpass.LastPass": "LastPass",
    ]

    static func displayName(forBundleId bundleId: String) -> String {
        let trimmed = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return bundleId }

        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmed) {
            if let name = localizedBundleName(at: url) {
                return name
            }
            return FileManager.default.displayName(atPath: url.path)
        }

        return knownDisplayNames[trimmed] ?? trimmed
    }

    static func identity(bundleId: String, preferredName: String? = nil) -> AppIdentity {
        let id = bundleId.trimmingCharacters(in: .whitespacesAndNewlines)
        if let preferredName {
            let name = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return AppIdentity(bundleId: id, name: name)
            }
        }
        return AppIdentity(bundleId: id, name: displayName(forBundleId: id))
    }

    /// Regular (Dock-visible) running apps, excluding self and any IDs in `excludingBundleIds`.
    static func runningApps(excludingBundleIds: Set<String> = []) -> [AppIdentity] {
        let selfId = AppConstants.bundleID
        var seen = Set<String>()
        var result: [AppIdentity] = []

        for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
            guard let id = app.bundleIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !id.isEmpty,
                  id != selfId,
                  !excludingBundleIds.contains(id),
                  !seen.contains(id)
            else { continue }

            seen.insert(id)
            let localized = app.localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = (localized?.isEmpty == false) ? localized! : displayName(forBundleId: id)
            result.append(AppIdentity(bundleId: id, name: name))
        }

        return result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func localizedBundleName(at url: URL) -> String? {
        guard let bundle = Bundle(url: url) else { return nil }
        let keys = ["CFBundleDisplayName", "CFBundleName"]
        for dict in [bundle.localizedInfoDictionary, bundle.infoDictionary].compactMap({ $0 }) {
            for key in keys {
                if let name = dict[key] as? String {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { return trimmed }
                }
            }
        }
        return nil
    }
}
