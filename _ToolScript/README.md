# _ToolScript — comedot 游戏项目脚手架与更新流水线

以 comedot 为框架开游戏项目时用的建仓/建业务/更新/体检脚本。
所有结构判断都读 `anchor.conf`（锚定规格），框架升级导致结构变化时**只改 `anchor.conf`**。

> **唯一支持形态：单仓 · Game 下多业务**（2026-11-18 决策）：一个项目 = 一个仓，框架与
> `Game/<业务>/` 同仓；`Game/` 下可并列多个互相独立的业务，用 `Game/override.cfg` 选当前激活的那个。
> 完整模型、公开/私有边界、从双仓迁移步骤见 `docs/multi-game-layout.md`。
> 历史的双仓模型（`Game/` 是嵌套 git 仓）已废弃：脚本检测到只打印迁移警告，不再提供完整支持。

```
_ToolScript/
├── anchor.conf          锚定规格：框架必需目录/文件、业务契约、启动链、命名规范
├── lib.sh               共用函数（日志、git 环境、布局识别、锚定校验）
├── new_project.sh       ★ 从零开一个项目：克隆框架 → 建仓 → 建首个业务（调 new_game.sh）
├── new_game.sh          ★ 新建同级游戏业务（Game/<Name>/ + 契约文件）
├── select_game.sh       ★ 切换激活业务（重写 Game/override.cfg）
├── update_project.sh    拉上游框架更新（Game/ 一起合并，脏文件按重叠判定）
├── verify_project.sh    体检：只读，自动识别 single / legacy 布局
└── link_upstream.sh     clone 后接上框架上游（upstream，push 自动禁用）
```

## 常用命令

```bash
new_project.sh --proj <Proj> --game <业务> --title "标题" --create-remote   # 开新项目
new_game.sh --name <Proj> --title "武侠" --activate                        # 同仓并列新业务并切过去
select_game.sh                                                             # 看有哪些业务、当前激活谁
select_game.sh <Proj>                                                      # 切换
verify_project.sh                                                          # 体检（0=过 1=有 FAIL）
update_project.sh --dry-run                                                # 看上游带来什么
update_project.sh                                                          # 合并上游框架更新
link_upstream.sh                                                           # 新 clone 接上游
```

## 模型

```
~/your-workspace/
└── Comedot_<Prefix><Proj>/        ← 唯一的仓（origin=项目私仓，upstream=框架上游）
    ├── project.godot                 ← 框架层，基本不动
    ├── Components/ Entities/ Scenes/ Scripts/ UI/ ...   ← 框架层（跟随上游）
    ├── _ToolScript/                  ← 本工具（随仓分发）
    └── Game/                         ← 由本仓跟踪，不是独立仓
        ├── override.cfg              ← 业务选择器（select_game.sh 生成，勿手改）
        ├── MyGame/                   ← 示例业务（可删）
        └── <业务>/                   ← 自己的业务，结构与 MyGame 同级、互相独立
            ├── game.cfg              ← 业务声明（标题等）
            ├── ComedotProjectSettings.tres   ← 该业务的主场景
            └── Scenes/ Scripts/ Components/ ... 
```

| 层 | 归谁 | 规则 |
|---|---|---|
| 框架层 | 上游 | 改动保持「一条提交一个改动」，便于 cherry-pick 提 PR |
| `Game/` | 本项目 | 上游不该碰；`Game/<业务>/` 之间不得互相 `res://` 引用 |

## 启动契约（对齐 `af4bc065` 之后的 comedot）

上游 `af4bc065` 删掉了 `Scripts/Start.gd`，旧的 `extends Start` 启动写法已失效。现在的契约是纯配置：

1. `project.godot`：`config/project_settings_override="res://Game/override.cfg"`
2. `Game/override.cfg`：设 `config/name`，把 `comedot/settings/comedotProjectSettingsPath` 指到 `res://Game/<业务>/ComedotProjectSettings.tres`
3. `Game/<业务>/ComedotProjectSettings.tres`：`mainGameScenePath` = 该业务首个可玩场景
4. 运行 → `IOLogoScene` → `GameFrame` 主菜单 → Start → `GameState.startMainScene()` → 上面的场景

框架根的 `ComedotProjectSettings.tres` 保持上游原样（上游改它也不会串到游戏），游戏设置全在 `Game/` 层。

### 两种合法变体

| 变体 | 做法 | 生成者 |
|---|---|---|
| A 框架启动链 | 不写 `run/main_scene`，玩家先看框架 Logo + 主菜单，Start 进游戏 | 默认 |
| B 业务自己的启动画面 | `Game/<业务>/game.cfg` 写 `run/main_scene` 指向该业务的 `Control` 场景（只做标题 + Start），主场景仍走 `ComedotProjectSettings.tres` | 手工 |

两种变体都**不需要** `extends Start`。

## 用法

### 开新项目

```bash
# 在任意位置执行（需要 git；--create-remote 另需 gh 已登录）
new_project.sh --proj <Proj> --game <业务> --create-remote

# 只建本地不碰远端
new_project.sh --proj <Proj> --root ~/_Proj/_godot --no-push

# 看清要做什么
new_project.sh --proj <Proj> --dry-run
```

| 参数 | 说明 | 默认 |
|---|---|---|
| `--proj NAME` | 项目名，决定仓名 `Comedot_<prefix><NAME>` | 必填 |
| `--prefix NAME` | 仓名前缀 | `GDGameProj` |
| `--owner NAME` | GitHub 账号/组织 | `yzx4036` |
| `--root PATH` | 工作区根；项目落在 `<root>/<仓名>` | `~/_Proj/_godot` |
| `--game NAME` | `Game/` 下的业务目录名 | 同 `--proj` |
| `--title TEXT` | 业务的 `config/name`（窗口标题） | 同 `--game` |
| `--framework-source SRC` | 框架来源（URL 或本地路径） | `git@github.com:<owner>/comedot.git` |
| `--framework-branch B` | 框架分支 | `develop` |
| `--create-remote` | 用 `gh` 建**一个**私有仓 | 关 |
| `--no-push` | 只建本地 | 关 |

脚本保证：
- **只建一个仓**；业务骨架统一由 `new_game.sh` 生成（不在本脚本里复制模板，避免两处漂移）
- 已存在的文件一律跳过，不覆盖
- 建完立刻自检框架锚定 + 全量体检
- 提交只 `git add Game/`，框架层保持上游原样

### 更新（拉上游框架）

```bash
update_project.sh --dry-run          # 先看上游带来哪些提交、哪些文件与本地冲突
update_project.sh                    # 合并 upstream/<branch> → 当前分支
update_project.sh --push             # 顺带推送
```

行为要点：
- 列出上游提交 + 上游改动文件 + **双方都改过的高冲突文件**
- 工作区脏文件只在与上游改动**重叠**时才阻塞（`Game/` 业务目录上游不会碰，不挡合并）
- 上游改动若触及 `Game/` → 报警（上游本不该碰业务目录）
- 冲突 → 列出冲突文件并默认 `git merge --abort` 回滚；要现场用 `--keep-conflicts`
- `--sync-game` 已无效（单仓模型没有独立业务仓），传了只打警告

### 体检

```bash
verify_project.sh        # 0=无 FAIL；1=有 FAIL
```

查：框架必需目录/文件、`project_settings_override`、`Game/` 是否真被本仓跟踪（`.gitignore` 里不该再有 `/Game/*`）、远端布局、`Game/override.cfg` 的三个字段（`config/name` / 设置资源路径 / 主场景覆盖）、每个业务的 `mainGameScenePath`、业务间是否越界引用、是否还引用已删除的框架锚点、游戏层所有 `res://` 引用是否有效。

布局判定：

| 布局 | 判据 | 处理 |
|---|---|---|
| `single` | `Game/` 是普通目录 | 全量校验（唯一支持形态） |
| `legacy` | `Game/.git` 存在（双仓旧模型） | 只警告提示迁移，跳过按单仓标准的业务层校验 |
| `none` | 没有 `Game/` | 警告：用 `new_game.sh` 建第一个业务 |

## 已知坑

| 坑 | 说明 |
|---|---|
| `extends Start` | 上游 `af4bc065` 已删除 `Scripts/Start.gd`；`verify_project.sh` 会把残留引用报 FAIL |
| 手改 `Game/override.cfg` | 它是 `select_game.sh` 的生成物，下次切换会被覆盖 |
| 业务间互相引用 | `Game/A` 引用 `res://Game/B/...` 会被体检报 FAIL，用共享资源或下沉到框架层 |
| 上游误推 | `upstream` 的 `pushurl` 被设成无效值 `DISABLED-upstream-is-read-only`，误 `git push upstream` 会立刻失败 |
| Windows | 脚本按 POSIX 写，Windows 用 git-bash 跑；不依赖 GNU-only 参数 |
| 变量紧跟中文要加花括号 | `"$name（…）"` 在 bash 3.2（macOS）下会把中文首字节吞进变量名 → `unbound variable`。所有贴中文的变量一律写 `${name}` |
| 编辑器改写被跟踪文件 | `--import` / 打开编辑器会重排 `project.godot`、归一化 `*.import`、升级 csproj 的 SDK 版本。跑完 `git status` 清点，别把这类改动提进仓库 |

## 测试记录

单仓模型改造后（2026-11-21）的实测：

| 用例 | 手段 | 结果 |
|---|---|---|
| 开新项目（离线） | 框架源=本地 comedot，`--proj TestProj --game TestGame --no-push` | 只建 1 个仓；`Game/TestGame` 由 `new_game.sh` 生成并激活；提交只含 `Game/`；体检 PASS 0 FAIL / 0 WARN |
| 体检（single） | 上例项目 | PASS |
| 体检（legacy） | 同项目加 `Game/.git` | 布局判 `legacy`，打印两条迁移警告，业务层跳过，PASS 0 FAIL / 1 WARN |
| 体检（legacy + 残留 `/Game/*`） | `.gitignore` 追加 `/Game/*` | FAIL「.gitignore 仍忽略 Game/」，引导删规则并迁移 |
