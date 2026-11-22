extends SceneTree

## 逐个把测试台里的可运行演示场景「打开 → 关闭」一遍，确认没有场景会崩、也不留残留节点。
##
## 这是清单里 `hasDemo()` 条目的护栏：新登记演示场景后跑一次，能立刻发现
## 「加载即崩」「卸载不干净」两类问题。单场景的深度探针见 ProbeDemoScene.gd。
##
## 跑法：Godot --headless --path . --script Game/MyGame/Tests/Regression/CheckAllDemoScenes.gd
## 退出码：0 = 全部可开可关；1 = 有失败项。

const logName: String = "CheckAllDemoScenes"

const TESTBED_SCENE_PATH: String = "res://Game/MyGame/Scenes/Testbeds/FrameworkFeatureTestbed.tscn"

## 每个演示挂载后等几帧再断言（场景 _ready 里的建树/定时器要跑起来）
const MOUNT_WAIT_FRAMES: int = 3

var failures: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame

	var packedScene: PackedScene = load(TESTBED_SCENE_PATH)
	if packedScene == null:
		print("AUTO_RESULT FAIL  测试台场景加载失败: ", TESTBED_SCENE_PATH)
		quit(1)
		return

	var testbed: Node = packedScene.instantiate()
	root.add_child(testbed)
	await _waitFrames(2)

	var demos: Array[FrameworkFeature] = []
	for feature in FrameworkFeatureCatalog.getFeatures():
		if feature.hasDemo():
			demos.append(feature)

	print("待扫演示场景: ", demos.size())

	for index in demos.size():
		await _checkOne(testbed, demos[index], index + 1, demos.size())

	# 扫完再确认一次清单自检没被演示污染
	var coverage: Dictionary = FrameworkFeatureCatalog.verifyCoverage()
	print("自检: 组件 ", coverage["covered"], "/", coverage["total"],
		" · 演示 ", coverage["demoCount"],
		" · 断链 ", (coverage["broken"] as PackedStringArray).size(),
		" · 未录 ", (coverage["notListed"] as PackedStringArray).size())

	print("")
	if failures.is_empty():
		print("AUTO_RESULT PASS  ", demos.size(), " 个演示全部可开可关")
		quit(0)
		return
	print("AUTO_RESULT FAIL  ", failures.size(), " 项失败")
	for item in failures:
		print("   - ", item)
	quit(1)


func _checkOne(testbed: Node, feature: FrameworkFeature, ordinal: int, total: int) -> void:
	var label: String = str("[", ordinal, "/", total, "] ", feature.title, " ← ", feature.demoScenePath)

	# 进这一轮之前必须是干净的，否则上一轮的残留会算到这一轮头上
	if testbed.demoHost.get_child_count() != 0:
		failures.append(label + "  进入时已有残留=" + str(testbed.demoHost.get_child_count()))
		print("FAIL  ", label, "  进入时已有残留")

	testbed._launchDemo(feature)
	await _waitFrames(MOUNT_WAIT_FRAMES)

	var mounted: int = testbed.demoHost.get_child_count()
	if mounted != 1:
		failures.append(label + "  挂载数=" + str(mounted))
		print("FAIL  ", label, "  挂载数=", mounted)
	elif testbed.browser.visible:
		failures.append(label + "  浏览面板未隐藏")
		print("FAIL  ", label, "  浏览面板未隐藏")
	else:
		print("OK    ", label)

	testbed._onCloseButton_pressed()
	await _waitFrames(2)

	var remaining: int = testbed.demoHost.get_child_count()
	if remaining != 0:
		failures.append(label + "  卸载残留=" + str(remaining))
		print("FAIL  ", label, "  卸载残留=", remaining)


func _waitFrames(count: int) -> void:
	for _i in count:
		await process_frame
