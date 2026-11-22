extends SceneTree

## 单场景安全性探针：把指定场景实例化进空场景树并跑若干帧，判断它能不能当「演示场景」。
##
## 用途：给框架功能清单挑演示场景时先过这一关。能加载、能实例化、跑起来不崩，才有资格登记。
##
## 跑法：
##   Godot --headless --path . --script Game/MyGame/Tests/Regression/ProbeDemoScene.gd \
##       -- <场景路径> [帧数]
##
## 输出约定（供外层脚本断言）：
##   PROBE_MISSING <path>    场景文件不存在
##   PROBE_LOAD_FAIL <path>  加载返回 null
##   PROBE_INST_FAIL <path>  实例化返回 null
##   PROBE_NOARG             没给场景路径
##   PROBE_OK <path>         跑完指定帧数且进程正常退出
##
## ⚠️ 探针**判不了** GDScript 运行期报错：`SCRIPT ERROR` 走引擎 stderr，脚本里拿不到。
## 外层调用方必须把 stderr 一起收走再 grep（排除退出时 `resources still in use at exit`
## 这类探针自身的噪音，它不代表场景有问题）。

## 默认跑几帧。够场景跑完 _ready、定时器与第一轮 _process
const DEFAULT_FRAMES: int = 30

func _initialize() -> void:
	_run()


func _run() -> void:
	var userArgs: PackedStringArray = OS.get_cmdline_user_args()
	if userArgs.is_empty():
		print("PROBE_NOARG")
		quit(2)
		return

	var scenePath: String = userArgs[0]
	var frames: int = DEFAULT_FRAMES
	if userArgs.size() > 1 and userArgs[1].is_valid_int():
		frames = maxi(1, userArgs[1].to_int())

	await process_frame

	if not ResourceLoader.exists(scenePath):
		print("PROBE_MISSING ", scenePath)
		quit(1)
		return

	var packedScene: PackedScene = load(scenePath)
	if packedScene == null:
		print("PROBE_LOAD_FAIL ", scenePath)
		quit(1)
		return

	var instance: Node = packedScene.instantiate()
	if instance == null:
		print("PROBE_INST_FAIL ", scenePath)
		quit(1)
		return

	root.add_child(instance)
	for _i in frames:
		await process_frame

	print("PROBE_OK ", scenePath)
	quit(0)
