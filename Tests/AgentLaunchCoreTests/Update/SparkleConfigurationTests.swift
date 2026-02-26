import XCTest
@testable import AgentLaunchCore

final class SparkleConfigurationTests: XCTestCase {
    func testCanEnableUpdaterReturnsTrueWhenFeedAndPublicKeyArePresent() {
        let info: [String: Any] = [
            "SUFeedURL": "https://example.com/appcast.xml",
            "SUPublicEDKey": "public-key"
        ]

        XCTAssertTrue(SparkleConfiguration.canEnableUpdater(infoDictionary: info))
    }

    func testCanEnableUpdaterReturnsFalseWhenPublicKeyIsMissing() {
        let info: [String: Any] = [
            "SUFeedURL": "https://example.com/appcast.xml"
        ]

        XCTAssertFalse(SparkleConfiguration.canEnableUpdater(infoDictionary: info))
    }

    func testCanEnableUpdaterReturnsFalseWhenFeedURLIsMissing() {
        let info: [String: Any] = [
            "SUPublicEDKey": "public-key"
        ]

        XCTAssertFalse(SparkleConfiguration.canEnableUpdater(infoDictionary: info))
    }

    func testCanEnableUpdaterReturnsFalseWhenValuesAreWhitespaceOnly() {
        let info: [String: Any] = [
            "SUFeedURL": "   ",
            "SUPublicEDKey": "\n\t"
        ]

        XCTAssertFalse(SparkleConfiguration.canEnableUpdater(infoDictionary: info))
    }
}
