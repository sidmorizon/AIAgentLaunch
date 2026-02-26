import Foundation
import XCTest

final class AIAgentLaunchAppSourceTests: XCTestCase {
    func testAppOwnsSharedLaunchConfigPreviewWindowController() throws {
        let source = try String(contentsOf: appSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("@StateObject private var launchConfigPreviewWindowController = LaunchConfigPreviewWindowController()"),
            "App should own one shared preview window controller so preview window outlives transient menu panel views."
        )
        XCTAssertTrue(
            source.contains("MenuBarContentView(launchConfigPreviewWindowController: launchConfigPreviewWindowController)"),
            "MenuBar content should receive the shared preview controller from app scope."
        )
    }

    private func appSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // UI
            .deletingLastPathComponent() // AgentLaunchCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Repository root
            .appendingPathComponent("Sources/AIAgentLaunch/AIAgentLaunchApp.swift")
    }
}
