import AgentLaunchCore
import AppKit
import SwiftUI

private enum LaunchConfigPreviewWindowLayout {
    static let initialSize = NSSize(width: 620, height: 520)
    static let minimumSize = NSSize(width: 500, height: 420)
}

@MainActor
final class LaunchConfigPreviewWindowController: ObservableObject {
    private var previewWindow: NSWindow?

    func present(
        launchLogText: String,
        claudeCLIEnvironment: [String: String]? = nil,
        claudeModelOptions: [String] = []
    ) {
        guard !launchLogText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let window = previewWindow ?? makeWindow()
        window.contentView = NSHostingView(
            rootView: LaunchConfigPreviewWindow(
                launchLogText: launchLogText,
                claudeCLIEnvironment: claudeCLIEnvironment,
                claudeModelOptions: claudeModelOptions,
                onClose: { [weak self] in
                    self?.close()
                }
            )
        )
        NSApplication.shared.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func close() {
        previewWindow?.orderOut(nil)
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: LaunchConfigPreviewWindowLayout.initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Agent 启动日志"
        window.minSize = LaunchConfigPreviewWindowLayout.minimumSize
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.center()
        previewWindow = window
        return window
    }
}

private struct LaunchConfigPreviewWindow: View {
    private static let opusModelKey = "ANTHROPIC_DEFAULT_OPUS_MODEL"
    private static let sonnetModelKey = "ANTHROPIC_DEFAULT_SONNET_MODEL"
    private static let haikuModelKey = "ANTHROPIC_DEFAULT_HAIKU_MODEL"
    private static let subagentModelKey = "CLAUDE_CODE_SUBAGENT_MODEL"

    let launchLogText: String
    let claudeCLIEnvironment: [String: String]?
    let claudeModelOptions: [String]
    let onClose: () -> Void
    @State private var didCopyClaudeCLICommand = false
    @State private var selectedOpusModel: String
    @State private var selectedSonnetModel: String
    @State private var selectedHaikuModel: String
    @State private var selectedSubagentModel: String

    init(
        launchLogText: String,
        claudeCLIEnvironment: [String: String]?,
        claudeModelOptions: [String],
        onClose: @escaping () -> Void
    ) {
        self.launchLogText = launchLogText
        self.claudeCLIEnvironment = claudeCLIEnvironment
        self.claudeModelOptions = claudeModelOptions
        self.onClose = onClose

        let defaultEnvironment = claudeCLIEnvironment ?? [:]
        let defaultOptions = Self.resolvedModelOptions(
            from: claudeModelOptions,
            environment: claudeCLIEnvironment
        )
        let fallbackModel = defaultOptions.first ?? ""

        _selectedOpusModel = State(initialValue: defaultEnvironment[Self.opusModelKey] ?? fallbackModel)
        _selectedSonnetModel = State(initialValue: defaultEnvironment[Self.sonnetModelKey] ?? fallbackModel)
        _selectedHaikuModel = State(initialValue: defaultEnvironment[Self.haikuModelKey] ?? fallbackModel)
        _selectedSubagentModel = State(initialValue: defaultEnvironment[Self.subagentModelKey] ?? fallbackModel)
    }

    var body: some View {
        MenuBarSheetContainer(title: "Agent 启动日志", systemImage: "doc.plaintext") {
            ScrollView {
                Text(launchLogText)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            if let copyClaudeCLICommand = currentClaudeCLICommand {
                VStack(alignment: .leading, spacing: 8) {
                    modelOverridePicker(
                        title: Self.opusModelKey,
                        selection: $selectedOpusModel
                    )
                    modelOverridePicker(
                        title: Self.sonnetModelKey,
                        selection: $selectedSonnetModel
                    )
                    modelOverridePicker(
                        title: Self.haikuModelKey,
                        selection: $selectedHaikuModel
                    )
                    modelOverridePicker(
                        title: Self.subagentModelKey,
                        selection: $selectedSubagentModel
                    )

                    HStack {
                        Button("复制 Claude CLI 命令") {
                            copyToPasteboard(copyClaudeCLICommand)
                            didCopyClaudeCLICommand = true
                        }
                        .buttonStyle(.borderedProminent)

                        if didCopyClaudeCLICommand {
                            Text("已复制")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }

            HStack {
                Spacer()
                Button("关闭", action: onClose)
                    .keyboardShortcut(.cancelAction)
            }
        }
        .frame(
            minWidth: LaunchConfigPreviewWindowLayout.minimumSize.width,
            minHeight: LaunchConfigPreviewWindowLayout.minimumSize.height
        )
    }

    private var currentClaudeCLICommand: String? {
        guard let claudeCLIEnvironment = normalizedClaudeCLIEnvironment else { return nil }
        let updatedEnvironment = ClaudeLaunchEnvironment.applyingCLIDefaultModelOverrides(
            to: claudeCLIEnvironment,
            opusModel: selectedOpusModel,
            sonnetModel: selectedSonnetModel,
            haikuModel: selectedHaikuModel,
            subagentModel: selectedSubagentModel
        )
        return ClaudeLaunchEnvironment.renderCLICommand(from: updatedEnvironment)
    }

    private var normalizedClaudeCLIEnvironment: [String: String]? {
        guard let claudeCLIEnvironment else { return nil }
        return claudeCLIEnvironment.isEmpty ? nil : claudeCLIEnvironment
    }

    private var availableModelOptions: [String] {
        Self.resolvedModelOptions(from: claudeModelOptions, environment: normalizedClaudeCLIEnvironment)
    }

    private func modelOverridePicker(title: String, selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(availableModelOptions, id: \.self) { modelIdentifier in
                    Text(modelIdentifier).tag(modelIdentifier)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private static func resolvedModelOptions(
        from options: [String],
        environment: [String: String]?
    ) -> [String] {
        var normalizedOptions: [String] = []
        for option in options {
            let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard !normalizedOptions.contains(trimmed) else { continue }
            normalizedOptions.append(trimmed)
        }
        if !normalizedOptions.isEmpty {
            return normalizedOptions
        }

        var fallbackOptions: [String] = []

        func appendFallbackIfNeeded(_ value: String?) {
            guard let value else { return }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            guard !fallbackOptions.contains(trimmed) else { return }
            fallbackOptions.append(trimmed)
        }

        appendFallbackIfNeeded(environment?[opusModelKey])
        appendFallbackIfNeeded(environment?[sonnetModelKey])
        appendFallbackIfNeeded(environment?[haikuModelKey])
        appendFallbackIfNeeded(environment?[subagentModelKey])
        appendFallbackIfNeeded(environment?["ANTHROPIC_MODEL"])
        appendFallbackIfNeeded(environment?["OPENAI_MODEL"])

        return fallbackOptions
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
