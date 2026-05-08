# Autoload and Start Flow

## Scope
Framework startup path from `project.godot` main scene to first frame scene handoff.

## Runtime truth from project settings
- Feature target: `config/features = ["4.7"]`.
- Main scene: `run/main_scene = uid://7hpq16neqhai` (Logo launch scene).
- Core AutoLoads enabled:
	- `Global`, `Settings`, `SceneManager`, `GlobalInput`, `GameState`, `GlobalUI`, `GlobalSonic`, `TurnBasedCoordinator`, `Debug`.

## Startup call chain
1. Engine creates AutoLoads in `project.godot` order:
	`Global` -> `Settings` -> `SceneManager` -> `GlobalInput` -> `GameState` -> `GlobalUI` -> `GlobalSonic` -> `TurnBasedCoordinator` -> `Debug` -> optional plugin AutoLoads such as `MCPInputHandler`.
2. AutoLoads can receive `NOTIFICATION_PARENTED` before their `_enter_tree()` / `_ready()` callbacks.
3. `Settings._notification(NOTIFICATION_PARENTED)` loads the user configuration file and project user settings early, before normal scene startup logic depends on preferences.
4. Other AutoLoads use `Debug.printAutoLoadLog()` for early low-state startup logs that must be safe before the framework is fully ready.
5. Engine loads main scene from `project.godot`.
6. `Scenes/Launch/Logo/IOLogoScene.gd` (class `LogoSceneIO`) runs and extends `Start`.
7. `Start._enter_tree()` runs first and calls `setupGameState()`.
8. `Start._ready()` runs and calls `startComedot()`.
9. `startComedot()` sets framework boot markers and invokes `applyGlobalFlags()`.
10. Logo scene continues its own `_ready()` logic and later transitions to `Scenes/Launch/GameFrame.tscn` via `SceneManager.transitionToScene(...)`.

## AutoLoad initialization notes
- `Settings` must be treated as an early configuration source. Its config file can be loaded from `NOTIFICATION_PARENTED`, so startup code may read settings without waiting for `Settings._ready()`.
- `Debug` itself is an AutoLoad, but `Debug.printAutoLoadLog()` is intentionally minimal: it avoids frame/state bookkeeping and is suitable for early AutoLoad lifecycle messages.
- `Debug._ready()` initializes the log window, debug window, startup shortcut message, labels, visibility state, and framework checks.
- `Debug.performFrameworkChecks()` warns when `Global.hasStartScript` was not set by a `Start.gd` root script.
- `Global.Colors.logAutoload` defines the standard color used by AutoLoad startup logs.

## What Start applies globally
- Game state initialization:
	- optional main game scene path assignment.
	- initial global dictionary merge.
	- optional auto-instancing of scenes under `GameState`.
- Debug controls:
	- debug logs and overlay visibility routing to `Debug`.
- Audio controls:
	- `GlobalSonic` music folder loading and first track selection.
- Turn-based controls:
	- coordinator delay options, or coordinator removal when disabled.

## IOLogoScene-specific handoff notes
- Calls `super._ready()` before logo animation setup.
- Temporarily disables pause shortcuts during intro.
- Supports skip input and still transitions through `SceneManager`.
- Restores debug background and pause shortcut permissions on exit.

## Validation checklist
- [ ] `project.godot` main scene points to expected launch scene.
- [ ] Startup scene root script extends `Start` and keeps `super` calls.
- [ ] Required AutoLoads are enabled in `project.godot`.
- [ ] AutoLoad order keeps `Global` before `Settings`, and `Debug` available for runtime checks after core singletons exist.
- [ ] Startup logs show `Settings` loading before scene flow reaches `Start._ready()`.
- [ ] Transition destination (`GameFrame.tscn`) resolves and loads.
