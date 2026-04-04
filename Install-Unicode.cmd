@echo off
chcp 65001 >nul 2>&1
title Digital Signage Installer (Unicode)
cd /d "%~dp0"

start "DS-Install" /wait powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install-Unified.ps1"

if errorlevel 1 (
    echo.
    echo =============================================
    echo ERROR: Installation failed.
    echo =============================================
    echo Log: %%TEMP%%\DigitalSignage-Setup.log
    echo.
    pause
    exit /b 1
)

echo.
echo =============================================
echo Installation completed!
echo =============================================
echo.
echo Start server: Start.cmd
echo Admin panel:  http://localhost:3000/admin/login.html
echo.
pause
