import AppKit

enum PasteboardWriter {
    static func write(_ snippet: Snippet, imageData: Data?, gate: InternalPasteboardWriteGate = .shared) throws {
        try gate.perform {
            let pb = NSPasteboard.general
            pb.clearContents()
            switch snippet.kind {
            case .text:
                pb.setString(snippet.textBody ?? snippet.previewText, forType: .string)
            case .image:
                guard let imageData else {
                    throw PasteError.missingImageData
                }
                pb.setData(imageData, forType: .png)
                if let img = NSImage(data: imageData) {
                    pb.writeObjects([img])
                }
            }
        }
    }
}

enum PasteError: Error {
    case missingImageData
}
