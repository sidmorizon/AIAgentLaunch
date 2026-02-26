import Foundation
import XCTest
@testable import AgentLaunchCore

final class ConfigTransactionTests: XCTestCase {
    func testRestoreRewritesOriginalContentWhenFileExisted() throws {
        let configurationFilePath = try makeTemporaryConfigFilePath()
        let originalConfigurationText = "model = \"old\""
        try writeConfigurationText(originalConfigurationText, to: configurationFilePath)

        let transaction = ConfigTransaction()
        _ = try transaction.applyTemporaryConfiguration("model = \"temp\"", at: configurationFilePath)
        try transaction.restoreOriginalConfiguration(at: configurationFilePath)

        XCTAssertEqual(try readConfigurationText(from: configurationFilePath), originalConfigurationText)
    }

    func testRestoreDeletesFileWhenOriginallyAbsent() throws {
        let configurationFilePath = try makeTemporaryConfigFilePath()
        XCTAssertFalse(FileManager.default.fileExists(atPath: configurationFilePath.path))

        let transaction = ConfigTransaction()
        _ = try transaction.applyTemporaryConfiguration("model = \"temp\"", at: configurationFilePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: configurationFilePath.path))

        try transaction.restoreOriginalConfiguration(at: configurationFilePath)

        XCTAssertFalse(FileManager.default.fileExists(atPath: configurationFilePath.path))
    }

    func testRestoreIsIdempotent() throws {
        let configurationFilePath = try makeTemporaryConfigFilePath()

        let transaction = ConfigTransaction()
        _ = try transaction.applyTemporaryConfiguration("model = \"temp\"", at: configurationFilePath)
        try transaction.restoreOriginalConfiguration(at: configurationFilePath)
        try transaction.restoreOriginalConfiguration(at: configurationFilePath)

        XCTAssertFalse(FileManager.default.fileExists(atPath: configurationFilePath.path))
    }

    func testApplyTemporaryConfigurationMergesWithExistingConfigAndKeepsUnrelatedSections() throws {
        let configurationFilePath = try makeTemporaryConfigFilePath()
        let originalConfigurationText = """
        profile = "legacy"

        [profiles.legacy]
        model_provider = "legacy"
        model = "gpt-4"

        [model_providers.legacy]
        name = "Legacy Provider"
        base_url = "https://legacy.example.com/v1"

        [shell_environment_policy]
        inherit = "core"
        """
        try writeConfigurationText(originalConfigurationText, to: configurationFilePath)

        let temporaryConfigurationText = AgentConfigRenderer().renderTemporaryConfiguration(
            from: AgentProxyLaunchConfig(
                apiBaseURL: URL(string: "https://llm-api.onekeytest.com/v1")!,
                providerAPIKey: "sk-temp",
                modelIdentifier: "gpt-5.3-codex",
                reasoningLevel: .high
            )
        )

        let transaction = ConfigTransaction()
        _ = try transaction.applyTemporaryConfiguration(temporaryConfigurationText, at: configurationFilePath)

        let mergedConfigurationText = try readConfigurationText(from: configurationFilePath)
        XCTAssertTrue(mergedConfigurationText.contains("profile = \"1k\""))
        XCTAssertTrue(mergedConfigurationText.contains("[profiles.legacy]"))
        XCTAssertTrue(mergedConfigurationText.contains("[shell_environment_policy]"))
        XCTAssertTrue(mergedConfigurationText.contains("[profiles.1k]"))
        XCTAssertTrue(mergedConfigurationText.contains("[model_providers.1k]"))
    }

    func testApplyTemporaryConfigurationReplacesConflictingSectionsInsteadOfDuplicating() throws {
        let configurationFilePath = try makeTemporaryConfigFilePath()
        let originalConfigurationText = """
        profile = "legacy"

        [profiles.1k]
        model_provider = "old"
        model = "old-model"
        model_reasoning_effort = "low"

        [model_providers.1k]
        name = "Old Provider"
        base_url = "https://old.example.com/v1"
        wire_api = "responses"
        env_key= "OLD_ENV_KEY"
        """
        try writeConfigurationText(originalConfigurationText, to: configurationFilePath)

        let temporaryConfigurationText = AgentConfigRenderer().renderTemporaryConfiguration(
            from: AgentProxyLaunchConfig(
                apiBaseURL: URL(string: "https://llm-api.onekeytest.com/v1")!,
                providerAPIKey: "sk-temp",
                modelIdentifier: "gpt-5.3-codex",
                reasoningLevel: .high
            )
        )

        let transaction = ConfigTransaction()
        _ = try transaction.applyTemporaryConfiguration(temporaryConfigurationText, at: configurationFilePath)

        let mergedConfigurationText = try readConfigurationText(from: configurationFilePath)
        XCTAssertEqual(mergedConfigurationText.components(separatedBy: "[profiles.1k]").count - 1, 1)
        XCTAssertEqual(mergedConfigurationText.components(separatedBy: "[model_providers.1k]").count - 1, 1)
        XCTAssertFalse(mergedConfigurationText.contains("base_url = \"https://old.example.com/v1\""))
        XCTAssertFalse(mergedConfigurationText.contains("env_key= \"OLD_ENV_KEY\""))
        XCTAssertTrue(mergedConfigurationText.contains("base_url = \"https://llm-api.onekeytest.com/v1\""))
        XCTAssertTrue(mergedConfigurationText.contains("env_key= \"OPENAI_API_KEY\""))
    }

    func testApplyTemporaryConfigurationKeepsNonConflictingKeysInsideSameSection() throws {
        let configurationFilePath = try makeTemporaryConfigFilePath()
        let originalConfigurationText = """
        profile = "legacy"

        [profiles.1k]
        model_provider = "old-provider"
        model = "old-model"
        model_reasoning_effort = "low"
        preserve_me = "legacy-extra"

        [model_providers.1k]
        name = "Old Provider"
        base_url = "https://old.example.com/v1"
        wire_api = "responses"
        env_key= "OLD_ENV_KEY"
        preserve_provider_key = "keep-this"
        """
        try writeConfigurationText(originalConfigurationText, to: configurationFilePath)

        let temporaryConfigurationText = AgentConfigRenderer().renderTemporaryConfiguration(
            from: AgentProxyLaunchConfig(
                apiBaseURL: URL(string: "https://llm-api.onekeytest.com/v1")!,
                providerAPIKey: "sk-temp",
                modelIdentifier: "gpt-5.3-codex",
                reasoningLevel: .high
            )
        )

        let transaction = ConfigTransaction()
        _ = try transaction.applyTemporaryConfiguration(temporaryConfigurationText, at: configurationFilePath)

        let mergedConfigurationText = try readConfigurationText(from: configurationFilePath)
        XCTAssertTrue(mergedConfigurationText.contains("preserve_me = \"legacy-extra\""))
        XCTAssertTrue(mergedConfigurationText.contains("preserve_provider_key = \"keep-this\""))
        XCTAssertTrue(mergedConfigurationText.contains("model = \"gpt-5.3-codex\""))
        XCTAssertTrue(mergedConfigurationText.contains("env_key= \"OPENAI_API_KEY\""))
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
