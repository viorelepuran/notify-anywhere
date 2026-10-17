import SwiftUI

/// First-run walkthrough: welcome → grant Accessibility → choose a position.
struct OnboardingView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var permission = PermissionMonitor.shared
    @State private var step = 0
    var onFinish: () -> Void

    var body: some View {
        ZStack {
            Brand.backdrop.ignoresSafeArea()
            RadialGradient(colors: [Brand.pink.opacity(0.35), .clear], center: .bottomLeading, startRadius: 0, endRadius: 520)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Group {
                    switch step {
                    case 0: welcome
                    case 1: accessibility
                    default: position
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))

                footer
            }
        }
        .foregroundStyle(.white)
        .frame(width: 680, height: 560)
        .environment(\.colorScheme, .dark)
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Capsule().fill(i == step ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(.white.opacity(0.25)))
                        .frame(width: i == step ? 22 : 7, height: 7)
                }
            }
            Spacer()
            if step > 0 {
                Button("Back") { withAnimation(.easeInOut(duration: 0.3)) { step -= 1 } }
                    .buttonStyle(.plain).foregroundStyle(.white.opacity(0.7)).padding(.trailing, 12)
            }
            switch step {
            case 0:
                Button("Get Started") { advance() }.buttonStyle(BrandButtonStyle())
            case 1:
                Button(permission.isTrusted ? "Continue" : "Waiting for Access…") { advance() }
                    .buttonStyle(BrandButtonStyle())
                    .disabled(!permission.isTrusted)
                    .opacity(permission.isTrusted ? 1 : 0.5)
            default:
                Button("Finish Setup") {
                    settings.hasCompletedOnboarding = true
                    TestNotification.send()
                    onFinish()
                }
                .buttonStyle(BrandButtonStyle())
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 22)
        .background(.black.opacity(0.25))
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.3)) { step += 1 }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable().frame(width: 128, height: 128)
                .shadow(color: Brand.violet.opacity(0.6), radius: 30, y: 10)
            Text("Welcome to \(Brand.appName)")
                .font(.system(size: 30, weight: .bold)).padding(.top, 16)
            Text(Brand.tagline)
                .font(.system(size: 15)).foregroundStyle(.white.opacity(0.75)).padding(.top, 6)

            VStack(alignment: .leading, spacing: 14) {
                feature("square.grid.3x3.fill", "Nine presets or any custom spot", "Corners, edges, center, or drag it exactly where you like.")
                feature("bolt.fill", "Instant and lightweight", "Banners move the moment they appear. No lag, no battery drain.")
                feature("lock.shield.fill", "Private by design", "Runs entirely on your Mac. No accounts, no tracking.")
            }
            .padding(.top, 30)

            if let logo = Brand.logo {
                HStack(spacing: 8) {
                    Text("by").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                    Image(nsImage: logo).resizable().scaledToFit().frame(height: 26)
                }
                .padding(.top, 28)
            }
        }
    }

    private func feature(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8).fill(Brand.gradient))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
            }
        }
        .frame(width: 420, alignment: .leading)
    }

    private var accessibility: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle().fill(Brand.gradient).frame(width: 96, height: 96)
                    .shadow(color: Brand.pink.opacity(0.5), radius: 24)
                Image(systemName: permission.isTrusted ? "checkmark" : "hand.raised.fill")
                    .font(.system(size: 40, weight: .bold))
                    .contentTransition(.symbolEffect(.replace))
            }
            Text(permission.isTrusted ? "You're all set" : "Allow Accessibility Access")
                .font(.system(size: 26, weight: .bold)).padding(.top, 22)
            Text("macOS only lets apps move another app's windows with your permission. \(Brand.appName) uses it for one thing: repositioning notification banners. Nothing is stored or sent anywhere.")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center).frame(width: 470).padding(.top, 8)

            if permission.isTrusted {
                Label("Access granted", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.green)
                    .padding(.top, 28)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    instruction(1, "Click **Open System Settings** below.")
                    instruction(2, "Find **\(Brand.appName)** in the list and turn it on.")
                    instruction(3, "Come back here. This screen updates automatically.")
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)))
                .padding(.top, 24)

                Button("Open System Settings") { permission.request() }
                    .buttonStyle(BrandButtonStyle())
                    .padding(.top, 20)
            }
        }
        .animation(.easeInOut, value: permission.isTrusted)
    }

    private func instruction(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: 12) {
            Text("\(n)").font(.system(size: 12, weight: .bold))
                .frame(width: 22, height: 22).background(Circle().fill(.white.opacity(0.15)))
            Text(text).font(.system(size: 13))
        }
        .frame(width: 400, alignment: .leading)
    }

    private var position: some View {
        VStack(spacing: 0) {
            Text("Where should notifications go?")
                .font(.system(size: 26, weight: .bold))
            Text("Drag the banner or pick a preset. You can change this anytime from the menu bar.")
                .font(.system(size: 13)).foregroundStyle(.white.opacity(0.75)).padding(.top, 6)
            HStack(alignment: .center, spacing: 24) {
                ScreenPreview().frame(width: 400)
                VStack(spacing: 10) {
                    PresetGrid(cell: 30)
                    Text(settings.placement.presetTitle).font(.system(size: 13, weight: .semibold))
                }
            }
            .padding(.top, 24)
        }
    }
}
