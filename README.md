# Ai工具余额展示

> 仓库名：**Ai-credits-menubar** · 当前版本 **2.1.0**

macOS **菜单栏常驻**小工具：用 **一个** 三角芯片同时展示 **Grok Build**、**Hermes（DeepSeek）** 与 **OpenAI Codex** 的余量；任务运行时对应字母会闪烁。

设计目标是**轻量常驻、占用低、不打扰**——适合长时间挂着当「余额指示灯」。

## 功能一览

| 项目 | 说明 |
|------|------|
| **菜单栏** | **单槽位三角芯片**：上 G / 左下 H / 右下 C，数字贴在圆旁 |
| **下拉菜单** | 分区展示 Grok / Hermes / Codex（余量、Token、任务状态等） |
| **任务进行中** | 对应字母闪烁；任一任务在跑时播放进行音效，结束时播放结束音 |
| **安装** | 根目录 `./install.sh` 安装统一应用，并自动卸掉旧的双图标版 |

### 菜单栏芯片（v2.1）

三个圆可交叉（约 30%），直径约 12pt；数字为 Times New Roman 黑色：

```
       ⬤G 46
   88 ⬤H⬤C 44
```

| 字母 | Agent | 圆配色 | 数字含义 |
|------|-------|--------|----------|
| **G** | Grok Build | 浅灰底 + 深色字母 | 剩余 %（圆右侧） |
| **H** | Hermes / DeepSeek | 靛紫底 + 白字 | 余额整数 ¥（圆左侧） |
| **C** | OpenAI Codex | 琥珀金底 + 深色字母 | 剩余 %（圆右侧） |

- 低余量时数字/徽章变警示红；任务中仅对应字母闪烁  
- 应用图标（`assets/AppIcon.icns`）与芯片同主题  

### 下拉菜单

**Grok** — 剩余 % · 重置时间 · 订阅 · 今日/本月 Token · 任务状态  

**Hermes** — DeepSeek 余额 · 模型 · 今日/本月 Token · 任务状态 · 打开余额页  

**Codex** — 剩余 % · 重置时间 · 窗口/Credits · 今日/本月 Token · 任务状态  

另有：立即刷新 · 关闭/开启音效 · 打开对应用量页 · 退出  

1. **余量监测**  
   默认每 **2 分钟** 自动刷新；菜单「立即刷新」可马上更新。  
   Grok 账单解析已增强；Hermes 走 DeepSeek 余额 API（本机 `DEEPSEEK_API_KEY` / Hermes 配置）；失败时尽量保留上次有效值。

2. **任务闪烁**  
   约每 **2 秒** 检测；仅字母闪烁。

3. **登录自启**  
   安装后注册 LaunchAgent（`com.github.ai-credits-menubar.combined`）。

4. **任务音效**  
   进行中循环提示音，结束一响。菜单可关（本机记住）。

5. **本机登录态**  
   读取本机 Grok / Hermes / Codex 配置，不把凭证提交仓库。见 [SECURITY.md](SECURITY.md)。

---

## 刷新与内存

| 内容 | 间隔 |
|------|------|
| 余额 / 百分比 / 重置 | **2 分钟** |
| 任务是否在跑 | **约 2 秒** |
| 手动刷新 | 随时 |

| 手段 | 作用 |
|------|------|
| 单进程三后端 | 菜单栏只占 **一个** 槽位 |
| Codex Token 短命子进程 | 扫描 GB 级 rollout 不撑爆主进程内存 |
| Hermes `hermes-balance` 短命脚本 | 余额 API + 本地 `state.db` Token/busy |
| 无 WebView / `LSUIElement` | 无 Dock、无重 UI |
| 芯片位图缓存 | 闪烁与刷新尽量复用已绘制图像 |

---

## 环境要求

- macOS 13+  
- Xcode 命令行工具（`swiftc`）  
- **Grok：** 已登录 Grok Build（`grok login`），本机有 `python3`  
- **Hermes：** 已安装 Hermes CLI，本机可查 DeepSeek 余额（`DEEPSEEK_API_KEY` 等）  
- **Codex：** 已登录 Codex/ChatGPT（`~/.codex/auth.json`）  
- 查用量需联网  

---

## 安装

```bash
git clone https://github.com/ubuchow/Ai-credits-menubar.git
cd Ai-credits-menubar
./install.sh
```

会安装 **`~/Applications/AI Credits.app`**（版本 2.1.0），并**自动卸掉**旧的双图标版（Grok Credits / Codex Credits），避免再占两个槽位。

卸载：

```bash
./uninstall.sh
```

装好后菜单栏右侧应只看到 **一个** G/H/C 三角芯片。若菜单栏很挤，可能被收进右侧 **`…`**。

### 首次打开被拦截？

本地编译、ad-hoc 签名。可在 **系统设置 → 隐私与安全性** 选「仍要打开」，或在 Finder 中右键应用 → **打开**。

### 显示 `?` 或某一侧为 `?`？

| 现象 | 处理 |
|------|------|
| Grok `?` | 终端执行 `grok login` 后点「立即刷新」 |
| Hermes `?` | 检查 Hermes / DeepSeek API Key 后刷新 |
| Codex `?` | 打开 Codex/ChatGPT 登录后刷新 |
| 有数字不闪 | 当前没有对应任务在跑，属正常 |
| 偶发 `?` 又恢复 | 可能是瞬时网络/解析问题；脚本会尽量回退缓存 |

---

## 原理（可选）

### Grok

1. `grok/scripts/grok-credits` 用本机登录态查 Build 额度。  
2. 任务：扫描 `~/.grok/sessions/**/events.jsonl` 是否有未结束 turn。  
3. Token：汇总 `~/.grok/logs/unified.jsonl` 中 `inference_done`。

### Hermes

1. `hermes/scripts/hermes-balance` 调 DeepSeek 余额 API。  
2. Token / busy：读 `~/.hermes/state.db`。  

### Codex

1. `~/.codex/auth.json` 请求 ChatGPT 用量接口。  
2. 任务：读 `logs_2.sqlite` 中 user turn / interrupt 日志。  
3. Token：`codex/scripts/codex-usage-stats` 短命进程扫描 session rollout。

### 合并应用（推荐）

`combined/` 单进程：一个 `NSStatusItem` + 分区菜单；安装脚本默认只装这一版。

`grok/`、`codex/` 目录仍保留独立应用源码与脚本，便于调试；日常请用根目录 `install.sh`。

---

## 目录结构

```
Ai-credits-menubar/
├── install.sh / uninstall.sh   # 默认安装/卸载统一应用
├── combined/                   # 统一菜单栏应用（推荐）
│   ├── Sources/main.swift      # 三角芯片、菜单、定时器、音效
│   ├── Sources/Backends.swift  # Grok / Hermes / Codex 后端
│   ├── scripts/generate-app-icon.py
│   └── build.sh / install.sh
├── hermes/scripts/hermes-balance
├── grok/                       # Grok 后端脚本 + 可选独立应用
├── codex/                      # Codex 后端脚本 + 可选独立应用
├── assets/AppIcon.icns         # 应用图标
├── sounds/
├── CHANGELOG.md
├── SECURITY.md
├── docs/PRIVACY.md
└── LICENSE
```

---

## 更新说明

见 [CHANGELOG.md](CHANGELOG.md)。从旧版升级直接重新执行 `./install.sh` 即可。

---

## 免责声明

非官方项目，与 xAI、DeepSeek、OpenAI 无关联。接口与登录方式可能随官方产品变更，请自行承担使用风险。
