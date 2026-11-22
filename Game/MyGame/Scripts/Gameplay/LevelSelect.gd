extends Node2D

## 关卡选择：**关卡列表完全由配置表生成**，不在代码里写死任何关卡。
##
## 表驱动的东西：
##   · 有哪些关卡、叫什么、多难     ← mygame_tblevel 的行
##   · 开放到第几关                ← mygame_tbgamesetting.MaxLevel
##   · 每关显示「几只 × 几血」     ← EnemyCount / EnemyHealth
##   · 开局金币提示                ← StartingGold
##
## 改 Excel → gen_all_configs.sh → 重开场景，这里的按钮数量与文字就跟着变。

const logName: String = "LevelSelect"

const SERVICE_SCRIPT: String = "res://Scripts/Mono/Luban/LubanConfigService.cs"
const CONFIG_DIR: String = "res://Assets/Configs/GameConfigs"
const LEVEL_PLAY_SCENE: String = "res://Game/MyGame/Scenes/Levels/LevelPlay.tscn"


#region 节点

@onready var statusLabel: Label = $UILayer/Root/Margin/VBox/TitleRow/StatusLabel
@onready var goldLabel: Label = $UILayer/Root/Margin/VBox/TitleRow/GoldLabel
@onready var hintLabel: Label = $UILayer/Root/Margin/VBox/HintLabel
@onready var levelGrid: GridContainer = $UILayer/Root/Margin/VBox/LevelScroll/LevelGrid
@onready var testbedButton: Button = $UILayer/Root/Margin/VBox/FooterRow/TestbedButton

#endregion


#region 状态

var config: GameConfig
var service: Node

## 关卡按钮与它对应的定义（回归测试会读这个断言数量与内容）
var levelButtons: Dictionary = {}

#endregion


func _ready() -> void:
	service = _ensureConfigService()
	if service == null:
		return

	config = GameConfig.new(service)
	if not config.isReady():
		statusLabel.text = "配置加载失败：" + config.getErrorMessage()
		return

	_buildLevelButtons()
	_updateHeader()
	testbedButton.pressed.connect(_onTestbedButton_pressed)

	Debug.printLog(str("关卡选择就绪: 显示 ", levelButtons.size(), " 关"), logName)


#region 构建

func _buildLevelButtons() -> void:
	for child in levelGrid.get_children():
		child.queue_free()
	levelButtons.clear()

	var settings: PlayerSettings = config.getSettings()
	var unlockedLevels: Array[LevelDefinition] = config.getUnlockedLevels()

	for level: LevelDefinition in unlockedLevels:
		var button: Button = Button.new()
		button.custom_minimum_size = Vector2(280, 150)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.text = str(
			level.name, "\n",
			"D", level.id, " · ", level.difficulty,
			" · ", level.enemyCount, " 敌 × ", level.enemyHealth, " 血"
		)
		button.tooltip_text = str(
			"限时 ", int(level.timeLimit), " 秒\n",
			"单击 ", settings.playerDamage, " 伤害 → 每只 ",
			level.getHitsToKill(settings.playerDamage), " 击\n",
			"打穿共需 ", level.getTotalHitsRequired(settings.playerDamage), " 击"
		)
		button.pressed.connect(_onLevelButton_pressed.bind(level.id))

		levelGrid.add_child(button)
		levelButtons[level.id] = button


func _updateHeader() -> void:
	var settings: PlayerSettings = config.getSettings()
	var allLevels: Array[LevelDefinition] = config.getLevels()
	var unlockedLevels: Array[LevelDefinition] = config.getUnlockedLevels()

	goldLabel.text = str("金币 ", settings.startingGold)
	statusLabel.text = str(
		"共 ", allLevels.size(), " 关，已开放 ", unlockedLevels.size(),
		" 关（MaxLevel=", settings.maxLevel, "）"
	)

	var hints: PackedStringArray = PackedStringArray()
	hints.append(str("单击伤害 ", settings.playerDamage, " 来自设置表 · 关卡数据来自关卡表"))
	hints.append("点关卡进入，点敌人攻击；清完过关，倒计时归零失败")
	hintLabel.text = "\n".join(hints)

#endregion


#region 信号回调

func _onLevelButton_pressed(levelId: int) -> void:
	var playScene: PackedScene = load(LEVEL_PLAY_SCENE)
	if playScene == null:
		Debug.printError(str("无法加载关卡场景: ", LEVEL_PLAY_SCENE), logName)
		return

	# 记住要开的关卡：切场景后 LevelPlay 从 GlobalData 取（SceneManager 会换掉当前场景树）
	GameState.setGlobalValue(&"selectedLevelId", levelId)

	var didTransition: bool = await SceneManager.transitionToScene(playScene)
	if not didTransition:
		Debug.printError("切换到关卡场景失败", logName)


func _onTestbedButton_pressed() -> void:
	var testbedScene: PackedScene = load("res://Game/MyGame/Scenes/Testbeds/FrameworkFeatureTestbed.tscn")
	if testbedScene == null:
		Debug.printError("无法加载功能测试台场景", logName)
		return
	SceneManager.transitionToScene(testbedScene)

#endregion


#region 配置

## 唯一配置服务由 [GameConfigHub] 持有。不要自己 new LubanConfigService：
## Luban 表类是 C# 静态单例，第二个实例会报「singleton register twice」并整体失败。
func _ensureConfigService() -> Node:
	var service: Node = GameConfigHub.getService()
	if service == null:
		Debug.printError("配置表不可用（C# 未编译或表缺失）", logName)
		statusLabel.text = "配置表不可用：先 dotnet build 并生成配置"
		return null
	return service

#endregion
