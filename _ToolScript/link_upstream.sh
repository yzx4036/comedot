#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# link_upstream.sh — 给项目仓接上「框架上游」（upstream），并禁用对它的推送
#
#   项目仓的 origin 是自己的私仓，upstream 才是框架来源；clone 下来只有 origin，
#   跑一次本脚本即可获得拉取框架更新的能力（update_project.sh 依赖它）。
#
# 用法：link_upstream.sh [上游URL] [--root <项目根>] [--no-fetch]
# ---------------------------------------------------------------------------

set -uo pipefail

# shellcheck source=lib.sh
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
load_anchor


URL=""
ROOT=""
DO_FETCH=1

usage() {
	cat <<EOF
用法: link_upstream.sh [上游URL] [选项]

  上游URL        默认 ${FRAMEWORK_UPSTREAM_URL}
  --root PATH    项目根（含 project.godot）；默认从当前目录向上查找
  --no-fetch     只配置远端，不立即 fetch
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--root)     ROOT=${2:-}; shift 2 ;;
		--no-fetch) DO_FETCH=0; shift ;;
		-h|--help)  usage; exit 0 ;;
		-*)         usage; die "未知参数: $1" ;;
		*)          URL=${1:-}; shift ;;
	esac
done

require_cmd git
[ -n "$URL" ] || URL="$FRAMEWORK_UPSTREAM_URL"

if [ -n "$ROOT" ]; then
	ROOT=$(abs_dir "$ROOT") || die "目录不存在: $ROOT"
else
	ROOT=$(find_project_root_any) || die "当前目录向上找不到 Godot 项目（project.godot）"
fi
[ -f "$ROOT/project.godot" ] || die "不是项目根（缺 project.godot）: $ROOT"

if git -C "$ROOT" remote get-url upstream >/dev/null 2>&1; then
	git -C "$ROOT" remote set-url upstream "$URL" || die "更新 upstream 失败"
	log_info "upstream 已存在，改为: $URL"
else
	git -C "$ROOT" remote add upstream "$URL" || die "添加 upstream 失败"
	log_ok "已添加 upstream: $URL"
fi

git -C "$ROOT" config remote.upstream.pushurl "DISABLED-upstream-is-read-only"
log_ok "upstream 推送已禁用（防误推污染框架上游）"

if [ "$DO_FETCH" = "1" ]; then
	log_info "fetch upstream…"
	GIT_TERMINAL_PROMPT=0 \
	GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new" \
	git -C "$ROOT" fetch --prune upstream || log_warn "fetch 失败（网络/权限），配置本身已就绪"
fi

printf '\n远端布局:\n'
git -C "$ROOT" remote -v | sed 's/^/    /'
printf '\n下一步: _ToolScript/update_project.sh --dry-run\n\n'
