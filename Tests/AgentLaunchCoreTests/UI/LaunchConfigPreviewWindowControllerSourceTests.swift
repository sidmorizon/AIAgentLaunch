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
            source.contains("inspectionSection(title: \"config.toml\", text: renderedCodexConfigTOMLText)"),
            "Preview window should show a dedicated config.toml section."
        )
        XCTAssertTrue(
            source.contains("inspectionSection(title: \"启动环境变量\", text: renderedLaunchEnvironmentText)"),
            "Preview window should show a dedicated launch environment section."
        )
        XCTAssertTrue(
            source.contains("if shouldShowCodexConfigSection"),
            "Preview window should hide config section for Claude launches without config content."
        )
        XCTAssertTrue(
            source.contains("ScrollView {"),
            "Preview window content should support vertical scrolling when sections overflow."
        )
        XCTAssertTrue(
            source.contains("LazyVStack("),
            "Preview window content should support vertical scrolling when sections overflow."
        )
        XCTAssertTrue(
            source.contains("Divider()"),
            "Preview window should separate content and footer actions."
        )
        XCTAssertTrue(
            source.contains("ScrollView([.vertical])"),
            "Each inspection section should have its own internal vertical scrolling."
        )
        XCTAssertTrue(
            source.contains("private struct LaunchInspectionTextSection: View"),
            "Inspection text areas should share a reusable section component."
        )
        XCTAssertTrue(
            source.contains("LaunchInspectionTextSection("),
            "Inspection sections should be rendered through the shared component."
        )
        XCTAssertTrue(
            source.contains("minHeight: LaunchConfigPreviewWindowLayout.inspectionSectionMinHeight"),
            "Inspection sections should share a unified minimum height configuration."
        )
        XCTAssertTrue(
            source.contains("LaunchConfigPreviewWindowLayout.inspectionSectionMaxHeight"),
            "Inspection sections should share a unified maximum height configuration."
        )
        XCTAssertTrue(
            source.contains("return min(max(estimatedContentHeight, minHeight), maxHeight)"),
            "Inspection section should keep height within a shared min/max range."
        )
        XCTAssertTrue(
            source.contains(".frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)"),
            "Preview window content area should grow to fill available space without adding footer gaps."
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
