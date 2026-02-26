import XCTest
@testable import AgentLaunchCore

final class UpdateAvailabilityHintTests: XCTestCase {
    func testInlineTextForIdleIsNil() {
        XCTAssertNil(UpdateAvailabilityHint.idle.inlineText)
    }

    func testInlineTextForCheckingShowsCheckingMessage() {
        XCTAssertEqual(UpdateAvailabilityHint.checking.inlineText, "正在检查更新…")
    }

    func testInlineTextForUpdateAvailableIncludesVersion() {
        XCTAssertEqual(
            UpdateAvailabilityHint.updateAvailable(version: "0.1.4").inlineText,
            "有新版本可升级"
        )
    }

    func testInlineTextForUpdateAvailableFallsBackWhenVersionIsBlank() {
        XCTAssertEqual(
            UpdateAvailabilityHint.updateAvailable(version: "  ").inlineText,
            "有新版本可升级"
        )
    }

    func testInlineTextForUpToDateShowsLatestMessage() {
        XCTAssertEqual(UpdateAvailabilityHint.upToDate.inlineText, "已是最新版本")
    }

    func testInlineTextForFailedShowsRetryMessage() {
        XCTAssertEqual(UpdateAvailabilityHint.failed.inlineText, "检测失败，请稍后再试")
    }

    func testToneForCheckingIsInfo() {
        XCTAssertEqual(UpdateAvailabilityHint.checking.tone, .info)
    }

    func testToneForUpdateAvailableIsWarning() {
        XCTAssertEqual(UpdateAvailabilityHint.updateAvailable(version: "0.1.4").tone, .warning)
    }

    func testToneForUpToDateIsSuccess() {
        XCTAssertEqual(UpdateAvailabilityHint.upToDate.tone, .success)
    }

    func testToneForFailedIsError() {
        XCTAssertEqual(UpdateAvailabilityHint.failed.tone, .error)
    }
}
