import Foundation

public protocol CodexAuthTransactionHandling {
    func applyProxyAuthentication(apiKey: String, at authFilePath: URL, backupFilePath: URL) throws
    func restoreOriginalAuthentication(at authFilePath: URL, backupFilePath: URL) throws
}

public enum CodexAuthTransactionError: Error {
    case missingBackupContent
}

public final class CodexAuthTransaction {
    private struct BackupPayload: Codable {
        let state: OriginalState
        let content: String?
    }

    private enum OriginalState: String, Codable {
        case absent
        case content
    }

    private struct AuthDocument: Encodable {
        let authMode: String
        let apiKey: String

        enum CodingKeys: String, CodingKey {
            case authMode = "auth_mode"
            case apiKey = "OPENAI_API_KEY"
        }
    }

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func applyProxyAuthentication(apiKey: String, at authFilePath: URL, backupFilePath: URL) throws {
        try persistBackupIfNeeded(for: authFilePath, at: backupFilePath)
        try writeAPIModeAuthentication(apiKey: apiKey, to: authFilePath)
    }

    public func restoreOriginalAuthentication(at authFilePath: URL, backupFilePath: URL) throws {
        guard fileManager.fileExists(atPath: backupFilePath.path) else { return }

        let backupData = try Data(contentsOf: backupFilePath)
        let payload = try decoder.decode(BackupPayload.self, from: backupData)

        switch payload.state {
        case .absent:
            if fileManager.fileExists(atPath: authFilePath.path) {
                try fileManager.removeItem(at: authFilePath)
            }
        case .content:
            guard let content = payload.content else {
                throw CodexAuthTransactionError.missingBackupContent
            }
            try fileManager.createDirectory(at: authFilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
            try content.write(to: authFilePath, atomically: true, encoding: .utf8)
        }

        try fileManager.removeItem(at: backupFilePath)
    }

    private func persistBackupIfNeeded(for authFilePath: URL, at backupFilePath: URL) throws {
        guard !fileManager.fileExists(atPath: backupFilePath.path) else { return }

        let payload: BackupPayload
        if fileManager.fileExists(atPath: authFilePath.path) {
            let originalContent = try String(contentsOf: authFilePath, encoding: .utf8)
            payload = BackupPayload(state: .content, content: originalContent)
        } else {
            payload = BackupPayload(state: .absent, content: nil)
        }

        try fileManager.createDirectory(at: backupFilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encodedPayload = try encoder.encode(payload)
        try encodedPayload.write(to: backupFilePath, options: .atomic)
    }

    private func writeAPIModeAuthentication(apiKey: String, to authFilePath: URL) throws {
        let document = AuthDocument(authMode: "apikey", apiKey: apiKey)
        let encodedDocument = try encoder.encode(document)
        guard var authText = String(data: encodedDocument, encoding: .utf8) else { return }
        authText.append("\n")

        try fileManager.createDirectory(at: authFilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try authText.write(to: authFilePath, atomically: true, encoding: .utf8)
    }
}

extension CodexAuthTransaction: CodexAuthTransactionHandling {}
