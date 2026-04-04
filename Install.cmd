@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
cd /d "%~dp0"
title Digital Signage - Master Ustanovki
echo.
echo   Digital Signage - master ustanovki
echo   Log: %%TEMP%%\DigitalSignage-Setup.log
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 (
    echo.
    echo OSHIBKA: Ustanovka zavershilas s oshibkoy.
    echo Log: %%TEMP%%\DigitalSignage-Setup.log
    echo.
    pause
    exit /b 1
)
echo.
echo Ustanovka zavershena uspešno.
pause
