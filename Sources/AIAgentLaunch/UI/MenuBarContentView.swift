import SwiftUI
import AgentLaunchCore

struct MenuBarContentView: View {
    @StateObject private var viewModel: MenuBarViewModel

    init(viewModel: MenuBarViewModel = MenuBarViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Mode", selection: $viewModel.mode) {
                Text("Original").tag(LaunchMode.original)
                Text("API Proxy").tag(LaunchMode.proxy)
            }
            .pickerStyle(.segmented)

            if viewModel.mode == .proxy {
                TextField("Base URL (https://.../v1)", text: $viewModel.baseURLText)
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key", text: $viewModel.apiKeyMasked)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button(viewModel.isTestingConnection ? "Testing..." : "Test Connection") {
                        Task {
                            await viewModel.testConnection()
                        }
                    }
                    .disabled(!viewModel.canTestConnection)
                }

                if !viewModel.models.isEmpty {
                    Picker("Model", selection: $viewModel.selectedModel) {
                        ForEach(viewModel.models, id: \.self) { modelIdentifier in
                            Text(modelIdentifier).tag(modelIdentifier)
                        }
                    }
                }

                Picker("Reasoning", selection: $viewModel.reasoningLevel) {
                    ForEach(ReasoningEffort.allCases, id: \.self) { effort in
                        Text(effort.rawValue).tag(effort)
                    }
                }
            }

            Button(viewModel.isLaunching ? "Launching..." : "Launch Agent") {
                Task {
                    await viewModel.launchSelectedAgent()
                }
            }
            .disabled(!viewModel.canLaunch)

            if let statusMessage = viewModel.statusMessage {
                Text(statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: 330)
    }
}
