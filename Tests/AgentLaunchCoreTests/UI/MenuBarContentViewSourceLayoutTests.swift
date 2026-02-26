import Foundation
import XCTest

final class MenuBarContentViewSourceLayoutTests: XCTestCase {
    func testHeaderMenuUsesCompactIconAndIndicatorLayout() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("Image(systemName: \"chevron.down\")"),
            "Header menu should render a compact chevron indicator next to the ellipsis icon."
        )
        XCTAssertTrue(
            source.contains(".menuIndicator(.hidden)"),
            "Default menu indicator should be hidden to avoid large spacing between icon and arrow."
        )
    }

    func testCheckForUpdatesMenuItemIsAlwaysEnabled() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertFalse(
            source.contains(".disabled(!sparkleUpdaterController.canCheckForUpdates)"),
            "Manual update check should remain clickable even when updater state is unavailable."
        )
    }

    private func menuBarContentViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // UI
            .deletingLastPathComponent() // AgentLaunchCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Repository root
            .appendingPathComponent("Sources/AIAgentLaunch/UI/MenuBarContentView.swift")
    }
}
