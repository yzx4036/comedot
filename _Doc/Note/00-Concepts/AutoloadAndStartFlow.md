# Autoload and Start Flow

## Scope
Framework startup path from `project.godot` main scene to first frame scene handoff.

## Runtime truth from project settings
- Feature target: `config/features = ["4.7"]`.
- Main scene: `run/main_scene = uid://7hpq16neqhai` (Logo launch scene).
- Core AutoLoads enabled:
	- `Global`, `Settings`, `SceneManager`, `GlobalInput`, `GameState`, `GlobalUI`, `GlobalSonic`, `TurnBasedCoordinator`, `Debug`.

## Startup call chain
1. Engine loads main scene from `project.godot`.
2. `Scenes/Launch/Logo/IOLogoScene.gd` (class `LogoSceneIO`) runs and extends `Start`.
3. `Start._enter_tree()` runs first and calls `setupGameState()`.
4. `Start._ready()` runs and calls `startComedot()`.
5. `startComedot()` sets framework boot markers and invokes `applyGlobalFlags()`.
6. Logo scene continues its own `_ready()` logic and later transitions to `Scenes/Launch/GameFrame.tscn` via `SceneManager.transitionToScene(...)`.

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
- [ ] Transition destination (`GameFrame.tscn`) resolves and loads.

