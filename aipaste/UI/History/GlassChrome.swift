import AppKit
import SwiftUI

/// Keeps the normal theme geometry intact while giving macOS Increase Contrast
/// a consistent, visible effect across panel, control, preview, and card outlines.
func workbenchOutlineWidth(_ baseWidth: CGFloat, increaseContrast: Bool) -> CGFloat {
    increaseContrast ? baseWidth + 0.5 : baseWidth
}

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
    let style: WorkbenchThemeStyle
    let reduceTransparency: Bool
    let increaseContrast: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: style.panelCornerRadius, style: .continuous)

        if reduceTransparency {
            shape
                .fill(style.opaquePanelColor)
                .overlay {
                    shape.strokeBorder(outerBorderColor, lineWidth: outerBorderWidth)
                }
        } else if style.usesSystemGlass {
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

                shape.strokeBorder(outerBorderColor, lineWidth: outerBorderWidth)
            }
            .compositingGroup()
        } else {
            ZStack {
                VibrancyBackground(material: .popover, blendingMode: .behindWindow)
                    .clipShape(shape)

                // Fixed themes need a deterministic backing before their translucent
                // gradient so normal-sized chrome text cannot inherit desktop contrast.
                shape.fill(style.opaquePanelColor)

                shape.fill(style.panelGradient.opacity(style.panelGradientOpacity))

                shape.strokeBorder(outerBorderColor, lineWidth: outerBorderWidth)
            }
            .compositingGroup()
        }
    }

    private var outerBorderColor: Color {
        if increaseContrast {
            return style.primaryText.opacity(0.20)
        }
        if style.usesSystemGlass {
            return Color.primary.opacity(0.06)
        }
        return style.borderColor
    }

    private var outerBorderWidth: CGFloat {
        workbenchOutlineWidth(
            style.usesSystemGlass ? 0.5 : 1,
            increaseContrast: increaseContrast
        )
    }
}
