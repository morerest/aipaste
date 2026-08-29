import AppKit
import SwiftUI

enum GalleryScrollMetrics {
    static let threshold: CGFloat = 70

    static func shouldShowBackToLatest(leadingX: CGFloat, hasResults: Bool) -> Bool {
        hasResults && leadingX < -threshold
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

    private weak var observedClipView: NSClipView?
    private var boundsObservation: NSObjectProtocol?
    private var isConnectionScheduled = false

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        connectToEnclosingScrollView()
    }

    func connectToEnclosingScrollView() {
        guard let clipView = enclosingScrollView?.contentView else {
            guard !isConnectionScheduled else { return }
            isConnectionScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isConnectionScheduled = false
                self.attachIfAvailable()
            }
            return
        }
        attach(to: clipView)
    }

    private func attachIfAvailable() {
        guard let clipView = enclosingScrollView?.contentView else { return }
        attach(to: clipView)
    }

    private func attach(to clipView: NSClipView) {
        guard observedClipView !== clipView else {
            publishOffset()
            return
        }

        disconnect()
        observedClipView = clipView
        clipView.postsBoundsChangedNotifications = true
        boundsObservation = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            self?.publishOffset()
        }
        publishOffset()
    }

    func disconnect() {
        if let boundsObservation {
            NotificationCenter.default.removeObserver(boundsObservation)
        }
        boundsObservation = nil
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
