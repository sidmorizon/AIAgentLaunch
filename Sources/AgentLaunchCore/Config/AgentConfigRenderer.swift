public struct AgentConfigRenderer {
    public init() {}

    public func renderTemporaryConfiguration(
        from launchConfiguration: AgentProxyLaunchConfig,
        profileIdentifier: String = AgentProxyConfigDefaults.profileIdentifier,
        providerDisplayName: String = AgentProxyConfigDefaults.providerDisplayName,
        apiKeyEnvironmentVariableName: String = AgentProxyConfigDefaults.apiKeyEnvironmentVariableName
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
        env_key= "\(apiKeyEnvironmentVariableName)" # 声明自定义 API KEY 的环境变量名，必须指定，且必须通过环境变量设置，不能定义在 auth.json 里
        """
    }
}
