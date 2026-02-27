# Get My Keys

一个基于 Next.js App Router 的小应用：
- 页面路径：`/get-my-keys`
- 接口路径：`POST /get-my-keys/api/key`
- 前端通过 Google Identity Services 登录，提交 ID token 到后端
- 后端验签后仅允许 `@onekey.so` 且 `email_verified=true` 的账号生成 Key

## 环境变量配置

业务代码仍通过 `lib/shared/constants.ts` 读取配置，常量值来自环境变量。

先复制模板：

```bash
cp .env.example .env
```

必填环境变量：
- `GOOGLE_OAUTH_CLIENT_ID`
- `KEY_SALT`
- `KEY_PREFIX`
- `ALLOWED_EMAIL_SUFFIX`
- `KEY_PERSIST_FILE_PATH`
- `KEY_SYNC_YAML_FILE_PATH`
- `AGENT_LAUNCHER_FILE_PATH`

说明：
- 前端使用的 Google Client ID 来自 `GOOGLE_OAUTH_CLIENT_ID`（通过 Next.js 暴露为 `NEXT_PUBLIC_GOOGLE_OAUTH_CLIENT_ID`）。
- 若配置缺失，服务仍可启动；前端会显示配置错误，`/api/key` 返回 `SERVER_CONFIG_MISSING`。
- “下载 Agent 启动器”按钮会调用 `GET /get-my-keys/api/agent-launcher`，读取 `AGENT_LAUNCHER_FILE_PATH` 指向的本地文件并触发下载。

## Key 生成规则

后端使用固定规则生成 Key：
- `sha256(sub:email:salt)`
- 输出格式：64 位小写十六进制字符串

前端展示时仅显示脱敏值：
- 前 6 + 星号 + 后 4
- 点击复制按钮复制完整 Key

## 开发与运行

```bash
npm install
npm run dev
```

默认开发地址：
- `http://localhost:3721/get-my-keys`

## 测试

```bash
npm test
```

当前测试覆盖：
- `buildKey` 与 `maskKey` 纯函数
- Google token 验签与邮箱授权逻辑
- `/api/key` 的 400/401/403/422/200 分支
- 前端页面请求路径前缀与错误展示
- 复制按钮行为（复制完整 Key + 反馈文案切换）

## 服务器启动脚本（Git 拉取 + 重编译 + 启动）

已提供脚本：
- `scripts/server-start.sh`

脚本执行流程：
1. `git pull --ff-only` 拉取最新代码
2. `npm ci` + `npm run build` 重新安装依赖并编译
3. `npm run start` 前台启动服务（适配 `systemd`）

示例：

```bash
cd /opt/get-my-keys/apps/get-my-keys-server
GIT_BRANCH=main PORT=3721 ./scripts/server-start.sh
```

## systemd 自启动示例（推荐）

建议将以下内容保存为 `/etc/systemd/system/get-my-keys.service`：

```ini
[Unit]
Description=Get My Keys (Next.js)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=deploy
Group=deploy
WorkingDirectory=/opt/get-my-keys/apps/get-my-keys-server
Environment=PORT=3721
Environment=HOST=0.0.0.0
Environment=GIT_BRANCH=main
ExecStart=/opt/get-my-keys/apps/get-my-keys-server/scripts/server-start.sh
Restart=always
RestartSec=5
TimeoutStartSec=600
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

启用：

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now get-my-keys
sudo systemctl status get-my-keys
```

## Node 生产部署最佳实践

- 使用专用低权限账号（如 `deploy`）运行服务，不使用 `root`
- 生产环境只允许快进拉取（`git pull --ff-only`），避免隐式 merge
- 避免在服务器工作目录手工改代码，减少拉取冲突
- 将配置放在环境变量（`PORT`、OAuth、盐值等），不要写死在代码仓库
- 由 `systemd` 管理进程与重启策略，不要让应用自己守护
- 通过 `journalctl -u get-my-keys -f` 统一查看日志
