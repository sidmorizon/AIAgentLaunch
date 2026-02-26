import Foundation

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
            return "正在检查新版本…"
        case let .updateAvailable(version):
            let normalizedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalizedVersion.isEmpty {
                return "发现新版本"
            }
            return "发现新版本 v\(normalizedVersion)"
        case .upToDate:
            return "当前已是最新版本"
        case .failed:
            return "未能获取更新信息"
        }
    }

    public var hasUpdate: Bool {
        if case .updateAvailable = self {
            return true
        }
        return false
    }
}
