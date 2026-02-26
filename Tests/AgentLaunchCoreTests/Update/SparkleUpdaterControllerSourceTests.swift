import Foundation
import XCTest

final class SparkleUpdaterControllerSourceTests: XCTestCase {
    func testInitializationTriggersSilentUpdateCheck() throws {
        let source = try String(contentsOf: sparkleUpdaterControllerSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("checkForUpdateInformationSilently()"),
            "Updater controller should trigger a silent update information check during startup."
        )
    }

    func testManualCheckFailureProvidesUserFacingAlertMessage() throws {
        let source = try String(contentsOf: sparkleUpdaterControllerSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("presentManualCheckFailureAlert"),
            "Manual update check should surface a user-facing alert when check is unavailable."
        )
        XCTAssertTrue(
            source.contains("无法检测升级"),
            "Failure alert should include a clear user-facing title."
        )
    }

    func testManualCheckNoUpdateMapsToUpToDateHint() throws {
        let source = try String(contentsOf: sparkleUpdaterControllerSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("isNoUpdateError"),
            "Manual check path should recognize Sparkle no-update errors and classify them."
        )
        XCTAssertTrue(
            source.contains("updateHint = .upToDate"),
            "Manual check no-update result should be reflected in menu hint text."
        )
    }

    func testDevelopmentBuildManualCheckShowsUnsupportedMessage() throws {
        let source = try String(contentsOf: sparkleUpdaterControllerSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("开发环境不支持检测"),
            "Development builds should show a clear unsupported message for manual update checks."
        )
    }

    func testInitializationRequiresCIBuildUpdateCheckMarker() throws {
        let source = try String(contentsOf: sparkleUpdaterControllerSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("AIAgentLaunchEnableUpdateChecks"),
            "Updater should require a CI build marker key before enabling Sparkle checks."
        )
        XCTAssertTrue(
            source.contains("isCIReleaseBuild"),
            "Updater initialization should gate Sparkle setup behind CI-release detection."
        )
    }

    private func sparkleUpdaterControllerSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Update
            .deletingLastPathComponent() // AgentLaunchCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Repository root
            .appendingPathComponent("Sources/AIAgentLaunch/Update/SparkleUpdaterController.swift")
    }
}
