import Foundation
import Security

public enum KeychainAuthPolicy: Sendable, Equatable {
    case biometryCurrentSet
    case userPresence
}

public enum KeychainAPIError: Error, Equatable {
    case missingData
    case unexpectedStatus(OSStatus)
    case stringEncodingFailed
}

public protocol KeychainAPI: Sendable {
    func upsertGenericPassword(account: String, service: String, value: Data, authPolicy: KeychainAuthPolicy) throws
    func readGenericPassword(account: String, service: String) throws -> Data
}

public struct SecurityKeychainAPI: KeychainAPI {
    public init() {}

    public func upsertGenericPassword(account: String, service: String, value: Data, authPolicy: KeychainAuthPolicy) throws {
        let baseQuery = makeBaseQuery(account: account, service: service)
        var addQuery = baseQuery
        addQuery[kSecValueData as String] = value
        addQuery[kSecAttrAccessControl as String] = try makeAccessControl(policy: authPolicy)

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return
        }

        if addStatus == errSecDuplicateItem {
            let attributes: [String: Any] = [
                kSecValueData as String: value
            ]
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else {
                throw KeychainAPIError.unexpectedStatus(updateStatus)
            }
            return
        }

        throw KeychainAPIError.unexpectedStatus(addStatus)
    }

    public func readGenericPassword(account: String, service: String) throws -> Data {
        var query = makeBaseQuery(account: account, service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            throw KeychainAPIError.unexpectedStatus(status)
        }
        guard let data = result as? Data else {
            throw KeychainAPIError.missingData
        }
        return data
    }

    private func makeAccessControl(policy: KeychainAuthPolicy) throws -> SecAccessControl {
        let flags: SecAccessControlCreateFlags
        switch policy {
        case .biometryCurrentSet:
            flags = .biometryCurrentSet
        case .userPresence:
            flags = .userPresence
        }

        var error: Unmanaged<CFError>?
        guard
            let accessControl = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                flags,
                &error
            )
        else {
            let status = error?.takeRetainedValue()._code ?? Int(errSecParam)
            throw KeychainAPIError.unexpectedStatus(OSStatus(status))
        }

        return accessControl
    }

    private func makeBaseQuery(account: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecAttrService as String: service
        ]
    }
}
