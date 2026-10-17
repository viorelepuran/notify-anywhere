import SwiftUI

/// A miniature of the main display. The notification can be dragged anywhere; it snaps to edges and centers.
struct ScreenPreview: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var dragStart: CGPoint?
    @State private var isDragging = false

    private static let bannerSize = CGSize(width: 344, height: 64)

    private var screen: NSScreen { NSScreen.main ?? NSScreen.screens[0] }

    var body: some View {
        let frame = screen.axFrame
        GeometryReader { geo in
            let scale = geo.size.width / frame.width
            let visible = screen.axVisibleFrame.offsetBy(dx: -frame.minX, dy: -frame.minY)
            let area = CGRect(x: visible.minX * scale, y: visible.minY * scale,
                              width: visible.width * scale, height: visible.height * scale)
            let banner = CGSize(width: Self.bannerSize.width * scale, height: Self.bannerSize.height * scale)
            let margin = CGFloat(settings.margin) * scale
            let origin = settings.placement.origin(for: banner, in: area, margin: margin)
            let ghost = Placement(fx: 1, fy: 0).origin(for: banner, in: area, margin: 16 * scale)

            ZStack(alignment: .topLeading) {
                Brand.backdrop
                RadialGradient(colors: [Brand.pink.opacity(0.35), .clear], center: .bottomLeading,
                               startRadius: 0, endRadius: geo.size.width * 0.6)

                // Menu bar
                Rectangle().fill(.black.opacity(0.35)).frame(height: max(area.minY, 6))
                HStack(spacing: 6) {
                    Image(systemName: "apple.logo").font(.system(size: 8))
                    ForEach(0..<4, id: \.self) { _ in Capsule().fill(.white.opacity(0.5)).frame(width: 18, height: 3) }
                    Spacer()
                    ForEach(0..<3, id: \.self) { _ in Circle().fill(.white.opacity(0.5)).frame(width: 4, height: 4) }
                }
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .frame(height: max(area.minY, 6))

                // Dock
                if geo.size.height - area.maxY > 4 {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.white.opacity(0.18))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.25), lineWidth: 0.5))
                        .frame(width: geo.size.width * 0.55, height: max(4, geo.size.height - area.maxY - 4))
                        .offset(x: geo.size.width * 0.225, y: area.maxY + 2)
                }

                // Where macOS would put it
                RoundedRectangle(cornerRadius: banner.height * 0.28)
                    .strokeBorder(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .frame(width: banner.width, height: banner.height)
                    .offset(x: ghost.x, y: ghost.y)
                    .opacity(settings.placement == Placement(fx: 1, fy: 0) ? 0 : 1)

                MiniBanner(height: banner.height)
                    .frame(width: banner.width, height: banner.height)
                    .scaleEffect(isDragging ? 1.06 : 1)
                    .shadow(color: .black.opacity(isDragging ? 0.45 : 0.3), radius: isDragging ? 10 : 5, y: 3)
                    .offset(x: origin.x, y: origin.y)
                    .animation(isDragging ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: settings.placement)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if dragStart == nil { dragStart = origin; isDragging = true }
                                let p = CGPoint(x: dragStart!.x + value.translation.width,
                                                y: dragStart!.y + value.translation.height)
                                settings.placement = Placement.from(origin: p, size: banner, in: area, margin: margin).snapped()
                            }
                            .onEnded { _ in dragStart = nil; isDragging = false }
                    )
                    .onHover { inside in if inside { NSCursor.openHand.push() } else { NSCursor.pop() } }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .aspectRatio(frame.width / frame.height, contentMode: .fit)
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(white: 0.12)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.08)))
        .accessibilityLabel("Screen preview. Notification position: \(settings.placement.presetTitle)")
    }
}

/// The small notification card used in previews.
struct MiniBanner: View {
    let height: CGFloat

    var body: some View {
        HStack(spacing: height * 0.18) {
            RoundedRectangle(cornerRadius: height * 0.14)
                .fill(Brand.gradient)
                .frame(width: height * 0.52, height: height * 0.52)
            VStack(alignment: .leading, spacing: height * 0.1) {
                Capsule().fill(Color(white: 0.15)).frame(height: height * 0.13)
                Capsule().fill(Color(white: 0.6)).frame(width: height * 1.6, height: height * 0.11)
            }
        }
        .padding(.horizontal, height * 0.22)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: height * 0.28).fill(.white.opacity(0.95)))
    }
}

/// 3×3 grid of preset positions.
struct PresetGrid: View {
    @ObservedObject var settings = AppSettings.shared
    var cell: CGFloat = 26

    var body: some View {
        VStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { col in
                        let preset = Placement.presets[row * 3 + col]
                        let selected = settings.placement == preset.placement
                        Button {
                            settings.placement = preset.placement
                        } label: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selected ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.primary.opacity(0.08)))
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .stroke(selected ? .clear : Color.primary.opacity(0.12)))
                                .overlay(Capsule().fill(selected ? .white : Color.primary.opacity(0.35))
                                    .frame(width: cell * 0.5, height: 3))
                                .frame(width: cell * 1.4, height: cell)
                        }
                        .buttonStyle(.plain)
                        .help(preset.title)
                        .accessibilityLabel(preset.title)
                    }
                }
            }
        }
    }
}
