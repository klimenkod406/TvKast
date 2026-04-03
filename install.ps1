# Digital Signage — полная установка (Windows)
# Лог: $env:TEMP\DigitalSignage-Setup.log
# Запуск: двойной щелчок по Install.cmd

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$LogFile = Join-Path $env:TEMP "DigitalSignage-Setup.log"

function Write-Log {
    param([string]$Message)
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
    Write-Host $Message
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

Write-Log "========== Digital Signage: установка =========="
Write-Log "Каталог: $Root"

if (-not (Test-NodeVersion)) {
    Write-Log "ОШИБКА: Нужен Node.js 18 или новее."
    Write-Log "Скачайте: https://nodejs.org/ (LTS) и повторите установку."
    Write-Log "Либо (от администратора): winget install OpenJS.NodeJS.LTS"
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

$nodeVer = & node -v
Write-Log "Node.js: $nodeVer"

Write-Log "Установка npm-зависимостей..."
& npm install --no-fund --no-audit
if ($LASTEXITCODE -ne 0) {
    Write-Log "ОШИБКА: npm install завершился с ошибкой."
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

Write-Log "Создание каталогов media..."
$dirs = @("media", "media\original", "media\converted", "media\metadata")
foreach ($d in $dirs) {
    $p = Join-Path $Root $d
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
        Write-Log "Создан: $p"
    }
}

$binDir = Join-Path $env:LOCALAPPDATA "DigitalSignage\bin"
$ffmpegScript = Join-Path $Root "download-ffmpeg.ps1"
Write-Log "Проверка / установка ffmpeg (в профиль пользователя, без прав администратора)..."
try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ffmpegScript -InstallPath $binDir
} catch {
    Write-Log "Предупреждение: ffmpeg: $_"
}

$ff = Join-Path $binDir "ffmpeg.exe"
$cmd = Get-Command ffmpeg -ErrorAction SilentlyContinue
if (Test-Path $ff) {
    $env:FFMPEG_PATH = $ff
    Write-Log "FFMPEG_PATH=$ff"
} elseif ($cmd) {
    $env:FFMPEG_PATH = $cmd.Source
    Write-Log "FFMPEG_PATH=$($cmd.Source) (PATH)"
} else {
    $env:FFMPEG_PATH = "ffmpeg"
    Write-Log "Предупреждение: ffmpeg не найден — установите вручную или проверьте интернет."
}

Write-Host ""
Write-Host "PostgreSQL: параметры суперпользователя (для создания БД и пользователя приложения)."
Write-Host "Служба PostgreSQL должна быть запущена (services.msc)."
Write-Host ""
$pgHost = Read-Host "Хост [localhost]"
if ([string]::IsNullOrWhiteSpace($pgHost)) { $pgHost = "localhost" }
$pgPort = Read-Host "Порт [5432]"
if ([string]::IsNullOrWhiteSpace($pgPort)) { $pgPort = "5432" }
$pgSuper = Read-Host "Имя суперпользователя [postgres]"
if ([string]::IsNullOrWhiteSpace($pgSuper)) { $pgSuper = "postgres" }
Write-Host "Пароль суперпользователя (Enter = пустой, если у postgres доверие localhost):"
$sec = Read-Host -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$pgPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$env:POSTGRES_HOST = $pgHost
$env:POSTGRES_PORT = $pgPort
$env:POSTGRES_SUPERUSER = $pgSuper
$env:POSTGRES_SUPERUSER_PASSWORD = $pgPassPlain

Write-Log "Создание БД, пользователя приложения и файла .env..."
& node (Join-Path $Root "scripts\ensure-db.js")
if ($LASTEXITCODE -ne 0) {
    Write-Log "ОШИБКА: ensure-db. Проверьте пароль, что PostgreSQL запущен и порт $pgPort доступен."
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

if ((Test-Path $ff) -and $env:FFMPEG_PATH) {
    & node (Join-Path $Root "scripts\set-env-value.js") "FFMPEG_PATH" $env:FFMPEG_PATH
    Write-Log "Обновлён FFMPEG_PATH в .env"
}

Write-Host ""
$adminPass = Read-Host "Пароль входа в админ-панель (логин admin) [случайный]"
if ([string]::IsNullOrWhiteSpace($adminPass)) {
    $chars = (48..57) + (65..90) + (97..122)
    $adminPass = -join ($chars | Get-Random -Count 16 | ForEach-Object { [char]$_ })
    Write-Log "Сгенерирован пароль администратора (сохраните): $adminPass"
    Write-Host ""
    Write-Host "ВАЖНО: сохраните пароль администратора: $adminPass"
    Write-Host ""
} else {
    Write-Log "Пароль администратора задан вручную."
}

$env:ADMIN_PASSWORD = $adminPass

Write-Log "Создание таблиц и учётной записи admin..."
& npm run db:init
if ($LASTEXITCODE -ne 0) {
    Write-Log "ОШИБКА: db:init"
    Read-Host "Нажмите Enter для выхода"
    exit 1
}

Remove-Item Env:ADMIN_PASSWORD -ErrorAction SilentlyContinue

$marker = Join-Path $Root "INSTALL_OK"
"installed $(Get-Date -Format o)" | Out-File -FilePath $marker -Encoding utf8
Write-Log "Создан маркер: INSTALL_OK"

try {
    $desk = [Environment]::GetFolderPath("Desktop")
    $shortcut = Join-Path $desk "Digital Signage — запуск.cmd"
    Copy-Item (Join-Path $Root "Start.cmd") $shortcut -Force
    Write-Log "Ярлык на рабочем столе: $shortcut"
} catch {
    Write-Log "Не удалось скопировать ярлык на рабочий стол: $_"
}

Write-Log "========== Установка завершена =========="
Write-Host ""
Write-Host "Готово."
Write-Host "  Запуск сервера: Start.cmd (или ярлык на рабочем столе)"
Write-Host "  Админ-панель:  http://localhost:3000/admin/login.html"
Write-Host "  Лог установки: $LogFile"
Write-Host ""
Read-Host "Нажмите Enter для выхода"
