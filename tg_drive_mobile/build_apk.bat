@echo off
cd /d "%~dp0"

:: Find Flutter SDK — check common locations
set FLUTTER_CMD=flutter
where flutter >nul 2>nul
if %errorlevel% neq 0 (
    if exist "E:\flutter\flutter\bin\flutter.bat" set FLUTTER_CMD=E:\flutter\flutter\bin\flutter.bat
    if exist "C:\flutter\bin\flutter.bat" set FLUTTER_CMD=C:\flutter\bin\flutter.bat
    if exist "C:\src\flutter\bin\flutter.bat" set FLUTTER_CMD=C:\src\flutter\bin\flutter.bat
    if exist "C:\tools\flutter\bin\flutter.bat" set FLUTTER_CMD=C:\tools\flutter\bin\flutter.bat
)

set FLUTTER_PREBUILT_ENGINE_VERSION=18b71d647a292a980abb405ac7d16fe1f0b20434

echo Building TeleDrive APK...
%FLUTTER_CMD% build apk --debug

if %errorlevel% neq 0 (
    echo Build failed!
    pause
    exit /b %errorlevel%
)

set OUTPUT_DIR=build\app\outputs\flutter-apk
set NEW_APK=%OUTPUT_DIR%\app-debug.apk
set DEST=%OUTPUT_DIR%\tele_drive.apk

del /f /q "%OUTPUT_DIR%\install teledrive.apk" 2>nul
copy /y "%NEW_APK%" "%DEST%" >nul

echo.
echo APK ready: %DEST%
echo.
pause
