import XCTest
@testable import AgentLaunchCore

final class KeychainServiceTests: XCTestCase {
    func testAccessControlPrefersBiometryCurrentSet() {
        let service = KeychainService(
            keychainAPI: InMemoryKeychainAPI(),
            capability: FixedBiometryCapability(isBiometryAvailable: true)
        )

        XCTAssertEqual(service.resolvePolicy(), .biometryCurrentSet)
    }

    func testFallbackToUserPresenceWhenBiometryUnavailable() {
        let service = KeychainService(
            keychainAPI: InMemoryKeychainAPI(),
            capability: FixedBiometryCapability(isBiometryAvailable: false)
        )

        XCTAssertEqual(service.resolvePolicy(), .userPresence)
    }

    func testSaveAPIKeyRetriesWhenMissingEntitlement() throws {
        let keychain = RetryOnMissingEntitlementKeychainAPI()
        let service = KeychainService(
            keychainAPI: keychain,
            capability: FixedBiometryCapability(isBiometryAvailable: true)
        )

        XCTAssertNoThrow(try service.saveAPIKey("sk-test"))
    }
}

private struct FixedBiometryCapability: BiometryCapabilityChecking {
    let isBiometryAvailable: Bool
}

private final class InMemoryKeychainAPI: KeychainAPI {
    func upsertGenericPassword(account: String, service: String, value: Data, authPolicy: KeychainAuthPolicy) throws {}
    func readGenericPassword(account: String, service: String) throws -> Data {
        Data()
    }
}

private final class RetryOnMissingEntitlementKeychainAPI: KeychainAPI {
    func upsertGenericPassword(account: String, service: String, value: Data, authPolicy: KeychainAuthPolicy) throws {
        if authPolicy == .biometryCurrentSet {
            throw KeychainAPIError.unexpectedStatus(errSecMissingEntitlement)
        }
    }

    func readGenericPassword(account: String, service: String) throws -> Data {
        Data()
    }
}
