# 02 · Backend (Node.js + Express 5)

โค้ดอยู่ที่ `backend/src/` รันด้วย Node.js 20+ เป็น **ESM** (`import`/`export`)
ไม่ใช่ CommonJS

---

## 1. การแบ่งชั้น และเหตุผล

```
src/
├── server.js       จุดเริ่ม เปิดพอร์ต เริ่มงานเบื้องหลัง
├── app.js          ประกอบ Express ต่อ middleware และ router
├── config.js       อ่านค่าจาก .env ที่เดียว
├── db.js           connection pool ของ MariaDB
├── middleware/     ตรวจ token ตรวจสิทธิ์
├── routes/         เส้นทาง HTTP
├── services/       งานที่คุยกับโลกภายนอก
└── utils/          ฟังก์ชันบริสุทธิ์
```

### กฎเหล็กข้อเดียวที่ทำให้ทุกอย่างง่ายขึ้น

> **ตรรกะที่ตัดสินใจ ต้องอยู่ใน `utils/` และห้ามแตะฐานข้อมูลหรือเครือข่าย**

ทำไมถึงสำคัญ — ลองดูตัวอย่างจริง การตัดสินใจว่าจะปิดแอร์หรือยังมีกรณีต้องคิด
อย่างน้อย 10 แบบ (ไม่มีเซ็นเซอร์ · เซ็นเซอร์ออฟไลน์ · PZEM เสีย · มีคน ·
แอร์ไม่ทำงาน · เพิ่งเริ่มนับ · กำลังนับ · ครบกำหนด · ยิงไปแล้วรอผล · ยิงครบแล้ว)

ถ้าตรรกะนี้ฝังอยู่ในฟังก์ชันที่ต้อง `SELECT` ก่อน การทดสอบทุกกรณีต้องเตรียม
ข้อมูลในฐานข้อมูลจริง 10 ชุด ซึ่งช้า เปราะ และคนเขียนจะยอมแพ้ก่อนเทสต์ครบ

พอแยกเป็น `decideAutoOff({device, occupancy, withinClass, now})` ที่รับ object
เข้าไปเฉย ๆ การทดสอบกลายเป็นการเรียกฟังก์ชัน 10 ครั้งด้วยค่าต่างกัน
ใช้เวลาเป็นมิลลิวินาที **เทสต์ทั้ง 136 เคสของ Backend รันจบในไม่กี่วินาที
โดยไม่ต้องมี MariaDB หรือ MQTT เลย** (นับ 14 ต.ค. 2569)

---

## 2. `config.js` — อ่าน `.env` ที่เดียว

```js
export const config = {
  env: process.env.NODE_ENV ?? 'development',
  port: numberFromEnv('PORT', 3000),
  db: { host, port, user, password, database, connectionLimit },
  jwtSecret: process.env.JWT_SECRET ?? '',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '8h',
  otpPepper: process.env.OTP_PEPPER ?? '',
  mail: { mode, host, port, secure, user, pass, from },
  mqtt: { required, url, deviceUrl, username, password,
          topicPrefix, occupancyTopicPrefix },
};
```

**ทำไมต้องรวมไว้ที่เดียว** — ถ้าไฟล์ไหนอยากรู้ค่าก็เรียก `process.env` เอง
จะเกิดปัญหาสามข้อ

1. ไม่มีที่ไหนบอกได้ว่าระบบต้องการตัวแปรอะไรบ้าง ต้องไล่ grep ทั้งโปรเจกต์
2. ค่าเริ่มต้นกระจัดกระจาย บางไฟล์ default เป็น `3000` บางไฟล์ `8080`
3. `process.env` คืนค่าเป็น **ข้อความเสมอ** ต้องแปลงเป็นตัวเลขทุกที่ที่ใช้

`numberFromEnv()` และ `booleanFromEnv()` จัดการข้อ 3 ให้ครั้งเดียว

### `assertServerConfig()` — ล้มตั้งแต่ตอนเปิด ดีกว่าพังตอนใช้งาน

```js
function unsafeSecret(value) {
  return value.length < 32 || /replace|change|example/i.test(value);
}
```

ฟังก์ชันนี้ถูกเรียกตอน `server.js` เริ่มทำงาน ถ้า `JWT_SECRET` สั้นกว่า 32 ตัว
หรือยังเป็นค่าตัวอย่างที่มีคำว่า `replace` / `change` / `example`
**เซิร์ฟเวอร์จะไม่ยอมเปิดเลย**

ที่ทำแบบนี้เพราะความผิดพลาดแบบนี้ **ไม่แสดงอาการ** ระบบที่ใช้ JWT secret ว่าง ๆ
ยังทำงานได้ปกติทุกอย่าง แค่ใครก็ปลอม token ได้ ถ้าไม่ดักตั้งแต่เปิด
จะไม่มีใครรู้จนกว่าจะโดนเข้าจริง

### `mqtt.url` กับ `mqtt.deviceUrl` ต่างกันอย่างไร

```js
url:       process.env.MQTT_URL,        // Backend ใช้ต่อเอง
deviceUrl: process.env.MQTT_DEVICE_URL ?? process.env.MQTT_URL,
```

- Backend อยู่ใน Docker เดียวกับ Broker ต่อผ่านชื่อ service
  `mqtt://mqtt:1883` ได้เลย ไม่ต้องออกอินเทอร์เน็ต
- ESP32 อยู่ในอาคาร ต้องเข้ามาจากข้างนอกด้วย `mqtts://`
  (อัปเดต 14 ต.ค. 2569) ตั้งแต่ 5 ต.ค. `deploy/docker-compose.yml` ตั้งค่าเริ่มต้นเป็น
  `mqtts://rmutt-energy.tailb292b4.ts.net:8443` (Tailscale Funnel เข้าได้จากทุกเครือข่าย)
  เดิมคือ `mqtts://rmutt-energy.duckdns.org:8883` ซึ่งยังใช้ได้ถ้าตั้ง `MQTT_DEVICE_URL` ใน `.env`

ถ้ามีตัวแปรเดียว จะต้องเลือกอย่างใดอย่างหนึ่ง ซึ่งทำให้อีกฝั่งใช้ไม่ได้
`?? MQTT_URL` ทำให้ตอนพัฒนาในเครื่องเดียวไม่ต้องตั้งสองค่า

---

## 3. `db.js` — connection pool แบบขี้เกียจ

pool คือ **กลุ่มการเชื่อมต่อที่เปิดค้างไว้แล้วหมุนเวียนใช้** เพราะการเปิด
การเชื่อมต่อใหม่ทุกคำขอช้ามาก (ต้อง handshake + ยืนยันตัวตน)

`DB_CONNECTION_LIMIT` เริ่มต้นที่ 5 ซึ่งดูน้อยแต่พอ เพราะคำขอส่วนใหญ่ใช้
การเชื่อมต่อไม่ถึงมิลลิวินาที การตั้งสูงเกินไปจะกินหน่วยความจำฝั่ง MariaDB
โดยไม่ได้ประโยชน์

**"ขี้เกียจ" (lazy)** หมายถึง pool จะยังไม่ต่อจริงจนกว่าจะมีคนใช้ครั้งแรก
จำเป็นสำหรับเทสต์ — ไฟล์เทสต์ที่ `import` โค้ดซึ่ง `import` `db.js` ต่อ ๆ กันมา
จะไม่พยายามต่อฐานข้อมูลที่ไม่มีอยู่

---

## 4. `middleware/` — ด่านตรวจ

### `authenticate.js`

ทำสามอย่างเรียงกัน

1. อ่าน `Authorization: Bearer <token>`
2. ตรวจลายเซ็นด้วย `JWT_SECRET` และวันหมดอายุ
3. **ไปอ่าน `users` จริงเพื่อเทียบ `token_version` และ `is_active`**

ข้อ 3 คือจุดที่คนมักข้าม เพราะ "ก็ตรวจลายเซ็นแล้วนี่"

ปัญหาคือ JWT เป็น **stateless** ข้อมูลข้างในถูกแช่แข็งไว้ตั้งแต่ตอนออก token
ถ้าถอดสิทธิ์คนหนึ่งจาก admin เป็น staff token เดิมยังบอกว่าเขาเป็น admin
อยู่อีก 8 ชั่วโมง การอ่านฐานข้อมูลทุกคำขอแลกความเร็วนิดหน่อยกับความถูกต้อง
ซึ่งคุ้มในระบบที่มีผู้ใช้หลักสิบคน

### `require-admin.js`

```js
export function requireAdmin(request, response, next) {
  if (request.authUser?.role !== 'admin') { /* 403 */ }
  next();
}
```

สั้นมากโดยตั้งใจ ใช้ต่อท้าย `authenticate` เช่น

```js
usersRouter.use(requireAdmin);                    // ทั้ง router
settingsRouter.patch('/auto-off', requireAdmin, handler);  // เฉพาะเส้นทาง
```

**ทำไมแยกเป็นสอง middleware ไม่รวมเป็นตัวเดียว** — เพราะบางเส้นทางต้องการแค่
"ล็อกอินแล้ว" ไม่ต้องเป็นแอดมิน เช่น `GET /api/settings` ที่ให้ทุกคนอ่านสถานะได้
แต่แก้ไม่ได้ ถ้ารวมกันจะต้องมีพารามิเตอร์บอกระดับ ซึ่งอ่านยากกว่า

---

## 5. `routes/` — เส้นทาง HTTP

| ไฟล์ | ขนาด | ดูแลอะไร |
|---|---|---|
| `auth.js` | 12 KB | login, ลืมรหัสผ่าน 4 ขั้น, แก้โปรไฟล์ตัวเอง |
| `rooms.js` | 7.5 KB | รายการห้อง + สถานะรวมของห้อง |
| `schedules.js` | 11 KB | ตารางเรียน + นำเข้า Excel + ปฏิทินภาคเรียน (`/terms`) |
| `bookings.js` | 5.2 KB | การใช้ห้องนอกตารางเรียน (อัปเดต 14 ต.ค. 2569) |
| `firmware.js` | 7.2 KB | รายการ/อัปโหลด/ลบไฟล์เฟิร์มแวร์ `.bin` จากหน้าเว็บ (แอดมิน, อัปเดต 14 ต.ค. 2569) |
| `air-conditioners.js` | 12 KB | จอง/ยืนยัน/สั่งงาน/นำออก แอร์ |
| `occupancy-sensors.js` | 8 KB | เหมือนกันสำหรับเซ็นเซอร์ |
| `energy.js` | 18 KB | ค่าไฟสด สรุป ประวัติ ส่งออก Excel |
| `alerts.js` | 3 KB | รายการแจ้งเตือน + รับทราบ |
| `users.js` | 5.7 KB | จัดการผู้ใช้ (แอดมินเท่านั้น) |
| `settings.js` | 1.6 KB | ค่าตั้งระดับระบบ |
| `public.js` | 1 KB | ข้อมูลติดต่อแอดมิน ไม่ต้องล็อกอิน |

### `utils/http.js` — `asyncHandler` และ `ApiError`

```js
asyncHandler(async (request, response) => { ... })
```

Express 4 **ไม่จับ error จาก async function** ถ้าโยน error ข้างในจะกลายเป็น
unhandled rejection และคำขอนั้นจะค้างจนหมดเวลา `asyncHandler` ครอบให้
แล้วส่งต่อไป error handler

Express 5 จับให้เองแล้ว แต่ยังคง `asyncHandler` ไว้เพราะ **อ่านแล้วรู้ทันที
ว่าเส้นทางนี้เป็น async** และย้ายกลับได้ถ้าต้อง

`ApiError(status, message)` ทำให้โยน error พร้อมรหัส HTTP ได้จากที่ไหนก็ได้
โดยไม่ต้องส่ง `response` ลงไปทุกชั้น

```js
throw new ApiError(400, 'ต้องส่ง enabled เป็น true หรือ false');
```

**ข้อความ error เป็นภาษาไทย** เพราะแอปมี `_englishTranslations`
(ไทย → อังกฤษ) ที่แปลกลับให้เมื่อผู้ใช้เลือกอังกฤษ วิธีนี้ทำให้ Backend
ไม่ต้องรู้จักภาษาของผู้ใช้

---

## 6. `services/` — งานที่คุยกับโลกภายนอก

### `mqtt.js` (16 KB) — สะพานหลักของระบบ

หน้าที่

1. ต่อ Broker และ subscribe ทุกหัวข้อของอุปกรณ์
2. รับ `status` → อัปเดต `air_conditioners` / `occupancy_sensors`
3. รับ `provision` → ตรวจ token → เปลี่ยนสถานะเป็น `active` → ส่ง ack
4. ส่ง `command` เมื่อแอปสั่งงาน
5. ส่ง `schedule-status` แบบ retained บอกบอร์ดว่าตอนนี้มีคาบเรียนไหม
6. ล้าง retained message ทั้งหมดเมื่อนำอุปกรณ์ออก
7. (อัปเดต 14 ต.ค. 2569) `unprovisionDevice()` ส่งคำสั่งให้บอร์ดล้างค่าในตัวเองก่อนลบบัญชี MQTT
   แล้วรอคำตอบไม่เกิน 4 วินาที (ดู `05-mqtt-ble.md`)
8. บอร์ดสายแอร์ส่ง `controlMode: "wired"` ใน status ถ้าฐานข้อมูลยังเป็นยี่ห้อ IR
   จะแก้ `protocol` เป็น `DAIKIN_WIRED` ให้เอง (`utils/air-conditioner.js`)

**ลำดับที่สำคัญมากในข้อ 2**

```js
// อ่านค่าเดิมก่อน
const previous = await readCurrentRow(deviceId);
// แล้วค่อยเขียนทับ
await updateRow(deviceId, status);
// แล้วค่อยบันทึกประวัติโดยใช้ค่าเดิมหาผลต่าง
await recordEnergySample({ previous, status, ... });
```

ถ้าสลับลำดับ ค่าเดิมจะหายไปก่อนได้ใช้ ผลคือหาผลต่างของเลขมิเตอร์ไม่ได้
และ `consumption_kwh` จะกลายเป็นเลขสะสมทั้งหมดตั้งแต่ติดตั้ง

### รูปแบบ listener hook — แก้ปัญหา import วนกัน

```js
// mqtt.js
export function onAirStatus(listener) { ... }
export function onOccupancyStatus(listener) { ... }

// auto-off.js
import { onAirStatus, onOccupancyStatus } from './mqtt.js';
onAirStatus(({ deviceId }) => runEvaluation(deviceId));
```

**ปัญหาที่แก้** — `auto-off.js` ต้องรู้เมื่อมีสถานะใหม่เข้ามา และต้องสั่ง
`publishAirCommand()` ด้วย ถ้า `mqtt.js` เรียก `auto-off.js` ตรง ๆ จะกลายเป็น
สองไฟล์ import กันไปมา (circular import) ซึ่งใน ESM ทำให้ไฟล์หนึ่งได้ค่า
`undefined` ตอนโหลด แล้วพังแบบหาสาเหตุยากมาก

วิธีแก้คือทำให้ **การพึ่งพาเป็นทางเดียว** `auto-off.js → mqtt.js`
โดย `mqtt.js` ไม่รู้จัก `auto-off.js` เลย แค่เปิดช่องให้ใครมาลงทะเบียนฟัง

### `auto-off.js` (11.7 KB) — ตัวคุมจังหวะ

ถูกกระตุ้นสามทาง

| ทาง | ทำไมต้องมี |
|---|---|
| `onAirStatus` | แอร์เพิ่งเปิด/ปิด ต้องประเมินใหม่ทันที |
| `onOccupancyStatus` | คนเพิ่งเข้า/ออก ต้องยกเลิกหรือเริ่มนับทันที |
| `setInterval` 10 วินาที | **ถ้าอุปกรณ์เงียบไปเฉย ๆ ก็ยังต้องยิงเมื่อครบกำหนด** |

ข้อสามสำคัญที่สุด — ถ้าพึ่งแต่เหตุการณ์ ห้องที่ไม่มีอะไรเปลี่ยนเลย
(แอร์เปิดค้าง ไม่มีคน สถานะเดิมทุกครั้ง) จะไม่มีใครมาตรวจว่าครบ 5 นาทีแล้ว

```js
timer = setInterval(() => runEvaluation(), TICK_INTERVAL_MS);
if (typeof timer.unref === 'function') timer.unref();
```

**`unref()` สำคัญสำหรับเทสต์** — บอก Node ว่า timer นี้ไม่ต้องนับเป็นเหตุผล
ที่ต้องรันต่อ ถ้าไม่มี `node --test` จะค้างไม่จบเพราะมี timer เดินอยู่ตลอด

```js
let running = false;
export async function evaluateAutoOff(...) {
  if (running) return [];
  running = true;
  try { ... } finally { running = false; }
}
```

**ธงกันทำงานซ้อน** — สามทางข้างบนอาจกระตุ้นพร้อมกัน ถ้าปล่อยให้ทำงานซ้อน
รอบหนึ่งอาจยิงคำสั่งปิดสองครั้งซ้อน หรือเพิ่ม `auto_off_attempts` สองเด้ง

### `alerts.js` — กันสร้างใบซ้ำ

```js
export const ALERT_KINDS = {
  OUTSIDE_SCHEDULE_OCCUPIED: 'outside_schedule_occupied',
  AUTO_OFF_SUCCEEDED: 'auto_off_succeeded',
  AUTO_OFF_FAILED: 'auto_off_failed',
};
```

`raiseAlert()` จะเช็คก่อนว่ามีใบ `open` ของ (ชนิด, ห้อง, อุปกรณ์) เดียวกัน
ค้างอยู่ไหม ถ้ามีก็ไม่สร้างใหม่

การเทียบ `device_id` ใช้ `(device_id <=> ?)` ไม่ใช่ `=`

> **`<=>` คือ null-safe equality ของ MySQL/MariaDB**
> `NULL = NULL` ให้ผลเป็น `NULL` (ไม่ใช่ `TRUE`) ตามมาตรฐาน SQL
> แต่ `NULL <=> NULL` ให้ `TRUE`
>
> จำเป็นเพราะแจ้งเตือนบางชนิดเป็นของทั้งห้อง `device_id` จึงเป็น `NULL`
> ถ้าใช้ `=` จะหาใบเดิมไม่เจอ แล้วสร้างใหม่ทุก 10 วินาที

### `energy-recorder.js` — UPSERT ก้อนเดียว

อธิบายละเอียดใน `07-energy-export.md` ขอเน้นแค่แนวคิด

```sql
INSERT INTO energy_hourly (...) VALUES (...)
ON DUPLICATE KEY UPDATE
  sample_count = sample_count + VALUES(sample_count),
  voltage_sum  = voltage_sum + VALUES(voltage_sum),
  voltage_min  = LEAST(COALESCE(voltage_min, VALUES(voltage_min)),
                       COALESCE(VALUES(voltage_min), voltage_min)),
  ...
```

**ทำไมต้องเป็นคำสั่งเดียว** — ถ้าเขียนเป็น `SELECT` แล้วค่อยตัดสินใจ
`INSERT` หรือ `UPDATE` จะเกิด race condition ทันทีที่มีข้อความสองอันของ
เครื่องเดียวกันเข้ามาพร้อมกัน ทั้งคู่เห็นว่า "ยังไม่มีแถว" แล้วต่างก็ `INSERT`
ตัวที่สองจะชนคีย์และ error หรือแย่กว่าคือข้อมูลหายไปหนึ่งรอบ

**`LEAST` + `COALESCE` ทำไมต้องซ้อนกัน** — `LEAST(NULL, 5)` ให้ `NULL`
ไม่ใช่ `5` ซึ่งจะทำให้ค่าต่ำสุดหายทันทีที่มีรอบใดรอบหนึ่งอ่านค่าไม่ได้
`COALESCE` แทนค่า `NULL` ด้วยอีกฝั่งก่อน จึงได้ค่าที่ถูกต้องเสมอ

### `mailer.js`

ส่ง OTP ผ่าน SMTP มี `MAIL_MODE` ให้สลับเป็นโหมดพิมพ์ลง console ตอนพัฒนา
จะได้ไม่ต้องตั้ง SMTP จริงเพื่อทดสอบการกู้รหัสผ่าน

---

## 7. `utils/` — ฟังก์ชันบริสุทธิ์

| ไฟล์ | ขนาด | ตรรกะอะไร |
|---|---|---|
| `energy-history.js` | 24 KB | แคตตาล็อกค่าที่เลือกได้ · ตัดถังรายชั่วโมง · ประกอบ SQL |
| `schedule-import.js` | 18 KB | แกะตารางเรียนจาก Excel |
| `xlsx-reader.js` | 8.9 KB | อ่าน .xlsx เอง |
| `xlsx-writer.js` | 7.8 KB | เขียน .xlsx เอง |
| `air-conditioner.js` | 8.1 KB | ตรวจค่าและแปลงแถวเป็น JSON สาธารณะ |
| `auto-off.js` | 6.4 KB | ตัดสินใจปิดแอร์ |
| `user.js` | 4.7 KB | `publicUser()` และตรวจข้อมูลโปรไฟล์ |
| `room.js` | 4.4 KB | รวมสถานะของห้อง |
| `schema-doctor.js` | 3 KB | เทียบโครงฐานข้อมูลกับ `schema.sql` |
| `class-schedule.js` | 2.2 KB | ตอนนี้มีคาบเรียนไหม + สถานะภาคเรียน (`termStatus`) |
| `security.js` | 0.8 KB | OTP, HMAC, เทียบ hash แบบปลอดภัย |
| `room-booking.js` | 7.8 KB | ตรวจการจองห้อง การทำซ้ำ `withBookings()` (อัปเดต 14 ต.ค. 2569) |
| `firmware.js` | 5.9 KB | ชื่อไฟล์ → ชนิดบอร์ด (`occ` = เซ็นเซอร์, `wired`/`slm8` = สายแอร์, นอกนั้น = แอร์ IR) และรุ่น |
| `unprovision.js` | 2.2 KB | คำสั่ง `unprovision` และตรวจคำตอบของบอร์ด |

(ขนาดไฟล์ในตารางนี้เป็นค่าตอนเขียนครั้งแรก ไฟล์เดิมหลายไฟล์โตขึ้นแล้ว)

บอร์ดสายแอร์ใช้ `protocol = 'DAIKIN_WIRED'` และ `utils/air-conditioner.js`
ปฏิเสธคำสั่งที่แอร์รับทางสายไม่ได้ (โหมด Auto/Heat, พัดลม Turbo, Eco/Turbo/Quiet/Clean,
ส่ายแนวนอน, Sleep ในโหมด Dry) API ส่ง `controlType: "wired" | "ir"` มากับแอร์ทุกเครื่อง

### `publicUser()` — ด่านกันข้อมูลรั่ว

```js
export function publicUser(row) {
  return {
    username, firstName, lastName, email, phone, role
    // ไม่มี id, password_hash, token_version
  };
}
```

**ทุกเส้นทางที่คืนข้อมูลผู้ใช้ต้องผ่านฟังก์ชันนี้** ถ้าปล่อยให้แต่ละที่เลือก
ฟิลด์เอง วันหนึ่งจะมีที่ที่เผลอส่ง `password_hash` ออกไป และไม่มีใครสังเกต

มีเทสต์ยืนยันว่า `'id' in result === false` ซึ่งดูเหมือนเทสต์ที่ไร้สาระ
แต่มันจะจับได้ทันทีถ้ามีคนเผลอเพิ่ม `id` กลับเข้าไป

### `security.js` — `safeHashEquals()`

```js
export function safeHashEquals(leftHash, rightHash) {
  const left = Buffer.from(leftHash, 'hex');
  const right = Buffer.from(rightHash, 'hex');
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}
```

**ทำไมไม่ใช้ `===`**

การเทียบข้อความด้วย `===` จะ **หยุดทันทีที่เจอตัวอักษรต่างกัน**
แปลว่าถ้าตัวแรกผิด จะเร็วกว่าตอนที่ 30 ตัวแรกถูก คนที่วัดเวลาตอบกลับ
อย่างละเอียดสามารถเดา hash ทีละตัวได้ (timing attack)

`timingSafeEqual` เทียบครบทุกไบต์เสมอ ใช้เวลาเท่ากันไม่ว่าจะต่างตรงไหน

ในทางปฏิบัติการโจมตีแบบนี้ทำได้ยากผ่านอินเทอร์เน็ต แต่ต้นทุนการใช้ฟังก์ชัน
ที่ถูกต้องแทบเป็นศูนย์ จึงไม่มีเหตุผลที่จะไม่ใช้

### `isValidNewPassword()` — ทำไมจำกัด 72 ไบต์

```js
password.length >= 8 && Buffer.byteLength(password, 'utf8') <= 72
```

**bcrypt ตัดที่ 72 ไบต์** ตัวที่ 73 เป็นต้นไปถูกทิ้งเงียบ ๆ
ถ้าไม่ดัก ผู้ใช้ที่ตั้งรหัสยาว 100 ตัวอักษรจะคิดว่าปลอดภัยมาก
แต่จริง ๆ แล้วแค่ 72 ตัวแรกที่มีผล

สังเกตว่าเช็ค **ไบต์** ไม่ใช่ **ตัวอักษร** เพราะภาษาไทยหนึ่งตัวกิน 3 ไบต์
รหัสผ่านไทย 24 ตัวอักษรก็ชน 72 ไบต์แล้ว

---

## 8. `scripts/` — เครื่องมือดูแล

| สคริปต์ | ใช้ตอนไหน |
|---|---|
| `init-db.js` | ติดตั้งใหม่ รัน `schema.sql` |
| `seed-admin.js` | สร้างแอดมินคนแรก |
| `migrate-*.js` (12 ตัว) | อัปเกรดฐานข้อมูลที่มีข้อมูลแล้ว |
| `doctor.js` | เทียบโครงจริงกับ `schema.sql` และเติมด้วย `--fix` |
| `convert-schedule-file.js` | แปลงไฟล์ตารางเรียนนอกระบบ |

**ทุก migration ต้องรันซ้ำได้** ใช้ `CREATE TABLE IF NOT EXISTS`,
`INSERT IGNORE`, และเช็คก่อนว่าคอลัมน์มีอยู่แล้วหรือยัง

เหตุผลคือสคริปต์อัปเดตเซิร์ฟเวอร์ (`deploy/update-remote.sh`) รัน migration
**ทุกตัวทุกครั้ง** โดยไม่จำว่าเคยรันอะไรไปแล้ว ซึ่งง่ายกว่าการทำระบบ
version tracking และปลอดภัยกว่าการให้คนจำเอง

---

## 9. การทดสอบ

```powershell
cd backend
npm test          # node --test
```

**21 ไฟล์ · 136 เคส** (นับ 14 ต.ค. 2569) ครอบคลุม auth, room, schedule, import, mqtt, pzem,
occupancy, security, user-management, energy-history, xlsx-writer, auto-off,
schema-doctor, room-booking, firmware, unprovision, air-conditioner (สายแอร์ Daikin),
mqtt-accounts, offline-history

GitHub Actions ยังไม่ได้รันเทสต์ Backend (`.github/workflows/test.yml` รันเฉพาะฝั่ง Flutter)
ต้องรัน `npm test` เองก่อน push

### ทำไมใช้ `node --test` ไม่ใช่ Jest หรือ Mocha

- มาพร้อม Node 20 ไม่ต้องติดตั้งอะไรเพิ่ม ลด dependency ลงหลายสิบตัว
- รองรับ ESM ตั้งแต่แรก ไม่ต้องตั้ง babel หรือ transformer
- เร็วพอ สำหรับ 136 เคสที่ไม่แตะฐานข้อมูล

### สิ่งที่เทสต์ชุดนี้จับได้จริงระหว่างพัฒนา

- `changePercent(null, 100)` คืน `-100` เพราะ `Number(null)` เป็น `0`
- `floorFilter()` ใช้ alias ผิดใน 2 ฟังก์ชันจาก 4
- `zipSync` ล้มเพราะ `mtime: 0` อยู่นอกช่วงปี 1980–2099
- โครง `schema.sql` กับเทสต์ไม่ตรงกันหลังเพิ่มตารางใหม่ (จับได้ 3 ครั้ง)

เคสสุดท้ายคือเหตุผลที่ `schema-doctor.test.js` มีค่าตายตัวว่าต้องมีกี่ตาราง
กี่คอลัมน์ — มันบังคับให้คนที่เพิ่มตารางต้องไปอัปเดตเทสต์ ซึ่งเป็นจังหวะที่
จะนึกได้ว่าต้องอัปเดต `schema.sql` และ migration ด้วย
