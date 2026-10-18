import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General", position = "Position", about = "About"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .position: return "rectangle.inset.topright.filled"
        case .about: return "info.circle.fill"
        }
    }
}

struct SettingsView: View {
    @State var tab: SettingsTab
    var placeOnScreen: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(tab: $tab)
                .frame(width: 200)
            Divider()
            Group {
                switch tab {
                case .general: GeneralPane()
                case .position: PositionPane(placeOnScreen: placeOnScreen)
                case .about: AboutPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 760, height: 580)
    }
}

private struct Sidebar: View {
    @Binding var tab: SettingsTab

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable().frame(width: 36, height: 36)
                VStack(alignment: .leading, spacing: 1) {
                    Text(Brand.appName).font(.system(size: 13, weight: .bold))
                    Text("by \(Brand.company)").font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 44)
            .padding(.bottom, 18)

            ForEach(SettingsTab.allCases) { item in
                Button { tab = item } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(tab == item ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(Color.gray.opacity(0.55))))
                        Text(item.rawValue).font(.system(size: 13, weight: tab == item ? .semibold : .regular))
                        Spacer()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(tab == item ? Color.primary.opacity(0.08) : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }

            Spacer()

            StatusBadge().padding(14)
        }
        .background(.regularMaterial)
    }
}

/// Small live status indicator: active / paused / needs permission.
struct StatusBadge: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var permission = PermissionMonitor.shared

    var body: some View {
        let (color, text): (Color, String) = !permission.isTrusted
            ? (.orange, "Needs permission")
            : settings.isEnabled ? (.green, "Active") : (.gray, "Paused")
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.7), radius: 3)
            Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Panes

private struct PaneHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.system(size: 22, weight: .bold))
            Text(subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 36)
    }
}

private struct GeneralPane: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var permission = PermissionMonitor.shared
    @ObservedObject var updates = UpdateController.shared
    @State private var loginError: String?

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: "General", subtitle: "Control how \(Brand.appName) runs on your Mac.")
            Form {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: permission.isTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(permission.isTrusted ? .green : .orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(permission.isTrusted ? "Accessibility access granted" : "Accessibility access required")
                                .font(.system(size: 13, weight: .semibold))
                            Text(permission.isTrusted
                                 ? "\(Brand.appName) can reposition notification banners."
                                 : "macOS needs your permission before banners can be moved.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if !permission.isTrusted {
                            Button("Grant Access…") { permission.request() }.buttonStyle(BrandButtonStyle())
                        }
                    }
                    .padding(.vertical, 4)

                    Toggle("Move notifications", isOn: $settings.isEnabled)
                        .disabled(!permission.isTrusted)
                } header: { Text("Status") }

                Section {
                    Toggle("Launch at login", isOn: Binding(
                        get: { settings.launchAtLogin },
                        set: { newValue in
                            do { try settings.setLaunchAtLogin(newValue) }
                            catch { loginError = error.localizedDescription }
                        }))
                    Toggle("Show icon in menu bar", isOn: $settings.showMenuBarIcon)
                } header: { Text("Startup") } footer: {
                    Text("If you hide the menu bar icon, open \(Brand.appName) again from your Applications folder to bring back this window.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }

                Section {
                    Toggle("Automatically check for updates", isOn: $updates.automaticallyChecksForUpdates)
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check for updates")
                            Text(updates.lastCheck.map { "Last checked \($0.formatted(.relative(presentation: .named)))." } ?? "Not checked yet.")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Check Now") { updates.checkForUpdates() }
                            .disabled(!updates.canCheckForUpdates)
                    }
                } header: { Text("Updates") }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Send a test notification")
                            Text("Check your current position instantly.").font(.system(size: 11)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Send Test") { TestNotification.send() }
                    }
                } header: { Text("Testing") }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .tint(Brand.violet)
        }
        .onAppear { settings.refreshLaunchAtLogin() }
        .alert("Couldn't change Launch at Login", isPresented: Binding(get: { loginError != nil }, set: { if !$0 { loginError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(loginError ?? "")\n\nMove \(Brand.appName) to your Applications folder and try again.")
        }
    }
}

private struct PositionPane: View {
    @ObservedObject var settings = AppSettings.shared
    var placeOnScreen: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PaneHeader(title: "Position", subtitle: "Drag the notification or choose a preset. Changes apply instantly.")

            ScreenPreview()
                .padding(.horizontal, 28)
                .padding(.top, 18)

            HStack(alignment: .top, spacing: 28) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PRESETS").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    PresetGrid()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("EDGE SPACING").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    HStack {
                        Slider(value: $settings.margin, in: 0...120, step: 2)
                            .tint(Brand.violet)
                        Text("\(Int(settings.margin)) pt")
                            .font(.system(size: 12, design: .monospaced))
                            .frame(width: 48, alignment: .trailing)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse").foregroundStyle(Brand.violet)
                        Text(settings.placement.presetTitle).font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .trailing, spacing: 8) {
                    Button("Send Test") { TestNotification.send() }.buttonStyle(BrandButtonStyle())
                    Button("Place on Screen…", action: placeOnScreen)
                    Button("Reset to macOS Default") {
                        settings.placement = Placement(fx: 1, fy: 0)
                        settings.margin = 16
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 11))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)

            Spacer(minLength: 0)
        }
    }
}

private struct AboutPane: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 112, height: 112)
                .shadow(color: Brand.violet.opacity(0.35), radius: 18, y: 8)
            Text(Brand.appName).font(.system(size: 26, weight: .bold)).padding(.top, 10)
            Text(Brand.version).font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 2)
            Text(Brand.tagline).font(.system(size: 13)).padding(.top, 10)
            Label("Free & open source", systemImage: "heart.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Brand.gradient, in: Capsule())
                .padding(.top, 10)

            VStack(spacing: 6) {
                Text("DESIGNED & DEVELOPED BY").font(.system(size: 9, weight: .semibold)).tracking(1.2).foregroundStyle(.secondary)
                if let logo = Brand.logo {
                    Image(nsImage: logo).resizable().scaledToFit().frame(height: 46)
                } else {
                    Text(Brand.company).font(.system(size: 18, weight: .heavy))
                }
            }
            .padding(.top, 28)

            HStack(spacing: 10) {
                Link("Website", destination: Brand.website)
                Text("·").foregroundStyle(.tertiary)
                Link("Source Code", destination: Brand.sourceCode)
                Text("·").foregroundStyle(.tertiary)
                Link("Report an Issue", destination: Brand.issues)
                Text("·").foregroundStyle(.tertiary)
                Link("Contact", destination: URL(string: "mailto:\(Brand.supportEmail)?subject=\(Brand.appName.replacingOccurrences(of: " ", with: "%20"))")!)
            }
            .font(.system(size: 12, weight: .medium))
            .tint(Brand.lavender)
            .foregroundStyle(Brand.lavender)
            .padding(.top, 18)

            Label("Runs entirely on your Mac. No accounts, no tracking. Update checks are its only network access.", systemImage: "lock.shield")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .padding(.top, 22)
            Spacer()
            Text(Brand.copyright).font(.system(size: 10)).foregroundStyle(.tertiary).padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
    }
}
