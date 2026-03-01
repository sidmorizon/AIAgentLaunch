import Foundation

public protocol CodexAuthTransactionHandling {
    func applyProxyAuthentication(apiKey: String, at authFilePath: URL, backupFilePath: URL) throws
    func restoreOriginalAuthentication(at authFilePath: URL, backupFilePath: URL) throws
}

public final class CodexAuthTransaction {
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

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        self.encoder = encoder
    }

    public func applyProxyAuthentication(apiKey: String, at authFilePath: URL, backupFilePath: URL) throws {
        try persistBackupIfNeeded(for: authFilePath, at: backupFilePath)
        try writeAPIModeAuthentication(apiKey: apiKey, to: authFilePath)
    }

    public func restoreOriginalAuthentication(at authFilePath: URL, backupFilePath: URL) throws {
        guard fileManager.fileExists(atPath: backupFilePath.path) else { return }

        let backupData = try Data(contentsOf: backupFilePath)
        try fileManager.createDirectory(at: authFilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try backupData.write(to: authFilePath, options: .atomic)
        try fileManager.removeItem(at: backupFilePath)
    }

    private func persistBackupIfNeeded(for authFilePath: URL, at backupFilePath: URL) throws {
        guard !fileManager.fileExists(atPath: backupFilePath.path) else { return }
        guard fileManager.fileExists(atPath: authFilePath.path) else { return }

        let originalData = try Data(contentsOf: authFilePath)
        guard shouldBackupAuthContent(originalData) else { return }

        try fileManager.createDirectory(at: backupFilePath.deletingLastPathComponent(), withIntermediateDirectories: true)
        try originalData.write(to: backupFilePath, options: .atomic)
    }

    private func shouldBackupAuthContent(_ authData: Data) -> Bool {
        guard let rootObject = try? JSONSerialization.jsonObject(with: authData),
              let authDocument = rootObject as? [String: Any],
              let authMode = authDocument["auth_mode"] as? String else {
            return false
        }

        return authMode == "chatgpt"
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
