<#
.SYNOPSIS
    Digital Signage — единый CLI-установщик
.DESCRIPTION
    Интерактивный установщик с цветным выводом, меню и маской пароля.
    Единственная точка входа — запустить: .\Install.ps1
.NOTES
    Требуется PowerShell 5.1+ (встроен в Windows 7+)
#>

# ============================================================
# Инициализация
# ============================================================
$ErrorActionPreference = "Stop"

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
try { $ScriptRoot = (Get-Item $ScriptRoot).FullName } catch { }
Set-Location $ScriptRoot

$LogFile   = Join-Path $env:TEMP "DigitalSignage-Setup.log"
$InstallDir = $ScriptRoot

# Очистка лога
if (Test-Path $LogFile) { Clear-Content $LogFile }

# ============================================================
# Цветовые утилиты
# ============================================================
$ESC = [char]27

$Colors = @{
    Reset    = "$ESC[0m"
    Bold     = "$ESC[1m"
    Dim      = "$ESC[2m"
    Underline= "$ESC[4m"
    Red      = "$ESC[31m"
    Green    = "$ESC[32m"
    Yellow   = "$ESC[33m"
    Blue     = "$ESC[34m"
    Magenta  = "$ESC[35m"
    Cyan     = "$ESC[36m"
    White    = "$ESC[37m"
    BrightCyan  = "$ESC[96m"
    BrightGreen = "$ESC[92m"
    BrightYellow= "$ESC[93m"
    BrightRed   = "$ESC[91m"
    BrightWhite = "$ESC[97m"
    BgBlue   = "$ESC[44m"
    BgGreen  = "$ESC[42m"
    BgDark   = "$ESC[48;5;236m"
}

function Clear-Host2 {
    [Console]::Clear()
}

function Write-Centered {
    param([string]$Text, [int]$Width = 70)
    $pad = [Math]::Max(0, ($Width - $Text.Length) / 2)
    $padding = " " * [Math]::Floor($pad)
    Write-Host "${padding}$Text"
}

function Write-Logo {
    Clear-Host2
    Write-Host ""
    Write-Host "$($Colors.Bold)$($Colors.Cyan)" -NoNewline
    Write-Centered "╔══════════════════════════════════════════════════════╗"
    Write-Centered "║                                                      ║"
    Write-Centered "║   ███╗   ██╗ ██████╗ ██╗   ██╗ █████╗                ║"
    Write-Centered "║   ████╗  ██║██╔═══██╗██║   ██║██╔══██╗               ║"
    Write-Centered "║   ██╔██╗ ██║██║   ██║██║   ██║███████║               ║"
    Write-Centered "║   ██║╚██╗██║██║   ██║╚██╗ ██╔╝██╔══██║               ║"
    Write-Centered "║   ██║ ╚████║╚██████╔╝ ╚████╔╝ ██║  ██║               ║"
    Write-Centered "║   ╚═╝  ╚═══╝ ╚═════╝   ╚═══╝  ╚═╝  ╚═╝               ║"
    Write-Centered "║                                                      ║"
    Write-Centered "║        D I G I T A L   S I G N A G E                ║"
    Write-Centered "║              Мастер установки  v1.0.0                 ║"
    Write-Centered "║                                                      ║"
    Write-Centered "╚══════════════════════════════════════════════════════╝"
    Write-Host "$($Colors.Reset)"
    Write-Host ""
}

function Write-StepHeader {
    param([string]$Title, [string]$Step, [string]$Total = "7")
    Write-Host ""
    Write-Host "$($Colors.Bold)$($Colors.BgBlue)$($Colors.White)  ШАГ $Step/$Total  $($Colors.Reset)"
    Write-Host "$($Colors.Bold)$($Colors.Cyan)$Title$($Colors.Reset)"
    Write-Host "$($Colors.Dim)$('-' * 60)$($Colors.Reset)"
}

function Write-Ok {
    param([string]$Msg)
    Write-Host "  $($Colors.BrightGreen)[OK]$($Colors.Reset) $Msg"
}

function Write-Err {
    param([string]$Msg)
    Write-Host "  $($Colors.BrightRed)[ERROR]$($Colors.Reset) $Msg" -ForegroundColor Red
}

function Write-Warn {
    param([string]$Msg)
    Write-Host "  $($Colors.BrightYellow)[WARN]$($Colors.Reset) $Msg" -ForegroundColor Yellow
}

function Write-Info {
    param([string]$Msg)
    Write-Host "  $($Colors.Cyan)[INFO]$($Colors.Reset) $Msg"
}

function Write-Success {
    param([string]$Msg)
    Write-Host "  $($Colors.BrightGreen)[SUCCESS]$($Colors.Reset) $Msg"
}

# ============================================================
# Логирование
# ============================================================
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $line = "{0} [{1}] {2}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Level, $Message
    Add-Content -Path $LogFile -Value $line -Encoding UTF8
}

# ============================================================
# Ввод с маской пароля
# ============================================================
function Read-MaskedPassword {
    param([string]$Prompt = "Пароль")
    Write-Host "  $Prompt " -NoNewline
    $pw = ""
    $cons = [System.Console]
    # Сохраняем текущий цвет
    $origFg = $cons::ForegroundColor
    $origBg = $cons::BackgroundColor

    try {
        # Устанавливаем тёмно-серый для маски
        if ($origBg -ne "Black") {
            $cons::BackgroundColor = "Black"
        }
        $cons::ForegroundColor = "DarkGray"

        while ($true) {
            $key = $cons::ReadKey($true)
            if ($key.Key -eq "Enter") {
                break
            }
            if ($key.Key -eq "Escape") {
                Write-Host ""
                return ""
            }
            if ($key.Key -eq "Backspace") {
                if ($pw.Length -gt 0) {
                    $pw = $pw.Substring(0, $pw.Length - 1)
                    Write-Host "`b $`b" -NoNewline
                }
            } elseif ($key.Key -eq "LeftArrow" -or $key.Key -eq "RightArrow" -or
                      $key.Key -eq "UpArrow" -or $key.Key -eq "DownArrow" -or
                      $key.Key -eq "Tab") {
                # Игнорируем навигационные клавиши
            } else {
                $pw += $key.KeyChar
                Write-Host "•" -NoNewline
            }
        }
    } finally {
        $cons::ForegroundColor = $origFg
        $cons::BackgroundColor = $origBg
        Write-Host ""
    }

    return $pw
}

# ============================================================
# Интерактивное меню
# ============================================================
function Show-Menu {
    param(
        [string]$Title,
        [string[]]$Options,
        [int]$DefaultIndex = 0
    )

    Write-Host ""
    Write-Host "  $($Colors.Bold)$Title$($Colors.Reset)"
    Write-Host ""

    $selected = $DefaultIndex
    $page = 0
    $pageSize = 10

    function Draw-Menu {
        Clear-Host2
        Write-Logo
        Write-Host "  $($Colors.Bold)$Title$($Colors.Reset)"
        Write-Host ""

        for ($i = 0; $i -lt $Options.Count; $i++) {
            if ($i -eq $selected) {
                Write-Host "  $($Colors.BgBlue)$($Colors.White)  $($Options[$i])  $($Colors.Reset)"
            } else {
                Write-Host "     $($Options[$i])"
            }
        }

        Write-Host ""
        Write-Host "  $($Colors.Dim)↑↓ — навигация  |  Enter — выбор  |  Esc — отмена$($Colors.Reset)"
    }

    Draw-Menu

    while ($true) {
        $key = [System.Console]::ReadKey($true)

        if ($key.Key -eq "UpArrow" -or $key.Key -eq "W") {
            $selected = ($selected - 1 + $Options.Count) % $Options.Count
            Draw-Menu
        }
        elseif ($key.Key -eq "DownArrow" -or $key.Key -eq "S") {
            $selected = ($selected + 1) % $Options.Count
            Draw-Menu
        }
        elseif ($key.Key -eq "Enter") {
            Write-Host ""
            return $selected
        }
        elseif ($key.Key -eq "Escape") {
            Write-Host ""
            return -1
        }
    }
}

# ============================================================
# Прогресс-бар
# ============================================================
function Write-Progress2 {
    param(
        [int]$Percent,
        [string]$Activity = "Выполняется",
        [int]$Width = 50
    )
    $filled = [Math]::Floor($Width * $Percent / 100)
    $empty = $Width - $filled
    $bar = "$($Colors.BrightGreen)" + ("█" * $filled) + "$($Colors.Dim)" + ("░" * $empty) + "$($Colors.Reset)"
    Write-Host "  $bar $($Colors.Bold)$Percent%$($Colors.Reset)  $Activity" -NoNewline
    if ($Percent -lt 100) {
        Write-Host "`r" -NoNewline
    } else {
        Write-Host ""
    }
}

# ============================================================
# Проверки
# ============================================================
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

function Test-PostgresPort {
    param([string]$Host, [string]$Port)
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $tcp.Connect($Host, [int]$Port)
        $tcp.Close()
        return $true
    } catch {
        return $false
    }
}

# ============================================================
# Утилиты
# ============================================================
function Install-Ffmpeg {
    param([string]$TargetPath)
    $url = "https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip"
    $zipPath = Join-Path $env:TEMP "ffmpeg-win64.zip"
    $extractPath = Join-Path $env:TEMP "ffmpeg-extract"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $progressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
        $progressPreference = 'Continue'
    } catch {
        Write-Log "Ошибка загрузки ffmpeg: $_" -Level "ERROR"
        return $null
    }

    if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
    Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

    $exe = Get-ChildItem -Path $extractPath -Recurse -Filter "ffmpeg.exe" | Select-Object -First 1
    if (-not $exe) {
        Write-Log "ffmpeg.exe не найден в архиве" -Level "ERROR"
        return $null
    }

    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
    Copy-Item $exe.FullName (Join-Path $TargetPath "ffmpeg.exe") -Force

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
    if (-not $found) { $out += "$Key=$Value" }
    [System.IO.File]::WriteAllLines($EnvPath, $out, [System.Text.Encoding]::UTF8)
}

function Create-MediaDirs {
    $dirs = @("media", "media\original", "media\converted", "media\metadata")
    foreach ($d in $dirs) {
        $p = Join-Path $InstallDir $d
        if (-not (Test-Path $p)) {
            New-Item -ItemType Directory -Path $p -Force | Out-Null
        }
    }
}

function Generate-Password {
    $chars = (48..57) + (65..90) + (97..122) + @(33, 64, 35, 36, 37)
    return -join ($chars | Get-Random -Count 16 | ForEach-Object { [char]$_ })
}

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ============================================================
# Установка NPM-зависимостей с прогрессом
# ============================================================
function Run-NpmInstall {
    Write-Host "  Выполняется $($Colors.Bold)npm install$($Colors.Reset)..."
    Write-Host ""

    $npmOutput = & npm install --no-fund --no-audit 2>&1 | Out-String
    Write-Log $npmOutput

    $lines = $npmOutput -split "`n"
    foreach ($line in $lines) {
        $line = $line.Trim()
        if ($line -match "added\s+(\d+)" -or $line -match "installed\s+(\d+)") {
            Write-Ok "Установлено $($Matches[1]) пакетов"
        }
    }

    return $LASTEXITCODE -eq 0
}

# ============================================================
# Главный процесс установки
# ============================================================
function Main-Install {

    Write-Logo
    Write-Log "========== Запуск установщика =========="
    Write-Log "Каталог: $InstallDir"

    # --- Приветствие ---
    Write-Host "  $($Colors.Bold)Добро пожаловать в мастер установки Digital Signage!$($Colors.Reset)"
    Write-Host ""
    Write-Host "  Система управления цифровыми табло:"
    Write-Host "    $($Colors.Dim)• Сервер API/WebSocket$($Colors.Reset)"
    Write-Host "    $($Colors.Dim)• Админ-панель (веб)$($Colors.Reset)"
    Write-Host "    $($Colors.Dim)• Клиент для Smart TV$($Colors.Reset)"
    Write-Host ""
    Write-Host "  $($Colors.Dim)Каталог установки: $InstallDir$($Colors.Reset)"
    Write-Host "  $($Colors.Dim)Лог-файл: $LogFile$($Colors.Reset)"
    Write-Host ""

    # --- Проверка прав ---
    $isAdmin = Test-Admin
    if ($isAdmin) {
        Write-Ok "Запущен от имени администратора (сервис будет зарегистрирован)"
    } else {
        Write-Warn "Без прав администратора (сервис не будет зарегистрирован)"
    }

    Write-Host ""
    Write-Host "  $($Colors.Dim)Нажмите Enter для начала установки...$($Colors.Reset)" -NoNewline
    $null = [System.Console]::ReadLine()

    # ============================================================
    # ШАГ 1: Проверка Node.js
    # ============================================================
    Write-StepHeader "Проверка Node.js" "1"

    if (-not (Test-NodeVersion)) {
        Write-Err "Требуется Node.js версии 18 или выше"
        Write-Host ""
        Write-Host "  Скачайте и установите: $($Colors.Underline)https://nodejs.org/$($Colors.Reset)"
        Write-Host ""
        Write-Host "  $($Colors.Dim)Нажмите Enter для выхода...$($Colors.Reset)"
        $null = [System.Console]::ReadLine()
        exit 1
    }
    $nodeVer = & node -v
    Write-Ok "Node.js $nodeVer"

    # ============================================================
    # ШАГ 2: npm install
    # ============================================================
    Write-StepHeader "Установка зависимостей" "2"

    if (-not (Run-NpmInstall)) {
        Write-Err "npm install завершился с ошибкой"
        Write-Host ""
        Write-Host "  $($Colors.Dim)Нажмите Enter для выхода...$($Colors.Reset)"
        $null = [System.Console]::ReadLine()
        exit 1
    }
    Write-Ok "npm-зависимости установлены"

    # ============================================================
    # ШАГ 3: Служебные каталоги
    # ============================================================
    Write-StepHeader "Создание каталогов" "3"

    Create-MediaDirs
    $logDir = Join-Path $InstallDir "logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    Write-Ok "media/original, converted, metadata"
    Write-Ok "logs"

    # ============================================================
    # ШАГ 4: ffmpeg
    # ============================================================
    Write-StepHeader "Проверка / установка ffmpeg" "4"

    $ffmpegPath = $null

    # 4a. Проверка в PATH
    $existing = Get-Command ffmpeg -ErrorAction SilentlyContinue
    if ($existing -and (Test-FfmpegOk $existing.Source)) {
        $ffmpegPath = $existing.Source
        Write-Ok "ffmpeg найден в PATH: $ffmpegPath"
    }

    # 4b. Проверка локального bin/
    if (-not $ffmpegPath) {
        $localFfmpeg = Join-Path $InstallDir "bin\ffmpeg.exe"
        if (Test-FfmpegOk $localFfmpeg) {
            $ffmpegPath = $localFfmpeg
            Write-Ok "ffmpeg найден локально: $ffmpegPath"
        }
    }

    # 4c. Скачивание
    if (-not $ffmpegPath) {
        Write-Info "ffmpeg не найден — скачивание (~100 МБ)..."
        $binDir = Join-Path $InstallDir "bin"

        # Показываем прогресс загрузки
        Write-Host "  Загрузка..."
        $ffmpegPath = Install-Ffmpeg $binDir

        if ($ffmpegPath -and (Test-FfmpegOk $ffmpegPath)) {
            Write-Ok "ffmpeg установлен: $ffmpegPath"
            Write-Progress2 -Percent 100 -Activity "ffmpeg загружен"
        } else {
            Write-Warn "ffmpeg не установлен — установите вручную и укажите путь"
            $ffmpegPath = "ffmpeg"
        }
    }

    $ffmpegVer = & $ffmpegPath -version 2>&1 | Select-Object -First 1
    Write-Ok "ffmpeg: $ffmpegVer"

    # ============================================================
    # ШАГ 5: PostgreSQL
    # ============================================================
    Write-StepHeader "Настройка PostgreSQL" "5"

    Write-Host ""
    Write-Host "  Служба PostgreSQL должна быть запущена."
    Write-Host "  $($Colors.Dim)(services.msc → PostgreSQL → Запущена)$($Colors.Reset)"
    Write-Host ""

    # Хост
    $pgHost = Read-Host "  Хост PostgreSQL          [localhost]"
    if ([string]::IsNullOrWhiteSpace($pgHost)) { $pgHost = "localhost" }

    # Порт
    $pgPort = Read-Host "  Порт PostgreSQL            [5432]"
    if ([string]::IsNullOrWhiteSpace($pgPort)) { $pgPort = "5432" }

    # Суперпользователь
    $pgSuper = Read-Host "  Имя суперпользователя    [postgres]"
    if ([string]::IsNullOrWhiteSpace($pgSuper)) { $pgSuper = "postgres" }

    # Пароль (с маской)
    Write-Host ""
    Write-Info "Если пароль не задан — нажмите Enter (пустой пароль)"
    $pgPass = Read-MaskedPassword -Prompt "  Пароль суперпользователя:"

    Write-Host ""
    Write-Info "Проверка подключения к PostgreSQL ($pgHost`:$pgPort)..."

    if (-not (Test-PostgresPort $pgHost $pgPort)) {
        Write-Err "Не удалось подключиться к PostgreSQL"
        Write-Host ""
        Write-Host "  Проверьте:"
        Write-Host "    1. Служба PostgreSQL запущена (services.msc)"
        Write-Host "    2. Хост и порт указаны верно"
        Write-Host ""
        Write-Host "  $($Colors.Dim)Нажмите Enter для выхода...$($Colors.Reset)"
        $null = [System.Console]::ReadLine()
        exit 1
    }
    Write-Ok "Подключение к PostgreSQL"

    # Создаём/обновляем .env
    $envPath = Join-Path $InstallDir ".env"
    $envExamplePath = Join-Path $InstallDir ".env.example"
    if (-not (Test-Path $envPath) -and (Test-Path $envExamplePath)) {
        Copy-Item $envExamplePath $envPath -Force
        Write-Ok "Создан .env из .env.example"
    }

    # Передаём переменные для ensure-db
    $env:POSTGRES_HOST = $pgHost
    $env:POSTGRES_PORT = $pgPort
    $env:POSTGRES_SUPERUSER = $pgSuper
    $env:POSTGRES_SUPERUSER_PASSWORD = $pgPass

    Write-Info "Создание БД и пользователя приложения..."
    $ensureOut = & node (Join-Path $ScriptRoot "scripts\ensure-db.js") 2>&1 | Out-String
    Write-Log $ensureOut
    Write-Host $ensureOut.Trim()

    if ($LASTEXITCODE -ne 0) {
        Write-Err "ensure-db — проверьте параметры PostgreSQL"
        Write-Host ""
        Write-Host "  $($Colors.Dim)Нажмите Enter для выхода...$($Colors.Reset)"
        $null = [System.Console]::ReadLine()
        exit 1
    }
    Write-Ok "База данных и пользователь созданы"

    if ($ffmpegPath -and $ffmpegPath -ne "ffmpeg") {
        Set-EnvValue "FFMPEG_PATH" $ffmpegPath $envPath
        Write-Ok "FFMPEG_PATH записан в .env"
    }

    # ============================================================
    # ШАГ 6: Пароль администратора + таблицы
    # ============================================================
    Write-StepHeader "Учётная запись администратора" "6"

    Write-Host ""
    Write-Host "  Логин по умолчанию: $($Colors.Bold)admin$($Colors.Reset)"
    Write-Host ""

    # Выбор: ввести пароль или сгенерировать
    $menuOptions = @("Ввести пароль вручную", "Сгенерировать случайный пароль")
    $choice = Show-Menu -Title "Выберите способ задания пароля администратора:" -Options $menuOptions -DefaultIndex 0

    if ($choice -eq 0) {
        # Ввод вручную
        while ($true) {
            $adminPass1 = Read-MaskedPassword -Prompt "  Введите пароль администратора:"
            if ([string]::IsNullOrWhiteSpace($adminPass1)) {
                Write-Warn "Пароль не может быть пустым"
                continue
            }
            if ($adminPass1.Length -lt 8) {
                Write-Warn "Пароль должен быть не менее 8 символов"
                continue
            }
            $adminPass2 = Read-MaskedPassword -Prompt "  Подтвердите пароль:"
            if ($adminPass1 -ne $adminPass2) {
                Write-Warn "Пароли не совпадают, попробуйте снова"
                continue
            }
            $adminPass = $adminPass1
            break
        }
    } else {
        $adminPass = Generate-Password
        Write-Host ""
        Write-Host "  $($Colors.Bold)$($Colors.Yellow)Сгенерированный пароль: $adminPass$($Colors.Reset)"
        Write-Host "  $($Colors.Yellow)!!! Сохраните его — он не будет показан снова !!!$($Colors.Reset)"
        Write-Host ""
    }

    # Инициализация БД
    Write-Host ""
    Write-Info "Создание таблиц и учётной записи admin..."
    $env:ADMIN_PASSWORD = $adminPass
    $dbInitOut = & npm run db:init 2>&1 | Out-String
    Write-Log $dbInitOut
    Write-Host $dbInitOut.Trim()
    Remove-Item Env:ADMIN_PASSWORD -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -ne 0) {
        Write-Err "db:init — таблицы не созданы"
        Write-Host ""
        Write-Host "  $($Colors.Dim)Нажмите Enter для выхода...$($Colors.Reset)"
        $null = [System.Console]::ReadLine()
        exit 1
    }
    Write-Ok "Таблицы созданы, admin зарегистрирован"

    # ============================================================
    # ШАГ 7: Завершение + регистрация сервиса
    # ============================================================
    Write-StepHeader "Завершение установки" "7"

    $markerPath = Join-Path $InstallDir "INSTALL_OK"
    "installed $(Get-Date -Format o)" | Out-File -FilePath $markerPath -Encoding utf8 -Force
    Write-Ok "Маркер установки создан: INSTALL_OK"

    # Регистрация Windows-сервиса (если есть права)
    $serviceRegistered = $false
    if ($isAdmin) {
        Write-Host ""
        Write-Host "  Регистрация как Windows-сервис (автозапуск)..."

        # Скачиваем NSSM если нужен
        $nssmDir = Join-Path $InstallDir "service"
        $nssmExe = Join-Path $nssmDir "nssm.exe"

        if (-not (Test-Path $nssmExe)) {
            Write-Info "NSSM не найден — скачивание..."
            try {
                $nssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
                $nssmZip = Join-Path $env:TEMP "nssm.zip"
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $nssmUrl -OutFile $nssmZip -UseBasicParsing
                New-Item -ItemType Directory -Path $nssmDir -Force | Out-Null
                Expand-Archive -Path $nssmZip -DestinationPath (Join-Path $env:TEMP "nssm-extract") -Force

                $extractedNssm = Get-ChildItem -Path (Join-Path $env:TEMP "nssm-extract") -Recurse -Filter "nssm.exe" |
                    Where-Object { $_.FullName -match "win64" } | Select-Object -First 1

                if ($extractedNssm) {
                    Copy-Item $extractedNssm.FullName $nssmExe -Force
                    Write-Ok "NSSM загружен"
                }
                Remove-Item $nssmZip -Force -ErrorAction SilentlyContinue
                Remove-Item (Join-Path $env:TEMP "nssm-extract") -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                Write-Warn "Не удалось скачать NSSM — сервис не зарегистрирован"
            }
        }

        if (Test-Path $nssmExe) {
            $nodeExe = (Get-Command node -ErrorAction SilentlyContinue).Source
            if (-not $nodeExe) { $nodeExe = "C:\Program Files\nodejs\node.exe" }

            & $nssmExe stop DigitalSignage 60000 2>$null | Out-Null
            & $nssmExe remove DigitalSignage confirm 2>$null | Out-Null

            & $nssmExe install DigitalSignage $nodeExe "$InstallDir\src\server.js"
            & $nssmExe set DigitalSignage DisplayName "Digital Signage Server"
            & $nssmExe set DigitalSignage Start SERVICE_AUTO_START
            & $nssmExe set DigitalSignage AppDirectory $InstallDir
            & $nssmExe set DigitalSignage AppStdout "$InstallDir\logs\service-stdout.log"
            & $nssmExe set DigitalSignage AppStderr "$InstallDir\logs\service-stderr.log"

            $pgServiceNames = @("postgresql-x64-14","postgresql-x64-15","postgresql-x64-16","postgresql-x64-17","postgresql")
            foreach ($pgName in $pgServiceNames) {
                $pgSvc = Get-Service -Name $pgName -ErrorAction SilentlyContinue
                if ($pgSvc) {
                    & $nssmExe set DigitalSignage DependOnService $pgName
                    break
                }
            }

            # Переменные окружения
            if (Test-Path $envPath) {
                $envContent = Get-Content $envPath -Raw
                $envVars = @()
                foreach ($line in ($envContent -split "`n")) {
                    $line = $line.Trim()
                    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
                        $envVars += $line
                    }
                }
                if ($envVars.Count -gt 0) {
                    & $nssmExe set DigitalSignage AppEnvironmentExtra $envVars
                }
            }

            & $nssmExe start DigitalSignage
            if ($LASTEXITCODE -eq 0) {
                $serviceRegistered = $true
                Write-Ok "Сервис DigitalSignage зарегистрирован и запущен"
            } else {
                Write-Warn "Не удалось запустить сервис — запустите вручную через Start.cmd"
            }
        }
    }

    # Ярлык на рабочем столе
    try {
        $desktop = [Environment]::GetFolderPath("Desktop")
        $shortcutPath = Join-Path $desktop "Digital Signage — запуск.lnk"
        $WshShell = New-Object -ComObject WScript.Shell
        $shortcut = $WshShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = Join-Path $InstallDir "Start.cmd"
        $shortcut.WorkingDirectory = $InstallDir
        $shortcut.Description = "Запуск Digital Signage Server"
        $shortcut.Save()
        Write-Ok "Ярлык на рабочем столе создан"
    } catch {
        Write-Warn "Не удалось создать ярлык"
    }

    # Порт
    $port = 3000
    if (Test-Path $envPath) {
        foreach ($line in [System.IO.File]::ReadAllLines($envPath)) {
            $line = $line.Trim()
            if ($line -match "^PORT=(\d+)") {
                $port = [int]$Matches[1]
                break
            }
        }
    }

    # ============================================================
    # ФИНАЛЬНЫЙ ЭКРАН
    # ============================================================
    Clear-Host2
    Write-Logo

    Write-Host "  $($Colors.Bold)$($Colors.BrightGreen)═══════════════════════════════════════════════════$($Colors.Reset)"
    Write-Host "  $($Colors.Bold)$($Colors.BrightGreen)   УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО!                    $($Colors.Reset)"
    Write-Host "  $($Colors.Bold)$($Colors.BrightGreen)═══════════════════════════════════════════════════$($Colors.Reset)"
    Write-Host ""

    Write-Host "  $($Colors.Bold)$($Colors.Cyan)Ссылки:$($Colors.Reset)"
    Write-Host "    Админ-панель:  $($Colors.Underline)$($Colors.BrightCyan)http://localhost:$port/admin/login.html$($Colors.Reset)"
    Write-Host "    Плеер (ТВ):    $($Colors.Dim)http://localhost:$port/display/<screenId>$($Colors.Reset)"
    Write-Host ""

    Write-Host "  $($Colors.Bold)$($Colors.Cyan)Вход в админ-панель:$($Colors.Reset)"
    Write-Host "    Логин:         $($Colors.Bold)$admin$($Colors.Reset)"
    Write-Host "    Пароль:        $($Colors.Bold)$adminPass$($Colors.Reset)"
    Write-Host ""

    Write-Host "  $($Colors.Bold)$($Colors.Cyan)Запуск сервера:$($Colors.Reset)"
    if ($serviceRegistered) {
        Write-Host "    Сервис запущен автоматически как $($Colors.Bold)DigitalSignage$($Colors.Reset)"
        Write-Host "    Остановить:    $($Colors.Dim)net stop DigitalSignage$($Colors.Reset)"
    } else {
        Write-Host "    $($Colors.Bold)Start.cmd$($Colors.Reset) (двойной щелчок)"
    }
    Write-Host ""

    Write-Host "  $($Colors.Bold)$($Colors.Cyan)Лог установки:$($Colors.Reset)"
    Write-Host "    $LogFile"
    Write-Host ""

    Write-Host "  $($Colors.Dim)Нажмите Enter для выхода...$($Colors.Reset)"
    $null = [System.Console]::ReadLine()

    Write-Log "========== Установка завершена =========="
    exit 0
}

# ============================================================
# Точка входа
# ============================================================
try {
    Main-Install
} catch {
    Write-Host ""
    Write-Err "Критическая ошибка: $_"
    Write-Log "КРИТИЧЕСКАЯ ОШИБКА: $_" -Level "FATAL"
    Write-Host ""
    Write-Host "  $($Colors.Dim)Нажмите Enter для выхода...$($Colors.Reset)"
    $null = [System.Console]::ReadLine()
    exit 1
}
