import AppKit

enum PasteboardWriter {
    /// Hold the internal-write gate through the write and briefly after so the
    /// 0.3s monitor poll does not re-ingest our own pasteboard change.
    private static let gateHoldInterval: TimeInterval = 0.4

    static func write(_ snippet: Snippet, imageData: Data?, gate: InternalPasteboardWriteGate = .shared) throws {
        gate.begin()
        do {
            let pb = NSPasteboard.general
            pb.clearContents()
            switch snippet.kind {
            case .text:
                pb.setString(snippet.textBody ?? snippet.previewText, forType: .string)
            case .image:
                guard let imageData else {
                    gate.end()
                    throw PasteError.missingImageData
                }
                pb.setData(imageData, forType: .png)
                if let img = NSImage(data: imageData) {
                    pb.writeObjects([img])
                }
            }
        } catch {
            gate.end()
            throw error
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + gateHoldInterval) {
            gate.end()
        }
    }
}

enum PasteError: Error {
    case missingImageData
}
