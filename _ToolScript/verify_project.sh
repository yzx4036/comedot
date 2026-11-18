#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# verify_project.sh — 体检：项目是否严格锚定当前 comedot 框架结构
#
# 只读，不改任何文件。检查项：
#   框架层  project.godot 启动覆盖设置 / 必需目录与文件 / .gitignore 的 Game 边界 / 远端布局
#   游戏层  override.cfg 启动契约 / ComedotProjectSettings.tres 指向是否有效
#           禁用锚点（已删除的框架类）/ 场景与资源引用是否存在 / 游戏仓远端
#
# 退出码：0 = 全通过（可能有 WARN）；1 = 存在 FAIL
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

usage() {
	cat <<'EOF'
用法: verify_project.sh [--project PATH] [--quiet]

  --project PATH   框架仓根目录（含 project.godot 且 Game/ 是独立仓）；默认从当前目录向上查找
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

	if [ -f "$PROJECT/.gitignore" ] && grep -qxF "$FRAMEWORK_GAME_IGNORE_RULE" "$PROJECT/.gitignore"; then
		pass ".gitignore 含 Game 边界规则: $FRAMEWORK_GAME_IGNORE_RULE"
	else
		fail ".gitignore 缺少 Game 边界规则: $FRAMEWORK_GAME_IGNORE_RULE （框架仓会吞掉游戏仓内容）"
	fi

	# 边界实测：Game/ 下的东西必须被框架仓忽略
	if git -C "$PROJECT" check-ignore -q -- "Game/override.cfg"; then
		pass "边界实测: 框架仓忽略 Game/override.cfg"
	else
		fail "边界失效: 框架仓没有忽略 Game/override.cfg"
	fi

	# 框架仓远端布局
	local url=""
	if url=$(git -C "$PROJECT" remote get-url origin 2>/dev/null); then
		pass "框架仓 origin: $url"
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
	else
		fail "框架仓缺少 upstream 远端（无法拉框架更新）"
	fi
}

check_game_layer() {
	local item

	printf '\n── 游戏层（Game/ = 游戏业务仓根）──────────────────────\n'

	if game_repo_mounted "$PROJECT"; then
		pass "Game/ 是独立 git 仓（游戏业务仓）"
	else
		fail "Game/ 不是独立 git 仓"
		return 0
	fi

	for item in $GAME_REPO_REQUIRED_FILES; do
		if [ -f "$PROJECT/Game/$item" ]; then
			pass "游戏仓必需文件: $item"
		else
			fail "游戏仓缺必需文件: Game/$item"
		fi
	done

	# override.cfg 启动契约
	if [ -f "$PROJECT/Game/override.cfg" ]; then
		if grep -q '^config/name=' "$PROJECT/Game/override.cfg"; then
			pass "override.cfg 设置了 config/name: $(grep -m1 '^config/name=' "$PROJECT/Game/override.cfg")"
		else
			warn "override.cfg 未设置 config/name（游戏窗口标题会沿用框架名）"
		fi

		local settings_path
		settings_path=$(grep -m1 '^settings/comedotProjectSettingsPath=' "$PROJECT/Game/override.cfg" 2>/dev/null | sed -E 's/^[^=]+="?([^"]+)"?$/\1/' || true)
		if [ -n "$settings_path" ]; then
			if [ -f "$PROJECT/${settings_path#res://}" ]; then
				pass "override.cfg 的 Comedot 设置资源路径有效: $settings_path"
			else
				fail "override.cfg 指向的设置资源不存在: $settings_path"
			fi
		else
			warn "override.cfg 未重定向 comedot/settings/comedotProjectSettingsPath（会沿用框架根的 ComedotProjectSettings.tres，上游一改就串味）"
		fi

		if grep -q '^run/main_scene=' "$PROJECT/Game/override.cfg"; then
			local main_scene
			main_scene=$(grep -m1 '^run/main_scene=' "$PROJECT/Game/override.cfg" | sed -E 's/^[^=]+="?([^"]+)"?$/\1/')
			if [ -f "$PROJECT/${main_scene#res://}" ]; then
				pass "override.cfg 覆盖的主场景存在: $main_scene"
			else
				fail "override.cfg 覆盖的主场景不存在: $main_scene"
			fi
		else
			pass "override.cfg 未覆盖主场景 ⇒ 走框架启动链（IOLogoScene → GameFrame → startMainScene）"
		fi
	fi

	# ComedotProjectSettings.tres 的 mainGameScenePath
	local settings_tres="$PROJECT/Game/ComedotProjectSettings.tres"
	if [ -f "$settings_tres" ]; then
		local target
		target=$(grep -m1 '^mainGameScenePath' "$settings_tres" | sed -E 's/.*=[[:space:]]*"?([^"]+)"?[[:space:]]*$/\1/' || true)
		if [ -n "$target" ]; then
			if [ -f "$PROJECT/${target#res://}" ]; then
				pass "mainGameScenePath 有效: $target"
			else
				fail "mainGameScenePath 指向的场景不存在: $target"
			fi
		else
			warn "ComedotProjectSettings.tres 未设置 mainGameScenePath（Start 按钮会加载框架默认场景）"
		fi
	else
		warn "缺少 Game/ComedotProjectSettings.tres（主场景只能走框架默认值）"
	fi

	# 游戏仓远端
	if git -C "$PROJECT/Game" remote get-url origin >/dev/null 2>&1; then
		pass "游戏仓 origin: $(git -C "$PROJECT/Game" remote get-url origin)"
	else
		warn "游戏仓缺少 origin 远端（无法备份/同步）"
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
	local ref missing=0 local_only=0 total=0 ref_rel ref_repo
	printf '\n── 资源引用 ──────────────────────────────────────────\n'

	while IFS= read -r ref; do
		[ -n "$ref" ] || continue
		total=$((total + 1))
		[ -e "$PROJECT/${ref#res://}" ] && continue

		# Game/ 内的引用查游戏仓；框架层引用查框架仓
		ref_rel=${ref#res://}
		case "$ref_rel" in
			Game/*) ref_repo="$PROJECT/Game"; ref_rel=${ref_rel#Game/} ;;
			*)      ref_repo="$PROJECT" ;;
		esac

		if git -C "$ref_repo" cat-file -e "HEAD:${ref_rel}" 2>/dev/null; then
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
		PROJECT=$(find_project_root) || die "当前目录向上找不到 comedot 项目（需 project.godot + Game/.git）"
	fi
	[ -f "$PROJECT/project.godot" ] || die "不是框架仓根目录（缺 project.godot）: $PROJECT"

	printf '体检目标: %s\n' "$PROJECT"

	check_framework_layer
	check_game_layer
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
