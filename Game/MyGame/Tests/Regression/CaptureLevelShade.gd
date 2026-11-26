extends Node
## LevelPlay 接上 LutCanvas 后的 A/B 截图与断言。
##
## 验证三件事：
##   1. 关卡真的跑起来了（敌人数 > 0），shader 没把场景搞崩
##   2. 关 / 开明暗层两帧画面不同 → shader 确实在起作用
##   3. HUD 区域两帧完全相同 → UI 位于 shader 之上，文字没被量化
##      （这条是图层顺序的硬证据，顺序错了这里会挂）
##
## 用法：
##   godot --path . Game/MyGame/Tests/Regression/CaptureLevelShade.tscn

const LEVEL_SCENE: String = "res://Game/MyGame/Scenes/Levels/LevelPlay.tscn"
const LEVEL_ID: int = 1
const RAW_PATH: String = "user://level_shade_off.png"
const LUT_PATH: String = "user://level_shade_on.png"

## HUD 面板在左上角，取一块只含 HUD 的区域
const HUD_REGION: Rect2i = Rect2i(8, 6, 360, 130)
## 敌人活动区（避开 HUD）
const PLAY_REGION: Rect2i = Rect2i(60, 200, 1160, 480)

var _play: Node2D
var _failures: PackedStringArray = PackedStringArray()
var _summary: String = ""


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("VERDICT SKIP headless 无渲染后端")
		get_tree().quit(2)
		return
	await _run()
	if _failures.is_empty():
		print("VERDICT PASS " + _summary)
	else:
		print("VERDICT FAIL")
		for f: String in _failures:
			print("  FAIL " + f)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	var scene: PackedScene = load(LEVEL_SCENE) as PackedScene
	if scene == null:
		_failures.append("关卡场景加载失败: " + LEVEL_SCENE)
		return
	_play = scene.instantiate() as Node2D
	if _play == null:
		_failures.append("关卡实例化失败（脚本可能有解析错误）")
		return
	add_child(_play)

	if not _play.has_method("setShadeEnabled") or not _play.has_method("getShadeMaterial"):
		_failures.append("关卡脚本未挂载明暗层接口，可能是解析错误")
		return

	for i: int in 3:
		await get_tree().process_frame

	# 硬门禁：材质与 ramp 真的绑上了
	var material: ShaderMaterial = _play.call("getShadeMaterial") as ShaderMaterial
	if material == null or material.shader == null:
		_failures.append("ShadeLayer 上没有 LutCanvas 材质")
		return
	var ramp: Variant = material.get_shader_parameter(&"ramp_texture")
	if not (ramp is Texture2D):
		_failures.append("ramp_texture 未绑定")
		return
	print("RAMP %dx%d" % [(ramp as Texture2D).get_width(), (ramp as Texture2D).get_height()])

	# 显式启动一关：单独跑本场景时 GameState 里没有 selectedLevelId
	var started: bool = bool(_play.call("startLevel", LEVEL_ID))
	var spawned: int = int(_play.get("spawnedEnemies"))
	print("LEVEL id=%d started=%s spawned=%d" % [LEVEL_ID, str(started), spawned])
	if not started:
		_failures.append("关卡 %d 未能启动" % LEVEL_ID)
		return
	if spawned <= 0:
		_failures.append("敌人数为 0，场景是空的")
		return

	# 默认必须是关闭的：LutCanvas 会把整体压暗，在原型关卡上实测可读性下降，
	# 所以只作为可手动开启的选项（游戏内按 T 切换）。这里钉住这个行为契约。
	var defaultOn: bool = bool(_play.call("isShadeEnabled"))
	print("DEFAULT_SHADE " + ("on" if defaultOn else "off"))
	if defaultOn:
		_failures.append("明暗层默认应为关闭，实际是开启")

	# ── 关 ──
	_play.call("setShadeEnabled", false)
	await _settle()
	var imgOff: Image = _grab()
	if imgOff == null:
		_failures.append("关闭状态截图失败")
		return

	# ── 开 ──
	_play.call("setShadeEnabled", true)
	await _settle()
	var imgOn: Image = _grab()
	if imgOn == null:
		_failures.append("开启状态截图失败")
		return

	imgOff.save_png(RAW_PATH)
	imgOn.save_png(LUT_PATH)
	print("SHOT_OFF " + ProjectSettings.globalize_path(RAW_PATH))
	print("SHOT_ON " + ProjectSettings.globalize_path(LUT_PATH))
	print("SHOT_SIZE %dx%d" % [imgOff.get_width(), imgOff.get_height()])

	# ── 判据 1：两帧必须不同 ──
	var playDiff: int = _diff_count(imgOff, imgOn, PLAY_REGION)
	print("PLAY_DIFF %d" % playDiff)
	_summary = "关卡 %d · 敌人 %d · 明暗层生效 · UI 未被处理" % [LEVEL_ID, spawned]
	if playDiff <= 0:
		_failures.append("敌人区域两帧完全相同，明暗层没生效")

	# ── 判据 2：图层顺序 —— UI 必须整体位于明暗层之上 ──
	# 不用 HUD 文字验：文字有抗锯齿边缘，会和下层混合，分不清是"被量化"还是"正常混色"。
	# 改为运行时往 UILayer 塞一块调色板里不存在的纯品红：
	#   在 shade 之上 → 原样保留；在 shade 之下 → 必被吸附成某个调色板色。
	var markerRect: Rect2i = Rect2i(1000, 20, 40, 40)
	var marker: ColorRect = ColorRect.new()
	marker.name = "LayerOrderMarker"
	marker.color = Color(1.0, 0.0, 1.0)   # 纯品红，north 39 色里没有
	marker.position = Vector2(markerRect.position)
	marker.size = Vector2(markerRect.size)
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play.get_node("UILayer").add_child(marker)

	await _settle()
	imgOff = _grab()
	_play.call("setShadeEnabled", true)
	await _settle()
	imgOn = _grab()
	if imgOff == null or imgOn == null:
		_failures.append("图层顺序验证截图失败")
		return

	var markerDiff: int = _diff_count(imgOff, imgOn, markerRect)
	var markerOff: Color = imgOff.get_pixel(
		markerRect.position.x + markerRect.size.x / 2,
		markerRect.position.y + markerRect.size.y / 2)
	print("LAYER_MARKER 关闭时=%s  两帧差异=%d" % [_hex(markerOff), markerDiff])
	if not markerOff.is_equal_approx(Color(1.0, 0.0, 1.0)):
		# 读到的不是品红，说明它经过了 LutCanvas 被吸附成调色板色
		_failures.append("UILayer 里的标记块被量化成 %s（应为 ff00ff），UI 落在了 shader 之下"
			% _hex(markerOff))
	elif markerDiff > 0:
		_failures.append("UILayer 里的标记块被改动了 %d 像素，UI 落在了 shader 之下" % markerDiff)

	# ── 判据 3：画面不是空白 ──
	if _is_flat(imgOn):
		_failures.append("开启明暗层后画面近乎单色")


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _grab() -> Image:
	return get_viewport().get_texture().get_image()


func _diff_count(a: Image, b: Image, rect: Rect2i) -> int:
	var n: int = 0
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			if x < 0 or y < 0 or x >= a.get_width() or y >= a.get_height():
				continue
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				n += 1
	return n


func _hex(c: Color) -> String:
	return c.to_html(false)


func _is_flat(img: Image) -> bool:
	var seen: Dictionary = {}
	var step: int = maxi(1, img.get_width() / 80)
	for y: int in range(0, img.get_height(), step):
		for x: int in range(0, img.get_width(), step):
			seen[img.get_pixel(x, y).to_html(false)] = true
			if seen.size() > 10:
				return false
	return true
