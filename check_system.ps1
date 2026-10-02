$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$projectDirectory = $PSScriptRoot
$mqttDirectory = Join-Path $projectDirectory 'mqtt'

Write-Host '1/3 ตรวจ Mosquitto container'
Push-Location $mqttDirectory
try {
  if (-not (Test-Path '.env')) {
    throw 'ยังไม่มี mqtt/.env กรุณารัน mqtt/setup_mqtt.ps1 ก่อน'
  }
  $brokerHealth = docker inspect `
    --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' `
    rmutt-mosquitto 2>$null
  if ($brokerHealth -ne 'healthy') {
    throw "Mosquitto ยังไม่พร้อม: $brokerHealth"
  }
  & (Join-Path $mqttDirectory 'test_mqtt.ps1')
} finally {
  Pop-Location
}

Write-Host '2/3 ตรวจ Backend API'
$health = Invoke-RestMethod -Uri 'http://127.0.0.1:3000/api/health' `
  -Method Get -TimeoutSec 10
if ($health.status -ne 'ok') {
  throw 'Backend health check ไม่ผ่าน'
}

Write-Host '3/3 ตรวจ Backend -> MQTT'
if ($health.mqtt.connected -ne $true) {
  $mqttError = $health.mqtt.lastError
  throw "Backend ยังไม่เชื่อม MQTT: $mqttError"
}

Write-Host ''
Write-Host 'ระบบหลักพร้อม: MariaDB + Backend + MQTT' -ForegroundColor Green
Write-Host "Broker: $($health.mqtt.broker)"
Write-Host "Topic : $($health.mqtt.topicPrefix)/<deviceId>/..."
