extends SceneTree

## 测试台截图（视觉验收用；headless 拿不到渲染，必须窗口模式跑）。
##
## 跑法：
##   Godot --path . --script Game/MyGame/Tests/Regression/CaptureTestbedScreenshot.gd \
##       -- <mode> [输出路径]
##     mode = index  截「功能索引」界面
##     mode = demo   先启动第一个演示场景再截
##
## 输出路径缺省写 `user://` 下（导出/沙箱环境都可写），并打印全局绝对路径便于取图。
## 输出约定：`SHOT_SAVED <abs_path> <WxH>` / `SHOT_SKIPPED` / `SHOT_FAIL <原因>`

const TESTBED_SCENE_PATH: String = "res://Game/MyGame/Scenes/Testbeds/FrameworkFeatureTestbed.tscn"

## 等布局与主题稳定所需帧数（太少会截到空网格）
const SETTLE_FRAMES: int = 10

## 启动演示后额外等待帧数
const DEMO_SETTLE_FRAMES: int = 20


func _initialize() -> void:
	_run()


func _run() -> void:
	# headless 下 frame_post_draw 永不触发，会挂死等；先挡住
	if DisplayServer.get_name() == "headless":
		print("SHOT_SKIPPED headless 模式没有渲染，请用窗口模式跑")
		quit(2)
		return

	var userArgs: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = userArgs[0] if userArgs.size() > 0 else "index"
	var shouldShowDemo: bool = mode == "demo"
	var outPath: String = userArgs[1] if userArgs.size() > 1 else str("user://testbed_", mode, ".png")
	if not outPath.contains("://"):
		outPath = "user://" + outPath

	var packedScene: PackedScene = load(TESTBED_SCENE_PATH)
	if packedScene == null:
		print("SHOT_FAIL 无法加载测试台场景: ", TESTBED_SCENE_PATH)
		quit(1)
		return

	var testbed: Node = packedScene.instantiate()
	root.add_child(testbed)
	await _waitFrames(SETTLE_FRAMES)

	if shouldShowDemo:
		var demoFeature: FrameworkFeature = _findFeatureWithDemo()
		if demoFeature == null:
			print("SHOT_FAIL 清单里没有可运行演示")
			quit(1)
			return
		testbed._launchDemo(demoFeature)
		await _waitFrames(DEMO_SETTLE_FRAMES)

	await _waitFrames(SETTLE_FRAMES)
	await RenderingServer.frame_post_draw

	var image: Image = root.get_texture().get_image()
	if image == null:
		print("SHOT_FAIL 拿到空图像")
		quit(1)
		return

	var error: int = image.save_png(outPath)
	if error != OK:
		print("SHOT_FAIL 保存失败 error=", error, " path=", outPath)
		quit(1)
		return

	print("SHOT_SAVED ", ProjectSettings.globalize_path(outPath), " ", image.get_size())
	quit(0)


func _findFeatureWithDemo() -> FrameworkFeature:
	for feature in FrameworkFeatureCatalog.getFeatures():
		if feature.hasDemo():
			return feature
	return null


func _waitFrames(count: int) -> void:
	for _i in count:
		await process_frame
