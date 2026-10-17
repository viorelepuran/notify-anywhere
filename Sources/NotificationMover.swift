import Cocoa
import ApplicationServices

/// Watches the Notification Center process and moves its banner window so banners land
/// at the user's chosen placement.
///
/// On current macOS the banners live inside a screen-sized "AXSystemDialog" window owned by
/// `com.apple.notificationcenterui`. We find the banner elements inside it, compute where they
/// should be, and shift the whole window by the difference.
final class NotificationMover {
    static let ncBundleID = "com.apple.notificationcenterui"
    private static let bannerSubroles: Set<String> = [
        "AXNotificationCenterBanner", "AXNotificationCenterBannerStack", "AXNotificationCenterAlert",
    ]

    private let settings = AppSettings.shared

    private var observer: AXObserver?
    private var ncPid: pid_t = 0
    private var timer: Timer?
    /// Original (untouched) origin of each window we have moved, keyed by CFHash of the element.
    private var homeOrigins: [Int: (window: AXUIElement, origin: CGPoint)] = [:]

    func start() {
        guard timer == nil else { return }
        attachIfNeeded()
        // Fallback poll: cheap, catches stacking/resize changes and Notification Center restarts.
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.attachIfNeeded()
            self?.refresh()
        }
    }

    /// Put every window back where macOS had it. Called on quit / disable.
    func restoreAll() {
        for (_, entry) in homeOrigins { setPosition(entry.window, entry.origin) }
        homeOrigins.removeAll()
    }

    // MARK: Observer

    private func attachIfNeeded() {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: Self.ncBundleID).first else { return }
        if app.processIdentifier == ncPid, observer != nil { return }

        if let old = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(old), .defaultMode)
        }
        observer = nil
        homeOrigins.removeAll()
        ncPid = app.processIdentifier

        let callback: AXObserverCallback = { _, _, _, refcon in
            guard let refcon else { return }
            let mover = Unmanaged<NotificationMover>.fromOpaque(refcon).takeUnretainedValue()
            mover.refreshSoon()
        }
        var obs: AXObserver?
        guard AXObserverCreate(ncPid, callback, &obs) == .success, let obs else { return }
        let appElement = AXUIElementCreateApplication(ncPid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in [kAXWindowCreatedNotification, kAXCreatedNotification, kAXUIElementDestroyedNotification,
                     kAXLayoutChangedNotification, kAXWindowResizedNotification, kAXWindowMovedNotification] {
            AXObserverAddNotification(obs, appElement, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        observer = obs
    }

    /// Banners animate in, so re-check a few times right after an event.
    private func refreshSoon() {
        refresh()
        for delay in [0.03, 0.1, 0.25] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.refresh() }
        }
    }

    // MARK: Moving

    func refresh() {
        guard ncPid != 0, AXIsProcessTrusted() else { return }
        let appElement = AXUIElementCreateApplication(ncPid)
        guard let windows: [AXUIElement] = attribute(appElement, kAXWindowsAttribute) else { return }
        for window in windows where (attribute(window, kAXSubroleAttribute) as String?) == "AXSystemDialog" {
            update(window)
        }
    }

    private func update(_ window: AXUIElement) {
        let key = Int(CFHash(window))
        guard let windowPos = position(window) else { return }

        var banners: [AXUIElement] = []
        let panelOpen = collectBanners(in: window, depth: 0, into: &banners)

        // Notification Center panel is open (or disabled / nothing showing): leave the window where
        // macOS expects it so the panel itself is not displaced.
        guard settings.isEnabled, !panelOpen, !banners.isEmpty else {
            if (!settings.isEnabled || panelOpen), let home = homeOrigins[key] {
                setPosition(window, home.origin)
                homeOrigins[key] = nil
            }
            return
        }

        if homeOrigins[key] == nil { homeOrigins[key] = (window, windowPos) }
        let home = homeOrigins[key]!.origin

        // Union of all visible banners (stacked notifications move together).
        var union = CGRect.null
        for b in banners {
            if let p = position(b), let s = size(b), s.width > 0, s.height > 0 {
                union = union.union(CGRect(origin: p, size: s))
            }
        }
        guard !union.isNull else { return }

        // Pick the screen the banner would be on if the window were at home.
        let unmovedCenter = CGPoint(x: union.midX - (windowPos.x - home.x), y: union.midY - (windowPos.y - home.y))
        let screen = NSScreen.screens.first { $0.axFrame.contains(unmovedCenter) } ?? NSScreen.screens.first
        guard let area = screen?.axVisibleFrame else { return }

        let target = settings.placement.origin(for: union.size, in: area, margin: CGFloat(settings.margin))
        let dx = target.x - union.minX, dy = target.y - union.minY
        guard abs(dx) >= 1 || abs(dy) >= 1 else { return }
        setPosition(window, CGPoint(x: windowPos.x + dx, y: windowPos.y + dy))
    }

    /// Collects banner elements. Returns true if this looks like the full Notification Center panel
    /// (the history list that opens from the menu bar clock) rather than transient banners.
    private func collectBanners(in element: AXUIElement, depth: Int, into result: inout [AXUIElement]) -> Bool {
        if let subrole: String = attribute(element, kAXSubroleAttribute), Self.bannerSubroles.contains(subrole) {
            result.append(element)
            return false
        }
        // The full panel has a "Notification Centre" heading and a "Clear All" button; banners have neither.
        if let role: String = attribute(element, kAXRoleAttribute) {
            if role == "AXHeading" { return true }
            if role == kAXButtonRole as String, let desc: String = attribute(element, kAXDescriptionAttribute),
               desc == "Clear All" { return true }
        }
        guard depth < 8, let children: [AXUIElement] = attribute(element, kAXChildrenAttribute) else { return false }
        var panel = false
        for child in children where collectBanners(in: child, depth: depth + 1, into: &result) { panel = true }
        return panel
    }

    // MARK: AX helpers

    private func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private func position(_ element: AXUIElement) -> CGPoint? {
        guard let value: AXValue = attribute(element, kAXPositionAttribute) else { return nil }
        var point = CGPoint.zero
        return AXValueGetValue(value, .cgPoint, &point) ? point : nil
    }

    private func size(_ element: AXUIElement) -> CGSize? {
        guard let value: AXValue = attribute(element, kAXSizeAttribute) else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(value, .cgSize, &size) ? size : nil
    }

    private func setPosition(_ element: AXUIElement, _ point: CGPoint) {
        var p = point
        guard let value = AXValueCreate(.cgPoint, &p) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, value)
    }
}
