import Cocoa
import ApplicationServices

/// Watches the Notification Center process and moves its banner windows so banners land
/// at the user's chosen placement.
///
/// Notification Center (`com.apple.notificationcenterui`) has drawn banners in two layouts:
/// - macOS 26 and later: every banner is a view inside one persistent, screen-sized
///   "AXSystemDialog" window, which also hosts the Notification Center panel.
/// - macOS 14 and 15: a window per banner, created when the banner appears.
/// Desktop widgets are Notification Center windows too, so only windows that contain a banner
/// are touched. Either way we never move the banner view itself (its position is read-only);
/// we shift the window that holds it. All banner windows share one offset, so banners that macOS
/// stacks as separate windows keep their stacking.
final class NotificationMover {
    static let ncBundleID = "com.apple.notificationcenterui"
    private static let bannerSubroles: Set<String> = [
        "AXNotificationCenterBanner", "AXNotificationCenterBannerStack",
        "AXNotificationCenterAlert", "AXNotificationCenterAlertStack",
    ]
    /// Identifiers only the open Notification Center panel has. Unlike labels such as "Clear All",
    /// identifiers are not localized.
    private static let panelIdentifiers: Set<String> = ["widget-editor-button"]
    /// Widgets carry identifiers like "widget-local:com.apple.iCal:…". A window holding both a
    /// widget and a banner is the panel (which lists both), not a banner.
    private static let widgetIdentifierPrefix = "widget-local:"

    private let settings = AppSettings.shared

    private var observer: AXObserver?
    private var ncPid: pid_t = 0
    private var timer: Timer?

    private struct Moved {
        let window: AXUIElement
        /// Where macOS had the window before we moved it.
        var home: CGPoint
        /// Where we last put it. If the window is somewhere else, macOS moved it, which makes that
        /// its new home (per-banner windows get re-laid out as banners come and go).
        var placed: CGPoint
    }
    /// Windows we have moved, keyed by CFHash of the element.
    private var moved: [Int: Moved] = [:]

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
        for entry in moved.values { setPosition(entry.window, entry.home) }
        moved.removeAll()
    }

    // MARK: Observer

    private func attachIfNeeded() {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: Self.ncBundleID).first else { return }
        if app.processIdentifier == ncPid, observer != nil { return }

        if let old = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(old), .defaultMode)
        }
        observer = nil
        moved.removeAll()
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

    private struct BannerWindow {
        let window: AXUIElement
        let key: Int
        let position: CGPoint
        /// Banner frames, in screen coordinates as they are now.
        let banners: [CGRect]
    }

    func refresh() {
        guard ncPid != 0, AXIsProcessTrusted() else { return }
        let appElement = AXUIElementCreateApplication(ncPid)
        guard let windows: [AXUIElement] = attribute(appElement, kAXWindowsAttribute) else { return }

        // Notification Center reports the panel (opened from the menu bar clock) as AXExpanded on
        // its application element (seen on macOS 27; older releases may not have it, hence the
        // per-window markers below as well).
        var panelOpen = (attribute(appElement, "AXExpanded") as Bool?) == true

        var bannerWindows: [BannerWindow] = []
        /// Screen-sized windows holding banners or the panel, and where each belongs.
        var hosts: [(window: AXUIElement, home: CGPoint)] = []
        var present = Set<Int>()
        for window in windows {
            let key = Int(CFHash(window))
            present.insert(key)
            var scan = Scan()
            scan.walk(window, depth: 0)
            if scan.panel || (scan.widget && !scan.banners.isEmpty) { panelOpen = true }
            if scan.panel || !scan.banners.isEmpty, let home = screenOrigin(forWindowOfSize: size(window)) {
                hosts.append((window, home))
            }
            guard !scan.banners.isEmpty, let pos = position(window) else { continue }
            let frames = scan.banners.compactMap { b -> CGRect? in
                guard let p = position(b), let s = size(b), s.width > 0, s.height > 0 else { return nil }
                return CGRect(origin: p, size: s)
            }
            if !frames.isEmpty { bannerWindows.append(BannerWindow(window: window, key: key, position: pos, banners: frames)) }
        }
        // Windows that went away (per-banner windows are destroyed with their banner).
        moved = moved.filter { present.contains($0.key) }

        // Panel open, disabled, or nothing showing: put windows back where macOS expects them, so
        // the panel (which opens inside the banner window on macOS 15 and later) isn't displaced.
        guard settings.isEnabled, !panelOpen, !bannerWindows.isEmpty else {
            if !settings.isEnabled || panelOpen {
                restoreAll()
                for host in hosts where position(host.window).map({ distance($0, host.home) >= 1 }) ?? false {
                    setPosition(host.window, host.home)
                }
            }
            return
        }

        // Each window's home: where macOS put it. A screen-sized window belongs at the origin of
        // that screen (macOS keeps it wherever it was last put, even after a crash of ours). For
        // other windows, adopt the current position if we never moved it, or if macOS moved it
        // since we did.
        var homes: [Int: CGPoint] = [:]
        for bw in bannerWindows {
            if let screenHome = screenOrigin(forWindowOfSize: size(bw.window)) {
                homes[bw.key] = screenHome
            } else if let entry = moved[bw.key], distance(entry.placed, bw.position) < 1 {
                homes[bw.key] = entry.home
            } else {
                homes[bw.key] = bw.position
                moved[bw.key] = nil
            }
        }

        // Union of all banners as they would be with every window at home (stacked notifications
        // move together).
        var union = CGRect.null
        for bw in bannerWindows {
            let home = homes[bw.key]!
            for f in bw.banners {
                union = union.union(f.offsetBy(dx: home.x - bw.position.x, dy: home.y - bw.position.y))
            }
        }
        guard !union.isNull else { return }

        // The screen macOS showed the banners on.
        let center = CGPoint(x: union.midX, y: union.midY)
        let screen = NSScreen.screens.first { $0.axFrame.contains(center) } ?? NSScreen.screens.first
        guard let area = screen?.axVisibleFrame else { return }

        let target = settings.placement.origin(for: union.size, in: area, margin: CGFloat(settings.margin))
        let dx = target.x - union.minX, dy = target.y - union.minY

        for bw in bannerWindows {
            let home = homes[bw.key]!
            let destination = CGPoint(x: home.x + dx, y: home.y + dy)
            if distance(destination, bw.position) >= 1 { setPosition(bw.window, destination) }
            if distance(destination, home) >= 1 {
                moved[bw.key] = Moved(window: bw.window, home: home, placed: position(bw.window) ?? destination)
            }
        }
    }

    /// One pass over a window's accessibility tree.
    private struct Scan {
        var banners: [AXUIElement] = []
        /// Something only the full Notification Center panel has.
        var panel = false
        var widget = false

        mutating func walk(_ element: AXUIElement, depth: Int) {
            if let subrole: String = attr(element, kAXSubroleAttribute), NotificationMover.bannerSubroles.contains(subrole) {
                banners.append(element)
                return
            }
            if let id: String = attr(element, kAXIdentifierAttribute) {
                if NotificationMover.panelIdentifiers.contains(id) { panel = true }
                if id.hasPrefix(NotificationMover.widgetIdentifierPrefix) { widget = true }
            }
            // The panel's "Notification Center" title is a heading; banners have none.
            if (attr(element, kAXRoleAttribute) as String?) == "AXHeading" { panel = true }
            guard depth < 8, let children: [AXUIElement] = attr(element, kAXChildrenAttribute) else { return }
            for child in children { walk(child, depth: depth + 1) }
        }

        private func attr<T>(_ element: AXUIElement, _ name: String) -> T? {
            var value: AnyObject?
            guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
            return value as? T
        }
    }

    // MARK: AX helpers

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { max(abs(a.x - b.x), abs(a.y - b.y)) }

    /// The top-left of the screen a window of this size covers, preferring the main display
    /// (where macOS shows banners).
    private func screenOrigin(forWindowOfSize size: CGSize?) -> CGPoint? {
        guard let size else { return nil }
        let matches = NSScreen.screens.filter { distance(CGPoint(x: $0.frame.width, y: $0.frame.height),
                                                         CGPoint(x: size.width, y: size.height)) < 1 }
        return matches.first?.axFrame.origin
    }

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
