public enum AgentTarget: String, CaseIterable, Sendable {
    case codex
    case claude

    public var displayName: String {
        switch self {
        case .codex:
            "CODEX"
        case .claude:
            "CLAUDE"
        }
    }

    public var applicationBundleIdentifier: String {
        switch self {
        case .codex:
            "com.openai.codex"
        case .claude:
            "com.anthropic.claudefordesktop"
        }
    }
}
