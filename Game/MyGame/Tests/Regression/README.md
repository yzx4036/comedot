# Regression — 功能测试台的自动验收

`Game/MyGame/Scenes/Testbeds/FrameworkFeatureTestbed.tscn` 展示的是 comedot 框架的**当前实际功能**。
这组脚本负责在改完框架/清单之后，用一次命令证明那个「展示」还是对的。

不属于「打开场景手点」的手工测试（那类放 `Tests/Manual/`），这里是 headless 跑的自动断言。

## 一条命令

```bash
Game/MyGame/Tests/Regression/runAll.sh
```

```bash
Game/MyGame/Tests/Regression/runAll.sh --skip-screenshot   # 无图形环境 / CI
GODOT_BIN=/path/to/Godot runAll.sh                          # 引擎不在默认位置（跨设备必设）
```

退出码：`0` 全通过，`1` 有失败项，`2` 环境问题（找不到引擎或项目根）。

> ⚠️ 新克隆的仓要先导一次项目，否则 `load()` 拿不到资源：
> `Godot --headless --path . --import`

## 四个脚本

| 脚本 | 管什么 | 成功标记 |
|---|---|---|
| `CheckTestbed.gd` | 按钮网格构建、清单与磁盘双向对照、演示启动/卸载/连开、搜索与类别筛选（28 项断言） | `AUTO_RESULT PASS` |
| `CheckAllDemoScenes.gd` | 把清单里**每一个**带演示的条目逐个「打开→关闭」，查崩溃与残留节点 | `AUTO_RESULT PASS` |
| `CheckConfigTables.gd` | 框架示例表的运行时：数据目录、四种表形态、字段命名契约、Loader 门面（38 项断言） | `AUTO_RESULT PASS` |
| `CheckBusinessConfigTables.gd` | **业务表**（`mygame_*`）的运行时：与框架表共存、map/one 形态、枚举别名→枚举名（25 项断言） | `AUTO_RESULT PASS` |
| `CheckConfigDrivenGameplay.tscn` | **表驱动玩法**：关卡生成数/血量/倒计时/击杀次数与表一致，通关与超时判定（57 项断言） | `AUTO_RESULT PASS` |
| `ProbeDemoScene.gd` | 单场景安全性探针：实例化指定场景跑 N 帧，判断它够不够格当演示 | `PROBE_OK <path>` |
| `CaptureTestbedScreenshot.gd` | 窗口模式截图（功能索引 / 演示视图），视觉验收用 | `SHOT_SAVED <path> <WxH>` |

两个配置表测试依赖 C# 已编译；`CheckConfigDrivenGameplay` 依赖业务表已生成。前置就绪时打印 `AUTO_RESULT SKIP`，runner 记 SKIP 而不算失败。

### 两种运行模式，别搞混

| 模式 | 适用 | 命令 |
|---|---|---|
| `--script`（SceneTree） | 不碰 autoload 的检查 | `Godot --headless --path . --script <x.gd> --quit-after N` |
| 场景模式 | **碰框架组件的检查**（`HealthComponent` / `Stat` 内部引用 autoload `GameState`） | `Godot --headless --path . --quit-after N res://<x>.tscn` |

`--script` 模式在 autoload 注册**之前**编译脚本，碰到引用 autoload 的框架脚本会报
`Identifier not found: GameState` 并让整条依赖链编译失败 —— 表现是「脚本没挂上、方法找不到」，很容易误判成自己代码的问题。
`CheckConfigDrivenGameplay` 因此做成了场景形态。

单独跑：

```bash
# 结构断言
Godot --headless --path . --script Game/MyGame/Tests/Regression/CheckTestbed.gd --quit-after 900

# 全部演示逐个开关
Godot --headless --path . --script Game/MyGame/Tests/Regression/CheckAllDemoScenes.gd --quit-after 2400

# 配置表运行时（需先 dotnet build）
Godot --headless --path . --script Game/MyGame/Tests/Regression/CheckConfigTables.gd --quit-after 900

# 探一个候选场景能不能当演示（帧数缺省 30）
Godot --headless --path . --script Game/MyGame/Tests/Regression/ProbeDemoScene.gd --quit-after 600 \
    -- res://Tests/Combat/CombatTest.tscn

# 截图（必须窗口模式；headless 会打印 SHOT_SKIPPED 并退 2）
Godot --path . --script Game/MyGame/Tests/Regression/CaptureTestbedScreenshot.gd -- demo
```

截图默认写到 `user://`（导出/沙箱环境都能写），脚本会打印 `globalize_path()` 后的绝对路径。
macOS 上落在 `~/Library/Application Support/Godot/app_userdata/<项目名>/`。

## 给清单加演示场景的流程

1. 先用探针过一遍：`ProbeDemoScene.gd -- <候选场景>`，要看到 `PROBE_OK`
2. 再把 stderr 一起收走看有没有 `SCRIPT ERROR` —— 探针在脚本内**判不了**运行期报错（走引擎 stderr）
3. 干净了才在 `FrameworkFeatureCatalog._build()` 里登记第 5 个参数
4. 跑一次 `runAll.sh`，`CheckAllDemoScenes` 会把新条目也扫一遍

已被排除、**别再加回去**的几类：

- `UI/PauseOverlay.tscn` —— 由 `GlobalUI` 管理，二次实例化会让引擎直接 abort
- `Tests/TurnBased/TurnBasedTest.tscn` —— 依赖启动时被自动移除的 `TurnBasedCoordinator`（需项目为 turn-based）
- `Tests/PopulateTest.tscn`、`UpgradeUI` / `UpgradeChoiceUI` / `AbilityButton` / `CameraFollowingLabel`
  —— 需要外部喂数据，打开即刷报错；只在清单里给路径，去编辑器单独跑

## 判据的两个层次

`CheckTestbed` 里的 `EXPECTED_COMPONENT_COUNT = 123` 是**金丝雀**，不是"必须永远等于 123"：

- 框架新增/删除组件 → 该断言失败 → 提醒你「清单该同步了」
- 同步完清单后把常量改成新数字

业务层的 `covered == total` 与 `notListed` 为空才是真正的护栏：漏登记一个组件就会红。

## 已知噪音

- `ERROR: 1 resources still in use at exit` —— 引擎退出时收尾噪音，`runAll.sh` 已过滤，不代表被测内容有问题
- 框架 `FileSystemTools` 的静态函数在本构建里调不通（框架自身 `GlobalSonic` 也踩到）。
  清单的目录遍历因此改用 `DirAccess` 自递归，不要再引回去
- 配置表测试**故意不**去调 `tb.row(advance表, id)` 或 `tb.val(..., &"snake_case")`：
  这两种错误用法会往 stderr 打 ERROR，虽是预期行为但会淹没真错误。
  契约改用「检查字典键全是 PascalCase」这种结构性断言来锁

## 表驱动玩法的验收做法（`CheckConfigDrivenGameplay`）

这条检查的核心是**期望值当场从表读**，不写死：

```gdscript
var expectedEnemyCount: int = int(tb.row(TABLE_LEVEL, levelId)["EnemyCount"])
playNode.startLevel(levelId)
assert playNode.enemyHost.get_child_count() == expectedEnemyCount   # 真生成了那么多节点
```

好处：改 Excel 后重跑断言自动跟着新值走；若代码改用硬编码，立刻红。

另配一组「快照」硬编码常量（`SNAPSHOT_ENEMY_COUNTS` 等）锁住当前表内容，
用来区分两种失败：

| 现象 | 含义 |
|---|---|
| 只有快照项红，动态项全绿 | 表变了、代码仍然正确读表 ⇒ 改快照常量即可 |
| 动态项红 | 代码没按表走（硬编码 / 读错表 / 桥接断了）⇒ 真 bug |

实测证过：把表里 L1 改成 `敌人数=7 / 血量=99` 重新生成后跑，
`PASS 关卡 1 敌人节点数 == 表 EnemyCount (7/7)`、`PASS 第 10 次攻击正好击杀（99/10）`，
而 `FAIL 敌人数 (7)`、`FAIL 敌人血量 (99)` 只有快照两项 —— 正是上表第一种情况。

## 配置表驱动玩法的三个运行期约束

| 约束 | 症状与原因 |
|---|---|
| 🔴 **`ConfigMgr` 全进程只能有一个** | Luban 表类是 C# 静态单例，第二个 `LubanConfigService` 会报 `singleton register twice! TbExampleXxx` 并让整个 ConfigMgr 加载失败。⇒ 由 autoload `GameConfigHub` 统一持有，各场景 `GameConfigHub.getService()` 取，不要自己 `script.new()` |
| 🔴 **碰框架组件的检查必须用场景模式跑** | 见上方「两种运行模式」 |
| **新增带 `class_name` 的脚本后要先 `--import`** | 否则 headless 报 `Could not find type "Xxx"`（全局类缓存没刷新），表现为「脚本没挂上」。`runAll.sh` 已在环境检查里自动 import |

## 配置表链路（Luban）的实测事实

改动配置表相关代码前先看这几条，都是实测出来的：

| 事实 | 影响 |
|---|---|
| `LubanConfigService.ConfigDirectory` 默认 `res://assets/configs/tables`，实际产物在 `res://Assets/Configs/GameConfigs` | **必须显式设**，用默认值加载不到（3 项断言会红） |
| `Tb.row()` 返回字典的键是 **PascalCase**（`Name` / `SomeLongValue`），不是 Excel 的 snake_case | 照 Excel 列名写 `&"some_long_value"` 取到 null |
| `Tb.val()` 大小写不敏感，但**不去下划线** | `&"name"` 能取到 `Name`，`&"some_long_value"` 取不到 `SomeLongValue` |
| `mode()` 返回 `map` / `list` / `one` 三种 | `map` 用 `row(id)`，`list` 只能用 `rows()`，`one` 用 `one()` |
| 枚举字段在 GDScript 侧是**字符串**（`"Consumable"`），不是数字 | 别拿 int 比 |
| 生成脚本 `gen_code_framework.bat` 是 Windows 批处理 | macOS/Linux 用同目录的 `gen_code_framework.sh` |
| `Luban.dll` 面向 .NET 8；只装了更新运行时的机器要 `DOTNET_ROLL_FORWARD=LatestMajor` | `.sh` 脚本已内置该环境变量 |
| Luban 生成会**删掉输出目录里的 `.uid`**（`[remove] xxx.cs.uid`） | 生成后要 `git restore` 回来，或接受 Godot 重新生成 |

生成 → 编译 → 测试的完整闭环：

```bash
_ConfigTables/gen_all_configs.sh --build   # 框架表 + 业务表 → 合并进运行目录 → 编译
Game/MyGame/Tests/Regression/runAll.sh
```

### 业务表（Game/MyGame/_ConfigTables/）

业务流程与框架表同构，但有四个必须知道的约束：

| 约束 | 原因 |
|---|---|
| 生成脚本是 `Game/MyGame/_ConfigTables/gen_code_business.sh`，**不要**直接调 Luban | 输出落点有讲究，见下 |
| 业务表的 C# 生成到 `Scripts/Mono/Luban/Configs/GameAutoGen/`，不在 `Game/` 下 | `Comedot.csproj` 有 `<Compile Remove="Game/**/*.cs" />`，放 `Game/` 下不会被编译；而 `ConfigMgr` 只扫自己所在程序集里的表类 |
| `luban.conf` 的 `topModule` 必须是 `Y0Studio.Config`，表 `full_name` 用 `MyGame.TbLevel` | `ConfigMgr` 默认前缀是 `Y0Studio.Config`；若 topModule 写成 `Y0Studio.Config.MyGame` 会变成 `...MyGame.MyGame.TbLevel`，枚举引用失配报 `type is invalid` |
| 业务 `.bytes` 先落到 `Game/MyGame/_ConfigTables/Configs/Bin/`，再由 `gen_all_configs.sh` 拷进运行目录 | **Luban 生成前会清空输出目录**；业务直接输出到 `Assets/Configs/GameConfigs` 会把框架的 `examples_*.bytes` 删掉 |

其余实测行为：

- 枚举字段在 Excel 里填**别名**（如「简单」），运行时 `Tb.val()` 读到的是**枚举名**（`"Easy"`）
- id 不存在时用 `tb.hasId()` 判断，**不要**调 `tb.row(不存在id)` —— 后者会往 stderr 打 ERROR
- 业务表缺任何一个 `.bytes`，`ConfigMgr` 整体加载失败，**框架表也一并读不到**（共用一个 ConfigDirectory）。所以运行目录里两类表必须同时齐

### 手工维护表结构时的两个格式铁律

改 `__tables__.xlsx` / `__beans__.xlsx` / `__enums__.xlsx` 时，**优先复制框架的 `_ConfigTables/Excel/Datas/*.xlsx` 再改内容**，不要用脚本从零建 sheet：

1. **不要 unmerge 合并单元格**：`__enums__.xlsx` 的 `*items` 是 `H1:L1` 合并，表示子结构横跨 5 列。解开后 Luban 认为子结构只有 1 列，报
   `bean:'__intern__.__EnumItem__' 缺失 列:'alias'` —— 即使逐格对比列位置完全一致也会报。
2. **子字段行必须对齐到合并区起点**：`##var` 第二行的 `name/alias/value/...` 要从 H 列（第 8 列）开始写，前面用空值占位。写到 B 列会让 Luban 认为 `full_name` 有子列，报「简单数据类型字段 不支持子列名或者多行」。
3. 合并区内的非左上角单元格是 openpyxl 的 `MergedCell`，只读，赋值会抛 `AttributeError` ⇒ 写脚本时跳过。
