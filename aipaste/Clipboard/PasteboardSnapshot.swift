import AppKit
import Foundation

/// Full multi-flavor pasteboard capture so apps like 飞书 can rehydrate proprietary types on paste.
enum PasteboardSnapshot {
    /// Each element is one pasteboard item: UTI/type string → raw bytes.
    typealias Items = [[String: Data]]

    static let maxTotalBytes = 40 * 1024 * 1024

    private struct FileBox: Codable {
        var items: [[String: Data]]
    }

    static func capture(_ pasteboard: NSPasteboard) -> Items {
        var items: Items = []
        var total = 0

        if let pbItems = pasteboard.pasteboardItems, !pbItems.isEmpty {
            for item in pbItems {
                var map: [String: Data] = [:]
                for type in item.types {
                    guard let data = item.data(forType: type), !data.isEmpty else { continue }
                    if total + data.count > maxTotalBytes { continue }
                    map[type.rawValue] = data
                    total += data.count
                }
                if !map.isEmpty {
                    items.append(map)
                }
            }
        }

        if items.isEmpty, let types = pasteboard.types {
            var map: [String: Data] = [:]
            for type in types {
                guard let data = pasteboard.data(forType: type), !data.isEmpty else { continue }
                if total + data.count > maxTotalBytes { continue }
                map[type.rawValue] = data
                total += data.count
            }
            if !map.isEmpty {
                items.append(map)
            }
        }

        return items
    }

    static func restore(_ items: Items, onto pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        let objects: [NSPasteboardItem] = items.map { map in
            let item = NSPasteboardItem()
            for (key, data) in map {
                item.setData(data, forType: NSPasteboard.PasteboardType(key))
            }
            return item
        }
        _ = pasteboard.writeObjects(objects)
    }

    static func encode(_ items: Items) throws -> Data {
        // JSON + base64 Data is more reliable than PropertyList casting back to [[String: Data]].
        try JSONEncoder().encode(FileBox(items: items))
    }

    static func decode(_ data: Data) throws -> Items {
        if let box = try? JSONDecoder().decode(FileBox.self, from: data) {
            return box.items
        }
        // Backward-compatible: older binary plist snapshots.
        let obj = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        guard let rawItems = obj as? [[String: Any]] else {
            throw CocoaError(.coderInvalidValue)
        }
        return rawItems.map { raw in
            var map: [String: Data] = [:]
            for (key, value) in raw {
                if let d = value as? Data {
                    map[key] = d
                } else if let d = value as? NSData {
                    map[key] = d as Data
                }
            }
            return map
        }
    }
}
