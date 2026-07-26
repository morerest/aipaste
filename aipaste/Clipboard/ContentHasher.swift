import Foundation
import CryptoKit

enum ContentHasher {
    static func hashText(_ text: String) -> String {
        let payload = Data(("text:" + text).utf8)
        return sha256Hex(payload)
    }

    static func hashImage(_ data: Data) -> String {
        var combined = Data("image:".utf8)
        combined.append(data)
        return sha256Hex(combined)
    }

    /// Dedupes mixed (text + image) clips as a single unit.
    static func hashMixed(text: String, imageData: Data) -> String {
        var combined = Data("mixed:".utf8)
        combined.append(Data(text.utf8))
        combined.append(0)
        combined.append(imageData)
        return sha256Hex(combined)
    }

    private static func sha256Hex(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
