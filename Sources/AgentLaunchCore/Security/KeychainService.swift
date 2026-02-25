import Foundation
import LocalAuthentication

public protocol BiometryCapabilityChecking: Sendable {
    var isBiometryAvailable: Bool { get }
}

public struct SystemBiometryCapabilityChecker: BiometryCapabilityChecking {
    public init() {}

    public var isBiometryAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }
}

public final class KeychainService {
    private let keychainAPI: KeychainAPI
    private let capability: BiometryCapabilityChecking
    private let account: String
    private let service: String

    public init(
        keychainAPI: KeychainAPI = SecurityKeychainAPI(),
        capability: BiometryCapabilityChecking = SystemBiometryCapabilityChecker(),
        account: String = "provider-api-key",
        service: String = "AIAgentLaunch"
    ) {
        self.keychainAPI = keychainAPI
        self.capability = capability
        self.account = account
        self.service = service
    }

    public func resolvePolicy() -> KeychainAuthPolicy {
        capability.isBiometryAvailable ? .biometryCurrentSet : .userPresence
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

    public func readAPIKey() throws -> String {
        let keyData = try keychainAPI.readGenericPassword(account: account, service: service)
        guard let key = String(data: keyData, encoding: .utf8) else {
            throw KeychainAPIError.stringEncodingFailed
        }
        return key
    }
}
