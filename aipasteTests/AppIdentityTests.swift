import XCTest
@testable import aipaste

final class AppIdentityTests: XCTestCase {
    func testKnownDisplayNameFallback() {
        // Not relying on the app being installed — seed IDs have friendly names.
        XCTAssertEqual(
            AppIdentityResolver.displayName(forBundleId: "com.1password.1password"),
            "1Password"
        )
        XCTAssertEqual(
            AppIdentityResolver.displayName(forBundleId: "com.bitwarden.desktop"),
            "Bitwarden"
        )
        XCTAssertEqual(
            AppIdentityResolver.displayName(forBundleId: "com.apple.keychainaccess"),
            "Keychain Access"
        )
    }

    func testUnknownBundleFallsBackToId() {
        let id = "com.example.not-a-real-app.\(UUID().uuidString)"
        XCTAssertEqual(AppIdentityResolver.displayName(forBundleId: id), id)
    }

    func testPreferredNameWins() {
        let identity = AppIdentityResolver.identity(
            bundleId: "com.example.app",
            preferredName: "Example"
        )
        XCTAssertEqual(identity.name, "Example")
        XCTAssertEqual(identity.bundleId, "com.example.app")
    }

    func testRunningAppsExcludesSelf() {
        let apps = AppIdentityResolver.runningApps()
        XCTAssertFalse(apps.contains { $0.bundleId == AppConstants.bundleID })
    }
}

@MainActor
final class PreferencesIgnoreTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("aipaste-prefs-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
        tempRoot = nil
    }

    private func makeModel(ignore: IgnoreRuleStore) throws -> PreferencesViewModel {
        let paths = AppPaths(root: tempRoot)
        try paths.ensureDirectories()
        let db = try Database(path: paths.databaseFile)
        let store = SnippetStore(
            database: db,
            mediaStore: MediaStore(directory: paths.mediaDirectory)
        )
        let defaults = UserDefaults(suiteName: "com.eden.aipaste.tests.prefs.\(UUID().uuidString)")!
        let prefs = AppPreferences(defaults: defaults)
        return PreferencesViewModel(
            preferences: prefs,
            ignoreRules: ignore,
            store: store
        )
    }

    func testAddIgnoreRejectsSelf() throws {
        let defaults = UserDefaults(suiteName: "com.eden.aipaste.tests.prefs.\(UUID().uuidString)")!
        let ignore = IgnoreRuleStore(defaults: defaults)
        let model = try makeModel(ignore: ignore)

        let ok = model.addIgnore(bundleId: AppConstants.bundleID)
        XCTAssertFalse(ok)
        XCTAssertTrue(model.ignoredApps.isEmpty)
        XCTAssertEqual(model.ignoreStatusMessage, model.strings.cannotIgnoreSelf)
    }

    func testAddIgnoreShowsFriendlyName() throws {
        let defaults = UserDefaults(suiteName: "com.eden.aipaste.tests.prefs.\(UUID().uuidString)")!
        let ignore = IgnoreRuleStore(defaults: defaults)
        let model = try makeModel(ignore: ignore)

        let ok = model.addIgnore(bundleId: "com.example.notes", preferredName: "Notes")
        XCTAssertTrue(ok)
        XCTAssertEqual(model.ignoredApps.map(\.bundleId), ["com.example.notes"])
        XCTAssertEqual(model.ignoredApps.first?.displayName, "Notes")
        XCTAssertTrue(ignore.isIgnored(bundleId: "com.example.notes"))
    }

    func testAddIgnoreDuplicate() throws {
        let defaults = UserDefaults(suiteName: "com.eden.aipaste.tests.prefs.\(UUID().uuidString)")!
        let ignore = IgnoreRuleStore(defaults: defaults)
        ignore.add(bundleId: "com.example.dup")
        let model = try makeModel(ignore: ignore)

        let ok = model.addIgnore(bundleId: "com.example.dup")
        XCTAssertFalse(ok)
        XCTAssertEqual(model.ignoredApps.count, 1)
        XCTAssertEqual(model.ignoreStatusMessage, model.strings.alreadyIgnored)
    }

    func testStartsWithEmptyIgnoreList() throws {
        let defaults = UserDefaults(suiteName: "com.eden.aipaste.tests.prefs.\(UUID().uuidString)")!
        let ignore = IgnoreRuleStore(defaults: defaults)
        let model = try makeModel(ignore: ignore)
        XCTAssertTrue(model.ignoredApps.isEmpty)
    }
}
