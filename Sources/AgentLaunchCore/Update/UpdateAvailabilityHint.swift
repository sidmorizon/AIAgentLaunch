import Foundation

public enum UpdateAvailabilityTone: Equatable {
    case neutral
    case info
    case success
    case warning
    case error
}

public enum UpdateAvailabilityHint: Equatable {
    case idle
    case checking
    case updateAvailable(version: String)
    case upToDate
    case failed

    public var inlineText: String? {
        switch self {
        case .idle:
            return nil
        case .checking:
            return "正在检查更新…"
        case .updateAvailable:
            return "有新版本可升级"
        case .upToDate:
            return "已是最新版本"
        case .failed:
            return "检测失败，请稍后再试"
        }
    }

    public var tone: UpdateAvailabilityTone {
        switch self {
        case .idle:
            return .neutral
        case .checking:
            return .info
        case .updateAvailable:
            return .warning
        case .upToDate:
            return .success
        case .failed:
            return .error
        }
    }

    public var hasUpdate: Bool {
        if case .updateAvailable = self {
            return true
        }
        return false
    }
}
