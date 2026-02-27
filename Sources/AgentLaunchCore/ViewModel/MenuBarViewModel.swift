import AppKit
import Combine
import Foundation

@MainActor
public protocol ModelDiscovering {
    func fetchModels(apiBaseURL: URL, providerAPIKey: String) async throws -> [String]
}

@MainActor
extension ModelDiscoveryService: ModelDiscovering {}

@MainActor
public protocol LaunchConfigurationValidating {
    func validate(configuration: AgentProxyLaunchConfig) async throws
}

@MainActor
extension LaunchConfigurationValidationService: LaunchConfigurationValidating {}

@MainActor
public protocol MenuBarLaunchRouting {
    func isInstalled(agent: AgentTarget) -> Bool
    func launchOriginalMode(agent: AgentTarget) async throws -> String?
    func launchProxyMode(agent: AgentTarget, configuration: AgentProxyLaunchConfig) async throws -> String
}

public extension MenuBarLaunchRouting {
    func launchOriginalMode() async throws -> String? {
        try await launchOriginalMode(agent: .codex)
    }

    func launchProxyMode(configuration: AgentProxyLaunchConfig) async throws -> String {
        try await launchProxyMode(agent: .codex, configuration: configuration)
    }
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
    private let codexProvider: any AgentProviderBase
    private let launcher: any AgentLaunching
    private let codexCoordinator: AgentLaunchCoordinator
    private let fileManager: FileManager

    public init(
        provider: any AgentProviderBase = AgentProviderCodex(),
        launcher: any AgentLaunching = AgentLauncher(),
        coordinator: AgentLaunchCoordinator? = nil,
        fileManager: FileManager = .default
    ) {
        codexProvider = provider
        self.launcher = launcher
        codexCoordinator = coordinator ?? AgentLaunchCoordinator(provider: provider)
        self.fileManager = fileManager
    }

    public func isInstalled(agent: AgentTarget) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: agent.applicationBundleIdentifier) != nil
    }

    public func launchOriginalMode(agent: AgentTarget) async throws -> String? {
        switch agent {
        case .codex:
            try commentOutProfileAssignmentIfNeeded(at: codexProvider.configurationFilePath)
            let launchedConfiguration = try readConfigurationTextIfPresent(at: codexProvider.configurationFilePath)
            try await launcher.launchApplication(
                bundleIdentifier: codexProvider.applicationBundleIdentifier,
                environmentVariables: [:]
            )
            return launchedConfiguration
        case .claude:
            try await launcher.launchApplication(
                bundleIdentifier: agent.applicationBundleIdentifier,
                environmentVariables: [:]
            )
            return nil
        }
    }

    public func launchProxyMode(agent: AgentTarget, configuration: AgentProxyLaunchConfig) async throws -> String {
        switch agent {
        case .codex:
            return try await codexCoordinator.launchWithTemporaryConfiguration(configuration)
        case .claude:
            let environmentVariables = ClaudeLaunchEnvironment.makeProxyEnvironment(from: configuration)
            try await launcher.launchApplication(
                bundleIdentifier: agent.applicationBundleIdentifier,
                environmentVariables: environmentVariables
            )
            return ClaudeLaunchEnvironment.renderMaskedSnapshot(from: environmentVariables)
        }
    }

    private func readConfigurationTextIfPresent(at configurationFilePath: URL) throws -> String? {
        guard fileManager.fileExists(atPath: configurationFilePath.path) else { return nil }
        return try String(contentsOf: configurationFilePath, encoding: .utf8)
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
    @Published public private(set) var isLaunchingCodex = false
    @Published public private(set) var isLaunchingClaude = false
    @Published public private(set) var isTestingConnection = false
    @Published public private(set) var state: MenuBarViewState = .idle
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var isStatusError = false
    @Published public private(set) var lastLaunchLogText: String?
    @Published public private(set) var lastClaudeCLICommandText: String?
    @Published public private(set) var lastClaudeCLIEnvironmentVariables: [String: String]?

    private let modelDiscovery: any ModelDiscovering
    private let launchConfigurationValidator: any LaunchConfigurationValidating
    private let launchRouter: any MenuBarLaunchRouting
    private let settingsStore: any MenuBarSettingsStoring
    private let apiKeyStore: any MenuBarAPIKeyStoring
    private var isHydratingPersistedState = false
    private var hasPreparedProxyContext = false

    public init(
        modelDiscovery: (any ModelDiscovering)? = nil,
        launchConfigurationValidator: (any LaunchConfigurationValidating)? = nil,
        launchRouter: (any MenuBarLaunchRouting)? = nil,
        settingsStore: (any MenuBarSettingsStoring)? = nil,
        apiKeyStore: (any MenuBarAPIKeyStoring)? = nil
    ) {
        self.modelDiscovery = modelDiscovery ?? ModelDiscoveryService()
        self.launchConfigurationValidator = launchConfigurationValidator ?? LaunchConfigurationValidationService()
        self.launchRouter = launchRouter ?? DefaultMenuBarLaunchRouter()
        self.settingsStore = settingsStore ?? UserDefaultsMenuBarSettingsStore()
        self.apiKeyStore = apiKeyStore ?? KeychainMenuBarAPIKeyStore()

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
        canLaunchCodex
    }

    public var canLaunchCodex: Bool {
        canLaunch(agent: .codex)
    }

    public var canLaunchClaude: Bool {
        canLaunch(agent: .claude)
    }

    public var canInspectLastLaunchLogText: Bool {
        guard statusMessage == "Launch requested." else { return false }
        guard let lastLaunchLogText else { return false }
        return !lastLaunchLogText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var canInspectLastLaunchConfigTOML: Bool {
        canInspectLastLaunchLogText
    }

    public var lastLaunchedProxyConfigTOML: String? {
        lastLaunchLogText
    }

    private func canLaunch(agent: AgentTarget) -> Bool {
        guard !isLaunching else { return false }
        guard launchRouter.isInstalled(agent: agent) else { return false }
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

    public func launchSelectedAgent() async {
        await launchSelectedAgent(.codex)
    }

    public func launchSelectedAgent(_ agent: AgentTarget) async {
        guard launchRouter.isInstalled(agent: agent) else {
            state = .launchFailed
            setStatusMessage("\(agent.displayName) is not installed.", isError: true)
            return
        }

        guard canLaunch(agent: agent) else {
            if mode == .proxy {
                state = .launchFailed
                setStatusMessage(baseURLValidationMessage ?? apiKeyValidationMessage ?? modelValidationMessage, isError: true)
            }
            return
        }

        state = .launching
        setStatusMessage(nil)
        isLaunching = true
        setLaunchingAgent(agent)
        defer {
            isLaunching = false
            setLaunchingAgent(nil)
        }

        var launchLogForInspection: String?
        var claudeCLICommandForInspection: String?
        var claudeCLIEnvironmentForInspection: [String: String]?
        do {
            switch mode {
            case .original:
                launchLogForInspection = try await launchRouter.launchOriginalMode(agent: agent)
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
                do {
                    try await launchConfigurationValidator.validate(configuration: configuration)
                } catch {
                    state = .launchFailed
                    setStatusMessage("Launch precheck failed: \(resolvedErrorMessage(from: error))", isError: true)
                    return
                }
                if agent == .claude {
                    let launchEnvironment = ClaudeLaunchEnvironment.makeProxyEnvironment(from: configuration)
                    claudeCLIEnvironmentForInspection = launchEnvironment
                    claudeCLICommandForInspection = ClaudeLaunchEnvironment.renderCLICommand(from: launchEnvironment)
                }
                launchLogForInspection = try await launchRouter
                    .launchProxyMode(agent: agent, configuration: configuration)
            }
            lastLaunchLogText = launchLogForInspection
            lastClaudeCLICommandText = claudeCLICommandForInspection
            lastClaudeCLIEnvironmentVariables = claudeCLIEnvironmentForInspection
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
        if let validationError = error as? LaunchConfigurationValidationError {
            return validationError.localizedDescription
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

    private func setLaunchingAgent(_ agent: AgentTarget?) {
        isLaunchingCodex = agent == .codex
        isLaunchingClaude = agent == .claude
    }
}
