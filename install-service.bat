@echo off
chcp 65001 >nul 2>&1

REM ========================================
REM  Digital Signage — Регистрация сервиса
REM  Запускать от имени администратора!
REM ========================================

title Digital Signage — Регистрация сервиса
echo.
echo   =============================================
echo     Digital Signage — Регистрация сервиса
echo   =============================================
echo.

REM Проверка прав администратора
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo   ОШИБКА: Запустите от имени администратора!
    echo   (Правый клик -^> "Запуск от имени администратора")
    echo.
    pause
    exit /b 1
)

echo   [OK] Права администратора подтверждены
echo.

set "APP_DIR=%~dp0"
REM Убираем последний слэш
if "%APP_DIR:~-1%"=="\" set "APP_DIR=%APP_DIR:~0,-1%"

set "NODE_EXE="
where node >nul 2>&1
if %errorlevel%==0 (
    for /f "delims=" %%i in ('where node') do set "NODE_EXE=%%i"
)
if not defined NODE_EXE (
    if exist "C:\Program Files\nodejs\node.exe" (
        set "NODE_EXE=C:\Program Files\nodejs\node.exe"
    )
)

if not defined NODE_EXE (
    echo   ОШИБКА: Node.js не найден!
    echo   Установите Node.js 18+ с https://nodejs.org/
    echo.
    pause
    exit /b 1
)

echo   Node.js: %NODE_EXE%
echo   Каталог: %APP_DIR%
echo.

REM Проверка .env
if not exist "%APP_DIR%\.env" (
    echo   ОШИБКА: Файл .env не найден!
    echo   Сначала запустите Install.cmd
    echo.
    pause
    exit /b 1
)

echo   [OK] .env найден
echo.

REM Проверяем наличие NSSM
set "NSSM_EXE=%APP_DIR%\nssm.exe"
if not exist "%NSSM_EXE%" (
    set "NSSM_EXE=%APP_DIR%\service\nssm.exe"
)
if not exist "%NSSM_EXE%" (
    echo   NSSM не найден. Скачивание...
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
        "$nssmUrl = 'https://nssm.cc/release/nssm-2.24.zip'; ^" ^
        "$nssmZip = Join-Path $env:TEMP 'nssm.zip'; ^" ^
        "$extractPath = Join-Path $env:TEMP 'nssm-extract'; ^" ^
        "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ^" ^
        "Invoke-WebRequest -Uri $nssmUrl -OutFile $nssmZip -UseBasicParsing; ^" ^
        "Expand-Archive -Path $nssmZip -DestinationPath $extractPath -Force; ^" ^
        "$exe = Get-ChildItem -Path $extractPath -Recurse -Filter 'nssm.exe' | Where-Object { $_.FullName -match 'win64' } | Select-Object -First 1; ^" ^
        "if ($exe) { Copy-Item $exe.FullName '%APP_DIR%\nssm.exe' -Force; Write-Host 'NSSM установлен' } ^" ^
        "else { Write-Host 'ОШИБКА: nssm.exe не найден' -ForegroundColor Red; exit 1 }; ^" ^
        "Remove-Item $nssmZip -Force -ErrorAction SilentlyContinue; ^" ^
        "Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue"

    if errorlevel 1 (
        echo.
        echo   ОШИБКА: Не удалось скачать NSSM
        echo   Скачайте вручную с https://nssm.cc/ и поместите nssm.exe в %APP_DIR%
        echo.
        pause
        exit /b 1
    )
    set "NSSM_EXE=%APP_DIR%\nssm.exe"
)

echo   [OK] NSSM: %NSSM_EXE%
echo.

REM Останавливаем старый сервис
echo   Остановка существующего сервиса...
"%NSSM_EXE%" stop DigitalSignage 30000 >nul 2>&1
"%NSSM_EXE%" remove DigitalSignage confirm >nul 2>&1

REM Регистрируем новый
echo   Регистрация сервиса...
"%NSSM_EXE%" install DigitalSignage "%NODE_EXE%" "%APP_DIR%\src\server.js"
"%NSSM_EXE%" set DigitalSignage DisplayName "Digital Signage Server"
"%NSSM_EXE%" set DigitalSignage Start SERVICE_AUTO_START
"%NSSM_EXE%" set DigitalSignage AppDirectory "%APP_DIR%"
"%NSSM_EXE%" set DigitalSignage AppStdout "%APP_DIR%\logs\service-stdout.log"
"%NSSM_EXE%" set DigitalSignage AppStderr "%APP_DIR%\logs\service-stderr.log"

REM Зависимость от PostgreSQL
for %%S in (postgresql-x64-14 postgresql-x64-15 postgresql-x64-16 postgresql) do (
    sc query %%S >nul 2>&1
    if !errorlevel!==0 (
        "%NSSM_EXE%" set DigitalSignage DependOnService %%S
        echo   [OK] Зависимость от PostgreSQL: %%S
        goto :found_pg
    )
)
echo   [!] Служба PostgreSQL не найдена в стандартных именах

:found_pg
REM Переменные окружения из .env
echo   Чтение переменных из .env...
for /f "usebackq tokens=1,* delims==" %%a in ("%APP_DIR%\.env") do (
    set "line=%%a"
    if not "!line:~0,1!"=="#" (
        if not "!line!"=="" (
            "%NSSM_EXE%" set DigitalSignage AppEnvironmentExtra "%%a=%%b"
        )
    )
)
setlocal enabledelayedexpansion

REM Запускаем сервис
echo.
echo   Запуск сервиса...
"%NSSM_EXE%" start DigitalSignage

if errorlevel 1 (
    echo.
    echo   ОШИБКА: Не удалось запустить сервис
    echo   Проверьте логи в %APP_DIR%\logs\
    echo.
    pause
    exit /b 1
)

echo.
echo   =============================================
echo   Сервис Digital Signage зарегистрирован!
echo   =============================================
echo.
echo   Статус:    sc query DigitalSignage
echo   Остановить: net stop DigitalSignage
echo   Удалить:    "%NSSM_EXE%" remove DigitalSignage confirm
echo.
pause
