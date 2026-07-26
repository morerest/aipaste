import AppKit

enum PasteboardWriter {
    /// Hold the internal-write gate through the write and briefly after so the
    /// 0.3s monitor poll does not re-ingest our own pasteboard change.
    private static let gateHoldInterval: TimeInterval = 0.4

    static func write(
        _ snippet: Snippet,
        imageData: Data?,
        pasteboardSnapshot: PasteboardSnapshot.Items? = nil,
        gate: InternalPasteboardWriteGate = .shared
    ) throws {
        gate.begin()
        do {
            let pb = NSPasteboard.general

            // 1) Always put reliable standard flavors first (text / png / tiff).
            //    This matches the earlier “working” mixed paste behavior.
            try writeStandardFlavors(snippet, imageData: imageData, onto: pb)

            // 2) If we captured the original board, re-apply proprietary types on top
            //    without clearing string/png (飞书 needs its private flavors for real images).
            if let pasteboardSnapshot, !pasteboardSnapshot.isEmpty {
                mergeProprietaryTypes(pasteboardSnapshot, onto: pb)
            }
        } catch {
            gate.end()
            throw error
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + gateHoldInterval) {
            gate.end()
        }
    }

    private static func writeStandardFlavors(
        _ snippet: Snippet,
        imageData: Data?,
        onto pb: NSPasteboard
    ) throws {
        pb.clearContents()
        switch snippet.kind {
        case .text:
            let text = snippet.textBody ?? snippet.previewText
            pb.declareTypes([.string], owner: nil)
            pb.setString(text, forType: .string)

        case .image:
            guard let imageData else { throw PasteError.missingImageData }
            writeImageFlavors(pb, imageData: imageData, alsoText: nil)

        case .mixed:
            guard let imageData else { throw PasteError.missingImageData }
            let text = snippet.textBody ?? snippet.previewText
            writeImageFlavors(pb, imageData: imageData, alsoText: text.isEmpty ? nil : text)
        }
    }

    private static func writeImageFlavors(
        _ pb: NSPasteboard,
        imageData: Data,
        alsoText: String?
    ) {
        var types: [NSPasteboard.PasteboardType] = [.png, .tiff]
        if alsoText != nil {
            types.insert(.string, at: 0)
        }
        pb.declareTypes(types, owner: nil)

        if let alsoText {
            pb.setString(alsoText, forType: .string)
        }
        pb.setData(imageData, forType: .png)
        if let tiff = NSImage(data: imageData)?.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        } else {
            pb.setData(imageData, forType: .tiff)
        }
    }

    /// Adds non-standard types from the original capture onto the current board.
    /// Does not clear existing string/png/tiff we just wrote.
    private static func mergeProprietaryTypes(
        _ items: PasteboardSnapshot.Items,
        onto pb: NSPasteboard
    ) {
        let protected: Set<String> = [
            NSPasteboard.PasteboardType.string.rawValue,
            NSPasteboard.PasteboardType.png.rawValue,
            NSPasteboard.PasteboardType.tiff.rawValue,
            "public.utf8-plain-text",
        ]

        // Flatten extra types onto the general pasteboard (single-item apps still see them).
        var extraTypes: [NSPasteboard.PasteboardType] = pb.types ?? []
        var extras: [(NSPasteboard.PasteboardType, Data)] = []

        for map in items {
            for (key, data) in map {
                guard !protected.contains(key), !data.isEmpty else { continue }
                let type = NSPasteboard.PasteboardType(key)
                if !extraTypes.contains(type) {
                    extraTypes.append(type)
                }
                extras.append((type, data))
            }
        }

        guard !extras.isEmpty else { return }

        // Re-declare including proprietary types, then rewrite standard + extras.
        let standard = pb.types ?? []
        var combined = standard
        for t in extraTypes where !combined.contains(t) {
            combined.append(t)
        }

        // Preserve standard payloads we already set.
        let keptString = pb.string(forType: .string)
        let keptPNG = pb.data(forType: .png)
        let keptTIFF = pb.data(forType: .tiff)

        pb.declareTypes(combined, owner: nil)
        if let keptString { pb.setString(keptString, forType: .string) }
        if let keptPNG { pb.setData(keptPNG, forType: .png) }
        if let keptTIFF { pb.setData(keptTIFF, forType: .tiff) }
        for (type, data) in extras {
            pb.setData(data, forType: type)
        }
    }
}

enum PasteError: Error {
    case missingImageData
}
