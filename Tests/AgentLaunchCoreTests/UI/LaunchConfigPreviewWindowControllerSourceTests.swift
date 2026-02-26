import Foundation
import XCTest

final class LaunchConfigPreviewWindowControllerSourceTests: XCTestCase {
    func testWindowUsesStartupLogTitleAndStrongForegroundPresentation() throws {
        let source = try String(contentsOf: sourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("window.title = \"Agent 启动日志\""),
            "Preview window title should match startup-log naming."
        )
        XCTAssertTrue(
            source.contains("window.level = .floating"),
            "Preview window should float above the menu panel so clicks appear effective."
        )
        XCTAssertTrue(
            source.contains("window.orderFrontRegardless()"),
            "Preview window should force itself to front to avoid appearing non-responsive."
        )
    }

    private func sourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // UI
            .deletingLastPathComponent() // AgentLaunchCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Repository root
            .appendingPathComponent("Sources/AIAgentLaunch/UI/LaunchConfigPreviewWindowController.swift")
    }
}
