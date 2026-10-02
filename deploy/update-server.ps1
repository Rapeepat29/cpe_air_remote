[CmdletBinding()]
param(
  # ไม่ต้องใส่ถ้าตั้ง deploy\server.config.json ไว้แล้ว
  [string]$Server = '',
  [string]$User = '',
  # ข้ามการอัปโหลด ใช้ตอนอยากรันขั้นตอนบนเซิร์ฟเวอร์ซ้ำอย่างเดียว
  [switch]$SkipUpload,
  # ข้ามการอัปโหลดเว็บแอป ใช้ตอนแก้แต่ Backend
  [switch]$SkipWeb
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$deployDirectory = $PSScriptRoot
$projectDirectory = Split-Path -Parent $deployDirectory
$backendDirectory = Join-Path $projectDirectory 'backend'
$webDirectory = Join-Path $projectDirectory 'webapp'
. (Join-Path $PSScriptRoot 'ServerConfig.ps1')
$server = Get-RmuttServer -HostOverride $Server -UserOverride $User
$target = $server.Target
$sshArgs = $server.SshArgs
$scpArgs = $server.ScpArgs

function Write-Step {
  param([string]$Text)
  Write-Host ''
  Write-Host "==> $Text" -ForegroundColor Cyan
}

Write-Host ''
Write-Host '=== อัปเดตเซิร์ฟเวอร์ RMUTT Save Energy ===' -ForegroundColor Cyan
Write-Host "ปลายทาง: $target"
Write-Host 'ถ้าถามรหัสผ่าน ให้พิมพ์รหัส SSH ของเซิร์ฟเวอร์ (แนะนำตั้ง SSH key จะได้ไม่ต้องพิมพ์)'

if (-not (Test-Path -LiteralPath $backendDirectory)) {
  throw "ไม่พบโฟลเดอร์ backend ที่ $backendDirectory"
}
if (-not (Get-Command ssh -ErrorAction SilentlyContinue)) {
  throw 'ไม่พบคำสั่ง ssh ให้เปิด OpenSSH Client ใน Windows ก่อน'
}

# ------------------------------------------------- 1. อัปโหลดซอร์ส backend
if (-not $SkipUpload) {
  Write-Step '1/3 อัปโหลดซอร์ส backend และสคริปต์อัปเดต'

  $items = @('src', 'scripts', 'database', 'package.json', 'package-lock.json', '.dockerignore') |
    ForEach-Object { Join-Path $backendDirectory $_ } |
    Where-Object { Test-Path -LiteralPath $_ }

  if ($items.Count -eq 0) { throw 'ไม่พบไฟล์ backend ที่จะอัปโหลด' }

  Write-Host ("อัปโหลด: " + (($items | Split-Path -Leaf) -join ', '))
  scp @scpArgs -r @items "${target}:/opt/rmutt/backend/"
  if ($LASTEXITCODE -ne 0) {
    Write-Host ''
    Write-Host 'ถ้าขึ้นว่าไม่มีโฟลเดอร์ ให้สร้างก่อนด้วย:' -ForegroundColor Yellow
    Write-Host "  ssh -p $($server.Port) $target 'mkdir -p /opt/rmutt/backend'"
    throw 'อัปโหลด backend ไม่สำเร็จ'
  }

  # สคริปต์ที่จะรันบนเซิร์ฟเวอร์ ส่งไปพร้อมกันจะได้ถามรหัสแค่รอบเดียว
  $remoteScript = Join-Path $deployDirectory 'update-remote.sh'
  if (-not (Test-Path -LiteralPath $remoteScript)) {
    throw "ไม่พบ $remoteScript"
  }
  scp @scpArgs $remoteScript "${target}:/opt/rmutt/update-remote.sh"
  if ($LASTEXITCODE -ne 0) { throw 'อัปโหลดสคริปต์อัปเดตไม่สำเร็จ' }

  # ไฟล์ตั้งค่าและสคริปต์ดูแลระบบอาจมีการแก้ ส่งไปด้วยทุกครั้ง
  # (ไม่ส่ง mosquitto.conf เพราะ init-env.sh ปรับ path ของ plugin ไว้บนเครื่องนั้น)
  $deployFiles = @(
    'Caddyfile', 'docker-compose.yml', 'backend.Dockerfile',
    'sync-mqtt-cert.sh', 'backup-db.sh', 'fix-mqtt-permissions.sh', 'db-view.sh'
  ) | ForEach-Object { Join-Path $deployDirectory $_ } |
    Where-Object { Test-Path -LiteralPath $_ }
  scp @scpArgs @deployFiles "${target}:/opt/rmutt/"
  if ($LASTEXITCODE -ne 0) { throw 'อัปโหลดไฟล์ตั้งค่าไม่สำเร็จ' }
} else {
  Write-Step '1/3 ข้ามการอัปโหลด backend ตามที่สั่ง'
}

# ------------------------------------------------------ 2. อัปโหลดเว็บแอป
if (-not $SkipWeb -and (Test-Path -LiteralPath $webDirectory)) {
  Write-Step '2/3 อัปโหลดเว็บแอป (โฟลเดอร์ webapp)'

  # สร้างในโฟลเดอร์ชั่วคราวแล้วค่อยสลับ เพื่อไม่ให้มีช่วงที่ไฟล์ครึ่ง ๆ กลาง ๆ
  # ถูกเสิร์ฟออกไป และเพื่อล้างไฟล์เก่าที่ถูกลบออกจากโปรเจกต์แล้ว
  ssh @sshArgs $target 'rm -rf /opt/rmutt/www.new && mkdir -p /opt/rmutt/www.new'
  if ($LASTEXITCODE -ne 0) { throw 'ต่อ SSH ไม่ได้' }

  $webItems = Get-ChildItem -LiteralPath $webDirectory -Force |
    ForEach-Object { $_.FullName }
  scp @scpArgs -r @webItems "${target}:/opt/rmutt/www.new/"
  if ($LASTEXITCODE -ne 0) { throw 'อัปโหลดเว็บแอปไม่สำเร็จ' }

  # คัดลอกไฟล์ "เข้าไปใน" www ตัวเดิม ห้ามเปลี่ยนชื่อโฟลเดอร์
  # Docker ผูก ./www เข้ากับ container ตาม inode ไม่ใช่ตามชื่อ
  # ถ้า mv สลับโฟลเดอร์ Caddy จะยังชี้ไปที่โฟลเดอร์เดิมที่ถูกลบไปแล้ว
  # แล้วเสิร์ฟ 404 ทุกหน้าโดยไม่มีข้อความบอกว่าเกิดอะไรขึ้น
  ssh @sshArgs $target 'cd /opt/rmutt && mkdir -p www && find www -mindepth 1 -delete && cp -a www.new/. www/ && rm -rf www.new && ls -la www'
  if ($LASTEXITCODE -ne 0) { throw 'สลับโฟลเดอร์เว็บไม่สำเร็จ' }
} else {
  Write-Step '2/3 ข้ามการอัปโหลดเว็บแอป'
}

# --------------------------------------- 3. สั่งให้เซิร์ฟเวอร์อัปเดตตัวเอง
Write-Step '3/3 build + migrate + ตรวจสอบบนเซิร์ฟเวอร์'
# sed ตัด CR ออก เพราะไฟล์ที่แก้บน Windows มักติด CRLF มาด้วย
# ใช้สตริงเดี่ยวล้วน กัน PowerShell ไปแปลง $ กับ \ ระหว่างทาง
$remoteCommand = 'sed -i ''s/\r$//'' /opt/rmutt/*.sh' +
  '; bash /opt/rmutt/update-remote.sh'
ssh @sshArgs $target $remoteCommand
if ($LASTEXITCODE -ne 0) {
  Write-Host ''
  Write-Host 'อัปเดตไม่สำเร็จ ดู log ด้วยคำสั่งนี้:' -ForegroundColor Red
  Write-Host "  ssh -p $($server.Port) $target 'cd /opt/rmutt && docker compose logs --tail 80 backend'"
  throw 'ขั้นตอนบนเซิร์ฟเวอร์ล้มเหลว'
}

Write-Host ''
Write-Host '===== เซิร์ฟเวอร์อัปเดตแล้ว =====' -ForegroundColor Green
Write-Host ''
Write-Host 'เปิดใช้งาน' -ForegroundColor Cyan
Write-Host "  เว็บแอป   https://$($server.Domain)/"
Write-Host "  หน้าสถานะ https://$($server.Domain)/status.html"
Write-Host "  API       https://$($server.Domain)/api/health"
Write-Host ''
Write-Host 'ขั้นถัดไป' -ForegroundColor Cyan
Write-Host '  1. .\build-apk.ps1        สร้าง APK ตัวใหม่ลงมือถือ'
Write-Host '  2. .\deploy\deploy-web.ps1  อัปโหลดเฉพาะเว็บแอป (ครั้งต่อ ๆ ไปที่แก้แต่หน้าเว็บ)'
Write-Host '  3. .\db-tunnel.ps1        เปิดอุโมงค์ดูฐานข้อมูลด้วย HeidiSQL'
Write-Host ''
