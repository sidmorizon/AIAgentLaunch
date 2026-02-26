import Foundation

public struct AgentProviderCodex: AgentProviderBase {
    public let providerIdentifier = "codex"
    public let providerDisplayName = "Codex"
    public let applicationBundleIdentifier = "com.openai.codex"
    public let configurationFilePath: URL
    public let apiKeyEnvironmentVariableName = "OPENAI_API_KEY"
    private let proxyProfileIdentifier = "1k"
    private let proxyProviderDisplayName = "CLIProxyOneKey"

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.configurationFilePath = homeDirectory.appendingPathComponent(".codex/config.toml", isDirectory: false)
    }

    public func renderTemporaryConfiguration(from launchConfiguration: AgentProxyLaunchConfig) -> String {
        AgentConfigRenderer().renderTemporaryConfiguration(
            from: launchConfiguration,
            profileIdentifier: proxyProfileIdentifier,
            providerDisplayName: proxyProviderDisplayName,
            apiKeyEnvironmentVariableName: apiKeyEnvironmentVariableName
        )
    }
}
