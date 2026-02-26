import Foundation

public protocol AppVersionProviding {
    func currentVersion() -> String
}

public struct AppVersionProvider: AppVersionProviding {
    private let bundle: Bundle
    private let environment: [String: String]
    private let currentDirectoryPath: String
    private let fileManager: FileManager

    public init(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        currentDirectoryPath: String = FileManager.default.currentDirectoryPath,
        fileManager: FileManager = .default
    ) {
        self.bundle = bundle
        self.environment = environment
        self.currentDirectoryPath = currentDirectoryPath
        self.fileManager = fileManager
    }

    public func currentVersion() -> String {
        if let environmentVersion = normalizedVersion(environment["AIAgentLaunch_VERSION"]) {
            return environmentVersion
        }

        if let bundleResourceVersion = loadBundleResourceVersion() {
            return bundleResourceVersion
        }

        if let workingDirectoryVersion = loadWorkingDirectoryVersion() {
            return workingDirectoryVersion
        }

        return agentLaunchCoreVersion()
    }

    private func loadBundleResourceVersion() -> String? {
        guard let resourceURL = bundle.url(forResource: "version", withExtension: nil) else {
            return nil
        }
        guard let text = try? String(contentsOf: resourceURL, encoding: .utf8) else {
            return nil
        }
        return normalizedVersion(text)
    }

    private func loadWorkingDirectoryVersion() -> String? {
        let versionFilePath = URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
            .appendingPathComponent("version", isDirectory: false)
        guard fileManager.fileExists(atPath: versionFilePath.path) else {
            return nil
        }

        guard let text = try? String(contentsOf: versionFilePath, encoding: .utf8) else {
            return nil
        }
        return normalizedVersion(text)
    }

    private func normalizedVersion(_ rawVersion: String?) -> String? {
        guard let trimmed = rawVersion?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
