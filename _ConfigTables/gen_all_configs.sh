#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gen_all_configs.sh — 一条命令生成并合并「框架表 + 全部业务表」
#
# 为什么需要它：
#   Luban 每次生成前会**清空输出目录**。
#     · 框架表输出到 Assets/Configs/GameConfigs
#     · 业务表若也输出到那里，会把框架的 examples_*.bytes 删掉
#   而运行时 ConfigMgr 只有一个 ConfigDirectory，两类表必须共处同一目录。
#   所以：各自生成到自己的目录，最后由本脚本把业务 .bytes 合并进运行目录。
#
# 顺序固定：框架先生成（会清空运行目录）→ 各业务生成到私有目录 → 合并。
#
# 用法：gen_all_configs.sh [--build] [--business NAME]
#   --build          生成后顺带 dotnet build
#   --business NAME  只处理指定业务（默认扫描 Game/ 下所有带生成脚本的业务）
# ---------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

FRAMEWORK_GEN="$SCRIPT_DIR/gen_code_framework.sh"
RUNTIME_DIR="$PROJECT_ROOT/Assets/Configs/GameConfigs"
GAME_DIR="$PROJECT_ROOT/Game"

DO_BUILD=0
ONLY_BUSINESS=""

while [ $# -gt 0 ]; do
	case "$1" in
		--build)    DO_BUILD=1; shift ;;
		--business) ONLY_BUSINESS=${2:-}; shift 2 ;;
		-h|--help)  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*)          printf '[FAIL] 未知参数: %s\n' "$1" >&2; exit 2 ;;
	esac
done

[ -f "$FRAMEWORK_GEN" ] || { printf '[FAIL] 缺少框架生成脚本: %s\n' "$FRAMEWORK_GEN" >&2; exit 2; }

# 判据：Game/<业务>/_ConfigTables/gen_code_business.sh 存在
discover_businesses() {
	local dir name
	for dir in "$GAME_DIR"/*/; do
		[ -d "$dir" ] || continue
		name=$(basename "$dir")
		[ -f "$dir/_ConfigTables/gen_code_business.sh" ] && printf '%s\n' "$name"
	done
}

if [ -n "$ONLY_BUSINESS" ]; then
	[ -f "$GAME_DIR/$ONLY_BUSINESS/_ConfigTables/gen_code_business.sh" ] \
		|| { printf '[FAIL] 业务没有生成脚本: Game/%s/_ConfigTables/gen_code_business.sh\n' "$ONLY_BUSINESS" >&2; exit 2; }
	BUSINESSES="$ONLY_BUSINESS"
else
	BUSINESSES=$(discover_businesses)
fi

printf '[INFO] 1. 框架表 → %s\n' "$RUNTIME_DIR"
bash "$FRAMEWORK_GEN" >/tmp/gen_framework.log 2>&1 || {
	printf '[FAIL] 框架表生成失败，见 /tmp/gen_framework.log\n' >&2
	tail -15 /tmp/gen_framework.log >&2
	exit 1
}

if [ -z "$BUSINESSES" ]; then
	printf '[INFO] 没有业务配置表（Game/*/_ConfigTables/gen_code_business.sh 均不存在）\n'
else
	business_index=0
	for business in $BUSINESSES; do
		business_index=$((business_index + 1))
		gen_script="$GAME_DIR/$business/_ConfigTables/gen_code_business.sh"
		business_bin="$GAME_DIR/$business/_ConfigTables/Configs/Bin"

		printf '[INFO] 2.%s 业务 %s → %s\n' "$business_index" "$business" "$business_bin"
		bash "$gen_script" >"/tmp/gen_business_${business}.log" 2>&1 || {
			printf '[FAIL] 业务 %s 生成失败，见 /tmp/gen_business_%s.log\n' "$business" "$business" >&2
			tail -15 "/tmp/gen_business_${business}.log" >&2
			exit 1
		}

		merged=0
		for bytes in "$business_bin"/*.bytes; do
			[ -f "$bytes" ] || continue
			cp "$bytes" "$RUNTIME_DIR/" || { printf '[FAIL] 复制失败: %s\n' "$bytes" >&2; exit 1; }
			merged=$((merged + 1))
		done
		printf '       合并 %s 个 .bytes\n' "$merged"
	done
fi

# 自检：框架表必须齐全（业务表少了会让 ConfigMgr 整体加载失败，这里先兜住最常见的一类）
missing=0
for name in examples_tbexamplebasic examples_tbexampleadvance examples_tbexamplelist examples_tbexamplesingleton; do
	[ -f "$RUNTIME_DIR/$name.bytes" ] || { printf '[FAIL] 运行目录缺少框架表 %s.bytes\n' "$name" >&2; missing=1; }
done
[ "$missing" = "0" ] || exit 1

total=$(ls -1 "$RUNTIME_DIR"/*.bytes 2>/dev/null | wc -l | tr -d ' ')
printf '[ OK ] 运行目录共 %s 张表:\n' "$total"
ls -1 "$RUNTIME_DIR"/*.bytes | sed 's|^.*/|       |'

if [ "$DO_BUILD" = "1" ]; then
	printf '[INFO] dotnet build…\n'
	( cd "$PROJECT_ROOT" && dotnet build Comedot.csproj -v q --nologo ) || exit 1
fi

printf '\n下一步: Game/MyGame/Tests/Regression/runAll.sh\n'
