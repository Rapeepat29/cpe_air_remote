[CmdletBinding()]
param()

# เปลี่ยนรหัสผ่านของกุญแจเซ็น APK (ไฟล์ .jks) โดยใช้กุญแจตัวเดิม
#
# กุญแจไม่เปลี่ยน เปลี่ยนแค่รหัสที่ล็อกไฟล์ไว้ แอปที่ติดตั้งไปแล้วจึงยังอัปเดตทับได้ตามปกติ
# ใช้เมื่อรหัสเดิมเดาง่าย (เช่น 12345678) เพราะถ้าไฟล์ .jks หลุดออกไป
# รหัสคือสิ่งเดียวที่กันไม่ให้คนอื่นเซ็นแอปปลอมเป็นอัปเดตของเรา
#
# สคริปต์สำรองไฟล์ .jks เดิมไว้ข้าง ๆ ก่อนแก้ทุกครั้ง

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$propertiesPath = Join-Path $PSScriptRoot 'android\key.properties'
if (-not (Test-Path -LiteralPath $propertiesPath)) {
  throw "ไม่พบ $propertiesPath (ยังไม่เคยสร้างกุญแจ ให้รัน .\create-keystore.ps1)"
}

$properties = @{}
foreach ($line in Get-Content -LiteralPath $propertiesPath -Encoding UTF8) {
  if ($line -match '^\s*([^#=]+?)\s*=\s*(.*)$') {
    $properties[$Matches[1]] = $Matches[2]
  }
}
$oldPassword = $properties['storePassword']
$oldKeyPassword = $properties['keyPassword']
$alias = $properties['keyAlias']
$keystorePath = $properties['storeFile']
if (-not $oldPassword -or -not $alias -or -not $keystorePath) {
  throw 'key.properties ไม่ครบ (ต้องมี storePassword, keyAlias, storeFile)'
}
if (-not $oldKeyPassword) { $oldKeyPassword = $oldPassword }
if (-not (Test-Path -LiteralPath $keystorePath)) {
  throw "ไม่พบไฟล์กุญแจ $keystorePath"
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

$first = Read-Host 'รหัสผ่านใหม่ (อย่างน้อย 12 ตัว ผสมตัวอักษรและตัวเลข)' -AsSecureString
$second = Read-Host 'พิมพ์รหัสผ่านใหม่อีกครั้ง' -AsSecureString
$newPassword = [System.Net.NetworkCredential]::new('', $first).Password
$confirm = [System.Net.NetworkCredential]::new('', $second).Password
if ($newPassword -ne $confirm) { throw 'รหัสผ่านสองช่องไม่ตรงกัน' }
if ($newPassword.Length -lt 12) { throw 'รหัสผ่านสั้นเกินไป (อย่างน้อย 12 ตัว)' }
if ($newPassword -match '^\d+$') { throw 'อย่าใช้ตัวเลขล้วน' }

$backup = "$keystorePath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -LiteralPath $keystorePath -Destination $backup
Write-Host "สำรองกุญแจเดิมไว้ที่ $backup"

# เปลี่ยนรหัสของกุญแจก่อน แล้วค่อยเปลี่ยนรหัสของไฟล์
& $keytool -keypasswd -keystore $keystorePath -alias $alias `
  -storepass $oldPassword -keypass $oldKeyPassword -new $newPassword
if ($LASTEXITCODE -ne 0) {
  throw "เปลี่ยนรหัสของกุญแจไม่สำเร็จ ไฟล์เดิมยังใช้ได้ (สำรองอยู่ที่ $backup)"
}
& $keytool -storepasswd -keystore $keystorePath `
  -storepass $oldPassword -new $newPassword
if ($LASTEXITCODE -ne 0) {
  Copy-Item -LiteralPath $backup -Destination $keystorePath -Force
  throw 'เปลี่ยนรหัสของไฟล์ไม่สำเร็จ คืนไฟล์กุญแจเดิมให้แล้ว'
}

# ตรวจว่ารหัสใหม่เปิดไฟล์ได้จริงก่อนเขียน key.properties
& $keytool -list -keystore $keystorePath -alias $alias -storepass $newPassword | Out-Null
if ($LASTEXITCODE -ne 0) {
  Copy-Item -LiteralPath $backup -Destination $keystorePath -Force
  throw 'ตรวจรหัสใหม่ไม่ผ่าน คืนไฟล์กุญแจเดิมให้แล้ว'
}

$content = @(
  "storePassword=$newPassword"
  "keyPassword=$newPassword"
  "keyAlias=$alias"
  "storeFile=$keystorePath"
) -join "`n"
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($propertiesPath, $content + "`n", $encoding)

Write-Host ''
Write-Host 'เปลี่ยนรหัสกุญแจเซ็น APK แล้ว' -ForegroundColor Green
Write-Host "  กุญแจ (ตัวเดิม)    : $keystorePath"
Write-Host "  ไฟล์สำรองรหัสเก่า : $backup"
Write-Host ''
Write-Host 'จดรหัสใหม่เก็บไว้ที่ปลอดภัย แล้วทดสอบด้วย .\build-apk.ps1' -ForegroundColor Yellow
Write-Host 'เมื่อ build ผ่านแล้ว ให้ลบไฟล์สำรอง (.bak-...) ทิ้ง เพราะไฟล์นั้นยังเปิดได้ด้วยรหัสเก่า'
