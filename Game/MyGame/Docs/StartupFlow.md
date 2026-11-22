# 启动链路（Comedot Example）

1. `project.godot`：`config/project_settings_override="res://Game/override.cfg"`
2. `Game/override.cfg` 把 `comedot/settings/comedotProjectSettingsPath` 指向 `res://Game/MyGame/ComedotProjectSettings.tres`，
   并把 `Game/MyGame/override.cfg` 的业务片段（分辨率 1280×720）并入
3. `Game/MyGame/ComedotProjectSettings.tres` 的 `mainGameScenePath` =
   `res://Game/MyGame/Scenes/Testbeds/FrameworkFeatureTestbed.tscn`
4. 运行 → `Scenes/Launch/Logo/IOLogoScene.tscn` → `Scenes/Launch/GameFrame.tscn` → Start →
   `GameState.startMainScene()` → 功能测试台

## 注意

- 启动脚本用普通 `Control`/`Node2D`，**不要** `extends Start`（该类随上游 `af4bc065` 删除）
- 需要自定义启动画面：`override.cfg` 里覆盖 `application/run/main_scene`，并同步本业务 `override.cfg` 片段
- 框架默认逻辑分辨率是 320×180（`display/window/stretch/mode="viewport"`，主题字号 8，字体 Pixel Operator 8）。
  测试台要放下多列按钮，所以用 `Game/MyGame/override.cfg` 把它提到 1280×720；
  改完这个片段要跑一次 `_ToolScript/select_game.sh MyGame` 重新生成根 `Game/override.cfg`
