#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# new_project.sh — 以 comedot 为框架的新游戏项目脚手架
#
#   1. 克隆框架 → 建「项目框架仓」：origin=项目框架仓，upstream=框架上游（只读）
#   2. 在框架仓的 Game/ 挂载「游戏业务仓」（Game/ 即该仓仓库根）
#   3. 按 anchor.conf 锚定当前 comedot 目录结构，生成游戏层骨架与启动契约
#
# 用法：new_project.sh --proj <Proj> [选项]
# 详细说明见 _ToolScript/README.md
# ---------------------------------------------------------------------------

set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
load_anchor


# region 参数

PROJ=""
PREFIX="$DEFAULT_REPO_PREFIX"
OWNER="$DEFAULT_OWNER"
ROOT="$HOME/_Proj/_godot"
GAME_FOLDER=""
TITLE=""
FW_SOURCE=""
FW_BRANCH="$DEFAULT_FRAMEWORK_BRANCH"
DRY_RUN=0
NO_PUSH=0
CREATE_REMOTE=0

FW_REPO=""
GAME_REPO=""
WORKSPACE=""

usage() {
	cat <<'EOF'
用法: new_project.sh --proj <项目名> [选项]

必填:
  --proj NAME             游戏项目名，如 <Proj>（仓名 = Comedot_<prefix><NAME>）

选项:
  --prefix NAME           仓库前缀，默认 GDGameProj → Comedot_<Prefix><Proj>
  --owner NAME            GitHub 账号/组织，默认 yzx4036
  --root PATH             工作区根目录，默认 ~/_Proj/_godot（项目落在 <root>/<框架仓名>）
  --game-folder NAME      Game/ 下的游戏目录名，默认 MyGame
  --title TEXT            override.cfg 的 config/name，默认等于 --game-folder
  --framework-source SRC  框架来源（URL 或本地路径），默认 git@github.com:<owner>/comedot.git
  --framework-branch B    框架分支，默认 develop
  --create-remote         用 gh 创建两个 GitHub 私有仓（需 gh 已登录）
  --no-push               只建本地，不推送
  --dry-run               只打印计划，不落盘

示例:
  new_project.sh --proj <Proj> --create-remote
  new_project.sh --proj <Proj> --root /tmp/ws --no-push --game-folder <Proj>
EOF
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--proj)              PROJ=${2:-}; shift 2 ;;
			--prefix)            PREFIX=${2:-}; shift 2 ;;
			--owner)             OWNER=${2:-}; shift 2 ;;
			--root)              ROOT=${2:-}; shift 2 ;;
			--game-folder)       GAME_FOLDER=${2:-}; shift 2 ;;
			--title)             TITLE=${2:-}; shift 2 ;;
			--framework-source)  FW_SOURCE=${2:-}; shift 2 ;;
			--framework-branch)  FW_BRANCH=${2:-}; shift 2 ;;
			--create-remote)     CREATE_REMOTE=1; shift ;;
			--no-push)           NO_PUSH=1; shift ;;
			--dry-run)           DRY_RUN=1; shift ;;
			-h|--help)           usage; exit 0 ;;
			*)                   usage; die "未知参数: $1" ;;
		esac
	done
}

# endregion


# region 工具

# DRY_RUN 时不真正执行
run() {
	if [ "$DRY_RUN" = "1" ]; then
		printf '[DRY ] %s\n' "$*"
		return 0
	fi
	"$@"
}

# 生成 Game 层文件：内容从 stdin 读；已存在则跳过（绝不覆盖用户文件）
scaffold_file() {
	local rel=$1
	local path="$WORKSPACE/Game/$rel"

	if [ -f "$path" ]; then
		log_info "已存在，跳过: Game/$rel"
		cat >/dev/null
		return 0
	fi

	if [ "$DRY_RUN" = "1" ]; then
		log_info "[DRY] 生成 Game/$rel"
		cat >/dev/null
		return 0
	fi

	mkdir -p "$(dirname "$path")" || die "无法创建目录: $(dirname "$path")"
	cat > "$path" || die "写入失败: $path"
	log_ok "生成 Game/$rel"
}

# 建目录 + .gitkeep
scaffold_dir() {
	local rel=$1
	local path="$WORKSPACE/Game/$rel"

	if [ -d "$path" ]; then return 0; fi
	if [ "$DRY_RUN" = "1" ]; then
		log_info "[DRY] 建目录 Game/$rel"
		return 0
	fi
	mkdir -p "$path" || die "无法创建目录: $path"
	[ -f "$path/.gitkeep" ] || : > "$path/.gitkeep"
}

# endregion


# region 步骤

validate_inputs() {
	[ -n "$PROJ" ] || { usage; die "--proj 必填"; }
	case "$PROJ" in *[!A-Za-z0-9_-]*) die "--proj 只允许字母/数字/下划线/中划线: $PROJ" ;; esac
	case "$PREFIX" in *[!A-Za-z0-9_-]*) die "--prefix 非法: $PREFIX" ;; esac

	GAME_FOLDER=${GAME_FOLDER:-MyGame}
	TITLE=${TITLE:-$GAME_FOLDER}
	case "$GAME_FOLDER" in *[!A-Za-z0-9_-]*) die "--game-folder 只允许字母/数字/下划线/中划线: $GAME_FOLDER" ;; esac

	derive_repo_names "$PROJ" "$PREFIX"
	[ -n "$FW_SOURCE" ] || FW_SOURCE=$(fw_repo_url "$OWNER" "comedot")

	mkdir -p "$ROOT" || die "无法创建工作区根目录: $ROOT"
	ROOT=$(abs_dir "$ROOT") || die "无法解析工作区根目录"
	WORKSPACE="$ROOT/$FW_REPO"

	log_info "项目:      $PROJ"
	log_info "框架仓:    $FW_REPO  (origin=$OWNER/$FW_REPO, upstream=框架上游)"
	log_info "游戏业务仓: $GAME_REPO  (挂载于 <框架仓>/Game)"
	log_info "工作区:    $WORKSPACE"
	log_info "游戏目录:  Game/$GAME_FOLDER  标题: $TITLE"
	log_info "框架来源:  $FW_SOURCE ($FW_BRANCH)"
}

step_create_remotes() {
	[ "$CREATE_REMOTE" = "1" ] || {
		log_info "未指定 --create-remote：假定两个远端已在 GitHub 建好"
		return 0
	}
	require_cmd gh
	if ! gh auth status >/dev/null 2>&1; then
		die "gh 未登录，无法创建远端：先 gh auth login，或去掉 --create-remote 手动建仓"
	fi

	local repo=""
	for repo in "$FW_REPO" "$GAME_REPO"; do
		if gh repo view "$OWNER/$repo" >/dev/null 2>&1; then
			log_warn "远端已存在，跳过创建: $OWNER/$repo"
		else
			log_info "创建私有仓: $OWNER/$repo"
			run gh repo create "$OWNER/$repo" --private || die "创建远端失败: $OWNER/$repo"
		fi
	done
}

step_clone_framework() {
	[ -e "$WORKSPACE" ] && die "目标已存在，拒绝覆盖: $WORKSPACE"

	log_info "克隆框架 → $WORKSPACE"
	run git_env git clone --branch "$FW_BRANCH" "$FW_SOURCE" "$WORKSPACE" \
		|| die "框架克隆失败: ${FW_SOURCE}（检查网络/权限/分支是否存在）"
	[ "$DRY_RUN" = "1" ] && return 0

	cd "$WORKSPACE" || die "无法进入 $WORKSPACE"

	# 框架来源仓变成 upstream（只读），新仓变成 origin
	if git remote get-url origin >/dev/null 2>&1; then
		git remote rename origin upstream || die "重命名 origin → upstream 失败"
	fi
	git remote add origin "$(fw_repo_url "$OWNER" "$FW_REPO")" || die "添加 origin 失败"
	# 防呆：把 upstream 的 pushurl 指向无效值，误推立刻报错而不是污染上游
	git config remote.upstream.pushurl "DISABLED-upstream-is-read-only"
	# origin 尚不可达时，让 fetch 别把 upstream 的分支混进 origin
	git config remote.upstream.tagOpt "--no-tags" 2>/dev/null || true

	log_ok "框架仓远端: origin=$(fw_repo_url "$OWNER" "$FW_REPO")"
	log_ok "              upstream=$FW_SOURCE (push 已禁用)"

	log_info "校验框架锚定…"
	check_framework_anchor "$WORKSPACE" || die "框架结构与 anchor.conf 不符，先更新 _ToolScript/anchor.conf"
	log_ok "框架锚定通过"
}

step_mount_game_repo() {
	local url path
	url=$(fw_repo_url "$OWNER" "$GAME_REPO")
	path="$WORKSPACE/Game"

	if game_repo_mounted "$WORKSPACE"; then
		log_warn "Game/ 已是 git 仓，跳过挂载: $path"
		return 0
	fi

	if [ "$DRY_RUN" = "1" ]; then
		log_info "[DRY] 挂载游戏业务仓 $url → $path"
		return 0
	fi

	mkdir -p "$path" || die "无法创建 $path"

	if remote_reachable "$url" && git_env git clone --quiet "$url" "$path" 2>/dev/null; then
		log_ok "克隆游戏业务仓: $url"
	else
		log_info "游戏业务仓远端不可用/为空 → 本地初始化: $url"
		(
			cd "$path" || exit 1
			git init -q -b develop
			git remote add origin "$url"
		) || die "游戏仓初始化失败"
		log_ok "已初始化游戏仓并绑定 origin"
	fi

	# 统一落到 develop 分支
	(
		cd "$path" || exit 1
		if branch_exists "." develop; then
			git checkout -q develop
		else
			git checkout -q -b develop
		fi
	) || die "游戏仓分支切换失败"
}

step_scaffold_game() {
	log_info "生成游戏层骨架（已存在文件一律跳过）…"

	# 镜像目录（与 GameProjectInitializer.gd 的 leafFolders 对齐）
	local dir=""
	for dir in $GAME_MIRROR_LEAF_DIRS; do
		scaffold_dir "$GAME_FOLDER/$dir"
	done
	for dir in $GAME_OPTIONAL_DIRS; do
		scaffold_dir "$dir"
	done

	# --- 启动契约 -----------------------------------------------------------
	scaffold_file "override.cfg" <<EOF
; Game-local project setting overrides.
; Keep this file at Game/ root because project.godot points to res://Game/override.cfg
;
; 启动契约（对齐 af4bc065 之后的 comedot）：
;   不覆盖 application/run/main_scene ⇒ 走框架启动链
;   IOLogoScene → GameFrame 菜单 → Start 按钮 → GameState.startMainScene()
;   → Settings.mainGameScenePath 由 Game/ComedotProjectSettings.tres 提供

[application]
config/name="$TITLE"

[comedot]
settings/comedotProjectSettingsPath="res://Game/ComedotProjectSettings.tres"

; 需要时解开，按项目改分辨率：
; [display]
; window/size/viewport_width=640
; window/size/viewport_height=360
; window/size/window_width_override=1280
; window/size/window_height_override=720
; window/stretch/mode="viewport"
; window/stretch/scale_mode="integer"
EOF

	scaffold_file "ComedotProjectSettings.tres" <<EOF
[gd_resource type="Resource" script_class="ComedotProjectSettings" format=3]

[ext_resource type="Script" path="res://$FRAMEWORK_SETTINGS_SCRIPT" id="1_settings"]

[resource]
script = ExtResource("1_settings")
mainGameScenePath = "res://Game/$GAME_FOLDER/Scenes/Levels/${GAME_FOLDER}Main.tscn"
EOF

	# --- 占位可玩场景（不依赖任何框架已删除的脚本类）------------------------
	scaffold_file "$GAME_FOLDER/Scenes/Levels/${GAME_FOLDER}Main.tscn" <<EOF
[gd_scene format=3]

[node name="${GAME_FOLDER}Main" type="Node2D"]

[node name="CanvasLayer" type="CanvasLayer" parent="."]

[node name="Background" type="ColorRect" parent="CanvasLayer"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
color = Color(0.0588235, 0.0117647, 0.12, 1)

[node name="TitleLabel" type="Label" parent="CanvasLayer"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -140.0
offset_top = -24.0
offset_right = 140.0
offset_bottom = 0.0
grow_horizontal = 2
grow_vertical = 2
text = "$TITLE"
horizontal_alignment = 1

[node name="HintLabel" type="Label" parent="CanvasLayer"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -140.0
offset_top = 4.0
offset_right = 140.0
offset_bottom = 28.0
grow_horizontal = 2
grow_vertical = 2
text = "占位场景，替换为真实关卡"
horizontal_alignment = 1
EOF

	# --- 文档 --------------------------------------------------------------
	scaffold_file "README.md" <<EOF
# $FW_REPO — Game 层（游戏业务仓）

本仓是 \`$FW_REPO\` 的**游戏业务仓**，仓库根 = 框架仓的 \`Game/\` 目录。
框架仓通过 \`.gitignore: $FRAMEWORK_GAME_IGNORE_RULE\` 忽略整个 \`Game/\`，因此本仓内容不会被上游框架覆盖。

## 双仓职责

| 仓 | 位置 | 管什么 |
|---|---|---|
| \`$FW_REPO\`（框架仓） | 工作区根目录 | comedot 框架层 + 少量框架补丁；origin=本仓，upstream=框架上游 |
| \`$GAME_REPO\`（游戏仓） | 框架仓的 \`Game/\` | 游戏玩法、关卡、美术、UI、配置表、测试 |

## 启动契约

1. 框架 \`project.godot\`：\`$FRAMEWORK_OVERRIDE_SETTING_LINE\`
2. \`Game/override.cfg\`：改 \`config/name\`，把 \`comedot/settings/comedotProjectSettingsPath\` 指向 \`res://Game/ComedotProjectSettings.tres\`
3. \`Game/ComedotProjectSettings.tres\`：\`mainGameScenePath\` = \`res://Game/$GAME_FOLDER/Scenes/Levels/${GAME_FOLDER}Main.tscn\`
4. 运行即走框架启动链：IOLogoScene → GameFrame 菜单 → Start 按钮 → \`GameState.startMainScene()\` → 上面的可玩场景

更细的链路见 \`$GAME_FOLDER/Docs/StartupFlow.md\`。

## 常用操作

\`\`\`bash
# 拉上游框架更新 + 同步本仓（在框架仓根目录执行）
_ToolScript/update_project.sh

# 体检（锚定/启动链/残留引用）
_ToolScript/verify_project.sh
\`\`\`

## 目录

游戏代码与资源一律放本仓，不要往框架根目录的 \`Components/\`、\`Scenes/\`、\`Scripts/\` 里写。
EOF

	scaffold_file "$GAME_FOLDER/README.md" <<EOF
# $TITLE

游戏 \`$GAME_FOLDER\` 的全部内容。

- 关卡场景：\`Scenes/Levels/\`
- 游戏组件：\`Components/\`（沿用框架的组件范式，但只属于本游戏）
- 配置表：框架根 \`_ConfigTables/\` 是框架示例链；本游戏的表放 \`Game/_ConfigTables/\`
- 启动契约：\`Game/override.cfg\` + \`Game/ComedotProjectSettings.tres\`
EOF

	scaffold_file "$GAME_FOLDER/Docs/README.md" <<EOF
# Docs

\`$GAME_FOLDER\` 的设计与工程文档。

- \`StartupFlow.md\`：启动链路（框架 → 游戏）
- \`ProjectMap.md\`：目录地图
- \`FrameworkUpgradeNotes.md\`：框架升级检查清单
EOF

	scaffold_file "$GAME_FOLDER/Docs/StartupFlow.md" <<EOF
# 启动链路

对齐 comedot \`af4bc065\`（删除 \`Scripts/Start.gd\`）之后的启动契约。

1. \`project.godot\` → \`$FRAMEWORK_OVERRIDE_SETTING_LINE\`
2. \`Game/override.cfg\` 覆盖 \`application/config/name\`，并把 \`comedot/settings/comedotProjectSettingsPath\` 指向 \`res://Game/ComedotProjectSettings.tres\`
3. 框架 \`application/run/main_scene\` 未被覆盖 ⇒ 跑 \`$FRAMEWORK_LAUNCH_SCENE\`
4. 商标动画结束（或按键跳过）→ \`$FRAMEWORK_MENU_SCENE\` 主菜单
5. 主菜单 Start 按钮 → \`GameState.startMainScene()\`
6. \`GameState.startMainScene()\` 读取 \`Settings.mainGameScenePath\`
7. 该值来自 \`Game/ComedotProjectSettings.tres\` 的 \`mainGameScenePath\` = \`res://Game/$GAME_FOLDER/Scenes/Levels/${GAME_FOLDER}Main.tscn\`

## 注意

- 不要再写 \`extends Start\`：该框架类已被上游删除（\`af4bc065\`）。
- 需要自定义启动画面时，用普通 \`Control\`/\`Node2D\` 场景，并在 \`override.cfg\` 里覆盖 \`application/run/main_scene\` 指向它。
EOF

	scaffold_file "$GAME_FOLDER/Docs/ProjectMap.md" <<EOF
# 目录地图

\`\`\`text
Game/                                  ← $GAME_REPO 仓库根
├── override.cfg                       启动契约：config/name + Comedot 设置资源路径
├── ComedotProjectSettings.tres        启动契约：mainGameScenePath
├── _ConfigTables/                     本游戏的 Luban 表（Excel/Configs）
└── $GAME_FOLDER/
$(for d in $GAME_MIRROR_LEAF_DIRS; do printf '    ├── %s\n' "$d"; done)
\`\`\`

框架层（不要写游戏内容）：
$(for d in $FRAMEWORK_REQUIRED_DIRS; do printf '    %s\n' "$d"; done)
EOF

	scaffold_file "$GAME_FOLDER/Docs/FrameworkUpgradeNotes.md" <<EOF
# 框架升级检查清单

升级用 \`_ToolScript/update_project.sh\`，它会先体检再合并。合并后人工确认：

- [ ] \`.gitignore\` 仍含 \`$FRAMEWORK_GAME_IGNORE_RULE\`（合并冲突高发点）
- [ ] \`project.godot\` 仍含 \`$FRAMEWORK_OVERRIDE_SETTING_LINE\`
- [ ] 游戏层没有引用已删除的框架类（脚本会扫 \`$GAME_FORBIDDEN_PATTERNS\`）
- [ ] \`ComedotProjectSettings.tres\` 仍在，\`mainGameScenePath\` 指向的场景仍存在
- [ ] 组件/实体基类签名变化（\`Component.gd\`、\`Entity.gd\`）是否需要跟进
- [ ] 打开 Godot 跑一次主场景 + 至少一个手动测试场景
EOF

	scaffold_file ".gitignore" <<EOF
# OS junk
.DS_Store
Thumbs.db
[Dd]esktop.ini

# Godot 本地导入缓存（本仓是 Game/，正常不会出现，兜底）
.godot/

# 框架仓自己的占位说明（框架仓已跟踪同名文件，本仓不重复管理，避免双仓改同一文件）
/Start Making Your Game Here.md
EOF

	log_ok "游戏层骨架生成完毕"
}

step_commit() {
	[ "$DRY_RUN" = "1" ] && return 0

	local game="$WORKSPACE/Game"

	if [ -n "$(git -C "$WORKSPACE" status --porcelain)" ]; then
		log_warn "框架仓出现非预期改动（应只有 Game/ 被忽略）："
		git -C "$WORKSPACE" status --short
	else
		log_ok "框架仓干净：Game/ 边界生效，框架层未被污染"
	fi

	if [ -n "$(git -C "$game" status --porcelain)" ]; then
		git -C "$game" add -A
		git -C "$game" commit -q -F - <<'MSG'
chore: 初始化游戏业务仓骨架

+ 生成 override.cfg 与 Game 层 ComedotProjectSettings.tres 启动契约
+ 建立镜像 comedot 框架结构的游戏层目录与占位可玩场景
+ 补齐游戏层 README 与 Docs（启动链路/目录地图/升级清单）
MSG
		log_ok "游戏仓已提交: $(git -C "$game" log --oneline -1)"
	else
		log_info "游戏仓无改动，跳过提交"
	fi
}

step_verify() {
	[ "$DRY_RUN" = "1" ] && return 0
	[ -x "$SCRIPT_DIR/verify_project.sh" ] || { log_warn "缺少 verify_project.sh，跳过校验"; return 0; }
	"$SCRIPT_DIR/verify_project.sh" --project "$WORKSPACE" || log_warn "锚定校验未全绿，请按提示处理"
}

step_push() {
	if [ "$NO_PUSH" = "1" ]; then
		log_info "--no-push：跳过推送"
		return 0
	fi
	if [ "$DRY_RUN" = "1" ]; then
		log_info "[DRY] 推送两个仓"
		return 0
	fi

	log_info "推送框架仓 → origin"
	git -C "$WORKSPACE" push -u origin HEAD \
		|| log_warn "框架仓推送失败：确认 $OWNER/$FW_REPO 已存在且有权限"
	log_info "推送游戏仓 → origin"
	git -C "$WORKSPACE/Game" push -u origin HEAD \
		|| log_warn "游戏仓推送失败：确认 $OWNER/$GAME_REPO 已存在且有权限"
}

print_summary() {
	cat <<EOF

════════════════════════════════════════════════════════════════
项目脚手架完成
════════════════════════════════════════════════════════════════
  工作区      $WORKSPACE
  框架仓      origin   = $(fw_repo_url "$OWNER" "$FW_REPO")
              upstream = $FW_SOURCE  (push 已禁用)
  游戏业务仓  origin   = $(fw_repo_url "$OWNER" "$GAME_REPO")
              挂载点   = $WORKSPACE/Game

下一步:
  1. Godot 打开 $WORKSPACE/project.godot
  2. 跑主场景验证启动链：IOLogoScene → GameFrame → Start → Game/$GAME_FOLDER/Scenes/Levels/${GAME_FOLDER}Main.tscn
  3. 日常：
       $WORKSPACE/_ToolScript/update_project.sh    # 拉上游框架更新
       $WORKSPACE/_ToolScript/verify_project.sh    # 体检
════════════════════════════════════════════════════════════════
EOF
}

# endregion


main() {
	parse_args "$@"
	require_cmd git
	validate_inputs
	step_create_remotes
	step_clone_framework
	step_mount_game_repo
	step_scaffold_game
	step_commit
	step_verify
	step_push
	print_summary
}

main "$@"
