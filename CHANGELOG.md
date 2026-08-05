# 更新日志

## 2.1.0 — 2026-08-05

### 新增

- **第三路 Hermes（DeepSeek）**：`hermes-balance` 拉余额与 Token/busy；菜单栏 H 圆显示整数余额  
- **三角芯片**：上 G · 左下 H · 右下 C，数字贴在圆旁（G/C 右、H 左），圆可 30% 交叉、直径 12pt  
- **应用图标**：`assets/AppIcon.icns`（与 G/H/C 主题一致），`generate-app-icon.py` 可重生成  

### 改进

- 数字 Times New Roman、黑色；圆内字母 Times New Roman  
- Hermes 余额菜单栏仅整数；低余量警示色保留  
- 文档与安装文案同步为三 agent  

---

## 2.0.0 — 2026-07-31

### 新增

- **统一菜单栏应用**（`combined/`）：Grok + Codex 合并为一个 `NSStatusItem`，只占一个图标位  
- **堆叠双芯片**：上 Grok / 下 Codex，徽章字母 + 整数百分比  
- 安装时自动卸掉旧版「Grok Credits」「Codex Credits」双应用与对应 LaunchAgent  
- 任务音效、分区下拉菜单、打开用量页等沿用并集中到同一进程  

### 改进

- `grok-credits`：账单 protobuf 字段漂移兼容；周期重置后空用量按 0% 使用处理  
- 用量拉取失败时优先保留上次有效余量与本地缓存，减少菜单栏长期 `?`  
- 独立 Grok 应用同样合并 Token 与上次有效余量逻辑  

### 说明

- 版本号以 `combined` Info.plist **2.0.0** 为准  
- 日常安装请使用仓库根目录 `./install.sh`  

---

## 1.0.0 — 2026-07-30

### 新增

- 双独立菜单栏应用：Grok Credits / Codex Credits  
- 2 分钟刷新余量、约 2 秒任务检测与字母闪烁  
- LaunchAgent 登录自启、任务音效  
- 本机登录态读用量，MIT 开源  
