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
- `GetTableMode(configName)`
- `HasTable(configName)`
- `HasRecord(configName, key)`
- `ValidateRecord(configName, key, requiredFields)`
- `GetRecord(configName, key)`
- `GetRecords(configName)`
- `GetValue(configName, key, fieldName)`
- `GetSingleton(configName)`
- `GetSingletonValue(configName, fieldName)`

Table access by Luban mode:
- `map`: use `GetRecord`, `GetRecords`, `GetValue`, `HasRecord`, `ValidateRecord`.
- `list`: use `GetRecords`.
- `one`: use `GetSingleton`, `GetSingletonValue`.

Generated Luban row objects should stay inside C#. GDScript and scenes should store stable table IDs and read dictionaries, arrays or scalar values through the service.

GDScript facade:
- Use `Tb.new(lubanConfigServiceNode)` to avoid hand-written C# method-name strings in game scripts.
- Common calls:
	- `tb.load()`
	- `tb.names()`
	- `tb.row(TbField.ExampleBasic.table, 1001)`
	- `tb.rows(TbField.ExampleBasic.table)`
	- `tb.val(TbField.ExampleBasic.table, 1001, TbField.ExampleBasic.name)`
	- `tb.one(TbField.ExampleSingleton.table)`
	- `tb.oneVal(TbField.ExampleSingleton.table, TbField.ExampleSingleton.newbieDiscountTimes)`

Generated GDScript config-name constants:
- Run `Scripts/Tools/Editor/GenerateLubanConfigNames.gd` in the Godot script editor, or call `LubanConfigNameGenerator.generate()` from editor script code.
- The default output is `Game/Cd_ProjectZero/Scripts/Gameplay/Config/TbCfg.gd`.
- Use constants such as `TbCfg.exampleBasic` instead of hand-written table-name strings.
- The same generator also writes `Game/Cd_ProjectZero/Scripts/Gameplay/Config/TbField.gd`.
- Use field constants such as `TbField.ExampleBasic.name` and `TbField.ExampleSingleton.newbieDiscountTimes` instead of hand-written field-name strings.
- Regenerate this file after running Luban whenever `.bytes` table files are added, removed or renamed.


## Tests

Current smoke tests:
- `Game/Cd_ProjectZero/Tests/Manual/Runtime/LubanConfigRuntimeTest.tscn`
	- C# service load and visual table display.
- `Game/Cd_ProjectZero/Tests/Manual/Runtime/LubanConfigBridgeTest.tscn`
	- GDScript bridge reads a record and a list through `LubanConfigService`.

Expected GDScript bridge output:

```text
Luban bridge test | loaded true | tables 4 | item 瓶盖 | records 4 | validId true | invalidId false | modes map/list/one | singleton 3 | passed true
```


## Version Control Notes

Current policy:
- Track generated `.cs` and `.cs.uid` when they are needed for Godot C# compilation and editor resource identity.
- Track generated `.bytes` when they are needed for runtime smoke tests or current gameplay content.
- Track JSON preview data while table schemas are still being reviewed by humans.
- Keep Luban tools and source Excel outside `res://Assets`. Use root `_ConfigTables` for framework tooling and `Game/_ConfigTables` for game-owned table sources.
- `Assets/_ConfigTables` is deprecated and should stay removed.
