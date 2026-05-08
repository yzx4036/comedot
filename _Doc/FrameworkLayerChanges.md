# Framework Layer Changes

本文档记录当前 Comedot 框架层近期重要改动的影响面。它只覆盖 `Game/` 之外的根框架仓库内容；`Game/` 业务仓库变更应记录在业务项目自己的文档中。


## 2026-05-08：启动、调试与自动化规则整理

### AutoLoad 启动顺序
- `Settings.gd` 在 `NOTIFICATION_PARENTED` 阶段加载配置文件和用户项目设置。
- 这意味着 `Settings` 是早期配置来源，不应等到 `_ready()` 才假设设置可用。
- 相关文档：
	- `_Doc/Note/00-Concepts/AutoloadAndStartFlow.md`
	- `_Doc/Note/30-Flow/StartReading-StartGd.md`
	- `_Doc/BestPractices.md`

### Debug 与 AutoLoad 日志
- `Debug.gd` 的启动职责已拆为更清晰的初始化步骤：日志窗口、Debug 窗口、启动提示、标签重置、可见性、框架检查。
- 新增/明确 `Debug.printAutoLoadLog()` 作为 AutoLoad 早期生命周期日志入口。
- `Debug.performFrameworkChecks()` 会在缺少 `Start.gd` 根脚本或 `super` 调用导致 `Global.hasStartScript` 未设置时显示警告。
- 相关文档：
	- `_Doc/Note/00-Concepts/DebugAndAutoloadLogging.md`
	- `_Doc/Note/00-Concepts/AutoloadAndStartFlow.md`
	- `_Doc/BestPractices.md`

### Godot MCP 自动化
- 框架层已包含 `addons/godot_mcp/` 插件文件，并在 `project.godot` 中启用。
- 当前本机 CLI 命令名为 `godot-mcp`；部分外部文档可能称为 `godot-mcp-cli`。
- 自动化测试与编辑器交互应优先读取 `_Doc/GodotMcpCliAutomationGuide.md`。
- MCP 操作应优先映射到 `addons/godot_mcp/commands/` 下对应命令处理器。

### AI / Git 工作流规则
- 根仓库是 Comedot 框架仓库；`Game/` 是独立业务仓库。两者的 Git 状态、分支、提交、合并和历史必须分开处理。
- `合并up_stream到dev` 采用 Git Flow 的分支模型和完成理念，不要求本机安装或直接调用明文 `git flow` 命令。
- `提交dev` 要先分析当前相关仓库的变更，再用中文提交说明；功能新增使用 `[feat]`，修复使用 `[fix]`，纯文档/规则调整可不用前缀。
- 相关文档：
	- `AGENTS.md`
	- `.github/copilot-instructions.md`
	- `Game/AGENTS.override.md`


## 维护规则
- 框架层启动流程变更时，同步更新：
	- `_Doc/BestPractices.md`
	- `_Doc/Note/00-Concepts/AutoloadAndStartFlow.md`
	- `_Doc/Note/30-Flow/StartReading-StartGd.md`
- Debug / 日志体系变更时，同步更新：
	- `_Doc/Note/00-Concepts/DebugAndAutoloadLogging.md`
	- `_Doc/BestPractices.md`
- MCP 插件、CLI 参数、命令处理器或验收流程变更时，同步更新：
	- `_Doc/GodotMcpCliAutomationGuide.md`
- 仓库边界、Git 自动化或 AI 协作规则变更时，同步更新：
	- `AGENTS.md`
	- `.github/copilot-instructions.md`
	- 如涉及 `Game/` 子树，再更新 `Game/AGENTS.override.md`
