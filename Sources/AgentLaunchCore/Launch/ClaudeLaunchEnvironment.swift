import Foundation

public enum ClaudeLaunchEnvironment {
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
            "ANTHROPIC_MODEL": model,
            "OPENAI_MODEL": model,
            "ANTHROPIC_REASONING_EFFORT": reasoning,
            "OPENAI_REASONING_EFFORT": reasoning,
        ]
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
}
