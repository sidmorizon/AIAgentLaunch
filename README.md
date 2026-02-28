# AIAgentLaunch

macOS 顶部菜单栏 Agent 启动器，支持 CODEX / CLAUDE 两个目标，并支持原版启动与 API 代理启动两种模式。

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
  - 打包 `AIAgentLaunch.app` 为 `AIAgentLaunch-<version>.dmg`；
  - 使用 Sparkle EdDSA 私钥签名更新包并生成 `appcast.xml`；
  - 发布到 GitHub Release（tag: `v<version>`）。
- Release workflow 依赖仓库 Secrets：
  - `SPARKLE_PUBLIC_ED_KEY`：写入应用 `Info.plist` 的 `SUPublicEDKey`；
  - `SPARKLE_PRIVATE_ED_KEY`：用于签名 dmg 并写入 `sparkle:edSignature`。
- 菜单栏界面会读取版本并展示 `v<version>`。
- 应用内“检测升级”由 Sparkle 处理，依赖发布产物中的 `appcast.xml` 与 dmg 资产。
- 仅 CI Release 流程打包的安装包会启用升级检测；本地开发构建点击“检测升级”会提示开发环境不支持。

## Dev Watch Mode

```bash
make dev
```

监听 `Sources/`、`Tests/`、`Package.swift`、`Makefile` 变更并自动重启。

## Security Notes

- API Key 与 Base URL / Model 一样，持久化到 `UserDefaults`（普通本地存储）。
- 应用不再依赖 Keychain 读取 API Key，启动不会出现 Keychain 访问弹窗。
- CODEX 的代理启动流程会临时写入 `~/.codex/config.toml`，同时备份原 `~/.codex/auth.json` 并写入 API 模式的 `auth.json`；下次通过原版模式启动 CODEX 时会恢复之前备份的 `auth.json`。
- CLAUDE 的启动流程为 Env-Only：仅在启动进程时注入环境变量，不读取也不改写 `claude_desktop_config.json`。

## Current Scope And Known Limitations

- 当前内置目标：
  - CODEX（`com.openai.codex`）
  - CLAUDE Desktop（`com.anthropic.claudefordesktop`）
- CLAUDE 代理模式会注入兼容环境变量（如 `ANTHROPIC_API_KEY`、`OPENAI_API_KEY`、`ANTHROPIC_BASE_URL`、`OPENAI_BASE_URL` 等）；部分非官方键可能被客户端忽略。
- 模型配置写入使用占位字段映射，后续可按 Provider 的真实字段做细化校对。
- 菜单栏输入状态（Base URL、API Key、Model、Reasoning）会持久化到 `UserDefaults`。
