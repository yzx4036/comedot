extends Node2D

## 一个可玩的关卡：**全部玩法参数来自配置表**，代码里不留可调数值。
##
## 由表驱动的东西：
##   · 敌人数量        ← mygame_tblevel.EnemyCount
##   · 每个敌人血量    ← mygame_tblevel.EnemyHealth
##   · 限时            ← mygame_tblevel.TimeLimit
##   · boss 关表现     ← mygame_tblevel.IsBossStage
##   · 玩家攻击伤害    ← mygame_tbgamesetting.PlayerDamage
##   · 开局金币        ← mygame_tbgamesetting.StartingGold
##
## 开局流程：
##   [method startLevel] 传入关卡 id → 从 [GameConfig] 取定义 → 生成敌人 / 起倒计时
##   点敌人扣血 → 血量归零移除 → 全部清完过关；倒计时归零失败
##
## 验收钩子（回归测试用，也可由外部读状态）：
##   [member spawnedEnemies] / [member killsRemaining] / [member timeRemaining] / [member gold]

const logName: String = "LevelPlay"

const SERVICE_SCRIPT: String = "res://Scripts/Mono/Luban/LubanConfigService.cs"
const CONFIG_DIR: String = "res://Assets/Configs/GameConfigs"
const LEVEL_SELECT_SCENE: String = "res://Game/MyGame/Scenes/Levels/LevelSelect.tscn"

## 敌人在场地内的布局（相对关卡区域的比例），避免写死像素坐标
const ENEMY_AREA_MARGIN: float = 60.0

## HUD 与敌人区域之间的额外留白（血条在方块上方，要给够）
const HUD_CLEARANCE: float = 24.0

## 布局尚未算完时 HUD 的估算高度（4 行小字 + 内边距）
const HUD_FALLBACK_HEIGHT: float = 140.0

## 敌人之间的固定间距（像素）。用固定值而不是按区域均分，横纵间距才一致
const ENEMY_SPACING: Vector2 = Vector2(120.0, 110.0)

## 敌人配色取自 north 调色板。不要用任意的 RGB：LutCanvas 只在调色板内做替换，
## 调色板外的颜色会被吸附到最近色，反而看不出设计意图。
const ENEMY_COLOR: String = "#d8a848"   # gold 族亮端
const BOSS_COLOR: String = "#b85a44"    # 深红族亮端
const HEALTH_FILL_COLOR: String = "#b85a44"  # 深红族亮端：在橄榄棕背景上对比明确


#region 节点

@onready var statusLabel: Label = $UILayer/HUD/Margin/VBox/StatusLabel
@onready var enemiesLabel: Label = $UILayer/HUD/Margin/VBox/EnemiesLabel
@onready var timeLabel: Label = $UILayer/HUD/Margin/VBox/TimeLabel
@onready var goldLabel: Label = $UILayer/HUD/Margin/VBox/GoldLabel
@onready var resultPanel: PanelContainer = $UILayer/ResultPanel
@onready var resultLabel: Label = $UILayer/ResultPanel/ResultBox/ResultLabel
@onready var backButton: Button = $UILayer/ResultPanel/ResultBox/BackButton
@onready var enemyHost: Node2D = $EnemyHost
@onready var shadeRect: ColorRect = $ShadeLayer/ShadeRect

#endregion


#region 明暗层

## LutCanvas 挂在 layer 5：在游戏内容（layer 0）之上、UI（layer 10）之下。
## UI 必须留在上面，否则抗锯齿文字会被量化成调色板色，小字边缘发硬。
func setShadeEnabled(isEnabled: bool) -> void:
	if shadeRect != null:
		shadeRect.visible = isEnabled


func isShadeEnabled() -> bool:
	return shadeRect != null and shadeRect.visible


func getShadeMaterial() -> ShaderMaterial:
	if shadeRect == null:
		return null
	return shadeRect.material as ShaderMaterial

#endregion


#region 状态

var config: GameConfig
var level: LevelDefinition

## 当前存活的敌人（节点 → 血量组件）
var aliveEnemies: Dictionary = {}

## 已生成的敌人总数量（= 表里的 EnemyCount，供验收断言）
var spawnedEnemies: int = 0

## 还需击杀几只（0 = 过关）
var killsRemaining: int = 0

var timeRemaining: float = 0.0
var gold: int = 0
var isPlaying: bool = false
var isFinished: bool = false

## 玩家攻击伤害（来自设置表）
var playerDamage: int = 0

var _hitCount: int = 0

#endregion


#region 生命周期

func _ready() -> void:
	resultPanel.visible = false
	backButton.pressed.connect(_onBackButton_pressed)

	# 自己拉起配置服务：这样本场景单独运行（F6）也能跑，不依赖从 LevelSelect 进来
	var service: Node = _ensureConfigService()
	if service == null:
		return

	config = GameConfig.new(service)
	if not config.isReady():
		statusLabel.text = "配置加载失败：" + config.getErrorMessage()
		return

	playerDamage = config.getSettings().playerDamage
	gold = config.getSettings().startingGold

	# 从关卡选择进来时，关卡 id 记在 GlobalData 里（SceneManager 换了场景树）
	var requestedLevelId: Variant = GameState.getGlobalValue(&"selectedLevelId")
	if requestedLevelId != null:
		startLevel(int(requestedLevelId))
	else:
		statusLabel.text = "等待选关…"
		_updateHud()


## 外部调用：进入某一关。[param levelId] 来自关卡表
func startLevel(levelId: int) -> bool:
	if config == null or not config.isReady():
		return false

	var definition: LevelDefinition = config.findLevel(levelId)
	if definition == null:
		Debug.printError(str("关卡不存在: ", levelId), logName)
		return false

	level = definition
	_clearEnemies()

	spawnedEnemies = 0
	killsRemaining = level.enemyCount
	timeRemaining = level.timeLimit
	isPlaying = true
	isFinished = false
	resultPanel.visible = false

	_spawnEnemies()

	Debug.printLog(str("开始关卡: ", level, " 玩家伤害 ", playerDamage), logName)
	_updateHud()
	return true

#endregion


#region 敌人

## 按表里的 EnemyCount 生成敌人；血量取 EnemyHealth
## 布局用固定间距 + 整体居中：用「铺满区域」算步长会让横纵间距不等、看起来上密下疏
func _spawnEnemies() -> void:
	var area: Rect2 = _getEnemyArea()
	var columns: int = maxi(int(ceil(sqrt(float(level.enemyCount)))), 1)
	var rows: int = maxi(int(ceil(float(level.enemyCount) / float(columns))), 1)

	# 网格整体在区域内居中，而不是拉伸铺满
	var totalWidth: float = float(columns - 1) * ENEMY_SPACING.x
	var totalHeight: float = float(rows - 1) * ENEMY_SPACING.y
	var startX: float = area.position.x + (area.size.x - totalWidth) * 0.5
	var startY: float = area.position.y + (area.size.y - totalHeight) * 0.5

	for index in level.enemyCount:
		var row: int = index / columns
		var column: int = index % columns

		var enemy: Area2D = _createEnemyNode()
		enemy.position = Vector2(
			startX + float(column) * ENEMY_SPACING.x,
			startY + float(row) * ENEMY_SPACING.y
		)
		enemyHost.add_child(enemy)

		var healthComponent: HealthComponent = enemy.get_node("HealthComponent")
		healthComponent.health.max = level.enemyHealth
		healthComponent.health.value = level.enemyHealth
		healthComponent.healthDidZero.connect(_onEnemyDefeated.bind(enemy))

		aliveEnemies[enemy] = healthComponent
		spawnedEnemies += 1

	# boss 关画大一点；只是表现，不影响判定
	if level.isBossStage:
		for enemy: Area2D in aliveEnemies.keys():
			enemy.scale = Vector2(1.25, 1.25)


## 敌人在运行时搭出来：Entity(Area2D) + HealthComponent + 可点区域
## 不用 .tscn 是因为数量由配置表决定，模板写死在场景里反而不好维护
func _createEnemyNode() -> Area2D:
	var enemy: Area2D = Area2D.new()
	enemy.name = "Enemy"
	enemy.input_pickable = true
	enemy.monitorable = false
	enemy.monitoring = false

	# 外观：矩形色块（boss 关用不同颜色）
	var colorRect: ColorRect = ColorRect.new()
	colorRect.color = Color.html(BOSS_COLOR if level.isBossStage else ENEMY_COLOR)
	colorRect.custom_minimum_size = Vector2(48, 48)
	colorRect.position = Vector2(-24, -24)
	colorRect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	enemy.add_child(colorRect)

	# 碰撞形状：点击命中区
	var collider: CollisionShape2D = CollisionShape2D.new()
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(48, 48)
	collider.shape = shape
	enemy.add_child(collider)

	# 血量条（默认样式在深色背景上对比度太低，给个明确的绿→红配色）
	# 配色同样取自调色板：绿族最亮端在 LutCanvas 下会被钳制，颜色稳定不会被压暗
	var healthBar: ProgressBar = ProgressBar.new()
	healthBar.name = "HealthBar"
	healthBar.custom_minimum_size = Vector2(48, 8)
	healthBar.position = Vector2(-24, -36)
	healthBar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	healthBar.show_percentage = false
	healthBar.max_value = level.enemyHealth
	healthBar.value = level.enemyHealth

	var backgroundStyle: StyleBoxFlat = StyleBoxFlat.new()
	backgroundStyle.bg_color = Color.html("#36301f")
	backgroundStyle.border_width_bottom = 1
	backgroundStyle.border_width_top = 1
	backgroundStyle.border_width_left = 1
	backgroundStyle.border_width_right = 1
	backgroundStyle.border_color = Color.html("#14140e")
	healthBar.add_theme_stylebox_override("background", backgroundStyle)

	var fillStyle: StyleBoxFlat = StyleBoxFlat.new()
	fillStyle.bg_color = Color.html(HEALTH_FILL_COLOR)
	healthBar.add_theme_stylebox_override("fill", fillStyle)

	enemy.add_child(healthBar)

	# 用框架的 HealthComponent：证明业务代码能直接复用框架组件
	var healthComponent: HealthComponent = HealthComponent.new()
	healthComponent.name = "HealthComponent"
	var stat: Stat = Stat.new()
	stat.max = level.enemyHealth
	stat.value = level.enemyHealth
	healthComponent.health = stat
	enemy.add_child(healthComponent)

	enemy.input_event.connect(_onEnemyInputEvent.bind(enemy))

	return enemy


func _getEnemyArea() -> Rect2:
	var viewportSize: Vector2 = get_viewport_rect().size

	# 敌人区域必须从 HUD 下方开始，否则第一排的血条会被 HUD 盖住、点击区也会被挡。
	# HUD 高度取决于内容（字号/行数会变）所以运行时量；但布局尚未算完时 size 会是 0，
	# 这时回退到估算值（HUD 4 行文字的实际高度约 140）。
	var hudBottom: float = ENEMY_AREA_MARGIN
	var hud: Control = $UILayer/HUD
	if hud != null:
		var hudHeight: float = hud.size.y
		if hudHeight < 10.0:
			hudHeight = HUD_FALLBACK_HEIGHT
		hudBottom = maxf(hud.position.y + hudHeight, ENEMY_AREA_MARGIN) + HUD_CLEARANCE

	var top: float = hudBottom
	var availableHeight: float = viewportSize.y - top - ENEMY_AREA_MARGIN
	return Rect2(
		Vector2(ENEMY_AREA_MARGIN, top),
		Vector2(
			maxf(viewportSize.x - ENEMY_AREA_MARGIN * 2.0, 100.0),
			maxf(availableHeight, 100.0)
		)
	)


func _clearEnemies() -> void:
	for enemy: Node in aliveEnemies.keys():
		if is_instance_valid(enemy):
			enemy.queue_free()
	aliveEnemies.clear()

#endregion


#region 玩法

func _onEnemyInputEvent(_viewport: Node, event: InputEvent, _shapeIdx: int, enemy: Area2D) -> void:
	if not isPlaying or isFinished:
		return
	if not (event is InputEventMouseButton):
		return
	var mouseEvent: InputEventMouseButton = event
	if not mouseEvent.pressed or mouseEvent.button_index != MOUSE_BUTTON_LEFT:
		return

	_attack(enemy)


## 打一下：伤害来自设置表，不是常量
func _attack(enemy: Area2D) -> void:
	if not aliveEnemies.has(enemy):
		return

	var healthComponent: HealthComponent = aliveEnemies[enemy]
	_hitCount += 1
	healthComponent.damage(playerDamage)

	var healthBar: ProgressBar = enemy.get_node_or_null("HealthBar")
	if healthBar != null:
		healthBar.value = healthComponent.health.value
		healthBar.max_value = healthComponent.health.max

	_updateHud()


func _onEnemyDefeated(enemy: Area2D) -> void:
	aliveEnemies.erase(enemy)
	killsRemaining = maxi(killsRemaining - 1, 0)

	if is_instance_valid(enemy):
		enemy.queue_free()

	_updateHud()

	if killsRemaining <= 0:
		_finishLevel(true)

#endregion


#region 结算

func _finishLevel(didWin: bool) -> void:
	if isFinished:
		return
	isFinished = true
	isPlaying = false
	resultPanel.visible = true

	if didWin:
		resultLabel.text = str("过关！", level.name, "\n点击 ", _hitCount, " 次 · 金币 ", gold)
		Debug.printLog(str("过关: ", level.name, " 点击 ", _hitCount, " 次"), logName)
	else:
		resultLabel.text = str("时间到\n还剩 ", killsRemaining, " 个敌人")
		Debug.printLog(str("失败: ", level.name, " 剩 ", killsRemaining), logName)


func _process(delta: float) -> void:
	if not isPlaying or isFinished:
		return

	timeRemaining -= delta
	if timeRemaining <= 0.0:
		timeRemaining = 0.0
		_finishLevel(false)
	_updateTimeLabel()

#endregion


#region UI

func _updateHud() -> void:
	if level != null:
		statusLabel.text = str(level.name, " · ", level.difficulty,
			" · 每只 ", level.enemyHealth, " 血 / 单击 ", playerDamage, "（",
			level.getHitsToKill(playerDamage), " 击一只）")
	enemiesLabel.text = str("剩余敌人: ", killsRemaining, " / ", spawnedEnemies)
	goldLabel.text = str("金币: ", gold)
	_updateTimeLabel()


func _updateTimeLabel() -> void:
	timeLabel.text = str("剩余时间: ", int(ceil(timeRemaining)), " 秒")

#endregion


#region 信号回调

func _unhandled_input(event: InputEvent) -> void:
	# T 键开关明暗层，方便在真机上直接 A/B 对比
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			setShadeEnabled(not isShadeEnabled())
			Debug.printLog(str("明暗层: ", "开" if isShadeEnabled() else "关"), logName)


func _onBackButton_pressed() -> void:
	# 回关卡选择（不要用 GameState.restart()：那是回框架主菜单）
	var selectScene: PackedScene = load(LEVEL_SELECT_SCENE)
	if selectScene == null:
		Debug.printError(str("无法加载关卡选择场景: ", LEVEL_SELECT_SCENE), logName)
		return
	SceneManager.transitionToScene(selectScene)

#endregion


#region 配置

## 唯一配置服务由 [GameConfigHub] 持有（autoload）。不要自己 new LubanConfigService：
## Luban 表类是 C# 静态单例，第二个实例会报「singleton register twice」。
func _ensureConfigService() -> Node:
	var service: Node = GameConfigHub.getService()
	if service == null:
		Debug.printError("配置表不可用（C# 未编译或表缺失）", logName)
		statusLabel.text = "配置表不可用：先 dotnet build 并生成配置"
		return null
	return service

#endregion
