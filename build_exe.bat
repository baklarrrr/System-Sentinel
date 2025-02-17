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
:: Adjust or add more files as needed:
set "REQUIRED_FILES=SystemSentinel.ps1 SystemSentinelModule.psm1 SystemSentinelConfig.json SystemSentinel.ico"

:: Flag to indicate if any file is missing
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
:: │   4) OPTIONAL: RUN PYINSTALLER BUILD               │
:: └─────────────────────────────────────────────────────┘
:: NOTE: It's recommended to NOT run PyInstaller as admin
:: to avoid future version blocks. If you truly need admin 
:: to handle folder permissions, do so BEFORE calling pyinstaller.

echo [*] Running PyInstaller build...
:: Append build output to the same log
pyinstaller --noconfirm --clean --onefile ^
  --add-data "SystemSentinel.ps1;." ^
  --add-data "SystemSentinelModule.psm1;." ^
  --add-data "SystemSentinelConfig.json;." ^
  --add-data "SystemSentinel.ico;." ^
  --distpath dist ^
  --hidden-import=os ^
  --hidden-import=sys ^
  SystemSentinelGUI.py >> "%LOGFILE%" 2>&1
if errorlevel 1 (
    echo [!] PyInstaller build failed. Check "%LOGFILE%" for details.
    pause
    exit /b 1
)

echo [*] Build succeeded! Final EXE in "%cd%\dist".
echo [*] For details, see "%LOGFILE%".
pause
cmd /k

echo [*] Verifying build contents...
dir /s /b "dist\*.ps1" >> "%LOGFILE%"
dir /s /b "dist\*.psm1" >> "%LOGFILE%"
