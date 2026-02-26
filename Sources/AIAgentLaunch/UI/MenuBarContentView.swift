import AgentLaunchCore
import AppKit
import SwiftUI

struct MenuBarContentView: View {
    @StateObject private var viewModel: MenuBarViewModel
    @State private var isShowingLaunchConfigPreview = false

    init(viewModel: MenuBarViewModel = MenuBarViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 14) {
                modeSection

                if viewModel.mode == .proxy {
                    proxyConfigurationSection
                }

                launchSection

                if let statusMessage = viewModel.statusMessage {
                    statusBanner(message: statusMessage)
                }

                footerSection
            }
            .padding(14)
            .frame(width: 372)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.96, green: 0.98, blue: 1.00),
                                Color(red: 0.93, green: 0.96, blue: 0.99)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )

            if isShowingLaunchConfigPreview {
                Color.black.opacity(0.12)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isShowingLaunchConfigPreview = false
                    }

                launchConfigPreviewOverlay
                    .padding(10)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.easeInOut(duration: 0.16), value: isShowingLaunchConfigPreview)
        .task(id: viewModel.mode) {
            await viewModel.handlePanelPresented()
        }
        .onChange(of: viewModel.canInspectLastLaunchConfigTOML) { _, canInspect in
            if !canInspect {
                isShowingLaunchConfigPreview = false
            }
        }
    }

    private var modeSection: some View {
        HStack(spacing: 8) {
            modeOptionButton(
                mode: .proxy,
                title: "API 代理版"
            )
            modeOptionButton(
                mode: .original,
                title: "原版"
            )
        }
    }

    private func modeOptionButton(mode: LaunchMode, title: String) -> some View {
        let isSelected = viewModel.mode == mode

        return Button {
            // Avoid AppKit constraint crashes when removing focused fields during animated transitions.
            NSApplication.shared.keyWindow?.makeFirstResponder(nil)
            viewModel.mode = mode
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.caption)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color(red: 0.79, green: 0.91, blue: 1.00) : Color.white.opacity(0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color(red: 0.11, green: 0.52, blue: 0.84) : Color.gray.opacity(0.25), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var proxyConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("Base URL")
                TextField("https://api.example.com/v1", text: $viewModel.baseURLText)
                    .textFieldStyle(.roundedBorder)
                if let validation = viewModel.baseURLValidationMessage {
                    validationText(validation)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                fieldLabel("API Key")
                SecureField("sk-...", text: $viewModel.apiKeyMasked)
                    .textFieldStyle(.roundedBorder)
                if let validation = viewModel.apiKeyValidationMessage {
                    validationText(validation)
                }
            }

            HStack(spacing: 8) {
                Button(viewModel.isTestingConnection ? "Testing..." : "测试连接") {
                    Task {
                        await viewModel.testConnection()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.11, green: 0.60, blue: 0.60))
                .disabled(!viewModel.canTestConnection)

                if viewModel.state == .testSuccess {
                    Label("连接成功", systemImage: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(Color(red: 0.10, green: 0.56, blue: 0.29))
                }
            }

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("模型")
                    Picker("", selection: $viewModel.selectedModel) {
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

                VStack(alignment: .leading, spacing: 6) {
                    fieldLabel("思考强度")
                    Picker("", selection: $viewModel.reasoningLevel) {
                        ForEach(ReasoningEffort.allCases, id: \.self) { effort in
                            Text(effort.rawValue).tag(effort)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .disabled(!viewModel.isModelSelectionEnabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if viewModel.isModelSelectionEnabled, let validation = viewModel.modelValidationMessage {
                validationText(validation)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.70))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.22), lineWidth: 1)
        )
    }

    private var launchSection: some View {
        Button(viewModel.isLaunching ? "Launching..." : "启动 Codex") {
            Task {
                await viewModel.launchSelectedAgent()
            }
        }
        .frame(maxWidth: .infinity)
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .tint(
            viewModel.mode == .proxy
                ? Color(red: 0.11, green: 0.52, blue: 0.84)
                : Color(red: 0.20, green: 0.45, blue: 0.80)
        )
        .disabled(!viewModel.canLaunch)
    }

    private func statusBanner(message: String) -> some View {
        let isError = viewModel.isStatusError || viewModel.state == .testFailed || viewModel.state == .launchFailed
        let fgColor = isError
            ? Color(red: 0.63, green: 0.14, blue: 0.12)
            : Color(red: 0.17, green: 0.39, blue: 0.17)

        return HStack(alignment: .top, spacing: 8) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.caption)
                .padding(.top, 1)
            Text(message)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            if viewModel.canInspectLastLaunchConfigTOML {
                Spacer(minLength: 6)
                Button {
                    isShowingLaunchConfigPreview = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("查看本次启动使用的 config.toml")
            }
        }
        .foregroundStyle(fgColor)
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isError ? Color(red: 1.00, green: 0.92, blue: 0.90) : Color(red: 0.91, green: 0.97, blue: 0.91))
        )
    }

    private var launchConfigPreviewOverlay: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("本次启动使用的 config.toml")
                .font(.headline)
            ScrollView {
                Text(viewModel.lastLaunchedProxyConfigTOML ?? "")
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
            HStack {
                Spacer()
                Button("关闭") {
                    isShowingLaunchConfigPreview = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 340, height: 320, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.98, green: 0.99, blue: 1.00))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.gray.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 14, x: 0, y: 8)
    }

    private var footerSection: some View {
        HStack {
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func validationText(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(Color(red: 0.63, green: 0.14, blue: 0.12))
    }
}
