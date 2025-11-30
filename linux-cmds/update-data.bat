@echo off
echo ===================================
echo   Updating Plugin Offline Data    
echo ===================================

set "DATA_URL=https://unpkg.com/linux-command@latest/dist/data.json"
set "OUTPUT_FILE=public/data.json"

echo.
echo [1/2] Downloading latest data from:
echo %DATA_URL%
echo.

powershell -NoProfile -Command "Invoke-WebRequest -Uri %DATA_URL% -OutFile %OUTPUT_FILE%"

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Failed to download the data file.
    echo Please check your internet connection and the URL.
    exit /b %errorlevel%
)

echo.
echo [2/2] Successfully updated local data file:
echo %OUTPUT_FILE%
echo.
echo ===================================
echo      Update Complete!
echo ===================================
echo.
echo Next step: Run 'release.bat' to package the new version of your plugin.
echo.
