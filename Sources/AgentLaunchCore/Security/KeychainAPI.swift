import Foundation
import Security

public enum KeychainAuthPolicy: Sendable, Equatable {
    case biometryCurrentSet
    case userPresence
    case none
}

public enum KeychainAPIError: Error, Equatable {
    case missingData
    case unexpectedStatus(OSStatus)
    case stringEncodingFailed
}

extension KeychainAPIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingData:
            return "Keychain returned no data."
        case let .unexpectedStatus(status):
            let systemMessage = SecCopyErrorMessageString(status, nil) as String? ?? "Unknown Security.framework error"
            if status == errSecMissingEntitlement {
                return "Keychain OSStatus \(status): \(systemMessage). This build is missing required keychain entitlements for protected items."
            }
            return "Keychain OSStatus \(status): \(systemMessage)"
        case .stringEncodingFailed:
            return "Failed to encode/decode keychain value as UTF-8."
        }
    }
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
        if authPolicy == .none {
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        } else {
            addQuery[kSecAttrAccessControl as String] = try makeAccessControl(policy: authPolicy)
        }

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
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIAllow
        query[kSecUseOperationPrompt as String] = "Authenticate to access API Key"

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
        case .none:
            throw KeychainAPIError.unexpectedStatus(errSecParam)
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
