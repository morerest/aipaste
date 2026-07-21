import AppKit
import SwiftUI

@MainActor
final class HistoryPanelController: NSObject {
    private var panel: NSPanel?
    private var model: HistoryViewModel?

    func configure(store: SnippetStore, pasteEngine: PasteEngine) {
        model = HistoryViewModel(store: store, pasteEngine: pasteEngine)
    }

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard let model else { return }
        model.reload()
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 360),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.title = "clipai"
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            let root = HistoryView(
                model: model,
                onClose: { [weak self] in self?.hide() },
                onPasteAndClose: { [weak self] in
                    // Spec: hide panel first so ⌘V targets the previous app, not clipai.
                    self?.pasteSelectedThenHide()
                }
            )
            panel.contentViewController = NSHostingController(rootView: root)
            self.panel = panel
        }
        if let screen = NSScreen.main, let panel {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            let origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2
            )
            panel.setFrameOrigin(origin)
        }
        // Become key so search / Enter / Esc work without an extra click.
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    /// Hide first, yield to the previous app, then paste (write + optional ⌘V).
    private func pasteSelectedThenHide() {
        guard let model else { return }
        hide()
        // Delay lets the previously focused app reclaim first responder before ⌘V.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            model.pasteSelected()
            if let message = model.statusMessage, message.contains("Accessibility") {
                // Keep guidance visible when auto-paste is unavailable.
                let alert = NSAlert()
                alert.messageText = "clipai"
                alert.informativeText = message
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

    func reloadIfVisible() {
        guard panel?.isVisible == true else { return }
        model?.reload()
    }
}
