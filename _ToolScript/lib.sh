#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# _ToolScript/lib.sh — new_project.sh / update_project.sh / verify_project.sh 共用函数
# 兼容 macOS bash 3.2 与 Windows git-bash（MSYS）：不用 GNU-only 参数、不用 sed -i、
# 不用 associative array、不用 mapfile。
# ---------------------------------------------------------------------------

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ANCHOR_CONF="$SCRIPT_DIR/anchor.conf"

# region 日志

log_info() { printf '[INFO] %s\n' "$*"; }
log_ok()   { printf '[ OK ] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; }
log_err()  { printf '[FAIL] %s\n' "$*" >&2; }
die()      { log_err "$*"; exit 1; }

# endregion


# region 基础

require_cmd() {
	local missing=""
	local command_name=""
	for command_name in "$@"; do
		command -v "$command_name" >/dev/null 2>&1 || missing="$missing $command_name"
	done
	[ -z "$missing" ] || die "缺少必需命令:$missing"
}

# 目录绝对化（不走 realpath：git-bash / BSD 都可能没有）
abs_dir() {
	( cd "$1" >/dev/null 2>&1 && pwd )
}

# 内部统一 git 环境：不弹凭据、SSH 不挂死
git_env() {
	GIT_TERMINAL_PROMPT=0 \
	GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new" \
	"$@"
}

# 远端是否可达（0=可达）
remote_reachable() {
	local url=$1
	git_env git ls-remote --heads "$url" >/dev/null 2>&1
}

load_anchor() {
	[ -f "$ANCHOR_CONF" ] || die "找不到锚定规格文件: $ANCHOR_CONF"
	# shellcheck disable=SC1090
	. "$ANCHOR_CONF"
	[ -n "${FRAMEWORK_REQUIRED_DIRS:-}" ] || die "锚定规格载入失败: $ANCHOR_CONF"
}

# 空格分隔的规格列表 → 逐行
spec_lines() {
	printf '%s\n' "$1" | tr ' ' '\n' | sed '/^$/d'
}

# endregion


# region 命名推导

# 由 PROJ / PREFIX 推导项目仓名（全局变量）
#   单仓模型：一个项目 = 一个仓（框架 + Game/ 同仓），没有独立的游戏业务仓
derive_repo_names() {
	local proj=$1 prefix=$2
	FW_REPO="Comedot_${prefix}${proj}"
}

fw_repo_url() { printf 'git@github.com:%s/%s.git' "$1" "$2"; }

# endregion


# region 锚定校验（供 create 前置检查 / verify 复用）

# 框架层锚定：$1=项目目录；有缺失返回 1
check_framework_anchor() {
	local dir=$1 item missing=0
	for item in $FRAMEWORK_REQUIRED_DIRS; do
		[ -d "$dir/$item" ] || { log_err "框架目录缺失: $item"; missing=1; }
	done
	for item in $FRAMEWORK_REQUIRED_FILES; do
		[ -f "$dir/$item" ] || { log_err "框架文件缺失: $item"; missing=1; }
	done
	if [ -f "$dir/project.godot" ]; then
		grep -qF "$FRAMEWORK_OVERRIDE_SETTING_LINE" "$dir/project.godot" \
			|| { log_err "project.godot 缺少启动覆盖设置: $FRAMEWORK_OVERRIDE_SETTING_LINE"; missing=1; }
	fi
	# 单仓模型：Game/ 必须由本仓跟踪，.gitignore 里不能还有旧的忽略规则
	if [ -f "$dir/.gitignore" ] && grep -qxF "$FRAMEWORK_FORBIDDEN_IGNORE_RULE" "$dir/.gitignore"; then
		log_err ".gitignore 仍忽略 Game/ ($FRAMEWORK_FORBIDDEN_IGNORE_RULE)：单仓模型要求跟踪 Game/"
		missing=1
	fi
	[ -f "$dir/$FRAMEWORK_SETTINGS_SCRIPT" ] || { log_err "框架缺少 Comedot 设置脚本: $FRAMEWORK_SETTINGS_SCRIPT"; missing=1; }
	return $missing
}


# region 布局识别（single = 单仓多业务，唯一支持形态；legacy = 双仓旧模型，仅警告）

# Game/ 是否还是独立 git 仓（双仓旧模型残留）
legacy_nested_game_repo() {
	[ -d "$1/Game/.git" ] || [ -f "$1/Game/.git" ]
}

# 输出 single | legacy | none
project_layout() {
	local dir=$1
	if legacy_nested_game_repo "$dir"; then
		printf 'legacy\n'
	elif [ -d "$dir/$GAME_ROOT_REL" ]; then
		printf 'single\n'
	else
		printf 'none\n'
	fi
}

# legacy 布局统一提示（复用点：new_project/new_game/select_game/update/verify）
# 旧形态不再提供完整支持，各脚本在提示后自行决定是否继续尽力而为
warn_legacy_layout() {
	log_warn "检测到双仓旧模型：$1/$GAME_ROOT_REL 仍是嵌套 git 仓"
	log_warn "该形态已废弃，仅做尽力兼容；请按 docs/multi-game-layout.md §6 迁移到「单仓 · Game 下多业务」"
}

# 列出 Game/ 下的业务目录名
# 判据：目录里含 game.cfg 或 ComedotProjectSettings.tres 才算游戏业务；
# 这样 Game/_ConfigTables、Game/generated 之类的辅助目录不会被误当成业务。
list_game_businesses() {
	local dir=$1 path name
	for path in "$dir/$GAME_ROOT_REL"/*/; do
		[ -d "$path" ] || continue
		name=${path%/}
		name=${name##*/}
		case "$name" in .*) continue ;; esac
		if [ -f "$path/game.cfg" ] || [ -f "$path/$GAME_PER_BUSINESS_SETTINGS" ]; then
			printf '%s\n' "$name"
		fi
	done
}

# 列出 Game/ 下不是业务的辅助目录（供体检提示）
list_game_support_dirs() {
	local dir=$1 path name
	for path in "$dir/$GAME_ROOT_REL"/*/; do
		[ -d "$path" ] || continue
		name=${path%/}
		name=${name##*/}
		case "$name" in .*) continue ;; esac
		if [ ! -f "$path/game.cfg" ] && [ ! -f "$path/$GAME_PER_BUSINESS_SETTINGS" ]; then
			printf '%s\n' "$name"
		fi
	done
}

# 从 Game/override.cfg 推断当前激活的业务目录名
active_game_business() {
	local dir=$1 settings
	settings=$(grep -m1 '^settings/comedotProjectSettingsPath=' "$dir/$GAME_OVERRIDE_REL" 2>/dev/null \
		| sed -E 's/^[^=]+=["]?([^"]+)["]?[[:space:]]*$/\1/' || true)
	[ -n "$settings" ] || return 1
	printf '%s\n' "$settings" | sed -E 's|^res://Game/([^/]+)/.*$|\1|'
}

# 向上找项目根（project.godot 即项目根的判据；单仓模型下 Game/ 是普通目录，不参与判定）
find_project_root_any() {
	local dir
	dir=$(abs_dir ".")
	[ -n "$dir" ] || return 1
	while [ "$dir" != "/" ] && [ -n "$dir" ]; do
		if [ -f "$dir/project.godot" ]; then
			printf '%s\n' "$dir"
			return 0
		fi
		dir=$(dirname "$dir")
	done
	return 1
}

# endregion


# region 通用判定

# 工作区是否有已跟踪文件的改动（$1=仓库目录，$2=可选 pathspec）
worktree_dirty() {
	local repo=$1
	local dirty
	dirty=$(git -C "$repo" status --porcelain --untracked-files=no)
	[ -n "$dirty" ]
}

# git 分支是否存在（$1=仓库，$2=本地分支名）
branch_exists() {
	git -C "$1" show-ref --verify --quiet "refs/heads/$2"
}

# 远端引用是否存在（$1=仓库，$2=ref 如 upstream/develop）
remote_ref_exists() {
	git -C "$1" show-ref --verify --quiet "refs/remotes/$2"
}

# endregion
