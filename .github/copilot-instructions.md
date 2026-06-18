<!--
⚠️ DEPRECATED — 2026-05
本文件已弃用。当前唯一 AI 工具为 Claude Code。
权威配置在：
- .claude/CLAUDE.md（框架）
- Game/.claude/CLAUDE.md（游戏）
- .claude/settings.json（权限/hooks）
本文件保留仅供历史参考，不再维护。所有规则以 CLAUDE.md + Conventions.md 为准。
-->

# Copilot Instructions for Comedot (DEPRECATED)

## ⚠️ 此文件已弃用 — 请参阅 .claude/CLAUDE.md

## What This Repository Is
- Comedot is a reusable Godot 2D gameplay framework centered on composition (Entities + Components), not inheritance-heavy monolithic scripts.
- The framework lives outside `Game/`; `Game/` is game-specific and should only be changed when the task is explicitly about a game implementation.
- This workspace currently has two separate Git repositories: the root repository is the Comedot framework repository, and `Game/` contains the business/game project repository. Keep framework and game Git status, branches, merges, commits, and history separate.
- `Game/` is intentionally ignored by the root Comedot `.gitignore`; game project folders under it are expected to be independent Git repositories. Keep framework and game Git workflows separate.
- Use `project.godot` as the runtime truth, especially `config/features` (currently `4.7`) and enabled autoloads/plugins.


## Game-Specific Project Memory
- The current active game root is `Game/Cd_ProjectZero/`, as defined by `Game/override.cfg`.
- For any task inside `Game/`, read `Game/Cd_ProjectZero/Docs/ProjectPrompt.md` first and treat it as the canonical game-specific prompt.
- `Game/Cd_ProjectZero/Docs/ProjectPrompt.md` is a Chinese-language document; expect mixed Chinese and English for paths, identifiers, scene names, APIs, and technical terms.
- Before reading or summarizing game plans / memory, preserve the original mixed-language meaning instead of translating code symbols or file paths.
- Use that document for the current game's design direction, project overview, development constraints, and decision log; update it when those change.
- For gameplay-related tasks, also read `Game/Cd_ProjectZero/Docs/Gameplay/GameplayDesign.md` and `Game/Cd_ProjectZero/Docs/DevPlan.md` before planning or implementing. Keep the work aligned with the documented gameplay direction unless the user explicitly changes the design.
- After completing gameplay-related work, check whether `DevPlan.md` should be updated for changed scope, milestone order, acceptance criteria, or next steps, and update it when needed.
- When implementing gameplay, inspect the existing Comedot framework `Entities/` and `Components/` first. Prefer reusing or extending existing entities/components; if something similar exists, implement the game-specific behavior as a `Game/` subclass or inherited scene rather than duplicating framework code or creating a parallel architecture.
- New game-layer gameplay entities/components must use the `GP` prefix in filenames, scene names/root node names, and `class_name` values.
- Keep framework-layer guidance in this file separate from game-layer guidance in the game prompt so reusable Comedot rules stay clean.


## High-Value Folder Map
- `Components/`: reusable gameplay behavior units (always scene + script).
- `Entities/`: container nodes that aggregate components.
- `AutoLoad/`: global singletons (`Global`, `Settings`, `SceneManager`, `Debug`, `GlobalUI`, `GlobalSonic`, `TurnBasedCoordinator`, etc.).
- `Scripts/`: shared scripts that are not entities/components. Important: `Scripts/Start.gd` boots framework state.
- `Resources/`: data/resource classes (`Stat`, `Action`, `Upgrade`, payloads, collections).
- `Tests/`: manual playable test scenes (`*Test.tscn` with optional companion script).
- `Temporary/`, `Lab/`: experimental/transient; ignore for review and implementation decisions.


## Non-Negotiable Architecture Rules
- Prefer adding/changing a component over adding game logic to entity scripts.
- Components must be a `.tscn` + `.gd` pair and inherit `Components/Component.gd` (directly or indirectly).
- Component root node type must match responsibility:
	- logic-only: `Node`
	- visual/offsettable component trees: `Node2D`
	- specialized single-purpose nodes: use the specialized node as root (`Timer`, `Area2D`, etc.)
- Add component roots to `components` group and entity roots to `entities` group.
- Use `class_name` for entities/components and reusable runtime-referenced classes.


## Startup and Scene Boot Expectations
- Main scenes should run `Scripts/Start.gd` early (root node is preferred).
- If extending `Start`, overridden `_enter_tree()` and `_ready()` must call `super`.
- Current default flow from `project.godot`:
	1. `run/main_scene` -> `Scenes/Launch/Logo/IOLogoScene.tscn`
	2. `IOLogoScene.gd` (`extends Start`) runs framework boot
	3. scene transitions via `SceneManager.transitionToScene(...)` to `Scenes/Launch/GameFrame.tscn`
- `Start.gd` responsibilities include `GameState` initialization, debug flags, music setup, and optional turn-based coordinator setup/removal.


## Style and Naming (Follow Existing Patterns)
- Tabs, not spaces.
- camelCase for most identifiers (including constants in this codebase).
- Capitalized type names.
- Prefer explicit static typing (`var value: int = 1`).
- Signal handler naming: `on[Emitter]_[signal]`.
- Avoid variable/property shadowing (especially inherited or shared common names like `body`).


## Godot-Specific Patterns in This Codebase
- Both `is` and `as` are used; `is_instance_of(...)` is also common.
- For self-cast patterns, repository commonly uses `get_node(".") as SomeType` for typed assignment.
- If you add casts/type checks, match nearby file style instead of introducing a new pattern.


## Workflow for AI Changes
- Before implementing, search for an existing subsystem/component with similar behavior and reuse/extend it.
- Do not refactor broad areas unless requested; keep changes scoped.
- For turn-based features, integrate with `TurnBasedCoordinator` and `TurnBasedEntity`/turn-based components instead of inventing parallel flow.
- For scene transitions/navigation, use `SceneManager` APIs (`transitionToScene`, stack helpers).
- For debug and logging, prefer `Debug` AutoLoad utilities over ad-hoc prints when touching framework code.


## Git Automation
- If the user says `合并up_stream到dev`, perform the Git Flow style merge workflow automatically in the current relevant repository. Follow Git Flow's feature branch model and completion concept; do not require the literal `git flow` command when normal Git commands can implement the same branch workflow.
	1. Start a new feature branch with the configured Git Flow feature prefix, using a clear name such as `feature/merge-up_stream-to-dev`.
	2. Fetch / pull the remote `up_stream` branch and merge that remote update into the new feature branch.
	3. Resolve conflicts directly when the correct resolution is clear. If not, stop and ask the user to resolve the conflict manually.
	4. Finish the feature in the Git Flow sense by merging it back into the Git Flow development branch, expected to be `dev` or the repository-configured development branch, then remove the completed feature branch when appropriate.
	5. Analyze the pulled `up_stream` changes and improve relevant docs when behavior, workflow, architecture, gameplay planning, MCP/Godot automation guidance, or repository rules changed.
- If the user says `提交dev`, analyze the current relevant repository changes and create a commit on `dev` or the current Git Flow development branch. Use Chinese for the commit description. Add `[feat]` for feature additions and `[fix]` for bug fixes when appropriate; use a concise Chinese title without those prefixes for documentation, planning, refactor, chore, or mixed maintenance work.
- Keep root Comedot Git workflow separate from the `Game/` business repository. Run Git automation only in the repository that matches the user's target context. Do not push unless explicitly requested.


## Godot MCP CLI Workflow
- If a task needs Godot Engine interaction (editor state, scenes, nodes, running project, debugger, output/errors, runtime input, or `测试xx` / `测试<something>`), first read `_Doc/GodotMcpCliAutomationGuide.md`.
- Treat `godot-mcp-cli` as the project-specific skill/tool workflow for relevant Godot editor/runtime operations before falling back to manual editor instructions or headless checks.
- For MCP-driven operation, implementation, and testing, inspect `addons/godot_mcp/commands/` when needed to understand the Godot-side command behavior and parameters, then invoke the matching `godot-mcp-cli` tool.
- Use `input_commands.gd` for mouse/keyboard/InputMap actions, `node_commands.gd` for node creation/properties, `scene_commands.gd` for scene operations, and the project/debugger/editor/script/enhanced/asset command processors for implementation, test, and acceptance workflows.
- For runtime behavior validation, actively use mouse, keyboard, InputMap actions, and input sequences to test movement, interaction, attacks, and UI clicks.


## Validation and Testing
- Preferred runtime checks:
	- Run project scene (`F5`) or specific scene (`F6`) in editor.
	- Manual tests in `Tests/`.
- Headless syntax/check-only pattern:
	- `godot --headless --check-only --path /absolute/path/to/comedot --script res://path/to/script.gd --log-file /tmp/comedot.log`
- If headless runtime is unavailable, do static read/lint validation and keep edits conservative.


## Scope and Review Guardrails
- Ignore `Temporary/` and `Lab/` unless explicitly requested.
- Ignore `Game/` unless task is game-specific.
- Do not use root repository `git status` as a required recurring check for `Game/` work. The root repo intentionally ignores `Game/`; inspect the relevant nested game repository only when the task requires Git state there.
- Treat `@experimental` code findings/changes as lower priority unless stable code depends on them.
- Do not add generic "best practices" that conflict with existing repository conventions; mirror current codebase behavior.
