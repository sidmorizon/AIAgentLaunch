# Get My Keys

一个基于 Next.js App Router 的小应用：
- 页面路径：`/get-my-keys`
- 接口路径：`POST /get-my-keys/api/key`
- 前端通过 Google Identity Services 登录，提交 ID token 到后端
- 后端验签后仅允许 `@onekey.so` 且 `email_verified=true` 的账号生成 Key

## 常量统一配置

所有可配置常量统一在：
- `lib/shared/constants.ts`

包括：
- `GOOGLE_OAUTH_CLIENT_ID`
- `KEY_SALT`
- `ALLOWED_EMAIL_SUFFIX`
- `NEXT_BASE_PATH`
- `KEY_API_PATH`

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
- `http://localhost:3000/get-my-keys`

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
