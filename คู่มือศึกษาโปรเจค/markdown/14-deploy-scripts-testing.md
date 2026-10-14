# การติดตั้งระบบ สคริปต์อัตโนมัติ และการทดสอบ

## ภาพรวม

บทนี้อธิบาย "ทุกอย่างที่ไม่ใช่โค้ดของแอป" แต่ขาดไม่ได้: สคริปต์ที่เปิดระบบบนเครื่อง Windows ของนักพัฒนา สคริปต์ที่ติดตั้งและอัปเดตเซิร์ฟเวอร์จริง สคริปต์สร้างไฟล์ติดตั้งแอป (APK/IPA) และชุดทดสอบอัตโนมัติ ระบบนี้มี service หลายตัว (MariaDB, Mosquitto, Backend, Caddy, เว็บแอป, แอป) ถ้าต้องพิมพ์คำสั่งทีละตัวด้วยมือทุกครั้ง จะพลาดง่ายและอธิบายใครไม่ได้ จึงเขียนเป็นสคริปต์ที่ "ตรวจก่อนทำ หยุดทันทีเมื่อพัง และบอกว่าต้องแก้อะไร"

มี **สองสภาพแวดล้อม** ที่ต้องแยกให้ออก:

1. **Local dev (Windows)** — เครื่องของนักศึกษา รัน MariaDB ใน Docker/ติดตั้งตรง, Mosquitto แบบ `1883` ไม่เข้ารหัส, Backend ด้วย `npm start`, แอป Flutter ด้วย `flutter run` สคริปต์หลักคือ `run_all.ps1`
2. **Production (Ubuntu + Docker)** — เซิร์ฟเวอร์จริงที่ `/opt/rmutt` รันทุก service ใน Docker Compose ผ่าน HTTPS 443 และ MQTTS (ค่าเริ่มต้นผ่าน Tailscale Funnel พอร์ต 8443 หรือต่อตรงพอร์ต 8883) สคริปต์หลักคือชุดใน `deploy/` (เครื่อง Windows เป็นผู้สั่ง เครื่อง Ubuntu เป็นผู้ทำ)

เรื่อง `docker-compose.yml`, `Caddyfile` และ Tailscale อธิบายลึกใน "บทเครือข่าย เซิร์ฟเวอร์ และ Tailscale" บทนี้จะอ้างถึงเท่าที่จำเป็นเพื่อเข้าใจลำดับขั้นตอน

## ความรู้ที่ต้องมีก่อนอ่านบทนี้

**1. Shell script: bash กับ PowerShell** — shell คือโปรแกรมที่รับคำสั่งที่พิมพ์ bash (ไฟล์ `.sh`) ใช้บน Linux/Ubuntu ส่วน PowerShell (ไฟล์ `.ps1`) ใช้บน Windows สองตัวนี้ไวยากรณ์ต่างกันมาก: bash ใช้ `$VAR`, `[ -f file ]`, `if ...; then ... fi` ส่วน PowerShell ใช้ `$Var`, `Test-Path`, `if (...) { }` และส่งเป็น "object" ไม่ใช่ข้อความล้วน โปรเจกต์ใช้ PowerShell ฝั่ง Windows (เครื่องผู้พัฒนา) และ bash ฝั่งเซิร์ฟเวอร์ (Ubuntu) เพราะเป็น shell ที่แต่ละเครื่องมีติดมาอยู่แล้ว

**2. พารามิเตอร์ (params)** — ค่าที่ส่งให้สคริปต์ตอนเรียก ใน PowerShell ประกาศด้วยบล็อก `param(...)` เช่น `[string]$BrokerHost = ''` (ข้อความ ค่าเริ่มต้นว่าง) และ `[switch]$SkipFlutter` (สวิตช์ เปิดเมื่อพิมพ์ชื่อ ไม่ต้องใส่ค่า) เรียกว่า `.\run_all.ps1 -SkipFlutter` ใน bash ใช้ตัวแปรพิเศษ `$1` (อาร์กิวเมนต์ตัวแรก) เช่น `${1:-}` แปลว่า "ค่าของ `$1` ถ้าไม่มีให้เป็นค่าว่าง"

**3. Exit code (รหัสออก)** — ทุกโปรแกรมเมื่อจบจะคืนเลขหนึ่งตัว `0` = สำเร็จ ค่าอื่น = ล้มเหลว bash เก็บไว้ใน `$?` PowerShell เก็บของโปรแกรมภายนอก (docker, npm, flutter) ไว้ใน `$LASTEXITCODE` สคริปต์ที่ดีต้องตรวจเลขนี้เสมอ แล้ว `exit 1` / `throw` เมื่อพัง เพื่อให้สคริปต์ที่เรียกต่อรู้ว่าไม่ควรไปต่อ

**4. `set -euo pipefail` (bash)** — สามสวิตช์ความปลอดภัยที่ต้นสคริปต์: `-e` หยุดทันทีเมื่อคำสั่งใดล้มเหลว, `-u` ถือว่าใช้ตัวแปรที่ไม่เคยตั้งค่าเป็น error (กันพิมพ์ชื่อตัวแปรผิดแล้วกลายเป็นค่าว่างเงียบ ๆ เช่น `rm -rf "$DIR/"` ตอน `$DIR` ว่าง), `-o pipefail` ทำให้ท่อ `a | b | c` ล้มเหลวถ้าตัวใดตัวหนึ่งล้มเหลว (ปกติดูแค่ตัวสุดท้าย) ใน PowerShell สิ่งเทียบเท่าคือ `$ErrorActionPreference = 'Stop'` กับ `Set-StrictMode -Version Latest` แต่ **ไม่ครอบคลุมโปรแกรมภายนอก** จึงต้องตรวจ `$LASTEXITCODE` เองทุกครั้ง

**5. ไฟล์ `.env`** — ไฟล์ข้อความรูปแบบ `ชื่อ=ค่า` บรรทัดละค่า เก็บการตั้งค่าที่เปลี่ยนตามเครื่องและความลับ (รหัสผ่าน DB, JWT secret) แยกออกจากโค้ด เพื่อไม่ต้องแก้โค้ดตอนย้ายเครื่อง และไม่ต้องส่งความลับขึ้น git

**6. SSH / SCP / rsync** — SSH คือการล็อกอินเข้าเครื่องอื่นผ่านเครือข่ายแบบเข้ารหัส (`ssh -p 22 user@host 'คำสั่ง'` รันคำสั่งบนเครื่องปลายทางแล้วกลับ) SCP ก๊อปไฟล์ผ่าน SSH (`scp -P 22 -r ไฟล์ user@host:/ปลายทาง/` สังเกต: SSH ใช้ `-p` พอร์ตตัวเล็ก SCP ใช้ `-P` ตัวใหญ่ จึงมี `SshArgs` กับ `ScpArgs` แยกกัน) rsync ก๊อปเฉพาะส่วนที่ต่าง ใช้ส่งไฟล์สำรองออกนอกเครื่อง SSH ยังทำ **tunnel** ได้: `ssh -N -L 3307:127.0.0.1:3306 user@host` = ทุกอย่างที่ต่อพอร์ต 3307 ในเครื่องเรา จะถูกส่งเข้ารหัสไปต่อพอร์ต 3306 บนเซิร์ฟเวอร์ (`-N` = ไม่ต้องเปิด shell)

**7. `sudo` และผู้ใช้ root** — root คือผู้ดูแลสูงสุดของ Linux `sudo` = รันคำสั่งนี้ในฐานะ root สคริปต์ติดตั้ง (ลง Docker, สร้างโฟลเดอร์ใน `/opt`, เปลี่ยนเจ้าของไฟล์) ต้องใช้ root จึงตรวจ `id -u` ว่าเป็น 0 ก่อน ส่วนสคริปต์ที่ไม่จำเป็น (เช่น `seed-admin.sh`) รันด้วยผู้ใช้ปกติเพื่อลดความเสี่ยง

**8. cron** — ตัวตั้งเวลารันคำสั่งของ Linux ไฟล์ใน `/etc/cron.d/` มีรูปแบบ `นาที ชั่วโมง วัน เดือน วันในสัปดาห์ ผู้ใช้ คำสั่ง` เช่น `30 2 * * *` = ทุกวันเวลา 02:30

**9. Ubuntu พื้นฐาน** — `apt-get` คือตัวติดตั้งโปรแกรม, `systemctl` จัดการ service (`enable --now docker` = ให้เปิดตอนบูตและเปิดเดี๋ยวนี้), `ufw` คือ firewall ตัวง่าย, `swap` คือพื้นที่ดิสก์ที่ใช้แทน RAM ตอนเต็ม, `fail2ban` บล็อก IP ที่เดารหัส SSH, `/opt` คือโฟลเดอร์มาตรฐานสำหรับโปรแกรมที่ติดตั้งเอง, uid คือเลขประจำตัวผู้ใช้ (ผู้ใช้ `mosquitto` ในคอนเทนเนอร์คือ uid 1883)

**10. คำสั่ง docker compose ที่ใช้** — `docker compose up -d` เปิด service ทั้งชุดแบบเบื้องหลัง, `--build` สร้าง image ใหม่จากโค้ด, `ps` ดูสถานะ, `logs --tail 40 <service>` ดู log, `exec -T <service> <คำสั่ง>` รันคำสั่งในคอนเทนเนอร์ที่ทำงานอยู่ (`-T` = ไม่ต้องใช้ terminal จำลอง จำเป็นเมื่อรันจากสคริปต์), `restart`, `up -d --force-recreate` สร้างคอนเทนเนอร์ใหม่ (ไม่ใช่แค่รีสตาร์ท)

**11. การเซ็นแอป Android** — Android ยอมติดตั้งแอปทับของเดิมก็ต่อเมื่อ "ลายเซ็น" เหมือนเดิม ลายเซ็นมาจาก **keystore** (ไฟล์ `.jks` เก็บกุญแจส่วนตัว + รหัสผ่าน) ไฟล์ `android/key.properties` บอก Gradle ว่า keystore อยู่ไหน รหัส/alias คืออะไร APK แบบ **debug** เซ็นด้วยกุญแจ debug ที่ใครก็มี (ลงเทสต์ได้ ห้ามแจกจริง) APK แบบ **release** เซ็นด้วยกุญแจของโปรเจกต์ ถ้ากุญแจหาย จะอัปเดตแอปที่ผู้ใช้ลงไปแล้วไม่ได้อีกเลย

**12. GitHub Actions** — บริการของ GitHub ที่รันงานอัตโนมัติบนเครื่องเสมือนของ GitHub ตามไฟล์ YAML ใน `.github/workflows/` เรียกเครื่องนั้นว่า "runner" ที่ต้องใช้ runner macOS เพราะ Apple อนุญาตให้ build แอป iOS บน macOS เท่านั้น แต่เครื่องพัฒนาเป็น Windows

**13. git และ `.gitignore`** — git เก็บประวัติโค้ด ไฟล์ที่ commit แล้วจะอยู่ในประวัติตลอดไป (ลบทีหลังก็ยังกู้ได้) จึงต้องกันความลับออกตั้งแต่แรกด้วย `.gitignore` = รายชื่อรูปแบบไฟล์ที่ git ต้องมองข้าม

**14. Health check และรหัส HTTP** — "health check" คือการเรียก URL เล็ก ๆ (`/api/health`) เพื่อถามว่าระบบมีชีวิตอยู่ไหม 401 = "ต้องล็อกอินก่อน" ใช้เป็นสัญญาณว่าเส้นทางมีอยู่จริง 404 = ไม่มีเส้นทางนั้น

## โครงสร้างโฟลเดอร์

```text
cpe_air_remote/
├── run_all.ps1               # เปิดระบบ local ทั้งชุด (หรือ -Server)
├── check_system.ps1          # ตรวจเร็ว 3 ขั้น
├── diagnose.ps1              # ตรวจละเอียด 7 ขั้น: ESP32 ไม่ขึ้นในแอป
├── db-tunnel.ps1             # อุโมงค์ SSH ไป DB บนเซิร์ฟเวอร์ (HeidiSQL)
├── build-apk.ps1             # build APK
├── BUILD-ANDROID.bat         # ดับเบิลคลิก = keystore + build-apk
├── create-keystore.ps1       # สร้างกุญแจเซ็น APK (ครั้งเดียว)
├── change-keystore-password.ps1  # เปลี่ยนรหัสกุญแจ
├── .gitignore  .vscode/settings.json
├── .github/workflows/build-android.yml # build APK บน Linux ของ GitHub (กดรันเอง, เพิ่ม 9 ต.ค.)
├── .github/workflows/build-ios.yml   # build iOS บน macOS (กดรันเอง)
├── .github/workflows/test.yml        # flutter analyze + flutter test ทุกครั้งที่ push (เพิ่ม 9 ต.ค.)
├── mqtt/                     # broker สำหรับ local (setup_mqtt.ps1, test_mqtt.ps1 ...)
├── backend/{test,scripts}    # test ของ Backend (node --test) + migration/doctor
├── test/                     # test ของ Flutter (flutter test)
├── firmware/tests/history_log_test.cpp   # test เฟิร์มแวร์บน PC
└── deploy/                   # ชุดติดตั้งเซิร์ฟเวอร์จริง
    ├── ServerConfig.ps1  server.config.example.json   # ค่าเซิร์ฟเวอร์ที่ใช้ร่วม
    ├── upload.ps1  update-server.ps1  deploy-web.ps1  # ฝั่ง Windows (ผู้สั่ง)
    ├── setup-vps.sh  init-env.sh  update-remote.sh    # ฝั่ง Ubuntu (ผู้ทำ)
    ├── sync-mqtt-cert.sh  fix-mqtt-permissions.sh
    ├── backup-db.sh  seed-admin.sh  db-view.sh        # ดูแลระบบ
    ├── docker-compose.yml  Caddyfile  *.Dockerfile    # (บทเครือข่าย)
    └── DEPLOY.md  SERVER_REQUIREMENTS.md              # คู่มือ
```

บนเซิร์ฟเวอร์จะได้โฟลเดอร์ `/opt/rmutt` (สร้างโดย `setup-vps.sh`): `db/data`, `mosquitto/{config,certs,data}`, `caddy/{data,config}`, `backend`, `www` (เว็บแอป), `firmware` (ไฟล์ OTA), `backups`

## สภาพแวดล้อมที่ 1: Local dev บน Windows

```text
เครื่อง Windows ของนักพัฒนา
┌──────────────────────────────────────────────────────────────────┐
│ .\run_all.ps1  (ลำดับการทำงาน)                                    │
│  1 Docker Desktop ทำงานไหม          docker info                   │
│  2 MariaDB container                docker start ...  พอร์ต 3306  │
│  3 npm ci + migrate + doctor --fix  (node scripts/...)            │
│  4 หา LAN IP -> เขียน MQTT_URL ลง backend/.env                    │
│  5 Mosquitto (mqtt/docker-compose)  พอร์ต 1883 -> รอ healthy      │
│  6 Backend: npm start (หน้าต่างใหม่) พอร์ต 3000                   │
│  7 ตรวจ http://127.0.0.1:3000/api/health  (status ok + mqtt)      │
│  → flutter run -d windows --dart-define=API_BASE_URL=...:3000/api │
└──────────────────────────────────────────────────────────────────┘
       ESP32 ในห้อง ──Wi-Fi──> LAN IP:1883 (mqtt:// ไม่เข้ารหัส)
```

- **พอร์ต:** MariaDB `3306` · Mosquitto `1883` · Backend `3000` (ที่อยู่ `http://127.0.0.1:3000/api`)
- **broker ของ local** เป็นแบบ "ไฟล์รหัส + ACL" (บัญชีเดียว `MQTT_USERNAME` ของ `mqtt/.env`) ต่างจาก production ที่ใช้ Dynamic Security (แต่ละบอร์ดมีบัญชีของตัวเอง) และเป็น TLS
- `check_system.ps1` ตรวจเร็วว่า "ตอนนี้ทุกอย่างปกติไหม" ส่วน `diagnose.ps1` ใช้เมื่อ "บอร์ดไม่ขึ้นในแอป" แล้วอยากรู้ว่าพังตรงไหน
- แอป Flutter รู้ว่าจะเรียก API ที่ไหนจากค่าคอมไพล์ `--dart-define=API_BASE_URL=...` (อ่านใน `lib/config/api_config.dart` ด้วย `String.fromEnvironment('API_BASE_URL')`) ตัวอย่างในโค้ดคือ Windows ใช้ `http://127.0.0.1:3000/api`, Android emulator ใช้ `http://10.0.2.2:3000/api` (10.0.2.2 คือชื่อที่ emulator เรียกเครื่องโฮสต์)

> [!WHY]
> ใช้ `--dart-define` แทนการเขียน URL ลงโค้ด เพราะ URL ต่างกันตามที่รัน (local / production) ถ้าเขียนตายตัว ต้องแก้โค้ดแล้ว build ใหม่ทุกครั้งที่เปลี่ยนเครื่อง ค่าที่ส่งตอน build ถูก "ฝัง" ลงแอป จึงไม่ต้องมีหน้าตั้งค่าให้ผู้ใช้กรอก

## สภาพแวดล้อมที่ 2: Production (Ubuntu + Docker)

```text
Windows (ผู้สั่ง)                             Ubuntu /opt/rmutt (ผู้ทำ)
deploy/server.config.json                 ┌─────────────────────────────────┐
  host/user/port/domain                   │ docker compose                  │
        │ ssh / scp                       │  caddy :80 :443 (HTTPS)         │
        ├─ upload.ps1 ───────────────────►│   ├ /api/* → backend :3000      │
        ├─ update-server.ps1 ────────────►│   ├ /  → ./www (เว็บแอป)         │
        ├─ deploy-web.ps1 ───────────────►│   └ /firmware/* → ./firmware    │
        └─ db-tunnel.ps1 (ssh -L 3307)    │  backend (Node 22) ─► db :3306  │
                                          │  mqtt :1883 (ภายใน Docker)      │
ESP32 ในอาคาร MQTTS 8883 ────────────────►│       :8883 (MQTTS ตรง)         │
ESP32/แอป นอกอาคาร ─► relay Tailscale     │  tailscale (ต่อออกหา Tailscale)  │
Funnel 443 / 8443 ───────────────────────►│   ├ 443  → caddy :8080          │
แอป/เว็บในอาคาร HTTPS 443 ────────────────►│   └ 8443 → mqtt :1883           │
                                          └─────────────────────────────────┘
cron (root): 02:30 backup-db.sh   03:10 sync-mqtt-cert.sh
```

พอร์ตที่ publish บนเครื่อง: `443` HTTPS, `8883` MQTTS (ต่อตรงในอาคาร), `80` (ให้ Let's Encrypt ตรวจโดเมน), `22` SSH เฉพาะผู้ดูแล ส่วน Funnel (`443` → `caddy:8080` และ `8443` → `mqtt:1883`) ไม่ใช่พอร์ตที่ publish เพราะกล่อง tailscale ต่อออกไปหา relay ของ Tailscale เอง แต่เปิดให้อินเทอร์เน็ตเข้าผ่านชื่อ ts.net ได้ (ค่าเริ่มต้นของบอร์ดคือ `ts.net:8443`) MariaDB `3306` ผูกกับ `127.0.0.1` เท่านั้น (ดูจาก `docker-compose.yml`: `"127.0.0.1:3306:3306"`) จึงต้องใช้ SSH tunnel เพื่อดู DB จากเครื่องเรา และ Mosquitto `1883` ไม่ publish (ใช้ภายใน Docker โดย Backend และกล่อง tailscale)

## ไทม์ไลน์ติดตั้งเครื่องใหม่ (จับคู่กับสคริปต์)

| ลำดับ | ทำที่ | คำสั่ง | สคริปต์/ผลที่ได้ |
|---|---|---|---|
| 0 | Windows | คัดลอก `server.config.example.json` เป็น `server.config.json` แล้วแก้ host/user/domain (แนะนำตั้ง SSH key) | `ServerConfig.ps1` อ่านไฟล์นี้ |
| 1 | Windows | `.\deploy\upload.ps1` | สร้าง `/opt/rmutt/{backend,www}` แล้วส่งชุด deploy + เว็บแอป + ซอร์ส backend |
| 2 | Ubuntu | `sudo bash setup-vps.sh` (+ `--firewall` ถ้าไม่มีฝ่ายไอที) | Docker, swap, เวลา, โฟลเดอร์, cron; แล้วออก SSH เข้าใหม่ให้กลุ่ม docker มีผล |
| 3 | Ubuntu | `sudo bash init-env.sh` | `.env` (รหัสสุ่ม) + ไฟล์บัญชี MQTT dynsec |
| 4 | Ubuntu | `docker compose up -d caddy` รอ log "certificate obtained" | Caddy ขอใบรับรอง HTTPS จาก Let's Encrypt |
| 5 | Ubuntu | `sudo bash sync-mqtt-cert.sh` | ก๊อปใบรับรองให้ Mosquitto (ถ้าไม่มี Mosquitto สตาร์ตไม่ขึ้น) |
| 6 | Ubuntu | `docker compose up -d --build` แล้ว `docker compose ps` | เปิดทุก service |
| 7 | Ubuntu | `docker compose exec backend npm run db:init` + `db:migrate:settings`, `db:migrate:firmware`, `db:migrate:history` | สร้างตารางตาม `schema.sql` และ migration |
| 8 | Ubuntu | `bash seed-admin.sh` | สร้างแอดมินคนแรก แล้วล้างรหัสออกจาก `.env` |
| 9 | Ubuntu | `docker compose exec backend npm run db:doctor` แล้ว `docker compose restart backend` | ตรวจ schema ตรง แล้วรีสตาร์ท |
| 10 | ใครก็ได้ | `curl -s https://<โดเมน>/api/health` | ต้องเห็น `"status":"ok"`, `"connected":true`, `"deviceAuth":"dynsec"` |

**ทำไมลำดับนี้:** `.env` ต้องมีก่อน compose (ตัวแปร `DOMAIN` ฯลฯ) · Caddy ต้องขอใบรับรองก่อน เพราะ Mosquitto อ่านไฟล์ใบรับรองตอนสตาร์ท (ไม่มีไฟล์ = ล้ม) · ตารางต้องมีก่อนสร้างแอดมิน

**ครั้งต่อไปที่แก้โค้ด:** `git pull` แล้ว `.\deploy\update-server.ps1` คำสั่งเดียว (อธิบายต่อด้านล่าง ต้องรันใน **PowerShell** ถ้าเป็น Command Prompt ที่บรรทัดขึ้นต้น `C:\...>` ไม่มี `PS` การพิมพ์ชื่อไฟล์ `.ps1` จะเปิด Notepad แทน ให้ใช้ `powershell -ExecutionPolicy Bypass -File .\deploy\update-server.ps1` ตาม `DEPLOY.md` ที่เพิ่มเมื่อ 11 ต.ค. 2569) · แก้แต่หน้าเว็บ: `.\deploy\deploy-web.ps1` · แล้วจึง `.\build-apk.ps1` ถ้าต้องแจกแอปรุ่นใหม่

**ไฟล์เฟิร์มแวร์ OTA (เปลี่ยน 14 ต.ค. 2569):** บอร์ดอัปเดตตัวเองผ่าน Wi-Fi จากไฟล์ `.bin` ที่อยู่ใน `/opt/rmutt/firmware` (Caddy เสิร์ฟที่ `/firmware/*` แบบอ่านอย่างเดียว ส่วน Backend mount โฟลเดอร์เดียวกันที่ `/firmware` แบบ **เขียนได้** ผ่าน `FIRMWARE_DIR` เพื่อรับไฟล์ที่อัปโหลดจากเว็บ) ขั้นตอนตาม `deploy/DEPLOY.md`:

1. Arduino IDE → **Sketch → Export Compiled Binary** ได้ `<สเก็ตช์>.ino.bin` (ใช้ไฟล์นี้เท่านั้น ไม่ใช่ `.merged.bin` ที่ขึ้นต้นด้วย bootloader ซึ่ง OTA ใช้ไม่ได้)
2. เว็บแอป → เมนู **เฟิร์มแวร์** → เลือกแท็บชนิดบอร์ด (**แอร์ IR** / **สายแอร์ Daikin** / **เซ็นเซอร์ LD2410**) แล้วลากไฟล์มาวาง ถ้าชื่อไฟล์ยังไม่มีเลขรุ่น เว็บถามรุ่นแล้วตั้งชื่อเป็น `<สเก็ตช์>-<รุ่น>.bin` ให้
3. ตารางบอร์ดบอกว่าตัวไหนยังเก่า กด **อัปเดต** ทีละตัว หรือเลือกทุกตัวที่ยังเก่าแล้วสั่งพร้อมกัน รอ 1–2 นาที

ชนิดไฟล์ดูจากชื่อ: มีคำว่า `occ` = เซ็นเซอร์, มี `wired` หรือ `slm8` = สายแอร์, นอกนั้น = แอร์ IR Backend ไม่ยอมให้อัปโหลดเข้าผิดแท็บ ไม่ยอมสั่งไฟล์ผิดชนิดให้บอร์ด ไฟล์ต้องขึ้นต้นด้วยไบต์ `0xE9` และไม่เกิน 1,984 KB (ขนาดช่องโปรแกรมใน `partitions.csv`) รายละเอียดฝั่ง API อยู่ในบท Backend ตอนที่ 1 และมุมความปลอดภัยในบทความปลอดภัย ยังวางไฟล์ด้วย `scp -P 22 ไฟล์ <user>@<host>:/opt/rmutt/firmware/` ได้เหมือนเดิม ตัวไฟล์ไม่ผ่าน `update-server.ps1` เพราะเป็นไฟล์ที่ build ภายนอก โค้ดฝั่งเฟิร์มแวร์อธิบายในบทเฟิร์มแวร์

> [!WARN]
> โฟลเดอร์ `/opt/rmutt/firmware` บนเครื่องต้องเป็นของ **uid 1000** (user `node` ที่ Backend ใช้รันในคอนเทนเนอร์ ตาม `USER node` ใน `backend.Dockerfile`) ไม่งั้นอัปโหลดจากเว็บจะได้ข้อความ "Backend เขียนโฟลเดอร์ firmware ไม่ได้" (`EACCES`) `setup-vps.sh` ตั้งให้ตอนติดตั้ง และ `update-remote.sh` ตรวจแก้ให้ทุกครั้งที่อัปเดต ถ้ายังไม่ได้ให้รัน `sudo chown 1000:1000 /opt/rmutt/firmware` ทำไมเป็นตัวเลข: ในเครื่อง Ubuntu อาจไม่มีผู้ใช้ชื่อ `node` แต่สิทธิ์ไฟล์ของ Linux เทียบกันด้วยเลข uid ไม่ใช่ชื่อ

## อธิบายทีละไฟล์

### กลุ่ม A: สคริปต์ฝั่ง Windows สำหรับ local dev

#### `run_all.ps1` (329 บรรทัด)

- **หน้าที่:** เปิดระบบ local ทั้งชุดด้วยคำสั่งเดียว
- **พารามิเตอร์:** `-BrokerHost <IP>` (บังคับ LAN IP ถ้าไม่ใส่จะหาเอง), `-SkipFlutter` (ไม่เปิดแอป), `-InitDb` (รัน `db:init` สร้างตาราง ใช้ครั้งแรกเท่านั้น), `-Server` (ไม่เปิดอะไรในเครื่อง ตรวจเซิร์ฟเวอร์จริง), `-ServerUrl` (ค่าเริ่มต้น `https://rmutt-energy.duckdns.org`)
- **ฟังก์ชันข้างใน:** `Write-Step` (พิมพ์หัวข้อสีฟ้า), `Get-DotEnv` (อ่าน `.env` เป็น hashtable), `Set-DotEnvValue` (แก้/เพิ่มค่าใน `.env` โดยไม่แตะบรรทัดอื่น), `Get-LanIPv4` (หา IP ของการ์ดเครือข่ายที่ต่อเน็ตอยู่และมี gateway ตัด `127.*` กับ `169.254.*`)
- **ใครเรียก/เรียกใคร:** ผู้ใช้เรียกเอง; ภายในเรียก `docker`, `npm run db:*`, `node scripts/doctor.js --fix`, `docker compose` ใน `mqtt/`, `npm start`, `flutter run` ต้องมี `mqtt/.env` ที่ `mqtt\setup_mqtt.ps1` สร้างไว้ก่อน
- **ทำไมแยกเป็นไฟล์เดียว:** ลำดับมีผล (ต้องมี DB ก่อน migrate, ต้องรู้ IP ก่อนเขียน `.env`, ต้องมี broker ก่อน Backend) การให้คนจำเองทำให้ลืมขั้นบ่อย โดยเฉพาะ "IP เครื่องเปลี่ยน → `MQTT_URL` เก่า → ESP32 ต่อไม่ได้"
- **ข้อควรรู้:** หัวข้อ `Write-Step` ในโค้ดนับ "1/6, 2/6, 3/7 …" ไม่สม่ำเสมอ (เติมขั้นทีหลังแต่ไม่ได้แก้เลข) ที่จริงมี 7 ขั้น

#### `check_system.ps1` (40 บรรทัด)

ตรวจ 3 ขั้น: (1) container `rmutt-mosquitto` ต้อง `healthy` แล้วเรียก `mqtt/test_mqtt.ps1` (2) `GET /api/health` ต้องได้ `status = ok` (3) `mqtt.connected` ต้องเป็น `true` พังตรงไหน `throw` ตรงนั้น ไม่แก้อะไรเลย (อ่านอย่างเดียว) จึงรันซ้ำได้ปลอดภัย ต่างจาก `run_all.ps1` ที่เปลี่ยน `.env`

#### `diagnose.ps1` (144 บรรทัด)

พารามิเตอร์ `-ListenSeconds` (ค่าเริ่มต้น 20) ใช้ `$ErrorActionPreference = 'Continue'` ต่างจากสคริปต์อื่นโดยตั้งใจ เพราะเป็นเครื่องมือสำรวจ ต้องรันครบทุกขั้นแม้ขั้นหนึ่งพัง ผลลัพธ์ 7 ขั้น: (1) `docker ps` ชื่อ `rmutt` (2) เทียบ LAN IP ปัจจุบันกับ host ใน `MQTT_URL` ถ้าไม่ตรงเตือนสีแดง (3) `/api/health` + `lastError` (4) `node scripts/doctor.js` (5) กฎ Windows Firewall ขาเข้า TCP 1883 พร้อมคำสั่งสร้างกฎ (6) log broker 40 บรรทัด (7) `mosquitto_sub -t 'rmutt/#' -W <วินาที>` ดักฟังข้อความจริง: มีข้อความ = ESP32 ถึง broker แล้ว, เงียบ = ยังต่อไม่ได้ ตอนท้ายบอกให้ส่งผลทั้งหมดไปให้ผู้ช่วยดู

#### `db-tunnel.ps1` (95 บรรทัด)

พารามิเตอร์ `-Server`, `-User`, `-LocalPort` (3307) ใช้ `Get-RmuttServer` อ่านค่าเซิร์ฟเวอร์ → `ssh` ไปอ่าน `DB_PASSWORD`/`DB_USER` จาก `/opt/rmutt/.env` (ถ้าไม่มี `DB_USER` ใช้ `root` เพราะ `.env` รุ่นเก่า) → `Set-Clipboard` (รหัสไม่ถูกพิมพ์ขึ้นจอ) → เปิดหน้าต่าง PowerShell ใหม่รัน `ssh -N -L 3307:127.0.0.1:3306` → ทดสอบพอร์ตซ้ำสูงสุด 6 ครั้ง → พิมพ์ค่าที่ต้องกรอกใน HeidiSQL (ให้เอาติ๊ก SSH tunnel ของ HeidiSQL ออก เพราะเราทำ tunnel เองแล้ว) **ทำไมไม่เปิดพอร์ต 3306 ออกอินเทอร์เน็ต:** ฐานข้อมูลคือสิ่งที่อันตรายที่สุดถ้าถูกเดารหัส จึงผูกไว้ `127.0.0.1` และใช้ SSH (มีการยืนยันตัวตนและเข้ารหัสอยู่แล้ว) เป็นประตูเดียว

### กลุ่ม B: สร้างแอปและกุญแจเซ็น

#### `build-apk.ps1` (103 บรรทัด)

พารามิเตอร์ `-ApiBaseUrl` (ว่าง = ใช้ `https://<domain>/api` จาก `server.config.json`), `-Org` (`th.ac.rmutt.cpe`), `-DebugApk` (สวิตช์ ตั้งชื่อ `DebugApk` เพราะ `-Debug` ชนกับพารามิเตอร์สงวนของ PowerShell) 4 ขั้น: ตรวจ/สร้างโฟลเดอร์ `android` ด้วย `flutter create --platforms=android` → เติมสิทธิ์ INTERNET, BLUETOOTH_SCAN, BLUETOOTH_CONNECT, ACCESS_FINE_LOCATION (`maxSdkVersion=30`) ใน `AndroidManifest.xml` ถ้ายังไม่มี → `flutter pub get` + `flutter build apk` (release ต้องเซ็นด้วย keystore) → รายงานพาธและขนาดไฟล์ ถ้าไม่มี `android/key.properties` จะเตือนว่าจะเซ็นด้วย debug key

#### `BUILD-ANDROID.bat` (18 บรรทัด)

ไฟล์ batch สำหรับคนที่ไม่อยากเปิด PowerShell: `chcp 65001` ตั้งหน้าโค้ด UTF-8, `cd /d "%~dp0"` ไปโฟลเดอร์ของไฟล์, ถ้าไม่มี `android\key.properties` เรียก `create-keystore.ps1` แล้วเรียก `build-apk.ps1 -ApiBaseUrl https://rmutt-energy.tailb292b4.ts.net/api` (URL ฝังตายตัวในไฟล์นี้ ชี้โดเมน Tailscale) แล้วเปิด Explorer ที่ไฟล์ APK ใช้ `-NoProfile -ExecutionPolicy Bypass` เพื่อให้รันได้แม้ Windows ห้ามรันสคริปต์ `.ps1` ตามค่าเริ่มต้น

#### `create-keystore.ps1` (71 บรรทัด)

พารามิเตอร์ `-KeystorePath` (ค่าเริ่มต้น `~/rmutt-save-energy-upload.jks` **อยู่นอกโฟลเดอร์โปรเจกต์** กันหลุดไปกับ zip/git), `-Alias` (`rmutt-upload`) ปฏิเสธถ้ามี `key.properties` แล้ว, หา `keytool` 3 ที่ (JAVA_HOME, PATH, JDK ใน Android Studio), อ่านรหัสแบบ `SecureString` (ไม่โชว์บนจอ) ขั้นต่ำ 8 ตัว, สร้างคีย์ RSA 2048 บิต อายุ 10000 วัน (~27 ปี), เขียน `android/key.properties` (4 บรรทัด)

#### `change-keystore-password.ps1` (102 บรรทัด)

เปลี่ยนรหัส (ไม่เปลี่ยนกุญแจ จึงอัปเดตทับแอปเดิมได้) ต้องยาว ≥ 12 ตัวและไม่ใช่ตัวเลขล้วน พิมพ์สองรอบ **สำรอง `.jks` เป็น `.bak-<เวลา>` ก่อน** แล้วเปลี่ยน `-keypasswd` (รหัสของกุญแจ) ตามด้วย `-storepasswd` (รหัสของไฟล์) ทุกขั้นที่พังจะคืนไฟล์สำรองกลับ และตรวจว่ารหัสใหม่เปิดไฟล์ได้จริงก่อนเขียน `key.properties` ใหม่ ตอนท้ายเตือนให้ลบไฟล์ `.bak` เพราะยังเปิดได้ด้วยรหัสเก่า

### กลุ่ม C: ค่าเซิร์ฟเวอร์ร่วม

#### `deploy/ServerConfig.ps1` (46 บรรทัด) และ `server.config.example.json`

ไฟล์ที่ถูก "dot-source" (`. (Join-Path $PSScriptRoot 'ServerConfig.ps1')` จุดนำหน้า = โหลดฟังก์ชันเข้ามาในสคริปต์ปัจจุบัน) มีฟังก์ชันเดียว `Get-RmuttServer -HostOverride -UserOverride -PortOverride` คืน object ที่มี `Host, User (ค่าเริ่มต้น root), Port (22), Domain (ไม่มี = ใช้ host), Target (user@host), SshArgs (-p), ScpArgs (-P), RemoteDir (/opt/rmutt), ApiBase (https://domain/api)` ถ้าไม่มี host เลยจะ `throw` พร้อมบอกให้คัดลอกไฟล์ตัวอย่าง **ทำไม:** ถ้าเขียนที่อยู่เซิร์ฟเวอร์ในทุกสคริปต์ ย้ายเครื่องต้องแก้ 6 ไฟล์ และที่อยู่จะหลุดขึ้น git ไฟล์ `server.config.json` จึงอยู่ใน `.gitignore` และ `upload.ps1` ก็กรองไม่ส่งขึ้นเซิร์ฟเวอร์ (`server.config*`)

### กลุ่ม D: สคริปต์ deploy ฝั่ง Windows

#### `deploy/upload.ps1` (80 บรรทัด)

ใช้ครั้งแรก (หรือ `-BackendOnly` ตอนแก้เฉพาะ backend) ขั้น: `ssh mkdir -p /opt/rmutt/backend /opt/rmutt/www` → ส่งทุกอย่างใน `deploy/` ยกเว้น `www`, ไฟล์ `.ps1`, `.tmp`, `.env*`, `server.config*` (ไม่ส่ง `.ps1` เพราะใช้บน Windows อย่างเดียว ไม่ส่งความลับ) → ส่ง `webapp/` ไปที่ `www/` → ส่งซอร์ส backend เฉพาะ `src, scripts, database, package.json, package-lock.json, .dockerignore` (ไม่ส่ง `node_modules` และ `.env` ของเครื่อง dev) → `cp backend.Dockerfile backend/Dockerfile && chmod +x *.sh` แล้วบอกขั้นถัดไป `sudo bash init-env.sh`

#### `deploy/update-server.ps1` (133 บรรทัด) และ `deploy/update-remote.sh` (179 บรรทัด)

คู่ "ผู้สั่ง/ผู้ทำ" สำหรับอัปเดตทุกครั้งหลังแก้โค้ด (เจาะโค้ดด้านล่าง) พารามิเตอร์ `-Server`, `-User`, `-SkipUpload` (รันขั้นบนเซิร์ฟเวอร์ซ้ำอย่างเดียว), `-SkipWeb` (ไม่อัปโหลดเว็บ) ขั้น 5 ของ `update-remote.sh` โหลด Caddyfile ใหม่ **และสร้างกล่อง `tailscale` ใหม่** เพื่อให้ `tailscale-serve.json` (เว็บ 443 + MQTT 8443) ที่เพิ่งอัปโหลดมีผล ก่อนขั้น 1 (เพิ่ม 14 ต.ค. 2569) ตรวจว่าโฟลเดอร์ `firmware` เป็นของ uid 1000 ถ้าไม่ใช่จะ `chown` ให้ (ไม่ได้ก็แค่เตือน)

#### `deploy/deploy-web.ps1` (56 บรรทัด)

อัปโหลดเฉพาะ `webapp/` ไป `/opt/rmutt/www` ไม่ build ไม่รีสตาร์ท (เร็วกว่ามาก) เพราะ Caddy อ่านไฟล์จากดิสก์ทุกคำขอ ขั้น: สร้าง `www.new` ว่าง → `scp` ขึ้นไป → `find www -mindepth 1 -delete && cp -a www.new/. www/` (ลบ "ข้างใน" แล้วก๊อป "เข้าไปใน" โฟลเดอร์เดิม ไม่ใช่ `mv` สลับโฟลเดอร์) **ทำไม:** Docker bind mount ผูกโฟลเดอร์ตาม inode ถ้าสลับชื่อโฟลเดอร์ Caddy จะยังเห็นโฟลเดอร์เก่าที่ถูกลบ แล้วตอบ 404 ทุกหน้าแบบเงียบ ๆ และที่ลบไฟล์เก่าก่อนก็เพื่อไม่ให้ JavaScript เก่าที่ถูกลบจากโปรเจกต์แล้วยังค้างบนเซิร์ฟเวอร์

### กลุ่ม E: สคริปต์บนเซิร์ฟเวอร์ (bash)

#### `deploy/setup-vps.sh` (116 บรรทัด)

ติดตั้งเครื่องใหม่ครั้งเดียว 7 ขั้น (เจาะโค้ดด้านล่าง) พารามิเตอร์ `--firewall` (ตั้ง ufw เอง) ขั้น 6 ตั้งเจ้าของโฟลเดอร์ `firmware` เป็น uid 1000 ด้วย (เพิ่ม 14 ต.ค. 2569)

#### `deploy/init-env.sh` (157 บรรทัด)

สร้าง `.env` และบัญชี MQTT dynsec (เจาะโค้ดด้านล่าง)

#### `deploy/sync-mqtt-cert.sh` (56 บรรทัด)

ก๊อปใบรับรองจาก Caddy ให้ Mosquitto (เจาะโค้ดด้านล่าง) เรียกโดย cron ทุกวัน 03:10, `update-remote.sh` และมือ

#### `deploy/fix-mqtt-permissions.sh` (48 บรรทัด)

ใช้เมื่อ `rmutt-mqtt` วน Restarting (มักเพราะ Mosquitto ในคอนเทนเนอร์รัน uid 1883 อ่านไฟล์ไม่ได้) ขั้น: แสดง log 15 บรรทัด → แสดงสิทธิ์ไฟล์ก่อนแก้ → เช็กว่ามีไฟล์ครบ 4 ไฟล์ (`mosquitto.conf`, `dynamic-security.json`, `fullchain.pem`, `privkey.pem`) ถ้าขาดบอกวิธี (ขาดใบรับรอง → `sync-mqtt-cert.sh`, ขาด dynsec → `init-env.sh`) แล้วออก → `chown -R 1883:1883`, `chmod 700` โฟลเดอร์ data, `600` ไฟล์ลับ (dynsec, privkey), `644` ไฟล์ที่อ่านได้ → `docker compose restart mqtt` → แสดงสถานะ ตั้งใจ "ไม่แก้ถ้าไฟล์ไม่ครบ" เพราะสิทธิ์ไม่ใช่สาเหตุ

#### สคริปต์ดูแลระบบที่เกี่ยวข้อง (นอกรายการหลักแต่ถูกเรียกใช้)

- `deploy/backup-db.sh` (58 บรรทัด): สำรองฐานข้อมูล อธิบายในหัวข้อ "การดูแลระบบ"
- `deploy/seed-admin.sh` (59 บรรทัด): สร้าง/รีเซ็ตแอดมิน ส่งรหัสผ่านเข้า `backend node scripts/seed-admin.js --password-stdin` ผ่าน stdin (`printf '%s' "$PASSWORD" | docker compose exec -T ...`) แล้วล้าง `SEED_ADMIN_PASSWORD` ใน `.env` ด้วย `sed -i` **ทำไมใช้ stdin:** ถ้าส่งเป็นอาร์กิวเมนต์ รหัสจะโผล่ใน `ps` และ history ของ shell
- `deploy/db-view.sh` (92 บรรทัด): ดูข้อมูลแบบอ่านอย่างเดียวจากเทอร์มินัล

### กลุ่ม F: GitHub Actions, git และ editor

#### `.github/workflows/test.yml` (36 บรรทัด, เพิ่ม 9 ต.ค. 2569)

ระบบทดสอบอัตโนมัติ (CI = Continuous Integration) ของแอป Flutter ทุกครั้งที่ push โค้ดขึ้น GitHub และไฟล์ที่เปลี่ยนอยู่ใน `lib/**`, `test/**`, `pubspec.yaml`, `pubspec.lock` หรือตัว workflow เอง GitHub จะรันให้บนเครื่อง Linux (`ubuntu-latest`) ซึ่งไม่กินโควตานาทีแพงแบบ macOS กดรันเองก็ได้ (`workflow_dispatch`)

**ไฟล์ `.github/workflows/test.yml` บรรทัด 9–36**

```yaml:9
jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true
      - run: flutter pub get
      # ผลลัพธ์ส่งออกเป็น annotation ด้วย จะได้เห็นในหน้า Summary โดยไม่ต้องเปิด log
      - name: flutter analyze
        run: |
          set -o pipefail
          flutter analyze --no-fatal-infos --no-fatal-warnings 2>&1 | tee analyze.txt || {
            tail -40 analyze.txt | while IFS= read -r line; do echo "::error::$line"; done
            exit 1
          }
          grep -E ' warning • ' analyze.txt | head -20 | while IFS= read -r line; do echo "::warning::$line"; done || true
      - name: flutter test
        if: always()
        run: |
          set -o pipefail
          flutter test --reporter expanded 2>&1 | tee test.txt || {
            grep -E '\[E\]|Expected:|Actual:|Error:|error:' test.txt | head -40 | while IFS= read -r line; do echo "::error::$line"; done
            exit 1
          }
```

| บรรทัด | ความหมาย |
|---|---|
| 11–12 | ใช้เครื่อง Linux ของ GitHub ถ้าเกิน 20 นาทีให้ยกเลิก กันงานค้างกินโควตา |
| 14–18 | ดึงโค้ด (`checkout`) แล้วติดตั้ง Flutter รุ่น stable พร้อมเก็บแคชให้รอบหน้าเร็วขึ้น |
| 19 | `flutter pub get` ติดตั้งแพ็กเกจตาม `pubspec.lock` |
| 21–27 | `flutter analyze` ตรวจโค้ดแบบไม่ต้องรัน (static analysis) ตามกฎใน `analysis_options.yaml` ข้อความระดับ info/warning ไม่ทำให้ล้ม แต่ error ทำให้ล้ม `tee` เก็บผลลงไฟล์พร้อมแสดงบนจอ ถ้าล้มจะส่ง 40 บรรทัดสุดท้ายเป็น `::error::` (annotation ที่ GitHub แสดงในหน้า Summary) และส่ง warning 20 รายการแรกเป็น `::warning::` |
| 23 | `set -o pipefail` ให้คำสั่งทั้งท่อ (pipe) ล้มเมื่อ `flutter analyze` ล้ม ไม่งั้น `tee` ที่สำเร็จจะกลบผลล้มเหลว |
| 27 | `\|\| true` ท้ายบรรทัด ทำให้ไม่ล้มเมื่อไม่มี warning เลย (`grep` ไม่เจออะไรจะคืนค่าผิดพลาด) — แก้ใน commit ล่าสุดวันที่ 9 ต.ค. |
| 28–29 | `if: always()` รันเทสต์ต่อแม้ขั้น analyze ล้ม จะได้เห็นผลทั้งสองอย่างในรอบเดียว |
| 31–35 | `flutter test --reporter expanded` แสดงชื่อเทสต์ทีละตัว ถ้าล้มดึงบรรทัดที่มี `Expected:`/`Actual:`/`Error:` มาเป็น annotation |

> [!WHY]
> เดิมการทดสอบต้องรันเองบนเครื่อง ซึ่งลืมได้ CI ทำให้ทุกการแก้ถูกตรวจอัตโนมัติ ถ้าใครแก้แล้วทำของเดิมพัง จะเห็นเครื่องหมาย ✗ สีแดงบน GitHub ทันที ตัวอย่างจริง: commit วันที่ 9 ต.ค. ที่เปลี่ยนวันที่บนกราฟเป็นแบบไทย ทำให้ `energy_usage_chart_test.dart` ที่ยังคาดรูปแบบวันที่แบบเดิมล้ม CI จับได้ แล้วจึงแก้เทสต์ให้คาดวันที่แบบไทย

#### `.github/workflows/build-android.yml` (82 บรรทัด, เพิ่ม 9 ต.ค. 2569)

Workflow ชื่อ "Build Android (APK)" สร้างไฟล์ติดตั้ง Android บนเครื่อง Linux ของ GitHub **โดยไม่ต้องลง Flutter หรือ Android SDK ในเครื่องตัวเอง** ทำงานคู่กับ `build-apk.ps1` (สคริปต์เดิมที่ build บนเครื่อง Windows) ไม่ได้มาแทน คอมเมนต์หัวไฟล์อธิบายวิธีใช้: แท็บ Actions → "Build Android (APK)" → Run workflow

**ไฟล์ `.github/workflows/build-android.yml` บรรทัด 11–24**

```yaml:11
name: Build Android (APK)

on:
  workflow_dispatch:
    inputs:
      api_base_url:
        description: ที่อยู่ API ที่แอปจะใช้ (ต้องเข้าได้จากอินเทอร์เน็ต)
        required: true
        default: https://rmutt-energy.tailb292b4.ts.net/api

jobs:
  build-android:
    runs-on: ubuntu-latest
    timeout-minutes: 40
```

| บรรทัด | อธิบาย |
|---|---|
| 13–19 | รันเมื่อกดเองเท่านั้น (`workflow_dispatch`) และถามที่อยู่ API ก่อนรัน ค่าเริ่มต้นคือที่อยู่ Tailscale Funnel ของเซิร์ฟเวอร์จริง (แบบเดียวกับ `build-ios.yml`) |
| 23 | เครื่อง Ubuntu ของ GitHub (ถูกกว่า macOS และ build Android ได้) |
| 24 | ถ้าเกิน 40 นาทีให้ยกเลิก กันงานค้างกินโควตา |

**ไฟล์ `.github/workflows/build-android.yml` บรรทัด 26–59**

```yaml:26
    steps:
      - name: ดึงโค้ด
        uses: actions/checkout@v4

      - name: ติดตั้ง Java 17
        uses: actions/setup-java@v5
        with:
          distribution: temurin
          java-version: '17'

      - name: ติดตั้ง Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: เตรียมกุญแจเซ็นแอป
        env:
          KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          if [ -n "$KEYSTORE_BASE64" ] && [ -n "$KEY_PASSWORD" ]; then
            echo "$KEYSTORE_BASE64" | base64 -d > "$RUNNER_TEMP/upload.jks"
            {
              echo "storePassword=$KEY_PASSWORD"
              echo "keyPassword=$KEY_PASSWORD"
              echo "keyAlias=rmutt-upload"
              echo "storeFile=$RUNNER_TEMP/upload.jks"
            } > android/key.properties
            echo "SIGN_SUFFIX=" >> "$GITHUB_ENV"
          else
            echo "::warning::ยังไม่ได้ตั้ง Secrets ของกุญแจ จะเซ็นด้วย debug key (ใช้ทดสอบเท่านั้น ห้ามแจก)"
            echo "SIGN_SUFFIX=-DEBUG-KEY" >> "$GITHUB_ENV"
          fi
```

| บรรทัด | อธิบาย |
|---|---|
| 30–34 | Gradle ของ Android ต้องใช้ Java ติดตั้ง JDK 17 ของ Temurin (Eclipse) commit `ffd129c` อัปเดต `setup-java` จาก v4 เป็น **v5** |
| 36–40 | ติดตั้ง Flutter รุ่น stable และเปิด cache ให้รอบหน้าเร็วขึ้น |
| 43–45 | ดึงความลับจาก **GitHub Secrets** มาเป็นตัวแปรสภาพแวดล้อม (ไม่เขียนลงไฟล์ workflow ที่ทุกคนเห็น) |
| 47 | `-n` = "ไม่ว่าง" ตั้ง Secrets ครบทั้งสองตัวจึงใช้กุญแจจริง |
| 48 | Secrets เก็บได้แต่ข้อความ จึงเก็บไฟล์ `.jks` (ไบนารี) เป็น **base64** แล้วถอดกลับเป็นไฟล์ในโฟลเดอร์ชั่วคราวของ runner (`$RUNNER_TEMP`) |
| 49–54 | เขียน `android/key.properties` รูปแบบเดียวกับที่ `create-keystore.ps1` สร้างบนเครื่อง ใช้รหัสเดียวทั้ง store และ key และ alias `rmutt-upload` ปีกกา `{ ... } > ไฟล์` รวมผล `echo` ทั้งหมดเขียนลงไฟล์ครั้งเดียว |
| 55 | `>> "$GITHUB_ENV"` คือวิธีส่งตัวแปรไปให้ **ขั้นถัดไป** ของ job เดียวกัน (แต่ละ step เป็น shell คนละตัว) กุญแจจริงต่อท้ายชื่อไฟล์ว่าง |
| 57–58 | ไม่มี Secrets: ขึ้นคำเตือนสีเหลืองในหน้า Actions (`::warning::`) แล้วต่อท้ายชื่อไฟล์ `-DEBUG-KEY` ให้เห็นชัด build ยังทำต่อได้ด้วย debug key ที่ Flutter สร้างให้ |

**ไฟล์ `.github/workflows/build-android.yml` บรรทัด 61–82**

```yaml:61
      - name: ติดตั้งแพ็กเกจ
        run: flutter pub get

      - name: Build APK
        # ส่งผ่าน env กันค่า input ถูกตีความเป็นคำสั่ง shell
        env:
          API_BASE_URL: ${{ inputs.api_base_url }}
        run: flutter build apk --release --dart-define=API_BASE_URL="$API_BASE_URL"

      - name: ตั้งชื่อไฟล์
        run: |
          VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | tr '+' '-')
          cp build/app/outputs/flutter-apk/app-release.apk "RMUTT-Energy-${VERSION}${SIGN_SUFFIX}.apk"
          ls -lh *.apk
          rm -f android/key.properties

      - name: เก็บไฟล์ให้ดาวน์โหลด
        uses: actions/upload-artifact@v4
        with:
          name: RMUTT-Energy-Android
          path: "*.apk"
          retention-days: 14
```

| บรรทัด | อธิบาย |
|---|---|
| 65–68 | build แบบ release และฝังที่อยู่ API ด้วย `--dart-define` ค่า input ส่งผ่าน `env` ก่อนแล้วอ้างเป็นตัวแปร shell (`"$API_BASE_URL"`) **กัน shell injection** หลักเดียวกับ `build-ios.yml` |
| 72 | อ่านเวอร์ชันจาก `pubspec.yaml` เช่น `version: 3.16.0+32` → `awk` เอาคำที่ 2 → `tr '+' '-'` ได้ `3.16.0-32` (เครื่องหมาย `+` ในชื่อไฟล์บางระบบมีปัญหา) |
| 73 | ตั้งชื่อเช่น `RMUTT-Energy-3.13.1-31.apk` หรือ `RMUTT-Energy-3.13.1-31-DEBUG-KEY.apk` |
| 75 | ลบ `key.properties` ที่มีรหัสผ่านทิ้งทันทีหลังใช้ (runner ถูกทำลายหลังจบงานอยู่แล้ว แต่ลบไว้ก่อนเป็นนิสัยที่ดี) |
| 77–82 | อัปโหลดไฟล์ APK เป็น artifact ชื่อ `RMUTT-Energy-Android` ดาวน์โหลดได้จากหน้าผลการรัน 14 วัน |

> [!WARN]
> **ห้ามแจกไฟล์ `-DEBUG-KEY`** (คอมเมนต์หัวไฟล์เตือนไว้) Android ยอมให้ติดตั้งทับแอปเดิมได้เฉพาะเมื่อลายเซ็นตรงกัน ถ้าผู้ใช้ติดตั้งไฟล์ที่เซ็นด้วย debug key ไปแล้ว วันหน้าจะอัปเดตด้วยไฟล์ที่เซ็นกุญแจจริงไม่ได้ ต้องถอนแอปออกก่อน (ข้อมูลในแอปหาย)

> [!TIP]
> วิธีตั้ง Secrets: บนเครื่อง Windows แปลงไฟล์กุญแจเป็น base64 ด้วย PowerShell `[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\rmutt-save-energy-upload.jks")) | Set-Clipboard` (ไฟล์ที่ `create-keystore.ps1` สร้างไว้นอกโฟลเดอร์โปรเจกต์ alias `rmutt-upload` ตรงกับที่ workflow ใช้) แล้วนำข้อความไปใส่ใน GitHub → Settings → Secrets and variables → Actions → `ANDROID_KEYSTORE_BASE64` และใส่รหัสผ่านที่ `ANDROID_KEY_PASSWORD` **ห้าม** commit ไฟล์ `.jks` หรือรหัสลง git

| | `build-apk.ps1` (บนเครื่อง) | `build-android.yml` (บน GitHub) |
|---|---|---|
| ต้องลงอะไรในเครื่อง | Flutter, Android SDK, Java | ไม่ต้อง (มีแค่เว็บเบราว์เซอร์) |
| กุญแจเซ็น | `android/key.properties` + `.jks` ในเครื่อง | GitHub Secrets (base64) |
| ไม่มีกุญแจ | หยุดและบอกให้สร้าง (หรือ `-DebugApk`) | เซ็นด้วย debug key และติดป้ายชื่อไฟล์ |
| เติมสิทธิ์ AndroidManifest | สคริปต์เติมให้ | ใช้ manifest ที่อยู่ใน repo ตามที่ commit ไว้ |
| ผลลัพธ์ | ไฟล์ในโฟลเดอร์ `build/` | artifact ดาวน์โหลดจากหน้า Actions 14 วัน |

#### `.github/workflows/build-ios.yml` (90 บรรทัด)

Workflow ชื่อ "Build iOS (IPA ไม่เซ็น)" ทริกเกอร์ `workflow_dispatch` (กดรันเองในแท็บ Actions เท่านั้น เพราะนาที macOS กินโควตาฟรีมากกว่า Linux) พร้อม **input `api_base_url`** (บังคับกรอก ค่าเริ่มต้น `https://rmutt-energy.tailb292b4.ts.net/api` คำอธิบาย "ที่อยู่ API ที่แอปจะใช้ ต้องเข้าได้จากอินเทอร์เน็ต") `runs-on: macos-latest`, `timeout-minutes: 45` ขั้นตอน (steps):

1. `actions/checkout@v4` ดึงโค้ด
2. `subosito/flutter-action@v2` ติดตั้ง Flutter (channel stable, เปิด cache)
3. สร้างโฟลเดอร์ `ios/` ถ้าไม่มี (`flutter create --platforms=ios --org th.ac.rmutt.cpe --project-name cpe_air_remote .`) เพราะโปรเจกต์ไม่เก็บ `ios/` ใน git; ต้องระบุ `--project-name` เพราะชื่อ repo อาจมีขีด (Dart ไม่รับ)
4. ใช้ `plutil` ตั้ง `Info.plist`: ข้อความขอสิทธิ์บลูทูธ (`NSBluetoothAlwaysUsageDescription`, `NSBluetoothPeripheralUsageDescription`) และชื่อแอป `RMUTT Energy` — ถ้าไม่มีข้อความขอสิทธิ์บลูทูธ iOS จะปิดแอปทันทีที่เริ่มสแกน
5. **ใส่ไอคอนแอป** (ขั้น "ใส่ไอคอนแอป RMUTT Energy") `flutter create` ใส่ไอคอน Flutter มาให้ จึงวนทุกไฟล์ `.png` ใน `ios/Runner/Assets.xcassets/AppIcon.appiconset` อ่านความกว้างเดิมด้วย `sips -g pixelWidth` แล้วใช้ `sips -z` ย่อภาพต้นฉบับ `assets/app_icon/ios-1024.png` (1024×1024 พื้นทึบเต็มกรอบ เพราะ iOS ตัดมุมมนเองและไม่รับภาพโปร่งใส) ให้ได้ขนาดนั้นแล้วเขียนทับ (`sips` เป็นเครื่องมือจัดการภาพที่มากับ macOS)
6. `flutter pub get`
7. `flutter build ios --release --no-codesign --dart-define=API_BASE_URL="$API_BASE_URL"` (ต้อง release เพราะแอป debug บน iOS เปิดจากหน้าโฮมเองไม่ได้ และ `--no-codesign` เพราะไม่มีใบรับรอง Apple ใน runner) ค่า input ส่งผ่าน `env: API_BASE_URL: ${{ inputs.api_base_url }}` ก่อน แล้วอ้างเป็นตัวแปร shell `"$API_BASE_URL"` เพื่อกัน shell injection (ถ้าเขียน `${{ inputs.api_base_url }}` ลงในคำสั่งตรง ๆ GitHub จะแทนข้อความเข้าไปก่อน shell อ่าน คนกรอกใส่เครื่องหมายคำสั่งแทรกได้) ค่านี้ตรงกับที่แอปอ่านด้วย `String.fromEnvironment('API_BASE_URL')` ใน `lib/config/api_config.dart`
8. แพ็ก `.ipa` = zip ของโฟลเดอร์ `Payload/Runner.app` ตั้งชื่อ `RMUTT-Energy-<version>-unsigned.ipa` (ดึง version จาก `pubspec.yaml`)
9. `actions/upload-artifact@v4` เก็บไว้ 14 วันให้ดาวน์โหลด

จากนั้นใช้ Sideloadly บน Windows เซ็นด้วย Apple ID ฟรีแล้วลง iPhone (ไฟล์เซ็นด้วย Apple ID ฟรีมีอายุสั้น ต้องเซ็นใหม่เป็นระยะ ตามข้อจำกัดของ Apple)

> [!WHY]
> ใช้ Actions แทนซื้อ Mac: ได้เครื่อง macOS ชั่วคราวฟรี ตั้งให้ทำงานตามสั่งเท่านั้นเพื่อประหยัดโควตา และไม่เก็บ `ios/` ใน git เพื่อไม่ให้ repo มีไฟล์ที่ generate ได้

#### `.gitignore` (49 บรรทัด)

กลุ่มที่กัน: (1) ไฟล์ generate ของ Flutter (`.dart_tool/`, `build/`, `coverage/`) (2) IDE (`.idea/`, `.vscode/`, `*.iml`) (3) ไฟล์เครื่อง (`android/local.properties`, `.DS_Store`) (4) **ความลับ broker local** `mqtt/.env`, `mqtt/config/passwords`, `mqtt/config/acl`, `mqtt/data/*`, `mqtt/log/*` (เว้น `.gitkeep` ด้วย `!`) (5) **ความลับ deploy** `deploy/server.config.json`, `deploy/.env`, `deploy/.env.*` (เว้น `.env.example`), `backend/.env.*` (เว้น `.env.example`) (6) **กุญแจเซ็น APK** `android/key.properties`, `*.jks`, `*.keystore` (7) ไฟล์ชั่วคราว `*.bak-*` (ไฟล์สำรองจาก `init-env.sh`/`change-keystore-password.ps1`), `_patch/`, `_to_delete/` มีหมายเหตุว่า `pubspec.lock` **ต้อง commit** เพื่อให้ทุกเครื่อง build ได้แพ็กเกจรุ่นเดียวกัน (สังเกตว่า `backend/.env` ตรง ๆ ไม่ได้อยู่ในรายการ มีแต่ `backend/.env.*` ควรตรวจว่าไม่เคย commit)

> [!WARN]
> `.gitignore` กันได้เฉพาะไฟล์ที่ **ยังไม่เคย** ถูก commit ถ้าเคยเผลอ commit ความลับแล้ว ต้องเปลี่ยนรหัสนั้นทิ้ง (ลบไฟล์ทีหลังไม่พอ ประวัติ git ยังมี)

#### `.vscode/settings.json` (2 บรรทัด)

มีค่าเดียว `cmake.sourceDirectory` ชี้โฟลเดอร์ `windows` ของโปรเจกต์ (พาธเครื่องผู้เขียน `C:/Users/rapee/Downloads/...`) ให้ส่วนขยาย CMake ใน VS Code รู้ว่าโค้ด C++ ของ Flutter Windows อยู่ไหน ไม่มีผลกับระบบ และโฟลเดอร์ `.vscode/` อยู่ใน `.gitignore` อยู่แล้ว (ไฟล์นี้จึงไม่ควรถูกใช้ร่วมกับคนอื่น)

## เจาะโค้ดทีละบรรทัด

### 1. `deploy/setup-vps.sh` — ส่วนหัวและตรวจสิทธิ์

**ไฟล์ `deploy/setup-vps.sh` บรรทัด 8–22**

```bash:8
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if [ "$(id -u)" -ne 0 ]; then
  echo "ต้องรันด้วย sudo" >&2
  exit 1
fi

WITH_FIREWALL=0
[ "${1:-}" = "--firewall" ] && WITH_FIREWALL=1
APP_DIR=/opt/rmutt
# ผู้ใช้ที่สั่ง sudo จะได้ใช้ docker และจัดการ /opt/rmutt ได้โดยไม่ต้องเป็น root
OWNER="${SUDO_USER:-root}"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 8 | `set -euo pipefail` | หยุดเมื่อคำสั่งพัง / ตัวแปรไม่ถูกตั้ง / ท่อพัง (ดูความรู้พื้นฐานข้อ 4) การติดตั้งที่พังครึ่งทางแล้วไปต่อ จะได้เครื่องที่ค้างสภาพแปลก ๆ |
| 9 | `export DEBIAN_FRONTEND=noninteractive` | บอก `apt` อย่าเด้งหน้าจอถามคำถาม สคริปต์จะได้ไม่ค้างรอคนกด |
| 11 | `$(id -u)` | `$( )` รันคำสั่งแล้วเอาผลลัพธ์มาใช้; `id -u` คือเลข uid ของผู้รัน root = 0 |
| 12 | `echo "..." >&2` | `>&2` ส่งข้อความไปช่อง stderr (ช่องข้อผิดพลาด) ไม่ปนกับผลลัพธ์ปกติ |
| 17 | `[ "${1:-}" = "--firewall" ] && WITH_FIREWALL=1` | `${1:-}` = อาร์กิวเมนต์แรก (ว่างถ้าไม่มี ไม่งั้น `-u` จะ error); `&&` = ทำอันขวาเมื่ออันซ้ายจริง |
| 20 | `OWNER="${SUDO_USER:-root}"` | ตอนรัน `sudo` ตัวแปร `SUDO_USER` เก็บชื่อผู้ใช้จริงที่สั่ง ถ้ารันเป็น root ตรง ๆ ให้ใช้ root ใช้เพื่อไม่ให้โฟลเดอร์ทั้งหมดตกเป็นของ root จนผู้ใช้ปกติแก้ไม่ได้ |
| 22 | `step()` | ฟังก์ชันพิมพ์หัวข้อสีฟ้า (`\033[1;36m` = รหัสสี ANSI) |

### 2. `deploy/setup-vps.sh` — Docker, swap, โฟลเดอร์, cron

**บรรทัด 30–50 (ติดตั้ง Docker)**

```bash:30
step "2/7 ติดตั้ง Docker"
if ! command -v docker >/dev/null 2>&1; then
  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f /etc/apt/keyrings/docker.asc ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
      -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc
  fi
  cat >/etc/apt/sources.list.d/docker.list <<EOF
deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable
EOF
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
fi
systemctl enable --now docker
if [ "$OWNER" != "root" ]; then
  usermod -aG docker "$OWNER"
  echo "เพิ่ม $OWNER เข้ากลุ่ม docker แล้ว (ออกจาก SSH แล้วเข้าใหม่หนึ่งครั้ง)"
fi
```

- **31** `command -v docker` เช็กว่ามี docker แล้วหรือยัง `>/dev/null 2>&1` ทิ้งทั้งผลลัพธ์และ error → รันซ้ำได้ ไม่ติดตั้งซ้ำ (เรียกว่า **idempotent** = รันกี่ครั้งผลเหมือนกัน)
- **33–37** ดาวน์โหลดกุญแจ GPG ของ Docker (ไว้ตรวจว่าแพ็กเกจที่โหลดมาเป็นของจริง) `curl -fsSL`: `-f` ล้มเหลวเมื่อ HTTP error, `-s` เงียบ, `-S` แต่โชว์ error, `-L` ตามการ redirect
- **38–41** `cat > ไฟล์ <<EOF ... EOF` = here-document เขียนข้อความหลายบรรทัดลงไฟล์ เพิ่มที่เก็บแพ็กเกจ (repository) ทางการของ Docker โดยเติมสถาปัตยกรรม (`dpkg --print-architecture`) และชื่อรุ่น Ubuntu (`VERSION_CODENAME`) อัตโนมัติ
- **43–44** ติดตั้ง `docker-compose-plugin` ซึ่งให้คำสั่ง `docker compose` (แบบเว้นวรรค)
- **46** `systemctl enable --now docker` เปิดเดี๋ยวนี้ + เปิดทุกครั้งที่บูต เพื่อให้เซิร์ฟเวอร์รีบูตแล้วระบบกลับมาเอง (ประกอบกับ `restart: unless-stopped` ใน compose)
- **47–49** `usermod -aG docker` เพิ่มผู้ใช้เข้ากลุ่ม docker ให้สั่ง docker ได้โดยไม่ต้อง sudo ทุกครั้ง กลุ่มมีผลเมื่อล็อกอินใหม่ จึงให้ออก SSH แล้วเข้าใหม่

**บรรทัด 52–60 (swap)**

```bash:52
step "3/7 สร้าง swap 2GB (ถ้ายังไม่มี)"
if [ "$(swapon --show | wc -l)" -eq 0 ] && [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile >/dev/null
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
  echo 'vm.swappiness=10' >/etc/sysctl.d/99-swappiness.conf
  sysctl -p /etc/sysctl.d/99-swappiness.conf >/dev/null
```

- **53** นับบรรทัดของ `swapon --show` ถ้า 0 = ยังไม่มี swap และไม่มีไฟล์ `/swapfile` ค่อยสร้าง
- **54–57** จองไฟล์ 2 GB, ตั้งสิทธิ์ 600 (เฉพาะ root อ่านได้ เพราะ swap อาจมีข้อมูลลับจากหน่วยความจำ), จัดรูปแบบเป็น swap, เปิดใช้
- **58** เขียนลง `/etc/fstab` ให้เปิดทุกครั้งที่บูต (`grep -q ... || echo ...` = เพิ่มเมื่อยังไม่มี)
- **59** `swappiness=10` = ใช้ swap เฉพาะเมื่อ RAM ใกล้เต็มจริง ๆ
- **ทำไมต้องมี swap:** ตอน `docker compose up --build` เครื่อง RAM 2 GB อาจเต็ม แล้ว Linux ฆ่า process ที่ build (OOM) swap กันกรณีนั้น (`SERVER_REQUIREMENTS.md` ขอ RAM 4 GB + swap 2 GB)

**บรรทัด 85–108 (โฟลเดอร์ + cron)**

```bash:85
step "6/7 วางโครงไฟล์ที่ $APP_DIR"
mkdir -p "$APP_DIR"/{db/data,mosquitto/{config,certs,data},caddy/{data,config},backend,www,firmware,backups}
chown -R "$OWNER":"$OWNER" "$APP_DIR"
# ข้อมูลของ mosquitto ต้องเป็นของ uid 1883 ที่ใช้ในคอนเทนเนอร์
chown -R 1883:1883 "$APP_DIR/mosquitto/data" "$APP_DIR/mosquitto/certs"
# backend (user node uid 1000) รับไฟล์เฟิร์มแวร์ที่อัปโหลดจากเว็บ
chown 1000:1000 "$APP_DIR/firmware"
chmod 750 "$APP_DIR"
chmod 700 "$APP_DIR/backups"

step "7/7 งานตามเวลา (cron ของ root)"
# ใบรับรองของ Caddy ต่ออายุเองทุก ~60 วัน ต้องก๊อปให้ Mosquitto ด้วย
# ไม่งั้นพอใบเก่าหมดอายุ บอร์ด ESP32 ทุกตัวจะต่อ MQTT ไม่ได้พร้อมกัน
CRON_FILE=/etc/cron.d/rmutt
cat >"$CRON_FILE" <<EOF
# RMUTT Save Energy
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# ก๊อปใบรับรอง HTTPS ให้ Mosquitto ทุกวัน 03:10
10 3 * * * root bash $APP_DIR/sync-mqtt-cert.sh >> /var/log/rmutt-cert.log 2>&1
# สำรองฐานข้อมูลทุกวัน 02:30
30 2 * * * root bash $APP_DIR/backup-db.sh >> /var/log/rmutt-backup.log 2>&1
EOF
chmod 644 "$CRON_FILE"
```

- **86** `{a,b,c}` คือ brace expansion ของ bash ขยายเป็นหลายพาธในคำสั่งเดียว (`mkdir -p` = สร้างพ่อแม่ให้และไม่ error ถ้ามีแล้ว)
- **87–89** เจ้าของทั้งหมดเป็นผู้ใช้ แต่ `mosquitto/data` และ `certs` เป็นของ uid 1883 เพราะ Mosquitto ในคอนเทนเนอร์รันเป็น uid นั้น ถ้าไม่ตรง Mosquitto อ่านไฟล์ไม่ได้ → วน Restarting (อาการที่ `fix-mqtt-permissions.sh` แก้)
- **90–91** (เพิ่ม 14 ต.ค. 2569) โฟลเดอร์ `firmware` เป็นของ uid 1000 = user `node` ในคอนเทนเนอร์ backend หลักคิดเดียวกับ Mosquitto: คอนเทนเนอร์เขียนไฟล์ลง bind mount ด้วย uid ของตัวเอง ถ้าโฟลเดอร์เป็นของผู้ใช้คนอื่นและสิทธิ์ `755` user `node` จะเขียนไม่ได้ ไม่ใช้ `-R` เพราะต้องการแค่สิทธิ์สร้างไฟล์ในโฟลเดอร์ ไฟล์เก่าที่ `scp` มายังเป็นของผู้ใช้เดิมได้ (Caddy แค่อ่าน) ทางเลือกอื่นคือ `chmod 777` ซึ่งให้ทุกคนบนเครื่องเขียนได้ หลวมเกินไป
- **92–93** `750` = เจ้าของทำได้ทุกอย่าง กลุ่มอ่านได้ คนอื่นไม่ได้เลย, `backups` เป็น `700` เฉพาะเจ้าของ เพราะไฟล์สำรองมีข้อมูลผู้ใช้
- **98–108** เขียน cron: `>> ไฟล์ 2>&1` ต่อท้าย log และรวม stderr ไว้ด้วย ตรวจย้อนหลังได้ที่ `/var/log/rmutt-cert.log` และ `/var/log/rmutt-backup.log` ใบรับรองของ Caddy ต่ออายุเองทุก ~60 วัน ถ้าไม่ก๊อปให้ Mosquitto ใบเก่าหมดอายุแล้ว **บอร์ด ESP32 ทุกตัวต่อ MQTT ไม่ได้พร้อมกัน** จึงให้ cron ตรวจทุกวัน (ไม่รอ 60 วัน เพราะวันที่ต่ออายุเดาไม่ได้)
- สคริปต์ใน cron อ้างไฟล์ `$APP_DIR/sync-mqtt-cert.sh` และ `backup-db.sh` ซึ่ง `upload.ps1` ส่งขึ้นมาแล้วตั้งแต่ขั้น 1

### 3. `deploy/init-env.sh` — สร้างความลับและบัญชี MQTT

**บรรทัด 4–24 (ป้องกันเขียนทับ + ฟังก์ชันสุ่ม)**

```bash:4
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if [ -f .env ]; then
  read -r -p ".env มีอยู่แล้ว เขียนทับไหม (พิมพ์ yes เพื่อยืนยัน): " confirm
  [ "$confirm" = "yes" ] || { echo "ยกเลิก"; exit 0; }
  cp .env ".env.bak-$(date +%Y%m%d-%H%M%S)"
  chmod 600 .env.bak-*
  if [ -d db/data/mysql ]; then
    echo "คำเตือน: มีฐานข้อมูลอยู่แล้วใน db/data"
    read -r -p "  ทำต่อ (พิมพ์ yes): " confirm_db
    [ "$confirm_db" = "yes" ] || { echo "ยกเลิก"; exit 0; }
  fi
fi

secret() { openssl rand -base64 64 | tr -dc 'A-Za-z0-9' | head -c "${1:-40}"; }
```

(ตัดบรรทัด echo ย่อยออกเพื่อให้สั้น เลขบรรทัดของคำสั่งที่เหลือตรงกับไฟล์จริง)

| บรรทัด | ความหมาย |
|---|---|
| 6 | `$0` คือพาธของสคริปต์เอง `dirname` ตัดเอาโฟลเดอร์ `cd ... && pwd` ได้พาธเต็ม → `ROOT` คือโฟลเดอร์ของสคริปต์ไม่ว่าจะเรียกจากที่ไหน แล้ว `cd` เข้าไป เพื่อให้พาธอย่าง `.env` ถูกต้องเสมอ |
| 9–11 | ถ้ามี `.env` แล้วต้องพิมพ์ `yes` เท่านั้นจึงทำต่อ (`read -r -p` อ่านค่าจากแป้นพิมพ์พร้อมข้อความถาม; `{ ...; exit 0; }` คือกลุ่มคำสั่ง) |
| 12–13 | สำรอง `.env` เดิมเป็น `.env.bak-<วันเวลา>` และ `chmod 600` (ไฟล์สำรองมีรหัสเหมือนกัน) |
| 14–21 | **ด่านที่สอง:** ถ้ามี `db/data/mysql` แปลว่า MariaDB ถูกสร้างไปแล้ว ซึ่งตั้ง user/รหัสครั้งเดียวตอนสร้าง รหัสใหม่ใน `.env` จึงใช้กับฐานข้อมูลเดิมไม่ได้ ต้องถามย้ำ |
| 24 | `secret`: `openssl rand -base64 64` สุ่มระดับ crypto → `tr -dc 'A-Za-z0-9'` เก็บเฉพาะตัวอักษรและตัวเลข (กันอักขระพิเศษที่ทำให้ `.env`/shell/URL พัง) → `head -c N` ตัดความยาว (ค่าเริ่มต้น 40) |

**บรรทัด 28–31 และ 68–74 (ค่าเริ่มต้น + รหัสสุ่ม)**

```bash:28
DOMAIN_DEFAULT="$(grep -E '^DOMAIN=' .env.example 2>/dev/null | cut -d= -f2 || true)"
DOMAIN_DEFAULT="${DOMAIN_DEFAULT:-rmutt-energy.duckdns.org}"
read -r -p "โดเมนของเซิร์ฟเวอร์ [$DOMAIN_DEFAULT]: " DOMAIN
DOMAIN="${DOMAIN:-$DOMAIN_DEFAULT}"
```

```bash:68
DB_ROOT_PASSWORD="$(secret 40)"
DB_PASSWORD="$(secret 40)"
JWT_SECRET="$(secret 48)"
OTP_PEPPER="$(secret 48)"
MQTT_USERNAME="rmutt_backend"
MQTT_PASSWORD="$(secret 32)"
MQTT_DEVICE_SECRET="$(secret 48)"
```

- **28** อ่านโดเมนเริ่มต้นจาก `.env.example`; `2>/dev/null` ซ่อน error; `|| true` ทำให้ "grep ไม่เจอ/ไม่มีไฟล์" ไม่ฆ่าสคริปต์ (เพราะ `set -e` + `pipefail` จะหยุดทันที ดังคอมเมนต์บรรทัด 26–27 อธิบายว่า `upload.ps1` ไม่ส่ง `.env*` ขึ้นไป)
- **29** `${VAR:-ค่า}` = ใช้ค่าสำรองถ้าตัวแปรว่าง
- **33–41** ถ้าโดเมนลงท้าย `.duckdns.org` (`case ... in *.duckdns.org)` คือการเทียบรูปแบบ) ต้องกรอก DuckDNS token วนถามจนกรอก (`while [ -z "$DUCKDNS_TOKEN" ]`)
- **43–48** `read -s` ไม่แสดงรหัสที่พิมพ์ และวนถามจนยาว ≥ 8 (`${#ADMIN_PASSWORD}` = ความยาวข้อความ)
- **63–64** `MAIL_MODE` เป็น `console` (พิมพ์ OTP ลง log) ถ้าไม่ได้กรอก SMTP ครบ และเป็น `smtp` ถ้ากรอกครบ ระบบจึงเริ่มใช้งานได้แม้ยังไม่มีอีเมล
- **68–74** รหัสทั้งหมดสุ่มเอง: DB root, DB app (ผู้ใช้ `rmutt_app` ที่ Backend ใช้ ไม่ใช้ root), `JWT_SECRET` (เซ็น token ล็อกอิน), `OTP_PEPPER` (ผสมตอนแฮช OTP), `MQTT_PASSWORD` (ของบัญชี `rmutt_backend`), `MQTT_DEVICE_SECRET` (ใช้สร้างรหัสบัญชีบอร์ดแต่ละตัว) ไม่มีรหัสใดถูกคนตั้งเอง จึงเดาไม่ได้และไม่ซ้ำกับที่อื่น
- **76 และ 114** `cat > .env <<EOF` ขยายตัวแปรลงข้อความทั้งก้อน แล้ว `chmod 600 .env` ให้อ่านได้เฉพาะเจ้าของ บรรทัด 109–110 กำหนด `BACKUP_KEEP_DAYS=14` และ `BACKUP_REMOTE=` (ว่าง) ที่ `backup-db.sh` อ่าน ท้ายสคริปต์ (147–149) `chown` ไฟล์ให้ผู้ใช้ที่สั่ง sudo เพื่อให้ `docker compose` (รันด้วยผู้ใช้ธรรมดา) อ่านได้ ทั้งที่สคริปต์รันด้วย root

**บรรทัด 121–136 (Mosquitto Dynamic Security)**

```bash:121
PLUGIN_PATH="$(docker run --rm eclipse-mosquitto:2.0 \
  sh -c 'find / -name mosquitto_dynamic_security.so 2>/dev/null | head -1')"
if [ -z "$PLUGIN_PATH" ]; then
  echo "ไม่พบ mosquitto_dynamic_security.so ใน image eclipse-mosquitto:2.0" >&2
  exit 1
fi
sed -i "s#^plugin .*#plugin $PLUGIN_PATH#" mosquitto/config/mosquitto.conf
```

```bash:132
rm -f mosquitto/data/dynamic-security.json
docker run --rm -v "$ROOT/mosquitto/data:/mosquitto/data" \
  eclipse-mosquitto:2.0 \
  mosquitto_ctrl dynsec init /mosquitto/data/dynamic-security.json \
  "$MQTT_USERNAME" "$MQTT_PASSWORD" >/dev/null
```

- **121–122** รันคอนเทนเนอร์ชั่วคราว (`--rm` = ลบเมื่อจบ) ค้นหาไฟล์ปลั๊กอิน เพราะ image แต่ละรุ่นวางไว้คนละที่ **ทำไมไม่เขียนพาธตายตัว:** ถ้า image เปลี่ยน พาธผิดแล้ว Mosquitto สตาร์ตไม่ขึ้น
- **127** `sed -i "s#^plugin .*#plugin $PLUGIN_PATH#"` แก้บรรทัดที่ขึ้นต้น `plugin` ใน `mosquitto.conf` (ใช้ `#` เป็นตัวคั่นแทน `/` เพราะพาธมี `/` เต็มไปหมด) นี่คือเหตุผลที่ `update-server.ps1` ไม่ส่ง `mosquitto.conf` ทับ
- **132–136** ลบไฟล์บัญชีเก่า แล้วให้ `mosquitto_ctrl dynsec init` สร้างไฟล์ใหม่ที่มีผู้ดูแลหนึ่งคนคือ `rmutt_backend` + รหัสที่เพิ่งสุ่ม `-v` mount โฟลเดอร์เข้าไปเขียนไฟล์ลงดิสก์ของเครื่องโฮสต์ ส่วนบอร์ดไม่ต้องกังวล: Backend สร้างบัญชีบอร์ดคืนให้เองทุกครั้งที่ต่อ broker (ตามคอมเมนต์ 130–131)
- **139–144** ตั้งเจ้าของ uid 1883 และสิทธิ์ (data 700, ไฟล์ dynsec 600, conf 644) และลบ `passwords`/`acl` ของระบบเก่า (บัญชีเดียวทุกบอร์ด)

> [!WHY]
> ทำไมใช้ Dynamic Security: ระบบเก่าให้ทุกบอร์ดใช้ username/password ร่วมกัน ถ้าบอร์ดเดียวถูกถอดไปอ่านรหัส ก็สั่งแอร์ทุกห้องได้ ระบบใหม่ให้แต่ละบอร์ดมีบัญชีและสิทธิ์ของตัวเอง และถอนสิทธิ์ได้ทันทีจากหน้าเว็บ (รายละเอียดฝั่ง Backend อยู่ในบท MQTT)

### 4. `deploy/update-server.ps1` — ผู้สั่งอัปเดตจาก Windows

**บรรทัด 44–55 (อัปโหลด backend)**

```powershell:44
if (-not $SkipUpload) {
  Write-Step '1/3 อัปโหลดซอร์ส backend และสคริปต์อัปเดต'

  $items = @('src', 'scripts', 'database', 'package.json', 'package-lock.json', '.dockerignore') |
    ForEach-Object { Join-Path $backendDirectory $_ } |
    Where-Object { Test-Path -LiteralPath $_ }

  if ($items.Count -eq 0) { throw 'ไม่พบไฟล์ backend ที่จะอัปโหลด' }

  Write-Host ("อัปโหลด: " + (($items | Split-Path -Leaf) -join ', '))
  scp @scpArgs -r @items "${target}:/opt/rmutt/backend/"
  if ($LASTEXITCODE -ne 0) {
```

| บรรทัด | ความหมาย |
|---|---|
| 47–49 | `@(...) \| ForEach-Object { ... } \| Where-Object { ... }` สร้างรายชื่อพาธเต็ม แล้วกรองเอาเฉพาะที่มีอยู่จริง (`$_` = ตัวที่กำลังประมวลผลในท่อ) ไม่ส่ง `node_modules` และ `.env` ของเครื่อง dev |
| 54 | `@scpArgs` (splatting) กระจายอาร์เรย์เป็นอาร์กิวเมนต์ = `-P 22`; `-r` ส่งโฟลเดอร์ทั้งก้อน; `"${target}:/opt/..."` ปีกกากันไม่ให้ `:` ถูกตีความเป็นส่วนของชื่อตัวแปร |
| 55 | ตรวจ `$LASTEXITCODE` ทันทีหลัง `scp` เพราะ `$ErrorActionPreference='Stop'` ไม่ครอบคลุมโปรแกรมภายนอก |
| 63–68 | ส่ง `update-remote.sh` ไปด้วยกันในรอบเดียว (ถ้าไม่มี SSH key จะถามรหัสน้อยครั้งลง) |
| 72–78 | ส่งไฟล์ตั้งค่า/สคริปต์ดูแล (`Caddyfile`, `docker-compose.yml`, Dockerfile, `sync-mqtt-cert.sh`, `backup-db.sh`, `seed-admin.sh` ฯลฯ) ทุกครั้งเผื่อมีการแก้ **ยกเว้น `mosquitto.conf`** เพราะ `init-env.sh` แก้ path ของ plugin ไว้บนเครื่องนั้นแล้ว |

**บรรทัด 109–119 (สั่งรันบนเซิร์ฟเวอร์)**

```powershell:109
# sed ตัด CR ออก เพราะไฟล์ที่แก้บน Windows มักติด CRLF มาด้วย
# ใช้สตริงเดี่ยวล้วน กัน PowerShell ไปแปลง $ กับ \ ระหว่างทาง
$remoteCommand = 'sed -i ''s/\r$//'' /opt/rmutt/*.sh' +
  '; bash /opt/rmutt/update-remote.sh'
ssh @sshArgs $target $remoteCommand
if ($LASTEXITCODE -ne 0) {
  Write-Host ''
  Write-Host 'อัปเดตไม่สำเร็จ ดู log ด้วยคำสั่งนี้:' -ForegroundColor Red
  Write-Host "  ssh -p $($srv.Port) $target 'cd /opt/rmutt && docker compose logs --tail 80 backend'"
  throw 'ขั้นตอนบนเซิร์ฟเวอร์ล้มเหลว'
}
```

- **89, 94, 101** (ขั้น 2) สร้าง `www.new` → ส่งเว็บเข้าไป → `find www -mindepth 1 -delete && cp -a www.new/. www/` (เหตุผล inode อยู่ในส่วนไฟล์ `deploy-web.ps1`)
- **111** `sed -i 's/\r$//'` ลบอักขระ CR (`\r`) ท้ายบรรทัดของไฟล์ `.sh` Windows บันทึกบรรทัดจบเป็น CRLF แต่ bash ถือ `\r` เป็นส่วนของคำสั่ง ทำให้ error แปลก ๆ เช่น `command not found` การลบก่อนรันกันปัญหานี้ทุกครั้ง
- **111** เครื่องหมายคำพูดเดี่ยวซ้อน (`''` ในสตริงเดี่ยวของ PowerShell = `'` หนึ่งตัว) เพื่อไม่ให้ PowerShell ตีความ `$` และ `\` ก่อนส่งไป
- **113** `ssh ... $remoteCommand` รันคำสั่งบนเซิร์ฟเวอร์ และ **ส่ง exit code กลับมา** ถ้า `update-remote.sh` `exit 1` ฝั่ง Windows จะ `throw` พร้อมบอกคำสั่งดู log

### 5. `deploy/update-remote.sh` — ผู้ทำบนเซิร์ฟเวอร์

**บรรทัด 6–16**

```bash:6
set -uo pipefail

cd /opt/rmutt || { echo "ไม่พบ /opt/rmutt"; exit 1; }

step() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
fail() { printf '\n\033[31mล้มเหลว: %s\033[0m\n' "$1"; exit 1; }

# อ่าน DOMAIN ด้วย grep ไม่ใช่ source เพราะบางบรรทัดใน .env มีช่องว่าง
DOMAIN=$(grep -E '^DOMAIN=' .env 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'")
[ -n "$DOMAIN" ] || fail 'อ่าน DOMAIN จาก /opt/rmutt/.env ไม่ได้'
```

- **6** `set -uo pipefail` **ไม่มี `-e`** โดยตั้งใจ สคริปต์นี้มีหลายขั้นที่ล้มเหลวได้แบบ "เตือนแล้วไปต่อ" (เช่น reload Caddy ไม่สำเร็จ) จึงใช้ `|| fail '...'` ตรวจเฉพาะขั้นที่ต้องหยุดจริง และใช้ `|| echo 'เตือน...'` กับขั้นที่ไม่วิกฤติ
- **14** อ่าน `DOMAIN` ด้วย `grep ... | cut -d= -f2-` แทน `source .env` เพราะบางบรรทัด (เช่น `SMTP_FROM="RMUTT Save Energy <...>"`) มีช่องว่าง `source` จะตีความเป็นคำสั่ง `-f2-` = เอาตั้งแต่ field ที่ 2 จนจบ (กันรหัสที่มี `=`) `tr -d` ลบเครื่องหมายคำพูด

**บรรทัด 22–36 (ตรวจก่อนทำ)**

```bash:22
dynsec_exists() {
  local f=mosquitto/data/dynamic-security.json
  [ -f "$f" ] && return 0
  docker exec rmutt-mqtt test -f /mosquitto/data/dynamic-security.json 2>/dev/null && return 0
  sudo -n test -f "$f" 2>/dev/null && return 0
  # อ่านโฟลเดอร์ไม่ได้และตรวจทางอื่นไม่ได้ อย่าสรุปว่าไม่มี
  if [ -d mosquitto/data ] && [ ! -x mosquitto/data ]; then
    echo 'เตือน: ตรวจ dynamic-security.json ไม่ได้ (ไม่มีสิทธิ์อ่าน mosquitto/data) ข้ามการตรวจ'
    return 0
  fi
  return 1
}
if ! dynsec_exists; then
  fail 'ยังไม่มี mosquitto/data/dynamic-security.json ให้รัน: sudo bash init-env.sh'
fi
```

ฟังก์ชันนี้ลองตรวจไฟล์ 3 วิธีตามลำดับ เพราะโฟลเดอร์ `mosquitto/data` เป็นของ uid 1883 สิทธิ์ 700 ผู้ใช้ทั่วไป "มองไม่เห็น" ไฟล์ข้างใน `[ -f ]` จึงตอบ "ไม่มี" ทั้งที่มี: (1) ตรงๆ (2) ถามผ่านคอนเทนเนอร์ `rmutt-mqtt` (3) `sudo -n` (`-n` = ห้ามถามรหัส จะไม่ค้าง) ถ้าทุกทางตรวจไม่ได้เพราะไม่มีสิทธิ์ ก็ **ไม่สรุปว่าไม่มี** (คืน 0 พร้อมเตือน) หลักคิด: ตรวจผิดว่า "ไม่มี" จะบล็อกการอัปเดตโดยไม่จำเป็น `return 0` = จริง (สำเร็จ) ของ bash บรรทัด 37–43 ตรวจต่อว่า `.env` มี `MQTT_DEVICE_SECRET` (`grep -q '^...=.\+'` = มีค่าอย่างน้อย 1 ตัว) และเตือนถ้ายังเป็น `.env` รุ่นเก่า (ไม่มี `DB_ROOT_PASSWORD`)

**บรรทัด 44–49 (เจ้าของโฟลเดอร์ firmware, เพิ่ม 14 ต.ค. 2569)**

```bash:44
mkdir -p firmware backups
# Backend (user node uid 1000) ต้องเขียนโฟลเดอร์ firmware ได้ เพื่อรับไฟล์ที่อัปโหลดจากเว็บ
if [ "$(stat -c %u firmware)" != 1000 ]; then
  chown 1000:1000 firmware 2>/dev/null || sudo -n chown 1000:1000 firmware 2>/dev/null \
    || echo 'เตือน: เปลี่ยนเจ้าของ firmware ไม่ได้ อัปโหลดเฟิร์มแวร์จากเว็บจะไม่สำเร็จ ให้รัน: sudo chown 1000:1000 /opt/rmutt/firmware'
fi
```

- **44** `mkdir -p` สร้างโฟลเดอร์ถ้ายังไม่มี (เครื่องที่ติดตั้งก่อนมีฟีเจอร์นี้ก็มีอยู่แล้ว ไม่ error)
- **46** `stat -c %u firmware` พิมพ์ **เลข uid** ของเจ้าของโฟลเดอร์ ถ้าเป็น 1000 อยู่แล้วข้ามทั้งก้อน (idempotent ไม่ต้อง sudo ทุกครั้ง)
- **47–48** ลองสามทางเรียงกัน: `chown` ตรง ๆ (ได้ถ้ารันเป็น root) → `sudo -n chown` (`-n` = ห้ามถามรหัส สคริปต์นี้รันผ่าน SSH แบบไม่มี terminal ถ้า sudo ต้องถามรหัสจะค้าง จึงให้ล้มทันทีแทน) → ถ้าไม่ได้ทั้งคู่ **แค่เตือน** พร้อมคำสั่งแก้ ไม่ `fail` เพราะการอัปเดต Backend ยังทำต่อได้ เสียแค่ปุ่มอัปโหลดในเว็บ `2>/dev/null` ซ่อนข้อความ error ของความพยายามที่ล้ม ให้เหลือแต่คำเตือนที่อ่านง่าย
- **ทำไมต้องมีทั้งใน `setup-vps.sh` และที่นี่:** เครื่องที่ติดตั้งไว้ก่อน 14 ต.ค. 2569 จะไม่รัน `setup-vps.sh` อีก โฟลเดอร์ยังเป็นของผู้ใช้เดิม และ `docker-compose.yml` เพิ่งเปลี่ยน mount ของ Backend จาก `./firmware:/firmware:ro` เป็น `./firmware:/firmware` การอัปเดตครั้งแรกหลังดึงโค้ดใหม่จึงต้องแก้สิทธิ์ให้เอง

**บรรทัด 62–74 (build + รอ) ของ `deploy/update-remote.sh`**

```bash:62
cp -f backend.Dockerfile backend/Dockerfile
docker compose up -d --build backend || fail 'build backend ไม่สำเร็จ'

step '2/6 รอให้ backend พร้อมรับคำสั่ง'
ready=0
for _ in $(seq 1 40); do
  if docker compose exec -T backend node -e 'process.exit(0)' >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 2
done
[ "$ready" = 1 ] || fail 'backend ไม่ขึ้นภายใน 80 วินาที ดูด้วย: docker compose logs backend'
```

- **54–60** ก่อน build ล้าง `SEED_ADMIN_PASSWORD` ที่ค้างใน `.env` ด้วย `sed -i` (รหัสแอดมินใช้แค่ตอน seed ไม่ควรค้างเป็นข้อความธรรมดา)
- **62** ก๊อป `backend.Dockerfile` (ที่ส่งมาในโฟลเดอร์หลัก) ไปเป็น `backend/Dockerfile` ที่ build context ต้องการ ไฟล์นี้มีบรรทัด `RUN chmod -R a+rX src scripts database` ก่อน `USER node` เพราะไฟล์ที่ `scp` ขึ้นมาจาก Windows อาจมีสิทธิ์ 700 ทำให้ user `node` อ่าน `/app/src` ไม่ได้ (`Cannot find module`) `a+rX` ให้ทุกคนอ่านได้อย่างเดียว ไฟล์ยังเป็นของ root จึงแก้โค้ดใน container ไม่ได้ และไม่แตะ `node_modules` เพื่อไม่ให้ build ช้า (อธิบายละเอียดในบทเครือข่ายหัวข้อ `backend.Dockerfile`)
- **63** `up -d --build backend` สร้าง image ใหม่และเปลี่ยนคอนเทนเนอร์ (เฉพาะ backend ไม่แตะ db/mqtt จึงข้อมูลไม่หาย)
- **67–73** วนสูงสุด 40 รอบ × 2 วินาที = 80 วินาที รอจน `docker compose exec backend node -e 'process.exit(0)'` สำเร็จ `for _ in ...` ใช้ `_` เป็นตัวแปรที่ไม่ใช้ค่า **ทำไมต้องรอ:** `up -d` กลับทันทีก่อนคอนเทนเนอร์พร้อมจริง ถ้า migrate ทันทีจะเจอ "container is not running"

**บรรทัด 77–98 (migrate) ของ `deploy/update-remote.sh`**

```bash:77
step '3/6 อัปเดตโครงสร้างฐานข้อมูล'
# แต่ละคำสั่งปลอดภัยที่จะรันซ้ำ ถ้ามีอยู่แล้วจะข้ามให้เอง
docker compose exec -T backend node scripts/migrate-energy-history-v370.js \
  || fail 'migrate energy ไม่สำเร็จ'
docker compose exec -T backend node scripts/migrate-auto-off-v380.js \
  || fail 'migrate auto-off ไม่สำเร็จ'
docker compose exec -T backend node scripts/migrate-system-settings-v3100.js \
  || fail 'migrate system settings ไม่สำเร็จ'
docker compose exec -T backend node scripts/migrate-firmware-v3140.js \
  || fail 'migrate firmware ไม่สำเร็จ'
docker compose exec -T backend node scripts/migrate-offline-history-v3150.js \
  || fail 'migrate offline history ไม่สำเร็จ'
# เอาคอลัมน์ rooms.is_active และสถานะ 'removed' ที่ไม่ใช้แล้วออก (ต้องรันหลัง backend รุ่นใหม่ขึ้น)
docker compose exec -T backend node scripts/migrate-drop-unused.js \
  || fail 'migrate ลบส่วนที่ไม่ใช้ ไม่สำเร็จ'
docker compose exec -T backend node scripts/doctor.js --fix \
  || fail 'doctor ไม่สำเร็จ'
# ใบรับรองของ MQTTS อาจถูกต่ออายุไปแล้วระหว่างที่ไม่ได้อัปเดต
bash sync-mqtt-cert.sh || echo 'เตือน: sync-mqtt-cert.sh ไม่สำเร็จ (รันด้วย sudo)'

step '4/6 รีสตาร์ท backend ให้รู้จักตารางใหม่'
docker compose restart backend || fail 'รีสตาร์ทไม่สำเร็จ'
```

รัน migration 6 ตัวตามลำดับ (`energy-history-v370`, `auto-off-v380`, `system-settings-v3100`, `firmware-v3140`, `offline-history-v3150`, `drop-unused`) แล้ว `doctor.js --fix` (เทียบกับ `database/schema.sql` และเติมตาราง/คอลัมน์ที่ขาด) **หัวใจคือ idempotent** ทุกสคริปต์ตรวจก่อนว่ามีอยู่แล้วหรือยัง จึงรันซ้ำทุกครั้งได้ ไม่ต้องจำว่ารอบนี้ต้องรันตัวไหน `-T` จำเป็นเพราะ SSH แบบสั่งคำสั่งเดียวไม่มี terminal บรรทัด 95 ก๊อปใบรับรองเผื่อต่ออายุระหว่างนั้น (ล้มเหลวได้เพราะไม่ใช่ root จึงแค่เตือน) บรรทัด 98 รีสตาร์ทให้ Backend รู้จักตารางใหม่

**บรรทัด 111–123 (ขั้น 5: โหลด Caddy ใหม่ และสร้างกล่อง tailscale ใหม่) ของ `deploy/update-remote.sh`**

```bash:111
# Caddy อ่านไฟล์เว็บจากดิสก์ทุกครั้งอยู่แล้ว แต่ Caddyfile ต้องโหลดใหม่
docker compose up -d caddy >/dev/null 2>&1
docker compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile >/dev/null 2>&1 \
  && echo 'โหลด Caddyfile ใหม่แล้ว' \
  || echo 'เตือน: reload Caddy ไม่สำเร็จ ลองดู: docker compose logs --tail 40 caddy'

# tailscale-serve.json ถูกอัปโหลดทับเป็นไฟล์ใหม่ container เดิมยังเห็นไฟล์เก่า
# ต้องสร้าง container ใหม่ (สถานะล็อกอินอยู่ใน ./tailscale/state ไม่หาย)
if docker compose ps --services 2>/dev/null | grep -qx tailscale; then
  docker compose up -d --force-recreate tailscale >/dev/null 2>&1 \
    && echo 'โหลด tailscale-serve.json ใหม่แล้ว (เว็บ 443 + MQTT 8443)' \
    || echo 'เตือน: สร้าง container tailscale ใหม่ไม่สำเร็จ ลองดู: docker compose logs --tail 40 tailscale'
fi
```

- **112–115** เดิมของขั้นนี้: ให้ Caddy ขึ้น แล้ว `caddy reload` อ่าน `Caddyfile` ใหม่โดยไม่ตัดการเชื่อมต่อ ถ้าล้มเหลวแค่เตือน (`&& ... || ...` เป็นรูปแบบ "สำเร็จพิมพ์อย่างหนึ่ง ล้มพิมพ์อีกอย่าง" ไม่ใช้ `fail` เพราะไม่ควรหยุดทั้งสคริปต์)
- **117–118** เหตุผลของขั้นใหม่: `update-server.ps1` อัปโหลด `tailscale-serve.json` ทับเป็นไฟล์ใหม่ แต่ container tailscale ที่รันอยู่ยังเห็นไฟล์เก่า (bind mount ของไฟล์เดี่ยวผูกกับตัวไฟล์เดิม แบบเดียวกับปัญหา inode ของโฟลเดอร์ `www` ในบทนี้) ถ้าแค่ `restart` กฎใหม่ (เช่นพอร์ต 8443 ของ MQTT) จะไม่มีผล จึงต้องสร้างกล่องใหม่ สถานะล็อกอินอยู่ในโฟลเดอร์ `./tailscale/state` (bind mount ของโฟลเดอร์ จึงอยู่รอด) ชื่อ ts.net จึงไม่เปลี่ยนและไม่ต้องล็อกอินใหม่
- **119** `docker compose ps --services` พิมพ์ชื่อ service ของ compose นี้ `grep -qx tailscale` (`-q` เงียบ, `-x` ต้องตรงทั้งบรรทัด) ใช้เป็นเงื่อนไข ทำเฉพาะเมื่อมี service ชื่อ `tailscale` กัน compose รุ่นเก่าที่ยังไม่มีกล่องนี้
- **120–122** `up -d --force-recreate tailscale` สร้างกล่องนี้ใหม่ทั้งที่ config ไม่เปลี่ยน (เฉพาะกล่องนี้ ไม่แตะ db/mqtt/backend) ผลเป็นข้อความ "เว็บ 443 + MQTT 8443" ถ้าล้มเหลวแค่เตือน เพราะ Backend อัปเดตเสร็จไปแล้ว การสร้างใหม่ทำให้ Funnel หลุดช่วงสั้น ๆ ระหว่างกล่องเริ่มใหม่

**บรรทัด 126–145 (ตรวจว่าใช้งานได้จริง) ของ `deploy/update-remote.sh`**

```bash:126
health=$(curl -s --max-time 20 "https://$DOMAIN/api/health")
echo "health: $health"
case "$health" in
  *'"status":"ok"'*) echo 'API ตอบปกติ' ;;
  *) fail "API ยังไม่ตอบ ดูด้วย: docker compose logs --tail 60 backend" ;;
esac
case "$health" in
  *'"connected":true'*) echo 'MQTT เชื่อมต่ออยู่' ;;
  *) echo 'เตือน: MQTT ยังไม่เชื่อมต่อ ดูด้วย: docker compose logs --tail 40 mqtt' ;;
esac

# 401 = เส้นทางมีอยู่จริงแต่ยังไม่ได้ล็อกอิน / 404 = ยังไม่ได้ลงโค้ดใหม่
for path in /api/alerts /api/energy/summary /api/energy/live /api/settings; do
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "https://$DOMAIN$path")
  if [ "$code" = "401" ]; then
    echo "OK   $path (401 = มีเส้นทางแล้ว รอ token)"
  else
    echo "ผิด  $path -> HTTP $code (ควรเป็น 401)"
  fi
done
```

- **126–131** `curl -s --max-time 20` ดึง health (เงียบ จำกัดเวลา) แล้ว `case` เทียบรูปแบบข้อความ ถ้าไม่มี `"status":"ok"` → `fail` (exit 1 ทำให้ฝั่ง Windows `throw`) ส่วน `"connected":true` (MQTT) เป็นแค่คำเตือน
- **138–145** ยิง 4 เส้นทางที่เพิ่มในรุ่นหลังโดยไม่ล็อกอิน: **401 = เส้นทางมีอยู่ (ต้องการ token)** / 404 = ยังไม่ได้ลงโค้ดใหม่ `-w '%{http_code}'` ให้ curl พิมพ์เฉพาะรหัส HTTP `-o /dev/null` ทิ้งเนื้อหา เป็นวิธีตรวจ "deploy ครบ" โดยไม่ต้องมีรหัสผ่านใด ๆ
- **147–154** เรียก `/` ต้องได้ 200 และเนื้อหามีคำว่า `RMUTT` (กันกรณีได้ 200 แต่เป็นหน้าอื่น)
- **156–169** ถ้า `/` ไม่ใช่ 200 ทั้งที่ `www/index.html` มี แปลว่า bind mount ของ Caddy ชี้โฟลเดอร์เก่า → `up -d --force-recreate caddy` (สร้างคอนเทนเนอร์ใหม่ เพราะรีสตาร์ทเฉย ๆ ผูก mount ใหม่ไม่ได้) แล้วตรวจอีกรอบ
- **171–176** ดู log 200 บรรทัดว่ามี `Auto-off service started` ไหม (ยืนยันว่าตัวคุมปิดแอร์อัตโนมัติเริ่มทำงาน)

### 6. `deploy/sync-mqtt-cert.sh` — ก๊อปใบรับรองให้ Mosquitto

**บรรทัด 11–56 (ย่อ)**

```bash:11
DOMAIN="$(grep -E '^DOMAIN=' .env | head -1 | cut -d= -f2- | tr -d '"\r' | xargs)"
...
CERT_DIR="$ROOT/caddy/data/caddy/certificates"
TARGET="$ROOT/mosquitto/certs"
...
SRC_CRT="$(find "$CERT_DIR" -name "${DOMAIN}.crt" | head -1)"
SRC_KEY="$(find "$CERT_DIR" -name "${DOMAIN}.key" | head -1)"
...
if cmp -s "$SRC_CRT" "$TARGET/fullchain.pem" \
  && cmp -s "$SRC_KEY" "$TARGET/privkey.pem"; then
  echo "$(date '+%F %T') ใบรับรองยังเป็นใบเดิม ไม่ต้อง reload"
  exit 0
fi

cp "$SRC_CRT" "$TARGET/fullchain.pem"
cp "$SRC_KEY" "$TARGET/privkey.pem"
chown 1883:1883 "$TARGET/fullchain.pem" "$TARGET/privkey.pem"
chmod 644 "$TARGET/fullchain.pem"
chmod 600 "$TARGET/privkey.pem"
...
if docker ps --format '{{.Names}}' | grep -q '^rmutt-mqtt$'; then
  docker kill -s HUP rmutt-mqtt >/dev/null
```

| บรรทัด | ความหมาย |
|---|---|
| 11 | อ่าน `DOMAIN` จาก `.env` แบบเลือกเฉพาะบรรทัด (ไม่ `source`) `head -1` เอาบรรทัดแรก `tr -d '"\r'` ลบเครื่องหมายคำพูดและ CR; `xargs` ตัดช่องว่างหัวท้าย |
| 18, 21–25 | Caddy เก็บใบรับรองที่ `caddy/data/caddy/certificates/...` ถ้าโฟลเดอร์ยังไม่มี = Caddy ยังขอไม่สำเร็จ (DNS ไม่ชี้ หรือพอร์ต 80 เข้าไม่ได้) บอกวิธีดู log แล้ว `exit 1` |
| 27–28 | `find` หาไฟล์ `<โดเมน>.crt` และ `.key` (โฟลเดอร์ย่อยมีชื่อผู้ออกใบรับรอง จึงต้องค้นหา) |
| 37–41 | `cmp -s` เทียบไฟล์ต่อไบต์ (เงียบ) ถ้าตรงกันทั้งคู่ = ใบเดิม ออกเลย ไม่ reload **ทำไม:** cron รันทุกวัน ถ้า reload ทุกวันโดยไม่จำเป็นจะรบกวน broker |
| 43–47 | ก๊อปเป็นชื่อที่ `mosquitto.conf` อ้างถึง (`fullchain.pem`, `privkey.pem`), เจ้าของ uid 1883, กุญแจส่วนตัว 600 |
| 50 | `openssl x509 ... -enddate` พิมพ์ผู้ออก/วันหมดอายุลง log ให้ตรวจย้อนหลังได้ |
| 52–54 | ถ้าคอนเทนเนอร์ `rmutt-mqtt` ทำงานอยู่ ส่งสัญญาณ **SIGHUP** (`kill -s HUP`) ให้ Mosquitto โหลดใบรับรองใหม่ **โดยไม่ตัดการเชื่อมต่อ** ของบอร์ดที่ต่ออยู่ (ถ้า restart บอร์ดทั้งตึกจะหลุดพร้อมกันแล้วต่อใหม่พร้อมกัน) |

### 7. `run_all.ps1` — เปิดระบบ local

**บรรทัด 1–15 และ 37–48 (พารามิเตอร์ + อ่าน .env)**

```powershell:1
[CmdletBinding()]
param(
  [string]$BrokerHost = '',
  [switch]$SkipFlutter,
  [switch]$InitDb,
  [switch]$Server,
  [string]$ServerUrl = 'https://rmutt-energy.duckdns.org'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
```

```powershell:37
function Get-DotEnv {
  param([Parameter(Mandatory)][string]$Path)
  $values = @{}
  if (Test-Path -LiteralPath $Path) {
    foreach ($line in Get-Content -LiteralPath $Path) {
      if ($line -match '^\s*([^#\s][^=]*)=(.*)$') {
        $values[$matches[1].Trim()] = $matches[2].Trim()
      }
    }
  }
  return $values
}
```

- **1** `[CmdletBinding()]` ทำให้สคริปต์ทำตัวเป็น "cmdlet" เต็มรูป รองรับ `-Verbose` และตรวจชื่อพารามิเตอร์ที่พิมพ์ผิดให้
- **4–7** `[switch]` เป็นสวิตช์ใช่/ไม่ใช่
- **14–15** `Stop` = error ตัวไหนก็หยุดทันที, `StrictMode Latest` = ใช้ตัวแปรที่ไม่เคยกำหนดเป็น error
- **42** regex `^\s*([^#\s][^=]*)=(.*)$` = บรรทัดที่ไม่ขึ้นต้นด้วย `#` (คอมเมนต์) มีรูป `ชื่อ=ค่า` วงเล็บแรกจับชื่อ วงเล็บที่สองจับค่า; `$matches[1]` คือผลที่จับได้ `@{}` คือ hashtable (พจนานุกรมชื่อ → ค่า)

**บรรทัด 83–111 (โหมด -Server)**

```powershell:83
if ($Server) {
  Write-Step "ตรวจเซิร์ฟเวอร์ $ServerUrl"
  try {
    $health = Invoke-RestMethod -Uri "$ServerUrl/api/health" -TimeoutSec 15
  } catch {
    Write-Host "เรียก $ServerUrl/api/health ไม่ได้: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
  }
  ...
  if ($health.mqtt.connected -ne $true) {
    Write-Host 'Backend บนเซิร์ฟเวอร์ยังไม่เชื่อม Broker' -ForegroundColor Red
    exit 1
  }
  ...
  flutter run -d windows --dart-define=API_BASE_URL="$ServerUrl/api"
```

`Invoke-RestMethod` เรียก HTTP แล้วแปลง JSON เป็น object ให้เลย (`$health.mqtt.connected`) ไม่แตะ Docker ในเครื่องเลย ใช้เมื่อแค่อยากเปิดแอปคุยกับเซิร์ฟเวอร์จริง `try/catch` จับ error แล้ว `exit 1` พร้อมคำแนะนำ (`exit 1` ใช้แทน `throw` ตรงนี้เพื่อคุมข้อความเอง)

**บรรทัด 131–157 (ขั้น 2: MariaDB)**

```powershell:131
$mariaName = (docker ps -a --filter 'name=mariadb' --format '{{.Names}}' |
  Select-Object -First 1)
if ([string]::IsNullOrWhiteSpace($mariaName)) {
  Write-Host 'ไม่พบ container ชื่อที่มีคำว่า mariadb' -ForegroundColor Yellow
  ...
} else {
  $mariaState = docker inspect --format '{{.State.Status}}' $mariaName
  if ($mariaState -ne 'running') {
    docker start $mariaName | Out-Null
```

```powershell:148
$deadline = (Get-Date).AddSeconds(60)
$dbReady = $false
do {
  $dbReady = (Test-NetConnection -ComputerName '127.0.0.1' -Port $dbPort `
    -InformationLevel Quiet -WarningAction SilentlyContinue)
  if ($dbReady) { break }
  Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)
if (-not $dbReady) { throw "ต่อพอร์ต $dbPort ของ MariaDB ไม่ได้" }
```

หา container ที่ชื่อมี `mariadb` (`docker ps -a` รวมที่หยุดอยู่ด้วย) ถ้าไม่ running ก็สั่ง start ถ้าไม่พบเลยก็ข้าม (รองรับ MariaDB ที่ติดตั้งตรงบน Windows) จากนั้น **วนรอสูงสุด 60 วินาที** จนพอร์ต (อ่าน `DB_PORT` จาก `backend/.env` ค่าเริ่มต้น 3306) เปิด รูปแบบ "deadline loop" `do { ... } while (เวลายังไม่หมด)` ใช้ซ้ำทุกที่ที่ต้องรอ service ขึ้น ดีกว่า `Start-Sleep 30` ตายตัว เพราะเร็วเมื่อพร้อมเร็ว และไม่รอเกินเมื่อพัง

**บรรทัด 161–187 (ขั้น 3: migrate)**

```powershell:161
Push-Location $backendDirectory
try {
  if (-not (Test-Path 'node_modules')) {
    Write-Host 'ติดตั้ง dependencies (npm ci)...'
    npm ci
    if ($LASTEXITCODE -ne 0) { throw 'npm ci ไม่สำเร็จ' }
  }
  if ($InitDb) {
    npm run db:init
    if ($LASTEXITCODE -ne 0) { throw 'db:init ไม่สำเร็จ' }
  }
  npm run db:migrate:pzem
  if ($LASTEXITCODE -ne 0) { throw 'migrate:pzem ไม่สำเร็จ' }
  ...
  node scripts/doctor.js --fix
  if ($LASTEXITCODE -ne 0) { throw 'doctor ไม่สำเร็จ' }
} finally {
  Pop-Location
}
```

`Push-Location` / `Pop-Location` (ใน `finally`) เข้าโฟลเดอร์ `backend` แล้ว **รับประกันว่ากลับที่เดิม** แม้ error `npm ci` (ติดตั้งตามเวอร์ชันใน `package-lock.json` เป๊ะ ๆ) รันเฉพาะเมื่อยังไม่มี `node_modules` `-InitDb` ถึงจะรัน `db:init` (เพราะ "สร้างตารางใหม่" อาจทับข้อมูล ไม่ควรเป็นค่าเริ่มต้น) ตามด้วย migration 5 ตัว (pzem, occupancy, energy, autooff, settings) และ `doctor --fix` ทุกครั้ง เพื่อให้ DB ของเครื่อง dev ตามทันโค้ดหลัง `git pull` โดยไม่ต้องจำ

**บรรทัด 191–216 (ขั้น 4: IP และ .env)**

```powershell:191
if ([string]::IsNullOrWhiteSpace($BrokerHost)) { $BrokerHost = Get-LanIPv4 }
...
if ($BrokerHost -like '127.*' -or $BrokerHost -eq 'localhost') {
  throw 'BrokerHost ต้องเป็น LAN IPv4 ของคอม ห้ามใช้ 127.0.0.1'
}
...
$newUrl = "mqtt://$BrokerHost`:1883"
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_REQUIRED' -Value 'true'
Set-DotEnvValue -Path $backendEnv -Name 'MQTT_URL' -Value $newUrl
```

**ทำไมห้าม 127.0.0.1:** ESP32 เป็นอุปกรณ์อีกเครื่องบน Wi-Fi ถ้าตั้งให้ต่อ 127.0.0.1 มันจะวนกลับหาตัวเอง ไม่ใช่คอมเรา ต้องเป็น LAN IP (เช่น 192.168.1.x) และ IP เปลี่ยนเมื่อย้ายเครือข่าย ดังนั้นทุกครั้งที่รัน สคริปต์เขียน `MQTT_URL` ใหม่และเตือน (บรรทัด 214–216) ว่าถ้า IP เปลี่ยน ต้อง provision ESP32 ผ่านบลูทูธใหม่ `` `: `` คือ backtick escape กัน PowerShell อ่าน `$BrokerHost:` เป็นชื่อตัวแปรแบบมี scope

**บรรทัด 225–245 (ขั้น 5: ซ่อม ACL)**

```powershell:225
$requiredAcl = @(
  "user $($mqttValues['MQTT_USERNAME'])"
  'topic readwrite rmutt/ac/#'
  'topic readwrite rmutt/occupancy/#'
  'topic read $SYS/#'
)
...
$missingAcl = @($requiredAcl | Where-Object { $currentAcl -notcontains $_ })
$aclRepaired = $false
if ($missingAcl.Count -gt 0) {
  Write-Host "ACL ขาดสิทธิ์: $($missingAcl -join ' | ')" -ForegroundColor Yellow
  Set-Content -LiteralPath $aclPath -Value $requiredAcl -Encoding ascii
  $aclRepaired = $true
```

ACL (Access Control List) คือไฟล์ที่ Mosquitto ใช้ตัดสินว่าผู้ใช้ไหน publish/subscribe topic ไหนได้ ไฟล์เก่าที่สร้างก่อนมีฟีเจอร์เซ็นเซอร์จะไม่มี `rmutt/occupancy/#` แล้ว broker จะ **ปฏิเสธเงียบ ๆ** (ไม่มี error ให้เห็น) สคริปต์จึงเทียบบรรทัดที่ต้องมีกับของจริง ถ้าขาดก็เขียนใหม่ และรีสตาร์ต broker (บรรทัด 252–255) ในสตริงเดี่ยว `'$SYS/#'` PowerShell ไม่ขยาย `$SYS` (ถ้าเป็นสตริงคู่จะพัง) และ `-Encoding ascii` เพราะ Mosquitto ไม่ชอบ BOM ของ UTF-8

**บรรทัด 259–264 และ 277–292 (รอ healthy, เปิด Backend)**

```powershell:259
    $status = docker inspect `
      --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' `
      rmutt-mosquitto 2>$null
    if ($status -eq 'healthy') { break }
```

```powershell:277
$listeners = @(Get-NetTCPConnection -LocalPort 3000 -State Listen `
  -ErrorAction SilentlyContinue)
foreach ($listener in $listeners) {
  try {
    $owner = Get-Process -Id $listener.OwningProcess -ErrorAction Stop
    Stop-Process -Id $owner.Id -Force
  } catch { ... }
}
...
Start-Process -FilePath 'powershell.exe' -WorkingDirectory $backendDirectory `
  -ArgumentList '-NoExit', '-Command',
    '[Console]::OutputEncoding = [System.Text.Encoding]::UTF8; npm start'
```

- ใช้ Go template ของ `docker inspect --format` ดึงสถานะ healthcheck (ที่นิยามไว้ใน compose ของ `mqtt/`) รอจนเป็น `healthy` ถ้าหมดเวลาแสดง log broker 40 บรรทัดแล้ว `throw`
- ปิด process เก่าที่ค้างพอร์ต 3000 เพื่อให้ Backend ใหม่ **โหลด `.env` ใหม่** (ไม่งั้น `EADDRINUSE`)
- `Start-Process` เปิดหน้าต่าง PowerShell ใหม่รัน `npm start` (`-NoExit` ไม่ปิดหน้าต่างเมื่อจบ) เพราะ Backend เป็นโปรแกรมที่รันค้าง และต้องการให้เห็น log (รวม OTP ตอน `MAIL_MODE=console`) แยกจากสคริปต์นี้

**บรรทัด 295–329 (ขั้น 7 และเปิดแอป)** รอ `/api/health` ให้ได้ `status = ok` และ `mqtt.connected = true` ภายใน 60 วินาที ถ้าไม่ตอบเลยให้ `throw 'Backend ไม่ตอบ...'` ถ้าตอบแต่ MQTT ไม่ต่อ ให้ `throw` พร้อม `lastError` จากนั้น `flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api` ในบล็อก `try/finally` กลับโฟลเดอร์เดิม

### 8. `build-apk.ps1` — สร้าง APK

**บรรทัด 46–60 (เติมสิทธิ์)**

```powershell:46
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
```

- สิทธิ์ที่ต้องใช้: `INTERNET` (เรียก API), `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` (Android 12 ขึ้นไป ใช้ตั้งค่าบอร์ดผ่านบลูทูธ; `neverForLocation` บอกว่าไม่ใช้สแกนหาตำแหน่ง), `ACCESS_FINE_LOCATION` เฉพาะ Android ≤ 30 (`maxSdkVersion="30"`) เพราะรุ่นเก่าถือว่าสแกนบลูทูธต้องมีสิทธิ์ตำแหน่ง
- **55** ดึงชื่อสิทธิ์ด้วย regex; **56** ถ้า manifest ยังไม่มีชื่อนี้ (`-notmatch`) ค่อยเติม → รันซ้ำไม่เติมซ้ำ (idempotent)
- **57** `-replace '(?=\s*<application)', ...` ใช้ lookahead (`(?=...)` = "ตำแหน่งที่ข้างหน้าเป็น ...") แทรกบรรทัดสิทธิ์ก่อนแท็ก `<application`
- **63–65** เขียนไฟล์ด้วย `UTF8Encoding($false)` = UTF-8 **ไม่มี BOM** (`$false` = ไม่ใส่ BOM) เพื่อไม่ให้ BOM ไปปนไฟล์ XML ของ Android
- **ทำไมเติมสิทธิ์ด้วยสคริปต์:** โฟลเดอร์ `android` สร้างใหม่ได้ด้วย `flutter create` (ถ้าหาย) สคริปต์รับประกันว่าสิทธิ์ที่แอปต้องใช้จะอยู่ครบเสมอ

**บรรทัด 76–89 (build)**

```powershell:76
if ($DebugApk) {
  flutter build apk --debug --dart-define=API_BASE_URL=$ApiBaseUrl
  $apk = 'build/app/outputs/flutter-apk/app-debug.apk'
} else {
  if (-not (Test-Path -LiteralPath 'android/key.properties')) {
    Write-Host 'ยังไม่มี android/key.properties จะเซ็นด้วย debug key แทน' -ForegroundColor Yellow
  }
  flutter build apk --release --dart-define=API_BASE_URL=$ApiBaseUrl
  $apk = 'build/app/outputs/flutter-apk/app-release.apk'
}
if ($LASTEXITCODE -ne 0) { throw 'build apk ไม่สำเร็จ' }
```

สองโหมด: debug (ติดตั้งง่าย) หรือ release (ค่าเริ่มต้น) ฝั่ง Gradle (`android/app/build.gradle.kts`) อ่าน `key.properties` ถ้ามีก็ใช้กุญแจโปรเจกต์ (`signingConfigs.getByName("release")`) ถ้าไม่มีก็ใช้ debug key พร้อมพิมพ์ WARNING สคริปต์เตือนซ้ำอีกชั้นก่อน build **ทำไมต้องเป็นกุญแจเดิมตลอด:** ลายเซ็นต่างกัน = Android ถือเป็นแอปคนละตัว ผู้ใช้ต้องลบแล้วลงใหม่

### 9. `create-keystore.ps1` — สร้างกุญแจเซ็น

**บรรทัด 43–63**

```powershell:43
$secure = Read-Host 'ตั้งรหัสผ่านของกุญแจ (อย่างน้อย 8 ตัว จดเก็บไว้)' -AsSecureString
$password = [System.Net.NetworkCredential]::new('', $secure).Password
if ($password.Length -lt 8) { throw 'รหัสผ่านสั้นเกินไป' }

& $keytool -genkeypair -v `
  -keystore $KeystorePath -storetype JKS `
  -alias $Alias -keyalg RSA -keysize 2048 -validity 10000 `
  -storepass $password -keypass $password `
  -dname 'CN=RMUTT Save Energy, OU=Computer Engineering, O=RMUTT, L=Pathum Thani, C=TH'
if ($LASTEXITCODE -ne 0) { throw 'สร้างกุญแจไม่สำเร็จ' }

$storeFile = $KeystorePath -replace '\\', '/'
$content = @(
  "storePassword=$password"
  "keyPassword=$password"
  "keyAlias=$Alias"
  "storeFile=$storeFile"
) -join "`n"
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($propertiesPath, $content + "`n", $encoding)
```

| บรรทัด | ความหมาย |
|---|---|
| 43 | `-AsSecureString` ไม่แสดงตัวอักษรบนจอ เก็บเป็นชนิด SecureString |
| 44 | แปลง SecureString กลับเป็นข้อความธรรมดาผ่าน `NetworkCredential` (ต้องใช้ข้อความธรรมดาเพื่อส่งให้ keytool และเขียนลง `key.properties`) |
| 47 | `&` = เรียกโปรแกรมที่พาธอยู่ในตัวแปร; backtick `` ` `` ท้ายบรรทัด = ต่อบรรทัด |
| 48–50 | `-genkeypair` สร้างคู่กุญแจ, `-keyalg RSA -keysize 2048` อัลกอริทึมและขนาดมาตรฐาน, `-validity 10000` อายุ 10,000 วัน (~27 ปี ต้องอยู่ได้นานกว่าอายุแอป), `-storepass/-keypass` รหัสของไฟล์/ของกุญแจ (ตั้งเท่ากัน) |
| 51 | `-dname` ข้อมูลผู้ออก (ชื่อ หน่วยงาน เมือง ประเทศ) ใส่ใน certificate |
| 55 | เปลี่ยน `\` เป็น `/` เพราะไฟล์ `.properties` ของ Java ถือ `\` เป็นตัว escape |
| 56–63 | เขียน 4 บรรทัดที่ Gradle อ่าน (`storePassword`, `keyPassword`, `keyAlias`, `storeFile`) |

> [!WARN]
> `key.properties` เก็บรหัสเป็นข้อความธรรมดา จึงต้องอยู่ใน `.gitignore` (อยู่แล้ว) และไฟล์ `.jks` อยู่นอกโฟลเดอร์โปรเจกต์โดยตั้งใจ ต้องสำรองทั้งไฟล์และรหัสอย่างน้อยสองที่ ถ้าสองอย่างนี้หาย จะอัปเดตแอปที่ผู้ใช้ติดตั้งไปแล้วไม่ได้อีกเลย

## การดูแลระบบหลังติดตั้ง (Operations)

### สำรองข้อมูล (`deploy/backup-db.sh`)

- **เวลา:** cron ของ root รันทุกวัน **02:30** (บรรทัด `30 2 * * *` ที่ `setup-vps.sh` เขียนไว้) ผลลง `/var/log/rmutt-backup.log`
- **ที่เก็บ:** `/opt/rmutt/backups/rmutt-YYYY-MM-DD_HHMM.sql.gz` (โฟลเดอร์สิทธิ์ 700 ไฟล์สิทธิ์ 600)
- **วิธี:** `docker compose exec -T db mariadb-dump -uroot -p"$DB_ROOT_PASSWORD" --single-transaction --routines --triggers --events <ฐานข้อมูล> | gzip -9` `--single-transaction` อ่านข้อมูลชุดเดียวกันทั้งไฟล์โดยไม่ล็อกตาราง ระบบจึงบันทึกค่าไฟต่อได้ระหว่างสำรอง
- **ความปลอดภัยของไฟล์:** เขียนลง `*.partial` ก่อน แล้วตรวจ `gzip -t` และบรรทัดสุดท้ายต้องมีคำว่า `Dump completed` ถ้าไม่ครบ (เช่น DB ล่มกลางทาง) จะลบทิ้งและ `exit 1` ผ่านแล้วค่อย `mv` เป็นชื่อจริง → ไฟล์ที่ดูเหมือน backup แต่พังจะไม่ถูกเก็บ
- **เก็บย้อนหลัง:** `find backups -name 'rmutt-*.sql.gz' -mtime +"$KEEP_DAYS" -delete` ค่าจาก `BACKUP_KEEP_DAYS` ใน `.env` (ค่าเริ่มต้น 14 วัน)
- **ส่งออกนอกเครื่อง:** ถ้าตั้ง `BACKUP_REMOTE` (เช่น `user@nas:/path`) จะ `rsync -a --delete backups/ "$REMOTE/"` ต้องตั้ง SSH key ของ root ไว้ก่อน
- **กู้คืน:** `gunzip -c backups/<ไฟล์>.sql.gz | docker compose exec -T db mariadb -uroot -p"..." rmutt_save_energy` และ DEPLOY.md เตือนให้ทดลองกู้อย่างน้อยเทอมละครั้ง **"backup ที่ไม่เคยลองกู้ถือว่ายังไม่มี"**
- **ขนาด:** ข้อมูลประมาณ 230 MB ต่อปี (SERVER_REQUIREMENTS.md วัดได้ ~363 ไบต์/แถว × 72 บอร์ด × 8,760 ชั่วโมง) backup 14 วันจึงต่ำกว่า 1 GB ในปีแรก

### ตรวจสุขภาพ (`/api/health`)

`curl -s https://<โดเมน>/api/health` ต้องเห็น `"status":"ok"`, `"connected":true` (Backend ต่อ broker อยู่) และ `"deviceAuth":"dynsec"` (โหมดบัญชีแยกต่อบอร์ด) endpoint นี้ (นิยามใน `backend/src/app.js`) ไม่ต้องล็อกอิน และรัน `SELECT 1` ถาม DB ด้วย จึงยืนยันได้ทั้ง API และฐานข้อมูล บนเซิร์ฟเวอร์จริง (`config.env === 'production'`) จะไม่บอกที่อยู่ broker หรือข้อความ error ภายในให้คนนอกเห็น (ตอน dev ได้รายละเอียดครบ ซึ่ง `check_system.ps1`/`diagnose.ps1` ใช้) docker compose ก็ใช้ URL นี้เป็น healthcheck ของ backend เอง DEPLOY.md แนะนำให้ตั้ง UptimeRobot (หรือระบบ monitor ของมหาวิทยาลัย) เรียกทุก 5 นาที และแจ้งเตือนเมื่อไม่ได้ `"connected":true`

### ดู log และสถานะ

```bash
cd /opt/rmutt
docker compose ps                      # สถานะ/health ของทุก service
docker compose logs -f backend         # ตามดู log (Ctrl+C เพื่อออก)
docker compose logs --tail 40 mqtt     # 40 บรรทัดล่าสุดของ broker
docker compose restart backend
bash db-view.sh                        # ดูข้อมูลแบบอ่านอย่างเดียว
tail /var/log/rmutt-backup.log         # ผล backup รอบอัตโนมัติ
tail /var/log/rmutt-cert.log           # ผลก๊อปใบรับรอง
```

### ปัญหาที่พบบ่อยและวิธีแก้

| อาการ | สาเหตุที่เป็นไปได้ | วิธีแก้ |
|---|---|---|
| `rmutt-mqtt` วน Restarting | เจ้าของ/สิทธิ์ไฟล์ใน `mosquitto/` ไม่ใช่ uid 1883 หรือไฟล์ไม่ครบ | `sudo bash fix-mqtt-permissions.sh` (ถ้าขาดใบรับรอง → `sync-mqtt-cert.sh`, ขาด dynsec → `init-env.sh`) |
| Caddy ขอใบรับรองไม่ได้ / `sync-mqtt-cert.sh` ขึ้น "ยังไม่มีใบรับรอง" | DNS ไม่ชี้มาที่เครื่อง หรือพอร์ต 80 เข้าจากอินเทอร์เน็ตไม่ได้ | `dig +short <โดเมน>` เทียบกับ `curl -s ifconfig.me`, `docker compose logs caddy \| tail -30` |
| บอร์ด ESP32 ที่ต่อตรง 8883 ทุกตัวต่อ MQTT ไม่ได้พร้อมกัน | ใบรับรองของ Mosquitto หมดอายุ (cron ก๊อปไม่ทำงาน) บอร์ดที่ต่อผ่าน Funnel 8443 ไม่เกี่ยว เพราะใช้ใบ ts.net ของกล่อง tailscale | ดู `/var/log/rmutt-cert.log`, รัน `sudo bash sync-mqtt-cert.sh` |
| เว็บแอปเปิดแล้ว 404 ทุกหน้า | bind mount ของ Caddy ชี้โฟลเดอร์ `www` เก่า (มีคนเปลี่ยนชื่อโฟลเดอร์) | `docker compose up -d --force-recreate caddy` (`update-remote.sh` ทำให้อัตโนมัติ) |
| `update-remote.sh` ขึ้น `$'\r': command not found` | ไฟล์ `.sh` ติด CRLF จาก Windows | `update-server.ps1` ลบ CR ให้ทุกครั้ง; ถ้ารันมือ `sed -i 's/\r$//' *.sh` |
| Backend ขึ้น `Cannot find module` ที่ `/app/src/...` | ไฟล์ที่ `scp` จาก Windows มีสิทธิ์ 700 user `node` ใน container อ่านไม่ได้ | `backend.Dockerfile` มี `RUN chmod -R a+rX src scripts database` แล้ว ให้ build ใหม่ `docker compose up -d --build backend` |
| บอร์ดที่ตั้งให้ต่อ `ts.net:8443` ต่อ MQTT ไม่ได้ (เว็บผ่าน ts.net ยังเข้าได้) | `tailscale-serve.json` ใหม่ยังไม่มีผล (กล่อง tailscale ยังอ่านไฟล์เก่า) หรือไม่มีบรรทัด `:8443` ใน `AllowFunnel` | `docker compose up -d --force-recreate tailscale` (`update-remote.sh` ทำให้เองในขั้น 5) แล้วดู `docker compose logs --tail 40 tailscale` |
| `init-env.sh` ใหม่แล้ว Backend ต่อ DB ไม่ได้ | รหัส DB ใหม่ใช้กับฐานข้อมูลที่สร้างไปแล้วไม่ได้ (MariaDB ตั้ง user ครั้งเดียว) | คืน `.env` จากไฟล์ `.env.bak-*` หรือแก้ `.env` เอง |
| `docker: permission denied` | ผู้ใช้ยังไม่อยู่กลุ่ม docker (หรือยังไม่ล็อกอินใหม่) | ออกจาก SSH แล้วเข้าใหม่ |
| อัปโหลดเฟิร์มแวร์จากเว็บแล้วขึ้น "Backend เขียนโฟลเดอร์ firmware ไม่ได้" (เพิ่ม 14 ต.ค. 2569) | โฟลเดอร์ `/opt/rmutt/firmware` ไม่ใช่ของ uid 1000 หรือ `docker-compose.yml` บนเครื่องยังเป็น `:ro` | `sudo chown 1000:1000 /opt/rmutt/firmware` แล้วอัปเดตด้วย `update-server.ps1` (สคริปต์แก้สิทธิ์ให้เองถ้าทำได้) |
| พิมพ์ `.\deploy\update-server.ps1` แล้วเปิด Notepad | รันใน Command Prompt ไม่ใช่ PowerShell | `powershell -ExecutionPolicy Bypass -File .\deploy\update-server.ps1` หรือเปิด PowerShell |
| API ตอบ 404 ที่เส้นทางใหม่ | ยังไม่ได้อัปเดตโค้ดบนเซิร์ฟเวอร์ | `.\deploy\update-server.ps1` (ตรวจ 401/404 ท้ายสคริปต์) |
| local: ESP32 ไม่ขึ้นในแอป | IP เครื่องเปลี่ยน / Firewall ปิดพอร์ต 1883 / ACL ขาด | `.\diagnose.ps1` แล้วอ่านทีละขั้น, `.\run_all.ps1` ซ่อม `MQTT_URL` และ ACL |
| local: `EADDRINUSE 3000` | Backend ตัวเก่ายังรัน | `run_all.ps1` ปิดให้เอง |
| APK ติดตั้งทับของเดิมไม่ได้ | เซ็นด้วยกุญแจคนละตัว (debug key กับ release key) | ใช้ keystore เดียวกันตลอด หรือถอนแอปเก่าก่อน |

## กลยุทธ์การทดสอบ

### ทำไมต้องมีการทดสอบ

ระบบนี้สั่งแอร์จริงและเก็บค่าไฟจริง แก้โค้ดจุดหนึ่งอาจทำให้ส่วนอื่นพังโดยไม่รู้ตัว (เช่น เปลี่ยนสูตรคำนวณไฟแล้วรายงานผิด) การทดสอบอัตโนมัติคือ "สคริปต์ที่ตรวจว่าฟังก์ชันสำคัญยังให้คำตอบที่ถูก" รันได้ในไม่กี่วินาทีทุกครั้งก่อน deploy เพื่อจับข้อผิดพลาดตั้งแต่เครื่องตัวเอง ไม่ต้องรอไปเจอบนเซิร์ฟเวอร์จริง ชุดทดสอบเน้น **ตรรกะล้วน (pure logic)** ที่ไม่ต้องพึ่งฐานข้อมูลหรือเครือข่าย จึงเร็วและเสถียร

มี 3 ชั้น ตามภาษาของแต่ละส่วน:

| ชั้น | เครื่องมือ | คำสั่ง | ที่ไฟล์ |
|---|---|---|---|
| Backend (Node.js) | `node --test` (ตัวรันทดสอบที่มากับ Node) + `node:assert/strict` | `cd backend && npm test` | `backend/test/*.test.js` |
| แอป Flutter (Dart) | `flutter test` | `flutter test` (ที่โฟลเดอร์หลัก) | `test/*_test.dart` |
| เฟิร์มแวร์ (C++) | คอมไพล์ด้วย `g++` แล้วรันบนคอม | ดูด้านล่าง | `firmware/tests/history_log_test.cpp` |

### Backend: `npm test` = `node --test`

`package.json` กำหนด `"test": "node --test"` Node จะค้นหาไฟล์ `*.test.js` ใน `test/` แล้วรันแต่ละไฟล์เป็นกระบวนการแยก (ไฟล์หนึ่งพังไม่ลากไฟล์อื่น) มี **21 ไฟล์ รวม 136 เทสต์** (นับบรรทัดที่ขึ้นต้นด้วย `test(` ในแต่ละไฟล์; เดิม 20 ไฟล์ 126 เทสต์ เพิ่ม `unprovision.test.js` 2 เทสต์ เมื่อ 13 ต.ค. 2569 และเทสต์ใน `air-conditioner` +4 กับ `firmware` +4 เมื่อ 11–14 ต.ค. 2569) รูปแบบ:

```js
import assert from 'node:assert/strict';
import test from 'node:test';

test('OTP always contains exactly six digits', () => {
  for (let index = 0; index < 100; index += 1) {
    assert.match(createOtp(), /^\d{6}$/);
  }
});
```

(ตัวอย่างจริงจาก `backend/test/security.test.js`) `test('ชื่อ', () => { ... })` = หนึ่งกรณีทดสอบ `assert.*` ตรวจว่าผลตรงที่คาด ถ้าไม่ตรงจะ throw ทำให้เทสต์ล้มเหลว

| กลุ่ม | ไฟล์ (จำนวนเทสต์โดยประมาณ) | ตรวจอะไร |
|---|---|---|
| ความปลอดภัย/ผู้ใช้ | `security` (3), `user` (2), `user-management` (7), `profile-email` (4) | OTP 6 หลัก, แฮชแบบเทียบเวลาคงที่, ความยาวรหัสผ่านตามขีดจำกัด bcrypt, กฎการจัดการผู้ใช้, อีเมล |
| ห้อง/ตารางเรียน | `room` (4), `room-booking` (5), `schedule` (11), `schedule-import` (9), `xlsx-writer` (6) | ตรรกะห้อง การจองห้อง ตารางเรียน นำเข้า Excel และเขียนไฟล์ xlsx |
| แอร์/เซ็นเซอร์ | `air-conditioner` (10), `pzem-status` (4), `occupancy-sensor` (5), `auto-off` (15) | คำสั่งแอร์ สถานะ PZEM เซ็นเซอร์ตรวจคน และการตัดสินใจปิดแอร์อัตโนมัติ (ชุดใหญ่สุดเพราะผิดแล้วกระทบการใช้งานจริง) + (เพิ่ม 11 ต.ค. 2569) โปรโตคอล `DAIKIN_WIRED`: คำสั่งที่รีโมตติดผนังทำไม่ได้ถูกปฏิเสธ/ปิด, `controlType`, อ่าน `controlMode: wired` จาก status |
| พลังงาน/ประวัติ | `energy-history` (17), `offline-history` (4) | สรุปค่าไฟรายชั่วโมง/วัน และรับข้อมูลที่บอร์ดเก็บตอนเน็ตหลุด |
| MQTT/เฟิร์มแวร์ | `mqtt` (3), `mqtt-accounts` (7), `mqtt-provisioning` (5), `firmware` (7), `unprovision` (2) | topic และข้อความ, บัญชี dynsec ต่อบอร์ด, provisioning, ชื่อไฟล์ OTA + (เพิ่ม 14 ต.ค. 2569) แยกชนิดไฟล์ `air`/`wired`/`occupancy`, ห้ามสั่งไฟล์ผิดชนิด, อ่าน/เทียบรุ่นจากชื่อไฟล์, ตรวจไบต์ `0xE9` และขนาดไม่เกินช่อง OTA + (เพิ่ม 13 ต.ค. 2569) รูปคำสั่ง `unprovision` และนับเป็นคำตอบเฉพาะ `unprovisioned === true` ของบอร์ดตัวเดียวกัน |
| ฐานข้อมูล | `schema-doctor` (6) | ตัววิเคราะห์ `schema.sql` ของ doctor (ทุกตารางถูก parse, หาคอลัมน์ที่ขาด) โดยอ่านไฟล์ schema จริง ไม่ต้องต่อ DB |

> [!NOTE]
> จำนวนเทสต์นับจากข้อความ `test(` ในไฟล์ ตัวเลขจริงตอนรันอาจต่างเล็กน้อย ตอนผู้เขียนลองรัน `node --test` บนสำเนาที่ **ยังไม่ได้ `npm ci`** 8 ไฟล์ import แพ็กเกจ (เช่น `fflate`) ไม่ได้จึงล้มตั้งแต่โหลด ส่วนอีก 12 ไฟล์ผ่านรวม 79 เทสต์ ดังนั้นต้อง `npm ci` ก่อนเสมอ ผลที่ถูกต้องคือ `fail 0` (14 ต.ค. 2569: รัน `node --test test/unprovision.test.js test/firmware.test.js test/air-conditioner.test.js` สามไฟล์ที่เปลี่ยนรอบนี้ได้ `tests 19`, `pass 19`, `fail 0` ทั้งสามไฟล์ไม่ต้องใช้แพ็กเกจภายนอก)

### แอป Flutter: `flutter test`

มี **21 ไฟล์ ประมาณ 119 เทสต์** ใน `test/` (9 ต.ค. เพิ่ม `room_calendar_test.dart` 11 เทสต์ และ `energy_usage_chart_test.dart` จาก 9 เป็น 14) (นับ `test(` และ `testWidgets(`) เทสต์ส่วนใหญ่เป็นตรรกะล้วนไม่ต้องเปิดหน้าจอ ตัวอย่างพื้นที่ที่ครอบคลุม:

| พื้นที่ | ไฟล์ | ตรวจอะไร |
|---|---|---|
| พลังงาน | `energy_format_test`, `energy_database_test`, `energy_usage_chart_test` | จัดรูปแบบหน่วยไฟ เก็บ/อ่านข้อมูลพลังงานในแอป กราฟการใช้ไฟ |
| ปิดอัตโนมัติ/เซ็นเซอร์ | `auto_off_countdown_test`, `occupancy_status_test`, `pzem_status_test` | นับถอยหลัง สถานะห้องว่าง/มีคน สถานะ PZEM |
| ตารางเรียน | `class_schedule_test`, `schedule_date_test`, `schedule_import_test`, `room_calendar_test` | ตรรกะตารางและวันที่ นำเข้าตาราง การใช้ห้อง (วันเดียว/รายวัน/รายสัปดาห์) ภาคเรียน และ CSV |
| ภาษา/รูปแบบ | `app_localizations_test`, `thai_date_test`, `number_format_test` | แปลภาษา วันที่ไทย (พ.ศ.) รูปแบบตัวเลข |
| ตั้งค่า/ผู้ใช้ | `app_preferences_test`, `system_settings_test`, `user_management_test` | ค่าที่จำในเครื่อง ตั้งค่าระบบ จัดการผู้ใช้ |
| บลูทูธ/Wi-Fi | `ble_identity_test`, `wifi_network_candidate_test`, `saijo_denki_support_test` | ระบุตัวบอร์ดจากชื่อ BLE เลือกเครือข่าย Wi-Fi รองรับรุ่นแอร์ |
| อื่น ๆ | `mock_data_test`, `widget_test` | ข้อมูลจำลอง และทดสอบ widget พื้นฐาน |

`--dart-define` ไม่เกี่ยวกับ `flutter test` (ค่าเริ่มต้นของ `API_BASE_URL` ใช้ในโค้ด)

### เฟิร์มแวร์: `history_log_test.cpp` ทดสอบบนคอม

`firmware/rmutt_esp32_air/history_log.h` คือที่เก็บค่าไฟสรุปทุก 5 นาทีไว้ใน flash ของบอร์ดตอนเน็ตหลุด (2,048 รายการ ≈ 7 วัน) เขียนเป็น template C++ ที่รับ "flash" เป็นพารามิเตอร์ (`HistoryLog<FakeFlash>`) จึงเอามาทดสอบบนคอมได้โดยไม่ต้องมีบอร์ด ไฟล์ทดสอบสร้าง `FakeFlash` ที่จำลองพฤติกรรม **NOR flash**: เขียนได้เฉพาะเปลี่ยนบิตจาก 1 เป็น 0 (`bytes[...] &= in[i]`) ต้อง erase ทั้ง sector ก่อนจึงกลับเป็น 1 ได้ (ถ้าโค้ดเขียนทับโดยไม่ erase จะเห็นข้อมูลเพี้ยนในเทสต์) คำสั่ง (จากคอมเมนต์บรรทัดที่ 2 ของไฟล์):

```bash
cd firmware/tests
g++ -std=c++17 -I../rmutt_esp32_air history_log_test.cpp -o t && ./t
```

`-I../rmutt_esp32_air` บอก compiler ให้หา `history_log.h` ที่นั่น ผลตอนทดลองรัน: `history_log: 2099 checks passed` ไฟล์ใช้แมโคร `CHECK(cond)` ที่ถ้าเงื่อนไขเท็จจะพิมพ์ `FAIL line N` แล้ว `exit(1)` และมีสถานการณ์หลัก 4 แบบ: (1) เก็บ → ส่งตามลำดับ → ยืนยัน → ลบหมด (2) รีบูตกลางทาง ข้อมูลยังอยู่และเขียนต่อจากตำแหน่งเดิม (3) เต็มแล้ววนทับ sector ที่เก่าที่สุด (4) พาร์ติชันมีขยะเดิม (เช่นข้อมูล coredump เก่า)

> [!WHY]
> ทดสอบ logic ของเฟิร์มแวร์บนคอมเพราะการแฟลชบอร์ดช้า ทดสอบเหตุการณ์อย่างไฟดับกลางเขียนทำซ้ำบนบอร์ดจริงยาก และถ้าข้อมูลเสียกลางสนามแก้ไขได้ต้องเดินไปแฟลชทุกห้อง (โค้ดต้องแยกส่วนที่ผูกกับฮาร์ดแวร์ ออกเป็น "flash" ที่สลับได้ ซึ่งคือ dependency injection)

### ลำดับที่ควรรันก่อน deploy

1. `cd backend && npm ci && npm test` (ต้อง `fail 0`)
2. `flutter test`
3. ถ้าแตะ `history_log.h` รัน `g++ ... && ./t`
4. `.\deploy\update-server.ps1` แล้วดูการตรวจท้ายสคริปต์ (health, 401 ของ 4 เส้นทาง, เว็บ 200)

ข้อจำกัด: ชุดทดสอบไม่ครอบคลุมการต่อ MariaDB/Mosquitto/ESP32 จริง สิ่งเหล่านั้นตรวจด้วยสคริปต์ปฏิบัติการ (`check_system.ps1`, `diagnose.ps1`, ส่วนตรวจใน `update-remote.sh`) ซึ่งเป็น "smoke test" บนระบบจริง

## หลักการเขียนโค้ดที่ใช้ในส่วนนี้

- **Idempotent (รันซ้ำได้ผลเหมือนเดิม)** — `setup-vps.sh` (เช็ก `command -v docker`, swap, `grep -q /swapfile /etc/fstab ||`), migration ทั้งหมด, `build-apk.ps1` (ไม่เติมสิทธิ์ซ้ำ), `sync-mqtt-cert.sh` (`cmp -s` ไม่ reload ถ้าไม่เปลี่ยน) ทำไม: คนรันสคริปต์ซ้ำเสมอ (หลังแก้ error, หลังอัปเดต) ถ้ารันซ้ำแล้วพังหรือทำของซ้ำ จะไม่กล้าใช้
- **Fail fast และตรวจก่อนทำ (guard clauses)** — `set -euo pipefail`, `throw` ทันทีที่ `$LASTEXITCODE -ne 0`, ตรวจ Docker/`.env`/`key.properties` ก่อนเริ่ม ทำไม: พังต้นทางข้อความชัด ดีกว่าพังกลางทางแล้วไม่รู้ว่าทำอะไรไปแล้วบ้าง
- **ยืนยันก่อนทำสิ่งที่ย้อนไม่ได้** — `init-env.sh` ถามพิมพ์ `yes` สองด่านและสำรอง `.env` ก่อนเสมอ, `change-keystore-password.ps1` สำรอง `.jks` แล้วคืนให้เมื่อพลาด, `seed-admin.sh` เตือนว่ารันซ้ำ = รีเซ็ตรหัส
- **Single source of truth ของค่าตั้ง** — `ServerConfig.ps1` + `server.config.json` ให้ทุกสคริปต์ Windows ใช้ host/user/port/domain ร่วมกัน แก้ที่เดียว และไฟล์นั้นไม่ขึ้น git
- **ความลับไม่เข้า git และไม่ค้างเป็นข้อความธรรมดา** — `.gitignore`, รหัสสุ่มจาก `openssl`, `chmod 600 .env`, `seed-admin.sh` ส่งรหัสทาง stdin แล้วล้างจาก `.env`, `db-tunnel.ps1` ส่งรหัส DB ทางคลิปบอร์ด ไม่พิมพ์ขึ้นจอ
- **Least privilege (สิทธิ์น้อยที่สุดที่ใช้ได้)** — Backend ใช้ DB user `rmutt_app` ไม่ใช่ root, Mosquitto เป็น uid 1883, DB ผูกกับ 127.0.0.1, แต่ละบอร์ดมีบัญชี MQTT ของตัวเอง, โฟลเดอร์ `firmware` ให้ uid 1000 เขียนได้เฉพาะโฟลเดอร์นั้น (ไม่ใช่ `chmod 777` และ Caddy ยัง mount แบบ `:ro`) (เพิ่ม 14 ต.ค. 2569)
- **Deadline loop (รอแบบมีเวลาหมด)** — `run_all.ps1` รอ DB/broker/health, `update-remote.sh` รอ backend 40×2 วินาที แทนการ `sleep` ตายตัว
- **ตรวจผลจริงหลัง deploy (smoke test)** — `update-remote.sh` ยิง `/api/health`, 4 เส้นทางต้องได้ 401, หน้าเว็บต้อง 200 และมี "RMUTT" แล้วค่อยบอกว่าสำเร็จ
- **Orchestrator/worker แยกเครื่อง** — Windows (`update-server.ps1`) เตรียมไฟล์และสั่งงาน, Ubuntu (`update-remote.sh`) ทำงานจริง เพราะ bash/Docker อยู่ที่เซิร์ฟเวอร์ และการรันบนเครื่องเดียวกับข้อมูลลดปัญหาเครือข่ายกลางทาง
- **Dependency injection ในเทสต์เฟิร์มแวร์** — `HistoryLog<Flash>` รับ flash ที่สลับเป็น `FakeFlash` ได้ ทดสอบบนคอมโดยไม่ต้องมีฮาร์ดแวร์

## คำถามที่อาจารย์อาจถาม

> [!ASK]
> **ถาม:** ทำไมต้องมีสคริปต์ ไม่พิมพ์คำสั่งเองตอน deploy?
> **ตอบ:** ระบบมีหลาย service และลำดับสำคัญ เช่น ต้องให้ Caddy ขอใบรับรองก่อน Mosquitto ถึงจะสตาร์ตได้ และต้องรอ backend พร้อมก่อน migrate พิมพ์เองแล้วลืมหรือสลับลำดับก็พัง สคริปต์ทำให้ขั้นตอนทำซ้ำได้ ตรวจก่อนทำ หยุดทันทีเมื่อพัง และอธิบายให้คนอื่นรับช่วงต่อได้ นอกจากนี้ทุกตัวรันซ้ำได้ ไม่ทำของซ้ำ

> [!ASK]
> **ถาม:** ทำไมใช้ทั้ง PowerShell และ bash?
> **ตอบ:** เครื่องพัฒนาเป็น Windows ซึ่งมี PowerShell กับ OpenSSH อยู่แล้ว ส่วนเซิร์ฟเวอร์เป็น Ubuntu ซึ่งมี bash เราเลยแบ่งงาน: สคริปต์ `.ps1` ฝั่ง Windows ทำหน้าที่ผู้สั่ง (อัปโหลดด้วย scp แล้วสั่งผ่าน ssh) และสคริปต์ `.sh` ทำงานจริงบนเซิร์ฟเวอร์ ไม่ต้องติดตั้งเครื่องมือเพิ่มทั้งสองฝั่ง

> [!ASK]
> **ถาม:** `set -euo pipefail` คืออะไร และทำไม `update-remote.sh` ใช้ `set -uo pipefail` ที่ไม่มี `-e`?
> **ตอบ:** `-e` หยุดเมื่อคำสั่งใดล้มเหลว `-u` ถือว่าตัวแปรที่ไม่ได้ตั้งค่าเป็น error `pipefail` ให้ท่อที่มีขั้นใดพังนับว่าพัง สคริปต์ติดตั้งใช้ครบสามตัวเพื่อไม่ให้ทำต่อบนฐานที่พัง ส่วน `update-remote.sh` ตั้งใจตัด `-e` เพราะบางขั้นล้มเหลวแล้วควรแค่เตือนและไปต่อ เช่น reload Caddy ไม่สำเร็จ เราจึงควบคุมเองด้วย `|| fail '...'` เฉพาะขั้นที่ต้องหยุดจริง

> [!ASK]
> **ถาม:** ทำไมรหัสผ่านทั้งหมดถูกสุ่มโดย `init-env.sh` ไม่ให้ผู้ดูแลตั้งเอง?
> **ตอบ:** รหัสที่คนตั้งมักเดาง่ายหรือซ้ำกับที่อื่น `openssl rand` ให้ค่าสุ่มระดับ crypto ยาว 32–48 ตัว เก็บใน `.env` ที่ `chmod 600` ไม่ขึ้น git และผู้ดูแลไม่ต้องจำ รหัสแอดมินของแอปเป็นข้อยกเว้นเพราะเป็นรหัสที่คนต้องใช้ล็อกอิน สคริปต์ถามแล้วล้างออกจาก `.env` หลัง seed

> [!ASK]
> **ถาม:** ทำไมต้องก๊อปใบรับรองจาก Caddy ให้ Mosquitto ทุกวัน?
> **ตอบ:** Caddy ขอและต่ออายุใบรับรอง Let's Encrypt เองทุก ~60 วัน แต่ Mosquitto (พอร์ต 8883) อ่านเป็นไฟล์ ถ้าไม่ก๊อปใบใหม่ ใบเก่าหมดอายุแล้วบอร์ด ESP32 ที่ต่อตรงพอร์ต 8883 ทุกตัวจะต่อ MQTTS ไม่ได้พร้อมกัน (บอร์ดที่ต่อผ่าน Funnel 8443 ใช้ใบ ts.net ที่กล่อง tailscale จัดการเอง จึงไม่โดน) `sync-mqtt-cert.sh` ให้ cron รันทุกวัน 03:10 เทียบไฟล์ด้วย `cmp` ถ้าเปลี่ยนจริงจึงก๊อปและส่ง SIGHUP ให้ Mosquitto โหลดใหม่โดยบอร์ดที่ต่ออยู่ไม่หลุด

> [!ASK]
> **ถาม:** ทำไมอัปโหลดเว็บด้วยการก๊อป "เข้าไปใน" โฟลเดอร์ `www` เดิม ไม่ใช้ `mv` สลับโฟลเดอร์ซึ่งดูง่ายกว่า?
> **ตอบ:** Docker bind mount ผูกโฟลเดอร์ตาม inode ไม่ใช่ตามชื่อ ถ้าสลับชื่อโฟลเดอร์ Caddy จะยังชี้โฟลเดอร์เก่าที่ถูกลบไปแล้ว แล้วตอบ 404 ทุกหน้าแบบไม่มีข้อความบอก เราจึงลบของข้างใน (`find ... -delete`) แล้ว `cp -a` เข้าไปในโฟลเดอร์เดิม และเตรียมไฟล์ใน `www.new` ก่อนเพื่อลดช่วงที่ไฟล์ไม่ครบ ถ้าเกิดแล้ว `update-remote.sh` ตรวจเจอและสร้างคอนเทนเนอร์ Caddy ใหม่ให้

> [!ASK]
> **ถาม:** ทำไมต้องใช้ keystore และทำไมห้ามทำหาย?
> **ตอบ:** Android ยอมให้ติดตั้งแอปทับเวอร์ชันเก่าเมื่อลายเซ็นเหมือนเดิมเท่านั้น ลายเซ็นมาจากกุญแจใน keystore ถ้าแจก APK ที่เซ็นด้วย debug key แล้วเปลี่ยนเครื่อง build ผู้ใช้ทุกคนต้องลบแล้วลงใหม่ ถ้ากุญแจหายก็อัปเดตแอปเดิมไม่ได้อีกเลย จึงสร้างครั้งเดียวด้วย `create-keystore.ps1` เก็บ `.jks` ไว้นอกโปรเจกต์ ไม่ commit (`.gitignore`) และสำรองไฟล์กับรหัสอย่างน้อยสองที่

> [!ASK]
> **ถาม:** ทำไม iOS ต้อง build บน GitHub Actions?
> **ตอบ:** Apple อนุญาตให้ build แอป iOS บน macOS เท่านั้น แต่เครื่องเราเป็น Windows `build-ios.yml` จึงยืมเครื่อง `macos-latest` ของ GitHub มา `flutter build ios --release --no-codesign` ได้ `.ipa` ที่ยังไม่เซ็น แล้วใช้ Sideloadly เซ็นด้วย Apple ID ฟรีลงเครื่อง ตั้งให้รันเฉพาะเมื่อกดเอง (`workflow_dispatch`) เพราะนาที macOS กินโควตาฟรีมากกว่า Linux ตอนกดรันจะถามที่อยู่ API (`api_base_url` ค่าเริ่มต้น `https://rmutt-energy.tailb292b4.ts.net/api`) แล้วส่งเข้า `--dart-define=API_BASE_URL` ให้แอป iOS ต่อเซิร์ฟเวอร์ถูกที่ (ส่งผ่าน `env` กัน shell injection) และมีขั้นเปลี่ยนไอคอน Flutter เป็นโลโก้ RMUTT Energy ด้วย `sips`

> [!ASK]
> **ถาม:** ไม่มีเครื่องที่ลง Flutter จะสร้างไฟล์ APK ได้อย่างไร?
> **ตอบ:** ใช้ `build-android.yml` บน GitHub Actions (เพิ่ม 9 ต.ค.) กดรันในแท็บ Actions กรอกที่อยู่ API แล้วเครื่อง Ubuntu ของ GitHub ติดตั้ง Java 17 + Flutter, build APK แบบ release และให้ดาวน์โหลดเป็น artifact 14 วัน กุญแจเซ็นเก็บใน GitHub Secrets เป็น base64 ไม่อยู่ใน repo ถ้ายังไม่ตั้ง Secrets จะเซ็นด้วย debug key และชื่อไฟล์ลงท้าย `-DEBUG-KEY` ใช้ทดสอบได้แต่ห้ามแจก เพราะอัปเดตทับด้วยไฟล์ที่เซ็นกุญแจจริงไม่ได้

> [!ASK]
> **ถาม:** ทดสอบอะไรบ้าง ครอบคลุมแค่ไหน?
> **ตอบ:** Backend 21 ไฟล์ 136 เทสต์ด้วย `node --test` (ความปลอดภัย ตารางเรียน นำเข้า Excel ปิดแอร์อัตโนมัติ ประวัติพลังงาน บัญชี MQTT schema doctor และตั้งแต่ 13–14 ต.ค. 2569 คำสั่งล้างค่าบอร์ด การตรวจไฟล์เฟิร์มแวร์ และกติกาแอร์สาย `DAIKIN_WIRED`) Flutter 21 ไฟล์ประมาณ 119 เทสต์ด้วย `flutter test` (รูปแบบพลังงาน กราฟ วันที่ไทย ตาราง การใช้ห้อง ภาคเรียน ตั้งค่า BLE) และตั้งแต่ 9 ต.ค. GitHub Actions รัน `flutter analyze` + `flutter test` ให้ทุกครั้งที่ push และเฟิร์มแวร์มีเทสต์ที่คอมไพล์รันบนคอมสำหรับตัวเก็บประวัติใน flash (2,099 checks) ส่วนที่ไม่ครอบคลุมคือการต่อระบบจริงทั้งชุด ซึ่งตรวจด้วย smoke test ใน `update-remote.sh`, `check_system.ps1` และ `diagnose.ps1`

> [!ASK]
> **ถาม:** ถ้าเซิร์ฟเวอร์พังหมด กู้ข้อมูลอย่างไร?
> **ตอบ:** cron สำรองฐานข้อมูลเป็น `.sql.gz` ทุกวัน 02:30 เก็บ 14 วัน (ปรับด้วย `BACKUP_KEEP_DAYS`) และส่งสำเนานอกเครื่องด้วย rsync ถ้าตั้ง `BACKUP_REMOTE` ไฟล์ที่ dump ไม่ครบจะถูกลบทิ้ง ไม่นับเป็น backup กู้คืนโดย `gunzip -c ไฟล์ | docker compose exec -T db mariadb ...` ติดตั้งเครื่องใหม่ตามไทม์ไลน์เดิม แล้วเว้น `db:init` กับ seed ตามหัวข้อ "ย้ายจากระบบเดิม" ใน DEPLOY.md ต้องตั้งค่าบอร์ดผ่านบลูทูธใหม่เมื่อโดเมนหรือบัญชี MQTT เปลี่ยน

> [!ASK]
> **ถาม:** หลังเพิ่มหน้าอัปโหลดเฟิร์มแวร์ ทำไมต้องแก้ `docker-compose.yml` และสคริปต์ deploy ด้วย?
> **ตอบ:** (เพิ่ม 14 ต.ค. 2569) เดิม Backend mount โฟลเดอร์ firmware แบบอ่านอย่างเดียว (`./firmware:/firmware:ro`) เพราะแค่แสดงรายการไฟล์ พออัปโหลดจากเว็บได้ Backend ต้องเขียนไฟล์ จึงเอา `:ro` ออก แต่แค่นั้นยังไม่พอ เพราะ Backend รันเป็น user `node` (uid 1000) ในคอนเทนเนอร์ ส่วนโฟลเดอร์บนเครื่องเป็นของผู้ดูแล สิทธิ์ไฟล์ของ Linux ดูที่ uid จึงต้อง `chown 1000:1000` ทั้งใน `setup-vps.sh` (เครื่องใหม่) และ `update-remote.sh` (เครื่องเดิมที่อัปเดต) ฝั่ง Caddy ยังอ่านอย่างเดียวเหมือนเดิม เพราะแค่เสิร์ฟไฟล์ให้บอร์ดดาวน์โหลด

> [!ASK]
> **ถาม:** ถ้าอัปโหลดเฟิร์มแวร์จากเว็บแล้วขึ้นว่า "Backend เขียนโฟลเดอร์ firmware ไม่ได้" จะแก้อย่างไร?
> **ตอบ:** ข้อความนี้มาจาก Backend เมื่อเขียนไฟล์แล้วเจอ `EACCES` (ไม่มีสิทธิ์) หรือ `EROFS` (mount อ่านอย่างเดียว) ตรวจสองอย่าง: (1) `docker-compose.yml` บนเซิร์ฟเวอร์ต้องเป็น `./firmware:/firmware` ไม่มี `:ro` (อัปเดตด้วย `update-server.ps1`) (2) `stat -c %u /opt/rmutt/firmware` ต้องได้ 1000 ถ้าไม่ใช่ให้ `sudo chown 1000:1000 /opt/rmutt/firmware` ซึ่ง `update-remote.sh` พยายามทำให้เองและเตือนคำสั่งนี้ถ้าทำไม่ได้

## สรุปและเช็กลิสต์ความเข้าใจ

ถ้าตอบข้อเหล่านี้ได้ แปลว่าเข้าใจบทนี้แล้ว

- [ ] แยกได้ว่า local dev กับ production ต่างกันอย่างไร (พอร์ต 1883 vs 8883 TLS, ACL vs Dynamic Security, `npm start` vs Docker Compose)
- [ ] เล่าลำดับของ `run_all.ps1` ทั้ง 7 ขั้นพร้อมเหตุผล (Docker → MariaDB → migrate/doctor → LAN IP + `.env` → Mosquitto + ACL → Backend → health → Flutter)
- [ ] บอกได้ว่า `check_system.ps1` กับ `diagnose.ps1` ต่างกันอย่างไร และเมื่อไรใช้ตัวไหน
- [ ] เรียงไทม์ไลน์ติดตั้งเซิร์ฟเวอร์ใหม่ได้ (upload → setup-vps → init-env → Caddy cert → sync-mqtt-cert → compose up → db:init/migrate → seed-admin → doctor → health) และตอบได้ว่าทำไมลำดับนี้
- [ ] อธิบายได้ว่า `update-server.ps1` ส่งอะไรขึ้นไป อะไรที่ไม่ส่ง (`mosquitto.conf`, `.env`, `node_modules`) และ `update-remote.sh` ทำ 6 ขั้นอะไรบ้าง (รวมการสร้างกล่อง tailscale ใหม่ในขั้น 5 และเหตุผล)
- [ ] อธิบาย `set -euo pipefail`, exit code, `$LASTEXITCODE` และทำไม `update-remote.sh` ไม่ใช้ `-e`
- [ ] อธิบายปัญหา CRLF และปัญหา bind mount/inode ของ `www` พร้อมวิธีแก้
- [ ] อธิบาย cron 2 งาน (02:30 backup, 03:10 sync cert), การเก็บ backup 14 วัน และวิธีกู้คืน
- [ ] อธิบายได้ว่า keystore / `key.properties` / debug vs release ต่างกันอย่างไร และทำไมกุญแจห้ามหาย
- [ ] อธิบายได้ว่าทำไม iOS ใช้ GitHub Actions บน macOS และได้ไฟล์อะไร รวมถึง input `api_base_url`, ขั้นใส่ไอคอน และเหตุที่ส่งค่าผ่าน `env`
- [ ] ระบุได้ว่าอะไรอยู่ใน `.gitignore` และทำไม (ความลับ, กุญแจ, ข้อมูล broker, ค่าเซิร์ฟเวอร์)
- [ ] บอกวิธีรันทดสอบทั้งสามชั้น (`npm test`, `flutter test`, `g++ ... && ./t`) และตอบได้ว่าแต่ละชั้นทดสอบอะไร
- [ ] ตรวจระบบจริงหลัง deploy ด้วย `/api/health` ได้ และรู้ว่าต้องเห็นอะไร (`status ok`, `connected true`, `deviceAuth dynsec`)
- [ ] อธิบายขั้นตอนอัปเดตเฟิร์มแวร์แบบใหม่ (Export Compiled Binary → หน้าเฟิร์มแวร์ในเว็บ เลือกแท็บชนิดบอร์ด → อัปโหลด → สั่งอัปเดต) และกติกาชื่อไฟล์ `occ` / `wired`/`slm8` / นอกนั้น (เพิ่ม 14 ต.ค. 2569)
- [ ] บอกได้ว่าทำไมโฟลเดอร์ `/opt/rmutt/firmware` ต้องเป็นของ uid 1000 และสคริปต์ไหนตั้งให้ (`setup-vps.sh` บรรทัด 90–91, `update-remote.sh` บรรทัด 44–49)
- [ ] บอกจำนวนเทสต์ Backend ปัจจุบัน (21 ไฟล์ 136 เทสต์) และเทสต์ที่เพิ่มรอบล่าสุด (`unprovision` 2, `firmware` +4, `air-conditioner` +4)
