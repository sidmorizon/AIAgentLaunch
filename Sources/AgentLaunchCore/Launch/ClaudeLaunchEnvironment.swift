import Foundation

public enum ClaudeLaunchEnvironment {
    private static let opusModelKey = "ANTHROPIC_DEFAULT_OPUS_MODEL"
    private static let sonnetModelKey = "ANTHROPIC_DEFAULT_SONNET_MODEL"
    private static let haikuModelKey = "ANTHROPIC_DEFAULT_HAIKU_MODEL"
    private static let subagentModelKey = "CLAUDE_CODE_SUBAGENT_MODEL"

    private static let apiKeyKeys: Set<String> = [
        "ANTHROPIC_API_KEY",
        "OPENAI_API_KEY",
    ]

    public static func makeProxyEnvironment(from configuration: AgentProxyLaunchConfig) -> [String: String] {
        let baseURL = configuration.apiBaseURL.absoluteString
        let model = configuration.modelIdentifier
        let reasoning = configuration.reasoningLevel.rawValue
        let apiKey = configuration.providerAPIKey

        return [
            "ANTHROPIC_API_KEY": apiKey,
            "OPENAI_API_KEY": apiKey,
            "ANTHROPIC_BASE_URL": baseURL,
            "OPENAI_BASE_URL": baseURL,
            opusModelKey: model,
            sonnetModelKey: model,
            haikuModelKey: model,
            subagentModelKey: model,
            "ANTHROPIC_MODEL": model,
            "OPENAI_MODEL": model,
            "ANTHROPIC_REASONING_EFFORT": reasoning,
            "OPENAI_REASONING_EFFORT": reasoning,
        ]
    }

    public static func applyingCLIDefaultModelOverrides(
        to environment: [String: String],
        opusModel: String,
        sonnetModel: String,
        haikuModel: String,
        subagentModel: String
    ) -> [String: String] {
        var updatedEnvironment = environment
        applyModelOverride(opusModel, forKey: opusModelKey, in: &updatedEnvironment)
        applyModelOverride(sonnetModel, forKey: sonnetModelKey, in: &updatedEnvironment)
        applyModelOverride(haikuModel, forKey: haikuModelKey, in: &updatedEnvironment)
        applyModelOverride(subagentModel, forKey: subagentModelKey, in: &updatedEnvironment)
        return updatedEnvironment
    }

    public static func renderMaskedSnapshot(from environment: [String: String]) -> String {
        guard !environment.isEmpty else {
            return ""
        }

        let sortedKeys = environment.keys.sorted()
        let lines = sortedKeys.map { key in
            let value = environment[key] ?? ""
            return "\(key) = \"\(maskedValue(for: key, value: value))\""
        }
        return lines.joined(separator: "\n")
    }

    public static func renderCLICommand(from environment: [String: String]) -> String {
        let sortedKeys = environment.keys.sorted()
        let assignments = sortedKeys.map { key in
            let value = environment[key] ?? ""
            return "\(key)=\(shellQuoted(value))"
        }
        guard !assignments.isEmpty else {
            return "claude"
        }
        return "\(assignments.joined(separator: " ")) claude"
    }

    private static func maskedValue(for key: String, value: String) -> String {
        guard apiKeyKeys.contains(key) else { return value }
        return redactAPIKey(value)
    }

    private static func redactAPIKey(_ value: String) -> String {
        guard value.count > 8 else {
            return String(repeating: "*", count: max(1, value.count))
        }
        let prefix = value.prefix(4)
        let suffix = value.suffix(4)
        return "\(prefix)********\(suffix)"
    }

    private static func shellQuoted(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private static func applyModelOverride(_ model: String, forKey key: String, in environment: inout [String: String]) {
        let trimmed = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        environment[key] = trimmed
    }
}
