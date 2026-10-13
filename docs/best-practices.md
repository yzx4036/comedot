# Comedot 框架实践指南（Best Practices）

> 源自 `_Doc/BestPractices.md`（2026-10-13 并入 docs）· 面向框架贡献者与 AI 代理 · 启动流程已按 as-built 实况修正

面向在 Comedot 框架代码上工作的贡献者与 AI 代理的实践指南。


## 1. 项目结构与边界

- 框架优先：`Game/` 之外为框架层。
- `Game/` 用于项目专属实现，与框架改进保持隔离（当前仅承载 `Game/Example/` 最小闭环示例）。
- 正常工作忽略 `Temporary/` 与 `Lab/`。
- 核心可复用玩法逻辑归属：
	- `Components/`（行为单元）
	- `Entities/`（组件容器）
	- `Resources/`（数据类）
	- `Scripts/`（非组件的共享逻辑）


## 2. 首选架构模式

- 用"实体 + 组件组合"实现玩法，不要堆单体实体脚本。
- 先复用既有子系统（战斗、属性、动作、交互、回合制）。
- 新组件必须是场景 + 脚本对（`.tscn` + `.gd`），继承 `Components/Component.gd`（或其子类）。
- 组件根节点按职责选择：
	- 纯逻辑 → `Node`
	- 视觉/可偏移 → `Node2D`
	- 行为核心即该节点 → 专用节点（`Timer`、`Area2D` 等）
- 一致地加入节点组（`components`、`entities`，以及 `players`、`enemies`、`turnBased` 等玩法组）。


## 3. 编码与命名约定

- 制表符缩进，不用空格。
- 广泛使用 camelCase（本仓库常量也如此）。
- 尽量使用显式静态类型。
- 实体/组件及运行时引用的可复用类使用 `class_name`。
- 信号处理函数遵循 `on[Emitter]_[signal]`。
- 避免变量/属性遮蔽（例如不要复用继承来的 `body` 等名称）。


## 4. 启动流程（Boot Sequence）

> ⚠️ **上游协议对照**：上游文档本节以 `Scripts/Start.gd` 为启动核心——`Start._enter_tree() → setupGameState()`、`Start._ready() → startComedot()/applyGlobalFlags()`，并以 `Global.hasStartScript` 作为启动标记。**本 fork 无 `Scripts/Start.gd`**（无 `Scripts/Boot/`），启动职责由各 AutoLoad 自行完成。下列为 as-built 实况。

实况启动链：

1. AutoLoad 按 `project.godot` 顺序实例化：
	`Global → Settings → Debug → SceneManager → GlobalInput → GameState → GlobalUI → GlobalSonic → TurnBasedCoordinator`
2. `Settings` 在 `NOTIFICATION_PARENTED` 阶段加载用户配置（早于 `_enter_tree()`/`_ready()`）；启动代码可提前读取设置。
3. `run/main_scene` → `Scenes/Launch/Logo/IOLogoScene.tscn`（`class_name LogoSceneIO extends Node2D`）。
4. Logo → `SceneManager.transitionToScene(GameFrame.tscn)` 主菜单 → `GameState.startMainScene()`（`Settings.mainGameScenePath`）。
5. Game 层由 `Game/override.cfg` 将主场景覆盖为 `res://Game/Example/ExampleScene.tscn`。

启动规则：

- 若按上游协议创建 `extends Start` 的子类（例如新项目骨架由 `addons/Comedot/GameProjectInitializer.gd` 生成 `Scripts/Boot/*Start.gd`），覆写的 `_enter_tree()` 与 `_ready()` 必须调用 `super`。
- `Debug.performFrameworkChecks()` 依赖 `Global.hasStartScript`；本 fork 无 Start 脚本时该警告恒出现，属已知漂移而非故障。
- AutoLoad 生命周期日志优先使用 `Debug.printAutoLoadLog()`，不要直接 `print()` 或普通调试日志。


## 5. 场景与导航实践

- 用 `SceneManager` API 做转场与栈导航，不要临时性地直接 `change_scene_to_*`。
- 暂停/恢复行为与 `SceneManager.setPause()` 及相关信号保持一致。
- 全局持久的视觉/音频/UI 行为优先复用既有单例（`GlobalUI`、`GlobalSonic` 等）。


## 6. 回合制实践

- 通过既有流程集成回合制行为：
	- `AutoLoad/TurnBasedCoordinator`
	- `Entities/TurnBased/TurnBasedEntity`
	- 回合制组件族
- 既有 API 覆盖需求时，不要另起并行的回合协调器或孤立状态机。


## 7. 验证与测试流程

- 首轮验证：在编辑器中运行整项目（F5）或目标场景（F6）。
- 人工功能检查优先使用 `Tests/` 下的场景。
- 语法/静态检查命令模式：

```bash
godot --headless --check-only --path <repo 绝对路径> --script res://path/to/script.gd --log-file <可写日志路径>
```

- 若 headless 运行环境不可用，保持改动保守，并用静态代码检查验证。


## 8. 常见反模式

- 当组件更可复用时，把游戏专属逻辑加进框架实体。
- 只改组件脚本，忘记其配套场景的要求。
- 未经直接请求就引入大范围重构。
- 用并行的一次性工具替换既有项目模式（`SceneManager`、`Debug`、`Start`）。
- 绕过框架 `Debug.printAutoLoadLog()` 路径，用直接 `print()` 添加 AutoLoad 启动日志。
