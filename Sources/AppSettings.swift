import Cocoa
import ServiceManagement

/// User preferences, persisted in UserDefaults and observed by the UI.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    @Published var placement: Placement {
        didSet {
            defaults.set(Double(placement.fx), forKey: "placementFX")
            defaults.set(Double(placement.fy), forKey: "placementFY")
        }
    }
    /// Distance from the screen edges, in points.
    @Published var margin: Double { didSet { defaults.set(margin, forKey: "margin") } }
    @Published var isEnabled: Bool { didSet { defaults.set(isEnabled, forKey: "enabled") } }
    @Published var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon") } }
    @Published var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: "onboarded") } }
    @Published private(set) var launchAtLogin: Bool

    private init() {
        if defaults.object(forKey: "placementFX") != nil {
            placement = Placement(fx: CGFloat(defaults.double(forKey: "placementFX")),
                                  fy: CGFloat(defaults.double(forKey: "placementFY")))
        } else {
            placement = Placement(fx: 1, fy: 1)
        }
        margin = defaults.object(forKey: "margin") as? Double ?? 16
        isEnabled = defaults.object(forKey: "enabled") as? Bool ?? true
        showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true
        hasCompletedOnboarding = defaults.bool(forKey: "onboarded")
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) throws {
        defer { launchAtLogin = SMAppService.mainApp.status == .enabled }
        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
    }

    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// Tracks the Accessibility permission, which macOS can grant or revoke at any time.
final class PermissionMonitor: ObservableObject {
    static let shared = PermissionMonitor()
    @Published private(set) var isTrusted = AXIsProcessTrusted()
    private var timer: Timer?

    private init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            let trusted = AXIsProcessTrusted()
            if self?.isTrusted != trusted { self?.isTrusted = trusted }
        }
    }

    /// Shows the system prompt (first time) and opens the Accessibility pane.
    func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

enum TestNotification {
    static func send() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "display notification \"Notifications will now appear right here.\" with title \"\(Brand.appName)\" subtitle \"Test notification\""]
        try? task.run()
    }
}
