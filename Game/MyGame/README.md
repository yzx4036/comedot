# Comedot Example

单仓模型下的一个**独立游戏业务**，位于 `Game/MyGame/`。

本业务的内容是 **comedot 框架功能测试台**：把框架当前的全部功能（组件 / 运行时 / 资源 / 场景 / UI / 模板）
列成多行多列的按钮，可直接在游戏里点开对应的演示场景跑一遍。

## 目录

```
Game/MyGame/
├── game.cfg                                        业务声明（窗口标题）
├── override.cfg                                    业务专属设置片段（逻辑分辨率提到 1280×720）
├── ComedotProjectSettings.tres                     启动契约：mainGameScenePath
├── Scenes/Testbeds/FrameworkFeatureTestbed.tscn     ★ 功能测试台（= 主场景）
├── Scenes/Testbeds/FrameworkFeatureTestbed.gd       测试台逻辑
├── Scripts/UI/FrameworkFeature.gd                   单条功能的数据结构
└── Scripts/UI/FrameworkFeatureCatalog.gd            ★ 功能清单（258 条）+ 双向对照自检
```

## 怎么用

1. `_ToolScript/select_game.sh MyGame` 切到本业务
2. Godot 打开 `project.godot`，F5 → Logo → 主菜单 → Start → 进入测试台
3. 左侧是按类别分组的多行多列按钮网格：单击看右侧说明，绿字条目带可运行演示
4. 点「运行演示」把该场景现场挂进 `DemoHost` 跑，左上「返回功能列表」卸载

想跳过 Logo/主菜单直奔测试台，就在 `Game/MyGame/override.cfg` 里加
`run/main_scene="res://Game/MyGame/Scenes/Testbeds/FrameworkFeatureTestbed.tscn"`（在 `[application]` 小节，
它是业务片段允许的两个小节之一，改完重跑 `select_game.sh MyGame`）。

## 功能清单怎么维护

`FrameworkFeatureCatalog.gd` 是**数据**，`Components/` 等目录是**事实**：

- 进场景时跑 `verifyCoverage()` 做双向对照，标题栏右上角显示
  `自检通过 · 条目 N · 组件覆盖 x/y · 可运行演示 z`
- 框架新增组件但清单没登记 → 自检转黄并列出「未录条目」
- 清单引用的路径被删 → 自检转红并列出「断链」

补录方式：在 `FrameworkFeatureCatalog._build()` 里按现有格式追加一行
`FrameworkFeature.new(类名, 类别, 中文说明, 脚本路径[, 演示场景])`。

> ⚠️ 演示场景只收「打开即干净」的：`PauseOverlay` 重复实例化会让引擎 abort，
> `TurnBasedTest` 依赖启动时被自动移除的 `TurnBasedCoordinator`，
> 需要外部喂数据的 UI 组件（UpgradeUI / AbilityButton / CameraFollowingLabel 等）也会刷报错。
> 这些一律留空、只在详情里给出路径，到编辑器里单独跑。

## 其它

- 不引用 `Game/` 下其他业务目录
- 切换到本业务：`_ToolScript/select_game.sh MyGame`
- 启动链路见 `Docs/StartupFlow.md`
