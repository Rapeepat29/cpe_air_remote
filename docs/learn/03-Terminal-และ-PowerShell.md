# 03 · Terminal และ PowerShell — การสั่งงานคอมพิวเตอร์ด้วยการพิมพ์

> โปรเจกต์นี้แทบทุกขั้นตอนต้องพิมพ์คำสั่ง บทนี้สอนตั้งแต่เปิดหน้าต่างครั้งแรก
> จนถึงอ่านสคริปต์ `.ps1` ของโปรเจกต์ออกทุกบรรทัด

---

## 1. Terminal, Shell, PowerShell คืออะไร

- **Terminal** = หน้าต่างสีดำ/น้ำเงินที่ให้พิมพ์คำสั่ง
- **Shell** = โปรแกรมที่อ่านคำสั่งที่พิมพ์ แล้วไปสั่งคอมพิวเตอร์
- **PowerShell** = Shell ของ Windows (โปรเจกต์นี้ใช้บน Windows)
- **Bash** = Shell ของ Linux (ใช้บนเซิร์ฟเวอร์ ในบท 14)
- **CMD** (Command Prompt) = Shell รุ่นเก่าของ Windows — **ไม่ใช้** เพราะสคริปต์ `.ps1` รันใน CMD ไม่ได้

ทำไมต้องพิมพ์ ทั้งที่มีเมาส์?
- บางโปรแกรม (Node, Docker, Flutter) **ไม่มีหน้าจอให้กด** มีแต่คำสั่ง
- คำสั่งเขียนลงเอกสารได้ ทำซ้ำได้เหมือนเดิมทุกครั้ง
- รวมหลายคำสั่งเป็น **สคริปต์** ให้ทำงานอัตโนมัติได้ (เช่น `run_all.ps1`)

---

## 2. เปิด PowerShell

### วิธีที่ 1: เปิดตรงที่โฟลเดอร์ (แนะนำ)
1. เปิด File Explorer ไปที่โฟลเดอร์ `cpe_air_remote`
2. คลิกที่ **แถบที่อยู่** ด้านบน (ที่เขียน `C:\Users\...`)
3. พิมพ์ `powershell` แล้วกด Enter
4. หน้าต่าง PowerShell จะเปิดขึ้นโดยอยู่ในโฟลเดอร์นั้นแล้ว

### วิธีที่ 2: คลิกขวา
- Windows 11: คลิกขวาที่พื้นที่ว่างในโฟลเดอร์ → **Open in Terminal**

### วิธีที่ 3: ใน VS Code
- เปิดโฟลเดอร์โปรเจกต์ใน VS Code → เมนู **Terminal → New Terminal** (หรือ `` Ctrl + ` ``)

### หน้าตาที่เห็น

```text
PS C:\Users\rapee\Downloads\rmutt_save_energy_complete_mqtt\cpe_air_remote>
```

- `PS` = กำลังอยู่ใน PowerShell
- `C:\...\cpe_air_remote` = **โฟลเดอร์ปัจจุบัน** (working directory)
- `>` = รอให้พิมพ์คำสั่ง (เรียกว่า **prompt**)

---

## 3. Path — ที่อยู่ของไฟล์

### 3.1 Absolute path (เต็ม)
เริ่มจากไดรฟ์

```text
C:\Users\rapee\Downloads\rmutt_save_energy_complete_mqtt\cpe_air_remote\backend\src\server.js
```

### 3.2 Relative path (สัมพัทธ์)
เริ่มจาก **โฟลเดอร์ปัจจุบัน**

ถ้าตอนนี้อยู่ที่ `cpe_air_remote` แล้ว

```text
backend\src\server.js
```

### 3.3 สัญลักษณ์พิเศษ

| สัญลักษณ์ | ความหมาย |
|---|---|
| `.` | โฟลเดอร์ปัจจุบัน |
| `..` | โฟลเดอร์แม่ (ขึ้นไปหนึ่งชั้น) |
| `~` หรือ `$HOME` | โฟลเดอร์ผู้ใช้ เช่น `C:\Users\rapee` |
| `\` | ตัวคั่นโฟลเดอร์บน Windows |
| `/` | ตัวคั่นโฟลเดอร์บน Linux (PowerShell รับได้ทั้งสองแบบ) |

### 3.4 ชื่อที่มีเว้นวรรค ต้องใส่เครื่องหมายคำพูด

```powershell
cd "Claude outputs"
```

---

## 4. คำสั่งพื้นฐานที่ใช้บ่อยที่สุด

| คำสั่ง | ชื่อเต็มใน PowerShell | ทำอะไร | ตัวอย่าง |
|---|---|---|---|
| `pwd` | `Get-Location` | บอกว่าอยู่โฟลเดอร์ไหน | `pwd` |
| `cd` | `Set-Location` | ย้ายโฟลเดอร์ | `cd backend` |
| `cd ..` | | ขึ้นไปหนึ่งชั้น | `cd ..` |
| `ls` / `dir` | `Get-ChildItem` | ดูไฟล์ในโฟลเดอร์ | `dir` |
| `dir -Force` | | ดูไฟล์ซ่อนด้วย (เช่น `.env`) | `dir -Force` |
| `cat` / `type` | `Get-Content` | แสดงเนื้อหาไฟล์ | `cat .env.example` |
| `mkdir` | `New-Item -ItemType Directory` | สร้างโฟลเดอร์ | `mkdir temp` |
| `copy` / `cp` | `Copy-Item` | คัดลอก | `Copy-Item .env.example .env` |
| `move` / `mv` | `Move-Item` | ย้าย/เปลี่ยนชื่อ | `Move-Item a.txt b.txt` |
| `del` / `rm` | `Remove-Item` | ลบ ⚠️ ไม่ผ่านถังขยะ | `Remove-Item temp.txt` |
| `notepad` | | เปิดไฟล์ด้วย Notepad | `notepad .env` |
| `code .` | | เปิดโฟลเดอร์ปัจจุบันใน VS Code | `code .` |
| `cls` / `clear` | `Clear-Host` | ล้างหน้าจอ | `cls` |
| `exit` | | ปิดหน้าต่าง | `exit` |

### ลองทำตามทีละบรรทัด

```powershell
pwd
dir
cd backend
dir
cat package.json
cd ..
pwd
```

---

## 5. ปุ่มลัดที่ช่วยชีวิต

| ปุ่ม | ทำอะไร |
|---|---|
| `Tab` | เติมชื่อไฟล์/โฟลเดอร์ให้อัตโนมัติ (พิมพ์ `cd bac` แล้วกด Tab → `cd .\backend\`) |
| `↑` / `↓` | เรียกคำสั่งก่อนหน้า |
| `Ctrl + C` | **หยุดโปรแกรมที่กำลังรัน** (เช่น หยุด Backend) |
| `Ctrl + V` หรือคลิกขวา | วางข้อความ |
| ลากเมาส์คลุม + Enter หรือ `Ctrl + C` ตอนมี selection | คัดลอกข้อความ |
| `F7` | แสดงประวัติคำสั่ง |

> 💡 `Ctrl + C` มีสองความหมาย: ถ้ามีข้อความที่ลากคลุมอยู่ = คัดลอก,
> ถ้าไม่มี = หยุดโปรแกรม ระวังกดผิดตอน Backend รันอยู่

---

## 6. โครงสร้างของคำสั่งหนึ่งคำสั่ง

```powershell
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
└──┬──┘ └┬┘ └──┬────┘ └────────────────────┬──────────────────────────┘
 โปรแกรม คำสั่งย่อย  ตัวเลือก+ค่า                ตัวเลือกแบบ ชื่อ=ค่า
```

- **โปรแกรม** (program/command): `flutter`, `npm`, `docker`, `node`, `git`
- **คำสั่งย่อย** (subcommand): `run`, `test`, `build`, `compose`
- **ตัวเลือก** (option/flag):
  - แบบสั้น ขึ้นต้นด้วย `-` ตัวเดียว: `-d windows`
  - แบบยาว ขึ้นต้นด้วย `--` : `--dart-define=...`, `--build`
- **อาร์กิวเมนต์** (argument): ค่าที่ส่งให้ เช่น ชื่อไฟล์

ดูวิธีใช้ของทุกโปรแกรมได้ด้วย `--help`

```powershell
npm --help
docker compose --help
flutter run --help
```

---

## 7. การรันสคริปต์ `.ps1` และ Execution Policy

### 7.1 ทำไมรันไม่ได้ครั้งแรก

ถ้าพิมพ์ `.\run_all.ps1` แล้วเจอ

```text
.\run_all.ps1 : File ... cannot be loaded because running scripts is disabled on this system.
```

เพราะ Windows ตั้งค่าเริ่มต้นว่า **ห้ามรันสคริปต์** (ป้องกันไวรัส)

### 7.2 วิธีแก้แบบปลอดภัย (ใช้ในโปรเจกต์นี้)

```powershell
Set-ExecutionPolicy -Scope Process Bypass
```

- `Set-ExecutionPolicy` = เปลี่ยนนโยบายการรันสคริปต์
- `-Scope Process` = **มีผลแค่หน้าต่างนี้** ปิดหน้าต่างแล้วกลับเป็นเหมือนเดิม
- `Bypass` = อนุญาตทุกสคริปต์

ต้องพิมพ์ใหม่ทุกครั้งที่เปิดหน้าต่าง PowerShell ใหม่

> 💡 ถ้าไม่อยากพิมพ์ทุกครั้ง: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
> (ทำครั้งเดียว อนุญาตสคริปต์ที่เขียนในเครื่องเรา)

### 7.3 ทำไมต้องมี `.\` นำหน้า

```powershell
.\run_all.ps1      # ✅ ถูก
run_all.ps1        # ❌ PowerShell จะไม่หาในโฟลเดอร์ปัจจุบัน (เพื่อความปลอดภัย)
```

`.\` = "ไฟล์นี้ในโฟลเดอร์ปัจจุบัน"

### 7.4 ส่งพารามิเตอร์ให้สคริปต์

```powershell
.\run_all.ps1 -SkipFlutter
.\run_all.ps1 -BrokerHost 192.168.1.153
.\run_all.ps1 -Server
.\mqtt\setup_mqtt.ps1 -BrokerHost 192.168.1.10
```

พารามิเตอร์มีสองแบบ
- **Switch** (สวิตช์เปิด/ปิด) ไม่ต้องใส่ค่า: `-SkipFlutter`, `-InitDb`, `-Server`
- **มีค่า**: `-BrokerHost 192.168.1.153`

ดูว่าสคริปต์รับพารามิเตอร์อะไรบ้าง: เปิดไฟล์ดูบล็อก `param( ... )` บนสุด

---

## 8. Environment Variable ใน PowerShell

```powershell
$env:PATH                 # ดูค่า PATH
$env:USERNAME             # ชื่อผู้ใช้
$env:MY_VAR = 'hello'     # ตั้งค่า (มีผลแค่หน้าต่างนี้)
```

### PATH คืออะไร
`PATH` คือรายการโฟลเดอร์ที่ Windows จะไปหาโปรแกรมเวลาเราพิมพ์ชื่อ
เช่นพิมพ์ `node` → Windows ไปหา `node.exe` ในทุกโฟลเดอร์ใน PATH

ถ้าติดตั้งโปรแกรมแล้วพิมพ์ชื่อแล้วขึ้น

```text
node : The term 'node' is not recognized as the name of a cmdlet...
```

แปลว่า **ไม่อยู่ใน PATH** วิธีแก้
1. ปิด PowerShell แล้วเปิดใหม่ (PATH โหลดตอนเปิดหน้าต่าง)
2. ถ้ายังไม่ได้ ติดตั้งใหม่และติ๊ก "Add to PATH"

ตรวจว่าโปรแกรมอยู่ที่ไหน

```powershell
Get-Command node
where.exe node
```

---

## 9. อ่านไวยากรณ์ PowerShell ให้ออก (เพื่ออ่านสคริปต์ของโปรเจกต์)

### 9.1 ตัวแปร ขึ้นต้นด้วย `$`

```powershell
$name = 'RMUTT'
$port = 3000
Write-Host "Port is $port"      # ฟันหนูคู่ = แทนค่าตัวแปรในข้อความได้
Write-Host 'Port is $port'      # ฟันหนูเดี่ยว = พิมพ์ตรงตัว ไม่แทนค่า
```

### 9.2 ตัวแปรพิเศษที่เจอในสคริปต์ของโปรเจกต์

| ตัวแปร | ความหมาย |
|---|---|
| `$PSScriptRoot` | โฟลเดอร์ที่ไฟล์สคริปต์นั้นอยู่ (ไม่ใช่โฟลเดอร์ที่เราอยู่) |
| `$LASTEXITCODE` | ผลของโปรแกรมภายนอกที่เพิ่งรัน `0` = สำเร็จ, อื่น ๆ = ล้มเหลว |
| `$true` / `$false` / `$null` | จริง / เท็จ / ไม่มีค่า |
| `$_` | "ตัวปัจจุบัน" ในลูปหรือ pipeline |
| `$matches` | ผลการจับ regex ล่าสุด |
| `$HOME` | โฟลเดอร์ผู้ใช้ |
| `$PID` | หมายเลขโปรเซสของ PowerShell นี้ |

### 9.3 Pipeline `|` — ส่งผลลัพธ์ต่อ

```powershell
Get-Process | Where-Object { $_.Name -like 'node*' } | Select-Object Id, Name
```

อ่านว่า: เอารายการโปรเซสทั้งหมด → กรองเฉพาะชื่อขึ้นต้นด้วย node → เลือกแสดงแค่ Id กับ Name

### 9.4 ตัวเปรียบเทียบ (ไม่ใช้ `==` `>` เหมือนภาษาอื่น)

| PowerShell | ความหมาย |
|---|---|
| `-eq` / `-ne` | เท่ากับ / ไม่เท่ากับ |
| `-lt` / `-gt` / `-le` / `-ge` | น้อยกว่า / มากกว่า / ≤ / ≥ |
| `-like` | เทียบแบบมี `*` เช่น `'127.0.0.1' -like '127.*'` |
| `-match` | เทียบด้วย regex |
| `-not`, `-and`, `-or` | ตรรกะ |

### 9.5 เงื่อนไขและลูป

```powershell
if ($port -eq 3000) {
  Write-Host 'default port'
} elseif ($port -lt 1024) {
  Write-Host 'system port'
} else {
  Write-Host 'custom port'
}

foreach ($file in Get-ChildItem *.ps1) {
  Write-Host $file.Name
}

do {
  Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)
```

### 9.6 ฟังก์ชัน

```powershell
function Write-Step {
  param([string]$Text)
  Write-Host ''
  Write-Host "==> $Text" -ForegroundColor Cyan
}

Write-Step '1/6 ตรวจ Docker Desktop'
```

ฟังก์ชันนี้มีอยู่จริงใน `run_all.ps1` ใช้พิมพ์หัวข้อสีฟ้า

### 9.7 Hashtable (ตาราง key-value)

```powershell
$values = @{}
$values['DB_PORT'] = '3306'
$values.ContainsKey('DB_PORT')   # True
```

### 9.8 Error handling

```powershell
$ErrorActionPreference = 'Stop'   # เจอ error ให้หยุดทันที (ไม่ดื้อทำต่อ)
Set-StrictMode -Version Latest    # ใช้ตัวแปรที่ไม่มีอยู่ = error

try {
  # ทำบางอย่าง
} catch {
  Write-Host "พัง: $($_.Exception.Message)"
} finally {
  # ทำเสมอ ไม่ว่าพังหรือไม่
}

throw 'ข้อความ error'              # โยน error ออกไปเอง
```

### 9.9 `Push-Location` / `Pop-Location`
เหมือน `cd` แต่ **จำไว้ว่ามาจากไหน** แล้วกลับที่เดิมได้

```powershell
Push-Location $mqttDirectory     # เข้าไปในโฟลเดอร์ mqtt
try {
  docker compose up -d
} finally {
  Pop-Location                   # กลับโฟลเดอร์เดิมเสมอ แม้จะ error
}
```

### 9.10 backtick `` ` `` ต่อบรรทัด

```powershell
docker run --rm `
  --mount "type=bind,source=$configDirectory,target=/mosquitto/config" `
  eclipse-mosquitto:2.0 `
  mosquitto_passwd -U /mosquitto/config/passwords
```

ทั้ง 4 บรรทัดคือคำสั่งเดียว `` ` `` ท้ายบรรทัดต้อง **ไม่มีช่องว่างตามหลัง**

---

## 10. อ่านสคริปต์จริงทีละบรรทัด: `mqtt/start_mqtt.ps1`

```powershell
$ErrorActionPreference = 'Stop'          # (1)
Set-StrictMode -Version Latest           # (2)

Push-Location $PSScriptRoot              # (3)
try {
  if (-not (Test-Path '.env') -or -not (Test-Path 'config/passwords')) {   # (4)
    throw 'ยังไม่ได้ตั้งค่า MQTT กรุณารัน .\setup_mqtt.ps1 ก่อน'             # (5)
  }
  docker compose --env-file .env up -d   # (6)
  if ($LASTEXITCODE -ne 0) {             # (7)
    throw 'เปิด Mosquitto ไม่สำเร็จ'
  }
  docker compose --env-file .env ps      # (8)
} finally {
  Pop-Location                           # (9)
}
```

1. ถ้ามี error ให้หยุดทันที
2. เข้มงวด: ตัวแปรพิมพ์ผิดจะ error
3. ย้ายไปโฟลเดอร์ที่สคริปต์อยู่ (`mqtt\`) — ทำให้รันจากที่ไหนก็ได้
4. `Test-Path` = ไฟล์นี้มีอยู่ไหม, `-not` = กลับค่า → "ถ้าไม่มี .env หรือไม่มีไฟล์รหัส"
5. หยุดพร้อมบอกให้ไปรัน `setup_mqtt.ps1` ก่อน
6. สั่ง Docker เปิด Mosquitto เบื้องหลัง (บท 05 อธิบาย)
7. ถ้า docker ล้มเหลว (exit code ไม่ใช่ 0) ให้หยุด
8. แสดงสถานะ container
9. กลับโฟลเดอร์เดิม

---

## 11. อ่านสคริปต์ใหญ่: โครงของ `run_all.ps1`

เปิดไฟล์ `run_all.ps1` ดูประกอบ

```powershell
[CmdletBinding()]
param(
  [string]$BrokerHost = '',      # ระบุ LAN IP เอง
  [switch]$SkipFlutter,          # ไม่เปิดแอป
  [switch]$InitDb,               # สร้างตารางครั้งแรก
  [switch]$Server,               # ใช้เซิร์ฟเวอร์จริง ไม่เปิดอะไรในเครื่อง
  [string]$ServerUrl = 'https://rmutt-energy.duckdns.org'
)
```

`param(...)` = รายการพารามิเตอร์ที่รับได้ ค่าหลัง `=` คือค่าเริ่มต้น

ฟังก์ชันช่วยที่สคริปต์ประกาศไว้

| ฟังก์ชัน | ทำอะไร |
|---|---|
| `Write-Step` | พิมพ์หัวข้อสีฟ้า `==> ...` |
| `Get-DotEnv` | อ่านไฟล์ `.env` เป็น hashtable (ใช้ regex `^\s*([^#\s][^=]*)=(.*)$`) |
| `Set-DotEnvValue` | แก้/เพิ่มค่าบรรทัดเดียวในไฟล์ `.env` โดยไม่แตะบรรทัดอื่น |
| `Get-LanIPv4` | หา LAN IP จากการ์ดเครือข่ายที่ `Up` และมี Default Gateway ตัด `127.*` และ `169.254.*` ออก |

ลำดับการทำงาน

```text
ถ้ามี -Server  → เรียก https://<ServerUrl>/api/health → ถ้า ok เปิด flutter ชี้เซิร์ฟเวอร์จริง → จบ

1/6 docker info                         ตรวจว่า Docker Desktop เปิดอยู่
2/6 docker ps -a --filter name=mariadb  หา container ชื่อมี "mariadb" แล้ว docker start
    Test-NetConnection 127.0.0.1:3306   รอจนพอร์ต DB ตอบ (สูงสุด 60 วินาที)
3/7 npm ci (ถ้ายังไม่มี node_modules)
    npm run db:init (ถ้าใส่ -InitDb)
    npm run db:migrate:pzem / occupancy / energy / autooff / settings
    node scripts/doctor.js --fix         เติมตาราง/คอลัมน์ที่ขาด
4/7 หา LAN IP → เขียน MQTT_URL, USERNAME, PASSWORD ลง backend/.env
5/7 ตรวจ/ซ่อมไฟล์ mqtt/config/acl → docker compose up -d → รอจน healthy
6/7 ปิดโปรเซสที่จองพอร์ต 3000 → เปิดหน้าต่างใหม่รัน npm start
7/7 เรียก /api/health จน status=ok และ mqtt.connected=true
    → flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

> 💡 สังเกต: หัวข้อมีทั้ง "1/6" และ "3/7" ปนกัน เป็นร่องรอยว่ามีการเพิ่มขั้นตอนทีหลัง
> ไม่มีผลกับการทำงาน

คำสั่ง PowerShell ที่ใช้ในสคริปต์นี้

| คำสั่ง | ทำอะไร |
|---|---|
| `Get-Command docker` | มีโปรแกรม docker ไหม |
| `docker info *> $null` | ถาม Docker แต่ทิ้งผลลัพธ์ทั้งหมด (`*>` = ทุก stream, `$null` = ถังขยะ) |
| `Test-NetConnection -ComputerName 127.0.0.1 -Port 3306 -InformationLevel Quiet` | ลองต่อพอร์ต ได้ True/False |
| `Get-NetIPConfiguration` | ดูค่าการ์ดเครือข่ายทั้งหมด |
| `Get-NetTCPConnection -LocalPort 3000 -State Listen` | ใครจองพอร์ต 3000 |
| `Stop-Process -Id <PID> -Force` | ฆ่าโปรเซส |
| `Start-Process powershell.exe -ArgumentList '-NoExit','-Command','npm start'` | เปิดหน้าต่าง PowerShell ใหม่ แล้วรันคำสั่ง (`-NoExit` = รันเสร็จไม่ปิดหน้าต่าง) |
| `Invoke-RestMethod -Uri ... -TimeoutSec 5` | เรียก HTTP แปลง JSON ให้ |
| `Start-Sleep -Seconds 3` | รอ 3 วินาที |
| `[Console]::OutputEncoding = [System.Text.Encoding]::UTF8` | ให้หน้าจอแสดงภาษาไทยถูกต้อง |

---

## 12. Bash เบื้องต้น (ใช้บนเซิร์ฟเวอร์ Linux)

เปรียบเทียบกับ PowerShell

| งาน | PowerShell | Bash |
|---|---|---|
| ดูโฟลเดอร์ปัจจุบัน | `pwd` | `pwd` |
| ดูไฟล์ | `dir` | `ls -la` |
| ย้ายโฟลเดอร์ | `cd /opt/rmutt` | `cd /opt/rmutt` |
| ดูไฟล์ | `cat` | `cat`, `less`, `tail -n 50` |
| ค้นข้อความ | `Select-String` | `grep` |
| รันสคริปต์ | `.\x.ps1` | `bash x.sh` หรือ `./x.sh` |
| สิทธิ์ผู้ดูแล | Run as Administrator | `sudo ...` |
| ตัวแปร | `$x = 1` | `x=1` (ห้ามเว้นวรรครอบ `=`) |
| ต่อบรรทัด | `` ` `` | `\` |
| คอมเมนต์ | `#` | `#` |

ศึกษาเพิ่มในบท 14

---

## 13. ค้นหาข้อความในไฟล์ (มีประโยชน์มากตอนศึกษาโค้ด)

```powershell
# หาว่า "MQTT_URL" ถูกใช้ที่ไหนบ้างใน backend
Select-String -Path backend\src\*.js -Pattern 'MQTT_URL'

# ค้นทุกโฟลเดอร์ย่อย
Get-ChildItem -Recurse -Include *.js backend\src | Select-String 'auto_off'

# ดู 50 บรรทัดสุดท้ายของ log
Get-Content mqtt\log\mosquitto.log -Tail 50

# ดู log แบบสด (เหมือน tail -f)
Get-Content mqtt\log\mosquitto.log -Tail 20 -Wait
```

> 💡 ใน VS Code กด `Ctrl + Shift + F` ค้นทั้งโปรเจกต์ได้ง่ายกว่า

---

## 14. สรุปบท

- เปิด PowerShell ตรงโฟลเดอร์ด้วยการพิมพ์ `powershell` ในแถบที่อยู่
- `cd`, `dir`, `cat`, `Copy-Item`, `notepad` คือคำสั่งหลัก
- ก่อนรันสคริปต์: `Set-ExecutionPolicy -Scope Process Bypass`
- รันสคริปต์ด้วย `.\ชื่อ.ps1` ส่งพารามิเตอร์ด้วย `-ชื่อ ค่า`
- `Ctrl + C` หยุดโปรแกรม, `Tab` เติมชื่อ, `↑` เรียกคำสั่งเก่า
- `$LASTEXITCODE -ne 0` = คำสั่งก่อนหน้าล้มเหลว

## 🧪 แบบฝึกหัด

1. เปิด PowerShell ที่โฟลเดอร์หลัก ใช้ `cd` เข้าไปที่ `backend\src\routes` แล้ว `dir` ดูว่ามีกี่ไฟล์
2. กลับไปโฟลเดอร์หลักด้วย `cd ..` กี่ครั้ง?
3. ใช้ `Select-String` หาว่าไฟล์ไหนใน `backend\src\routes` มีคำว่า `requireAdmin`
4. เปิด `mqtt\stop_mqtt.ps1` แล้วอธิบายทุกบรรทัดเหมือนหัวข้อ 10
5. ใน `run_all.ps1` หาบรรทัดที่ป้องกันไม่ให้ใช้ `127.0.0.1` เป็น BrokerHost

ถัดไป: **บท 04 ติดตั้งเครื่องมือทั้งหมด**
