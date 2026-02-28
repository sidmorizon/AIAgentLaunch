import AppKit
import Foundation

public protocol ConfigurationTransactionHandling {
    func applyTemporaryConfiguration(_ temporaryConfiguration: String, at configurationFilePath: URL) throws -> String
    func restoreOriginalConfiguration(at configurationFilePath: URL) throws
}

extension ConfigTransaction: ConfigurationTransactionHandling {}

@MainActor
public protocol ProviderLaunchEventSource {
    func waitForLaunch(of bundleIdentifier: String, timeoutNanoseconds: UInt64) async
}

@MainActor
public struct WorkspaceLaunchEventSource: ProviderLaunchEventSource {
    private let notificationCenter: NotificationCenter

    public init(notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter) {
        self.notificationCenter = notificationCenter
    }

    public func waitForLaunch(of bundleIdentifier: String, timeoutNanoseconds: UInt64) async {
        await withCheckedContinuation { continuation in
            let waitState = LaunchWaitState(notificationCenter: notificationCenter, continuation: continuation)
            let observer = notificationCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: nil
            ) { notification in
                guard
                    let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                    application.bundleIdentifier == bundleIdentifier
                else {
                    return
                }
                waitState.resumeIfNeeded()
            }
            waitState.storeObserver(observer)

            let timeoutInterval = DispatchTimeInterval.nanoseconds(Int(clamping: timeoutNanoseconds))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeoutInterval) {
                waitState.resumeIfNeeded()
            }
        }
    }
}

private final class LaunchWaitState: @unchecked Sendable {
    private let notificationCenter: NotificationCenter
    private let lock = NSLock()
    private let continuation: CheckedContinuation<Void, Never>
    private var observer: NSObjectProtocol?
    private var resumed = false

    init(notificationCenter: NotificationCenter, continuation: CheckedContinuation<Void, Never>) {
        self.notificationCenter = notificationCenter
        self.continuation = continuation
    }

    func storeObserver(_ observer: NSObjectProtocol) {
        lock.lock()
        self.observer = observer
        lock.unlock()
    }

    func resumeIfNeeded() {
        lock.lock()
        guard !resumed else {
            lock.unlock()
            return
        }
        resumed = true
        let observer = observer
        self.observer = nil
        lock.unlock()

        if let observer {
            notificationCenter.removeObserver(observer)
        }
        continuation.resume()
    }
}

@MainActor
public final class AgentLaunchCoordinator {
    private let provider: any AgentProviderBase
    private let transaction: any ConfigurationTransactionHandling
    private let authTransaction: any CodexAuthTransactionHandling
    private let launcher: any AgentLaunching
    private let launchEventSource: any ProviderLaunchEventSource
    private let launchTimeoutNanoseconds: UInt64

    public init(
        provider: any AgentProviderBase = AgentProviderCodex(),
        transaction: any ConfigurationTransactionHandling = ConfigTransaction(),
        authTransaction: any CodexAuthTransactionHandling = CodexAuthTransaction(),
        launcher: any AgentLaunching = AgentLauncher(),
        launchEventSource: any ProviderLaunchEventSource = WorkspaceLaunchEventSource(),
        launchTimeoutNanoseconds: UInt64 = 3_000_000_000
    ) {
        self.provider = provider
        self.transaction = transaction
        self.authTransaction = authTransaction
        self.launcher = launcher
        self.launchEventSource = launchEventSource
        self.launchTimeoutNanoseconds = launchTimeoutNanoseconds
    }

    public func launchWithTemporaryConfiguration(_ launchConfiguration: AgentProxyLaunchConfig) async throws -> String {
        let temporaryConfiguration = provider.renderTemporaryConfiguration(from: launchConfiguration)
        let configurationFilePath = provider.configurationFilePath
        let mergedConfiguration = try transaction.applyTemporaryConfiguration(temporaryConfiguration, at: configurationFilePath)
        try authTransaction.applyProxyAuthentication(
            apiKey: launchConfiguration.providerAPIKey,
            at: provider.authFilePath,
            backupFilePath: provider.authBackupFilePath
        )

        do {
            try await launcher.launchApplication(
                bundleIdentifier: provider.applicationBundleIdentifier,
                environmentVariables: [:]
            )
        } catch {
            throw error
        }

        await launchEventSource.waitForLaunch(
            of: provider.applicationBundleIdentifier,
            timeoutNanoseconds: launchTimeoutNanoseconds
        )
        return mergedConfiguration
    }
}
