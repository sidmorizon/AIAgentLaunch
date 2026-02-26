import Foundation
import XCTest

final class SparkleUpdaterControllerSourceTests: XCTestCase {
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

    private func sparkleUpdaterControllerSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // Update
            .deletingLastPathComponent() // AgentLaunchCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Repository root
            .appendingPathComponent("Sources/AIAgentLaunch/Update/SparkleUpdaterController.swift")
    }
}
