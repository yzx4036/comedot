extends SceneTree

## 业务配置表（MyGame 自己维护的 Luban 表）的运行时验收。
##
## 与 CheckConfigTables.gd 的分工：
##   CheckConfigTables    → 框架自带示例表（examples_*），验通用能力
##   CheckBusinessConfigTables → 业务表（mygame_*），验「业务侧配置表真能用」
##
## 锁住的四件事（都是实测踩出来的）：
##   1. 业务表与框架表必须由**同一个** ConfigMgr 加载 ⇒ 运行目录共处一地
##   2. 业务的 map 表按 id 索引，one 表只有一条
##   3. 枚举字段：Excel 里填别名（如「简单」），运行时读到的是**枚举名**（"Easy"）
##   4. 字段键为 PascalCase
##
## 前置：跑过 _ConfigTables/gen_all_configs.sh（它把业务 .bytes 合并进运行目录）
## 跑法：Godot --headless --path . --script Game/MyGame/Tests/Regression/CheckBusinessConfigTables.gd

const logName: String = "CheckBusinessConfigTables"

const SERVICE_SCRIPT: String = "res://Scripts/Mono/Luban/LubanConfigService.cs"
const CONFIG_DIR: String = "res://Assets/Configs/GameConfigs"

# 业务表（表名 = <模块小写>_<表类名小写>）
const TABLE_LEVEL: StringName = &"mygame_tblevel"
const TABLE_SETTING: StringName = &"mygame_tbgamesetting"

# 框架表：用来证明两类表能共存于同一个 ConfigMgr
const TABLE_FRAMEWORK: StringName = &"examples_tbexamplebasic"

const EXPECTED_LEVEL_COUNT: int = 4
const EXPECTED_STARTING_GOLD: int = 100

var failures: PackedStringArray = PackedStringArray()
var service: Node
var tb: Tb


func _initialize() -> void:
	_run()


func _check(condition: bool, label: String, detail: String = "") -> void:
	var suffix: String = ("  (" + detail + ")") if not detail.is_empty() else ""
	if condition:
		print("PASS  ", label, suffix)
		return
	failures.append(label)
	print("FAIL  ", label, suffix)


func _run() -> void:
	await process_frame

	var script: Script = load(SERVICE_SCRIPT)
	if script == null:
		print("AUTO_RESULT SKIP  C# 未编译（先 dotnet build）")
		quit(0)
		return

	# 产物存在性先查，缺了能一眼看出是没生成还是加载出问题
	_check(FileAccess.file_exists(CONFIG_DIR.path_join(str(TABLE_LEVEL, ".bytes"))),
		"业务表 .bytes 已生成", str(TABLE_LEVEL))
	_check(FileAccess.file_exists(CONFIG_DIR.path_join(str(TABLE_SETTING, ".bytes"))),
		"业务单例表 .bytes 已生成", str(TABLE_SETTING))

	if not await _loadService():
		_finish()
		return

	_checkTableRegistration()
	_checkLevelTable()
	_checkSingletonTable()
	_checkEnumBehaviour()

	service.UnloadConfigs()
	_finish()


func _finish() -> void:
	print("")
	if failures.is_empty():
		print("AUTO_RESULT PASS  0 项失败")
		quit(0)
		return
	print("AUTO_RESULT FAIL  ", failures.size(), " 项失败")
	for item in failures:
		print("   - ", item)
	quit(1)


func _loadService() -> bool:
	var script: Script = load(SERVICE_SCRIPT)
	service = script.new()
	service.ConfigDirectory = CONFIG_DIR
	service.LoadOnReady = false
	root.add_child(service)
	await process_frame

	var isLoaded: bool = service.LoadConfigs()
	_check(isLoaded, "ConfigMgr 加载成功（框架表与业务表共存）", CONFIG_DIR)
	if not isLoaded:
		return false

	tb = Tb.new(service)
	return true


#region 表的注册与共存

## 这是本文件最重要的断言：一个 ConfigMgr 同时拿到框架表和业务表，
## 说明业务表的 C# 表类确实进了框架程序集，且命名空间前缀对得上
func _checkTableRegistration() -> void:
	var names: Array = service.GetConfigNames()
	_check(names.has(str(TABLE_LEVEL)), "业务 map 表已注册", str(TABLE_LEVEL))
	_check(names.has(str(TABLE_SETTING)), "业务单例表已注册", str(TABLE_SETTING))
	_check(names.has(str(TABLE_FRAMEWORK)), "框架表同时也在（共存）", str(TABLE_FRAMEWORK))
	_check(names.size() >= 6, "表总数 ≥ 6（4 框架 + 2 业务）", str(names.size()))

#endregion


#region 数据内容

func _checkLevelTable() -> void:
	_check(tb.has(TABLE_LEVEL), "has() 认识业务表")
	_check(tb.mode(TABLE_LEVEL) == "map", "业务关卡表是 map 表", tb.mode(TABLE_LEVEL))

	var allRows: Array = tb.rows(TABLE_LEVEL)
	_check(allRows.size() == EXPECTED_LEVEL_COUNT, "关卡数量",
		str(allRows.size()) + " / 期望 " + str(EXPECTED_LEVEL_COUNT))

	var level1: Dictionary = tb.row(TABLE_LEVEL, 1)
	_check(not level1.is_empty(), "按 id 取到关卡 1")
	if level1.is_empty():
		return

	_check(str(level1.get("Name", "")) == "新手村", "中文关卡名正确", str(level1.get("Name")))
	_check(int(level1.get("EnemyCount", -1)) == 5, "整数字段正确",
		str(level1.get("EnemyCount")))
	_check(is_equal_approx(float(level1.get("TimeLimit", -1.0)), 120.0), "浮点字段正确",
		str(level1.get("TimeLimit")))
	_check(level1.get("IsBossStage") == false, "布尔字段正确", str(level1.get("IsBossStage")))

	# 高难度关卡的 boss 标记
	var bossLevel: Dictionary = tb.row(TABLE_LEVEL, 4)
	_check(bossLevel.get("IsBossStage") == true, "关卡 4 是 boss 关",
		str(bossLevel.get("IsBossStage")))

	# 不存在的 id：用 hasId 判断，**不要**调 tb.row(9999)
	# —— 后者会往 stderr 打 "record not found" 的 ERROR，虽是预期行为但会淹没真错误
	_check(not tb.hasId(TABLE_LEVEL, 9999), "hasId(9999) 为假")


func _checkSingletonTable() -> void:
	_check(tb.mode(TABLE_SETTING) == "one", "业务设置表是单例表", tb.mode(TABLE_SETTING))

	var one: Dictionary = tb.one(TABLE_SETTING)
	_check(not one.is_empty(), "one() 取到设置", str(one.keys()))

	var gold: Variant = tb.oneVal(TABLE_SETTING, &"StartingGold")
	_check(gold != null and int(gold) == EXPECTED_STARTING_GOLD, "开局金币",
		str(gold))

	# 纵表里 bool 字段
	var autoSave: Variant = tb.oneVal(TABLE_SETTING, &"AutoSave")
	_check(autoSave is bool and autoSave == true, "布尔设置正确", str(autoSave))

#endregion


#region 枚举行为

## Excel 里填的是别名「简单」，运行时拿到的是枚举名 "Easy"。
## 这条锁住：改 Excel 用别名、代码里比枚举名。写错任一侧这里都会红。
func _checkEnumBehaviour() -> void:
	var difficulty: Variant = tb.val(TABLE_LEVEL, 1, &"Difficulty")
	_check(difficulty is String, "枚举转成字符串", str(difficulty))
	_check(str(difficulty) == "Easy", "Excel 别名「简单」→ 运行时可读枚举名 \"Easy\"", str(difficulty))

	# 换一关确认不是恒等值
	var nightmare: Variant = tb.val(TABLE_LEVEL, 4, &"Difficulty")
	_check(str(nightmare) == "Nightmare", "关卡 4 难度为 Nightmare", str(nightmare))

#endregion
