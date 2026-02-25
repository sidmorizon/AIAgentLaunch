import Foundation

public struct AgentProxyLaunchConfig: Sendable {
    public let apiBaseURL: URL
    public let providerAPIKey: String
    public let modelIdentifier: String
    public let reasoningLevel: ReasoningEffort

    public init(apiBaseURL: URL, providerAPIKey: String, modelIdentifier: String, reasoningLevel: ReasoningEffort) {
        self.apiBaseURL = apiBaseURL
        self.providerAPIKey = providerAPIKey
        self.modelIdentifier = modelIdentifier
        self.reasoningLevel = reasoningLevel
    }
}
