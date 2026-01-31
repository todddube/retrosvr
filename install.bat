@echo off
echo ==========================================
echo  Retro 8-Bit Screensaver Installer
echo ==========================================
echo.

REM Build the project
echo Building screensaver...
cd /d "%~dp0RetroScreensaver"
dotnet publish -c Release -r win-x64 --self-contained false -o "%~dp0publish"

if errorlevel 1 (
    echo Build failed!
    pause
    exit /b 1
)

echo.
echo Copying screensaver to Windows directory...

REM Copy as .scr file
copy /Y "%~dp0publish\Retro8Bit.exe" "%WINDIR%\System32\Retro8Bit.scr"

if errorlevel 1 (
    echo.
    echo Failed to copy to System32. Try running as Administrator.
    echo.
    echo Alternatively, you can manually copy:
    echo   From: %~dp0publish\Retro8Bit.exe
    echo   To:   %WINDIR%\System32\Retro8Bit.scr
    pause
    exit /b 1
)

echo.
echo ==========================================
echo  Installation Complete!
echo ==========================================
echo.
echo The screensaver "Retro8Bit" is now available.
echo.
echo To activate:
echo   1. Right-click desktop, select "Personalize"
echo   2. Click "Lock screen" then "Screen saver settings"
echo   3. Select "Retro8Bit" from the dropdown
echo.
echo Press any key to open Screen Saver Settings...
pause >nul

REM Open screen saver settings
control desk.cpl,,@screensaver

exit /b 0
