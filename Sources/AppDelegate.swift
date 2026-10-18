import Cocoa
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private let settings = AppSettings.shared
    private let permission = PermissionMonitor.shared
    private let mover = NotificationMover()
    private let picker = PositionPicker()
    private var settingsWindow: NSWindow?
    private var onboardingWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = UpdateController.shared // starts Sparkle's scheduled update checks

        settings.$showMenuBarIcon
            .sink { [weak self] show in self?.setStatusItemVisible(show) }
            .store(in: &cancellables)

        permission.$isTrusted
            .sink { [weak self] trusted in if trusted { self?.mover.start() } }
            .store(in: &cancellables)

        if !settings.hasCompletedOnboarding || !permission.isTrusted {
            showOnboarding()
        }
    }

    /// Opening the app again (e.g. from Finder while the menu bar icon is hidden) shows Settings.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(.general)
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        mover.restoreAll()
    }

    // MARK: Status item

    private func setStatusItemVisible(_ visible: Bool) {
        if visible, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            let image = NSImage(systemSymbolName: "bell.badge.fill", accessibilityDescription: Brand.appName)
            image?.isTemplate = true
            item.button?.image = image
            let menu = NSMenu()
            menu.delegate = self
            item.menu = menu
            statusItem = item
        } else if !visible, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: Brand.appName, action: nil, keyEquivalent: "")
        header.attributedTitle = NSAttributedString(string: Brand.appName,
                                                    attributes: [.font: NSFont.boldSystemFont(ofSize: 13)])
        header.isEnabled = false
        menu.addItem(header)

        let status: String
        if !permission.isTrusted { status = "Needs Accessibility access" }
        else if settings.isEnabled { status = "Active · \(settings.placement.presetTitle)" }
        else { status = "Paused" }
        let statusItem = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(.separator())

        if !permission.isTrusted {
            menu.addItem(item("Grant Accessibility Access…", #selector(grantAccess)))
            menu.addItem(.separator())
        }

        let enabled = item("Move Notifications", #selector(toggleEnabled))
        enabled.state = settings.isEnabled ? .on : .off
        menu.addItem(enabled)

        let positionMenu = NSMenu()
        for (index, preset) in Placement.presets.enumerated() {
            let p = item(preset.title, #selector(choosePreset(_:)))
            p.tag = index
            p.state = settings.placement == preset.placement ? .on : .off
            positionMenu.addItem(p)
        }
        positionMenu.addItem(.separator())
        let custom = item("Place on Screen…", #selector(placeOnScreen))
        custom.state = settings.placement.presetTitle == "Custom" ? .on : .off
        positionMenu.addItem(custom)
        let position = NSMenuItem(title: "Position", action: nil, keyEquivalent: "")
        position.submenu = positionMenu
        menu.addItem(position)

        menu.addItem(item("Send Test Notification", #selector(sendTest), key: "t"))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", #selector(openSettings), key: ","))
        menu.addItem(item("Check for Updates…", #selector(checkForUpdates)))
        menu.addItem(item("About \(Brand.appName)", #selector(openAbout)))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit \(Brand.appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleEnabled() { settings.isEnabled.toggle() }
    @objc private func choosePreset(_ sender: NSMenuItem) { settings.placement = Placement.presets[sender.tag].placement }
    @objc private func sendTest() { TestNotification.send() }
    @objc private func grantAccess() { permission.request() }
    @objc private func openSettings() { showSettings(.general) }
    @objc private func openAbout() { showSettings(.about) }
    @objc private func checkForUpdates() { UpdateController.shared.checkForUpdates() }

    @objc private func placeOnScreen() {
        picker.show(current: settings.placement, margin: CGFloat(settings.margin)) { [weak self] placement in
            self?.settings.placement = placement
            TestNotification.send()
        }
    }

    // MARK: Windows

    private func showSettings(_ tab: SettingsTab) {
        settingsWindow?.close()
        let view = SettingsView(tab: tab, placeOnScreen: { [weak self] in self?.placeOnScreen() })
        let window = makeWindow(NSHostingView(rootView: view), title: "\(Brand.appName) Settings")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        settingsWindow = window
        present(window)
    }

    private func showOnboarding() {
        let view = OnboardingView { [weak self] in
            self?.onboardingWindow?.close()
        }
        let window = makeWindow(NSHostingView(rootView: view), title: "Welcome to \(Brand.appName)")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.styleMask.insert(.fullSizeContentView)
        onboardingWindow = window
        present(window)
    }

    private func makeWindow(_ content: NSView, title: String) -> NSWindow {
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: content.fittingSize),
                              styleMask: [.titled, .closable, .miniaturizable],
                              backing: .buffered, defer: false)
        window.title = title
        window.contentView = content
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        return window
    }

    /// Menu bar apps have no Dock icon; show one while a window is open so it behaves like a normal app.
    private func present(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let open = [self.settingsWindow, self.onboardingWindow].contains { $0?.isVisible == true }
            if !open { NSApp.setActivationPolicy(.accessory) }
        }
    }
}
