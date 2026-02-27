import Foundation
import XCTest
@testable import AgentLaunchCore

final class ClaudeLaunchEnvironmentTests: XCTestCase {
    func testMakeProxyEnvironmentIncludesExpectedKeysAndValues() {
        let configuration = AgentProxyLaunchConfig(
            apiBaseURL: URL(string: "https://example.com/v1")!,
            providerAPIKey: "sk-test-12345678",
            modelIdentifier: "claude-sonnet-4-5",
            reasoningLevel: .high
        )

        let environment = ClaudeLaunchEnvironment.makeProxyEnvironment(from: configuration)

        XCTAssertEqual(environment["ANTHROPIC_API_KEY"], "sk-test-12345678")
        XCTAssertEqual(environment["OPENAI_API_KEY"], "sk-test-12345678")
        XCTAssertEqual(environment["ANTHROPIC_BASE_URL"], "https://example.com/v1")
        XCTAssertEqual(environment["OPENAI_BASE_URL"], "https://example.com/v1")
        XCTAssertEqual(environment["ANTHROPIC_DEFAULT_OPUS_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(environment["ANTHROPIC_DEFAULT_SONNET_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(environment["ANTHROPIC_DEFAULT_HAIKU_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(environment["CLAUDE_CODE_SUBAGENT_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(environment["ANTHROPIC_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(environment["OPENAI_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(environment["ANTHROPIC_REASONING_EFFORT"], "high")
        XCTAssertEqual(environment["OPENAI_REASONING_EFFORT"], "high")
    }

    func testRenderMaskedSnapshotHidesRawAPIKeys() {
        let environment = [
            "ANTHROPIC_API_KEY": "abcd1234wxyz9876",
            "OPENAI_API_KEY": "abcd1234wxyz9876",
            "OPENAI_MODEL": "gpt-5"
        ]

        let snapshot = ClaudeLaunchEnvironment.renderMaskedSnapshot(from: environment)

        XCTAssertFalse(snapshot.contains("abcd1234wxyz9876"))
        XCTAssertTrue(snapshot.contains("abcd********9876"))
        XCTAssertTrue(snapshot.contains("OPENAI_MODEL = \"gpt-5\""))
    }

    func testRenderCLICommandIncludesInjectedEnvironmentAndEscapesSingleQuotes() {
        let environment = [
            "ANTHROPIC_API_KEY": "sk-test-12'345",
            "OPENAI_BASE_URL": "https://example.com/v1",
            "OPENAI_MODEL": "claude-sonnet-4-5"
        ]

        let command = ClaudeLaunchEnvironment.renderCLICommand(from: environment)

        XCTAssertEqual(
            command,
            "ANTHROPIC_API_KEY='sk-test-12'\\''345' OPENAI_BASE_URL='https://example.com/v1' OPENAI_MODEL='claude-sonnet-4-5' claude"
        )
    }

    func testApplyingCLIDefaultModelOverridesOnlyTouchesFourModelVariables() {
        let original = [
            "ANTHROPIC_API_KEY": "sk-test",
            "ANTHROPIC_DEFAULT_OPUS_MODEL": "opus-old",
            "ANTHROPIC_DEFAULT_SONNET_MODEL": "sonnet-old",
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": "haiku-old",
            "CLAUDE_CODE_SUBAGENT_MODEL": "subagent-old",
            "OPENAI_MODEL": "openai-keep"
        ]

        let updated = ClaudeLaunchEnvironment.applyingCLIDefaultModelOverrides(
            to: original,
            opusModel: "opus-new",
            sonnetModel: "sonnet-new",
            haikuModel: "haiku-new",
            subagentModel: "subagent-new"
        )

        XCTAssertEqual(updated["ANTHROPIC_DEFAULT_OPUS_MODEL"], "opus-new")
        XCTAssertEqual(updated["ANTHROPIC_DEFAULT_SONNET_MODEL"], "sonnet-new")
        XCTAssertEqual(updated["ANTHROPIC_DEFAULT_HAIKU_MODEL"], "haiku-new")
        XCTAssertEqual(updated["CLAUDE_CODE_SUBAGENT_MODEL"], "subagent-new")
        XCTAssertEqual(updated["ANTHROPIC_API_KEY"], "sk-test")
        XCTAssertEqual(updated["OPENAI_MODEL"], "openai-keep")
    }
}
