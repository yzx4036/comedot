extends Node2D

## comedot 框架功能测试台。
##
## 把 [FrameworkFeatureCatalog] 的全部条目按类别分成若干小节，每节铺成多行多列的按钮网格：
##   · 单击按钮 → 右侧详情显示类别、说明、源文件路径
##   · 带演示场景的条目 → 「运行演示」把该场景实例化到 [member demoHost]，点「返回」卸载
##   · 顶部搜索框与类别下拉做筛选，空掉的小节自动隐藏
##   · 进场景时跑一次自检：[FrameworkFeatureCatalog.verifyCoverage]，
##     报告组件覆盖数与断链/未录条目（框架新增组件忘了登记就会在这里露出来）


#region 常量

const logName: String = "FrameworkFeatureTestbed"

const CATEGORY_ALL: String = "全部"

## 每个按钮的最小宽度，用来算网格列数
const BUTTON_MIN_WIDTH: float = 230.0
const BUTTON_MIN_HEIGHT: float = 28.0

## 按钮字号。项目默认字体是 Pixel Operator 8（主题默认字号 8），字宽比常见字体宽，
## 12 号在 1280 宽的逻辑分辨率下可读且能放下大多数类名
const BUTTON_FONT_SIZE: int = 12

## 按钮内左右留白，用来算文字可用宽度
const BUTTON_TEXT_PADDING: float = 18.0

## 超宽文字的收尾符号
const ELLIPSIS: String = "…"

## 给竖直滚动条预留的宽度
const SCROLLBAR_ALLOWANCE: float = 18.0

const GRID_H_SEPARATION: int = 8
const GRID_V_SEPARATION: int = 6
const CATEGORY_FONT_SIZE: int = 14

const COLOR_HAS_DEMO: Color = Color(0.45, 0.95, 0.55)
const COLOR_NO_DEMO: Color = Color(0.84, 0.86, 0.9)
const COLOR_CATEGORY: Color = Color(0.72, 0.62, 0.98)
const COLOR_OK: Color = Color(0.55, 0.9, 0.65)
const COLOR_WARN: Color = Color(0.98, 0.78, 0.35)
const COLOR_BAD: Color = Color(0.95, 0.45, 0.45)

#endregion


#region 节点

@onready var browser: Control = $UILayer/Browser
@onready var statusLabel: Label = $UILayer/Browser/Margin/VBox/TitleRow/StatusLabel
@onready var searchBox: LineEdit = $UILayer/Browser/Margin/VBox/FilterRow/SearchBox
@onready var categoryOption: OptionButton = $UILayer/Browser/Margin/VBox/FilterRow/CategoryOption
@onready var countLabel: Label = $UILayer/Browser/Margin/VBox/FilterRow/CountLabel
@onready var scrollContainer: ScrollContainer = $UILayer/Browser/Margin/VBox/Body/ScrollContainer
@onready var blocksContainer: VBoxContainer = $UILayer/Browser/Margin/VBox/Body/ScrollContainer/Blocks
@onready var detailTitle: Label = $UILayer/Browser/Margin/VBox/Body/DetailPanel/DetailVBox/DetailTitle
@onready var detailCategory: Label = $UILayer/Browser/Margin/VBox/Body/DetailPanel/DetailVBox/DetailCategory
@onready var detailSummary: Label = $UILayer/Browser/Margin/VBox/Body/DetailPanel/DetailVBox/DetailSummary
@onready var detailPaths: Label = $UILayer/Browser/Margin/VBox/Body/DetailPanel/DetailVBox/DetailPaths
@onready var launchButton: Button = $UILayer/Browser/Margin/VBox/Body/DetailPanel/DetailVBox/LaunchButton
@onready var demoToolbar: PanelContainer = $UILayer/DemoToolbar
@onready var demoNameLabel: Label = $UILayer/DemoToolbar/ToolbarBox/DemoNameLabel
@onready var closeButton: Button = $UILayer/DemoToolbar/ToolbarBox/CloseButton
@onready var demoHost: Node2D = $DemoHost

#endregion


#region 状态

## 每个按钮对应的功能条目（按钮做 key，因筛选只切 visible 不重建按钮）
var buttonFeatures: Dictionary = {}

## 按构建顺序保存全部按钮，供筛选遍历
var allButtons: Array[Button] = []

## 类别 → 该类的按钮网格
var categoryGrids: Dictionary = {}

## 类别 → 该类的小节容器（标题 + 网格），筛空时整节隐藏
var categoryBlocks: Dictionary = {}

## 类别 → 该类的标题标签
var categoryHeaders: Dictionary = {}

## 类别 → 该类条目总数
var categoryTotals: Dictionary = {}

## 当前选中的条目（详情面板正在显示的那个）
var currentFeature: FrameworkFeature

## 正在运行的演示场景实例
var demoInstance: Node

## 按钮实际生效的字体（量文字宽度用，构建按钮时取一次）
var buttonFont: Font

## 上一次布局时 scrollContainer 的宽度，用于检测「布局变了」再重排
var lastScrollWidth: float = -1.0

#endregion


#region 生命周期

func _ready() -> void:
	_populateCategories()
	_buildCategoryBlocks()
	_buildFeatureButtons()
	_applyFilter()
	_updateColumns.call_deferred()
	_runSelfCheck()
	_selectFeature(_firstFeatureWithDemo(), false)

	searchBox.text_changed.connect(_onSearchBox_textChanged)
	categoryOption.item_selected.connect(_onCategoryOption_itemSelected)
	launchButton.pressed.connect(_onLaunchButton_pressed)
	closeButton.pressed.connect(_onCloseButton_pressed)

	demoToolbar.visible = false

#endregion


#region 构建

func _populateCategories() -> void:
	categoryOption.clear()
	categoryOption.add_item(CATEGORY_ALL)
	for category in FrameworkFeatureCatalog.getCategories():
		categoryOption.add_item(category)
	categoryOption.select(0)


## 每个类别一个小节：标题 Label + 自己的 GridContainer。
## 用「每类一个网格」而不是「一个网格插标题」——GridContainer 不能让某个子节点跨列，
## 分类标题只能在网格外面。
func _buildCategoryBlocks() -> void:
	for category in FrameworkFeatureCatalog.getCategories():
		var block: VBoxContainer = VBoxContainer.new()
		block.add_theme_constant_override("separation", 4)

		var header: Label = Label.new()
		header.text = category
		header.add_theme_font_size_override("font_size", CATEGORY_FONT_SIZE)
		header.add_theme_color_override("font_color", COLOR_CATEGORY)
		block.add_child(header)

		var grid: GridContainer = GridContainer.new()
		grid.add_theme_constant_override("h_separation", GRID_H_SEPARATION)
		grid.add_theme_constant_override("v_separation", GRID_V_SEPARATION)
		block.add_child(grid)

		blocksContainer.add_child(block)
		categoryGrids[category] = grid
		categoryBlocks[category] = block
		categoryHeaders[category] = header
		categoryTotals[category] = 0


func _buildFeatureButtons() -> void:
	for feature in FrameworkFeatureCatalog.getFeatures():
		var grid: GridContainer = categoryGrids[feature.category]

		var button: Button = Button.new()
		button.text = feature.getDisplayTitle()
		button.tooltip_text = str(feature.title, "\n", feature.summary)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(BUTTON_MIN_WIDTH, BUTTON_MIN_HEIGHT)
		button.clip_text = true
		# 选中态用 toggle 的按下外观，视觉上能一眼看出当前是哪一个
		button.toggle_mode = true
		button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
		button.add_theme_color_override("font_color", COLOR_HAS_DEMO if feature.hasDemo() else COLOR_NO_DEMO)
		button.pressed.connect(_onFeatureButton_pressed.bind(feature))

		grid.add_child(button)
		buttonFeatures[button] = feature
		allButtons.append(button)
		categoryTotals[feature.category] = int(categoryTotals[feature.category]) + 1

	# 量文字宽度要用按钮真实生效的字体（项目默认字体是 Pixel Operator 8，字宽和想象差很远）
	if not allButtons.is_empty():
		buttonFont = allButtons[0].get_theme_font("font")

	Debug.printLog(str("构建功能按钮: ", allButtons.size(), " / 类别: ", categoryGrids.size()), logName)


func _process(_delta: float) -> void:
	# 布局完成后 scrollContainer 才有真实宽度；这里按「宽度变了就重排」兜住各种时机
	var width: float = scrollContainer.size.x
	if not is_equal_approx(width, lastScrollWidth):
		lastScrollWidth = width
		_updateColumns()


## 按可用宽度算列数，并把每个按钮的宽度铺满可用宽度
## （只算列数不调宽度的话，网格右侧会留一条空带）
func _updateColumns() -> void:
	# 预留竖直滚动条宽度，否则算出的按钮总宽会超出容器、右边被切
	var available: float = scrollContainer.size.x - SCROLLBAR_ALLOWANCE
	if available <= 0.0:
		return

	var separation: float = float(GRID_H_SEPARATION)
	var columns: int = maxi(1, int((available + separation) / (BUTTON_MIN_WIDTH + separation)))
	var buttonWidth: float = floor((available - separation * float(columns - 1)) / float(columns))
	buttonWidth = maxf(buttonWidth, 80.0)

	for grid: GridContainer in categoryGrids.values():
		if grid.columns != columns:
			grid.columns = columns

	var newSize: Vector2 = Vector2(buttonWidth, BUTTON_MIN_HEIGHT)
	var textMaxWidth: float = buttonWidth - BUTTON_TEXT_PADDING
	for button in allButtons:
		if button.custom_minimum_size != newSize:
			button.custom_minimum_size = newSize
		# 按钮不能换行，超宽的自己截断成「…」，别让文字被硬切
		var fitted: String = _fitLabelText(buttonFeatures[button].getDisplayTitle(), textMaxWidth)
		if button.text != fitted:
			button.text = fitted


## 把文字裁到指定像素宽度，超出部分以省略号收尾
func _fitLabelText(text: String, maxWidth: float) -> String:
	if buttonFont == null or maxWidth <= 0.0:
		return text
	if _measureText(text) <= maxWidth:
		return text

	var trimmed: String = text
	while trimmed.length() > 1 and _measureText(trimmed + ELLIPSIS) > maxWidth:
		trimmed = trimmed.substr(0, trimmed.length() - 1)
	return trimmed + ELLIPSIS


func _measureText(text: String) -> float:
	return buttonFont.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, BUTTON_FONT_SIZE).x

#endregion


#region 筛选

func _applyFilter() -> void:
	var query: String = searchBox.text.strip_edges()
	var selectedCategory: String = categoryOption.get_item_text(categoryOption.selected)

	var shown: int = 0
	var visiblePerCategory: Dictionary = {}

	for button in allButtons:
		var feature: FrameworkFeature = buttonFeatures[button]
		var isMatch: bool = feature.matchesQuery(query)
		if selectedCategory != CATEGORY_ALL and feature.category != selectedCategory:
			isMatch = false

		button.visible = isMatch
		if isMatch:
			shown += 1
			visiblePerCategory[feature.category] = int(visiblePerCategory.get(feature.category, 0)) + 1

	_refreshCategoryHeaders(visiblePerCategory)
	countLabel.text = str("显示 ", shown, " / 共 ", allButtons.size())

	# 选中项被筛掉时就清空详情，避免看的是「看不见的那一条」
	if currentFeature != null and not _isFeatureVisible(currentFeature):
		_selectFeature(null, false)


## 标题显示「类别（命中/总数）」，整节没命中就隐藏
func _refreshCategoryHeaders(visiblePerCategory: Dictionary) -> void:
	for category in categoryHeaders.keys():
		var total: int = int(categoryTotals[category])
		var shown: int = int(visiblePerCategory.get(category, 0))
		var header: Label = categoryHeaders[category]
		var block: VBoxContainer = categoryBlocks[category]

		if shown == total:
			header.text = str(category, "（", total, "）")
		else:
			header.text = str(category, "（", shown, "/", total, "）")

		block.visible = shown > 0


func _isFeatureVisible(feature: FrameworkFeature) -> bool:
	for button in allButtons:
		if buttonFeatures[button] == feature:
			return button.visible
	return false

#endregion


#region 详情面板

func _firstFeatureWithDemo() -> FrameworkFeature:
	for feature in FrameworkFeatureCatalog.getFeatures():
		if feature.hasDemo():
			return feature
	return null


func _selectFeature(feature: FrameworkFeature, shouldScrollTo: bool = true) -> void:
	currentFeature = feature

	if feature == null:
		detailTitle.text = "（未选择）"
		detailCategory.text = ""
		detailSummary.text = "在左侧点一个功能查看说明。绿字条目带可运行演示场景。"
		detailPaths.text = ""
		launchButton.disabled = true
		launchButton.text = "运行演示"
		_updateSelectionHighlight()
		return

	detailTitle.text = feature.title
	detailCategory.text = str("类别：", feature.category)
	detailSummary.text = feature.summary

	var pathLines: PackedStringArray = PackedStringArray()
	pathLines.append(str("脚本/资源：", feature.sourcePath))
	var sceneSibling: String = feature.getSceneSiblingPath()
	if not sceneSibling.is_empty():
		pathLines.append(str("配套场景：", sceneSibling))
	if feature.hasDemo():
		pathLines.append(str("演示场景：", feature.demoScenePath))
	else:
		pathLines.append("演示场景：无（框架未提供独立可跑场景）")
	detailPaths.text = "\n".join(pathLines)

	launchButton.disabled = not feature.hasDemo()
	launchButton.text = "运行演示" if feature.hasDemo() else "无独立演示场景"

	_updateSelectionHighlight()

	if shouldScrollTo:
		_scrollToFeature(feature)


## 让当前选中的按钮保持按下外观，其余复位
func _updateSelectionHighlight() -> void:
	for button in allButtons:
		button.button_pressed = buttonFeatures[button] == currentFeature


func _scrollToFeature(feature: FrameworkFeature) -> void:
	for button in allButtons:
		if buttonFeatures[button] == feature and button.visible:
			# 延到布局完成后再滚，避免按旧尺寸计算落点；不用 await 以免本函数变成协程
			scrollContainer.ensure_control_visible.call_deferred(button)
			return

#endregion


#region 演示场景

func _launchDemo(feature: FrameworkFeature) -> void:
	if feature == null or not feature.hasDemo():
		return
	if is_instance_valid(demoInstance):
		return # 已经在跑：连点不叠加，避免同一场景被挂两份

	_freeDemoInstance()

	var packedScene: PackedScene = load(feature.demoScenePath)
	if packedScene == null:
		Debug.printError(str("无法加载演示场景: ", feature.demoScenePath), logName)
		return

	demoInstance = packedScene.instantiate()
	if demoInstance == null:
		Debug.printError(str("实例化失败: ", feature.demoScenePath), logName)
		return

	demoHost.add_child(demoInstance)
	browser.visible = false
	demoToolbar.visible = true
	demoNameLabel.text = str("演示中：", feature.title, "  ←  ", feature.demoScenePath)
	Debug.printLog(str("运行演示: ", feature.title, " ← ", feature.demoScenePath), logName)


func _onCloseButton_pressed() -> void:
	_clearDemo()


func _clearDemo() -> void:
	_freeDemoInstance()
	browser.visible = true


## 只负责卸掉实例，不动浏览面板的可见性（调用方决定界面状态）
func _freeDemoInstance() -> void:
	if is_instance_valid(demoInstance):
		# 先摘出树再延迟释放：同一帧里换演示时旧节点不会和新节点并存
		demoHost.remove_child(demoInstance)
		demoInstance.queue_free()
	demoInstance = null
	demoToolbar.visible = false

#endregion


#region 自检

## 与磁盘双向对照：组件是否全部登记、条目引用的路径是否都还在
func _runSelfCheck() -> void:
	var result: Dictionary = FrameworkFeatureCatalog.verifyCoverage()
	var broken: PackedStringArray = result["broken"]
	var notListed: PackedStringArray = result["notListed"]

	var headline: String = str(
		"条目 ", allButtons.size(),
		" · 组件覆盖 ", result["covered"], "/", result["total"],
		" · 可运行演示 ", result["demoCount"])

	if broken.is_empty() and notListed.is_empty():
		statusLabel.text = str("自检通过 · ", headline)
		statusLabel.add_theme_color_override("font_color", COLOR_OK)
		Debug.printLog(str("自检通过 · ", headline), logName)
		return

	statusLabel.text = str("自检异常（断链 ", broken.size(), " / 未录 ", notListed.size(), "）· ", headline)
	statusLabel.add_theme_color_override("font_color", COLOR_BAD if not broken.is_empty() else COLOR_WARN)

	for path in broken:
		Debug.printError(str("断链: ", path), logName)
	for path in notListed:
		Debug.printWarning(str("未录条目（Components 下存在但清单里没有）: ", path), logName)

#endregion


#region 信号回调

func _onFeatureButton_pressed(feature: FrameworkFeature) -> void:
	_selectFeature(feature)


func _onLaunchButton_pressed() -> void:
	_launchDemo(currentFeature)


func _onSearchBox_textChanged(_newText: String) -> void:
	_applyFilter()


func _onCategoryOption_itemSelected(_index: int) -> void:
	_applyFilter()

#endregion
