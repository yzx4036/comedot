class_name PlayerSettings
extends RefCounted

## 全局玩法设置（来自 mygame_tbgamesetting 单例表）。
## 只装数据；由 [GameConfig] 构造。

## 开局金币
var startingGold: int = 0

## 开放到第几关（关卡选择里只显示 id ≤ 它的关卡）
var maxLevel: int = 0

## 玩家每次攻击造成的伤害
var playerDamage: int = 0

## 通关后是否自动存档（当前业务侧只做标记，框架的 GameState.saveGame 仍是 experimental）
var isAutoSave: bool = false
