import AgentLaunchCore
import Foundation
import Sparkle

@MainActor
final class SparkleUpdaterController: NSObject, ObservableObject {
    private var updaterController: SPUStandardUpdaterController?
    @Published private(set) var updateHint: UpdateAvailabilityHint = .idle

    var isConfigured: Bool {
        updaterController != nil
    }

    var canCheckForUpdates: Bool {
        updaterController?.updater.canCheckForUpdates ?? false
    }

    var updateHintText: String? {
        updateHint.inlineText
    }

    var hasAvailableUpdate: Bool {
        updateHint.hasUpdate
    }

    init(bundle: Bundle = .main) {
        updaterController = nil
        super.init()

        guard SparkleConfiguration.canEnableUpdater(infoDictionary: bundle.infoDictionary ?? [:]) else {
            updaterController = nil
            return
        }

        let controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        updaterController = controller

        // Probe once on startup without opening Sparkle's update UI.
        DispatchQueue.main.async { [weak self] in
            self?.checkForUpdateInformationSilently()
        }
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }

    func checkForUpdateInformationSilently(retryCount: Int = 2) {
        guard let updater = updaterController?.updater else {
            return
        }
        guard updater.canCheckForUpdates else {
            if retryCount > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                    self?.checkForUpdateInformationSilently(retryCount: retryCount - 1)
                }
            }
            return
        }

        updateHint = .checking
        updater.checkForUpdateInformation()
    }
}

extension SparkleUpdaterController: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        updateHint = .updateAvailable(version: item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error _: Error) {
        updateHint = .upToDate
    }

    func updater(_ updater: SPUUpdater, didAbortWithError _: Error) {
        updateHint = .failed
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor _: SPUUpdateCheck, error: Error?) {
        if error != nil, case .checking = updateHint {
            updateHint = .failed
        }
    }
}
