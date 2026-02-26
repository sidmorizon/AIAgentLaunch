import AgentLaunchCore
import AppKit
import Foundation
import Sparkle

@MainActor
final class SparkleUpdaterController: NSObject, ObservableObject {
    private enum SparkleErrorCode {
        static let noUpdate = 1001 // SUNoUpdateError
        static let installationCanceled = 4007 // SUInstallationCanceledError
        static let installationAuthorizeLater = 4008 // SUInstallationAuthorizeLaterError
    }

    private enum MetadataKey {
        static let ciReleaseUpdateCheckEnabled = "AIAgentLaunchEnableUpdateChecks"
    }

    private enum UpdateCheckAvailability: Equatable {
        case enabled
        case developmentBuild
        case ciReleaseMisconfigured

        var manualCheckFailureReason: String {
            switch self {
            case .enabled:
                return "更新服务暂时不可用，请稍后重试。"
            case .developmentBuild:
                return "开发环境不支持检测，请使用 CI 发布安装包进行升级检测。"
            case .ciReleaseMisconfigured:
                return "当前安装包未正确配置升级能力，请重新下载安装最新版本后重试。"
            }
        }
    }

    private var updaterController: SPUStandardUpdaterController?
    private let updateCheckAvailability: UpdateCheckAvailability
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

    var updateHintTone: UpdateAvailabilityTone {
        updateHint.tone
    }

    init(bundle: Bundle = .main) {
        updaterController = nil
        let infoDictionary = bundle.infoDictionary ?? [:]
        let isCIReleaseBuild = Self.isCIReleaseBuild(infoDictionary: infoDictionary)

        if isCIReleaseBuild {
            updateCheckAvailability = SparkleConfiguration.canEnableUpdater(infoDictionary: infoDictionary)
                ? .enabled
                : .ciReleaseMisconfigured
        } else {
            updateCheckAvailability = .developmentBuild
        }

        super.init()

        guard updateCheckAvailability == .enabled else {
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
        guard let updater = updaterController?.updater else {
            updateHint = .failed
            presentManualCheckFailureAlert(reason: updateCheckAvailability.manualCheckFailureReason)
            return
        }
        guard updater.canCheckForUpdates else {
            updateHint = .failed
            presentManualCheckFailureAlert(
                reason: "更新服务暂时不可用，请稍后重试。"
            )
            return
        }

        updateHint = .checking
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

    private func presentManualCheckFailureAlert(reason: String) {
        let alert = NSAlert()
        alert.messageText = "无法检测升级"
        alert.informativeText = reason
        alert.alertStyle = .warning
        alert.addButton(withTitle: "确定")
        alert.runModal()
    }

    private static func isCIReleaseBuild(infoDictionary: [String: Any]) -> Bool {
        guard let rawValue = infoDictionary[MetadataKey.ciReleaseUpdateCheckEnabled] else {
            return false
        }

        if let boolValue = rawValue as? Bool {
            return boolValue
        }
        if let numberValue = rawValue as? NSNumber {
            return numberValue.boolValue
        }
        if let stringValue = rawValue as? String {
            let normalized = stringValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return normalized == "1" || normalized == "true" || normalized == "yes" || normalized == "on"
        }
        return false
    }
}

extension SparkleUpdaterController: SPUUpdaterDelegate {
    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        updateHint = .updateAvailable(version: item.displayVersionString)
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        updateHint = .upToDate
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error _: Error) {
        updateHint = .upToDate
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        if isNoUpdateError(error) {
            updateHint = .upToDate
            return
        }
        if isUserDeferredInstallationError(error) {
            return
        }
        updateHint = .failed
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor _: SPUUpdateCheck, error: Error?) {
        guard let error else {
            return
        }
        if isNoUpdateError(error) {
            updateHint = .upToDate
            return
        }
        if isUserDeferredInstallationError(error) {
            return
        }
        if case .checking = updateHint {
            updateHint = .failed
        }
    }

    private func isNoUpdateError(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == SUSparkleErrorDomain && nsError.code == SparkleErrorCode.noUpdate
    }

    private func isUserDeferredInstallationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == SUSparkleErrorDomain else {
            return false
        }
        return nsError.code == SparkleErrorCode.installationCanceled || nsError.code == SparkleErrorCode.installationAuthorizeLater
    }
}
