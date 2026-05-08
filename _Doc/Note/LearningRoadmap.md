# Learning Roadmap

- [ ] Run the project from `project.godot` and verify boot scene flow.
- [ ] Read `Scripts/Start.gd` and summarize boot responsibilities.
- [ ] Trace AutoLoad interactions: `Debug`, `Settings`, `SceneManager`, `TurnBasedCoordinator`.
- [ ] Confirm `Settings` loads preferences during `NOTIFICATION_PARENTED` and understand why this happens before `_enter_tree()`.
- [ ] Review `Debug.printAutoLoadLog()` and identify which startup messages should use it instead of normal debug logs.
- [ ] Pick one component in `Components/` and map its data flow.
- [ ] Pick one entity in `Entities/` and map attached components.
- [ ] Record one practical change and validation steps in notes.
