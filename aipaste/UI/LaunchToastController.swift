import AppKit
import QuartzCore
import SwiftUI

/// Short non-modal HUD after a successful cold start so menu-bar-only launch
/// still feels intentional (no Dock icon, easy to miss).
@MainActor
final class LaunchToastController {
    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?

    /// Show near the status item when possible; auto-dismiss after a few seconds.
    func show(
        hotKeyDisplay: String,
        theme: WorkbenchTheme,
        anchorScreenFrame: NSRect?
    ) {
        dismiss(animated: false)

        let strings = L10n.workbench
        let root = LaunchToastView(
            title: strings.launchReadyTitle,
            detail: strings.launchReadyDetail(hotKeyDisplay: hotKeyDisplay),
            theme: theme
        )
        let hosting = NSHostingController(rootView: root)
        hosting.view.wantsLayer = true
        hosting.view.layer?.backgroundColor = NSColor.clear.cgColor

        // Size from fitting content; fall back if layout has not run yet.
        hosting.view.layoutSubtreeIfNeeded()
        var size = hosting.view.fittingSize
        if size.width < 40 || size.height < 20 {
            size = NSSize(width: 320, height: 72)
        }
        size.width = min(max(size.width, 280), 420)
        size.height = min(max(size.height, 64), 100)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentViewController = hosting
        panel.setContentSize(size)
        panel.setFrameOrigin(Self.origin(for: size, anchor: anchorScreenFrame))
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        self.panel = panel

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        let work = DispatchWorkItem { [weak self] in
            self?.dismiss(animated: true)
        }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    func dismiss(animated: Bool) {
        dismissWork?.cancel()
        dismissWork = nil
        guard let panel else { return }
        self.panel = nil
        if animated {
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        } else {
            panel.orderOut(nil)
        }
    }

    /// Prefer just under the menu-bar icon; otherwise top-center of the main screen.
    private static func origin(for size: NSSize, anchor: NSRect?) -> NSPoint {
        if let anchor, anchor.width > 0 {
            let x = anchor.midX - size.width / 2
            let y = anchor.minY - size.height - 10
            if let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) })
                ?? NSScreen.main
            {
                let vis = screen.visibleFrame
                return NSPoint(
                    x: min(max(x, vis.minX + 8), vis.maxX - size.width - 8),
                    y: min(max(y, vis.minY + 8), vis.maxY - size.height - 8)
                )
            }
            return NSPoint(x: x, y: y)
        }

        let screen = NSScreen.main ?? NSScreen.screens.first
        let vis = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        return NSPoint(
            x: vis.midX - size.width / 2,
            y: vis.maxY - size.height - 12
        )
    }
}

// MARK: - SwiftUI content

private struct LaunchToastView: View {
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let title: String
    let detail: String
    let theme: WorkbenchTheme

    private var style: WorkbenchThemeStyle { theme.style }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(style.usesSystemGlass ? Color.primary : style.primaryText)
                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(style.usesSystemGlass ? Color.secondary : style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minWidth: 280, idealWidth: 320, maxWidth: 400)
        .background { toastBackground }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
        .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
        .padding(4)
        .environment(\.colorScheme, style.interfaceColorScheme ?? systemColorScheme)
    }

    @ViewBuilder
    private var toastBackground: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if style.usesSystemGlass {
            if reduceTransparency {
                shape.fill(Color(nsColor: .windowBackgroundColor))
            } else {
                ZStack {
                    VibrancyBackground(material: .hudWindow, blendingMode: .behindWindow)
                    shape.fill(.ultraThinMaterial)
                    shape.fill(Color.primary.opacity(0.03))
                }
            }
        } else {
            ZStack {
                shape.fill(style.opaquePanelColor)
                shape.fill(style.panelGradient.opacity(style.panelGradientOpacity * 0.7))
            }
        }
    }

    private var borderColor: Color {
        style.usesSystemGlass
            ? Color.primary.opacity(0.10)
            : style.borderColor
    }
}
