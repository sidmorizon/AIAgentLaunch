import XCTest
@testable import AgentLaunchCore

final class UserDefaultsMenuBarAPIKeyStoreTests: XCTestCase {
    func testLoadAPIKeyReturnsNilWhenNoValueIsPersisted() throws {
        let (defaults, domain) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = UserDefaultsMenuBarAPIKeyStore(defaults: defaults)

        XCTAssertNil(try store.loadAPIKey())
    }

    func testSaveAPIKeyPersistsValueForSubsequentLoad() throws {
        let (defaults, domain) = makeIsolatedDefaults()
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = UserDefaultsMenuBarAPIKeyStore(defaults: defaults)

        try store.saveAPIKey("sk-local")

        XCTAssertEqual(try store.loadAPIKey(), "sk-local")
    }

    private func makeIsolatedDefaults() -> (UserDefaults, String) {
        let domain = "com.onekey.agentlaunch.tests.apikey.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defaults.removePersistentDomain(forName: domain)
        return (defaults, domain)
    }
}
