public struct AgentConfigRenderer {
    public init() {}

    public func renderTemporaryConfiguration(
        from launchConfiguration: AgentProxyLaunchConfig,
        profileIdentifier: String = AgentProxyConfigDefaults.profileIdentifier,
        providerDisplayName: String = AgentProxyConfigDefaults.providerDisplayName
    ) -> String {
        return """
        profile = "\(profileIdentifier)"

        [profiles.\(profileIdentifier)]
        model_provider = "\(profileIdentifier)"
        model = "\(launchConfiguration.modelIdentifier)"
        model_reasoning_effort = "\(launchConfiguration.reasoningLevel.rawValue)"

        [model_providers.\(profileIdentifier)]
        name = "\(providerDisplayName)"
        base_url = "\(launchConfiguration.apiBaseURL.absoluteString)"
        wire_api = "responses"
        """
    }
}
