extends Node
## LutCanvas shader 的自动化 A/B 截图 + 数值验收。
##
## 输出：
##   SHOT_RAW / SHOT_LUT  两张 PNG 的绝对路径
##   RAMP / PALETTE_SIZE  资源就绪情况
##   REGION ...           分区统计（亮度、饱和度变化）
##   SWATCH n/n           39 色原色条的逐色精确断言
##   VERDICT PASS|FAIL
##
## 用法：
##   godot --path . Game/MyGame/Tests/Regression/CaptureLutCanvas.tscn
## headless 下直接 SKIP（无渲染后端，图会是空白）。

const TESTBED_SCENE: String = "res://Game/MyGame/Scenes/Testbeds/LutCanvasTest.tscn"
const OUT_DIR: String = "user://lut_canvas_shots"

## 必须与 shader 的默认 uniform 一致，用于推算期望档位
const DARK_LSTAR: float = 38.0
const BRIGHT_LSTAR: float = 62.0
const DARK_STEPS: float = 1.0
const BRIGHT_STEPS: float = 1.0

var _testbed: Node2D
var _failures: PackedStringArray = PackedStringArray()
var _summary: String = ""


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("SHOT_SKIPPED headless 无渲染后端")
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

	# ── 硬门禁 1：测试台真的挂上了脚本（否则后面的统计全是假绿）──
	var scene: PackedScene = load(TESTBED_SCENE) as PackedScene
	if scene == null:
		_failures.append("测试台场景加载失败：%s" % TESTBED_SCENE)
		return
	_testbed = scene.instantiate() as Node2D
	if _testbed == null:
		_failures.append("测试台实例化失败（脚本可能有解析错误）")
		return
	add_child(_testbed)

	if not _testbed.has_method("set_shader_enabled") or not _testbed.has_method("get_ramp_table"):
		_failures.append("测试台脚本未挂载（方法不存在），大概率是 GDScript 解析错误")
		return

	# 窗口尺寸对齐画布，避免内容被裁
	DisplayServer.window_set_size(_testbed.call("get_canvas_size"))
	await get_tree().process_frame

	var material: ShaderMaterial = _testbed.call("get_shade_material") as ShaderMaterial
	if material == null or material.shader == null:
		_failures.append("LutCanvas ShaderMaterial / shader 未就绪")
		return
	var ramp: Variant = material.get_shader_parameter(&"ramp_texture")
	if not (ramp is Texture2D):
		_failures.append("ramp_texture 未绑定到 ShaderMaterial")
		return
	var ramp_tex: Texture2D = ramp as Texture2D
	print("RAMP %dx%d" % [ramp_tex.get_width(), ramp_tex.get_height()])

	var palette: Array[Color] = _testbed.call("get_palette_colors")
	var ramp_table: Array = _testbed.call("get_ramp_table")
	print("PALETTE_SIZE %d" % palette.size())
	if palette.size() != ramp_tex.get_width():
		_failures.append("调色板 %d 色与 ramp 宽 %d 不一致" % [palette.size(), ramp_tex.get_width()])
		return
	if ramp_table.size() != palette.size():
		_failures.append("ramp 表 %d 行与调色板 %d 色不一致" % [ramp_table.size(), palette.size()])
		return

	# 等构图与首帧绘制完成
	for i: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

	# ── A 面：shader 关 ──
	_testbed.call("set_shader_enabled", false)
	await _settle()
	var img_raw: Image = _grab()
	if img_raw == null:
		_failures.append("A 面截图失败")
		return

	# ── B 面：shader 开，±1 档（P1 默认「两档」）──
	_testbed.call("set_steps", 1.0, 1.0)
	_testbed.call("set_shader_enabled", true)
	await _settle()
	var img_lut: Image = _grab()
	if img_lut == null:
		_failures.append("B 面截图失败")
		return

	# ── C 面：shader 开，±2 档（展示机制可见的强度）──
	_testbed.call("set_steps", 2.0, 2.0)
	await _settle()
	var img_strong: Image = _grab()
	_testbed.call("set_steps", 1.0, 1.0)  # 复位，避免影响后续断言

	var path_raw: String = OUT_DIR.path_join("lut_raw.png")
	var path_lut: String = OUT_DIR.path_join("lut_on.png")
	var path_strong: String = OUT_DIR.path_join("lut_strong.png")
	img_raw.save_png(path_raw)
	img_lut.save_png(path_lut)
	if img_strong != null:
		img_strong.save_png(path_strong)
	print("SHOT_RAW " + ProjectSettings.globalize_path(path_raw))
	print("SHOT_LUT " + ProjectSettings.globalize_path(path_lut))
	if img_strong != null:
		print("SHOT_STRONG " + ProjectSettings.globalize_path(path_strong))
	print("SHOT_SIZE %dx%d" % [img_raw.get_width(), img_raw.get_height()])

	# ── 硬门禁 2：两张图有内容且互不相同 ──
	if _is_blank(img_raw):
		_failures.append("A 面截图全黑/单色，渲染未发生")
	if _is_blank(img_lut):
		_failures.append("B 面截图全黑/单色，渲染未发生")
	if _identical(img_raw, img_lut):
		_failures.append("A/B 两张截图完全一致，shader 没有生效")

	var layout: Dictionary = _testbed.call("get_layout")
	_report_regions(img_raw, img_lut, layout)
	_check_strip_exact(img_raw, img_lut, layout, palette, ramp_table, ramp_tex.get_height())
	var label_rects: Array[Rect2i] = []
	if _testbed.has_method("get_label_rects"):
		label_rects.assign(_testbed.call("get_label_rects"))
	_check_containment(img_raw, img_lut, palette, label_rects)


# ────────────────────────── 断言 ──────────────────────────

## 核心断言：39 色原色条的每个色块，输出必须精确等于 ramp 里该色的期望档位
func _check_strip_exact(raw: Image, lut: Image, layout: Dictionary, palette: Array[Color],
		ramp_table: Array, bands: int) -> void:
	var rect: Rect2i = layout[&"strip"]
	var y: int = rect.position.y + rect.size.y / 2
	var sw: float = float(rect.size.x) / float(palette.size())
	var center: int = bands / 2

	var ok_raw: int = 0
	var ok_lut: int = 0
	var total: int = palette.size()
	var mismatches: PackedStringArray = PackedStringArray()
	var hue_drift_max: float = 0.0
	var sat_delta_min: float = 0.0

	for i: int in total:
		var x: int = int((float(i) + 0.5) * sw)
		var got_raw: Color = raw.get_pixel(x, y)
		var got_lut: Color = lut.get_pixel(x, y)

		if _rgb_equal(got_raw, palette[i]):
			ok_raw += 1
		else:
			mismatches.append("色%d 原始采样 %s ≠ 调色板 %s" % [i, _hex(got_raw), _hex(palette[i])])

		var band: int = _expected_band(palette[i], bands, center)
		var expected_index: int = int(ramp_table[i][band])
		var expected: Color = palette[expected_index]
		if _rgb_equal(got_lut, expected):
			ok_lut += 1
		else:
			mismatches.append("色%d 输出 %s ≠ 期望 %s (band=%d)" % [i, _hex(got_lut), _hex(expected), band])

		var hd: float = _hue_delta(palette[i], got_lut)
		hue_drift_max = maxf(hue_drift_max, hd)
		sat_delta_min = minf(sat_delta_min, got_lut.s - palette[i].s)

	print("SWATCH %d/%d raw %d/%d lut" % [ok_lut, total, ok_raw, total])
	_summary = "%d/%d 色精确匹配" % [ok_lut, total]
	print("HUE_DRIFT_MAX %.1f°" % hue_drift_max)
	print("SAT_DELTA_MIN %+.3f" % sat_delta_min)

	if ok_raw != total:
		_failures.append("原色条原始采样只有 %d/%d 命中，构图或采样位置有问题" % [ok_raw, total])
	if ok_lut != total:
		_failures.append("原色条输出只有 %d/%d 与期望档位一致" % [ok_lut, total])
		for m: String in mismatches.slice(0, 6):
			_failures.append(m)
	# 色相漂移：近黑色（饱和度极低）的色相是噪声，跳过
	if hue_drift_max > 15.0:
		_failures.append("色相漂移过大：%.1f°" % hue_drift_max)


## shader 输出的每一像素都必须是调色板内真实颜色。
## 注意：分区标签挂在 shader 之上（UILayer），它们没被处理、颜色不在调色板内，
## 所以只针对「被 shader 改动过的像素」做断言——那才是 shader 真正输出的结果。
func _check_containment(raw: Image, lut: Image, palette: Array[Color],
		exclude: Array[Rect2i]) -> void:
	var allowed: Dictionary = {}
	for c: Color in palette:
		allowed[_rgb_key(c)] = true

	var changed: int = 0
	var bad: int = 0
	var all_palette: int = 0
	var all_checked: int = 0
	var bad_positions: PackedStringArray = PackedStringArray()
	for y: int in range(0, lut.get_height(), 2):
		for x: int in range(0, lut.get_width(), 2):
			if _in_any(x, y, exclude):
				continue
			all_checked += 1
			var c: Color = lut.get_pixel(x, y)
			var in_palette: bool = allowed.has(_rgb_key(c))
			if in_palette:
				all_palette += 1
			if not _rgb_equal(c, raw.get_pixel(x, y)):
				changed += 1
				if not in_palette:
					bad += 1
					if bad_positions.size() < 8:
						bad_positions.append("(%d,%d)%s" % [x, y, _hex(c)])

	print("PALETTE_CONTAINMENT changed=%d bad=%d  (全体 %.2f%% 命中)" % [
		changed, bad, float(all_palette) / float(max(all_checked, 1)) * 100.0,
	])
	if changed == 0:
		_failures.append("没有任何像素被 shader 改动")
	if bad > 0:
		_failures.append("有 %d 个被 shader 改动的像素落在调色板外，如 %s"
			% [bad, ", ".join(bad_positions)])


func _in_any(x: int, y: int, rects: Array[Rect2i]) -> bool:
	for r: Rect2i in rects:
		if x >= r.position.x and x < r.position.x + r.size.x \
				and y >= r.position.y and y < r.position.y + r.size.y:
			return true
	return false


## 分区统计：不发灰 = 饱和度不能掉；暗部要变暗、亮部要变亮
func _report_regions(raw: Image, lut: Image, layout: Dictionary) -> void:
	for key: StringName in [&"scene", &"strip", &"families", &"offpalette"]:
		if not layout.has(key):
			continue
		var rect: Rect2i = layout[key]
		var s_raw: float = _mean_saturation(raw, rect)
		var s_lut: float = _mean_saturation(lut, rect)
		var l_raw: float = _mean_lstar(raw, rect)
		var l_lut: float = _mean_lstar(lut, rect)
		print("REGION %-11s sat %.4f -> %.4f (%+6.1f%%)  L* %5.1f -> %5.1f (%+6.1f%%)" % [
			String(key), s_raw, s_lut, _pct(s_raw, s_lut), l_raw, l_lut, _pct(l_raw, l_lut),
		])
		# 场景区（调色板锁定素材）的饱和度不许掉
		if key == &"scene" and s_lut < s_raw * 0.95:
			_failures.append("场景区饱和度下降 %.1f%%，出现发灰" % ((1.0 - s_lut / maxf(s_raw, 1e-6)) * 100.0))


# ────────────────────────── 工具 ──────────────────────────

## 复刻 shader 里的档位推算，用于断言
func _expected_band(color: Color, bands: int, center: int) -> int:
	var L: float = _lstar(color)
	var t: float = clampf((L - DARK_LSTAR) / maxf(BRIGHT_LSTAR - DARK_LSTAR, 0.001), 0.0, 1.0)
	var offset: float
	if t < 0.5:
		offset = lerpf(-DARK_STEPS, 0.0, t * 2.0)
	else:
		offset = lerpf(0.0, BRIGHT_STEPS, (t - 0.5) * 2.0)
	return clampi(center + int(floorf(offset + 0.5)), 0, bands - 1)


func _srgb_to_linear(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


func _lstar(color: Color) -> float:
	var y: float = 0.2126729 * _srgb_to_linear(color.r) \
		+ 0.7151522 * _srgb_to_linear(color.g) \
		+ 0.0721750 * _srgb_to_linear(color.b)
	return 116.0 * pow(y, 1.0 / 3.0) - 16.0 if y > 0.008856 else 903.3 * y


func _hue_delta(a: Color, b: Color) -> float:
	if a.s < 0.12 or b.s < 0.12:
		return 0.0  # 近灰色的色相是噪声，不计
	var d: float = absf(a.h - b.h) * 360.0
	return minf(d, 360.0 - d)


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


func _is_blank(img: Image) -> bool:
	var seen: Dictionary = {}
	var step: int = maxi(1, img.get_width() / 64)
	for y: int in range(0, img.get_height(), step):
		for x: int in range(0, img.get_width(), step):
			seen[_rgb_key(img.get_pixel(x, y))] = true
			if seen.size() > 8:
				return false
	return seen.size() <= 8


func _identical(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	var step: int = maxi(1, a.get_width() / 200)
	for y: int in range(0, a.get_height(), step):
		for x: int in range(0, a.get_width(), step):
			if not _rgb_equal(a.get_pixel(x, y), b.get_pixel(x, y)):
				return false
	return true


func _mean_saturation(img: Image, rect: Rect2i) -> float:
	var total: float = 0.0
	var n: int = 0
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			total += img.get_pixel(x, y).s
			n += 1
	return total / float(max(n, 1))


func _mean_lstar(img: Image, rect: Rect2i) -> float:
	var total: float = 0.0
	var n: int = 0
	for y: int in range(rect.position.y, rect.position.y + rect.size.y):
		for x: int in range(rect.position.x, rect.position.x + rect.size.x):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			total += _lstar(img.get_pixel(x, y))
			n += 1
	return total / float(max(n, 1))


func _pct(before: float, after: float) -> float:
	if is_zero_approx(before):
		return 0.0
	return (after - before) / before * 100.0


func _hex(c: Color) -> String:
	return "#%02x%02x%02x" % [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0)]


func _rgb_key(c: Color) -> String:
	return "%d,%d,%d" % [roundi(c.r * 255.0), roundi(c.g * 255.0), roundi(c.b * 255.0)]


func _rgb_equal(a: Color, b: Color) -> bool:
	return _rgb_key(a) == _rgb_key(b)
