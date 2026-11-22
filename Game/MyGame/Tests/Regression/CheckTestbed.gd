extends SceneTree

## 功能测试台的结构与交互验收。
##
## 覆盖：按钮网格构建、清单与磁盘双向对照、演示场景的启动/卸载/连开、搜索与类别筛选。
## 跑法：Godot --headless --path . --script Game/MyGame/Tests/Regression/CheckTestbed.gd
##
## 退出码：0 = 全部通过；1 = 有失败项。stdout 末尾固定打印 `AUTO_RESULT PASS|FAIL` 供外层断言。

const logName: String = "CheckTestbed"

const TESTBED_SCENE_PATH: String = "res://Game/MyGame/Scenes/Testbeds/FrameworkFeatureTestbed.tscn"

## 金丝雀：框架升级新增/删除组件后这个数字会变，本项失败即为提醒「该同步功能清单了」
const EXPECTED_COMPONENT_COUNT: int = 123

## 清单条目数下限（清单只会增长，低于此值说明构建逻辑坏了或清单被误删）
const MIN_FEATURE_COUNT: int = 200

var failures: PackedStringArray = PackedStringArray()


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

	var packedScene: PackedScene = load(TESTBED_SCENE_PATH)
	_check(packedScene != null, "测试台场景可加载", TESTBED_SCENE_PATH)
	if packedScene == null:
		_finish()
		return

	var testbed: Node = packedScene.instantiate()
	root.add_child(testbed)
	await process_frame
	await process_frame

	_checkGrid(testbed)
	_checkCatalogCoverage()
	_checkDemoScenesExist()
	await _checkDemoLifecycle(testbed)
	await _checkFiltering(testbed)

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


#region 网格

func _checkGrid(testbed: Node) -> void:
	var buttonCount: int = testbed.allButtons.size()
	_check(buttonCount >= MIN_FEATURE_COUNT, "按钮数量", str(buttonCount))

	# 每个类别一个小节：按钮分布在各节自己的网格里，且每节都分到了列数
	var gridButtonCount: int = 0
	var minColumns: int = 0
	var isEmptyGrid: bool = false
	for grid: GridContainer in testbed.categoryGrids.values():
		gridButtonCount += grid.get_child_count()
		if minColumns == 0:
			minColumns = grid.columns
		minColumns = mini(minColumns, grid.columns)
		if grid.get_child_count() > 0 and grid.columns < 1:
			isEmptyGrid = true

	_check(not isEmptyGrid, "非空分类网格都有列数")
	_check(minColumns >= 1, "所有分类网格都有列数", str(minColumns))
	_check(gridButtonCount == buttonCount, "按钮全部入格", str(gridButtonCount))
	_check(testbed.categoryGrids.size() == testbed.categoryHeaders.size(),
		"分类小节数与标题数一致", str(testbed.categoryGrids.size()))

	# 每个按钮都必须映射回一条清单条目，否则筛选与详情都会点空
	var unmapped: int = 0
	for button in testbed.allButtons:
		if not testbed.buttonFeatures.has(button):
			unmapped += 1
	_check(unmapped == 0, "按钮全部映射到条目", str(unmapped))

#endregion


#region 清单自检

func _checkCatalogCoverage() -> void:
	var coverage: Dictionary = FrameworkFeatureCatalog.verifyCoverage()

	_check(int(coverage["total"]) == EXPECTED_COMPONENT_COUNT,
		"组件总数（框架新增/删除组件时需同步清单）", str(coverage["total"]))
	_check(int(coverage["covered"]) == int(coverage["total"]), "组件全覆盖",
		str(coverage["covered"]) + "/" + str(coverage["total"]))

	var broken: PackedStringArray = coverage["broken"]
	var notListed: PackedStringArray = coverage["notListed"]
	_check(broken.is_empty(), "无断链路径", str(broken.size()))
	if not broken.is_empty():
		for path in broken:
			print("      断链: ", path)

	_check(notListed.is_empty(), "无未录组件", str(notListed.size()))
	if not notListed.is_empty():
		for path in notListed:
			print("      未录: ", path)

	_check(int(coverage["demoCount"]) > 0, "存在可运行演示", str(coverage["demoCount"]))
	_check(FrameworkFeatureCatalog.getCategories().size() >= 10, "类别数",
		str(FrameworkFeatureCatalog.getCategories().size()))


## 每条带演示的条目，场景文件都必须真实存在
func _checkDemoScenesExist() -> void:
	var missing: PackedStringArray = PackedStringArray()
	for feature in FrameworkFeatureCatalog.getFeatures():
		if feature.hasDemo() and not ResourceLoader.exists(feature.demoScenePath):
			missing.append(feature.demoScenePath)

	_check(missing.is_empty(), "演示场景全部存在", "缺 " + str(missing.size()))
	for path in missing:
		print("      缺失: ", path)

#endregion


#region 演示生命周期

func _checkDemoLifecycle(testbed: Node) -> void:
	var firstDemo: FrameworkFeature = _findFeatureWithDemo(null)
	_check(firstDemo != null, "找到演示条目", firstDemo.title if firstDemo != null else "无")
	if firstDemo == null:
		return

	testbed._launchDemo(firstDemo)
	await _waitFrames(2)
	_check(testbed.demoHost.get_child_count() == 1, "演示已挂载",
		str(testbed.demoHost.get_child_count()))
	_check(not testbed.browser.visible, "运行中隐藏浏览面板")
	_check(testbed.demoToolbar.visible, "运行中显示返回栏")

	testbed._onCloseButton_pressed()
	await _waitFrames(2)
	_check(testbed.demoHost.get_child_count() == 0, "返回后卸载演示",
		str(testbed.demoHost.get_child_count()))
	_check(testbed.browser.visible, "返回后恢复浏览面板")

	# 连开两个不同演示：不许累积节点
	var secondDemo: FrameworkFeature = _findFeatureWithDemo(firstDemo)
	_check(secondDemo != null, "找到第二个演示条目")
	if secondDemo == null:
		return

	await process_frame
	testbed._launchDemo(firstDemo)
	await process_frame
	testbed._launchDemo(secondDemo)
	await _waitFrames(2)
	_check(testbed.demoHost.get_child_count() == 1, "连开不累积",
		str(testbed.demoHost.get_child_count()))

	testbed._onCloseButton_pressed()
	await _waitFrames(2)
	_check(testbed.demoHost.get_child_count() == 0, "二次卸载干净",
		str(testbed.demoHost.get_child_count()))


func _findFeatureWithDemo(exclude: FrameworkFeature) -> FrameworkFeature:
	for feature in FrameworkFeatureCatalog.getFeatures():
		if feature.hasDemo() and feature != exclude:
			return feature
	return null

#endregion


#region 筛选

func _checkFiltering(testbed: Node) -> void:
	var totalButtons: int = testbed.allButtons.size()

	testbed.searchBox.text = "damage"
	testbed._applyFilter()
	await process_frame
	var visibleMatches: int = _countVisible(testbed)
	_check(visibleMatches > 0 and visibleMatches < totalButtons, "搜索命中子集",
		str(visibleMatches))

	# 搜不到东西时必须清空详情，不能留着一条看不见的选中项
	testbed.searchBox.text = "zzzz-no-such-feature"
	testbed._applyFilter()
	await process_frame
	_check(_countVisible(testbed) == 0, "无命中时按钮全隐", str(_countVisible(testbed)))
	_check(testbed.currentFeature == null, "无命中时清空选中项")

	testbed.searchBox.text = ""
	testbed._applyFilter()
	await process_frame
	_check(_countVisible(testbed) == totalButtons, "清空搜索恢复全部",
		str(_countVisible(testbed)))


func _countVisible(testbed: Node) -> int:
	var visibleCount: int = 0
	for button in testbed.allButtons:
		if button.visible:
			visibleCount += 1
	return visibleCount

#endregion


func _waitFrames(count: int) -> void:
	for _i in count:
		await process_frame
