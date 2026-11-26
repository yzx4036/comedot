extends Node2D
## LutCanvas 光照驱动的验证台。
##
## 设计要点：整屏铺**同一个**调色板色 (#7a6a4c, earth 族 L*=45.6)。
##
## 为什么必须同色：
##   - 自明度驱动下，同色像素的 L* 相同 → 落到同一档 → 全屏输出一模一样（等于没效果）
##   - 光照驱动下，同色像素按所在位置的光照强度分档 → 亮处提、暗处压
## 所以「同色铺底」是区分两种驱动方式的最小可控实验。
##
## 画布固定 960×540，光照贴图同尺寸（shader 用 SCREEN_UV 直接采样，不做坐标变换）。

const CANVAS_SIZE: Vector2i = Vector2i(960, 540)

const SHADER_PATH: String = "res://Assets/Shaders/Screen/LutCanvas.gdshader"
const RAMP_PATH: String = "res://Assets/Shaders/Ramps/north_ramp_7.png"
const LIGHT_PATH: String = "res://Assets/Shaders/Lights/test_light.png"

## earth 族中间调：L*=45.6，自明度模式下 offset≈−0.37 → 落在不变档附近。
## 这个色最适合做对照——自明度模式"什么都不做"，光照模式才看得出结构。
const GROUND_COLOR: String = "#7a6a4c"

## 采样点：光源中心 / 中等光 / 角落
const PROBE_BRIGHT: Vector2i = Vector2i(260, 320)
const PROBE_MID: Vector2i = Vector2i(560, 200)
const PROBE_DARK: Vector2i = Vector2i(920, 500)

var _shade_rect: ColorRect
var _material: ShaderMaterial
var _is_shader_enabled: bool = false


func _ready() -> void:
	_build_shade_layer()
	_build_content()
	_build_labels()
	# 默认用光照驱动（这是本测试台要验证的模式）
	set_use_light_mask(true)
	set_shader_enabled(true)


func set_shader_enabled(is_enabled: bool) -> void:
	_is_shader_enabled = is_enabled
	if _shade_rect:
		_shade_rect.visible = is_enabled


func set_use_light_mask(is_use: bool) -> void:
	if _material:
		_material.set_shader_parameter(&"use_light_mask", is_use)


func is_using_light_mask() -> bool:
	if _material == null:
		return false
	return bool(_material.get_shader_parameter(&"use_light_mask"))


func get_shade_material() -> ShaderMaterial:
	return _material


func get_canvas_size() -> Vector2i:
	return CANVAS_SIZE


func get_probe_points() -> Dictionary:
	return {
		&"bright": PROBE_BRIGHT,
		&"mid": PROBE_MID,
		&"dark": PROBE_DARK,
	}


func _build_shade_layer() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "ShadeLayer"
	layer.layer = 50
	add_child(layer)

	_shade_rect = ColorRect.new()
	_shade_rect.name = "ShadeRect"
	_shade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	var ramp: Texture2D = load(RAMP_PATH)
	if ramp == null:
		Debug.printError("读不到 ramp: " + RAMP_PATH, "LutLightingTest")
	_material.set_shader_parameter(&"ramp_texture", ramp)

	var light: Texture2D = load(LIGHT_PATH)
	if light == null:
		Debug.printError("读不到光照贴图: " + LIGHT_PATH, "LutLightingTest")
	_material.set_shader_parameter(&"light_mask", light)

	# 光照贴图已经量化过，对比直通即可
	_material.set_shader_parameter(&"light_contrast", 1.0)
	_material.set_shader_parameter(&"light_bias", 0.0)

	_shade_rect.material = _material
	layer.add_child(_shade_rect)


func _build_content() -> void:
	var content: Node2D = Node2D.new()
	content.name = "Content"
	add_child(content)
	content.draw.connect(_on_content_draw.bind(content))


func _on_content_draw(canvas: Node2D) -> void:
	var w: float = float(CANVAS_SIZE.x)
	var h: float = float(CANVAS_SIZE.y)

	# 整屏同色铺底：这是对照实验的基础
	canvas.draw_rect(Rect2(0, 0, w, h), Color.html(GROUND_COLOR))

	# 用另一族颜色点几个方框，确认明暗处理没有把颜色改坏
	var accents: Array = [
		[Vector2(120, 90), "#82905a"],
		[Vector2(760, 90), "#b85a44"],
		[Vector2(120, 420), "#b8862e"],
		[Vector2(760, 420), "#909290"],
	]
	for item: Array in accents:
		var pos: Vector2 = item[0]
		canvas.draw_rect(Rect2(pos.x, pos.y, 60, 40), Color.html(String(item[1])))

	# 采样点上方画十字做定位标记。注意十字不能盖在采样点上——
	# 否则读到的就是标记色而不是底色，整个对照实验失效。
	for probe: Vector2i in [PROBE_BRIGHT, PROBE_MID, PROBE_DARK]:
		var c: Color = Color.html("#d8c8a8")
		var cx: int = probe.x
		var cy: int = probe.y - 26
		canvas.draw_rect(Rect2(cx - 6, cy, 13, 2), c)
		canvas.draw_rect(Rect2(cx, cy - 6, 2, 13), c)


func _build_labels() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "UILayer"
	layer.layer = 100
	add_child(layer)

	var lines: Array = [
		["整屏同色铺底 #7a6a4c —— 只有光照驱动才能拉开明暗", 8],
		["十字 = 采样点：左亮 / 中 / 右下暗", 26],
	]
	for item: Array in lines:
		var label: Label = Label.new()
		label.text = String(item[0])
		label.position = Vector2(8, float(item[1]))
		label.add_theme_font_size_override(&"font_size", 12)
		label.add_theme_color_override(&"font_color", Color.html("#14140e"))
		layer.add_child(label)
