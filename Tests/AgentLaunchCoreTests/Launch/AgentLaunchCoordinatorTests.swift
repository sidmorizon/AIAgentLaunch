import Foundation
import XCTest
@testable import AgentLaunchCore

@MainActor
final class AgentLaunchCoordinatorTests: XCTestCase {
    func testLaunchSuccessRestoresAfterLaunchNotification() async throws {
        let provider = StubProvider()
        let transaction = SpyConfigTransaction()
        let launcher = StubAgentLauncher()
        let eventSource = StubLaunchEventSource(mode: .didLaunch)
        let coordinator = AgentLaunchCoordinator(
            provider: provider,
            transaction: transaction,
            launcher: launcher,
            launchEventSource: eventSource,
            launchTimeoutNanoseconds: 1_000_000
        )

        try await coordinator.launchWithTemporaryConfiguration(makeLaunchConfiguration())

        XCTAssertEqual(transaction.applyCount, 1)
        XCTAssertEqual(transaction.restoreCount, 1)
        XCTAssertEqual(launcher.launchCount, 1)
        XCTAssertEqual(eventSource.waitCount, 1)
    }

    func testLaunchFailureStillRestores() async throws {
        let provider = StubProvider()
        let transaction = SpyConfigTransaction()
        let launcher = StubAgentLauncher(shouldThrow: true)
        let eventSource = StubLaunchEventSource(mode: .didLaunch)
        let coordinator = AgentLaunchCoordinator(
            provider: provider,
            transaction: transaction,
            launcher: launcher,
            launchEventSource: eventSource,
            launchTimeoutNanoseconds: 1_000_000
        )

        do {
            try await coordinator.launchWithTemporaryConfiguration(makeLaunchConfiguration())
            XCTFail("Expected launch error")
        } catch is StubLaunchError {
            XCTAssertEqual(transaction.applyCount, 1)
            XCTAssertEqual(transaction.restoreCount, 1)
            XCTAssertEqual(eventSource.waitCount, 0)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testLaunchRestoreFallbackTimeout() async throws {
        let provider = StubProvider()
        let transaction = SpyConfigTransaction()
        let launcher = StubAgentLauncher()
        let eventSource = StubLaunchEventSource(mode: .timeout)
        let coordinator = AgentLaunchCoordinator(
            provider: provider,
            transaction: transaction,
            launcher: launcher,
            launchEventSource: eventSource,
            launchTimeoutNanoseconds: 2_000_000
        )

        try await coordinator.launchWithTemporaryConfiguration(makeLaunchConfiguration())

        XCTAssertEqual(transaction.applyCount, 1)
        XCTAssertEqual(transaction.restoreCount, 1)
        XCTAssertEqual(eventSource.waitCount, 1)
    }

    private func makeLaunchConfiguration() -> AgentProxyLaunchConfig {
        AgentProxyLaunchConfig(
            apiBaseURL: URL(string: "https://example.com/v1")!,
            providerAPIKey: "sk-test",
            modelIdentifier: "gpt-5",
            reasoningLevel: .medium
        )
    }
}

private struct StubProvider: AgentProviderBase {
    let providerIdentifier = "stub"
    let providerDisplayName = "Stub"
    let applicationBundleIdentifier = "com.example.stub"
    let configurationFilePath = URL(fileURLWithPath: "/tmp/stub-config.toml")

    func renderTemporaryConfiguration(from launchConfiguration: AgentProxyLaunchConfig) -> String {
        AgentConfigRenderer().renderTemporaryConfiguration(from: launchConfiguration)
    }
}

private final class SpyConfigTransaction: ConfigurationTransactionHandling {
    private(set) var applyCount = 0
    private(set) var restoreCount = 0

    func applyTemporaryConfiguration(_ temporaryConfiguration: String, at configurationFilePath: URL) throws {
        applyCount += 1
    }

    func restoreOriginalConfiguration(at configurationFilePath: URL) throws {
        restoreCount += 1
    }
}

private enum StubLaunchError: Error {
    case failed
}

private final class StubAgentLauncher: AgentLaunching {
    private(set) var launchCount = 0
    private let shouldThrow: Bool

    init(shouldThrow: Bool = false) {
        self.shouldThrow = shouldThrow
    }

    func launchApplication(bundleIdentifier: String) throws {
        launchCount += 1
        if shouldThrow {
            throw StubLaunchError.failed
        }
    }
}

private final class StubLaunchEventSource: ProviderLaunchEventSource {
    enum Mode {
        case didLaunch
        case timeout
    }

    private(set) var waitCount = 0
    private let mode: Mode

    init(mode: Mode) {
        self.mode = mode
    }

    func waitForLaunch(of bundleIdentifier: String, timeoutNanoseconds: UInt64) async {
        waitCount += 1
        if mode == .timeout {
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
        }
    }
}
