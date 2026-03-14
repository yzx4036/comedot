# Prompt Guide for Comedot Tasks

This file provides reusable prompt templates for AI coding assistants working in this repository.


## Before You Ask the AI
- State whether the change targets framework code or `Game/` code.
- Provide exact file paths when possible.
- Say whether you want minimal patch vs broad refactor.
- If scene behavior is involved, include the scene path (`.tscn`) and expected runtime behavior.


## Prompt Template: Add a New Component
```text
Create a new reusable component in `Components/<Category>/`.
Requirements:
- Name: <Name>Component
- Purpose: <single responsibility>
- Root node type: <Node|Node2D|Area2D|Timer...>
- Must inherit from `Components/Component.gd` (or subclass)
- Add to `components` group
- Include `.tscn` + `.gd`
- Use explicit typing and current naming conventions
- Show how to attach/use it in an Entity
Also add/update a minimal test scene under `Tests/` if needed.
```


## Prompt Template: Extend Existing Subsystem
```text
Implement <feature> by extending existing <subsystem> without creating a parallel architecture.
Search first for related classes in:
- `Components/`
- `Entities/`
- `Resources/`
Use existing signals/data flow patterns and keep patch scoped.
Output:
1) files changed
2) key behavior changes
3) manual verification steps in Godot editor
```


## Prompt Template: Bug Fix
```text
Fix <bug description>.
Constraints:
- No broad refactor
- Preserve existing API unless required
- Follow local style in touched files
- Avoid modifying `Temporary/`, `Lab/`, and unrelated `Game/` files
After patch, list likely regression risks and a quick manual test path.
```


## Prompt Template: Code Review
```text
Review the changes in <paths or PR scope>.
Prioritize:
1. Functional bugs
2. Behavioral regressions
3. Missing/weak test coverage
4. Risky assumptions
Ignore experimental and transient areas unless critical dependencies exist.
```


## Prompt Template: Startup/Scene Flow Tasks
```text
Update startup flow behavior.
Context:
- Boot script: `Scripts/Start.gd`
- Main scene from `project.godot` (`run/main_scene`)
- Transition APIs in `AutoLoad/SceneManager.gd`
Requirements:
- Keep `Start` super-calls intact when subclassing
- Avoid breaking autoload expectations
- Document changed flow steps in markdown
```


## Good Prompting Examples
- "Add a reusable `CollectOnProximityComponent` under `Components/Interaction/` with a `Node2D` root and scene+script pair. Reuse existing collectible subsystem signals if available."
- "Fix duplicate pause toggle issue by changing only `AutoLoad/SceneManager.gd` and relevant UI script; do not alter unrelated input mappings."
- "Review turn-based queue processing in `AutoLoad/TurnBasedCoordinator.gd` and `Entities/TurnBased/TurnBasedEntity.gd`; list concrete bugs first with line refs."


## Anti-Patterns to Avoid in Prompts
- "Rewrite architecture" without scope.
- "Optimize everything" without profiling target.
- "Make it clean" without acceptance criteria.
- Asking to edit both framework and `Game/` simultaneously without boundaries.

