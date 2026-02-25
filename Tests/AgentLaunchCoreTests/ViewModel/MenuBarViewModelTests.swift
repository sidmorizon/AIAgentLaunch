import Foundation
import XCTest
@testable import AgentLaunchCore

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    func testProxyModeRequiresFieldsBeforeLaunchEnabled() {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(),
            launchRouter: SpyLaunchRouter()
        )

        viewModel.mode = .proxy
        viewModel.baseURLText = ""
        viewModel.apiKeyMasked = ""
        viewModel.selectedModel = ""

        XCTAssertFalse(viewModel.canLaunch)

        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"
        viewModel.selectedModel = "gpt-5"

        XCTAssertTrue(viewModel.canLaunch)
    }

    func testLaunchInOriginalModeSkipsTransaction() async throws {
        let router = SpyLaunchRouter()
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(),
            launchRouter: router
        )
        viewModel.mode = .original

        await viewModel.launchSelectedAgent()

        XCTAssertEqual(router.launchOriginalCallCount, 1)
        XCTAssertEqual(router.launchProxyCallCount, 0)
    }
}

private struct StubModelDiscovery: ModelDiscovering {
    func fetchModels(apiBaseURL: URL, providerAPIKey: String) async throws -> [String] {
        ["gpt-5"]
    }
}

private final class SpyLaunchRouter: MenuBarLaunchRouting {
    private(set) var launchOriginalCallCount = 0
    private(set) var launchProxyCallCount = 0

    func launchOriginalMode() async throws {
        launchOriginalCallCount += 1
    }

    func launchProxyMode(configuration: AgentProxyLaunchConfig) async throws {
        launchProxyCallCount += 1
    }
}
