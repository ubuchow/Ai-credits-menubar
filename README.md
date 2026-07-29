# Ai工具余额展示

> 仓库名：**Ai-credits-menubar**

macOS **菜单栏常驻**小工具：在顶部菜单栏显示 **Grok Build** 与 **OpenAI Codex** 的用量余量与重置时间；任务运行时字母会闪烁提示。

设计目标是**轻量常驻、占用低、不打扰**——适合长时间挂着当「余额指示灯」。

## 功能一览

| 应用 | 图标 | 显示 | 任务进行中 |
|------|------|------|------------|
| **Grok Credits** | 蓝色单线圆环 + **G** | 剩余 % · 重置时间 · 下次订阅 · **今日/本月 Token** | 圆环内 **G** 闪烁 |
| **Codex Credits** | 橙色单线圆环 + **C** | 剩余 % · 重置时间 · 重置次数 · 下次订阅 · **今日/本月 Token** | 圆环内 **C** 闪烁 |

1. **余量监测**  
   菜单栏显示剩余百分比（如 `G 56%`、`C 57%`），点击可看重置时间等。  
   **默认每 2 分钟自动刷新**；也可点「立即刷新」马上更新。

2. **任务闪烁**  
   仅圆环内的字母闪烁；圆环与百分比保持不动。约 **每 2 秒** 检测是否在跑任务。

3. **登录自启**  
   安装后注册 LaunchAgent，登录系统后自动出现在菜单栏。

4. **任务音效**  
   任务进行中循环播放提示音，结束时播放结束音。菜单可点 **关闭音效 / 开启音效**（默认开启，本机记住选择）。

5. **本机登录态**  
   读取你电脑上已有的 Grok / Codex 登录配置，不把凭证提交到仓库。详见 [SECURITY.md](SECURITY.md)。

百分比与圆环内字母均使用 **Times New Roman**（字母为加粗）。

---

## 刷新时间与内存占用

### 刷新时间

| 内容 | 间隔 | 说明 |
|------|------|------|
| 余额 / 百分比 / 重置时间 | **2 分钟** | 定时向服务端查询；兼顾及时与省资源 |
| 任务是否在跑 | **约 2 秒** | 只影响是否闪烁，不拉用量接口 |
| 手动刷新 | 随时 | 菜单 → **立即刷新** |

**为何不是秒级实时？**  
高频请求会增加网络与后台唤醒，空闲时也会抬高 CPU；对「看还剩多少额度」来说，2 分钟足够。需要立刻看到变化时用「立即刷新」。

### 内存与资源（轻量设计）

| 手段 | 作用 |
|------|------|
| 无主窗口（`LSUIElement`） | 不占 Dock、无大界面树 |
| 无 WebView / 无浏览器内核 | 避免上百 MB 级占用 |
| 图标启动时缓存 | 闪烁只切换已有图片，不反复绘制 |
| 用量 2 分钟轮询 | 少起子进程、少解析 JSON |
| 任务检测 2 秒间隔 | 少扫盘、少调用 `sqlite3` |
| Codex Token 短命子进程 | 扫描 GB 级 rollout 在独立 `codex-usage-stats` 进程完成，主进程不吃 1GB+ 内存 |

本机实测空闲常驻大约每个进程数十 MB 量级（系统 AppKit 菜单栏应用的常见基线），**额外逻辑尽量省**，目标是「挂着几乎无感」。

---

## 环境要求

- macOS 13 及以上  
- Xcode 命令行工具：`xcode-select --install`（需要 `swiftc`）  
- **Grok：** 已安装并登录 Grok Build（如 `grok login`），且本机有 `python3`  
- **Codex：** 已用官方客户端/CLI 登录（存在 `~/.codex/auth.json`）  
- 查询用量需要联网  

---

## 安装

```bash
git clone https://github.com/ubuchow/Ai-credits-menubar.git
cd Ai-credits-menubar
./install.sh
```

只装一个：

```bash
./grok/install.sh
./codex/install.sh
```

卸载：

```bash
./uninstall.sh
```

装好后菜单栏右侧会出现 **`G xx%`**、**`C xx%`**。若很挤，可能在右侧 **`…`** 里。

### 首次打开被拦截？

本地编译、ad-hoc 签名。可在 **系统设置 → 隐私与安全性** 选「仍要打开」，或在 Finder 中右键应用 → **打开**。

### 显示 `G ?` / `C ?`？

| 现象 | 处理 |
|------|------|
| `G ?` | 终端执行 `grok login` 后「立即刷新」 |
| `C ?` | 打开 Codex/ChatGPT 登录后刷新 |
| 有数字不闪 | 当前没有任务在跑，属正常 |
| 看不到图标 | 看菜单栏 `…`，或 `open -a "Grok Credits"` |

---

## 原理（可选阅读）

### Grok Credits

1. `grok/scripts/grok-credits` 用本机 Grok 登录态查询 Build 额度。  
2. 任务状态：扫描近期 `~/.grok/sessions/**/events.jsonl` 是否有未结束的 `turn_started`。  
3. **今日/本月 Token**：汇总 `~/.grok/logs/unified.jsonl` 中每次 `shell.turn.inference_done` 的 `prompt_tokens + completion_tokens`，按事件时间归入今日/本月（纯本地，中文单位万/亿）。

### Codex Credits

1. 用 `~/.codex/auth.json` 的 token 请求 ChatGPT 用量接口；下拉面板展示余量、重置时间、Credits、**限额重置次数**（`rate_limit_reset_credits`）等。  
2. 任务状态：根据 `~/.codex/logs_2.sqlite` 中与 turn / 流式 / 工具相关的日志判断（忽略 `account/read`、`fs/changed` 等空闲心跳）。  
3. **今日/本月 Token**：扫描 `~/.codex/sessions/**` 与 `archived_sessions` 的 rollout，对每个 `token_count` 事件累加 `last_token_usage.total_tokens`，按事件时间戳归入今日/本月（精确到每次模型调用；中文单位万/亿）。

---

## 目录结构

```
Ai-credits-menubar/
├── install.sh / uninstall.sh
├── grok/          # Grok 菜单栏应用 + grok-credits
├── codex/         # Codex 菜单栏应用
├── scripts/       # 发布辅助脚本
├── SECURITY.md
├── docs/PRIVACY.md
└── LICENSE        # MIT
```

---

## 免责声明

非官方项目，与 xAI、OpenAI 无关联。接口与登录方式可能随官方产品变更，请自行承担使用风险。
