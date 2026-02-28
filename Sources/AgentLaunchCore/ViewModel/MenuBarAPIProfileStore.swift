import Foundation

public protocol MenuBarAPIProfileStoring {
    func loadProfiles() -> [APIProfile]
    func saveProfiles(_ profiles: [APIProfile])
    func loadActiveProfileID() -> UUID?
    func saveActiveProfileID(_ profileID: UUID?)
}

public final class UserDefaultsMenuBarAPIProfileStore: MenuBarAPIProfileStoring {
    private enum Keys {
        static let profiles = "menu_bar.api_profiles"
        static let activeProfileID = "menu_bar.active_profile_id"
        static let legacyGlobalAPIKey = "menu_bar.api_key"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // All API keys are now profile-scoped.
        self.defaults.removeObject(forKey: Keys.legacyGlobalAPIKey)
    }

    public func loadProfiles() -> [APIProfile] {
        guard let data = defaults.data(forKey: Keys.profiles) else { return [] }
        return (try? decoder.decode([APIProfile].self, from: data)) ?? []
    }

    public func saveProfiles(_ profiles: [APIProfile]) {
        guard let data = try? encoder.encode(profiles) else { return }
        defaults.set(data, forKey: Keys.profiles)
    }

    public func loadActiveProfileID() -> UUID? {
        guard let rawValue = defaults.string(forKey: Keys.activeProfileID) else { return nil }
        return UUID(uuidString: rawValue)
    }

    public func saveActiveProfileID(_ profileID: UUID?) {
        guard let profileID else {
            defaults.removeObject(forKey: Keys.activeProfileID)
            return
        }
        defaults.set(profileID.uuidString, forKey: Keys.activeProfileID)
    }
}
