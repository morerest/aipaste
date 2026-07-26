import AppKit
import UniformTypeIdentifiers

struct PasteboardPayload: Equatable {
    enum Kind: Equatable {
        case text(String)
        case image(Data, preview: String)
        /// Both plain text and image flavors present on the same pasteboard change.
        case mixed(text: String, image: Data, imagePreview: String)
    }
    let kind: Kind
}

/// One decoded PNG candidate with quality score for ranking.
private struct ImageCandidate: Comparable {
    let data: Data
    let preview: String
    let pixelArea: Int
    let byteCount: Int
    let source: String

    var score: Int { pixelArea * 10 + min(byteCount, 5_000_000) }

    static func < (lhs: ImageCandidate, rhs: ImageCandidate) -> Bool {
        lhs.score < rhs.score
    }

    /// Chat apps often put a small "broken image" / attachment glyph next to captions.
    var isLikelyPlaceholder: Bool {
        if byteCount < 4_000 { return true }
        guard let rep = NSBitmapImageRep(data: data) else { return byteCount < 8_000 }
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        let shortSide = min(w, h)
        if shortSide > 0, shortSide < 64 { return true }
        if w * h > 0, w * h < 80 * 80 { return true }
        // Nearly-square small UI icon (e.g. 飞书 blue “?” tile ~120–200px).
        if shortSide <= 200, abs(w - h) <= 8, byteCount < 40_000 {
            if isMostlySolidUIChrome(rep) { return true }
        }
        return false
    }

    private func isMostlySolidUIChrome(_ rep: NSBitmapImageRep) -> Bool {
        // Sample a grid; placeholders are flat color blocks with little variance.
        let w = rep.pixelsWide
        let h = rep.pixelsHigh
        guard w > 4, h > 4 else { return true }
        var samples: [(r: CGFloat, g: CGFloat, b: CGFloat)] = []
        let steps = 6
        for yi in 0..<steps {
            for xi in 0..<steps {
                let x = min(w - 1, max(0, (xi * (w - 1)) / (steps - 1)))
                let y = min(h - 1, max(0, (yi * (h - 1)) / (steps - 1)))
                guard let color = rep.colorAt(x: x, y: y) else { continue }
                var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                color.getRed(&r, green: &g, blue: &b, alpha: &a)
                if a < 0.1 { continue }
                samples.append((r, g, b))
            }
        }
        guard samples.count >= 8 else { return false }
        let avgR = samples.map(\.r).reduce(0, +) / CGFloat(samples.count)
        let avgG = samples.map(\.g).reduce(0, +) / CGFloat(samples.count)
        let avgB = samples.map(\.b).reduce(0, +) / CGFloat(samples.count)
        var varSum: CGFloat = 0
        for s in samples {
            let dr = s.r - avgR, dg = s.g - avgG, db = s.b - avgB
            varSum += dr * dr + dg * dg + db * db
        }
        let variance = varSum / CGFloat(samples.count)
        // Flat blue UI chrome has very low color variance.
        return variance < 0.02
    }
}

enum PasteboardReader {
    static func read(_ pasteboard: NSPasteboard = .general) -> PasteboardPayload? {
        let text = readText(pasteboard)
        var candidates = collectImageCandidates(pasteboard)

        // If we only have text + placeholder icons, hunt file paths / img URLs in the board.
        if text != nil {
            let hasReal = candidates.contains { !$0.isLikelyPlaceholder }
            if !hasReal {
                for hit in recoverImagesFromEmbeddedReferences(pasteboard) {
                    appendCandidate(hit, source: "embedded-ref", into: &candidates)
                }
            }
        }

        let image = pickBestImage(from: candidates, preferSubstantial: text != nil)

        if text != nil, image == nil {
            logMissingImage(pasteboard, candidates: candidates)
        } else if text != nil, let image, candidates.contains(where: {
            $0.data == image.data && $0.isLikelyPlaceholder
        }) {
            NSLog("aipaste pasteboard: using best-available image which may still be a UI placeholder")
        }

        switch (image, text) {
        case let (img?, str?):
            return PasteboardPayload(
                kind: .mixed(text: str, image: img.data, imagePreview: img.preview)
            )
        case let (img?, nil):
            return PasteboardPayload(kind: .image(img.data, preview: img.preview))
        case let (nil, str?):
            return PasteboardPayload(kind: .text(str))
        case (nil, nil):
            return nil
        }
    }

    private static func pickBestImage(
        from candidates: [ImageCandidate],
        preferSubstantial: Bool
    ) -> (data: Data, preview: String)? {
        guard !candidates.isEmpty else { return nil }
        let sorted = candidates.sorted(by: >)

        if preferSubstantial {
            if let substantial = sorted.first(where: { !$0.isLikelyPlaceholder }) {
                return (substantial.data, substantial.preview)
            }
            // Keep best overall so we do not silently drop image flavors entirely.
            if let best = sorted.first {
                return (best.data, best.preview)
            }
            return nil
        }
        return sorted.first.map { ($0.data, $0.preview) }
    }

    private static func logMissingImage(_ pasteboard: NSPasteboard, candidates: [ImageCandidate]) {
        let types = pasteboard.types?.map(\.rawValue).joined(separator: ", ") ?? "(none)"
        let itemSummary = (pasteboard.pasteboardItems ?? []).enumerated().map { idx, item in
            let parts = item.types.map { t -> String in
                let n = item.data(forType: t)?.count ?? 0
                return "\(t.rawValue)(\(n))"
            }
            return "item\(idx):[\(parts.joined(separator: ","))]"
        }.joined(separator: " ")
        let cand = candidates.map { "\($0.source):\($0.byteCount)b/\($0.pixelArea)px" }.joined(separator: ",")
        NSLog("aipaste pasteboard: text without usable image; types=[\(types)] \(itemSummary); candidates=[\(cand)]")
    }

    // MARK: - Text

    private static func readText(_ pasteboard: NSPasteboard) -> String? {
        if let str = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty {
            return str
        }
        if let data = pasteboard.data(forType: .init("public.utf8-plain-text")),
           let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !str.isEmpty {
            return str
        }
        for item in pasteboard.pasteboardItems ?? [] {
            if let str = item.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !str.isEmpty {
                return str
            }
            if let data = item.data(forType: .init("public.utf8-plain-text")),
               let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !str.isEmpty {
                return str
            }
        }
        if let html = pasteboard.string(forType: .html) ?? htmlFromItems(pasteboard) {
            let plain = stripHTML(html).trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty { return plain }
        }
        return nil
    }

    private static func htmlFromItems(_ pasteboard: NSPasteboard) -> String? {
        for item in pasteboard.pasteboardItems ?? [] {
            if let html = item.string(forType: .html), !html.isEmpty { return html }
            if let data = item.data(forType: .html),
               let html = String(data: data, encoding: .utf8),
               !html.isEmpty {
                return html
            }
        }
        return nil
    }

    private static func stripHTML(_ html: String) -> String {
        var s = html
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>", options: .caseInsensitive) {
            s = regex.stringByReplacingMatches(
                in: s,
                range: NSRange(s.startIndex..., in: s),
                withTemplate: " "
            )
        }
        s = s
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
        return s
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    // MARK: - Image candidates

    private static func collectImageCandidates(_ pasteboard: NSPasteboard) -> [ImageCandidate] {
        var found: [ImageCandidate] = []
        var seen = Set<Data>()

        func add(_ hit: (data: Data, preview: String)?, source: String) {
            appendCandidate(hit, source: source, into: &found, seen: &seen)
        }

        for type in standardImageTypes {
            if let data = pasteboard.data(forType: type), !data.isEmpty {
                if type.rawValue == "com.adobe.pdf" {
                    if let img = NSImage(data: data), let tiff = img.tiffRepresentation {
                        add(normalizedImagePayload(from: tiff), source: "pdf")
                    }
                } else {
                    add(normalizedImagePayload(from: data, alreadyPNG: type == .png), source: type.rawValue)
                }
            }
        }

        for item in pasteboard.pasteboardItems ?? [] {
            for type in item.types {
                if type == .fileURL || type.rawValue == "public.file-url" {
                    if let urlString = item.string(forType: type),
                       let url = URL(string: urlString) {
                        add(imageFromLocalFileURL(url), source: "file-url")
                    }
                    continue
                }
                if isProbablyNonImageType(type) { continue }
                guard let data = item.data(forType: type), !data.isEmpty else { continue }

                if looksLikeImageBinary(data) || isKnownImageType(type) {
                    add(normalizedImagePayload(from: data, alreadyPNG: type == .png), source: "item:\(type.rawValue)")
                    continue
                }
                if data.count >= 8_000 {
                    add(normalizedImagePayload(from: data), source: "blob:\(type.rawValue)")
                }
            }
        }

        if let urls = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL] {
            for url in urls { add(imageFromLocalFileURL(url), source: "nsurl") }
        }
        if let paths = pasteboard.propertyList(forType: .init("NSFilenamesPboardType")) as? [String] {
            for path in paths { add(imageFromLocalFileURL(URL(fileURLWithPath: path)), source: "filenames") }
        }

        if let objects = pasteboard.readObjects(forClasses: [NSAttributedString.self], options: nil)
            as? [NSAttributedString] {
            for attr in objects {
                let full = NSRange(location: 0, length: attr.length)
                attr.enumerateAttribute(.attachment, in: full) { value, _, _ in
                    guard let attachment = value as? NSTextAttachment,
                          let data = attachmentImageData(attachment) else { return }
                    add(normalizedImagePayload(from: data), source: "attachment")
                }
            }
        }

        if let html = pasteboard.string(forType: .html) ?? htmlFromItems(pasteboard) {
            for hit in allImagesFromHTMLDataURI(html) {
                add(hit, source: "html-data-uri")
            }
        }

        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage] {
            for (idx, image) in images.enumerated() {
                if let tiff = image.tiffRepresentation {
                    add(normalizedImagePayload(from: tiff), source: "nsimage-\(idx)")
                }
            }
        }

        return found
    }

    private static func appendCandidate(
        _ hit: (data: Data, preview: String)?,
        source: String,
        into found: inout [ImageCandidate],
        seen: inout Set<Data>
    ) {
        guard let hit, !seen.contains(hit.data) else { return }
        seen.insert(hit.data)
        let area: Int
        if let rep = NSBitmapImageRep(data: hit.data) {
            area = max(0, rep.pixelsWide * rep.pixelsHigh)
        } else {
            area = 0
        }
        found.append(
            ImageCandidate(
                data: hit.data,
                preview: hit.preview,
                pixelArea: area,
                byteCount: hit.data.count,
                source: source
            )
        )
    }

    private static func appendCandidate(
        _ hit: (data: Data, preview: String)?,
        source: String,
        into found: inout [ImageCandidate]
    ) {
        var seen = Set(found.map(\.data))
        appendCandidate(hit, source: source, into: &found, seen: &seen)
    }

    /// Last-ditch: scrape paths / img src from every string-like pasteboard payload.
    private static func recoverImagesFromEmbeddedReferences(
        _ pasteboard: NSPasteboard
    ) -> [(data: Data, preview: String)] {
        var results: [(data: Data, preview: String)] = []
        var seenPaths = Set<String>()

        func considerPath(_ raw: String) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "file://", with: "")
                .removingPercentEncoding ?? raw
            guard !seenPaths.contains(trimmed) else { return }
            seenPaths.insert(trimmed)
            let url: URL
            if trimmed.hasPrefix("/") {
                url = URL(fileURLWithPath: trimmed)
            } else if let u = URL(string: raw), u.isFileURL {
                url = u
            } else {
                return
            }
            if let hit = imageFromLocalFileURL(url) {
                results.append(hit)
            }
        }

        for blob in allStringBlobs(pasteboard) {
            // Absolute paths to images
            if let regex = try? NSRegularExpression(
                pattern: #"(?i)(/[^\s\"'<>]+?\.(?:png|jpe?g|gif|webp|heic|tiff?))\b"#
            ) {
                let range = NSRange(blob.startIndex..., in: blob)
                for match in regex.matches(in: blob, range: range) {
                    if let r = Range(match.range(at: 1), in: blob) {
                        considerPath(String(blob[r]))
                    }
                }
            }
            // file:// URLs
            if let regex = try? NSRegularExpression(
                pattern: #"(?i)file://[^\s\"'<>]+"#
            ) {
                let range = NSRange(blob.startIndex..., in: blob)
                for match in regex.matches(in: blob, range: range) {
                    if let r = Range(match.range, in: blob) {
                        considerPath(String(blob[r]))
                    }
                }
            }
            // <img src="...">
            if let regex = try? NSRegularExpression(
                pattern: #"(?i)<img[^>]+src=["']([^"']+)["']"#
            ) {
                let range = NSRange(blob.startIndex..., in: blob)
                for match in regex.matches(in: blob, range: range) {
                    guard let r = Range(match.range(at: 1), in: blob) else { continue }
                    let src = String(blob[r])
                    if src.hasPrefix("data:image") {
                        if let hit = firstImageFromHTMLDataURI(src) {
                            results.append(hit)
                        }
                    } else if src.hasPrefix("file:") || src.hasPrefix("/") {
                        considerPath(src)
                    }
                    // Remote https intentionally not downloaded (privacy / auth).
                }
            }
        }
        return results
    }

    private static func allStringBlobs(_ pasteboard: NSPasteboard) -> [String] {
        var blobs: [String] = []
        if let s = pasteboard.string(forType: .string) { blobs.append(s) }
        if let s = pasteboard.string(forType: .html) { blobs.append(s) }
        if let s = pasteboard.string(forType: .rtf) { blobs.append(s) }
        for item in pasteboard.pasteboardItems ?? [] {
            for type in item.types {
                if let s = item.string(forType: type), s.count > 8, s.count < 2_000_000 {
                    blobs.append(s)
                } else if let data = item.data(forType: type),
                          data.count < 2_000_000,
                          let s = String(data: data, encoding: .utf8),
                          s.count > 8 {
                    blobs.append(s)
                }
            }
        }
        return blobs
    }

    private static var standardImageTypes: [NSPasteboard.PasteboardType] {
        [
            .tiff,
            .png,
            NSPasteboard.PasteboardType("public.jpeg"),
            NSPasteboard.PasteboardType("public.jpeg-xl"),
            NSPasteboard.PasteboardType("public.heic"),
            NSPasteboard.PasteboardType("public.heif"),
            NSPasteboard.PasteboardType("com.compuserve.gif"),
            NSPasteboard.PasteboardType("public.webp"),
            NSPasteboard.PasteboardType("public.image"),
            NSPasteboard.PasteboardType("com.adobe.pdf"),
        ]
    }

    private static func isKnownImageType(_ type: NSPasteboard.PasteboardType) -> Bool {
        let raw = type.rawValue.lowercased()
        return raw.contains("image")
            || raw.contains("png")
            || raw.contains("jpeg")
            || raw.contains("jpg")
            || raw.contains("tiff")
            || raw.contains("gif")
            || raw.contains("heic")
            || raw.contains("webp")
    }

    private static func isProbablyNonImageType(_ type: NSPasteboard.PasteboardType) -> Bool {
        let raw = type.rawValue.lowercased()
        if raw.contains("text") && !raw.contains("image") { return true }
        if raw.contains("html") { return true }
        if raw.contains("rtf") && !raw.contains("rtfd") { return true }
        if raw.contains("url") && !raw.contains("file-url") && !raw.contains("fileurl") { return true }
        return false
    }

    private static func looksLikeImageBinary(_ data: Data) -> Bool {
        guard data.count >= 12 else { return false }
        let b = [UInt8](data.prefix(12))
        if b.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return true }
        if b[0] == 0xFF, b[1] == 0xD8, b[2] == 0xFF { return true }
        if b.starts(with: [0x47, 0x49, 0x46, 0x38]) { return true }
        if b.starts(with: [0x49, 0x49, 0x2A, 0x00]) || b.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) { return true }
        if b.starts(with: [0x52, 0x49, 0x46, 0x46]), data.count >= 12 {
            let tag = [UInt8](data.subdata(in: 8..<12))
            if tag == [0x57, 0x45, 0x42, 0x50] { return true }
        }
        return false
    }

    private static func imageFromLocalFileURL(_ url: URL) -> (data: Data, preview: String)? {
        guard url.isFileURL else { return nil }
        let path = url.path
        guard FileManager.default.fileExists(atPath: path) else { return nil }

        let ext = url.pathExtension.lowercased()
        let known = ["png", "jpg", "jpeg", "tif", "tiff", "gif", "heic", "heif", "webp", "bmp"]
        if !ext.isEmpty, !known.contains(ext) {
            if let type = UTType(filenameExtension: ext), !type.conforms(to: .image) {
                return nil
            }
        }

        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        if let hit = normalizedImagePayload(from: data) { return hit }
        if let img = NSImage(contentsOf: url), let tiff = img.tiffRepresentation {
            return normalizedImagePayload(from: tiff)
        }
        return nil
    }

    private static func attachmentImageData(_ attachment: NSTextAttachment) -> Data? {
        if let data = attachment.fileWrapper?.regularFileContents, !data.isEmpty {
            return data
        }
        if let wrapper = attachment.fileWrapper, wrapper.isDirectory,
           let children = wrapper.fileWrappers {
            for (_, child) in children {
                if let data = child.regularFileContents, looksLikeImageBinary(data) {
                    return data
                }
            }
        }
        if let data = attachment.contents, !data.isEmpty {
            return data
        }
        if let image = attachment.image, let tiff = image.tiffRepresentation {
            return tiff
        }
        if let cell = attachment.attachmentCell as? NSCell,
           let image = cell.image,
           let tiff = image.tiffRepresentation {
            return tiff
        }
        return nil
    }

    private static func allImagesFromHTMLDataURI(_ html: String) -> [(data: Data, preview: String)] {
        guard let regex = try? NSRegularExpression(
            pattern: #"data:image/(png|jpeg|jpg|gif|webp);base64,([A-Za-z0-9+/=\s]+)"#,
            options: .caseInsensitive
        ) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        var results: [(data: Data, preview: String)] = []
        for match in regex.matches(in: html, range: range) {
            guard match.numberOfRanges >= 3,
                  let b64Range = Range(match.range(at: 2), in: html) else { continue }
            let b64 = html[b64Range]
                .components(separatedBy: .whitespacesAndNewlines)
                .joined()
            guard let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters),
                  !data.isEmpty,
                  let hit = normalizedImagePayload(from: data) else { continue }
            results.append(hit)
        }
        return results
    }

    private static func firstImageFromHTMLDataURI(_ html: String) -> (data: Data, preview: String)? {
        allImagesFromHTMLDataURI(html).first
    }

    private static func normalizedImagePayload(
        from data: Data,
        alreadyPNG: Bool = false
    ) -> (data: Data, preview: String)? {
        let png: Data
        if alreadyPNG, NSBitmapImageRep(data: data) != nil {
            png = data
        } else if let converted = NSBitmapImageRep(data: data)?.representation(using: .png, properties: [:]) {
            png = converted
        } else if let img = NSImage(data: data),
                  let tiff = img.tiffRepresentation,
                  let converted = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            png = converted
        } else {
            return nil
        }
        guard png.count <= AppConstants.maxImageBytes, !png.isEmpty else { return nil }
        return (png, previewLabel(for: png))
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
