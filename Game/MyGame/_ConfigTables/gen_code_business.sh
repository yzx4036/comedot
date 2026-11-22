#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# gen_code_business.sh — 生成 MyGame 业务配置表（macOS / Linux / git-bash）
#
#   Excel 源表 → C# 表类 + 运行时 .bytes + 可读 .json
#
# 落点之所以这样定（改之前先读）：
#   · C# 必须生成到 Scripts/Mono/Luban/Configs/GameAutoGen/
#     业务侧 Comedot.csproj 有 <Compile Remove="Game/**/*.cs" />，
#     C# 放在 Game/ 下不会被编译；而 ConfigMgr 只扫自己所在程序集里的表类，
#     所以业务表类必须进框架程序集，只能落在 Scripts/ 下。
#   · 命名空间由 luban.conf 的 topModule 决定，必须是 Y0Studio.Config.MyGame，
#     这样 ConfigMgr 用默认前缀 Y0Studio.Config 就能连带扫到业务表。
#   · 数据与 json 与框架表同目录，靠表名前缀（mygame_*）区分。
#
# 用法：gen_code_business.sh
# ---------------------------------------------------------------------------

set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
GAME_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
PROJECT_ROOT=$(cd "$GAME_DIR/../.." && pwd)

CONF_ROOT="$SCRIPT_DIR/Excel"
LUBAN_DLL="$PROJECT_ROOT/_ConfigTables/Luban/Release/Luban.dll"
CUSTOM_TEMPLATE="$PROJECT_ROOT/_ConfigTables/Luban/CustomTemplate"

# 业务表产物。
# ⚠️ bin 必须输出到业务自己的目录：Luban 生成前会**清空输出目录**，
# 直接写 Assets/Configs/GameConfigs 会把框架的 examples_*.bytes 一起删掉。
# 合并进运行目录由 _ConfigTables/gen_all_configs.sh 统一做。
OUTPUT_CODE_DIR="$PROJECT_ROOT/Scripts/Mono/Luban/Configs/GameAutoGen"
OUTPUT_DATA_DIR="$SCRIPT_DIR/Configs/Bin"
OUTPUT_JSON_DIR="$SCRIPT_DIR/Configs/Json"

[ -f "$LUBAN_DLL" ] || { echo "缺少 Luban: $LUBAN_DLL" >&2; exit 1; }
[ -f "$CONF_ROOT/luban.conf" ] || { echo "缺少业务表配置: $CONF_ROOT/luban.conf" >&2; exit 1; }
command -v dotnet >/dev/null 2>&1 || { echo "需要 dotnet" >&2; exit 1; }

# Luban.dll 面向 .NET 8；只装了更新运行时的机器靠 roll-forward
export DOTNET_ROLL_FORWARD="${DOTNET_ROLL_FORWARD:-LatestMajor}"

mkdir -p "$OUTPUT_CODE_DIR" "$OUTPUT_DATA_DIR" "$OUTPUT_JSON_DIR" || exit 1

echo "======================= MyGame Config (C#) =========================="
dotnet "$LUBAN_DLL" \
	--customTemplateDir "$CUSTOM_TEMPLATE" \
	-t client \
	-c cs-bin \
	-d json \
	-d bin \
	--conf "$CONF_ROOT/luban.conf" \
	-x outputCodeDir="$OUTPUT_CODE_DIR" \
	-x json.outputDataDir="$OUTPUT_JSON_DIR" \
	-x bin.outputDataDir="$OUTPUT_DATA_DIR" \
	--excludeTag dev

status=$?
if [ "$status" -ne 0 ]; then
	echo "业务配置表生成失败 (exit $status)." >&2
	exit 1
fi

echo "业务配置表生成完成。"
echo "  C#  : $OUTPUT_CODE_DIR"
echo "  数据: $OUTPUT_DATA_DIR  (mygame_*.bytes)"
echo "  JSON: $OUTPUT_JSON_DIR"
echo
echo "下一步: dotnet build Comedot.csproj 之后跑 Game/MyGame/Tests/Regression/runAll.sh"
