extends Node2D
## 特效播放展示台：把 pixelfx 生成的 SpriteFrames 真的放进 AnimatedSprite2D 播。
##
## 这一步的意义：SpriteFrames 资源存在 ≠ 能播。图集切分、AtlasTexture 区域、
## fps/loop、纹理过滤任何一环错了，表现出来都是空白、错位或糊边。
##
## 画布固定 960×540，2×2 排四个特效，背景用 north 调色板色以便判断颜色是否协调。

const CANVAS_SIZE: Vector2i = Vector2i(960, 540)

## 特效清单：资源路径 + 显示名
const EFFECTS: Array = [
	[&"sword-slash", "刀光 sword-slash", "res://Game/MyGame/Resources/FX/sword-slash_frames.tres"],
	[&"talisman-burn", "符纸燃烧 talisman-burn", "res://Game/MyGame/Resources/FX/talisman-burn_frames.tres"],
	[&"rune-circle", "法阵 rune-circle", "res://Game/MyGame/Resources/FX/rune-circle_frames.tres"],
	[&"arrow", "箭矢 arrow", "res://Game/MyGame/Resources/FX/arrow_frames.tres"],
]

## 背景两档土色，用来判断特效在明暗底上的可读性
const BG_LIGHT: String = "#504530"
const BG_DARK: String = "#14140e"

var _sprites: Dictionary = {}
var _labels: Array[Label] = []


func _ready() -> void:
	_build_background()
	_build_sprites()
	_build_labels()


## 每个特效的 AnimatedSprite2D，键为特效 id
func get_sprites() -> Dictionary:
	return _sprites


func get_canvas_size() -> Vector2i:
	return CANVAS_SIZE


func _build_background() -> void:
	var bg: Node2D = Node2D.new()
	bg.name = "Background"
	add_child(bg)
	# 左半浅土色、右半暗色，一次截图就能看到两种底上的表现
	bg.draw.connect(func() -> void:
		bg.draw_rect(Rect2(0, 0, CANVAS_SIZE.x * 0.5, CANVAS_SIZE.y), Color.html(BG_LIGHT))
		bg.draw_rect(Rect2(CANVAS_SIZE.x * 0.5, 0, CANVAS_SIZE.x * 0.5, CANVAS_SIZE.y), Color.html(BG_DARK))
	)


func _build_sprites() -> void:
	var host: Node2D = Node2D.new()
	host.name = "FxHost"
	add_child(host)

	var cell: Vector2 = Vector2(CANVAS_SIZE.x * 0.5, CANVAS_SIZE.y * 0.5)
	for i: int in EFFECTS.size():
		var entry: Array = EFFECTS[i]
		var id: StringName = entry[0]
		var path: String = entry[2]

		var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		sprite.name = String(id)
		sprite.centered = true
		# 像素美术：最近邻采样，否则缩放后糊边
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

		var frames: SpriteFrames = load(path) as SpriteFrames
		if frames != null:
			sprite.sprite_frames = frames
			sprite.autoplay = &"default"
			sprite.play(&"default")
			# one-shot 特效播完会停在最后一帧（通常是淡出末态、几乎全空），
			# 展示台里让它隔一会儿重播，否则截图会拍到"什么都没有"
			if not frames.get_animation_loop(&"default"):
				sprite.animation_finished.connect(_on_one_shot_finished.bind(sprite))
		else:
			Debug.printError("特效资源加载失败: " + path, "FxShowcase")

		var column: int = i % 2
		var row: int = i / 2
		sprite.position = cell * Vector2(float(column) + 0.5, float(row) + 0.5)

		host.add_child(sprite)
		_sprites[id] = sprite


## one-shot 播完 → 停一拍再重播，让展示台一直在动
func _on_one_shot_finished(sprite: AnimatedSprite2D) -> void:
	await get_tree().create_timer(0.5).timeout
	if is_instance_valid(sprite) and not sprite.is_playing():
		sprite.play(&"default")


func _build_labels() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.name = "UILayer"
	layer.layer = 10
	add_child(layer)

	for i: int in EFFECTS.size():
		var entry: Array = EFFECTS[i]
		var column: int = i % 2
		var row: int = i / 2

		var label: Label = Label.new()
		label.text = String(entry[1])
		label.position = Vector2(
			float(column) * CANVAS_SIZE.x * 0.5 + 10.0,
			float(row) * CANVAS_SIZE.y * 0.5 + 6.0,
		)
		label.add_theme_font_size_override(&"font_size", 13)
		# 左半是浅底用深字、右半是暗底用亮字
		label.add_theme_color_override(&"font_color",
			Color.html("#14140e") if column == 0 else Color.html("#d8c8a8"))
		layer.add_child(label)
		_labels.append(label)
