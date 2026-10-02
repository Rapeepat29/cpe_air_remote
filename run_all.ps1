[CmdletBinding()]
param(
  # ระบุ LAN IP เอง เช่น -BrokerHost 192.168.1.153 (ถ้าไม่ระบุจะหาให้อัตโนมัติ)
  [string]$BrokerHost = '',
  # ข้ามการเปิด Flutter (รันเฉพาะ MariaDB + MQTT + Backend)
  [switch]$SkipFlutter,
  # สร้าง/รีเซ็ตตารางในฐานข้อมูล (รันครั้งแรกครั้งเดียว)
  [switch]$InitDb,
  # ใช้เซิร์ฟเวอร์จริงบน VPS ไม่ต้องเปิดอะไรในเครื่องเลย
  [switch]$Server,
  [string]$ServerUrl = 'https://rmutt-energy.duckdns.org'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# ให้ console แสดงภาษาไทยจาก Node/Docker ได้ถูกต้อง
try {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
  Write-Host 'ตั้งค่า UTF-8 console ไม่ได้ ข้อความไทยอาจเพี้ยน' -ForegroundColor Yellow
}

$projectDirectory = $PSScriptRoot
$mqttDirectory    = Join-Path $projectDirectory 'mqtt'
$backendDirectory = Join-Path $projectDirectory 'backend'
$backendEnv       = Join-Path $backendDirectory '.env'
$mqttEnv          = Join-Path $mqttDirectory '.env'

function Write-Step {
  param([string]$Text)
  Write-Host ''
  Write-Host "==> $Text" -ForegroundColor Cyan
}

function Get-DotEnv {
  param([Parameter(Mandatory)][string]$Path)
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

function Set-DotEnvValue {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Value
  )
  $lines = [System.Collections.Generic.List[string]]::new()
  if (Test-Path -LiteralPath $Path) {
    foreach ($line in Get-Content -LiteralPath $Path) { $lines.Add($line) }
  }
  $updated = $false
  for ($i = 0; $i -lt $lines.Count; $i += 1) {
    if ($lines[$i] -match ('^' + [regex]::Escape($Name) + '=')) {
      $lines[$i] = "$Name=$Value"
      $updated = $true
    }
  }
  if (-not $updated) { $lines.Add("$Name=$Value") }
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($Path, $lines.ToArray(), $encoding)
}

function Get-LanIPv4 {
  $addresses = Get-NetIPConfiguration |
    Where-Object { $_.NetAdapter.Status -eq 'Up' -and $null -ne $_.IPv4DefaultGateway } |
    ForEach-Object { $_.IPv4Address.IPAddress } |
    Where-Object { $_ -and $_ -notlike '127.*' -and $_ -notlike '169.254.*' }
  return $addresses | Select-Object -First 1
}

# ================================================================= Server mode
# โหมดนี้ไม่แตะ Docker/MariaDB/Mosquitto/Backend ในเครื่องเลย
# แค่ตรวจว่าเซิร์ฟเวอร์จริงพร้อม แล้วเปิดแอปให้
if ($Server) {
  Write-Step "ตรวจเซิร์ฟเวอร์ $ServerUrl"
  try {
    $health = Invoke-RestMethod -Uri "$ServerUrl/api/health" -TimeoutSec 15
  } catch {
    Write-Host "เรียก $ServerUrl/api/health ไม่ได้: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host 'ตรวจบน VPS ด้วย: docker compose ps' -ForegroundColor Yellow
    exit 1
  }

  Write-Host "status        : $($health.status)" -ForegroundColor Green
  Write-Host "mqtt.connected: $($health.mqtt.connected)"
  Write-Host "mqtt.broker   : $($health.mqtt.broker)"
  if ($health.mqtt.connected -ne $true) {
    Write-Host 'Backend บนเซิร์ฟเวอร์ยังไม่เชื่อม Broker' -ForegroundColor Red
    Write-Host 'ตรวจบน VPS: docker compose logs mqtt | tail -20' -ForegroundColor Yellow
    exit 1
  }

  if ($SkipFlutter) {
    Write-Host ''
    Write-Host 'เซิร์ฟเวอร์พร้อมใช้งาน (ข้าม Flutter ตามที่สั่ง)' -ForegroundColor Green
    exit 0
  }

  Write-Step 'เปิดแอปที่ชี้เซิร์ฟเวอร์จริง'
  Push-Location $projectDirectory
  try {
    flutter run -d windows --dart-define=API_BASE_URL="$ServerUrl/api"
  } finally {
    Pop-Location
  }
  exit 0
}

# ---------------------------------------------------------------- 1. Docker
Write-Step '1/6 ตรวจ Docker Desktop'
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw 'ไม่พบคำสั่ง docker กรุณาติดตั้ง/เปิด Docker Desktop ก่อน'
}
docker info *> $null
if ($LASTEXITCODE -ne 0) {
  throw 'Docker Desktop ยังไม่ทำงาน กรุณาเปิด Docker Desktop แล้วรันสคริปต์ใหม่'
}
Write-Host 'Docker พร้อมใช้งาน' -ForegroundColor Green

# --------------------------------------------------------------- 2. MariaDB
Write-Step '2/6 เปิด MariaDB container'
$mariaName = (docker ps -a --filter 'name=mariadb' --format '{{.Names}}' |
  Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($mariaName)) {
  Write-Host 'ไม่พบ container ชื่อที่มีคำว่า mariadb' -ForegroundColor Yellow
  Write-Host 'ถ้าใช้ MariaDB ที่ติดตั้งบน Windows โดยตรง ข้ามขั้นตอนนี้ได้'
} else {
  $mariaState = docker inspect --format '{{.State.Status}}' $mariaName
  if ($mariaState -ne 'running') {
    docker start $mariaName | Out-Null
    Write-Host "สั่งเปิด $mariaName แล้ว"
  } else {
    Write-Host "$mariaName ทำงานอยู่แล้ว"
  }
}

$backendValues = Get-DotEnv -Path $backendEnv
$dbPort = if ($backendValues.ContainsKey('DB_PORT')) { [int]$backendValues['DB_PORT'] } else { 3306 }
$deadline = (Get-Date).AddSeconds(60)
$dbReady = $false
do {
  $dbReady = (Test-NetConnection -ComputerName '127.0.0.1' -Port $dbPort `
    -InformationLevel Quiet -WarningAction SilentlyContinue)
  if ($dbReady) { break }
  Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)
if (-not $dbReady) { throw "ต่อพอร์ต $dbPort ของ MariaDB ไม่ได้" }
Write-Host "MariaDB พร้อมที่ 127.0.0.1:$dbPort" -ForegroundColor Green

# ------------------------------------------------ 3. ซ่อมโครงสร้างฐานข้อมูล
Write-Step '3/7 ตรวจและซ่อมโครงสร้างฐานข้อมูล'
Push-Location $backendDirectory
try {
  if (-not (Test-Path 'node_modules')) {
    Write-Host 'ติดตั้ง dependencies (npm ci)...'
    npm ci
    if ($LASTEXITCODE -ne 0) { throw 'npm ci ไม่สำเร็จ' }
  }
  if ($InitDb) {
    Write-Host 'สร้างตารางใหม่ทั้งหมด (npm run db:init)...'
    npm run db:init
    if ($LASTEXITCODE -ne 0) { throw 'db:init ไม่สำเร็จ' }
  }
  npm run db:migrate:pzem
  if ($LASTEXITCODE -ne 0) { throw 'migrate:pzem ไม่สำเร็จ' }
  npm run db:migrate:occupancy
  if ($LASTEXITCODE -ne 0) { throw 'migrate:occupancy ไม่สำเร็จ' }
  npm run db:migrate:energy
  if ($LASTEXITCODE -ne 0) { throw 'migrate:energy ไม่สำเร็จ' }
  npm run db:migrate:autooff
  if ($LASTEXITCODE -ne 0) { throw 'migrate:autooff ไม่สำเร็จ' }
  npm run db:migrate:settings
  if ($LASTEXITCODE -ne 0) { throw 'migrate:settings ไม่สำเร็จ' }
  node scripts/doctor.js --fix
  if ($LASTEXITCODE -ne 0) { throw 'doctor ไม่สำเร็จ' }
} finally {
  Pop-Location
}

# ------------------------------------------------------------- 4. LAN IP / env
Write-Step '4/7 ตั้งค่า MQTT ใน backend/.env ให้ตรงกับ LAN IP ปัจจุบัน'
if ([string]::IsNullOrWhiteSpace($BrokerHost)) { $BrokerHost = Get-LanIPv4 }
if ([string]::IsNullOrWhiteSpace($BrokerHost)) {
  throw 'หา LAN IPv4 ไม่พบ กรุณารันใหม่พร้อม -BrokerHost เช่น 192.168.1.10'
}
if ($BrokerHost -like '127.*' -or $BrokerHost -eq 'localhost') {
  throw 'BrokerHost ต้องเป็น LAN IPv4 ของคอม ห้ามใช้ 127.0.0.1'
}

$mqttValues = Get-DotEnv -Path $mqttEnv
if (-not $mqttValues.ContainsKey('MQTT_USERNAME') -or
    -not $mqttValues.ContainsKey('MQTT_PASSWORD')) {
  throw 'mqtt/.env ไม่มี MQTT_USERNAME/MQTT_PASSWORD กรุณารัน mqtt\setup_mqtt.ps1 ก่อน'
}

$oldUrl = if ($backendValues.ContainsKey('MQTT_URL')) { $backendValues['MQTT_URL'] } else { '' }
$newUrl = "mqtt://$BrokerHost`:1883"
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_REQUIRED' -Value 'true'
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_URL' -Value $newUrl
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_USERNAME' -Value $mqttValues['MQTT_USERNAME']
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_PASSWORD' -Value $mqttValues['MQTT_PASSWORD']
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_TOPIC_PREFIX' -Value 'rmutt/ac'
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_OCCUPANCY_TOPIC_PREFIX' -Value 'rmutt/occupancy'
Write-Host "MQTT_URL : $newUrl" -ForegroundColor Green
if ($oldUrl -and $oldUrl -ne $newUrl) {
  Write-Host "ค่าเดิมคือ $oldUrl - IP เปลี่ยนแล้ว ต้อง provision ESP32 ผ่าน Bluetooth ใหม่" -ForegroundColor Yellow
}

# -------------------------------------------------------------- 4. Mosquitto
Write-Step '5/7 เปิด Mosquitto broker'

# ACL ต้องครอบคลุม topic ของทั้งแอร์และเซ็นเซอร์ตรวจจับคน ถ้าไฟล์ถูกสร้างไว้
# ตั้งแต่ก่อนมีฟีเจอร์เซ็นเซอร์ Broker จะปฏิเสธทั้งการ publish ของ ESP32
# และการ subscribe ของ Backend แบบเงียบ ๆ
$aclPath = Join-Path $mqttDirectory 'config/acl'
$requiredAcl = @(
  "user $($mqttValues['MQTT_USERNAME'])"
  'topic readwrite rmutt/ac/#'
  'topic readwrite rmutt/occupancy/#'
  'topic read $SYS/#'
)
$currentAcl = @()
if (Test-Path -LiteralPath $aclPath) {
  $currentAcl = @(Get-Content -LiteralPath $aclPath |
    ForEach-Object { $_.Trim() })
}
$missingAcl = @($requiredAcl | Where-Object { $currentAcl -notcontains $_ })
$aclRepaired = $false
if ($missingAcl.Count -gt 0) {
  Write-Host "ACL ขาดสิทธิ์: $($missingAcl -join ' | ')" -ForegroundColor Yellow
  Set-Content -LiteralPath $aclPath -Value $requiredAcl -Encoding ascii
  $aclRepaired = $true
  Write-Host 'เขียน mqtt/config/acl ใหม่แล้ว' -ForegroundColor Green
} else {
  Write-Host 'ACL ครอบคลุม rmutt/ac/# และ rmutt/occupancy/# แล้ว' -ForegroundColor Green
}

Push-Location $mqttDirectory
try {
  docker compose --env-file .env up -d
  if ($LASTEXITCODE -ne 0) { throw 'เปิด Mosquitto ไม่สำเร็จ' }

  if ($aclRepaired) {
    Write-Host 'รีสตาร์ต Broker เพื่อโหลด ACL ใหม่'
    docker compose --env-file .env restart broker | Out-Null
  }

  $deadline = (Get-Date).AddSeconds(60)
  do {
    $status = docker inspect `
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' `
      rmutt-mosquitto 2>$null
    if ($status -eq 'healthy') { break }
    Start-Sleep -Seconds 3
  } while ((Get-Date) -lt $deadline)
  if ($status -ne 'healthy') {
    docker compose --env-file .env logs --tail 40 broker
    throw "Mosquitto ยังไม่พร้อม สถานะ: $status"
  }
} finally {
  Pop-Location
}
Write-Host 'Mosquitto healthy' -ForegroundColor Green

# ---------------------------------------------------------------- 5. Backend
Write-Step '6/7 เปิด Backend API'
# ปิดตัวเก่าที่ยังค้างพอร์ต 3000 เพื่อให้โหลด .env ใหม่แน่นอน
$listeners = @(Get-NetTCPConnection -LocalPort 3000 -State Listen `
  -ErrorAction SilentlyContinue)
foreach ($listener in $listeners) {
  try {
    $owner = Get-Process -Id $listener.OwningProcess -ErrorAction Stop
    Write-Host "ปิด Backend ตัวเดิม (PID $($owner.Id)) เพื่อโหลดค่าใหม่"
    Stop-Process -Id $owner.Id -Force
  } catch {
    Write-Host 'ปิดโปรเซสเดิมไม่ได้ กรุณาปิดหน้าต่าง Backend เดิมเอง' -ForegroundColor Yellow
  }
}
if ($listeners.Count -gt 0) { Start-Sleep -Seconds 2 }

Start-Process -FilePath 'powershell.exe' -WorkingDirectory $backendDirectory `
  -ArgumentList '-NoExit', '-Command',
    '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; npm start'
Write-Host 'เปิด Backend ในหน้าต่าง PowerShell ใหม่แล้ว (OTP จะโชว์ในหน้าต่างนั้น)'

Write-Step '7/7 ตรวจระบบ'
$deadline = (Get-Date).AddSeconds(60)
$health = $null
do {
  try {
    $health = Invoke-RestMethod -Uri 'http://127.0.0.1:3000/api/health' -TimeoutSec 5
    if ($health.status -eq 'ok' -and $health.mqtt.connected -eq $true) { break }
  } catch { $health = $null }
  Start-Sleep -Seconds 3
} while ((Get-Date) -lt $deadline)

if ($null -eq $health) { throw 'Backend ไม่ตอบที่ http://127.0.0.1:3000/api/health' }
if ($health.mqtt.connected -ne $true) {
  throw "Backend ยังไม่เชื่อม MQTT: $($health.mqtt.lastError)"
}

Write-Host ''
Write-Host 'ระบบหลักพร้อม: MariaDB + Backend + MQTT' -ForegroundColor Green
Write-Host "Broker : $($health.mqtt.broker)"
Write-Host "Topic  : $($health.mqtt.topicPrefix)/<deviceId>/..."
Write-Host "API    : http://127.0.0.1:3000/api"

if (-not $SkipFlutter) {
  Write-Step 'เปิดแอป Flutter บน Windows'
  Push-Location $projectDirectory
  try {
    flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
  } finally {
    Pop-Location
  }
} else {
  Write-Host ''
  Write-Host 'ข้าม Flutter ตามที่สั่ง (-SkipFlutter)' -ForegroundColor Yellow
  Write-Host 'สั่งเองได้ด้วย: flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api'
}
