import Foundation
import XCTest

final class MenuBarContentViewSourceLayoutTests: XCTestCase {
    func testHeaderMenuUsesCompactIconAndIndicatorLayout() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("Image(systemName: \"chevron.down\")"),
            "Header menu should render a compact chevron indicator next to the ellipsis icon."
        )
        XCTAssertTrue(
            source.contains(".menuIndicator(.hidden)"),
            "Default menu indicator should be hidden to avoid large spacing between icon and arrow."
        )
    }

    func testCheckForUpdatesMenuItemIsAlwaysEnabled() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertFalse(
            source.contains(".disabled(!sparkleUpdaterController.canCheckForUpdates)"),
            "Manual update check should remain clickable even when updater state is unavailable."
        )
    }

    func testCheckForUpdatesMenuItemUsesStableActionLabel() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("Button(\"检测升级\")"),
            "Update menu entry label should remain stable and descriptive."
        )
    }

    func testCheckForUpdatesMenuDoesNotRenderStandaloneStatusRow() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertFalse(
            source.contains("updateHintMenuSubtitle"),
            "Update status should no longer render as a standalone menu subtitle row."
        )
    }

    func testHeaderShowsUpdateStatusBesideVersionText() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("Text(\"v\\(appVersion)\")"),
            "Header should continue to render the app version text."
        )
        XCTAssertTrue(
            source.contains("if let updateHintText = sparkleUpdaterController.updateHintText"),
            "Header should read update status from the updater controller."
        )
        XCTAssertTrue(
            source.contains("updateHintInlineLabel"),
            "Header should render update status using the inline label beside the version text."
        )
    }

    func testModeSegmentedPickerExpandsToFullWidth() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains(
                """
                .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                """
            ),
            "Mode segmented picker should stretch to the full panel width for clearer, balanced layout."
        )
    }

    func testModeSectionDoesNotRenderStandaloneTitleLabel() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertFalse(
            source.contains("MenuBarSection(title: \"启动模式\", systemImage: \"switch.2\")"),
            "Mode controls should be displayed as a visual group without a standalone title label."
        )
    }

    func testProxyAndLaunchSectionsDoNotRenderStandaloneTitleLabels() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertFalse(
            source.contains("MenuBarSection(title: \"代理配置\", systemImage: \"network\")"),
            "Proxy controls should be displayed as a visual group without a standalone title label."
        )
        XCTAssertFalse(
            source.contains("MenuBarSection(title: \"启动\", systemImage: \"play.circle\")"),
            "Launch controls should be displayed as a visual group without a standalone title label."
        )
    }

    func testModeSectionUsesPlainLayoutWithoutGroupCard() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("private var modeSection: some View {\n        VStack(alignment: .leading, spacing: MenuBarUITokens.fieldSpacing) {"),
            "Mode controls should use plain layout without an enclosing group card."
        )
        XCTAssertFalse(
            source.contains("private var modeSection: some View {\n        visualGroupSection {"),
            "Mode controls should not be wrapped by the group-card container."
        )
    }

    func testLaunchSectionUsesPlainLayoutWithoutGroupCard() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("private var launchSection: some View {\n        ZStack {"),
            "Launch controls should use plain layout without an enclosing group card."
        )
        XCTAssertFalse(
            source.contains("private var launchSection: some View {\n        visualGroupSection {"),
            "Launch controls should not be wrapped by the group-card container."
        )
    }

    func testLaunchSectionPinsInspectButtonToTrailingWithoutShiftingPrimaryButton() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("await viewModel.launchSelectedAgent(.codex)"),
            "Launch section should include an explicit Codex launch action."
        )
        XCTAssertTrue(
            source.contains("await viewModel.launchSelectedAgent(.claude)"),
            "Launch section should include an explicit Claude launch action."
        )
        XCTAssertTrue(
            source.contains("HStack {\n                Spacer(minLength: 0)\n                if viewModel.canInspectLastLaunchLogText"),
            "Inspect action should be pinned to trailing edge in an overlay track."
        )
    }

    func testLaunchConfigPreviewUsesIndependentWindowInsteadOfSheet() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertFalse(
            source.contains(".sheet(isPresented:"),
            "Config preview should open in an independent window instead of a sheet tied to the menu panel."
        )
        XCTAssertTrue(
            source.contains("launchConfigPreviewWindowController.present("),
            "Inspect action should route through a dedicated preview window controller."
        )
        XCTAssertTrue(
            source.contains("claudeCLIEnvironment: viewModel.lastClaudeCLIEnvironmentVariables"),
            "Inspect action should pass through Claude launch environment for dynamic CLI command generation."
        )
        XCTAssertTrue(
            source.contains("claudeModelOptions: viewModel.models"),
            "Inspect action should pass through the same model list used by the configuration section."
        )
    }

    func testInspectButtonUsesIconOnlyCompactStyle() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("Image(systemName: \"doc.text.magnifyingglass\")"),
            "Inspect control should be icon-only for compact placement beside launch."
        )
        XCTAssertFalse(
            source.contains("Button(\"查看本次 config.toml\", systemImage: \"doc.text.magnifyingglass\")"),
            "Inspect button should no longer render text label in the launch row."
        )
        XCTAssertTrue(
            source.contains(".accessibilityLabel(\"查看 Agent 启动日志\")"),
            "Inspect button should expose the new startup-log naming in accessibility text."
        )
        XCTAssertTrue(
            source.contains(".help(\"查看 Agent 启动日志\")"),
            "Inspect button hover text should use the new startup-log naming."
        )
    }

    func testProxyConfigurationGroupUsesSoftNeutralBackground() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("private var proxyConfigurationSection: some View {\n        visualGroupSection {"),
            "Proxy configuration should remain inside the visual group card."
        )
        XCTAssertTrue(
            source.contains(".fill(Color(red: 0.94, green: 0.95, blue: 0.97).opacity(0.90))"),
            "Group-card background should use a softer neutral tone instead of bright white."
        )
    }

    func testModeDescriptionTextIsCentered() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains(".multilineTextAlignment(.center)"),
            "Mode description text should be centered."
        )
        XCTAssertTrue(
            source.contains(".frame(maxWidth: .infinity, alignment: .center)"),
            "Mode description text should be horizontally centered in full width."
        )
    }

    func testOriginalModeDescriptionUsesPersonalSubscriptionCopy() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("通过默认配置启动，使用你的个人订阅账号"),
            "Original mode description should clarify that launch uses default config with personal subscription account."
        )
    }

    func testPrimaryAndLoadingButtonsUseUppercaseEnglishStyle() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains("Button(viewModel.isLaunchingCodex ? \"LAUNCHING...\" : \"启动 CODEX\")"),
            "Primary launch button should keep English terms in uppercase for a modern visual rhythm."
        )
        XCTAssertTrue(
            source.contains("Button(viewModel.isLaunchingClaude ? \"LAUNCHING...\" : \"启动 CLAUDE\")"),
            "Secondary launch button should mirror the same uppercase rhythm with CLAUDE label."
        )
        XCTAssertTrue(
            source.contains("Button(viewModel.isTestingConnection ? \"TESTING...\" : \"测试连接\")"),
            "Connection button loading label should use uppercase English style."
        )
    }

    func testModelPickerUsesAdaptiveWidthWhileReasoningStaysCompact() throws {
        let source = try String(contentsOf: menuBarContentViewSourceURL(), encoding: .utf8)

        XCTAssertTrue(
            source.contains(".layoutPriority(1)"),
            "Model selector should take remaining horizontal space so long model names are less likely to be truncated."
        )
        XCTAssertTrue(
            source.contains(".fixedSize(horizontal: true, vertical: false)"),
            "Reasoning selector should keep compact intrinsic width to leave room for model selector."
        )
        XCTAssertFalse(
            source.contains(".frame(maxWidth: .infinity, alignment: .leading)\n                }\n                .frame(maxWidth: .infinity, alignment: .leading)"),
            "Model selector should no longer be forced into a fixed half-width column."
        )
        XCTAssertFalse(
            source.contains(".frame(maxWidth: .infinity, alignment: .trailing)\n                }\n                .frame(maxWidth: .infinity, alignment: .trailing)"),
            "Reasoning selector should no longer stretch to consume half-width."
        )
    }

    private func menuBarContentViewSourceURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent() // UI
            .deletingLastPathComponent() // AgentLaunchCoreTests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // Repository root
            .appendingPathComponent("Sources/AIAgentLaunch/UI/MenuBarContentView.swift")
    }
}
