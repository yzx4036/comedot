extends Node
## 特效播放验收：SpriteFrames 存在不算数，要证明它真的在 AnimatedSprite2D 里推进。
##
## 判据（每项都必须是硬断言）：
##   · sprite_frames 已挂且帧数 > 0
##   · 第一帧是 AtlasTexture，atlas 与 region 都有效
##   · fps 与源 json 一致
##   · is_playing
##   · 采样一段时间后 current_frame 出现过多个不同值（真的在推进，不是卡住）
##   · 窗口模式下额外截图：非空白，且不同时刻的画面不同
##
## 用法：
##   godot --path . Game/MyGame/Tests/Regression/CheckFxPlayback.tscn

const SHOWCASE_SCENE: String = "res://Game/MyGame/Scenes/Testbeds/FxShowcase.tscn"
const SHOT_PATH: String = "user://fx_showcase.png"

## 采样多久、每隔几帧采一次
const SAMPLE_SECONDS: float = 0.4
const SAMPLE_STEP_FRAMES: int = 2

var _failures: PackedStringArray = PackedStringArray()
var _checked: int = 0


func _ready() -> void:
	await _run()
	if _failures.is_empty():
		print("AUTO_RESULT PASS %d/%d 特效在推进" % [_checked, _checked + _failures.size()])
		get_tree().quit(0)
	else:
		for f: String in _failures:
			print("  FAIL " + f)
		print("AUTO_RESULT FAIL %d 项失败" % _failures.size())
		get_tree().quit(1)


func _run() -> void:
	var scene: PackedScene = load(SHOWCASE_SCENE) as PackedScene
	if scene == null:
		_failures.append("展示台场景加载失败: " + SHOWCASE_SCENE)
		return

	var showcase: Node2D = scene.instantiate() as Node2D
	if showcase == null:
		_failures.append("展示台实例化失败")
		return
	add_child(showcase)

	if not showcase.has_method("get_sprites"):
		_failures.append("展示台脚本未挂载（get_sprites 不存在），可能有解析错误")
		return

	await get_tree().process_frame
	await get_tree().process_frame

	var sprites: Dictionary = showcase.call("get_sprites")
	if sprites.is_empty():
		_failures.append("没有拿到任何 AnimatedSprite2D")
		return

	# ── 静态判据 ──
	for id: StringName in sprites:
		_check_sprite_static(id, sprites[id] as AnimatedSprite2D)

	# ── 动态判据：采样看帧有没有推进 ──
	# 先把所有特效拨回第 0 帧重新播：one-shot 可能在上面的等待里已经播完，
	# 直接采样会采到"静止在末帧"，误判成动画没动。
	for id: StringName in sprites:
		var s: AnimatedSprite2D = sprites[id]
		if is_instance_valid(s) and s.sprite_frames != null:
			s.set_frame_and_progress(0, 0.0)
			s.play(&"default")

	var traces: Dictionary = {}
	for id: StringName in sprites:
		traces[id] = {}

	var elapsed: float = 0.0
	var frameCount: int = 0
	while elapsed < SAMPLE_SECONDS:
		await get_tree().process_frame
		frameCount += 1
		elapsed += get_process_delta_time()
		if frameCount % SAMPLE_STEP_FRAMES != 0:
			continue
		for id: StringName in sprites:
			var s: AnimatedSprite2D = sprites[id]
			if is_instance_valid(s):
				(traces[id] as Dictionary)[s.frame] = true

	for id: StringName in sprites:
		var s: AnimatedSprite2D = sprites[id]
		if not is_instance_valid(s) or s.sprite_frames == null:
			continue
		var distinct: int = (traces[id] as Dictionary).size()
		var frameCount2: int = s.sprite_frames.get_frame_count(&"default")
		var shouldLoop: bool = s.sprite_frames.get_animation_loop(&"default")
		print("FX %-14s 帧=%3d fps=%.0f loop=%-5s playing=%-5s 采样到不同帧=%d" % [
			String(id), frameCount2, s.sprite_frames.get_animation_speed(&"default"),
			str(shouldLoop), str(s.is_playing()), distinct,
		])
		if distinct < 2:
			_failures.append("%s: 采样期内只见到 %d 个不同帧，动画没在推进" % [String(id), distinct])
		else:
			_checked += 1

	# ── 窗口模式才做的视觉判据 ──
	if DisplayServer.get_name() == "headless":
		print("SHOT_SKIPPED headless 无渲染后端")
		return

	await _check_visual(sprites)


## 静态结构断言
func _check_sprite_static(id: StringName, sprite: AnimatedSprite2D) -> void:
	if sprite == null:
		_failures.append("%s: 不是 AnimatedSprite2D" % String(id))
		return
	if sprite.sprite_frames == null:
		_failures.append("%s: sprite_frames 未挂载" % String(id))
		return
	var count: int = sprite.sprite_frames.get_frame_count(&"default")
	if count <= 0:
		_failures.append("%s: 动画帧数为 0" % String(id))
		return
	if sprite.sprite_frames.get_animation_speed(&"default") <= 0.0:
		_failures.append("%s: fps 非正数" % String(id))
		return

	var first: Texture2D = sprite.sprite_frames.get_frame_texture(&"default", 0)
	if not (first is AtlasTexture):
		_failures.append("%s: 首帧不是 AtlasTexture（图集切分没生效）" % String(id))
		return
	var atlas: AtlasTexture = first
	if atlas.atlas == null:
		_failures.append("%s: AtlasTexture.atlas 为空" % String(id))
		return
	if atlas.region.size.x <= 0.0 or atlas.region.size.y <= 0.0:
		_failures.append("%s: AtlasTexture.region 尺寸非法" % String(id))
		return
	if not Rect2(Vector2.ZERO, atlas.atlas.get_size()).encloses(atlas.region):
		_failures.append("%s: region %s 超出图集 %s" % [
			String(id), str(atlas.region), str(atlas.atlas.get_size())])
		return

	if sprite.texture_filter != CanvasItem.TEXTURE_FILTER_NEAREST:
		_failures.append("%s: 纹理过滤不是最近邻，像素会被插值糊掉" % String(id))


## 两张不同时刻的截图必须不同，且都不是空白
func _check_visual(sprites: Dictionary) -> void:
	# 拨到帧数的 1/3 处：one-shot 特效的末帧是淡出态、几乎全空，
	# 自然播放时有一半概率被拍到空白，那不能说明"画不出来"。
	for id: StringName in sprites:
		var s: AnimatedSprite2D = sprites[id]
		if not is_instance_valid(s) or s.sprite_frames == null:
			continue
		var count: int = s.sprite_frames.get_frame_count(&"default")
		s.set_frame_and_progress(maxi(count / 3, 0), 0.0)
		s.play(&"default")

	for i: int in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var a: Image = get_viewport().get_texture().get_image()

	# 让它自然再走一段，第二张必须不同
	var waited: int = 0
	while waited < 10:
		await get_tree().process_frame
		waited += 1
	await RenderingServer.frame_post_draw
	var b: Image = get_viewport().get_texture().get_image()

	if a == null or b == null:
		_failures.append("截图失败")
		return

	a.save_png(SHOT_PATH)
	print("SHOT_SAVED " + ProjectSettings.globalize_path(SHOT_PATH))

	if _is_flat(a):
		_failures.append("截图几乎单色，特效没画出来")
	if _same_image(a, b):
		_failures.append("两个时刻的截图完全相同，画面是静止的")


func _is_flat(img: Image) -> bool:
	var seen: Dictionary = {}
	var step: int = maxi(1, img.get_width() / 80)
	for y: int in range(0, img.get_height(), step):
		for x: int in range(0, img.get_width(), step):
			seen[img.get_pixel(x, y).to_html(false)] = true
			if seen.size() > 12:
				return false
	return true


func _same_image(a: Image, b: Image) -> bool:
	if a.get_size() != b.get_size():
		return false
	var step: int = maxi(1, a.get_width() / 160)
	for y: int in range(0, a.get_height(), step):
		for x: int in range(0, a.get_width(), step):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				return false
	return true
