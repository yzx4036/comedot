cd /D %~dp0
set "scriptDir=%~dp0"

set WORKSPACE=%scriptDir%/..\
set GAME_WORKSPACE=%WORKSPACE%/Game\
set GAME_CONFIG_WORKSPACE=%GAME_WORKSPACE%/_ConfigTables\
set GAME_NAME=Cd_ProjectZero
set GAME_ROOT=%GAME_WORKSPACE%/%GAME_NAME%\

set LUBAN_DLL=%scriptDir%/Luban\Release\Luban.dll
set CONF_ROOT=%GAME_CONFIG_WORKSPACE%\Excel
set OUTPUT_CODE_DIR=%GAME_ROOT%\Scripts\Mono\Luban\Configs\AutoGen
set OUTPUT_DATA_DIR=%GAME_ROOT%\Assets\Configs\GameConfigs
set OUTPUT_JSON_DIR=%GAME_CONFIG_WORKSPACE%\Configs\Json
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