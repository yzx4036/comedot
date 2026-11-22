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
| `CheckConfigTables.gd` | Luban 配置表运行时：数据目录、四张表的形态、字段命名契约、Loader 门面（38 项断言） | `AUTO_RESULT PASS` |
| `ProbeDemoScene.gd` | 单场景安全性探针：实例化指定场景跑 N 帧，判断它够不够格当演示 | `PROBE_OK <path>` |
| `CaptureTestbedScreenshot.gd` | 窗口模式截图（功能索引 / 演示视图），视觉验收用 | `SHOT_SAVED <path> <WxH>` |

`CheckConfigTables` 依赖 C# 已编译；未编译时它打印 `AUTO_RESULT SKIP`，runner 记 SKIP 而不算失败。

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
_ConfigTables/gen_code_framework.sh     # Excel → C# 代码 + .bytes/.json
dotnet build Comedot.csproj             # 编译生成的 C#
Game/MyGame/Tests/Regression/runAll.sh  # 含 CheckConfigTables
```
