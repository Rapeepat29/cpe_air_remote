[CmdletBinding()]
param(
  # ไม่ต้องใส่ถ้าตั้ง deploy\server.config.json ไว้แล้ว
  [string]$Server = '',
  [string]$User = '',
  [int]$LocalPort = 3307
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

. (Join-Path $PSScriptRoot 'deploy\ServerConfig.ps1')
$srv = Get-RmuttServer -HostOverride $Server -UserOverride $User
$target = $srv.Target

Write-Host ''
Write-Host '=== เปิดอุโมงค์ไปฐานข้อมูลบนเซิร์ฟเวอร์ ===' -ForegroundColor Cyan

# ---------------------------------------------- 1. ดึงรหัสผ่านฐานข้อมูล
Write-Host ''
Write-Host "1/3 ดึงรหัสผ่านฐานข้อมูลจาก $($srv.Host)"
Write-Host '    (ถ้าถามรหัส SSH ให้พิมพ์รหัสของบัญชีบนเซิร์ฟเวอร์)'
Write-Host '    ใช้ user ของแอป (สิทธิ์เฉพาะฐานข้อมูลนี้) ไม่ใช้ root'

# PowerShell ใช้ backtick เป็นตัว escape ไม่ใช่ backslash
# จึงห้ามมีเครื่องหมายคำพูดคู่ในคำสั่งนี้ เลยใช้สตริงเดี่ยวล้วน
$remoteCommand = 'grep -E ''^DB_PASSWORD='' /opt/rmutt/.env | cut -d= -f2-'
$dbPassword = ssh -p $srv.Port $target $remoteCommand
$dbUser = ssh -p $srv.Port $target 'grep -E ''^DB_USER='' /opt/rmutt/.env | cut -d= -f2-'
if ($dbUser) { $dbUser = ([string]$dbUser).Trim().Trim([char]34) }
# .env รุ่นเก่าไม่มี DB_USER และใช้ root
if ([string]::IsNullOrWhiteSpace($dbUser)) { $dbUser = 'root' }
# [char]34 คือเครื่องหมายคำพูดคู่ เขียนแบบนี้เพื่อเลี่ยงปัญหา quote ซ้อน
if ($dbPassword) {
  $dbPassword = ([string]$dbPassword).Trim().Trim([char]34)
}

if ([string]::IsNullOrWhiteSpace($dbPassword)) {
  throw 'อ่านรหัสผ่านไม่ได้ ตรวจว่า /opt/rmutt/.env มีอยู่จริง'
}

Set-Clipboard -Value $dbPassword
Write-Host '    ก๊อปรหัสใส่คลิปบอร์ดแล้ว (กด Ctrl+V ในช่อง Password ได้เลย)' -ForegroundColor Green

# ------------------------------------------------------ 2. เปิดอุโมงค์
Write-Host ''
Write-Host "2/3 เปิดอุโมงค์ 127.0.0.1:$LocalPort  ->  เซิร์ฟเวอร์ 127.0.0.1:3306"

$existing = Get-NetTCPConnection -LocalPort $LocalPort -State Listen -ErrorAction SilentlyContinue
if ($existing) {
  Write-Host "    พอร์ต $LocalPort มีอุโมงค์เปิดอยู่แล้ว ใช้ตัวเดิมได้เลย" -ForegroundColor Yellow
} else {
  Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoExit'
    '-Command'
    "Write-Host 'อุโมงค์ฐานข้อมูล - ห้ามปิดหน้าต่างนี้ระหว่างใช้งาน HeidiSQL' -ForegroundColor Yellow; " +
    "ssh -N -p $($srv.Port) -L ${LocalPort}:127.0.0.1:3306 $target"
  )
  Write-Host '    เปิดหน้าต่างใหม่แล้ว ถ้าถามรหัสให้พิมพ์ในหน้าต่างนั้น'
  Start-Sleep -Seconds 8
}

# -------------------------------------------------------- 3. ทดสอบ
Write-Host ''
Write-Host '3/3 ทดสอบอุโมงค์'

$ok = $false
foreach ($attempt in 1..6) {
  $ok = Test-NetConnection -ComputerName '127.0.0.1' -Port $LocalPort `
    -InformationLevel Quiet -WarningAction SilentlyContinue
  if ($ok) { break }
  Start-Sleep -Seconds 3
}

Write-Host ''
if ($ok) {
  Write-Host '===== อุโมงค์พร้อมใช้งาน =====' -ForegroundColor Green
} else {
  Write-Host '===== ยังต่อไม่ได้ =====' -ForegroundColor Red
  Write-Host 'ดูหน้าต่างอุโมงค์ที่เพิ่งเปิด ว่ามันถามรหัสผ่านค้างอยู่หรือเปล่า'
  Write-Host 'ถ้ายังไม่ได้ ตรวจบนเซิร์ฟเวอร์ว่า: docker compose ps db'
  Write-Host 'ต้องเห็น 127.0.0.1:3306->3306/tcp'
}

Write-Host ''
Write-Host 'กรอกใน HeidiSQL แบบนี้ (แท็บ Settings)' -ForegroundColor Cyan
Write-Host '  Network type   : MariaDB or MySQL (TCP/IP)'
Write-Host '  Hostname / IP  : 127.0.0.1'
Write-Host "  Port           : $LocalPort"
Write-Host "  User           : $dbUser"
Write-Host '  Password       : กด Ctrl+V (อยู่ในคลิปบอร์ดแล้ว)'
Write-Host '  Databases      : rmutt_save_energy'
Write-Host ''
Write-Host 'แท็บ SSH tunnel : เอาติ๊กออกให้หมด (ห้ามใช้ tunnel ของ HeidiSQL)' -ForegroundColor Yellow
Write-Host ''
