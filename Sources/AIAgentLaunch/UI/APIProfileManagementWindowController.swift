import AgentLaunchCore
import AppKit
import SwiftUI

@MainActor
final class APIProfileManagementWindowController: ObservableObject {
    private var managementWindowControllers: [NSWindowController] = []
    private var windowCloseObservers: [ObjectIdentifier: NSObjectProtocol] = [:]
    private var previousActivationPolicy: NSApplication.ActivationPolicy?

    func present(viewModel: MenuBarViewModel) {
        DispatchQueue.main.async {
            self.openNewWindow(viewModel: viewModel)
        }
    }

    func close() {
        managementWindowControllers.last?.close()
    }

    private func openNewWindow(viewModel: MenuBarViewModel) {
        let windowController = makeWindowController(viewModel: viewModel)
        guard let window = windowController.window else { return }
        let app = NSApplication.shared
        if managementWindowControllers.isEmpty {
            previousActivationPolicy = app.activationPolicy()
        }
        if app.activationPolicy() != .regular {
            _ = app.setActivationPolicy(.regular)
        }
        managementWindowControllers.append(windowController)

        windowController.showWindow(nil)
        app.activate(ignoringOtherApps: true)
        window.makeMain()
        window.makeKeyAndOrderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak window] in
            guard let window else { return }
            app.activate(ignoringOtherApps: true)
            window.makeMain()
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func makeWindowController(viewModel: MenuBarViewModel) -> NSWindowController {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: NSSize(width: 520, height: 520)),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentView = NSHostingView(
            rootView: APIProfileManagementWindow(
                viewModel: viewModel,
                onClose: {
                    window.close()
                }
            )
        )
        window.title = "API 管理"
        window.minSize = NSSize(width: 460, height: 420)
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.center()
        let windowController = NSWindowController(window: window)
        let observerToken = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: nil
        ) { [weak self, weak windowController] _ in
            Task { @MainActor [weak self, weak windowController] in
                guard let self, let windowController else { return }
                let identifier = ObjectIdentifier(windowController)
                if let token = self.windowCloseObservers.removeValue(forKey: identifier) {
                    NotificationCenter.default.removeObserver(token)
                }
                self.managementWindowControllers.removeAll { $0 === windowController }
                if self.managementWindowControllers.isEmpty, let previousPolicy = self.previousActivationPolicy {
                    _ = NSApplication.shared.setActivationPolicy(previousPolicy)
                    self.previousActivationPolicy = nil
                }
            }
        }
        windowCloseObservers[ObjectIdentifier(windowController)] = observerToken
        return windowController
    }
}

private struct APIProfileManagementWindow: View {
    private struct ProfileDraft: Equatable {
        var name: String
        var baseURLText: String
        var apiKey: String

        static let empty = ProfileDraft(name: "", baseURLText: "", apiKey: "")
    }

    @ObservedObject var viewModel: MenuBarViewModel
    let onClose: () -> Void

    @State private var selectedProfileID: UUID?
    @State private var newProfileName = ""
    @State private var newProfileBaseURL = ""
    @State private var newProfileAPIKey = ""
    @State private var lastPersistedDraft: ProfileDraft = .empty
    @State private var autoSaveTask: Task<Void, Never>?
    @State private var isTestingDraftConnection = false
    @State private var draftTestMessage: String?
    @State private var isDraftTestError = false
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        MenuBarSheetContainer(title: "API 管理", systemImage: "list.bullet.rectangle") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("新增") {
                        try? viewModel.addProfile(
                            name: newProfileName,
                            baseURLText: newProfileBaseURL,
                            apiKey: newProfileAPIKey,
                            setActive: false
                        )
                        selectedProfileID = nil
                        clearEditor()
                        isNameFieldFocused = true
                    }
                    .buttonStyle(.borderedProminent)

                    Button("删除") {
                        guard let selectedProfileID else { return }
                        try? viewModel.deleteProfile(selectedProfileID)
                        self.selectedProfileID = viewModel.activeProfileID
                        loadEditor(for: self.selectedProfileID)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .disabled(selectedProfileID == nil)

                    Spacer()
                }

                List(viewModel.profiles, id: \.id, selection: $selectedProfileID) { profile in
                    HStack {
                        Button(action: {
                            do {
                                try viewModel.selectActiveProfile(profile.id)
                            } catch {
                                return
                            }
                        }) {
                            Image(systemName: viewModel.activeProfileID == profile.id ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(viewModel.activeProfileID == profile.id ? Color.green : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .frame(width: 30, height: 30)
                        .disabled(viewModel.activeProfileID == profile.id)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                            Text(profile.baseURLText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(minHeight: 30)
                }
                .frame(minHeight: 220)

                MenuBarField("配置名称") {
                    TextField("默认配置", text: $newProfileName)
                        .textFieldStyle(.roundedBorder)
                        .focused($isNameFieldFocused)
                }
                MenuBarField("BASE URL") {
                    TextField("https://api.example.com/v1", text: $newProfileBaseURL)
                        .textFieldStyle(.roundedBorder)
                }
                MenuBarField("API KEY") {
                    SecureField("sk-...", text: $newProfileAPIKey)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 8) {
                    Button(isTestingDraftConnection ? "TESTING..." : "测试连接") {
                        testDraftConnection()
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canTestDraftConnection)

                    if let draftTestMessage {
                        if isDraftTestError {
                            MenuBarValidationText(text: draftTestMessage)
                        } else {
                            MenuBarStatusBadge(text: draftTestMessage, tone: .success)
                        }
                    }

                    Spacer()
                }

                HStack {
                    Spacer()
                    Button("关闭", action: onClose)
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .onAppear {
            selectedProfileID = viewModel.activeProfileID
            loadEditor(for: selectedProfileID)
            isNameFieldFocused = true
        }
        .onChange(of: selectedProfileID) { _, newValue in
            loadEditor(for: newValue)
        }
        .onChange(of: newProfileName) { _, _ in
            handleEditorInputChanged()
        }
        .onChange(of: newProfileBaseURL) { _, _ in
            handleEditorInputChanged()
        }
        .onChange(of: newProfileAPIKey) { _, _ in
            handleEditorInputChanged()
        }
        .onDisappear {
            autoSaveTask?.cancel()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard let window = notification.object as? NSWindow else { return }
            guard window.title == "API 管理" else { return }
            isNameFieldFocused = true
        }
    }

    private var currentDraft: ProfileDraft {
        ProfileDraft(
            name: newProfileName,
            baseURLText: newProfileBaseURL,
            apiKey: newProfileAPIKey
        )
    }

    private var canTestDraftConnection: Bool {
        !isTestingDraftConnection &&
            !newProfileBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handleEditorInputChanged() {
        clearDraftTestFeedback()
        scheduleAutoSave()
    }

    private func scheduleAutoSave() {
        autoSaveTask?.cancel()
        guard selectedProfileID != nil else { return }
        autoSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            attemptAutoSaveSelectedProfile()
        }
    }

    private func attemptAutoSaveSelectedProfile() {
        guard let selectedProfileID else { return }
        let draft = currentDraft
        guard draft != lastPersistedDraft else { return }
        guard !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try viewModel.updateProfile(
                selectedProfileID,
                name: draft.name,
                baseURLText: draft.baseURLText,
                apiKey: draft.apiKey
            )
            lastPersistedDraft = draft
        } catch {
            return
        }
    }

    private func testDraftConnection() {
        let draft = currentDraft
        isTestingDraftConnection = true
        clearDraftTestFeedback()
        Task {
            let result = await viewModel.testConnectionForProfile(
                baseURLText: draft.baseURLText,
                apiKey: draft.apiKey
            )
            await MainActor.run {
                isTestingDraftConnection = false
                draftTestMessage = result.message
                isDraftTestError = !result.isSuccess
            }
        }
    }

    private func loadEditor(for profileID: UUID?) {
        autoSaveTask?.cancel()
        guard let profileID,
              let profile = viewModel.profiles.first(where: { $0.id == profileID }) else {
            clearEditor()
            return
        }
        newProfileName = profile.name
        newProfileBaseURL = profile.baseURLText
        newProfileAPIKey = profile.apiKey
        lastPersistedDraft = currentDraft
        clearDraftTestFeedback()
    }

    private func clearEditor() {
        autoSaveTask?.cancel()
        newProfileName = ""
        newProfileBaseURL = ""
        newProfileAPIKey = ""
        lastPersistedDraft = currentDraft
        clearDraftTestFeedback()
    }

    private func clearDraftTestFeedback() {
        draftTestMessage = nil
        isDraftTestError = false
    }
}
