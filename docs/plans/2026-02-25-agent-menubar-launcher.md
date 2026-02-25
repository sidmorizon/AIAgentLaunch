# Agent Menu Bar Launcher Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 实现一个常驻 macOS 顶部菜单栏的通用 Agent 启动器，支持“原版 / API 代理版”模式切换；API 代理版支持 BaseURL/APIKey（Keychain 存储，优先生物识别、降级系统密码）、模型拉取、思考强度选择，并通过 Provider 定义的配置路径进行临时改写与自动回滚。

**Architecture:** 采用 SwiftUI `MenuBarExtra` + MVVM。`AgentLaunchCore` 模块负责配置渲染、配置事务（备份/写入/恢复）、Keychain、模型发现、启动器。新增 `AgentProviderBase` 协议定义 Provider 能力（配置路径、临时配置渲染、启动 bundle id），并以通用 Provider 实现作为首个落地；未来可扩展 Claude Code、Cursor 等 Provider。启动链路为 `apply temp config -> launch provider app -> restore config`，并使用通知+超时双保险做幂等恢复。

**Tech Stack:** Swift 6, SwiftUI/AppKit, Security.framework(Keychain), URLSession, XCTest, Swift Package Manager.

**Branch:** `ai-agent/agent-menubar-launcher`

**Local Dev Commands（当前代码）:**
- `make run`：启动菜单栏应用（等价 `swift run AIAgentLaunch`）
- `make build`：构建
- `make test`：测试
- `make dev`：监听文件变更自动重启（依赖 `watchexec`）

**Execution Status (2026-02-25):**
- [x] Task 1: 初始化工程骨架（SwiftPM + 双 Target）
- [x] Task 2: 配置模型与 TOML 渲染器
- [x] Task 3: 配置事务（备份/写入/恢复，含幂等）
- [x] Task 4: Keychain 服务（生物识别优先，降级系统密码）
- [x] Task 5: 模型发现服务（OpenAI 兼容 /v1/models）
- [x] Task 6: 启动器编排（apply -> launch -> restore）
- [x] Task 7: ViewModel + 菜单栏 UI
- [x] Task 8: 收尾验证与使用文档

---

### Task 1: 初始化工程骨架（SwiftPM + 双 Target）

**Files:**
- Delete: `package.json`
- Create: `.gitignore`
- Create: `Package.swift`
- Create: `Makefile`
- Create: `Sources/AgentLaunchCore/Placeholder.swift`
- Create: `Sources/AIAgentLaunch/AIAgentLaunchApp.swift`
- Create: `Tests/AgentLaunchCoreTests/SmokeTests.swift`

**Step 1: 建立最小 failing 测试（@test-driven-development）**

```swift
import XCTest
@testable import AgentLaunchCore

final class SmokeTests: XCTestCase {
    func testCoreModuleLoads() {
        XCTAssertEqual(agentLaunchCoreVersion(), "0.1.0")
    }
}
```

**Step 2: 运行测试确认失败**

Run: `swift test --filter SmokeTests/testCoreModuleLoads`
Expected: FAIL with `cannot find 'agentLaunchCoreVersion' in scope`

**Step 3: 写最小实现让测试通过**

```swift
public func agentLaunchCoreVersion() -> String { "0.1.0" }
```

**Step 4: 运行测试确认通过**

Run: `swift test --filter SmokeTests/testCoreModuleLoads`
Expected: PASS

**Step 4.1: 启动壳 UI（当前代码基线）**

`AIAgentLaunchApp` 菜单包含：
- 标题文案 `Agent Launcher`
- `Quit` 菜单项，调用 `NSApplication.shared.terminate(nil)` 退出应用

**Step 5: Commit**

```bash
git init
git add .
git commit -m "chore: bootstrap swift package for agent menubar launcher"
```

### Task 2: 配置模型与 TOML 渲染器

**Files:**
- Create: `Sources/AgentLaunchCore/Models/LaunchMode.swift`
- Create: `Sources/AgentLaunchCore/Models/ReasoningEffort.swift`
- Create: `Sources/AgentLaunchCore/Models/AgentProxyLaunchConfig.swift`
- Create: `Sources/AgentLaunchCore/Config/AgentConfigRenderer.swift`
- Create: `Sources/AgentLaunchCore/Providers/AgentProviderBase.swift`
- Create: `Sources/AgentLaunchCore/Providers/AgentProviderCodex.swift`
- Create: `Tests/AgentLaunchCoreTests/Config/AgentConfigRendererTests.swift`

**Step 1: 写 failing 测试（验证临时配置渲染）**

```swift
func testRenderProxyConfigContainsRequiredFields() {
    let launchConfiguration = AgentProxyLaunchConfig(
        apiBaseURL: URL(string: "https://example.com/v1")!,
        providerAPIKey: "sk-test",
        modelIdentifier: "gpt-5",
        reasoningLevel: .medium
    )

    let renderedConfiguration = AgentConfigRenderer().renderTemporaryConfiguration(from: launchConfiguration)

    XCTAssertTrue(renderedConfiguration.contains("base_url = \"https://example.com/v1\""))
    XCTAssertTrue(renderedConfiguration.contains("api_key = \"sk-test\""))
    XCTAssertTrue(renderedConfiguration.contains("model = \"gpt-5\""))
    XCTAssertTrue(renderedConfiguration.contains("model_reasoning_effort = \"medium\""))
}
```

**Step 2: 运行测试确认失败**

Run: `swift test --filter AgentConfigRendererTests/testRenderProxyConfigContainsRequiredFields`
Expected: FAIL with `Cannot find 'AgentConfigRenderer' in scope`

**Step 3: 最小实现**

```swift
public struct AgentConfigRenderer {
    public init() {}

    public func renderTemporaryConfiguration(from launchConfiguration: AgentProxyLaunchConfig) -> String {
        return """
        model = "\(launchConfiguration.modelIdentifier)"
        model_reasoning_effort = "\(launchConfiguration.reasoningLevel.rawValue)"

        [model_providers.custom]
        name = "Custom OpenAI Compatible"
        base_url = "\(launchConfiguration.apiBaseURL.absoluteString)"
        api_key = "\(launchConfiguration.providerAPIKey)"
        wire_api = "responses"
        """
    }
}
```

**Step 4: 运行测试确认通过**

Run: `swift test --filter AgentConfigRendererTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentLaunchCore/Models Sources/AgentLaunchCore/Config Tests/AgentLaunchCoreTests/Config
git commit -m "feat: add agent config models renderer and provider base wiring"
```

### Task 3: 配置事务（备份/写入/恢复，含幂等）

**Files:**
- Create: `Sources/AgentLaunchCore/Config/ConfigTransaction.swift`
- Create: `Tests/AgentLaunchCoreTests/Config/ConfigTransactionTests.swift`

**Step 1: 写 failing 测试（文件存在与不存在两种恢复）**

```swift
func testRestoreRewritesOriginalContentWhenFileExisted() throws {
    // Arrange temp provider config.toml with original text
    // Apply temporary content, then restore
    // Assert content equals original
}

func testRestoreDeletesFileWhenOriginallyAbsent() throws {
    // Arrange no config file
    // Apply temporary content, then restore
    // Assert file removed
}

func testRestoreIsIdempotent() throws {
    // restore called twice should not throw and final state unchanged
}
```

**Step 2: 运行测试确认失败**

Run: `swift test --filter ConfigTransactionTests`
Expected: FAIL with missing type/methods

**Step 3: 最小实现（事务状态 + 幂等恢复）**

```swift
public final class ConfigTransaction {
    public enum OriginalState { case absent, content(String) }

    private var originalState: OriginalState?
    private var restored = false

    public func applyTemporaryConfiguration(_ temporaryConfiguration: String, at configurationFilePath: URL) throws { /* backup + atomic write */ }
    public func restoreOriginalConfiguration(at configurationFilePath: URL) throws { /* idempotent restore */ }
}
```

**Step 4: 运行测试确认通过**

Run: `swift test --filter ConfigTransactionTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentLaunchCore/Config/ConfigTransaction.swift Tests/AgentLaunchCoreTests/Config/ConfigTransactionTests.swift
git commit -m "feat: implement agent config transactional apply and restore"
```

### Task 4: Keychain 服务（生物识别优先，降级系统密码）

**Files:**
- Create: `Sources/AgentLaunchCore/Security/KeychainAPI.swift`
- Create: `Sources/AgentLaunchCore/Security/KeychainService.swift`
- Create: `Tests/AgentLaunchCoreTests/Security/KeychainServiceTests.swift`

**Step 1: 写 failing 测试（access control 选择）**

```swift
func testAccessControlPrefersBiometryCurrentSet() {
    // mock capability: biometry available
    // assert selected policy == biometryCurrentSet
}

func testFallbackToUserPresenceWhenBiometryUnavailable() {
    // mock capability: biometry unavailable
    // assert selected policy == userPresence
}
```

**Step 2: 运行测试确认失败**

Run: `swift test --filter KeychainServiceTests`
Expected: FAIL with missing service implementation

**Step 3: 最小实现**

```swift
public enum KeychainAuthPolicy { case biometryCurrentSet, userPresence }

public final class KeychainService {
    public func resolvePolicy() -> KeychainAuthPolicy { /* capability -> policy */ }
    public func saveAPIKey(_ key: String) throws { /* SecItemAdd / SecItemUpdate */ }
    public func readAPIKey() throws -> String { /* SecItemCopyMatching */ }
}
```

**Step 4: 运行测试确认通过**

Run: `swift test --filter KeychainServiceTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentLaunchCore/Security Tests/AgentLaunchCoreTests/Security
git commit -m "feat: add keychain api key storage with biometric fallback policy"
```

### Task 5: 模型发现服务（OpenAI 兼容 /v1/models）

**Files:**
- Create: `Sources/AgentLaunchCore/Networking/ModelDiscoveryService.swift`
- Create: `Tests/AgentLaunchCoreTests/Networking/ModelDiscoveryServiceTests.swift`

**Step 1: 写 failing 测试（成功与常见失败映射）**

```swift
func testFetchModelsReturnsSortedModelIDs() async throws { /* mock 200 JSON */ }
func testFetchModelsMaps401ToUnauthorizedError() async throws { /* mock 401 */ }
func testFetchModelsMapsInvalidJSONToDecodeError() async throws { /* mock bad body */ }
```

**Step 2: 运行测试确认失败**

Run: `swift test --filter ModelDiscoveryServiceTests`
Expected: FAIL with missing service

**Step 3: 最小实现**

```swift
public final class ModelDiscoveryService {
    public func fetchModels(apiBaseURL: URL, providerAPIKey: String) async throws -> [String] {
        // GET {baseURL}/models
        // parse data[].id
    }
}
```

**Step 4: 运行测试确认通过**

Run: `swift test --filter ModelDiscoveryServiceTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentLaunchCore/Networking Tests/AgentLaunchCoreTests/Networking
git commit -m "feat: implement openai-compatible model discovery service"
```

### Task 6: 启动器编排（apply -> launch -> restore）

**Files:**
- Create: `Sources/AgentLaunchCore/Launch/AgentLauncher.swift`
- Create: `Sources/AgentLaunchCore/Launch/AgentLaunchCoordinator.swift`
- Create: `Tests/AgentLaunchCoreTests/Launch/AgentLaunchCoordinatorTests.swift`

**Step 1: 写 failing 测试（启动成功与失败都恢复）**

```swift
func testLaunchSuccessRestoresAfterLaunchNotification() async throws {
    // fake launcher emits didLaunch
    // assert restore called once
}

func testLaunchFailureStillRestores() async throws {
    // fake launcher throws
    // assert restore called once and error propagated
}

func testLaunchRestoreFallbackTimeout() async throws {
    // no launch notification
    // assert restore on timeout path
}
```

**Step 2: 运行测试确认失败**

Run: `swift test --filter AgentLaunchCoordinatorTests`
Expected: FAIL with missing coordinator

**Step 3: 最小实现**

```swift
public final class AgentLaunchCoordinator {
    public func launchWithTemporaryConfiguration(_ launchConfiguration: AgentProxyLaunchConfig) async throws {
        // apply temp config
        // launch selected provider bundle id
        // restore on didLaunch or timeout
    }
}
```

**Step 4: 运行测试确认通过**

Run: `swift test --filter AgentLaunchCoordinatorTests`
Expected: PASS

**Step 5: Commit**

```bash
git add Sources/AgentLaunchCore/Launch Tests/AgentLaunchCoreTests/Launch
git commit -m "feat: add provider-driven launch coordinator with guaranteed restore"
```

### Task 7: ViewModel + 菜单栏 UI

**Files:**
- Create: `Sources/AgentLaunchCore/ViewModel/MenuBarViewModel.swift`
- Create: `Sources/AIAgentLaunch/UI/MenuBarContentView.swift`
- Modify: `Sources/AIAgentLaunch/AIAgentLaunchApp.swift`
- Create: `Tests/AgentLaunchCoreTests/ViewModel/MenuBarViewModelTests.swift`

**Step 1: 写 failing 测试（状态切换与启动按钮可用性）**

```swift
func testProxyModeRequiresFieldsBeforeLaunchEnabled() {
    // mode .proxy + missing fields => disabled
    // mode .proxy + all fields => enabled
}

func testLaunchInOriginalModeSkipsTransaction() async throws {
    // assert direct launcher path
}
```

**Step 2: 运行测试确认失败**

Run: `swift test --filter MenuBarViewModelTests`
Expected: FAIL with missing view model

**Step 3: 最小实现**

```swift
@MainActor
public final class MenuBarViewModel: ObservableObject {
    @Published var mode: LaunchMode = .original
    @Published var baseURLText: String = ""
    @Published var apiKeyMasked: String = ""
    @Published var models: [String] = []
    @Published var selectedModel: String = ""
    @Published var reasoningLevel: ReasoningEffort = .medium

    var canLaunch: Bool { /* derive from mode + inputs */ }
    func testConnection() async { /* call model discovery */ }
    func launchSelectedAgent() async { /* call coordinator */ }
}
```

**Step 4: 运行测试与构建**

Run: `swift test --filter MenuBarViewModelTests`
Expected: PASS

Run: `swift build`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Sources/AgentLaunchCore/ViewModel Sources/AIAgentLaunch/UI Sources/AIAgentLaunch/AIAgentLaunchApp.swift Tests/AgentLaunchCoreTests/ViewModel
git commit -m "feat: add menubar view model and swiftui menu content"
```

### Task 8: 收尾验证与使用文档

**Files:**
- Create: `README.md`
- Modify: `docs/plans/2026-02-25-agent-menubar-launcher.md` (勾选完成项)

**Step 1: 写 failing 验收清单测试（可选 smoke）**

```swift
func testReasoningEffortAllOptionsPresent() {
    XCTAssertEqual(ReasoningEffort.allCases.map(\.rawValue), ["none", "minimal", "low", "medium", "high"])
}
```

**Step 2: 运行完整验证（@verification-before-completion）**

Run: `swift test`
Expected: all PASS

Run: `swift build`
Expected: BUILD SUCCEEDED

Run: `swift run AIAgentLaunch`
Expected: 菜单栏出现应用图标，可展开交互，且菜单中包含 `Quit`

Run: `make run`
Expected: 与 `swift run AIAgentLaunch` 一致

Run: `make dev`
Expected: 修改 `Sources/`、`Tests/`、`Package.swift`、`Makefile` 后自动重启（需先安装 `watchexec`）

**Step 3: 更新 README（运行方式 + 安全说明 + 已知限制）**

```markdown
- APIKey 存 Keychain，不存 UserDefaults
- 启动流程为临时写入 Provider 配置后自动恢复
- config.toml 字段当前按占位映射，后续单独做字段核对
```

**Step 4: 最终提交**

```bash
git add README.md docs/plans/2026-02-25-agent-menubar-launcher.md
git commit -m "docs: add usage and verification notes for agent menubar launcher"
```
