# Ai工具余额展示

> 仓库名：**Ai-credits-menubar** · 当前版本 **2.0.0**

macOS **菜单栏常驻**小工具：用 **一个** 堆叠芯片同时展示 **Grok Build** 与 **OpenAI Codex** 的用量余量与重置时间；任务运行时对应字母会闪烁。

设计目标是**轻量常驻、占用低、不打扰**——适合长时间挂着当「余额指示灯」。

## 功能一览

| 项目 | 说明 |
|------|------|
| **菜单栏** | **单槽位堆叠芯片**：上 Grok / 下 Codex，各显示徽章字母 + 整数百分比 |
| **下拉菜单** | 分区展示 Grok / Codex 全部信息（余量、重置、订阅、Token、任务状态等） |
| **任务进行中** | 对应字母闪烁；任一任务在跑时播放进行音效，结束时播放结束音 |
| **安装** | 根目录 `./install.sh` 安装统一应用，并自动卸掉旧的双图标版 |

### 菜单栏芯片（v2）

整块绘制为一张图，上下两行、间距紧凑：

```
 ⬤G 95   ← 浅灰底圆 + 深色 G + 深红数字
 ⬤C 78   ← 琥珀金底圆 + 深色 C + 深红数字
```

- **Grok**：浅灰徽章 + 深色字母（黑白体系）  
- **Codex**：琥珀金徽章 + 深色字母（与 G 区分）  
- **数字**：深红，便于在深色菜单栏上辨认  
- 徽章与数字间距约 2pt；高度约 18pt，只占 **一个** 菜单栏图标位  
- 低余量时徽章/数字变警示红；任务中仅对应字母闪烁（环与百分比不动）

### 下拉菜单

**Grok**  
剩余 % · 重置时间 · 下次订阅 · 今日/本月 Token · 任务状态  

**Codex**  
剩余 % · 重置时间 · 窗口/副窗口 · Credits · 重置次数 · 下次订阅 · 今日/本月 Token · 任务状态  

另有：立即刷新 · 关闭/开启音效 · 打开 Grok/Codex 用量页 · 退出  

1. **余量监测**  
   默认每 **2 分钟** 自动刷新；菜单「立即刷新」可马上更新。  
   Grok 账单解析已增强：接口字段漂移、周期重置后「空用量」会按 0% 使用（100% 剩余）处理；网络/解析失败时优先保留上次有效余量与本地缓存，尽量避免菜单栏长期停在 `?`。

2. **任务闪烁**  
   约每 **2 秒** 检测；仅字母闪烁。

3. **登录自启**  
   安装后注册 LaunchAgent（`com.github.ai-credits-menubar.combined`）。

4. **任务音效**  
   进行中循环提示音，结束一响。菜单可关（本机记住）。

5. **本机登录态**  
   读取本机 Grok / Codex 登录配置，不把凭证提交仓库。见 [SECURITY.md](SECURITY.md)。

---

## 刷新与内存

| 内容 | 间隔 |
|------|------|
| 余额 / 百分比 / 重置 | **2 分钟** |
| 任务是否在跑 | **约 2 秒** |
| 手动刷新 | 随时 |

| 手段 | 作用 |
|------|------|
| 单进程双后端 | 菜单栏只占 **一个** 槽位 |
| Codex Token 短命子进程 | 扫描 GB 级 rollout 不撑爆主进程内存 |
| 无 WebView / `LSUIElement` | 无 Dock、无重 UI |
| 芯片位图缓存 | 闪烁与刷新尽量复用已绘制图像 |

---

## 环境要求

- macOS 13+  
- Xcode 命令行工具（`swiftc`）  
- **Grok：** 已登录 Grok Build（`grok login`），本机有 `python3`  
- **Codex：** 已登录 Codex/ChatGPT（`~/.codex/auth.json`）  
- 查用量需联网  

---

## 安装

```bash
git clone https://github.com/ubuchow/Ai-credits-menubar.git
cd Ai-credits-menubar
./install.sh
```

会安装 **`~/Applications/AI Credits.app`**（版本 2.0.0），并**自动卸掉**旧的双图标版（Grok Credits / Codex Credits），避免再占两个槽位。

卸载：

```bash
./uninstall.sh
```

装好后菜单栏右侧应只看到 **一个** 堆叠 G/C 芯片（例如上 `95`、下 `78`）。若菜单栏很挤，可能被收进右侧 **`…`**。

### 首次打开被拦截？

本地编译、ad-hoc 签名。可在 **系统设置 → 隐私与安全性** 选「仍要打开」，或在 Finder 中右键应用 → **打开**。

### 显示 `?` 或一侧为 `?`？

| 现象 | 处理 |
|------|------|
| Grok 一侧 `?` | 终端执行 `grok login` 后点「立即刷新」 |
| Codex 一侧 `?` | 打开 Codex/ChatGPT 登录后刷新 |
| 有数字不闪 | 当前没有对应任务在跑，属正常 |
| 偶发 `?` 又恢复 | 可能是瞬时网络/解析问题；脚本会尽量回退缓存 |

---

## 原理（可选）

### Grok

1. `grok/scripts/grok-credits` 用本机登录态查 Build 额度（含更稳健的 protobuf 解析与过期缓存回退）。  
2. 任务：扫描 `~/.grok/sessions/**/events.jsonl` 是否有未结束 turn。  
3. Token：汇总 `~/.grok/logs/unified.jsonl` 中 `inference_done` 的 prompt+completion。

### Codex

1. `~/.codex/auth.json` 请求 ChatGPT 用量接口。  
2. 任务：读 `logs_2.sqlite` 中 user turn / interrupt 日志。  
3. Token：`codex/scripts/codex-usage-stats` 短命进程扫描 session rollout。

### 合并应用（推荐）

`combined/` 单进程：一个 `NSStatusItem` + 分区菜单，后端复用上述逻辑；安装脚本默认只装这一版。

`grok/`、`codex/` 目录仍保留独立应用源码与脚本，便于调试或对照；日常请用根目录 `install.sh`。

---

## 目录结构

```
Ai-credits-menubar/
├── install.sh / uninstall.sh   # 默认安装/卸载统一应用
├── combined/                   # 统一菜单栏应用（推荐，v2）
│   ├── Sources/main.swift      # 芯片绘制、菜单、定时器、音效
│   ├── Sources/Backends.swift  # Grok/Codex 拉取与任务检测
│   └── build.sh / install.sh
├── grok/                       # Grok 后端脚本 + 可选独立应用
├── codex/                      # Codex 后端脚本 + 可选独立应用
├── sounds/                     # 任务音效
├── CHANGELOG.md
├── SECURITY.md
├── docs/PRIVACY.md
└── LICENSE
```

---

## 更新说明

见 [CHANGELOG.md](CHANGELOG.md)。v2 起默认变为 **单图标双余量**；从旧版升级直接重新执行 `./install.sh` 即可。

---

## 免责声明

非官方项目，与 xAI、OpenAI 无关联。接口与登录方式可能随官方产品变更，请自行承担使用风险。
