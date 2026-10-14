# Deploy — RMUTT Save Energy (เซิร์ฟเวอร์ของมหาวิทยาลัย)

สเปกเครื่องและสิ่งที่ต้องขอจากฝ่ายไอที อยู่ใน `SERVER_REQUIREMENTS.md`

| ค่า | |
|---|---|
| ระบบปฏิบัติการ | Ubuntu Server 22.04 หรือ 24.04 LTS |
| โดเมน | ตัวอย่าง `energy.eng.rmutt.ac.th` (ขอจากฝ่ายไอที) |
| พอร์ตที่ต้องเข้าถึงได้ | `443` HTTPS · `8883` MQTTS · `80` ขอใบรับรอง · `22` SSH (เฉพาะผู้ดูแล) |
| ไม่เปิดออกนอกเครื่อง | MariaDB `3306` · MQTT `1883` |

```text
   แอปมือถือ / เบราว์เซอร์            ESP32 (Wi-Fi ในอาคาร)
         HTTPS 443                        MQTTS 8883
             │                                │
             ▼                                ▼
      ┌─────────────────────────────────────────────┐
      │ caddy ──> backend ──> db (MariaDB)          │
      │   │          └──────> mqtt (Mosquitto 1883) │
      │   └─ /firmware/*.bin  (อัปเดตบอร์ดผ่าน Wi-Fi)  │
      └─────────────────────────────────────────────┘
```

---

## 0 · ตั้งค่าบนเครื่อง Windows (ครั้งเดียว)

```powershell
cd "$HOME\Downloads\rmutt_save_energy_complete_mqtt\cpe_air_remote"
Copy-Item deploy\server.config.example.json deploy\server.config.json
notepad deploy\server.config.json      # แก้ host, user, domain
```

ไฟล์ `server.config.json` ไม่ถูก commit และไม่ถูกอัปโหลด สคริปต์ทุกตัว
(`update-server`, `deploy-web`, `upload`, `db-tunnel`, `build-apk`) อ่านค่าจากไฟล์นี้

แนะนำให้ตั้ง SSH key จะได้ไม่ต้องพิมพ์รหัสทุกครั้ง:

```powershell
ssh-keygen -t ed25519
type $HOME\.ssh\id_ed25519.pub | ssh <user>@<host> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

---

## 1 · ติดตั้งเครื่อง (ครั้งเดียว)

```powershell
.\deploy\upload.ps1
ssh <user>@<host>
```

บนเซิร์ฟเวอร์:

```bash
cd /opt/rmutt
sudo bash setup-vps.sh            # Docker, เวลา, swap, cron สำรองข้อมูล/ใบรับรอง
# ถ้าฝ่ายไอทีไม่ได้ดูแล firewall ให้ ใช้: sudo bash setup-vps.sh --firewall
exit                              # ออกแล้วเข้าใหม่ ให้สิทธิ์กลุ่ม docker มีผล
```

> ถ้า `upload.ps1` บอกว่าไม่มี `/opt/rmutt` ให้สร้างก่อน:
> `ssh <user>@<host> "sudo mkdir -p /opt/rmutt && sudo chown $USER /opt/rmutt"`

---

## 2 · สร้าง `.env` และบัญชี MQTT

```bash
cd /opt/rmutt && sudo bash init-env.sh
```

สคริปต์จะถามโดเมน รหัสแอดมินของแอป และบัญชีอีเมลสำหรับส่ง OTP
แล้วสุ่มรหัสที่เหลือทั้งหมด (DB root, DB app, JWT, OTP, MQTT, MQTT_DEVICE_SECRET)
และสร้างไฟล์บัญชี Mosquitto Dynamic Security ให้

---

## 3 · ขอใบรับรอง HTTPS

Mosquitto สตาร์ตไม่ขึ้นถ้ายังไม่มีใบรับรอง จึงต้องเปิด Caddy ก่อน

```bash
cd /opt/rmutt
docker compose up -d caddy
docker compose logs -f caddy      # รอ certificate obtained แล้ว Ctrl+C
sudo bash sync-mqtt-cert.sh
```

ถ้าค้าง: DNS ยังไม่ชี้มาที่เครื่องนี้ หรือพอร์ต 80 เข้าจากอินเทอร์เน็ตไม่ได้

```bash
dig +short <โดเมน>
curl -s ifconfig.me; echo        # สองค่านี้ต้องตรงกัน (หรือเป็น NAT ที่ฝ่ายไอทีตั้งให้)
```

> ถ้ามหาวิทยาลัยไม่ให้เปิดพอร์ต 80 หรือจะใช้ใบรับรองของมหาวิทยาลัยเอง
> ดูหัวข้อ "ใช้ใบรับรองของมหาวิทยาลัย" ท้ายไฟล์

---

## 4 · เปิดทุก service และสร้างฐานข้อมูล

```bash
cd /opt/rmutt
docker compose up -d --build
docker compose ps                              # ทุกตัวต้อง healthy/running
docker compose exec backend npm run db:init
docker compose exec backend npm run db:migrate:settings
docker compose exec backend npm run db:migrate:firmware
docker compose exec backend npm run db:migrate:history
bash seed-admin.sh                             # สร้างแอดมิน แล้วลบรหัสออกจาก .env
docker compose exec backend npm run db:doctor
docker compose restart backend
```

ครั้งต่อไปที่อัปเดตโค้ด ใช้คำสั่งเดียวจากเครื่อง Windows (ใน **PowerShell** ที่โฟลเดอร์ `cpe_air_remote`):

```powershell
git pull
.\deploy\update-server.ps1
```

ถ้า Terminal เป็น Command Prompt (บรรทัดขึ้นต้น `C:\...>` ไม่มี `PS`) การพิมพ์ชื่อไฟล์ `.ps1`
จะเปิด Notepad แทนการรัน ให้ใช้:

```bat
powershell -ExecutionPolicy Bypass -File .\deploy\update-server.ps1
```

---

## 5 · ตรวจรับงาน

```bash
curl -s https://<โดเมน>/api/health
```

ต้องได้ `"status":"ok"`, `"connected":true` และ `"deviceAuth":"dynsec"`

ดู log ว่า Backend สร้างบัญชี MQTT ของบอร์ดแล้ว:

```bash
docker compose logs backend | grep "per-device accounts"
```

ทดสอบ rate limit (ต้องล็อกเฉพาะเครื่องที่กรอกผิด ไม่ล็อกทุกคน):
กรอกรหัสผิด 11 ครั้งจากมือถือเครื่องหนึ่ง แล้วล็อกอินจากอีกเครื่องต้องผ่าน

---

## 6 · ESP32 และแอป

1. แฟลชเฟิร์มแวร์ผ่าน USB หนึ่งครั้ง (แอร์ `2.4.0`, เซ็นเซอร์ `1.3.0`)
   - Arduino IDE: **Tools → Partition Scheme → "No FS 4MB (2MB APP x2)"**
   - ไฟล์ `partitions.csv` ในโฟลเดอร์สเก็ตช์ทำให้มีช่องแอปสองช่องสำหรับ OTA
     และพื้นที่ `rmuttlog` 64 KB ของบอร์ดแอร์สำหรับเก็บข้อมูลตอนเน็ตหลุด
     (ต้องแฟลชผ่าน USB เพราะ OTA เปลี่ยนตารางพาร์ติชันไม่ได้)
2. ตั้งค่าบอร์ดผ่านบลูทูธใหม่ทุกตัว (บอร์ดจะได้ user/รหัส MQTT ของตัวเอง)
3. สร้าง APK:

```powershell
.\create-keystore.ps1     # ครั้งเดียว สำรองไฟล์ .jks และรหัสไว้นอกเครื่อง
.\build-apk.ps1           # ใช้ https://<domain>/api จาก server.config.json
```

### อัปเดตเฟิร์มแวร์ผ่าน Wi-Fi (ครั้งต่อ ๆ ไป)

1. Arduino IDE: **Sketch → Export Compiled Binary** ได้ไฟล์ `<สเก็ตช์>.ino.bin`
   (ใช้ไฟล์ `.ino.bin` เท่านั้น ไม่ใช่ `.merged.bin`)
2. เว็บแอป → เมนู **เฟิร์มแวร์** → เลือกแท็บชนิดบอร์ด
   (**แอร์ IR** / **สายแอร์ Daikin** / **เซ็นเซอร์ LD2410**)
3. ลากไฟล์มาวางในช่องอัปโหลดของแท็บนั้น ถ้าชื่อไฟล์ยังไม่มีเลขรุ่น
   เว็บจะถามรุ่น (ดูจาก `FIRMWARE_VERSION` หรือบรรทัด `Firmware:` ใน Serial)
   แล้วตั้งชื่อเป็น `<สเก็ตช์>-<รุ่น>.bin` ให้เอง
4. ตารางบอร์ดจะบอกว่าบอร์ดไหนยังเก่า กด **อัปเดต** ทีละตัว หรือ
   **เลือกทุกตัวที่ยังเก่า** แล้วกดปุ่มที่แถบด้านล่าง
5. รอ 1–2 นาที สถานะจะเปลี่ยนเป็น "ล่าสุดแล้ว" ถ้าไม่สำเร็จจะขึ้นสาเหตุเป็นสีแดง
   และบอร์ดทำงานต่อด้วยเฟิร์มแวร์เดิม

ชนิดของไฟล์ดูจากชื่อ: มีคำว่า `occ` = เซ็นเซอร์, มี `wired` หรือ `slm8` = สายแอร์,
นอกนั้น = แอร์ IR Backend ไม่ยอมให้อัปโหลดไฟล์เข้าผิดแท็บ และไม่ยอมสั่งไฟล์ผิดชนิดให้บอร์ด
ไฟล์ต้องขึ้นต้นด้วยไบต์ `0xE9` (โปรแกรม ESP32) และไม่เกิน 1,984 KB (ขนาดช่องใน `partitions.csv`)

โฟลเดอร์ `/opt/rmutt/firmware` ต้องเป็นของ uid 1000 (user `node` ใน container backend)
`update-remote.sh` ตั้งให้เองทุกครั้ง ถ้าอัปโหลดแล้วขึ้นว่าเขียนโฟลเดอร์ไม่ได้ ให้รัน
`sudo chown 1000:1000 /opt/rmutt/firmware` ยังวางไฟล์ด้วย `scp` เข้าโฟลเดอร์นี้ได้เหมือนเดิม

---

### ข้อมูลไฟฟ้าตอนบอร์ดเน็ตหลุด

บอร์ดแอร์ (เฟิร์มแวร์ 2.4.0 ขึ้นไป) เก็บค่าไฟสรุปทุก 5 นาทีไว้ในบอร์ดเองตอนต่อเซิร์ฟเวอร์ไม่ได้
เก็บได้ประมาณ 7 วัน (2,048 รายการ) ถ้าเกินจะทับของเก่าที่สุด ข้อมูลไม่หายแม้ไฟดับหรือรีบูต
และยังส่งได้แม้เปลี่ยน Wi-Fi ใหม่ผ่านบลูทูธ

พอต่อได้ บอร์ดรอ 5–45 วินาทีแบบสุ่ม (กันทั้งตึกส่งพร้อมกัน) แล้วส่งทีละ 10 รายการ
รอเซิร์ฟเวอร์ตอบว่าบันทึกแล้วจึงลบชุดนั้นออกจากบอร์ดและส่งชุดถัดไป ข้อมูล 7 วันส่งหมดในไม่กี่นาที
หน้า "ห้องและอุปกรณ์" แสดงจำนวนที่ยังค้างส่ง

ข้อจำกัด: ถ้าบอร์ดบูตขึ้นมาตอนไม่มีเน็ตเลย จะยังไม่รู้เวลาจริง จึงยังเก็บไม่ได้จนกว่าจะต่อเน็ตได้ครั้งแรก
(เลขมิเตอร์ของ PZEM ยังนับต่อ พลังงานรวมไม่หาย แต่จะไปรวมอยู่ในชั่วโมงที่ต่อได้)

## 7 · ทดลองระบบปิดแอร์อัตโนมัติแบบนำร่อง

เปิดใช้จริงทีละน้อย เพราะเกณฑ์ของเรดาร์ (พลังงานนิ่ง > 25) ยังไม่ได้ปรับตามห้องจริง

1. เว็บแอป → ห้องและอุปกรณ์ → เครื่องปรับอากาศ → ปิดสวิตช์ "ปิดอัตโนมัติ"
   ทุกเครื่อง ยกเว้น 2–3 ห้องนำร่อง
2. ใช้งาน 1–2 สัปดาห์ ดูหน้า "การแจ้งเตือน" ว่ามีการปิดแอร์ตอนที่ยังมีคนอยู่หรือไม่
3. ถ้าไม่มีปัญหา ค่อยเปิดห้องอื่นเพิ่ม

---

## สำรองและกู้คืนข้อมูล

cron สำรองอัตโนมัติทุกวัน 02:30 ไว้ที่ `/opt/rmutt/backups` (เก็บ 14 วัน)
ถ้าตั้ง `BACKUP_REMOTE` ใน `.env` จะส่งสำเนาออกนอกเครื่องให้ด้วย

```bash
sudo bash /opt/rmutt/backup-db.sh           # สำรองเดี๋ยวนี้
tail /var/log/rmutt-backup.log              # ผลของรอบอัตโนมัติ

# กู้คืน
gunzip -c backups/rmutt-2026-10-01_0230.sql.gz | \
  docker compose exec -T db mariadb -uroot -p"$(grep ^DB_ROOT_PASSWORD .env | cut -d= -f2)" rmutt_save_energy
```

ทดลองกู้คืนลงเครื่องทดสอบอย่างน้อยเทอมละครั้ง backup ที่ไม่เคยลองกู้ถือว่ายังไม่มี

---

## ย้ายจากระบบเดิม (VPS duckdns)

```bash
# บนเครื่องเดิม
cd /opt/rmutt && source <(grep -E '^(DB_PASSWORD|DB_DATABASE)=' .env)
docker compose exec -T db mariadb-dump -uroot -p"$DB_PASSWORD" --single-transaction "$DB_DATABASE" | gzip > old.sql.gz
```

คัดลอก `old.sql.gz` ไปเครื่องใหม่ แล้วหลังขั้นที่ 4 (ข้าม `db:init` และ `seed:admin`):

```bash
gunzip -c old.sql.gz | docker compose exec -T db mariadb -uroot -p"$(grep ^DB_ROOT_PASSWORD .env | cut -d= -f2)" rmutt_save_energy
docker compose exec backend npm run db:doctor -- --fix
docker compose restart backend
```

บอร์ดทุกตัวต้องตั้งค่าผ่านบลูทูธใหม่ เพราะโดเมนและบัญชี MQTT เปลี่ยน

---

## ใช้ใบรับรองของมหาวิทยาลัย (ถ้าไม่ใช้ Let's Encrypt)

1. วาง `fullchain.pem` และ `privkey.pem` ไว้ที่ `/opt/rmutt/certs/`
2. แก้ `Caddyfile` บรรทัดแรกเป็น `{$DOMAIN} { tls /certs/fullchain.pem /certs/privkey.pem`
   และเพิ่ม `- ./certs:/certs:ro` ใน volumes ของ caddy
3. ก๊อปไฟล์ชุดเดียวกันไปที่ `mosquitto/certs/` (เจ้าของ uid 1883)
4. **เปลี่ยนใบรากในเฟิร์มแวร์** `letsencrypt_ca.h` เป็นใบรากของผู้ออกใบรับรองนั้น
   (`firmware\update-root-ca.ps1 -Urls <url ของใบราก>`) แล้วแฟลชบอร์ดใหม่
   ไม่งั้น ESP32 จะต่อ MQTTS ไม่ได้

---

## คำสั่งที่ใช้บ่อย

```bash
cd /opt/rmutt
docker compose ps
docker compose logs -f backend
docker compose restart backend
bash db-view.sh                        # ดูข้อมูลแบบอ่านอย่างเดียว
sudo bash fix-mqtt-permissions.sh      # เมื่อ rmutt-mqtt วน Restarting
```

ติดตามสถานะจากภายนอก: ตั้ง UptimeRobot (หรือระบบ monitor ของมหาวิทยาลัย)
ให้เรียก `https://<โดเมน>/api/health` ทุก 5 นาที และแจ้งเตือนเมื่อไม่ได้ `"connected":true`
