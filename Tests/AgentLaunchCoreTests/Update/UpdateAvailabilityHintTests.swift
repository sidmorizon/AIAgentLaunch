import XCTest
@testable import AgentLaunchCore

final class UpdateAvailabilityHintTests: XCTestCase {
    func testInlineTextForIdleIsNil() {
        XCTAssertNil(UpdateAvailabilityHint.idle.inlineText)
    }

    func testInlineTextForCheckingShowsCheckingMessage() {
        XCTAssertEqual(UpdateAvailabilityHint.checking.inlineText, "正在检查新版本…")
    }

    func testInlineTextForUpdateAvailableIncludesVersion() {
        XCTAssertEqual(
            UpdateAvailabilityHint.updateAvailable(version: "0.1.4").inlineText,
            "发现新版本 v0.1.4"
        )
    }

    func testInlineTextForUpdateAvailableFallsBackWhenVersionIsBlank() {
        XCTAssertEqual(
            UpdateAvailabilityHint.updateAvailable(version: "  ").inlineText,
            "发现新版本"
        )
    }

    func testInlineTextForUpToDateShowsLatestMessage() {
        XCTAssertEqual(UpdateAvailabilityHint.upToDate.inlineText, "当前已是最新版本")
    }

    func testInlineTextForFailedShowsRetryMessage() {
        XCTAssertEqual(UpdateAvailabilityHint.failed.inlineText, "未能获取更新信息")
    }
}
