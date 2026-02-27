import Foundation
import Security

public final class KeychainService {
    private let keychainAPI: KeychainAPI
    private let account: String
    private let service: String

    public init(
        keychainAPI: KeychainAPI = SecurityKeychainAPI(),
        account: String = "provider-api-key",
        service: String = "AIAgentLaunch"
    ) {
        self.keychainAPI = keychainAPI
        self.account = account
        self.service = service
    }

    public func resolvePolicy() -> KeychainAuthPolicy {
        .none
    }

    public func saveAPIKey(_ key: String) throws {
        guard let keyData = key.data(using: .utf8) else {
            throw KeychainAPIError.stringEncodingFailed
        }
        try keychainAPI.upsertGenericPassword(
            account: account,
            service: service,
            value: keyData,
            authPolicy: resolvePolicy()
        )
    }

    public func readAPIKey() throws -> String? {
        let keyData: Data
        do {
            keyData = try keychainAPI.readGenericPassword(account: account, service: service)
        } catch KeychainAPIError.unexpectedStatus(errSecItemNotFound),
                KeychainAPIError.unexpectedStatus(errSecInteractionNotAllowed) {
            return nil
        }

        guard let key = String(data: keyData, encoding: .utf8) else {
            throw KeychainAPIError.stringEncodingFailed
        }
        return key
    }
}
