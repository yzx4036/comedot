# Comedot Best Practices

A practical guide for contributors and AI agents working on Comedot framework code.


## 1) Project Structure and Scope
- Framework-first code lives outside `Game/`.
- `Game/` is for project-specific implementations and should stay isolated from framework improvements.
- Ignore `Temporary/` and `Lab/` for normal implementation and review work.
- Core reusable gameplay logic belongs in:
	- `Components/` (behavior units)
	- `Entities/` (containers of components)
	- `Resources/` (data classes)
	- `Scripts/` (shared non-component logic)


## 2) Preferred Architecture Patterns
- Implement gameplay by composing components on entities, not by growing monolithic entity scripts.
- Reuse existing subsystems before creating new ones (combat, stats, actions, interactions, turn-based).
- New components should be scene+script pairs (`.tscn` + `.gd`) and inherit from `Components/Component.gd` (or subclass).
- Choose component root node by responsibility:
	- `Node` for logic-only
	- `Node2D` for visual/offsettable trees
	- specialized root nodes (`Timer`, `Area2D`, etc.) when that node is the actual behavior core
- Add node groups consistently (`components`, `entities`, and gameplay groups like `players`, `enemies`, `turnBased`).


## 3) Coding and Naming Conventions
- Use tabs, not spaces.
- Use camelCase broadly (including constants in this repository).
- Keep explicit static typing where practical.
- Use `class_name` for entities/components and runtime-referenced reusable classes.
- Signal handlers should follow `on[Emitter]_[signal]`.
- Avoid variable/property shadowing (for example avoid reusing names like `body` when inherited).


## 4) Startup Flow (Boot Sequence)
Current default startup flow is:
1. `project.godot` sets `run/main_scene` to `Scenes/Launch/Logo/IOLogoScene.tscn`.
2. `Scenes/Launch/Logo/IOLogoScene.gd` extends `Scripts/Start.gd`.
3. `Start._enter_tree()` runs early and calls `setupGameState()`.
4. `Start._ready()` calls `startComedot()` then `applyGlobalFlags()`.
5. `Start` applies debug flags, initializes music via `GlobalSonic`, and configures/removes `TurnBasedCoordinator` based on settings.
6. Logo scene transitions via `SceneManager.transitionToScene(preload("res://Scenes/Launch/GameFrame.tscn"), false)`.
7. `Scenes/Launch/GameFrame.tscn` also attaches `Scripts/Start.gd` at root, ensuring framework startup assumptions remain true.

Important startup rule:
- If you subclass `Start`, overridden `_enter_tree()` and `_ready()` must call `super`.


## 5) Scene and Navigation Practices
- Use `SceneManager` APIs for transitions and stack navigation instead of ad-hoc scene changes.
- Keep pause/unpause behavior consistent with `SceneManager.setPause()` and related signals.
- For globally persistent visuals/audio/UI behavior, prefer existing autoload singletons (`GlobalUI`, `GlobalSonic`, etc.).


## 6) Turn-Based Practices
- Integrate turn-based behavior through existing flow:
	- `AutoLoad/TurnBasedCoordinator.gd`
	- `Entities/TurnBased/TurnBasedEntity.gd`
	- turn-based components
- Do not create parallel turn coordinators or disconnected state machines when existing APIs cover the requirement.


## 7) Validation and Testing Workflow
- First-pass validation: run the project (`F5`) or target scene (`F6`) in editor.
- Manual feature checks should use scenes under `Tests/` when available.
- Syntax/check-only command pattern:

```bash
godot --headless --check-only --path /absolute/path/to/comedot --script res://path/to/script.gd --log-file /tmp/comedot.log
```

- If headless runtime is unavailable, keep changes conservative and validate with static code inspection.


## 8) Common Anti-Patterns
- Adding game-specific logic to framework entities when a component is more reusable.
- Editing only a component script while forgetting its paired scene requirements.
- Introducing broad refactors without a direct request.
- Replacing established project patterns (`SceneManager`, `Debug`, `Start`) with parallel one-off utilities.

