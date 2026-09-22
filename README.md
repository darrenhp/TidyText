# TidyText - macOS 智能文字整理助手

专为 macOS 打造的原生极速、无感智能文字整理工具。在任意软件中选中文本，按下快捷键（默认 `⌥ + 空格`），AI 自动根据你的输入习惯纠正错别字并理顺语句，**直接在原位替换原文本**。

---

## ✨ 核心特色

### 1. 方案 B：原位直接替换 (In-Place Silent Replacement)
- **零弹窗打扰**：选中一段文字后按下快捷键，光标旁仅浮现微型毛玻璃小药丸（`✦ 整理中...`），整理完成后直接原地替换文字，恢复原本光标位置。
- **撤销与安全保障**：
  - 支持系统原生 `⌘ + Z` 一键撤销还原。
  - 菜单栏自动保留最近历史快照（History），随时可一键找回或还原任意历史整理。

### 2. 专为输入痛点量身定制的内置 Prompt 矩阵
- **自然码双拼 & 全模糊音专属纠偏**：
  - 针对平翘舌 (`z/zh, c/ch, s/sh`)、前后鼻音 (`in/ing, en/eng, an/ang`)、边鼻音 (`n/l`)、唇齿音 (`f/h`) 等模糊音导致的同音/近音词误选。
  - 针对自然码双手交替键位相邻产生的错字进行智能推断还原。
- **反复修改理顺急救包**：
  - 专治“改动后遗症”：消除剪切重组留下的重复残留词（如“我觉得我认为”）、修复脱节残缺成分（缺少主谓宾）、理顺杂糅病句。
  - 严格坚守**最小修改原则（Min-Diff）**：只修复错字与病句，原作者语气、观点与专业词汇一字不改。
- **综合整理 (双拼纠错 + 语句理顺)**（默认）。
- **结构化要点提炼** & **职场得体沟通优化**。

### 3. 供应商 → 多模型分层架构与优先级故障转移 (Failover)
- **分层管理**：
  - **供应商层 (Providers)**：统一管理 DeepSeek、Anthropic Claude、OpenAI、火山引擎豆包 (Ark)、自定义兼容接口（Ollama / 通义千问 / Kimi 等）的 Base URL 与 API Key（安全保存在系统 Keychain 中）。
  - **模型配置层 (Models)**：各供应商下可自由添加多个具体模型，支持独立命名、参数配置、启用开关与优先级排序。
- **优先级与自动故障转移 (Failover)**：
  - 列表排序即为调用优先级（#1 主用、#2 备用...）。
  - 若第一主用模型发生限流 (429)、网络超时或接口异常，系统**自动无缝故障转移至顺位下一启用模型**，确保每一次打字都不卡顿。

### 4. 全局快捷键随时自定义与一键秒切
- **交互式按键录制**：在设置 -> 通用设置中，点击录制按钮即可按下任意快捷键组合修改。
- **开箱常用预设**：提供 `⌥ + 空格`、`⌥ + ⇧ + T`、`⌘ + ⌥ + T`、`⌃ + ⌥ + T`、`⌘ + ⇧ + E` 等经典组合一键秒切。
- **实时热生效**：修改后立即注销旧键绑定新键，无需重启应用，菜单栏联动更新。

---

## 🚀 快速上手

### 1. 运行应用
已构建好的应用位于：
```bash
open build/TidyText.app
```
或直接进入项目目录调试运行：
```bash
swift run TidyText
```

### 2. 授权辅助功能 (Accessibility)
首次使用时，应用会自动提示需要「辅助功能」权限（用于在屏幕选区无损读取和原位替换文本）：
- 前往：`系统设置 -> 隐私与安全性 -> 辅助功能`
- 勾选 `TidyText` 即可。

### 3. 配置 API Key
1. 点击屏幕右上角菜单栏的 ✨ 闪烁图标。
2. 选择 **「设置与模型配置...」**（快捷键 `⌘+,`）。
3. 切换到 **「供应商配置」** 标签，填入你的 DeepSeek、豆包、Claude 或 OpenAI 的 API Key。
4. 切换到 **「模型与优先级」** 标签，点击模型右侧的 **「测试」** 按钮，验证连通性。

### 4. 日常使用
在任意文本框（微信、备忘录、Word、浏览器、终端等）中：
1. 鼠标拖动或按快捷键选中文本。
2. 按下 `⌥ + 空格` (Option + Space)。
3. 观察光标旁显示 `✦ 整理中...`，约 1 秒后自动直接替换为规范润色文本！

---

## 🛠️ 从源码构建

本项目采用纯原生 Swift 语言与 AppKit/SwiftUI 打造，零第三方冗余依赖，体积仅约 1.2 MB：

```bash
# 运行内置自测套件
swift run TidyText --test

# 构建 Release 应用 Bundle (生成 build/TidyText.app)
./Scripts/build_app.sh
```

---

## 📂 项目结构

```
TidyText/
├── Package.swift                    # 纯原生 Swift Package 声明
├── Info.plist                       # macOS 应用元数据 (LSUIElement=true)
├── Scripts/
│   └── build_app.sh                 # 一键 Release 构建与 Bundle 打包脚本
├── Sources/
│   └── TidyText/
│       ├── main.swift               # 启动入口与 CLI 测试分发
│       ├── App/
│       │   └── AppDelegate.swift    # 菜单栏应用生命周期与热键注册
│       ├── Models/
│       │   ├── AIProviderConfig.swift # 供应商定义 (DeepSeek, 豆包, Claude, OpenAI)
│       │   ├── ModelConfig.swift      # 模型条目模型 (优先级、启用开关、参数)
│       │   └── PromptTemplate.swift   # 专属 Prompt 矩阵 (自然码/模糊音/反复修改)
│       ├── Core/
│       │   ├── TextCaptureService.swift # AXUIElement + Cmd+C 双引擎选区读取
│       │   ├── TextReplaceService.swift # AXUIElement + Cmd+V 双引擎原位替换
│       │   ├── HistoryManager.swift     # 撤销保障快照管理
│       │   ├── HotKeyManager.swift      # Carbon 全局热键后台监听
│       │   ├── PermissionsManager.swift # 辅助功能权限检测与引导
│       │   ├── TidyPipeline.swift       # 完整流程编排管道
│       │   └── SelfTestRunner.swift     # 自动化自检运行器
│       ├── Services/
│       │   ├── AI/
│       │   │   ├── AIServiceProtocol.swift # 通用 AI 接口与错误规范
│       │   │   ├── OpenAIService.swift     # DeepSeek / OpenAI / 豆包 Ark 适配
│       │   │   ├── ClaudeService.swift     # Anthropic Messages API 适配
│       │   │   ├── AIServiceFactory.swift  # 供应商工厂分发
│       │   │   └── ModelRouter.swift       # 核心调度与 Failover 自动故障转移
│       │   └── Storage/
│       │       ├── KeychainManager.swift   # 系统钥匙串安全存储 API Key
│       │       └── ConfigStorage.swift     # 本地持久化与多模型优先级维护
│       └── Views/
│           ├── CursorHUD/
│           │   └── CursorHUDController.swift # 光标旁微型药丸状态反馈浮层
│           ├── MenuBar/
│           │   └── MenuBarController.swift   # 状态栏菜单、提示词与历史切换
│           └── Settings/
│               ├── SettingsView.swift        # 多模型优先级、供应商、Prompt 设置
│               └── SettingsWindowController.swift # 原生设置窗口管理
```

---

## 📄 License
MIT
