# Диагностика подключения к Digital Signage
Write-Host "=== Digital Signage Диагностика ===" -ForegroundColor Cyan
Write-Host ""

# 1. Провер сервер
Write-Host "[1] Проверка сервера..." -ForegroundColor Yellow
try {
    $r = Invoke-WebRequest -Uri "http://localhost:3000/display" -UseBasicParsing -TimeoutSec 5
    Write-Host "  OK: Сервер отвечает (HTTP $($r.StatusCode))" -ForegroundColor Green
} catch {
    Write-Host "  ERROR: Сервер не отвечает: $_" -ForegroundColor Red
    exit 1
}

# 2. IP-адреса
Write-Host ""
Write-Host "[2] IP-адреса сервера:" -ForegroundColor Yellow
$ips = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "Loopback*" } | Select-Object -ExpandProperty IPAddress
foreach ($ip in $ips) {
    Write-Host "  http://$ip`:3000/display" -ForegroundColor Cyan
}

# 3. Проверка порта
Write-Host ""
Write-Host "[3] Порт 3000:" -ForegroundColor Yellow
$listener = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if ($listener) {
    Write-Host "  OK: Слушает на $($listener[0].LocalAddress):3000" -ForegroundColor Green
} else {
    Write-Host "  ERROR: Порт 3000 не слушает" -ForegroundColor Red
}

# 4. Брандмауэр
Write-Host ""
Write-Host "[4] Брандмауэр:" -ForegroundColor Yellow
$fwRule = Get-NetFirewallRule -DisplayName "*3000*" -ErrorAction SilentlyContinue
if ($fwRule) {
    Write-Host "  OK: Правило найдено" -ForegroundColor Green
} else {
    Write-Host "  WARN: Правило брандмауэра для порта 3000 не найдено" -ForegroundColor Yellow
    Write-Host "  Создаю правило..." -ForegroundColor Yellow
    New-NetFirewallRule -DisplayName "Digital Signage (TCP 3000)" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow -Profile Any -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  Правило создано" -ForegroundColor Green
}

# 5. Экраны в БД
Write-Host ""
Write-Host "[5] Экраны в базе данных:" -ForegroundColor Yellow
try {
    $env:PGPASSWORD = "digitalsignage"
    $screens = & psql -U digitalsignage -h localhost -d digitalsignage_db -t -c "SELECT id, name, status, ip_address FROM screens ORDER BY created_at DESC LIMIT 5;" 2>$null
    if ($screens) {
        $screens.Trim() -split "`n" | ForEach-Object { Write-Host "  $_" }
    } else {
        Write-Host "  Нет зарегистрированных экранов" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Не удалось подключиться к БД" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Инструкция ===" -ForegroundColor Cyan
Write-Host "1. Откройте на экране (ТВ): http://<IP_СЕРВЕРА>:3000/display" -ForegroundColor White
Write-Host "2. Убедитесь, что экран и сервер в одной сети" -ForegroundColor White
Write-Host "3. Проверьте, что брандмауэр не блокирует подключения" -ForegroundColor White
Write-Host ""
