# Debug And AutoLoad Logging

## Scope
Framework-level Debug AutoLoad behavior and the startup logging pattern used by AutoLoads.

## Current behavior
- `Debug.gd` is an AutoLoad scene that owns the debug window, custom log window, debug labels, warning label, and watch list.
- `Debug._ready()` now reads as a sequence of explicit setup steps:
	1. `initializeLogWindow()`
	2. `initializeDebugWindow()`
	3. `displayInitializationMessage("_ready()")`
	4. `resetLabels()`
	5. `setLabelVisibility()`
	6. `performFrameworkChecks()`
- `performFrameworkChecks()` reports a visible warning when `Global.hasStartScript` is false. This means the running main scene probably does not have `Scripts/Start.gd` on the root node, or a subclass forgot to call `super`.
- `showDebugLabels` controls the debug label and watch list visibility and toggles processing so the watch list does not update every frame when labels are disabled.
- The warning label is intentionally kept visible even when normal debug labels are hidden.

## AutoLoad Startup Log Pattern
- Use `Debug.printAutoLoadLog(message)` for AutoLoad lifecycle messages, especially from `_notification(NOTIFICATION_PARENTED)` and early `_ready()` calls.
- `printAutoLoadLog()` is deliberately minimal and avoids regular frame bookkeeping. This keeps it safe while AutoLoads are still initializing.
- Current AutoLoads using this pattern include:
	- `Settings`
	- `GameState`
	- `GlobalInput`
	- `GlobalUI`
	- `TurnBasedCoordinator`
	- `Debug`
- `Settings` logs and loads user preferences from `NOTIFICATION_PARENTED`, which happens before `_enter_tree()`.

## When To Use Each Debug Method
| Method | Use for |
| --- | --- |
| `Debug.printAutoLoadLog()` | Early AutoLoad lifecycle and startup order messages. |
| `Debug.printDebug()` | Debug-only low-priority messages controlled by `shouldPrintDebugLogs`. |
| `Debug.printLog()` | Normal rich log output after debug state is available. |
| `Debug.printTrace()` | Focused stack-aware debugging in debug builds. |
| `Debug.printWarning()` / `Debug.printError()` | User-visible warnings/errors that should not be hidden by debug log settings. |

## Maintenance Notes
- Do not add direct `print()` calls to AutoLoads for startup tracing unless there is a specific reason. Prefer `Debug.printAutoLoadLog()` so output is consistent.
- Keep `Global.Colors.logAutoload` as the common AutoLoad log color.
- If adding new framework checks, prefer adding them to `Debug.performFrameworkChecks()` so they appear in one predictable place.
- If changing the expected startup root, update `performFrameworkChecks()` and the startup flow notes together.
