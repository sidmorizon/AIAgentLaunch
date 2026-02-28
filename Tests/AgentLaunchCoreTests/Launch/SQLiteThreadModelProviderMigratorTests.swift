import XCTest
@testable import AgentLaunchCore

final class SQLiteThreadModelProviderMigratorTests: XCTestCase {
    func testProxyLaunchMigrationUsesExpectedProviderSwapSQL() throws {
        let commandRunner = SpyShellCommandRunner()
        let migrator = SQLiteThreadModelProviderMigrator(
            databaseFilePath: "/tmp/state_5.sqlite",
            sqliteExecutablePath: "/usr/bin/sqlite3",
            commandRunner: commandRunner
        )

        try migrator.migrateForProxyLaunch()

        XCTAssertEqual(commandRunner.calls.count, 1)
        XCTAssertEqual(commandRunner.calls[0].executablePath, "/usr/bin/sqlite3")
        XCTAssertEqual(
            commandRunner.calls[0].arguments,
            [
                "/tmp/state_5.sqlite",
                "BEGIN; UPDATE threads SET model_provider = 'ai_agent_launch_proxy_260226' WHERE model_provider = 'openai'; COMMIT;"
            ]
        )
    }

    func testOriginalLaunchMigrationUsesExpectedProviderSwapSQL() throws {
        let commandRunner = SpyShellCommandRunner()
        let migrator = SQLiteThreadModelProviderMigrator(
            databaseFilePath: "/tmp/state_5.sqlite",
            sqliteExecutablePath: "/usr/bin/sqlite3",
            commandRunner: commandRunner
        )

        try migrator.migrateForOriginalLaunch()

        XCTAssertEqual(commandRunner.calls.count, 1)
        XCTAssertEqual(commandRunner.calls[0].executablePath, "/usr/bin/sqlite3")
        XCTAssertEqual(
            commandRunner.calls[0].arguments,
            [
                "/tmp/state_5.sqlite",
                "BEGIN; UPDATE threads SET model_provider = 'openai' WHERE model_provider = 'ai_agent_launch_proxy_260226'; COMMIT;"
            ]
        )
    }

    func testMigrationThrowsWhenSQLiteCommandFails() throws {
        let commandRunner = SpyShellCommandRunner()
        commandRunner.nextResult = ShellCommandResult(terminationStatus: 1, standardError: "no such table: threads")
        let migrator = SQLiteThreadModelProviderMigrator(
            databaseFilePath: "/tmp/state_5.sqlite",
            sqliteExecutablePath: "/usr/bin/sqlite3",
            commandRunner: commandRunner
        )

        XCTAssertThrowsError(try migrator.migrateForProxyLaunch()) { error in
            XCTAssertEqual(
                error as? ThreadModelProviderMigrationError,
                .sqliteCommandFailed(status: 1, errorOutput: "no such table: threads")
            )
        }
    }
}

private final class SpyShellCommandRunner: ShellCommandRunning {
    struct Call: Equatable {
        let executablePath: String
        let arguments: [String]
    }

    private(set) var calls: [Call] = []
    var nextResult = ShellCommandResult(terminationStatus: 0, standardError: "")

    func run(executablePath: String, arguments: [String]) throws -> ShellCommandResult {
        calls.append(Call(executablePath: executablePath, arguments: arguments))
        return nextResult
    }
}
