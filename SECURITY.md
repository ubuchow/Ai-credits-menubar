# 安全说明

## 本仓库绝不包含

- API Key、OAuth Token、Refresh Token、Cookie  
- `~/.grok/auth.json`、`~/.codex/auth.json`、DeepSeek API Key 或任何凭证导出  
- 真实账号的邮箱、账号 ID、用量截图数据  

## 运行时凭证（仅在你自己电脑上）

| 组件 | 本机读取 | 是否上传到本仓库 / 作者 |
|------|----------|-------------------------|
| **AI Credits**（`combined/`，推荐） | Grok `auth.json`；Codex `auth.json`；Hermes/DeepSeek 本机 Key 与 `~/.hermes/` | 否，仅本地 |
| Grok 独立应用 / 脚本（`grok/`） | 通过 `grok-credits` 读 `~/.grok/auth.json` | 否，仅本地 |
| Hermes 脚本（`hermes/`） | 本机 DeepSeek / Hermes 环境与 `state.db` | 否，仅本地 |
| Codex 独立应用 / 脚本（`codex/`） | 读 `~/.codex/auth.json` 中的 access token | 否，仅本地 |

Token 始终保存在用户磁盘。应用仅用**用户自己的**登录态调用官方用量相关接口；仓库维护者收不到任何凭证。

## 日志

统一应用可将标准输出/错误写到本机 `~/Library/Logs/AICreditsMenuBar/`（由 LaunchAgent 配置）。日志仅供本机排查，不上传。

## 发现问题

若在某次提交或 PR 中发现疑似密钥，请先轮换/作废该凭证，再提 Issue（请勿把密钥贴到 Issue 里）。
