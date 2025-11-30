@echo off
echo ===================================
echo   Starting Rubick Plugin Release
echo ===================================

echo [0/3] Downloading offline data...
call update-data.bat

echo.
echo [1/3] Installing dependencies...
call npm install

REM Check if npm install was successful
if %errorlevel% neq 0 (
    echo.
    echo ERROR: npm install failed. Aborting.
    exit /b %errorlevel%
)

echo.
echo [2/3] Building the plugin...
call npm run build

REM Check if build was successful
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Build process failed. Aborting.
    exit /b %errorlevel%
)

echo.
echo [3/3] Packaging the release...
set "RELEASE_FILE=linux-command-release.zip"

REM Check if the old release file exists and delete it
if exist "%RELEASE_FILE%" (
    echo Deleting old release file: %RELEASE_FILE%
    del "%RELEASE_FILE%"
)

REM Create the new zip archive using PowerShell
powershell -NoProfile -Command "Compress-Archive -Path dist/* -DestinationPath %RELEASE_FILE%"

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Failed to create release archive. Make sure PowerShell is available.
    exit /b %errorlevel%
)

echo.
echo ===================================
echo      Release Complete!
echo ===================================
echo.
echo Your packaged plugin is ready: %RELEASE_FILE%
echo You can now drag this file into Rubick to install.
echo.
