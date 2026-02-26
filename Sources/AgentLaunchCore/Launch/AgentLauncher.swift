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
    private let workspace: NSWorkspace

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public func launchApplication(bundleIdentifier: String, environmentVariables: [String: String]) async throws {
        guard let applicationURL = workspace.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            throw AgentLauncherError.failedToLaunch(bundleIdentifier: bundleIdentifier)
        }

        let configuration = NSWorkspace.OpenConfiguration()
        if !environmentVariables.isEmpty {
            var mergedEnvironment = ProcessInfo.processInfo.environment
            mergedEnvironment.merge(environmentVariables) { _, injectedValue in injectedValue }
            configuration.environment = mergedEnvironment
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            workspace.openApplication(at: applicationURL, configuration: configuration) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }
}
