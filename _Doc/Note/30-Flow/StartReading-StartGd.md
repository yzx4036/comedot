# Start.gd Reading Note

Source: `Scripts/Start.gd`

## Purpose
- Boot Comedot framework state from the root node of the startup scene.
- Apply exported framework flags to AutoLoads at startup.
- Optionally configure and initialize turn-based runtime behavior.

## Region map
- `Framework Settings`
	- General: game scene path, initial global data, optional GameState child nodes.
	- Music: folder/source selection and playback strategy.
	- Turn-Based Gameplay: enable switch and delay tuning.
	- Debugging: debug window, log visibility, debug label/background visibility.
- `Bootup`
	- `_enter_tree()` -> calls `setupGameState()` early.
	- `_ready()` -> calls `startComedot()`.
	- `applyGlobalFlags()` -> pushes exported settings into AutoLoads.

## Lifecycle and why it is ordered this way
1. AutoLoads initialize before the startup scene. `Settings` may already have loaded user preferences in `NOTIFICATION_PARENTED`.
2. `_enter_tree()` runs first and calls `setupGameState()`.
3. `setupGameState()` updates `Settings.mainGameScenePath`, merges `GameState.globalData`, and spawns optional GameState nodes.
4. `_ready()` runs later and calls `startComedot()`.
5. `startComedot()` marks `Global.hasStartScript`, runs framework checks, then applies global flags.
6. `applyGlobalFlags()` configures debug/UI, music, and turn-based coordinator behavior.

This order ensures game-wide state is available before children that depend on it complete `_ready()`.

## Key exported fields and side effects
| Export | Main side effect |
| --- | --- |
| `mainGameScenePath` | Writes to `Settings.mainGameScenePath` via setter and `setupGameState()`. |
| `initialGlobalData` | Merged into `GameState.globalData` with overwrite enabled. |
| `gameStateNodes` | For each path, calls `GameState.createNode(path)`. |
| `musicFolder` / `musicFileToPlayOnStart` / `shouldPlayRandomMusicIndex` / `musicIndexToPlayOnStart` | Configure `GlobalSonic` and trigger playback choice. |
| `isTurnBasedGame` and turn delays | Configure `TurnBasedCoordinator`; or disable and `queue_free()` it when false. |
| Debug flags | Push values to `Debug` singleton visual/logging state. |

## Integration points
- AutoLoads touched directly:
	- `Global`
	- `Debug`
	- `Settings`
	- `GameState`
	- `GlobalSonic`
	- `TurnBasedCoordinator`
- Typical subclassing pattern:
	- `extends Start`
	- overridden `_enter_tree()` and `_ready()` must call `super`.

## Gotchas
- `Settings` does not wait for `_ready()` to load the config file; avoid adding startup code that assumes Settings is still unloaded during AutoLoad parenting.
- Early AutoLoad logs should use `Debug.printAutoLoadLog()` instead of `Debug.printLog()` when called before normal debug-frame state is reliable.
- `TurnBasedCoordinator` is intentionally removed when `isTurnBasedGame` is false; accessing it later can crash by design.
- Delay exports use minimum guard (`minimumTurnDelay = 0.05`) to avoid timer errors.
- Debug visual toggles check for node existence in some setters (`if Debug.debugWindow`).

## Quick trace checklist
- [ ] Confirm scene root script extends `Start`.
- [ ] Confirm `_enter_tree()` and `_ready()` super calls in subclasses.
- [ ] Confirm desired startup music mode.
- [ ] Confirm turn-based flag matches scene/game mode.
- [ ] Confirm `GameState` injected data keys do not accidentally overwrite required values.
