class_name LevelDefinition
extends RefCounted

## 一个关卡的配置（来自 mygame_tblevel 表的一行）。
## 只装数据，不做 I/O；由 [GameConfig] 从 [Tb] 构造。

## 关卡 id，同时是关卡表的主键
var id: int = 0

## 显示名
var name: String = ""

## 难度枚举名：Easy / Normal / Hard / Nightmare
## 注意：Excel 里填的是别名（如「简单」），Luban 读出来的是枚举名
var difficulty: String = ""

## 这一关要打几只敌人
var enemyCount: int = 0

## 限时（秒）
var timeLimit: float = 0.0

## 是否 boss 关（UI 上做区分）
var isBossStage: bool = false

## 每个敌人的血量；配合 PlayerSettings.playerDamage 决定击杀所需点击次数
var enemyHealth: int = 0


## 击杀一个敌人需要打几次（向上取整）。表里的两个数决定，不在代码里硬编码。
func getHitsToKill(playerDamage: int) -> int:
	if playerDamage <= 0:
		return 0
	return int(ceil(float(enemyHealth) / float(playerDamage)))


## 打穿这一关总共要点多少下（用于 UI 提示与验收断言）
func getTotalHitsRequired(playerDamage: int) -> int:
	return getHitsToKill(playerDamage) * enemyCount


func _to_string() -> String:
	return str("Level(", id, " ", name, " ", difficulty, " ×", enemyCount,
		" hp", enemyHealth, " ", timeLimit, "s", " boss" if isBossStage else "")
