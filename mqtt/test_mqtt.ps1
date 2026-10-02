$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$envPath = Join-Path $PSScriptRoot '.env'
if (-not (Test-Path $envPath)) {
  throw 'ไม่พบ mqtt/.env กรุณารัน .\setup_mqtt.ps1 ก่อน'
}

$values = @{}
foreach ($line in Get-Content -LiteralPath $envPath) {
  if ($line -match '^\s*([^#][^=]*)=(.*)$') {
    $values[$matches[1].Trim()] = $matches[2]
  }
}
$username = $values['MQTT_USERNAME']
$password = $values['MQTT_PASSWORD']
if ([string]::IsNullOrWhiteSpace($username) -or
    [string]::IsNullOrWhiteSpace($password)) {
  throw 'MQTT_USERNAME หรือ MQTT_PASSWORD ใน mqtt/.env ไม่ครบ'
}

$topic = "rmutt/ac/diagnostic-$PID"
$payload = '{"source":"mqtt-test","ok":true}'

Push-Location $PSScriptRoot
try {
  $deadline = (Get-Date).AddSeconds(35)
  do {
    $status = docker inspect `
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' `
      rmutt-mosquitto 2>$null
    if ($status -eq 'healthy') {
      break
    }
    Start-Sleep -Seconds 2
  } while ((Get-Date) -lt $deadline)
  if ($status -ne 'healthy') {
    docker compose --env-file .env logs --tail 60 broker
    throw "Mosquitto ยังไม่พร้อม สถานะปัจจุบัน: $status"
  }

  docker compose --env-file .env exec -T broker `
    mosquitto_pub -h 127.0.0.1 -p 1883 `
    -u $username -P $password -q 1 -r -t $topic -m $payload
  if ($LASTEXITCODE -ne 0) {
    throw 'Publish MQTT ไม่สำเร็จ'
  }

  $received = docker compose --env-file .env exec -T broker `
    mosquitto_sub -h 127.0.0.1 -p 1883 `
    -u $username -P $password -q 1 -C 1 -W 8 -t $topic
  $receivedText = ($received -join "`n").Trim()
  if ($LASTEXITCODE -ne 0 -or $receivedText -ne $payload) {
    throw 'Subscribe MQTT ไม่ได้รับข้อความทดสอบที่ถูกต้อง'
  }

  docker compose --env-file .env exec -T broker `
    mosquitto_pub -h 127.0.0.1 -p 1883 `
    -u $username -P $password -q 1 -r -n -t $topic
  if ($LASTEXITCODE -ne 0) {
    throw 'ล้าง retained diagnostic message ไม่สำเร็จ'
  }
} finally {
  Pop-Location
}

Write-Host 'MQTT publish/subscribe test ผ่าน' -ForegroundColor Green
