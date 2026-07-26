import Foundation

final class MediaStore: @unchecked Sendable {
    let directory: URL
    private let fm = FileManager.default

    init(directory: URL) {
        self.directory = directory
    }

    func absoluteURL(relativePath: String) -> URL {
        directory.appendingPathComponent(relativePath)
    }

    /// Returns relative file name stored in DB.
    func writeImage(id: String, data: Data, fileExtension: String = "png") throws -> String {
        let name = "\(id).\(fileExtension)"
        let url = absoluteURL(relativePath: name)
        try data.write(to: url, options: .atomic)
        return name
    }

    /// Full pasteboard multi-type snapshot (for fidelity paste into source apps).
    func writeSnapshot(id: String, data: Data) throws -> String {
        let name = "\(id).pbsnap"
        let url = absoluteURL(relativePath: name)
        try data.write(to: url, options: .atomic)
        return name
    }

    func snapshotRelativePath(forSnippetID id: String) -> String {
        "\(id).pbsnap"
    }

    func read(relativePath: String) throws -> Data {
        try Data(contentsOf: absoluteURL(relativePath: relativePath))
    }

    func delete(relativePath: String) throws {
        let url = absoluteURL(relativePath: relativePath)
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    /// Removes image + optional pasteboard snapshot for a snippet id.
    func deleteMediaBundle(snippetID: String, mediaPath: String?) throws {
        if let mediaPath {
            try delete(relativePath: mediaPath)
        }
        try? delete(relativePath: snapshotRelativePath(forSnippetID: snippetID))
    }

    func deleteAll() throws {
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in contents {
            try fm.removeItem(at: url)
        }
    }
}
