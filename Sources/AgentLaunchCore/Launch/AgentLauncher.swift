import AppKit
import Foundation

public enum AgentLauncherError: Error, Equatable {
    case failedToLaunch(bundleIdentifier: String)
}

public protocol AgentLaunching {
    func launchApplication(bundleIdentifier: String) throws
}

public struct AgentLauncher: AgentLaunching {
    private let workspace: NSWorkspace

    public init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    public func launchApplication(bundleIdentifier: String) throws {
        let didLaunch = workspace.launchApplication(
            withBundleIdentifier: bundleIdentifier,
            options: [],
            additionalEventParamDescriptor: nil,
            launchIdentifier: nil
        )

        guard didLaunch else {
            throw AgentLauncherError.failedToLaunch(bundleIdentifier: bundleIdentifier)
        }
    }
}
