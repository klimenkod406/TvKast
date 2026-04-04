@echo off
chcp 65001 >nul 2>&1
cd /d "%~dp0"
title Digital Signage Installer

echo.
echo   =============================================
echo     Digital Signage — Мастер установки
echo   =============================================
echo   Лог: %%TEMP%%\DigitalSignage-Setup.log
echo.

REM Проверка прав администратора (опционально, для сервиса)
net session >nul 2>&1
if %errorlevel%==0 (
    echo   [OK] Запущен от имени администратора
) else (
    echo   [!] Без прав администратора (сервис не будет зарегистрирован)
)
echo.

REM Запуск единого PowerShell-установщика с поддержкой Unicode
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-Unified.ps1"

if errorlevel 1 (
    echo.
    echo   =============================================
    echo   ОШИБКА: Установка не завершена.
    echo   =============================================
    echo   Лог: %%TEMP%%\DigitalSignage-Setup.log
    echo.
    pause
    exit /b 1
)

echo.
echo   =============================================
echo   Установка завершена успешно!
echo   =============================================
echo.
echo   Ссылки:
echo     Админ-панель:  http://localhost:3000/admin/login.html
echo     Плеер (ТВ):    http://localhost:3000/display/^<screenId^>
echo.
echo   Запуск сервера:  Start.cmd
echo.
pause
