import Foundation

public struct AgentProviderCodex: AgentProviderBase {
    public let providerIdentifier = "codex"
    public let providerDisplayName = "Codex"
    public let applicationBundleIdentifier = "com.openai.codex"
    public let configurationFilePath: URL
    public let authFilePath: URL
    public let authBackupFilePath: URL
    public let apiKeyEnvironmentVariableName = AgentProxyConfigDefaults.apiKeyEnvironmentVariableName

    public init(homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let codexDirectory = homeDirectory.appendingPathComponent(".codex", isDirectory: true)
        self.configurationFilePath = codexDirectory.appendingPathComponent("config.toml", isDirectory: false)
        self.authFilePath = codexDirectory.appendingPathComponent("auth.json", isDirectory: false)
        self.authBackupFilePath = codexDirectory.appendingPathComponent("auth.json.ai-agent-launch.backup", isDirectory: false)
    }

    public func renderTemporaryConfiguration(from launchConfiguration: AgentProxyLaunchConfig) -> String {
        AgentConfigRenderer().renderTemporaryConfiguration(
            from: launchConfiguration,
            profileIdentifier: AgentProxyConfigDefaults.profileIdentifier,
            providerDisplayName: AgentProxyConfigDefaults.providerDisplayName
        )
    }
}
