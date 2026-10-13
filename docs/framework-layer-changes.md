# 框架层变更记录（Framework Layer Changes）

> 源自 `_Doc/FrameworkLayerChanges.md`（2026-10-13 并入 docs）· 引用与维护规则已更新为 docs 体系

本文档记录 Comedot 框架层（仓库根，`Game/` 之外）近期重要改动的影响面。`Game/` 业务变更记录在业务项目自己的文档中（当前业务仓：`Comedot_GDGameProjWuXia`）。

## 2026-05-08：启动、调试与自动化规则整理

### AutoLoad 启动顺序
- `Settings.gd` 在 `NOTIFICATION_PARENTED` 阶段加载配置文件和用户项目设置。
- 这意味着 `Settings` 是早期配置来源，不应等到 `_ready()` 才假设设置可用。
- 相关文档：`architecture-asbuilt.md` §2.3、`learning-guide.md` 启动流程章节。

### Debug 与 AutoLoad 日志
- `Debug.gd` 的启动职责拆分为清晰的初始化步骤：日志窗口、Debug 窗口、启动提示、标签重置、可见性、框架检查。
- `Debug.printAutoLoadLog()` 作为 AutoLoad 早期生命周期日志入口（已在 `AutoLoad/Debug.gd` 实证存在）。
- `Debug.performFrameworkChecks()` 在 `Global.hasStartScript` 未设置时显示警告——本 fork 无 `Scripts/Start.gd`，该提示恒出现，属已知漂移（非故障）。
- 相关文档：`learning-guide.md` 调试章节。

### Godot MCP 自动化
- 框架层包含 `addons/godot_mcp/` 插件并已在 `project.godot` 中启用。
- 本机 CLI 命令名为 `godot-mcp`；部分外部文档可能称为 `godot-mcp-cli`。
- 自动化测试与编辑器交互优先阅读 `docs/godot-mcp-automation.md`。
- MCP 操作应优先映射到 `addons/godot_mcp/commands/` 下对应命令处理器。

### AI / Git 工作流规则
- 根仓库是 Comedot 框架仓库；`Game/` 是独立业务边界。两者的 Git 状态、分支、提交、合并和历史必须分开处理。
- `合并up_stream到dev` 采用 Git Flow 的分支模型和完成理念，不要求本机安装或直接调用明文 `git flow` 命令。
- `提交dev` 要先分析当前相关仓库的变更，再用中文提交说明；功能新增使用 `[feat]`，修复使用 `[fix]`，纯文档/规则调整可不用前缀。
- 相关文档：`AGENTS.md`、`.github/copilot-instructions.md`、`Game/AGENTS.override.md`。


## 维护规则（docs 体系）

- 框架层启动流程变更时，同步更新：
	- `learning-guide.md`（启动流程章节）
	- `best-practices.md`（启动流程节）
	- `architecture-asbuilt.md`（§2 场景流转）
- Debug / 日志体系变更时，同步更新：
	- `learning-guide.md`（调试章节）
	- `best-practices.md`（启动流程节）
- MCP 插件、CLI 参数、命令处理器或验收流程变更时，同步更新：
	- `godot-mcp-automation.md`
- 仓库边界、Git 自动化或 AI 协作规则变更时，同步更新：
	- `AGENTS.md`
	- `.github/copilot-instructions.md`
	- 如涉及 `Game/` 子树，再更新 `Game/AGENTS.override.md`
