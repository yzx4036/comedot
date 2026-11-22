#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# select_game.sh — 切换「单仓 · Game 下多业务」模型里当前激活的游戏业务
#
#   重写 Game/override.cfg，让它指向 Game/<业务>/ComedotProjectSettings.tres。
#   业务自己的额外项目设置（如分辨率）写在 Game/<业务>/override.cfg，会被追加进来——
#   但该片段只允许放 [application]/[comedot] 之外的小节（这两个由本脚本负责）。
#
# 用法：select_game.sh [<业务名>] [--list] [--root <项目根>] [--dry-run]
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
MAIN_SCENE=""
DRY_RUN=0
SHOW_LIST=0

usage() {
	cat <<'EOF'
用法: select_game.sh [业务名] [选项]

  不带业务名 / --list    列出所有业务并标出当前激活项
  --root PATH            项目根（含 project.godot）；默认从当前目录向上查找
  --title TEXT           config/name；默认沿用当前值，否则等于业务名
  --main-scene PATH      覆盖 application/run/main_scene（res:// 路径）；不给则沿用当前值
  --dry-run              只打印将要写的内容

示例:
  select_game.sh                # 看有哪些业务
  select_game.sh <Proj>          # 切到 <Proj>
  select_game.sh MyGame --main-scene res://Game/MyGame/Scenes/Boot/GameInitStart.tscn
EOF
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--list)       SHOW_LIST=1; shift ;;
			--root)       ROOT=${2:-}; shift 2 ;;
			--title)      TITLE=${2:-}; shift 2 ;;
			--main-scene) MAIN_SCENE=${2:-}; shift 2 ;;
			--dry-run)    DRY_RUN=1; shift ;;
			-h|--help)    usage; exit 0 ;;
			-*)           usage; die "未知参数: $1" ;;
			*)            [ -z "$NAME" ] || { usage; die "只能指定一个业务名（多余: $1）"; }; NAME=$1; shift ;;
		esac
	done
}

# endregion


# region 步骤

resolve_root() {
	if [ -n "$ROOT" ]; then
		ROOT=$(abs_dir "$ROOT") || die "目录不存在: $ROOT"
	else
		ROOT=$(find_project_root_any) || die "当前目录向上找不到 Godot 项目（project.godot）"
	fi
	[ -f "$ROOT/project.godot" ] || die "不是项目根（缺 project.godot）: $ROOT"

	case "$(project_layout "$ROOT")" in
		single) ;;
		legacy) warn_legacy_layout "$ROOT"
		        log_warn "继续执行：重写的是旧形态的 Game/override.cfg" ;;
		*)      die "缺少 Game/ 目录: $ROOT/$GAME_ROOT_REL" ;;
	esac

	OVERRIDE_PATH="$ROOT/$GAME_OVERRIDE_REL"
}

print_list() {
	local active line name marker
	active=$(active_game_business "$ROOT" 2>/dev/null || true)

	printf '\n项目: %s\n' "$ROOT"
	printf '当前激活: %s\n\n' "${active:-（未设置 / override.cfg 缺失）}"
	printf '%-24s %s\n' "业务" "状态"
	printf '%-24s %s\n' "────────────────────" "────"
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		marker=""
		[ "$line" = "$active" ] && marker="← 激活中"
		printf '%-24s %s\n' "$line" "$marker"
	done <<EOF
$(list_game_businesses "$ROOT")
EOF
	if [ -f "$OVERRIDE_PATH" ]; then
		printf '\nGame/override.cfg:\n'
		sed 's/^/    /' "$OVERRIDE_PATH"
	fi
	printf '\n'
}

validate_business() {
	local games
	games=$(list_game_businesses "$ROOT")
	[ -n "$games" ] || die "Game/ 下没有任何业务目录；先用 new_game.sh 建一个"

	if ! printf '%s\n' "$games" | grep -qxF "$NAME"; then
		log_err "业务不存在: ${NAME}；现有业务："
		printf '%s\n' "$games" | sed 's/^/    /'
		exit 1
	fi

	local settings="$ROOT/$GAME_ROOT_REL/$NAME/$GAME_PER_BUSINESS_SETTINGS"
	if [ ! -f "$settings" ]; then
		log_warn "业务缺 ${GAME_PER_BUSINESS_SETTINGS}: Game/${NAME}/（启动找不到主场景，切换后 Play 会报错）"
		log_warn "补齐方式: _ToolScript/new_game.sh --name ${NAME}（已存在目录时会跳过已有文件，只补缺的契约文件）"
		return 0
	fi

	local main_scene
	main_scene=$(grep -m1 '^mainGameScenePath' "$settings" | sed -E 's/.*=[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/' || true)
	if [ -n "$main_scene" ] && [ ! -f "$ROOT/${main_scene#res://}" ]; then
		log_warn "${GAME_PER_BUSINESS_SETTINGS} 的 mainGameScenePath 指向不存在的场景: ${main_scene}"
	fi
}

# 业务片段的合规性检查：不允许重新定义 [application] / [comedot]
check_fragment() {
	local fragment="$ROOT/$GAME_ROOT_REL/$NAME/override.cfg"
	[ -f "$fragment" ] || return 0
	if grep -qE '^\[(application|comedot)\]' "$fragment"; then
		log_warn "Game/${NAME}/override.cfg 含 [application]/[comedot] 小节，会被本脚本生成的段落覆盖"
		log_warn "该片段只应放其他小节（如 [display]）；config/name 用 --title、主场景用 --main-scene"
	fi
}

read_current_key() {
	local key=$1
	[ -f "$OVERRIDE_PATH" ] || return 1
	grep -m1 "^${key}=" "$OVERRIDE_PATH" | sed -E 's/^[^=]+=["]?([^"]+)["]?[[:space:]]*$/\1/'
}

write_override() {
	local title current_main fragment_path tmp declare_path declare_title declare_main active
	fragment_path="$ROOT/$GAME_ROOT_REL/$NAME/override.cfg"
	declare_path="$ROOT/$GAME_ROOT_REL/$NAME/game.cfg"

	active=$(active_game_business "$ROOT" 2>/dev/null || true)

	# 标题优先级：--title > 本业务 game.cfg > 业务名
	# 绝不沿用当前 override.cfg 里的旧标题（那是上一个业务的名，切过去会串味）
	declare_title=""
	if [ -f "$declare_path" ]; then
		declare_title=$(grep -m1 '^config/name=' "$declare_path" 2>/dev/null \
			| sed -E 's/^[^=]+=["]?([^"]+)["]?[[:space:]]*$/\1/' || true)
	fi
	title=${TITLE:-${declare_title:-$NAME}}

	# 主场景路径优先级：--main-scene > 本业务 game.cfg > （切到同一业务时）沿用当前值
	declare_main=""
	if [ -f "$declare_path" ]; then
		declare_main=$(grep -m1 '^run/main_scene=' "$declare_path" 2>/dev/null \
			| sed -E 's/^[^=]+=["]?([^"]+)["]?[[:space:]]*$/\1/' || true)
	fi
	[ "$active" = "$NAME" ] && current_main=$(read_current_key 'run/main_scene' 2>/dev/null || true)
	[ -n "$MAIN_SCENE" ] || MAIN_SCENE=${declare_main:-${current_main:-}}

	tmp="$OVERRIDE_PATH.tmp.$$"

	{
		printf '; 由 _ToolScript/select_game.sh 生成（改动会被下次切换覆盖）\n'
		printf '; 当前激活：Game/%s\n' "$NAME"
		printf '; 切换：_ToolScript/select_game.sh <业务名>    查看：_ToolScript/select_game.sh --list\n'
		printf '\n[application]\n'
		printf 'config/name="%s"\n' "$title"
		[ -n "$MAIN_SCENE" ] && printf 'run/main_scene="%s"\n' "$MAIN_SCENE"
		printf '\n[comedot]\n'
		printf 'settings/comedotProjectSettingsPath="res://%s/%s/%s"\n' "$GAME_ROOT_REL" "$NAME" "$GAME_PER_BUSINESS_SETTINGS"
		if [ -f "$fragment_path" ]; then
			printf '\n; ---- 业务片段：Game/%s/override.cfg ----\n' "$NAME"
			cat "$fragment_path"
		fi
	} > "$tmp" || die "写入失败: $tmp"

	if [ "$DRY_RUN" = "1" ]; then
		log_info "[DRY] 将写入 Game/override.cfg："
		sed 's/^/    /' "$tmp"
		rm -f "$tmp"
		return 0
	fi

	mv "$tmp" "$OVERRIDE_PATH" || die "无法写入 $OVERRIDE_PATH"
	log_ok "已切换激活业务 → Game/${NAME}/（config/name=\"${title}\"${MAIN_SCENE:+，main_scene=${MAIN_SCENE}}）"
	log_info "下一步: _ToolScript/verify_project.sh"
}

# endregion


main() {
	parse_args "$@"
	require_cmd git
	resolve_root

	if [ "$SHOW_LIST" = "1" ] || [ -z "$NAME" ]; then
		print_list
		exit 0
	fi

	validate_business
	check_fragment
	write_override
}

main "$@"
