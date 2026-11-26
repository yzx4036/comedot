#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# audit_production.sh — 扫框架层，产出「生产可用性基线」报告
#
#   · 组件稳定性分级：整类 @experimental（慎用）vs 仅局部成员标记（本体可用）
#   · 已知运行期故障清单（本仓实测踩到并规避过的）
#   · 门禁结果：回归套件是否全绿
#
# 输出：docs/production-readiness.md（可提交）+ stdout 摘要
# 用法：audit_production.sh [--no-tests]
#
# 框架升级后重跑一次即可刷新基线；不要手改产出的 md。
# ---------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROJECT_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
OUT_FILE="$PROJECT_ROOT/docs/production-readiness.md"

RUN_TESTS=1

while [ $# -gt 0 ]; do
	case "$1" in
		--no-tests) RUN_TESTS=0; shift ;;
		-h|--help)  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*)          printf '[FAIL] 未知参数: %s\n' "$1" >&2; exit 2 ;;
	esac
done

[ -d "$PROJECT_ROOT/Components" ] || { printf '[FAIL] 找不到 Components/: %s\n' "$PROJECT_ROOT" >&2; exit 2; }

TMP_DIR="${TMPDIR:-/tmp}/comedot-audit.$$"
mkdir -p "$TMP_DIR" || exit 2
trap 'rm -rf "$TMP_DIR"' EXIT


# region 扫描组件稳定性

# 每个组件文件 → 一行 "整类|局部 <次数> <相对路径>"
scan_components() {
	local file rel class_line first_mark line_no marks is_class
	find "$PROJECT_ROOT/Components" -name '*.gd' | sort | while IFS= read -r file; do
		grep -q '@experimental' "$file" || continue

		rel=${file#"$PROJECT_ROOT"/Components/}
		rel=${rel%.gd}

		# class_name / extends 的首次出现行号（类声明起点）
		class_line=$(grep -n -m1 -E '^(class_name|extends) ' "$file" | cut -d: -f1)
		# 第一处 @experimental 的行号
		first_mark=$(grep -n -m1 '@experimental' "$file" | cut -d: -f1)

		# @experimental 出现在类声明之前 ⇒ 整类标记；否则只是某个成员
		if [ -n "$class_line" ] && [ "$first_mark" -lt "$class_line" ]; then
			printf '整类|0|%s\n' "$rel"
		else
			marks=$(grep -c '@experimental' "$file")
			printf '局部|%s|%s\n' "$marks" "$rel"
		fi
	done
}

# endregion


# region 统计

TOTAL_COMPONENTS=$(find "$PROJECT_ROOT/Components" -name '*.gd' | wc -l | tr -d ' ')
scan_components > "$TMP_DIR/components.txt"

CLASS_LEVEL=$(grep '^整类|' "$TMP_DIR/components.txt" | wc -l | tr -d ' ')
MEMBER_FILES=$(grep '^局部|' "$TMP_DIR/components.txt" | wc -l | tr -d ' ')
MEMBER_MARKS=$(grep '^局部|' "$TMP_DIR/components.txt" | awk -F'|' '{s+=$2} END {print s+0}')
STABLE=$((TOTAL_COMPONENTS - CLASS_LEVEL))

# endregion


# region 回归门禁

TEST_RESULT="未运行"
TEST_DETAIL=""
if [ "$RUN_TESTS" = "1" ]; then
	printf '[INFO] 跑回归门禁…\n'
	if "$PROJECT_ROOT/Game/MyGame/Tests/Regression/runAll.sh" --skip-screenshot \
		> "$TMP_DIR/tests.log" 2>&1
	then
		TEST_RESULT="PASS"
	else
		TEST_RESULT="FAIL"
	fi
	TEST_DETAIL=$(grep -E '^(Check|Probe|Capture)[A-Za-z]+ +(PASS|FAIL|SKIP)' "$TMP_DIR/tests.log" || true)
fi

# endregion


# region 输出

{
	printf '# comedot 生产可用性基线\n'
	printf '\n'
	printf '> 由 `_ToolScript/audit_production.sh` 生成于 %s。**不要手改**，框架升级后重跑。\n' "$(date '+%Y-%m-%d %H:%M')"
	printf '> 引擎：%s\n' "$(grep -m1 'config/features' "$PROJECT_ROOT/project.godot" | sed 's/.*=//')"
	printf '\n'
	printf '## 1. 组件稳定性\n'
	printf '\n'
	printf '| 指标 | 数量 |\n'
	printf '|---|---|\n'
	printf '| 组件总数 | %s |\n' "$TOTAL_COMPONENTS"
	printf '| **整类 @experimental**（慎用，不当地基） | %s |\n' "$CLASS_LEVEL"
	printf '| 仅局部成员标记（组件本体可用） | %s 个文件 / %s 处标记 |\n' "$MEMBER_FILES" "$MEMBER_MARKS"
	printf '| 可直接用作地基 | %s |\n' "$STABLE"
	printf '\n'
	printf '⚠️ `@experimental` 是**逐成员**标记，不是整类标记。判据：标记出现在 `class_name`/`extends` 之前才算整类。\n'
	printf '按文件 grep 会把 `Component` 基类、`CharacterBodyComponent`、`PlatformerPhysicsComponent` 这类\n'
	printf '「只有一个方法/可选项实验」的核心组件误判成不可用。\n'
	printf '\n'

	printf '### 整类 experimental — 不要当生产地基（%s 个）\n' "$CLASS_LEVEL"
	printf '\n'
	grep '^整类|' "$TMP_DIR/components.txt" | cut -d'|' -f3 | while IFS= read -r rel; do
		printf -- '- `%s`\n' "$rel"
	done
	printf '\n'

	printf '### 仅局部成员 experimental — 本体可用，避开标了的那几个成员（%s 个文件）\n' "$MEMBER_FILES"
	printf '\n'
	printf '| 组件 | 标记数 |\n'
	printf '|---|---|\n'
	grep '^局部|' "$TMP_DIR/components.txt" | awk -F'|' '{printf "| `%s` | %s |\n", $3, $2}'
	printf '\n'

	printf '## 2. 已知运行期故障（本仓实测踩到并规避）\n'
	printf '\n'
	printf '这些是框架侧的问题，不是用法错误。升级上游后应重验，修好了就从下表删掉。\n'
	printf '\n'
	printf '| 症状 | 触发条件 | 规避 |\n'
	printf '|---|---|---|\n'
	printf '| 调用即报 `Nonexistent function ... in base '"'"'GDScript'"'"'` | 调 `FileSystemTools.findAllSubfolders()` / `getFilesInFolder()`（框架自身 `GlobalSonic` 启动时也踩） | 目录遍历改用 `DirAccess.get_directories_at()` / `get_files_at()` 自递归 |\n'
	printf '| 引擎 `Abort trap: 6` | 二次实例化 `UI/PauseOverlay.tscn`（由 `GlobalUI` 托管） | 不要自己实例化，交给 `GlobalUI` |\n'
	printf '| 加载即崩，报 `previously freed` | 加载 `Tests/TurnBased/TurnBasedTest.tscn`（依赖启动时被自删的 `TurnBasedCoordinator`） | 用前把 `ComedotProjectSettings.isTurnBasedGame` 设为 true |\n'
	printf '| 加载报「配置文件不存在」 | `LubanConfigService` 用默认 `ConfigDirectory` | 显式设为 `res://Assets/Configs/GameConfigs` |\n'
	printf '| 取字段恒为 null | 照 Excel/JSON 的 snake_case 写字段名 | 用 PascalCase：`&"SomeLongValue"` 不是 `&"some_long_value"` |\n'
	printf '| `singleton register twice! TbExampleXxx`，整个 ConfigMgr 加载失败 | 进程里 new 了第二个 `LubanConfigService`（Luban 表类是 C# 静态单例） | 全项目只由一个 autoload 持有（本仓为 `GameConfigHub`），各场景统一向它取 |\n'
	printf '| `Identifier not found: GameState`，随后「方法不存在」 | 用 `--script` 模式跑依赖框架组件的代码（autoload 在编译后注册） | 改用场景模式：`Godot --headless --path . --quit-after N res://<x>.tscn` |\n'
	printf '| `Could not find type "Xxx"` | 新增带 `class_name` 的脚本后直接 headless 跑（全局类缓存未刷新） | 先 `Godot --headless --path . --import` |\n'
	printf '| 配置表生成报「You must install or update .NET」 | `Luban.dll` 面向 .NET 8，机器只有更新运行时 | `DOTNET_ROLL_FORWARD=LatestMajor`（`gen_code_framework.sh` 已内置） |\n'
	printf '| 生成后一堆 `.uid` 显示删除 | Luban 清输出目录时删掉 Godot 的 `.uid` | 生成后 `git restore` 对应目录 |\n'
	printf '\n'

	printf '## 3. 回归门禁\n'
	printf '\n'
	if [ "$TEST_RESULT" = "未运行" ]; then
		printf '未运行（`--no-tests`）。\n'
	else
		printf '`Game/MyGame/Tests/Regression/runAll.sh --skip-screenshot` → **%s**\n' "$TEST_RESULT"
		printf '\n'
		if [ -n "$TEST_DETAIL" ]; then
			printf '```\n%s\n```\n' "$TEST_DETAIL"
			printf '\n'
		fi
	fi
	printf '生产改动的最低门禁：这条命令必须 PASS。\n'
	printf '\n'
	printf '本审计用 `--skip-screenshot` 跑，因此四个窗口模式检查（索引截图、shader A/B、特效播放、关卡明暗层）会记 SKIP；\n'
	printf '有图形环境时不带参数跑同一脚本，这几项也会执行并给出 PASS。\n'
	printf '每项检查的判据与「为什么这么判」见 `docs/regression-gates.md`。\n'
	printf '\n'

	printf '## 4. 落地纪律\n'
	printf '\n'
	printf '1. **地基只用第 1 节里「可直接用作地基」的组件**；整类 experimental 当参考，不当依赖。\n'
	printf '2. **框架层改动单独成提交**，一条提交一个改动，便于日后 cherry-pick 提 PR 给上游。\n'
	printf '3. **业务代码放 `Game/<业务>/`**，不要写进框架目录（`verify_project.sh` 会查越界）。\n'
	printf '4. **上游升级前先跑 `_ToolScript/update_project.sh --dry-run`**，并保留 `Game/` 不动。\n'
	printf '5. **配置文件、美术资源等的路径用 `res://`**，不要写本机绝对路径（公开仓硬约束）。\n'
} > "$OUT_FILE" || { printf '[FAIL] 写入失败: %s\n' "$OUT_FILE" >&2; exit 1; }

# endregion


printf '\n'
printf '[ OK ] 报告已写入: %s\n' "$OUT_FILE"
printf '       组件 %s 个：整类 experimental %s，仅局部标记 %s 个文件，可作地基 %s\n' \
	"$TOTAL_COMPONENTS" "$CLASS_LEVEL" "$MEMBER_FILES" "$STABLE"
printf '       回归门禁: %s\n' "$TEST_RESULT"

[ "$TEST_RESULT" = "FAIL" ] && exit 1
exit 0
