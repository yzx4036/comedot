@echo off
cd /D %~dp0
set "scriptDir=%~dp0"
set "WORKSPACE=%scriptDir%.."
set "CONF_ROOT=%scriptDir%Excel"
set "LUBAN_DLL=%scriptDir%Luban\Release\Luban.dll"
set "OUTPUT_CODE_DIR=%WORKSPACE%\Scripts\Mono\Luban\Configs\AutoGen"
set "OUTPUT_DATA_DIR=%WORKSPACE%\Assets\Configs\GameConfigs"
set "OUTPUT_JSON_DIR=%scriptDir%Configs\Json"

echo ======================= Framework Config (C#) ==========================
dotnet "%LUBAN_DLL%" ^
    --customTemplateDir "%scriptDir%Luban\CustomTemplate" ^
    -t client ^
    -c cs-bin ^
    -d json ^
    -d bin ^
    --conf "%CONF_ROOT%\luban.conf" ^
    -x outputCodeDir=%OUTPUT_CODE_DIR% ^
    -x json.outputDataDir=%OUTPUT_JSON_DIR% ^
    -x bin.outputDataDir=%OUTPUT_DATA_DIR% ^
    --excludeTag dev

if %ERRORLEVEL% NEQ 0 (
    echo Luban generation FAILED.
    exit /b 1
)
echo.
echo Framework config generation done.