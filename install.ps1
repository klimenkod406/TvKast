# Digital Signage - polnaya ustanovka (Windows)
# Log: $env:TEMP\DigitalSignage-Setup.log
# Zapusk: dvoynoy shchelchok po Install.cmd

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
# Use short path to avoid Cyrillic issues
try {
    $Root = (Get-Item $Root).FullName
} catch {
    # Fallback: continue with original path
}
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

Write-Log "========== Digital Signage: ustanovka =========="
Write-Log "Catalog: $Root"

if (-not (Test-NodeVersion)) {
    Write-Log "OSHIBKA: Nuzhen Node.js 18 ili nozhee."
    Write-Log "Skachayte: https://nodejs.org/ (LTS) i povtorite ustanovku."
    Write-Log "Libo (ot administratora): winget install OpenJS.NodeJS.LTS"
    Read-Host "Nazhmite Enter dlya vykhoda"
    exit 1
}

$nodeVer = & node -v
Write-Log "Node.js: $nodeVer"

Write-Log "Ustanovka npm-zavisimostey..."
& npm install --no-fund --no-audit
if ($LASTEXITCODE -ne 0) {
    Write-Log "OSHIBKA: npm install zavershilsya s oshibkoy."
    Read-Host "Nazhmite Enter dlya vykhoda"
    exit 1
}

Write-Log "Sozdanie katalogov media..."
$dirs = @("media", "media\original", "media\converted", "media\metadata")
foreach ($d in $dirs) {
    $p = Join-Path $Root $d
    if (-not (Test-Path $p)) {
        New-Item -ItemType Directory -Path $p -Force | Out-Null
        Write-Log "Sozdan: $p"
    }
}

$binDir = Join-Path $env:LOCALAPPDATA "DigitalSignage\bin"
$ffmpegScript = Join-Path $Root "download-ffmpeg.ps1"
Write-Log "Proverka / ustanovka ffmpeg (v profil polzovatelya, bez prav administratora)..."
try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ffmpegScript -InstallPath $binDir
} catch {
    Write-Log "Preduprezhdenie: ffmpeg: $_"
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
    Write-Log "Preduprezhdenie: ffmpeg ne nayden - ustanovite vruchnuyu ili proverite internet."
}

Write-Host ""
Write-Host "PostgreSQL: parametry superpolzovatelya (dlya sozdaniya BD i polzovatelya prilozheniya)."
Write-Host "Sluzhba PostgreSQL dolzhna byt zapushchena (services.msc)."
Write-Host ""
$pgHost = Read-Host "Host [localhost]"
if ([string]::IsNullOrWhiteSpace($pgHost)) { $pgHost = "localhost" }
$pgPort = Read-Host "Port [5432]"
if ([string]::IsNullOrWhiteSpace($pgPort)) { $pgPort = "5432" }
$pgSuper = Read-Host "Imya superpolzovatelya [postgres]"
if ([string]::IsNullOrWhiteSpace($pgSuper)) { $pgSuper = "postgres" }
Write-Host "Parol superpolzovatelya (Enter = pustoy, yesli u postgres doverie localhost):"
$sec = Read-Host -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
$pgPassPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

$env:POSTGRES_HOST = $pgHost
$env:POSTGRES_PORT = $pgPort
$env:POSTGRES_SUPERUSER = $pgSuper
$env:POSTGRES_SUPERUSER_PASSWORD = $pgPassPlain

Write-Log "Sozdanie BD, polzovatelya prilozheniya i fayla .env..."
& node (Join-Path $Root "scripts\ensure-db.js")
if ($LASTEXITCODE -ne 0) {
    Write-Log "OSHIBKA: ensure-db. Proverte parol, chto PostgreSQL zapushchen i port $pgPort dostupan."
    Read-Host "Nazhmite Enter dlya vykhoda"
    exit 1
}

if ((Test-Path $ff) -and $env:FFMPEG_PATH) {
    & node (Join-Path $Root "scripts\set-env-value.js") "FFMPEG_PATH" $env:FFMPEG_PATH
    Write-Log "Obnovlyon FFMPEG_PATH v .env"
}

Write-Host ""
$adminPass = Read-Host "Parol vhoda v admin-panel (login admin) [sluchaynyy]"
if ([string]::IsNullOrWhiteSpace($adminPass)) {
    $chars = (48..57) + (65..90) + (97..122)
    $adminPass = -join ($chars | Get-Random -Count 16 | ForEach-Object { [char]$_ })
    Write-Log "Sgenerirovan parol administratora (sohranite): $adminPass"
    Write-Host ""
    Write-Host "VAZHNO: sokhranite parol administratora: $adminPass"
    Write-Host ""
} else {
    Write-Log "Parol administratora zadan vruchnuyu."
}

$env:ADMIN_PASSWORD = $adminPass

Write-Log "Sozdanie tablits i uchetnoy zapisi admin..."
& npm run db:init
if ($LASTEXITCODE -ne 0) {
    Write-Log "OSHIBKA: db:init"
    Read-Host "Nazhmite Enter dlya vykhoda"
    exit 1
}

Remove-Item Env:ADMIN_PASSWORD -ErrorAction SilentlyContinue

$marker = Join-Path $Root "INSTALL_OK"
try {
    "installed $(Get-Date -Format o)" | Out-File -FilePath $marker -Encoding utf8 -Force
    Write-Log "Sozdan marker: INSTALL_OK"
} catch {
    Write-Log "WARN: Ne udalos sozdat INSTALL_OK: $_"
}

try {
    $desk = [Environment]::GetFolderPath("Desktop")
    $shortcutName = "Digital Signage - zapusk.cmd"
    $shortcut = Join-Path $desk $shortcutName
    Copy-Item (Join-Path $Root "Start.cmd") $shortcut -Force
    Write-Log "Yarlyk na rabochem stole: $shortcut"
} catch {
    Write-Log "Ne udalos skopirovat yarlyk na rabochiy stol: $_"
}

Write-Log "========== Ustanovka zavershena =========="
Write-Host ""
Write-Host "Gotovo."
Write-Host "  Zapusk servera: Start.cmd (ili yarlyk na rabochem stole)"
Write-Host "  Admin-panel:  http://localhost:3000/admin/login.html"
Write-Host "  Log ustanovki: $LogFile"
Write-Host ""
Read-Host "Nazhmite Enter dlya vykhoda"
