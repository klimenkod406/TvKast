param(
  [string]$InstallPath = (Join-Path $env:LOCALAPPDATA "DigitalSignage\bin")
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Test-FfmpegOk {
  param([string]$ExePath)
  if (-not (Test-Path $ExePath)) { return $false }
  try {
    $out = & $ExePath -version 2>&1 | Out-String
    if ($out -match "ffmpeg version") {
      if ($out -match "ffmpeg version\s+(\d+)") {
        return [int]$Matches[1] -ge 5
      }
      return $true
    }
  } catch { }
  return $false
}

$existing = Get-Command ffmpeg -ErrorAction SilentlyContinue
if ($existing -and (Test-FfmpegOk $existing.Source)) {
  Write-Host "Используется ffmpeg из PATH: $($existing.Source)"
  exit 0
}

$localExe = Join-Path $InstallPath "ffmpeg.exe"
if (Test-FfmpegOk $localExe) {
  Write-Host "Используется локальный ffmpeg: $localExe"
  exit 0
}

$url = "https://github.com/BtbN/FFmpeg-Builds/releases/latest/download/ffmpeg-master-latest-win64-gpl.zip"
$zipPath = Join-Path $env:TEMP "ffmpeg-win64.zip"
$extractPath = Join-Path $env:TEMP "ffmpeg-extract"

Write-Host "Скачивание ffmpeg (~100 МБ)..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile $zipPath

if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

$exe = Get-ChildItem -Path $extractPath -Recurse -Filter "ffmpeg.exe" |
       Where-Object { $_.Name -eq "ffmpeg.exe" } |
       Select-Object -First 1
if (-not $exe) { throw "ffmpeg.exe не найден в архиве" }

New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
Copy-Item $exe.FullName (Join-Path $InstallPath "ffmpeg.exe") -Force

$probe = Get-ChildItem -Path $extractPath -Recurse -Filter "ffprobe.exe" | Select-Object -First 1
if ($probe) {
    Copy-Item $probe.FullName (Join-Path $InstallPath "ffprobe.exe") -Force
}

Write-Host "ffmpeg установлен: $(Join-Path $InstallPath 'ffmpeg.exe')"
