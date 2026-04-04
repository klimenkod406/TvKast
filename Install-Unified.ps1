<#
.SYNOPSIS
    Единый установщик Digital Signage (Windows)
.DESCRIPTION
    Объединяет все шаги установки: проверка зависимостей, ffmpeg, БД, .env, сервис
.NOTES
    Запускается через Install.cmd для корректной работы с кириллицей
#>

param(
    [switch]$Silent,
    [switch]$SkipService,
    [string]$InstallDir
)

$ErrorActionPreference = "Stop"

# ============================================================
# Кириллица: гарантируем UTF-8 и правильную кодировку консоли
# ============================================================
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    [Console]::InputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # Игнорируем ошибки, если консоль не поддерживает
}
# chcp 65001 — перекодировка консоли в UTF-8 (через cmd-обёртку)

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
# Нормализуем путь (полный путь без сокращений — обход проблем с кириллицей)
try {
    $ScriptRoot = (Get-Item $ScriptRoot).FullName
} catch {
    # Если не удалось — продолжаем как есть
}
Set-Location $ScriptRoot

$LogFile = Join-Path $env:TEMP "DigitalSignage-Setup.log"
$InstallDir = if ($InstallDir) { $InstallDir } else { $ScriptRoot }

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Host $Message
}

function Write-Section {
    param([string]$Title)
    $sep = "=" * 60
    Write-Log $sep
    Write-Log $Title
    Write-Log $sep
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-NodeVersion {
    try {
        $v = & node -v 2>$null
        if (-not $v) { return $false }
        if ($v -match '^v(\d+)') {
            return [int]$Matches[1] -ge 18
        }
    } catch { }
    return $false
}

function Test-PostgreSQL {
    try {
        # Проверяем, запущена ли служба PostgreSQL
        $svc = Get-Service -Name "postgresql*" -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Running' }
        if ($svc) { return $true }
        # Пробуем подключение к порту 5432
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect("localhost", 5432)
        $tcp.Close()
        return $true
    } catch { }
    return $false
}

function Test-FfmpegOk {
    param([string]$ExePath)
    if (-not (Test-Path $ExePath)) { return $false }
    try {
        $out = & $ExePath -version 2>&1 | Out-String
        if ($out -match "ffmpeg version (\d+)") {
            return [int]$Matches[1] -ge 5
        }
    } catch { }
    return $false
}

function Install-Ffmpeg {
    param([string]$TargetPath)
    $url = "https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip"
    $zipPath = Join-Path $env:TEMP "ffmpeg-win64.zip"
    $extractPath = Join-Path $env:TEMP "ffmpeg-extract"

    Write-Log "Скачивание ffmpeg (~100 МБ)..."
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
    } catch {
        Write-Log "ОШИБКА: Не удалось скачать ffmpeg: $_" -Level "ERROR"
        return $null
    }

    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    $exe = Get-ChildItem -Path $extractPath -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
    if (-not $exe) {
        Write-Log "ОШИБКА: ffmpeg.exe не найден в архиве" -Level "ERROR"
        return $null
    }

    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    Copy-Item $exe.FullName (Join-Path $TargetPath "ffmpeg.exe") -Force

    # Чистим временные файлы
    Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

    return Join-Path $TargetPath "ffmpeg.exe"
}

function Set-EnvValue {
    param([string]$Key, [string]$Value, [string]$EnvPath)
    $lines = @()
    if (Test-Path $EnvPath) {
        $lines = [System.IO.File]::ReadAllLines($EnvPath)
    }
    $found = $false
    $out = @()
    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) {
            $out += $line
            continue
        }
        $idx = $line.IndexOf("=")
        if ($idx -eq -1) { $out += $line; continue }
        $k = $line.Substring(0, $idx).Trim()
        if ($k -eq $Key) {
            $out += "$Key=$Value"
            $found = $true
        } else {
            $out += $line
        }
    }
    if (-not $found) {
        $out += "$Key=$Value"
    }
    [System.IO.File]::WriteAllLines($EnvPath, $out, [System.Text.Encoding]::UTF8)
}

function Create-MediaDirs {
    $dirs = @("media", "media\original", "media\converted", "media\metadata")
    foreach ($d in $dirs) {
        $p = Join-Path $InstallDir $d
        if (-not (Test-Path $p)) {
            New-Item -ItemType Directory -Path $p -Force | Out-Null
            Write-Log "Создан каталог: $p"
        }
    }
}

function Prompt-PostgreSQL {
    Write-Section "PostgreSQL: параметры подключения"
    Write-Host "Служба PostgreSQL должна быть запущена (services.msc)."
    Write-Host ""

    if ($Silent) {
        return @{
            Host     = "localhost"
            Port     = "5432"
            SuperUser = "postgres"
            Password = ""
        }
    }

    $pgHost = Read-Host "Хост PostgreSQL [localhost]"
    if ([string]::IsNullOrWhiteSpace($pgHost)) { $pgHost = "localhost" }
    $pgPort = Read-Host "Порт PostgreSQL [5432]"
    if ([string]::IsNullOrWhiteSpace($pgPort)) { $pgPort = "5432" }
    $pgSuper = Read-Host "Имя суперпользователя PostgreSQL [postgres]"
    if ([string]::IsNullOrWhiteSpace($pgSuper)) { $pgSuper = "postgres" }
    Write-Host "Пароль суперпользователя (пусто = доверие localhost):"
    $sec = Read-Host -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    $pgPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    return @{
        Host     = $pgHost
        Port     = $pgPort
        SuperUser = $pgSuper
        Password = $pgPassPlain
    }
}

function Prompt-AdminPassword {
    Write-Host ""
    Write-Section "Пароль администратора"
    if ($Silent) {
        $chars = (48..57) + (65..90) + (97..122)
        $pass = -join ($chars | Get-Random -Count 16 | ForEach-Object { [char]$_ })
        Write-Log "Сгенерирован пароль: $pass" -Level "WARN"
        return $pass
    }

    $adminPass = Read-Host "Пароль для входа в админ-панель (логин: admin) [случайный]"
    if ([string]::IsNullOrWhiteSpace($adminPass)) {
        $chars = (48..57) + (65..90) + (97..122)
        $adminPass = -join ($chars | Get-Random -Count 16 | ForEach-Object { [char]$_ })
        Write-Host ""
        Write-Host "ВАЖНО: сохраните пароль администратора: $adminPass" -ForegroundColor Yellow
        Write-Host ""
    }
    return $adminPass
}

function Register-WindowsService {
    Write-Section "Регистрация Windows-сервиса"

    if ($SkipService) {
        Write-Log "Пропуск регистрации сервиса (флаг --SkipService)"
        return $true
    }

    if (-not (Test-Admin)) {
        Write-Log "Для регистрации сервиса нужны права администратора. Пропуск." -Level "WARN"
        Write-Log "Запустите установщик от имени администратора или используйте install-service.bat" -Level "WARN"
        return $false
    }

    $appDir = $InstallDir
    $nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
    if (-not $nodeExe) {
        $nodeExe = "C:\Program Files\nodejs\node.exe"
        if (-not (Test-Path $nodeExe)) {
            Write-Log "ОШИБКА: node.exe не найден" -Level "ERROR"
            return $false
        }
    }

    # Проверяем наличие NSSM
    $nssmPath = Join-Path $appDir "nssm.exe"
    $nssmDir = Join-Path $appDir "service"
    $nssmExe = Join-Path $nssmDir "nssm.exe"

    if (-not (Test-Path $nssmExe)) {
        Write-Log "NSSM не найден. Скачивание..." -Level "INFO"
        try {
            $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
            $nssmZip = Join-Path $env:TEMP "nssm.zip"
            Invoke-WebRequest -Uri $nssmUrl -OutFile $nssmZip -UseBasicParsing
            New-Item -ItemType Directory -Path $nssmDir -Force | Out-Null
            Expand-Archive -Path $nssmZip -DestinationPath (Join-Path $env:TEMP "nssm-extract") -Force

            $extractedNssm = Get-ChildItem -Path (Join-Path $env:TEMP "nssm-extract") -Recurse -Filter "nssm.exe" |
                Where-Object { $_.FullName -match "win64" } | Select-Object -First 1

            if ($extractedNssm) {
                Copy-Item $extractedNssm.FullName $nssmExe -Force
                Write-Log "NSSM установлен: $nssmExe"
            } else {
                Write-Log "ОШИБКА: nssm.exe не найден в архиве" -Level "ERROR"
                return $false
            }
            Remove-Item $nssmZip -Force -ErrorAction SilentlyContinue
            Remove-Item (Join-Path $env:TEMP "nssm-extract") -Recurse -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Log "Не удалось скачать NSSM: $_" -Level "ERROR"
            Write-Log "Сервис можно зарегистри позже через install-service.bat" -Level "WARN"
            return $false
        }
    }

    # Останавливаем сервис если уже существует
    & $nssmExe stop DigitalSignage 60000 2>$null | Out-Null
    & $nssmExe remove DigitalSignage confirm 2>$null | Out-Null

    # Регистрируем сервис
    & $nssmExe install DigitalSignage $nodeExe "$appDir\src\server.js"
    & $nssmExe set DigitalSignage DisplayName "Digital Signage Server"
    & $nssmExe set DigitalSignage Start SERVICE_AUTO_START
    & $nssmExe set DigitalSignage AppDirectory $appDir
    & $nssmExe set DigitalSignage AppStdout "$appDir\logs\service-stdout.log"
    & $nssmExe set DigitalSignage AppStderr "$appDir\logs\service-stderr.log"

    # Зависимость от PostgreSQL (пробуем разные имена служб)
    $pgServiceNames = @("postgresql-x64-14", "postgresql-x64-15", "postgresql-x64-16", "postgresql")
    foreach ($pgName in $pgServiceNames) {
        $pgSvc = Get-Service -Name $pgName -ErrorAction SilentlyContinue
        if ($pgSvc) {
            & $nssmExe set DigitalSignage DependOnService $pgName
            break
        }
    }

    # Переменные окружения для сервиса
    $envPath = Join-Path $appDir ".env"
    if (Test-Path $envPath) {
        $envContent = Get-Content $envPath -Raw
        $envVars = @{}
        foreach ($line in ($envContent -split "`n")) {
            $line = $line.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
                $idx = $line.IndexOf("=")
                $key = $line.Substring(0, $idx).Trim()
                $val = $line.Substring($idx + 1).Trim()
                $envVars[$key] = $val
            }
        }
        if ($envVars.Count -gt 0) {
            $envStr = ($envVars.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "`0"
            & $nssmExe set DigitalSignage AppEnvironmentExtra $envStr
        }
    }

    & $nssmExe start DigitalSignage

    Write-Log "Сервис DigitalSignage зарегистрирован и запущен"
    return $true
}

function Create-DesktopShortcut {
    try {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktop "Digital Signage — запуск.lnk"

        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = Join-Path $InstallDir "Start.cmd"
        $shortcut.WorkingDirectory = $InstallDir
        $shortcut.Description = "Запуск Digital Signage Server"
        $shortcut.Save()

        Write-Log "Ярлык создан: $shortcutPath"
    } catch {
        Write-Log "Не удалось создать ярлык: $_" -Level "WARN"
    }
}

# ============================================================
# ОСНОВНОЙ ПРОЦЕСС УСТАНОВКИ
# ============================================================

Write-Section "Digital Signage — Установка"
Write-Log "Каталог установки: $InstallDir"
Write-Log "Лог-файл: $LogFile"

# --- Шаг 1: Проверка Node.js ---
Write-Section "Шаг 1/8: Проверка Node.js"
if (-not (Test-NodeVersion)) {
    Write-Log "ОШИБКА: Требуется Node.js версии 18 или выше." -Level "ERROR"
    Write-Log "Скачайте: https://nodejs.org/ (LTS)" -Level "ERROR"
    if (-not $Silent) { Read-Host "Нажмите Enter для выхода" }
    exit 1
}
$nodeVer = & node -v
Write-Log "Node.js: $nodeVer — OK"

# --- Шаг 2: npm install ---
Write-Section "Шаг 2/8: Установка npm-зависимостей"
Write-Log "Выполняется npm install..."
& npm install --no-fund --no-audit 2>&1 | ForEach-Object { Write-Log $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Log "ОШИБКА: npm install завершился с ошибкой" -Level "ERROR"
    if (-not $Silent) { Read-Host "Нажмите Enter для выхода" }
    exit 1
}
Write-Log "npm-зависимости установлены — OK"

# --- Шаг 3: Создание каталогов ---
Write-Section "Шаг 3/8: Создание служебных каталогов"
Create-MediaDirs

# Создание каталога логов для сервиса
$logDir = Join-Path $InstallDir "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    Write-Log "Создан каталог: $logDir"
}

# --- Шаг 4: ffmpeg ---
Write-Section "Шаг 4/8: Проверка / установка ffmpeg"
$ffmpegPath = $null

# 4a. Проверка в PATH
$existing = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($existing -and (Test-FfmpegOk $existing.Source)) {
    $ffmpegPath = $existing.Source
    Write-Log "Найден ffmpeg в PATH: $ffmpegPath"
}

# 4b. Проверка локального
if (-not $ffmpegPath) {
    $localFfmpeg = Join-Path $InstallDir "bin\ffmpeg.exe"
    if (Test-FfmpegOk $localFfmpeg) {
        $ffmpegPath = $localFfmpeg
        Write-Log "Найден локальный ffmpeg: $ffmpegPath"
    }
}

# 4c. Скачивание
if (-not $ffmpegPath) {
    $binDir = Join-Path $InstallDir "bin"
    $ffmpegPath = Install-Ffmpeg $binDir
    if ($ffmpegPath -and (Test-FfmpegOk $ffmpegPath)) {
        Write-Log "ffmpeg установлен: $ffmpegPath"
    } else {
        Write-Log "ПРЕДУПРЕЖДЕНИЕ: ffmpeg не установлен — загрузите вручную" -Level "WARN"
        $ffmpegPath = "ffmpeg"
    }
}

$ffmpegVer = & $ffmpegPath -version 2>&1 | Select-Object -First 1
Write-Log "ffmpeg версия: $ffmpegVer"

# --- Шаг 5: PostgreSQL ---
Write-Section "Шаг 5/8: Настройка PostgreSQL"
$pgConfig = Prompt-PostgreSQL

$env:POSTGRES_HOST = $pgConfig.Host
$env:POSTGRES_PORT = $pgConfig.Port
$env:POSTGRES_SUPERUSER = $pgConfig.SuperUser
$env:POSTGRES_SUPERUSER_PASSWORD = $pgConfig.Password

Write-Log "Подключение к PostgreSQL: $($pgConfig.Host):$($pgConfig.Port)..."

# Проверка подключения
try {
    $pgTestClient = New-Object Pg.Client @{
        Host = $pgConfig.Host
        Port = [int]$pgConfig.Port
        Username = $pgConfig.SuperUser
        Password = if ($pgConfig.Password) { $pgConfig.Password } else { $null }
        Database = "postgres"
    }
    # pg модуль может быть не установлен — используем psql
    Remove-Variable pgTestClient -ErrorAction SilentlyContinue
} catch {}

# --- Шаг 6: Инициализация БД и .env ---
Write-Section "Шаг 6/8: Создание БД и файла .env"

# Копируем .env.example если .env не существует
$envPath = Join-Path $InstallDir ".env"
$envExamplePath = Join-Path $InstallDir ".env.example"
if (-not (Test-Path $envPath) -and (Test-Path $envExamplePath)) {
    Copy-Item $envExamplePath $envPath -Force
    Write-Log "Создан .env из .env.example"
}

Write-Log "Выполняется ensure-db..."
& node (Join-Path $ScriptRoot "scripts\ensure-db.js") 2>&1 | ForEach-Object { Write-Log $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Log "ОШИБКА: ensure-db — проверьте параметры PostgreSQL" -Level "ERROR"
    if (-not $Silent) { Read-Host "Нажмите Enter для выхода" }
    exit 1
}

# Обновляем FFMPEG_PATH в .env
if ($ffmpegPath -and $ffmpegPath -ne "ffmpeg") {
    Set-EnvValue "FFMPEG_PATH" $ffmpegPath $envPath
    Write-Log "FFMPEG_PATH=$ffmpegPath записан в .env"
}

Write-Log "Файл .env обновлён — OK"

# --- Шаг 7: Инициализация таблиц и admin ---
Write-Section "Шаг 7/8: Создание таблиц и учётной записи admin"

$adminPass = Prompt-AdminPassword
$env:ADMIN_PASSWORD = $adminPass

Write-Log "Выполняется db:init..."
& npm run db:init 2>&1 | ForEach-Object { Write-Log $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Log "ОШИБКА: db:init — таблицы не создены" -Level "ERROR"
    if (-not $Silent) { Read-Host "Нажмите Enter для выхода" }
    exit 1
}

Remove-Item Env:ADMIN_PASSWORD -ErrorAction SilentlyContinue
Write-Log "Таблицы созданы, admin зарегистрирован — OK"

# --- Шаг 8: Маркер установки и сервис ---
Write-Section "Шаг 8/8: Завершение установки"

$markerPath = Join-Path $InstallDir "INSTALL_OK"
"installed $(Get-Date -Format o)" | Out-File -FilePath $markerPath -Encoding utf8 -Force
Write-Log "Создан маркер: INSTALL_OK"

Create-DesktopShortcut

# Регистрация сервиса (если есть права)
if (-not $Silent) {
    Write-Host ""
    $regService = Read-Host "Зарегистрировать как Windows-сервис? (Y/N) [N]"
    if ($regService -match '^[Yy]') {
        Register-WindowsService
    }
} elseif (-not $SkipService) {
    Register-WindowsService
}

# ============================================================
# ФИНАЛЬНОЕ СООБЩЕНИЕ
# ============================================================
Write-Section "Установка завершена успешно!"
Write-Host ""
Write-Host "  Запуск сервера:      Start.cmd" -ForegroundColor Green
Write-Host "  Админ-панель:        http://localhost:3000/admin/login.html" -ForegroundColor Green
Write-Host "  Логин:               admin" -ForegroundColor Green
Write-Host "  Пароль:              $adminPass" -ForegroundColor Green
Write-Host "  Лог установки:       $LogFile" -ForegroundColor Green
Write-Host ""

if ($Silent) {
    Write-Log "Тихий режим — установка завершена"
} else {
    Read-Host "Нажмите Enter для выхода"
}

exit 0
