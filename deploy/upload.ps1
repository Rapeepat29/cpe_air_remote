[CmdletBinding()]
param(
  # ไม่ต้องใส่ถ้าตั้ง deploy\server.config.json ไว้แล้ว
  [string]$Server = '',
  [string]$User = '',
  # อัปโหลดเฉพาะซอร์ส backend (ใช้ตอนแก้โค้ดแล้วอยากอัปเดตเซิร์ฟเวอร์)
  [switch]$BackendOnly
)

$ErrorActionPreference = 'Stop'

try {
  [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

$projectDirectory = Split-Path -Parent $PSScriptRoot
$deployDirectory = $PSScriptRoot
$backendDirectory = Join-Path $projectDirectory 'backend'
$webDirectory = Join-Path $projectDirectory 'webapp'
. (Join-Path $PSScriptRoot 'ServerConfig.ps1')
$srv = Get-RmuttServer -HostOverride $Server -UserOverride $User
$target = $srv.Target
$sshArgs = $srv.SshArgs
$scpArgs = $srv.ScpArgs

function Write-Step {
  param([string]$Text)
  Write-Host ''
  Write-Host "==> $Text" -ForegroundColor Cyan
}

if (-not (Test-Path -LiteralPath $backendDirectory)) {
  throw "ไม่พบโฟลเดอร์ backend ที่ $backendDirectory"
}

Write-Step "สร้างโฟลเดอร์ปลายทางบน $($srv.Host)"
ssh @sshArgs $target 'mkdir -p /opt/rmutt/backend /opt/rmutt/www'
if ($LASTEXITCODE -ne 0) { throw 'ต่อ SSH ไม่ได้' }

if (-not $BackendOnly) {
  Write-Step 'อัปโหลดชุด deploy'
  # ไม่ส่ง upload.ps1 (สคริปต์ตัวนี้เอง) และไม่ส่ง www/ ของเดิม
  # เพราะเว็บแอปตัวจริงอยู่ที่โฟลเดอร์ webapp\ ระดับโปรเจกต์แล้ว
  $items = Get-ChildItem -LiteralPath $deployDirectory -Force |
    # ไม่ส่งไฟล์ที่ใช้บน Windows อย่างเดียว ไฟล์ความลับ และไฟล์ชั่วคราว
    Where-Object {
      $_.Name -ne 'www' -and
      $_.Extension -ne '.ps1' -and $_.Extension -ne '.tmp' -and
      $_.Name -notlike '.env*' -and $_.Name -notlike 'server.config*'
    } |
    ForEach-Object { $_.FullName }
  scp @scpArgs -r @items "${target}:/opt/rmutt/"
  if ($LASTEXITCODE -ne 0) { throw 'อัปโหลดชุด deploy ไม่สำเร็จ' }

  if (Test-Path -LiteralPath $webDirectory) {
    Write-Step 'อัปโหลดเว็บแอป'
    $webItems = Get-ChildItem -LiteralPath $webDirectory -Force |
      ForEach-Object { $_.FullName }
    scp @scpArgs -r @webItems "${target}:/opt/rmutt/www/"
    if ($LASTEXITCODE -ne 0) { throw 'อัปโหลดเว็บแอปไม่สำเร็จ' }
  }
}

Write-Step 'อัปโหลดซอร์ส backend'
$backendItems = @('src', 'scripts', 'database', 'package.json', 'package-lock.json', '.dockerignore') |
  ForEach-Object { Join-Path $backendDirectory $_ } |
  Where-Object { Test-Path -LiteralPath $_ }
scp @scpArgs -r @backendItems "${target}:/opt/rmutt/backend/"
if ($LASTEXITCODE -ne 0) { throw 'อัปโหลด backend ไม่สำเร็จ' }

Write-Step 'จัดไฟล์บนเซิร์ฟเวอร์'
ssh @sshArgs $target 'cd /opt/rmutt && cp -f backend.Dockerfile backend/Dockerfile && chmod +x *.sh && ls backend && ls www | head'

Write-Host ''
Write-Host 'อัปโหลดเสร็จแล้ว' -ForegroundColor Green
if ($BackendOnly) {
  Write-Host "สั่ง build ใหม่ด้วย: ssh -p $($srv.Port) $target 'cd /opt/rmutt && docker compose up -d --build backend'"
} else {
  Write-Host "ขั้นถัดไปบนเซิร์ฟเวอร์: cd /opt/rmutt && sudo bash init-env.sh"
}
