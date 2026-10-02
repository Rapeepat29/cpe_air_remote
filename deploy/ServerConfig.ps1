# อ่านค่าเซิร์ฟเวอร์จาก deploy\server.config.json
#
# ใช้ร่วมกันทุกสคริปต์ที่ต่อเซิร์ฟเวอร์ (update-server, deploy-web, upload,
# db-tunnel, build-apk) ที่อยู่เซิร์ฟเวอร์จึงไม่ต้องเขียนตายไว้ในโค้ด
# และไฟล์ server.config.json ไม่ถูก commit ขึ้น git
#
# ใช้งาน:  . (Join-Path $PSScriptRoot 'ServerConfig.ps1')
#          $server = Get-RmuttServer -HostOverride $Server -UserOverride $User

function Get-RmuttServer {
  param(
    [string]$HostOverride = '',
    [string]$UserOverride = '',
    [int]$PortOverride = 0
  )

  $configPath = Join-Path $PSScriptRoot 'server.config.json'
  $config = $null
  if (Test-Path -LiteralPath $configPath) {
    $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 |
      ConvertFrom-Json
  }

  $hostName = if ($HostOverride) { $HostOverride } elseif ($config.host) { [string]$config.host } else { '' }
  if (-not $hostName) {
    $example = Join-Path $PSScriptRoot 'server.config.example.json'
    throw ("ยังไม่ได้ตั้งค่าเซิร์ฟเวอร์: คัดลอก $example เป็น server.config.json " +
      'แล้วแก้ host/user/domain หรือระบุ -Server ตอนเรียกสคริปต์')
  }

  $user = if ($UserOverride) { $UserOverride } elseif ($config.user) { [string]$config.user } else { 'root' }
  $port = if ($PortOverride -gt 0) { $PortOverride } elseif ($config.port) { [int]$config.port } else { 22 }
  $domain = if ($config.domain) { [string]$config.domain } else { $hostName }

  [pscustomobject]@{
    Host      = $hostName
    User      = $user
    Port      = $port
    Domain    = $domain
    Target    = "$user@$hostName"
    SshArgs   = @('-p', "$port")
    ScpArgs   = @('-P', "$port")
    RemoteDir = '/opt/rmutt'
    ApiBase   = "https://$domain/api"
  }
}
