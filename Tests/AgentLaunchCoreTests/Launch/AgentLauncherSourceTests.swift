import Foundation
import XCTest

final class AgentLauncherSourceTests: XCTestCase {
    func testLaunchUsesAsyncWorkspaceOpenApplicationAPI() throws {
        let source = try String(contentsOf: agentLauncherSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("try await workspace.openApplication(at: applicationURL, configuration: configuration)"),
            "AgentLauncher should use the async NSWorkspace open API to avoid actor-isolation crashes from callback queues."
        )
        XCTAssertFalse(
            source.contains("withCheckedThrowingContinuation"),
            "AgentLauncher should not bridge launch completion with continuations and callback closures."
        )
    }

    func testLaunchDoesNotUseStoredNSWorkspaceForAsyncOpenCall() throws {
        let source = try String(contentsOf: agentLauncherSourceURL(), encoding: .utf8)

        XCTAssertFalse(
            source.contains("private let workspace: NSWorkspace"),
            "Storing NSWorkspace on a main-actor isolated launcher can trigger strict-concurrency data-race diagnostics in CI."
        )
        XCTAssertTrue(
            source.contains("let workspace = NSWorkspace.shared"),
            "Launcher should resolve NSWorkspace locally before performing async open calls."
        )
    }

    private func agentLauncherSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Launch
            .deletingLastPathComponent() // AgentLaunchCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Repository root
            .appendingPathComponent("Sources/AgentLaunchCore/Launch/AgentLauncher.swift")
    }
}
