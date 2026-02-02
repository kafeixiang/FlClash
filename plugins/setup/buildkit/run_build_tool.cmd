@echo off
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "PROJECT_DIR=%SCRIPT_DIR%"

:find_root
if exist "%PROJECT_DIR%\pubspec.yaml" if exist "%PROJECT_DIR%core\" goto :found
set "PROJECT_DIR=%PROJECT_DIR%..\"
if "%PROJECT_DIR%"=="..\" (
  echo Error: Could not find project root (no pubspec.yaml found)
  exit /b 1
)
goto :find_root

:found
set "DEV_MODE=0"
for %%a in (%*) do if "%%a"=="--dev" set "DEV_MODE=1"
if "%DEV_MODE%"=="1" (
    taskkill /F /IM FlClashHelperService.exe >nul 2>&1
)

set "BUILD_TOOL_DIR=%SCRIPT_DIR%build_tool"

if not defined DART_SDK (
  where dart >nul 2>&1 && set "DART=dart" || set "DART=dart"
) else (
  set "DART=%DART_SDK%\bin\dart"
)

cd /d "%BUILD_TOOL_DIR%"

"%DART%" run build_tool %* --root-dir "%PROJECT_DIR%"
