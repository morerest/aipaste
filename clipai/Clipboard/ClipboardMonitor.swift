import AppKit

final class ClipboardMonitor {
    private let ingester: PasteboardIngester
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let interval: TimeInterval
    var onIngested: (() -> Void)?

    init(ingester: PasteboardIngester, interval: TimeInterval = AppConstants.monitorInterval) {
        self.ingester = ingester
        self.interval = interval
    }

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        do {
            if try ingester.handlePasteboardChange(pasteboard: pb) {
                onIngested?()
            }
        } catch {
            NSLog("clipai ingest error: \(error.localizedDescription)")
        }
    }
}
