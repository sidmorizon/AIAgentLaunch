# AIAgentLaunch

macOS 顶部菜单栏 Agent 启动器，支持原版启动与 API 代理启动两种模式。

## Requirements

- macOS 14+
- Swift 6 toolchain（Xcode 16+）
- `make dev` 需要 `watchexec`（`brew install watchexec`）

## Run

```bash
make run
```

或：

```bash
swift run AIAgentLaunch
```

## Build And Test

```bash
make build
make test
```

## Dev Watch Mode

```bash
make dev
```

监听 `Sources/`、`Tests/`、`Package.swift`、`Makefile` 变更并自动重启。

## Security Notes

- API Key 存储在 Keychain，不落盘到 `UserDefaults`。
- Keychain 访问策略优先生物识别（`biometryCurrentSet`），不可用时降级为 `userPresence`。
- 当运行环境缺少受保护 Keychain 所需 entitlement（常见于 `swift run`）时，会自动降级为 `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` 存储以避免 `OSStatus -34018`。
- 代理启动流程会临时写入 Provider 配置（当前为 Codex `~/.codex/config.toml`），随后在应用启动通知或超时路径中自动恢复原始配置。

## Current Scope And Known Limitations

- 当前仅内置 Codex Provider（`com.openai.codex`）。
- 模型配置写入使用占位字段映射，后续可按 Provider 的真实字段做细化校对。
- 菜单栏输入状态（Base URL、API Key、Model）当前不做持久化。
