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

        XCTAssertTrue(renderedConfiguration.contains("base_url = \"https://example.com/v1\""))
        XCTAssertTrue(renderedConfiguration.contains("api_key = \"sk-test\""))
        XCTAssertTrue(renderedConfiguration.contains("model = \"gpt-5\""))
        XCTAssertTrue(renderedConfiguration.contains("model_reasoning_effort = \"medium\""))
    }
}
