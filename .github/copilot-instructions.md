# Copilot Instructions for Comedot

## What This Repository Is
- Comedot is a reusable Godot 2D gameplay framework centered on composition (Entities + Components), not inheritance-heavy monolithic scripts.
- The framework lives outside `Game/`; `Game/` is game-specific and should only be changed when the task is explicitly about a game implementation.
- Use `project.godot` as the runtime truth, especially `config/features` (currently `4.7`) and enabled autoloads/plugins.


## Game-Specific Project Memory
- The current active game root is `Game/Cd_ProjectZero/`, as defined by `Game/override.cfg`.
- For any task inside `Game/`, read `Game/Cd_ProjectZero/Docs/ProjectPrompt.md` first and treat it as the canonical game-specific prompt.
- `Game/Cd_ProjectZero/Docs/ProjectPrompt.md` is a Chinese-language document; expect mixed Chinese and English for paths, identifiers, scene names, APIs, and technical terms.
- Before reading or summarizing game plans / memory, preserve the original mixed-language meaning instead of translating code symbols or file paths.
- Use that document for the current game's design direction, project overview, development constraints, and decision log; update it when those change.
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
- Treat `@experimental` code findings/changes as lower priority unless stable code depends on them.
- Do not add generic "best practices" that conflict with existing repository conventions; mirror current codebase behavior.

