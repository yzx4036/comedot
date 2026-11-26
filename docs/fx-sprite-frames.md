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

## 光晕型特效的色域收敛（fx_tone.py）

### 为什么不能靠 palette_unify

`palette_unify.py` 只处理 `alpha >= 240` 的实心像素。实测：

| 特效 | 光晕占比（0<alpha<240） | 光晕主色相 |
|---|---:|---|
| `rune-circle` | **91.1%** | 270°(紫) / 240°(蓝) |
| `sword-slash` | **87.9%** | 180°(青) / 210° |
| `talisman-burn` | 34.8% | 30°(橙金) |
| `arrow` | 29.3% | 无彩 |

而 north 39 色的色相只覆盖 **35°–124°**（黄橙金绿），**根本没有青(180°)、蓝(240°)、紫(270°)**。
所以法阵刷色板的实际效果是：91% 的像素没被处理，剩下的实心核被拉向 46°的棕——
结果是"魔法感没了，也没变协调"。

### 这个工具的做法

不动色相、不动明度、不动 alpha，只压饱和度上限：

```
H' = H          # 紫色还是紫色，辨识度在
S' = min(S, cap)
V' = V          # 光晕的亮心和层次结构保留
```

```bash
~/miniconda3/bin/python _ToolScript/fx_tone.py \
  --src Game/MyGame/Assets/Images/FX/rune-circle.png \
  --out Game/MyGame/Assets/Images/FX/rune-circle_tone.png \
  --sat-cap 0.45
```

实测：法阵 880908 像素，平均饱和 0.708 → 0.431，**色相漂移仅 0.83°**（HSV 往返的量化误差）。

### 选档

同一帧叠在土褐底上对比四档（vision 复核结论）：

| 档 | 土褐底观感 | 颜色辨识度保留 |
|---|---|---:|
| 原图 | 紫色最艳、发光最冲，色相对撞 | 100% |
| 0.55 | 仍明显是紫色法阵，冲突减轻 | ~90–95% |
| **0.45** | **淡紫偏灰，与土褐底最协调，白核/光晕仍在** | **~75–85%** |
| 0.35 | 接近白灰刻线，魔法紫味明显弱 | ~60–70% |

**当前默认 0.45**（土褐主场景）。暗底场景或需要更强魔法记忆点时可用 0.55 或原图。

### 一个反直觉的联动

收敛越狠，特效颜色离调色板越近，**越多像素会掉进 LutCanvas 的吸附范围**：

| 版本 | 到最近 north 色距离中位 | 距离 ≤ 0.06 占比（会被吸附） |
|---|---:|---:|
| 原图 | 0.124 | 5.5% |
| sat<0.55 | 0.118 | 19.0% |
| sat<0.45 | 0.113 | **20.8%** |
| sat<0.35 | 0.098 | 29.9% |

所以收敛必须配合 **图层隔离**：特效挂在明暗层之上，根本不进 LutCanvas 的处理范围。
只靠调 `max_match_distance` 会被这个联动坑到。

### 生成器怎么知道用哪版

`BuildFxSpriteFrames` 的约定：**存在 `<name>_tone.png` 就优先用它**，日志里标 `源 收敛版`。

`CheckFxPlayback` 有一条硬断言钉住这个行为：有收敛版的图集时，
`SpriteFrames` 的 `AtlasTexture.atlas.resource_path` 必须指向 `_tone.png`。
（写错时播放完全正常，只有颜色悄悄变回原图，肉眼很难发现。）

反向用例已验证：把 tres 里的路径改回原图，断言报
`rune-circle 存在收敛版但 SpriteFrames 指向了 .../rune-circle.png`。

## 零散注意

- **one-shot 特效的末帧几乎是空的**。在展示或截图时先 `set_frame_and_progress(n/3, 0)`
  拨到有内容的帧位，否则会拍到"什么都没有"
- 全部特效的原始配色偏西幻的青蓝紫。处理结论：
  - 实心形体（刀光/箭矢）→ `palette_unify` 刷色板有效
  - 光晕型（法阵，91% 是光晕）→ **不能刷色板**，走 `fx_tone.py` 色域收敛
- `arrow` 素材本身偏细（白色细线 + 速度线），在杂乱底上视觉权重不足。
  这是 pixelfx 原始素材的问题；需要时可以让它自带一点发光或拖尾
