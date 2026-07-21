import AppKit
import Carbon.HIToolbox

enum PasteMode {
    case paste
    case copyOnly
}

enum PasteResult: Equatable {
    case pasted
    case copiedOnly(reason: CopyOnlyReason)

    enum CopyOnlyReason: Equatable {
        case modeCopyOnly
        case accessibilityDenied
    }
}

final class PasteEngine {
    private let store: SnippetStore
    private let gate: InternalPasteboardWriteGate

    init(store: SnippetStore, gate: InternalPasteboardWriteGate = .shared) {
        self.store = store
        self.gate = gate
    }

    @discardableResult
    func perform(_ snippet: Snippet, mode: PasteMode) throws -> PasteResult {
        let imageData = try store.mediaData(for: snippet)
        try PasteboardWriter.write(snippet, imageData: imageData, gate: gate)

        if mode == .copyOnly {
            return .copiedOnly(reason: .modeCopyOnly)
        }
        guard AccessibilityPermission.isTrusted(prompt: true) else {
            return .copiedOnly(reason: .accessibilityDenied)
        }
        postCommandV()
        return .pasted
    }

    private func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyV: CGKeyCode = 9 // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
