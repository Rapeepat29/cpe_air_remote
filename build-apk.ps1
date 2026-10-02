[CmdletBinding()]
param(
  # ไม่ใส่ = ใช้ https://<domain>/api จาก deploy\server.config.json
  [string]$ApiBaseUrl = '',
  [string]$Org = 'th.ac.rmutt.cpe',
  # สร้าง APK แบบ debug (ติดตั้งง่าย ไม่ต้องเซ็น) แทน release
  # ห้ามใช้ชื่อ Debug เพราะชนกับพารามิเตอร์สงวนของ PowerShell
  [switch]$DebugApk
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$projectDirectory = $PSScriptRoot
Set-Location $projectDirectory

if (-not $ApiBaseUrl) {
  . (Join-Path $PSScriptRoot 'deploy\ServerConfig.ps1')
  $ApiBaseUrl = (Get-RmuttServer).ApiBase
}

function Write-Step {
  param([string]$Text)
  Write-Host ''
  Write-Host "==> $Text" -ForegroundColor Cyan
}

# ------------------------------------------------- 1. สร้างโปรเจกต์ Android
Write-Step '1/4 ตรวจโฟลเดอร์ android'
if (-not (Test-Path -LiteralPath 'android')) {
  Write-Host "ยังไม่มี สร้างใหม่ด้วย org = $Org"
  flutter create --platforms=android --org $Org .
  if ($LASTEXITCODE -ne 0) { throw 'flutter create ไม่สำเร็จ' }
} else {
  Write-Host 'มีอยู่แล้ว ข้าม'
}

# --------------------------------------------------- 2. ใส่สิทธิ์ที่จำเป็น
Write-Step '2/4 ตั้งสิทธิ์ใน AndroidManifest.xml'
$manifestPath = 'android/app/src/main/AndroidManifest.xml'
if (-not (Test-Path -LiteralPath $manifestPath)) {
  throw "ไม่พบ $manifestPath"
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw
$permissions = @(
  '<uses-permission android:name="android.permission.INTERNET"/>'
  '<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation"/>'
  '<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>'
  '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" android:maxSdkVersion="30"/>'
)

$added = 0
foreach ($permission in $permissions) {
  $name = ([regex]'android:name="([^"]+)"').Match($permission).Groups[1].Value
  if ($manifest -notmatch [regex]::Escape($name)) {
    $manifest = $manifest -replace '(?=\s*<application)', "`n    $permission"
    $added += 1
  }
}

if ($added -gt 0) {
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText(
    (Join-Path $projectDirectory $manifestPath), $manifest, $encoding)
  Write-Host "เพิ่มสิทธิ์ $added รายการ" -ForegroundColor Green
} else {
  Write-Host 'สิทธิ์ครบแล้ว'
}

# --------------------------------------------------------- 3. Build APK
Write-Step "3/4 Build APK  (API = $ApiBaseUrl)"
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get ไม่สำเร็จ' }

if ($DebugApk) {
  flutter build apk --debug --dart-define=API_BASE_URL=$ApiBaseUrl
  $apk = 'build/app/outputs/flutter-apk/app-debug.apk'
} else {
  # APK ที่แจกให้ผู้ใช้ต้องเซ็นด้วย keystore ของโปรเจกต์ ไม่ใช่ debug key
  # ไม่งั้นติดตั้งทับเวอร์ชันเก่าไม่ได้เมื่อเปลี่ยนเครื่องที่ build
  if (-not (Test-Path -LiteralPath 'android/key.properties')) {
    Write-Host 'ยังไม่มี android/key.properties จะเซ็นด้วย debug key แทน' -ForegroundColor Yellow
    Write-Host '  สร้าง keystore ครั้งเดียวด้วย: .\create-keystore.ps1' -ForegroundColor Yellow
  }
  flutter build apk --release --dart-define=API_BASE_URL=$ApiBaseUrl
  $apk = 'build/app/outputs/flutter-apk/app-release.apk'
}
if ($LASTEXITCODE -ne 0) { throw 'build apk ไม่สำเร็จ' }

# ------------------------------------------------------------ 4. สรุปผล
Write-Step '4/4 เสร็จแล้ว'
$full = Join-Path $projectDirectory $apk
if (Test-Path -LiteralPath $full) {
  $size = [math]::Round((Get-Item -LiteralPath $full).Length / 1MB, 1)
  Write-Host "ไฟล์: $full" -ForegroundColor Green
  Write-Host "ขนาด: $size MB"
  Write-Host ''
  Write-Host 'ส่งไฟล์นี้เข้ามือถือแล้วกดติดตั้งได้เลย'
  Write-Host 'Android จะเตือนว่ามาจากแหล่งที่ไม่รู้จัก ให้กด "ติดตั้งอยู่ดี"'
} else {
  throw "หาไฟล์ APK ไม่เจอที่ $apk"
}
