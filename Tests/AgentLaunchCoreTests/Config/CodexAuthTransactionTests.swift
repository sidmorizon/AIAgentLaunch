import Foundation
import XCTest
@testable import AgentLaunchCore

final class CodexAuthTransactionTests: XCTestCase {
    func testApplyProxyAuthenticationWritesAPIModeAuthFileAndBacksUpExistingContent() throws {
        let paths = try makeTemporaryAuthPaths()
        let originalAuthText = """
        {
          "auth_mode": "device"
        }
        """
        try originalAuthText.write(to: paths.authFilePath, atomically: true, encoding: .utf8)

        let transaction = CodexAuthTransaction()
        try transaction.applyProxyAuthentication(
            apiKey: "sk-test-1234",
            at: paths.authFilePath,
            backupFilePath: paths.backupFilePath
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.backupFilePath.path))
        let authDocument = try readJSONObject(from: paths.authFilePath)
        XCTAssertEqual(authDocument["auth_mode"] as? String, "api")
        XCTAssertEqual(authDocument["OPENAI_API_KEY"] as? String, "sk-test-1234")
    }

    func testRestoreOriginalAuthenticationRewritesOriginalContentWhenFileExisted() throws {
        let paths = try makeTemporaryAuthPaths()
        let originalAuthText = """
        {
          "auth_mode": "device",
          "token": "persist-me"
        }
        """
        try originalAuthText.write(to: paths.authFilePath, atomically: true, encoding: .utf8)

        let transaction = CodexAuthTransaction()
        try transaction.applyProxyAuthentication(
            apiKey: "sk-test-1234",
            at: paths.authFilePath,
            backupFilePath: paths.backupFilePath
        )
        try transaction.restoreOriginalAuthentication(
            at: paths.authFilePath,
            backupFilePath: paths.backupFilePath
        )

        XCTAssertEqual(try String(contentsOf: paths.authFilePath, encoding: .utf8), originalAuthText)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backupFilePath.path))
    }

    func testRestoreOriginalAuthenticationDeletesFileWhenOriginallyAbsent() throws {
        let paths = try makeTemporaryAuthPaths()
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.authFilePath.path))

        let transaction = CodexAuthTransaction()
        try transaction.applyProxyAuthentication(
            apiKey: "sk-test-1234",
            at: paths.authFilePath,
            backupFilePath: paths.backupFilePath
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.authFilePath.path))

        try transaction.restoreOriginalAuthentication(
            at: paths.authFilePath,
            backupFilePath: paths.backupFilePath
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.authFilePath.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.backupFilePath.path))
    }

    func testSecondProxyLaunchKeepsOriginalBackupState() throws {
        let paths = try makeTemporaryAuthPaths()
        let originalAuthText = """
        {
          "auth_mode": "device",
          "token": "persist-me"
        }
        """
        try originalAuthText.write(to: paths.authFilePath, atomically: true, encoding: .utf8)

        let transaction = CodexAuthTransaction()
        try transaction.applyProxyAuthentication(
            apiKey: "sk-first",
            at: paths.authFilePath,
            backupFilePath: paths.backupFilePath
        )
        try transaction.applyProxyAuthentication(
            apiKey: "sk-second",
            at: paths.authFilePath,
            backupFilePath: paths.backupFilePath
        )
        try transaction.restoreOriginalAuthentication(
            at: paths.authFilePath,
            backupFilePath: paths.backupFilePath
        )

        XCTAssertEqual(try String(contentsOf: paths.authFilePath, encoding: .utf8), originalAuthText)
    }

    func testRestoreOriginalAuthenticationIsNoOpWithoutBackupFile() throws {
        let paths = try makeTemporaryAuthPaths()

        let transaction = CodexAuthTransaction()
        try transaction.restoreOriginalAuthentication(
            at: paths.authFilePath,
            backupFilePath: paths.backupFilePath
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.authFilePath.path))
    }

    private func makeTemporaryAuthPaths() throws -> (authFilePath: URL, backupFilePath: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let codexDirectory = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        return (
            codexDirectory.appendingPathComponent("auth.json", isDirectory: false),
            codexDirectory.appendingPathComponent("auth.json.ai-agent-launch.backup", isDirectory: false)
        )
    }

    private func readJSONObject(from filePath: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: filePath)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
