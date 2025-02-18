@echo off
setlocal enabledelayedexpansion

:: ┌─────────────────────────────────────────────────────┐
:: │   1) SETUP LOG FILE & SWITCH TO SCRIPT DIRECTORY   │
:: └─────────────────────────────────────────────────────┘
pushd "%~dp0"
set "LOGFILE=build_scan_log.txt"

echo. > "%LOGFILE%"
echo ====================================== >> "%LOGFILE%"
echo  BUILD SCAN LOG - %date% %time%       >> "%LOGFILE%"
echo ====================================== >> "%LOGFILE%"
echo. >> "%LOGFILE%"

:: ┌─────────────────────────────────────────────────────┐
:: │   2) DEFINE REQUIRED FILES                         │
:: └─────────────────────────────────────────────────────┘
set "REQUIRED_FILES=SystemSentinel.ps1 SystemSentinelModule.psm1 SystemSentinelConfig.json SystemSentinel.ico"

set "MISSING=0"

:: ┌─────────────────────────────────────────────────────┐
:: │   3) SCAN FOR REQUIRED FILES                       │
:: └─────────────────────────────────────────────────────┘
echo [*] Checking for required files in %cd% ...
echo [*] Results will be saved to "%LOGFILE%".
echo. >> "%LOGFILE%"

for %%F in (%REQUIRED_FILES%) do (
    echo Checking %%F... >> "%LOGFILE%"
    dir /s /b "%%F" >nul 2>&1
    if !errorlevel! == 0 (
        echo [FOUND] %%F >> "%LOGFILE%"
        echo Found in: >> "%LOGFILE%"
        dir /s /b "%%F" >> "%LOGFILE%"
    ) else (
        echo [MISSING] %%F >> "%LOGFILE%"
        set "MISSING=1"
    )
    dir /b >> "%LOGFILE%"
    echo. >> "%LOGFILE%"
)

echo Scan complete. >> "%LOGFILE%"
echo. >> "%LOGFILE%"

if !MISSING! == 1 (
    echo [!] Some required files are missing. See "%LOGFILE%" for details.
    pause
    exit /b 1
)

echo [*] All required files found. See "%LOGFILE%" for details.

:: ┌─────────────────────────────────────────────────────┐
:: │   4) RUN PYINSTALLER BUILD                         │
:: └─────────────────────────────────────────────────────┘
echo [*] Running PyInstaller build...
pyinstaller --noconfirm --clean --onefile ^
  --icon "SystemSentinel.ico" ^
  --add-data "SystemSentinel.ps1;." ^
  --add-data "SystemSentinelModule.psm1;." ^
  --add-data "SystemSentinelConfig.json;." ^
  --add-data "SystemSentinel.ico;." ^
  --distpath "C:\Users\Bakar\Documents\Powershell Scripts\System Sentinal" ^
  --hidden-import=os ^
  --hidden-import=sys ^
  SystemSentinelGUI.py

if errorlevel 1 (
    echo [!] PyInstaller build failed. Check "%LOGFILE%" for details.
    pause
    exit /b 1
)

echo [*] Build succeeded! Final EXE in "C:\Users\Bakar\Documents\Powershell Scripts\System Sentinal".
echo [*] For details, see "%LOGFILE%".
pause
cmd /k

echo [*] Verifying build contents...
dir /s /b "dist\*.ps1" >> "%LOGFILE%"
dir /s /b "dist\*.psm1" >> "%LOGFILE%"
