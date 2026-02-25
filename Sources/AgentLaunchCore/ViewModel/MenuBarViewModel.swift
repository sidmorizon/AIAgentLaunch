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
    func launchProxyMode(configuration: AgentProxyLaunchConfig) async throws
}

@MainActor
public struct DefaultMenuBarLaunchRouter: MenuBarLaunchRouting {
    private let provider: any AgentProviderBase
    private let launcher: any AgentLaunching
    private let coordinator: AgentLaunchCoordinator

    public init(
        provider: any AgentProviderBase = AgentProviderCodex(),
        launcher: any AgentLaunching = AgentLauncher(),
        coordinator: AgentLaunchCoordinator? = nil
    ) {
        self.provider = provider
        self.launcher = launcher
        self.coordinator = coordinator ?? AgentLaunchCoordinator(provider: provider)
    }

    public func launchOriginalMode() async throws {
        try launcher.launchApplication(bundleIdentifier: provider.applicationBundleIdentifier)
    }

    public func launchProxyMode(configuration: AgentProxyLaunchConfig) async throws {
        try await coordinator.launchWithTemporaryConfiguration(configuration)
    }
}

@MainActor
public final class MenuBarViewModel: ObservableObject {
    @Published public var mode: LaunchMode = .original
    @Published public var baseURLText: String = ""
    @Published public var apiKeyMasked: String = ""
    @Published public var models: [String] = []
    @Published public var selectedModel: String = ""
    @Published public var reasoningLevel: ReasoningEffort = .medium
    @Published public private(set) var isLaunching = false
    @Published public private(set) var isTestingConnection = false
    @Published public private(set) var statusMessage: String?

    private let modelDiscovery: any ModelDiscovering
    private let launchRouter: any MenuBarLaunchRouting

    public init(
        modelDiscovery: any ModelDiscovering = ModelDiscoveryService(),
        launchRouter: any MenuBarLaunchRouting = DefaultMenuBarLaunchRouter()
    ) {
        self.modelDiscovery = modelDiscovery
        self.launchRouter = launchRouter
    }

    public var canLaunch: Bool {
        guard !isLaunching else { return false }
        switch mode {
        case .original:
            return true
        case .proxy:
            guard URL(string: baseURLText) != nil else { return false }
            return !apiKeyMasked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !selectedModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    public var canTestConnection: Bool {
        guard mode == .proxy, !isTestingConnection else { return false }
        guard URL(string: baseURLText) != nil else { return false }
        return !apiKeyMasked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func testConnection() async {
        guard canTestConnection, let apiBaseURL = URL(string: baseURLText) else { return }

        isTestingConnection = true
        defer { isTestingConnection = false }

        do {
            let discoveredModels = try await modelDiscovery.fetchModels(
                apiBaseURL: apiBaseURL,
                providerAPIKey: apiKeyMasked
            )
            models = discoveredModels
            if selectedModel.isEmpty {
                selectedModel = discoveredModels.first ?? ""
            }
            statusMessage = discoveredModels.isEmpty ? "No models returned." : "Connected."
        } catch {
            statusMessage = "Connection failed: \(error.localizedDescription)"
        }
    }

    public func launchSelectedAgent() async {
        guard canLaunch else { return }

        isLaunching = true
        defer { isLaunching = false }

        do {
            switch mode {
            case .original:
                try await launchRouter.launchOriginalMode()
            case .proxy:
                guard let apiBaseURL = URL(string: baseURLText) else {
                    statusMessage = "Invalid Base URL."
                    return
                }

                let configuration = AgentProxyLaunchConfig(
                    apiBaseURL: apiBaseURL,
                    providerAPIKey: apiKeyMasked,
                    modelIdentifier: selectedModel,
                    reasoningLevel: reasoningLevel
                )
                try await launchRouter.launchProxyMode(configuration: configuration)
            }
            statusMessage = "Launch requested."
        } catch {
            statusMessage = "Launch failed: \(error.localizedDescription)"
        }
    }
}
