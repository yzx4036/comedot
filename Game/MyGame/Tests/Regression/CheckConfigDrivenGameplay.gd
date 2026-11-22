extends Node

## 配置表驱动玩法的验收：证明「表里的数」真的决定「游戏里的行为」。
##
## ⚠️ 本检查必须用**场景**方式跑（`Godot --headless --path . <场景路径>`），不能用 `--script`：
##   被测代码 path 上会碰框架的 `HealthComponent` / `Stat`，它们内部引用 `GameState` 这个
##   autoload 全局名。`--script` 模式在 autoload 注册**之前**编译脚本 ⇒ 报
##   `Identifier not found: GameState`，整个依赖链编译失败。
##
## 设计要点：期望值全部**当场从配置表读**，不在测试里写死。
##   · 表里 EnemyCount=5 → 游戏里必须真的生成 5 个敌人节点
##   · 表里 EnemyHealth=20、PlayerDamage=10 → 第 2 次攻击必须打死，第 1 次不能
## 改 Excel 后重跑，断言自动跟着新值走；若代码改用硬编码，这里会立刻红。
##
## 另有一组「快照」硬编码断言，锁住当前表内容 —— 表被误改时能马上发现。

const SERVICE_SCRIPT: String = "res://Scripts/Mono/Luban/LubanConfigService.cs"
const CONFIG_DIR: String = "res://Assets/Configs/GameConfigs"
const LEVEL_SELECT_SCENE: String = "res://Game/MyGame/Scenes/Levels/LevelSelect.tscn"
const LEVEL_PLAY_SCENE: String = "res://Game/MyGame/Scenes/Levels/LevelPlay.tscn"

const TABLE_LEVEL: StringName = &"mygame_tblevel"
const TABLE_SETTING: StringName = &"mygame_tbgamesetting"

## 表快照：改了 Excel 就该同步这里，否则本项会红（这是设计，不是麻烦）
const SNAPSHOT_LEVEL_IDS: Array = [1, 2, 3, 4]
const SNAPSHOT_ENEMY_COUNTS: Array = [5, 12, 20, 35]
const SNAPSHOT_ENEMY_HEALTH: Array = [20, 40, 70, 240]
const SNAPSHOT_PLAYER_DAMAGE: int = 10
const SNAPSHOT_STARTING_GOLD: int = 100

var failures: PackedStringArray = PackedStringArray()
var tb: Tb
var service: Node


func _ready() -> void:
	await _run()


func _check(condition: bool, label: String, detail: String = "") -> void:
	var suffix: String = ("  (" + detail + ")") if not detail.is_empty() else ""
	if condition:
		print("PASS  ", label, suffix)
		return
	failures.append(label)
	print("FAIL  ", label, suffix)


func _run() -> void:
	await get_tree().process_frame

	# 必须复用 autoload 持有的唯一实例：Luban 表类是 C# 静态单例，
	# 自己再 new 一个会报「singleton register twice」并让整个 ConfigMgr 加载失败
	service = GameConfigHub.getService()
	if service == null:
		print("AUTO_RESULT SKIP  配置表不可用（C# 未编译 或 未跑 gen_all_configs.sh）")
		get_tree().quit(0)
		return
	tb = Tb.new(service)

	_checkSnapshot()
	await _checkLevelSelect()
	await _checkGameplayMatchesTable()
	await _checkHitCountIsDrivenByTable()
	await _checkTimeoutFail()

	_finish()


func _finish() -> void:
	print("")
	if failures.is_empty():
		print("AUTO_RESULT PASS  0 项失败")
		get_tree().quit(0)
		return
	print("AUTO_RESULT FAIL  ", failures.size(), " 项失败")
	for item in failures:
		print("   - ", item)
	get_tree().quit(1)


#region 表快照

func _checkSnapshot() -> void:
	print("\n── 表内容快照 ──")
	var rows: Array = tb.rows(TABLE_LEVEL)
	_check(rows.size() == SNAPSHOT_LEVEL_IDS.size(), "关卡行数", str(rows.size()))

	for index in rows.size():
		var row: Dictionary = rows[index]
		_check(int(row["Id"]) == SNAPSHOT_LEVEL_IDS[index], "关卡 id", str(row["Id"]))
		_check(int(row["EnemyCount"]) == SNAPSHOT_ENEMY_COUNTS[index], "敌人数",
			str(row["EnemyCount"]))
		_check(int(row["EnemyHealth"]) == SNAPSHOT_ENEMY_HEALTH[index], "敌人血量",
			str(row["EnemyHealth"]))

	var settings: Dictionary = tb.one(TABLE_SETTING)
	_check(int(settings["PlayerDamage"]) == SNAPSHOT_PLAYER_DAMAGE, "玩家伤害",
		str(settings["PlayerDamage"]))
	_check(int(settings["StartingGold"]) == SNAPSHOT_STARTING_GOLD, "开局金币",
		str(settings["StartingGold"]))

#endregion


#region 关卡选择：UI 结构由表决定

func _checkLevelSelect() -> void:
	print("\n── 关卡选择由表驱动 ──")
	var scene: PackedScene = load(LEVEL_SELECT_SCENE)
	_check(scene != null, "关卡选择场景可加载")
	if scene == null:
		return

	var selectNode: Node = scene.instantiate()
	add_child(selectNode)
	await _waitFrames(3)

	_check(selectNode.config != null and selectNode.config.isReady(), "关卡选择的配置就绪")

	var expectedUnlocked: int = mini(
		int(tb.one(TABLE_SETTING)["MaxLevel"]),
		tb.rows(TABLE_LEVEL).size()
	)
	var buttonCount: int = selectNode.levelButtons.size()
	_check(buttonCount == expectedUnlocked, "按钮数量 == 表里开放的关卡数",
		str(buttonCount) + " / 期望 " + str(expectedUnlocked))

	# 按钮文字必须含表里的关卡名 ⇒ 证明内容来自表而不是写死
	var missingNames: PackedStringArray = PackedStringArray()
	for row: Dictionary in tb.rows(TABLE_LEVEL):
		var levelId: int = int(row["Id"])
		if not selectNode.levelButtons.has(levelId):
			continue
		var button: Button = selectNode.levelButtons[levelId]
		if not button.text.contains(str(row["Name"])):
			missingNames.append(str(levelId, ":", row["Name"]))
	_check(missingNames.is_empty(), "按钮文字含表里的关卡名", str(missingNames))

	# tooltip 里的「每只几击」应与表算出来的一致
	var level1Row: Dictionary = tb.row(TABLE_LEVEL, 1)
	var expectedHits: int = int(ceil(float(level1Row["EnemyHealth"]) / float(SNAPSHOT_PLAYER_DAMAGE)))
	var level1Button: Button = selectNode.levelButtons.get(1)
	if level1Button != null:
		_check(level1Button.tooltip_text.contains(str(expectedHits, " 击")),
			"tooltip 里每只击杀次数与表一致", str(expectedHits, " 击"))

	selectNode.queue_free()
	await _waitFrames(2)

#endregion


#region 玩法参数来自表

func _checkGameplayMatchesTable() -> void:
	print("\n── 关卡生成由表驱动 ──")
	var scene: PackedScene = load(LEVEL_PLAY_SCENE)
	_check(scene != null, "关卡场景可加载")
	if scene == null:
		return

	var playNode: Node = scene.instantiate()
	add_child(playNode)
	await _waitFrames(3)

	for row: Dictionary in tb.rows(TABLE_LEVEL):
		var levelId: int = int(row["Id"])
		var expectedEnemyCount: int = int(row["EnemyCount"])
		var expectedHealth: int = int(row["EnemyHealth"])
		var expectedTime: float = float(row["TimeLimit"])

		var didStart: bool = playNode.startLevel(levelId)
		_check(didStart, str("关卡 ", levelId, " 能开始"))
		if not didStart:
			continue

		await _waitFrames(2)

		# 1) 真的生成了那么多敌人节点（不是只记了个数）
		var spawnedNodes: int = playNode.enemyHost.get_child_count()
		_check(spawnedNodes == expectedEnemyCount,
			str("关卡 ", levelId, " 敌人节点数 == 表 EnemyCount"),
			str(spawnedNodes, " / ", expectedEnemyCount))
		_check(playNode.spawnedEnemies == expectedEnemyCount,
			str("关卡 ", levelId, " spawnedEnemies 计数"),
			str(playNode.spawnedEnemies))

		# 2) 每个敌人血量上限 == 表 EnemyHealth
		var wrongHealth: int = 0
		for enemy: Node in playNode.aliveEnemies.keys():
			var healthComponent: HealthComponent = playNode.aliveEnemies[enemy]
			if healthComponent.health.max != expectedHealth:
				wrongHealth += 1
		_check(wrongHealth == 0, str("关卡 ", levelId, " 敌人血量上限 == 表 EnemyHealth"),
			str(wrongHealth, " 个不符"))

		# 3) 倒计时初值 == 表 TimeLimit（跑了若干帧，所以只要求不超过初值且接近）
		_check(playNode.timeRemaining <= expectedTime and playNode.timeRemaining > expectedTime - 2.0,
			str("关卡 ", levelId, " 倒计时 ≈ 表 TimeLimit"),
			str(snapped(playNode.timeRemaining, 0.01), " / ", expectedTime))

		# 4) 玩家伤害 == 设置表 PlayerDamage
		_check(playNode.playerDamage == SNAPSHOT_PLAYER_DAMAGE,
			str("关卡 ", levelId, " 玩家伤害 == 设置表"), str(playNode.playerDamage))

	playNode.queue_free()
	await _waitFrames(2)

#endregion


#region 击杀次数由表决定

func _checkHitCountIsDrivenByTable() -> void:
	print("\n── 击杀次数由表决定 ──")
	var scene: PackedScene = load(LEVEL_PLAY_SCENE)
	if scene == null:
		return

	var playNode: Node = scene.instantiate()
	add_child(playNode)
	await _waitFrames(3)

	var row: Dictionary = tb.row(TABLE_LEVEL, 1)
	var enemyHealth: int = int(row["EnemyHealth"])
	var playerDamage: int = int(tb.one(TABLE_SETTING)["PlayerDamage"])
	var expectedHits: int = int(ceil(float(enemyHealth) / float(playerDamage)))

	playNode.startLevel(1)
	await _waitFrames(2)

	var firstEnemy: Area2D = null
	for enemy: Area2D in playNode.aliveEnemies.keys():
		firstEnemy = enemy
		break
	_check(firstEnemy != null, "取到第一个敌人")
	if firstEnemy == null:
		playNode.queue_free()
		return

	var initialKills: int = playNode.killsRemaining

	# 打 expectedHits - 1 次：必须还活着
	for i in expectedHits - 1:
		playNode._attack(firstEnemy)
	await _waitFrames(2)
	_check(playNode.aliveEnemies.has(firstEnemy), "打 " + str(expectedHits - 1) + " 次后敌人还活着")
	_check(playNode.killsRemaining == initialKills, "计数未提前减少", str(playNode.killsRemaining))

	# 再打 1 次：正好打死
	playNode._attack(firstEnemy)
	await _waitFrames(2)
	_check(not playNode.aliveEnemies.has(firstEnemy),
		str("第 ", expectedHits, " 次攻击正好击杀（", enemyHealth, "/", playerDamage, "）"))
	_check(playNode.killsRemaining == initialKills - 1, "击杀计数减 1",
		str(playNode.killsRemaining))

	# 全部击杀 ⇒ 过关
	var guard: int = 0
	while playNode.killsRemaining > 0 and guard < 10000:
		var target: Area2D = null
		for enemy: Area2D in playNode.aliveEnemies.keys():
			target = enemy
			break
		if target == null:
			break
		playNode._attack(target)
		guard += 1
	await _waitFrames(3)
	_check(playNode.killsRemaining == 0, "清完所有敌人", str(playNode.killsRemaining))
	_check(playNode.isFinished and playNode.isPlaying == false, "通关后停止计时")
	_check(playNode.resultPanel.visible, "通关后显示结算面板")

	playNode.queue_free()
	await _waitFrames(2)

#endregion


#region 超时失败

func _checkTimeoutFail() -> void:
	print("\n── 超时判定 ──")
	var scene: PackedScene = load(LEVEL_PLAY_SCENE)
	if scene == null:
		return

	var playNode: Node = scene.instantiate()
	add_child(playNode)
	await _waitFrames(3)

	playNode.startLevel(1)
	await _waitFrames(2)

	# 把时间压到 0 模拟超时（不真等 120 秒）
	playNode.timeRemaining = 0.0
	await _waitFrames(3)

	_check(playNode.isFinished, "超时后关卡结束")
	_check(playNode.isPlaying == false, "超时后停止计时")
	_check(playNode.killsRemaining > 0, "超时时仍有剩余敌人", str(playNode.killsRemaining))
	_check(playNode.resultPanel.visible, "超时后显示结算面板")

	playNode.queue_free()
	await _waitFrames(2)

#endregion


func _waitFrames(count: int) -> void:
	for _i in count:
		await get_tree().process_frame
