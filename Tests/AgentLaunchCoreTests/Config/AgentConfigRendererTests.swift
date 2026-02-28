import XCTest
@testable import AgentLaunchCore

final class AgentConfigRendererTests: XCTestCase {
    func testRenderProxyConfigContainsRequiredFields() {
        let launchConfiguration = AgentProxyLaunchConfig(
            apiBaseURL: URL(string: "https://example.com/v1")!,
            providerAPIKey: "sk-test",
            modelIdentifier: "gpt-5",
            reasoningLevel: .medium
        )

        let renderedConfiguration = AgentConfigRenderer().renderTemporaryConfiguration(from: launchConfiguration)

        XCTAssertTrue(renderedConfiguration.contains("profile = \"\(AgentProxyConfigDefaults.profileIdentifier)\""))
        XCTAssertTrue(renderedConfiguration.contains("[profiles.\(AgentProxyConfigDefaults.profileIdentifier)]"))
        XCTAssertTrue(renderedConfiguration.contains("model_provider = \"\(AgentProxyConfigDefaults.profileIdentifier)\""))
        XCTAssertTrue(renderedConfiguration.contains("base_url = \"https://example.com/v1\""))
        XCTAssertTrue(renderedConfiguration.contains("name = \"\(AgentProxyConfigDefaults.providerDisplayName)\""))
        XCTAssertTrue(renderedConfiguration.contains("wire_api = \"responses\""))
        XCTAssertTrue(renderedConfiguration.contains("model = \"gpt-5\""))
        XCTAssertTrue(renderedConfiguration.contains("model_reasoning_effort = \"medium\""))
        XCTAssertFalse(renderedConfiguration.contains("env_key"))
        XCTAssertFalse(renderedConfiguration.contains("api_key ="))
    }

    func testRenderProxyConfigKeepsHighReasoningEffort() {
        let launchConfiguration = AgentProxyLaunchConfig(
            apiBaseURL: URL(string: "https://example.com/v1")!,
            providerAPIKey: "sk-test",
            modelIdentifier: "gpt-5.3-codex",
            reasoningLevel: .high
        )

        let renderedConfiguration = AgentConfigRenderer().renderTemporaryConfiguration(from: launchConfiguration)

        XCTAssertTrue(renderedConfiguration.contains("model_reasoning_effort = \"high\""))
    }

    func testRenderProxyConfigSupportsXHighReasoningEffort() {
        let launchConfiguration = AgentProxyLaunchConfig(
            apiBaseURL: URL(string: "https://example.com/v1")!,
            providerAPIKey: "sk-test",
            modelIdentifier: "gpt-5.3-codex",
            reasoningLevel: .xhigh
        )

        let renderedConfiguration = AgentConfigRenderer().renderTemporaryConfiguration(from: launchConfiguration)

        XCTAssertTrue(renderedConfiguration.contains("model_reasoning_effort = \"xhigh\""))
    }
}
