public struct LaunchInspectionPayload: Equatable, Sendable {
    public let agent: AgentTarget
    public let codexConfigTOMLText: String?
    public let launchEnvironmentVariables: [String: String]
    public let claudeCLIEnvironmentVariables: [String: String]?

    public init(
        agent: AgentTarget,
        codexConfigTOMLText: String?,
        launchEnvironmentVariables: [String: String],
        claudeCLIEnvironmentVariables: [String: String]? = nil
    ) {
        self.agent = agent
        self.codexConfigTOMLText = codexConfigTOMLText
        self.launchEnvironmentVariables = launchEnvironmentVariables
        self.claudeCLIEnvironmentVariables = claudeCLIEnvironmentVariables
    }
}
