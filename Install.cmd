@echo off
chcp 65001 >nul 2>&1
cd /d "%~dp0"
title Digital Signage - Установка
echo.
echo   Digital Signage - мастер установки
echo   Лог: %%TEMP%%\DigitalSignage-Setup.log
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Console]::InputEncoding=[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; & '%~dp0install.ps1'"
if errorlevel 1 (
    echo.
    echo ОШИБКА: Установка завершилась с ошибой.
    echo Лог: %%TEMP%%\DigitalSignage-Setup.log
    echo.
    pause
    exit /b 1
)
