$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Push-Location $PSScriptRoot
try {
  if (-not (Test-Path '.env')) {
    throw 'ไม่พบ mqtt/.env'
  }
  docker compose --env-file .env down
} finally {
  Pop-Location
}
