import Foundation

public enum LaunchEnvironmentSnapshotFormatter {
    public static func renderMaskedSnapshot(from environment: [String: String]) -> String {
        guard !environment.isEmpty else { return "" }

        let sortedKeys = environment.keys.sorted()
        let lines = sortedKeys.map { key in
            let value = environment[key] ?? ""
            return "\(key) = \"\(maskedValue(forKey: key, value: value))\""
        }
        return lines.joined(separator: "\n")
    }

    private static func maskedValue(forKey key: String, value: String) -> String {
        guard requiresMasking(key: key) else { return value }
        return redact(value)
    }

    private static func requiresMasking(key: String) -> Bool {
        let normalizedKey = key.uppercased()
        return normalizedKey.contains("API_KEY") || normalizedKey.contains("TOKEN")
    }

    private static func redact(_ value: String) -> String {
        guard value.count > 8 else {
            return String(repeating: "*", count: max(1, value.count))
        }
        let prefix = value.prefix(4)
        let suffix = value.suffix(4)
        return "\(prefix)********\(suffix)"
    }
}
