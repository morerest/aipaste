import AppKit
import SwiftUI

enum GalleryScrollMetrics {
    static let threshold: CGFloat = 70
    static let discreteLineStep: CGFloat = 48

    static func shouldShowBackToLatest(leadingX: CGFloat, hasResults: Bool) -> Bool {
        hasResults && leadingX < -threshold
    }

    /// Maps a predominantly vertical scroll-wheel delta to a horizontal content-offset
    /// delta (`+x` moves toward older cards on the right; `-x` moves toward the latest
    /// card on the left). Returns `nil` when horizontal scrolling already dominates.
    static func horizontalScrollDelta(
        scrollingDeltaX: CGFloat,
        scrollingDeltaY: CGFloat,
        deltaY: CGFloat = 0,
        hasPreciseScrollingDeltas: Bool,
        lineScroll: CGFloat = discreteLineStep
    ) -> CGFloat? {
        let effectiveVerticalDelta = scrollingDeltaY != 0 ? scrollingDeltaY : (deltaY * 10)
        guard effectiveVerticalDelta != 0,
              abs(effectiveVerticalDelta) > abs(scrollingDeltaX)
        else {
            return nil
        }
        if hasPreciseScrollingDeltas {
            return -effectiveVerticalDelta
        }
        let step = max(lineScroll, discreteLineStep)
        return -effectiveVerticalDelta * step
    }

    static func clampedHorizontalOffset(
        currentX: CGFloat,
        deltaX: CGFloat,
        documentWidth: CGFloat,
        visibleWidth: CGFloat
    ) -> CGFloat {
        let maxOffsetX = max(0, documentWidth - visibleWidth)
        return min(max(0, currentX + deltaX), maxOffsetX)
    }
}

/// Bridges the native macOS clip-view offset into SwiftUI. Unlike geometry
/// preferences, bounds notifications continue firing during live trackpad and
/// scrollbar scrolling.
struct GalleryScrollOffsetObserver: NSViewRepresentable {
    let onOffsetChange: (CGFloat) -> Void

    func makeNSView(context: Context) -> GalleryScrollObservationView {
        let view = GalleryScrollObservationView()
        view.onOffsetChange = onOffsetChange
        return view
    }

    func updateNSView(_ nsView: GalleryScrollObservationView, context: Context) {
        nsView.onOffsetChange = onOffsetChange
        nsView.connectToEnclosingScrollView()
    }

    static func dismantleNSView(_ nsView: GalleryScrollObservationView, coordinator: ()) {
        nsView.disconnect()
    }
}

final class GalleryScrollObservationView: NSView {
    var onOffsetChange: ((CGFloat) -> Void)?

    private weak var observedScrollView: NSScrollView?
    private weak var observedClipView: NSClipView?
    private var boundsObservation: NSObjectProtocol?
    private var scrollWheelMonitor: Any?
    private var isConnectionScheduled = false

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        connectToEnclosingScrollView()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            removeScrollWheelMonitor()
        } else {
            connectToEnclosingScrollView()
        }
    }

    func connectToEnclosingScrollView() {
        guard let scrollView = enclosingScrollView else {
            guard !isConnectionScheduled else { return }
            isConnectionScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isConnectionScheduled = false
                self.attachIfAvailable()
            }
            return
        }
        attach(to: scrollView)
    }

    private func attachIfAvailable() {
        guard let scrollView = enclosingScrollView else { return }
        attach(to: scrollView)
    }

    private func attach(to scrollView: NSScrollView) {
        let clipView = scrollView.contentView
        guard observedClipView !== clipView || observedScrollView !== scrollView else {
            installScrollWheelMonitorIfNeeded()
            publishOffset()
            return
        }

        disconnect()
        observedScrollView = scrollView
        observedClipView = clipView
        clipView.postsBoundsChangedNotifications = true
        boundsObservation = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            self?.publishOffset()
        }
        installScrollWheelMonitorIfNeeded()
        publishOffset()
    }

    private func installScrollWheelMonitorIfNeeded() {
        guard scrollWheelMonitor == nil else { return }
        scrollWheelMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.handleScrollWheel(event) else { return event }
            return nil
        }
    }

    private func removeScrollWheelMonitor() {
        if let scrollWheelMonitor {
            NSEvent.removeMonitor(scrollWheelMonitor)
        }
        scrollWheelMonitor = nil
    }

    @discardableResult
    func handleScrollWheel(_ event: NSEvent) -> Bool {
        guard let scrollView = observedScrollView,
              let window = scrollView.window,
              window.isVisible,
              event.window === window
        else {
            return false
        }

        let modifiers = event.modifierFlags.intersection([.command, .option, .control])
        guard modifiers.isEmpty else { return false }

        let pointInScrollView = scrollView.convert(event.locationInWindow, from: nil)
        guard scrollView.bounds.contains(pointInScrollView) else { return false }

        if let hitView = window.contentView?.hitTest(event.locationInWindow),
           let hitScrollView = hitView.enclosingScrollView,
           hitScrollView !== scrollView {
            return false
        }

        return scrollHorizontally(
            scrollingDeltaX: event.scrollingDeltaX,
            scrollingDeltaY: event.scrollingDeltaY,
            deltaY: event.deltaY,
            hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas
        )
    }

    @discardableResult
    func scrollHorizontally(
        scrollingDeltaX: CGFloat,
        scrollingDeltaY: CGFloat,
        deltaY: CGFloat = 0,
        hasPreciseScrollingDeltas: Bool
    ) -> Bool {
        guard let scrollView = observedScrollView,
              let clipView = observedClipView,
              let deltaX = GalleryScrollMetrics.horizontalScrollDelta(
                  scrollingDeltaX: scrollingDeltaX,
                  scrollingDeltaY: scrollingDeltaY,
                  deltaY: deltaY,
                  hasPreciseScrollingDeltas: hasPreciseScrollingDeltas,
                  lineScroll: scrollView.horizontalLineScroll
              )
        else {
            return false
        }

        let documentWidth = scrollView.documentView?.frame.width ?? 0
        let currentOrigin = clipView.bounds.origin
        let targetX = GalleryScrollMetrics.clampedHorizontalOffset(
            currentX: currentOrigin.x,
            deltaX: deltaX,
            documentWidth: documentWidth,
            visibleWidth: clipView.bounds.width
        )
        guard abs(targetX - currentOrigin.x) > 0.01 else {
            return true
        }
        clipView.scroll(to: NSPoint(x: targetX, y: currentOrigin.y))
        scrollView.reflectScrolledClipView(clipView)
        scrollView.flashScrollers()
        return true
    }

    func disconnect() {
        removeScrollWheelMonitor()
        if let boundsObservation {
            NotificationCenter.default.removeObserver(boundsObservation)
        }
        boundsObservation = nil
        observedScrollView = nil
        observedClipView = nil
    }

    private func publishOffset() {
        guard let observedClipView else { return }
        onOffsetChange?(observedClipView.bounds.origin.x)
    }

    deinit {
        disconnect()
    }
}
