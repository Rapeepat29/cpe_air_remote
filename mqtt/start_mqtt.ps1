$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Push-Location $PSScriptRoot
try {
  if (-not (Test-Path '.env') -or -not (Test-Path 'config/passwords')) {
    throw 'ยังไม่ได้ตั้งค่า MQTT กรุณารัน .\setup_mqtt.ps1 ก่อน'
  }
  docker compose --env-file .env up -d
  if ($LASTEXITCODE -ne 0) {
    throw 'เปิด Mosquitto ไม่สำเร็จ'
  }
  docker compose --env-file .env ps
} finally {
  Pop-Location
}
