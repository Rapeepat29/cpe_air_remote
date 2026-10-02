[CmdletBinding()]
param(
  [string[]]$Urls = @(
    'https://letsencrypt.org/certs/isrgrootx1.pem',
    'https://letsencrypt.org/certs/isrg-root-x2.pem'
  )
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

# ดาวน์โหลดใบรับรองรากของ Let's Encrypt ทั้งสาย RSA (X1) และ ECDSA (X2)
# แล้วสร้างไฟล์ header ให้สเก็ตช์ทั้งสองบอร์ด
#
# ถ้าเซิร์ฟเวอร์ใช้ใบรับรองของผู้ออกรายอื่น ให้ส่ง -Urls เป็นใบรากของผู้ออกนั้น

$firmwareDirectory = $PSScriptRoot
$targets = @(
  (Join-Path $firmwareDirectory 'rmutt_esp32_air'),
  (Join-Path $firmwareDirectory 'rmutt_esp32_occupancy')
)

$pems = @()
foreach ($url in $Urls) {
  Write-Host "ดาวน์โหลด $url"
  $pem = (Invoke-WebRequest -Uri $url -UseBasicParsing).Content
  if ($pem -is [byte[]]) { $pem = [System.Text.Encoding]::ASCII.GetString($pem) }
  if ($pem -notmatch '-----BEGIN CERTIFICATE-----') {
    throw "ไฟล์จาก $url ไม่ใช่ใบรับรอง PEM"
  }
  $pems += ($pem -replace "`r`n", "`n").Trim()
}
$allPem = $pems -join "`n"

# ชื่อตัวแปรต้องเป็น LETSENCRYPT_CA ให้ตรงกับที่ .ino ใช้
$header = @"
// สร้างโดย firmware/update-root-ca.ps1 (ถ้าจะแก้ ให้รันสคริปต์นั้นแทนแก้มือ)
//
// ใบรับรองรากที่ใช้ตรวจตัวตนของ Broker ตอนต่อ MQTTS
// และตอนดาวน์โหลดเฟิร์มแวร์ใหม่ผ่าน Wi-Fi (OTA)
#pragma once

static const char LETSENCRYPT_CA[] PROGMEM = R"EOF(
$allPem
)EOF";
"@
$header = $header -replace "`r`n", "`n"

foreach ($target in $targets) {
  if (-not (Test-Path -LiteralPath $target)) {
    Write-Host "ข้าม $target (ไม่มีโฟลเดอร์)" -ForegroundColor Yellow
    continue
  }
  $path = Join-Path $target 'letsencrypt_ca.h'
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText($path, $header, $encoding)
  Write-Host "เขียน $path ($($pems.Count) ใบ)" -ForegroundColor Green
}

Write-Host ''
Write-Host 'เสร็จแล้ว เปิด Arduino IDE แล้วอัปโหลดใหม่ได้เลย'
