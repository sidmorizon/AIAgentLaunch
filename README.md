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

## Version And Release

- 项目版本由仓库根目录 [`version`](version) 文件定义（例如 `0.1.0`）。
- GitHub Actions 监听 `main` 分支上的 `version` 变更，自动执行：
  - 校验版本号必须递增；
  - 打包 `AIAgentLaunch.app` 为 `AIAgentLaunch-<version>.zip`；
  - 使用 Sparkle EdDSA 私钥签名更新包并生成 `appcast.xml`；
  - 发布到 GitHub Release（tag: `v<version>`）。
- Release workflow 依赖仓库 Secrets：
  - `SPARKLE_PUBLIC_ED_KEY`：写入应用 `Info.plist` 的 `SUPublicEDKey`；
  - `SPARKLE_PRIVATE_ED_KEY`：用于签名 zip 并写入 `sparkle:edSignature`。
- 菜单栏界面会读取版本并展示 `v<version>`。
- 应用内“检测升级”由 Sparkle 处理，依赖发布产物中的 `appcast.xml` 与 zip 资产。

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
