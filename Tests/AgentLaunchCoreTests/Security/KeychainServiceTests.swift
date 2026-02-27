import XCTest
@testable import AgentLaunchCore

final class KeychainServiceTests: XCTestCase {
    func testAccessControlUsesNonInteractivePolicy() {
        let service = KeychainService(keychainAPI: InMemoryKeychainAPI())

        XCTAssertEqual(service.resolvePolicy(), .none)
    }

    func testSaveAPIKeyUsesNonInteractivePolicy() throws {
        let keychain = RecordingKeychainAPI()
        let service = KeychainService(keychainAPI: keychain)

        try service.saveAPIKey("sk-test")
        XCTAssertEqual(keychain.policies, [.none])
    }

    func testReadAPIKeyReturnsNilWhenItemNotFound() throws {
        let service = KeychainService(
            keychainAPI: FailingReadKeychainAPI(status: errSecItemNotFound)
        )

        XCTAssertNil(try service.readAPIKey())
    }

    func testReadAPIKeyReturnsNilWhenAuthenticationIsRequired() throws {
        let service = KeychainService(
            keychainAPI: FailingReadKeychainAPI(status: errSecInteractionNotAllowed)
        )

        XCTAssertNil(try service.readAPIKey())
    }
}

private final class InMemoryKeychainAPI: KeychainAPI {
    func upsertGenericPassword(account: String, service: String, value: Data, authPolicy: KeychainAuthPolicy) throws {}
    func readGenericPassword(account: String, service: String) throws -> Data {
        Data()
    }
}

private struct FailingReadKeychainAPI: KeychainAPI {
    let status: OSStatus

    func upsertGenericPassword(account: String, service: String, value: Data, authPolicy: KeychainAuthPolicy) throws {}

    func readGenericPassword(account: String, service: String) throws -> Data {
        throw KeychainAPIError.unexpectedStatus(status)
    }
}

private final class RecordingKeychainAPI: KeychainAPI, @unchecked Sendable {
    private(set) var policies: [KeychainAuthPolicy] = []

    func upsertGenericPassword(account: String, service: String, value: Data, authPolicy: KeychainAuthPolicy) throws {
        policies.append(authPolicy)
    }

    func readGenericPassword(account: String, service: String) throws -> Data {
        Data()
    }
}
