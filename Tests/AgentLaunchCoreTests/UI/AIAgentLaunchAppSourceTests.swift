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
            source.contains("MenuBarContentView(") &&
                source.contains("launchConfigPreviewWindowController: launchConfigPreviewWindowController"),
            "MenuBar content should receive the shared preview controller from app scope."
        )
    }

    func testAppOwnsSharedProfileManagementWindowController() throws {
        let source = try String(contentsOf: appSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("@StateObject private var profileManagementWindowController = APIProfileManagementWindowController()"),
            "App should own one shared API profile management window controller."
        )
        XCTAssertTrue(
            source.contains("profileManagementWindowController: profileManagementWindowController"),
            "MenuBar content should receive shared profile management window controller."
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
