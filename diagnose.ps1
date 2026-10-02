[CmdletBinding()]
param(
  # ฟังข้อความบน MQTT นานกี่วินาที
  [int]$ListenSeconds = 20
)

$ErrorActionPreference = 'Continue'

try {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$projectDirectory = $PSScriptRoot
$mqttDirectory    = Join-Path $projectDirectory 'mqtt'
$backendDirectory = Join-Path $projectDirectory 'backend'

function Write-Step {
  param([string]$Text)
  Write-Host ''
  Write-Host "==== $Text ====" -ForegroundColor Cyan
}

function Get-DotEnv {
  param([string]$Path)
  $values = @{}
  if (Test-Path -LiteralPath $Path) {
    foreach ($line in Get-Content -LiteralPath $Path) {
      if ($line -match '^\s*([^#\s][^=]*)=(.*)$') {
        $values[$matches[1].Trim()] = $matches[2].Trim()
      }
    }
  }
  return $values
}

function Get-LanIPv4 {
  $addresses = Get-NetIPConfiguration |
    Where-Object { $_.NetAdapter.Status -eq 'Up' -and $null -ne $_.IPv4DefaultGateway } |
    ForEach-Object { $_.IPv4Address.IPAddress } |
    Where-Object { $_ -and $_ -notlike '127.*' -and $_ -notlike '169.254.*' }
  return $addresses | Select-Object -First 1
}

Write-Host 'RMUTT Save Energy - ตรวจหาสาเหตุที่ ESP32 ไม่ขึ้นในแอป'
Write-Host "เวลา: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

# ---------------------------------------------------------------- 1. Docker
Write-Step '1/7 Docker container'
docker ps -a --filter 'name=rmutt' --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

# ------------------------------------------------------------------- 2. IP
Write-Step '2/7 LAN IP กับค่าใน backend/.env'
$lanIp = Get-LanIPv4
$backendValues = Get-DotEnv -Path (Join-Path $backendDirectory '.env')
$mqttUrl = $backendValues['MQTT_URL']
Write-Host "LAN IPv4 ของคอมตอนนี้ : $lanIp"
Write-Host "MQTT_URL ใน .env      : $mqttUrl"
Write-Host "MQTT_USERNAME         : $($backendValues['MQTT_USERNAME'])"

$envHost = ''
if ($mqttUrl -match '^mqtt://([^:/]+)') { $envHost = $matches[1] }
if ($envHost -and $lanIp -and $envHost -ne $lanIp) {
  Write-Host "ไม่ตรงกัน! ESP32 ถูกตั้งให้ไปหา $envHost แต่คอมอยู่ที่ $lanIp" -ForegroundColor Red
  Write-Host 'แก้ด้วย .\run_all.ps1 แล้วตั้งค่า ESP32 ผ่านบลูทูธใหม่' -ForegroundColor Yellow
} elseif ($envHost) {
  Write-Host 'IP ตรงกัน' -ForegroundColor Green
}

# --------------------------------------------------------------- 3. Backend
Write-Step '3/7 Backend /api/health'
try {
  $health = Invoke-RestMethod -Uri 'http://127.0.0.1:3000/api/health' -TimeoutSec 8
  Write-Host "status        : $($health.status)"
  Write-Host "mqtt.connected: $($health.mqtt.connected)"
  Write-Host "mqtt.broker   : $($health.mqtt.broker)"
  Write-Host "topicPrefix   : $($health.mqtt.topicPrefix) / $($health.mqtt.occupancyTopicPrefix)"
  if ($health.mqtt.lastError) {
    Write-Host "lastError     : $($health.mqtt.lastError)" -ForegroundColor Red
  }
  if ($health.mqtt.connected -ne $true) {
    Write-Host 'Backend ยังไม่เชื่อม Broker - ปัญหาอยู่ฝั่งคอม ไม่ใช่ ESP32' -ForegroundColor Red
  }
} catch {
  Write-Host "เรียก /api/health ไม่ได้: $($_.Exception.Message)" -ForegroundColor Red
  Write-Host 'Backend อาจยังไม่ได้เปิด ให้รัน .\run_all.ps1 ก่อน' -ForegroundColor Yellow
}

# -------------------------------------------------------------- 4. Database
Write-Step '4/7 อุปกรณ์ในฐานข้อมูล'
Push-Location $backendDirectory
try {
  node scripts/doctor.js
} finally {
  Pop-Location
}

# -------------------------------------------------------------- 5. Firewall
Write-Step '5/7 Windows Firewall พอร์ต 1883'
$rules = @()
try {
  $rules = @(Get-NetFirewallPortFilter -ErrorAction Stop |
    Where-Object { $_.LocalPort -eq 1883 -or $_.LocalPort -contains 1883 } |
    ForEach-Object { Get-NetFirewallRule -AssociatedNetFirewallPortFilter $_ -ErrorAction SilentlyContinue } |
    Where-Object { $_.Enabled -eq 'True' -and $_.Direction -eq 'Inbound' -and $_.Action -eq 'Allow' })
} catch {
  Write-Host "อ่านกฎ Firewall ไม่ได้: $($_.Exception.Message)" -ForegroundColor Yellow
}
if ($rules.Count -gt 0) {
  Write-Host "พบกฎอนุญาต inbound 1883 จำนวน $($rules.Count) กฎ" -ForegroundColor Green
  $rules | Select-Object -First 5 DisplayName, Profile | Format-Table -AutoSize
} else {
  Write-Host 'ไม่พบกฎอนุญาต inbound TCP 1883' -ForegroundColor Red
  Write-Host 'ESP32 จะต่อ Broker ไม่ได้ถ้า Firewall บล็อกอยู่' -ForegroundColor Yellow
  Write-Host 'เปิด PowerShell แบบ Run as administrator แล้วรัน:' -ForegroundColor Yellow
  Write-Host '  New-NetFirewallRule -DisplayName "RMUTT MQTT 1883" -Direction Inbound -Protocol TCP -LocalPort 1883 -Action Allow -Profile Private'
}

# ------------------------------------------------------------ 6. Broker log
Write-Step '6/7 Log ของ Mosquitto (40 บรรทัดล่าสุด)'
Push-Location $mqttDirectory
try {
  docker compose --env-file .env logs --tail 40 broker
} finally {
  Pop-Location
}

# --------------------------------------------------------- 7. Live messages
Write-Step "7/7 ดักฟังข้อความบน rmutt/# นาน $ListenSeconds วินาที"
$mqttValues = Get-DotEnv -Path (Join-Path $mqttDirectory '.env')
$user = $mqttValues['MQTT_USERNAME']
$pass = $mqttValues['MQTT_PASSWORD']
if (-not $user -or -not $pass) {
  Write-Host 'ไม่พบ MQTT_USERNAME/MQTT_PASSWORD ใน mqtt/.env' -ForegroundColor Red
} else {
  Write-Host 'ถ้ามีข้อความขึ้น = ESP32 ส่งข้อมูลถึง Broker แล้ว'
  Write-Host 'ถ้าไม่มีอะไรเลย = ESP32 ยังต่อ Broker ไม่ได้'
  Write-Host ''
  docker exec rmutt-mosquitto mosquitto_sub -h 127.0.0.1 -p 1883 `
    -u $user -P $pass -v -t 'rmutt/#' -W $ListenSeconds
}

Write-Host ''
Write-Host '==== จบการตรวจ ส่งผลทั้งหมดนี้ให้ผู้ช่วยดูได้เลย ====' -ForegroundColor Cyan
