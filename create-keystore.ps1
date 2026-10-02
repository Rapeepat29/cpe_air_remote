[CmdletBinding()]
param(
  # เก็บไฟล์กุญแจไว้นอกโฟลเดอร์โปรเจกต์ จะได้ไม่เผลอส่งไปกับ zip หรือ git
  [string]$KeystorePath = (Join-Path $HOME 'rmutt-save-energy-upload.jks'),
  [string]$Alias = 'rmutt-upload'
)

# สร้างกุญแจสำหรับเซ็น APK ตัวจริง (ทำครั้งเดียวในชีวิตโปรเจกต์)
#
# APK ที่เซ็นด้วยกุญแจเดียวกันเท่านั้นที่ติดตั้งทับเวอร์ชันเก่าได้
# ถ้าใช้ debug key แล้วเปลี่ยนเครื่องที่ build ผู้ใช้ทุกคนต้องลบแอปแล้วลงใหม่
#
# สำรองไฟล์ .jks และรหัสผ่านไว้อย่างน้อยสองที่ (เช่น Drive ของภาควิชา)
# ถ้าหาย จะอัปเดตแอปที่ติดตั้งไปแล้วไม่ได้อีกเลย

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$projectDirectory = $PSScriptRoot
$propertiesPath = Join-Path $projectDirectory 'android\key.properties'

if (Test-Path -LiteralPath $propertiesPath) {
  throw "มี $propertiesPath อยู่แล้ว (ลบเองก่อนถ้าต้องการสร้างใหม่ แต่แอปเดิมจะอัปเดตทับไม่ได้)"
}

# หา keytool: จาก JAVA_HOME, PATH หรือ JDK ที่มากับ Android Studio
$keytool = $null
if ($env:JAVA_HOME -and (Test-Path (Join-Path $env:JAVA_HOME 'bin\keytool.exe'))) {
  $keytool = Join-Path $env:JAVA_HOME 'bin\keytool.exe'
}
if (-not $keytool) {
  $cmd = Get-Command keytool -ErrorAction SilentlyContinue
  if ($cmd) { $keytool = $cmd.Source }
}
if (-not $keytool) {
  $studio = Join-Path $env:ProgramFiles 'Android\Android Studio\jbr\bin\keytool.exe'
  if (Test-Path -LiteralPath $studio) { $keytool = $studio }
}
if (-not $keytool) {
  throw 'ไม่พบ keytool ติดตั้ง Android Studio หรือ JDK 17 ก่อน'
}

$secure = Read-Host 'ตั้งรหัสผ่านของกุญแจ (อย่างน้อย 8 ตัว จดเก็บไว้)' -AsSecureString
$password = [System.Net.NetworkCredential]::new('', $secure).Password
if ($password.Length -lt 8) { throw 'รหัสผ่านสั้นเกินไป' }

& $keytool -genkeypair -v `
  -keystore $KeystorePath -storetype JKS `
  -alias $Alias -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass $password -keypass $password `
  -dname 'CN=RMUTT Save Energy, OU=Computer Engineering, O=RMUTT, L=Pathum Thani, C=TH'
if ($LASTEXITCODE -ne 0) { throw 'สร้างกุญแจไม่สำเร็จ' }

# Properties ของ Java ถือ \ เป็นตัว escape จึงต้องใช้ / ในพาธ
$storeFile = $KeystorePath -replace '\\', '/'
$content = @(
  "storePassword=$password"
  "keyPassword=$password"
  "keyAlias=$Alias"
  "storeFile=$storeFile"
) -join "`n"
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($propertiesPath, $content + "`n", $encoding)

Write-Host ''
Write-Host 'สร้างกุญแจแล้ว' -ForegroundColor Green
Write-Host "  กุญแจ          : $KeystorePath"
Write-Host "  ค่าตั้งสำหรับ build : $propertiesPath"
Write-Host ''
Write-Host 'สำรองไฟล์ .jks และรหัสผ่านไว้นอกเครื่องนี้ด้วย' -ForegroundColor Yellow
Write-Host 'จากนี้ .\build-apk.ps1 จะเซ็นด้วยกุญแจนี้อัตโนมัติ'
