# Luban 配置表（框架方案）

> 源自 `_Doc/LubanConfigTables.md`（2026-10-13 并入 docs）· 业务路径引用已按"业务迁出"注记 · 架构视角概览见 `architecture-asbuilt.md` §4.2

本文档记录 Comedot 框架级 Luban 配置表方案与操作细节。


## 当前决策

- Luban 作为 Comedot 框架级可复用配置表能力。
- 实现留在框架层：`Scripts/Mono/Luban/` 与根 `_ConfigTables/`。
- 暂不迁为 addon；待运行时服务、GDScript 桥、编辑器校验与再生成工作流稳定后，再考虑 `addons/comedot_luban_config/`。
- 框架层演示样例：`_ConfigTables/Excel` 下的 `examples_tb*`（basic/list/singleton/advance），生成走 `gen_code_framework.bat`。


## 目录归属

框架层：

- `_ConfigTables/`
	- Luban 工具分发、自定义模板与共享生成脚本。
- `Scripts/Mono/Luban/`
	- Luban 运行时支持与 Godot 侧配置服务。

业务层（**历史路径**——武侠业务 `Cd_ProjectZero` 已迁出至业务仓 `Comedot_GDGameProjWuXia`；下列路径为迁出前的组织方式，保留作参考）：

- `Game/_ConfigTables/Excel`
	- 业务 Excel、schema 与 `luban.conf`。
- `Game/_ConfigTables/Configs/Json`
	- 生成 JSON 预览数据。
- `Game/Cd_ProjectZero/Scripts/Mono/Luban/Configs/AutoGen`
	- 生成的 C# 配置类。
- `Game/Cd_ProjectZero/Assets/Configs/GameConfigs`
	- 生成的 `.bytes` 运行时数据。


## 运行时入口

以 `Scripts/Mono/Luban/LubanConfigService.cs` 为框架服务节点。

重要导出属性：

- `ConfigDirectory`：生成的 `.bytes` 文件所在目录。
- `ConfigNamespacePrefix`：生成 C# 配置命名空间前缀，默认 `Y0Studio.Config`。
- `LoadOnReady`：是否在 `_Ready()` 中加载配置。

面向 GDScript 的方法：

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

按 Luban 模式取数：

- `map`：用 `GetRecord`、`GetRecords`、`GetValue`、`HasRecord`、`ValidateRecord`。
- `list`：用 `GetRecords`。
- `one`：用 `GetSingleton`、`GetSingletonValue`。

生成的 Luban 行对象应保持在 C# 内；GDScript 与场景存稳定表 ID，经服务读取字典、数组或标量。

GDScript 门面：

- 用 `Tb.new(lubanConfigServiceNode)`，避免在手写脚本里出现 C# 方法名字符串。
- 常用调用：
	- `tb.load()`
	- `tb.names()`
	- `tb.row(TbField.ExampleBasic.table, 1001)`
	- `tb.rows(TbField.ExampleBasic.table)`
	- `tb.val(TbField.ExampleBasic.table, 1001, TbField.ExampleBasic.name)`
	- `tb.one(TbField.ExampleSingleton.table)`
	- `tb.oneVal(TbField.ExampleSingleton.table, TbField.ExampleSingleton.newbieDiscountTimes)`

生成的 GDScript 常量：

- 运行 `LubanConfigNameGenerator.gd`（编辑器脚本，或编辑器脚本代码中调用 `LubanConfigNameGenerator.generate()`）。
- 默认输出 `TbCfg.gd`（表名常量）与 `TbField.gd`（字段名常量）——原默认输出路径为业务仓 `Game/Cd_ProjectZero/Scripts/Gameplay/Config/`（历史业务路径；当前业务仓使用其对应路径）。
- 用 `TbCfg.exampleBasic`、`TbField.ExampleBasic.name` 等常量，避免手写表名/字段名。
- 每当 `.bytes` 表文件增删改名（重新跑 Luban 后），需重新生成这些常量。


## 测试

迁移前的烟雾测试（历史业务仓）：

- `LubanConfigRuntimeTest.tscn`
	- C# 服务加载与可视化表显示。
- `LubanConfigBridgeTest.tscn`
	- GDScript 桥经 `LubanConfigService` 读取一条记录与一个列表。
- `M21LubanIdentityEffectTest.tscn`
	- GDScript 桥经 `TbCfg` / `TbField` / `Tb` 读取 M21 身份效果试点表，转换为运行时 `IdentityEffectSet`，并验证一个玩法价格效果。

预期 GDScript 桥输出：

```text
Luban bridge test | loaded true | tables 5 | item 瓶盖 | records 4 | validId true | invalidId false | modes map/list/one | singleton 3 | passed true
M21 Luban identity effect acceptance | loaded true | table true | mode map | rows 5 | validate true | runtime true | tresMirror true | failurePath true | constants true | passed true
```


## 版本控制策略

- 当 Godot C# 编译与编辑器资源身份需要时，跟踪生成的 `.cs` 与 `.cs.uid`。
- 当运行时烟雾测试或内容需要时，跟踪生成的 `.bytes`。
- 表 schema 仍处于人工评审期时，跟踪 JSON 预览数据。
- Luban 工具与源 Excel 不放进 `res://Assets`：框架工具用根 `_ConfigTables`，业务表源放业务仓的对应目录。
- `Assets/_ConfigTables` 已弃用，保持移除状态。
