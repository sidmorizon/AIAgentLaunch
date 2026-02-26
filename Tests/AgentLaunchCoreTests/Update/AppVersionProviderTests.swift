import Foundation
import XCTest
@testable import AgentLaunchCore

final class AppVersionProviderTests: XCTestCase {
    func testCurrentVersionPrefersEnvironmentValue() {
        let provider = AppVersionProvider(
            bundle: .main,
            environment: ["AIAgentLaunch_VERSION": "1.2.3"],
            currentDirectoryPath: FileManager.default.currentDirectoryPath,
            fileManager: .default
        )

        XCTAssertEqual(provider.currentVersion(), "1.2.3")
    }

    func testCurrentVersionReadsVersionFileFromWorkingDirectoryWhenEnvironmentMissing() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        try "2.0.1\n".write(
            to: tempDirectory.appendingPathComponent("version", isDirectory: false),
            atomically: true,
            encoding: .utf8
        )

        let provider = AppVersionProvider(
            bundle: .main,
            environment: [:],
            currentDirectoryPath: tempDirectory.path,
            fileManager: .default
        )

        XCTAssertEqual(provider.currentVersion(), "2.0.1")
    }

    func testCurrentVersionFallsBackToCoreVersionWhenNoVersionSourceExists() {
        let provider = AppVersionProvider(
            bundle: .main,
            environment: [:],
            currentDirectoryPath: "/path/that/does/not/exist",
            fileManager: .default
        )

        XCTAssertEqual(provider.currentVersion(), agentLaunchCoreVersion())
    }
}
