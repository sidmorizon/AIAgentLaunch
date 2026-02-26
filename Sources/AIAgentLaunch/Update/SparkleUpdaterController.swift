import Foundation
import Sparkle

@MainActor
final class SparkleUpdaterController: ObservableObject {
    private let updaterController: SPUStandardUpdaterController?

    var isConfigured: Bool {
        updaterController != nil
    }

    var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? false
    }

    init(bundle: Bundle = .main) {
        let hasFeedURL = (bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String)?.isEmpty == false
        guard hasFeedURL else {
            updaterController = nil
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        updaterController = controller
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
}
