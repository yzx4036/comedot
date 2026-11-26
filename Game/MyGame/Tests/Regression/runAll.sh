#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# runAll.sh — 跑功能测试台的全部验收（Game/MyGame/Tests/Regression/）
#
#   1) CheckTestbed              结构与交互断言（headless）
#   2) CheckAllDemoScenes        逐个开关清单里所有演示场景（headless）
#   3) ProbeDemoScene            单场景安全性探针冒烟（headless，验探针自身可用）
#   4) CaptureTestbedScreenshot  功能索引 + 演示视图截图（窗口模式，可跳过）
#
# 用法：runAll.sh [--skip-screenshot] [--verbose]
#
# 引擎：优先用环境变量 GODOT_BIN，否则按平台探测。跨设备时必须先设 GODOT_BIN。
# 退出码：0 = 全部通过；1 = 有失败项；2 = 环境问题（找不到引擎/项目根）
# ---------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/../../../.." && pwd)

CHECK_TESTBED_REL="Game/MyGame/Tests/Regression/CheckTestbed.gd"
CHECK_DEMOS_REL="Game/MyGame/Tests/Regression/CheckAllDemoScenes.gd"
CHECK_CONFIG_REL="Game/MyGame/Tests/Regression/CheckConfigTables.gd"
CHECK_BIZ_CONFIG_REL="Game/MyGame/Tests/Regression/CheckBusinessConfigTables.gd"
CHECK_GAMEPLAY_REL="Game/MyGame/Tests/Regression/CheckConfigDrivenGameplay.tscn"
PROBE_SCENE_REL="Game/MyGame/Tests/Regression/ProbeDemoScene.gd"
SHOT_REL="Game/MyGame/Tests/Regression/CaptureTestbedScreenshot.gd"
LUT_CAPTURE_REL="Game/MyGame/Tests/Regression/CaptureLutCanvas.tscn"
FX_CHECK_REL="Game/MyGame/Tests/Regression/CheckFxPlayback.tscn"
LEVEL_SHADE_REL="Game/MyGame/Tests/Regression/CaptureLevelShade.tscn"
LIGHTING_REL="Game/MyGame/Tests/Regression/CaptureLutLighting.tscn"

# headless 脚本的兜底帧数：脚本自身出错时 quit() 到不了，靠它避免挂死
QUIT_AFTER_CHECK=900
QUIT_AFTER_DEMOS=2400
QUIT_AFTER_CONFIG=900
QUIT_AFTER_BIZ_CONFIG=900
QUIT_AFTER_GAMEPLAY=1500
QUIT_AFTER_PROBE=600

SKIP_SCREENSHOT=0

FAILS=0
WARNS=0
SUMMARY=""
LOG_DIR="${TMPDIR:-/tmp}/comedot-testbed-checks.$$"
GODOT=""


# region 日志

log_info() { printf '[INFO] %s\n' "$*"; }
log_ok()   { printf '[ OK ] %s\n' "$*"; }
log_warn() { printf '[WARN] %s\n' "$*" >&2; WARNS=$((WARNS + 1)); }
log_err()  { printf '[FAIL] %s\n' "$*" >&2; }

die() { log_err "$*"; exit 2; }

# $1=名称 $2=结果 $3=附注
record() { SUMMARY="${SUMMARY}$(printf '%-26s %-5s %s' "$1" "$2" "$3")"$'\n'; }

# endregion


# region 参数与引擎

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
			--skip-screenshot) SKIP_SCREENSHOT=1; shift ;;
			--verbose)         VERBOSE=1; shift ;;
			-h|--help)         sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
			*)                 die "未知参数: $1" ;;
		esac
	done
}

resolve_godot() {
	if [ -n "${GODOT_BIN:-}" ]; then
		[ -x "$GODOT_BIN" ] || die "GODOT_BIN 不可执行: $GODOT_BIN"
		printf '%s' "$GODOT_BIN"
		return 0
	fi

	local candidate
	for candidate in \
		"/Applications/Godot_mono.app/Contents/MacOS/Godot" \
		"/Applications/Godot.app/Contents/MacOS/Godot" \
		"$HOME/Applications/Godot_mono.app/Contents/MacOS/Godot"
	do
		[ -x "$candidate" ] && { printf '%s' "$candidate"; return 0; }
	done

	candidate=$(command -v godot 2>/dev/null || true)
	[ -n "$candidate" ] && { printf '%s' "$candidate"; return 0; }
	candidate=$(command -v godot4 2>/dev/null || true)
	[ -n "$candidate" ] && { printf '%s' "$candidate"; return 0; }

	return 1
}

check_environment() {
	[ -f "$PROJECT_ROOT/project.godot" ] \
		|| die "找不到项目根（缺 project.godot）: $PROJECT_ROOT"

	local rel
	for rel in "$CHECK_TESTBED_REL" "$CHECK_DEMOS_REL" "$CHECK_CONFIG_REL" "$CHECK_BIZ_CONFIG_REL" "$CHECK_GAMEPLAY_REL" "$PROBE_SCENE_REL" "$SHOT_REL"; do
		[ -f "$PROJECT_ROOT/$rel" ] || die "缺少验收脚本: $rel"
	done

	GODOT=$(resolve_godot) || die "找不到 Godot 可执行文件：设置 GODOT_BIN=<路径> 后重试"
	log_info "引擎: $GODOT"
	log_info "项目: $PROJECT_ROOT"

	[ -d "$PROJECT_ROOT/.godot" ] \
		|| log_warn "项目还没导入过（缺 .godot/）：先跑一次 Godot --headless --path . --import"

	# 刷新 class_name 全局类缓存：新增带 class_name 的脚本后，headless 直接跑
	# 会报 `Could not find type "Xxx"`（缓存里没有），必须先 import 一次。
	if [ "${SKIP_IMPORT:-0}" != "1" ]; then
		printf '[INFO] 刷新导入缓存（注册新 class_name）…\n'
		( cd "$PROJECT_ROOT" && "$GODOT" --headless --path . --import >/dev/null 2>&1 ) \
			|| log_warn "import 失败，可能碰到新脚本的 class_name 找不到"
	fi
}

# endregion


# region 通用执行

# $1=脚本相对路径 $2=--quit-after 帧数 $3=日志文件 $4...=传给脚本的 user args
# 返回值为引擎退出码
run_godot_script() {
	local rel=$1 frames=$2 log_file=$3
	shift 3

	: > "$log_file"
	( cd "$PROJECT_ROOT" && "$GODOT" --headless --path . --script "$rel" \
		--quit-after "$frames" --log-file "$log_file" -- "$@" >/dev/null 2>&1 )
}

# 场景模式：把 .tscn 当主场景跑。
# 用于必须依赖 autoload（GameState / SceneManager / 业务 autoload）的检查 ——
# `--script` 模式在 autoload 注册前编译脚本，碰到引用 autoload 的框架脚本会编译失败。
run_godot_scene() {
	local rel=$1 frames=$2 log_file=$3

	: > "$log_file"
	( cd "$PROJECT_ROOT" && "$GODOT" --headless --path . --quit-after "$frames" \
		--log-file "$log_file" "res://$rel" >/dev/null 2>&1 )
}

print_tail() {
	local log_file=$1
	[ -f "$log_file" ] || return 0
	log_info "日志末尾:"
	tail -15 "$log_file" | sed 's/^/       /'
}

# 退出时 "resources still in use at exit" 是引擎收尾噪音，与被测内容无关
report_runtime_errors() {
	local name=$1 log_file=$2 errors
	errors=$(grep -E 'SCRIPT ERROR|^ERROR:' "$log_file" 2>/dev/null \
		| grep -v 'resources still in use at exit' || true)
	[ -n "$errors" ] || return 0

	log_warn "$name 日志里有运行期报错（不阻断，但请确认是否与本次改动相关）:"
	printf '%s\n' "$errors" | sed 's/^/       /' | head -10
}

# endregion


# region 各项检查

# 场景模式检查：$1=显示名 $2=场景相对路径 $3=帧数
# 结果判定与 run_headless_check 相同（AUTO_RESULT PASS / SKIP / 其余 FAIL）
run_scene_check() {
	local name=$1 rel=$2 frames=$3
	local log_file="$LOG_DIR/$name.log"

	log_info "── ${name}（场景模式）──────────────"

	run_godot_scene "$rel" "$frames" "$log_file"
	local exit_code=$?

	if grep -q 'AUTO_RESULT SKIP' "$log_file" 2>/dev/null; then
		local skipReason
		skipReason=$(grep 'AUTO_RESULT SKIP' "$log_file" | tail -1 | sed 's/^AUTO_RESULT SKIP  *//')
		log_info "$name → 跳过：$skipReason"
		record "$name" "SKIP" "$skipReason"
		return 0
	fi

	if [ "$exit_code" -ne 0 ] || ! grep -q 'AUTO_RESULT PASS' "$log_file" 2>/dev/null; then
		log_err "$name 没有通过（退出码 ${exit_code}）"
		print_tail "$log_file"
		FAILS=$((FAILS + 1))
		record "$name" "FAIL" "退出码 ${exit_code}"
		return 1
	fi

	local headline
	headline=$(grep 'AUTO_RESULT PASS' "$log_file" | tail -1 | sed 's/^AUTO_RESULT PASS  *//')
	log_ok "$name → $headline"
	report_runtime_errors "$name" "$log_file"
	record "$name" "PASS" "$headline"
	return 0
}

# $1=显示名 $2=脚本相对路径 $3=帧数 $4=成功标记串
# 识别三种结局：PASS 标记 / SKIP 标记（环境未就绪，不算失败）/ 其余为 FAIL
run_headless_check() {
	local name=$1 rel=$2 frames=$3 marker=$4
	local log_file="$LOG_DIR/$name.log"

	log_info "── $name ──────────────────────────────"

	run_godot_script "$rel" "$frames" "$log_file"
	local exit_code=$?

	if [ "$exit_code" -ne 0 ]; then
		log_err "$name 执行失败（退出码 ${exit_code}）"
		print_tail "$log_file"
		FAILS=$((FAILS + 1))
		record "$name" "FAIL" "退出码 ${exit_code}"
		return 1
	fi

	# 环境未就绪（如 C# 未编译）由脚本自己声明 SKIP，别记成失败
	if grep -q 'AUTO_RESULT SKIP' "$log_file" 2>/dev/null; then
		local skipReason
		skipReason=$(grep 'AUTO_RESULT SKIP' "$log_file" | tail -1 | sed 's/^AUTO_RESULT SKIP  *//')
		log_info "$name → 跳过：$skipReason"
		record "$name" "SKIP" "$skipReason"
		return 0
	fi

	if ! grep -q "$marker" "$log_file" 2>/dev/null; then
		log_err "$name 没有通过：输出里找不到 $marker"
		print_tail "$log_file"
		FAILS=$((FAILS + 1))
		record "$name" "FAIL" "无 $marker"
		return 1
	fi

	local headline
	headline=$(grep "$marker" "$log_file" | tail -1 | sed "s/^$marker  *//")
	log_ok "$name → $headline"
	report_runtime_errors "$name" "$log_file"
	record "$name" "PASS" "$headline"
	return 0
}


## 用清单里第一个演示场景验一次探针自身可用（探针坏了要能立刻知道）
run_probe_smoke() {
	local name="ProbeDemoScene"
	local log_file="$LOG_DIR/$name.log"

	log_info "── ${name}（探针冒烟）──────────────────"

	local scene
	scene=$(grep -oE 'FrameworkFeature\.new\("[^"]*", "[^"]*", "[^"]*", "[^"]*", "res://[^"]*"' \
		"$PROJECT_ROOT/Game/MyGame/Scripts/UI/FrameworkFeatureCatalog.gd" 2>/dev/null \
		| head -1 | sed -E 's/.*"(res:\/\/[^"]*)"$/\1/')

	if [ -z "$scene" ]; then
		log_warn "$name 清单里找不到演示场景，跳过"
		record "$name" "SKIP" "无演示场景"
		return 0
	fi

	run_godot_script "$PROBE_SCENE_REL" "$QUIT_AFTER_PROBE" "$log_file" "$scene"
	local exit_code=$?

	if [ "$exit_code" -ne 0 ] || ! grep -q 'PROBE_OK' "$log_file" 2>/dev/null; then
		log_err "$name 探针没能正常完成: $scene"
		print_tail "$log_file"
		FAILS=$((FAILS + 1))
		record "$name" "FAIL" "无 PROBE_OK"
		return 1
	fi

	log_ok "$name → PROBE_OK $scene"
	report_runtime_errors "$name" "$log_file"
	record "$name" "PASS" "探针可用"
	return 0
}


## 窗口模式截图：headless 拿不到渲染；等日志出结果再按脚本名收窄收掉进程
run_screenshot() {
	local name="CaptureTestbedScreenshot"
	local log_file="$LOG_DIR/$name.log"

	log_info "── ${name}（窗口模式）──────────────────"

	if [ "$SKIP_SCREENSHOT" = "1" ]; then
		log_info "--skip-screenshot：跳过"
		record "$name" "SKIP" "--skip-screenshot"
		return 0
	fi

	# 无图形环境时 Godot 也开不出窗口，直接跳过而不是算失败
	if [ "$(uname -s)" != "Darwin" ] \
		&& [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
		log_info "无图形环境，跳过截图"
		record "$name" "SKIP" "无图形环境"
		return 0
	fi

	local mode saved_count=0
	for mode in index demo; do
		: > "$log_file"
		# 用 subshell + exec，让子进程直接替换成 Godot，$! 拿到的就是引擎 pid
		( cd "$PROJECT_ROOT" && exec "$GODOT" --path . --script "$SHOT_REL" \
			--log-file "$log_file" -- "$mode" >/dev/null 2>&1 ) &
		local godot_pid=$!

		# 渲染通常几秒完成，这里只是兜底上限
		local waited=0
		while [ "$waited" -lt 40 ]; do
			sleep 1
			waited=$((waited + 1))
			grep -qE 'SHOT_SAVED|SHOT_FAIL|SHOT_SKIPPED' "$log_file" 2>/dev/null && break
		done

		# 只收这一条命令起的进程（按 pid 收窄，不碰用户其它 Godot 窗口）；
		# wait 顺带回收子进程，避免 bash 打印 "Terminated" 作业通知
		kill "$godot_pid" 2>/dev/null || true
		wait "$godot_pid" 2>/dev/null || true

		if grep -q 'SHOT_SAVED' "$log_file" 2>/dev/null; then
			log_ok "截图($mode): $(grep 'SHOT_SAVED' "$log_file" | tail -1 | sed 's/^SHOT_SAVED  *//')"
			saved_count=$((saved_count + 1))
		else
			log_warn "截图($mode) 未成功:"
			tail -5 "$log_file" 2>/dev/null | sed 's/^/       /'
		fi
	done

	if [ "$saved_count" -ge 1 ]; then
		record "$name" "PASS" "$saved_count/2 张"
		return 0
	fi
	FAILS=$((FAILS + 1))
	record "$name" "FAIL" "0/2 张"
	return 1
}


## 窗口模式的场景验收：需要真实渲染才能断言视觉
## $1=名称  $2=场景路径  $3=结果标记（VERDICT / AUTO_RESULT）  $4=明细回显正则
run_window_check() {
	local name=$1 rel=$2 marker=$3 echo_pattern=$4
	local log_file="$LOG_DIR/$name.log"

	log_info "── ${name}（窗口模式）──────────────────"

	if [ "$SKIP_SCREENSHOT" = "1" ]; then
		log_info "--skip-screenshot：跳过"
		record "$name" "SKIP" "--skip-screenshot"
		return 0
	fi

	if [ "$(uname -s)" != "Darwin" ] \
		&& [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
		log_info "无图形环境，跳过"
		record "$name" "SKIP" "无图形环境"
		return 0
	fi

	: > "$log_file"
	( cd "$PROJECT_ROOT" && exec "$GODOT" --path . "$rel" \
		--log-file "$log_file" >/dev/null 2>&1 ) &
	local godot_pid=$!

	# 脚本自己会 quit，这里只是兜底上限
	local waited=0
	while [ "$waited" -lt 60 ]; do
		sleep 1
		waited=$((waited + 1))
		grep -qE "^${marker} (PASS|FAIL)" "$log_file" 2>/dev/null && break
	done

	kill "$godot_pid" 2>/dev/null || true
	wait "$godot_pid" 2>/dev/null || true

	local verdict headline
	verdict=$(grep -E "^${marker} (PASS|FAIL)" "$log_file" 2>/dev/null | tail -1 | awk '{print $2}')
	headline=$(grep -E "^${marker} PASS" "$log_file" 2>/dev/null | tail -1 | sed "s/^${marker} PASS  *//")

	# 明细一律回显，方便判断是"真过"还是"没跑到"
	if [ -n "$echo_pattern" ]; then
		grep -E "$echo_pattern" "$log_file" 2>/dev/null | sed 's/^/       /'
	fi
	grep -E '^  FAIL ' "$log_file" 2>/dev/null | sed 's/^/       /'

	if [ "$verdict" = "PASS" ]; then
		log_ok "$name PASS"
		record "$name" "PASS" "${headline:-通过}"
		return 0
	fi

	if [ -z "$verdict" ]; then
		log_warn "$name 未产生 ${marker}（可能没跑起来）"
		record "$name" "WARN" "无 ${marker}"
		return 0
	fi

	log_warn "$name FAIL"
	FAILS=$((FAILS + 1))
	record "$name" "FAIL" "见日志"
	return 1
}


## LutCanvas 明暗 shader 的 A/B 验收
run_lut_canvas() {
	run_window_check "CaptureLutCanvas" "$LUT_CAPTURE_REL" "VERDICT" \
		'^(RAMP|PALETTE_SIZE|PALETTE_CONTAINMENT|SWATCH|HUE_DRIFT|SAT_DELTA|REGION) '
}


## pixelfx 特效的 SpriteFrames 播放验收
run_fx_playback() {
	run_window_check "CheckFxPlayback" "$FX_CHECK_REL" "AUTO_RESULT" '^FX '
}


## LevelPlay 接入 LutCanvas 后的 A/B 验收
run_level_shade() {
	run_window_check "CaptureLevelShade" "$LEVEL_SHADE_REL" "VERDICT" \
		'^(RAMP|LEVEL|DEFAULT_SHADE|PLAY_DIFF|LAYER_MARKER) '
}


## LutCanvas 光照驱动的验收：同色铺底在两种驱动下的差异
run_lut_lighting() {
	run_window_check "CaptureLutLighting" "$LIGHTING_REL" "VERDICT" \
		'^(RAMP|OFF|SELF|LIGHT) '
}

# endregion


main() {
	parse_args "$@"
	mkdir -p "$LOG_DIR" || die "无法创建日志目录: $LOG_DIR"
	trap 'rm -rf "$LOG_DIR"' EXIT

	check_environment

	run_headless_check "CheckTestbed"       "$CHECK_TESTBED_REL" "$QUIT_AFTER_CHECK" "AUTO_RESULT PASS" || true
	run_headless_check "CheckAllDemoScenes" "$CHECK_DEMOS_REL"   "$QUIT_AFTER_DEMOS" "AUTO_RESULT PASS" || true
	run_headless_check "CheckConfigTables"  "$CHECK_CONFIG_REL"  "$QUIT_AFTER_CONFIG" "AUTO_RESULT PASS" || true
	run_headless_check "CheckBusinessConfigTables" "$CHECK_BIZ_CONFIG_REL" "$QUIT_AFTER_BIZ_CONFIG" "AUTO_RESULT PASS" || true
	run_scene_check    "CheckConfigDrivenGameplay" "$CHECK_GAMEPLAY_REL" "$QUIT_AFTER_GAMEPLAY" || true
	run_probe_smoke || true
	run_screenshot || true
	run_lut_canvas || true
	run_fx_playback || true
	run_level_shade || true
	run_lut_lighting || true

	printf '\n════════════════════════════════════════════════════\n'
	printf '汇总\n'
	printf '════════════════════════════════════════════════════\n'
	printf '%s' "$SUMMARY"

	printf '\n'
	if [ "$FAILS" = "0" ]; then
		printf '结论：PASS（%d 项 WARN）\n' "$WARNS"
		exit 0
	fi
	printf '结论：FAIL（%d 项失败，%d 项 WARN）\n' "$FAILS" "$WARNS"
	exit 1
}

main "$@"
