# เว็บแอป — อ่านง่ายขึ้น ใช้ได้ทั้งคอมพิวเตอร์และมือถือ

ขึ้นเซิร์ฟเวอร์ด้วย `.\deploy\update-server.ps1` (มีแก้ Backend เรื่องเปลี่ยนภาคเรียน)
ไม่ต้องรัน migration และแอปมือถือรุ่นเดิมใช้ต่อได้ไม่ต้องอัปเดต

## อ่านสบายตาขึ้น

- ตัวหนังสือรองทุกจุด (หัวตาราง คำอธิบาย เวลา) มีคอนทราสต์อย่างน้อย 4.5:1 ตาม WCAG AA
  (เดิม 3:1) ขนาดเล็กสุด 12px (เดิม 9.5px) และเว้นบรรทัด 1.6 ให้วรรณยุกต์ไทยไม่ชนกัน
- ตัวไทยเปลี่ยนเป็น IBM Plex Sans Thai ซึ่งหัวตัวอักษรใหญ่กว่า Sarabun อ่านง่ายกว่าที่ขนาดเล็ก
- เพิ่ม **ธีมสว่าง** (ปุ่มดวงอาทิตย์บนแถบบน หรือหน้าตั้งค่า) และ **ขนาดตัวอักษร**
  ปกติ / ใหญ่ / ใหญ่มาก — จำแยกตามเครื่อง ค่าเริ่มต้นยังเป็นธีมมืดเหมือนเดิม

## นำเข้าตารางเรียนจาก Excel / CSV บนเว็บ

- ปุ่ม "นำเข้าจาก Excel / CSV" ในหน้าตารางเรียน (แอดมิน) ใช้ Backend ตัวเดียวกับแอปมือถือ
  (`/api/schedules/import/preview` และ `/commit`) ไม่ต้องแก้ Backend
- เลือกไฟล์หรือลากมาวาง → ดูจำนวนห้อง/คาบ ข้อสังเกต ห้องใหม่ที่จะสร้าง ห้องที่จะถูกแทนที่
  และตัวอย่างทุกแถว (กรองดูรายห้องได้) → บันทึกผลเป็น CSV ได้ → ยืนยันแล้วจึงบันทึก
- แทนที่ตารางเดิมเฉพาะห้องที่อยู่ในไฟล์ ทั้งชุดใน transaction เดียว ล้มเหลวแล้วตารางเดิมอยู่ครบ
- มีแบบฟอร์ม CSV ให้ดาวน์โหลด และบอกชัดเมื่อเลือกไฟล์ .xls รุ่นเก่าหรือไฟล์เกิน 8 MB
- ถ้ายังไม่มีตารางเรียนเลย หน้าตารางเรียนจะชี้ไปที่การนำเข้าแทนการแสดงการ์ดว่าง

## เปลี่ยนภาคเรียน

ปัญหาเดิม: นำเข้าไฟล์เทอมใหม่จะแทนที่เฉพาะห้องที่อยู่ในไฟล์ ห้องที่เทอมก่อนมีเรียนแต่เทอมนี้
ไม่มีชีตจะค้างตารางเก่า ระบบปิดแอร์อัตโนมัติจึงคิดว่ายังมีคาบ (รอ 15 นาทีแทน 5 และไม่แจ้งเตือน)

- นำเข้าแบบ **"เปลี่ยนภาคเรียน — ล้างตารางเดิมของทุกห้อง"** ได้ (`replaceAll: true` ใน
  `/api/schedules/import/commit`) ล้างและนำเข้าใน transaction เดียว
  หน้าเว็บถามให้เลือกเมื่อมีห้องที่มีตารางอยู่แต่ไม่อยู่ในไฟล์ และเลือกให้เองถ้าภาคเรียนในไฟล์ต่างจากในระบบ
- ระบบจำภาคเรียนของตารางที่ใช้อยู่ ผู้นำเข้า และเวลา (`system_settings.timetable_semester`)
  แสดงบนหน้าตารางเรียน และส่งมากับ `GET /api/schedules` ในช่อง `timetable`
- ปุ่ม **ดาวน์โหลด CSV** สำรองตารางที่ใช้อยู่ (นำกลับเข้ามาได้) และ **ล้างตารางทั้งหมด** บนเว็บ
  การล้างตารางไม่ลบข้อมูลไฟฟ้า ประวัติการแจ้งเตือน ห้อง หรืออุปกรณ์
- ชื่อเดือนย่อเป็น "ต.ค." "ส.ค." ตามแบบราชการ (เดิมตัดเป็น "ตุล." "สิง.")

## มือถือและแท็บเล็ต

- แถบเมนูล่าง 5 ปุ่ม แทนการกดปุ่มสามขีดทุกครั้ง แถบบนไม่ค้างกินพื้นที่จอ
- ปุ่ม ชิป และสวิตช์ใหญ่พอให้นิ้วกด, ช่องกรอกไม่ทำให้ iOS ซูมหน้าเอง
- ลิ้นชักรีโมตเต็มจอ หัวลิ้นชัก (ปุ่มปิด) ค้างไว้ด้านบน, กล่องโต้ตอบเลื่อนขึ้นจากด้านล่าง
- Building Pulse วางชื่อชั้นไว้บนแถว ช่องห้องจึงกว้างพอจะอ่านตัวเลข

## ใช้งานง่ายขึ้น

- หน้าห้อง: เปิดมาเห็น **ทุกชั้น** แบ่งหัวข้อตามชั้น มีช่องค้นหา และปุ่ม "เฉพาะห้องที่แอร์ทำงาน"
  การ์ดห้องที่ยังไม่ติดตั้งแอร์ถูกย่อให้เหลือแค่ชื่อ
- หน้าข้อมูลไฟฟ้า: ตารางเลื่อนในกรอบ หัวตาราง แถวรวม และคอลัมน์วันที่ค้างไว้, เส้นคั่นวันใหม่,
  หัวคอลัมน์ "วันที่ / ช่วงเวลา" เป็นภาษาไทย, เลือกห้อง/เครื่องเป็นชิปติ๊ก (ไม่ต้องกด Ctrl ค้าง)
  และตัวกรองไม่ถูกวาดใหม่ทุก 10 วินาทีจนช่องวันที่หลุดโฟกัส
- กราฟทุกตัว: ชี้เมาส์หรือแตะเพื่อดูค่าและวันเวลาของจุดนั้น ป้ายแกนไม่ซ้ำ/ไม่ทับกัน
- ตารางเรียน: ชื่อวันเต็ม มีจุดบอก "วันนี้" และแท็บ "ทุกชั้น" ที่แสดงเฉพาะห้องที่มีเรียน
- ภาพรวม: การ์ดตัวเลขกดไปหน้ารายละเอียดได้ การ์ดแจ้งเตือนมีปุ่ม "ดูทั้งหมด"

## แก้บั๊ก

- หน้าห้องพังเมื่อมีห้องกำลังนับถอยหลังปิดแอร์ (`Cannot access 'handle' before initialization`)
  การ์ดห้องหลังห้องนั้นไม่ขึ้นเลย
- การแจ้งเตือนแสดงรหัสดิบ `noScheduleAtAll` / `noClassNow` / `attempts=5` แทนข้อความไทย
- ลิ้นชักรีโมตค้างบังหน้าใหม่เมื่อเปลี่ยนหน้าด้วยปุ่มย้อนกลับของเบราว์เซอร์
- ตัวเลือก "แยกรายเครื่อง" ในหน้าข้อมูลไฟฟ้าหลุดขอบจอจนมองไม่เห็น

# Release 3.15.0 — เก็บข้อมูลไฟฟ้าตอนบอร์ดเน็ตหลุด

- เฟิร์มแวร์แอร์ 2.4.0 สรุปค่าไฟทุก 5 นาทีลง flash (พาร์ติชัน `rmuttlog` 64 KB
  เก็บได้ ~7 วัน) เมื่อต่อ MQTT ไม่ได้ ข้อมูลอยู่รอดข้ามการรีบูต ไฟดับ และการเปลี่ยน Wi-Fi
- ต่อได้แล้วรอแบบสุ่ม 5–45 วินาที ส่งทีละ 10 รายการทาง `rmutt/ac/<id>/history`
  รอ `history-ack` จาก Backend แล้วจึงลบรายการที่ยืนยันแล้วออกจาก flash และส่งชุดถัดไป
  ส่งครบแล้วลบ sector ที่ใช้ทั้งหมด
- Backend ใช้ "จุดต่อ" (`energy_chain_*`) ร่วมกันทั้งข้อมูลสดและย้อนหลัง
  ส่งซ้ำไม่นับซ้ำ และหยุดบันทึกข้อมูลสดระหว่างที่บอร์ดยังส่งย้อนหลังไม่ครบ
  (`historyPending` ใน status) พลังงานช่วงเน็ตหลุดจึงลงถูกชั่วโมง
- บัญชี MQTT ของบอร์ดได้สิทธิ์ `history` / `history-ack` เพิ่มอัตโนมัติ
- หน้าเว็บ "ห้องและอุปกรณ์" แสดงจำนวนรายการที่ยังค้างส่ง
- migration: `npm run db:migrate:history` (update-server.ps1 รันให้เอง)
- ทดสอบตัวเก็บข้อมูลบนคอมพิวเตอร์ได้: `firmware/tests/history_log_test.cpp`

# Release 3.14.0 — เตรียมใช้งานจริงบนเซิร์ฟเวอร์ของมหาวิทยาลัย

## ความปลอดภัย

- **บัญชี MQTT แยกรายบอร์ด** (Mosquitto Dynamic Security): บอร์ดแต่ละตัวใช้
  username = Device ID และเห็นเฉพาะ topic ของตัวเอง Backend สร้างบัญชีให้ตอนจองช่อง
  ลบให้ตอนถอดอุปกรณ์ และสร้างคืนเองทุกครั้งที่ต่อ Broker (`MQTT_DEVICE_AUTH=dynsec`)
  โหมดเดิม (`shared`) ยังใช้กับ Broker ทดสอบในโฟลเดอร์ `mqtt/` ได้เหมือนเดิม
- แก้ rate limit ของหน้า login หลัง Caddy (`TRUST_PROXY=1`): เดิมคนเดียวกรอกผิด
  10 ครั้งทำให้ทุกคนล็อกอินไม่ได้ 15 นาที
- Backend ใช้ user ฐานข้อมูลของตัวเอง (`DB_USER`) ไม่ใช้ root
- เว็บตั้ง Content-Security-Policy และหัวความปลอดภัย ย้ายสคริปต์ในหน้า
  `index.html`/`status.html` ไปเป็นไฟล์ `main.js`/`status.js`
- `APP_ORIGIN` เป็นโดเมนจริงแทน `*`, เพิ่ม `backend/.dockerignore`
- แอปมือถือจำเฉพาะชื่อผู้ใช้ ไม่เก็บรหัสผ่านลงเครื่องแล้ว (ลบของเดิมให้อัตโนมัติ)
- ตรวจ `SMTP_FROM` ต้องมีอีเมล ไม่งั้น OTP ส่งไม่ออกแบบเงียบ ๆ

## ความเสถียร

- ระบบปิดแอร์อัตโนมัติใช้ lock ของ MariaDB กันการยิงคำสั่งซ้ำเมื่อมี Backend มากกว่าหนึ่งตัว
- แก้สวิตช์ "ปิดอัตโนมัติ" รายเครื่องในเว็บที่แสดงเปิดเสมอ (API ไม่ได้ส่งค่าจริงกลับมา)
- สำรองฐานข้อมูลอัตโนมัติทุกวัน (`backup-db.sh`, เก็บ 14 วัน, ส่งนอกเครื่องได้)
- cron ก๊อปใบรับรอง HTTPS ให้ Mosquitto ทุกวัน (reload เฉพาะตอนใบเปลี่ยน)
- จำกัดขนาด log ของทุก container, healthcheck ของ Backend
- เฟิร์มแวร์มีใบรากทั้ง ISRG Root X1 และ X2 และแก้ `update-root-ca.ps1`
  ที่เขียนชื่อตัวแปรไม่ตรงกับเฟิร์มแวร์

## อัปเดตเฟิร์มแวร์ผ่าน Wi-Fi (OTA)

- เฟิร์มแวร์แอร์ 2.3.0 / เซ็นเซอร์ 1.3.0 รับคำสั่ง `ota` ทาง MQTT ดาวน์โหลดไฟล์
  ผ่าน HTTPS จาก `https://<โดเมนเดียวกับ MQTT>/firmware/` แล้วรีบูต
- เพิ่ม `partitions.csv` (แอปสองช่อง ช่องละ 1.9 MB) ต้องแฟลชผ่าน USB หนึ่งครั้ง
- บอร์ดรายงาน `firmwareVersion` / `otaError` ใน status เก็บลงคอลัมน์ใหม่
  (`npm run db:migrate:firmware`) และแสดงในเว็บ หน้า "ห้องและอุปกรณ์"
- API ใหม่: `GET /api/firmware`, `POST /api/air-conditioners/:id/ota`,
  `POST /api/occupancy-sensors/:id/ota`

## การ deploy

- สคริปต์ PowerShell อ่านที่อยู่เซิร์ฟเวอร์จาก `deploy/server.config.json`
  (ไม่ commit) แทน IP ที่เขียนไว้ในโค้ด รองรับ user ที่ไม่ใช่ root และพอร์ต SSH อื่น
- `setup-vps.sh` ไม่ยุ่ง firewall โดยค่าเริ่มต้น (ใช้ `--firewall` ถ้าต้องการ)
- เซ็น APK ด้วยกุญแจของโปรเจกต์ (`create-keystore.ps1` + `android/key.properties`)
- เอกสาร `deploy/DEPLOY.md` และ `deploy/SERVER_REQUIREMENTS.md`

# Release 3.6.0+23

## Per-room ESP32 + HLK-LD2410 occupancy sensor

- Added a separate occupancy ESP32 for each room with BLE setup and normal
  reporting over Wi-Fi/MQTT.
- Firmware 1.0.0 automatically enables LD2410 Engineering mode after every
  boot and reads only stationary/static energy for gates 0 through 8.
- A room is occupied when at least one gate is strictly greater than 25;
  values at or below 25 mean vacant. Moving data, distances, and all other
  radar measurements are ignored and are not sent to the app.
- Added Admin setup, reconfiguration, and removal for the room sensor.
- Room cards and the room-control screen refresh occupancy every 10 seconds
  and distinguish sensor/radar unavailable from a genuinely vacant room.
- Added the `occupancy_sensors` database table, MQTT topics under
  `rmutt/occupancy`, and `npm run db:migrate:occupancy` migration.

# Release 3.5.0+22

## PZEM-004T measured status and board LEDs

- Firmware 2.0.0 reads one PZEM-004T v3/v4 on HardwareSerial and publishes
  voltage, current, power, cumulative energy, frequency, and power factor.
- Air-conditioner running status now comes from measured power with hysteresis
  and three-sample confirmation instead of assuming an IR command succeeded.
- Green indicates measured operation. Red turns on in addition to green when
  measured operation is outside the room's class timetable.
- Yellow flashes while Wi-Fi connects and stays on after Wi-Fi is connected.
- Backend evaluates class schedules in Asia/Bangkok and sends a retained
  `schedule-status` result to each ESP32; rooms without a class timetable fall
  back to the device's daily automatic schedule.
- Flutter shows measured running status, outside-schedule warnings, live PZEM
  values, kWh/Hz/power factor, and refreshes telemetry every 10 seconds.
- Added the `npm run db:migrate:pzem` database migration.

# Release 3.4.1+21

## Saijo Denki Turbo correction

- Corrected the strongest fifth Saijo fan capture from `Level 4` to `Turbo`.
- The Flutter fan selector now shows Auto, levels 1-3, and Turbo.
- MQTT continues to use `fanSpeed: turbo`, and Firmware 1.8.1 sends the
  verified strongest 72-bit frame without changing the protocol payload.
- Renamed the local repeat and duty-cycle constants to avoid collisions with
  IRremoteESP8266 during Arduino compilation.

# Release 3.4.0+20

## Additional verified Saijo Denki captures

- Firmware 1.8.0 adds the complete 72-bit Cool, Dry, and Fan-mode frames from
  `saijo.txt`; the isolated 1-bit UNKNOWN entry is treated as receiver noise.
- Replaced the provisional fan and swing frames with the new ordered captures:
  Fan Auto plus levels 1–3 and strongest state, and Swing Auto plus five fixed
  positions.
- Flutter and Backend now expose exactly those additional Saijo controls while
  preserving the existing 18–29 °C range and hiding unrelated extra features.
- The strongest Saijo fan frame is represented as `turbo` on MQTT.
- Existing IRac brands, BLE provisioning, server-managed MQTT settings, rooms,
  and schedules are unchanged.

# Release 3.3.9+19

## Saijo Denki custom infrared support

- Added `Saijo Denki` to the brand/protocol selector using `SAIJO_DENKI`.
- Backend reservation and MQTT validation now recognize the custom protocol.
- Firmware 1.7.0 routes Saijo commands through the bundled 72-bit sender while
  all existing brands continue through the IRremoteESP8266 `IRac` interface.
- Added the verified Saijo range: Power, Cool, 18–29 °C, Fan Auto/1/2/3, and
  Swing Auto/positions 1–5.
- The Flutter controls hide unsupported Saijo modes and extra functions and
  use the correct 18–29 °C bounds.
- Dry remains unavailable because its captured frame is incomplete.

# Release 3.3.8+18

## Server-managed MQTT provisioning

- Removed MQTT Host, Port, Username, and Password from the BLE setup form.
- Admins select a Wi-Fi network detected by the ESP32 and type only its
  Wi-Fi password.
- The Backend is now the single source of truth for MQTT connection settings.
- The authenticated reservation response supplies the same MQTT URL and
  credentials already configured in `backend/.env` to the selected ESP32.
- MQTT secrets are not embedded in the Flutter source or displayed in the UI.
- Existing room/unit uniqueness, Device ID checks, schedules, BLE GATT flow,
  and firmware 1.6.0 remain compatible; no database migration or reflash is
  required.

# Release 3.3.7+17

## Windows BLE GATT sequencing fix

- Windows BLE waits for WinRT's internal GATT work in `connect()` before
  calling `discoverServices()`.
- Service discovery retries reuse one live connection instead of rapidly
  disconnecting and reconnecting the ESP32.
- Windows BLE is pinned to `flutter_blue_plus_winrt 0.0.20`.
- Failures include the actual connection/discovery stage and native error.
- ESP32 firmware remains 1.6.0; no reflash is required for this app fix.

# Release 3.3.6+16

## Windows BLE second-device fix

- Fixed the silent screen state where selecting an ESP32 failed before an
  identity was available and the error message was hidden.
- Added a visible connection status, error card, and one-tap retry action.
- Windows connections now wait on `connectionState`, retry GATT discovery up
  to three times, and stop scanning before every connection.
- Firmware 1.6.0 exposes a compact core identity value and moves optional saved
  settings to a separate characteristic, avoiding long first-read timeouts.
- The form scrolls into view automatically after the ESP32 is verified.
- Device ID, room/unit uniqueness, NVS, MQTT, timetable, and IR behavior are
  unchanged.

# Release 3.3.5+15

## Automatic room creation during timetable import

- Timetable preview now keeps valid room sheets even when the room list is
  empty.
- New rooms are shown separately and require Admin confirmation before they
  are created.
- Building 16 room codes such as `16203` automatically use floor 2 and display
  order 3.
- Special room codes such as `CL503` automatically use the Special group
  (floor 0).
- Room creation, schedule replacement, and schedule inserts run in one
  database transaction.
- The Flutter room list refreshes immediately after rooms are created.

# Release 3.3.4+14

## Clear all class schedules

- Added an Admin-only clear-all action with a destructive confirmation dialog.
- The API deletes only class schedules and returns the number of deleted rows.
- Rooms, air conditioners, users, MQTT settings, and ESP32 settings are
  preserved.

# Release 3.3.3+13

## Current-day timetable update

- The room timetable now selects the device's current weekday when it first
  opens instead of always starting on Monday.
- The green header shows `Today` with the real calendar date.
- Selecting another weekday changes the header to `Selected date` and shows
  that day's date in the current week.
- Thai dates use Thai weekday/month abbreviations and the Buddhist year.
- Added regression checks for all Sunday-through-Saturday date mappings and
  the initially selected current-day chip.

# Release 3.3.2+12

## Weekday and visual consistency update

- Replaced the horizontally clipped timetable day chips with a responsive
  seven-day selector, so Sunday through Saturday are always visible.
- Applied the same seven-day selector to the timetable overview and Admin
  schedule manager.
- Matched the control-screen header to the green headers used elsewhere while
  keeping the Admin settings action at the top-right.
- Refined the light and dark palettes around one RMUTT emerald color family.
- Removed unnecessary orange/blue accents from primary schedule and room
  controls.
- Added widget regression checks for Saturday visibility and header styling.

# Release 3.3.1+11

## Control screen redesign

- Replaced the overlapping control-screen header with a responsive row.
- Moved the Admin room-management action to a dedicated settings button at
  the top-right.
- Refined the floor selector, room count, empty state, and room cards.
- Preserved room CRUD, special rooms such as CL503, schedules, instructor
  display, BLE provisioning, MQTT behavior, themes, and language switching.
- Added a widget regression check for header spacing and settings placement.

# Release 3.3.0+10

## Room management and instructors

- Added a database-backed room list and Admin room management screen.
- Added support for special room codes such as `CL503`.
- Added safe room deletion checks for linked schedules and air conditioners.
- Added separate timetable fields for section and instructor.
- Instructor names now appear in timetable cards, Admin management, and import
  previews.
- Excel import now accepts sheets for rooms registered by Admin.
- Added the v1.8.0 migration and special-room-compatible ESP32 firmware.

# Release 3.1.0+8

## MQTT completion

- Added a runnable Eclipse Mosquitto 2 broker with Docker Compose.
- Added generated password authentication and topic ACLs.
- Added Windows setup, start, stop, and publish/subscribe test scripts.
- MQTT setup now writes matching values to `backend/.env`.
- Backend health reports broker connection state without exposing credentials.
- Backend can require MQTT configuration with `MQTT_REQUIRED=true`.
- BLE provisioning now requires MQTT Username and Password.
- Backend validates MQTT Host, Port, and Username before reserving an ESP32.
- Added `check_system.ps1` for MariaDB, Backend, and MQTT verification.
- Added `START_HERE.md` and a complete `backend/.env.example`.

## Preserved features

- Flutter Thai/English UI and Dark Mode.
- Remembered username/password setting.
- Electricity-rate calculation.
- Admin room timetable management with the Dart time-comparison fix.
- Admin BLE provisioning with duplicate Device ID and room/air checks.
- MQTT air-conditioner control and ESP32 IRremoteESP8266 firmware.
