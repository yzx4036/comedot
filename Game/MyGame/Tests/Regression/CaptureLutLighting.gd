extends Node
## LutCanvas 光照驱动的验收：证明"跟光照走"确实不同于"跟自身亮度走"。
##
## 测试台整屏铺同一个调色板色，所以：
##   · 自明度模式：三个采样点的 L* 相同 → 输出必须几乎一致（这就是原来做不到体积感的原因）
##   · 光照模式：三个采样点按光照强度分档 → 亮点的 L* 必须显著高于暗点
##
## 用法：
##   godot --path . Game/MyGame/Tests/Regression/CaptureLutLighting.tscn

const TESTBED_SCENE: String = "res://Game/MyGame/Scenes/Testbeds/LutLightingTest.tscn"
const OUT_DIR: String = "user://lut_lighting_shots"

## 自明度模式下，三个点的 L* 差异必须小于这个值（同色应当被同样处理）
const SELF_LUM_MAX_SPREAD: float = 2.0
## 光照模式下，亮点必须比暗点亮至少这么多 L*，才算真的拉出明暗结构
const LIGHT_MIN_SPREAD: float = 8.0

var _testbed: Node2D
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
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	_isolate_autoload_ui()

	var scene: PackedScene = load(TESTBED_SCENE) as PackedScene
	if scene == null:
		_failures.append("测试台加载失败: " + TESTBED_SCENE)
		return
	_testbed = scene.instantiate() as Node2D
	if _testbed == null:
		_failures.append("测试台实例化失败（脚本可能有解析错误）")
		return
	add_child(_testbed)

	if not _testbed.has_method("set_use_light_mask") or not _testbed.has_method("get_probe_points"):
		_failures.append("测试台脚本未挂载接口，可能是解析错误")
		return

	DisplayServer.window_set_size(_testbed.call("get_canvas_size"))
	for i: int in 3:
		await get_tree().process_frame

	# 硬门禁：材质与两张贴图都在
	var material: ShaderMaterial = _testbed.call("get_shade_material") as ShaderMaterial
	if material == null or material.shader == null:
		_failures.append("LutCanvas 材质未就绪")
		return
	var ramp: Variant = material.get_shader_parameter(&"ramp_texture")
	var light: Variant = material.get_shader_parameter(&"light_mask")
	if not (ramp is Texture2D):
		_failures.append("ramp_texture 未绑定")
		return
	if not (light is Texture2D):
		_failures.append("light_mask 未绑定")
		return
	print("RAMP %dx%d  LIGHT %dx%d" % [
		(ramp as Texture2D).get_width(), (ramp as Texture2D).get_height(),
		(light as Texture2D).get_width(), (light as Texture2D).get_height(),
	])

	var probes: Dictionary = _testbed.call("get_probe_points")

	# ── A：shader 关，确认底色一致 ──
	_testbed.call("set_shader_enabled", false)
	await _settle()
	var imgOff: Image = _grab()
	if imgOff == null:
		_failures.append("关闭状态截图失败")
		return
	_save(imgOff, "lighting_off.png", "SHOT_OFF")

	# ── B：自明度模式 ──
	_testbed.call("set_shader_enabled", true)
	_testbed.call("set_use_light_mask", false)
	await _settle()
	var imgSelf: Image = _grab()
	if imgSelf == null:
		_failures.append("自明度模式截图失败")
		return
	_save(imgSelf, "lighting_self_lum.png", "SHOT_SELF")

	# ── C：光照驱动 ──
	_testbed.call("set_use_light_mask", true)
	await _settle()
	var imgLight: Image = _grab()
	if imgLight == null:
		_failures.append("光照模式截图失败")
		return
	_save(imgLight, "lighting_light_mask.png", "SHOT_LIGHT")

	# ── 断言 1：关闭时三点同色（对照实验的基础）──
	var off_b: float = _lstar(imgOff.get_pixelv(probes[&"bright"]))
	var off_m: float = _lstar(imgOff.get_pixelv(probes[&"mid"]))
	var off_d: float = _lstar(imgOff.get_pixelv(probes[&"dark"]))
	print("OFF     L* bright=%.1f mid=%.1f dark=%.1f" % [off_b, off_m, off_d])
	var offSpread: float = maxf(off_b, maxf(off_m, off_d)) - minf(off_b, minf(off_m, off_d))
	if offSpread > SELF_LUM_MAX_SPREAD:
		_failures.append("关闭时三个采样点就不同色（L* 差 %.1f），对照实验不成立，检查铺底" % offSpread)

	# ── 断言 2：自明度模式下三点仍然一致 ──
	var self_b: float = _lstar(imgSelf.get_pixelv(probes[&"bright"]))
	var self_m: float = _lstar(imgSelf.get_pixelv(probes[&"mid"]))
	var self_d: float = _lstar(imgSelf.get_pixelv(probes[&"dark"]))
	var selfSpread: float = maxf(self_b, maxf(self_m, self_d)) - minf(self_b, minf(self_m, self_d))
	print("SELF    L* bright=%.1f mid=%.1f dark=%.1f  跨度 %.1f" % [self_b, self_m, self_d, selfSpread])
	if selfSpread > SELF_LUM_MAX_SPREAD:
		_failures.append("自明度模式下同色像素居然被区别处理（跨度 %.1f），说明测试台铺底不是同一种颜色" % selfSpread)

	# ── 断言 3：光照模式下必须拉开明暗 ──
	var light_b: float = _lstar(imgLight.get_pixelv(probes[&"bright"]))
	var light_m: float = _lstar(imgLight.get_pixelv(probes[&"mid"]))
	var light_d: float = _lstar(imgLight.get_pixelv(probes[&"dark"]))
	var lightSpread: float = light_b - light_d
	print("LIGHT   L* bright=%.1f mid=%.1f dark=%.1f  亮暗差 %.1f" % [light_b, light_m, light_d, lightSpread])
	if lightSpread < LIGHT_MIN_SPREAD:
		_failures.append("光照模式下亮暗差只有 %.1f（要求 >%.1f），光照贴图没起作用"
			% [lightSpread, LIGHT_MIN_SPREAD])

	_summary = "自明度跨度 %.1f → 光照亮暗差 %.1f" % [selfSpread, lightSpread]


## 把 autoload 的 UI 层藏起来，保证截图只含测试台内容
func _isolate_autoload_ui() -> void:
	for node_name: String in ["GlobalUI", "Debug"]:
		var node: Node = get_tree().root.get_node_or_null(NodePath(node_name))
		if node == null:
			continue
		if node is CanvasItem:
			(node as CanvasItem).visible = false
		for child: Node in node.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
			if child is CanvasLayer:
				(child as CanvasLayer).visible = false


func _save(img: Image, file_name: String, tag: String) -> void:
	var path: String = OUT_DIR.path_join(file_name)
	img.save_png(path)
	print("%s %s" % [tag, ProjectSettings.globalize_path(path)])


func _settle() -> void:
	for i: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw


func _grab() -> Image:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		return null
	var size: Vector2i = _testbed.call("get_canvas_size")
	var w: int = mini(img.get_width(), size.x)
	var h: int = mini(img.get_height(), size.y)
	if w != img.get_width() or h != img.get_height():
		img = img.get_region(Rect2i(0, 0, w, h))
	return img


func _srgb_to_linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


func _lstar(color: Color) -> float:
	var y: float = 0.2126729 * _srgb_to_linear(color.r) \
		+ 0.7151522 * _srgb_to_linear(color.g) \
		+ 0.0721750 * _srgb_to_linear(color.b)
	return 116.0 * pow(y, 1.0 / 3.0) - 16.0 if y > 0.008856 else 903.3 * y
