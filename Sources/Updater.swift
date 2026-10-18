import Cocoa
import Combine
import Sparkle

/// Sparkle-backed update checks. The feed URL and EdDSA public key live in Info.plist.
final class UpdateController: ObservableObject {
    static let shared = UpdateController()

    private let controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var updater: SPUUpdater { controller.updater }
    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var lastCheck: Date?

    var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { objectWillChange.send(); updater.automaticallyChecksForUpdates = newValue }
    }

    private init() {
        updater.publisher(for: \.canCheckForUpdates)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                guard let self else { return }
                self.canCheckForUpdates = $0
                // lastUpdateCheckDate isn't KVO-compliant; re-read it whenever a check starts or ends.
                self.lastCheck = self.updater.lastUpdateCheckDate
            }
            .store(in: &cancellables)
    }

    func checkForUpdates() {
        // Menu bar apps aren't active by default; bring Sparkle's window to the front.
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }
}
