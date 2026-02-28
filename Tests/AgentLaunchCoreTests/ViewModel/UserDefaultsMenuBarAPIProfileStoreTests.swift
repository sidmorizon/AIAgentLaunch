import Foundation
import XCTest
@testable import AgentLaunchCore

final class UserDefaultsMenuBarAPIProfileStoreTests: XCTestCase {
    func testLoadProfilesReturnsEmptyWhenNoValueIsPersisted() {
        let (defaults, domain) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = UserDefaultsMenuBarAPIProfileStore(defaults: defaults)

        XCTAssertEqual(store.loadProfiles(), [])
    }

    func testSaveProfilesPersistsValueForSubsequentLoad() {
        let (defaults, domain) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = UserDefaultsMenuBarAPIProfileStore(defaults: defaults)
        let createdAt = Date(timeIntervalSince1970: 1_740_000_000)
        let updatedAt = Date(timeIntervalSince1970: 1_740_000_100)
        let profile = APIProfile(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            name: "默认配置",
            baseURLText: "https://api.example.com/v1",
            apiKey: "sk-local",
            createdAt: createdAt,
            updatedAt: updatedAt
        )

        store.saveProfiles([profile])

        XCTAssertEqual(store.loadProfiles(), [profile])
    }

    func testSaveActiveProfileIDPersistsValueForSubsequentLoad() {
        let (defaults, domain) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = UserDefaultsMenuBarAPIProfileStore(defaults: defaults)
        let activeID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!

        store.saveActiveProfileID(activeID)

        XCTAssertEqual(store.loadActiveProfileID(), activeID)
    }

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let domain = "com.onekey.agentlaunch.tests.apiprofiles.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        return (defaults, domain)
    }
}
