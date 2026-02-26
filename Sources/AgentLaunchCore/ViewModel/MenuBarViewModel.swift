import Combine
import Foundation

@MainActor
public protocol ModelDiscovering {
    func fetchModels(apiBaseURL: URL, providerAPIKey: String) async throws -> [String]
}

@MainActor
extension ModelDiscoveryService: ModelDiscovering {}

@MainActor
public protocol MenuBarLaunchRouting {
    func launchOriginalMode() async throws
    func launchProxyMode(configuration: AgentProxyLaunchConfig) async throws -> String
}

public struct MenuBarPersistedSettings: Equatable, Sendable {
    public var mode: LaunchMode
    public var baseURLText: String
    public var selectedModel: String
    public var reasoningLevel: ReasoningEffort

    public init(mode: LaunchMode, baseURLText: String, selectedModel: String, reasoningLevel: ReasoningEffort) {
        self.mode = mode
        self.baseURLText = baseURLText
        self.selectedModel = selectedModel
        self.reasoningLevel = reasoningLevel
    }
}

public protocol MenuBarSettingsStoring {
    func loadSettings() -> MenuBarPersistedSettings
    func saveSettings(_ settings: MenuBarPersistedSettings)
}

public final class UserDefaultsMenuBarSettingsStore: MenuBarSettingsStoring {
    private enum Keys {
        static let mode = "menu_bar.mode"
        static let baseURLText = "menu_bar.base_url_text"
        static let selectedModel = "menu_bar.selected_model"
        static let reasoningLevel = "menu_bar.reasoning_level"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func loadSettings() -> MenuBarPersistedSettings {
        let mode = LaunchMode(rawValue: defaults.string(forKey: Keys.mode) ?? "") ?? .proxy
        let baseURLText = defaults.string(forKey: Keys.baseURLText) ?? ""
        let selectedModel = defaults.string(forKey: Keys.selectedModel) ?? ""
        let reasoningLevel = ReasoningEffort(rawValue: defaults.string(forKey: Keys.reasoningLevel) ?? "") ?? .medium
        return MenuBarPersistedSettings(
            mode: mode,
            baseURLText: baseURLText,
            selectedModel: selectedModel,
            reasoningLevel: reasoningLevel
        )
    }

    public func saveSettings(_ settings: MenuBarPersistedSettings) {
        defaults.set(settings.mode.rawValue, forKey: Keys.mode)
        defaults.set(settings.baseURLText, forKey: Keys.baseURLText)
        defaults.set(settings.selectedModel, forKey: Keys.selectedModel)
        defaults.set(settings.reasoningLevel.rawValue, forKey: Keys.reasoningLevel)
    }
}

public protocol MenuBarAPIKeyStoring {
    func loadAPIKey() throws -> String?
    func saveAPIKey(_ apiKey: String) throws
}

public final class KeychainMenuBarAPIKeyStore: MenuBarAPIKeyStoring {
    private let keychainService: KeychainService

    public init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
    }

    public func loadAPIKey() throws -> String? {
        try keychainService.readAPIKey()
    }

    public func saveAPIKey(_ apiKey: String) throws {
        try keychainService.saveAPIKey(apiKey)
    }
}

public enum MenuBarViewState: Equatable, Sendable {
    case idle
    case testing
    case testSuccess
    case testFailed
    case launching
    case launchFailed
}

@MainActor
public struct DefaultMenuBarLaunchRouter: MenuBarLaunchRouting {
    private let provider: any AgentProviderBase
    private let launcher: any AgentLaunching
    private let coordinator: AgentLaunchCoordinator
    private let fileManager: FileManager

    public init(
        provider: any AgentProviderBase = AgentProviderCodex(),
        launcher: any AgentLaunching = AgentLauncher(),
        coordinator: AgentLaunchCoordinator? = nil,
        fileManager: FileManager = .default
    ) {
        self.provider = provider
        self.launcher = launcher
        self.coordinator = coordinator ?? AgentLaunchCoordinator(provider: provider)
        self.fileManager = fileManager
    }

    public func launchOriginalMode() async throws {
        try commentOutProfileAssignmentIfNeeded(at: provider.configurationFilePath)
        try await launcher.launchApplication(
            bundleIdentifier: provider.applicationBundleIdentifier,
            environmentVariables: [:]
        )
    }

    public func launchProxyMode(configuration: AgentProxyLaunchConfig) async throws -> String {
        try await coordinator.launchWithTemporaryConfiguration(configuration)
    }

    private func commentOutProfileAssignmentIfNeeded(at configurationFilePath: URL) throws {
        guard fileManager.fileExists(atPath: configurationFilePath.path) else { return }

        let originalText = try String(contentsOf: configurationFilePath, encoding: .utf8)
        let hadTrailingNewline = originalText.hasSuffix("\n") || originalText.hasSuffix("\r\n")
        let normalizedLines = originalText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        var changed = false
        let updatedLines = normalizedLines.map { line -> String in
            guard let updatedLine = commentOutLineIfProfileAssignment(line) else { return line }
            changed = true
            return updatedLine
        }

        guard changed else { return }
        var updatedText = updatedLines.joined(separator: "\n")
        if hadTrailingNewline {
            updatedText.append("\n")
        }
        try updatedText.write(to: configurationFilePath, atomically: true, encoding: .utf8)
    }

    private func commentOutLineIfProfileAssignment(_ line: String) -> String? {
        let leadingWhitespace = String(line.prefix { $0 == " " || $0 == "\t" })
        let content = String(line.dropFirst(leadingWhitespace.count))
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.hasPrefix("#"), isProfileAssignment(trimmed) else { return nil }
        return "\(leadingWhitespace)# \(content)"
    }

    private func isProfileAssignment(_ line: String) -> Bool {
        guard let equalIndex = line.firstIndex(of: "=") else { return false }
        let key = line[..<equalIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        return key == "profile"
    }
}

@MainActor
public final class MenuBarViewModel: ObservableObject {
    @Published public var mode: LaunchMode = .proxy {
        didSet { persistSettingsIfNeeded() }
    }
    @Published public var baseURLText: String = "" {
        didSet { persistSettingsIfNeeded() }
    }
    @Published public var apiKeyMasked: String = ""
    @Published public var models: [String] = []
    @Published public var selectedModel: String = "" {
        didSet { persistSettingsIfNeeded() }
    }
    @Published public var reasoningLevel: ReasoningEffort = .medium {
        didSet { persistSettingsIfNeeded() }
    }
    @Published public private(set) var isLaunching = false
    @Published public private(set) var isTestingConnection = false
    @Published public private(set) var state: MenuBarViewState = .idle
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var isStatusError = false
    @Published public private(set) var lastLaunchedProxyConfigTOML: String?

    private let modelDiscovery: any ModelDiscovering
    private let launchRouter: any MenuBarLaunchRouting
    private let settingsStore: any MenuBarSettingsStoring
    private let apiKeyStore: any MenuBarAPIKeyStoring
    private var isHydratingPersistedState = false
    private var hasPreparedProxyContext = false

    public init(
        modelDiscovery: any ModelDiscovering = ModelDiscoveryService(),
        launchRouter: any MenuBarLaunchRouting = DefaultMenuBarLaunchRouter(),
        settingsStore: any MenuBarSettingsStoring = UserDefaultsMenuBarSettingsStore(),
        apiKeyStore: any MenuBarAPIKeyStoring = KeychainMenuBarAPIKeyStore()
    ) {
        self.modelDiscovery = modelDiscovery
        self.launchRouter = launchRouter
        self.settingsStore = settingsStore
        self.apiKeyStore = apiKeyStore

        hydratePersistedState()
    }

    public var baseURLValidationMessage: String? {
        guard mode == .proxy else { return nil }
        let trimmed = baseURLText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Base URL is required."
        }
        return validatedBaseURL(from: trimmed) == nil
            ? "Base URL must use http(s) and include a host."
            : nil
    }

    public var apiKeyValidationMessage: String? {
        guard mode == .proxy else { return nil }
        return apiKeyMasked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "API Key is required."
            : nil
    }

    public var modelValidationMessage: String? {
        guard mode == .proxy else { return nil }
        return selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Model is required."
            : nil
    }

    public var isModelSelectionEnabled: Bool {
        mode == .proxy && !isTestingConnection && !models.isEmpty
    }

    public var canLaunch: Bool {
        guard !isLaunching else { return false }
        switch mode {
        case .original:
            return true
        case .proxy:
            return baseURLValidationMessage == nil &&
                apiKeyValidationMessage == nil &&
                modelValidationMessage == nil &&
                isModelSelectionEnabled
        }
    }

    public var canTestConnection: Bool {
        guard mode == .proxy, !isTestingConnection else { return false }
        return baseURLValidationMessage == nil && apiKeyValidationMessage == nil
    }

    public var canInspectLastLaunchConfigTOML: Bool {
        guard statusMessage == "Launch requested." else { return false }
        guard mode == .proxy else { return false }
        guard let lastLaunchedProxyConfigTOML else { return false }
        return !lastLaunchedProxyConfigTOML.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func testConnection() async {
        guard mode == .proxy else { return }
        guard canTestConnection, let apiBaseURL = validatedBaseURL(from: baseURLText) else {
            state = .testFailed
            setStatusMessage(baseURLValidationMessage ?? apiKeyValidationMessage, isError: true)
            return
        }

        state = .testing
        setStatusMessage(nil)
        isTestingConnection = true
        defer { isTestingConnection = false }

        do {
            let discoveredModels = try await modelDiscovery.fetchModels(
                apiBaseURL: apiBaseURL,
                providerAPIKey: apiKeyMasked
            )
            models = discoveredModels
            if selectedModel.isEmpty || !discoveredModels.contains(selectedModel) {
                selectedModel = discoveredModels.first ?? ""
            }
            state = .testSuccess
            setStatusMessage(
                discoveredModels.isEmpty
                    ? "Connected successfully, but no models were returned."
                    : "Connected successfully."
            )
            persistAPIKeyIfNeeded()
        } catch {
            models = []
            selectedModel = ""
            state = .testFailed
            setStatusMessage("Connection failed: \(resolvedErrorMessage(from: error))", isError: true)
        }
    }

    public func launchSelectedAgent() async {
        guard canLaunch else {
            if mode == .proxy {
                state = .launchFailed
                setStatusMessage(baseURLValidationMessage ?? apiKeyValidationMessage ?? modelValidationMessage, isError: true)
            }
            return
        }

        state = .launching
        setStatusMessage(nil)
        isLaunching = true
        defer { isLaunching = false }

        var renderedProxyConfigurationForInspection: String?
        do {
            switch mode {
            case .original:
                try await launchRouter.launchOriginalMode()
                renderedProxyConfigurationForInspection = nil
            case .proxy:
                guard let apiBaseURL = validatedBaseURL(from: baseURLText) else {
                    state = .launchFailed
                    setStatusMessage("Invalid Base URL.", isError: true)
                    return
                }

                let configuration = AgentProxyLaunchConfig(
                    apiBaseURL: apiBaseURL,
                    providerAPIKey: apiKeyMasked,
                    modelIdentifier: selectedModel,
                    reasoningLevel: reasoningLevel
                )
                renderedProxyConfigurationForInspection = try await launchRouter
                    .launchProxyMode(configuration: configuration)
            }
            lastLaunchedProxyConfigTOML = renderedProxyConfigurationForInspection
            state = .idle
            setStatusMessage("Launch requested.")
            if mode == .proxy {
                persistAPIKeyIfNeeded()
            }
        } catch {
            state = .launchFailed
            setStatusMessage("Launch failed: \(resolvedErrorMessage(from: error))", isError: true)
        }
    }

    public func handlePanelPresented() async {
        guard mode == .proxy else { return }
        guard !hasPreparedProxyContext else { return }
        hasPreparedProxyContext = true

        if apiKeyMasked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            do {
                if let persistedAPIKey = try apiKeyStore.loadAPIKey() {
                    apiKeyMasked = persistedAPIKey
                }
            } catch {
                setStatusMessage("Keychain error: \(resolvedErrorMessage(from: error))", isError: true)
            }
        }

        guard canTestConnection else { return }
        await testConnection()
    }

    private func validatedBaseURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let components = URLComponents(string: trimmed) else { return nil }
        guard let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        guard let host = components.host, !host.isEmpty else { return nil }
        return components.url
    }

    private func resolvedErrorMessage(from error: Error) -> String {
        if let modelError = error as? ModelDiscoveryServiceError {
            return modelError.localizedDescription
        }
        if let urlError = error as? URLError {
            return "Network error (\(urlError.code.rawValue)): \(urlError.localizedDescription)"
        }
        return error.localizedDescription
    }

    private func hydratePersistedState() {
        isHydratingPersistedState = true
        defer { isHydratingPersistedState = false }

        let persistedSettings = settingsStore.loadSettings()
        mode = persistedSettings.mode
        baseURLText = persistedSettings.baseURLText
        selectedModel = persistedSettings.selectedModel
        reasoningLevel = persistedSettings.reasoningLevel
    }

    private func persistSettingsIfNeeded() {
        guard !isHydratingPersistedState else { return }
        settingsStore.saveSettings(
            MenuBarPersistedSettings(
                mode: mode,
                baseURLText: baseURLText,
                selectedModel: selectedModel,
                reasoningLevel: reasoningLevel
            )
        )
    }

    private func persistAPIKeyIfNeeded() {
        guard !isHydratingPersistedState else { return }
        do {
            try apiKeyStore.saveAPIKey(apiKeyMasked)
        } catch {
            setStatusMessage("Keychain error: \(resolvedErrorMessage(from: error))", isError: true)
        }
    }

    private func setStatusMessage(_ message: String?, isError: Bool = false) {
        statusMessage = message
        isStatusError = message == nil ? false : isError
    }
}
