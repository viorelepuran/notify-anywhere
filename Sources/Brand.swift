import SwiftUI

/// Product and publisher identity. Change the product name here.
enum Brand {
    static let appName = "Notify Anywhere"
    static let tagline = "Put macOS notifications exactly where you want them."
    static let company = "Liftoff Media"
    static let website = URL(string: "https://liftoffmedia.ro/")!
    static let supportEmail = "vivi@liftoffmedia.ro"
    static let sourceCode = URL(string: "https://github.com/viorelepuran/notify-anywhere")!
    static let issues = URL(string: "https://github.com/viorelepuran/notify-anywhere/issues")!

    static var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(short) (\(build))"
    }

    static var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String ?? "© \(company)"
    }

    static var logo: NSImage? {
        Bundle.main.url(forResource: "LiftoffLogo", withExtension: "png").flatMap(NSImage.init(contentsOf:))
    }

    // Liftoff Media palette (from liftoffmedia.ro)
    static let ink = Color(hex: 0x0B0B0F)
    static let violet = Color(hex: 0x7C3AED)
    static let violetDeep = Color(hex: 0x6D28D9)
    static let lavender = Color(hex: 0xC4B5FD)
    static let pink = Color(hex: 0xEC4899)

    static let gradient = LinearGradient(colors: [pink, violet], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let backdrop = LinearGradient(colors: [Color(hex: 0x3B1286), Color(hex: 0x1A0B3D), ink],
                                         startPoint: .topLeading, endPoint: .bottomTrailing)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// Primary call-to-action button in brand gradient.
struct BrandButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Brand.gradient, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .shadow(color: Brand.violet.opacity(0.35), radius: 8, y: 3)
    }
}
