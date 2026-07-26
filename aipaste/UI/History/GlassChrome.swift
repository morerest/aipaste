import AppKit
import SwiftUI

/// Real macOS vibrancy behind SwiftUI content (blurs desktop / apps under the panel).
struct VibrancyBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    var emphasized: Bool = true

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.isEmphasized = emphasized
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
        nsView.isEmphasized = emphasized
    }
}

/// Floating workbench shell: vibrancy frost + light glass veil + edge highlight.
struct WorkbenchGlassBackground: View {
    var cornerRadius: CGFloat = 24

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            // System blur of whatever sits under the panel (slightly more open than hudWindow).
            VibrancyBackground(material: .popover, blendingMode: .behindWindow)
                .clipShape(shape)

            // Extra SwiftUI frost so the surface reads as matte glass, not bare blur.
            shape.fill(.ultraThinMaterial)

            // Very light depth wash — keep glass open without a heavy grey slab.
            shape.fill(
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.02),
                        Color.primary.opacity(0.01),
                        Color.primary.opacity(0.025),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            // Specular glass edge (light top, quieter bottom).
            shape.strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.38),
                        Color.white.opacity(0.08),
                        Color.primary.opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
            .blendMode(.plusLighter)
            .opacity(0.8)

            shape.strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
        }
        .compositingGroup()
    }
}
