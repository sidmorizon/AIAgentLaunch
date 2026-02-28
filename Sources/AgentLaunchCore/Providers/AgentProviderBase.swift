import Foundation

public protocol AgentProviderBase: Sendable {
    var providerIdentifier: String { get }
    var providerDisplayName: String { get }
    var applicationBundleIdentifier: String { get }
    var configurationFilePath: URL { get }
    var authFilePath: URL { get }
    var authBackupFilePath: URL { get }
    var apiKeyEnvironmentVariableName: String { get }

    func renderTemporaryConfiguration(from launchConfiguration: AgentProxyLaunchConfig) -> String
}
