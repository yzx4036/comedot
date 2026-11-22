#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# new_project.sh — 以 comedot 为框架开新游戏项目（单仓 · Game 下多业务）
#
#   一次 clone = 框架 + 游戏业务，全部在一个仓（见 docs/multi-game-layout.md）：
#     1) 克隆框架来源 → 工作区，框架来源变成只读 upstream，新建私仓成为 origin
#     2) 业务目录 Game/<业务>/ 交回 new_game.sh 生成（本脚本不再自己铺骨架）
#     3) 只提交 Game/ 层改动，框架层保持上游原样，便于日后提 PR
#
#   游戏业务不再进独立仓：整个项目就是这一个仓。
#
# 用法：new_project.sh --proj <项目名> [--game <业务名>] [选项]
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
GAME_NAME=""
TITLE=""
FW_SOURCE=""
FW_BRANCH="$DEFAULT_FRAMEWORK_BRANCH"
DRY_RUN=0
NO_PUSH=0
CREATE_REMOTE=0

FW_REPO=""
WORKSPACE=""

usage() {
	cat <<'EOF'
用法: new_project.sh --proj <项目名> [选项]

必填:
  --proj NAME             游戏项目名，如 <Proj>（仓名 = Comedot_<prefix><NAME>）

选项:
  --prefix NAME           仓名前缀，默认 GDGameProj → Comedot_<Prefix><Proj>
  --owner NAME            GitHub 账号/组织，默认 yzx4036
  --root PATH             工作区根目录，默认 ~/_Proj/_godot（项目落在 <root>/<仓名>）
  --game NAME             Game/ 下的游戏业务目录名，默认等于 --proj
  --title TEXT            业务的 config/name（窗口标题），默认等于 --game
  --framework-source SRC  框架来源（URL 或本地路径），默认 git@github.com:<owner>/comedot.git
  --framework-branch B    框架分支，默认 develop
  --create-remote         用 gh 创建一个 GitHub 私有仓（需 gh 已登录）
  --no-push               只建本地，不推送
  --dry-run               只打印计划，不落盘

示例:
  new_project.sh --proj <Proj> --create-remote
  new_project.sh --proj <Proj> --game <业务> --title "武侠" --root /tmp/ws --no-push

说明:
  项目 = 一个仓（框架 + Game/ 同仓）。多游戏并存用 new_game.sh 在同仓 Game/ 下并列建业务。
EOF
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--proj)              PROJ=${2:-}; shift 2 ;;
			--prefix)            PREFIX=${2:-}; shift 2 ;;
			--owner)             OWNER=${2:-}; shift 2 ;;
			--root)              ROOT=${2:-}; shift 2 ;;
			--game)              GAME_NAME=${2:-}; shift 2 ;;
			--game-folder)       GAME_NAME=${2:-}; shift 2 ;;   # 旧参数名，等价于 --game
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

# endregion


# region 步骤

validate_inputs() {
	[ -n "$PROJ" ] || { usage; die "--proj 必填"; }
	case "$PROJ" in *[!A-Za-z0-9_-]*) die "--proj 只允许字母/数字/下划线/中划线: $PROJ" ;; esac
	case "$PREFIX" in *[!A-Za-z0-9_-]*) die "--prefix 非法: $PREFIX" ;; esac

	GAME_NAME=${GAME_NAME:-$PROJ}
	case "$GAME_NAME" in
		[A-Za-z]*) ;;
		*) die "--game 必须以字母开头: $GAME_NAME" ;;
	esac
	case "$GAME_NAME" in *[!A-Za-z0-9_]*) die "--game 只允许字母/数字/下划线: $GAME_NAME" ;; esac
	TITLE=${TITLE:-$GAME_NAME}

	derive_repo_names "$PROJ" "$PREFIX"
	[ -n "$FW_SOURCE" ] || FW_SOURCE=$(fw_repo_url "$OWNER" "comedot")

	mkdir -p "$ROOT" || die "无法创建工作区根目录: $ROOT"
	ROOT=$(abs_dir "$ROOT") || die "无法解析工作区根目录"
	WORKSPACE="$ROOT/$FW_REPO"

	log_info "项目仓:    $FW_REPO  (origin=$OWNER/$FW_REPO, upstream=框架上游)"
	log_info "工作区:    $WORKSPACE"
	log_info "游戏业务:  Game/$GAME_NAME  标题: $TITLE"
	log_info "框架来源:  $FW_SOURCE ($FW_BRANCH)"
}

step_create_remote() {
	[ "$CREATE_REMOTE" = "1" ] || {
		log_info "未指定 --create-remote：假定远端 $OWNER/$FW_REPO 已存在"
		return 0
	}
	require_cmd gh
	if ! gh auth status >/dev/null 2>&1; then
		die "gh 未登录，无法创建远端：先 gh auth login，或去掉 --create-remote 手动建仓"
	fi

	if gh repo view "$OWNER/$FW_REPO" >/dev/null 2>&1; then
		log_warn "远端已存在，跳过创建: $OWNER/$FW_REPO"
	else
		log_info "创建私有仓: $OWNER/$FW_REPO"
		run gh repo create "$OWNER/$FW_REPO" --private || die "创建远端失败: $OWNER/$FW_REPO"
	fi
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

	log_ok "远端布局: origin=$(fw_repo_url "$OWNER" "$FW_REPO")"
	log_ok "          upstream=$FW_SOURCE (push 已禁用)"

	log_info "校验框架锚定…"
	check_framework_anchor "$WORKSPACE" || die "框架结构与 anchor.conf 不符，先更新 _ToolScript/anchor.conf"
	log_ok "框架锚定通过"
}

# 业务骨架统一由 new_game.sh 生成（本脚本不再自带一套模板，避免两处漂移）
step_create_business() {
	local new_game="$SCRIPT_DIR/new_game.sh"
	[ -f "$new_game" ] || die "缺少 new_game.sh（单仓模型下业务骨架由它生成）: $new_game"

	local layout
	layout=$(project_layout "$WORKSPACE")
	[ "$layout" = "legacy" ] && warn_legacy_layout "$WORKSPACE"

	if [ -d "$WORKSPACE/$GAME_ROOT_REL/$GAME_NAME" ]; then
		log_warn "业务目录已存在（随框架带来的示例业务？）: Game/$GAME_NAME → 跳过创建，只切换激活项"
		if [ "$DRY_RUN" = "1" ]; then
			log_info "[DRY] select_game.sh $GAME_NAME --root $WORKSPACE --title $TITLE"
		else
			"$SCRIPT_DIR/select_game.sh" "$GAME_NAME" --root "$WORKSPACE" --title "$TITLE" \
				|| die "切换激活业务失败: $GAME_NAME"
		fi
		return 0
	fi

	log_info "生成游戏业务 Game/${GAME_NAME}（new_game.sh）…"
	if [ "$DRY_RUN" = "1" ]; then
		bash "$new_game" --name "$GAME_NAME" --root "$WORKSPACE" --title "$TITLE" --activate --dry-run
		return 0
	fi
	bash "$new_game" --name "$GAME_NAME" --root "$WORKSPACE" --title "$TITLE" --activate \
		|| die "业务生成失败: new_game.sh --name $GAME_NAME"
}

step_commit() {
	[ "$DRY_RUN" = "1" ] && return 0

	# 框架层应保持上游原样：任何 Game/ 之外的改动都要提示（否则将来提 PR 会带脏）
	local pollute
	pollute=$(git -C "$WORKSPACE" status --porcelain | grep -v 'Game/' || true)
	if [ -n "$pollute" ]; then
		log_warn "框架层出现非预期改动（应只动 Game/）："
		printf '%s\n' "$pollute" | sed 's/^/    /'
	fi

	if [ -z "$(git -C "$WORKSPACE" status --porcelain -- "$GAME_ROOT_REL")" ]; then
		log_info "Game/ 无改动，跳过提交"
		return 0
	fi

	git -C "$WORKSPACE" add -A -- "$GAME_ROOT_REL" || die "git add 失败"
	git -C "$WORKSPACE" commit -q -F - <<'MSG'
chore: 初始化游戏业务骨架

+ 生成 Game/<业务>/ 目录树与启动契约（ComedotProjectSettings.tres + game.cfg）
+ 由 select_game.sh 生成 Game/override.cfg 指向该业务
+ 补齐业务 README 与 Docs（启动链路）
MSG
	log_ok "已提交: $(git -C "$WORKSPACE" log --oneline -1)"
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
		log_info "[DRY] 推送到 $OWNER/$FW_REPO"
		return 0
	fi

	log_info "推送 → origin ($OWNER/$FW_REPO)"
	git -C "$WORKSPACE" push -u origin HEAD \
		|| log_warn "推送失败：确认 $OWNER/$FW_REPO 已存在且有权限"
}

print_summary() {
	cat <<EOF

════════════════════════════════════════════════════════════════
项目脚手架完成（单仓 · Game 下多业务）
════════════════════════════════════════════════════════════════
  工作区   $WORKSPACE
  origin   $(fw_repo_url "$OWNER" "$FW_REPO")
  upstream $FW_SOURCE  (push 已禁用)
  业务     Game/$GAME_NAME   ← 当前激活

下一步:
  1. Godot 打开 $WORKSPACE/project.godot
  2. 跑一次启动链：IOLogoScene → GameFrame → Start → Game/$GAME_NAME/Scenes/Levels/${GAME_NAME}Main.tscn
  3. 日常：
       $WORKSPACE/_ToolScript/new_game.sh --name <业务> --activate   # 同仓并列新业务
       $WORKSPACE/_ToolScript/select_game.sh --list                  # 看/切业务
       $WORKSPACE/_ToolScript/update_project.sh --dry-run            # 看上游带来什么
       $WORKSPACE/_ToolScript/verify_project.sh                      # 体检
════════════════════════════════════════════════════════════════
EOF
}

# endregion


main() {
	parse_args "$@"
	require_cmd git
	validate_inputs
	step_create_remote
	step_clone_framework
	step_create_business
	step_commit
	step_verify
	step_push
	print_summary
}

main "$@"
