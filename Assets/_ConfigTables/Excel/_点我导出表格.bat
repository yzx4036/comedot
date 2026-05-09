set LUBAN_DLL=..\Luban\Luban.dll

dotnet %LUBAN_DLL% ^
    -t all ^
    -c cs-bin ^
    -d bin ^
    --conf .\luban.conf ^
    -x outputCodeDir=..\..\godot-luban-project\src\Configs\Tables ^
    -x outputDataDir=..\..\godot-luban-project\assets\configs\tables

pause