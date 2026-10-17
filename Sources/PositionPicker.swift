import Cocoa

/// A draggable, notification-shaped window. The user drags it where banners should appear,
/// then clicks "Save".
final class PositionPicker: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var onSave: ((Placement) -> Void)?
    private var margin: CGFloat = 16

    static let bannerSize = CGSize(width: 344, height: 72)

    func show(current: Placement, margin: CGFloat, onSave: @escaping (Placement) -> Void) {
        self.margin = margin
        self.onSave = onSave
        panel?.close()

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let size = Self.bannerSize
        let axOrigin = current.origin(for: size, in: screen.axVisibleFrame, margin: margin)
        let cocoaOrigin = CGPoint(x: axOrigin.x, y: NSScreen.primaryHeight - axOrigin.y - size.height)

        let panel = NSPanel(contentRect: CGRect(origin: cocoaOrigin, size: size),
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isMovableByWindowBackground = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self

        let blur = NSVisualEffectView(frame: CGRect(origin: .zero, size: size))
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 18
        blur.layer?.masksToBounds = true
        blur.layer?.borderWidth = 2
        blur.layer?.borderColor = NSColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1).cgColor

        let icon = NSImageView(image: NSImage(systemSymbolName: "hand.draw", accessibilityDescription: nil)!)
        icon.symbolConfiguration = .init(pointSize: 22, weight: .regular)
        icon.contentTintColor = NSColor(red: 0.486, green: 0.227, blue: 0.929, alpha: 1)
        icon.frame = CGRect(x: 14, y: 22, width: 30, height: 30)

        let title = NSTextField(labelWithString: "Drag me anywhere")
        title.font = .boldSystemFont(ofSize: 13)
        title.frame = CGRect(x: 54, y: 38, width: 170, height: 18)
        let subtitle = NSTextField(labelWithString: "Notifications will appear here")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.frame = CGRect(x: 54, y: 18, width: 190, height: 16)

        let save = NSButton(title: "Save", target: self, action: #selector(savePressed))
        save.bezelStyle = .rounded
        save.keyEquivalent = "\r"
        save.frame = CGRect(x: 262, y: 36, width: 70, height: 26)
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancel.bezelStyle = .rounded
        cancel.frame = CGRect(x: 262, y: 10, width: 70, height: 26)

        [icon, title, subtitle, save, cancel].forEach { blur.addSubview($0) }
        panel.contentView = blur
        panel.orderFrontRegardless()
        panel.makeKey()
        self.panel = panel
    }

    @objc private func savePressed() {
        guard let panel else { return }
        let frame = panel.frame
        let screen = panel.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let axOrigin = CGPoint(x: frame.minX, y: NSScreen.primaryHeight - frame.maxY)
        onSave?(Placement.from(origin: axOrigin, size: frame.size, in: screen.axVisibleFrame, margin: margin))
        close()
    }

    @objc private func cancelPressed() { close() }

    private func close() {
        panel?.orderOut(nil)
        panel = nil
        onSave = nil
    }
}
