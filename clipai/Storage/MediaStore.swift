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

    func read(relativePath: String) throws -> Data {
        try Data(contentsOf: absoluteURL(relativePath: relativePath))
    }

    func delete(relativePath: String) throws {
        let url = absoluteURL(relativePath: relativePath)
        if fm.fileExists(atPath: url.path) {
            try fm.removeItem(at: url)
        }
    }

    func deleteAll() throws {
        let contents = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        for url in contents {
            try fm.removeItem(at: url)
        }
    }
}
