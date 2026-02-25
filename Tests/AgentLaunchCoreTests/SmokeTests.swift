import XCTest
@testable import AgentLaunchCore

final class SmokeTests: XCTestCase {
    func testCoreModuleLoads() {
        XCTAssertEqual(agentLaunchCoreVersion(), "0.1.0")
    }
}
