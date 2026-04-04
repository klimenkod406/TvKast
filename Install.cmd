@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul 2>&1
cd /d "%~dp0"
title Digital Signage - Master Ustanovki
echo.
echo   Digital Signage - master ustanovki
echo   Log: %%TEMP%%\DigitalSignage-Setup.log
echo.

rem Get short 8.3 path to avoid Cyrillic issues
for %%I in ("%~dp0.") do set "SHORT_PATH=%%~fsI"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 exit /b 1
