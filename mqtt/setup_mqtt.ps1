[CmdletBinding()]
param(
  [ValidatePattern('^[A-Za-z0-9_.-]{1,64}$')]
  [string]$Username = 'rmutt_air',

  [ValidateRange(1, 65535)]
  [int]$Port = 1883,

  [string]$BrokerHost = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$mqttDirectory = $PSScriptRoot
$projectDirectory = Split-Path -Parent $mqttDirectory
$configDirectory = Join-Path $mqttDirectory 'config'
$backendDirectory = Join-Path $projectDirectory 'backend'
$backendEnv = Join-Path $backendDirectory '.env'
$backendEnvExample = Join-Path $backendDirectory '.env.example'
$mqttEnv = Join-Path $mqttDirectory '.env'
$passwordFile = Join-Path $configDirectory 'passwords'
$aclFile = Join-Path $configDirectory 'acl'

function Assert-Command {
  param([Parameter(Mandatory)][string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "ไม่พบคำสั่ง $Name กรุณาติดตั้งและเปิด Docker Desktop ก่อน"
  }
}

function Get-LanIPv4 {
  $addresses = Get-NetIPConfiguration |
    Where-Object {
      $_.NetAdapter.Status -eq 'Up' -and
      $null -ne $_.IPv4DefaultGateway
    } |
    ForEach-Object { $_.IPv4Address.IPAddress } |
    Where-Object {
      $_ -and
      $_ -notlike '127.*' -and
      $_ -notlike '169.254.*'
    }
  return $addresses | Select-Object -First 1
}

function New-RandomPassword {
  $bytes = New-Object byte[] 24
  $generator = [System.Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $generator.GetBytes($bytes)
  } finally {
    $generator.Dispose()
  }
  $value = [Convert]::ToBase64String($bytes)
  $value = $value.Replace('+', 'A')
  $value = $value.Replace('/', 'B')
  return $value.TrimEnd('=')
}

function Write-Utf8File {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string[]]$Lines
  )
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllLines($Path, $Lines, $encoding)
}

function Set-DotEnvValue {
  param(
    [Parameter(Mandatory)][string]$Path,
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Value
  )
  $lines = [System.Collections.Generic.List[string]]::new()
  if (Test-Path $Path) {
    foreach ($line in Get-Content -LiteralPath $Path) {
      $lines.Add($line)
    }
  }

  $updated = $false
  for ($index = 0; $index -lt $lines.Count; $index += 1) {
    if ($lines[$index] -match ('^' + [regex]::Escape($Name) + '=')) {
      $lines[$index] = "$Name=$Value"
      $updated = $true
    }
  }
  if (-not $updated) {
    $lines.Add("$Name=$Value")
  }
  Write-Utf8File -Path $Path -Lines $lines.ToArray()
}

Assert-Command -Name 'docker'
docker info *> $null
if ($LASTEXITCODE -ne 0) {
  throw 'Docker Desktop ยังไม่ทำงาน กรุณาเปิด Docker Desktop แล้วรันใหม่'
}

if ([string]::IsNullOrWhiteSpace($BrokerHost)) {
  $BrokerHost = Get-LanIPv4
}
if ([string]::IsNullOrWhiteSpace($BrokerHost)) {
  throw 'หา LAN IPv4 ไม่พบ กรุณารันใหม่พร้อม -BrokerHost เช่น 192.168.1.10'
}
if (
  $BrokerHost -eq 'localhost' -or
  $BrokerHost -eq '0.0.0.0' -or
  $BrokerHost -like '127.*'
) {
  throw 'BrokerHost ต้องเป็น LAN IPv4 ของคอม ห้ามใช้ localhost หรือ 127.0.0.1'
}

New-Item -ItemType Directory -Force -Path $configDirectory | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $mqttDirectory 'data') |
  Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $mqttDirectory 'log') |
  Out-Null

$password = New-RandomPassword
try {
  Set-Content -LiteralPath $passwordFile -Value "$Username`:$password" `
    -Encoding ascii -NoNewline
  docker run --rm `
    --mount "type=bind,source=$configDirectory,target=/mosquitto/config" `
    eclipse-mosquitto:2.0 `
    mosquitto_passwd -U /mosquitto/config/passwords
  if ($LASTEXITCODE -ne 0) {
    throw 'สร้าง Mosquitto password file ไม่สำเร็จ'
  }
} catch {
  Remove-Item -LiteralPath $passwordFile -Force -ErrorAction SilentlyContinue
  throw
}

@(
  "user $Username"
  'topic readwrite rmutt/ac/#'
  'topic readwrite rmutt/occupancy/#'
  'topic read $SYS/#'
) | Set-Content -LiteralPath $aclFile -Encoding ascii

$mqttEnvLines = @(
  "MQTT_USERNAME=$Username"
  "MQTT_PASSWORD=$password"
)
Write-Utf8File -Path $mqttEnv -Lines $mqttEnvLines

if (-not (Test-Path $backendEnv)) {
  Copy-Item -LiteralPath $backendEnvExample -Destination $backendEnv
}
$mqttUrl = "mqtt://$BrokerHost`:$Port"
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_REQUIRED' -Value 'true'
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_URL' -Value $mqttUrl
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_USERNAME' -Value $Username
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_PASSWORD' -Value $password
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_TOPIC_PREFIX' -Value 'rmutt/ac'
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_OCCUPANCY_TOPIC_PREFIX' `
  -Value 'rmutt/occupancy'

Push-Location $mqttDirectory
try {
  docker compose --env-file .env up -d
  if ($LASTEXITCODE -ne 0) {
    throw 'เปิด Mosquitto container ไม่สำเร็จ'
  }
  & (Join-Path $mqttDirectory 'test_mqtt.ps1')
} finally {
  Pop-Location
}

Write-Host ''
Write-Host 'ตั้งค่า MQTT สำเร็จ' -ForegroundColor Green
Write-Host "Broker Host : $BrokerHost"
Write-Host "Broker Port : $Port"
Write-Host "Username    : $Username"
Write-Host 'Password ถูกสร้างและใส่ใน mqtt/.env กับ backend/.env แล้ว'
Write-Host 'ตอนคอนฟิก ESP32 ในแอป ให้ใช้ Host, Port, Username และ Password ชุดนี้'
