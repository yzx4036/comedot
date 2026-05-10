# Luban Config Tables

This document records the current Comedot framework-level Luban configuration table scheme.


## Current Decision

- Luban is treated as a reusable Comedot framework configuration-table capability.
- The current implementation stays in the framework layer under `Scripts/Mono/Luban/` and root `_ConfigTables/`.
- Do not move it to an addon yet. Reconsider `addons/comedot_luban_config/` after the runtime service, GDScript bridge, editor validation and regeneration workflow are stable.


## Folder Ownership

Framework layer:
- `_ConfigTables/`
	- Luban tool distribution, custom templates and shared generation script.
- `Scripts/Mono/Luban/`
	- Luban runtime support and Godot-facing config service.

Game layer:
- `Game/_ConfigTables/Excel`
	- Game-owned Excel, schema and `luban.conf`.
- `Game/_ConfigTables/Configs/Json`
	- Generated JSON preview data.
- `Game/Cd_ProjectZero/Scripts/Mono/Luban/Configs/AutoGen`
	- Generated C# config classes.
- `Game/Cd_ProjectZero/Assets/Configs/GameConfigs`
	- Generated `.bytes` runtime data.


## Runtime Entry

Use `Scripts/Mono/Luban/LubanConfigService.cs` as the framework service node.

Important exported properties:
- `ConfigDirectory`: directory containing generated `.bytes` files.
- `ConfigNamespacePrefix`: generated C# config namespace prefix, default `Y0Studio.Config`.
- `LoadOnReady`: whether to load configs in `_Ready()`.

GDScript-facing methods:
- `LoadConfigs()`
- `ReloadConfigs()`
- `UnloadConfigs()`
- `GetConfigNames()`
- `HasTable(configName)`
- `HasRecord(configName, key)`
- `GetRecord(configName, key)`
- `GetRecords(configName)`
- `GetValue(configName, key, fieldName)`

Generated Luban row objects should stay inside C#. GDScript and scenes should store stable table IDs and read dictionaries, arrays or scalar values through the service.


## Tests

Current smoke tests:
- `Game/Cd_ProjectZero/Tests/Manual/Runtime/LubanConfigRuntimeTest.tscn`
	- C# service load and visual table display.
- `Game/Cd_ProjectZero/Tests/Manual/Runtime/LubanConfigBridgeTest.tscn`
	- GDScript bridge reads a record and a list through `LubanConfigService`.

Expected GDScript bridge output:

```text
Luban bridge test | loaded true | tables 4 | item 瓶盖 | records 4 | passed true
```


## Version Control Notes

The project still needs a final policy for generated files:
- generated `.cs`
- generated `.cs.uid`
- generated `.bytes`
- generated JSON preview data

Until that policy is confirmed, do not delete generated files just because they are untracked.
