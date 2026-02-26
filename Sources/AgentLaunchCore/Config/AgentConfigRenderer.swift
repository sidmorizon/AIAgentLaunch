public struct AgentConfigRenderer {
    public init() {}

    public func renderTemporaryConfiguration(
        from launchConfiguration: AgentProxyLaunchConfig,
        profileIdentifier: String = "1k",
        providerDisplayName: String = "CLIProxyOneKey",
        apiKeyEnvironmentVariableName: String = "OPENAI_API_KEY"
    ) -> String {
        let renderedReasoningEffort = launchConfiguration.reasoningLevel == .high
            ? "xhigh"
            : launchConfiguration.reasoningLevel.rawValue

        return """
        profile = "\(profileIdentifier)"

        [profiles.\(profileIdentifier)]
        model_provider = "\(profileIdentifier)"
        model = "\(launchConfiguration.modelIdentifier)"
        model_reasoning_effort = "\(renderedReasoningEffort)"

        [model_providers.\(profileIdentifier)]
        name = "\(providerDisplayName)"
        base_url = "\(launchConfiguration.apiBaseURL.absoluteString)"
        wire_api = "responses"
        env_key= "\(apiKeyEnvironmentVariableName)" # 声明自定义 API KEY 的环境变量名，必须指定，且必须通过环境变量设置，不能定义在 auth.json 里
        """
    }
}
