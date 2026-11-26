extends Node
## 把 pixelfx 导出的图集（PNG + Aseprite 格式 JSON）转成 Godot 的 SpriteFrames 资源。
##
## 为什么要转：pixelfx 出的是「一张大图 + 帧坐标」，Godot 的 AnimatedSprite2D 要的是
## SpriteFrames 里每个动画帧一个 Texture2D。用 AtlasTexture 引用同一张大图，不复制像素。
##
## 会做的处理：
##   1. 读 JSON 的 meta.pixelfx 拿 frameSize / fps / loop
##   2. 逐帧建 AtlasTexture
##   3. **裁掉尾部空帧**：pixelfx 的 sword-slash 末尾 6 帧全空、12~17 帧几乎全空，
##      不裁的话 one-shot 播完会有半秒空档，循环播放时还会周期性"消失"
##   4. 存成 .tres，AnimatedSprite2D 直接引用
##
## 用法（scene 模式，需渲染无关但要走资源加载）：
##   godot --headless --path . Game/MyGame/Tools/BuildFxSpriteFrames.tscn

const SRC_DIR: String = "res://Game/MyGame/Assets/Images/FX"
const OUT_DIR: String = "res://Game/MyGame/Resources/FX"

## 尾部帧的"有内容"判据：不透明像素占比低于这个值就算空
const EMPTY_COVERAGE: float = 0.004

var _failures: PackedStringArray = PackedStringArray()
var _built: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)

	var dir: DirAccess = DirAccess.open(SRC_DIR)
	if dir == null:
		print("FAIL 打不开源目录: " + SRC_DIR)
		get_tree().quit(1)
		return

	var names: PackedStringArray = PackedStringArray()
	for file: String in dir.get_files():
		if file.ends_with(".json"):
			names.append(file.get_basename())
	names.sort()

	if names.is_empty():
		print("FAIL 源目录里没有 json: " + SRC_DIR)
		get_tree().quit(1)
		return

	for name: String in names:
		_build_one(name)

	print("BUILT %d/%d" % [_built, names.size()])
	if _failures.is_empty():
		print("VERDICT PASS")
		get_tree().quit(0)
	else:
		for f: String in _failures:
			print("  FAIL " + f)
		print("VERDICT FAIL")
		get_tree().quit(1)


func _build_one(name: String) -> void:
	var json_path: String = SRC_DIR.path_join(name + ".json")
	var png_path: String = SRC_DIR.path_join(name + ".png")

	var text: String = FileAccess.get_file_as_string(json_path)
	if text.is_empty():
		_failures.append("%s: 读不到 json" % name)
		return
	var data: Variant = JSON.parse_string(text)
	if typeof(data) != TYPE_DICTIONARY:
		_failures.append("%s: json 解析失败" % name)
		return

	var pixelfx: Dictionary = data.get("meta", {}).get("pixelfx", {})
	var fps: float = float(pixelfx.get("fps", 30))
	var should_loop: bool = bool(pixelfx.get("loop", false))
	var frame_size: Array = pixelfx.get("frameSize", [])

	var frames: Array = data.get("frames", [])
	if frames.is_empty():
		_failures.append("%s: json 里没有 frames" % name)
		return

	var atlas: Texture2D = load(png_path) as Texture2D
	if atlas == null:
		_failures.append("%s: 读不到 png（可能还没 import）" % name)
		return

	var image: Image = atlas.get_image()
	if image == null:
		_failures.append("%s: 取不到图像数据" % name)
		return
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	# 先算出每帧的覆盖率，用来裁尾部空帧
	var coverages: PackedFloat32Array = PackedFloat32Array()
	for f: Variant in frames:
		coverages.append(_coverage(image, (f as Dictionary).get("frame", {})))

	var keep: int = coverages.size()
	while keep > 1 and coverages[keep - 1] < EMPTY_COVERAGE:
		keep -= 1
	var dropped: int = coverages.size() - keep

	var sprite_frames: SpriteFrames = SpriteFrames.new()
	var anim: StringName = &"default"
	sprite_frames.set_animation_speed(anim, fps)
	sprite_frames.set_animation_loop(anim, should_loop)
	# 新建的 SpriteFrames 自带一个 default 动画（1 帧空），先清掉它的帧
	while sprite_frames.get_frame_count(anim) > 0:
		sprite_frames.remove_frame(anim, 0)

	for i: int in keep:
		var rect: Dictionary = (frames[i] as Dictionary).get("frame", {})
		var region: Rect2 = Rect2(
			float(rect.get("x", 0)),
			float(rect.get("y", 0)),
			float(rect.get("w", frame_size[0] if frame_size.size() > 0 else 0)),
			float(rect.get("h", frame_size[1] if frame_size.size() > 1 else 0)),
		)
		var tex: AtlasTexture = AtlasTexture.new()
		tex.atlas = atlas
		tex.region = region
		sprite_frames.add_frame(anim, tex)

	var out_path: String = OUT_DIR.path_join(name + "_frames.tres")
	var err: int = ResourceSaver.save(sprite_frames, out_path)
	if err != OK:
		_failures.append("%s: 保存失败 err=%d" % [name, err])
		return

	# 保存后重新加载，确认帧数和 loop 真的落进文件（不是只在内存里对）
	var check: SpriteFrames = load(out_path) as SpriteFrames
	if check == null:
		_failures.append("%s: 保存后加载不回来" % name)
		return
	var got_frames: int = check.get_frame_count(anim)
	if got_frames != keep:
		_failures.append("%s: 落盘帧数 %d ≠ 期望 %d" % [name, got_frames, keep])
		return
	if not is_equal_approx(check.get_animation_speed(anim), fps):
		_failures.append("%s: fps 落盘值不对" % name)
		return

	_built += 1
	print("OK   %-14s 帧 %3d（裁掉尾部 %d）  fps %.0f  loop %s  → %s" % [
		name, got_frames, dropped, fps, str(should_loop), out_path,
	])


## 单帧的不透明像素占比。按 stride 扫原始字节，比逐像素 get_pixel 快得多
func _coverage(image: Image, rect: Dictionary) -> float:
	var rx: int = int(rect.get("x", 0))
	var ry: int = int(rect.get("y", 0))
	var rw: int = int(rect.get("w", 0))
	var rh: int = int(rect.get("h", 0))
	if rw <= 0 or rh <= 0:
		return 0.0

	var data: PackedByteArray = image.get_data()
	var stride: int = image.get_width() * 4
	var opaque: int = 0
	for y: int in range(ry, ry + rh):
		var rowStart: int = y * stride + rx * 4
		for x: int in range(rw):
			if data[rowStart + x * 4 + 3] > 16:
				opaque += 1
	return float(opaque) / float(rw * rh)
