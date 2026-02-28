import Foundation

public protocol ThreadModelProviderMigrating {
    func migrateForProxyLaunch() throws
    func migrateForOriginalLaunch() throws
}

public enum ThreadModelProviderMigrationError: Error, Equatable {
    case sqliteCommandFailed(status: Int32, errorOutput: String)
}

public protocol ShellCommandRunning {
    func run(executablePath: String, arguments: [String]) throws -> ShellCommandResult
}

public struct ShellCommandResult: Sendable, Equatable {
    public let terminationStatus: Int32
    public let standardError: String

    public init(terminationStatus: Int32, standardError: String) {
        self.terminationStatus = terminationStatus
        self.standardError = standardError
    }
}

public struct FoundationShellCommandRunner: ShellCommandRunning {
    public init() {}

    public func run(executablePath: String, arguments: [String]) throws -> ShellCommandResult {
        let process = Process()
        let standardErrorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.standardError = standardErrorPipe

        try process.run()
        process.waitUntilExit()

        let errorData = standardErrorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return ShellCommandResult(
            terminationStatus: process.terminationStatus,
            standardError: errorOutput
        )
    }
}

public struct SQLiteThreadModelProviderMigrator: ThreadModelProviderMigrating {
    public static let proxyModelProviderIdentifier = "ai_agent_launch_proxy_260226"
    public static let openAIModelProviderIdentifier = "openai"

    private let databaseFilePath: String
    private let sqliteExecutablePath: String
    private let commandRunner: any ShellCommandRunning

    public init(
        databaseFilePath: String = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/state_5.sqlite", isDirectory: false).path,
        sqliteExecutablePath: String = "/usr/bin/sqlite3",
        commandRunner: any ShellCommandRunning = FoundationShellCommandRunner()
    ) {
        self.databaseFilePath = databaseFilePath
        self.sqliteExecutablePath = sqliteExecutablePath
        self.commandRunner = commandRunner
    }

    public func migrateForProxyLaunch() throws {
        try migrateModelProvider(
            from: Self.openAIModelProviderIdentifier,
            to: Self.proxyModelProviderIdentifier
        )
    }

    public func migrateForOriginalLaunch() throws {
        try migrateModelProvider(
            from: Self.proxyModelProviderIdentifier,
            to: Self.openAIModelProviderIdentifier
        )
    }

    private func migrateModelProvider(from source: String, to destination: String) throws {
        let sql = "BEGIN; UPDATE threads SET model_provider = '\(destination)' WHERE model_provider = '\(source)'; COMMIT;"
        let result = try commandRunner.run(
            executablePath: sqliteExecutablePath,
            arguments: [databaseFilePath, sql]
        )
        guard result.terminationStatus == 0 else {
            throw ThreadModelProviderMigrationError.sqliteCommandFailed(
                status: result.terminationStatus,
                errorOutput: result.standardError
            )
        }
    }
}
