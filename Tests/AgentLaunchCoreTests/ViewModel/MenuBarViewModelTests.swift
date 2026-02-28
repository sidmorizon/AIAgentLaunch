import Foundation
import XCTest
@testable import AgentLaunchCore

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    func testHydratesPersistedConfigurationOnInitWithoutLoadingAPIKey() {
        let settingsStore = InMemorySettingsStore(
            persistedSettings: MenuBarPersistedSettings(
                mode: .original,
                baseURLText: "https://persisted.example.com/v1",
                selectedModel: "gpt-5.3-codex",
                reasoningLevel: .high
            )
        )
        let apiKeyStore = InMemoryAPIKeyStore(storedAPIKey: "sk-persisted")
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: settingsStore,
            apiKeyStore: apiKeyStore
        )

        XCTAssertEqual(viewModel.mode, .original)
        XCTAssertEqual(viewModel.baseURLText, "https://persisted.example.com/v1")
        XCTAssertEqual(viewModel.selectedModel, "gpt-5.3-codex")
        XCTAssertEqual(viewModel.reasoningLevel, .high)
        XCTAssertEqual(viewModel.apiKeyMasked, "")
        XCTAssertEqual(apiKeyStore.loadCallCount, 0)
    }

    func testPreparesProxyContextOnPanelAppearLoadsAPIKeyAndAutoTestsConnection() async {
        let apiKeyStore = InMemoryAPIKeyStore(storedAPIKey: "sk-persisted")
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-4.1", "gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "https://persisted.example.com/v1",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: apiKeyStore
        )

        XCTAssertEqual(viewModel.apiKeyMasked, "")
        XCTAssertEqual(apiKeyStore.loadCallCount, 0)

        await viewModel.handlePanelPresented()

        XCTAssertEqual(apiKeyStore.loadCallCount, 1)
        XCTAssertEqual(viewModel.apiKeyMasked, "sk-persisted")
        XCTAssertEqual(viewModel.state, .testSuccess)
        XCTAssertEqual(viewModel.models, ["gpt-4.1", "gpt-5"])
        XCTAssertEqual(viewModel.selectedModel, "gpt-4.1")
    }

    func testPanelAppearSkipsProxyPreparationWhenModeIsOriginal() async {
        let apiKeyStore = InMemoryAPIKeyStore(storedAPIKey: "sk-persisted")
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-4.1", "gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .original,
                    baseURLText: "https://persisted.example.com/v1",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: apiKeyStore
        )

        await viewModel.handlePanelPresented()

        XCTAssertEqual(apiKeyStore.loadCallCount, 0)
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(viewModel.models.isEmpty)
    }

    func testPersistsPlaintextFieldsWhenValuesChange() {
        let settingsStore = InMemorySettingsStore(
            persistedSettings: MenuBarPersistedSettings(
                mode: .proxy,
                baseURLText: "",
                selectedModel: "",
                reasoningLevel: .medium
            )
        )
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: settingsStore,
            apiKeyStore: InMemoryAPIKeyStore()
        )

        viewModel.mode = .original
        viewModel.baseURLText = "https://local.example.com/v1"
        viewModel.selectedModel = "gpt-5.3-codex"
        viewModel.reasoningLevel = .low

        XCTAssertEqual(
            settingsStore.saveCalls.last,
            MenuBarPersistedSettings(
                mode: .original,
                baseURLText: "https://local.example.com/v1",
                selectedModel: "gpt-5.3-codex",
                reasoningLevel: .low
            )
        )
    }

    func testPersistsAPIKeyToLocalStoreAfterSuccessfulConnectionTest() async {
        let apiKeyStore = InMemoryAPIKeyStore()
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: apiKeyStore
        )

        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-updated"
        XCTAssertTrue(apiKeyStore.saveCalls.isEmpty)

        await viewModel.testConnection()

        XCTAssertEqual(apiKeyStore.saveCalls.last, "sk-updated")
    }

    func testShowsStorageLoadErrorInStatusMessageAfterPanelAppear() async {
        let apiKeyStore = InMemoryAPIKeyStore(
            storedAPIKey: nil,
            loadError: KeychainAPIError.unexpectedStatus(-25308)
        )
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: apiKeyStore
        )

        await viewModel.handlePanelPresented()

        XCTAssertTrue(viewModel.isStatusError)
        XCTAssertTrue(viewModel.statusMessage?.contains("Storage error") == true)
        XCTAssertTrue(viewModel.statusMessage?.contains("-25308") == true)
    }

    func testShowsStorageSaveErrorInStatusMessageWhenPersistingAfterSuccessfulConnectionTest() async {
        let apiKeyStore = InMemoryAPIKeyStore(
            storedAPIKey: nil,
            saveError: KeychainAPIError.unexpectedStatus(-25308)
        )
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: apiKeyStore
        )

        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-updated"
        await viewModel.testConnection()

        XCTAssertTrue(viewModel.isStatusError)
        XCTAssertTrue(viewModel.statusMessage?.contains("Storage error") == true)
        XCTAssertTrue(viewModel.statusMessage?.contains("-25308") == true)
    }

    func testDoesNotPersistAPIKeyWhenConnectionTestFails() async {
        let apiKeyStore = InMemoryAPIKeyStore(storedAPIKey: "sk-old")
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .failure(ModelDiscoveryServiceError.unauthorized())),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: apiKeyStore
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-new"

        XCTAssertTrue(apiKeyStore.saveCalls.isEmpty)

        await viewModel.testConnection()

        XCTAssertEqual(viewModel.state, .testFailed)
        XCTAssertTrue(apiKeyStore.saveCalls.isEmpty)
        XCTAssertEqual(apiKeyStore.storedAPIKey, "sk-old")
    }

    func testDefaultModeIsProxy() {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )

        XCTAssertEqual(viewModel.mode, .proxy)
    }

    func testProxyModeRequiresFieldsBeforeLaunchEnabled() {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )

        viewModel.mode = .proxy
        viewModel.baseURLText = ""
        viewModel.apiKeyMasked = ""
        viewModel.selectedModel = ""

        XCTAssertFalse(viewModel.canLaunch)
        XCTAssertFalse(viewModel.canTestConnection)

        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"
        viewModel.selectedModel = "gpt-5"
        viewModel.models = ["gpt-5"]

        XCTAssertTrue(viewModel.canLaunch)
        XCTAssertTrue(viewModel.canTestConnection)
    }

    func testProxyModeAllowsEmptyAPIKey() {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )

        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = ""
        viewModel.selectedModel = "gpt-5"
        viewModel.models = ["gpt-5"]

        XCTAssertNil(viewModel.apiKeyValidationMessage)
        XCTAssertTrue(viewModel.canTestConnection)
        XCTAssertTrue(viewModel.canLaunch)
    }

    func testProxyModeDisablesLaunchWhenModelSelectionIsUnavailable() {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "https://example.com/v1",
                    selectedModel: "gpt-5",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.apiKeyMasked = "sk-test"

        XCTAssertFalse(viewModel.isModelSelectionEnabled)
        XCTAssertFalse(viewModel.canLaunch)
    }

    func testProxyModeRejectsBaseURLWithoutHTTPScheme() {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )

        viewModel.mode = .proxy
        viewModel.baseURLText = "example.com/v1"
        viewModel.apiKeyMasked = "sk-test"
        viewModel.selectedModel = "gpt-5"

        XCTAssertFalse(viewModel.canLaunch)
        XCTAssertFalse(viewModel.canTestConnection)
        XCTAssertNotNil(viewModel.baseURLValidationMessage)
    }

    func testModelSelectionStaysDisabledUntilModelsLoaded() async {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success([])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"

        XCTAssertFalse(viewModel.isModelSelectionEnabled)

        await viewModel.testConnection()

        XCTAssertFalse(viewModel.isModelSelectionEnabled)
        XCTAssertFalse(viewModel.canLaunch)
    }

    func testTestConnectionSuccessLoadsModelsAndTransitionsToSuccessState() async {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-4.1", "gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com"
        viewModel.apiKeyMasked = "sk-test"

        await viewModel.testConnection()

        XCTAssertEqual(viewModel.state, .testSuccess)
        XCTAssertEqual(viewModel.models, ["gpt-4.1", "gpt-5"])
        XCTAssertEqual(viewModel.selectedModel, "gpt-4.1")
        XCTAssertTrue(viewModel.isModelSelectionEnabled)
    }

    func testTestConnectionFailureTransitionsToFailedState() async {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .failure(ModelDiscoveryServiceError.unauthorized())),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"

        await viewModel.testConnection()

        XCTAssertEqual(viewModel.state, .testFailed)
        XCTAssertTrue(viewModel.statusMessage?.contains("401") == true)
    }

    func testTestConnectionFailureUsesRawServerErrorMessage() async {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .failure(ModelDiscoveryServiceError.unauthorized(message: "API key missing"))),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = ""

        await viewModel.testConnection()

        XCTAssertEqual(viewModel.state, .testFailed)
        XCTAssertEqual(viewModel.statusMessage, "Connection failed: API key missing")
    }

    func testLaunchInOriginalModeSkipsProxyPath() async {
        let router = SpyLaunchRouter()
        let validator = SpyLaunchConfigurationValidator()
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchConfigurationValidator: validator,
            launchRouter: router,
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .original

        await viewModel.launchSelectedAgent()

        XCTAssertEqual(router.launchOriginalCallCount, 1)
        XCTAssertEqual(router.launchProxyCallCount, 0)
        XCTAssertEqual(validator.validateCallCount, 0)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testLaunchClaudeInOriginalModeRoutesToClaudeOriginalOnly() async {
        let router = SpyLaunchRouter()
        let validator = SpyLaunchConfigurationValidator()
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchConfigurationValidator: validator,
            launchRouter: router,
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .original

        await viewModel.launchSelectedAgent(.claude)

        XCTAssertEqual(router.launchOriginalByAgent[.claude], 1)
        XCTAssertEqual(router.launchOriginalByAgent[.codex], nil)
        XCTAssertEqual(router.launchProxyCallCount, 0)
        XCTAssertEqual(validator.validateCallCount, 0)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testLaunchInProxyModeValidatesAndPassesCurrentConfiguration() async {
        let router = SpyLaunchRouter()
        let validator = SpyLaunchConfigurationValidator()
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchConfigurationValidator: validator,
            launchRouter: router,
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"
        viewModel.selectedModel = "gpt-5"
        viewModel.reasoningLevel = .high
        viewModel.models = ["gpt-5"]

        await viewModel.launchSelectedAgent()

        XCTAssertEqual(router.launchOriginalCallCount, 0)
        XCTAssertEqual(router.launchProxyCallCount, 1)
        XCTAssertEqual(router.lastProxyConfiguration?.apiBaseURL.absoluteString, "https://example.com/v1")
        XCTAssertEqual(router.lastProxyConfiguration?.providerAPIKey, "sk-test")
        XCTAssertEqual(router.lastProxyConfiguration?.modelIdentifier, "gpt-5")
        XCTAssertEqual(router.lastProxyConfiguration?.reasoningLevel, .high)
        XCTAssertEqual(validator.validateCallCount, 1)
        XCTAssertEqual(validator.lastConfiguration?.apiBaseURL.absoluteString, "https://example.com/v1")
        XCTAssertEqual(validator.lastConfiguration?.providerAPIKey, "sk-test")
        XCTAssertEqual(validator.lastConfiguration?.modelIdentifier, "gpt-5")
        XCTAssertEqual(validator.lastConfiguration?.reasoningLevel, .high)
    }

    func testLaunchClaudeInProxyModeValidatesAndPassesCurrentConfiguration() async {
        let router = SpyLaunchRouter()
        let validator = SpyLaunchConfigurationValidator()
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchConfigurationValidator: validator,
            launchRouter: router,
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"
        viewModel.selectedModel = "claude-sonnet-4-5"
        viewModel.reasoningLevel = .high
        viewModel.models = ["claude-sonnet-4-5"]

        await viewModel.launchSelectedAgent(.claude)

        XCTAssertEqual(router.launchProxyByAgent[.claude], 1)
        XCTAssertEqual(router.launchProxyByAgent[.codex], nil)
        XCTAssertEqual(validator.validateCallCount, 1)
        XCTAssertEqual(router.lastProxyConfiguration?.modelIdentifier, "claude-sonnet-4-5")
    }

    func testSuccessfulClaudeProxyLaunchBuildsCopyableClaudeCLICommand() async {
        let router = SpyLaunchRouter()
        let validator = SpyLaunchConfigurationValidator()
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["claude-sonnet-4-5"])),
            launchConfigurationValidator: validator,
            launchRouter: router,
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"
        viewModel.selectedModel = "claude-sonnet-4-5"
        viewModel.reasoningLevel = .high
        viewModel.models = ["claude-sonnet-4-5"]

        await viewModel.launchSelectedAgent(.claude)

        XCTAssertEqual(router.launchProxyByAgent[.claude], 1)
        XCTAssertEqual(validator.validateCallCount, 1)
        XCTAssertEqual(
            viewModel.lastClaudeCLICommandText,
            "ANTHROPIC_API_KEY='sk-test' ANTHROPIC_BASE_URL='https://example.com/v1' ANTHROPIC_DEFAULT_HAIKU_MODEL='claude-sonnet-4-5' ANTHROPIC_DEFAULT_OPUS_MODEL='claude-sonnet-4-5' ANTHROPIC_DEFAULT_SONNET_MODEL='claude-sonnet-4-5' ANTHROPIC_MODEL='claude-sonnet-4-5' ANTHROPIC_REASONING_EFFORT='high' CLAUDE_CODE_SUBAGENT_MODEL='claude-sonnet-4-5' OPENAI_API_KEY='sk-test' OPENAI_BASE_URL='https://example.com/v1' OPENAI_MODEL='claude-sonnet-4-5' OPENAI_REASONING_EFFORT='high' OPEN_BY_AI_AGENT_LAUNCH='true' claude"
        )
        XCTAssertEqual(
            viewModel.lastClaudeCLIEnvironmentVariables?["ANTHROPIC_DEFAULT_OPUS_MODEL"],
            "claude-sonnet-4-5"
        )
        XCTAssertEqual(
            viewModel.lastClaudeCLIEnvironmentVariables?["CLAUDE_CODE_SUBAGENT_MODEL"],
            "claude-sonnet-4-5"
        )
        XCTAssertEqual(
            viewModel.lastClaudeCLIEnvironmentVariables?["OPEN_BY_AI_AGENT_LAUNCH"],
            "true"
        )
    }

    func testCanLaunchClaudeIsFalseWhenClaudeNotInstalled() {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(installedAgents: [.codex]),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .original,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )

        XCTAssertTrue(viewModel.canLaunchCodex)
        XCTAssertFalse(viewModel.canLaunchClaude)
    }

    func testSuccessfulProxyLaunchStoresMergedConfigForInspection() async {
        let mergedConfigurationForInspection = """
        profile = "merged"

        [profiles.merged]
        model = "gpt-5.3-codex"
        """
        let validator = SpyLaunchConfigurationValidator()
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchConfigurationValidator: validator,
            launchRouter: SpyLaunchRouter(proxyLaunchMergedConfiguration: mergedConfigurationForInspection),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"
        viewModel.selectedModel = "gpt-5"
        viewModel.reasoningLevel = .high
        viewModel.models = ["gpt-5"]

        await viewModel.launchSelectedAgent()

        XCTAssertEqual(viewModel.lastLaunchedProxyConfigTOML, mergedConfigurationForInspection)
        XCTAssertEqual(viewModel.lastLaunchInspectionPayload?.codexConfigTOMLText, mergedConfigurationForInspection)
        XCTAssertTrue(viewModel.canInspectLastLaunchConfigTOML)
    }

    func testSuccessfulOriginalLaunchStoresConfigForInspection() async {
        let originalConfigurationForInspection = """
        # profile = "legacy"

        [profiles.legacy]
        model = "gpt-5"
        """
        let router = SpyLaunchRouter(
            originalLaunchConfiguration: originalConfigurationForInspection
        )
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: router,
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .original
        await viewModel.launchSelectedAgent()

        XCTAssertEqual(router.launchOriginalCallCount, 1)
        XCTAssertEqual(viewModel.lastLaunchedProxyConfigTOML, originalConfigurationForInspection)
        XCTAssertEqual(viewModel.lastLaunchInspectionPayload?.codexConfigTOMLText, originalConfigurationForInspection)
        XCTAssertTrue(viewModel.canInspectLastLaunchConfigTOML)
    }

    func testLaunchFailureInProxyModeTransitionsToLaunchFailedState() async {
        let router = SpyLaunchRouter(proxyLaunchError: StubLaunchError.failed)
        let validator = SpyLaunchConfigurationValidator()
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchConfigurationValidator: validator,
            launchRouter: router,
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"
        viewModel.selectedModel = "gpt-5"
        viewModel.models = ["gpt-5"]

        await viewModel.launchSelectedAgent()

        XCTAssertEqual(viewModel.state, .launchFailed)
        XCTAssertTrue(viewModel.statusMessage?.contains("Launch failed") == true)
    }

    func testLaunchPrecheckFailureStopsProxyLaunchAndShowsError() async {
        let validator = SpyLaunchConfigurationValidator(
            result: .failure(LaunchConfigurationValidationError.rejected("reasoning effort is not supported for model"))
        )
        let router = SpyLaunchRouter()
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchConfigurationValidator: validator,
            launchRouter: router,
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            apiKeyStore: InMemoryAPIKeyStore()
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"
        viewModel.selectedModel = "gpt-5"
        viewModel.reasoningLevel = .high
        viewModel.models = ["gpt-5"]

        await viewModel.launchSelectedAgent()

        XCTAssertEqual(validator.validateCallCount, 1)
        XCTAssertEqual(router.launchProxyCallCount, 0)
        XCTAssertEqual(viewModel.state, .launchFailed)
        XCTAssertTrue(viewModel.statusMessage?.contains("Launch precheck failed") == true)
        XCTAssertTrue(viewModel.statusMessage?.contains("reasoning effort is not supported for model") == true)
    }
}

private enum StubLaunchError: Error {
    case failed
}

private struct StubModelDiscovery: ModelDiscovering {
    let result: Result<[String], Error>

    func fetchModels(apiBaseURL: URL, providerAPIKey: String) async throws -> [String] {
        try result.get()
    }
}

private final class SpyLaunchRouter: MenuBarLaunchRouting {
    private(set) var launchOriginalCallCount = 0
    private(set) var launchProxyCallCount = 0
    private(set) var launchOriginalByAgent: [AgentTarget: Int] = [:]
    private(set) var launchProxyByAgent: [AgentTarget: Int] = [:]
    private(set) var lastProxyConfiguration: AgentProxyLaunchConfig?
    private(set) var lastOriginalAgent: AgentTarget?
    private(set) var lastProxyAgent: AgentTarget?
    private let originalLaunchError: Error?
    private let originalLaunchConfiguration: String?
    private let proxyLaunchError: Error?
    private let proxyLaunchMergedConfiguration: String?
    private let installedAgents: Set<AgentTarget>

    init(
        originalLaunchError: Error? = nil,
        originalLaunchConfiguration: String? = nil,
        proxyLaunchError: Error? = nil,
        proxyLaunchMergedConfiguration: String? = nil,
        installedAgents: Set<AgentTarget> = Set(AgentTarget.allCases)
    ) {
        self.originalLaunchError = originalLaunchError
        self.originalLaunchConfiguration = originalLaunchConfiguration
        self.proxyLaunchError = proxyLaunchError
        self.proxyLaunchMergedConfiguration = proxyLaunchMergedConfiguration
        self.installedAgents = installedAgents
    }

    func launchOriginalMode() async throws -> LaunchInspectionPayload {
        try await launchOriginalMode(agent: .codex)
    }

    func launchProxyMode(configuration: AgentProxyLaunchConfig) async throws -> LaunchInspectionPayload {
        try await launchProxyMode(agent: .codex, configuration: configuration)
    }

    func isInstalled(agent: AgentTarget) -> Bool {
        installedAgents.contains(agent)
    }

    func launchOriginalMode(agent: AgentTarget) async throws -> LaunchInspectionPayload {
        launchOriginalCallCount += 1
        launchOriginalByAgent[agent, default: 0] += 1
        lastOriginalAgent = agent
        if let originalLaunchError {
            throw originalLaunchError
        }
        return LaunchInspectionPayload(
            agent: agent,
            codexConfigTOMLText: agent == .codex ? originalLaunchConfiguration : nil,
            launchEnvironmentVariables: [:]
        )
    }

    func launchProxyMode(agent: AgentTarget, configuration: AgentProxyLaunchConfig) async throws -> LaunchInspectionPayload {
        launchProxyCallCount += 1
        launchProxyByAgent[agent, default: 0] += 1
        lastProxyAgent = agent
        lastProxyConfiguration = configuration
        if let proxyLaunchError {
            throw proxyLaunchError
        }
        if agent == .claude {
            let environmentVariables = ClaudeLaunchEnvironment.makeProxyEnvironment(from: configuration)
            return LaunchInspectionPayload(
                agent: .claude,
                codexConfigTOMLText: nil,
                launchEnvironmentVariables: environmentVariables,
                claudeCLIEnvironmentVariables: environmentVariables
            )
        }
        let codexConfiguration = proxyLaunchMergedConfiguration ?? AgentConfigRenderer()
            .renderTemporaryConfiguration(from: configuration)
        return LaunchInspectionPayload(
            agent: .codex,
            codexConfigTOMLText: codexConfiguration,
            launchEnvironmentVariables: [:]
        )
    }
}

private final class SpyLaunchConfigurationValidator: LaunchConfigurationValidating {
    private(set) var validateCallCount = 0
    private(set) var lastConfiguration: AgentProxyLaunchConfig?
    private let result: Result<Void, Error>

    init(result: Result<Void, Error> = .success(())) {
        self.result = result
    }

    func validate(configuration: AgentProxyLaunchConfig) async throws {
        validateCallCount += 1
        lastConfiguration = configuration
        try result.get()
    }
}

private final class InMemorySettingsStore: MenuBarSettingsStoring {
    private(set) var persistedSettings: MenuBarPersistedSettings
    private(set) var saveCalls: [MenuBarPersistedSettings] = []

    init(persistedSettings: MenuBarPersistedSettings) {
        self.persistedSettings = persistedSettings
    }

    func loadSettings() -> MenuBarPersistedSettings {
        persistedSettings
    }

    func saveSettings(_ settings: MenuBarPersistedSettings) {
        persistedSettings = settings
        saveCalls.append(settings)
    }
}

private final class InMemoryAPIKeyStore: MenuBarAPIKeyStoring {
    private(set) var storedAPIKey: String?
    private(set) var saveCalls: [String] = []
    private(set) var loadCallCount = 0
    private let loadError: Error?
    private let saveError: Error?

    init(storedAPIKey: String? = nil, loadError: Error? = nil, saveError: Error? = nil) {
        self.storedAPIKey = storedAPIKey
        self.loadError = loadError
        self.saveError = saveError
    }

    func loadAPIKey() throws -> String? {
        loadCallCount += 1
        if let loadError {
            throw loadError
        }
        return storedAPIKey
    }

    func saveAPIKey(_ apiKey: String) throws {
        if let saveError {
            throw saveError
        }
        storedAPIKey = apiKey
        saveCalls.append(apiKey)
    }
}
