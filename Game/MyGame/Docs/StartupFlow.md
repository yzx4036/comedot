# 启动链路（Comedot Example）

1. `project.godot`：`config/project_settings_override="res://Game/override.cfg"`
2. `Game/override.cfg` 把 `comedot/settings/comedotProjectSettingsPath` 指向 `res://Game/MyGame/ComedotProjectSettings.tres`
3. `Game/MyGame/ComedotProjectSettings.tres` 的 `mainGameScenePath` = `res://Game/MyGame/Scenes/Levels/MyGameMain.tscn`
4. 运行 → `Scenes/Launch/Logo/IOLogoScene.tscn` → `Scenes/Launch/GameFrame.tscn` → Start → `GameState.startMainScene()` → 本业务可玩场景

## 注意
- 启动脚本用普通 `Control`/`Node2D`，**不要** `extends Start`（该类随上游 `af4bc065` 删除）
- 需要自定义启动画面：`override.cfg` 里覆盖 `application/run/main_scene`，并同步本业务 `override.cfg` 片段
