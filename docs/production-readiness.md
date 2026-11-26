# comedot 生产可用性基线

> 由 `_ToolScript/audit_production.sh` 生成于 2026-11-26 09:14。**不要手改**，框架升级后重跑。
> 引擎：PackedStringArray("4.8", "C#")

## 1. 组件稳定性

| 指标 | 数量 |
|---|---|
| 组件总数 | 123 |
| **整类 @experimental**（慎用，不当地基） | 24 |
| 仅局部成员标记（组件本体可用） | 11 个文件 / 18 处标记 |
| 可直接用作地基 | 99 |

⚠️ `@experimental` 是**逐成员**标记，不是整类标记。判据：标记出现在 `class_name`/`extends` 之前才算整类。
按文件 grep 会把 `Component` 基类、`CharacterBodyComponent`、`PlatformerPhysicsComponent` 这类
「只有一个方法/可选项实验」的核心组件误判成不可用。

### 整类 experimental — 不要当生产地基（24 个）

- `AI/TimerAgentComponentBase`
- `Combat/BulletlessGunComponent`
- `Combat/DamageOverTimeComponent`
- `Combat/DamageRayComponent`
- `Combat/DamageRepeatingComponent`
- `Combat/TileDamageComponent`
- `Control/AbilityTargetingCursorComponentBase`
- `Control/AbilityTargetingMouseComponent`
- `Control/AbilityTargetingPositionComponent`
- `Control/AsteroidsControlComponent`
- `Control/ClimbTileMapComponent`
- `Control/TileBasedAsteroidsControlComponent`
- `Gameplay/AbilityTargetableComponent`
- `Gameplay/ComponentSwapperComponent`
- `Interaction/InteractionMouseControlComponent`
- `Interaction/TextInteractionComponent`
- `Movement/IndependentPathFollowComponent`
- `Movement/NavigationComponent`
- `TurnBased/TurnBasedStateUIComponent`
- `TurnBased/TurnBasedTileBasedGravityComponent`
- `TurnBased/TurnBasedTileBasedPlatformerControlComponent`
- `Visual/LabelComponent`
- `Visual/ShapeDrawComponent`
- `Visual/TileBasedSightComponent`

### 仅局部成员 experimental — 本体可用，避开标了的那几个成员（11 个文件）

| 组件 | 标记数 |
|---|---|
| `Combat/DamageComponent` | 3 |
| `Combat/GunComponent` | 1 |
| `Component` | 4 |
| `Data/StatsComponent` | 1 |
| `Gameplay/AbilityReactionComponent` | 1 |
| `Interaction/MineableComponent` | 1 |
| `Movement/TileBasedPositionComponent` | 1 |
| `Physics/CharacterBodyComponent` | 2 |
| `Physics/PlatformerPhysicsComponent` | 1 |
| `Visual/DamageVisualComponent` | 1 |
| `Visual/HealthVisualComponent` | 2 |

## 2. 已知运行期故障（本仓实测踩到并规避）

这些是框架侧的问题，不是用法错误。升级上游后应重验，修好了就从下表删掉。

| 症状 | 触发条件 | 规避 |
|---|---|---|
| 调用即报 `Nonexistent function ... in base 'GDScript'` | 调 `FileSystemTools.findAllSubfolders()` / `getFilesInFolder()`（框架自身 `GlobalSonic` 启动时也踩） | 目录遍历改用 `DirAccess.get_directories_at()` / `get_files_at()` 自递归 |
| 引擎 `Abort trap: 6` | 二次实例化 `UI/PauseOverlay.tscn`（由 `GlobalUI` 托管） | 不要自己实例化，交给 `GlobalUI` |
| 加载即崩，报 `previously freed` | 加载 `Tests/TurnBased/TurnBasedTest.tscn`（依赖启动时被自删的 `TurnBasedCoordinator`） | 用前把 `ComedotProjectSettings.isTurnBasedGame` 设为 true |
| 加载报「配置文件不存在」 | `LubanConfigService` 用默认 `ConfigDirectory` | 显式设为 `res://Assets/Configs/GameConfigs` |
| 取字段恒为 null | 照 Excel/JSON 的 snake_case 写字段名 | 用 PascalCase：`&"SomeLongValue"` 不是 `&"some_long_value"` |
| `singleton register twice! TbExampleXxx`，整个 ConfigMgr 加载失败 | 进程里 new 了第二个 `LubanConfigService`（Luban 表类是 C# 静态单例） | 全项目只由一个 autoload 持有（本仓为 `GameConfigHub`），各场景统一向它取 |
| `Identifier not found: GameState`，随后「方法不存在」 | 用 `--script` 模式跑依赖框架组件的代码（autoload 在编译后注册） | 改用场景模式：`Godot --headless --path . --quit-after N res://<x>.tscn` |
| `Could not find type "Xxx"` | 新增带 `class_name` 的脚本后直接 headless 跑（全局类缓存未刷新） | 先 `Godot --headless --path . --import` |
| 配置表生成报「You must install or update .NET」 | `Luban.dll` 面向 .NET 8，机器只有更新运行时 | `DOTNET_ROLL_FORWARD=LatestMajor`（`gen_code_framework.sh` 已内置） |
| 生成后一堆 `.uid` 显示删除 | Luban 清输出目录时删掉 Godot 的 `.uid` | 生成后 `git restore` 对应目录 |

## 3. 回归门禁

`Game/MyGame/Tests/Regression/runAll.sh --skip-screenshot` → **PASS**

```
CheckTestbed               PASS  0 项失败
CheckAllDemoScenes         PASS  41 个演示全部可开可关
CheckConfigTables          PASS  0 项失败
CheckBusinessConfigTables  PASS  0 项失败
CheckConfigDrivenGameplay  PASS  0 项失败
ProbeDemoScene             PASS  探针可用
CaptureTestbedScreenshot   SKIP  --skip-screenshot
CaptureLutCanvas           SKIP  --skip-screenshot
CheckFxPlayback            SKIP  --skip-screenshot
CaptureLevelShade          SKIP  --skip-screenshot
```

生产改动的最低门禁：这条命令必须 PASS。

本审计用 `--skip-screenshot` 跑，因此四个窗口模式检查（索引截图、shader A/B、特效播放、关卡明暗层）会记 SKIP；
有图形环境时不带参数跑同一脚本，这几项也会执行并给出 PASS。
每项检查的判据与「为什么这么判」见 `docs/regression-gates.md`。

## 4. 落地纪律

1. **地基只用第 1 节里「可直接用作地基」的组件**；整类 experimental 当参考，不当依赖。
2. **框架层改动单独成提交**，一条提交一个改动，便于日后 cherry-pick 提 PR 给上游。
3. **业务代码放 `Game/<业务>/`**，不要写进框架目录（`verify_project.sh` 会查越界）。
4. **上游升级前先跑 `_ToolScript/update_project.sh --dry-run`**，并保留 `Game/` 不动。
5. **配置文件、美术资源等的路径用 `res://`**，不要写本机绝对路径（公开仓硬约束）。
