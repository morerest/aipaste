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
    private let accessibilityCheck: (Bool) -> Bool
    private let commandVAction: () -> Void

    init(store: SnippetStore, gate: InternalPasteboardWriteGate = .shared) {
        self.store = store
        self.gate = gate
        self.accessibilityCheck = AccessibilityPermission.isTrusted(prompt:)
        self.commandVAction = Self.postCommandV
    }

    init(
        store: SnippetStore,
        gate: InternalPasteboardWriteGate = .shared,
        accessibilityCheck: @escaping (Bool) -> Bool,
        commandVAction: @escaping () -> Void
    ) {
        self.store = store
        self.gate = gate
        self.accessibilityCheck = accessibilityCheck
        self.commandVAction = commandVAction
    }

    @discardableResult
    func perform(_ snippet: Snippet, mode: PasteMode) throws -> PasteResult {
        let imageData = try store.mediaData(for: snippet)
        let snapshot = store.pasteboardSnapshot(for: snippet)
        try PasteboardWriter.write(
            snippet,
            imageData: imageData,
            pasteboardSnapshot: snapshot,
            gate: gate
        )
        // The board now holds this snippet, i.e. it was just "copied" —
        // move its card to the front exactly like an external re-copy dedup.
        try store.touch(id: snippet.id)

        if mode == .copyOnly {
            return .copiedOnly(reason: .modeCopyOnly)
        }
        guard accessibilityCheck(false) else {
            return .copiedOnly(reason: .accessibilityDenied)
        }
        commandVAction()
        return .pasted
    }

    private static func postCommandV() {
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
