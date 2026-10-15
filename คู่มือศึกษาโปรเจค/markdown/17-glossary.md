# อภิธานศัพท์

บทนี้รวบรวมคำศัพท์เทคนิคที่ใช้ตลอดคู่มือ จัดเป็นหมวดตามส่วนของระบบ แต่ละคำบอกความหมายแบบภาษาง่าย และชี้ว่าในโปรเจคนี้เจอที่ไหน (ไฟล์หรือส่วนประกอบ) ถ้าอ่านบทไหนแล้วเจอคำที่ไม่คุ้น ให้กลับมาค้นที่นี่ ตัวเลขและชื่อทุกตัวอ้างจากโค้ดในแต่ละบท ถ้าสงสัยรายละเอียดให้เปิดบทนั้นดูต่อ


## เครือข่ายและอินเทอร์เน็ต

| คำศัพท์ | ความหมาย (ภาษาง่าย) | ใช้ตรงไหนในโปรเจค |
|---|---|---|
| CA (Certificate Authority) | องค์กรที่ออกใบรับรองให้เว็บ เบราว์เซอร์เชื่อ CA เหล่านี้อยู่แล้วจึงขึ้นรูปกุญแจว่าปลอดภัย | Let's Encrypt เป็น CA ของโปรเจค; บอร์ดฝังใบรับรองรากไว้ใน `firmware/*/letsencrypt_ca.h` |
| DNS | ระบบแปลงชื่อโดเมนเป็นเลข IP | ชื่อ `rmutt-energy.duckdns.org` ถูกแปลงเป็น IP ผ่าน DNS (บท 04) |
| DNS-01 | วิธีพิสูจน์ว่าเป็นเจ้าของโดเมนโดยเพิ่มระเบียน TXT ใน DNS ไม่ต้องเปิดพอร์ตให้คนนอกเข้า | Caddy ขอใบรับรองจาก Let's Encrypt ผ่าน DuckDNS ใช้ `deploy/caddy.Dockerfile` และ `deploy/Caddyfile` |
| DuckDNS | บริการฟรีที่ให้ชื่อโดเมนย่อยของ duckdns.org แล้วชี้ไปที่ IP ที่เราตั้งได้ | โดเมนของเซิร์ฟเวอร์ชี้ไป IP ภายในมหาวิทยาลัย; ใช้คู่กับปลั๊กอิน DuckDNS ของ Caddy |
| Firewall | ตัวกรองที่อนุญาตหรือบล็อกทราฟฟิกตามพอร์ตและทิศทาง | ไฟร์วอลล์ของมหาวิทยาลัยกันคนนอกเข้าเซิร์ฟเวอร์ จึงต้องใช้ Tailscale Funnel (บท 04) |
| Funnel (Tailscale Funnel) | ฟีเจอร์ของ Tailscale ที่เปิดบริการในเครื่องให้คนบนอินเทอร์เน็ตเข้าผ่านชื่อ `*.ts.net` โดยไม่ต้องเปิดพอร์ตที่ firewall | แอปมือถือใช้ `ts.net:443` และบอร์ด ESP32 ใช้ `ts.net:8443` (MQTT) เป็นค่าเริ่มต้น; ตั้งค่าที่ `deploy/tailscale-serve.json` |
| HTTP / HTTPS | โปรโตคอลที่เบราว์เซอร์และแอปใช้คุยกับเว็บเซิร์ฟเวอร์ HTTPS คือ HTTP ที่เข้ารหัสด้วย TLS | แอปและเว็บเรียก Backend ผ่าน HTTPS ที่ Caddy รับไว้ (พอร์ต 443) |
| IP address | เลขที่อยู่ของเครื่องในเครือข่าย | เซิร์ฟเวอร์มี IP ภายใน 10.x ของมหาวิทยาลัย (บท 04) |
| Let's Encrypt | CA ฟรีที่ออกใบรับรอง TLS ให้โดเมน อายุสั้นและต่ออายุอัตโนมัติ | Caddy ขอและต่อใบรับรองให้เอง; บอร์ดเชื่อ Let's Encrypt ผ่าน `letsencrypt_ca.h` |
| MQTTS | MQTT ที่เข้ารหัสด้วย TLS พอร์ตมาตรฐานคือ 8883 | บอร์ด ESP32 ต่อผ่าน Tailscale Funnel พอร์ต 8443 เป็นค่าเริ่มต้น หรือต่อตรง Mosquitto พอร์ต 8883 ในมหาวิทยาลัย |
| NAT | การแปลงที่อยู่ IP ที่ router ใช้ ทำให้เครื่องข้างในใช้ IP ส่วนตัวแต่ออกเน็ตด้วย IP สาธารณะร่วมกันได้ | เป็นเหตุผลที่คนนอกต่อเข้าเซิร์ฟเวอร์ภายในตรง ๆ ไม่ได้ (บท 04) |
| Overlay network | เครือข่ายเสมือนที่สร้างทับอินเทอร์เน็ตเดิม ให้เครื่องต่าง ๆ คุยกันเหมือนอยู่ LAN เดียวกัน | Tailscale เป็น overlay network (VPN แบบ mesh) |
| Port (พอร์ต) | เลขประตูของเครื่อง แยกว่าข้อมูลเข้าโปรแกรมไหน | 80/443 = Caddy, 3000 = Backend, 3306 = MariaDB, 1883/8883 = Mosquitto, 8080 = Caddy ให้ Tailscale เข้า, 8443 = Funnel ส่งต่อ MQTT ของบอร์ด |
| Reverse proxy | เซิร์ฟเวอร์ด่านหน้าที่รับคำขอแล้วส่งต่อให้บริการข้างหลัง ทำ HTTPS และใส่ header ให้ด้วย | Caddy ส่ง `/api/*` ต่อไป Backend ที่พอร์ต 3000 และเสิร์ฟเว็บแอป (`deploy/Caddyfile`) |
| Serve (Tailscale Serve) | ฟีเจอร์ Tailscale ที่เปิดบริการให้เฉพาะเครื่องในเครือข่าย Tailscale (ต่างจาก Funnel ที่เปิดสู่สาธารณะ) | กำหนดคู่กับ Funnel ใน `deploy/tailscale-serve.json` |
| SSH | การล็อกอินเข้าเครื่องอื่นผ่านเครือข่ายแบบเข้ารหัส | `update-server.ps1` ใช้ SSH สั่งงานบนเซิร์ฟเวอร์; `db-tunnel.ps1` ใช้ SSH tunnel |
| SSH tunnel | การใช้ SSH ส่งต่อพอร์ตจากเครื่องเราไปยังพอร์ตบนเซิร์ฟเวอร์อย่างปลอดภัย | `db-tunnel.ps1` เปิดทางให้ดู MariaDB บนเซิร์ฟเวอร์จากเครื่องผู้พัฒนา |
| Tailscale | บริการ VPN แบบ mesh ที่ตั้งง่าย ใช้ WireGuard ข้างใน | รันเป็น container `rmutt-tailscale` ใน `deploy/docker-compose.yml` |
| TLS | โปรโตคอลเข้ารหัสการเชื่อมต่อ (รุ่นต่อจาก SSL) ใช้ใน HTTPS และ MQTTS | Mosquitto listener 8883 กำหนดขั้นต่ำ `tlsv1.2` ใน `mosquitto.conf`; ทาง Funnel 8443 กล่อง tailscale เป็นคนถอด TLS (`TerminateTLS`) |
| TRUST_PROXY | ค่าตั้งของ Express บอกว่าเชื่อ header `X-Forwarded-For` จากกี่ชั้นของ proxy เพื่อให้เห็น IP จริงของผู้ใช้ | `TRUST_PROXY=2` ใน `.env` (Tailscale + Caddy) ใช้กับ rate limit ใน `backend/src/app.js` |

## เซิร์ฟเวอร์และ DevOps

| คำศัพท์ | ความหมาย (ภาษาง่าย) | ใช้ตรงไหนในโปรเจค |
|---|---|---|
| Bind mount | การเอาโฟลเดอร์จริงของเครื่อง host ไปแปะให้ container เห็น | mount คอนฟิก Mosquitto เข้า `/mosquitto/config` ใน `deploy/docker-compose.yml` |
| Caddy | เว็บเซิร์ฟเวอร์/reverse proxy ที่ทำ HTTPS อัตโนมัติ | service `caddy` ใน compose; ตั้งค่าที่ `deploy/Caddyfile` |
| Caddyfile | ไฟล์ตั้งค่าของ Caddy เขียนง่ายกว่า nginx | `deploy/Caddyfile` กำหนดโดเมน, reverse proxy, แคช, header ความปลอดภัย |
| Container | กล่องที่รันโปรแกรมแยกจากกัน มีไฟล์และเครือข่ายของตัวเอง เบากว่าเครื่องเสมือน | `rmutt-db`, `rmutt-mqtt`, backend, `rmutt-caddy`, `rmutt-tailscale` |
| cron | ตัวตั้งเวลารันคำสั่งอัตโนมัติของ Linux | `setup-vps.sh` สร้างไฟล์ใน `/etc/cron.d/` เช่นให้ `backup-db.sh` ทำงานตามเวลา |
| Docker | เครื่องมือรันโปรแกรมใน container | ทั้งชุดเซิร์ฟเวอร์รันบน Docker (บท 04, 13) |
| Docker Compose | เครื่องมือประกาศหลาย container ในไฟล์ YAML เดียว แล้วสั่งเปิด/ปิดทีเดียว | `deploy/docker-compose.yml`; `docker compose up -d --build` |
| Dockerfile | สูตรสร้าง image ว่าเริ่มจากอะไรและติดตั้งอะไร | `deploy/backend.Dockerfile` และ `deploy/caddy.Dockerfile` |
| Environment variable (ตัวแปรสภาพแวดล้อม) | ค่าตั้งที่ส่งให้โปรแกรมจากภายนอก แยกจากโค้ด เช่น รหัสผ่านและ URL | `.env` สร้างโดย `deploy/init-env.sh`; อ่านใน `backend/src/config.js` |
| GitHub Actions | บริการของ GitHub ที่รันงานอัตโนมัติ (เช่น ทดสอบโค้ด) ตามไฟล์ YAML | `.github/workflows/build-ios.yml` (build iOS บน macOS) |
| Health check | การเรียกเล็ก ๆ ถามว่าระบบยังมีชีวิตอยู่ไหม | `GET /api/health` ของ Backend และ `healthcheck` ของ db/mqtt ใน compose |
| Image (Docker image) | แม่แบบแช่แข็งของ container สร้างจาก Dockerfile หรือดึงจากต้นทาง | `mariadb:11`, `eclipse-mosquitto:2.0`, `tailscale/tailscale:stable`, `rmutt-caddy:duckdns` |
| Keystore | ไฟล์กุญแจที่ใช้เซ็นแอป Android ต้องใช้ตัวเดิมตลอด ไม่งั้นติดตั้งทับแอปเดิมไม่ได้ | สร้างด้วย `create-keystore.ps1`; เปลี่ยนรหัสด้วย `change-keystore-password.ps1` |
| PowerShell | เชลล์ของ Windows ใช้เขียนสคริปต์ไฟล์ `.ps1` | `run_all.ps1`, `build-apk.ps1`, `update-server.ps1`, `deploy-web.ps1` |
| restart: unless-stopped | นโยบายให้ container เริ่มใหม่เองเมื่อล้มหรือเครื่องรีบูต ยกเว้นเราสั่งหยุดเอง | ทุก service ใน `deploy/docker-compose.yml` |
| rsync / scp | คำสั่งคัดลอกไฟล์ข้ามเครื่องผ่าน SSH (rsync คัดลอกเฉพาะที่เปลี่ยน) | `update-server.ps1`/`update-remote.sh` ส่งโค้ดขึ้นเซิร์ฟเวอร์ |
| set -euo pipefail | สวิตช์ความปลอดภัยของ bash: หยุดเมื่อคำสั่งพัง, ห้ามใช้ตัวแปรที่ไม่ได้ตั้ง, จับความผิดพลาดใน pipe | บรรทัดต้นของสคริปต์ใน `deploy/*.sh` |
| Volume | ที่เก็บข้อมูลถาวรของ container ข้อมูลไม่หายเมื่อสร้าง container ใหม่ | ข้อมูล MariaDB และ Mosquitto (`dynamic-security.json`, retained) ใน `deploy/docker-compose.yml` |
| Artifact (GitHub Actions) | ไฟล์ผลลัพธ์ที่ workflow อัปโหลดเก็บไว้ให้ดาวน์โหลดจากหน้าผลการรัน มีวันหมดอายุ | `build-android.yml` และ `build-ios.yml` เก็บไฟล์ APK/IPA ไว้ 14 วัน (บท 14) |
| GitHub Secrets | ที่เก็บความลับของ repo (รหัส กุญแจ) workflow อ่านได้ แต่คนดูโค้ดไม่เห็น | กุญแจเซ็น APK `ANDROID_KEYSTORE_BASE64` และ `ANDROID_KEY_PASSWORD` (บท 14) |
| base64 | วิธีแปลงข้อมูลไบนารีเป็นตัวอักษรธรรมดา ใช้เมื่อที่เก็บรับได้แต่ข้อความ | เก็บไฟล์ `.jks` ใน GitHub Secrets แล้ว `base64 -d` ถอดกลับตอน build (บท 14) |

## ความปลอดภัย

| คำศัพท์ | ความหมาย (ภาษาง่าย) | ใช้ตรงไหนในโปรเจค |
|---|---|---|
| ACL (Access Control List) | รายการสิทธิ์ว่าใครอ่าน/เขียนอะไรได้ ใน MQTT คือสิทธิ์ publish/subscribe ต่อ topic | บอร์ดแต่ละตัวมี ACL ของตัวเองใน `backend/src/utils/mqtt-accounts.js` |
| Authentication / Authorization | Authentication = พิสูจน์ว่าเป็นใคร (ล็อกอิน) ส่วน Authorization = ตรวจว่ามีสิทธิ์ทำสิ่งนั้นไหม | `middleware/authenticate.js` (ยืนยันตัวตน) และ `middleware/require-admin.js` (ตรวจสิทธิ์แอดมิน) |
| bcrypt (bcryptjs) | อัลกอริทึม hash รหัสผ่านที่ตั้งใจให้ช้า เพื่อให้เดารหัสยาก | `routes/auth.js` และ `routes/users.js` ใช้ cost 12 |
| Bearer token | วิธีแนบ token ใน header `Authorization: Bearer <token>` ทุกคำขอ | แอปและเว็บส่ง JWT นี้ไป Backend |
| CORS | กติกาของเบราว์เซอร์ว่าหน้าจาก origin หนึ่งอ่านคำตอบจากอีก origin ได้ไหม เซิร์ฟเวอร์ต้องอนุญาตผ่าน header | ใช้แพ็กเกจ `cors` ใน `backend/src/app.js`; ค่า `APP_ORIGIN` |
| CSP (Content-Security-Policy) | header ที่บอกเบราว์เซอร์ว่าหน้านี้โหลด/รันอะไรได้บ้าง ช่วยลดผลของ XSS | ตั้งใน `deploy/Caddyfile` (และเว็บไม่ใช้ inline script) |
| Defense in depth | ป้องกันหลายชั้น ชั้นหนึ่งพลาดอีกชั้นยังกันได้ | ACL รายบอร์ด + TLS + token + rate limit (บท 08, 09) |
| Fail-safe | ออกแบบให้เมื่อพังหรือไม่แน่ใจ ระบบเลือกทางที่ไม่เกิดอันตราย | auto-off ไม่ปิดแอร์ถ้าเซ็นเซอร์ไม่น่าเชื่อถือ (`utils/auto-off.js`) |
| HMAC | วิธีสร้างค่าแฮชโดยใช้กุญแจลับร่วม ตรวจได้ว่าข้อมูลถูกสร้างโดยผู้ที่รู้กุญแจ | สร้างรหัสผ่าน MQTT รายบอร์ด (`deriveDevicePassword`) และ hash ของ OTP/reset token |
| HSTS | header ที่สั่งเบราว์เซอร์ให้ใช้ HTTPS เสมอสำหรับโดเมนนี้ | ตั้งใน `deploy/Caddyfile` |
| JWT (JSON Web Token) | token ที่เซิร์ฟเวอร์เซ็นไว้ มีข้อมูลผู้ใช้ ตรวจได้โดยไม่ต้องถามฐานข้อมูลทุกครั้ง | `jsonwebtoken` ใน `routes/auth.js` และ `middleware/authenticate.js`; อายุเริ่มต้น `8h` |
| OTP (One-Time Password) | รหัส 6 หลักใช้ครั้งเดียว ส่งทางอีเมลเพื่อยืนยันตอนลืมรหัสผ่าน | ตาราง `password_reset_otps`; `routes/auth.js` |
| Parameter binding | ส่งค่าแยกจากคำสั่ง SQL ด้วย `?` เพื่อกัน SQL injection | ทุก query ใน `backend/src/routes/*.js` และ `services/*.js` |
| Rate limiting | จำกัดจำนวนคำขอต่อช่วงเวลา กันเดารหัสและกันถล่ม | `express-rate-limit` ใน `routes/auth.js` (`loginLimiter` 10 ครั้ง/15 นาที ฯลฯ) |
| SQL injection | การแทรกคำสั่ง SQL ผ่านช่องกรอกข้อมูล เพื่อให้ฐานข้อมูลทำสิ่งที่ไม่ตั้งใจ | กันด้วย parameter binding |
| XSS (Cross-Site Scripting) | การแทรกโค้ด JavaScript ผ่านข้อความที่ผู้ใช้กรอก แล้วไปรันในเบราว์เซอร์คนอื่น | เว็บแอปใช้ `el()` ใน `webapp/assets/js/dom.js` ที่ตั้งข้อความด้วย `textContent` |

## ฐานข้อมูล

| คำศัพท์ | ความหมาย (ภาษาง่าย) | ใช้ตรงไหนในโปรเจค |
|---|---|---|
| air_conditioners | ตารางเก็บแอร์แต่ละเครื่อง ทั้งสถานะ ค่าไฟล่าสุด Device ID และสถานะ auto-off | `backend/database/schema.sql`; เขียนโดย `services/mqtt.js` |
| Backup (สำรองข้อมูล) | คัดลอกข้อมูลไว้เผื่อเสียหาย | `deploy/backup-db.sh` รันตาม cron |
| Composite key | คีย์หลักที่ประกอบจากหลายคอลัมน์ | `energy_hourly` ใช้ `PRIMARY KEY (device_id, bucket_start)` |
| Connection pool | กลุ่มการเชื่อมต่อฐานข้อมูลที่เปิดค้างไว้ใช้ซ้ำ ไม่ต้องต่อใหม่ทุกคำขอ | `backend/src/db.js` ผ่านไดรเวอร์ `mariadb` |
| CREATE TABLE IF NOT EXISTS | คำสั่งสร้างตารางถ้ายังไม่มี ถ้ามีแล้วข้าม ทำให้รันไฟล์ซ้ำได้ | `schema.sql` — แต่เติมคอลัมน์ให้ตารางเก่าไม่ได้ จึงต้องมี migration |
| Foreign key | คอลัมน์ที่อ้างถึงแถวของอีกตาราง ช่วยรักษาความสัมพันธ์ของข้อมูล | เช่น `room_number` ของแอร์ต้องอ้างถึงห้องที่มีอยู่ใน `schema.sql` |
| Index | โครงสร้างช่วยให้ค้นหาเร็วขึ้น แลกกับเขียนช้าลงเล็กน้อย | กำหนดใน `schema.sql` ต่อคอลัมน์ที่ค้นบ่อย เช่น เวลา, ห้อง |
| LEFT JOIN | เชื่อมสองตารางโดยเก็บแถวฝั่งซ้ายไว้แม้ไม่มีคู่ | `services/auto-off.js` ดึงแอร์พร้อมสถานะเซ็นเซอร์ (`occupancy_sensors`) |
| MariaDB | ระบบฐานข้อมูลเชิงสัมพันธ์ (fork ของ MySQL) | service `db` (`mariadb:11`) ใน compose |
| Migration | สคริปต์ `ALTER TABLE` ทีละรุ่นที่อัปเกรดฐานข้อมูลเก่าให้ตรงกับ schema ใหม่ เขียนให้รันซ้ำได้ | `backend/scripts/migrate-*.js` (`npm run db:migrate:*`) |
| ON DUPLICATE KEY UPDATE | ถ้าแทรกแล้วคีย์ซ้ำ ให้อัปเดตแถวเดิมแทน (UPSERT ของ MariaDB) | `services/energy-recorder.js` (`upsertBucket`) |
| Primary key | คอลัมน์ที่ระบุแต่ละแถวไม่ซ้ำกัน | ทุกตารางใน `schema.sql` |
| Schema | โครงสร้างของฐานข้อมูล: ตาราง คอลัมน์ ชนิด คีย์ และ index | `backend/database/schema.sql` |
| Schema doctor | เครื่องมือเทียบฐานข้อมูลจริงกับ `schema.sql` แล้วรายงานสิ่งที่ขาด | `utils/schema-doctor.js` และ `scripts/doctor.js` (`npm run db:doctor`) |
| SQL | ภาษาสำหรับถามและจัดการข้อมูลในฐานข้อมูลเชิงสัมพันธ์ | `schema.sql` และ query ทั่ว Backend |
| UPSERT | Update + Insert: ถ้ามีแถวอยู่แล้วให้อัปเดต ถ้าไม่มีให้แทรก | เขียนข้อมูลลงถังรายชั่วโมงใน `energy_hourly` |

## Backend และเว็บ

| คำศัพท์ | ความหมาย (ภาษาง่าย) | ใช้ตรงไหนในโปรเจค |
|---|---|---|
| API | ช่องทางที่โปรแกรมหนึ่งเรียกใช้ฟังก์ชันของอีกโปรแกรม ในที่นี้คือ URL ที่ Backend เปิดให้ | `/api/...` ทั้งหมด (ตารางอ้างอิงในบท 06) |
| async / await | ไวยากรณ์เขียนงานที่ต้องรอ (เน็ต ฐานข้อมูล) ให้อ่านเหมือนโค้ดปกติ โดยไม่ค้างโปรแกรม | ใช้ทั้ง Backend (JS), เว็บ และแอป Dart |
| Bounded retries | ลองซ้ำแบบมีเพดาน ไม่ลองไม่สิ้นสุด | auto-off ยิงคำสั่งปิดได้สูงสุด 5 ครั้ง ห่างกันอย่างน้อย 20 วินาที (`utils/auto-off.js`) |
| Design tokens | ตัวแปรสี/ระยะที่ตั้งชื่อตามความหมาย (`--panel`, `--danger`) แล้วเรียกใช้ทั่วทั้งเว็บ | `webapp/assets/css/tokens.css` |
| DOM | โครงสร้างต้นไม้ของหน้าเว็บที่ JavaScript แก้ได้ | `webapp/assets/js/dom.js` |
| Express | เฟรมเวิร์กเว็บของ Node.js (โปรเจคใช้รุ่น 5) | `backend/src/app.js` และ `routes/*.js` |
| Fail-fast | ถ้าค่าตั้งผิดหรือขาด ให้โปรแกรมหยุดทันทีตอนเริ่ม ดีกว่าพังกลางทาง | `backend/src/config.js` |
| fflate / fast-xml-parser | แพ็กเกจแตก/บีบ zip และอ่าน XML เพราะ `.xlsx` คือ zip ของไฟล์ XML | `utils/xlsx-reader.js` และ `utils/xlsx-writer.js` |
| HTTP method / status code | method คือชนิดการกระทำ (GET, POST, PATCH, DELETE) status code คือผลลัพธ์ (200, 401, 404 ...) | ทุก route ใน `routes/*.js` |
| Idempotency | ทำซ้ำกี่ครั้งผลก็เท่ากับทำครั้งเดียว ทำให้ส่งซ้ำได้อย่างปลอดภัย | history ส่งซ้ำได้โดยไม่ซ้ำข้อมูล; migration รันซ้ำได้ |
| JSON | รูปแบบข้อความเก็บข้อมูลเป็นคู่ key/value ที่ทุกภาษาอ่านได้ | ใช้ในทุกคำขอ API, ข้อความ MQTT และ BLE |
| localStorage | ที่เก็บ key/value ถาวรในเบราว์เซอร์ ไม่ส่งไปเซิร์ฟเวอร์ | `theme.js` และ `prefs.js` จำธีมและค่ากำหนดของผู้ใช้ |
| Middleware | ฟังก์ชันที่คั่นกลางระหว่างคำขอกับ handler เช่น ตรวจ token | `middleware/authenticate.js`, `middleware/require-admin.js` |
| Node.js | ตัวรัน JavaScript นอกเบราว์เซอร์ (ต้องรุ่น 20+) | Backend ทั้งหมด |
| nodemailer | แพ็กเกจส่งอีเมลผ่าน SMTP | `backend/src/services/mailer.js` ส่ง OTP |
| npm / package.json | ตัวจัดการแพ็กเกจของ Node กับไฟล์ที่ระบุแพ็กเกจและสคริปต์ | `backend/package.json` |
| Polling | ถามเซิร์ฟเวอร์ซ้ำเป็นช่วง ๆ แทนที่จะรอเซิร์ฟเวอร์ส่งมาเอง | `webapp/assets/js/store.js` ดึงข้อมูลสดทุก 10 วินาที |
| Pure function | ฟังก์ชันที่ผลลัพธ์ขึ้นกับอินพุตเท่านั้น ไม่แตะฐานข้อมูล/เวลา/เครือข่าย ทดสอบง่าย | `decideAutoOff` ใน `utils/auto-off.js`; ไฟล์ `utils/*.js` |
| PWA manifest | ไฟล์ JSON บอกชื่อ ไอคอน และสีของเว็บ เพื่อให้ติดตั้งเป็นแอปบนหน้าจอได้ | `webapp/site.webmanifest` |
| Route | การจับคู่ URL + method กับ handler | `backend/src/routes/*.js` |
| Same-origin | เว็บกับ API อยู่ origin เดียวกัน (โปรโตคอล+โดเมน+พอร์ตเหมือนกัน) จึงไม่ต้องใช้ CORS | เว็บแอปเรียก `/api` ผ่าน Caddy โดเมนเดียวกัน |
| Side effect | การกระทำที่เปลี่ยนสิ่งนอกฟังก์ชัน เช่น เขียนฐานข้อมูล ส่ง MQTT | แยกไว้ใน `services/*.js` จากตรรกะใน `utils/*.js` |
| SPA (Single Page Application) | เว็บที่โหลดหน้าเดียวแล้วใช้ JavaScript สลับเนื้อหาโดยไม่โหลดหน้าใหม่ | `webapp/index.html` + `assets/js/app.js` |
| State machine | โมเดลที่ระบบอยู่ในสถานะใดสถานะหนึ่ง และเปลี่ยนสถานะตามเหตุการณ์ | นาฬิกา auto-off: idle → นับถอยหลัง → ยิงคำสั่ง → สำเร็จ/ยอมแพ้ |
| SVG chart | กราฟที่วาดด้วย SVG เขียนเองด้วย JavaScript ไม่พึ่งไลบรารี | `webapp/assets/js/charts.js` |

## แอปมือถือ Flutter/Dart

| คำศัพท์ | ความหมาย (ภาษาง่าย) | ใช้ตรงไหนในโปรเจค |
|---|---|---|
| abstract interface class | คลาสที่เป็น "สัญญา" มีแต่หัวฟังก์ชัน คลาสอื่นต้อง implements แล้วเขียนเอง | ชั้น Repository ในแอป (เช่น `AuthRepository`) |
| AnimatedBuilder | widget ที่วาดส่วนของหน้าใหม่เมื่อ Listenable (เช่น Controller) แจ้งว่ามีการเปลี่ยน | ใช้ฟัง Controller ในแอป (ไม่มีแพ็กเกจ state เพิ่ม) |
| ApiConfig | คลาสที่เก็บ URL ของ Backend ที่แอปเรียก | `lib/config/api_config.dart` |
| AppShell | widget โครงหลักหลังล็อกอิน มีเมนูนำทางและรวม Controller ทั้งหมด | `app_shell.dart` (main.dart สลับ loading → login → AppShell) |
| async / await / Future | `Future` คือค่าที่จะมาทีหลัง `await` รอผลโดยไม่ค้างหน้าจอ | ทุก `*_service.dart` ที่ยิง HTTP |
| BuildContext | ตัวบอกตำแหน่งของ widget ในต้นไม้ ใช้เข้าถึงธีม ภาษา การนำทาง | `context.tr('...')` เป็น extension บน BuildContext |
| ChangeNotifier | คลาสของ Flutter ที่มีเมธอด `notifyListeners()` บอกให้หน้าจอวาดใหม่เมื่อข้อมูลเปลี่ยน | Controller ทุกตัว เช่น `AuthController`, `RoomController` |
| Controller | ชั้นที่เก็บ state ของหน้า แล้วแจ้งหน้าจอให้วาดใหม่ (ไม่ใช่ controller แบบ MVC ทั่วไป) | `lib/controllers/` เช่น `AirConditionerController`, `ScheduleController` |
| Dart | ภาษาโปรแกรมที่ใช้เขียน Flutter (โปรเจคใช้ Dart 3.8+) | โค้ดทั้งหมดใน `lib/` |
| Dependency injection | ส่งสิ่งที่คลาสต้องใช้เข้าทาง constructor แทนที่จะสร้างเอง ทำให้สลับตัวจริง/ตัวปลอมได้ | ส่ง Repository เข้า Controller ใน `main.dart` |
| factory / fromJson / toJson | `factory` constructor สร้าง object จากข้อมูลอื่น ใช้แปลง JSON เป็น model และกลับ | ทุกไฟล์ใน `lib/models/` |
| file_selector / path_provider / share_plus | แพ็กเกจเลือกไฟล์ หาโฟลเดอร์ชั่วคราว และเปิดเมนูแชร์ ใช้ตอนบันทึกไฟล์ส่งออก | `lib/utils/file_saver.dart` |
| Flutter | เฟรมเวิร์กสร้างแอปจากโค้ดชุดเดียวให้รันได้ทั้ง Android และ Windows | แอป `cpe_air_remote` (ชื่อที่ผู้ใช้เห็น RMUTT Save Energy) |
| flutter_localizations | ชุดคำแปลและปฏิทินมาตรฐานของ Flutter | `localizationsDelegates` ใน `main.dart` |
| flutter_secure_storage | เก็บ key/value แบบเข้ารหัสในเครื่อง (Android ใช้ Keystore ของระบบ) | เก็บ JWT และการตั้งค่า (`auth_service.dart`, `app_settings_controller.dart`) |
| kDisplayFont (ChakraPetch) | ค่าคงที่ชื่อฟอนต์หัวข้อ/ตัวเลขใหญ่ ฟอนต์เดียวกับโลโก้ รองรับภาษาไทย | `pubspec.yaml` และไฟล์ธีม |
| NoopAlertNotifier | ตัวแจ้งเตือนที่ "ไม่ทำอะไร" ใช้แทนการแจ้งเตือนบนเครื่อง ซึ่งยังไม่มีตัวจริงในแอป | `alert_notifier.dart` (บท 10) |
| Null safety | ตัวแปรปกติห้ามเป็น null ถ้าจะให้เป็นได้ต้องเติม `?` พร้อมตัวช่วย `??`, `?.`, `!` | ทุกไฟล์ Dart |
| pubspec.yaml | ไฟล์ประกาศชื่อแอป เวอร์ชัน แพ็กเกจ ฟอนต์ และ assets | `pubspec.yaml` ที่รากโปรเจค Flutter |
| Repository | ชั้นกลางที่ซ่อนว่าข้อมูลมาจากไหน Controller ถาม Repository ไม่ต้องรู้เรื่อง HTTP | `lib/services/*_repository.dart` เช่น `RoomRepository` |
| Service (ในแอป) | ชั้นที่ยิง HTTP/BLE จริง | `*_service.dart` เช่น `RoomService`, `BleProvisioningService` |
| Stream | เหมือน Future แต่ส่งค่ามาได้หลายครั้ง | ผลสแกน BLE: `FlutterBluePlus.onScanResults` |
| Widget | หน่วยย่อยของหน้าจอ Flutter ทุกอย่างบนจอเป็น widget | ไฟล์ใน `lib/screens/` และ `lib/widgets/` |
| Record (Dart 3) | ชนิดข้อมูลรวมหลายค่าแบบไม่ต้องสร้างคลาส เช่น `({String start, Widget child})` หรือ `(String, Color)` | เรียงคาบเรียนกับการใช้ห้องรวมกันใน `_ScheduleCard`, `termStatusLabel` คืน (ข้อความ, สี) (บท 11) |
| `context.mounted` | เช็กว่า `BuildContext` ยังใช้ได้หลัง `await` ใน StatelessWidget (คู่กับ `mounted` ของ State) | ลบภาคเรียนใน `term_calendar_screen.dart` (บท 11) |
| BOM (Byte Order Mark) | อักขระมองไม่เห็น `U+FEFF` หน้าไฟล์ บอกโปรแกรมว่าเป็น UTF-8 | `schedulesToCsv` ใส่ไว้ให้ Excel อ่านภาษาไทยถูก (บท 10) |
| `niceScaleMax` | ฟังก์ชันปัดค่าสูงสุดของกราฟขึ้นเป็นตัวเลขกลม (1, 2, 2.5, 4, 5, 10 × 10ⁿ) | แกนตั้งของกราฟแท่งพลังงาน 3.56 → 4 (บท 11) |

## IoT ฮาร์ดแวร์และเฟิร์มแวร์

| คำศัพท์ | ความหมาย (ภาษาง่าย) | ใช้ตรงไหนในโปรเจค |
|---|---|---|
| app0 / app1 (OTA slot) | สองช่องเก็บโปรแกรมเฟิร์มแวร์ OTA เขียนลงช่องที่ไม่ได้ใช้ แล้วค่อยสลับบูต | `firmware/*/partitions.csv` |
| Arduino-ESP32 | ชุด board package ที่ทำให้เขียน ESP32 ด้วยสไตล์ Arduino ได้ (Core 3.x) | สเก็ตช์ `.ino` ทั้งสองบอร์ด |
| ArduinoJson | ไลบรารีอ่าน/สร้าง JSON บนไมโครคอนโทรลเลอร์ (ตรึงรุ่น 6.x) | ทั้งสองสเก็ตช์ ใช้ `DynamicJsonDocument` |
| ESP32 | ไมโครคอนโทรลเลอร์มี Wi-Fi และ Bluetooth ในตัว | บอร์ดแอร์และบอร์ดตรวจคน |
| Firmware (เฟิร์มแวร์) | โปรแกรมที่ฝังอยู่ในไมโครคอนโทรลเลอร์ | `firmware/rmutt_esp32_air/`, `firmware/rmutt_esp32_occupancy/` (รุ่นแอร์ 2.4.x) |
| GPIO | ขาของชิปที่ตั้งเป็นรับ/ส่งสัญญาณไฟฟ้าได้ | ตารางขาในบท 09 (IR, PZEM, LD2410, LED, ปุ่ม) |
| HistoryRecord | โครงสร้างข้อมูลย้อนหลัง 32 ไบต์ต่อช่วง 5 นาที | `firmware/rmutt_esp32_air/history_log.h` |
| HLK-LD2410 | โมดูลเรดาร์ตรวจจับคนทั้งขณะเคลื่อนไหวและนิ่ง | บอร์ดตรวจคน (`rmutt_esp32_occupancy.ino`) |
| Hysteresis | ช่วงกันสั่น: ใช้เกณฑ์เปิดกับปิดคนละค่า เพื่อไม่ให้สถานะกระพริบ | แอร์ "ทำงาน" เมื่อ ≥ 30 W และ "หยุด" เมื่อ ≤ 10 W (`AC_RUNNING_ON_WATTS/OFF_WATTS`) |
| IR (อินฟราเรด) | แสงที่ตามองไม่เห็น ใช้ส่งคำสั่งรีโมต | LED IR ของบอร์ดแอร์ส่งคำสั่งเปิด/ปิด/ปรับอุณหภูมิ |
| IRremoteESP8266 | ไลบรารีส่ง IR ของ ESP (รุ่น 2.9.0) มี `IRac` สำหรับแอร์หลายยี่ห้อ | บอร์ดแอร์เท่านั้น |
| kWh | หน่วยพลังงานไฟฟ้า (กิโลวัตต์-ชั่วโมง) เท่ากับ 1 "หน่วย" ที่ใช้คิดค่าไฟ | `consumption_kwh` ใน `energy_hourly` |
| millis() | ฟังก์ชันคืนเวลา (ms) นับตั้งแต่เปิดเครื่อง ใช้จับเวลาโดยไม่หยุดโปรแกรม | แทน `delay()` ใน `loop()` ของบอร์ด |
| NTP | โปรโตคอลซิงก์เวลาผ่านอินเทอร์เน็ต | บอร์ดตั้งนาฬิกาเพื่อใส่เวลา (`ts`) ในข้อมูลย้อนหลัง |
| NVS / Preferences | พื้นที่ key/value ใน flash เก็บค่าตั้งที่ต้องรอดหลังรีบูต เช่น Wi-Fi และ token | พาร์ติชัน `nvs`; คลาส `Preferences` ในสเก็ตช์ |
| OTA (Over-The-Air) | อัปเดตเฟิร์มแวร์ผ่าน Wi-Fi ไม่ต้องเสียบสาย | `firmware/*/ota_update.h` (`performOtaUpdate()`) |
| otadata | พาร์ติชันที่จดว่าบูตจาก app0 หรือ app1 | `partitions.csv` |
| Partition table | ตารางแบ่งหน่วยความจำ flash เป็นส่วน ๆ | `firmware/*/partitions.csv` |
| PubSubClient | ไลบรารี MQTT client สำหรับ Arduino | ทั้งสองสเก็ตช์ |
| PZEM-004T | โมดูลวัดไฟ AC: แรงดัน กระแส กำลัง พลังงานสะสม ตัวประกอบกำลัง ความถี่ (คุยผ่าน UART) | บอร์ดแอร์ ผ่านไลบรารี PZEM004Tv30 |
| Ring buffer | ที่เก็บแบบวนที่เขียนทับข้อมูลเก่าสุดเมื่อเต็ม | พาร์ติชัน `rmuttlog` 64 KB เก็บข้อมูลย้อนหลังราว 7 วัน |
| rmuttlog | พาร์ติชัน flash ขนาด 64 KB (subtype `0x40`) ที่โปรเจคกำหนดเอง เก็บข้อมูลตอนเน็ตหลุด | `partitions.csv`; `history_log.h` |
| Root CA (ใบรับรองราก) | ใบรับรองต้นทางที่ใช้ตรวจว่าใบของเซิร์ฟเวอร์ไว้ใจได้ บอร์ดไม่มีรายชื่อ CA ในตัว ต้องฝังเอง | `letsencrypt_ca.h`; อัปเดตด้วย `firmware/update-root-ca.ps1` |
| SaijoDenkiAC | ไดรเวอร์ IR ที่เขียนเองสำหรับแอร์ยี่ห้อ Saijo Denki | `SaijoDenkiAC.h/.cpp`; ชื่อโปรโตคอล `SAIJO_DENKI` |
| setup() / loop() | `setup()` รันครั้งเดียวตอนเปิดเครื่อง `loop()` วนซ้ำตลอด | `.ino` ทั้งสองบอร์ด |
| UART | การสื่อสารอนุกรมสองสาย (TX/RX) ที่ใช้คุยกับ PZEM และ LD2410 | ขา UART ในตารางขาของบท 09 |
| FreeRTOS task | งานที่ระบบปฏิบัติการใน ESP32 สลับให้รันแยกจาก `loop()` กำหนด priority และ core ได้ | `wired_bus.h` ส่งเฟรม SLM8 ทุก 1 วินาที (บท 19) |
| Mutex | กุญแจที่ถือได้ทีละงาน กันสองงานแก้ข้อมูลเดียวกันพร้อมกัน | `WiredBus::lock()` (บท 19) |
| Ring buffer | คิวแบบวงกลม ผู้เขียนเลื่อนหัว ผู้อ่านเลื่อนท้าย ส่งข้อมูลออกจาก interrupt โดยไม่ต้องล็อก | ตัวรับ `Rx` ใน `DaikinSLM8.h` (บท 19) |
| SH1106 / U8g2 | ชิปควบคุมจอ OLED 1.3" 128×64 / ไลบรารีวาดจอขาวดำที่มีฟอนต์ในตัว | `oled_display.h`, `oled_ui.h` (บท 9) |
| Software I2C (bit-bang) | I2C ที่ CPU ขยับขาเองแทนวงจรฮาร์ดแวร์ | จอ OLED GPIO21/22 และ `build_opt.h` (บท 9) |
| Burn-in | พิกเซล OLED เสื่อมไม่เท่ากันจนเห็นเงาค้างเมื่อแสดงภาพเดิมนาน | `saver()` พักจอเมื่อแอร์ปิดเกิน 10 นาที (บท 9) |
| `build_opt.h` | ไฟล์แฟล็กคอมไพเลอร์ที่ Arduino IDE อ่านอัตโนมัติ ใช้ปิดส่วนของไลบรารีที่ไม่ใช้ | ปิดโปรโตคอล IR 28 ยี่ห้อให้แฟลชพอ (บท 9) |

## MQTT และ BLE

| คำศัพท์ | ความหมาย (ภาษาง่าย) | ใช้ตรงไหนในโปรเจค |
|---|---|---|
| BLE (Bluetooth Low Energy) | บลูทูธประหยัดพลังงาน ระยะใกล้ ใช้ตั้งค่าบอร์ดครั้งแรกโดยไม่ต้องมี Wi-Fi | แอปคุยกับบอร์ดตอน provisioning |
| Broker | เซิร์ฟเวอร์กลางของ MQTT ที่รับและส่งต่อข้อความ | Mosquitto (`rmutt-mqtt`) |
| Characteristic (BLE) | ช่องข้อมูลหนึ่งช่องภายใน GATT service ที่อ่าน เขียน หรือแจ้งเตือนได้ | Config (Write), Status/ACK (Read+Notify), Identity, Nearby Wi-Fi, Saved settings |
| Client ID | ชื่อเฉพาะของ client บน Broker ถ้าซ้ำ Broker จะเตะตัวเก่าออก | `rmutt-ESP32-<MAC>`, `rmutt-occ-OCC32-<MAC>`, `rmutt-api-<pid>` |
| $CONTROL/dynamic-security/v1 | topic พิเศษสำหรับสั่ง Dynamic Security (คำตอบกลับที่ `/response`) | `services/mqtt-accounts.js` |
| flutter_blue_plus | แพ็กเกจ BLE ของ Flutter (ตรึงรุ่น 2.3.11) | `ble_provisioning_service.dart`, `models/provisioning.dart` |
| flutter_blue_plus_winrt | ตัวเชื่อม BLE บน Windows ผ่าน WinRT (ตรึง 0.0.20) | `pubspec.yaml`; ที่มาของข้อจำกัดเฉพาะ Windows (บท 08) |
| GATT | โครงสร้างข้อมูลของ BLE: service ที่มีหลาย characteristic | ประกาศใน `.ino` และ `ble_provisioning_service.dart` |
| LWT (Last Will and Testament) | ข้อความที่ Broker ส่งแทนอุปกรณ์เมื่ออุปกรณ์หลุดโดยไม่ได้บอกลา | บอร์ดตั้ง LWT ที่ topic `status` เป็น offline (`connectMqtt()`) |
| MQTT | โปรโตคอลส่งข้อความแบบ publish/subscribe เบา เหมาะกับ IoT | ช่องทางระหว่าง ESP32 ↔ Mosquitto ↔ Backend |
| Nearby Wi-Fi characteristic | characteristic ที่ "อ่านแล้วบอร์ดสแกน Wi-Fi รอบตัวเอง" (สูงสุด 8 SSID) | UUID `7b570005-…`; หน้าเลือก Wi-Fi ในแอป |
| Notify (BLE) | บอร์ดผลักค่าใหม่ให้ client ที่สมัครรับไว้ โดยไม่ต้องถามซ้ำ | Status/ACK characteristic (ต้องมี descriptor BLE2902 / CCCD) |
| persistence (Mosquitto) | เก็บ retained message และสถานะลงดิสก์ รีสตาร์ทแล้วไม่หาย | `persistence true` ใน `mosquitto.conf` (โฟลเดอร์ `/mosquitto/data`) |
| Publish / Subscribe | ฝั่งส่งข้อความเข้า topic กับฝั่งสมัครรับข้อความจาก topic ผู้ส่งไม่ต้องรู้จักผู้รับ | Backend subscribe `rmutt/ac/#`; บอร์ด publish `state`/`status` |
| QoS (Quality of Service) | ระดับการรับประกันส่งข้อความ: 0 อย่างมากครั้งเดียว, 1 อย่างน้อยครั้งเดียว, 2 ครั้งเดียวพอดี | ข้อความสำคัญใช้ QoS 1 (เช่น `provision-ack`, `history-ack`) |
| Retained message | ข้อความที่ Broker จำค่าล่าสุดไว้ ส่งให้ทันทีเมื่อมีคนสมัครรับใหม่ | `state`, `status`, `provision-ack`, `schedule-status` เป็น retained |
| Topic | ชื่อช่องข้อความของ MQTT เป็นลำดับชั้นคั่นด้วย `/` | `rmutt/ac/<DEVICE_ID>/command` ฯลฯ ดู `utils/mqtt-topics.js` |
| unprovision | คำสั่งให้บอร์ดล้างการตั้งค่าใน NVS แล้วกลับเป็นบอร์ดใหม่ (โหมดตั้งค่าบลูทูธ) | ลบอุปกรณ์ในแอป/เว็บ (บท 8, 9, 15) |
| `boardCleared` | ฟิลด์ที่ API ตอบตอนลบอุปกรณ์ บอกว่าบอร์ดยืนยันว่าล้างค่าแล้วหรือไม่ | `DELETE /air-conditioners/:id` (บท 6, 8) |
| `controlType` / `controlMode` | วิธีที่บอร์ดสั่งแอร์ `ir` หรือ `wired` (ใน BLE identity และ REST) / ค่าที่บอร์ดสายแอร์รายงานใน status | Backend ตั้งโปรโตคอล `DAIKIN_WIRED` ให้เอง (บท 7, 8) |

## คำเฉพาะของโปรเจคนี้

| คำศัพท์ | ความหมาย (ภาษาง่าย) | ใช้ตรงไหนในโปรเจค |
|---|---|---|
| academic_terms | ตารางปฏิทินภาคเรียน ใช้ตัดสินว่าวันนี้อยู่ในเทอมหรือไม่ | `schema.sql`; `services/academic-terms.js` |
| auto-off | ระบบปิดแอร์อัตโนมัติ: ถ้าแอร์ทำงานแต่ห้องว่าง ให้นับถอยหลัง 5 นาที (นอกคาบ) หรือ 15 นาที (ในคาบ) แล้วสั่งปิด ลองซ้ำได้ถึง 5 ครั้ง | ตัดสินใน `utils/auto-off.js`, คุมจังหวะใน `services/auto-off.js` (ที่ Backend ไม่ใช่ที่บอร์ด) |
| AUTO_OFF_FAILED / AUTO_OFF_SUCCEEDED | ประเภทใบแจ้งเตือนเมื่อสั่งปิดครบ 5 ครั้งแล้วแอร์ยังทำงาน / เมื่อปิดสำเร็จ | `services/alerts.js` (ตาราง `system_alerts`) |
| BLE Recovery (กู้ Wi-Fi) | การใช้ BLE ตั้งค่า Wi-Fi ใหม่ให้บอร์ดที่ตั้งค่าแล้วแต่ Wi-Fi หลุด | บท 08; ฝั่งบอร์ดและ `BleProvisioningService` |
| bucket_start | เวลาเริ่มต้นของชั่วโมง (เวลาไทย) ที่ใช้เป็นคีย์ของถัง `energy_hourly` | `bangkokHourStart(now)` ใน `utils/energy-history.js`/`energy-recorder.js` |
| Building Pulse | ช่องห้องแบบ heatmap ในหน้าภาพรวมของเว็บ จัดตามชั้น สีตามค่าไฟ จุดกะพริบ = แอร์กำลังทำงาน | `renderPulse` ใน `webapp/assets/js/views/overview.js` |
| class_schedules | ตารางเรียนของแต่ละห้อง | `schema.sql`; `utils/class-schedule.js`, `utils/schedule-import.js` |
| decideAutoOff | ฟังก์ชัน pure ที่รับสถานะแอร์ เซ็นเซอร์ คาบเรียน เวลา แล้วคืนการตัดสินใจ 7 แบบ (idle, start, wait, fire, succeeded, giveUp, cancel) | `backend/src/utils/auto-off.js` |
| deriveDevicePassword | ฟังก์ชันคำนวณรหัสผ่าน MQTT ของบอร์ดจาก HMAC ของ Device ID จึงคำนวณซ้ำได้ ไม่ต้องเก็บในฐานข้อมูล | `backend/src/utils/mqtt-accounts.js` |
| Device ID | ตัวระบุบอร์ดที่ได้จาก MAC: `ESP32-<12 hex>` (แอร์) หรือ `OCC32-<12 hex>` (ตรวจคน) | ใช้เป็น username MQTT, ใน topic และเป็นคีย์ในตาราง; ตรวจด้วย regex ใน `services/mqtt.js` |
| Dynamic Security | ปลั๊กอินของ Mosquitto ที่สร้าง/ลบบัญชีและสิทธิ์ขณะรัน โปรเจคใช้ให้บอร์ดแต่ละตัวมีบัญชีและ role ของตัวเอง | `MQTT_DEVICE_AUTH=dynsec`; `services/mqtt-accounts.js`; ไฟล์ `dynamic-security.json` |
| energy_hourly | ตารางค่าไฟรายชั่วโมงต่อเครื่อง (หนึ่งแถว = หนึ่งเครื่อง × หนึ่งชั่วโมง) เก็บผลรวมและตัวนับ | `schema.sql`; เขียนโดย `services/energy-recorder.js`; อ่านโดย `routes/energy.js` |
| ESP32- | คำนำหน้า Device ID ของบอร์ดแอร์ เช่น `ESP32-AABBCCDDEEFF` (ชื่อ BLE `RMUTT-AC-…`) | `rmutt_esp32_air.ino`; topic `rmutt/ac/<ID>/…` |
| Grace period (เวลานับถอยหลัง) | ช่วงเวลารอก่อนปิดแอร์: 300 วินาที นอกคาบ, 900 วินาที ในคาบ | `AUTO_OFF_IDLE_SECONDS`, `AUTO_OFF_IN_CLASS_SECONDS` ใน `utils/auto-off.js` |
| history | topic ที่บอร์ดส่งข้อมูลพลังงานย้อนหลังที่เก็บไว้ตอนเน็ตหลุดเป็นชุด | `services/mqtt.js` (`handleAirHistory`); `history_log.h` |
| history-ack | topic ที่ Backend ตอบรับว่าบันทึกข้อมูลย้อนหลังถึงลำดับไหนแล้ว (`upTo`, `stored`, `skipped`) บอร์ดจึงลบข้อมูลนั้นได้ | `recordHistoryBatch`; `history_log.h` (`acknowledge`) |
| Meter reset (เลขมิเตอร์รีเซ็ต) | เมื่อค่าพลังงานสะสมของ PZEM ลดลง ระบบไม่เดาย้อนหลัง ชั่วโมงนั้นนับ 0 แล้วเริ่มจากเลขใหม่ | `energyDelta` ใน `utils/energy-history.js` |
| MQTT_DEVICE_AUTH | ตัวแปรเลือกโหมดบัญชี MQTT: `dynsec` (รายบอร์ด) หรือ `shared` (ใช้บัญชีเดียว สำหรับพัฒนา) | `backend/src/config.js`; `.env` |
| OCC32- | คำนำหน้า Device ID ของบอร์ดตรวจคน เช่น `OCC32-AABBCCDDEEFF` (ชื่อ BLE `RMUTT-OCC-…`) | `rmutt_esp32_occupancy.ino`; topic `rmutt/occupancy/<ID>/…` |
| occupancy_sensors | ตารางบอร์ดตรวจคน เก็บสถานะออนไลน์ เรดาร์ และมี/ไม่มีคน | `schema.sql`; `routes/occupancy-sensors.js` |
| Offline history | ระบบที่บอร์ดแอร์เก็บค่าไฟทุก 5 นาทีลง flash ตอนเน็ตหลุด (ราว 7 วัน) แล้วส่งย้อนหลังเมื่อกลับมาออนไลน์ | `history_log.h`; topic `history`/`history-ack` |
| prepareDeviceCredentials | ขั้นตอนจองช่องอุปกรณ์และเตรียมบัญชี/รหัสผ่านก่อนส่งให้บอร์ด | `services/mqtt-accounts.js` (ใช้ `repair: true`) |
| provision / provision-ack | topic ที่บอร์ดประกาศตัวพร้อม token (`provision`) และ Backend ตอบยืนยัน (`provision-ack`) เพื่อจบ provisioning | `services/mqtt.js` (`activateProvisioning`); `.ino` |
| Provisioning | ขั้นตอนตั้งค่าบอร์ดใหม่ครั้งแรก: แอปส่ง Wi-Fi, MQTT, ห้อง/แอร์ ผ่าน BLE แล้วบอร์ดต่อ Wi-Fi/MQTT และยืนยันกับ Backend ด้วย token | `ble_provisioning_service.dart`, `models/provisioning.dart`, `services/mqtt.js`, บท 08 |
| provisioning_token_hash | hash ของ token ที่ใช้ยืนยันบอร์ดตอน provisioning ล้างทิ้งเมื่อ activate สำเร็จ | ตาราง `air_conditioners`/`occupancy_sensors` |
| reconcileAccounts | ซิงก์บัญชี MQTT ให้ตรงกับอุปกรณ์ในฐานข้อมูลทุกครั้งที่ Backend ต่อ Broker ได้ | `services/mqtt-accounts.js` |
| rmutt-backend (role) | role ใน Dynamic Security ของ Backend ที่ publish/subscribe ได้ทั้ง `rmutt/ac/#` และ `rmutt/occupancy/#` | `utils/mqtt-accounts.js` (`backendAcls`) |
| room_bookings | ตารางการจองห้อง ถือเป็น "ช่วงใช้ห้อง" ที่ไม่ปิดแอร์ | `services/room-bookings.js`; `utils/room-booking.js` |
| Schedule import | นำเข้าตารางเรียนจากไฟล์ Excel (.xlsx) และสร้างห้องให้อัตโนมัติ | `utils/schedule-import.js`, `utils/xlsx-reader.js`; หน้า `schedule_import_screen` |
| schedule-status | topic (retained) ที่ Backend บอกบอร์ดว่าขณะนี้อยู่ในคาบเรียนหรือไม่ ส่งทุกครั้งที่บอร์ดออนไลน์ | `publishScheduleEvaluation` ใน `services/mqtt.js` |
| system_alerts | ตารางใบแจ้งเตือนของระบบ (เช่น auto-off ล้มเหลว) ที่ผู้ใช้กดรับทราบได้ | `services/alerts.js`; `routes/alerts.js` |
| system_settings | ตารางตั้งค่าระบบ เช่น อัตราค่าไฟ และสวิตช์รวมของ auto-off | `services/system-settings.js` |
| token_version | ตัวนับเวอร์ชันของ JWT ในตาราง `users` เพิ่มเมื่อเปลี่ยนรหัสผ่านหรือสิทธิ์ ทำให้ token เก่าใช้ไม่ได้ทันที | `routes/auth.js` (ออก `ver`), `middleware/authenticate.js` (เทียบ) |
| withinClass | ค่าบอกว่าตอนนี้อยู่ในคาบเรียนหรือมีการจองห้องหรือไม่ มาจากตารางเรียน + ปฏิทินภาคเรียน + การจอง | อินพุตของ `decideAutoOff` |
| อัตราค่าไฟ (electricityRate) | ราคาไฟต่อหน่วย (บาท/kWh) ที่ใช้คำนวณค่าไฟโดยประมาณ = kWh × rate | `system_settings`; หน้า `views/rates.js`; `state.settings.electricityRate` |
| เวลาไทย (Asia/Bangkok) | ระบบทั้งชุดใช้เวลาไทยล้วน (container ตั้ง `TZ=Asia/Bangkok`) ไม่แปลงเขตเวลา | `deploy/docker-compose.yml`, `deploy/backend.Dockerfile` |
| การใช้ห้อง (room booking) | การใช้ห้องนอกตารางเรียนที่มีวันที่กำกับ เช่น ประชุม สอบ กิจกรรม ทำซ้ำได้ วันเดียว/ทุกวัน/ทุกสัปดาห์ | ระหว่างเวลาที่จองระบบปิดแอร์ถือว่าอยู่ในคาบ (รอ 15 นาที) เพิ่มได้ทั้งในเว็บและแอป (บท 11) |
| ปฏิทินภาคเรียน | วันเปิด–ปิดของแต่ละเทอม (`1/2569`) ตารางเรียนมีผลเฉพาะในช่วงนี้ | นอกช่วงทุกห้องถือว่าว่าง รอ 5 นาทีแล้วปิดแอร์ (บท 11) |
| เปลี่ยนภาคเรียน (`replaceAll`) | โหมดนำเข้าตารางที่ล้างตารางเดิมของ **ทุกห้อง** ก่อน ไม่ใช่แค่ห้องในไฟล์ | กันห้องที่ไม่อยู่ในไฟล์เทอมใหม่ค้างตารางเทอมเก่า (บท 12) |
| `DAIKIN_WIRED` / บอร์ดสายแอร์ | โปรโตคอลของบอร์ด ESP32 ที่ต่อสายแทนรีโมตติดผนัง Daikin SLM8 แสดงเป็น "Daikin · สายแอร์" | `rmutt_esp32_air_wired`, Backend, แอป, เว็บ (บท 19) |
| หน้าเฟิร์มแวร์ | เมนูเว็บของแอดมิน อัปโหลดไฟล์ .bin แยกตามชนิดบอร์ด และสั่งอัปเดตหลายบอร์ดพร้อมกัน | `webapp/assets/js/views/firmware.js` (บท 13) |
| capability getter (`supportsXxx`) | getter บอกว่าแอร์เครื่องนี้ทำฟังก์ชันนั้นได้ไหม หน้าจอใช้ซ่อนปุ่ม | `air_conditioner.dart`, `full_remote_sheet.dart` (บท 10, 11) |

