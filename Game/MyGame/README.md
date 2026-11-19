# Comedot Example

单仓模型下的一个**独立游戏业务**，位于 `Game/MyGame/`。

- 自带启动设置：`ComedotProjectSettings.tres`（`mainGameScenePath` 指向本业务首个可玩场景）
- 不引用 `Game/` 下其他业务目录
- 切换到本业务：`_ToolScript/select_game.sh MyGame`
- 本业务专属的额外项目设置（分辨率等）可写在本目录的 `override.cfg`，切换时会被并入根 `Game/override.cfg`
