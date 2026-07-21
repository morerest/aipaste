import AppKit

struct PasteboardPayload: Equatable {
    enum Kind: Equatable {
        case text(String)
        case image(Data, preview: String)
    }
    let kind: Kind
}

enum PasteboardReader {
    static func read(_ pasteboard: NSPasteboard = .general) -> PasteboardPayload? {
        if let image = readImage(pasteboard) {
            return PasteboardPayload(kind: .image(image.data, preview: image.preview))
        }
        if let str = pasteboard.string(forType: .string), !str.isEmpty {
            return PasteboardPayload(kind: .text(str))
        }
        return nil
    }

    private static func readImage(_ pasteboard: NSPasteboard) -> (data: Data, preview: String)? {
        if let tiff = pasteboard.data(forType: .tiff), !tiff.isEmpty {
            let data = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) ?? tiff
            if data.count > AppConstants.maxImageBytes { return nil }
            let preview = previewLabel(for: data)
            return (data, preview)
        }
        if let png = pasteboard.data(forType: .png), !png.isEmpty {
            if png.count > AppConstants.maxImageBytes { return nil }
            return (png, previewLabel(for: png))
        }
        return nil
    }

    private static func previewLabel(for data: Data) -> String {
        if let rep = NSBitmapImageRep(data: data) {
            return "Image (\(rep.pixelsWide)×\(rep.pixelsHigh))"
        }
        return "Image"
    }
}

enum FrontmostAppInfo {
    static func current() -> (bundleId: String?, name: String?) {
        let app = NSWorkspace.shared.frontmostApplication
        return (app?.bundleIdentifier, app?.localizedName)
    }
}
