# แผนที่ไฟล์ทั้งโปรเจค

บทนี้รวมคำอธิบายสั้น ๆ ของ **ทุกไฟล์** ในโปรเจค (ยกเว้นไฟล์ที่ระบบสร้างเอง เช่น `build/`, `node_modules/`, `.dart_tool/` และไฟล์ที่เก็บรหัสผ่านจริง) ใช้เป็นดัชนีเวลาอยากรู้ว่าไฟล์หนึ่งทำอะไร แล้วค่อยไปอ่านรายละเอียดในบทที่ระบุ

> [!TIP]
> กด Ctrl+F ในเบราว์เซอร์แล้วพิมพ์ชื่อไฟล์ เพื่อหาไฟล์ที่ต้องการได้เร็วที่สุด

## เครือข่าย เซิร์ฟเวอร์ และ Docker

รายละเอียดอยู่ในบทเครือข่าย เซิร์ฟเวอร์ และ Tailscale (15 รายการ)

| ไฟล์ | หน้าที่ |
|---|---|
| `deploy/docker-compose.yml` | กำหนด 5 service ของเซิร์ฟเวอร์จริง (db, mqtt, backend, caddy, tailscale) พร้อมพอร์ต volume healthcheck และตัวแปรที่ส่งเข้าแต่ละกล่อง (`MQTT_DEVICE_URL` ค่าเริ่มต้นชี้ Funnel `ts.net:8443` ตั้งเป็น `mqtts://<DOMAIN>:8883` ใน `.env` ได้ และ tailscale `depends_on` ทั้ง caddy กับ mqtt) (14 ต.ค.) backend mount `./firmware` แบบเขียนได้ เพื่อรับไฟล์ที่อัปโหลดจากเว็บ |
| `deploy/Caddyfile` | กฎของ reverse proxy: ขอใบรับรอง DuckDNS ด้วย DNS-01, ส่ง /api/* ไป Backend, เสิร์ฟเว็บและไฟล์เฟิร์มแวร์, ใส่หัวความปลอดภัย และรับ Funnel ที่พอร์ต 8080 |
| `deploy/caddy.Dockerfile` | build Caddy แบบ multi-stage ที่มีปลั๊กอิน DuckDNS สำหรับ DNS challenge |
| `deploy/backend.Dockerfile` | สูตร image ของ Backend (node:22-alpine, ติดตั้ง dependency production, ปรับสิทธิ์ซอร์สด้วย `chmod -R a+rX src scripts database` ก่อน `USER node` รันด้วย user node) |
| `deploy/tailscale-serve.json` | กฎของ Tailscale Serve/Funnel: พอร์ต 443 ถอด TLS แล้วส่งต่อ HTTP ไป caddy:8080 (เว็บ/API) และพอร์ต 8443 ถอด TLS (`TerminateTLS`) แล้วส่งต่อ TCP ดิบ (`TCPForward`) ไป mqtt:1883 (MQTT ของ ESP32) พร้อม `AllowFunnel` เปิดทั้งสองพอร์ตให้อินเทอร์เน็ต |
| `deploy/mosquitto/config/mosquitto.conf` | คอนฟิก Mosquitto จริง: Dynamic Security, listener 1883 ภายใน และ 8883 แบบ TLS 1.2 (1883 รับทั้ง Backend และ MQTT ที่กล่อง tailscale ส่งต่อมาจาก Funnel 8443) |
| `deploy/.env.example` | ตัวอย่างตัวแปรความลับและค่าตั้งของเซิร์ฟเวอร์ (init-env.sh สุ่มค่าจริงให้) |
| `deploy/server.config.example.json` | ตัวอย่างไฟล์ที่อยู่เซิร์ฟเวอร์ (host, user, port, domain) ให้สคริปต์ PowerShell บน Windows อ่าน |
| `deploy/SERVER_REQUIREMENTS.md` | สเปกเครื่องและรายการที่ต้องขอฝ่ายไอที (เขียนตามแผนเดิมที่ขอเปิดพอร์ต) |
| `deploy/DEPLOY.md` | คู่มือขั้นตอน deploy ขึ้นเซิร์ฟเวอร์ตั้งแต่ติดตั้งจนสร้างแอดมิน (บางส่วนเขียนตามแผน HTTP-01 เดิม) (14 ต.ค.) ขั้น `git pull` และหมายเหตุ PowerShell กับ cmd |
| `mqtt/docker-compose.yml` | รัน Mosquitto สำหรับพัฒนาบนเครื่องตัวเอง เปิดพอร์ต 1883 พร้อม healthcheck |
| `mqtt/config/mosquitto.conf` | คอนฟิก Broker สำหรับพัฒนา ใช้ password_file กับ acl_file และ listener 1883 ไม่เข้ารหัส |
| `mqtt/config/acl` | สิทธิ์ของผู้ใช้ rmutt_air ให้อ่านเขียน rmutt/ac/# และ rmutt/occupancy/# และอ่าน $SYS/# |
| `mqtt/.env.example` | ตัวอย่างชื่อและรหัสผ่าน MQTT ที่ setup_mqtt.ps1 สร้างให้ |
| `mqtt/README.md` | วิธีติดตั้งและใช้ Broker สำหรับพัฒนาบน Windows (setup, start, test, stop, เปิด firewall) |

## ฐานข้อมูลและสคริปต์ดูแลข้อมูล

รายละเอียดอยู่ในบทฐานข้อมูล MariaDB (25 รายการ)

| ไฟล์ | หน้าที่ |
|---|---|
| `backend/database/schema.sql` | นิยามโครงสร้างทั้ง 11 ตาราง พร้อม index, foreign key และข้อมูลเริ่มต้น (ห้อง ตารางเรียนตัวอย่าง ค่าตั้งระบบ) เป็นแหล่งความจริงของโครงสร้างฐานข้อมูล |
| `backend/src/db.js` | สร้าง Connection Pool ของ MariaDB แบบ lazy (`getPool`, `pool`) และมี `withTransaction` สำหรับ begin/commit/rollback |
| `backend/scripts/init-db.js` | รัน `schema.sql` ทั้งไฟล์ด้วย connection เดี่ยวที่เปิด `multipleStatements` (`npm run db:init`) |
| `backend/scripts/doctor.js` | ตรวจว่าฐานข้อมูลจริงขาดตารางหรือคอลัมน์ใดเมื่อเทียบกับ `schema.sql` และซ่อมด้วย `--fix` (`npm run db:doctor`) |
| `backend/scripts/seed-admin.js` | สร้างหรือรีเซ็ตบัญชีแอดมินด้วยรหัสผ่านแฮช bcrypt แบบ upsert และรับรหัสทาง stdin ได้ (`npm run seed:admin`) |
| `backend/scripts/migrate-user-primary-key.js` | เปลี่ยนคีย์หลักของ `users` จาก `id` เป็น `username`, ปรับ `role` เป็น ENUM และย้าย `password_reset_otps` ไปอ้าง `username` (`npm run db:migrate:username`) |
| `backend/scripts/migrate-class-schedules.js` | สร้างตาราง `class_schedules` และคาบเรียนตัวอย่าง 4 คาบ (`npm run db:migrate:schedules`) |
| `backend/scripts/migrate-air-conditioners.js` | สร้างตาราง `air_conditioners` รุ่นแรกและทำ `protocol` เป็นตัวพิมพ์ใหญ่ (`npm run db:migrate:air`) |
| `backend/scripts/migrate-pzem-v200.js` | เพิ่มคอลัมน์ PZEM 6 ตัว (`energy_kwh`, `frequency_hz`, `power_factor`, `pzem_available`, `ac_running`, `outside_schedule`) ให้ `air_conditioners` (`npm run db:migrate:pzem`) |
| `backend/scripts/migrate-rooms-v180.js` | สร้างตาราง `rooms` พร้อมห้องมาตรฐาน เติมห้องที่ถูกอ้างถึงแต่ยังไม่มี แล้วผูก foreign key จาก `class_schedules` และ `air_conditioners` (`npm run db:migrate:rooms`) |
| `backend/scripts/migrate-occupancy-v210.js` | สร้างตาราง `occupancy_sensors` พร้อม foreign key ไป `rooms` (`npm run db:migrate:occupancy`) |
| `backend/scripts/migrate-energy-history-v370.js` | สร้างตาราง `energy_hourly` เก็บค่าไฟรายชั่วโมง (`npm run db:migrate:energy`) |
| `backend/scripts/migrate-auto-off-v380.js` | เพิ่มคอลัมน์ `auto_off_*` ให้ `air_conditioners` และสร้างตาราง `system_alerts` (`npm run db:migrate:autooff`) |
| `backend/scripts/migrate-system-settings-v3100.js` | สร้างตาราง `system_settings` และค่าเริ่มต้น `auto_off_enabled`, `electricity_rate` ด้วย `INSERT IGNORE` (`npm run db:migrate:settings`) |
| `backend/scripts/migrate-firmware-v3140.js` | เพิ่มคอลัมน์ `firmware_version` และ `ota_error` ให้ทั้งตารางแอร์และตารางเซ็นเซอร์ (`npm run db:migrate:firmware`) |
| `backend/scripts/migrate-offline-history-v3150.js` | เพิ่มคอลัมน์จุดต่อประวัติไฟฟ้า (`energy_chain_*`) และ `history_pending` พร้อมตั้งจุดต่อเริ่มต้น (`npm run db:migrate:history`) |
| `backend/scripts/migrate-legacy-user.js` | ย้ายผู้ใช้จากตารางเก่าเข้า `users` ใน transaction เดียวและแฮชรหัสผ่านที่ยังเป็นข้อความธรรมดา (`npm run migrate:legacy`) |
| `backend/scripts/convert-schedule-file.js` | แปลงไฟล์ตารางเรียน `.xlsx` เป็น CSV ด้วย `parseScheduleFile` โดยไม่แตะฐานข้อมูล (`npm run schedules:convert`) |
| `backend/src/utils/schema-doctor.js` | ฟังก์ชันบริสุทธิ์ (`parseSchemaTables`, `parseColumns`, `isAutoAddableColumn`, `diffTables`, `stripLineComments`) ที่แยก `schema.sql` เป็นตาราง/คอลัมน์และเทียบกับฐานข้อมูลจริง |
| `deploy/backup-db.sh` | สำรองฐานข้อมูลเป็น `.sql.gz` ทุกวัน (cron) ตรวจความสมบูรณ์ ลบไฟล์เก่า และ rsync สำเนาออกนอกเครื่อง |
| `deploy/db-view.sh` | เปิดดูข้อมูลบนเซิร์ฟเวอร์ผ่าน `docker compose exec` แบบสรุปทุกตาราง ดูทีละตาราง หรือรัน SQL เอง |
| `deploy/seed-admin.sh` | สร้างแอดมินแรกบนเซิร์ฟเวอร์โดยส่งรหัสผ่านทาง stdin ให้ `seed-admin.js` แล้วล้างรหัสออกจาก `.env` |
| `db-tunnel.ps1` | เปิด SSH tunnel จากเครื่อง Windows (พอร์ต 3307) ไปยังฐานข้อมูลบนเซิร์ฟเวอร์ และคัดลอกรหัสผ่านใส่คลิปบอร์ดสำหรับ HeidiSQL |
| `examples/rmutt_class_schedules_1-2569.csv` | ไฟล์ตัวอย่างตารางเรียนภาค 1/2569 (คอลัมน์ `semester, room_code, day, start_time, end_time, subject, section, instructor, enabled`) สำหรับนำเข้าที่ `class_schedules` |
| `examples/rmutt_class_schedules_1-2569_with_CL503.csv` | ไฟล์ตัวอย่างชุดเดียวกันที่เพิ่มคาบของห้องพิเศษ CL503 |

## Backend: โครงหลัก ระบบสมาชิก API และเทสต์

รายละเอียดอยู่ในบท Backend ตอนที่ 1 (46 รายการ)

| ไฟล์ | หน้าที่ |
|---|---|
| backend/package.json | ประกาศชื่อโปรเจค ES module, เวอร์ชัน Node ขั้นต่ำ (>=20), สคริปต์ npm (start, dev, test, db:*) และไลบรารีที่ใช้ |
| backend/.env.example | ตัวอย่างไฟล์ตั้งค่า environment variable ทั้งหมดของ Backend (DB, JWT, OTP, SMTP, MQTT) โดยใช้ค่าตัวอย่างแทนความลับจริง |
| backend/.gitignore | ห้าม Git เก็บ node_modules, .env, log และ coverage |
| backend/.dockerignore | กันไฟล์ความลับ (.env), test, log และ node_modules ไม่ให้ถูกคัดลอกเข้า Docker image ของ Backend |
| backend/src/server.js | จุดเริ่มต้นของโปรเซส: ตรวจ config, เริ่มบริการเบื้องหลัง (MQTT, auto-off), เปิดพอร์ต HTTP และปิดระบบอย่างเรียบร้อยเมื่อได้รับ SIGINT/SIGTERM |
| backend/src/app.js | สร้าง Express app: ใส่ helmet, CORS, JSON parser, route /api/health, ผูกทุก router เข้ากับ prefix /api/... และ error handler |
| backend/src/config.js | อ่าน environment variable มารวมเป็นอ็อบเจกต์ config พร้อมค่าเริ่มต้น และ assertServerConfig() ตรวจค่าที่ขาดหรือไม่ปลอดภัยก่อนเริ่มเซิร์ฟเวอร์ |
| backend/src/middleware/authenticate.js | middleware ตรวจ JWT (Bearer) แล้วเทียบกับผู้ใช้และ token_version ในฐานข้อมูล ก่อนใส่ request.authUser |
| backend/src/middleware/require-admin.js | middleware ตรวจว่า request.authUser.role เป็น admin ไม่ใช่จะตอบ 403 |
| backend/src/routes/auth.js | endpoint เข้าสู่ระบบ ดู/แก้โปรไฟล์ตัวเอง เปลี่ยนรหัสผ่าน และลืมรหัสผ่านด้วย OTP พร้อม rate limit |
| backend/src/routes/public.js | endpoint ที่ไม่ต้องล็อกอิน: ข้อมูลติดต่อแอดมิน (GET /api/public/admin-contact) |
| backend/src/routes/users.js | จัดการบัญชีผู้ใช้ (ดู เพิ่ม แก้สิทธิ์/สถานะ ลบ) เฉพาะแอดมิน และกันไม่ให้ระบบไม่เหลือแอดมิน |
| backend/src/routes/rooms.js | CRUD ห้อง: ดูรายการห้องพร้อมสถานะแอร์/เซ็นเซอร์/นับถอยหลัง, เพิ่ม แก้ ลบห้อง |
| backend/src/routes/schedules.js | ตารางเรียน: ดู เพิ่ม แก้ ลบ, นำเข้าจากไฟล์ Excel/CSV (preview + commit) และจัดการปฏิทินภาคเรียน |
| backend/src/routes/bookings.js | การใช้ห้องนอกตารางเรียน (ประชุม สอบ กิจกรรม) ดูได้ทุกคน เพิ่ม/แก้/ลบเฉพาะแอดมิน |
| backend/src/routes/air-conditioners.js | ดูรายการแอร์, จองอุปกรณ์ (reservation) ให้ ESP32, สั่งแอร์ผ่าน MQTT, เข้าโหมด setup, แก้ชื่อ/ปิดอัตโนมัติ, สั่ง OTA และลบ (13 ต.ค.) ลบแอร์แล้วสั่งบอร์ด `unprovision` ก่อนลบบัญชี MQTT ตอบ `boardCleared` |
| backend/src/routes/occupancy-sensors.js | จัดการเซ็นเซอร์ตรวจจับคน (ESP32 + LD2410): ดู จองอุปกรณ์ เข้าโหมด setup สั่ง OTA และลบ (13 ต.ค.) ลบเซ็นเซอร์แล้วสั่งบอร์ด `unprovision` เช่นเดียวกับแอร์ |
| backend/src/routes/energy.js | API ข้อมูลไฟฟ้า: ค่าสด (live), สรุปรายช่วง (summary), ประวัติ (history), ส่งออก Excel (export), รายการค่าที่เลือกได้ (metrics) และแหล่งข้อมูล (sources) |
| backend/src/routes/firmware.js | แสดงรายการไฟล์ .bin สำหรับ OTA ในโฟลเดอร์ firmware (แอดมินเท่านั้น) และฟังก์ชันตรวจว่าไฟล์มีจริง (14 ต.ค.) เพิ่มอัปโหลด `POST /api/firmware` (ไฟล์ดิบ + `X-File-Name`) และลบ `DELETE /api/firmware/:file` เฉพาะแอดมิน |
| backend/src/routes/alerts.js | ดูรายการแจ้งเตือนระบบและกด "รับทราบ" การแจ้งเตือน |
| backend/src/routes/settings.js | อ่านค่าตั้งระบบ (ทุกคนที่ล็อกอิน) และแก้สวิตช์ปิดแอร์อัตโนมัติ/อัตราค่าไฟ (แอดมิน) |
| backend/src/utils/http.js | ApiError, asyncHandler, notFoundHandler และ errorHandler ที่ทุก route ใช้ร่วมกัน |
| backend/src/utils/security.js | ฟังก์ชันความปลอดภัยแบบ pure: สร้าง OTP, reset token, HMAC hash, เทียบ hash แบบ timing-safe, ตรวจความยาวรหัสผ่านใหม่ |
| backend/src/utils/user.js | ตรวจและทำความสะอาดข้อมูลผู้ใช้ (username, role, อีเมล, เบอร์) และแปลงแถวฐานข้อมูลเป็น JSON ที่ปลอดภัยส่งให้แอป |
| backend/src/services/mailer.js | ส่งอีเมล OTP ผ่าน nodemailer (SMTP) หรือพิมพ์ลงคอนโซลเมื่อ MAIL_MODE=console |
| backend/test/air-conditioner.test.js | ทดสอบ validation ของการจองแอร์ ชื่อโปรโตคอล IRac และคำสั่งแอร์ที่ส่งผ่าน MQTT (11 ต.ค.) เพิ่มเคส `DAIKIN_WIRED` (รวม 10 เทสต์) |
| backend/test/auto-off.test.js | ทดสอบตรรกะปิดแอร์อัตโนมัติ (นับถอยหลัง 5/15 นาที ยิงซ้ำ ยอมแพ้ ยกเลิกเมื่อมีคน) |
| backend/test/energy-history.test.js | ทดสอบการตัดถังรายชั่วโมงเวลาไทย การคำนวณผลต่างมิเตอร์ การสร้าง SQL แบบผูกพารามิเตอร์ และช่วงเวลาหน้าสรุป |
| backend/test/firmware.test.js | ทดสอบการตรวจชื่อไฟล์ .bin ที่ปลอดภัย การสร้าง URL ดาวน์โหลด และการเดาชนิดบอร์ดจากชื่อไฟล์ (14 ต.ค.) เพิ่มเคสชนิดไฟล์และเนื้อไฟล์ (รวม 7 เทสต์) |
| backend/test/unprovision.test.js | (ใหม่ 13 ต.ค.) ทดสอบรูปคำสั่ง unprovision และคำตอบที่นับได้/ไม่ได้ (2 เทสต์) |
| backend/test/mqtt-accounts.test.js | ทดสอบรหัสผ่าน MQTT ของบอร์ด, ACL ต่อ topic, คำสั่ง Dynamic Security และการตรวจ SMTP_FROM |
| backend/test/mqtt-provisioning.test.js | ทดสอบการเลือก URL/พอร์ต Broker ที่ส่งให้ ESP32 ตอน provisioning |
| backend/test/mqtt.test.js | ทดสอบว่า health ของ MQTT ไม่เปิดเผยรหัสผ่าน และรายการ retained topic ที่ต้องล้างเมื่อลบอุปกรณ์ |
| backend/test/occupancy-sensor.test.js | ทดสอบ validation ของเซ็นเซอร์ LD2410 และการแปลงข้อมูลเซ็นเซอร์เป็น JSON สาธารณะ |
| backend/test/offline-history.test.js | ทดสอบการแปลงข้อมูลย้อนหลังที่บอร์ดเก็บไว้ตอนออฟไลน์กลับเป็นหน่วยจริงและลงถังชั่วโมง |
| backend/test/profile-email.test.js | ทดสอบ PATCH /api/auth/me แบบ end-to-end ด้วย pool ปลอม: เปลี่ยนอีเมลต้องใส่รหัสผ่านปัจจุบันที่ถูกต้อง |
| backend/test/pzem-status.test.js | ทดสอบการ normalize ค่า PZEM จากข้อความ status ของบอร์ด และการคำนวณคาบเรียนด้วยเวลา Asia/Bangkok |
| backend/test/room-booking.test.js | ทดสอบการนับวันที่เกิดขึ้นของการใช้ห้อง (ครั้งเดียว รายวัน รายสัปดาห์) และการตรวจ input |
| backend/test/room.test.js | ทดสอบ validation รหัสห้อง ค่าเริ่มต้นห้องตอนนำเข้า และการแปลงข้อมูลเซ็นเซอร์ในรายการห้อง |
| backend/test/schedule-import.test.js | ทดสอบการแปลงไฟล์ Excel/CSV ตารางเรียนเป็นรายการ การข้ามห้องที่ไม่มี และการตรวจคาบซ้อนกัน |
| backend/test/schedule.test.js | ทดสอบ validation ตารางเรียน, requireAdmin, การลบทั้งหมด, การสร้างห้องตอนนำเข้า และคำนวณภาคเรียน |
| backend/test/schema-doctor.test.js | ทดสอบตัวอ่าน schema.sql และการเปรียบเทียบตาราง/คอลัมน์ที่ขาดของ db:doctor |
| backend/test/security.test.js | ทดสอบ createOtp (6 หลัก), hashSecret/safeHashEquals และ isValidNewPassword (จำกัด 72 ไบต์) |
| backend/test/user-management.test.js | ทดสอบ managedUser, validateRole, validateUsername, validateNewUserInput และ validateUserUpdate |
| backend/test/user.test.js | ทดสอบ publicUser ไม่เปิดเผย id ภายใน และเบอร์ว่างกลายเป็นข้อความว่าง |
| backend/test/xlsx-writer.test.js | ทดสอบตัวสร้างไฟล์ .xlsx: โครงไฟล์ครบ ชนิดเซลล์ การ escape XML ชื่อแท็บ และชื่อคอลัมน์ AA |

## Backend: services และ utils

รายละเอียดอยู่ในบท Backend ตอนที่ 2 (25 รายการ)

| ไฟล์ | หน้าที่ |
|---|---|
| backend/src/services/mqtt.js | ต่อ Mosquitto, subscribe topic ของบอร์ด, เขียนสถานะลงฐานข้อมูล, ส่งคำสั่ง/ack/schedule-status กลับไปหาบอร์ด และให้ผู้ฟังเหตุการณ์ (listener) กับระบบอื่น (11–13 ต.ค.) แก้โปรโตคอลเป็น `DAIKIN_WIRED` เมื่อบอร์ดรายงาน `controlMode: wired` และส่ง/รอคำตอบ `unprovision` |
| backend/src/services/mqtt-accounts.js | สร้าง ซ่อม และลบบัญชี MQTT รายบอร์ดบน Mosquitto Dynamic Security ทุกครั้งที่ Backend ต่อ Broker ได้ |
| backend/src/services/auto-off.js | ตัวคุมจังหวะปิดแอร์อัตโนมัติ (setInterval 10 วินาที + ผู้ฟัง status) อ่านสถานะ เรียกตัวตัดสินใจ แล้วสั่งปิดผ่าน MQTT และสร้างการแจ้งเตือน |
| backend/src/services/energy-recorder.js | บันทึกค่าไฟสดและข้อมูลย้อนหลังของบอร์ดลงตาราง energy_hourly (UPSERT รายชั่วโมง) โดยใช้ "จุดต่อ" และคิวต่อบอร์ดกันนับซ้ำ |
| backend/src/services/alerts.js | สร้างและปิดใบแจ้งเตือน system_alerts (ไม่สร้างซ้ำ) และแปลงแถวเป็น JSON ให้แอป |
| backend/src/services/system-settings.js | ค่าตั้งระดับอาคารในตาราง system_settings: สวิตช์รวมปิดแอร์อัตโนมัติ อัตราค่าไฟ (เริ่มต้น 4.50) และภาคเรียนของตาราง พร้อม cache 5 วินาที |
| backend/src/services/academic-terms.js | จัดการปฏิทินวันเปิด-ปิดภาคเรียน และให้ readActiveTermGate (cache 15 วินาที) บอกว่าตารางเรียนมีผลช่วงไหน |
| backend/src/services/room-bookings.js | อ่านการจองห้องที่ครอบคลุมวันนี้สำหรับระบบปิดแอร์และ MQTT |
| backend/src/utils/auto-off.js | ฟังก์ชันบริสุทธิ์ decideAutoOff และค่าคงที่ปิดแอร์ (300/900/20 วินาที, 5 ครั้ง) พร้อมตัวคำนวณวินาทีที่เหลือและ phase สำหรับแอป |
| backend/src/utils/mqtt-accounts.js | ฟังก์ชันบริสุทธิ์สร้างรหัสผ่าน HMAC, ACL และชุดคำสั่ง Dynamic Security ของบอร์ดแอร์/เซ็นเซอร์ และ Backend |
| backend/src/utils/mqtt-topics.js | รายชื่อส่วนท้าย topic แบบ retained และฟังก์ชันประกอบ topic เต็มที่ต้องล้างเมื่อถอดอุปกรณ์ |
| backend/src/utils/mqtt-provisioning.js | แยก MQTT_URL เป็น host/port/TLS/username/password ที่ส่งให้บอร์ดตอนติดตั้ง |
| backend/src/utils/energy-history.js | ฟังก์ชันบริสุทธิ์ของระบบค่าไฟ: ผลต่างพลังงาน ถังรายชั่วโมงเวลาไทย ข้อมูลย้อนหลัง แคตตาล็อก 16 เมทริก SQL รายงานสองชั้น และช่วงเวลาสรุป |
| backend/src/utils/xlsx-writer.js | เขียนไฟล์ .xlsx เองด้วย fflate (ZIP + XML ขั้นต่ำ 6 ไฟล์, inlineStr, freeze หัวตาราง) |
| backend/src/utils/xlsx-reader.js | อ่านไฟล์ .xlsx (ชีต เซลล์ เซลล์ที่รวม) พร้อมด่านกัน ZIP bomb และ XML entity |
| backend/src/utils/schedule-import.js | แปลงไฟล์ Excel/CSV ตารางเรียนเป็นรายการคาบ ตรวจซ้ำ/ทับซ้อน สร้างคำเตือนและ CSV มาตรฐาน |
| backend/src/utils/schedule.js | ตรวจตัวกรองและข้อมูลคาบเรียน (ห้อง วัน เวลา ความยาวข้อความ) ใช้ร่วมกันทั้ง route และตัวนำเข้า |
| backend/src/utils/class-schedule.js | คำนวณว่าตอนนี้อยู่ในคาบเรียนหรือไม่ตามเวลา Asia/Bangkok รวมสถานะภาคเรียน (none/before/active/after) |
| backend/src/utils/room-booking.js | ตรวจข้อมูลการจองห้อง คำนวณวันที่เกิดขึ้น หาการจองที่กำลังใช้ และรวมกับผลตารางเรียน (withBookings) |
| backend/src/utils/room.js | ตรวจข้อมูลห้อง แปลงแถวห้องเป็น JSON (รวมนาฬิกาปิดแอร์) และเดาค่าห้องใหม่ตอนนำเข้าตาราง |
| backend/src/utils/air-conditioner.js | ตรวจข้อมูลจองบอร์ดแอร์และคำสั่งแอร์ (อุณหภูมิ โหมด protocol) และแปลงแถวแอร์เป็น JSON ให้แอป (11 ต.ค.) โปรโตคอล `DAIKIN_WIRED` ตรวจคำสั่งตามความสามารถรีโมตติดผนัง และ `controlType` |
| backend/src/utils/occupancy-sensor.js | ตรวจข้อมูลเซ็นเซอร์ตรวจคน ปรับรูปข้อความสถานะ (occupied ต้องมี radarAvailable) และแปลงแถวเป็น JSON |
| backend/src/utils/firmware.js | ตรวจชื่อไฟล์ firmware (.bin) สร้าง URL ดาวน์โหลดสำหรับ OTA และเดาชนิดบอร์ดจากชื่อไฟล์ (14 ต.ค.) แยกชนิดไฟล์ air/wired/occupancy ตรวจไบต์แรก `0xE9` และขนาดไม่เกินช่อง OTA กันสั่งไฟล์ผิดชนิดให้บอร์ด |
| backend/src/utils/unprovision.js | (ใหม่ 13 ต.ค.) สร้างคำสั่ง `{"action":"unprovision"}` พร้อม `deviceId` ของบอร์ด และตรวจว่าคำตอบ "ล้างค่าแล้ว" มาจากบอร์ดตัวเดียวกัน (รอไม่เกิน 4 วินาที) |
| backend/src/utils/schema-doctor.js | อ่าน database/schema.sql แล้วเทียบกับฐานข้อมูลจริงเพื่อหาตารางและคอลัมน์ที่ขาด (ใช้กับ npm run db:doctor) |

## โปรโตคอล Broker สำหรับพัฒนา และเอกสาร README

รายละเอียดอยู่ในบทโปรโตคอลสื่อสาร (27 รายการ)

| ไฟล์ | หน้าที่ |
|---|---|
| `docs/BLE_MQTT_PROTOCOL.md` | เอกสารสัญญาการสื่อสาร: ตัวตนอุปกรณ์ UUID ของ BLE GATT รูปแพ็กเก็ตตั้งค่า และ topic/payload ของ MQTT (11–13 ต.ค.) เพิ่ม `controlType`/`controlMode`, บอร์ดสายแอร์ และคำสั่ง `unprovision` |
| `mqtt/setup_mqtt.ps1` | สคริปต์ตั้งค่า Broker สำหรับพัฒนา: หา LAN IP สร้างรหัสสุ่ม สร้าง password file กับ ACL เขียน `backend/.env` เปิด Docker และทดสอบ |
| `mqtt/start_mqtt.ps1` | เปิด Mosquitto container ที่ตั้งค่าไว้แล้วและแสดงสถานะ |
| `mqtt/stop_mqtt.ps1` | ปิด Mosquitto container ด้วย `docker compose down` |
| `mqtt/test_mqtt.ps1` | ทดสอบว่า Broker พร้อมโดยรอ healthcheck แล้ว publish retained, subscribe รับกลับ และล้างข้อความทดสอบ |
| `mqtt/README.md` | คู่มือสั้นของโฟลเดอร์ Broker สำหรับพัฒนา: ขั้นตอนตั้งค่า คำสั่งใช้งาน และ firewall |
| `README.md` | คู่มือหลักของโปรเจกต์: ฟังก์ชัน โครงสร้าง วิธีตั้งค่า Broker/Backend/Flutter/Firmware และเงื่อนไขเปิด BLE |
| `RELEASE_NOTES.md` | บันทึกการเปลี่ยนแปลงรุ่นล่าสุด (ความปลอดภัย เว็บแอป ตารางเรียน ภาคเรียน) (14 ต.ค.) หน้าเฟิร์มแวร์บนเว็บ, บอร์ดสายแอร์ Daikin + จอ OLED |
| `docs/learn/` | บทเรียนพื้นฐาน 18 บท (00–17) ตั้งแต่ Terminal, Docker, MQTT, SQL จนถึงขึ้นเซิร์ฟเวอร์ และไฟล์ Excel แผนการอ่าน (14 ต.ค.) เพิ่มบอร์ดสายแอร์ Daikin จอ OLED และหน้าเฟิร์มแวร์บนเว็บ |
| `docs/study/` | บันทึกสรุป 9 บท (00–08) แยกตามส่วน: ภาพรวม ฐานข้อมูล Backend แอป เฟิร์มแวร์ MQTT/BLE ปิดแอร์อัตโนมัติ ค่าไฟ และการขึ้นเซิร์ฟเวอร์ (14 ต.ค.) ปรับเลขรุ่นให้ตรงโค้ด |
| `คู่มือศึกษาโปรเจค/` | คู่มือนี้ 20 บท: `index.html` หน้าแรก, `chapters/` ฉบับ HTML, `markdown/` ต้นฉบับ .md, `assets/` CSS/JS (ขึ้น GitHub 14 ต.ค. 2569) |
| `START_HERE.md` | คู่มือเริ่มต้นฉบับย่อ: เตรียมโปรแกรม ตั้งค่า MQTT และรันระบบ |
| `README_TH.txt` | บันทึกอัปเดต firmware 1.6.0: เมนู "ตั้งค่าบอร์ด" ส่ง `enter_setup` ผ่าน MQTT และแก้เพิ่มบอร์ดตัวที่สองบน Windows |
| `README_FIXED_MQTT_TH.txt` | แอป 3.3.8: ตัดช่อง MQTT ออกจากฟอร์ม ให้ Backend ส่งค่าจาก `backend/.env` ให้บอร์ดอัตโนมัติ |
| `README_MQTT_HOST_EDIT_TH.txt` | อัปเดตเก่าที่ทำให้ช่อง MQTT Host แก้ไขได้ และอธิบายว่าห้ามใช้ 127.0.0.1 กับบอร์ด |
| `README_WIFI_RECOVERY_TH.txt` | บอร์ดทดสอบ Wi-Fi ก่อนบันทึกลง NVS และเปิด BLE recovery เมื่อต่อ Wi-Fi ที่เก็บไว้ไม่ได้ |
| `README_BLE_WINDOWS_GATT_FIX_TH.txt` | แก้ Windows เชื่อม BLE ได้แต่ค้นหา Service ไม่จบ (connect รอ GATT เสร็จก่อน ล็อก winrt 0.0.20) |
| `README_BLE_SECOND_DEVICE_FIX_TH.txt` | แก้ปัญหาเพิ่ม ESP32 ตัวที่สอง: Identity สั้นลงและแยกค่าตั้งเดิมไป characteristic ใหม่ |
| `README_AUTO_CREATE_ROOMS_TH.txt` | นำเข้าตารางเรียนแล้วสร้างห้องที่ยังไม่มีให้อัตโนมัติใน transaction เดียว |
| `README_EXCEL_IMPORT_TH.txt` | นำเข้าตารางเรียนจาก Excel/CSV พร้อมหน้า Preview และการตรวจข้อมูล |
| `README_LD2410_OCCUPANCY_V210_TH.txt` | คู่มือบอร์ดตรวจคน ESP32 + HLK-LD2410: Engineering mode เกต 0–8 และเกณฑ์ตัดสินว่ามีคน |
| `README_PZEM_LED_V200_TH.txt` | เพิ่ม PZEM-004T วัดไฟจริง ไฟ LED บอกสถานะ และการตรวจตารางเรียนโดย Backend |
| `README_ROOM_MANAGEMENT_V180_TH.txt` | เพิ่มชื่ออาจารย์ในตาราง และให้ Admin จัดการห้อง (เพิ่ม แก้ ลบ ห้องพิเศษ) |
| `README_SAIJO_DENKI_TH.txt` | เพิ่มโปรโตคอลแอร์ Saijo Denki (`SAIJO_DENKI`) พร้อมไดรเวอร์ IR เฉพาะและคำสั่งที่รองรับ |
| `README_UI_V181_TH.txt` | ปรับหน้าควบคุม: ปุ่มจัดการห้องเป็นเฟือง การ์ดห้อง และตัวเลือกชั้น |
| `README_UI_V182_TH.txt` | ปรับหน้าตารางและหน้าควบคุม: แถบวันครบ 7 วันและชุดสีเขียวเดียวกัน |
| `README_UI_V183_TH.txt` | หน้าตารางเลือกวันปัจจุบันอัตโนมัติและแสดงวันที่จริง |

## เฟิร์มแวร์ ESP32

รายละเอียดอยู่ในบทเฟิร์มแวร์ ESP32 (31 รายการ)

| ไฟล์ | หน้าที่ |
|---|---|
| firmware/README.md | คู่มือรวมของเฟิร์มแวร์ ESP32 ทั้งสองบอร์ด: ไลบรารี ขา GPIO ขั้นตอนตั้งค่า การกู้ Wi-Fi การต่อสายเรดาร์ การอ่าน log และตาราง MQTT state (ปรับ 11 ต.ค.; 14 ต.ค. แก้เลขรุ่นให้ตรงโค้ด 2.5.1 / 2.5.2-slm8 / 1.3.2 และเพิ่มหัวข้อ unprovision) ครอบคลุม 3 เฟิร์มแวร์ รวมบอร์ดสายแอร์ ไลบรารี U8g2/DHT ตารางขารวมจอ OLED GPIO21/22 |
| firmware/rmutt_esp32_air/rmutt_esp32_air.ino | โปรแกรมหลักของบอร์ดแอร์ (ปัจจุบัน 2.5.1 เริ่มเขียนบทนี้ตอน 2.4.1): BLE provisioning, Wi-Fi/MQTT (TLS, LWT), ยิง IR สั่งแอร์, อ่าน PZEM และตัดสินว่าแอร์ทำงาน, LED, ตารางเวลา, OTA และเก็บ/ส่งข้อมูลย้อนหลังตอนเน็ตหลุด (2.5.1) เพิ่มจอ OLED, `controlType:"ir"` ใน BLE และคำสั่ง `unprovision` ล้างบอร์ด |
| firmware/rmutt_esp32_air/SaijoDenkiAC.h | ประกาศคลาส SaijoDenkiAC และ enum SaijoFan/SaijoSwing สำหรับไดรเวอร์ IR ของแอร์ Saijo Denki |
| firmware/rmutt_esp32_air/SaijoDenkiAC.cpp | ค่าเวลาสัญญาณ 38 kHz และตารางเฟรม 72 บิตที่จับจากรีโมตจริง พร้อมเมธอดส่งเปิด/ปิด โหมด อุณหภูมิ 18–29 พัดลม และสวิง ผ่าน IRsend::sendGeneric |
| firmware/rmutt_esp32_air/history_log.h | เทมเพลต HistoryLog ที่เก็บรายการไฟฟ้า 32 ไบต์ทุก 5 นาทีเป็น ring buffer บนพาร์ติชัน rmuttlog พร้อม checksum, ส่งเป็น batch, ack และลบเป็น sector |
| firmware/rmutt_esp32_air/oled_display.h | (ใหม่ 11 ต.ค.) คลาส `OledDisplay` ขับจอ OLED SH1106: ตรวจว่ามีจอ วาดทุก 400 ms หรือเมื่อ `poke()` เก็บกราฟวัตต์ พักจอเมื่อแอร์ปิดเกิน 10 นาที |
| firmware/rmutt_esp32_air/oled_ui.h | (ใหม่ 11 ต.ค.) ฟังก์ชันวาดหน้าจอ 128×64 (`OledData`, หน้าหลัก, SETUP/CONNECTING/ALERT) ใช้ร่วมกับบอร์ดสายแอร์ |
| firmware/rmutt_esp32_air/build_opt.h | (ใหม่ 11 ต.ค.) แฟล็กคอมไพเลอร์ปิด I2C/SPI ฮาร์ดแวร์ของ U8g2 และโปรโตคอล IR 28 ยี่ห้อที่ไม่ใช้ ให้เฟิร์มแวร์ที่มีจอพอดีแฟลช (98%) |
| firmware/rmutt_esp32_air/README_OLED_TH.md | (ใหม่ 11 ต.ค.) คู่มือต่อจอ OLED หน้าจอที่แสดง ไลบรารี U8g2 และเหตุผลของ `build_opt.h` |
| firmware/rmutt_esp32_air_wired/rmutt_esp32_air_wired.ino | (ใหม่ 11 ต.ค.) เฟิร์มแวร์บอร์ดสายแอร์ Daikin 2.5.2-slm8 สั่งแอร์ทางสาย SLM8 + DHT11 รายงานสถานะจากแอร์ BLE/MQTT/PZEM/OTA เหมือนบอร์ด IR (บท 19) |
| firmware/rmutt_esp32_air_wired/DaikinSLM8.h | (ใหม่ 11 ต.ค.) โปรโตคอลสาย SLM8: สร้าง/อ่านเฟรม checksum ตัวรับ Rx (interrupt + ring buffer) ตัวส่ง Tx และ Controller |
| firmware/rmutt_esp32_air_wired/wired_bus.h | (ใหม่ 11 ต.ค.) รัน Controller ใน FreeRTOS task แยก (core 1, priority 3) พร้อม mutex ส่งเฟรมทุก 1 วินาที |
| firmware/rmutt_esp32_air_wired/README_WIRED_TH.md | (ใหม่ 11 ต.ค.) วิธีต่อสาย ไลบรารี ขั้นทดสอบหลังแฟลช และค่าที่ปรับได้ของบอร์ดสายแอร์ |
| firmware/rmutt_esp32_air_wired/build_opt.h | (ใหม่ 11 ต.ค.) ปิดไดรเวอร์ I2C/SPI ฮาร์ดแวร์ที่ U8g2 ไม่ใช้ เพื่อประหยัดแฟลช |
| firmware/rmutt_esp32_air_wired/partitions.csv | (ใหม่ 11 ต.ค.) แบ่งแฟลช 4MB เป็น 2 ช่องแอป (OTA) + rmuttlog 64KB เหมือนบอร์ด IR |
| firmware/rmutt_esp32_air_wired/history_log.h | (ใหม่ 11 ต.ค.) สำเนาเดียวกับบอร์ด IR: เก็บข้อมูลไฟย้อนหลังใน flash |
| firmware/rmutt_esp32_air_wired/ota_update.h | (ใหม่ 11 ต.ค.) สำเนาเดียวกับบอร์ด IR: อัปเดตเฟิร์มแวร์ผ่าน HTTPS |
| firmware/rmutt_esp32_air_wired/letsencrypt_ca.h | (ใหม่ 11 ต.ค.) สำเนาเดียวกับบอร์ด IR: ใบรับรอง CA ของ Let's Encrypt |
| firmware/rmutt_esp32_air_wired/oled_display.h | (ใหม่ 11 ต.ค.) สำเนาเดียวกับบอร์ด IR: ตัวขับจอ OLED |
| firmware/rmutt_esp32_air_wired/oled_ui.h | (ใหม่ 11 ต.ค.) สำเนาเดียวกับบอร์ด IR: หน้าจอ OLED |
| firmware/rmutt_esp32_air/ota_update.h | ตรวจ URL ที่อนุญาตและดาวน์โหลดเฟิร์มแวร์ใหม่ผ่าน HTTPS (ตรวจใบรับรองกับใบรากที่ฝังไว้) เขียนลงช่อง OTA ที่ว่าง |
| firmware/rmutt_esp32_air/letsencrypt_ca.h | ใบรับรองราก Let's Encrypt (ISRG Root X1 และ X2) ที่ฝังในเฟิร์มแวร์เพื่อตรวจ MQTTS และ OTA สร้างโดย update-root-ca.ps1 |
| firmware/rmutt_esp32_air/partitions.csv | ตารางพาร์ติชัน flash 4 MB ของบอร์ดแอร์: nvs, otadata, app0, app1 (OTA) และ rmuttlog 64 KB สำหรับข้อมูลย้อนหลัง |
| firmware/rmutt_esp32_occupancy/rmutt_esp32_occupancy.ino | โปรแกรมหลักของบอร์ดตรวจจับคน (v1.3.1): อ่านเรดาร์ LD2410 ใน Engineering mode, ตัดสินมีคนเมื่อ static energy เกต 0–8 มากกว่า 25, ส่งสถานะผ่าน MQTT, BLE provisioning และ OTA (1.3.2) เพิ่มคำสั่ง `unprovision` ล้าง NVS แล้วรีบูตเข้า BLE |
| firmware/rmutt_esp32_occupancy/ota_update.h | ไฟล์ OTA เหมือนของบอร์ดแอร์ทุกไบต์ ใช้ตรวจ URL และอัปเดตเฟิร์มแวร์ผ่าน HTTPS |
| firmware/rmutt_esp32_occupancy/letsencrypt_ca.h | ใบรับรองรากชุดเดียวกับบอร์ดแอร์ สำหรับ MQTTS และ OTA ของบอร์ดตรวจจับคน |
| firmware/rmutt_esp32_occupancy/partitions.csv | ตารางพาร์ติชัน flash 4 MB ของบอร์ดตรวจจับคน: nvs, otadata, app0, app1 และ coredump |
| firmware/ld2410_pinscan/ld2410_pinscan.ino | เครื่องมือสแกนขา GPIO ทีละขาเพื่อหาว่าขาไหนรับสัญญาณ UART จาก LD2410 และตรวจหัวเฟรมที่ baud 256000/115200/57600 |
| firmware/reset/reset.ino | สเก็ตช์ล้างค่าที่จำไว้ทั้งหมด (NVS และ Wi-Fi) เพื่อ factory reset บอร์ด |
| firmware/tests/history_log_test.cpp | เทสต์บนคอมพิวเตอร์สำหรับ history_log.h โดยจำลอง NOR flash ทดสอบการเก็บ ส่ง ack รีบูตกลางทาง การวนทับ และขยะในพาร์ติชัน |
| firmware/update-root-ca.ps1 | สคริปต์ PowerShell ดาวน์โหลดใบรับรองราก Let's Encrypt แล้วสร้าง letsencrypt_ca.h ให้ทั้งสองบอร์ด |

## แอป Flutter: โครงสร้าง ข้อมูล State และเทสต์

รายละเอียดอยู่ในบทแอป Flutter ตอนที่ 1 (83 รายการ)

| ไฟล์ | หน้าที่ |
|---|---|
| pubspec.yaml | ประกาศชื่อ เวอร์ชัน (3.16.0+32) SDK แพ็กเกจที่ใช้ ฟอนต์ ChakraPetch และ assets ของแอป Flutter |
| analysis_options.yaml | ตั้งกฎ lint ของ Dart (flutter_lints + avoid_print + prefer_const) |
| lib/main.dart | จุดเริ่มแอป สร้าง AuthController/AppSettingsController และ Service ทุกตัว ครอบ MaterialApp แล้วสลับ loading/login/AppShell ตามสถานะล็อกอิน |
| lib/config/api_config.dart | เก็บ URL ของ Backend (ค่าเริ่มต้น Tailscale ts.net, override ด้วย --dart-define=API_BASE_URL) |
| lib/data/mock_data.dart | สร้างรายการห้องตั้งต้น 21 ห้อง (3 ชั้น x 7) เป็นโครงเปล่าให้ Controller เติมข้อมูลจริงจาก Backend |
| lib/models/admin_contact.dart | โมเดลชื่อและเบอร์ติดต่อแอดมินที่แสดงในหน้า login |
| lib/models/air_conditioner.dart | โมเดลแอร์หนึ่งเครื่อง (สถานะสั่งงาน ค่า PZEM ปิดอัตโนมัติ) พร้อม enum โหมด/ลม/สวิง และกฎตามโปรโตคอล (Saijo Denki) (11 ต.ค.) ยี่ห้อ/วิธีควบคุม (`DAIKIN_WIRED`), getter `supportsXxx` และ `normalizeForProtocol()` |
| lib/models/auth_user.dart | โมเดลผู้ใช้ที่ล็อกอินอยู่ (username ชื่อ อีเมล role) |
| lib/models/class_schedule.dart | โมเดลคาบเรียนหนึ่งคาบ พร้อมฟังก์ชันตรวจเวลาทับกัน |
| lib/models/energy_data.dart | โมเดลทั้งหมดฝั่งพลังงาน: ค่าไฟสด ตัวเลือกรายงาน แถวประวัติ EnergyQuery สรุปรายช่วง และไฟล์ Excel ที่ดาวน์โหลด |
| lib/models/managed_user.dart | โมเดลผู้ใช้ในหน้าจัดการผู้ใช้ของแอดมิน (role, isActive, วันที่ล็อกอินล่าสุด) |
| lib/models/provisioning.dart | โมเดลสำหรับตั้งค่า ESP32 ผ่าน BLE: อุปกรณ์ที่สแกนเจอ Wi-Fi ที่ ESP32 เห็น identity ใบจอง และ JSON ที่เขียนลงบอร์ด (11 ต.ค.) อ่าน `controlType`/`brand` จาก identity ของบอร์ด |
| lib/models/remembered_login.dart | โมเดลชื่อผู้ใช้ที่จำไว้ในเครื่อง (ช่องรหัสผ่านเว้นว่างเสมอ) |
| lib/models/room.dart | โมเดลห้อง รวมรายการแอร์ในห้อง เซนเซอร์คนในห้อง และนาฬิกาปิดอัตโนมัติ |
| lib/models/schedule_import.dart | โมเดลพรีวิวและผลลัพธ์การนำเข้าตารางเรียนจาก Excel พร้อม `replaceAll` (เปลี่ยนภาคเรียน ล้างตารางเดิมทุกห้อง เพิ่ม 9 ต.ค.) |
| lib/models/room_calendar.dart | (ใหม่ 9 ต.ค.) ปฏิทินการใช้ห้อง: ตัวช่วยวันที่ `yyyy-MM-dd`, `RoomBooking` (วันเดียว/ทุกวัน/ทุกสัปดาห์) + นับจำนวนครั้ง, `AcademicTerm`/`AcademicCalendar` ภาคเรียน, `TimetableInfo`, `ScheduleBundle` และ `schedulesToCsv` |
| lib/models/system_alert.dart | โมเดลการแจ้งเตือนของระบบและ enum ชนิดแจ้งเตือน SystemAlertKind |
| lib/services/air_conditioner_repository.dart | สัญญา (abstract interface) ของการดึง/สั่ง/จอง/เปลี่ยนชื่อ/ลบแอร์ |
| lib/services/air_conditioner_service.dart | ตัวจริงที่ยิง HTTP ไป /air-conditioners ของ Backend |
| lib/services/alert_notifier.dart | สัญญาตัวเด้งแจ้งเตือนของเครื่อง + NoopAlertNotifier + ฟังก์ชัน describeAlert สร้างข้อความตามภาษา |
| lib/services/alert_repository.dart | สัญญาดึงและรับทราบการแจ้งเตือนของระบบ |
| lib/services/alert_service.dart | ตัวจริงที่ยิง GET /alerts และ POST /alerts/:id/acknowledge |
| lib/services/auth_repository.dart | สัญญาทั้งหมดเรื่องบัญชี: restoreSession, login, logout, ลืมรหัสผ่าน, แก้โปรไฟล์, เปลี่ยนรหัส |
| lib/services/auth_service.dart | ตัวจริงของ Auth: เก็บ token ใน secure storage ยิง /auth/* และนิยาม ApiException ที่ทุก Service ใช้ร่วม |
| lib/services/ble_provisioning_service.dart | คุย BLE กับ ESP32 ด้วย flutter_blue_plus: สแกน อ่าน identity สแกน Wi-Fi และส่ง config เป็นก้อน ๆ |
| lib/services/energy_repository.dart | สัญญาข้อมูลพลังงาน: metrics, live, sources, summary, history, export |
| lib/services/energy_service.dart | ตัวจริงที่ยิง /energy/* รวมถึงดาวน์โหลดไฟล์ Excel เป็น bytes |
| lib/services/occupancy_sensor_repository.dart | สัญญาจอง/ตั้งค่า/ลบเซนเซอร์คนในห้อง |
| lib/services/occupancy_sensor_service.dart | ตัวจริงที่ยิง /occupancy-sensors/* |
| lib/services/room_repository.dart | สัญญา CRUD ห้อง |
| lib/services/room_service.dart | ตัวจริงที่ยิง /rooms (ตัวอย่างต้นแบบของชั้น Service) |
| lib/services/schedule_repository.dart | สัญญา CRUD ตารางเรียน นำเข้าไฟล์ Excel และ (9 ต.ค.) ปฏิทินภาคเรียนกับการใช้ห้อง |
| lib/services/schedule_service.dart | ตัวจริงที่ยิง /schedules/* รวมอัปโหลดไฟล์ดิบเพื่อพรีวิว และ (9 ต.ค.) /schedules/terms, /bookings |
| lib/services/system_settings_repository.dart | นิยาม SystemSettings และสัญญาอ่าน/เขียนค่าตั้งระดับระบบ (สวิตช์ปิดแอร์อัตโนมัติรวม) |
| lib/services/system_settings_service.dart | ตัวจริงที่ยิง GET /settings และ PATCH /settings/auto-off |
| lib/services/user_repository.dart | สัญญา CRUD ผู้ใช้สำหรับแอดมิน |
| lib/services/user_service.dart | ตัวจริงที่ยิง /users |
| lib/controllers/air_conditioner_controller.dart | ดึงแอร์ทุก 10 วินาที แจกเข้าห้อง ส่งคำสั่ง เปลี่ยนชื่อ ลบ |
| lib/controllers/app_settings_controller.dart | ค่าตั้งของเครื่อง (ธีม ภาษา ขนาดตัวอักษร ค่าไฟต่อหน่วย การแจ้งเตือน) พร้อม AppSettingsStore เก็บใน secure storage |
| lib/controllers/auth_controller.dart | สถานะล็อกอิน (loading/signedOut/signedIn) และผู้ใช้ปัจจุบัน |
| lib/controllers/dashboard_controller.dart | สรุปพลังงานหน้าหลัก/สถิติ + รายการแจ้งเตือน รีเฟรชทุก 30 วินาที และตรวจใบใหม่ |
| lib/controllers/energy_controller.dart | ค่าไฟสด (รอบ 2/5/10/30/60 วินาที) แคตตาล็อกรายงาน พรีวิว และส่งออก Excel |
| lib/controllers/room_controller.dart | รายการห้อง รีโหลดทุก 10 วินาที และ CRUD ห้อง |
| lib/controllers/schedule_controller.dart | รายการตารางเรียน CRUD นำเข้า ตรวจเวลาทับกัน และ (9 ต.ค.) ภาคเรียนของตาราง ปฏิทินภาคเรียน การใช้ห้องรายสัปดาห์ `classesOn`/`bookingsOn` |
| lib/controllers/system_settings_controller.dart | ค่าตั้งระดับระบบจากเซิร์ฟเวอร์ แบบ optimistic update แล้วถอยกลับถ้าล้มเหลว |
| lib/controllers/user_controller.dart | รายการผู้ใช้ของแอดมิน เปลี่ยน role/สถานะ สร้าง ลบ และเรียงลำดับ |
| lib/utils/alert_preferences.dart | AlertChannels/AlertPreferences ค่าตั้งแจ้งเตือนรายชนิด (encode/decode JSON) และ freshAlerts |
| lib/utils/file_saver.dart | บันทึกไฟล์ Excel หรือ CSV (เลือกนามสกุลได้ตั้งแต่ 9 ต.ค.): Android/iOS ผ่านเมนูแชร์ Windows ผ่านกล่อง Save As |
| lib/utils/number_format.dart | จัดรูปตัวเลข: formatDecimal คั่นหลักพัน และ formatEnergy เลือกหน่วย Wh/kWh/MWh อัตโนมัติ |
| lib/utils/thai_date.dart | จัดวันที่ (พ.ศ./ค.ศ.) แปลงข้อความวันที่ และปฏิทินเลือกวันของแอปเอง รวม `formatWeekdayShort` ชื่อวันย่อใต้กราฟ |
| lib/localization/app_localizations.dart | ตัวแปลไทย/อังกฤษแบบ map ข้อความ + regex และ delegate ของ Flutter (11 ต.ค.) คำแปลใหม่ของยี่ห้อ/วิธีควบคุม |
| lib/localization/localized_material.dart | re-export Material แต่แทนที่ Text ด้วยตัวที่แปลข้อความอัตโนมัติ |
| lib/theme/app_theme.dart | สีแบรนด์ 4 ธีม (ขาว/เทา/ดำ/เขียว) + ตามเครื่อง ผ่าน AppColors, AppPalette และ AppTheme |
| web/index.html | หน้าเว็บเปล่าของ Flutter Web (flutter build web) ไม่ใช่เว็บแอปที่ใช้งานจริง |
| web/manifest.json | manifest ของ Flutter Web (ชื่อแอป สีธีม) |
| android/app/build.gradle.kts | ตั้ง applicationId, namespace, Java 17 และการเซ็น release ด้วย key.properties |
| android/build.gradle.kts | ตั้ง repository และย้ายโฟลเดอร์ build ของโปรเจกต์ Android |
| android/settings.gradle.kts | โหลด Flutter SDK และกำหนดเวอร์ชัน plugin (AGP 9.0.1, Kotlin 2.3.20) |
| android/gradle.properties | ตั้งหน่วยความจำ Gradle และแฟลก AndroidX/newDsl |
| android/app/src/main/AndroidManifest.xml | ประกาศสิทธิ์ INTERNET/Bluetooth/Location และ MainActivity ของแอป |
| android/app/src/main/kotlin/.../MainActivity.kt | ไม่มีในสำเนาที่ให้มา (ปกติ flutter สร้าง FlutterActivity เปล่า) |
| test/app_localizations_test.dart | ทดสอบตัวแปลไทย/อังกฤษและข้อความผิดพลาดจาก Backend |
| test/app_preferences_test.dart | ทดสอบธีม ขนาดตัวอักษร AlertPreferences freshAlerts และการจำค่าตั้งด้วย store ปลอม |
| test/auto_off_countdown_test.dart | ทดสอบวิดเจ็ตนับถอยหลังปิดอัตโนมัติ formatCountdown และฟิลด์ปิดอัตโนมัติของ Room |
| test/ble_identity_test.dart | ทดสอบการอ่าน BleDeviceIdentity ของเฟิร์มแวร์ 1.6 (identity สั้น + settings แยก) |
| test/class_schedule_test.dart | ทดสอบ timesOverlap และการแปลง JSON ของคาบเรียน |
| test/daikin_wired_support_test.dart | (ใหม่ 11 ต.ค.) ข้อจำกัดของแอร์ `DAIKIN_WIRED` ยี่ห้อ/วิธีควบคุมของแอร์ IR และ identity BLE แบบสายแอร์ (3 เทสต์) |
| test/energy_database_test.dart | ทดสอบหน้า ฐานข้อมูล (ค่าไฟสด โหมดสรุป/รายเครื่อง พรีวิว) ด้วย repository ปลอม |
| test/energy_format_test.dart | ทดสอบ formatEnergy และ energyScaleReference |
| test/energy_usage_chart_test.dart | ทดสอบกราฟแท่งพลังงาน 14 เคส: พิกัดแท่ง `niceScaleMax` ป้ายแกนนอน และการแตะ |
| test/mock_data_test.dart | ทดสอบ MockData ว่ามี 21 ห้อง 3 ชั้น |
| test/number_format_test.dart | ทดสอบ formatDecimal |
| test/occupancy_status_test.dart | ทดสอบการอ่านสถานะเซนเซอร์คนในห้องและ identity แบบ occupancy |
| test/pzem_status_test.dart | ทดสอบ 5 กรณีว่าสถานะ "กำลังทำงาน" มาจาก PZEM ไม่ใช่คำสั่ง IR รวมถึง `isPoweredOn` เป็นจริงเมื่อเปิดแอร์ด้วยรีโมตจริง (PZEM เห็นกระแส) และปิดแล้ว `isRunning` กลับเป็น false |
| test/room_calendar_test.dart | (ใหม่ 9 ต.ค.) ทดสอบตัวช่วยวันที่ การจองห้องแบบต่าง ๆ ภาคเรียน และ CSV ตารางเรียน 11 เคส |
| test/saijo_denki_support_test.dart | ทดสอบข้อจำกัดของโปรโตคอล Saijo Denki เทียบกับ Haier |
| test/schedule_date_test.dart | ทดสอบการแปลงวันในสัปดาห์เป็นดัชนีตารางเรียน (เริ่มวันอาทิตย์) |
| test/schedule_import_test.dart | ทดสอบพรีวิว/คอมมิตนำเข้าตารางและห้องใหม่ |
| test/system_settings_test.dart | ทดสอบ SystemSettingsController (optimistic update, ถอยกลับ, กันกดซ้ำ) |
| test/thai_date_test.dart | ทดสอบวันที่ พ.ศ./ค.ศ. และ parseNumericDate |
| test/user_management_test.dart | ทดสอบ ManagedUser และ UserController |
| test/widget_test.dart | ทดสอบทั้งแอป (9 ต.ค. เพิ่มขั้นเพิ่มการใช้ห้อง): ล็อกอิน จำชื่อผู้ใช้ สลับภาษา/ธีม ค่าไฟ เพิ่มตารางเรียน เพิ่มห้อง CL503 |
| test/wifi_network_candidate_test.dart | ทดสอบ WifiNetworkCandidate, identity ที่ ESP32 ส่ง และ JSON BLE ของใบจอง |

## แอป Flutter: หน้าจอและวิดเจ็ต

รายละเอียดอยู่ในบทแอป Flutter ตอนที่ 2–3 (36 รายการ)

| ไฟล์ | หน้าที่ |
|---|---|
| lib/screens/app_shell.dart | โครงหลักหลังล็อกอิน: สร้างและเป็นเจ้าของ Controller ทุกตัว มี NavigationBar สลับหน้า และเด้งแจ้งเตือนใบใหม่ |
| lib/screens/home_screen.dart | หน้าหลัก: การ์ดพลังงานตามช่วงเวลา แจ้งเตือนระบบ และสรุปห้อง |
| lib/screens/analytics_screen.dart | หน้าสถิติ: กราฟและอันดับการใช้ไฟรายห้อง/รายเครื่อง |
| lib/screens/rooms_screen.dart | หน้าเลือกห้องที่ต้องการควบคุม แบ่งตามชั้น |
| lib/screens/room_control_screen.dart | หน้าควบคุมแอร์ทุกเครื่องในห้องหนึ่งห้อง |
| lib/screens/schedule_screen.dart | หน้าตารางเรียนตามวันที่จริง เลื่อนทีละสัปดาห์ รวมคาบเรียนกับการใช้ห้อง สถานะภาคเรียน และดาวน์โหลด CSV (ขยาย 9 ต.ค.) |
| lib/screens/booking_editor_screen.dart | (ใหม่ 9 ต.ค.) ฟอร์มเพิ่ม/แก้การใช้ห้อง ทำซ้ำวันเดียว/ทุกวัน/ทุกสัปดาห์/ในตารางเรียน พร้อมสรุปจำนวนครั้ง |
| lib/screens/term_calendar_screen.dart | (ใหม่ 9 ต.ค.) ปฏิทินภาคเรียน เพิ่ม/แก้/ลบวันเปิด–ปิดของแต่ละเทอม |
| lib/screens/schedule_management_screen.dart | หน้าแอดมินเพิ่ม/แก้/ลบคาบเรียน |
| lib/screens/schedule_import_screen.dart | หน้านำเข้าตารางเรียนจาก Excel พร้อมพรีวิวและเลือกภาคเรียน |
| lib/screens/room_management_screen.dart | หน้าแอดมินเพิ่ม/แก้/ลบห้อง และเข้าไปเพิ่มแอร์/เซนเซอร์ |
| lib/screens/ble_provisioning_screen.dart | ตัวช่วยตั้งค่า ESP32 ของแอร์ผ่าน BLE ทีละขั้น (11 ต.ค.) แสดงชนิดบอร์ดและล็อกยี่ห้อเมื่อเป็นบอร์ดสายแอร์ |
| lib/screens/occupancy_provisioning_screen.dart | ตัวช่วยตั้งค่า ESP32 ของเซนเซอร์คนในห้อง (LD2410) ผ่าน BLE |
| lib/screens/energy_database_screen.dart | หน้า ฐานข้อมูล: ค่าไฟสดและการเลือกเงื่อนไขส่งออกรายงาน Excel |
| lib/screens/electricity_rate_screen.dart | หน้าตั้งอัตราค่าไฟต่อหน่วย |
| lib/screens/user_management_screen.dart | หน้าแอดมินจัดการผู้ใช้ |
| lib/screens/profile_screen.dart | หน้าโปรไฟล์และทางเข้าเมนูต่าง ๆ |
| lib/screens/account_settings_screen.dart | หน้าแก้ข้อมูลบัญชีและเปลี่ยนรหัสผ่าน |
| lib/screens/application_settings_screen.dart | หน้าตั้งค่าแอป: ธีม ภาษา ขนาดตัวอักษร และค่าระบบ |
| lib/screens/notification_settings_screen.dart | หน้าตั้งค่าการแจ้งเตือนแยกตามชนิด |
| lib/screens/auth/auth_loading_screen.dart | หน้าโหลดตอนกำลังตรวจ token ที่เก็บไว้ |
| lib/screens/auth/login_screen.dart | หน้าเข้าสู่ระบบ จำชื่อผู้ใช้ และแผ่นติดต่อแอดมิน |
| lib/screens/auth/forgot_password_screen.dart | หน้าลืมรหัสผ่านแบบขั้นตอน (ขอ OTP, ยืนยัน, ตั้งรหัสใหม่) |
| lib/widgets/air_control_card.dart | การ์ดควบคุมแอร์หนึ่งเครื่อง (เปิดปิด อุณหภูมิ โหมด ค่าไฟ) (11 ต.ค.) แสดงป้าย `AirControlBadge` |
| lib/widgets/air_control_badge.dart | (ใหม่ 11 ต.ค.) ป้ายยี่ห้อ·วิธีควบคุมแอร์ เช่น "Daikin · สายแอร์" / "Haier · รีโมต IR" ใช้ในการ์ดแอร์และรีโมตเต็ม |
| lib/widgets/auto_off_countdown.dart | วิดเจ็ตนับถอยหลังก่อนระบบปิดแอร์อัตโนมัติ |
| lib/widgets/brand_mark.dart | โลโก้ RMUTT Save Energy วาดด้วยโค้ด |
| lib/widgets/energy_usage_chart.dart | กราฟแท่งการใช้พลังงาน (เปลี่ยนจากกราฟเส้น 9 ต.ค.) ป้ายเฉพาะแท่งสูงสุด แกนตัวเลขกลม เส้นเฉลี่ยรายวัน แตะ/ลากดูค่าได้ |
| lib/widgets/floor_selector.dart | ตัวเลือกชั้น |
| lib/widgets/full_remote_sheet.dart | แผ่นรีโมตเต็มรูปแบบของแอร์ (11 ต.ค.) ซ่อนปุ่มที่แอร์เครื่องนั้นทำไม่ได้ และมีป้ายยี่ห้อ·วิธีควบคุม |
| lib/widgets/period_selector.dart | ตัวเลือกช่วงเวลา วัน/สัปดาห์/เดือน/กำหนดเอง |
| lib/widgets/section_title.dart | หัวข้อส่วนที่ใช้ซ้ำ |
| lib/widgets/status_pill.dart | ป้ายสถานะทรงเม็ดยา |
| lib/widgets/weekday_selector.dart | ตัวเลือกวันในสัปดาห์ |
| lib/widgets/auth/auth_background.dart | พื้นหลังและโลโก้ชื่อแอปของหน้า login/ลืมรหัส |
| lib/widgets/auth/auth_text_field.dart | ช่องกรอกข้อความสไตล์หน้า auth |

## เว็บแอป

รายละเอียดอยู่ในบทเว็บแอป (38 รายการ)

| ไฟล์ | หน้าที่ |
|---|---|
| webapp/index.html | เปลือกของเว็บแอป (แถบข้าง แถบบน พื้นที่เนื้อหา ลิ้นชักรีโมต) โหลด CSS 4 ไฟล์และ main.js แบบ module โดยไม่มี JavaScript ฝังในหน้า |
| webapp/status.html | หน้าสถานะเบา ๆ ที่ไม่ต้องล็อกอิน แสดงว่า API และ MQTT Broker ปกติหรือไม่ |
| webapp/site.webmanifest | ไฟล์ PWA บอกชื่อ ไอคอน สีธีม และโหมด standalone เมื่อติดตั้งเว็บลงหน้าจอหลัก |
| webapp/README.md | เอกสารของเว็บแอป: เหตุผลการออกแบบ โครงไฟล์ ฟีเจอร์ต่อหน้า การพัฒนาบนเครื่องและการ deploy |
| webapp/*.png, webapp/favicon.*, webapp/assets/brand/*.svg | ไอคอนแอป favicon apple-touch-icon และโลโก้ SVG ที่ index.html และ manifest อ้างถึง (ไม่อยู่ในสำเนาโค้ดที่ใช้เขียนบทนี้) |
| webapp/assets/css/tokens.css | ตัวแปร CSS ทั้งหมด: สี 4 ธีม (gray/white/black/green) ขนาดตัวอักษร ระยะ และตัวคูณขนาดตัวอักษรของผู้ใช้ |
| webapp/assets/css/base.css | reset โครงหน้า แถบข้าง แถบบน แถบเมนูล่างบนมือถือ และ media query ย่อจอ |
| webapp/assets/css/components.css | ชิ้นส่วนที่ใช้ซ้ำ: การ์ด ปุ่ม ฟอร์ม ตาราง สวิตช์ ลิ้นชัก modal toast ช่องวันที่ พ.ศ. |
| webapp/assets/css/views.css | สไตล์เฉพาะของแต่ละหน้า เช่น ภาพรวม Building Pulse ห้อง ตารางเรียน นำเข้าตาราง ผู้ใช้ ตั้งค่า (14 ต.ค.) สไตล์หน้าเฟิร์มแวร์และชิปยี่ห้อ |
| webapp/assets/js/main.js | จุดเริ่มของเว็บ: ใส่ธีมและขนาดตัวอักษรก่อนวาด เริ่มนาฬิกา แล้วเรียก startApp |
| webapp/assets/js/app.js | ตัวประกอบร่าง: ตรวจล็อกอิน วาดเมนูและแถบบน สลับหน้าตาม hash (#/rooms) และจัดการลิ้นชักรีโมตแอร์ (14 ต.ค.) เส้นทาง/เมนู "เฟิร์มแวร์" (แอดมิน) |
| webapp/assets/js/auth.js | หน้าเข้าสู่ระบบและขั้นตอนลืมรหัสผ่าน 3 ขั้น (ขอ OTP ยืนยัน OTP ตั้งรหัสใหม่) |
| webapp/assets/js/config.js | API_BASE (รับ ?api= เฉพาะ localhost) คีย์ localStorage ช่วงเวลา polling และชื่ออาคาร |
| webapp/assets/js/api.js | ชั้นเดียวที่เรียก fetch: แนบ Bearer token จัดการ 401 แปลง error เป็น ApiError และรวม method ของทุก endpoint (14 ต.ค.) ฟังก์ชันอัปโหลด/ลบไฟล์เฟิร์มแวร์ |
| webapp/assets/js/store.js | state กลาง subscribe/emit ตัวโหลดข้อมูลแต่ละชุด และ polling ตามช่วงใน config.js |
| webapp/assets/js/format.js | ฟังก์ชันจัดรูปแบบตัวเลข หน่วยพลังงาน วันที่ไทย พ.ศ. เวลา และคำอธิบายการแจ้งเตือน (11 ต.ค.) ป้ายยี่ห้อ/วิธีควบคุมและความสามารถของแอร์ |
| webapp/assets/js/thai-date-input.js | ช่องวันที่ที่พิมพ์และแสดงเป็น พ.ศ. มีปฏิทินป๊อปอัป แต่ .value ยังเป็น YYYY-MM-DD |
| webapp/assets/js/theme.js | ธีมสี gray/white/black/green/auto เก็บใน localStorage ตั้ง data-palette และจุดเลือกธีมบนแถบบน |
| webapp/assets/js/prefs.js | ขนาดตัวอักษร (ปกติ/ใหญ่/ใหญ่มาก) เก็บใน localStorage ตั้ง data-text บน html |
| webapp/assets/js/charts.js | วาดกราฟเส้นพื้นที่แบบ SVG พร้อมป้ายค่าและ tooltip แถบอันดับ สี heat ของ Building Pulse และกล่องตัวเลข |
| webapp/assets/js/icons.js | ไอคอน SVG ชุดหลักที่เขียนเอง ไม่พึ่ง CDN (14 ต.ค.) ไอคอนเมนูเฟิร์มแวร์ |
| webapp/assets/js/icons-ui.js | ไอคอน SVG ชุดเสริม (ค้นหา อัปโหลด เมนูล่าง ฯลฯ) แยกไฟล์เพื่อเลี่ยงปัญหาแคชไฟล์เก่า |
| webapp/assets/js/ui.js | toast modal ฟอร์มจากรายการช่อง กล่องยืนยัน และ withBusy ที่ทุกหน้าใช้ร่วมกัน |
| webapp/assets/js/dom.js | ตัวช่วยสร้าง DOM ปลอดภัย (el, append, replace, toggle ฯลฯ) ใส่ข้อความด้วย textContent กัน XSS |
| webapp/assets/js/status.js | สคริปต์ของ status.html เรียก /api/health ทุก 15 วินาทีแล้วแสดงสถานะ |
| webapp/assets/js/views/overview.js | หน้าภาพรวม: ค่าไฟรวมและกราฟ ตัวเลข 4 ช่อง Building Pulse การแจ้งเตือนล่าสุด และ 5 ห้องที่ใช้ไฟมากสุด |
| webapp/assets/js/views/rooms.js | หน้าห้อง: การ์ดห้อง ตัวกรอง นับถอยหลังปิดอัตโนมัติ และรีโมตแอร์ในลิ้นชัก (ส่งคำสั่งผ่าน API) (11 ต.ค.) ชิปยี่ห้อ/วิธีควบคุม และปุ่มตามความสามารถของเครื่อง |
| webapp/assets/js/views/energy.js | หน้าข้อมูลไฟฟ้า: ตัวกรองหลายแบบ กราฟ ตารางย้อนหลัง และส่งออกไฟล์ Excel |
| webapp/assets/js/views/schedule.js | หน้าตารางเรียนและการใช้ห้องรายวัน เลื่อนทีละสัปดาห์ แอดมินแก้ไข นำเข้า และล้างตารางได้ |
| webapp/assets/js/views/schedule-import.js | กล่องนำเข้าตารางเรียนจาก Excel/CSV 3 ขั้น (เลือกไฟล์ ตรวจตัวอย่าง ยืนยัน) พร้อมส่งออก CSV |
| webapp/assets/js/views/term-calendar.js | ปฏิทินภาคเรียน: แสดงและแก้วันเปิด-ปิดของแต่ละเทอม (แก้ได้เฉพาะแอดมิน) |
| webapp/assets/js/views/booking-form.js | ฟอร์มเพิ่มการใช้ห้องที่มีวันที่ (วันเดียว ทุกวัน ทุกสัปดาห์) หรือเพิ่มเป็นคาบในตารางเรียน |
| webapp/assets/js/views/alerts.js | หน้าการแจ้งเตือนทั้งหมด กรองตามสถานะและห้อง กดรับทราบได้ |
| webapp/assets/js/views/rates.js | หน้าอัตราค่าไฟต่อ kWh พร้อมตัวอย่างการคำนวณ (แอดมินแก้ได้) |
| webapp/assets/js/views/devices.js | หน้าห้องและอุปกรณ์ (แอดมินเท่านั้น): จัดการห้อง จองช่องบอร์ดแอร์และเซ็นเซอร์ อัปเดตเฟิร์มแวร์ ถอดอุปกรณ์ (11 ต.ค.) ตัวเลือกจอง "Daikin · สายแอร์" |
| webapp/assets/js/views/firmware.js | (ใหม่ 14 ต.ค.) หน้าเฟิร์มแวร์ (แอดมิน): 3 แท็บตามชนิดบอร์ด อัปโหลด .bin (ถามรุ่นถ้าชื่อไม่มี) ตารางบอร์ดที่ยังเก่า อัปเดตหลายบอร์ด ติดตามผลจนรายงานรุ่นใหม่หรือครบ 5 นาที |
| webapp/assets/js/views/users.js | หน้าผู้ใช้งาน (แอดมินเท่านั้น): เพิ่ม เปลี่ยนสิทธิ์ เปิด-ปิด และลบบัญชี |
| webapp/assets/js/views/settings.js | หน้าตั้งค่า: ธีมและขนาดตัวอักษร สวิตช์ปิดแอร์อัตโนมัติรวม ข้อมูลบัญชี สถานะเชื่อมต่อ และออกจากระบบ |

## สคริปต์ติดตั้ง สร้างแอป และ CI

รายละเอียดอยู่ในบทการติดตั้งระบบและการทดสอบ (22 รายการ)

| ไฟล์ | หน้าที่ |
|---|---|
| run_all.ps1 | สคริปต์เดียวเปิดระบบฝั่งเครื่อง Windows ทั้งชุด (Docker, MariaDB, migrate, ตั้ง MQTT_URL, Mosquitto, Backend, Flutter) หรือโหมด -Server เพื่อตรวจเซิร์ฟเวอร์จริงแล้วเปิดแอป |
| check_system.ps1 | ตรวจเร็ว 3 ขั้น: Mosquitto healthy, Backend /api/health ตอบ ok, Backend เชื่อม MQTT แล้ว |
| diagnose.ps1 | ตรวจ 7 ขั้นหาสาเหตุที่ ESP32 ไม่ขึ้นในแอป (Docker, IP ไม่ตรง, health, doctor, firewall 1883, log broker, ดักฟัง rmutt/#) |
| db-tunnel.ps1 | เปิดอุโมงค์ SSH พอร์ต 3307 ไปฐานข้อมูลบนเซิร์ฟเวอร์ และก๊อปรหัส DB ใส่คลิปบอร์ดสำหรับ HeidiSQL |
| build-apk.ps1 | สร้างโฟลเดอร์ android (ถ้าไม่มี), เติมสิทธิ์ใน AndroidManifest, แล้ว flutter build apk พร้อม --dart-define=API_BASE_URL |
| BUILD-ANDROID.bat | ไฟล์ดับเบิลคลิกบน Windows: สร้าง keystore ถ้ายังไม่มี แล้วเรียก build-apk.ps1 และเปิดโฟลเดอร์ผลลัพธ์ |
| create-keystore.ps1 | สร้างกุญแจเซ็น APK (.jks) ด้วย keytool และเขียน android/key.properties ครั้งเดียวในชีวิตโปรเจกต์ |
| change-keystore-password.ps1 | เปลี่ยนรหัสผ่านของ keystore เดิม (กุญแจไม่เปลี่ยน) พร้อมสำรองและย้อนกลับเมื่อพลาด |
| deploy/setup-vps.sh | ติดตั้งเครื่อง Ubuntu ใหม่: อัปเดตระบบ, Docker, swap, เวลา/NTP, firewall (เลือกได้), โครงโฟลเดอร์ /opt/rmutt, cron (14 ต.ค.) สร้างโฟลเดอร์ firmware เป็นของ uid 1000 |
| deploy/init-env.sh | สร้าง /opt/rmutt/.env พร้อมรหัสสุ่ม และสร้างไฟล์บัญชี MQTT Dynamic Security ของ Backend |
| deploy/update-remote.sh | สคริปต์ที่รันบนเซิร์ฟเวอร์ตอนอัปเดต: build backend, migrate, reload Caddy, สร้างกล่อง tailscale ใหม่ (`up -d --force-recreate tailscale`) ให้ `tailscale-serve.json` ใหม่มีผล, ตรวจ health และเส้นทางสำคัญ (14 ต.ค.) ตรวจและ `chown 1000:1000` โฟลเดอร์ firmware ทุกครั้งที่อัปเดต |
| deploy/update-server.ps1 | สั่งจาก Windows: อัปโหลด backend + ไฟล์ตั้งค่า + เว็บแอป แล้วสั่ง update-remote.sh ผ่าน SSH |
| deploy/upload.ps1 | อัปโหลดชุด deploy, เว็บแอป และซอร์ส backend ขึ้นเซิร์ฟเวอร์ครั้งแรก (หรือ -BackendOnly) |
| deploy/deploy-web.ps1 | อัปโหลดเฉพาะโฟลเดอร์ webapp ขึ้น /opt/rmutt/www โดยไม่ build/ไม่รีสตาร์ท |
| deploy/ServerConfig.ps1 | ฟังก์ชัน Get-RmuttServer อ่าน deploy/server.config.json ให้สคริปต์ทุกตัวใช้ host/user/port/domain ร่วมกัน |
| deploy/sync-mqtt-cert.sh | ก๊อปใบรับรอง TLS ที่ Caddy ขอไว้ให้ Mosquitto (8883) แล้วส่ง SIGHUP เมื่อใบเปลี่ยน; cron เรียกทุกวัน 03:10 |
| deploy/fix-mqtt-permissions.sh | แก้เจ้าของ/สิทธิ์ไฟล์ของ Mosquitto (uid 1883) เมื่อคอนเทนเนอร์ rmutt-mqtt วน Restarting |
| .github/workflows/test.yml | GitHub Actions (เพิ่ม 9 ต.ค. 2569) รันอัตโนมัติทุกครั้งที่ push หรือเปิด pull request: ติดตั้ง Flutter แล้วรัน `flutter analyze` และ `flutter test` เพื่อจับโค้ดพังก่อนรวมเข้า main |
| .github/workflows/build-android.yml | (ใหม่ 9 ต.ค.) GitHub Actions build APK บน Ubuntu เมื่อกดรันเอง รับ `api_base_url` ติดตั้ง Java 17 (`setup-java@v5`) + Flutter เซ็นด้วยกุญแจจาก Secrets (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_PASSWORD`) หรือ debug key แล้วต่อท้ายชื่อ `-DEBUG-KEY` เก็บ APK เป็น artifact 14 วัน |
| .github/workflows/build-ios.yml | GitHub Actions ที่ build แอป iOS (.ipa ไม่เซ็น) บนเครื่อง macOS เมื่อกดรันเอง รับ input `api_base_url` (ค่าเริ่มต้นที่อยู่ ts.net) ส่งผ่าน env เข้า `--dart-define=API_BASE_URL` และมีขั้นแทนไอคอน Flutter ด้วยโลโก้ RMUTT Energy ผ่าน `sips` |
| .gitignore | กำหนดไฟล์ที่ไม่ส่งขึ้น git: ความลับ (.env, key.properties, *.jks, server.config.json), build, ข้อมูล broker |
| .vscode/settings.json | ตั้งค่า VS Code ของผู้เขียน (cmake.sourceDirectory ชี้โฟลเดอร์ windows) ไม่เกี่ยวกับการทำงานของระบบ |

## สรุป

รวมทั้งหมด 345 รายการ ครอบคลุมโค้ดและไฟล์ตั้งค่าทุกส่วนของโปรเจค
