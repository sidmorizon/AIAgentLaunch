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
}
