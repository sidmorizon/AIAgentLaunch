import Foundation
import XCTest
@testable import AgentLaunchCore

final class ConfigTransactionTests: XCTestCase {
    func testRestoreRewritesOriginalContentWhenFileExisted() throws {
        let configurationFilePath = try makeTemporaryConfigFilePath()
        let originalConfigurationText = "model = \"old\""
        try writeConfigurationText(originalConfigurationText, to: configurationFilePath)

        let transaction = ConfigTransaction()
        try transaction.applyTemporaryConfiguration("model = \"temp\"", at: configurationFilePath)
        try transaction.restoreOriginalConfiguration(at: configurationFilePath)

        XCTAssertEqual(try readConfigurationText(from: configurationFilePath), originalConfigurationText)
    }

    func testRestoreDeletesFileWhenOriginallyAbsent() throws {
        let configurationFilePath = try makeTemporaryConfigFilePath()
        XCTAssertFalse(FileManager.default.fileExists(atPath: configurationFilePath.path))

        let transaction = ConfigTransaction()
        try transaction.applyTemporaryConfiguration("model = \"temp\"", at: configurationFilePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configurationFilePath.path))

        try transaction.restoreOriginalConfiguration(at: configurationFilePath)

        XCTAssertFalse(FileManager.default.fileExists(atPath: configurationFilePath.path))
    }

    func testRestoreIsIdempotent() throws {
        let configurationFilePath = try makeTemporaryConfigFilePath()

        let transaction = ConfigTransaction()
        try transaction.applyTemporaryConfiguration("model = \"temp\"", at: configurationFilePath)
        try transaction.restoreOriginalConfiguration(at: configurationFilePath)
        try transaction.restoreOriginalConfiguration(at: configurationFilePath)

        XCTAssertFalse(FileManager.default.fileExists(atPath: configurationFilePath.path))
    }

    private func makeTemporaryConfigFilePath() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let providerConfigDirectory = root.appendingPathComponent(".agent-launch", isDirectory: true)
        try FileManager.default.createDirectory(at: providerConfigDirectory, withIntermediateDirectories: true)
        return providerConfigDirectory.appendingPathComponent("config.toml", isDirectory: false)
    }

    private func readConfigurationText(from configurationFilePath: URL) throws -> String {
        try String(contentsOf: configurationFilePath, encoding: .utf8)
    }

    private func writeConfigurationText(_ configurationText: String, to configurationFilePath: URL) throws {
        try configurationText.write(to: configurationFilePath, atomically: true, encoding: .utf8)
    }
}
