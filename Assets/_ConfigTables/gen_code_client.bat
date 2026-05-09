cd /D %~dp0
set "scriptDir=%~dp0"

set WORKSPACE=%scriptDir%/..\

set LUBAN_DLL=%scriptDir%/Luban\Release\Luban.dll
set CONF_ROOT=%scriptDir%\Excel
set OUTPUT_CODE_DIR=%WORKSPACE%\src\Mono\Luban\Configs\AutoGen
set OUTPUT_DATA_DIR=%WORKSPACE%\assets\configs\tables
set OUTPUT_JSON_DIR=%scriptDir%\Configs\Json
set CONFIG_FOLDER=%1

echo CONF_ROOT

echo ======================= Client ==========================
dotnet %LUBAN_DLL% ^
    --customTemplateDir %scriptDir%/Luban\CustomTemplate ^
    -t client ^
    -c cs-bin ^
    -d json ^
    -d bin ^
    --conf %CONF_ROOT%\luban.conf ^
    -x outputCodeDir=%OUTPUT_CODE_DIR% ^
    -x json.outputDataDir=%OUTPUT_JSON_DIR% ^
    -x bin.outputDataDir=%OUTPUT_DATA_DIR% ^
    --excludeTag dev ^

if %ERRORLEVEL% NEQ 0 exit