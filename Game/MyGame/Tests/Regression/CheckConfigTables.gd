extends SceneTree

## Luban 配置表的运行时验收。
##
## 锁住三件容易坏、坏了又很难从日志看出来的事：
##   1. 数据目录：LubanConfigService 的默认值是 res://assets/configs/tables，
##      与实际产物目录 res://Assets/Configs/GameConfigs 不符 ⇒ 必须显式设置
##   2. 字段命名：Tb.row() 返回的字典键是 C# 属性名 PascalCase（Name / SomeLongValue），
##      不是 Excel/JSON 里的 snake_case（name / some_long_value）
##   3. 表形态：有 id 索引表用 row(id)，无 id 的行列表只能用 rows()
##
## 前置：C# 需已编译（dotnet build 或用编辑器打开一次）。未编译时本脚本报 SKIP 而非 FAIL。
## 跑法：Godot --headless --path . --script Game/MyGame/Tests/Regression/CheckConfigTables.gd

const logName: String = "CheckConfigTables"

const SERVICE_SCRIPT: String = "res://Scripts/Mono/Luban/LubanConfigService.cs"

## 配置表产物的真实目录（Luban 的 bin 输出目标）
const CONFIG_DIR: String = "res://Assets/Configs/GameConfigs"

## LubanConfigService 自己的默认值，故意写下来：它与上面的真实目录不一致，是个坑
const SERVICE_DEFAULT_DIR: String = "res://assets/configs/tables"

const TABLE_BASIC: StringName = &"examples_tbexamplebasic"
const TABLE_ADVANCE: StringName = &"examples_tbexampleadvance"
const TABLE_LIST: StringName = &"examples_tbexamplelist"
const TABLE_SINGLETON: StringName = &"examples_tbexamplesingleton"

## 框架自带的示例表数量。运行目录里还会并入业务表（mygame_*），
## 所以断言写成「≥ 这个数且四张框架表都在」，不要精确相等。
const EXPECTED_TABLE_COUNT: int = 4

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

	# C# 未编译时 load 会拿到 null —— 这不是配置表坏了，是环境没准备好
	var script: Script = load(SERVICE_SCRIPT)
	if script == null:
		print("AUTO_RESULT SKIP  C# 未编译（先 dotnet build 或用编辑器打开一次）")
		quit(0)
		return

	_checkProductsExist()
	if not await _loadService():
		_finish()
		return

	_checkTableIndex()
	_checkBasicTable()
	_checkSingletonTable()
	_checkListTable()
	_checkAdvanceTable()
	_checkFieldNamingContract()
	_checkLoaderFacade()

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


#region 前置

## 生成产物必须在盘上（没跑过 gen 脚本时这里先红，比到加载阶段才报错清楚）
func _checkProductsExist() -> void:
	_check(DirAccess.dir_exists_absolute(CONFIG_DIR), "数据目录存在", CONFIG_DIR)

	var expected: PackedStringArray = PackedStringArray([
		str(TABLE_BASIC), str(TABLE_ADVANCE), str(TABLE_LIST), str(TABLE_SINGLETON),
	])
	var missing: PackedStringArray = PackedStringArray()
	for tableName in expected:
		var filePath: String = CONFIG_DIR.path_join(str(tableName, ".bytes"))
		if not FileAccess.file_exists(filePath):
			missing.append(filePath)
	_check(missing.is_empty(), "四张示例表的 bytes 都在", "缺 " + str(missing.size()))
	for path in missing:
		print("      缺失: ", path)


func _loadService() -> bool:
	var script: Script = load(SERVICE_SCRIPT)
	service = script.new()
	# 必须显式设目录：默认值指向别处，不设就加载不到
	service.ConfigDirectory = CONFIG_DIR
	service.LoadOnReady = false
	root.add_child(service)
	await process_frame

	var isLoaded: bool = service.LoadConfigs()
	_check(isLoaded, "LoadConfigs 成功", service.ConfigDirectory)
	if not isLoaded:
		return false

	_check(service.IsLoaded, "IsLoaded 为真")
	tb = Tb.new(service)
	return true

#endregion


#region 各表形态

func _checkTableIndex() -> void:
	var names: Array = service.GetConfigNames()
	# 不要写成 names.size() == 4：运行目录里还有业务表，总数会更多
	_check(names.size() >= EXPECTED_TABLE_COUNT, "框架示例表齐全（总数含业务表）", str(names.size()))
	for tableName in [str(TABLE_BASIC), str(TABLE_ADVANCE), str(TABLE_LIST), str(TABLE_SINGLETON)]:
		_check(names.has(tableName), "表已注册", tableName)


func _checkBasicTable() -> void:
	_check(tb.has(TABLE_BASIC), "has() 认识 basic 表")
	_check(tb.mode(TABLE_BASIC) == "map", "basic 表是按 id 索引的 map 表", tb.mode(TABLE_BASIC))

	var rowCount: int = tb.rows(TABLE_BASIC).size()
	_check(rowCount > 0, "basic 表有记录", str(rowCount))

	var row: Dictionary = tb.row(TABLE_BASIC, 1001)
	_check(not row.is_empty(), "按 id 1001 取到记录")
	if row.is_empty():
		return

	_check(str(row.get("Name", "")) == "瓶盖", "中文值正确", str(row.get("Name", "")))
	_check(tb.hasId(TABLE_BASIC, 1001), "hasId(1001) 为真")
	_check(not tb.hasId(TABLE_BASIC, 999999), "hasId(999999) 为假")

	# 枚举在 GDScript 侧被转成字符串，不是数字
	var enumValue: Variant = tb.val(TABLE_BASIC, 1001, &"Type")
	_check(enumValue is String, "枚举转成字符串", str(enumValue))

	var checkResult: Dictionary = tb.check(TABLE_BASIC, 1001)
	_check(checkResult.get("isValid", false), "check() 校验通过", str(checkResult))


func _checkSingletonTable() -> void:
	_check(tb.has(TABLE_SINGLETON), "has() 认识 singleton 表")
	_check(tb.mode(TABLE_SINGLETON) == "one", "singleton 是单例表", tb.mode(TABLE_SINGLETON))

	var one: Dictionary = tb.one(TABLE_SINGLETON)
	_check(not one.is_empty(), "one() 取到单例内容", str(one.keys()))
	var discount: Variant = tb.oneVal(TABLE_SINGLETON, &"NewbieDiscountTimes")
	_check(discount != null, "oneVal 取到字段", str(discount))


func _checkListTable() -> void:
	_check(tb.mode(TABLE_LIST) == "list", "list 是行列表表", tb.mode(TABLE_LIST))
	var listRows: Array = tb.rows(TABLE_LIST)
	_check(listRows.size() > 1, "rows() 拿到多条", str(listRows.size()))
	if listRows.is_empty():
		return
	var first: Dictionary = listRows[0]
	_check(first.has("Name"), "行里有 PascalCase 字段", str(first.keys()))


func _checkAdvanceTable() -> void:
	_check(tb.mode(TABLE_ADVANCE) == "list", "advance 是行列表表（无 id）", tb.mode(TABLE_ADVANCE))

	# 坑：无 id 表不能用 row(id)。这里只按 mode 判断，不去实际调用 row(advance, 1001)——
	# 那会往 stderr 打一条 "has no DataMap" 的 ERROR，虽是预期行为，但会淹没以后的真错误。
	var advanceRows: Array = tb.rows(TABLE_ADVANCE)
	_check(advanceRows.size() > 0, "advance rows() 有内容", str(advanceRows.size()))
	if advanceRows.is_empty():
		return

	var row0: Dictionary = advanceRows[0]
	_check(row0.has("SomeArray1"), "嵌套数组字段存在", str(row0.keys()))
	var beanList: Variant = row0.get("SomeBeanList")
	_check(beanList is Array and (beanList as Array).size() > 0, "嵌套 bean 列表可用",
		str((beanList as Array).size()) if beanList is Array else "非数组")

#endregion


#region 字段命名契约

## 把「字典键是 PascalCase」这件事锁成断言：哪天 C# 侧改了序列化策略，这里会红
func _checkFieldNamingContract() -> void:
	var row: Dictionary = tb.row(TABLE_BASIC, 1001)
	if row.is_empty():
		_check(false, "字段命名契约（取不到记录，跳过）")
		return

	# 直接看键长什么样，不靠「用 snake_case 探一次」——后者会打一条 Field not found 的
	# ERROR 到 stderr，虽是预期行为，但会让真错误淹没在噪音里
	var snakeKeys: PackedStringArray = PackedStringArray()
	for key: Variant in row.keys():
		if str(key).contains("_"):
			snakeKeys.append(str(key))
	_check(snakeKeys.is_empty(), "字典键全是 PascalCase（无下划线）", str(row.keys()))

	_check(tb.val(TABLE_BASIC, 1001, &"Name") != null, "PascalCase 字段可取值")
	# val() 对大小写不敏感，所以小写同名字段也能拿到
	_check(tb.val(TABLE_BASIC, 1001, &"name") != null, "小写同名字段也可取值（val 忽略大小写）")
	_check(tb.val(TABLE_BASIC, 1001, &"SomeLongValue") != null, "PascalCase 多词字段可取值")

#endregion


#region 门面

func _checkLoaderFacade() -> void:
	var allRows: Array = LubanLoader.loadAll(tb, TABLE_BASIC,
		func(row: Dictionary) -> Variant: return row)
	_check(allRows.size() > 0, "LubanLoader.loadAll 可用", str(allRows.size()))

	var first: Variant = LubanLoader.loadFirst(tb, TABLE_BASIC, 1001,
		func(row: Dictionary) -> Variant: return row)
	_check(first != null, "LubanLoader.loadFirst 可用")

	var filtered: Array = LubanLoader.filter(allRows,
		func(item: Variant) -> bool: return (item as Dictionary).get("Grade", 0) == 1)
	_check(filtered.size() > 0, "LubanLoader.filter 可用", str(filtered.size()))

	# 分组用 PascalCase 键；用错大小写会全部落到默认分组
	var grouped: Dictionary = LubanLoader.loadGrouped(tb, TABLE_BASIC,
		func(row: Dictionary) -> Variant: return row,
		func(item: Dictionary) -> Variant: return item.get("Grade", -1))
	_check(not grouped.has(-1), "分组键取到 Grade（不是 -1）", str(grouped.keys()))

#endregion
