import Foundation
import XCTest
@testable import AgentLaunchCore

@MainActor
final class DefaultMenuBarLaunchRouterTests: XCTestCase {
    func testLaunchOriginalModeCommentsOutProfileLineForAnyValue() async throws {
        let configurationFilePath = try makeTemporaryConfigFilePath()
        try """
        profile = "custom-profile"
        [profiles.custom-profile]
        model = "gpt-5"
        """.write(to: configurationFilePath, atomically: true, encoding: .utf8)

        let provider = StubProvider(configurationFilePath: configurationFilePath)
        let launcher = SpyLauncher()
        let router = DefaultMenuBarLaunchRouter(
            provider: provider,
            launcher: launcher,
            coordinator: AgentLaunchCoordinator(
                provider: provider,
                transaction: StubTransaction(),
                launcher: launcher,
                launchEventSource: StubLaunchEventSource(),
                launchTimeoutNanoseconds: 1_000_000
            )
        )

        try await router.launchOriginalMode()

        XCTAssertEqual(launcher.launchCount, 1)
        XCTAssertEqual(
            try String(contentsOf: configurationFilePath, encoding: .utf8),
            """
            # profile = "custom-profile"
            [profiles.custom-profile]
            model = "gpt-5"
            """
        )
    }

    private func makeTemporaryConfigFilePath() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let providerConfigDirectory = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: providerConfigDirectory, withIntermediateDirectories: true)
        return providerConfigDirectory.appendingPathComponent("config.toml", isDirectory: false)
    }
}

private struct StubProvider: AgentProviderBase {
    let providerIdentifier = "stub"
    let providerDisplayName = "Stub"
    let applicationBundleIdentifier = "com.example.stub"
    let configurationFilePath: URL
    let apiKeyEnvironmentVariableName = "OPENAI_API_KEY"

    func renderTemporaryConfiguration(from launchConfiguration: AgentProxyLaunchConfig) -> String {
        AgentConfigRenderer().renderTemporaryConfiguration(from: launchConfiguration)
    }
}

private final class SpyLauncher: AgentLaunching {
    private(set) var launchCount = 0

    func launchApplication(bundleIdentifier: String, environmentVariables: [String: String]) async throws {
        launchCount += 1
    }
}

private final class StubTransaction: ConfigurationTransactionHandling {
    func applyTemporaryConfiguration(_ temporaryConfiguration: String, at configurationFilePath: URL) throws -> String {
        temporaryConfiguration
    }

    func restoreOriginalConfiguration(at configurationFilePath: URL) throws {}
}

private final class StubLaunchEventSource: ProviderLaunchEventSource {
    func waitForLaunch(of bundleIdentifier: String, timeoutNanoseconds: UInt64) async {}
}
