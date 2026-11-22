#!/usr/bin/env bash
# macOS / Linux 版 Luban 生成（等价于 _ConfigTables/gen_code_framework.bat）
# 用法：gen_code_framework.sh
set -uo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
WORKSPACE=$(cd "$SCRIPT_DIR/.." && pwd)
CONF_ROOT="$SCRIPT_DIR/Excel"
LUBAN_DLL="$SCRIPT_DIR/Luban/Release/Luban.dll"

OUTPUT_CODE_DIR="$WORKSPACE/Scripts/Mono/Luban/Configs/AutoGen"
OUTPUT_DATA_DIR="$WORKSPACE/Assets/Configs/GameConfigs"
OUTPUT_JSON_DIR="$SCRIPT_DIR/Configs/Json"

[ -f "$LUBAN_DLL" ] || { echo "缺少 $LUBAN_DLL" >&2; exit 1; }
command -v dotnet >/dev/null 2>&1 || { echo "需要 dotnet" >&2; exit 1; }

# Luban.dll 面向 .NET 8；本机若只装了更新的运行时，靠 roll-forward 顶上去。
# 不设这个的话报「You must install or update .NET to run this application」。
export DOTNET_ROLL_FORWARD="${DOTNET_ROLL_FORWARD:-LatestMajor}"

echo "======================= Framework Config (C#) =========================="
dotnet "$LUBAN_DLL" \
	--customTemplateDir "$SCRIPT_DIR/Luban/CustomTemplate" \
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
	echo "Luban generation FAILED (exit $status)." >&2
	exit 1
fi
echo "Framework config generation done."
