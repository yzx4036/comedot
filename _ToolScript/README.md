# _ToolScript — comedot 游戏项目脚手架与更新流水线

以 comedot 为框架开游戏项目时用的建仓/建业务/更新/体检脚本。
所有结构判断都读 `anchor.conf`（锚定规格），框架升级导致结构变化时**只改 `anchor.conf`**。

> **模型已切换为「单仓 · Game 下多业务」**（2026-11-18 决策）：框架与游戏业务在同一个仓，
> `Game/` 下可并列多个互相独立的业务，用 `Game/override.cfg` 选当前激活的那个。
> 完整模型、公开/私有边界、从双仓迁移步骤见 `docs/multi-game-layout.md`。

```
_ToolScript/
├── anchor.conf          锚定规格：框架必需目录/文件、游戏层契约、启动链、命名规范
├── lib.sh               共用函数（日志、git 环境、布局识别、锚定校验）
├── new_game.sh          ★ 新建同级游戏业务（Game/<Name>/ + 契约文件）
├── select_game.sh       ★ 切换激活业务（重写 Game/override.cfg）
├── update_project.sh    拉上游框架更新（单仓下 Game/ 一起合并，脏文件按重叠判定）
├── verify_project.sh    体检：只读，自动识别单仓/双仓布局
└── new_project.sh       【已废弃】双仓旧模型：建框架仓+独立业务仓（仅供参考迁移前历史）
```

## 常用命令

```bash
_ToolScript/new_game.sh --name <Proj> --title "武侠" --activate   # 建业务并切过去
_ToolScript/select_game.sh                                       # 看有哪些业务、当前激活谁
_ToolScript/select_game.sh <Proj>                                 # 切换
_ToolScript/verify_project.sh                                    # 体检（0=过 1=有 FAIL）
_ToolScript/update_project.sh --dry-run                          # 看上游带来什么
_ToolScript/update_project.sh                                    # 合并上游框架更新
```

## 双仓模型

```
~/your-workspace/
└── Comedot_<Prefix><Proj>/          ← 框架仓（工作区根 = Godot 项目根）
    ├── project.godot                 ← 框架层，基本不动
    ├── Components/ Entities/ Scenes/ Scripts/ UI/ ...   ← 框架层
    ├── _ToolScript/                  ← 本工具（随框架仓分发）
    └── Game/                         ← 游戏业务仓（这个目录就是一个独立 git 仓的仓库根）
        ├── override.cfg
        ├── ComedotProjectSettings.tres
        └── MyGame/           ← 游戏内容
```

| 仓 | 命名 | 远端 |
|---|---|---|
| 框架仓 | `Comedot_<prefix><项目名>` | `origin`=项目框架仓；`upstream`=框架上游（push 已禁用） |
| 游戏业务仓 | `Comedot_<prefix><项目名>Game` | `origin`=游戏仓；挂在框架仓的 `Game/` |

框架仓 `.gitignore` 里 `/Game/*` 是硬边界：**框架仓永远不跟踪 Game/ 内容**，上游框架更新也就永远碰不到游戏内容。

## 启动契约（对齐 `af4bc065` 之后的 comedot）

上游 `af4bc065` 删掉了 `Scripts/Start.gd`，旧的 `extends Start` 启动写法已失效。现在的契约是纯配置，不需要游戏层写启动脚本：

1. `project.godot`：`config/project_settings_override="res://Game/override.cfg"`
2. `Game/override.cfg`：设 `config/name`，并把 `comedot/settings/comedotProjectSettingsPath` 指到 `res://Game/ComedotProjectSettings.tres`
3. `Game/ComedotProjectSettings.tres`：`mainGameScenePath` = 游戏首个可玩场景
4. 运行 → `IOLogoScene` → `GameFrame` 主菜单 → Start 按钮 → `GameState.startMainScene()` → 上面的可玩场景

好处：框架根的 `ComedotProjectSettings.tres` 保持上游原样（上游改它也不会串到游戏），游戏设置全在 Game 层。

### 两种合法变体

| 变体 | 做法 | 生成者 |
|---|---|---|
| A 框架启动链 | `override.cfg` **不写** `run/main_scene`，玩家先看框架 Logo + 主菜单，Start 进游戏 | `new_project.sh`（新版默认） |
| B 游戏自己的启动画面 | `override.cfg` 覆盖 `run/main_scene` 指向 `Game/<项目>/Scenes/Boot/*Start.tscn`，该脚本是**普通 `Control`**（只做标题 + Start 按钮），主场景仍走 `Game/ComedotProjectSettings.tres` | 编辑器插件 `addons/Comedot/GameProjectInitializer.gd`；现有 <Proj> 项目采用此变体 |

两种变体都**不需要** `extends Start`。

## 用法

### 新建项目

```bash
# 在任意位置执行（需要 git；--create-remote 另需 gh 已登录）
_ToolScript/new_project.sh --proj <Proj> --create-remote

# 只建本地不碰远端
_ToolScript/new_project.sh --proj <Proj> --root ~/_Proj/_godot --no-push

# 看清要做什么
_ToolScript/new_project.sh --proj <Proj> --dry-run
```

| 参数 | 说明 | 默认 |
|---|---|---|
| `--proj NAME` | 项目名，决定两个仓名 | 必填 |
| `--prefix NAME` | 仓库前缀 | `GDGameProj` |
| `--owner NAME` | GitHub 账号/组织 | `yzx4036` |
| `--root PATH` | 工作区根；项目落在 `<root>/<框架仓名>` | `~/_Proj/_godot` |
| `--game-folder NAME` | `Game/` 下的游戏目录名 | `MyGame` |
| `--title TEXT` | `override.cfg` 的 `config/name` | 同 `--game-folder` |
| `--framework-source SRC` | 框架来源（URL 或本地路径） | `git@github.com:<owner>/comedot.git` |
| `--framework-branch B` | 框架分支 | `develop` |
| `--create-remote` | 用 `gh` 建两个私有仓 | 关 |
| `--no-push` | 只建本地 | 关 |

脚本保证：**已存在的文件一律跳过，不覆盖**；建完立刻自检框架锚定；框架仓必须保持干净（`Game/` 边界生效）。

### 更新（拉上游框架）

```bash
cd <框架仓>
_ToolScript/update_project.sh --dry-run    # 先看上游带来哪些提交、哪些文件与本地冲突
_ToolScript/update_project.sh              # 合并 upstream/<branch> → 当前分支
_ToolScript/update_project.sh --sync-game --push   # 顺带快进游戏仓并推送框架仓
```

行为要点：
- 框架仓工作区不干净 → 直接拒绝（合并失败会污染改动）
- 列出上游提交 + 上游改动文件 + **双方都改过的高冲突文件**
- 上游改动若触及 `Game/` → 报警（意味着 `/Game/*` 边界被上游改掉了）
- 冲突 → 列出冲突文件并默认 `git merge --abort` 回滚；要现场用 `--keep-conflicts`

### 体检

```bash
cd <框架仓>
_ToolScript/verify_project.sh        # 0=通过；1=有 FAIL
```

查：框架必需目录/文件、`project_settings_override`、`.gitignore` 的 `/Game/*`、`Game/` 是否真被忽略、双仓远端布局、`override.cfg` 与 `ComedotProjectSettings.tres` 指向是否存在、是否还引用已删除的框架锚点、游戏层所有 `res://` 引用是否有效。

## 已知坑

| 坑 | 说明 |
|---|---|
| `extends Start` | 上游 `af4bc065` 已删除 `Scripts/Start.gd`；`verify_project.sh` 会把残留引用报 FAIL |
| `.gitignore` 合并冲突 | 上游会改动 `.gitignore`；本地必须保住 `# Game/...` 注释 + `/Game/*` 两行，合并时优先保本地 |
| 上游误推 | `upstream` 的 `pushurl` 被设成无效值 `DISABLED-upstream-is-read-only`，误 `git push upstream` 会立刻失败 |
| Windows | 脚本按 POSIX 写，Windows 用 git-bash 跑；不依赖 GNU-only 参数 |
| 变量紧跟中文要加花括号 | `"$branch：落后"` 在 bash 3.2（macOS）下会把中文首字节吞进变量名 → `unbound variable`。所有贴中文的变量一律写 `${branch}` |
| 双仓重复跟踪 | 框架仓自己跟踪了 `Game/Start Making Your Game Here.md`，游戏仓若也提交它，框架更新会把它改成「有未提交改动」。游戏仓 `.gitignore` 已默认忽略该文件 |

## 测试记录

被测对象：`git@github.com:yzx4036/Comedot_<Prefix><Proj>.git`（框架仓）+ `git@github.com:yzx4036/Comedot_<Prefix><Proj>Game.git`（游戏仓），以及本地离线端到端。

| 用例 | 手段 | 结果 |
|---|---|---|
| 新建（离线） | 框架源=本地 comedot；远端不存在→本地 `git init` | 双仓建成，体检 0 FAIL / 0 WARN |
| 新建（含推送） | `url.<bare>.insteadOf` 把两个 GitHub URL 影子到本地 bare 仓 | 两个仓 `develop` 均推送成功、上游跟踪已设置 |
| 体检（真实 <Proj>） | 浅克隆真实双子仓组成项目布局 | 4 FAIL / 3 WARN（见下） |
| 更新（真实 12 提交） | 项目回退到 <Proj> 分叉点 `a85751c2`，upstream=真实 `yzx4036/comedot` | fetch 8s，12 提交 / 236 文件，干净合并，`/Game/*` 边界保住，体检仍 PASS |
| 更新（冲突） | 本地改上游同改的那一行（`addons/Comedot/plugin.cfg`） | 检出 CONFLICT、列出文件、自动 `merge --abort`、退出码 2、工作区干净 |
| 更新（`--keep-conflicts`） | 同上 | 保留 `MERGE_HEAD` 现场供手工解决 |
| 更新（脏工作区） | 改 `project.godot` 不提交 | 拒绝执行并列出改动 |
| 游戏仓同步 | bare 仓模拟「另一台机器」提交 | 不带 `--sync-game` 只报告落后 1；带则快进成功 |
| dry-run | 全部用例先跑 `--dry-run` | 不落盘、只输出待合并提交与高冲突文件 |

真实 <Proj> 项目被查出的问题（改造前的老骨架）：

1. `Game/MyGame/Scripts/Boot/GameInitStart.gd` 仍 `extends Start` —— `Start` 类已被上游 `af4bc065` 删除
2. `Game/MyGame/Scenes/Levels/MyGameMain.tscn` 仍引用 `res://Scripts/Start.gd`
3. 缺 `Game/ComedotProjectSettings.tres`，主场景只能吃框架默认值
4. `override.cfg` 未重定向 `comedot/settings/comedotProjectSettingsPath`

按本工具的启动契约改造后（删 `extends Start`、补 Game 层 `ComedotProjectSettings.tres`、`override.cfg` 重定向设置资源），体检即可转绿。
