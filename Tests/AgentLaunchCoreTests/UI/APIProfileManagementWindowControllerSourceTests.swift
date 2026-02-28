import Foundation
import XCTest

final class APIProfileManagementWindowControllerSourceTests: XCTestCase {
    func testProfileManagementWindowControllerExistsAndUsesIndependentWindow() throws {
        let source = try String(contentsOf: sourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("final class APIProfileManagementWindowController: ObservableObject"),
            "Profile management should use a dedicated window controller."
        )
        XCTAssertTrue(
            source.contains("private var managementWindowControllers: [NSWindowController] = []"),
            "Controller should track independently opened management window controllers."
        )
        XCTAssertTrue(
            source.contains("window.title = \"API 管理\""),
            "Management window should expose stable title."
        )
        XCTAssertTrue(
            source.contains("let windowController = makeWindowController(viewModel: viewModel)"),
            "Each open action should create a brand new management window controller."
        )
        XCTAssertTrue(
            source.contains("windowController.showWindow(nil)"),
            "Management window should be presented via NSWindowController to survive menu lifecycle transitions."
        )
        XCTAssertTrue(
            source.contains("window.makeMain()"),
            "Management window should explicitly become main window to receive keyboard focus."
        )
    }

    func testProfileManagementWindowContainsCRUDAndConnectionTestActions() throws {
        let source = try String(contentsOf: sourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("Button(\"新增\")"),
            "Management window should expose add-profile action."
        )
        XCTAssertTrue(
            source.contains("setActive: false"),
            "Add action should not switch current active profile."
        )
        XCTAssertTrue(
            source.contains("Button(isTestingDraftConnection ? \"TESTING...\" : \"测试连接\")"),
            "Management window should expose draft connection test action."
        )
        XCTAssertFalse(
            source.contains("Button(\"设为当前\")"),
            "Management window should not render separate set-active button in row trailing area."
        )
        XCTAssertTrue(
            source.contains("Button(action: {"),
            "Management window should make leading circle clickable for set-active action."
        )
        XCTAssertTrue(
            source.contains("try viewModel.selectActiveProfile(profile.id)"),
            "Leading-circle action should target row profile directly."
        )
        XCTAssertTrue(
            source.contains(".buttonStyle(.plain)"),
            "Leading-circle active switcher should use plain button style."
        )
        XCTAssertTrue(
            source.contains(".frame(width: 30, height: 30)"),
            "Leading-circle switcher should use larger hit area."
        )
        XCTAssertTrue(
            source.contains(".frame(minHeight: 30)"),
            "Profile row height should match enlarged leading-circle switcher."
        )
        XCTAssertTrue(
            source.contains(".disabled(viewModel.activeProfileID == profile.id)"),
            "Leading-circle switcher should be disabled for current active profile."
        )
        XCTAssertFalse(
            source.contains("onClose()"),
            "Set-active action should not close management window."
        )
        XCTAssertTrue(
            source.contains("Button(\"删除\")"),
            "Management window should expose delete action."
        )
        XCTAssertTrue(
            source.contains(".tint(.red)"),
            "Delete action should be rendered in red."
        )
        XCTAssertTrue(
            source.contains(".focused($isNameFieldFocused)"),
            "Name field should bind focus state for immediate keyboard input."
        )
        XCTAssertTrue(
            source.contains(".onChange(of: selectedProfileID)"),
            "Selecting a profile should hydrate editor fields for read/update flow."
        )
        XCTAssertTrue(
            source.contains(".onChange(of: newProfileName)"),
            "Editing profile name should trigger auto-save flow."
        )
        XCTAssertTrue(
            source.contains("try viewModel.updateProfile("),
            "Management window should auto-save profile updates without explicit save button."
        )
        XCTAssertTrue(
            source.contains("selectedProfileID = nil"),
            "Add action should reset current selection."
        )
        XCTAssertTrue(
            source.contains("clearEditor()"),
            "Add action should clear editor fields for the next input."
        )
        let apiKeyFieldRange = source.range(of: "MenuBarField(\"API KEY\")")
        let connectionButtonRange = source.range(of: "Button(isTestingDraftConnection ? \"TESTING...\" : \"测试连接\")")
        XCTAssertNotNil(apiKeyFieldRange, "Management window should include API KEY editor field.")
        XCTAssertNotNil(connectionButtonRange, "Management window should include connection test action.")
        if let apiKeyFieldRange, let connectionButtonRange {
            XCTAssertTrue(
                apiKeyFieldRange.upperBound <= connectionButtonRange.lowerBound,
                "Connection test action should be rendered below the form fields."
            )
            guard let spacerRange = source.range(
                of: "Spacer()",
                range: connectionButtonRange.upperBound ..< source.endIndex
            ) else {
                XCTFail("Expected trailing spacer in connection action row.")
                return
            }
            let connectionRowSegment = source[connectionButtonRange.upperBound ..< spacerRange.lowerBound]
            XCTAssertTrue(
                connectionRowSegment.contains("if let draftTestMessage"),
                "Connection result should render on the right side of the connection button in the same row."
            )
        }
        XCTAssertFalse(
            source.contains("Button(\"保存修改\")"),
            "Management window should not require manual save action."
        )
        XCTAssertFalse(
            source.contains("Button(\"新建\")"),
            "Management window should keep a single add entry point."
        )
    }

    private func sourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // UI
            .deletingLastPathComponent() // AgentLaunchCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Repository root
            .appendingPathComponent("Sources/AIAgentLaunch/UI/APIProfileManagementWindowController.swift")
    }
}
