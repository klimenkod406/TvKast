@echo off
chcp 65001 >nul
cd /d "%~dp0"
title Digital Signage — установка
echo.
echo   Digital Signage — мастер установки
echo   Лог: %%TEMP%%\DigitalSignage-Setup.log
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
if errorlevel 1 exit /b 1
