# 游戏业务分层模型（单仓 · Game 下多业务）

> 决策日期：2026-11-18。取代此前的「框架仓 + 独立 Game 业务仓」双仓模型。
> 依据：跟随上游 `InvadingOctopus/comedot` 的单仓形态；`Game/` 由框架仓自己跟踪，
> 但一个仓里可以并列多个**互相独立**的游戏业务，用 `Game/override.cfg` 选当前激活的那个。
>
> **脚本已全部收敛到本模型**（2026-11-21）：`new_project.sh` 只建一个仓、业务骨架统一交给
> `new_game.sh`；`lib.sh` 的布局识别只认 `single`，`Game/.git` 存在时判为 `legacy` 并只打印
> 迁移警告。旧双仓形态不再有工具支持，只是没删检测逻辑。

## 1. 目录形态

```text
<项目仓>/                          ← 一次 clone = 框架 + 游戏业务，全部在一个仓
├── project.godot                  ← 框架层，跟随上游
├── Components/ Entities/ Scenes/ Scripts/ UI/ Assets/ addons/ …   ← 框架层
├── _ToolScript/                   ← 本工具
└── Game/
    ├── override.cfg               ★ 唯一开关：指当前激活的游戏业务
    ├── README.md
    ├── MyGame/            ← 游戏业务 A（示例或某款游戏），结构自成一体的
    │   ├── ComedotProjectSettings.tres   ← 本业务自己的启动设置
    │   ├── Scenes/ Scripts/ Components/ Entities/ Resources/ Assets/ UI/ Tests/ Docs/
    │   └── override.cfg（可选）   ← 本业务专属的额外项目设置片段（分辨率等）
    └── <Proj>/                     ← 游戏业务 B，与 A 同级、完全独立
        └── ComedotProjectSettings.tres
```

规则：

1. **`Game/` 由框架仓跟踪**（不再 `gitignore`）。clone 下来即有示例业务可跑。
2. **每个业务目录自成一体**：有自己的 `ComedotProjectSettings.tres`、自己的场景/脚本/资产/文档，不引用别的业务目录。
3. **只有 `Game/override.cfg` 是共享的**，它是「当前用哪个业务」的选择器，由 `select_game.sh` 生成。
4. 示例业务可以选择保留或删除（`rm -rf Game/<Example>` + 切到自己的业务即可），不影响框架层。

## 2. 启动契约

```ini
; Game/override.cfg（由 _ToolScript/select_game.sh 生成）
[application]
config/name="MyGame"

[comedot]
settings/comedotProjectSettingsPath="res://Game/MyGame/ComedotProjectSettings.tres"
```

```gdscript
; Game/<业务>/ComedotProjectSettings.tres
[gd_resource type="Resource" script_class="ComedotProjectSettings" format=3]

[ext_resource type="Script" path="res://addons/Comedot/ComedotProjectSettings.gd" id="1_settings"]

[resource]
script = ExtResource("1_settings")
mainGameScenePath = "res://Game/<业务>/Scenes/Levels/<业务>Main.tscn"
```

运行链路：`project.godot` 的 `project_settings_override` → `Game/override.cfg` → 该业务的 `ComedotProjectSettings.tres` →
`IOLogoScene` → `GameFrame` 菜单 → Start → `GameState.startMainScene()` → 该业务首个可玩场景。

⚠️ 上游 `af4bc065` 已删除 `Scripts/Start.gd`：启动脚本一律普通 `Control`/`Node2D`，**不要 `extends Start`**。

## 3. 为什么这样比双仓好

| 维度 | 双仓（框架仓 + 嵌套 Game 仓） | 单仓多业务（本模型） |
|---|---|---|
| 一次 clone | 框架仓里 `Game/` 是空的/需另挂业务仓 | 自带示例业务，能直接跑 |
| git 状态 | 一个目录两套 git 状态，`/Game/*` 边界靠 `.gitignore` 维持 | 一个仓一个状态 |
| 双跟踪陷阱 | `Game/override.cfg`、`Game/Start Making Your Game Here.md` 两边都可能被跟踪 | 不存在 |
| 多游戏并存 | 每个游戏要一对仓（框架副本 × N） | 一个仓里多个 `Game/<业务>/` |
| 框架补丁回流上游 | 每个副本各带一套补丁，容易漂移 | 单条提交即可提 PR |
| 游戏代码公开边界 | 游戏仓私有，框架仓公开 | **框架仓公开 ⇒ Game/ 下所有业务一起公开**（见 §5） |

## 4. 框架补丁 → 上游 PR 纪律

目标是「其他地方 clone 出来的项目改了框架，也能干净地提 PR 给上游」：

1. **一个改动一个提交**：框架层改动单独成提交，不混入游戏内容提交（提交信息写清是框架层还是 Game 层）。
2. 框架层提交尽量小而自洽（改一个 API / 修一个 bug / 加一个 hook），便于 `git format-patch` 或 cherry-pick 提到上游。
3. 提交前先 `_ToolScript/verify_project.sh`：确保没有把游戏内容塞进框架目录。
4. 提 PR 的常规流程：在项目仓里找到那条框架层提交 → 在 `InvadingOctopus/comedot` 的 fork 上 cherry-pick → 开 PR。
   - 涉及框架设计问题先在上游仓提 issue，再动手。
5. 上游合并回来：`update_project.sh`（单仓形态下 `Game/` 一起参与合并，但上游不碰业务目录，冲突面只在框架层）。

## 5. 公开 vs 私有（必须按项目定）

框架仓（`yzx4036/comedot`）是**公开**的。单仓改造后，`Game/` 下的所有业务都会随仓公开。

- **公开框架仓**：`Game/` 里只放**最小示例业务**（占位场景 + 契约文件 + 一份 README），不含商业计划、里程碑、美术采购清单。
- **私有项目仓**：用它自己的 `Game/<真实业务>/`（如 <Proj>）。做法是 fork 框架仓 → 私有化 → 在 `Game/` 下建自己的业务。

只要某个业务的文档里有 `CommercialPlan.md`、`DevPlan.md`、里程碑、定价策略等，**它就属于私有项目仓，不能进公开框架仓**。

## 6. 从双仓迁移到单仓

在框架仓根执行（`Game/` 当前是嵌套 git 仓时）：

```bash
# 1) 备份嵌套业务仓（可随时还原）
mv Game ../$(basename "$PWD")-Game-backup-$(date +%Y%m%d)

# 2) 让框架仓跟踪 Game/
git rm --cached -r Game 2>/dev/null || true
#   .gitignore 删除 `/Game/*` 两行；保留上游的 override.cfg 规则，但放行 Game 层的那一个：
#     override.cfg
#     !/Game/override.cfg

# 3) 把业务内容搬进来（保留历史用 subtree，不要历史就拷贝）
git subtree add --prefix=Game <业务仓URL> develop --squash
#   或：cp -R ../<备份>/Game ./Game

# 4) 补齐契约：每个业务生成 ComedotProjectSettings.tres，切换开关
_ToolScript/select_game.sh <业务目录名>

# 5) 体检 + 提交
_ToolScript/verify_project.sh
git add -A Game .gitignore && git commit -m "feat: Game 业务并入仓内，改为单仓多业务"
```

嵌套业务仓的远端仓库之后只做归档（不再推送），历史留在 GitHub 上可查。
