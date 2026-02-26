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

        XCTAssertTrue(renderedConfiguration.contains("profile = \"1k\""))
        XCTAssertTrue(renderedConfiguration.contains("[profiles.1k]"))
        XCTAssertTrue(renderedConfiguration.contains("model_provider = \"1k\""))
        XCTAssertTrue(renderedConfiguration.contains("base_url = \"https://example.com/v1\""))
        XCTAssertTrue(renderedConfiguration.contains("name = \"CLIProxyOneKey\""))
        XCTAssertTrue(renderedConfiguration.contains("wire_api = \"responses\""))
        XCTAssertTrue(renderedConfiguration.contains("env_key= \"OPENAI_API_KEY\""))
        XCTAssertTrue(renderedConfiguration.contains("model = \"gpt-5\""))
        XCTAssertTrue(renderedConfiguration.contains("model_reasoning_effort = \"medium\""))
        XCTAssertFalse(renderedConfiguration.contains("api_key ="))
    }

    func testRenderProxyConfigMapsHighReasoningToXHigh() {
        let launchConfiguration = AgentProxyLaunchConfig(
            apiBaseURL: URL(string: "https://example.com/v1")!,
            providerAPIKey: "sk-test",
            modelIdentifier: "gpt-5.3-codex",
            reasoningLevel: .high
        )

        let renderedConfiguration = AgentConfigRenderer().renderTemporaryConfiguration(from: launchConfiguration)

        XCTAssertTrue(renderedConfiguration.contains("model_reasoning_effort = \"xhigh\""))
    }
}
