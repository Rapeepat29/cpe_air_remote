[CmdletBinding()]
param(
  # ไม่ต้องใส่ถ้าตั้ง deploy\server.config.json ไว้แล้ว
  [string]$Server = '',
  [string]$User = ''
)

# อัปโหลดเฉพาะเว็บแอป (โฟลเดอร์ webapp\) ขึ้นเซิร์ฟเวอร์
#
# ใช้ตอนแก้หน้าตาหรือ JavaScript ของเว็บอย่างเดียว ไม่ได้แตะ Backend
# เร็วกว่า update-server.ps1 มาก เพราะไม่ต้อง build ใหม่และไม่ต้องรีสตาร์ท
# Caddy อ่านไฟล์จากดิสก์ทุกครั้งที่มีคนขอ ไฟล์ใหม่จึงมีผลทันที

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$deployDirectory = $PSScriptRoot
$projectDirectory = Split-Path -Parent $deployDirectory
$webDirectory = Join-Path $projectDirectory 'webapp'
. (Join-Path $PSScriptRoot 'ServerConfig.ps1')
$srv = Get-RmuttServer -HostOverride $Server -UserOverride $User
$target = $srv.Target
$sshArgs = $srv.SshArgs
$scpArgs = $srv.ScpArgs

if (-not (Test-Path -LiteralPath $webDirectory)) {
  throw "ไม่พบโฟลเดอร์เว็บแอปที่ $webDirectory"
}

Write-Host ''
Write-Host '=== อัปโหลดเว็บแอป RMUTT Save Energy ===' -ForegroundColor Cyan
Write-Host "ปลายทาง: ${target}:/opt/rmutt/www"

# ลบของเก่าก่อน เพราะไฟล์ที่ถูกลบออกจากโปรเจกต์แล้วจะยังค้างบนเซิร์ฟเวอร์
# ถ้า scp ทับอย่างเดียว แล้ว JavaScript เก่าที่ยังอยู่อาจถูกเรียกโดยหน้าเดิม
# ที่ผู้ใช้เปิดค้างไว้ ทำให้เจอพฤติกรรมแปลก ๆ ที่ตามหาต้นเหตุยากมาก
ssh @sshArgs $target 'rm -rf /opt/rmutt/www.new && mkdir -p /opt/rmutt/www.new'
if ($LASTEXITCODE -ne 0) { throw 'ต่อ SSH ไม่ได้' }

$items = Get-ChildItem -LiteralPath $webDirectory -Force |
  ForEach-Object { $_.FullName }
scp @scpArgs -r @items "${target}:/opt/rmutt/www.new/"
if ($LASTEXITCODE -ne 0) { throw 'อัปโหลดเว็บแอปไม่สำเร็จ' }

# สลับโฟลเดอร์ทีเดียว ผู้ใช้ที่กำลังเปิดอยู่จะไม่เจอสภาพครึ่ง ๆ กลาง ๆ
# คัดลอกไฟล์ "เข้าไปใน" www ตัวเดิม ห้ามเปลี่ยนชื่อโฟลเดอร์
# Docker ผูก ./www เข้ากับ container ตาม inode ไม่ใช่ตามชื่อ
# ถ้า mv สลับโฟลเดอร์ Caddy จะยังชี้ไปที่โฟลเดอร์เดิมที่ถูกลบไปแล้ว
# แล้วเสิร์ฟ 404 ทุกหน้าโดยไม่มีข้อความบอกว่าเกิดอะไรขึ้น
ssh @sshArgs $target 'cd /opt/rmutt && mkdir -p www && find www -mindepth 1 -delete && cp -a www.new/. www/ && rm -rf www.new && ls -la www'
if ($LASTEXITCODE -ne 0) { throw 'สลับโฟลเดอร์เว็บไม่สำเร็จ' }

Write-Host ''
Write-Host 'อัปโหลดเสร็จแล้ว' -ForegroundColor Green
Write-Host "เปิดดูได้ที่ https://$($srv.Domain)/"
Write-Host 'ถ้ายังเห็นของเก่า ให้กด Ctrl+F5 หนึ่งครั้ง'
