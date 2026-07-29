# 安全说明

## 本仓库绝不包含

- API Key、OAuth Token、Refresh Token、Cookie  
- `~/.grok/auth.json`、`~/.codex/auth.json` 或任何凭证导出  
- 真实账号的邮箱、账号 ID、用量截图数据  

## 运行时凭证（仅在你自己电脑上）

| 应用 | 本机读取 | 是否上传到本仓库 / 作者 |
|------|----------|-------------------------|
| Grok Credits | 通过 `grok-credits` 读 `~/.grok/auth.json` | 否，仅本地 |
| Codex Credits | 读 `~/.codex/auth.json` 中的 access token | 否，仅本地 |

Token 始终保存在用户磁盘。应用仅用**用户自己的**登录态调用官方用量相关接口；仓库维护者收不到任何凭证。

## 发现问题

若在某次提交或 PR 中发现疑似密钥，请先轮换/作废该凭证，再提 Issue（请勿把密钥贴到 Issue 里）。
