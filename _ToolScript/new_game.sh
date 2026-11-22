#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# new_game.sh — 在「单仓 · Game 下多业务」模型里新建一个同级游戏业务
#
#   生成 Game/<Name>/ 自成一体的一套：目录骨架 + ComedotProjectSettings.tres
#   + 占位可玩场景 + README/Docs；不影响已有业务，不动框架层。
#
# 用法：new_game.sh --name <Proj> [--root <项目根>] [--title 标题] [--activate] [--dry-run]
# 模型说明见 docs/multi-game-layout.md
# ---------------------------------------------------------------------------

set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
load_anchor


# region 参数

NAME=""
ROOT=""
TITLE=""
ACTIVATE=0
DRY_RUN=0

usage() {
	cat <<'EOF'
用法: new_game.sh --name <业务名> [选项]

必填:
  --name NAME        业务目录名，同时用作场景/脚本前缀（字母开头，字母数字下划线）

选项:
  --root PATH        项目根（含 project.godot 且 Game/ 为普通目录）；默认从当前目录向上查找
  --title TEXT       override.cfg 里的 config/name，默认等于 --name
  --activate         创建后立即切换 Game/override.cfg 到该业务
  --dry-run          只打印计划

示例:
  new_game.sh --name <Proj> --activate
  new_game.sh --name Cd_Prototype --title "原型试验"
EOF
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--name)     NAME=${2:-}; shift 2 ;;
			--root)     ROOT=${2:-}; shift 2 ;;
			--title)    TITLE=${2:-}; shift 2 ;;
			--activate) ACTIVATE=1; shift ;;
			--dry-run)  DRY_RUN=1; shift ;;
			-h|--help)  usage; exit 0 ;;
			*)          usage; die "未知参数: $1" ;;
		esac
	done
}

# endregion


# region 工具

run() {
	if [ "$DRY_RUN" = "1" ]; then
		printf '[DRY ] %s\n' "$*"
		return 0
	fi
	"$@"
}

# 生成文件（内容走 stdin）；已存在则跳过
scaffold_file() {
	local rel=$1
	local path="$GAME_DIR/$rel"

	if [ -f "$path" ]; then
		log_info "已存在，跳过: Game/${NAME}/$rel"
		cat >/dev/null
		return 0
	fi
	if [ "$DRY_RUN" = "1" ]; then
		log_info "[DRY] 生成 Game/${NAME}/$rel"
		cat >/dev/null
		return 0
	fi
	mkdir -p "$(dirname "$path")" || die "无法创建目录: $(dirname "$path")"
	cat > "$path" || die "写入失败: $path"
	log_ok "生成 Game/${NAME}/$rel"
}

scaffold_dir() {
	local rel=$1
	local path="$GAME_DIR/$rel"
	[ -d "$path" ] && return 0
	if [ "$DRY_RUN" = "1" ]; then
		log_info "[DRY] 建目录 Game/${NAME}/$rel"
		return 0
	fi
	mkdir -p "$path" || die "无法创建目录: $path"
	[ -f "$path/.gitkeep" ] || : > "$path/.gitkeep"
}

# endregion


# region 步骤

resolve_root() {
	if [ -n "$ROOT" ]; then
		ROOT=$(abs_dir "$ROOT") || die "目录不存在: $ROOT"
	else
		ROOT=$(find_project_root_any) || die "当前目录向上找不到 Godot 项目（project.godot）；用 --root 指定"
	fi
	[ -f "$ROOT/project.godot" ] || die "不是项目根（缺 project.godot）: $ROOT"

	local layout
	layout=$(project_layout "$ROOT")
	case "$layout" in
		single) log_info "项目: ${ROOT}（单仓多业务布局）" ;;
		legacy) warn_legacy_layout "$ROOT"
		        log_warn "继续执行：新业务会落到旧形态的 Game/ 目录里" ;;
		*)      log_info "项目: ${ROOT}（Game/ 尚未建立，将创建）" ;;
	esac

	[ -n "$NAME" ] || { usage; die "--name 必填"; }
	case "$NAME" in
		[A-Za-z]*) ;;
		*) die "--name 必须以字母开头: $NAME" ;;
	esac
	case "$NAME" in
		*[!A-Za-z0-9_]*) die "--name 只允许字母/数字/下划线: $NAME" ;;
	esac

	TITLE=${TITLE:-$NAME}
	GAME_DIR="$ROOT/$GAME_ROOT_REL/$NAME"
	[ -e "$GAME_DIR" ] && die "业务已存在，拒绝覆盖: $GAME_DIR"
}

create_structure() {
	local dir=""
	log_info "创建业务目录 Game/${NAME}/"
	for dir in $GAME_MIRROR_LEAF_DIRS; do
		scaffold_dir "$dir"
	done
	# 业务自己的配置表目录（可选；不给业务表就不要建，避免空壳目录）
	for dir in ${GAME_OPTIONAL_DIRS:-}; do
		scaffold_dir "$dir"
	done
	log_ok "目录骨架就绪"
}

create_contract_files() {
	local main_scene="${GAME_ISOLATION_PREFIX}${NAME}/Scenes/Levels/${NAME}Main.tscn"

	# 业务声明（标题等）：select_game.sh 会读这里生成共享的 Game/override.cfg
	scaffold_file "game.cfg" <<EOF
; 本业务声明：select_game.sh 切到 Game/${NAME} 时会读取这里的 config/name
; 需要自定义启动画面时，加上 run/main_scene="res://Game/${NAME}/Scenes/Boot/XXX.tscn"
[application]
config/name="${TITLE}"
EOF

	scaffold_file "$GAME_PER_BUSINESS_SETTINGS" <<EOF
[gd_resource type="Resource" script_class="ComedotProjectSettings" format=3]

[ext_resource type="Script" path="res://${FRAMEWORK_SETTINGS_SCRIPT}" id="1_settings"]

[resource]
script = ExtResource("1_settings")
mainGameScenePath = "res://${main_scene}"
EOF

	scaffold_file "Scenes/Levels/${NAME}Main.tscn" <<EOF
[gd_scene format=3]

[node name="${NAME}Main" type="Node2D"]

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
text = "${TITLE}"
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
}

create_docs() {
	scaffold_file "README.md" <<EOF
# ${TITLE}

单仓模型下的一个**独立游戏业务**，位于 \`Game/${NAME}/\`。

- 自带启动设置：\`ComedotProjectSettings.tres\`（\`mainGameScenePath\` 指向本业务首个可玩场景）
- 不引用 \`Game/\` 下其他业务目录
- 切换到本业务：\`_ToolScript/select_game.sh ${NAME}\`
- 本业务专属的额外项目设置（分辨率等）可写在本目录的 \`override.cfg\`，切换时会被并入根 \`Game/override.cfg\`
EOF

	scaffold_file "Docs/README.md" <<EOF
# ${TITLE} · Docs

本业务的工程与设计文档。启动链路见 \`StartupFlow.md\`。
EOF

	scaffold_file "Docs/StartupFlow.md" <<EOF
# 启动链路（${TITLE}）

1. \`project.godot\`：\`${FRAMEWORK_OVERRIDE_SETTING_LINE}\`
2. \`Game/override.cfg\` 把 \`comedot/settings/comedotProjectSettingsPath\` 指向 \`res://Game/${NAME}/ComedotProjectSettings.tres\`
3. \`Game/${NAME}/ComedotProjectSettings.tres\` 的 \`mainGameScenePath\` = \`res://Game/${NAME}/Scenes/Levels/${NAME}Main.tscn\`
4. 运行 → \`${FRAMEWORK_LAUNCH_SCENE}\` → \`${FRAMEWORK_MENU_SCENE}\` → Start → \`GameState.startMainScene()\` → 本业务可玩场景

## 注意
- 启动脚本用普通 \`Control\`/\`Node2D\`，**不要** \`extends Start\`（该类随上游 \`af4bc065\` 删除）
- 需要自定义启动画面：\`override.cfg\` 里覆盖 \`application/run/main_scene\`，并同步本业务 \`override.cfg\` 片段
EOF
}

maybe_activate() {
	[ "$ACTIVATE" = "1" ] || { log_info "未切换激活业务（需要时跑 _ToolScript/select_game.sh ${NAME}）"; return 0; }
	local arg=""
	arg="$NAME"
	if [ "$DRY_RUN" = "1" ]; then
		"$SCRIPT_DIR/select_game.sh" "$arg" --root "$ROOT" --title "$TITLE" --dry-run
	else
		"$SCRIPT_DIR/select_game.sh" "$arg" --root "$ROOT" --title "$TITLE"
	fi
}

print_summary() {
	cat <<EOF

════════════════════════════════════════════════════════════════
新业务已创建：Game/${NAME}/   标题：${TITLE}
════════════════════════════════════════════════════════════════
  下一步:
    1. Godot 打开 $ROOT/project.godot
    2. 切换/确认激活业务: _ToolScript/select_game.sh ${NAME}
    3. 体检:             _ToolScript/verify_project.sh
    4. 替换 Game/${NAME}/Scenes/Levels/${NAME}Main.tscn 为真实关卡
════════════════════════════════════════════════════════════════
EOF
}

# endregion


main() {
	parse_args "$@"
	require_cmd git
	resolve_root
	create_structure
	create_contract_files
	create_docs
	maybe_activate
	[ "$DRY_RUN" = "1" ] || print_summary
}

main "$@"
