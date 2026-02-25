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
