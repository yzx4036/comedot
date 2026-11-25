# 调色板明暗处理（LutCanvas）

## 为什么不是 multiply

普通做法是 `COLOR.rgb = src * light`。在像素游戏里这会出两个问题：

1. **发灰**：乘一个 <1 的系数会把所有色相一起往黑拉，饱和度不变但明度全掉，画面变浑
2. **压黄/压蓝**：如果光色本身带色偏，乘上去会让整幅画偏色，原本精心配的调色板被破坏

LutLight2D（Unity 插件）的做法是：**给调色板的每个颜色单独定义一条明暗梯度**。
压暗时不是乘系数，而是换成同色族里更暗的那个真实调色板色。色相与饱和度天然保持。

本实现把这套思路搬到 Godot 4 的 `canvas_item` shader。

## 结构

```
_ToolScript/gen_palette_ramp.py     ← 生成 ramp（读 north 39 色，按色族切阶梯）
        ↓
Assets/Shaders/Ramps/north_ramp_7.png   39×7，X=颜色，Y=明度档，中间行=原色
        ↓
Assets/Shaders/Screen/LutCanvas.gdshader
        ↓
全屏 ColorRect（挂在要被处理的画面之上、UI 之下）
```

## 色族是怎么分的

north 39 色本身是按色族排列的（earth 15 / green 5 / brown 5 / gold 5 / red 3 / gray 6）。
生成器不靠硬编码索引，而是按**声明顺序**扫过去，相邻两色满足任一条就判定换族：

- Δ色相角 > 20°
- chroma 比 > 2×

然后逐块验证 **L\* 单调递增**——不单调就说明切错了，直接报错。实测 6 块全部单调。

> 为什么不用聚类：试过 Lab 的 a\*b\* 单链接聚类，暗色的 chroma 天然偏低，
> 会把 `#14140e`（暗土褐）误判进灰族，还会把土褐（chroma≈18）和金色（chroma≈53）
> 合成一族（色相几乎相同）。按声明顺序切块反而最贴合作者意图。

## ramp 怎么用

- **X 轴** = 调色板第 i 色
- **Y 轴** = 明度档，上暗下亮，中间行是原色
- **族内步进**：`target = clamp(pos + (band - center), 0, len(family)-1)`
  → 色族两端自动钳制：最暗的不能再暗，最亮的不能再亮

shader 用 `textureSize()` 读 ramp 尺寸、从**中间行**读调色板，
所以换 ramp 图（换主题、换档数）都不用改 shader。

## shader 参数

| 参数 | 默认 | 说明 |
|---|---|---|
| `ramp_texture` | — | ramp PNG，必须 `filter_nearest` |
| `dark_steps` | 1.0 | 暗部压几档（P1 的「两档」= dark 1 + bright 1）|
| `bright_steps` | 1.0 | 亮部提几档 |
| `dark_lstar` | 38.0 | 低于此 L\* 走满压深 |
| `bright_lstar` | 62.0 | 高于此 L\* 走满提亮 |
| `mix_amount` | 1.0 | 与原图混合量 |
| `debug_mode` | 0 | 1=显示调色板索引，2=显示档位 |

有效分档（默认参数下）：**L\* < 44 压深一档，44–56 不动，> 56 提亮一档**。

## 图层顺序（关键）

```
ContentLayer (layer 0)     场景、精灵、图块 ← 会被处理
ShadeLayer   (layer 50)    ColorRect + LutCanvas
UILayer      (layer 100)   文字、HUD、按钮 ← 必须在这之上
```

把 UI 放在 shade 之下会把抗锯齿文字量化成调色板色，边缘发硬、小字更糊。

## 已知限制

1. **只适合调色板锁定素材**
   它在调色板内做最近色替换。调色板外的颜色会被吸附——纯红被压成砖红、纯蓝变灰蓝、
   渐变插值的中间色会跳档。真实素材经过 `palette_unify` 统一过色板就不受影响。

2. **自明度驱动 ≠ 光照驱动**
   P1 用像素自身亮度判断"该压还是该提"，本质是调色板空间里的对比度曲线。
   **中间调为主的画面几乎不会变**（实测场景区 ±2 档也只有 −0.5 的 L\* 变化）。
   要让明暗跟着真实光源走，需要 P2 接入光照贴图/遮罩，而不是读屏幕亮度。

3. **每像素 39 次纹理采样**
   调色板越大越慢。39 色在 960×540 下无压力；若将来色板涨到 200+ 色，
   应改成预烘焙的 3D LUT 或索引图。

## 验收

`Game/MyGame/Tests/Regression/CaptureLutCanvas.tscn`（已接入 `runAll.sh`），窗口模式运行。

判据：

- 39 色原色条的每个色块，输出**精确等于** ramp 里该色的期望档位 → 39/39
- 被 shader 改动的像素里，落在调色板外的数量 → 0
- 色相漂移 ≤ 15°
- 场景区饱和度不许掉超 5%（发灰检测）
- 另外硬门禁：脚本挂载、材质就绪、ramp 绑定、两图非空且互不相同
  （这几条是为了防止"没跑起来却报 PASS"的假绿）

反向用例已验证：把 `int band = clamp(center + ...)` 改成 `center - ...`，
断言立刻报 `SWATCH 8/39` 并逐色列出期望值。

产物：`~/_Proj/_assets/lut-canvas/index.html`（三档对比 + ramp + 每色映射表）。
