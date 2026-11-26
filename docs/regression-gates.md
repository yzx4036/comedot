# 回归门禁判据说明

`production-readiness.md` 是 `_ToolScript/audit_production.sh` 自动生成的快照，**不要手改**。
本文是手写的配套说明：每个检查验的是什么、为什么这么验、什么情况下会假绿。

命令入口：`Game/MyGame/Tests/Regression/runAll.sh`

| 模式 | 行为 |
|---|---|
| 无参数 | 全部检查，含三个需要在窗口下真实渲染的项 |
| `--skip-screenshot` | 跳过三个窗口模式项并记 SKIP（CI / 纯 SSH 用）|

---

## 检查清单

| 检查 | 模式 | 核心断言 |
|---|---|---|
| `CheckTestbed` | headless | 功能索引的结构与交互（28 项） |
| `CheckAllDemoScenes` | headless | 41 个演示场景逐个开/关不崩 |
| `CheckConfigTables` | headless | 框架示例表加载与字段读取 |
| `CheckBusinessConfigTables` | headless | 业务表加载、枚举、跨表取数 |
| `CheckConfigDrivenGameplay` | 场景 | 改表 → 行为跟着变（57 项） |
| `ProbeDemoScene` | headless | 单场景探针自身可用 |
| `CaptureTestbedScreenshot` | 窗口 | 功能索引与演示视图能截出图 |
| `CaptureLutCanvas` | 窗口 | 39 色逐色精确匹配 + 输出不跑出调色板 |
| `CheckFxPlayback` | 窗口 | SpriteFrames 真的在 AnimatedSprite2D 里推进 |
| `CaptureLevelShade` | 窗口 | 明暗层生效 + UI 未被 shader 压到下面 |

---

## 三个带防假绿设计的检查

### `CaptureLutCanvas`

**验什么**：`LutCanvas` shader 的输出是否严格落在 north 39 色内，且分档算得对。

**怎么验**：测试台把 39 个原色块排成一条，截图后取每块中心像素，
用与 shader **同一套公式**（L\* → t → offset → band）算出期望档位，
再和 ramp 表里的期望颜色逐一比对。

**假绿防线**：
- 脚本挂载、材质就绪、ramp 绑定，任一失败直接 FAIL（曾出现过测试台解析失败
  但 VERDICT 仍报 PASS 的情况，就是缺这几条）
- A/B 两张图必须非空白且互不相同
- 反向用例已验证：把 `center + floor(offset)` 改成 `center - ...`，
  断言报 `SWATCH 8/39` 并逐色列出期望值

### `CheckFxPlayback`

**验什么**：SpriteFrames 资源存在 ≠ 能播。图集切分、AtlasTexture 区域、
fps、纹理过滤任何一环错了，表现为空白、错位或糊边。

**怎么验**：静态断言帧数 > 0、首帧是 `AtlasTexture`、region 不越出图集、
`texture_filter == NEAREST`；动态断言把特效拨回第 0 帧重新播，然后采样
`current_frame`，必须出现过多个不同值。

**踩过的坑**：one-shot 特效（`loop=false`）播完会停在末帧，而末帧通常是
淡出态、几乎全空。直接采会误判成"动画没动"，所以要**先拨回第 0 帧**。

### `CaptureLevelShade`

**验什么**：LutCanvas 挂进 `LevelPlay` 后 (a) 真的起作用，(b) 没有把 UI 一起处理掉。

**怎么验 (b)**：不用 HUD 文字做判据 —— 文字有抗锯齿边缘，会和下层混合，
分不清"被量化"还是"正常混色"。改为运行时往 `UILayer` 塞一块调色板里
**不存在**的纯品红 `#ff00ff`：
- 在 shader 之上 → 原样保留，判据通过
- 在 shader 之下 → 必被吸附成最近调色板色

**反向用例已验证**：把 `ShadeLayer.layer` 从 5 改成 15，
品红被量化成 `#909290`（north 灰族亮端），检查报红并指明原因。

---

## 图层顺序是硬约束

```
ContentLayer (0)   游戏内容：背景、敌人、图块     ← 会被处理
ShadeLayer   (5)   ColorRect + LutCanvas
UILayer      (10)  文字、HUD、按钮                ← 必须在这之上
```

顺序错了不会崩，只会让文字被量化、小字边缘发硬 —— 所以必须有 `CaptureLevelShade` 这条来钉住。

---

## 已知噪音（不算失败）

| 现象 | 说明 |
|---|---|
| `ERROR: 1 resources still in use at exit` | 引擎退出收尾，`runAll.sh` 已过滤 |
| `Terminated: 15` | runner 收进程时产生，已用 pid + `wait` 收窄 |
| `Settings.gd Error 7: Cannot load settings file` | 首次运行没有用户配置，会自动创建 |
