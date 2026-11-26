extends Node2D
## LutCanvas shader 的 A/B 测试台。
##
## 分区结构（截图可自解释）：
##   A 真实感像素场景   —— 全用调色板色，这是本 shader 的目标用例
##   B north 39 色原色条 —— 验证中间档不动、两端各走一步
##   C 各色族明暗阶梯   —— 验证族内阶梯与两端钳制
##   D 调色板外的纯饱和色 —— 展示"吸附到最近调色板色"的预期行为
##   E 抗锯齿文字       —— 演示为何本 shader 必须放在 UI 层之下
##
## 分区标签在 UILayer（layer 100），位于 shader 之上，因此保持清晰——
## 这同时示范了推荐的图层顺序。
##
## 用法：F6 打开，按 L 切换；自动化截图见 Tests/Regression/CaptureLutCanvas.gd

const RAMP_PATH: String = "res://Assets/Shaders/Ramps/north_ramp_7.png"
const RAMP_JSON: String = "res://Assets/Shaders/Ramps/north_ramp_7.json"
const SHADER_PATH: String = "res://Assets/Shaders/Screen/LutCanvas.gdshader"

const CANVAS_SIZE: Vector2i = Vector2i(960, 540)

## 分区矩形，CaptureLutCanvas 通过这些名字取区域做统计
const LAYOUT: Dictionary = {
	&"scene": Rect2i(0, 0, 960, 180),
	&"strip": Rect2i(0, 196, 960, 26),
	&"families": Rect2i(8, 236, 348, 160),
	&"offpalette": Rect2i(0, 410, 960, 44),
	&"text": Rect2i(0, 466, 960, 66),
}

var _shade_rect: ColorRect
var _material: ShaderMaterial
var _is_shader_enabled: bool = false
var _palette_colors: Array[Color] = []
var _palette_hex: PackedStringArray = PackedStringArray()
var _families: Array = []
var _labels: Array[Label] = []
var _label_backdrops: Array[ColorRect] = []


func _ready() -> void:
	_load_palette()
	_build_shade_layer()
	_build_content()
	_build_labels()
	set_shader_enabled(_is_shader_enabled)


func set_shader_enabled(is_enabled: bool) -> void:
	_is_shader_enabled = is_enabled
	if _shade_rect:
		_shade_rect.visible = is_enabled


## 供验收脚本切换档位强度，用来做 ±1 / ±2 的对照
func set_steps(dark: float, bright: float) -> void:
	if _material == null:
		return
	_material.set_shader_parameter(&"dark_steps", dark)
	_material.set_shader_parameter(&"bright_steps", bright)


func get_steps() -> Vector2:
	if _material == null:
		return Vector2.ZERO
	return Vector2(
		float(_material.get_shader_parameter(&"dark_steps")),
		float(_material.get_shader_parameter(&"bright_steps")),
	)


func get_shade_material() -> ShaderMaterial:
	return _material


func get_canvas_size() -> Vector2i:
	return CANVAS_SIZE


func get_layout() -> Dictionary:
	return LAYOUT


func get_palette_colors() -> Array[Color]:
	return _palette_colors


func get_ramp_table() -> Array:
	## ramp[i][k] = 颜色索引
	var f: FileAccess = FileAccess.open(RAMP_JSON, FileAccess.READ)
	if f == null:
		return []
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return data.get("ramp", []) if typeof(data) == TYPE_DICTIONARY else []


func _load_palette() -> void:
	var f: FileAccess = FileAccess.open(RAMP_JSON, FileAccess.READ)
	if f == null:
		Debug.printError("读不到调色板 json: %s" % RAMP_JSON)
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(data) != TYPE_DICTIONARY:
		Debug.printError("调色板 json 格式不对")
		return
	for hex: String in data.get("colors", []):
		_palette_hex.append(hex)
		_palette_colors.append(Color.html(hex))
	for family: Array in data.get("families", []):
		_families.append(family)


func _color_at(index: int) -> Color:
	if index < 0 or index >= _palette_colors.size():
		return Color.MAGENTA
	return _palette_colors[index]


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
		Debug.printError("读不到 ramp 图: %s" % RAMP_PATH)
	_material.set_shader_parameter(&"ramp_texture", ramp)
	_shade_rect.material = _material
	layer.add_child(_shade_rect)


func _build_content() -> void:
	var content: Node2D = Node2D.new()
	content.name = "Content"
	add_child(content)
	content.draw.connect(_on_content_draw.bind(content))


## 分区标签放在 shader 之上，保证清晰——真实项目也该这么做
func _build_labels() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "UILayer"
	layer.layer = 100
	add_child(layer)

	var labels: Array = [
		["A  真实感像素场景（全部为调色板色）—— 目标用例", 2],
		["B  north 39 色原色条", 182],
		["C  各色族明暗阶梯（左暗右亮，两端钳制）", 222],
		["D  调色板外的纯饱和色 —— 会吸附到最近的调色板色", 396],
		["E  抗锯齿文字 —— 会被量化，所以本 shader 应挂在 UI 层之下", 452],
	]
	for item: Array in labels:
		var half: Label = Label.new()
		half.text = String(item[0])
		half.add_theme_font_size_override(&"font_size", 11)
		var y: float = float(item[1])
		# 深色底：标签压在浅色天空或色条上也要看得清
		var pad: float = 2.0
		var pick: ColorRect = ColorRect.new()
		pick.color = Color(0.078, 0.078, 0.055, 0.82)
		pick.position = Vector2(8 - pad, y - pad)
		pick.size = Vector2(half.get_minimum_size().x + pad * 2, half.get_minimum_size().y + pad * 2)
		pick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(pick)
		_label_backdrops.append(pick)

		var label: Label = Label.new()
		label.text = String(item[0])
		label.position = Vector2(8, y)
		label.add_theme_font_size_override(&"font_size", 11)
		label.add_theme_color_override(&"font_color", Color.html("#cab896"))
		layer.add_child(label)
		_labels.append(label)

	var status: Label = Label.new()
	status.name = "StatusLabel"
	status.text = "A/B 测试台 · 按 L 切换 shader"
	status.position = Vector2(640, 4)
	status.add_theme_font_size_override(&"font_size", 11)
	status.add_theme_color_override(&"font_color", Color.html("#909290"))
	layer.add_child(status)
	_labels.append(status)


## 标签与它们的半透明底板都在 shader 之上：抗锯齿和半透明混合都会让像素发生变化，
## 而且变化的对象是被处理过的下层内容。把这些矩形报给验收脚本，断言时排除掉。
func get_label_rects() -> Array[Rect2i]:
	var rects: Array[Rect2i] = []

	# 半透明底板：它混合的是下层（已被 shader 处理）内容，像素必然变化
	for pick: ColorRect in _label_backdrops:
		if not is_instance_valid(pick):
			continue
		var pr: Rect2 = pick.get_global_rect()
		rects.append(Rect2i(
			int(floorf(pr.position.x)) - 1,
			int(floorf(pr.position.y)) - 1,
			int(ceilf(pr.size.x)) + 2,
			int(ceilf(pr.size.y)) + 2,
		))

	for label: Label in _labels:
		if not is_instance_valid(label):
			continue
		var r: Rect2 = label.get_global_rect()
		# Label 不在容器里时 size 可能是 0，get_global_rect 会给出空矩形，
		# 排除区就漏掉了整块文字。用最小尺寸兜底。
		var minSize: Vector2 = label.get_minimum_size()
		var size: Vector2 = Vector2(maxf(r.size.x, minSize.x), maxf(r.size.y, minSize.y))
		# 外扩 2px，容纳抗锯齿与描边
		rects.append(Rect2i(
			int(floorf(r.position.x)) - 2,
			int(floorf(r.position.y)) - 2,
			int(ceilf(size.x)) + 4,
			int(ceilf(size.y)) + 4,
		))
	return rects


func _on_content_draw(canvas: Node2D) -> void:
	_draw_scene(canvas)
	_draw_strip(canvas)
	_draw_families(canvas)
	_draw_offpalette(canvas)


## A：用调色板色拼一个"真实感"场景，全平涂色块——代表统一过色板的像素素材
func _draw_scene(canvas: Node2D) -> void:
	var w: float = float(CANVAS_SIZE.x)

	# 天空：上部亮、下部略暗（earth 族亮端）
	canvas.draw_rect(Rect2(0, 0, w, 60), _color_at(13))
	canvas.draw_rect(Rect2(0, 60, w, 20), _color_at(12))

	# 远山 / 中山 / 近林（green 族，从亮到暗拉出纵深）
	canvas.draw_rect(Rect2(0, 74, w, 26), _color_at(19))
	canvas.draw_rect(Rect2(0, 94, w, 22), _color_at(17))
	canvas.draw_rect(Rect2(0, 110, w, 14), _color_at(15))

	# 地面：两层土色
	canvas.draw_rect(Rect2(0, 124, w, 32), _color_at(7))
	canvas.draw_rect(Rect2(0, 156, w, 24), _color_at(4))

	# 三间屋子：墙体 earth 亮端、屋顶 brown/red 族
	var houses: Array[Vector3] = [Vector3(90, 112, 46), Vector3(330, 120, 62), Vector3(600, 106, 38)]
	for house: Vector3 in houses:
		var hx: float = house.x
		var hy: float = house.y
		var hw: float = house.z
		var hh: float = 40.0
		# 屋顶（三角用两层矩形近似，保持纯色块）
		canvas.draw_rect(Rect2(hx - 6, hy, hw + 12, 8), _color_at(23))
		canvas.draw_rect(Rect2(hx - 2, hy - 8, hw + 4, 8), _color_at(24))
		# 墙体
		canvas.draw_rect(Rect2(hx, hy + 8, hw, hh), _color_at(10))
		# 墙体左下阴影
		canvas.draw_rect(Rect2(hx, hy + 8 + hh - 10, hw, 10), _color_at(9))
		# 门与窗（暗）
		canvas.draw_rect(Rect2(hx + hw * 0.4, hy + 20, 10, 20), _color_at(2))
		canvas.draw_rect(Rect2(hx + hw * 0.7, hy + 16, 7, 7), _color_at(27))

	# 树：树干 brown，树冠 green 亮暗两层
	var trees: Array[Vector2] = [Vector2(240, 128), Vector2(470, 134), Vector2(760, 130)]
	for t: Vector2 in trees:
		canvas.draw_rect(Rect2(t.x - 3, t.y, 6, 26), _color_at(21))
		canvas.draw_rect(Rect2(t.x - 20, t.y - 16, 40, 20), _color_at(18))
		canvas.draw_rect(Rect2(t.x - 14, t.y - 24, 28, 10), _color_at(19))

	# 火把光斑（gold 族，亮）
	canvas.draw_rect(Rect2(196, 118, 6, 6), _color_at(28))
	canvas.draw_rect(Rect2(724, 122, 6, 6), _color_at(28))


## B：39 色原色条
func _draw_strip(canvas: Node2D) -> void:
	var rect: Rect2i = LAYOUT[&"strip"]
	var sw: float = float(rect.size.x) / float(max(_palette_colors.size(), 1))
	for i: int in _palette_colors.size():
		canvas.draw_rect(Rect2(i * sw, rect.position.y, ceil(sw), rect.size.y), _palette_colors[i])


## C：各色族完整阶梯
func _draw_families(canvas: Node2D) -> void:
	var rect: Rect2i = LAYOUT[&"families"]
	var block_w: float = 22.0
	var block_h: float = 22.0
	for fi: int in _families.size():
		var family: Array = _families[fi]
		var y: float = rect.position.y + fi * (block_h + 4.0)
		for pi: int in family.size():
			var idx: int = int(family[pi])
			canvas.draw_rect(Rect2(10 + pi * block_w, y, block_w - 1, block_h), _palette_colors[idx])


## D：调色板外的颜色
func _draw_offpalette(canvas: Node2D) -> void:
	var rect: Rect2i = LAYOUT[&"offpalette"]
	var off_colors: Array[Color] = [
		Color(1, 0, 0), Color(0, 1, 0), Color(0, 0, 1),
		Color(1, 1, 0), Color(1, 0, 1), Color(0, 1, 1),
		Color(1, 1, 1), Color(0.5, 0.5, 0.5), Color(0, 0, 0),
	]
	var off_w: float = float(rect.size.x) / float(off_colors.size())
	for i: int in off_colors.size():
		canvas.draw_rect(Rect2(i * off_w, rect.position.y, ceil(off_w), rect.size.y), off_colors[i])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_L:
			set_shader_enabled(not _is_shader_enabled)
			var status: Label = get_node_or_null("UILayer/StatusLabel") as Label
			if status:
				status.text = "shader: %s  (按 L 切换)" % ("ON" if _is_shader_enabled else "OFF")
