#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# verify_project.sh — 体检：项目是否严格锚定当前 comedot 框架结构
#
# 只读，不改任何文件。检查项：
#   框架层   project.godot 启动覆盖设置 / 必需目录与文件 / Game 归属 / 远端布局
#   启动契约 Game/override.cfg 的 config/name、设置资源路径、主场景覆盖
#   游戏层   业务目录识别 / 激活项 / 每个业务的 mainGameScenePath / 业务隔离
#           禁用锚点（已删除的框架类）/ 场景与资源引用是否存在
#
# 布局：single = 单仓多业务（唯一支持形态）；legacy = 双仓旧模型（只警告提示迁移）
# 退出码：0 = 无 FAIL（可能有 WARN）；1 = 存在 FAIL
# ---------------------------------------------------------------------------

set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
load_anchor


# region 参数与计数

PROJECT=""
QUIET=0
FAILS=0
WARNS=0
LAYOUT=""

usage() {
	cat <<'EOF'
用法: verify_project.sh [--project PATH] [--quiet]

  --project PATH   项目根目录（含 project.godot；单仓多业务）默认从当前目录向上查找
  --quiet          只输出 FAIL/WARN
EOF
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--project) PROJECT=${2:-}; shift 2 ;;
			--quiet)   QUIET=1; shift ;;
			-h|--help) usage; exit 0 ;;
			*)         usage; die "未知参数: $1" ;;
		esac
	done
}

pass() { [ "$QUIET" = "1" ] || log_ok "$*"; }
fail() { log_err "$*"; FAILS=$((FAILS + 1)); }
warn() { log_warn "$*"; WARNS=$((WARNS + 1)); }

# endregion


# region 检查项

check_framework_layer() {
	local item

	printf '\n── 框架层 ────────────────────────────────────────────\n'

	if grep -qF "$FRAMEWORK_OVERRIDE_SETTING_LINE" "$PROJECT/project.godot" 2>/dev/null; then
		pass "project.godot 含启动覆盖设置"
	else
		fail "project.godot 缺少: $FRAMEWORK_OVERRIDE_SETTING_LINE"
	fi

	for item in $FRAMEWORK_REQUIRED_DIRS; do
		if [ -d "$PROJECT/$item" ]; then
			pass "框架目录: $item"
		else
			fail "框架目录缺失: $item （框架结构变了，先更新 _ToolScript/anchor.conf）"
		fi
	done

	for item in $FRAMEWORK_REQUIRED_FILES; do
		if [ -f "$PROJECT/$item" ]; then
			pass "框架文件: $item"
		else
			fail "框架文件缺失: $item"
		fi
	done

	for item in $FRAMEWORK_OPTIONAL_DIRS; do
		[ -d "$PROJECT/$item" ] && pass "可选目录存在: $item"
	done

	if [ -f "$PROJECT/$FRAMEWORK_SETTINGS_SCRIPT" ]; then
		pass "Comedot 设置脚本存在: $FRAMEWORK_SETTINGS_SCRIPT"
	else
		fail "Comedot 设置脚本缺失: $FRAMEWORK_SETTINGS_SCRIPT"
	fi

	if [ -f "$PROJECT/$FRAMEWORK_LAUNCH_SCENE" ]; then
		pass "框架启动链首场景存在: $FRAMEWORK_LAUNCH_SCENE"
	else
		warn "框架启动链首场景不存在: $FRAMEWORK_LAUNCH_SCENE （启动契约可能已变）"
	fi

	if [ -f "$PROJECT/.gitignore" ] && grep -qxF "$FRAMEWORK_FORBIDDEN_IGNORE_RULE" "$PROJECT/.gitignore"; then
		fail ".gitignore 仍忽略 Game/ ($FRAMEWORK_FORBIDDEN_IGNORE_RULE)：单仓模型要求跟踪 Game/（删掉该规则并按 §6 迁移）"
	else
		pass ".gitignore 无 Game 忽略规则（单仓多业务模型下 Game/ 必须被跟踪）"
	fi

	# Game/ 归属：单仓模型必须由本仓跟踪
	if [ "$LAYOUT" = "legacy" ]; then
		warn "Game/ 是嵌套 git 仓（双仓旧模型），跳过单仓归属校验；迁移后本项转绿"
	elif [ "$LAYOUT" = "none" ]; then
		warn "缺少 Game/ 目录（用 _ToolScript/new_game.sh 建第一个业务）"
	elif git -C "$PROJECT" check-ignore -q -- "Game/override.cfg"; then
		fail "Game/ 被 .gitignore 忽略（单仓模型要求跟踪）"
	elif [ -z "$(git -C "$PROJECT" ls-files -- "$GAME_ROOT_REL" | head -1)" ]; then
		fail "Game/ 下没有任何被跟踪文件（尚未 git add？）"
	else
		pass "Game/ 已被本仓跟踪（$(git -C "$PROJECT" ls-files -- "$GAME_ROOT_REL" | wc -l | tr -d ' ') 个文件）"
	fi

	# 框架仓远端布局
	local url="" is_framework_source=0
	if url=$(git -C "$PROJECT" remote get-url origin 2>/dev/null); then
		pass "框架仓 origin: $url"
		case "$url" in
			*/comedot.git|*/comedot) is_framework_source=1 ;;
		esac
	else
		fail "框架仓缺少 origin 远端"
	fi
	if url=$(git -C "$PROJECT" remote get-url upstream 2>/dev/null); then
		pass "框架仓 upstream: $url"
		local pushurl
		pushurl=$(git -C "$PROJECT" config --get remote.upstream.pushurl 2>/dev/null || true)
		if [ -n "$pushurl" ]; then
			pass "upstream 推送已禁用（防污染框架上游）"
		else
			warn "upstream 未禁用推送：建议 git config remote.upstream.pushurl \"DISABLED-upstream-is-read-only\""
		fi
	elif [ "$is_framework_source" = "1" ]; then
		pass "本仓即框架源仓（origin 指向 comedot），不要求 upstream"
	else
		fail "缺少 upstream 远端（无法拉框架更新）；clone 后跑 _ToolScript/link_upstream.sh 接上"
	fi
}

# 单仓多业务：每个 Game/<业务>/ 自成一体，override.cfg 指当前激活项
check_single_repo_games() {
	local games active game settings target other ref hits
	printf '\n── 游戏业务（单仓多业务）─────────────────────────────\n'

	games=$(list_game_businesses "$PROJECT")
	if [ -z "$games" ]; then
		warn "Game/ 下没有业务目录（用 _ToolScript/new_game.sh 建一个）"
		return 0
	fi

	local support
	support=$(list_game_support_dirs "$PROJECT")
	if [ -n "$support" ]; then
		log_info "Game/ 下的辅助目录（不是游戏业务）: $(printf '%s ' $support)"
	fi

	if [ ! -f "$PROJECT/$GAME_OVERRIDE_REL" ]; then
		# 选择器缺失由 check_override_contract 报 FAIL，这里不重复计数
		return 0
	fi

	active=$(active_game_business "$PROJECT" 2>/dev/null || true)
	if [ -z "$active" ]; then
		fail "$GAME_OVERRIDE_REL 未指向任何业务的 ${GAME_PER_BUSINESS_SETTINGS}"
	elif ! printf '%s\n' "$games" | grep -qxF "$active"; then
		fail "override.cfg 指向的业务不存在: Game/${active}/"
	else
		pass "当前激活业务: Game/${active}/"
	fi

	local cfg_name
	cfg_name=$(grep -m1 '^config/name=' "$PROJECT/$GAME_OVERRIDE_REL" | sed -E 's/^[^=]+=["]?([^"]+)["]?[[:space:]]*$/\1/' || true)
	if [ -n "$cfg_name" ]; then
		pass "override.cfg config/name: ${cfg_name}"
	else
		warn "override.cfg 未设置 config/name"
	fi

	for game in $games; do
		settings="$PROJECT/$GAME_ROOT_REL/$game/$GAME_PER_BUSINESS_SETTINGS"
		if [ ! -f "$settings" ]; then
			fail "业务缺 ${GAME_PER_BUSINESS_SETTINGS}: Game/${game}/"
			continue
		fi
		target=$(grep -m1 '^mainGameScenePath' "$settings" | sed -E 's/.*=[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/' || true)
		if [ -z "$target" ]; then
			warn "Game/${game}/ 的 ${GAME_PER_BUSINESS_SETTINGS} 未设 mainGameScenePath"
		elif [ ! -f "$PROJECT/${target#res://}" ]; then
			fail "Game/${game}/ 的 mainGameScenePath 指向不存在的场景: ${target}"
		else
			pass "Game/${game}/ mainGameScenePath 有效"
		fi

		# 业务隔离：不得引用其他业务目录
		for other in $games; do
			[ "$other" = "$game" ] && continue
			hits=$(grep -rl --include='*.gd' --include='*.tscn' --include='*.tres' \
				"res://${GAME_ROOT_REL}/${other}/" "$PROJECT/$GAME_ROOT_REL/$game" 2>/dev/null | head -3 || true)
			if [ -n "$hits" ]; then
				fail "业务越界: Game/${game}/ 引用了 Game/${other}/："
				printf '%s\n' "$hits" | sed 's|^.*/Game/|    Game/|'
			fi
		done
	done
}

# ── 启动契约（Game/override.cfg）：单仓与 legacy 都适用 ──────────────────
check_override_contract() {
	local settings_path=""

	printf '\n── 启动契约（Game/override.cfg）───────────────────────\n'

	if [ ! -f "$PROJECT/$GAME_OVERRIDE_REL" ]; then
		fail "缺少业务选择器: ${GAME_OVERRIDE_REL}（用 _ToolScript/select_game.sh <业务> 生成）"
		return 0
	fi

	if grep -q '^config/name=' "$PROJECT/$GAME_OVERRIDE_REL"; then
		pass "override.cfg 设置了 config/name: $(grep -m1 '^config/name=' "$PROJECT/$GAME_OVERRIDE_REL")"
	else
		warn "override.cfg 未设置 config/name（窗口标题会沿用框架名）"
	fi

	settings_path=$(grep -m1 '^settings/comedotProjectSettingsPath=' "$PROJECT/$GAME_OVERRIDE_REL" 2>/dev/null \
		| sed -E 's/^[^=]+="?([^"]+)"?$/\1/' || true)
	if [ -n "$settings_path" ]; then
		if [ -f "$PROJECT/${settings_path#res://}" ]; then
			pass "override.cfg 的 Comedot 设置资源路径有效: $settings_path"
		else
			fail "override.cfg 指向的设置资源不存在: $settings_path"
		fi
	else
		warn "override.cfg 未重定向 comedot/settings/comedotProjectSettingsPath（会沿用框架根的 ComedotProjectSettings.tres，上游一改就串味）"
	fi

	if grep -q '^run/main_scene=' "$PROJECT/$GAME_OVERRIDE_REL"; then
		local main_scene
		main_scene=$(grep -m1 '^run/main_scene=' "$PROJECT/$GAME_OVERRIDE_REL" | sed -E 's/^[^=]+="?([^"]+)"?$/\1/')
		if [ -f "$PROJECT/${main_scene#res://}" ]; then
			pass "override.cfg 覆盖的主场景存在: $main_scene"
		else
			fail "override.cfg 覆盖的主场景不存在: $main_scene"
		fi
	else
		pass "override.cfg 未覆盖主场景 ⇒ 走框架启动链（IOLogoScene → GameFrame → startMainScene）"
	fi
}

# 禁用锚点扫描（框架已删除的类/脚本）
check_forbidden_patterns() {
	local hits
	printf '\n── 废弃锚点 ──────────────────────────────────────────\n'

	hits=$(grep -rn -E "$GAME_FORBIDDEN_PATTERNS" "$PROJECT/Game" \
		--include='*.gd' --include='*.tscn' --include='*.tres' 2>/dev/null \
		| grep -v '/\.git/' | head -20 || true)

	if [ -z "$hits" ]; then
		pass "游戏层没有引用已删除的框架锚点（${GAME_FORBIDDEN_PATTERNS}）"
	else
		fail "游戏层仍引用已删除的框架锚点（af4bc065 起 Scripts/Start.gd 已不存在）："
		printf '%s\n' "$hits" | sed 's/^/    /'
	fi
}

# 场景/资源引用存在性扫描
check_resource_refs() {
	local ref missing=0 local_only=0 total=0 ref_rel
	printf '\n── 资源引用 ──────────────────────────────────────────\n'

	while IFS= read -r ref; do
		[ -n "$ref" ] || continue
		total=$((total + 1))
		[ -e "$PROJECT/${ref#res://}" ] && continue

		# 单仓模型：框架层与 Game/ 层同一个仓，判「仓里有、工作区没有」
		ref_rel=${ref#res://}
		if git -C "$PROJECT" cat-file -e "HEAD:${ref_rel}" 2>/dev/null; then
			fail "引用丢失（仓里有、工作区没有）: $ref"
			missing=$((missing + 1))
		else
			warn "引用不存在且未被任何仓版本管理（本地/生成依赖，需本机安装或重跑生成脚本）: $ref"
			local_only=$((local_only + 1))
		fi
	done <<EOF
$(grep -rho -E 'path="res://[^"]+"' --include='*.tscn' --include='*.tres' "$PROJECT/Game" 2>/dev/null \
	| sed -E 's/^path="//; s/"$//' | sort -u)
EOF

	[ "$total" = "0" ] && { warn "游戏层没有可扫描的 res:// 引用"; return 0; }
	[ "$missing" = "0" ] && pass "游戏层 $total 个 res:// 引用全部可解析（其中 $local_only 个属于本地/被忽略依赖）"
	return 0
}

# endregion


main() {
	parse_args "$@"
	require_cmd git

	if [ -n "$PROJECT" ]; then
		PROJECT=$(abs_dir "$PROJECT") || die "目录不存在: $PROJECT"
	else
		PROJECT=$(find_project_root_any) || die "当前目录向上找不到 comedot 项目（需 project.godot）"
	fi
	[ -f "$PROJECT/project.godot" ] || die "不是框架仓根目录（缺 project.godot）: $PROJECT"

	LAYOUT=$(project_layout "$PROJECT")
	printf '体检目标: %s（布局: %s）\n' "$PROJECT" "$LAYOUT"

	# legacy：双仓旧模型只警告提示迁移，不再按单仓标准判 FAIL
	[ "$LAYOUT" = "legacy" ] && warn_legacy_layout "$PROJECT"

	check_framework_layer
	check_override_contract
	# 业务层只在单仓模型下校验（legacy 的 Game/ 是别人的仓，标准不适用）
	[ "$LAYOUT" = "legacy" ] || check_single_repo_games
	check_forbidden_patterns
	check_resource_refs

	printf '\n── 结论 ──────────────────────────────────────────────\n'
	if [ "$FAILS" = "0" ]; then
		printf 'PASS：%d 项 FAIL，%d 项 WARN\n' "$FAILS" "$WARNS"
		exit 0
	fi
	printf 'FAIL：%d 项 FAIL，%d 项 WARN\n' "$FAILS" "$WARNS"
	exit 1
}

main "$@"
