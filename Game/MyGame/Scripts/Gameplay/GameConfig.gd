class_name GameConfig
extends RefCounted

## 业务配置表的运行时门面。
##
## 把 [Tb] 返回的字典（键是 PascalCase）转成强类型对象，并在缺表/缺字段时给出
## 明确指出「哪张表哪个字段」的错误，而不是让调用方拿到 null 后自己猜。
##
## 用法：
##   var config := GameConfig.new(lubanConfigService)   # service 是 LubanConfigService 节点
##   if not config.isReady():
##       return                                        # 错误已经在加载时打印
##   for level in config.getLevels():
##       print(level.name, " × ", level.enemyCount)
##
## 数据来源（改 Excel 后跑 _ConfigTables/gen_all_configs.sh 即生效）：
##   mygame_tblevel      → [LevelDefinition] 数组
##   mygame_tbgamesetting → [PlayerSettings] 单例


#region 常量

const logName: String = "GameConfig"

const TABLE_LEVEL: StringName = &"mygame_tblevel"
const TABLE_SETTING: StringName = &"mygame_tbgamesetting"

## 关卡表必须有的字段。缺任何一个都说明 Excel 表头被改坏了。
## NOTE: const 里不能用 PackedStringArray([...]) 构造（不是常量表达式），用数组字面量
const REQUIRED_LEVEL_FIELDS: Array = [
	"Id", "Name", "Difficulty", "EnemyCount", "TimeLimit", "IsBossStage", "EnemyHealth",
]

## 设置表必须有的字段
const REQUIRED_SETTING_FIELDS: Array = [
	"StartingGold", "MaxLevel", "PlayerDamage",
]

#endregion


#region 状态

var _tb: Tb
var _levels: Array[LevelDefinition] = []
var _settings: PlayerSettings
var _isReady: bool = false
var _errorMessage: String = ""

#endregion


func _init(configService: Node = null) -> void:
	if configService == null:
		_setError("没有传入 LubanConfigService 节点")
		return

	_tb = Tb.new(configService)

	# 注意：IsLoaded 是 C# 的**属性**，不是方法 —— 不能用 has_method("IsLoaded") 检查，
	# 那恒返回 false 会把「已加载」误判成「未加载」。
	# 属性不存在时（C# 未编译）访问会直接报错，所以先用 signals/property 列表兜一层。
	if not ("IsLoaded" in configService):
		_setError("LubanConfigService 缺少 IsLoaded 属性（C# 是否未编译？）")
		return
	if not configService.IsLoaded:
		_setError("LubanConfigService 尚未加载配置表")
		return

	_loadSettings()
	if _errorMessage.is_empty():
		_loadLevels()


#region 加载

func _loadSettings() -> void:
	if not _tb.has(TABLE_SETTING):
		_setError(str("缺少配置表: ", TABLE_SETTING, "（跑 _ConfigTables/gen_all_configs.sh）"))
		return

	var row: Dictionary = _tb.one(TABLE_SETTING)
	if row.is_empty():
		_setError(str("配置表 ", TABLE_SETTING, " 没有数据行"))
		return

	var missingField: String = _findMissingField(row, REQUIRED_SETTING_FIELDS)
	if not missingField.is_empty():
		_setError(str("配置表 ", TABLE_SETTING, " 缺字段: ", missingField))
		return

	_settings = PlayerSettings.new()
	_settings.startingGold = int(row["StartingGold"])
	_settings.maxLevel = int(row["MaxLevel"])
	_settings.playerDamage = int(row["PlayerDamage"])
	_settings.isAutoSave = bool(row.get("AutoSave", false))


func _loadLevels() -> void:
	if not _tb.has(TABLE_LEVEL):
		_setError(str("缺少配置表: ", TABLE_LEVEL, "（跑 _ConfigTables/gen_all_configs.sh）"))
		return

	var rows: Array = _tb.rows(TABLE_LEVEL)
	if rows.is_empty():
		_setError(str("配置表 ", TABLE_LEVEL, " 没有任何记录"))
		return

	for row: Dictionary in rows:
		var missingField: String = _findMissingField(row, REQUIRED_LEVEL_FIELDS)
		if not missingField.is_empty():
			_setError(str("配置表 ", TABLE_LEVEL, " 的记录 ", row.get("Id", "?"), " 缺字段: ", missingField))
			return

		var level: LevelDefinition = LevelDefinition.new()
		level.id = int(row["Id"])
		level.name = str(row["Name"])
		level.difficulty = str(row["Difficulty"])
		level.enemyCount = int(row["EnemyCount"])
		level.timeLimit = float(row["TimeLimit"])
		level.isBossStage = bool(row["IsBossStage"])
		level.enemyHealth = int(row["EnemyHealth"])
		_levels.append(level)

	_levels.sort_custom(func(a: LevelDefinition, b: LevelDefinition) -> bool: return a.id < b.id)

	# 数据自洽性：表里写错了要在这里就报出来，别等到玩起来才发现
	_validateData()

	_isReady = true
	Debug.printLog(str("游戏配置就绪: ", _levels.size(), " 关，玩家伤害 ", _settings.playerDamage), logName)


## 跨表/跨字段的一致性检查。这些是「表能填、但填了就出 bug」的情况
func _validateData() -> void:
	for level: LevelDefinition in _levels:
		if level.enemyHealth <= 0:
			_setError(str("关卡 ", level.id, " 的 EnemyHealth 必须 > 0（当前 ", level.enemyHealth, "）"))
			return
		if level.enemyCount <= 0:
			_setError(str("关卡 ", level.id, " 的 EnemyCount 必须 > 0（当前 ", level.enemyCount, "）"))
			return
		if level.timeLimit <= 0.0:
			_setError(str("关卡 ", level.id, " 的 TimeLimit 必须 > 0（当前 ", level.timeLimit, "）"))
			return

	if _settings.playerDamage <= 0:
		_setError(str("设置表的 PlayerDamage 必须 > 0（当前 ", _settings.playerDamage, "）"))
		return

	if _settings.maxLevel <= 0:
		_setError(str("设置表的 MaxLevel 必须 > 0（当前 ", _settings.maxLevel, "）"))
		return

	# MaxLevel 说能玩到第几关，但关卡表里没有那么多关 ⇒ 玩家会看到「选了进不去」
	var highestId: int = _levels[_levels.size() - 1].id
	if _settings.maxLevel > highestId:
		_setError(str("MaxLevel=", _settings.maxLevel, " 超过关卡表最大 id=", highestId, "（关卡表只有 ",
			_levels.size(), " 关）"))
		return

#endregion


#region 查询

func isReady() -> bool:
	return _isReady


func getErrorMessage() -> String:
	return _errorMessage


func getLevels() -> Array[LevelDefinition]:
	return _levels


## 按 MaxLevel 筛出玩家实际能选的关卡（表驱动「开放到第几关」）
func getUnlockedLevels() -> Array[LevelDefinition]:
	var unlocked: Array[LevelDefinition] = []
	for level: LevelDefinition in _levels:
		if level.id <= _settings.maxLevel:
			unlocked.append(level)
	return unlocked


## 按 id 查关卡；找不到返回 null（调用方必须判空）
func findLevel(levelId: int) -> LevelDefinition:
	for level: LevelDefinition in _levels:
		if level.id == levelId:
			return level
	return null


func getSettings() -> PlayerSettings:
	return _settings

#endregion


#region 内部

func _findMissingField(row: Dictionary, requiredFields: Array) -> String:
	for fieldName in requiredFields:
		if not row.has(fieldName):
			return fieldName
	return ""


func _setError(message: String) -> void:
	_errorMessage = message
	_isReady = false
	Debug.printError(str("游戏配置加载失败: ", message), logName)

#endregion
