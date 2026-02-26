import Foundation

public enum SparkleConfiguration {
    public static func canEnableUpdater(infoDictionary: [String: Any]) -> Bool {
        hasNonEmptyStringValue(for: "SUFeedURL", in: infoDictionary)
            && hasNonEmptyStringValue(for: "SUPublicEDKey", in: infoDictionary)
    }

    private static func hasNonEmptyStringValue(for key: String, in infoDictionary: [String: Any]) -> Bool {
        guard let value = infoDictionary[key] as? String else {
            return false
        }

        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
