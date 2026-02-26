import AppKit
import Foundation

public enum AgentLauncherError: Error, Equatable {
    case failedToLaunch(bundleIdentifier: String)
}

@MainActor
public protocol AgentLaunching {
    func launchApplication(bundleIdentifier: String, environmentVariables: [String: String]) async throws
}

public struct AgentLauncher: AgentLaunching {
    public init() {}

    public func launchApplication(bundleIdentifier: String, environmentVariables: [String: String]) async throws {
        let workspace = NSWorkspace.shared
        guard let applicationURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AgentLauncherError.failedToLaunch(bundleIdentifier: bundleIdentifier)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        if !environmentVariables.isEmpty {
            var mergedEnvironment = ProcessInfo.processInfo.environment
            mergedEnvironment.merge(environmentVariables) { _, injectedValue in injectedValue }
            configuration.environment = mergedEnvironment
        }

        _ = try await workspace.openApplication(at: applicationURL, configuration: configuration)
    }
}
