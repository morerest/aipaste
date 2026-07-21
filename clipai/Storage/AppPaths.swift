import Foundation

struct AppPaths: Sendable {
    let root: URL

    init(root: URL) {
        self.root = root
    }

    static func defaultPaths() throws -> AppPaths {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return AppPaths(root: base.appendingPathComponent(AppConstants.appSupportFolderName, isDirectory: true))
    }

    var databaseDirectory: URL {
        root.appendingPathComponent(AppConstants.dbFolderName, isDirectory: true)
    }

    var databaseFile: URL {
        databaseDirectory.appendingPathComponent(AppConstants.databaseFileName)
    }

    var mediaDirectory: URL {
        root.appendingPathComponent(AppConstants.mediaFolderName, isDirectory: true)
    }

    func ensureDirectories() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
        try fm.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
    }
}
