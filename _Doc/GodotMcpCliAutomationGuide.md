# Godot MCP CLI Automation Guide

本文档面向在本项目中使用 `godot-mcp-cli` 开展 Godot 编辑器自动化、运行调试和 AI 辅助开发的工作流。

依据来源：
- 本项目根目录 `AGENTS.md`、`Conventions.md`、`HowTo.md`、`README.md`
- `.github/copilot-instructions.md`、`.github/prompt-guide.md`
- `Game/AGENTS.override.md`
- `Game/Cd_ProjectZero/Docs/ProjectPrompt.md`、`ProjectMap.md`、`StartupFlow.md`
- `_Doc/BestPractices.md` 与 `_Doc/Note/` 中的启动流程笔记
- 当前本机执行的 `godot-mcp --list-tools` 与 `godot-mcp --help <tool>` 输出
- 当前项目内已安装的 `addons/godot_mcp/` 插件代码
- `godot-mcp-cli` 仓库：https://github.com/nguyenchiencong/godot-mcp-cli


## Current Project MCP State

当前项目已经具备 Godot MCP 插件文件：

```text
addons/godot_mcp/
```

`project.godot` 当前状态：

```text
config/features=PackedStringArray("4.7")
config/project_settings_override="res://Game/override.cfg"
MCPInputHandler="*res://addons/godot_mcp/mcp_input_handler.gd"
enabled=PackedStringArray("res://addons/Comedot/plugin.cfg", "res://addons/godot_mcp/plugin.cfg")
```

这说明：
- Godot MCP 插件已在项目中启用。
- `MCPInputHandler` 已作为 AutoLoad 注册，用于运行中输入模拟。
- 项目通过 `Game/override.cfg` 切换到当前游戏 `Game/Cd_ProjectZero/` 的启动入口。

CLI 的基本用法：

```powershell
godot-mcp --list-tools
godot-mcp --help get_project_info
godot-mcp get_project_info
godot-mcp get_current_scene
```

如果 Godot 编辑器未打开，或插件未启用，大多数工具会无法连接。先打开本项目 `project.godot`，确认插件 `Godot MCP` 启用，再运行 CLI。


## Project Rules For Automation

CLI 自动化必须遵守本项目分层：

```text
Game/ 外 = Comedot framework layer
Game/Cd_ProjectZero/ 内 = 当前游戏 layer
```

默认策略：
- 只读巡检可以覆盖框架层与游戏层，但忽略 `Temporary/` 和 `Lab/`。
- 游戏功能开发优先修改 `Game/Cd_ProjectZero/`。
- 框架层改动只在修复框架 bug、增加可复用能力、或需要小型扩展点时进行。
- 若修改 `Game/` 外框架文件，需要记录到 `Game/Cd_ProjectZero/Docs/FrameworkUpgradeNotes.md`。
- 若修改启动流程，需要同步更新 `Game/Cd_ProjectZero/Docs/StartupFlow.md`。
- 若游戏方向、范围、里程碑或项目决策变化，需要更新 `Game/Cd_ProjectZero/Docs/ProjectPrompt.md`。

代码与场景生成规则：
- 组件必须是 `.tscn` + `.gd` 成对存在。
- 组件脚本必须继承 `Components/Component.gd` 或其子类。
- 组件根节点加入 `components` group。
- Entity 根节点加入 `entities` group。
- 游戏专属组件放在 `Game/Cd_ProjectZero/Components/`。
- 游戏专属资源、脚本、场景、测试分别放入 `Game/Cd_ProjectZero/Resources/`、`Scripts/`、`Scenes/`、`Tests/`。
- GDScript 使用 Tab 缩进、camelCase、显式类型，按附近文件风格写。


## Instruction And Markdown Analysis Summary

本次已扫描项目内 Markdown 与 instruction 文件，排除 `Temporary/`、`Lab/` 和 `.git/`。没有发现项目级 `SKILL.md` 或 `*.skill.md` 文件。

对 CLI 自动化最重要的本地指令文件：

| File | Automation Relevance |
| --- | --- |
| `AGENTS.md` | 根项目规则、框架和游戏边界、Godot 检查方式、组件生成规则 |
| `.github/copilot-instructions.md` | Copilot 长期工作规则、启动流程、框架目录地图 |
| `.github/prompt-guide.md` | 提示模板、任务边界声明、代码审查和游戏实现模板 |
| `Conventions.md` | 命名、缩进、类型、文件结构、注释与设计约束 |
| `HowTo.md` | 组件/实体用法、添加组件、创建组件、常见问题 |
| `_Doc/BestPractices.md` | 框架层最佳实践、启动流程、验证流程 |
| `Game/AGENTS.override.md` | `Game/` 子树优先规则 |
| `Game/Cd_ProjectZero/Docs/ProjectPrompt.md` | 当前游戏方向、范围、约束和优先事项 |
| `Game/Cd_ProjectZero/Docs/ProjectMap.md` | 游戏目录归属与框架边界 |
| `Game/Cd_ProjectZero/Docs/StartupFlow.md` | 当前游戏启动链路 |

与当前游戏方向相关的 Markdown 集中在 `Game/Cd_ProjectZero/Docs/`：
- `Gameplay/GameplayDesign.md` 定义江湖沙盒 RPG 的核心循环、战斗、经济、生活技和垂直切片目标。
- `WorldModel/` 下文档定义世界状态、区域、商路、势力、事件、关键 agent、调试与实现清单。
- 这些文档适合作为 AI 通过 CLI 自动化生成场景、测试和原型前的上下文，但不应让 CLI 直接无边界地批量创建框架层文件。


## Safety Levels

建议把工具分为四类使用。

| Level | 用途 | 命令例子 | 使用规则 |
| --- | --- | --- | --- |
| Read | 只读查询 | `get_project_info`, `get_current_scene`, `list_project_files` | 可以作为每次自动化的起点 |
| Run | 运行和调试 | `run_project`, `get_debug_output`, `get_editor_errors` | 会影响编辑器运行状态，但通常不改文件 |
| Edit | 修改当前场景或资源 | `create_node`, `update_node_property`, `save_scene` | 必须先限定目标路径和场景 |
| Dangerous | 删除、重载、任意代码执行 | `delete_node`, `delete_scene`, `reload_scene`, `execute_editor_script` | 仅在明确指令和已知影响范围下使用 |

特别注意：
- `reload_scene` 会丢弃未保存改动。
- `reload_project` 会重启 Godot 编辑器并断开 MCP 连接。
- `execute_editor_script` 可以在编辑器上下文执行任意 GDScript，应视为高风险工具。
- `delete_scene` 和 `delete_node` 只在明确指定路径并确认用途后使用。


## Recommended Automation Loop

每次 CLI 自动化建议按这个顺序执行：

```powershell
godot-mcp get_project_info
godot-mcp get_current_scene
godot-mcp get_editor_scene_structure --include_scripts true --max_depth 3
```

如果需要运行项目：

```powershell
godot-mcp run_project
godot-mcp get_debug_output
godot-mcp get_editor_errors
godot-mcp get_runtime_scene_structure --include_scripts true --max_depth 4 --timeout_ms 2000
```

如果要修改场景：

```powershell
godot-mcp open_scene --path "res://Game/Cd_ProjectZero/Scenes/Levels/MyGameMain.tscn"
godot-mcp get_editor_scene_structure --include_properties true --include_scripts true --max_depth 5
```

修改后：

```powershell
godot-mcp save_scene
godot-mcp rescan_filesystem
godot-mcp get_editor_errors
```

最后用 Git 检查实际文件变化：

```powershell
git status --short
```


## Command Reference

以下命令来自当前本机 `godot-mcp --list-tools`。如果未来 CLI 升级，以 `godot-mcp --list-tools` 和 `godot-mcp --help <tool>` 的本机输出为准。


### Project And Asset Queries

| Command | Purpose | Important Parameters |
| --- | --- | --- |
| `get_project_info` | 获取当前 Godot 项目信息 | none |
| `list_project_files` | 按扩展名列出项目文件 | `--extensions` array |
| `list_assets_by_type` | 按类型列出资源 | `--type scripts/scenes/images/audio/fonts/models/shaders/resources/all` |
| `get_current_scene` | 获取当前编辑器打开场景信息 | none |
| `get_editor_scene_structure` | 获取编辑器中当前场景树 | `--include_properties`, `--include_scripts`, `--max_depth` |
| `get_runtime_scene_structure` | 获取运行中场景树 | `--include_properties`, `--include_scripts`, `--max_depth`, `--timeout_ms` |

常用示例：

```powershell
godot-mcp list_assets_by_type --type scenes
godot-mcp list_project_files --extensions '[".gd",".tscn",".tres"]'
godot-mcp get_editor_scene_structure --include_scripts true --max_depth 4
```


### Scene Operations

| Command | Purpose | Important Parameters |
| --- | --- | --- |
| `open_scene` | 在编辑器打开场景 | `--path` |
| `save_scene` | 保存当前场景 | `--path` optional |
| `create_scene` | 创建新场景 | `--path`, `--root_node_type` |
| `delete_scene` | 删除场景文件 | `--path` |

本项目建议：
- 新游戏场景优先放在 `Game/Cd_ProjectZero/Scenes/`。
- 新手动测试场景优先放在 `Game/Cd_ProjectZero/Tests/`。
- 框架测试才放根目录 `Tests/`。

示例：

```powershell
godot-mcp create_scene --path "res://Game/Cd_ProjectZero/Scenes/Levels/PrototypeMarket.tscn" --root_node_type Node2D
godot-mcp open_scene --path "res://Game/Cd_ProjectZero/Scenes/Levels/PrototypeMarket.tscn"
godot-mcp save_scene
```


### Node Operations

| Command | Purpose | Important Parameters |
| --- | --- | --- |
| `create_node` | 在当前场景树创建节点 | `--parent_path`, `--node_type`, `--node_name` |
| `delete_node` | 删除当前场景树节点 | `--node_path` |
| `update_node_property` | 修改节点属性 | `--node_path`, `--property`, `--value` |
| `get_node_properties` | 获取节点属性 | `--node_path` |
| `list_nodes` | 列出某父节点下的子节点 | `--parent_path` |

本项目建议：
- 添加 Comedot 组件时，优先实例化已有 `.tscn` 组件场景，而不是只创建裸节点。
- `create_node` 适合创建普通 Godot 节点、UI 节点、容器节点、占位节点。
- 对组件根节点，必须补齐 `components` group 和脚本继承关系。
- 对实体根节点，必须补齐 `entities` group 和 Entity 脚本。

示例：

```powershell
godot-mcp list_nodes --parent_path "."
godot-mcp create_node --parent_path "." --node_type Node2D --node_name "EncounterRoot"
godot-mcp update_node_property --node_path "./EncounterRoot" --property "position" --value "[128, 96]"
godot-mcp get_node_properties --node_path "./EncounterRoot"
```


### Script And Resource Operations

| Command | Purpose | Important Parameters |
| --- | --- | --- |
| `create_script` | 创建 GDScript，可选挂到节点 | `--script_path`, `--content`, `--node_path` |
| `edit_script` | 覆盖编辑已有 GDScript | `--script_path`, `--content` |
| `get_script` | 读取脚本内容 | `--script_path` or `--node_path` |
| `create_resource` | 创建 Godot Resource | `--resource_type`, `--resource_path`, `--properties` |

本项目建议：
- 对非平凡脚本编辑，优先在文件系统中按项目规范修改，再用 `rescan_filesystem`。
- `edit_script` 是整文件覆盖式工具，使用前先 `get_script` 或读取文件，避免覆盖用户改动。
- 游戏专属脚本优先放在 `Game/Cd_ProjectZero/Scripts/` 或对应组件目录。
- 游戏专属数据资源优先放在 `Game/Cd_ProjectZero/Resources/`。

示例：

```powershell
godot-mcp get_script --script_path "res://Game/Cd_ProjectZero/Scripts/Boot/MyGameStart.gd"
godot-mcp create_resource --resource_type Resource --resource_path "res://Game/Cd_ProjectZero/Resources/PrototypeData.tres" --properties "{}"
```


### Editor Maintenance

| Command | Purpose | Important Parameters |
| --- | --- | --- |
| `rescan_filesystem` | 让 Godot 重新扫描外部文件变化 | none |
| `reload_scene` | 从磁盘重载场景，丢弃未保存变化 | `--scene_path` optional |
| `reload_project` | 重启 Godot 编辑器 | `--save` |
| `execute_editor_script` | 在编辑器上下文执行 GDScript | `--code` |

建议：
- 文件系统外部改动后用 `rescan_filesystem`。
- `reload_scene` 前确认没有需要保留的未保存编辑器改动。
- `execute_editor_script` 只用于缺少专用工具且目标可精确描述的自动化。

示例：

```powershell
godot-mcp rescan_filesystem
godot-mcp reload_scene --scene_path "res://Game/Cd_ProjectZero/Scenes/Levels/MyGameMain.tscn"
```


### Run And Output

| Command | Purpose | Important Parameters |
| --- | --- | --- |
| `run_project` | 运行项目主场景 | none |
| `run_current_scene` | 运行当前编辑器场景 | none |
| `run_specific_scene` | 运行指定场景 | `--scene_path` |
| `stop_running_project` | 停止当前运行场景 | none |
| `get_debug_output` | 读取 Godot Output 面板 | none |
| `clear_debug_output` | 清空 Output 面板 | none |
| `stream_debug_output` | 开启或停止 Output 流式订阅 | `--action start/stop` |
| `get_editor_errors` | 读取 Errors 面板 | none |
| `clear_editor_errors` | 清空 Errors 面板 | none |

本项目启动入口：
- `Game/override.cfg` 将运行主场景指向 `Game/Cd_ProjectZero/Scenes/Boot/MyGameStart.tscn`。
- `MyGameStart.gd` 应继续继承 `Start`。
- 主游戏场景目前是 `Game/Cd_ProjectZero/Scenes/Levels/MyGameMain.tscn`。

示例：

```powershell
godot-mcp run_project
godot-mcp get_debug_output
godot-mcp get_editor_errors
godot-mcp stop_running_project
```

运行指定游戏场景：

```powershell
godot-mcp run_specific_scene --scene_path "res://Game/Cd_ProjectZero/Scenes/Levels/MyGameMain.tscn"
```


### Debugger Commands

| Command | Purpose | Important Parameters |
| --- | --- | --- |
| `debugger_set_breakpoint` | 设置断点 | `--script_path`, `--line` |
| `debugger_remove_breakpoint` | 移除断点 | `--script_path`, `--line` |
| `debugger_get_breakpoints` | 获取断点列表 | none |
| `debugger_clear_all_breakpoints` | 清空断点 | none |
| `debugger_pause_execution` | 暂停运行中项目 | none |
| `debugger_resume_execution` | 恢复运行 | none |
| `debugger_step_over` | 单步跳过 | none |
| `debugger_step_into` | 单步进入 | none |
| `debugger_get_call_stack` | 获取调用栈 | `--session_id` optional |
| `debugger_get_current_state` | 获取调试器当前状态 | none |
| `debugger_enable_events` | 开启断点等事件推送 | none |
| `debugger_disable_events` | 关闭事件推送 | none |
| `get_stack_trace_panel` | 读取 Stack Trace 面板 | `--session_id` optional |
| `get_stack_frames_panel` | 读取 Stack Frames 面板 | `--session_id`, `--refresh` |
| `evaluate_runtime_expression` | 在运行中游戏里求值 GDScript 表达式 | `--expression`, `--context_path`, `--capture_prints`, `--timeout_ms` |

示例：

```powershell
godot-mcp debugger_set_breakpoint --script_path "res://Game/Cd_ProjectZero/Scripts/Boot/MyGameStart.gd" --line 12
godot-mcp run_project
godot-mcp debugger_get_current_state
godot-mcp debugger_get_call_stack
godot-mcp get_stack_frames_panel --refresh true
```

运行时表达式示例：

```powershell
godot-mcp evaluate_runtime_expression --expression "get_tree().current_scene.name" --timeout_ms 2000
```

只在调试明确问题时使用运行时表达式。不要用它替代正常代码实现。


### Runtime Input Simulation

这些工具依赖项目运行中，并且当前项目已经注册 `MCPInputHandler` AutoLoad。

| Command | Purpose | Important Parameters |
| --- | --- | --- |
| `get_input_actions` | 列出项目输入动作 | none |
| `simulate_action_press` | 按住输入 action | `--action`, `--strength` |
| `simulate_action_release` | 释放输入 action | `--action` |
| `simulate_action_tap` | 短按输入 action | `--action`, `--duration_ms` |
| `simulate_key_press` | 模拟键盘按键 | `--key`, `--duration_ms`, `--modifiers` |
| `simulate_mouse_move` | 移动鼠标 | `--x`, `--y` |
| `simulate_mouse_click` | 点击鼠标 | `--x`, `--y`, `--button`, `--double_click` |
| `simulate_drag` | 拖拽鼠标 | `--start_x`, `--start_y`, `--end_x`, `--end_y`, `--duration_ms`, `--steps`, `--button` |
| `simulate_input_sequence` | 执行一组有时序的输入步骤 | `--sequence` |

示例：

```powershell
godot-mcp get_input_actions
godot-mcp simulate_action_tap --action "ui_accept" --duration_ms 100
godot-mcp simulate_key_press --key "SPACE" --duration_ms 120
godot-mcp simulate_mouse_click --x 400 --y 300 --button "left"
```

自动化验证建议：
- 先运行目标场景。
- 使用 `get_runtime_scene_structure` 确认目标 UI 或玩家节点已存在。
- 输入模拟后读取 `get_debug_output` 和 `get_editor_errors`。
- 对 Comedot 组件调试，优先启用组件 `debugMode` 或使用 `Debug` AutoLoad 输出。


## Current CLI Commands By Risk

只读优先：

```text
get_project_info
get_current_scene
list_project_files
list_assets_by_type
get_editor_scene_structure
get_runtime_scene_structure
get_node_properties
list_nodes
get_script
get_debug_output
get_editor_errors
get_stack_trace_panel
get_stack_frames_panel
debugger_get_breakpoints
debugger_get_call_stack
debugger_get_current_state
get_input_actions
```

运行状态变更：

```text
run_project
run_current_scene
run_specific_scene
stop_running_project
debugger_pause_execution
debugger_resume_execution
debugger_step_over
debugger_step_into
debugger_enable_events
debugger_disable_events
stream_debug_output
clear_debug_output
clear_editor_errors
simulate_action_press
simulate_action_release
simulate_action_tap
simulate_key_press
simulate_mouse_move
simulate_mouse_click
simulate_drag
simulate_input_sequence
evaluate_runtime_expression
```

文件或场景写入：

```text
create_node
delete_node
update_node_property
create_script
edit_script
create_scene
delete_scene
save_scene
create_resource
rescan_filesystem
reload_scene
reload_project
execute_editor_script
debugger_set_breakpoint
debugger_remove_breakpoint
debugger_clear_all_breakpoints
```


## Practical Workflows For This Project

### 1. Inspect Current Game State

```powershell
godot-mcp get_project_info
godot-mcp list_assets_by_type --type scenes
godot-mcp list_assets_by_type --type scripts
godot-mcp open_scene --path "res://Game/Cd_ProjectZero/Scenes/Levels/MyGameMain.tscn"
godot-mcp get_editor_scene_structure --include_scripts true --include_properties true --max_depth 5
```

Use this before planning a `Game/Cd_ProjectZero/` feature.


### 2. Run The Game And Read Diagnostics

```powershell
godot-mcp clear_debug_output
godot-mcp clear_editor_errors
godot-mcp run_project
godot-mcp get_debug_output
godot-mcp get_editor_errors
```

If runtime tree inspection is needed:

```powershell
godot-mcp get_runtime_scene_structure --include_scripts true --max_depth 5 --timeout_ms 2000
```


### 3. Add A Game-Specific Prototype Scene

```powershell
godot-mcp create_scene --path "res://Game/Cd_ProjectZero/Scenes/Levels/PrototypeRouteEncounter.tscn" --root_node_type Node2D
godot-mcp open_scene --path "res://Game/Cd_ProjectZero/Scenes/Levels/PrototypeRouteEncounter.tscn"
godot-mcp create_node --parent_path "." --node_type Node2D --node_name "EncounterRoot"
godot-mcp save_scene
godot-mcp rescan_filesystem
```

After this, use normal file edits for non-trivial scripts so indentation, comments and project conventions can be reviewed carefully.


### 4. Add Or Verify A Manual Test Scene

Game-specific tests should be under:

```text
Game/Cd_ProjectZero/Tests/
```

Framework tests should be under:

```text
Tests/
```

Example:

```powershell
godot-mcp create_scene --path "res://Game/Cd_ProjectZero/Tests/WorldModelSmokeTest.tscn" --root_node_type Node
godot-mcp open_scene --path "res://Game/Cd_ProjectZero/Tests/WorldModelSmokeTest.tscn"
godot-mcp save_scene
```


### 5. Debug A Startup Problem

Project startup chain to remember:

```text
project.godot
-> Game/override.cfg
-> Game/Cd_ProjectZero/Scenes/Boot/MyGameStart.tscn
-> Game/Cd_ProjectZero/Scripts/Boot/MyGameStart.gd
-> Scripts/Start.gd
-> GameState.startMainScene()
-> Game/Cd_ProjectZero/Scenes/Levels/MyGameMain.tscn
```

Useful commands:

```powershell
godot-mcp open_scene --path "res://Game/Cd_ProjectZero/Scenes/Boot/MyGameStart.tscn"
godot-mcp get_editor_scene_structure --include_scripts true --include_properties true --max_depth 4
godot-mcp run_project
godot-mcp get_debug_output
godot-mcp get_editor_errors
```

If a breakpoint is needed:

```powershell
godot-mcp debugger_set_breakpoint --script_path "res://Game/Cd_ProjectZero/Scripts/Boot/MyGameStart.gd" --line 1
godot-mcp run_project
godot-mcp debugger_get_current_state
```


## Plugin Internal Commands Not Exposed By Current CLI

The current `addons/godot_mcp/mcp_enhanced_commands.gd` includes internal handlers such as:

```text
update_node_transform
evaluate_runtime
subscribe_debug_output
unsubscribe_debug_output
```

But current `godot-mcp --list-tools` exposes:

```text
evaluate_runtime_expression
stream_debug_output
```

and does not expose `update_node_transform` as a CLI tool. Use the CLI list as the automation truth.


## MCP Client Configuration Note

Current `.ai/mcp/mcp.json` contains:

```json
{
  "mcpServers": {
    "godot-mcp": {
      "command": "node",
      "args": [
        "index.js"
      ],
      "env": {
        "MCP_TRANSPORT": "stdio"
      }
    }
  }
}
```

Verify that `index.js` resolves correctly for the client that reads this config. If the client starts from another working directory, prefer an absolute path to the built server entry, or use the installed CLI/server command expected by that client.

For direct CLI automation inside this repo, use:

```powershell
godot-mcp --list-tools
godot-mcp <tool> [--flag value]
```


## Checklist Before Automated Edits

Before editing through CLI:

```text
1. Confirm whether the task targets framework code or Game/Cd_ProjectZero.
2. Read ProjectPrompt.md for Game tasks.
3. Open or inspect the exact target scene.
4. Prefer read-only structure and property queries first.
5. Avoid delete/reload/execute_editor_script unless explicitly required.
6. Save the scene only after checking the intended changes.
7. Run project or target scene when behavior changed.
8. Read Output and Errors panels.
9. Check git status.
```

For current game development, the default target should be:

```text
Game/Cd_ProjectZero/
```

For reusable Comedot framework development, state the framework target explicitly before using write commands outside `Game/`.
