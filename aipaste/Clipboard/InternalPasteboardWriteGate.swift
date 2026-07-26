import Foundation

/// Shared flag so Monitor ignores changes caused by PasteEngine.
final class InternalPasteboardWriteGate: @unchecked Sendable {
    static let shared = InternalPasteboardWriteGate()
    private let lock = NSLock()
    private var depth = 0

    var isInternalWrite: Bool {
        lock.lock(); defer { lock.unlock() }
        return depth > 0
    }

    func begin() {
        lock.lock(); depth += 1; lock.unlock()
    }

    func end() {
        lock.lock(); depth = max(0, depth - 1); lock.unlock()
    }

    func perform(_ body: () throws -> Void) rethrows {
        begin()
        defer { end() }
        try body()
    }
}
