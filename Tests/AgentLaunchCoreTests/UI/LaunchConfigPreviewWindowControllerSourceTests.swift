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

    func testPreviewWindowProvidesCopyClaudeCLICommandAction() throws {
        let source = try String(contentsOf: sourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("inspectionPayload: LaunchInspectionPayload"),
            "Preview window should consume structured launch inspection payloads."
        )
        XCTAssertTrue(
            source.contains("inspectionSection(title: \"config.toml\""),
            "Preview window should show a dedicated config.toml section."
        )
        XCTAssertTrue(
            source.contains("inspectionSection(title: \"启动环境变量\""),
            "Preview window should show a dedicated launch environment section."
        )
        XCTAssertTrue(
            source.contains("if shouldShowCodexConfigSection"),
            "Preview window should hide config section for Claude launches without config content."
        )
        XCTAssertTrue(
            source.contains("ScrollView {\n                VStack(alignment: .leading, spacing: 12)"),
            "Preview window content should support vertical scrolling when sections overflow."
        )
        XCTAssertTrue(
            source.contains("ScrollView([.vertical])"),
            "Each inspection section should have its own internal vertical scrolling."
        )
        XCTAssertTrue(
            source.contains("maxHeight: LaunchConfigPreviewWindowLayout.inspectionSectionMaxHeight"),
            "Inspection section content should cap height and scroll internally."
        )
        XCTAssertTrue(
            source.contains(".frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)"),
            "Preview window scroll container should expand to fill available window height."
        )
        XCTAssertTrue(
            source.contains("Button(\"复制 Claude CLI 命令\")"),
            "Preview window should expose a direct action to copy Claude CLI startup command."
        )
        XCTAssertTrue(
            source.contains("NSPasteboard.general"),
            "Preview window copy action should write the command into the system pasteboard."
        )
    }

    func testPreviewWindowIncludesFourModelDropdownsForCLIOverrides() throws {
        let source = try String(contentsOf: sourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("title: Self.opusModelKey"),
            "Preview window should include an Opus model dropdown above copy action."
        )
        XCTAssertTrue(
            source.contains("title: Self.sonnetModelKey"),
            "Preview window should include a Sonnet model dropdown above copy action."
        )
        XCTAssertTrue(
            source.contains("title: Self.haikuModelKey"),
            "Preview window should include a Haiku model dropdown above copy action."
        )
        XCTAssertTrue(
            source.contains("title: Self.subagentModelKey"),
            "Preview window should include a subagent model dropdown above copy action."
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
