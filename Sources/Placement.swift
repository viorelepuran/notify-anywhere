import Cocoa

/// Where notification banners should appear, expressed as fractions of the usable screen area.
/// (0, 0) is top-left, (1, 1) is bottom-right.
struct Placement: Equatable {
    var fx: CGFloat
    var fy: CGFloat

    struct Preset {
        let title: String
        let placement: Placement
    }

    /// Row-major 3×3 grid, top-left first.
    static let presets: [Preset] = [
        Preset(title: "Top Left", placement: Placement(fx: 0, fy: 0)),
        Preset(title: "Top Center", placement: Placement(fx: 0.5, fy: 0)),
        Preset(title: "Top Right", placement: Placement(fx: 1, fy: 0)),
        Preset(title: "Middle Left", placement: Placement(fx: 0, fy: 0.5)),
        Preset(title: "Center", placement: Placement(fx: 0.5, fy: 0.5)),
        Preset(title: "Middle Right", placement: Placement(fx: 1, fy: 0.5)),
        Preset(title: "Bottom Left", placement: Placement(fx: 0, fy: 1)),
        Preset(title: "Bottom Center", placement: Placement(fx: 0.5, fy: 1)),
        Preset(title: "Bottom Right", placement: Placement(fx: 1, fy: 1)),
    ]

    var presetTitle: String {
        Placement.presets.first { $0.placement == self }?.title ?? "Custom"
    }

    /// Top-left origin for a box of `size` inside `area`, keeping `margin` from the edges.
    /// Works in any coordinate space with a top-left origin.
    func origin(for size: CGSize, in area: CGRect, margin: CGFloat) -> CGPoint {
        let freeW = max(0, area.width - 2 * margin - size.width)
        let freeH = max(0, area.height - 2 * margin - size.height)
        return CGPoint(x: (area.minX + margin + fx * freeW).rounded(),
                       y: (area.minY + margin + fy * freeH).rounded())
    }

    /// Inverse of `origin(for:in:margin:)`.
    static func from(origin: CGPoint, size: CGSize, in area: CGRect, margin: CGFloat) -> Placement {
        let freeW = area.width - 2 * margin - size.width
        let freeH = area.height - 2 * margin - size.height
        let fx = freeW > 0 ? (origin.x - area.minX - margin) / freeW : 0.5
        let fy = freeH > 0 ? (origin.y - area.minY - margin) / freeH : 0.5
        return Placement(fx: min(1, max(0, fx)), fy: min(1, max(0, fy)))
    }

    /// Snaps to a preset when close enough, so dragging lands cleanly on edges and centers.
    func snapped(threshold: CGFloat = 0.04) -> Placement {
        func snap(_ v: CGFloat) -> CGFloat {
            for s in [0, 0.5, 1] as [CGFloat] where abs(v - s) < threshold { return s }
            return v
        }
        return Placement(fx: snap(fx), fy: snap(fy))
    }
}

extension NSScreen {
    /// Height of the primary screen; used to flip between Cocoa (bottom-left) and AX (top-left) coordinates.
    static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

    /// The frame in top-left-origin (Accessibility) coordinates.
    var axFrame: CGRect { Self.toAX(frame) }
    /// The usable area (excluding menu bar and Dock) in top-left-origin coordinates.
    var axVisibleFrame: CGRect { Self.toAX(visibleFrame) }

    static func toAX(_ r: CGRect) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }
}
