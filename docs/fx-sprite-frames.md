# 特效管线：pixelfx → SpriteFrames

## 为什么要有这一步

pixelfx 导出的是「一张大图 + 帧坐标的 JSON」（Aseprite 图集格式），
Godot 的 `AnimatedSprite2D` 要的是 `SpriteFrames`（每个动画帧一个 `Texture2D`）。
中间必须有一层转换，否则图集没法直接用。

转换不用复制像素：每帧是一个 `AtlasTexture`，`region` 指向大图里的一块。

```
pixelfx render.mjs --gif --sheet
        ↓
<name>.png（图集） + <name>.json（帧坐标 + fps + loop）
        ↓  Game/MyGame/Tools/BuildFxSpriteFrames.tscn
<name>_frames.tres（SpriteFrames，帧都是 AtlasTexture）
        ↓
AnimatedSprite2D.sprite_frames
```

## 现有素材

| 特效 | 图集 | 帧数 | fps | loop | 说明 |
|---|---|---:|---:|---|---|
| `sword-slash` | 680×520 | 13 | 30 | false | 近战月牙刀弧，导出 24 帧但尾部 11 帧近全空已裁 |
| `talisman-burn` | 1008×896 | 56 | 30 | false | 中式符纸燃烧，本项目按 pixelfx 契约新写 |
| `rune-circle` | 1360×1200 | 120 | 30 | true | 地面法阵展开 |
| `arrow` | 336×192 | 18 | 30 | true | 箭矢飞行 |

素材在 `Game/MyGame/Assets/Images/FX/`，生成的资源在 `Game/MyGame/Resources/FX/`。

## 重新生成

```bash
godot --headless --path . Game/MyGame/Tools/BuildFxSpriteFrames.tscn
```

脚本会扫 `Assets/Images/FX/*.json`，逐个生成 `.tres` 并**重新加载验证**帧数、
fps 真的落进了文件（不是只在内存里对）。

### 裁尾部空帧

pixelfx 导出的图集末尾常有几帧近乎全空（`sword-slash` 的 18~23 帧完全空白、
12~17 帧覆盖率不足 0.5%）。不裁的话：

- one-shot 播完会有半秒"什么都没有"的空档
- 循环播放时会有大半时间看不到东西

判据：帧的不透明像素占比低于 `0.004` 就从尾部砍掉。
注意只裁**尾部**，中间的空帧不能动（可能是刻意的停顿）。

## 用法

```gdscript
var sprite := AnimatedSprite2D.new()
sprite.sprite_frames = load("res://Game/MyGame/Resources/FX/talisman-burn_frames.tres")
sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # 像素美术必须
sprite.play(&"default")
```

`texture_filter` 一定要显式设为 `NEAREST`。项目级的
`textures/canvas_textures/default_texture_filter=0` 虽然是最近邻，
但节点自己设一次更稳（换项目设置时不会悄悄糊掉）。

## 验收

`CheckFxPlayback`（已接入 `runAll.sh`）：

- 静态：帧数 > 0、首帧是有效的 `AtlasTexture`、`region` 不越出图集、过滤是 NEAREST
- 动态：把特效拨回第 0 帧重新播，采样 `current_frame` 必须出现多个不同值
- 视觉（窗口模式）：两张不同时刻的截图必须不同且非空白

特效展示台：`Game/MyGame/Scenes/Testbeds/FxShowcase.tscn`（F6 直接看，2×2 排布，左浅底右暗底）。

## 注意

- **one-shot 特效的末帧几乎是空的**。在展示或截图时先 `set_frame_and_progress(n/3, 0)`
  拨到有内容的帧位，否则会拍到"什么都没有"
- 这批特效的原始配色是偏西幻的青蓝/紫色，**没有过 `palette_unify` 刷 north 色板**。
  实测结论见工作流文档：实心形体（刀光/箭矢）刷了有效，光晕型（法阵）刷了会毁辨识度
