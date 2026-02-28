public enum LaunchEnvironmentDefaults {
    public static let openByAIAgentLaunchKey = "OPEN_BY_AI_AGENT_LAUNCH"
    public static let openByAIAgentLaunchValue = "true"

    public static var launchMarker: [String: String] {
        [openByAIAgentLaunchKey: openByAIAgentLaunchValue]
    }
}
