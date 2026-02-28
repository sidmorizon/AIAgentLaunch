import Foundation
import XCTest
@testable import AgentLaunchCore

@MainActor
final class MenuBarViewModelTests: XCTestCase {
    func testNoProfilesShowsBootstrapProfileSetup() {
        let profileStore = InMemoryAPIProfileStore(profiles: [], activeProfileID: nil)
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
            profileStore: profileStore
        )

        XCTAssertTrue(viewModel.isBootstrapProfileSetup)
        XCTAssertTrue(viewModel.profiles.isEmpty)
        XCTAssertNil(viewModel.activeProfileID)
    }

    func testSaveBootstrapProfileAndActivateCreatesDefaultProfile() throws {
        let profileStore = InMemoryAPIProfileStore(profiles: [], activeProfileID: nil)
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
            profileStore: profileStore
        )
        viewModel.profileBaseURLInput = "https://bootstrap.example.com/v1"
        viewModel.profileAPIKeyInput = "sk-bootstrap"

        try viewModel.saveBootstrapProfileAndActivate()

        XCTAssertEqual(viewModel.profiles.count, 1)
        XCTAssertEqual(viewModel.profiles.first?.name, "默认配置")
        XCTAssertEqual(viewModel.activeProfileID, viewModel.profiles.first?.id)
        XCTAssertEqual(viewModel.baseURLText, "https://bootstrap.example.com/v1")
        XCTAssertEqual(viewModel.apiKeyMasked, "sk-bootstrap")
        XCTAssertFalse(viewModel.isBootstrapProfileSetup)
    }

    func testSelectActiveProfileLoadsBaseURLAndAPIKey() throws {
        let firstID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let secondID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let now = Date(timeIntervalSince1970: 1_740_000_000)
        let profiles = [
            APIProfile(
                id: firstID,
                name: "默认配置",
                baseURLText: "https://first.example.com/v1",
                apiKey: "sk-first",
                createdAt: now,
                updatedAt: now
            ),
            APIProfile(
                id: secondID,
                name: "预发布",
                baseURLText: "https://second.example.com/v1",
                apiKey: "sk-second",
                createdAt: now,
                updatedAt: now
            )
        ]
        let profileStore = InMemoryAPIProfileStore(profiles: profiles, activeProfileID: firstID)
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
            profileStore: profileStore
        )

        try viewModel.selectActiveProfile(secondID)

        XCTAssertEqual(viewModel.activeProfileID, secondID)
        XCTAssertEqual(viewModel.baseURLText, "https://second.example.com/v1")
        XCTAssertEqual(viewModel.apiKeyMasked, "sk-second")
    }

    func testSelectActiveProfileAndTestConnectionRunsConnectionCheck() async throws {
        let firstID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let secondID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let now = Date(timeIntervalSince1970: 1_740_000_000)
        let profiles = [
            APIProfile(
                id: firstID,
                name: "默认配置",
                baseURLText: "https://first.example.com/v1",
                apiKey: "sk-first",
                createdAt: now,
                updatedAt: now
            ),
            APIProfile(
                id: secondID,
                name: "预发布",
                baseURLText: "https://second.example.com/v1",
                apiKey: "sk-second",
                createdAt: now,
                updatedAt: now
            )
        ]
        let profileStore = InMemoryAPIProfileStore(profiles: profiles, activeProfileID: firstID)
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
            profileStore: profileStore
        )

        try await viewModel.selectActiveProfileAndTestConnection(secondID)

        XCTAssertEqual(viewModel.activeProfileID, secondID)
        XCTAssertEqual(viewModel.baseURLText, "https://second.example.com/v1")
        XCTAssertEqual(viewModel.apiKeyMasked, "sk-second")
        XCTAssertEqual(viewModel.state, .testSuccess)
        XCTAssertEqual(viewModel.models, ["gpt-4.1", "gpt-5"])
        XCTAssertEqual(viewModel.selectedModel, "gpt-4.1")
    }

    func testProfileCRUDFlowSupportsCreateReadUpdateDelete() throws {
        let defaultID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let now = Date(timeIntervalSince1970: 1_740_000_000)
        let profileStore = InMemoryAPIProfileStore(
            profiles: [
                APIProfile(
                    id: defaultID,
                    name: "默认配置",
                    baseURLText: "https://prod.example.com/v1",
                    apiKey: "sk-prod",
                    createdAt: now,
                    updatedAt: now
                )
            ],
            activeProfileID: defaultID
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
            profileStore: profileStore
        )

        try viewModel.addProfile(
            name: "预发布",
            baseURLText: "https://staging.example.com/v1",
            apiKey: "sk-staging",
            setActive: false
        )

        XCTAssertEqual(viewModel.profiles.count, 2)
        XCTAssertEqual(viewModel.activeProfileID, defaultID)
        guard let createdProfile = viewModel.profiles.first(where: { $0.name == "预发布" }) else {
            XCTFail("Expected created profile to exist")
            return
        }
        XCTAssertEqual(createdProfile.baseURLText, "https://staging.example.com/v1")
        XCTAssertEqual(createdProfile.apiKey, "sk-staging")

        try viewModel.selectActiveProfile(createdProfile.id)

        XCTAssertEqual(viewModel.activeProfileID, createdProfile.id)
        XCTAssertEqual(viewModel.baseURLText, "https://staging.example.com/v1")
        XCTAssertEqual(viewModel.apiKeyMasked, "sk-staging")

        try viewModel.updateProfile(
            createdProfile.id,
            name: "预发布-2",
            baseURLText: "https://staging2.example.com/v1",
            apiKey: "sk-staging-2"
        )

        let updatedProfile = viewModel.profiles.first(where: { $0.id == createdProfile.id })
        XCTAssertEqual(updatedProfile?.name, "预发布-2")
        XCTAssertEqual(updatedProfile?.baseURLText, "https://staging2.example.com/v1")
        XCTAssertEqual(updatedProfile?.apiKey, "sk-staging-2")
        XCTAssertEqual(viewModel.baseURLText, "https://staging2.example.com/v1")
        XCTAssertEqual(viewModel.apiKeyMasked, "sk-staging-2")

        try viewModel.deleteProfile(createdProfile.id)

        XCTAssertEqual(viewModel.profiles.count, 1)
        XCTAssertEqual(viewModel.profiles.first?.name, "默认配置")
        XCTAssertEqual(viewModel.activeProfileID, defaultID)
        XCTAssertEqual(viewModel.baseURLText, "https://prod.example.com/v1")
        XCTAssertEqual(viewModel.apiKeyMasked, "sk-prod")
    }

    func testSaveCurrentProfileEditsUpdatesNameBaseURLAndAPIKey() throws {
        let profileID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let now = Date(timeIntervalSince1970: 1_740_000_000)
        let profileStore = InMemoryAPIProfileStore(
            profiles: [
                APIProfile(
                    id: profileID,
                    name: "默认配置",
                    baseURLText: "https://old.example.com/v1",
                    apiKey: "sk-old",
                    createdAt: now,
                    updatedAt: now
                )
            ],
            activeProfileID: profileID
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
            profileStore: profileStore
        )

        viewModel.enterCurrentProfileEditing()
        viewModel.profileNameInput = "生产环境"
        viewModel.profileBaseURLInput = "https://new.example.com/v1"
        viewModel.profileAPIKeyInput = "sk-new"

        try viewModel.saveCurrentProfileEdits()

        XCTAssertEqual(viewModel.profiles.first?.name, "生产环境")
        XCTAssertEqual(viewModel.baseURLText, "https://new.example.com/v1")
        XCTAssertEqual(viewModel.apiKeyMasked, "sk-new")
        XCTAssertEqual(viewModel.profiles.first?.apiKey, "sk-new")
        XCTAssertFalse(viewModel.isEditingCurrentProfile)
    }

    func testUpdateProfileSupportsEditingNonActiveProfileFromManagementPanel() throws {
        let activeID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let targetID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let now = Date(timeIntervalSince1970: 1_740_000_000)
        let profileStore = InMemoryAPIProfileStore(
            profiles: [
                APIProfile(
                    id: activeID,
                    name: "默认配置",
                    baseURLText: "https://active.example.com/v1",
                    apiKey: "sk-active",
                    createdAt: now,
                    updatedAt: now
                ),
                APIProfile(
                    id: targetID,
                    name: "预发布",
                    baseURLText: "https://staging.example.com/v1",
                    apiKey: "sk-staging",
                    createdAt: now,
                    updatedAt: now
                )
            ],
            activeProfileID: activeID
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
            profileStore: profileStore
        )

        try viewModel.updateProfile(
            targetID,
            name: "预发布-2",
            baseURLText: "https://staging2.example.com/v1",
            apiKey: "sk-staging-2"
        )

        XCTAssertEqual(viewModel.activeProfileID, activeID)
        XCTAssertEqual(viewModel.baseURLText, "https://active.example.com/v1")
        XCTAssertEqual(viewModel.apiKeyMasked, "sk-active")
        let updated = viewModel.profiles.first { $0.id == targetID }
        XCTAssertEqual(updated?.name, "预发布-2")
        XCTAssertEqual(updated?.baseURLText, "https://staging2.example.com/v1")
        XCTAssertEqual(updated?.apiKey, "sk-staging-2")
    }

    func testDeleteAllProfilesReturnsToBootstrapStateWithNoData() throws {
        let profileID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let now = Date(timeIntervalSince1970: 1_740_000_000)
        let profileStore = InMemoryAPIProfileStore(
            profiles: [
                APIProfile(
                    id: profileID,
                    name: "默认配置",
                    baseURLText: "https://prod.example.com/v1",
                    apiKey: "sk-live",
                    createdAt: now,
                    updatedAt: now
                )
            ],
            activeProfileID: profileID
        )
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "",
                    selectedModel: "gpt-5",
                    reasoningLevel: .medium
                )
            ),
            profileStore: profileStore
        )
        viewModel.models = ["gpt-5"]

        try viewModel.deleteProfile(profileID)

        XCTAssertTrue(viewModel.profiles.isEmpty)
        XCTAssertNil(viewModel.activeProfileID)
        XCTAssertTrue(viewModel.isBootstrapProfileSetup)
        XCTAssertEqual(viewModel.baseURLText, "")
        XCTAssertEqual(viewModel.apiKeyMasked, "")
        XCTAssertEqual(viewModel.profileNameInput, "")
        XCTAssertEqual(viewModel.profileBaseURLInput, "")
        XCTAssertEqual(viewModel.profileAPIKeyInput, "")
        XCTAssertTrue(viewModel.models.isEmpty)
        XCTAssertEqual(viewModel.selectedModel, "")
    }

    func testMigratesLegacyConfigurationIntoDefaultProfileWhenNoProfilesExist() throws {
        let profileStore = InMemoryAPIProfileStore(profiles: [], activeProfileID: nil)
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "https://legacy.example.com/v1",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
            profileStore: profileStore
        )

        XCTAssertEqual(viewModel.profiles.count, 1)
        XCTAssertEqual(viewModel.profiles.first?.name, "默认配置")
        XCTAssertEqual(viewModel.activeProfileID, viewModel.profiles.first?.id)
        XCTAssertEqual(viewModel.baseURLText, "https://legacy.example.com/v1")
        XCTAssertEqual(viewModel.apiKeyMasked, "")
        guard let firstProfile = viewModel.profiles.first else {
            XCTFail("Expected migrated default profile to exist")
            return
        }
        XCTAssertEqual(firstProfile.apiKey, "")
    }

    func testLegacyMigrationIsIdempotentAcrossRepeatedInitializations() {
        let sharedProfileStore = InMemoryAPIProfileStore(profiles: [], activeProfileID: nil)
        let sharedSettingsStore = InMemorySettingsStore(
            persistedSettings: MenuBarPersistedSettings(
                mode: .proxy,
                baseURLText: "https://legacy.example.com/v1",
                selectedModel: "",
                reasoningLevel: .medium
            )
        )

        _ = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: sharedSettingsStore,
            profileStore: sharedProfileStore
        )
        let secondViewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: sharedSettingsStore,
            profileStore: sharedProfileStore
        )

        XCTAssertEqual(secondViewModel.profiles.count, 1)
    }

    func testHydratesPersistedConfigurationOnInit() {
        let settingsStore = InMemorySettingsStore(
            persistedSettings: MenuBarPersistedSettings(
                mode: .original,
                baseURLText: "https://persisted.example.com/v1",
                selectedModel: "gpt-5.3-codex",
                reasoningLevel: .high
            )
        )
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: settingsStore,
        )

        XCTAssertEqual(viewModel.mode, .original)
        XCTAssertEqual(viewModel.baseURLText, "https://persisted.example.com/v1")
        XCTAssertEqual(viewModel.selectedModel, "gpt-5.3-codex")
        XCTAssertEqual(viewModel.reasoningLevel, .high)
        XCTAssertEqual(viewModel.apiKeyMasked, "")
    }

    func testPreparesProxyContextOnPanelAppearAutoTestsConnection() async {
        let profileID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let now = Date(timeIntervalSince1970: 1_740_000_000)
        let profileStore = InMemoryAPIProfileStore(
            profiles: [
                APIProfile(
                    id: profileID,
                    name: "默认配置",
                    baseURLText: "https://persisted.example.com/v1",
                    apiKey: "sk-persisted",
                    createdAt: now,
                    updatedAt: now
                )
            ],
            activeProfileID: profileID
        )
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
            profileStore: profileStore
        )

        XCTAssertEqual(viewModel.apiKeyMasked, "sk-persisted")

        await viewModel.handlePanelPresented()

        XCTAssertEqual(viewModel.apiKeyMasked, "sk-persisted")
        XCTAssertEqual(viewModel.state, .testSuccess)
        XCTAssertEqual(viewModel.models, ["gpt-4.1", "gpt-5"])
        XCTAssertEqual(viewModel.selectedModel, "gpt-4.1")
    }

    func testPanelAppearSkipsProxyPreparationWhenModeIsOriginal() async {
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
        )

        await viewModel.handlePanelPresented()

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

    func testPersistsAPIKeyToActiveProfileAfterSuccessfulConnectionTest() async {
        let profileID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let now = Date(timeIntervalSince1970: 1_740_000_000)
        let profileStore = InMemoryAPIProfileStore(
            profiles: [
                APIProfile(
                    id: profileID,
                    name: "默认配置",
                    baseURLText: "https://example.com/v1",
                    apiKey: "sk-old",
                    createdAt: now,
                    updatedAt: now
                )
            ],
            activeProfileID: profileID
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
            profileStore: profileStore
        )

        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-updated"

        await viewModel.testConnection()

        XCTAssertEqual(viewModel.profiles.first?.apiKey, "sk-updated")
        XCTAssertEqual(profileStore.profiles.first?.apiKey, "sk-updated")
    }

    func testDoesNotPersistAPIKeyWhenConnectionTestFails() async {
        let profileID = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let now = Date(timeIntervalSince1970: 1_740_000_000)
        let profileStore = InMemoryAPIProfileStore(
            profiles: [
                APIProfile(
                    id: profileID,
                    name: "默认配置",
                    baseURLText: "https://example.com/v1",
                    apiKey: "sk-old",
                    createdAt: now,
                    updatedAt: now
                )
            ],
            activeProfileID: profileID
        )
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
            profileStore: profileStore
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://example.com/v1"
        viewModel.apiKeyMasked = "sk-new"

        await viewModel.testConnection()

        XCTAssertEqual(viewModel.state, .testFailed)
        XCTAssertEqual(profileStore.profiles.first?.apiKey, "sk-old")
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

    func testTestConnectionForProfileReturnsSuccessMessageWithoutMutatingMainState() async {
        let viewModel = MenuBarViewModel(
            modelDiscovery: StubModelDiscovery(result: .success(["gpt-4.1", "gpt-5"])),
            launchRouter: SpyLaunchRouter(),
            settingsStore: InMemorySettingsStore(
                persistedSettings: MenuBarPersistedSettings(
                    mode: .proxy,
                    baseURLText: "https://main.example.com/v1",
                    selectedModel: "",
                    reasoningLevel: .medium
                )
            ),
        )
        viewModel.mode = .proxy
        viewModel.baseURLText = "https://main.example.com/v1"
        viewModel.apiKeyMasked = "sk-main"

        let result = await viewModel.testConnectionForProfile(
            baseURLText: "https://profile.example.com/v1",
            apiKey: "sk-profile"
        )

        XCTAssertTrue(result.isSuccess)
        XCTAssertEqual(result.message, "Connected successfully.")
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(viewModel.models.isEmpty)
        XCTAssertEqual(viewModel.selectedModel, "")
        XCTAssertNil(viewModel.statusMessage)
        XCTAssertEqual(viewModel.baseURLText, "https://main.example.com/v1")
        XCTAssertEqual(viewModel.apiKeyMasked, "sk-main")
    }

    func testTestConnectionForProfileReturnsValidationMessageForInvalidBaseURL() async {
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
        )

        let result = await viewModel.testConnectionForProfile(
            baseURLText: "example.com/v1",
            apiKey: "sk-profile"
        )

        XCTAssertFalse(result.isSuccess)
        XCTAssertEqual(result.message, "Base URL must use http(s) and include a host.")
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertNil(viewModel.statusMessage)
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

private final class InMemoryAPIProfileStore: MenuBarAPIProfileStoring {
    private(set) var profiles: [APIProfile]
    private(set) var activeProfileID: UUID?

    init(profiles: [APIProfile], activeProfileID: UUID?) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
    }

    func loadProfiles() -> [APIProfile] {
        profiles
    }

    func saveProfiles(_ profiles: [APIProfile]) {
        self.profiles = profiles
    }

    func loadActiveProfileID() -> UUID? {
        activeProfileID
    }

    func saveActiveProfileID(_ profileID: UUID?) {
        activeProfileID = profileID
    }
}
