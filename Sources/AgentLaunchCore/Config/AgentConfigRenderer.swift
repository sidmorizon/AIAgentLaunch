public struct AgentConfigRenderer {
    public init() {}

    public func renderTemporaryConfiguration(from launchConfiguration: AgentProxyLaunchConfig) -> String {
        """
        model = "\(launchConfiguration.modelIdentifier)"
        model_reasoning_effort = "\(launchConfiguration.reasoningLevel.rawValue)"

        [model_providers.custom]
        name = "Custom OpenAI Compatible"
        base_url = "\(launchConfiguration.apiBaseURL.absoluteString)"
        api_key = "\(launchConfiguration.providerAPIKey)"
        wire_api = "responses"
        """
    }
}
