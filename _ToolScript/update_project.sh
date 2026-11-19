#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# update_project.sh — 以 comedot 为框架的游戏项目：拉上游框架更新 + 同步游戏业务仓
#
#   1. 体检（框架仓工作区必须干净；Game/ 由独立业务仓管理，不参与）
#   2. fetch upstream，列出将要合并的框架提交与文件，并标出「本地也改过」的高冲突文件
#   3. 合并到当前分支（默认 develop）；冲突时列出冲突文件并安全回滚
#   4. 合并后跑锚定体检；可选同步（快进）游戏业务仓
#
# 用法：update_project.sh [--project PATH] [--dry-run] [--push]
# 详细说明见 _ToolScript/README.md
# ---------------------------------------------------------------------------

set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
load_anchor


# region 参数

PROJECT=""
BRANCH=""
UPSTREAM_REF=""
DRY_RUN=0
PUSH=0
KEEP_CONFLICTS=0
SYNC_GAME=0
ALLOW_DIRTY=0

usage() {
	cat <<'EOF'
用法: update_project.sh [选项]     （在项目任意子目录执行，或显式 --project）

选项:
  --project PATH      框架仓根目录（含 project.godot 且 Game/ 是独立仓）；默认从当前目录向上自动查找
  --branch NAME       合并目标分支，默认当前分支
  --upstream REF      上游引用，默认 upstream/<branch>
  --sync-game         顺带把游戏业务仓快进到 origin（要求游戏仓干净）
  --push              合并成功后推送框架仓
  --keep-conflicts    冲突时保留冲突现场（默认自动 git merge --abort 回滚）
  --allow-dirty       允许框架仓有未提交改动（不推荐）
  --dry-run           只看会合并什么，不动仓库
EOF
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--project)        PROJECT=${2:-}; shift 2 ;;
			--branch)         BRANCH=${2:-}; shift 2 ;;
			--upstream)       UPSTREAM_REF=${2:-}; shift 2 ;;
			--sync-game)      SYNC_GAME=1; shift ;;
			--push)           PUSH=1; shift ;;
			--keep-conflicts) KEEP_CONFLICTS=1; shift ;;
			--allow-dirty)    ALLOW_DIRTY=1; shift ;;
			--dry-run)        DRY_RUN=1; shift ;;
			-h|--help)        usage; exit 0 ;;
			*)                usage; die "未知参数: $1" ;;
		esac
	done
}

# endregion


# region 步骤

resolve_project() {
	if [ -n "$PROJECT" ]; then
		PROJECT=$(abs_dir "$PROJECT") || die "目录不存在: $PROJECT"
	else
		PROJECT=$(find_project_root) || PROJECT=$(find_project_root_any) \
			|| die "当前目录向上找不到 comedot 项目（需 project.godot）；用 --project 指定"
	fi

	[ -f "$PROJECT/project.godot" ] || die "不是框架仓根目录（缺 project.godot）: $PROJECT"

	LAYOUT=$(project_layout "$PROJECT")
	case "$LAYOUT" in
		single) log_info "布局: 单仓多业务（Game/ 与本仓同属一个仓）" ;;
		nested) log_info "布局: 双仓旧模型（Game/ 是独立仓，建议按 docs/multi-game-layout.md 迁移）" ;;
		*)      die "缺少 Game/ 目录: $PROJECT/$GAME_ROOT_REL" ;;
	esac

	log_info "项目: $PROJECT"
}

check_worktree() {
	local dirty overlap
	dirty=$(git -C "$PROJECT" diff --name-only HEAD 2>/dev/null || true)

	if [ -z "$dirty" ]; then
		return 0
	fi

	# 单仓模型：Game/ 与框架同仓，但上游不会改我们的业务目录 ⇒
	# 只有「与上游改动重叠」的脏文件才真正阻塞合并
	if [ "$LAYOUT" = "single" ] && [ -f "$TMP_DIR/up.sorted" ]; then
		printf '%s\n' "$dirty" | sort > "$TMP_DIR/dirty.sorted"
		comm -12 "$TMP_DIR/dirty.sorted" "$TMP_DIR/up.sorted" > "$TMP_DIR/dirty_overlap.sorted"
		if [ ! -s "$TMP_DIR/dirty_overlap.sorted" ]; then
			log_ok "工作区有 $(printf '%s\n' "$dirty" | wc -l | tr -d ' ') 个未提交改动，但都与上游改动无重叠 → 允许合并"
			return 0
		fi
		log_err "以下未提交文件与上游将要改动的文件重叠，先提交或 stash："
		sed 's/^/    /' "$TMP_DIR/dirty_overlap.sorted"
		die "已中止（合并会覆盖这些改动）"
	fi

	if [ "$ALLOW_DIRTY" = "1" ]; then
		log_warn "框架仓有未提交改动，--allow-dirty 强制继续"
		printf '%s\n' "$dirty" | sed 's/^/    /'
		return 0
	fi

	log_err "框架仓有未提交改动，先提交或 stash："
	printf '%s\n' "$dirty" | sed 's/^/    /'
	die "已中止（合并失败会污染这些改动）"
}

resolve_branch() {
	if [ -z "$BRANCH" ]; then
		BRANCH=$(git -C "$PROJECT" symbolic-ref --quiet --short HEAD) \
			|| die "当前是 detached HEAD，用 --branch 指定要合并到的分支"
	fi
	branch_exists "$PROJECT" "$BRANCH" || die "本地分支不存在: $BRANCH"

	[ -n "$UPSTREAM_REF" ] || UPSTREAM_REF="upstream/$BRANCH"
	log_info "目标: $BRANCH  ⇠  $UPSTREAM_REF"
}

fetch_upstream() {
	git -C "$PROJECT" remote get-url upstream >/dev/null 2>&1 \
		|| die "框架仓没有 upstream 远端；先执行：git remote add upstream <框架上游 URL>"

	log_info "fetch upstream…"
	git_env git -C "$PROJECT" fetch --prune upstream \
		|| die "fetch upstream 失败（网络/权限）"

	if ! remote_ref_exists "$PROJECT" "$UPSTREAM_REF"; then
		log_err "上游引用不存在: ${UPSTREAM_REF}；可用："
		git -C "$PROJECT" branch -r | sed 's/^/  /'
		exit 1
	fi
}

# 打印待合并内容，并标出高冲突文件
show_incoming() {
	local incoming changed_file base local_changed overlap file
	incoming=$(git -C "$PROJECT" log --oneline "HEAD..$UPSTREAM_REF")

	if [ -z "$incoming" ]; then
		log_ok "框架层已是最新：$BRANCH 已包含 $UPSTREAM_REF 全部提交"
		return 1
	fi

	log_info "待合并框架提交（$(printf '%s\n' "$incoming" | wc -l | tr -d ' ') 个，显示前 20）："
	printf '%s\n' "$incoming" | head -20 | sed 's/^/    /'

	base=$(git -C "$PROJECT" merge-base HEAD "$UPSTREAM_REF") || die "无法计算 merge-base"
	# 基准必须是 merge-base：HEAD..upstream 会把「本地新增的 Game/ 业务目录」误算成上游要删的东西
	git -C "$PROJECT" diff --name-only "$base..$UPSTREAM_REF" > "$TMP_DIR/upstream_files.txt"
	git -C "$PROJECT" diff --name-only "$base..HEAD" > "$TMP_DIR/local_files.txt"

	local game_hits
	game_hits=$(grep -c '^Game/' "$TMP_DIR/upstream_files.txt" 2>/dev/null || true)
	if [ "${game_hits:-0}" != "0" ]; then
		log_warn "上游改动触及 Game/ ($game_hits 个文件)：框架仓应忽略 Game/，检查 .gitignore 边界"
		grep '^Game/' "$TMP_DIR/upstream_files.txt" | head -10 | sed 's/^/    /'
	fi

	sort "$TMP_DIR/upstream_files.txt" > "$TMP_DIR/up.sorted"
	sort "$TMP_DIR/local_files.txt" > "$TMP_DIR/local.sorted"
	comm -12 "$TMP_DIR/up.sorted" "$TMP_DIR/local.sorted" > "$TMP_DIR/overlap.sorted"

	if [ -s "$TMP_DIR/overlap.sorted" ]; then
		log_warn "双方都改过的文件（冲突高发，共 $(wc -l < "$TMP_DIR/overlap.sorted" | tr -d ' ') 个）："
		head -20 "$TMP_DIR/overlap.sorted" | sed 's/^/    /'
	else
		log_ok "上游改动与本地改动无重叠，预计干净合并"
	fi

	log_info "上游改动文件数: $(wc -l < "$TMP_DIR/upstream_files.txt" | tr -d ' ')"
	return 0
}

do_merge() {
	log_info "合并 $UPSTREAM_REF → $BRANCH …"
	if git -C "$PROJECT" merge --no-ff --no-edit "$UPSTREAM_REF"; then
		log_ok "合并成功: $(git -C "$PROJECT" log --oneline -1)"
		return 0
	fi

	log_err "合并冲突"
	git -C "$PROJECT" diff --name-only --diff-filter=U | sed 's/^/    冲突: /'

	if [ "$KEEP_CONFLICTS" = "1" ]; then
		log_warn "已保留冲突现场（--keep-conflicts）：手工解决后 git commit"
		return 1
	fi

	log_warn "自动回滚（默认不把冲突留在工作区）"
	git -C "$PROJECT" merge --abort || log_err "git merge --abort 失败，需手工处理"

	cat <<'EOF'

处理建议：
  · .gitignore 冲突：必须保留本地两行，勿随上游删除
        # Game/: 独立业务仓库，保持忽略（本地约定，勿随上游合并移除）
        /Game/*

  · 需要逐文件处理时：
        git merge upstream/<branch>
        # 解决冲突后
        git add <files> && git commit

  · 只想先看清冲突范围：
        _ToolScript/update_project.sh --dry-run
EOF
	return 1
}

sync_game_repo() {
	local game="$PROJECT/Game" branch counts behind ahead

	# 单仓多业务：Game/ 与本仓同一提交，不需要单独同步
	if [ "${LAYOUT:-}" != "nested" ]; then
		log_info "单仓布局：Game/ 随本仓一起读/写，无需单独同步业务仓"
		return 0
	fi

	branch=$(git -C "$game" symbolic-ref --quiet --short HEAD 2>/dev/null || true)

	log_info "游戏业务仓同步检查（分支: ${branch:-detached}）…"
	if ! git -C "$game" remote get-url origin >/dev/null 2>&1; then
		log_warn "游戏仓没有 origin 远端，跳过"
		return 0
	fi
	if ! git_env git -C "$game" fetch --prune origin; then
		log_warn "游戏仓 fetch 失败，跳过"
		return 0
	fi
	[ -n "$branch" ] || { log_warn "游戏仓处于 detached HEAD，跳过"; return 0; }

	if remote_ref_exists "$game" "origin/$branch"; then
		counts=$(git -C "$game" rev-list --left-right --count "origin/$branch...$branch" 2>/dev/null || true)
		behind=$(printf '%s' "$counts" | awk '{print $1}')
		ahead=$(printf '%s' "$counts" | awk '{print $2}')
		log_info "游戏仓 vs origin/${branch}：落后 ${behind:-?}，领先 ${ahead:-?}"
	else
		log_warn "游戏仓远端无分支 origin/$branch"
		return 0
	fi

	if [ "$SYNC_GAME" != "1" ]; then
		[ "${behind:-0}" = "0" ] || log_info "需要拉取时加 --sync-game（或进 Game/ 手动 git pull）"
		return 0
	fi

	if [ -n "$(git -C "$game" status --porcelain)" ]; then
		log_warn "游戏仓有未提交改动，跳过快进"
		return 0
	fi
	if [ "${behind:-0}" = "0" ]; then
		log_ok "游戏仓无落后提交"
		return 0
	fi
	if git -C "$game" merge --ff-only "origin/$branch" >/dev/null 2>&1; then
		git -C "$game" branch --set-upstream-to "origin/$branch" >/dev/null 2>&1 || true
		log_ok "游戏仓已快进: $(git -C "$game" log --oneline -1)"
	else
		log_warn "游戏仓快进失败（历史分叉或无跟踪分支），进 Game/ 手动处理"
	fi
}

run_verify() {
	[ -x "$SCRIPT_DIR/verify_project.sh" ] || return 0
	if "$SCRIPT_DIR/verify_project.sh" --project "$PROJECT"; then
		log_ok "锚定体检通过"
	else
		log_warn "锚定体检有问题，见上方 FAIL 项"
	fi
}

post_push() {
	[ "$PUSH" = "1" ] || return 0
	log_info "推送框架仓 origin…"
	git -C "$PROJECT" push origin "$BRANCH" || log_warn "推送失败，手动处理"
}

# endregion


main() {
	parse_args "$@"
	require_cmd git
	require_cmd awk

	TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/comedot-update.XXXXXX") || die "无法创建临时目录"
	trap 'rm -rf "$TMP_DIR"' EXIT

	resolve_project
	cd "$PROJECT" || die "无法进入 $PROJECT"

	resolve_branch
	fetch_upstream

	if ! show_incoming; then
		sync_game_repo
		run_verify
		exit 0
	fi

	# show_incoming 已生成 up.sorted，脏检查才能按「与上游是否重叠」判定
	check_worktree

	if [ "$DRY_RUN" = "1" ]; then
		log_info "--dry-run：未做合并。去掉 --dry-run 执行合并"
		exit 0
	fi

	if ! do_merge; then
		exit 2
	fi

	run_verify
	sync_game_repo
	post_push
	log_ok "更新完成"
}

main "$@"
