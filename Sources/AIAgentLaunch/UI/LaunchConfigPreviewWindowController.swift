import AgentLaunchCore
import AppKit
import SwiftUI

private enum LaunchConfigPreviewWindowLayout {
    static let initialSize = NSSize(width: 620, height: 520)
    static let minimumSize = NSSize(width: 500, height: 420)
    static let inspectionSectionMinHeight: CGFloat = 0
    static let inspectionSectionMaxHeight: CGFloat = 150
    static let inspectionSectionLineHeight: CGFloat = 16
    static let inspectionSectionVerticalPadding: CGFloat = 22
    static let contentSpacing: CGFloat = 12
}

@MainActor
final class LaunchConfigPreviewWindowController: ObservableObject {
    private var previewWindow: NSWindow?

    func present(
        inspectionPayload: LaunchInspectionPayload,
        claudeModelOptions: [String] = []
    ) {
        let window = previewWindow ?? makeWindow()
        window.contentView = NSHostingView(
            rootView: LaunchConfigPreviewWindow(
                inspectionPayload: inspectionPayload,
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

    let inspectionPayload: LaunchInspectionPayload
    let claudeModelOptions: [String]
    let onClose: () -> Void
    @State private var didCopyClaudeCLICommand = false
    @State private var selectedOpusModel: String
    @State private var selectedSonnetModel: String
    @State private var selectedHaikuModel: String
    @State private var selectedSubagentModel: String

    init(
        inspectionPayload: LaunchInspectionPayload,
        claudeModelOptions: [String],
        onClose: @escaping () -> Void
    ) {
        self.inspectionPayload = inspectionPayload
        self.claudeModelOptions = claudeModelOptions
        self.onClose = onClose

        let defaultEnvironment = inspectionPayload.claudeCLIEnvironmentVariables ?? [:]
        let defaultOptions = Self.resolvedModelOptions(
            from: claudeModelOptions,
            environment: inspectionPayload.claudeCLIEnvironmentVariables
        )
        let fallbackModel = defaultOptions.first ?? ""

        _selectedOpusModel = State(initialValue: defaultEnvironment[Self.opusModelKey] ?? fallbackModel)
        _selectedSonnetModel = State(initialValue: defaultEnvironment[Self.sonnetModelKey] ?? fallbackModel)
        _selectedHaikuModel = State(initialValue: defaultEnvironment[Self.haikuModelKey] ?? fallbackModel)
        _selectedSubagentModel = State(initialValue: defaultEnvironment[Self.subagentModelKey] ?? fallbackModel)
    }

    var body: some View {
        MenuBarSheetContainer(title: "Agent 启动日志", systemImage: "doc.plaintext") {
            VStack(alignment: .leading, spacing: LaunchConfigPreviewWindowLayout.contentSpacing) {
                ScrollView {
                    LazyVStack(
                        alignment: .leading,
                        spacing: LaunchConfigPreviewWindowLayout.contentSpacing
                    ) {
                        if shouldShowCodexConfigSection {
                            inspectionSection(title: "config.toml", text: renderedCodexConfigTOMLText)
                        }

                        inspectionSection(title: "启动环境变量", text: renderedLaunchEnvironmentText)

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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(minHeight: 0, maxHeight: .infinity, alignment: .topLeading)

                Divider()
                HStack {
                    Spacer()
                    Button("关闭", action: onClose)
                        .keyboardShortcut(.cancelAction)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        guard let claudeCLIEnvironment = inspectionPayload.claudeCLIEnvironmentVariables else { return nil }
        return claudeCLIEnvironment.isEmpty ? nil : claudeCLIEnvironment
    }

    private var shouldShowCodexConfigSection: Bool {
        let hasCodexConfiguration = !(inspectionPayload.codexConfigTOMLText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty ?? true)
        if inspectionPayload.agent == .claude, !hasCodexConfiguration {
            return false
        }
        return true
    }

    private var renderedCodexConfigTOMLText: String {
        let text = inspectionPayload.codexConfigTOMLText?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "This launch did not modify config.toml." : text
    }

    private var renderedLaunchEnvironmentText: String {
        let snapshot = LaunchEnvironmentSnapshotFormatter
            .renderMaskedSnapshot(from: inspectionPayload.launchEnvironmentVariables)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return snapshot.isEmpty ? "No injected environment variables." : snapshot
    }

    private var availableModelOptions: [String] {
        Self.resolvedModelOptions(from: claudeModelOptions, environment: normalizedClaudeCLIEnvironment)
    }

    private func inspectionSection(title: String, text: String) -> some View {
        LaunchInspectionTextSection(
            title: title,
            text: text,
            minHeight: LaunchConfigPreviewWindowLayout.inspectionSectionMinHeight,
            maxHeight: LaunchConfigPreviewWindowLayout.inspectionSectionMaxHeight
        )
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
            .labelsHidden()
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

private struct LaunchInspectionTextSection: View {
    let title: String
    let text: String
    let minHeight: CGFloat
    let maxHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView([.vertical]) {
                Text(text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: sectionHeight)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
    }

    private var sectionHeight: CGFloat {
        let lineCount = max(text.split(separator: "\n", omittingEmptySubsequences: false).count, 1)
        let estimatedContentHeight =
            (CGFloat(lineCount) * LaunchConfigPreviewWindowLayout.inspectionSectionLineHeight)
            + LaunchConfigPreviewWindowLayout.inspectionSectionVerticalPadding
        return min(max(estimatedContentHeight, minHeight), maxHeight)
    }
}
