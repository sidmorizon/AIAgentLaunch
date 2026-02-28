import XCTest
@testable import AgentLaunchCore

final class LaunchEnvironmentSnapshotFormatterTests: XCTestCase {
    func testRenderMaskedSnapshotSortsKeys() {
        let snapshot = LaunchEnvironmentSnapshotFormatter.renderMaskedSnapshot(
            from: [
                "Z_VAR": "z",
                "A_VAR": "a",
            ]
        )

        XCTAssertEqual(
            snapshot,
            """
            A_VAR = "a"
            Z_VAR = "z"
            """
        )
    }

    func testRenderMaskedSnapshotMasksAPIKeyAndToken() {
        let snapshot = LaunchEnvironmentSnapshotFormatter.renderMaskedSnapshot(
            from: [
                "OPENAI_API_KEY": "abcd1234wxyz9876",
                "AUTH_TOKEN": "token-1234567890",
                "OPENAI_MODEL": "gpt-5",
            ]
        )

        XCTAssertFalse(snapshot.contains("abcd1234wxyz9876"))
        XCTAssertFalse(snapshot.contains("token-1234567890"))
        XCTAssertTrue(snapshot.contains("OPENAI_API_KEY = \"abcd********9876\""))
        XCTAssertTrue(snapshot.contains("AUTH_TOKEN = \"toke********7890\""))
        XCTAssertTrue(snapshot.contains("OPENAI_MODEL = \"gpt-5\""))
    }

    func testRenderMaskedSnapshotReturnsEmptyStringForEmptyEnvironment() {
        XCTAssertEqual(LaunchEnvironmentSnapshotFormatter.renderMaskedSnapshot(from: [:]), "")
    }
}
