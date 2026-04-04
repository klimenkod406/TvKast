@echo off
cd /d "%~dp0"
title Digital Signage Installer

echo.
echo   Digital Signage - Setup Wizard
echo   Log: %%TEMP%%\DigitalSignage-Setup.log
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; & '%~dp0install.ps1'"
if errorlevel 1 (
    echo.
    echo ERROR: Installation failed.
    echo Log: %%TEMP%%\DigitalSignage-Setup.log
    echo.
    pause
    exit /b 1
)
