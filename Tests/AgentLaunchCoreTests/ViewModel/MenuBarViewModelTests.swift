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

    func testPersistsAPIKeyToKeychainStoreAfterSuccessfulConnectionTest() async {
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

    func testShowsKeychainLoadErrorInStatusMessageAfterPanelAppear() async {
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
        XCTAssertTrue(viewModel.statusMessage?.contains("Keychain error") == true)
        XCTAssertTrue(viewModel.statusMessage?.contains("-25308") == true)
    }

    func testShowsKeychainSaveErrorInStatusMessageWhenPersistingAfterSuccessfulConnectionTest() async {
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
        XCTAssertTrue(viewModel.statusMessage?.contains("Keychain error") == true)
        XCTAssertTrue(viewModel.statusMessage?.contains("-25308") == true)
    }

    func testDoesNotPersistAPIKeyWhenConnectionTestFails() async {
        let apiKeyStore = InMemoryAPIKeyStore(storedAPIKey: "sk-old")
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .failure(ModelDiscoveryServiceError.unauthorized)),
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
            modelDiscovery: StubModelDiscovery(result: .failure(ModelDiscoveryServiceError.unauthorized)),
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

    func testLaunchInOriginalModeSkipsProxyPath() async {
        let router = SpyLaunchRouter()
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
        XCTAssertEqual(router.launchProxyCallCount, 0)
        XCTAssertEqual(viewModel.state, .idle)
    }

    func testLaunchInProxyModePassesCurrentConfiguration() async {
        let router = SpyLaunchRouter()
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
    }

    func testSuccessfulProxyLaunchStoresMergedConfigForInspection() async {
        let mergedConfigurationForInspection = """
        profile = "merged"

        [profiles.merged]
        model = "gpt-5.3-codex"
        """
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
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
        XCTAssertTrue(viewModel.canInspectLastLaunchConfigTOML)
    }

    func testSuccessfulOriginalLaunchClearsTemporaryConfigInspectionState() async {
        let router = SpyLaunchRouter()
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
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"
        viewModel.selectedModel = "gpt-5"
        viewModel.models = ["gpt-5"]
        await viewModel.launchSelectedAgent()
        XCTAssertNotNil(viewModel.lastLaunchedProxyConfigTOML)

        viewModel.mode = .original
        await viewModel.launchSelectedAgent()

        XCTAssertEqual(router.launchOriginalCallCount, 1)
        XCTAssertNil(viewModel.lastLaunchedProxyConfigTOML)
        XCTAssertFalse(viewModel.canInspectLastLaunchConfigTOML)
    }

    func testLaunchFailureInProxyModeTransitionsToLaunchFailedState() async {
        let router = SpyLaunchRouter(proxyLaunchError: StubLaunchError.failed)
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
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-test"
        viewModel.selectedModel = "gpt-5"
        viewModel.models = ["gpt-5"]

        await viewModel.launchSelectedAgent()

        XCTAssertEqual(viewModel.state, .launchFailed)
        XCTAssertTrue(viewModel.statusMessage?.contains("Launch failed") == true)
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
    private(set) var lastProxyConfiguration: AgentProxyLaunchConfig?
    private let originalLaunchError: Error?
    private let proxyLaunchError: Error?
    private let proxyLaunchMergedConfiguration: String?

    init(
        originalLaunchError: Error? = nil,
        proxyLaunchError: Error? = nil,
        proxyLaunchMergedConfiguration: String? = nil
    ) {
        self.originalLaunchError = originalLaunchError
        self.proxyLaunchError = proxyLaunchError
        self.proxyLaunchMergedConfiguration = proxyLaunchMergedConfiguration
    }

    func launchOriginalMode() async throws {
        launchOriginalCallCount += 1
        if let originalLaunchError {
            throw originalLaunchError
        }
    }

    func launchProxyMode(configuration: AgentProxyLaunchConfig) async throws -> String {
        launchProxyCallCount += 1
        lastProxyConfiguration = configuration
        if let proxyLaunchError {
            throw proxyLaunchError
        }
        if let proxyLaunchMergedConfiguration {
            return proxyLaunchMergedConfiguration
        }
        return AgentConfigRenderer().renderTemporaryConfiguration(from: configuration)
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
