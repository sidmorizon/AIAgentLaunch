import AgentLaunchCore
import AppKit
import SwiftUI

@MainActor
struct MenuBarContentView: View {
    @StateObject private var viewModel: MenuBarViewModel
    @StateObject private var sparkleUpdaterController: SparkleUpdaterController
    @ObservedObject private var launchConfigPreviewWindowController: LaunchConfigPreviewWindowController
    private let appVersion: String

    init(
        viewModel: MenuBarViewModel = MenuBarViewModel(),
        sparkleUpdaterController: SparkleUpdaterController = SparkleUpdaterController(),
        launchConfigPreviewWindowController: LaunchConfigPreviewWindowController = LaunchConfigPreviewWindowController(),
        appVersion: String = AppVersionProvider().currentVersion()
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _sparkleUpdaterController = StateObject(wrappedValue: sparkleUpdaterController)
        _launchConfigPreviewWindowController = ObservedObject(wrappedValue: launchConfigPreviewWindowController)
        self.appVersion = appVersion
    }

    private var modeBinding: Binding<LaunchMode> {
        Binding(
            get: { viewModel.mode },
            set: { newMode in
                guard viewModel.mode != newMode else { return }
                // Avoid AppKit constraint crashes when removing focused fields during segmented transitions.
                NSApplication.shared.keyWindow?.makeFirstResponder(nil)
                viewModel.mode = newMode
            }
        )
    }

    var body: some View {
        MenuBarPanel {
            headerSection
            modeSection

            if viewModel.mode == .proxy {
                proxyConfigurationSection
            }

            launchSection

            if let statusMessage = viewModel.statusMessage {
                statusBanner(message: statusMessage)
            }
        }
        .task(id: viewModel.mode) {
            await viewModel.handlePanelPresented()
            sparkleUpdaterController.checkForUpdateInformationSilently()
        }
        .onChange(of: viewModel.canInspectLastLaunchLogText) { _, canInspect in
            if !canInspect {
                launchConfigPreviewWindowController.close()
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.circle.fill")
                .font(.title2)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("AIAgentLaunch")
                    .font(.headline.weight(.semibold))
                Text("v\(appVersion)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Menu {
                Button("检测升级") {
                    sparkleUpdaterController.checkForUpdates()
                }

                if let updateHintText = sparkleUpdaterController.updateHintText {
                    updateHintMenuSubtitle(
                        text: updateHintText,
                        tone: sparkleUpdaterController.updateHintTone
                    )
                }

                Divider()

                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.secondary)
                .padding(4)
            }
            .menuIndicator(.hidden)
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help(sparkleUpdaterController.isConfigured ? "菜单" : "未配置升级源")
        }
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: MenuBarUITokens.fieldSpacing) {
            Picker("启动模式", selection: modeBinding) {
                Text("API 代理版")
                    .tag(LaunchMode.proxy)
                Text("原版")
                    .tag(LaunchMode.original)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Text(
                viewModel.mode == .proxy
                    ? "通过自定义 Base URL、API Key 启动"
                    : "通过默认配置启动，使用你的个人订阅账号"
            )
            .font(.caption)
            .foregroundStyle(Color.primary.opacity(0.68))
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
        }
    }

    private var proxyConfigurationSection: some View {
        visualGroupSection {
            MenuBarField("BASE URL") {
                TextField("https://api.example.com/v1", text: $viewModel.baseURLText)
                    .textFieldStyle(.roundedBorder)
                if let validation = viewModel.baseURLValidationMessage {
                    MenuBarValidationText(text: validation)
                }
            }

            MenuBarField("API KEY") {
                SecureField("sk-...", text: $viewModel.apiKeyMasked)
                    .textFieldStyle(.roundedBorder)
                if let validation = viewModel.apiKeyValidationMessage {
                    MenuBarValidationText(text: validation)
                }
            }

            HStack(spacing: 8) {
                Button(viewModel.isTestingConnection ? "TESTING..." : "测试连接") {
                    Task {
                        await viewModel.testConnection()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .tint(Color(red: 0.08, green: 0.48, blue: 0.92))
                .disabled(!viewModel.canTestConnection)

                if viewModel.state == .testSuccess {
                    MenuBarStatusBadge(text: "已连接", tone: .success)
                } else if viewModel.isTestingConnection {
                    ProgressView()
                        .controlSize(.small)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .top, spacing: 10) {
                MenuBarField("模型") {
                    Picker("模型", selection: $viewModel.selectedModel) {
                        if viewModel.models.isEmpty {
                            Text("先测试连接").tag("")
                        } else {
                            ForEach(viewModel.models, id: \.self) { modelIdentifier in
                                Text(modelIdentifier).tag(modelIdentifier)
                            }
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .disabled(!viewModel.isModelSelectionEnabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .layoutPriority(1)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("思考强度")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Picker("思考强度", selection: $viewModel.reasoningLevel) {
                        ForEach(ReasoningEffort.allCases, id: \.self) { effort in
                            Text(effort.rawValue).tag(effort)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .disabled(!viewModel.isModelSelectionEnabled)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            if viewModel.isModelSelectionEnabled, let validation = viewModel.modelValidationMessage {
                MenuBarValidationText(text: validation)
            }
        }
    }

    private var launchSection: some View {
        ZStack {
            HStack {
                Spacer(minLength: 0)
                Button(viewModel.isLaunchingCodex ? "LAUNCHING..." : "启动 CODEX") {
                    Task {
                        await viewModel.launchSelectedAgent(.codex)
                    }
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.04, green: 0.45, blue: 0.92))
                .disabled(!viewModel.canLaunchCodex)
                .padding(.trailing, 8)

                Button(viewModel.isLaunchingClaude ? "LAUNCHING..." : "启动 CLAUDE") {
                    Task {
                        await viewModel.launchSelectedAgent(.claude)
                    }
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.15, green: 0.52, blue: 0.44))
                .disabled(!viewModel.canLaunchClaude)
                Spacer(minLength: 0)
            }

            HStack {
                Spacer(minLength: 0)
                if viewModel.canInspectLastLaunchLogText {
                    Button {
                        launchConfigPreviewWindowController.present(
                            launchLogText: viewModel.lastLaunchLogText ?? "",
                            claudeCLIEnvironment: viewModel.lastClaudeCLIEnvironmentVariables,
                            claudeModelOptions: viewModel.models
                        )
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .accessibilityLabel("查看 Agent 启动日志")
                    .help("查看 Agent 启动日志")
                }
            }
        }
    }

    private func visualGroupSection<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: MenuBarUITokens.fieldSpacing) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(red: 0.94, green: 0.95, blue: 0.97).opacity(0.90))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(red: 0.74, green: 0.79, blue: 0.87).opacity(0.42), lineWidth: 1)
        )
    }

    private func statusBanner(message: String) -> some View {
        let isError = viewModel.isStatusError || viewModel.state == .testFailed || viewModel.state == .launchFailed
        let tone: MenuBarBadgeTone = isError ? .error : .success

        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: tone.symbolName)
                .font(.caption)
                .foregroundStyle(tone.foregroundColor)
                .padding(.top, 1)
            Text(message)
                .font(.caption)
                .foregroundStyle(tone.foregroundColor)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tone.backgroundColor.opacity(0.82))
        )
    }

    private func updateHintMenuSubtitle(text: String, tone: UpdateAvailabilityTone) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(updateHintColor(for: tone))
                .frame(width: 6, height: 6)
            Text(text)
                .font(.caption2)
                .foregroundStyle(updateHintColor(for: tone))
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }

    private func updateHintColor(for tone: UpdateAvailabilityTone) -> Color {
        switch tone {
        case .neutral:
            return .secondary
        case .info:
            return Color(red: 0.13, green: 0.48, blue: 0.84)
        case .success:
            return Color(red: 0.12, green: 0.54, blue: 0.30)
        case .warning:
            return Color(red: 0.82, green: 0.43, blue: 0.08)
        case .error:
            return Color(red: 0.70, green: 0.16, blue: 0.14)
        }
    }
}
