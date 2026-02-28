import Foundation
import XCTest
@testable import AgentLaunchCore

@MainActor
final class DefaultMenuBarLaunchRouterTests: XCTestCase {
    func testLaunchOriginalModeCommentsOutProfileLineForAnyValue() async throws {
        let paths = try makeTemporaryProviderPaths()
        try """
        profile = "custom-profile"
        [profiles.custom-profile]
        model = "gpt-5"
        """.write(to: paths.configurationFilePath, atomically: true, encoding: .utf8)

        let provider = StubProvider(paths: paths)
        let launcher = SpyLauncher()
        let transaction = SpyTransaction()
        let router = DefaultMenuBarLaunchRouter(
            provider: provider,
            launcher: launcher,
            coordinator: AgentLaunchCoordinator(
                provider: provider,
                transaction: transaction,
                launcher: launcher,
                launchEventSource: StubLaunchEventSource(),
                launchTimeoutNanoseconds: 1_000_000
            )
        )

        let launchedConfiguration = try await router.launchOriginalMode(agent: .codex)

        XCTAssertEqual(launcher.launchCount, 1)
        XCTAssertEqual(launcher.lastBundleIdentifier, provider.applicationBundleIdentifier)
        XCTAssertTrue(launcher.lastEnvironmentVariables?.isEmpty == true)
        XCTAssertEqual(transaction.applyCount, 0)
        XCTAssertEqual(
            try String(contentsOf: paths.configurationFilePath, encoding: .utf8),
            """
            # profile = "custom-profile"
            [profiles.custom-profile]
            model = "gpt-5"
            """
        )
        XCTAssertEqual(
            launchedConfiguration,
            """
            # profile = "custom-profile"
            [profiles.custom-profile]
            model = "gpt-5"
            """
        )
    }

    func testLaunchOriginalModeRestoresExistingAuthFileBeforeLaunch() async throws {
        let paths = try makeTemporaryProviderPaths()
        let originalAuthText = """
        {
          "auth_mode": "device",
          "token": "persist-me"
        }
        """
        try originalAuthText.write(to: paths.authFilePath, atomically: true, encoding: .utf8)

        let authTransaction = CodexAuthTransaction()
        try authTransaction.applyProxyAuthentication(
            apiKey: "sk-test-12345678",
            at: paths.authFilePath,
            backupFilePath: paths.authBackupFilePath
        )

        let provider = StubProvider(paths: paths)
        let router = DefaultMenuBarLaunchRouter(
            provider: provider,
            launcher: SpyLauncher(),
            authTransaction: authTransaction
        )

        _ = try await router.launchOriginalMode(agent: .codex)

        XCTAssertEqual(try String(contentsOf: paths.authFilePath, encoding: .utf8), originalAuthText)
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.authBackupFilePath.path))
    }

    func testLaunchOriginalModeDeletesAuthFileWhenOriginalWasAbsent() async throws {
        let paths = try makeTemporaryProviderPaths()
        let authTransaction = CodexAuthTransaction()
        try authTransaction.applyProxyAuthentication(
            apiKey: "sk-test-12345678",
            at: paths.authFilePath,
            backupFilePath: paths.authBackupFilePath
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.authFilePath.path))

        let provider = StubProvider(paths: paths)
        let router = DefaultMenuBarLaunchRouter(
            provider: provider,
            launcher: SpyLauncher(),
            authTransaction: authTransaction
        )

        _ = try await router.launchOriginalMode(agent: .codex)

        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.authFilePath.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.authBackupFilePath.path))
    }

    func testLaunchProxyModeForClaudeInjectsEnvironmentAndSkipsCodexTransaction() async throws {
        let paths = try makeTemporaryProviderPaths()
        let provider = StubProvider(paths: paths)
        let launcher = SpyLauncher()
        let transaction = SpyTransaction()
        let router = DefaultMenuBarLaunchRouter(
            provider: provider,
            launcher: launcher,
            coordinator: AgentLaunchCoordinator(
                provider: provider,
                transaction: transaction,
                launcher: launcher,
                launchEventSource: StubLaunchEventSource(),
                launchTimeoutNanoseconds: 1_000_000
            )
        )
        let configuration = AgentProxyLaunchConfig(
            apiBaseURL: URL(string: "https://example.com/v1")!,
            providerAPIKey: "sk-test-12345678",
            modelIdentifier: "claude-sonnet-4-5",
            reasoningLevel: .high
        )

        let launchLog = try await router.launchProxyMode(agent: .claude, configuration: configuration)

        XCTAssertEqual(launcher.launchCount, 1)
        XCTAssertEqual(launcher.lastBundleIdentifier, AgentTarget.claude.applicationBundleIdentifier)
        XCTAssertEqual(launcher.lastEnvironmentVariables?["ANTHROPIC_API_KEY"], "sk-test-12345678")
        XCTAssertEqual(launcher.lastEnvironmentVariables?["OPENAI_API_KEY"], "sk-test-12345678")
        XCTAssertEqual(launcher.lastEnvironmentVariables?["ANTHROPIC_BASE_URL"], "https://example.com/v1")
        XCTAssertEqual(launcher.lastEnvironmentVariables?["OPENAI_BASE_URL"], "https://example.com/v1")
        XCTAssertEqual(launcher.lastEnvironmentVariables?["ANTHROPIC_DEFAULT_OPUS_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(launcher.lastEnvironmentVariables?["ANTHROPIC_DEFAULT_SONNET_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(launcher.lastEnvironmentVariables?["ANTHROPIC_DEFAULT_HAIKU_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(launcher.lastEnvironmentVariables?["CLAUDE_CODE_SUBAGENT_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(launcher.lastEnvironmentVariables?["ANTHROPIC_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(launcher.lastEnvironmentVariables?["OPENAI_MODEL"], "claude-sonnet-4-5")
        XCTAssertEqual(launcher.lastEnvironmentVariables?["ANTHROPIC_REASONING_EFFORT"], "high")
        XCTAssertEqual(launcher.lastEnvironmentVariables?["OPENAI_REASONING_EFFORT"], "high")
        XCTAssertEqual(transaction.applyCount, 0)
        XCTAssertFalse(launchLog.contains("sk-test-12345678"))
        XCTAssertTrue(launchLog.contains("ANTHROPIC_API_KEY = \"sk-t********5678\""))
    }

    private func makeTemporaryProviderPaths() throws -> StubProvider.Paths {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let providerConfigDirectory = root.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: providerConfigDirectory, withIntermediateDirectories: true)
        return .init(
            configurationFilePath: providerConfigDirectory.appendingPathComponent("config.toml", isDirectory: false),
            authFilePath: providerConfigDirectory.appendingPathComponent("auth.json", isDirectory: false),
            authBackupFilePath: providerConfigDirectory.appendingPathComponent("auth.json.ai-agent-launch.backup", isDirectory: false)
        )
    }
}

private struct StubProvider: AgentProviderBase {
    struct Paths {
        let configurationFilePath: URL
        let authFilePath: URL
        let authBackupFilePath: URL
    }

    let providerIdentifier = "stub"
    let providerDisplayName = "Stub"
    let applicationBundleIdentifier = "com.example.stub"
    let configurationFilePath: URL
    let authFilePath: URL
    let authBackupFilePath: URL
    let apiKeyEnvironmentVariableName = AgentProxyConfigDefaults.apiKeyEnvironmentVariableName

    init(paths: Paths) {
        configurationFilePath = paths.configurationFilePath
        authFilePath = paths.authFilePath
        authBackupFilePath = paths.authBackupFilePath
    }

    func renderTemporaryConfiguration(from launchConfiguration: AgentProxyLaunchConfig) -> String {
        AgentConfigRenderer().renderTemporaryConfiguration(from: launchConfiguration)
    }
}

private final class SpyLauncher: AgentLaunching {
    private(set) var launchCount = 0
    private(set) var lastBundleIdentifier: String?
    private(set) var lastEnvironmentVariables: [String: String]?

    func launchApplication(bundleIdentifier: String, environmentVariables: [String: String]) async throws {
        launchCount += 1
        lastBundleIdentifier = bundleIdentifier
        lastEnvironmentVariables = environmentVariables
    }
}

private final class SpyTransaction: ConfigurationTransactionHandling {
    private(set) var applyCount = 0

    func applyTemporaryConfiguration(_ temporaryConfiguration: String, at configurationFilePath: URL) throws -> String {
        applyCount += 1
        return temporaryConfiguration
    }

    func restoreOriginalConfiguration(at configurationFilePath: URL) throws {}
}

private final class StubLaunchEventSource: ProviderLaunchEventSource {
    func waitForLaunch(of bundleIdentifier: String, timeoutNanoseconds: UInt64) async {}
}
