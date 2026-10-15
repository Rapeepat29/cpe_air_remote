# Backend ตอนที่ 2: งานเบื้องหลังและตรรกะหลักของระบบ

## ภาพรวม

ตอนที่ 1 อธิบาย Backend ในมุม "รอรับคำขอ" คือ route ที่ตอบเมื่อแอปหรือเว็บเรียกเข้ามา บทนี้อธิบายอีกครึ่งหนึ่งของ Backend คือ **งานที่ทำเองโดยไม่มีใครเรียก** ได้แก่ รับข้อมูลจากบอร์ด ESP32 ผ่าน MQTT, นับถอยหลังแล้วสั่งปิดแอร์เมื่อห้องว่าง, สะสมค่าไฟเป็นรายชั่วโมง, และคำนวณว่าตอนนี้ห้องอยู่ในคาบเรียนหรือไม่ โค้ดทั้งหมดอยู่ใน 2 โฟลเดอร์ `backend/src/services/` และ `backend/src/utils/` (ยกเว้น `utils/http.js`, `utils/security.js`, `utils/user.js`, `services/mailer.js` ที่อยู่ในบทอื่น)

กติกาแบ่งชั้นของโปรเจกต์นี้ชัดมาก และเป็นกุญแจในการอ่านบทนี้

- **`utils/` = ฟังก์ชันบริสุทธิ์ (pure function)** รับค่าเข้า คืนค่าออก ไม่แตะฐานข้อมูล ไม่ส่ง MQTT ไม่อ่านนาฬิกาเอง (เวลาถูกส่งเข้ามาเป็นพารามิเตอร์ `now`) จึงทดสอบด้วย `node --test` ได้ในเสี้ยววินาที
- **`services/` = ตัวลงมือทำจริง (side effects)** ต่อ MQTT, อ่านเขียนฐานข้อมูล, ตั้ง timer ฟังก์ชันพวกนี้เรียกฟังก์ชันใน `utils/` เพื่อ "ตัดสินใจ" แล้วค่อยลงมือตามคำตัดสิน

ตัวอย่างที่เห็นชัดที่สุดคือระบบปิดแอร์อัตโนมัติ `utils/auto-off.js` ตอบแค่ว่า "ควรทำอะไร" (`start`, `wait`, `fire`, ...) ส่วน `services/auto-off.js` เป็นคนอ่านฐานข้อมูล เรียกตัวตัดสินใจ แล้วเขียนฐานข้อมูล/ยิง MQTT ตามคำตอบนั้น

เส้นทางข้อมูลหลักของบทนี้

```text
ESP32 แอร์ ──MQTT──▶ Mosquitto ──▶ services/mqtt.js ──▶ ตาราง air_conditioners
OCC32 เซ็นเซอร์คน ──MQTT──▶              │                 ตาราง energy_hourly
                                         │ (ผู้ฟังเหตุการณ์)
                                         ▼
                              services/auto-off.js ──▶ publishAirCommand ──MQTT──▶ ESP32 ยิง IR ปิดแอร์
                                         ▲
                       ทุก 10 วินาที (setInterval)
```

ลำดับตอนเริ่มระบบ (จาก `backend/src/server.js`) ต้องจำให้ได้ เพราะเกี่ยวกับ "ทำไมต้องลงทะเบียนก่อน"

1. `startMqttAccounts()` ลงทะเบียนผู้ฟัง "ต่อ Broker สำเร็จ" ไว้ก่อน
2. `startMqttBridge()` ต่อ Broker เมื่อต่อติด จะเรียกผู้ฟังข้อ 1 ทันที (สร้างบัญชีบอร์ดบน Broker)
3. `startAutoOffService()` ลงทะเบียนผู้ฟังสถานะแอร์/เซ็นเซอร์ และเริ่ม `setInterval`

ถ้าสลับข้อ 1 กับ 2 การต่อ Broker ครั้งแรกอาจเสร็จก่อนที่ใครลงทะเบียนรอฟัง บัญชีบอร์ดจะไม่ถูกสร้างในรอบนั้น (comment ใน `server.js` เขียนไว้ว่า "ต้องลงทะเบียนก่อนต่อ Broker เพื่อให้ทันรอบ connect แรก")

## ความรู้ที่ต้องมีก่อนอ่านบทนี้

### Timer และงานเบื้องหลังใน Node.js
Node.js รันโค้ดบน thread เดียว (single thread) แต่ไม่ได้หยุดรอ: สิ่งที่ช้า (ฐานข้อมูล เครือข่าย) ใช้ `await` แล้ว Node ไปทำอย่างอื่นระหว่างรอ งานเบื้องหลังเกิดจาก `setInterval(fn, ms)` ที่เรียก `fn` ซ้ำทุก `ms` มิลลิวินาที `timer.unref()` บอก Node ว่า "ถ้ามีแค่ timer นี้เหลืออยู่ ให้ปิดโปรเซสได้เลย" ไม่ต้องรอมัน อีกแบบคือ **event listener** ที่รอให้เหตุการณ์เกิดแล้วค่อยทำ (เช่น ข้อความ MQTT เข้ามา) ระบบนี้ใช้ทั้งสองแบบร่วมกัน

### MQTT, pub/sub, QoS, retained และ Last Will
MQTT คือโปรโตคอลส่งข้อความแบบ **publish/subscribe** ผ่านตัวกลางที่เรียกว่า Broker (ที่นี่คือ Mosquitto) ผู้ส่ง (publisher) ส่งข้อความไปที่ **topic** (ชื่อคล้าย path เช่น `rmutt/ac/ESP32-AABBCCDDEEFF/status`) ผู้รับ (subscriber) บอก Broker ว่าสนใจ topic ไหน Broker ส่งต่อให้ ผู้ส่งกับผู้รับไม่ต้องรู้จักกัน

- `+` ใน topic คือ wildcard แทนหนึ่งระดับ `rmutt/ac/+/status` ตรงกับทุกบอร์ด
- **QoS 1** = ส่งอย่างน้อยหนึ่งครั้ง (อาจซ้ำได้ ถ้าไม่ได้รับ ack จะส่งใหม่) ระบบนี้ใช้ QoS 1 ทุกที่
- **retained** = Broker จำข้อความล่าสุดของ topic นั้นไว้ ใครมา subscribe ทีหลังได้ข้อความนั้นทันที
- **Last Will and Testament (LWT)** = ตอนต่อ Broker บอร์ดฝากข้อความ "ลาตาย" ไว้ ถ้าบอร์ดหลุดแบบไม่บอกลา (ไฟดับ Wi-Fi หลุด) Broker จะ publish ข้อความนั้นแทน ระบบนี้ใช้ LWT บอกว่าบอร์ดออฟไลน์ (ดูหัวข้อ status ด้านล่าง)

### State machine (เครื่องสถานะ)
ระบบที่อยู่ได้ทีละ "สถานะ" และเปลี่ยนสถานะตามเหตุการณ์ด้วยกติกาตายตัว ระบบปิดแอร์อัตโนมัติคือ state machine 3 สถานะ (ว่าง/นับถอยหลัง/กำลังสั่งปิด) ข้อดีคือทุกกรณีมีคำตอบ ไม่มีช่วงที่ไม่รู้ว่าระบบอยู่ตรงไหน

### Pure function กับ side effect
Pure function = ใส่ค่าเดิมต้องได้ผลเดิมเสมอ และไม่ไปเปลี่ยนอะไรนอกฟังก์ชัน Side effect = การกระทำที่ส่งผลออกนอกฟังก์ชัน (เขียนฐานข้อมูล ส่งข้อความ พิมพ์ log) การแยกสองอย่างออกจากกันทำให้ตรรกะที่ซับซ้อนที่สุด (ตัดสินใจปิดแอร์) ทดสอบง่ายที่สุด

### Idempotency (ทำซ้ำกี่ครั้งผลก็เหมือนกัน)
การทำคำสั่งเดิมซ้ำแล้วผลลัพธ์สุดท้ายไม่เปลี่ยน สำคัญมากกับ MQTT เพราะ QoS 1 อาจส่งข้อความซ้ำ และบอร์ดอาจส่งข้อมูลย้อนหลังซ้ำ ระบบนี้ออกแบบให้ทำซ้ำได้ปลอดภัยหลายจุด เช่น รายการย้อนหลังที่เคยบันทึกแล้วถูกข้าม, `raiseAlert` ไม่สร้างใบเตือนซ้ำ, คำสั่งสร้างบัญชี MQTT ตอบ "already exists" ได้โดยไม่ถือเป็น error

### เวลาไทย (Asia/Bangkok) และ hour bucket
เซิร์ฟเวอร์ตั้งเวลาเป็น UTC แต่ผู้ใช้คิดเป็นเวลาไทย (UTC+7) ถ้าตัดชั่วโมงตาม UTC แถว "09:00" ในรายงานจะเป็น 16:00 น. จริง ๆ ระบบจึงใช้ `Intl.DateTimeFormat` กับ `timeZone: 'Asia/Bangkok'` ทุกครั้งที่ต้องรู้ "ชั่วโมงนี้" "วันนี้" "วันอะไรในสัปดาห์" **hour bucket (ถังรายชั่วโมง)** คือแถวเดียวในตาราง `energy_hourly` ต่อเครื่องต่อชั่วโมง ทุกตัวอย่างที่เข้ามาในชั่วโมงนั้นถูกบวกรวมเข้าแถวเดียวกัน

### Hysteresis (ช่วงกันสั่น)
ใช้สองเกณฑ์แทนหนึ่งเกณฑ์เพื่อไม่ให้สถานะสลับไปมาตอนค่าเฉียดเส้น ฝั่งเฟิร์มแวร์ ESP32 ตัดสินว่า "แอร์ทำงานอยู่" เมื่อกำลังไฟ ≥ 30 W ต่อเนื่อง 3 ครั้ง และตัดสินว่า "หยุด" เมื่อ ≤ 10 W ต่อเนื่อง 3 ครั้ง (ค่าคงที่ `AC_RUNNING_ON_WATTS`, `AC_RUNNING_OFF_WATTS`, `AC_RUNNING_CONFIRM_SAMPLES` ใน `rmutt_esp32_air.ino`) ค่าระหว่าง 10–30 W คงสถานะเดิม Backend ไม่คำนวณเองซ้ำ แค่เชื่อฟิลด์ `acRunning` ที่บอร์ดสรุปมาให้

### Bounded retries (ลองซ้ำแบบมีเพดาน)
ลองซ้ำได้ แต่ต้องมีจำนวนครั้งสูงสุดและช่วงห่างแน่นอน ถ้าไม่มีเพดานจะเกิด "พายุคำสั่ง" ตัวอย่างในบทนี้: ยิง IR ซ้ำทุก 20 วินาที สูงสุด 5 ครั้ง, รอคำตอบ Dynamic Security ไม่เกิน 8 วินาที, ต่อ Broker ใหม่ทุก 3 วินาที, รับข้อมูลย้อนหลังครั้งละไม่เกิน 50 รายการ

### UPSERT
`INSERT ... ON DUPLICATE KEY UPDATE` คือคำสั่งเดียวที่ "ถ้ายังไม่มีแถวให้สร้าง ถ้ามีแล้วให้บวกเพิ่ม" ทำให้บันทึกลงถังรายชั่วโมงได้ปลอดภัยแม้สองข้อความเข้ามาพร้อมกัน (ถ้า SELECT ก่อนแล้วค่อย INSERT/UPDATE สองคำสั่งอาจแย่งกัน)

## โครงสร้างโฟลเดอร์

```text
backend/src/
├── server.js                  จุดเริ่มระบบ: เริ่ม MQTT, บัญชี MQTT, ระบบปิดแอร์
├── services/                  ตัวลงมือทำ (มี side effect)
│   ├── mqtt.js                ต่อ Broker, รับ/ส่งข้อความ, เขียน status ลง DB
│   ├── mqtt-accounts.js       สร้าง/ลบบัญชี MQTT รายบอร์ดบน Mosquitto Dynamic Security
│   ├── auto-off.js            ตัวคุมจังหวะปิดแอร์อัตโนมัติ (setInterval + ผู้ฟังเหตุการณ์)
│   ├── energy-recorder.js     บันทึกค่าไฟลงถังรายชั่วโมง (สด + ย้อนหลัง)
│   ├── alerts.js              สร้าง/ปิดใบแจ้งเตือน system_alerts
│   ├── system-settings.js     ค่าตั้งระดับอาคาร (สวิตช์รวม, อัตราค่าไฟ, ภาคเรียนของตาราง)
│   ├── academic-terms.js      ปฏิทินวันเปิด-ปิดภาคเรียน
│   └── room-bookings.js       อ่านการจองห้องของวันนี้
└── utils/                     ฟังก์ชันบริสุทธิ์
    ├── auto-off.js            กติกาตัดสินใจปิดแอร์ (decideAutoOff)
    ├── mqtt-accounts.js       สร้างชุดคำสั่ง + ACL + รหัสผ่านของบอร์ด
    ├── mqtt-topics.js         รายชื่อ topic ที่ต้องล้าง retained
    ├── mqtt-provisioning.js   แยก MQTT_URL เป็น host/port/TLS ให้บอร์ด
    ├── energy-history.js      คำนวณผลต่างพลังงาน, ถัง, SQL รายงาน, ช่วงเวลา
    ├── xlsx-writer.js         เขียนไฟล์ .xlsx เอง
    ├── xlsx-reader.js         อ่านไฟล์ .xlsx (ป้องกันไฟล์อันตราย)
    ├── schedule-import.js     แปลง Excel/CSV เป็นรายการคาบเรียน
    ├── schedule.js            ตรวจข้อมูลคาบเรียน
    ├── class-schedule.js      "ตอนนี้อยู่ในคาบไหม" ตามเวลาไทย
    ├── room-booking.js        ตรวจ/คำนวณการจองห้องนอกตาราง
    ├── room.js                ตรวจข้อมูลห้อง, แปลงแถว DB เป็น JSON
    ├── air-conditioner.js     ตรวจข้อมูลแอร์/คำสั่งแอร์, แปลงแถว DB เป็น JSON
    ├── occupancy-sensor.js    ตรวจข้อมูลเซ็นเซอร์คน, ปรับรูปข้อความสถานะ
    ├── firmware.js            ตรวจชื่อไฟล์/ชนิด/รุ่น/เนื้อไฟล์ firmware, สร้าง URL สำหรับ OTA
    ├── unprovision.js         คำสั่งล้างค่าบอร์ด + ตรวจคำตอบ
    └── schema-doctor.js       อ่าน schema.sql เทียบกับฐานข้อมูลจริง
```

ไฟล์ทดสอบที่เกี่ยวข้องอยู่ที่ `backend/test/` เช่น `auto-off.test.js`, `energy-history.test.js`, `offline-history.test.js`, `mqtt-accounts.test.js`, `schedule-import.test.js`, `xlsx-writer.test.js`, `unprovision.test.js` รันทั้งหมดด้วย `npm test` (คือ `node --test`)

## อธิบายทีละไฟล์

**กลุ่ม MQTT**

### `services/mqtt.js` (876 บรรทัด) — สะพานระหว่าง Broker กับ Backend

**หน้าที่** ต่อ Mosquitto ในฐานะ client ตัวหนึ่ง รับข้อความจากบอร์ด เขียนลงฐานข้อมูล และส่งคำสั่งกลับไปหาบอร์ด เป็นไฟล์ใหญ่ที่สุดของบทนี้

**ต่อ Broker** `startMqttBridge()` (บรรทัด 86) เรียก `mqtt.connect(config.mqtt.url, {...})` ด้วยตัวเลือกสำคัญ

| ตัวเลือก | ค่า | ความหมาย |
|---|---|---|
| `reconnectPeriod` | `3000` | หลุดแล้วลองต่อใหม่เองทุก 3 วินาที (นี่คือกลไก reconnect) |
| `clean` | `true` | ไม่เก็บ session เก่าบน Broker ต่อใหม่ทุกครั้งต้อง subscribe ใหม่ จึงทำใน handler `connect` |
| `clientId` | `rmutt-api-<pid>` | ตั้งตามเลข process กันสองโปรเซสใช้ client id ซ้ำแล้วเตะกันไปมา |
| `username`/`password` | จาก `config.mqtt` | บัญชีของ Backend เอง (ไม่ใช่ของบอร์ด) |

ถ้า `MQTT_URL` ว่าง ฟังก์ชันพิมพ์คำเตือนแล้วคืนเลย ระบบอื่นยังทำงานต่อ (ไม่มี MQTT ก็ใช้แอปดูข้อมูลเก่าได้)

**Subscribe (ชื่อตรงตัวจากโค้ด บรรทัด 104–113)** ทำใน handler `connect` เพราะ `clean: true` ต้องสมัครใหม่ทุกครั้งที่ต่อติด รวมถึงตอนต่อใหม่หลังหลุด ใช้ `config.mqtt.topicPrefix` (ค่าเริ่มต้น `rmutt/ac`) และ `config.mqtt.occupancyTopicPrefix` (ค่าเริ่มต้น `rmutt/occupancy`)

| Topic ที่ Backend subscribe (QoS 1) | ใครส่ง | Handler |
|---|---|---|
| `rmutt/ac/+/state` | ESP32 แอร์ | อัปเดต `state_json`, `is_online = 1`, `last_seen_at` |
| `rmutt/ac/+/status` | ESP32 แอร์ (และ LWT) | `handleAirStatus` — หัวใจของ Backend ฝั่งอุปกรณ์ (ก่อนหน้านั้นตรวจคำตอบ unprovision และ `controlMode` ของบอร์ดสายแอร์) |
| `rmutt/ac/+/provision` | ESP32 แอร์ | `activateProvisioning` ยืนยันโทเคนตอนติดตั้ง |
| `rmutt/ac/+/history` | ESP32 แอร์ | `handleAirHistory` รับข้อมูลที่เก็บไว้ตอนเน็ตหลุด |
| `rmutt/occupancy/+/status` | OCC32 | `handleOccupancyMessage` |
| `rmutt/occupancy/+/provision` | OCC32 | `activateOccupancyProvisioning` |
| `$CONTROL/dynamic-security/v1/response` | Mosquitto (เฉพาะโหมด `dynsec`) | `handleDynsecResponse` |

ฟังก์ชัน `handleIncomingMessage` (บรรทัด 387) เป็นตัวแยกทางเดียวของไฟล์: จับ topic ด้วย regex ที่บังคับรูปแบบรหัสอุปกรณ์ `ESP32-[0-9A-F]{12}` และ `OCC32-[0-9A-F]{12}` และชนิดข้อความ `(state|status|provision|history)` ถ้า topic ไม่ตรงรูปแบบจะ `return` เฉย ๆ (ไม่ error) และถ้า JSON พัง `catch` แล้วทิ้ง

> [!WHY]
> ใช้ regex เข้มแทนที่จะ split ด้วย `/` เพราะ topic มาจากภายนอก (บอร์ดที่ถูกแฮ็กอาจส่ง topic แปลก ๆ) รหัสอุปกรณ์ที่ไม่ตรงรูปแบบจะไม่มีวันถูกใช้ใน SQL หรือชื่อไฟล์ นอกจากนี้ `escapeRegExp(prefix)` ป้องกันไม่ให้ตัวอักษรพิเศษใน prefix (เช่น `.`) กลายเป็นความหมายของ regex

**Topic ที่ Backend publish (คำสั่งไปหาบอร์ด)** ทุกตัว QoS 1

| Topic | retain | Payload | ฟังก์ชัน |
|---|---|---|---|
| `rmutt/ac/<id>/command` | ไม่ | `{version:1, commandId:<UUID>, sentAt:<ISO>, state:{...}}` | `publishAirCommand` สั่งแอร์ตามสถานะที่ต้องการ |
| `rmutt/ac/<id>/command` | ไม่ | `{version, commandId, sentAt, action:'enter_setup'}` | `publishEnterSetupMode` ให้บอร์ดกลับเข้าโหมดตั้งค่า |
| `<prefix>/<id>/command` | ไม่ | `{version, commandId, sentAt, action:'ota', url}` | `publishOtaCommand(kind, id, url)` สั่งอัปเดตเฟิร์มแวร์ (`kind` = `'air'` หรือ `'occupancy'`) |
| `rmutt/occupancy/<id>/command` | ไม่ | `{..., action:'enter_setup'}` | `publishEnterOccupancySetupMode` |
| `<prefix>/<id>/command` | ไม่ | `{version:1, commandId, sentAt, action:'unprovision', deviceId}` | `unprovisionDevice(kind, id)` สั่งบอร์ดล้างค่าในตัวเองตอนแอดมินลบอุปกรณ์ แล้วรอคำตอบไม่เกิน 4 วินาที |
| `rmutt/ac/<id>/schedule-status` | **ใช่** | `{version:1, classScheduleConfigured, withinClassSchedule, evaluatedAt, timezone:'Asia/Bangkok'}` | `publishScheduleEvaluation` บอกบอร์ดว่าตอนนี้อยู่ในคาบหรือไม่ |
| `rmutt/ac/<id>/history-ack` | ไม่ | `{version:1, upTo, stored, skipped}` | `handleAirHistory` ยืนยันรับข้อมูลย้อนหลัง |
| `<prefix>/<id>/provision-ack` | **ใช่** | `{version:1, activated:true, deviceId, token}` | ตอบหลังโทเคนติดตั้งถูกต้อง |
| `<prefix>/<id>/provision` | **ใช่** (ข้อความว่าง) | `''` | ล้าง retained ของ provision หลังใช้เสร็จ |
| `$CONTROL/dynamic-security/v1` | ไม่ | `{commands:[...]}` | `dynsecRequest` |

`commandId` (UUID สุ่ม) ทำให้บอร์ดแยกคำสั่งซ้ำได้ `version: 1` ให้โปรโตคอลขยายได้ในอนาคต ฟังก์ชันส่งคำสั่งทั้งหมดตรวจ `client?.connected` ก่อน ถ้ายังไม่ต่อจะโยน error ที่มี `statusCode = 503` ให้ route แปลงเป็นข้อความ "Backend ยังไม่เชื่อมต่อ MQTT Broker"

**สถานะออนไลน์และ LWT** บอร์ดแอร์ฝัง Last Will ไว้ตอน `connect` ที่ topic `<prefix>/<id>/status` (QoS 1, retained) เนื้อหา `{"online":false,"deviceId":"..."}` เมื่อบอร์ดหลุด Broker ส่งข้อความนี้ให้ Backend ผ่าน subscription `/status` เดิม `normalizePowerStatus` (บรรทัด 674) ตีความ `online: source.online !== false` และเมื่อ `pzemAvailable` ไม่ใช่ `true` ค่าไฟฟ้าทุกตัวเป็น `null` และ `acRunning` เป็น `false` ผลคือแถวถูกเขียนเป็น `is_online = 0` โดยไม่ต้องมีโค้ดแยกสำหรับ "ออฟไลน์" ข้อความ LWT ไม่มี `firmwareVersion` จึงไม่ไปทับรุ่นเฟิร์มแวร์เดิม (`recordFirmwareStatus` ข้ามเมื่อไม่มีรุ่น)

**ล้างค่าบอร์ดตอนลบอุปกรณ์ (unprovision)** `unprovisionDevice(kind, deviceId)` (บรรทัด 306) เป็นคำสั่งเดียวในไฟล์ที่ "ส่งแล้วรอคำตอบ" แทนที่จะส่งแล้วจบ ขั้นตอนคือ (1) ถ้ายังไม่ต่อ Broker คืน `{sent:false, acknowledged:false}` ทันที (2) สร้าง payload ด้วย `buildUnprovisionCommand` จาก `utils/unprovision.js` (3) สร้าง Promise ที่จะจบเมื่อบอร์ดตอบ หรือเมื่อครบ `UNPROVISION_ACK_TIMEOUT_MS` = 4000 ms แล้วเก็บฟังก์ชันปิดการรอไว้ใน `Map` ชื่อ `unprovisionWaiters` (key = รหัสบอร์ด) (4) publish ไปที่ `<prefix>/<id>/command` แบบ QoS 1 **ไม่ retain** (5) เมื่อบอร์ดส่ง `{"unprovisioned":true,"deviceId":...}` มาทาง `status` ตัวแยก topic เรียก `consumeUnprovisionAck` (บรรทัด 348) ซึ่งเรียกฟังก์ชันใน `Map` ด้วย `true` ฟังก์ชันนี้ **ไม่โยน error เลย** เพราะการลบในฐานข้อมูลต้องสำเร็จเสมอแม้บอร์ดออฟไลน์ ผลลัพธ์ `acknowledged` ถูกส่งต่อเป็น `boardCleared` ในคำตอบของ route ลบ (ดูบท Backend ตอนที่ 1)

> [!WHY]
> ทำไมรอแค่ 4 วินาที: route ลบอุปกรณ์ต้องรอผลนี้ก่อนตอบแอป ถ้ารอนานแอดมินจะเห็นปุ่มค้าง บอร์ดที่ออนไลน์ปกติตอบได้ในไม่ถึงวินาที (ส่งคำตอบก่อนเริ่มล้าง NVS) ถ้าเกิน 4 วินาทีแทบแน่ใจว่าบอร์ดออฟไลน์ ซึ่งรอนานกว่านี้ก็ไม่ได้อะไรเพิ่ม และทำไมไม่ส่งแบบ retain: ถ้าคำสั่งค้างบน Broker วันหลังเอาบอร์ดตัวเดิมกลับมาติดตั้งใหม่ บอร์ดจะได้รับคำสั่งเก่าทันทีที่ต่อ แล้วล้างตัวเองทิ้งอีกรอบ

> [!NOTE]
> บรรทัด 323 `unprovisionWaiters.get(deviceId)?.(false)` ปิดการรอเก่าของบอร์ดเดียวกันก่อน (กรณีกดลบซ้ำเร็ว ๆ) และใน `finish` เช็ก `unprovisionWaiters.get(deviceId) === finish` ก่อนลบออกจาก `Map` เพื่อไม่ให้ตัวรอเก่าที่หมดเวลาทีหลังไปลบตัวรอใหม่ทิ้ง `?.(...)` คือ "เรียกฟังก์ชันถ้ามี ถ้าไม่มี (undefined) ไม่ต้องทำอะไร"

**แก้ protocol ตามบอร์ดสายแอร์** บอร์ดรุ่น `rmutt_esp32_air_wired` ใส่ `controlMode: "wired"` ใน status ทุกครั้ง ตัวแยก topic อ่านด้วย `protocolFromStatus` (จาก `utils/air-conditioner.js`) แล้วเรียก `syncControlProtocol` (บรรทัด 445) ให้แถวใน `air_conditioners` มี `protocol = 'DAIKIN_WIRED'` ก่อนประมวลผล status ทำในคิวเดียวกับ `handleAirStatus` (ดูเจาะโค้ดจุดที่ 2)

**ข้อมูลย้อนหลังและ ack** ตอนเน็ตหลุดบอร์ดเก็บสรุปช่วงละ 5 นาทีไว้ในตัว พอต่อได้จะส่งไปที่ `/history` เป็นชุด Backend บันทึกผ่าน `recordHistoryBatch` แล้วตอบ `history-ack` พร้อม `upTo` (เวลาของรายการล่าสุดที่จัดการแล้ว) บอร์ดลบทุกรายการที่เวลา ≤ `upTo` และส่งชุดถัดไปหลังได้รับ ack เท่านั้น **ถ้าบันทึกไม่สำเร็จ Backend จะไม่ตอบ** บอร์ดจึงส่งชุดเดิมซ้ำเอง (เฟิร์มแวร์รอ ack 20 วินาที ลองใหม่หลัง 5 วินาที: `HISTORY_ACK_TIMEOUT_MS`, `HISTORY_RETRY_DELAY_MS`) ความปลอดภัยของการส่งซ้ำมาจากจุดต่อ (chain) ใน `energy-recorder.js`

**ผู้ฟังเหตุการณ์ (listener)** ไฟล์มี 3 ชุด `onAirStatus`, `onOccupancyStatus`, `onMqttConnected` แต่ละตัวคืนฟังก์ชันยกเลิกการสมัคร ฟังก์ชัน `notify` เรียกทุก listener ภายใน `try/catch` เพื่อให้ listener ที่พังไม่ทำให้ตัวอื่นหรือการรับ MQTT พังตาม

> [!WHY]
> ทำไมต้องมี listener แทนที่ `services/mqtt.js` จะ `import` `services/auto-off.js` ตรง ๆ: ระบบปิดแอร์ต้อง import `publishAirCommand` จาก `mqtt.js` อยู่แล้ว ถ้า `mqtt.js` import กลับจะเกิด **circular import** (สองไฟล์อ้างถึงกันเป็นวง) แก้ด้วยกลับทิศ: `mqtt.js` ไม่รู้จักใคร แค่เปิดช่องให้คนมาฟัง ผลพลอยได้คือทดสอบแต่ละฝั่งแยกกันได้

**ใครเรียกไฟล์นี้** `server.js` เรียก `startMqttBridge`/`stopMqttBridge`; `routes/air-conditioners.js` และ `routes/occupancy-sensors.js` เรียก `publishAirCommand`, `publishEnterSetupMode`, `publishEnterOccupancySetupMode`, `publishOtaCommand`, `unprovisionDevice`, `clearRetainedAirTopics`, `clearRetainedOccupancyTopics`; `services/auto-off.js` เรียก `onAirStatus`, `onOccupancyStatus`, `publishAirCommand`; `services/mqtt-accounts.js` เรียก `dynsecRequest`, `onMqttConnected`; `getMqttBridgeStatus()` ใช้ในหน้า health โดยตั้งใจไม่คืน username/password (มีเทสต์ใน `test/mqtt.test.js` ตรวจ)

ฟังก์ชันช่วยที่ export ไว้ให้เทสต์: `normalizePowerStatus`, `firmwareFields` (ตัดรุ่นเฟิร์มแวร์ 20 ตัวอักษร ข้อความ OTA error 120 ตัวอักษร), `evaluateClassSchedule` (re-export จาก `class-schedule.js`)

### `utils/mqtt-topics.js` (26 บรรทัด)

รายชื่อ "ส่วนท้าย topic" ที่ถูกส่งแบบ retained: `AIR_RETAINED_SUFFIXES` (6 ตัว: `command`, `state`, `status`, `provision`, `provision-ack`, `schedule-status`) และ `OCCUPANCY_RETAINED_SUFFIXES` (4 ตัว) กับฟังก์ชัน `retainedTopics(prefix, deviceId, suffixes)` ที่ประกอบเป็น topic เต็ม ใช้ตอนถอดอุปกรณ์: `clearRetained` ใน `mqtt.js` publish ข้อความว่าง (`''`) แบบ retained ไปทุก topic ซึ่งเป็นวิธีมาตรฐานของ MQTT ที่สั่งให้ Broker ลืมข้อความ retained ของ topic นั้น แยกเป็นไฟล์ `utils` เพราะประกอบสตริงล้วน ไม่ต้องแตะ Broker จึงมีเทสต์ใน `test/mqtt.test.js`

### `utils/mqtt-provisioning.js` (35 บรรทัด)

`resolveMqttProvisioningSettings(settings)` แปลง `MQTT_URL` (หรือ `MQTT_DEVICE_URL` ถ้าตั้งไว้) เป็น `{mqttHost, mqttPort, mqttUsername, mqttPassword, mqttTls}` ที่แอปส่งต่อให้บอร์ดผ่าน BLE ตอนติดตั้ง พอร์ตเริ่มต้น `1883` (`mqtt:`) หรือ `8883` (`mqtts:` = TLS) ถ้าค่าว่างตอบ 503 ถ้า URL ผิดรูปหรือ protocol ไม่ใช่ `mqtt:`/`mqtts:` ตอบ 500 แยก `MQTT_DEVICE_URL` ออกมาเพราะ Backend คุย Broker ในเครือข่าย Docker (`mqtt://mqtt:1883`) แต่บอร์ดต้องเข้าจากอินเทอร์เน็ต (ค่าเริ่มต้นใน compose คือ `mqtts://rmutt-energy.tailb292b4.ts.net:8443` ผ่าน Tailscale Funnel หรือ `mqtts://<โดเมน>:8883` ถ้าตั้งให้บอร์ดต่อตรง) ทดสอบใน `test/mqtt-provisioning.test.js`

### `services/mqtt-accounts.js` และ `utils/mqtt-accounts.js` — บัญชี MQTT รายบอร์ด

**ปัญหาที่แก้** ในโหมด `MQTT_DEVICE_AUTH=shared` (ใช้ตอน dev) ทุกบอร์ดใช้ username เดียวที่เข้าถึง `rmutt/#` ได้ทั้งหมด ถ้ามีคนแกะบอร์ดตัวเดียวออกจากฝ้าเพดานแล้วอ่านรหัสใน flash ก็สั่งแอร์ได้ทั้งอาคาร โหมด `MQTT_DEVICE_AUTH=dynsec` ที่ใช้บนเซิร์ฟเวอร์จริง ให้แต่ละบอร์ดมี username = Device ID ของตัวเอง และมีสิทธิ์เฉพาะ topic ของตัวเอง

ฝั่ง `utils/` (ฟังก์ชันบริสุทธิ์ ประกอบ "ชุดคำสั่ง" เป็น JSON):

| ฟังก์ชัน/ค่า | หน้าที่ |
|---|---|
| `DEVICE_KINDS` | ตารางสเปกแต่ละชนิด: `air` (รูปแบบ `ESP32-…`, client id `rmutt-`), `occupancy` (`OCC32-…`, `rmutt-occ-`) พร้อมรายการ topic ที่ publish/subscribe ได้ |
| `deriveDevicePassword(secret, deviceId)` | รหัสผ่านบอร์ดคำนวณด้วย HMAC-SHA256 (ดูหัวข้อเจาะโค้ด) |
| `deviceKindOf(id)` | บอกว่าเป็น `air`/`occupancy`/`null` |
| `deviceRoleName(id)` | ชื่อ role = `device-<ID ตัวใหญ่>` |
| `deviceAcls(...)` | ACL ของบอร์ดหนึ่งตัว |
| `backendAcls(prefixes)` | ACL ของ Backend: publish + subscribe `<prefix>/#` ทั้งสอง prefix |
| `ensureDeviceCommands(...)` | `createRole` → `addRoleACL` ทีละข้อ → `createClient` |
| `repairDeviceCommands(...)` | `setClientPassword`, `setClientId`, `addClientRole`, `enableClient` |
| `removeDeviceCommands(id)` | `deleteClient` แล้ว `deleteRole` |
| `ensureBackendCommands(...)` | สร้าง role `rmutt-backend` และผูกกับ username ของ Backend |
| `isHarmlessDynsecError(command, error)` | error ไหนถือว่าสำเร็จ |
| `normalizeDeviceAuthMode` | ค่าอื่นนอกจาก `shared`/`dynsec` ถอยเป็น `shared` |

**ACL ของบอร์ดแอร์** (ชื่อ `ESP32-…`): publish ได้เฉพาะ `state`, `status`, `provision`, `provision-ack`, `history` ของตัวเอง; subscribe ได้เฉพาะ `command`, `provision-ack`, `schedule-status`, `history-ack` ของตัวเอง ใช้ `subscribeLiteral` (ตรงตัว ไม่ใช่ wildcard) ส่วน Backend ใช้ `subscribePattern` กับ `<prefix>/#` บอร์ดเซ็นเซอร์คน publish ได้ `status`, `provision`, `provision-ack` และ subscribe ได้ `command`, `provision-ack` Dynamic Security ปฏิเสธทุก topic ที่ไม่ได้อนุญาตเป็นค่าเริ่มต้น

ฝั่ง `services/mqtt-accounts.js` (ลงมือส่งคำสั่งผ่าน `dynsecRequest`):

- `startMqttAccounts()` ลงทะเบียน `onMqttConnected(() => reconcileAccounts())` เฉพาะเมื่อ `isPerDeviceAuth()` (โหมด `dynsec`)
- `reconcileAccounts()` ทุกครั้งที่ต่อ Broker ได้: ให้สิทธิ์ Backend เอง แล้วอ่าน `device_id` ของทุกบอร์ด (ทั้ง `reserved` และ `active`) จากทั้ง `air_conditioners` และ `occupancy_sensors` (`UNION`) แล้ว `ensureDeviceAccount` ทีละตัว ผลคือถ้าไฟล์ `dynamic-security.json` ของ Mosquitto หายหรือย้ายเซิร์ฟเวอร์ บอร์ดเดิมกลับมาต่อได้เองโดยไม่ต้องตั้งค่าใหม่
- `prepareDeviceCredentials(deviceId, mqttSettings)` ใช้ตอนจองบอร์ด (route เรียก) โหมด `shared` คืนบัญชีเดียวของ Backend; โหมด `dynsec` คำนวณรหัสผ่าน แล้ว `ensureDeviceAccount(..., {repair: true})` ให้เสร็จ**ก่อน**ตอบแอป เพื่อให้แอปส่งเข้าบอร์ดแล้วบอร์ดต่อ Broker ได้ทันที
- `removeDeviceAccount(id)` ลบ client และ role คืน `true` ถ้าลบได้หรือไม่มีอยู่แล้ว คืน `false` ถ้า error (route รายงานผลเป็น `mqttAccountRemoved`)
- `runCommands` ส่งชุดคำสั่ง แล้วกรองผล: error ใดที่ `isHarmlessDynsecError` ตอบว่าไม่เป็นไร (เช่น `already exists`, `already has`, `already in`, `deleteClient/deleteRole` ที่ `not found`, `addClientRole` ที่ตอบ `internal error` ซึ่ง Mosquitto 2.0.x ตอบแบบนั้นเมื่อผูกไว้แล้ว) จะถูกข้าม ที่เหลือโยน `Error` ที่มี `statusCode = 502`

**`dynsecRequest(commands)` ใน `mqtt.js`** (บรรทัด 140) เป็นแบบ request/response บน pub/sub: ติด `correlationData` = `<batch>:<index>` ให้ทุกคำสั่ง publish ไปที่ `$CONTROL/dynamic-security/v1` แล้วรอใน `pendingDynsec` (Map) จน `handleDynsecResponse` เก็บคำตอบได้ครบตามจำนวน แล้ว resolve เป็นอาร์เรย์ `{command, error}` เรียงตามลำดับที่ส่ง รอได้ไม่เกิน `DYNSEC_TIMEOUT_MS = 8000` มิลลิวินาที เกินแล้ว reject (503)

> [!WARN]
> `ensureDeviceCommands` จงใจ **ไม่** แตะบัญชีที่มีอยู่แล้ว เพราะ Dynamic Security จะเตะบอร์ดที่ออนไลน์ให้หลุดทันทีเมื่อมี `setClientPassword`/`setClientId` ชุด "ซ่อม" (`repairDeviceCommands`) จึงใช้เฉพาะตอนจองบอร์ดใหม่ ซึ่งบอร์ดต้องต่อใหม่อยู่แล้ว

ทดสอบใน `test/mqtt-accounts.test.js`

**กลุ่มระบบปิดแอร์อัตโนมัติ**

### `utils/auto-off.js` (142 บรรทัด) — ตัวตัดสินใจ (pure)

ค่าคงที่ (export ทั้งหมด) และฟังก์ชัน

| ชื่อ | ค่า | ความหมาย |
|---|---|---|
| `AUTO_OFF_IDLE_SECONDS` | `300` | ห้องว่างนอกคาบเรียน: นับถอยหลัง 5 นาที |
| `AUTO_OFF_IN_CLASS_SECONDS` | `900` | ห้องว่างระหว่างมีคาบ: นับ 15 นาที (เผื่อพักเบรก) |
| `AUTO_OFF_RETRY_SECONDS` | `20` | ยิง IR ซ้ำทุกกี่วินาที ถ้าแอร์ยังกินไฟ |
| `AUTO_OFF_MAX_ATTEMPTS` | `5` | ยิงซ้ำสูงสุดกี่ครั้งก่อนยอมแพ้ |
| `decideAutoOff({device, occupancy, withinClass, now})` | — | คืน `{action, reason, ...}` |
| `autoOffSecondsRemaining(device, now)` | — | วินาทีที่เหลือ (ใช้แสดงนาฬิกาในแอป) หรือ `null` |
| `autoOffPhase(device, now)` | — | `'idle'` / `'counting'` / `'commanding'` ที่ส่งให้แอป |

`autoOffSecondsRemaining` และ `autoOffPhase` ถูกเรียกจาก `utils/room.js` (`publicRoom`) และ `utils/air-conditioner.js` (`publicAirConditioner`) เพื่อใส่ใน JSON ที่ส่งให้แอป รายละเอียดทุกกติกาอยู่ในหัวข้อ "ระบบปิดแอร์อัตโนมัติอย่างละเอียด" ด้านล่าง

### `services/auto-off.js` (373 บรรทัด) — ตัวคุมจังหวะ

`startAutoOffService()` / `stopAutoOffService()` (เรียกจาก `server.js`), `evaluateAutoOff({deviceId, roomNumber, now})` (export ไว้ให้เทสต์/เรียกตรง) และฟังก์ชันภายใน `readDevices`, `evaluateDevice`, `fireOffCommand`, `clearCountdown`, `clearAllCountdowns`, `applyNotificationRules`, `readSchedule`, `acquireRunnerLock`/`releaseRunnerLock`, `parseState` อธิบายละเอียดด้านล่างและในหัวข้อเจาะโค้ด

### `services/alerts.js` (111 บรรทัด) — ใบแจ้งเตือน

ตาราง `system_alerts` เก็บเหตุการณ์ที่คนควรรู้ ชนิดเก็บเป็นรหัสไม่ใช่ข้อความสำเร็จรูป (แอปแปลภาษาเอง และเปลี่ยนถ้อยคำได้โดยไม่แก้ข้อมูลเก่า)

| `ALERT_KINDS` | ค่าในฐานข้อมูล | ความหมาย | สถานะที่สร้าง |
|---|---|---|---|
| `OUTSIDE_SCHEDULE_OCCUPIED` | `outside_schedule_occupied` | ไม่มีคาบเรียน แต่แอร์ทำงานและมีคนอยู่ในห้อง | `open` (ต้องมีคนจัดการ) |
| `AUTO_OFF_SUCCEEDED` | `auto_off_succeeded` | สั่งปิดแล้วแอร์หยุดจริง | `resolved` ทันที (แค่รายงานผล) |
| `AUTO_OFF_FAILED` | `auto_off_failed` | ยิงครบ 5 ครั้งแล้วแอร์ยังทำงาน | `open` |

- `raiseAlert({kind, roomNumber, deviceId, deviceName, detail})` ชนิดที่ต้องมีคนจัดการ (`OPEN_KINDS`) จะ **ไม่สร้างซ้ำ** ถ้ายังมีใบ `open` ของ kind+ห้อง+เครื่องเดียวกัน (ตรวจด้วย `(device_id <=> ?)` ซึ่ง `<=>` คือ "เท่ากันแบบรองรับ NULL" ของ MariaDB) ตัด `deviceName` ไว้ 60 ตัวอักษร `detail` 255 ตัวอักษร id เป็น UUID
- `resolveOpenAlerts({kind, roomNumber, deviceId})` เปลี่ยนใบ `open` เป็น `resolved` พร้อม `resolved_at` เมื่อเงื่อนไขหมดไปเอง คืนจำนวนแถวที่ปิด
- `publicAlert(row)` แปลงแถว DB เป็น JSON ให้แอป (ใช้ใน `routes/alerts.js`)

> [!WHY]
> เหตุที่ไม่สร้างซ้ำ: ตัวคุมจังหวะทำงานทุก 10 วินาที ถ้า `raiseAlert` สร้างใบใหม่ทุกรอบที่เงื่อนไขยังจริง ตารางจะมีใบซ้ำหลายพันใบต่อชั่วโมง นี่คือ idempotency ของงานเบื้องหลัง: เรียกซ้ำกี่ครั้งผลสุดท้ายคือมีใบเดียว

**กลุ่มค่าไฟ (energy)**

### `services/energy-recorder.js` (333 บรรทัด)

บันทึกค่าที่ได้จากบอร์ดลงตาราง `energy_hourly` ข้อมูลมาได้ 2 ทาง: (1) status สดทุก ~10 วินาที (`STATUS_INTERVAL_MS = 10000` ในเฟิร์มแวร์) และ (2) ข้อมูลย้อนหลังช่วงละ 5 นาทีหลังเน็ตกลับมา ทั้งสองทางใช้ **"จุดต่อ" (chain)** ชุดเดียวกันคือคอลัมน์ `energy_chain_at`, `energy_chain_kwh`, `energy_chain_running` ของแถว `air_conditioners` = เวลา เลขมิเตอร์ และสถานะแอร์ของตัวอย่างล่าสุดที่บันทึกแล้ว พลังงานของตัวอย่างถัดไปคิดจากผลต่างกับจุดต่อนี้ จึงไม่มีช่วงไหนนับซ้ำหรือหาย

| ฟังก์ชัน | หน้าที่ |
|---|---|
| `runSerialForDevice(deviceId, task)` | คิวต่อบอร์ด งานของบอร์ดเดียวกันทำทีละงาน (เก็บ Promise ท้ายคิวใน Map `deviceQueues`) กัน status สดกับข้อมูลย้อนหลังแย่งอ่าน/เขียนจุดต่อพร้อมกัน |
| `recordEnergySample({deviceId, roomNumber, deviceName, previous, status, now})` | บันทึก status สดหนึ่งครั้ง |
| `recordHistoryBatch({deviceId, records, now})` | บันทึกข้อมูลย้อนหลังหนึ่งชุด ใน transaction เดียว (`withTransaction`) และล็อกแถวด้วย `SELECT ... FOR UPDATE` |
| `upsertBucket(database, {...})` | `INSERT ... ON DUPLICATE KEY UPDATE` เข้า `energy_hourly` |
| `chainFromRow`, `saveChain` | อ่าน/เขียนจุดต่อ (แถวเก่าที่ยังไม่มีจุดต่อใช้ค่าล่าสุดของแถวแทน; ถ้า DB ยังไม่ migrate (`ER_BAD_FIELD_ERROR`) ข้ามเงียบ ๆ) |
| `purgeEnergyHistoryOlderThan(days)` | ลบถังเก่ากว่ากำหนด ไม่มีอะไรเรียกอัตโนมัติ ค่าเริ่มต้นคือเก็บทั้งหมด |

ข้อจำกัดของข้อมูลย้อนหลัง: ชุดละไม่เกิน `HISTORY_MAX_RECORDS_PER_BATCH = 50` รายการ, เก่ากว่า `HISTORY_MAX_AGE_SECONDS = 31 * 24 * 3600` (31 วัน) ไม่รับ, เวลาในอนาคตเกิน `HISTORY_MAX_FUTURE_SECONDS = 300` ไม่รับ (นาฬิกาบอร์ดผิด), รายการที่เวลา ≤ จุดต่อถือว่าเคยบันทึกแล้วและข้าม

**ความหมายของ "ข้าม" กับ "ตอบ"** ผลลัพธ์ `{upTo, stored, skipped, invalid, unknown}` ถ้าบอร์ดถูกถอดไปแล้ว (`unknown: true`) ยังคืน `upTo` เพื่อให้ตอบ ack ให้บอร์ดลบทิ้ง ไม่ให้ส่งวนไม่รู้จบ

### `utils/energy-history.js` (804 บรรทัด)

ไฟล์บริสุทธิ์ที่ใหญ่ที่สุด แบ่งเป็นกลุ่ม:

| กลุ่ม | ฟังก์ชัน/ค่า |
|---|---|
| เวลาไทย | `BANGKOK_TIMEZONE`, `bangkokParts`, `bangkokHourStart`, `bangkokToday`, `describeBucket`, `toDateTimeText`, `shiftDate`, `nextDay` |
| ตัวคำนวณค่าไฟ | `MAX_SAMPLE_GAP_SECONDS = 300`, `energyDelta`, `elapsedSeconds`, `buildSampleDelta`, `sampleDeltaToBucket` |
| ข้อมูลย้อนหลัง | `HISTORY_INTERVAL_SECONDS = 300`, `decodeHistoryRecord`, `buildHistoryDelta` |
| แคตตาล็อกค่า | `METRIC_CATALOG` (16 ค่า), `DEFAULT_METRIC_KEYS`, `resolveMetrics`, `metricByKey`, `SCOPES`, `DETAIL_LEVELS` |
| รายงาน | `normalizeQuery`, `buildHistorySql`, `leadingColumns`, `buildExportSheet`, `summarizeRows` |
| สรุปหน้าหลัก | `SUMMARY_PERIODS`, `resolvePeriod`, `fillSeries`, `changePercent` |
| ช่วยทั่วไป | `round` |

ผู้เรียก: `services/mqtt.js` ผ่าน `energy-recorder.js`, และ `routes/energy.js` (เส้นทาง `/api/energy/metrics`, `/live`, `/summary`, `/history`, `/export`) ดูรายละเอียดคำนวณในหัวข้อ "ระบบค่าไฟอย่างละเอียด"

### `utils/xlsx-writer.js` (191 บรรทัด)

`buildXlsx({sheetName, header, body})` คืน `Uint8Array` ของไฟล์ `.xlsx` ที่ Excel เปิดได้จริง สร้างเองด้วย `fflate` (ไลบรารีบีบอัดที่โปรเจกต์มีอยู่แล้ว) ไม่เพิ่ม dependency ใหม่ ไฟล์ `.xlsx` คือ ZIP ที่ข้างในเป็น XML (รูปแบบ OOXML) ตัวเขียนสร้างเพียง 6 ไฟล์ขั้นต่ำ

| ไฟล์ใน ZIP | หน้าที่ |
|---|---|
| `[Content_Types].xml` | บอกชนิดของแต่ละส่วน |
| `_rels/.rels` | ชี้ว่า `xl/workbook.xml` คือเอกสารหลัก |
| `xl/workbook.xml` | รายชื่อแท็บ (ชื่อผ่าน `safeSheetName`: ตัดอักขระต้องห้าม `\ / * ? : [ ]` และยาวไม่เกิน 31) |
| `xl/_rels/workbook.xml.rels` | ผูกแท็บเข้ากับ `sheet1.xml` และ `styles.xml` |
| `xl/styles.xml` | สไตล์ 0 = ปกติ, สไตล์ 1 = หัวตารางตัวหนาพื้นเขียวอ่อน (ฟอนต์ Tahoma 11) |
| `xl/worksheets/sheet1.xml` | ข้อมูลจริง |

รายละเอียดที่ควรรู้: ข้อความใช้ `t="inlineStr"` (ฝังในเซลล์) แทน shared strings ทำให้ไม่ต้องมี `sharedStrings.xml` และมีไฟล์ที่ต้องถูกต้องน้อยลง ตัวเลขเขียนเป็น `<v>` ตรง ๆ (เฉพาะ `Number.isFinite`) เซลล์ว่างคือ `<c r="B3"/>` แถวหัวตารางถูก "freeze" ด้วย `<pane ySplit="1" ... state="frozen"/>` ความกว้างคอลัมน์ = ความยาวข้อความมากสุด + 3 จำกัดช่วง 10–42 `columnName(index)` แปลงเลขคอลัมน์เป็นตัวอักษรแบบ base-26 (0→A, 25→Z, 26→AA) `escapeXml` แปลง `& < > " '` และตัดอักขระควบคุม (ที่ทำให้ Excel ฟ้องว่าไฟล์เสีย) ทิ้ง มีเพดาน `MAX_COLUMNS = 64` และ `MAX_ROWS = 200000` (เกินแล้ว `RangeError`) บีบอัด ZIP ระดับ 6 ทดสอบใน `test/xlsx-writer.test.js`

> [!NOTE]
> JSDoc ของ `buildXlsx` พูดถึงพารามิเตอร์ `info` (แถวสรุปด้านบน) แต่โค้ดจริงรับเฉพาะ `sheetName`, `header`, `body` ไม่มีการใช้ `info` เหลือไว้จากแผนเดิม

**กลุ่มตารางเรียน ภาคเรียน และการจองห้อง**

### `utils/class-schedule.js` (115 บรรทัด)

หัวใจของคำถาม "ตอนนี้อยู่ในคาบเรียนไหม" ใช้ทั้ง `services/mqtt.js` และ `services/auto-off.js` จึงแยกเป็นไฟล์กลางเพื่อไม่ให้ import วนกัน

- `evaluateClassSchedule(schedules, now, {term})` คืน `{configured, withinSchedule, termStatus, dayOfWeek, minutesOfDay}` `withinSchedule` เป็นจริงเมื่อมีคาบที่ `day_of_week` ตรงกับวันนี้ (ตามเวลาไทย) และ `start ≤ นาทีของวัน < end` (ปลายเปิด: 10:00–11:00 หมายถึงถึง 10:59) ถ้าอยู่นอกภาคเรียน (`termStatus` เป็น `before`/`after`) จะคืน `withinSchedule: false` ทันทีแม้มีตาราง แต่ `configured` ยังเป็นจริงถ้ามีตาราง เพื่อให้บอร์ดเชื่อผลนี้ ไม่ถอยไปใช้เวลาเปิด-ปิดประจำวันของตัวเอง
- `termStatus(term, now)` คืน `'none'` (ไม่ได้ตั้งวันเปิด-ปิด ใช้ตารางทุกวัน) / `'before'` / `'active'` (รวมวันเปิดและวันปิด) / `'after'` เทียบสตริงวันที่ `YYYY-MM-DD` ตรง ๆ ซึ่งเรียงตามตัวอักษรได้ตรงกับเรียงตามวัน
- `bangkokDate(value)` ได้ `YYYY-MM-DD` ตามเวลาไทย (ใช้ locale `en-CA` เพราะรูปแบบวันที่ตรงกับที่ต้องการ), `bangkokClock(value)` ได้ `{dayOfWeek, minutesOfDay}` (0 = อาทิตย์; ใช้ `hourCycle: 'h23'` กันปัญหา "24:00"), `timeToMinutes('HH:mm')`

### `utils/schedule.js` (81 บรรทัด)

ตรวจข้อมูลคาบเรียนที่เข้ามาทาง API: `validateScheduleFilters(query)` (ชั้น 0–99, วัน 0–6) และ `validateScheduleInput(body)` (ห้องตามรูปแบบ `^[A-Z0-9][A-Z0-9_-]{1,19}$`, ชื่อวิชา 1–150, กลุ่ม ≤ 80, อาจารย์ ≤ 150, เวลารูปแบบ `HH:mm`, เวลาเลิกต้องหลังเวลาเริ่ม) ผิดเมื่อไรโยน `ApiError(400, ...)` ทั้ง route แก้คาบทีละรายการและตัวนำเข้าจากไฟล์ใช้ฟังก์ชันเดียวกัน กฎจึงตรงกันเสมอ ทดสอบใน `test/schedule.test.js`

### `services/academic-terms.js` (156 บรรทัด)

ปฏิทินวันเปิด-ปิดภาคเรียน (ตาราง `academic_terms`) ตารางเรียนในระบบมีชุดเดียว ถ้าภาคเรียนของตารางนั้นมีวันเปิด-ปิดตั้งไว้ ตารางจะมีผลเฉพาะช่วงนั้น นอกช่วงถือว่าทุกห้องอยู่นอกคาบ ห้องจึงถูกปิดแอร์เร็วช่วงปิดภาคโดยไม่ต้องลบตาราง และนำเข้าตารางเทอมหน้าไว้ล่วงหน้าได้

- `validateTermInput(body)` ภาคเรียนต้องเป็น `^[1-3]\/\d{4}$` (เช่น `1/2569`), วันที่ต้องเป็นวันจริง (ตรวจด้วยการแปลงแล้วเทียบกลับ กัน `2569-02-31`), วันปิดต้องไม่ก่อนวันเปิด
- `readTerms`, `upsertTerm` (INSERT ... ON DUPLICATE KEY UPDATE), `deleteTerm` (404 ถ้าไม่พบ), `readCalendar` ใช้ใน route `/api/schedules/terms`
- `readActiveTermGate()` คืน `{semester, startDate, endDate}` ของภาคเรียนที่ตารางปัจจุบันเป็นของมัน (อ่านจาก `system_settings.timetable_semester` ผ่าน `readTimetableInfo`) หรือ `null` ถ้าไม่รู้/ไม่ได้ตั้งวัน ซึ่งแปลว่า "ใช้ตารางทุกวันเหมือนเดิม" ผลถูกพักไว้ใน cache `CACHE_TTL_MS = 15000` (15 วินาที) เพราะถูกเรียกทุก 10 วินาทีต่อแอร์ทุกเครื่องและทุกครั้งที่บอร์ดส่งสถานะ; `clearTermCache()` ล้างทันทีเมื่อแก้ปฏิทินหรือนำเข้าตาราง
- ถ้าตาราง `academic_terms` ยังไม่มี (`ER_NO_SUCH_TABLE`) หรือ error อื่น จะถอยเป็น `null` (ระบบปิดแอร์ไม่ควรล้มเพราะปฏิทินอ่านไม่ได้)

### `utils/room-booking.js` (176 บรรทัด) และ `services/room-bookings.js` (32 บรรทัด)

การจองห้องนอกตารางเรียน (ประชุม สอบ กิจกรรม) ตาราง `room_bookings` `utils/` ตรวจและคำนวณ ส่วน `services/room-bookings.js` อ่านฐานข้อมูล (แยกเพื่อไม่ให้ service ต้อง import ตัว route)

- ค่าคงที่: `REPEAT_TYPES = ['once','daily','weekly']`, `BOOKING_CATEGORIES = ['class','meeting','exam','event','other']`, `MAX_SPAN_DAYS = 400` (กันพิมพ์ปีผิดจนจองยาวหลายสิบปี)
- `validateBookingInput(body)` ตรวจทุกฟิลด์ (ห้อง ชื่อ รูปแบบทำซ้ำ วัน เวลา วันในสัปดาห์สำหรับ `weekly`) และตรวจว่ามีอย่างน้อย 1 วันที่เกิดจริง (`countOccurrences`)
- `bookingOccursOn(booking, date)` การจองนี้มีในวันนั้นไหม (วันใน `[startDate,endDate]` และถ้า `weekly` ต้องตรงวันในสัปดาห์) ใช้ UTC คำนวณวันในสัปดาห์จากสตริงวันที่ล้วน ๆ (`dayOfWeekOf`) จึงไม่ขึ้นกับเขตเวลาเครื่อง
- `activeBooking(bookings, now)` การจองที่ครอบเวลาตอนนี้ (ตามเวลาไทย)
- `withBookings(classResult, bookings, now)` รวมผลตารางเรียนกับการจอง: **มีการจองอยู่ตอนนี้ = ถือว่าอยู่ในคาบ** แม้ตารางบอกว่าไม่มีคาบหรืออยู่นอกภาคเรียน เพราะการจองคือการบอกว่าจะมีคนใช้ห้องจริง
- `publicBooking(row)` แปลงแถว DB เป็น JSON
- `readTodayBookings(roomNumber, today)` ในไฟล์ service คืนการจองที่ `start_date <= today <= end_date` ของห้องนั้น (คืน `[]` ถ้าตารางยังไม่ถูกสร้าง)

### `utils/schedule-import.js` (642 บรรทัด) และ `utils/xlsx-reader.js` (315 บรรทัด)

นำเข้าตารางเรียนจากไฟล์ Excel (`.xlsx`) หรือ CSV (ดูหัวข้อเจาะโค้ดสำหรับอัลกอริทึม)

`schedule-import.js` export: `parseScheduleFile`, `validateScheduleImportPayload`, `pickSemester`, `scheduleLabelForDatabase`, `schedulesToCsv` ผู้เรียกคือ `routes/schedules.js` (`POST /api/schedules/import/preview` และ `/import/commit`) และสคริปต์ `scripts/convert-schedule-file.js`

`xlsx-reader.js` export `readXlsxWorksheets(buffer)` และ `cellAddress(row, column)` อ่านเฉพาะส่วนที่ต้องใช้ของไฟล์ (workbook, relationships, sharedStrings, worksheets) ด้วย `fflate` + `fast-xml-parser` และมีด่านป้องกันไฟล์อันตราย

| ค่าคงที่ | ค่า | ป้องกันอะไร |
|---|---|---|
| `MAX_UNCOMPRESSED_BYTES` | 32 MiB | ZIP bomb (ไฟล์เล็กที่บวมเป็นหลายกิกะไบต์ตอนแตก) |
| `MAX_ZIP_ENTRIES` | 2000 | ZIP ที่มีไฟล์ย่อยมหาศาล |
| `MAX_MERGED_CELLS` | 10000 | ช่วงเซลล์ที่รวมกันใหญ่ผิดปกติ (ใช้หน่วยความจำเยอะตอนสร้าง Map) |
| `processEntities: false` | — | ปิดการขยาย XML entity (กันโจมตีแบบ billion laughs) |

**กลุ่มค่าตั้งระบบ**

### `services/system-settings.js` (246 บรรทัด)

ค่าตั้งระดับ "ทั้งอาคาร" เก็บเป็นคู่ key-value ในตาราง `system_settings` (คอลัมน์ `setting_key`, `setting_value`, `updated_by`, `updated_at`)

| `SETTING_KEYS` | key | ค่าเริ่มต้น | หมายเหตุ |
|---|---|---|---|
| `AUTO_OFF_ENABLED` | `auto_off_enabled` | `true` | สวิตช์รวมของระบบปิดแอร์ ต้องอยู่ฝั่งเซิร์ฟเวอร์เพราะ Backend เป็นคนยิงคำสั่งปิด |
| `ELECTRICITY_RATE` | `electricity_rate` | `4.5` บาท/kWh | ขอบเขต `RATE_LIMITS = {min: 0.01, max: 100}` |
| `TIMETABLE_SEMESTER` | `timetable_semester` | — | ภาคเรียนของตารางที่ใช้ + ผู้นำเข้า/เวลา ไม่ได้ใช้ตัดสินปิดแอร์โดยตรง |

มี cache 5 วินาที (`CACHE_TTL_MS = 5000`) เพราะตัวคุมจังหวะอ่านทุก 10 วินาทีและทุกครั้งที่บอร์ดส่งสถานะ ล้างทันทีเมื่อเขียนใหม่ (`clearSettingsCache`) `parseRate` คืนค่าเริ่มต้นแทน `NaN` เมื่อค่าอ่านไม่ออกหรือเกินขอบเขต `setElectricityRate` ปฏิเสธค่านอกขอบเขตด้วย 400 และเก็บเป็นข้อความทศนิยม 2 ตำแหน่ง (`toFixed(2)`) ให้ค่าที่อ่านกลับเท่าเดิมเป๊ะ ฟังก์ชันที่ export: `isAutoOffEnabled`, `readElectricityRate`, `readPublicSettings`, `setAutoOffEnabled`, `setElectricityRate`, `readTimetableInfo`, `recordTimetableImport`, `clearTimetableInfo` ถ้าตารางยังไม่ถูกสร้าง (`ER_NO_SUCH_TABLE`) จะถอยไปใช้ค่าเริ่มต้นเพื่อให้ระบบเดิมทำงานต่อ route `routes/settings.js` เรียกใช้

> [!NOTE]
> อัตราค่าไฟที่เก็บใน `system_settings` ถูกส่งให้แอปผ่าน `readPublicSettings()` (GET `/api/settings`) แอปนำไปใส่ใน query `rate` ตอนเรียกรายงาน ส่วนการคูณค่าไฟอยู่ใน `routes/energy.js` (ใช้ `query.rate` ที่ผู้เรียกส่งมา) ไม่ได้อ่านค่านี้จากฐานข้อมูลเอง

### `utils/firmware.js` (124 บรรทัด)

ฟังก์ชันบริสุทธิ์ทั้งหมดเกี่ยวกับไฟล์เฟิร์มแวร์ ไม่แตะดิสก์เอง (การอ่าน/เขียนไฟล์อยู่ที่ `routes/firmware.js`)

| ฟังก์ชัน/ค่าคงที่ | หน้าที่ |
|---|---|
| `validateFirmwareFileName(value)` | ชื่อไฟล์ต้องตรง `^[A-Za-z0-9][A-Za-z0-9._-]{0,118}\.bin$` และห้ามมี `..` (กัน path traversal) ผิดโยน 400 |
| `firmwareUrl(host, fileName)` | ประกอบ `https://<host>/firmware/<ไฟล์>` host ต้องเป็นอักษร `[A-Za-z0-9.-]` และต้องเป็นโฮสต์เดียวกับ MQTT host ของบอร์ด เพราะเฟิร์มแวร์ปฏิเสธ URL ที่ชี้ไปโฮสต์อื่น |
| `firmwareKindOf(fileName)` | ชนิดบอร์ดจากชื่อไฟล์: มี `occ` = `occupancy`, มี `wired` หรือ `slm8` = `wired`, นอกนั้น `air` ตรวจ `occ` ก่อน ใช้ทั้งจัดกลุ่มในหน้าจอและกันสั่งไฟล์ผิดชนิด |
| `FIRMWARE_KIND_LABELS` | ชื่อภาษาไทยของแต่ละชนิด (`แอร์ IR`, `สายแอร์ Daikin`, `เซ็นเซอร์ LD2410`) ใช้ในข้อความ error |
| `airFirmwareKind(protocol)` | บอร์ดแอร์ที่ `protocol = DAIKIN_WIRED` ใช้ไฟล์ `wired` ที่เหลือใช้ไฟล์ `air` |
| `assertFirmwareKind(fileName, expectedKind)` | ชนิดจากชื่อไฟล์ต้องตรงกับชนิดบอร์ด ไม่งั้นโยน 400 |
| `firmwareVersionOf(fileName)` | ดึงเลขรุ่นท้ายชื่อ เช่น `rmutt_esp32_air_wired-2.5.2-slm8.bin` → `2.5.2-slm8` ไม่มีเลขรุ่นคืน `null` |
| `compareFirmwareVersions(a, b)` | เทียบรุ่นด้วยตัวเลขสามส่วนแรก (`2.5.10` ใหม่กว่า `2.5.9`) ส่วนท้ายอย่าง `-slm8` ไม่นับ อ่านไม่ได้ถือว่าเก่ากว่า (ตอนนี้ใน Backend มีแค่เทสต์เรียกใช้ หน้าเว็บ `webapp/assets/js/views/firmware.js` มี `compareVersions` ของตัวเองแบบเดียวกันไว้บอกว่าบอร์ดไหนยังเก่า) |
| `FIRMWARE_MAX_BYTES` | `0x1f0000` = 2,031,616 ไบต์ (1,984 KB) เท่าช่องโปรแกรม `app0`/`app1` ใน `partitions.csv` |
| `validateFirmwareImage(buffer)` | ตรวจเนื้อไฟล์: ต้องมีข้อมูล (400), ไม่เกิน `FIRMWARE_MAX_BYTES` (413), ยาวอย่างน้อย 256 ไบต์และไบต์แรกเป็น `0xE9` (400) |

ผู้เรียก: `routes/firmware.js` (รายการ อัปโหลด ลบ), `routes/air-conditioners.js` และ `routes/occupancy-sensors.js` (สั่ง OTA: ตรวจชื่อ ตรวจชนิด แล้วนำ URL ไปให้ `publishOtaCommand`) ทดสอบใน `test/firmware.test.js` (7 เทสต์) รายละเอียดทีละบรรทัดอยู่ในบท Backend ตอนที่ 1 หัวข้อเจาะโค้ดการอัปโหลดเฟิร์มแวร์

> [!WHY]
> ทำไมต้องกันไฟล์ผิดชนิด: บอร์ดแอร์ IR บอร์ดสายแอร์ และเซ็นเซอร์ ต่างก็เป็น ESP32 รับไฟล์ของกันและกันได้ทางเทคนิค ถ้าสั่งไฟล์เซ็นเซอร์ให้บอร์ดแอร์ บอร์ดจะรีบูตเข้าโปรแกรมเซ็นเซอร์ ซึ่งใช้ขาและ topic คนละชุด ต้องไปแฟลชผ่าน USB ที่หน้างาน จึงตรวจทั้งตอนอัปโหลด (ไฟล์ต้องตรงแท็บ) และตอนสั่งบอร์ด (ไฟล์ต้องตรงชนิดบอร์ด)

### `utils/air-conditioner.js` (297 บรรทัด)

ตัวตรวจข้อมูลและตัวแปลงแถวฐานข้อมูลของแอร์

- `validateReservationInput(body)` ตรวจตอนจองบอร์ด: รหัส `ESP32-…` 12 ฐานสิบหก, ห้อง, `airNumber` 1–6, ชื่อ 1–60 ตัวอักษร, ชื่อ Bluetooth ต้องเท่ากับ `RMUTT-AC-<12 ตัวท้ายของรหัส>`, `protocol` ต้องอยู่ในรายการที่รองรับ (`DAIKIN`, `DAIKIN_WIRED`, `GREE`, `MITSUBISHI_AC`, `SAIJO_DENKI`, ... รวม 19 ค่า; `DAIKIN_WIRED` เก็บในค่าคงที่ `WIRED_PROTOCOL`), เวลาเปิด-ปิดประจำวัน `HH:mm`
- `validateAirState(body, protocol)` ตรวจคำสั่งแอร์ที่แอปส่ง: `power` ต้องเป็น boolean, อุณหภูมิ 16–30, โหมด `auto|cool|dry|fan|heat`, พัดลม `auto|low|medium|high|turbo`, swing 7 ค่า, timer 1–1440 นาที และกฎพิเศษของ `SAIJO_DENKI` (อุณหภูมิ 18–29, โหมด cool/dry/fan, ไม่มี swing off) กับกฎของ `DAIKIN_WIRED` (ดูหัวข้อถัดไป)
- `controlTypeOf(protocol)` คืน `'wired'` ถ้าเป็น `DAIKIN_WIRED` นอกนั้น `'ir'` ใช้ใน `publicAirConditioner` ให้ JSON ของแอร์ทุกเครื่องมีฟิลด์ `controlType` แอปและเว็บใช้แสดงป้าย "Daikin · สายแอร์" หรือ "รีโมต IR" และซ่อนปุ่มที่เครื่องทำไม่ได้
- `protocolFromStatus(message)` อ่าน `controlMode` ใน status ถ้าเป็น `wired` (ไม่สนตัวพิมพ์และช่องว่าง) คืน `'DAIKIN_WIRED'` นอกนั้นคืน `null` ใช้ใน `services/mqtt.js`
- `publicAirConditioner(row)` แปลงแถว (snake_case) เป็น JSON (camelCase) ให้แอป รวมค่า `autoOffSecondsRemaining` และ `autoOffPhase` จาก `utils/auto-off.js` และ `state` ที่ parse จาก `state_json` (ถ้าอ่านไม่ได้ใช้ค่า fallback ที่ปลอดภัย)
- `validateDeviceId`

ผู้เรียก: `routes/air-conditioners.js` ทดสอบใน `test/air-conditioner.test.js`

#### กติกาคำสั่งของบอร์ดสายแอร์ `DAIKIN_WIRED`

บอร์ดสายแอร์ต่อเข้าสายของรีโมตติดผนัง Daikin (โปรโตคอล SLM8) แทนการยิง IR สั่งได้เฉพาะสิ่งที่รีโมตติดผนังรุ่นนั้นทำได้ Backend จึงตรวจให้ตรงกับความสามารถจริง

**ไฟล์ `backend/src/utils/air-conditioner.js` บรรทัด 112–123**

```js:112
  const wired = cleanString(protocol).toUpperCase() === WIRED_PROTOCOL;
  if (wired) {
    if (mode !== 'cool' && mode !== 'dry' && mode !== 'fan') {
      throw new ApiError(400, 'แอร์แบบสายแอร์รองรับโหมด Cool, Dry และ Fan');
    }
    if (fanSpeed === 'turbo') {
      throw new ApiError(400, 'แอร์แบบสายแอร์ไม่มีพัดลมระดับ Turbo');
    }
    if (verticalSwing !== 'auto' && verticalSwing !== 'off') {
      throw new ApiError(400, 'แอร์แบบสายแอร์มีเฉพาะส่าย (Auto) หรือหยุด (Off)');
    }
  }
```

| บรรทัด | ความหมาย |
|---|---|
| 112 | `wired` = โปรโตคอลของเครื่องนี้ (จากฐานข้อมูล ไม่ใช่จากคำขอ) คือ `DAIKIN_WIRED` หรือไม่ `cleanString(...).toUpperCase()` ทำให้ตัวพิมพ์เล็ก/ใหญ่ไม่มีผล |
| 114–116 | โหมดได้แค่ `cool`, `dry`, `fan` (ไม่มี `auto` และ `heat`) ผิดโยน 400 พร้อมข้อความไทยที่แอปแสดงได้ตรง ๆ |
| 117–119 | พัดลมระดับ `turbo` ไม่มี (มี `auto`, `low`, `medium`, `high`) |
| 120–122 | swing แนวตั้งมีแค่ "ส่าย" (`auto`) กับ "หยุด" (`off`) ตำแหน่งบานเกล็ดอื่น ๆ (`top`, `middle`, ...) ไม่มี |

**ไฟล์ `backend/src/utils/air-conditioner.js` บรรทัด 137–155**

```js:137
  // รุ่นสายแอร์ไม่มีฟังก์ชันเสริมเหล่านี้ ปิดไว้เลยให้ตรงกับที่แอร์ทำจริง
  // (Sleep มีจริง ยกเว้นในโหมด Dry ที่แอร์ไม่รับ)
  return {
    power: source.power,
    temperature,
    mode,
    fanSpeed,
    verticalSwing,
    horizontalSwing: wired ? false : boolean(source.horizontalSwing),
    eco: wired ? false : boolean(source.eco),
    turbo: wired ? false : boolean(source.turbo),
    sleep: wired && mode === 'dry' ? false : boolean(source.sleep),
    quiet: wired ? false : boolean(source.quiet),
    displayLight: boolean(source.displayLight, true),
    clean: wired ? false : boolean(source.clean),
    timerOnMinutes,
    timerOffMinutes,
  };
}
```

| บรรทัด | ความหมาย |
|---|---|
| 145–147, 149, 151 | `wired ? false : boolean(...)` คือ ternary operator (`เงื่อนไข ? ค่าเมื่อจริง : ค่าเมื่อเท็จ`) เครื่องสายแอร์บังคับ `horizontalSwing`, `eco`, `turbo`, `quiet`, `clean` เป็น `false` เสมอ ไม่ว่าแอปจะส่งอะไรมา |
| 148 | `sleep` เปิดได้ ยกเว้นโหมด `dry` ที่แอร์ไม่รับ (`&&` ต้องจริงทั้งสองข้าง) |
| 150 | `displayLight` ไม่ถูกแตะ ค่าเริ่มต้น `true` เหมือนเดิม |

> [!WHY]
> ทำไมบางอย่างโยน 400 แต่บางอย่างแค่ตั้งเป็น `false`: โหมด พัดลม swing คือค่าหลักที่ผู้ใช้เลือกเอง ถ้าเลือกค่าที่แอร์ทำไม่ได้ ต้องบอกผู้ใช้ตรง ๆ ไม่งั้นแอร์จะทำอย่างอื่นโดยที่ผู้ใช้ไม่รู้ ส่วนฟังก์ชันเสริม (eco, turbo, quiet, clean) แอปรุ่นเก่าอาจส่ง `true` ติดมาจากสถานะเดิม ถ้าปฏิเสธทั้งคำสั่งเพราะสวิตช์เสริมที่ไม่มีอยู่จริง ผู้ใช้จะเปิดแอร์ไม่ได้เลย จึงเลือกตัดทิ้งเงียบ ๆ ผลคือ `state_json` ที่เก็บไว้ตรงกับที่แอร์ทำจริงเสมอ เทสต์ใน `test/air-conditioner.test.js` (`limits wired Daikin commands to what the wall-panel bus supports`) ยังตรวจด้วยว่า `DAIKIN` แบบ IR ไม่ได้รับผลกระทบ

### `utils/unprovision.js` (36 บรรทัด)

ไฟล์เล็กที่เก็บ "รูปแบบข้อความ" ของการล้างค่าบอร์ด แยกจาก `services/mqtt.js` เพื่อให้เทสต์ได้โดยไม่ต้องต่อ Broker คอมเมนต์หัวไฟล์ (บรรทัด 1–13) เขียนลำดับขั้นตอนตอนลบอุปกรณ์ไว้ครบ

**ไฟล์ `backend/src/utils/unprovision.js` บรรทัด 15–36**

```js:15
export const UNPROVISION_ACK_TIMEOUT_MS = 4000;

export function buildUnprovisionCommand(deviceId, { commandId, sentAt }) {
  return {
    version: 1,
    commandId,
    sentAt,
    action: 'unprovision',
    // บอร์ดตรวจซ้ำว่าตรงกับตัวเอง กันข้อความหลงมาผิด topic
    deviceId,
  };
}

/** ข้อความ status ที่บอร์ดส่งกลับมายืนยันว่าล้างค่าแล้ว */
export function isUnprovisionAck(message, deviceId) {
  return Boolean(
    message
      && typeof message === 'object'
      && message.unprovisioned === true
      && message.deviceId === deviceId,
  );
}
```

| บรรทัด | ความหมาย |
|---|---|
| 15 | เวลารอคำตอบสูงสุด 4000 ms (4 วินาที) `services/mqtt.js` ใช้เป็นค่าเริ่มต้นของ `timeoutMs` |
| 17 | `{ commandId, sentAt }` ในวงเล็บพารามิเตอร์คือ destructuring ของ object ที่ส่งมา รับ UUID และเวลาจากผู้เรียก (ไม่สุ่ม/ไม่อ่านนาฬิกาเอง จึงเป็น pure function เทสต์เทียบผลแบบตรงตัวได้) |
| 18–25 | payload มีรูปเดียวกับคำสั่งอื่น (`version`, `commandId`, `sentAt`, `action`) เพิ่ม `deviceId` ให้บอร์ดตรวจซ้ำว่าคำสั่งนี้เป็นของตัวเองจริง (เฟิร์มแวร์ไม่ล้างค่าถ้าไม่ตรง) |
| 29–36 | คำตอบที่นับว่า "ล้างแล้ว" ต้องเป็น object, `unprovisioned === true` (ต้องเป็น boolean จริง สตริง `'true'` ไม่นับ) และ `deviceId` ตรงกับบอร์ดที่สั่ง status ปกติของบอร์ดจึงไม่ถูกตีความผิด |

ทดสอบใน `test/unprovision.test.js` (2 เทสต์: รูป payload และกรณีคำตอบที่ไม่นับ เช่น `deviceId` ของบอร์ดอื่น, `'true'` เป็นสตริง, `null`)

### `utils/room.js` (122 บรรทัด)

`validateRoomInput`, `validateRoomNumber` (รูปแบบเดียวกับที่อื่น), `publicRoom(row)` (รวมสถานะเซ็นเซอร์และนาฬิกาปิดแอร์ของห้อง), `roomDefaultsForImport(value)` เดาข้อมูลห้องใหม่ตอนนำเข้าตาราง: รหัสแบบ `16<ชั้น 1-9><ลำดับ 2 หลัก>` (เช่น `16103` = ชั้น 1 ลำดับ 3, ประเภท `Classroom`) นอกนั้นเป็น `Special` ชั้น 0 ทดสอบใน `test/room.test.js`

### `utils/occupancy-sensor.js` (71 บรรทัด)

- `STATIC_ENERGY_THRESHOLD = 25` ค่าความไวเริ่มต้นของเรดาร์ตรวจคนนิ่ง (ใช้ตอบกลับเมื่อแถวไม่มีค่า) **ระวัง:** เฟิร์มแวร์ตรวจคนใช้ค่าคงที่ของตัวเองเป็น 15 ค่า 25 ฝั่ง Backend จึงเป็นแค่ค่าที่แสดงในแอป/เว็บ ไม่ได้ควบคุมบอร์ด (ดูบท 9)
- `validateOccupancyReservationInput`, `validateOccupancyDeviceId` (รหัส `OCC32-…`, ชื่อ BLE ต้องเป็น `RMUTT-OCC-<12 ตัวท้าย>`)
- `publicOccupancySensor(row)`
- `normalizeOccupancyStatus(message)` ปรับข้อความสถานะ: `online = message.online !== false`; `radarAvailable` ต้อง online และบอร์ดบอกว่า `true`; **`occupied` จะเป็นจริงได้ก็ต่อเมื่อ `radarAvailable` เป็นจริง** (เรดาร์เสียแล้วรายงาน "มีคน" ไม่ได้) ฟังก์ชันนี้คือด่านแรกของหลัก fail-safe ของระบบปิดแอร์ ทดสอบใน `test/occupancy-sensor.test.js`

### `utils/schema-doctor.js` (138 บรรทัด)

เครื่องมือตรวจฐานข้อมูล ใช้กับสคริปต์ `npm run db:doctor` (`scripts/doctor.js`) `parseSchemaTables(sql)` อ่าน `database/schema.sql` ด้วย regex `CREATE TABLE IF NOT EXISTS ...` แล้วแยกชื่อคอลัมน์ (ข้ามบรรทัด PRIMARY/KEY/CONSTRAINT ฯลฯ) `diffTables(expected, actual)` คืน `{missingTables, missingColumns}` `isAutoAddableColumn` บอกว่าคอลัมน์ใดเติมทับตารางที่มีข้อมูลได้ (คอลัมน์ `NOT NULL` ที่ไม่มี `DEFAULT` เติมไม่ได้) `stripLineComments` ตัดคอมเมนต์ `--` ก่อนแยกคอลัมน์ ไม่งั้นคอลัมน์ที่มีคอมเมนต์อยู่บรรทัดก่อนหน้าจะถูกอ่านเป็นคอลัมน์ชื่อ `--` และ `--fix` จะสร้าง `ALTER TABLE` ผิด syntax ทดสอบใน `test/schema-doctor.test.js`

## ระบบปิดแอร์อัตโนมัติอย่างละเอียด

### โจทย์ และทำไมตรรกะอยู่ที่ Backend

> เมื่อแอร์ทำงานอยู่แต่ไม่มีคนในห้อง ให้นับถอยหลัง ถ้ายังไม่มีคนเมื่อครบเวลา ให้สั่งปิดแล้วยืนยันว่าแอร์หยุดจริง

ความผิดพลาดสองแบบไม่เท่ากัน: ไม่ปิดทั้งที่ควรปิดแค่เสียค่าไฟ แต่ **ปิดทั้งที่ไม่ควรปิด คือปิดแอร์ใส่คนที่นั่งอยู่** ทุกกติกาจึงเอนไปทาง "เมื่อไม่แน่ใจ ให้ไม่ปิด" ตรรกะอยู่ที่ Backend เพราะบอร์ดแอร์ (ESP32) รู้แค่ว่าแอร์กินไฟอยู่ไหม แต่ไม่รู้ว่ามีคนไหม ส่วนเซ็นเซอร์ (OCC32) รู้ว่ามีคนไหม แต่ไม่รู้เรื่องแอร์ และสองบอร์ดคุยกันเองไม่ได้ มีแต่ Backend ที่เห็นทั้งสองฝั่งและเห็นตารางเรียนด้วย

![ระบบปิดแอร์อัตโนมัติ](img/06-auto-off.svg)

### อินพุตและเอาต์พุตของ `decideAutoOff`

อินพุต `{ device, occupancy, withinClass, now }`

| ฟิลด์ | ที่มา (`services/auto-off.js`) | ความหมาย |
|---|---|---|
| `device.autoOffEnabled` | `auto_off_enabled` | สวิตช์รายเครื่อง (ต้องเป็น `true` เท่านั้น) |
| `device.acRunning` | `ac_running` | บอร์ดสรุปแล้วว่าแอร์กินไฟอยู่ (hysteresis ที่บอร์ด) |
| `device.pzemAvailable` | `pzem_available` | อ่านค่าไฟได้ไหม |
| `device.autoOffDeadlineAt` | `auto_off_deadline_at` | เวลาครบกำหนด หรือ `null` = ไม่มีนาฬิกาเดิน |
| `device.autoOffAttempts` | `auto_off_attempts` | ยิงไปแล้วกี่ครั้ง |
| `device.autoOffLastAttemptAt` | `auto_off_last_attempt_at` | เวลายิงครั้งล่าสุด |
| `occupancy.hasSensor / online / radarAvailable / occupied` | `LEFT JOIN occupancy_sensors` | ห้องมีเซ็นเซอร์ไหม ออนไลน์ไหม เรดาร์ใช้ได้ไหม มีคนไหม |
| `withinClass` | `evaluateClassSchedule` + ปฏิทินภาคเรียน + การจองห้อง | ตอนนี้อยู่ในคาบ (หรือมีการจอง) ไหม |
| `now` | ส่งเข้ามา | เวลาปัจจุบัน (ส่งเข้ามาเพื่อให้เทสต์ควบคุมเวลาได้) |

เอาต์พุต `{ action, reason, ... }` มี 7 `action`

| `action` | ความหมาย | `services/auto-off.js` ทำอะไรต่อ |
|---|---|---|
| `idle` | ไม่มีอะไรต้องทำ ไม่มีนาฬิกาเดิน | ไม่ทำอะไร |
| `start` | เริ่มนับถอยหลัง (มี `graceSeconds`, `withinClass`) | `UPDATE` ตั้ง `auto_off_started_at`, `auto_off_deadline_at`, `auto_off_attempts = 0`, `auto_off_in_class` |
| `wait` | นับอยู่ยังไม่ครบ หรือเพิ่งยิงรอดูผล | ไม่ทำอะไร |
| `fire` | ถึงเวลา (มี `attempt` = ครั้งที่) | `fireOffCommand` |
| `succeeded` | แอร์หยุดกินไฟหลังจากที่เราสั่ง | ล้างนาฬิกา, `raiseAlert(AUTO_OFF_SUCCEEDED)`, ปิดใบ `AUTO_OFF_FAILED` ที่ค้างอยู่ |
| `giveUp` | ยิงครบ 5 ครั้งแล้วแอร์ยังทำงาน | ล้างนาฬิกา, `raiseAlert(AUTO_OFF_FAILED)` |
| `cancel` | เงื่อนไขหมดไป | ล้างนาฬิกา |

### กติกาทุกข้อ ตามลำดับที่โค้ดตรวจ

| ด่าน | เงื่อนไข | ถ้ากำลังนับอยู่ | ถ้ายังไม่นับ | เหตุผล (`reason`) |
|---|---|---|---|---|
| 0 (service) | สวิตช์รวม `isAutoOffEnabled()` เป็นปิด | ล้างนาฬิกาทุกเครื่อง | — | ไม่ส่งเข้า `decideAutoOff` เลย |
| 1 | `autoOffEnabled !== true` หรือเซ็นเซอร์ไม่น่าเชื่อถือ (`hasSensor && online && radarAvailable` ขาดข้อใดข้อหนึ่ง) | `cancel` | `idle` | `disabled` (เซ็นเซอร์ดีแต่ปิดฟีเจอร์) หรือ `noSensor` |
| 2 | `pzemAvailable !== true` | `cancel` | `idle` | `noPzem` |
| 3 | `occupancy.occupied === true` | `cancel` | `idle` | `occupied` |
| 4 | `acRunning !== true` | ถ้า `attempts > 0` → `succeeded` (`powerDropped`) ไม่งั้น `cancel` | `idle` | `notRunning` |
| 5 | ผ่านทุกด่าน (แอร์เดินอยู่ ห้องว่าง เซ็นเซอร์ดี) และยังไม่นับ | — | `start` | `emptyRoom` |
| 6 | นับอยู่ แต่ `deadline` อ่านเป็นวันที่ไม่ได้ | `cancel` | — | `badDeadline` |
| 7 | `now < deadline` | `wait` | — | `countdown` (มี `secondsRemaining`) |
| 8 | `attempts >= 5` | `giveUp` | — | `stillRunning` |
| 9 | ยิงล่าสุดห่างไม่ถึง 20 วินาที | `wait` | — | `retryCooldown` |
| 10 | นอกนั้น | `fire` (`attempt = attempts + 1`) | — | `deadlinePassed` |

เวลานับถอยหลังที่ด่าน 5: `withinClass === true` → `AUTO_OFF_IN_CLASS_SECONDS = 900` (15 นาที), นอกนั้น → `AUTO_OFF_IDLE_SECONDS = 300` (5 นาที)

**เงื่อนไขยกเลิก (cancel) ทั้งหมด** ขณะนับอยู่: มีคนเข้ามา (`occupied`), เซ็นเซอร์ตายหรือไม่มี (`noSensor`), ปิดฟีเจอร์รายเครื่อง (`disabled`), PZEM อ่านไม่ได้ (`noPzem`), แอร์หยุดเอง ก่อนที่เราสั่ง (`notRunning` เมื่อ `attempts = 0` ซึ่งไม่ใช่ผลงานของระบบจึงไม่แจ้ง "สำเร็จ"), วันที่ครบกำหนดอ่านไม่ได้ (`badDeadline`) และสวิตช์รวมถูกปิด

> [!WHY]
> ทำไมมีคนเข้ามาแล้ว **ยกเลิก** ไม่ใช่ "พักนับ": ถ้าคนเข้ามาแล้วออกไปอีก ควรนับใหม่ 5 นาทีเต็ม ไม่ใช่เหลือแค่ไม่กี่วินาทีจากรอบก่อนแล้วโดนปิดแอร์ทันที

> [!WHY]
> ด่านเซ็นเซอร์ใช้ `occupancy.hasSensor === true && online === true && radarAvailable === true` และเงื่อนไขสวิตช์ใช้ `!== true` (ไม่ใช่ `=== false`) เพราะค่าที่หายไป (`undefined`/`null`) ต้องตกไปทางปลอดภัย คือไม่ปิดแอร์ นี่คือหลัก fail-safe ถ้าฐานข้อมูลเก็บแค่ `is_occupied` ตัวเดียว เรดาร์ที่สาย UART หลุดจะรายงาน "ไม่มีคน" ตลอด แล้วระบบจะปิดแอร์ใส่คนที่นั่งอยู่ทุกวัน ฝั่ง `normalizeOccupancyStatus` จึงบังคับ `occupied = radarAvailable && occupied` อีกชั้น

> [!WHY]
> ด่าน PZEM มาก่อนด่าน "แอร์ทำงานไหม" เพราะ IR เป็นการส่งทางเดียวไม่มีการตอบรับ วิธีเดียวที่รู้ว่าแอร์ปิดจริงคือกำลังไฟตก ถ้าอ่านไฟไม่ได้ ระบบจะยิงครบ 5 ครั้งแล้วแจ้ง "ล้มเหลว" ทุกครั้งโดยไม่มีประโยชน์ ลำดับนี้ยังช่วยกันกรณีบอร์ดแอร์หลุด (LWT): ข้อความ LWT ทำให้ `pzem_available = 0` จึงชนด่าน 2 และ `cancel` ไม่ใช่ `succeeded` ปลอม ๆ จากการที่ `ac_running` กลายเป็น 0

### State machine ของนาฬิกาปิดแอร์

สถานะของแอร์แต่ละเครื่องไม่ได้เก็บเป็นคอลัมน์ "state" ตรง ๆ แต่ **อนุมานจากคอลัมน์** `auto_off_deadline_at` และ `auto_off_attempts` (ฟังก์ชัน `autoOffPhase`): ไม่มี deadline = `idle`; มี deadline และ attempts > 0 = `commanding`; มี deadline, attempts = 0 และยังไม่ครบเวลา = `counting`; ครบเวลาแล้วแต่ยังไม่ได้ยิงสำเร็จ (เช่น Broker ล่ม) = `commanding`

```text
                 start: แอร์เดิน + ห้องว่าง + เซ็นเซอร์ดี + PZEM ดี
   +------+  ---------------------------------------->  +----------+
   | IDLE |                                              | COUNTING |
   +------+  <----------------------------------------  +----------+
     ^  ^     cancel: มีคน / เซ็นเซอร์ตาย / ปิดฟีเจอร์ /     |   |
     |  |             PZEM พัง / แอร์ดับเอง / สวิตช์รวมปิด     |   | wait: ยังไม่ครบ
     |  |                                       ครบ deadline  |   +--(วนอยู่ที่เดิม)
     |  |                                       fire ครั้งที่ 1 |
     |  |                                                     v
     |  |   cancel: มีคนเข้ามา ฯลฯ                      +------------+
     |  +-----------------------------------------------| COMMANDING |<-+
     |                                                  +------------+  | fire ครั้งถัดไป
     |   succeeded: แอร์หยุดกินไฟ -> แจ้ง "สำเร็จ"        |  |           | (ห่าง >= 20 วินาที
     +--------------------------------------------------+  |           |  และ attempts < 5)
     |   giveUp: attempts >= 5 แอร์ยังเดิน -> แจ้ง "ล้มเหลว"  |           |
     +-----------------------------------------------------+  wait: retryCooldown
```

> [!NOTE]
> ในโค้ดไม่มีตัวแปรชื่อ `state` ที่เก็บสถานะเหล่านี้ตรง ๆ การเก็บเป็น "เวลาครบกำหนดหนึ่งค่า" (`deadline_at`) แทนที่จะเก็บ "เหลืออีกกี่วินาที" ทำให้ต้องเขียนฐานข้อมูลแค่ครั้งเดียวตอน `start` แอปเดินนาฬิกาเองจาก deadline ไม่ต้องยิงถามเซิร์ฟเวอร์ทุกวินาที

### ตัวอย่างลำดับเวลา (ห้องว่างนอกคาบ)

| เวลา | เหตุการณ์ | ผลของ `decideAutoOff` |
|---|---|---|
| 10:00:00 | แอร์เดิน ห้องว่าง | `start`, deadline = 10:05:00 |
| 10:00:10 – 10:04:59 | ทุก 10 วินาที (หรือเมื่อมี status เข้า) | `wait` / `countdown` |
| 10:05:00 | ครบกำหนด | `fire` ครั้งที่ 1 → ส่ง `command` (`power:false`) |
| ถัดไป < 20 วินาที | ประเมินอีก | `wait` / `retryCooldown` |
| ≥ 20 วินาทีหลังยิง และแอร์ยังกินไฟ | | `fire` ครั้งที่ 2 (… จนถึงครั้งที่ 5) |
| แอร์หยุดกินไฟ (`ac_running = 0`) | | `succeeded` → แจ้งเตือน `auto_off_succeeded` |
| ยิงครบ 5 ครั้งแล้วยังเดิน | รอบประเมินถัดไป | `giveUp` → แจ้งเตือน `auto_off_failed` |

> [!WARN]
> ข้อสังเกตจากโค้ดจริง: ด่าน `attempts >= 5` (ด่าน 8) อยู่ **ก่อน** ด่าน `retryCooldown` (ด่าน 9) ดังนั้นหลังยิงครั้งที่ 5 รอบประเมินถัดไปจะ `giveUp` ทันทีโดยไม่รอครบ 20 วินาที (รอบประเมินถัดไปมาจาก tick 10 วินาที หรือ status ใหม่ของบอร์ด) ครั้งที่ 5 จึงมีเวลารอผลสั้นกว่าครั้งก่อน ๆ ถ้าอาจารย์ถามให้ตอบตามนี้ อย่าตอบว่ารอครบ 20 วินาทีทุกครั้ง

### ตัวคุมจังหวะ `services/auto-off.js` ทำงานอย่างไร

1. **สามตัวกระตุ้น** (`startAutoOffService`): (ก) ผู้ฟัง `onAirStatus` ทุกครั้งที่บอร์ดแอร์ส่ง status ประเมินเครื่องนั้น (ข) ผู้ฟัง `onOccupancyStatus` ประเมินแอร์ทุกเครื่องในห้องนั้น (ค) `setInterval` ทุก `TICK_INTERVAL_MS = 10_000` (10 วินาที) ประเมินทุกเครื่อง
2. **ทำไมต้องมี timer ด้วย** เพราะถ้าอุปกรณ์เงียบไปเฉย ๆ (ไม่มี event เข้ามา) ก็ยังต้องยิงเมื่อครบกำหนด การรอแต่ event จะไม่มีวันถึงเวลายิง
3. **ป้องกันงานซ้อน** ตัวแปร `running` ในโปรเซส ถ้ารอบก่อนยังไม่จบ รอบใหม่คืน `[]` ทันที (event ที่ถูกทิ้งไปจะมี tick ถัดไปมาชดเชย) และ **named lock ของ MariaDB** (`GET_LOCK('rmutt_auto_off_runner', 0)` ผูกกับ connection) กันกรณีมี Backend รันพร้อมกันเกินหนึ่งตัว ไม่งั้นสองตัวจะยิงคำสั่งปิดซ้ำและนับครั้งเพี้ยน
4. **รวบรวมสถานะ** `readDevices` ดึงแอร์ที่ `provision_status = 'active'` พร้อม `LEFT JOIN occupancy_sensors` ของห้องเดียวกันในคำสั่งเดียว แล้ว `evaluateDevice` แปลงแถวเป็นอ็อบเจกต์ `device` และ `occupancy` และเรียก `readSchedule` (ตารางเรียน + ปฏิทินภาคเรียน + การจองห้อง) เพื่อหา `withinClass`
5. **กติกาแจ้งเตือนข้อ 1** (`applyNotificationRules`) ทำทุกรอบก่อน `switch`: ถ้า แอร์ทำงาน + เซ็นเซอร์น่าเชื่อถือ + มีคน + **ไม่อยู่ในคาบ** → `raiseAlert(OUTSIDE_SCHEDULE_OCCUPIED)` โดย `detail` บอกสาเหตุ (`outsideTerm` / `noClassNow` / `noScheduleAtAll`) ถ้าเงื่อนไขหมดไปก็ `resolveOpenAlerts` ปิดใบเดิมให้เอง
6. **ยิงปิด** `fireOffCommand` เอา `state_json` ปัจจุบันมาตั้ง `power: false` แล้ว `publishAirCommand` ถ้า publish ล้มเหลว (Broker ไม่พร้อม) **ไม่นับเป็นครั้ง** เพื่อลองใหม่รอบหน้า ถ้าสำเร็จจึงบันทึก `auto_off_attempts`, `auto_off_last_attempt_at = CURRENT_TIMESTAMP` และ `state_json` ใหม่ (แอปจะเห็นสถานะปิดทันทีโดยไม่ต้องรอบอร์ดตอบ)
7. **สวิตช์รวมปิด** (`isAutoOffEnabled()` เป็นเท็จ) ไม่เพียงข้ามการประเมิน แต่ `clearAllCountdowns()` ล้างนาฬิกาที่ค้างอยู่ด้วย ไม่งั้นแอปจะโชว์เวลานับถอยหลังที่ไม่มีวันยิงจริง คำสั่ง `UPDATE` มี `WHERE auto_off_deadline_at IS NOT NULL` เพื่อไม่ต้องเขียนฐานข้อมูลเปล่า ๆ ทุก 10 วินาที
8. **ปิดฟีเจอร์รายเครื่อง** ที่ `routes/air-conditioners.js` เมื่อตั้ง `autoOffEnabled = false` จะล้างคอลัมน์นาฬิกาในคำสั่งเดียวกัน

> [!NOTE]
> เวลาครบกำหนดคำนวณฝั่งฐานข้อมูล (`DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? SECOND)` ด้วย `graceSeconds`) ส่วน `deadlineAt` ที่ `decideAutoOff` คืนมาคำนวณจาก `now` ฝั่ง Node ตัวคุมจังหวะไม่ได้ใช้ค่านั้นเขียนลงฐานข้อมูล ใช้เวลาของฐานข้อมูลเป็นหลัก เพื่อให้ทุกคอลัมน์เวลาอ้างนาฬิกาเดียวกัน

## ระบบค่าไฟอย่างละเอียด

### เส้นทางข้อมูลหนึ่งรอบ

```text
PZEM-004T (อ่านทุก 2 วินาที ได้ V, A, W, kWh สะสม, Hz, PF)
   ↓ ESP32 สรุป acRunning ด้วย hysteresis แล้วส่ง /status ทุก ~10 วินาที
services/mqtt.js : handleAirStatus
   ↓ 1. readPreviousAirRow  อ่านแถวเดิมของ air_conditioners
   ↓ 2. recordEnergySample  (ถ้า historyPending = 0)
   ↓ 3. UPDATE air_conditioners เขียนค่าล่าสุดทับ
utils/energy-history.js : buildSampleDelta → sampleDeltaToBucket
   ↓
services/energy-recorder.js : upsertBucket (INSERT ... ON DUPLICATE KEY UPDATE)
   ↓
ตาราง energy_hourly  PK (device_id, bucket_start) หนึ่งแถวต่อเครื่องต่อชั่วโมง
   ↓
routes/energy.js : /summary /history /export  →  แอป / ไฟล์ Excel
```

> [!NOTE]
> เอกสาร `docs/study/07-energy-export.md` และรูป `docs/study/img/07-energy-flow.svg` เขียนลำดับเป็น "อ่านค่าเดิม → เขียนค่าใหม่ทับ → บันทึกค่าไฟ" แต่โค้ดจริงใน `handleAirStatus` คือ **อ่านค่าเดิม → บันทึกค่าไฟ → เขียนค่าใหม่ทับ** (ตามที่เขียนในโค้ด) หลักการเดียวกันคือต้องอ่านค่าเดิมก่อนถูกทับ เหตุผลที่บันทึกก่อนเขียนทับคือถ้าขั้นบันทึกค่าไฟพัง (จับด้วย `try/catch` แล้วแค่ log) ค่าล่าสุดของเครื่องก็ยังถูกเขียนเสมอ

**ทำไมต้องอ่านค่าเดิมก่อน** ค่าไฟต่อชั่วโมงคำนวณจาก "ผลต่างของเลขมิเตอร์สะสม" ระหว่างตัวอย่างนี้กับตัวอย่างก่อนหน้า (และเวลาที่ห่างกัน) ถ้าเขียนทับก่อน ค่าเดิมหายไป จะหาผลต่างไม่ได้ ในทางปฏิบัติถ้าลำดับผิดตัวเลข `consumption_kwh` จะกลายเป็นเลขสะสมทั้งหมดตั้งแต่ติดตั้ง ไม่ใช่ของชั่วโมงนั้น

**ทำไมข้ามการบันทึกเมื่อ `historyPending > 0`** บอร์ดยังส่งข้อมูลย้อนหลังช่วงเน็ตหลุดไม่ครบ ถ้าเอา status สดมาคิดผลต่างตอนนี้ พลังงานช่วงเน็ตหลุดทั้งก้อนจะไปกองอยู่ที่ชั่วโมงที่ต่อเน็ตได้ เมื่อข้อมูลย้อนหลังมาถึงจะนับซ้ำ จึงรอจนบอร์ดบอก `historyPending = 0` ก่อน (บอร์ดรุ่นก่อน 2.4.0 ไม่ส่งฟิลด์นี้ = 0)

### กติกาการคำนวณ

| กติกา | ฟังก์ชัน | พฤติกรรม |
|---|---|---|
| ผลต่างพลังงาน | `energyDelta(prev, cur)` | `cur - prev` ปัดเป็นทศนิยม 3 ตำแหน่ง แต่คืน **0** เมื่อ `cur` หรือ `prev` เป็น null, ผลต่างติดลบ (เลขมิเตอร์รีเซ็ต/บอร์ดบูตใหม่), หรือเกิน 50 kWh (อ่านผิด/สัญญาณรบกวน) |
| เลขมิเตอร์รีเซ็ต | `energyDelta` + `recordEnergySample` | ไม่เดาย้อนหลัง ชั่วโมงนั้นนับ 0 แล้วจุดต่อเก็บเลขใหม่ ตัวอย่างถัดไปจึงคิดผลต่างจากฐานใหม่ ไม่ติดลบซ้ำ |
| เวลาที่ผ่านไป | `elapsedSeconds(prevAt, now, cap = 300)` | ห่างกี่วินาทีโดยจำกัดไม่เกิน `MAX_SAMPLE_GAP_SECONDS = 300` (5 นาที) |
| เกณฑ์เงียบหาย | `MAX_SAMPLE_GAP_SECONDS` | บอร์ดเงียบเกิน 5 นาทีถือว่าขาดช่วง เวลาที่เกินไม่ถูกนับเป็นเวลาทำงาน/ออนไลน์ เพราะไม่รู้ว่าระหว่างนั้นแอร์ทำงานอยู่หรือไม่ (พลังงานเองยังนับตามผลต่างเลขมิเตอร์ ไม่เสียหาย) |
| เวลาแอร์ทำงาน | `buildSampleDelta` | `runtimeSeconds = wasRunning ? gap : 0` ใช้สถานะ **ก่อนหน้า** (`previous.acRunning`) เพราะช่วงที่ผ่านมาแอร์อยู่ในสถานะนั้น |
| เวลาออนไลน์ | `buildSampleDelta` | `onlineSeconds = previous.isOnline ? gap : 0` |
| ถัง | `bangkokHourStart(now)` | ตัดชั่วโมงตามเวลาไทย ได้สตริง `'YYYY-MM-DD HH:00:00'` |
| จุดต่อ | `chainFromRow`, `saveChain` | ตอน PZEM อ่านไม่ได้ (หรือเป็นข้อความ offline) จำเลขมิเตอร์เดิมไว้ ไม่งั้นรอบถัดไปหาผลต่างไม่ได้และพลังงานช่วงนั้นหาย |

### UPSERT ลงถัง

`upsertBucket` เก็บ **ผลรวม + ตัวนับ** ไม่เก็บค่าเฉลี่ย เพราะค่าเฉลี่ยบวกกันไม่ได้ (แรงดัน 220 V จาก 100 ตัวอย่างกับ 230 V จาก 10 ตัวอย่าง ค่าเฉลี่ยที่ถูกคือ (220×100 + 230×10)/110 ไม่ใช่ 225) จึงเก็บ `voltage_sum`, `pzem_samples` แล้วหารตอนอ่านรายงาน ผลพลอยได้: ข้อมูล 1 เครื่อง 1 วัน = 24 แถว (ไม่ใช่ทุก 10 วินาที)

**ไฟล์ `backend/src/services/energy-recorder.js` บรรทัด 232–253**

```sql:232
      ON DUPLICATE KEY UPDATE
        room_number = VALUES(room_number),
        device_name = VALUES(device_name),
        sample_count = sample_count + VALUES(sample_count),
        pzem_samples = pzem_samples + VALUES(pzem_samples),
        running_samples = running_samples + VALUES(running_samples),
        energy_start_kwh = IF(
          VALUES(first_sample_at) < first_sample_at
            AND VALUES(energy_start_kwh) IS NOT NULL,
          VALUES(energy_start_kwh),
          COALESCE(energy_start_kwh, VALUES(energy_start_kwh))
        ),
        energy_end_kwh = IF(
          VALUES(last_sample_at) >= last_sample_at
            AND VALUES(energy_end_kwh) IS NOT NULL,
          VALUES(energy_end_kwh),
          COALESCE(energy_end_kwh, VALUES(energy_end_kwh))
        ),
        first_sample_at = LEAST(first_sample_at, VALUES(first_sample_at)),
        last_sample_at = GREATEST(last_sample_at, VALUES(last_sample_at)),
        consumption_kwh = consumption_kwh + VALUES(consumption_kwh),
        voltage_sum = voltage_sum + VALUES(voltage_sum),
```

ลำดับคอลัมน์ใน `ON DUPLICATE KEY UPDATE` สำคัญ: MariaDB ใช้ค่าที่เพิ่งอัปเดตในคอลัมน์ก่อนหน้ากับคอลัมน์ถัดไป จึงต้องตัดสินเลขมิเตอร์เริ่ม/ปลาย (`energy_start_kwh`, `energy_end_kwh`) ก่อนอัปเดต `first_sample_at`/`last_sample_at` ดังที่ comment ในโค้ดเตือนไว้ ข้อมูลย้อนหลังที่เข้ามาไม่เรียงลำดับก็ยังได้ค่า start/end ถูก เพราะเปรียบเทียบด้วยเวลาไม่ใช่ลำดับที่เข้ามา

### ข้อมูลย้อนหลัง (offline history)

บอร์ดส่งเป็นอาร์เรย์ของตัวเลข 15 ตัวต่อรายการ ตามลำดับที่ `decodeHistoryRecord` ถอดรหัส: `[ts, energyKwh, vAvg×10, vMin×10, vMax×10, iAvg×1000, iMax×1000, pAvg×10, pMin×10, pMax×10, pf×100, (Hz−40)×10, runtimeSec, samples, flags]` (`flags` บิตที่ 0 = แอร์ทำงาน) หนึ่งรายการ = ช่วง 5 นาที (`HISTORY_INTERVAL_SECONDS = 300`) ใช้จำนวนเต็มเพื่อให้ JSON เล็กและบอร์ดไม่ต้องจัดรูปทศนิยม รายการที่ผิดรูป (ไม่ใช่อาร์เรย์ยาว ≥ 15, ไม่ใช่ตัวเลข, `ts ≤ 0` หรือ `samples = 0`) ถูกนับเป็น `invalid`

`buildHistoryDelta` แปลงรายการเป็นค่าที่ต้องบวกเข้าถัง: ถังคือชั่วโมงของ `ts − 1 วินาที` (ช่วงปลายเปิด: รายการ `ts = 11:00` เป็นของช่วง 10:55–11:00 จึงลงถัง 10:00) ผลรวมคำนวณจาก `ค่าเฉลี่ย × samples`, เวลาทำงานใช้ค่าที่บอร์ดนับเองแต่ไม่เกินช่วงตั้งแต่จุดต่อ (กันนับซ้อนกับข้อมูลสดก่อนเน็ตหลุด), `onlineSeconds = 0` เพราะช่วงนั้นบอร์ดต่อเซิร์ฟเวอร์ไม่ได้ ส่วนพลังงานคิดจากผลต่างเลขมิเตอร์เหมือนข้อมูลสด `recordHistoryBatch` เรียงรายการตามเวลาแล้วประมวลผลต่อเนื่อง เลื่อนจุดต่อไปทีละรายการ ทั้งชุดอยู่ใน transaction เดียว

### ค่าไฟ (บาท) และอัตรา

ฐานข้อมูล **ไม่เก็บค่าเงิน** เก็บแค่ `consumption_kwh` ค่าไฟโดยประมาณ = `SUM(consumption_kwh) × rate` คูณหลัง query เสร็จใน `routes/energy.js` (เมทริก `cost` มี `costFactor: true`) `rate` มาจาก query ของผู้เรียก (`normalizeRate`: ต้องเป็นตัวเลข > 0 และ ≤ 100 ไม่งั้นเป็น 0 ปัดเป็น 4 ตำแหน่ง) ค่าตั้งกลางคือ `system_settings.electricity_rate` ค่าเริ่มต้น **4.50 บาท/kWh** ขอบเขต 0.01–100 แอปอ่านผ่าน `GET /api/settings` แล้วส่งเป็น `rate` ตามไปกับคำขอรายงาน

### รายงาน สรุป และส่งออก Excel

`METRIC_CATALOG` มี 16 ค่า (`consumption`, `cost`, `powerAvg`, `powerMax`, `powerMin`, `voltageAvg`, `voltageMin`, `voltageMax`, `currentAvg`, `currentMax`, `powerFactorAvg`, `frequencyAvg`, `energyMeter`, `runtimeMinutes`, `onlineMinutes`, `sampleCount`) แต่ละค่ามี `inner` (นิพจน์ SQL ต่อแถวถัง), `group` (วิธีรวม `SUM`/`AVG`/`MIN`/`MAX`), `detailOnly` (โชว์เฉพาะโหมดรายละเอียดสูง), `default` (ค่าเริ่มต้นคือ `consumption` อย่างเดียว) เพิ่มค่าใหม่ที่ Backend ที่เดียวแล้วแอปเห็นผ่าน `GET /api/energy/metrics` ทันที

`buildHistorySql(query)` สร้าง SQL **สองชั้น** ชั้นในสรุปต่อ (เครื่อง × ชั่วโมง) ก่อน ชั้นนอกจึงรวมตามระดับที่เลือก (`building`, `room`, `device`) ถ้ารวมทีเดียว ค่าเฉลี่ยของหลายเครื่องจะเพี้ยน (เครื่องที่ส่งข้อมูล 100 ครั้งมีน้ำหนักเท่ากับเครื่องที่ส่ง 1,800 ครั้ง) ชื่อคอลัมน์ทุกตัวมาจากแคตตาล็อกในโค้ด ไม่ใช่จากผู้ใช้ ส่วนค่าที่ผู้ใช้กรอก (ช่วงวัน ห้อง เครื่อง) ถูกส่งเป็นพารามิเตอร์ `?` ทั้งหมด จึงกัน SQL injection `LIMIT 20000` แถว เวลา `bucket_start` ส่งออกเป็นข้อความด้วย `DATE_FORMAT(..., '%Y-%m-%d %H:%i:%s')` ไม่ให้ไดรเวอร์แปลงเป็น `Date` เพราะถ้า timezone ของ Node กับ MariaDB ไม่ตรงกัน ชั่วโมงจะเลื่อนโดยไม่มี error ใด ๆ

`normalizeQuery` ตรวจ input จากหน้าจอ: `scope` ที่ไม่รู้จักใช้ `building`; `detail` ค่าเริ่มต้น `summary` สำหรับ `building` นอกนั้น `high`; วันที่ต้อง `YYYY-MM-DD`, `from ≤ to`, ช่วงไม่เกิน 366 วัน; รายการห้อง/เครื่องไม่เกิน 200 รายการ รายการละไม่เกิน 64 ตัวอักษร

`resolvePeriod` สำหรับหน้าหลัก: `day` = 1 วัน, `week` = 7 วันล่าสุดรวมวันนี้, `month` = 30 วันล่าสุด, `custom` = ที่ผู้ใช้เลือก (ค่าเริ่มต้นถ้า period ไม่รู้จักคือ `week`) พร้อมช่วงก่อนหน้าที่ยาวเท่ากัน (`previousFrom`/`previousTo`) ไว้คำนวณ `changePercent` (คืน `null` ถ้าช่วงก่อนหน้าเป็น 0 เพราะเทียบไม่ได้) ช่วงวันเดียวดูเป็นรายชั่วโมง (24 จุด) ยาวกว่านั้นดูเป็นรายวัน `fillSeries` เติมจุดที่ไม่มีข้อมูลเป็น 0 กราฟจะไม่ขาดเป็นช่วง ๆ

ส่งออก Excel: `GET /api/energy/export` → `normalizeQuery` → `runHistoryQuery` → ถ้าไม่มีแถว ตอบ 404 → `buildExportSheet` (หัวตารางสองคอลัมน์แรกชื่อ `data` และ `time` ตรงกับไฟล์ตัวอย่างที่ผู้ใช้เดิมใช้ ตามด้วย ห้อง/เครื่อง/Device ID ตามระดับ แล้วตามด้วยเมทริกที่เลือก แต่ละหัวต่อท้ายหน่วย เช่น `พลังงานที่ใช้/kWh`) → `buildXlsx` → ส่งเป็น `Content-Disposition: attachment` ชื่อไฟล์ไทยส่งผ่าน `filename*=UTF-8''...` (header ของ HTTP รับเฉพาะอักษรละติน) และ `X-Export-Rows` บอกจำนวนแถว

## เจาะโค้ดทีละบรรทัด

### จุดที่ 1: ต่อ Broker และ subscribe (`services/mqtt.js`)

**ไฟล์ `backend/src/services/mqtt.js` บรรทัด 92–117**

```js:92
  client = mqtt.connect(config.mqtt.url, {
    username: config.mqtt.username || undefined,
    password: config.mqtt.password || undefined,
    reconnectPeriod: 3000,
    clean: true,
    clientId: `rmutt-api-${process.pid}`,
  });

  client.on('connect', () => {
    bridgeStatus.connected = true;
    bridgeStatus.connectedAt = new Date().toISOString();
    bridgeStatus.lastError = null;
    client.subscribe([
      `${config.mqtt.topicPrefix}/+/state`,
      `${config.mqtt.topicPrefix}/+/status`,
      `${config.mqtt.topicPrefix}/+/provision`,
      `${config.mqtt.topicPrefix}/+/history`,
      `${config.mqtt.occupancyTopicPrefix}/+/status`,
      `${config.mqtt.occupancyTopicPrefix}/+/provision`,
    ], { qos: 1 });
    if (config.mqtt.deviceAuth === 'dynsec') {
      client.subscribe(DYNSEC_RESPONSE_TOPIC, { qos: 1 });
    }
    console.log('MQTT bridge connected');
    notify(connectedListeners, {});
  });
```

| บรรทัด | โค้ด/คำสั่ง | ความหมาย |
|---|---|---|
| 92 | `client = mqtt.connect(url, {...})` | สร้าง client (ไลบรารี `mqtt`) และเริ่มต่อ Broker ทันที `client` เป็นตัวแปรระดับโมดูล (`let client;`) ให้ฟังก์ชัน publish ทุกตัวใช้ร่วมกัน |
| 93–94 | `config.mqtt.username \|\| undefined` | `\|\|` คืนค่าด้านขวาเมื่อด้านซ้ายเป็นค่า "เท็จ" รวมสตริงว่าง จึงได้ `undefined` = ไม่ส่งชื่อผู้ใช้ (ใช้ตอน dev ที่ Broker ไม่มี auth) |
| 95 | `reconnectPeriod: 3000` | หลุดแล้วไลบรารีต่อใหม่เองทุก 3 วินาที ไม่ต้องเขียนลูป retry เอง |
| 96 | `clean: true` | ทุกครั้งที่ต่อ Broker ถือเป็น session ใหม่ ไม่จำการ subscribe เก่า ดังนั้นต้อง subscribe ใหม่ทุกครั้งที่ต่อติด (บรรทัด 104) |
| 97 | ``clientId: `rmutt-api-${process.pid}` `` | client id ต้องไม่ซ้ำ ถ้าสองโปรเซสใช้ id เดียวกัน Broker จะเตะตัวเก่าออก แล้วทั้งคู่จะเตะกันวนไป |
| 100 | `client.on('connect', () => {...})` | ลงทะเบียน callback ที่ถูกเรียก **ทุกครั้ง** ที่ต่อติด รวมตอนต่อใหม่หลังหลุด (นี่คือเหตุผลที่ subscribe อยู่ในนี้ ไม่ใช่นอก callback) |
| 101–103 | `bridgeStatus.connected = true` ฯลฯ | เก็บสถานะให้ `getMqttBridgeStatus()` รายงานในหน้า health |
| 104–111 | `client.subscribe([...], { qos: 1 })` | สมัครรับ 6 topic ในคำสั่งเดียว `${prefix}/+/state` ฯลฯ ใช้ template literal `${...}` แทรกค่า; `+` แทนรหัสอุปกรณ์ทุกตัว |
| 112–114 | `if (config.mqtt.deviceAuth === 'dynsec')` | สมัครรับ topic ตอบกลับของ Dynamic Security เฉพาะโหมดบัญชีรายบอร์ด |
| 116 | `notify(connectedListeners, {})` | แจ้งคนที่รอ "ต่อสำเร็จ" (ตอนนี้คือ `mqtt-accounts` ที่จะไปสร้างบัญชีบอร์ด) ทำหลัง subscribe เพื่อให้ response ของ Dynamic Security มีคนรอรับแล้ว |

ต่อจากนั้น บรรทัด 118–133 คือตัวรับข้อความและการจัดการความผิดพลาด

```js:118
  client.on('message', (topic, payload) => {
    if (topic === DYNSEC_RESPONSE_TOPIC) {
      handleDynsecResponse(payload);
      return;
    }
    handleIncomingMessage(topic, payload).catch((error) => {
      console.error('MQTT message failed', error);
    });
  });
  client.on('error', (error) => {
    bridgeStatus.lastError = error.message;
    console.error('MQTT bridge error', error.message);
  });
  client.on('offline', markDisconnected);
  client.on('close', markDisconnected);
}
```

- **บรรทัด 119–122:** ข้อความจาก topic ของ Dynamic Security แยกออกไปทาง `handleDynsecResponse` แล้ว `return` ก่อน ไม่ผ่านตัวแยก topic ของบอร์ด
- **บรรทัด 123–125:** `handleIncomingMessage(...)` เป็นฟังก์ชัน `async` จึงคืน Promise `.catch(...)` ดักความผิดพลาดไว้ ถ้าไม่ดัก ข้อความหนึ่งที่พัง (เช่น DB ล่มชั่วคราว) จะเป็น unhandled rejection ซึ่งใน Node รุ่นใหม่ทำให้โปรเซสหยุด
- **บรรทัด 127–130:** `error` เก็บข้อความล่าสุดไว้ดูใน health ส่วน `offline` กับ `close` เรียก `markDisconnected` ซึ่งเก็บเวลาที่หลุดครั้งล่าสุด (เฉพาะตอนที่เคยต่อติดอยู่)

### จุดที่ 2: handler ของ status และเหตุผลที่ "อ่านค่าเดิมก่อน" (`services/mqtt.js`)

**ไฟล์ `backend/src/services/mqtt.js` บรรทัด 410–441**

```js:410
  const [, deviceId, type] = match;
  if (type === 'status' && consumeUnprovisionAck(deviceId, message)) return;
  if (type === 'provision') {
    await activateProvisioning(deviceId, message);
    return;
  }
  if (type === 'state') {
    await pool.query(
      `UPDATE air_conditioners
          SET state_json = ?,
              is_online = 1,
              last_seen_at = CURRENT_TIMESTAMP
        WHERE device_id = ?`,
      [JSON.stringify(message.state ?? message), deviceId],
    );
    return;
  }

  if (type === 'history') {
    await runSerialForDevice(
      deviceId,
      () => handleAirHistory(deviceId, message),
    );
    return;
  }

  const statusProtocol = protocolFromStatus(message);
  await runSerialForDevice(deviceId, async () => {
    if (statusProtocol) await syncControlProtocol(deviceId, statusProtocol);
    await handleAirStatus(deviceId, normalizePowerStatus(message));
  });
}
```

| บรรทัด | โค้ด/คำสั่ง | ความหมาย |
|---|---|---|
| 410 | `const [, deviceId, type] = match;` | destructuring ของผล regex: ช่องแรก (`match[0]` = ข้อความทั้งก้อน) ข้ามด้วยเครื่องหมายจุลภาคเปล่า เก็บ `deviceId` และ `type` |
| 411 | `consumeUnprovisionAck(deviceId, message)` | ถ้าข้อความ `status` นี้คือคำตอบ `{"unprovisioned":true}` ของบอร์ดที่กำลังถูกลบ ให้ปลุกตัวที่รออยู่ใน `unprovisionDevice` แล้ว `return` ทันที ไม่บันทึกลงฐานข้อมูล (แถวถูกลบไปแล้ว และคำตอบนี้มี `online:false` ซึ่งถ้าปล่อยผ่านจะถูกตีความเป็นสถานะออฟไลน์) |
| 412–415 | `type === 'provision'` | ข้อความติดตั้งอุปกรณ์ ไปทางของมัน แล้ว `return` |
| 416–426 | `type === 'state'` | `state` = สถานะคำสั่งที่บอร์ดรับไว้ (อุณหภูมิ โหมด ฯลฯ) เขียนลง `state_json` ตรง ๆ และตั้ง `is_online = 1`; `message.state ?? message` คือ "ใช้ `message.state` ถ้ามี ไม่งั้นใช้ทั้งก้อน" (`??` ตรวจเฉพาะ null/undefined) |
| 428–434 | `type === 'history'` | ข้อมูลย้อนหลัง ห่อด้วย `runSerialForDevice` เพื่อให้ทำทีละงานต่อบอร์ด |
| 436 | `protocolFromStatus(message)` | ถ้า status มี `controlMode: "wired"` ได้ `'DAIKIN_WIRED'` นอกนั้นได้ `null` |
| 437–440 | `runSerialForDevice(deviceId, async () => {...})` | status (ข้อความที่เหลือ) ทำในคิวของบอร์ดตัวนี้ ขั้นแรกแก้ `protocol` ในฐานข้อมูลถ้าจำเป็น (`syncControlProtocol`) แล้วค่อย `handleAirStatus` ซึ่งรับค่าที่ผ่าน `normalizePowerStatus` แล้ว (ฟิลด์ที่ไม่น่าเชื่อถือกลายเป็น `null`/`false` อย่างปลอดภัย) |

**ไฟล์ `backend/src/services/mqtt.js` บรรทัด 443–456**

```js:443
// บอร์ดรุ่นสายแอร์ยืนยันชนิดตัวเองทุกครั้งที่ส่ง status
// แก้เฉพาะแถวที่ยังไม่ตรง จึงไม่เขียนฐานข้อมูลซ้ำทุก 10 วินาที
async function syncControlProtocol(deviceId, protocol) {
  const result = await pool.query(
    `UPDATE air_conditioners
        SET protocol = ?
      WHERE device_id = ?
        AND protocol <> ?`,
    [protocol, deviceId, protocol],
  );
  if (Number(result?.affectedRows ?? 0) > 0) {
    console.log(`[air] ${deviceId} เป็นบอร์ดสายแอร์ ปรับ protocol เป็น ${protocol}`);
  }
}
```

| บรรทัด | ความหมาย |
|---|---|
| 443–444 | คอมเมนต์บอกเหตุผล: บอร์ดสายแอร์ส่ง `controlMode: "wired"` มาทุก status (ราว 10 วินาที) |
| 447–450 | `UPDATE ... WHERE device_id = ? AND protocol <> ?` เงื่อนไข `protocol <> ?` ทำให้ถ้าค่าตรงอยู่แล้ว ฐานข้อมูลไม่ต้องเขียนอะไร (`affectedRows = 0`) จึงไม่มีการเขียนซ้ำทุก 10 วินาที |
| 451 | ค่า `protocol` ใส่สองครั้งเพราะมี `?` สองตัวที่ต้องการค่าเดียวกัน (ตัวที่ตั้งค่า และตัวที่เทียบ) |
| 453–455 | log เฉพาะครั้งที่แก้จริง ใช้ตรวจย้อนหลังว่าบอร์ดไหนถูกแก้ protocol เมื่อไร |

> [!WHY]
> ทำไมต้องแก้ protocol ให้เอง: แอปรุ่นเก่าที่ยังไม่รู้จักบอร์ดสายแอร์อาจจองบอร์ดด้วยยี่ห้อ IR (เช่น `DAIKIN`) ถ้าปล่อยไว้ Backend จะตรวจคำสั่งตามกติกาของรีโมต IR (ยอมให้ Turbo, Heat, Swing หลายตำแหน่ง) ซึ่งแอร์จริงทำไม่ได้ และหน้าเฟิร์มแวร์จะยอมสั่งไฟล์ IR ให้บอร์ดสายแอร์ บอร์ดเป็นผู้รู้ดีที่สุดว่าตัวเองต่อแบบไหน จึงให้คำบอกของบอร์ดเป็นความจริงสุดท้าย ทำแค่ทิศเดียว (ไป `DAIKIN_WIRED`) ไม่เปลี่ยนกลับ เพราะบอร์ด IR ไม่ส่ง `controlMode` ที่บอกว่าเป็นสายแอร์

> [!WHY]
> `runSerialForDevice` สำคัญเพราะ status สด (ทุก 10 วินาที) กับข้อมูลย้อนหลังของบอร์ดตัวเดียวกันอาจเข้ามาเกือบพร้อมกัน ทั้งคู่อ่านและเขียน "จุดต่อ" เดียวกัน ถ้าปล่อยให้ทำพร้อมกันอาจอ่านจุดต่อเดิมคู่กัน แล้วนับพลังงานช่วงเดียวกันสองรอบ คิวต่อบอร์ดทำให้ทีละงานโดยบอร์ดต่างตัวยังทำขนานกันได้

**ไฟล์ `backend/src/services/mqtt.js` บรรทัด 458–484**

```js:458
async function handleAirStatus(deviceId, status) {
  // อ่านค่าเดิมก่อนทับ เพื่อหาผลต่างของเลขมิเตอร์กับเวลาที่แอร์ทำงานจริง
  // แล้วค่อยบันทึกลงถังรายชั่วโมง ถ้าขั้นตอนนี้พังจะไม่ทำให้ค่าล่าสุดหาย
  const previous = await readPreviousAirRow(deviceId);
  // บอร์ดยังส่งข้อมูลช่วงเน็ตหลุดไม่ครบ ห้ามบันทึกค่าสด ไม่งั้นนับซ้ำ
  if (previous && status.historyPending === 0) {
    try {
      await recordEnergySample({
        deviceId,
        roomNumber: previous.room_number,
        deviceName: previous.name,
        previous: {
          energyKwh: previous.energy_kwh,
          acRunning: Boolean(previous.ac_running),
          isOnline: Boolean(previous.is_online),
          lastSeenAt: previous.last_seen_at,
          chainEnergyKwh: previous.energy_chain_kwh,
          chainAt: previous.energy_chain_at,
          chainRunning: previous.energy_chain_running,
        },
        status,
        now: new Date(),
      });
    } catch (error) {
      console.error('บันทึกค่าไฟรายชั่วโมงไม่สำเร็จ', error.message);
    }
  }
```

| บรรทัด | โค้ด/คำสั่ง | ความหมาย |
|---|---|---|
| 461 | `const previous = await readPreviousAirRow(deviceId);` | **อ่านแถวเดิมก่อนเขียนอะไรทั้งสิ้น** ได้เลขมิเตอร์ล่าสุด เวลาที่เห็นล่าสุด สถานะแอร์ และสถานะออนไลน์ ซึ่งคำนวณผลต่างต้องใช้ทั้งหมด |
| 463 | `if (previous && status.historyPending === 0)` | บันทึกค่าไฟเฉพาะเมื่อ (1) มีแถวเครื่องนี้ในระบบ และ (2) บอร์ดไม่เหลือข้อมูลย้อนหลังค้างส่ง ถ้ายังค้างต้องรอ ไม่งั้นนับซ้ำ |
| 464–480 | `await recordEnergySample({... previous: {...}, status, now })` | ส่งค่าเดิม (`previous`) กับค่าใหม่ (`status`) เข้าไปให้ตัวคำนวณ ฟิลด์ `chain*` คือ "จุดต่อ" ซึ่งอาจเป็น `undefined` ในฐานข้อมูลที่ยังไม่ migrate |
| 481–483 | `catch (error) { console.error(...) }` | ถ้าบันทึกค่าไฟพัง ได้แค่ log ไม่โยนต่อ เพราะการเขียนสถานะล่าสุด (บรรทัด 486) สำคัญกว่าและต้องเกิดเสมอ |

หลังบรรทัด 484 โค้ดทำต่อดังนี้ (ไม่ได้ยกมาทั้งหมด): `UPDATE air_conditioners` เขียนแรงดัน กระแส กำลังไฟ เลขมิเตอร์ ความถี่ PF `pzem_available`, `ac_running`, `outside_schedule`, `is_online`, `last_seen_at` (บรรทัด 486–513) → `recordFirmwareStatus` (รุ่นเฟิร์มแวร์/ผล OTA แยกเป็นอีกคำสั่งเพื่อไม่ให้สถานะหลักพังตอน DB ยังไม่ migrate) → `recordHistoryPending` → ถ้า `status.online` เรียก `publishScheduleEvaluation` (ส่ง `schedule-status` แบบ retained บอกบอร์ดว่าอยู่ในคาบหรือไม่) → `notify(airStatusListeners, ...)` ปลุกระบบปิดแอร์ให้ประเมินเครื่องนี้ทันที (บรรทัด 517–521)

> [!WARN]
> `readPreviousAirRow` (บรรทัด 525) ดัก `ER_BAD_FIELD_ERROR` แล้วอ่านใหม่แบบไม่มีคอลัมน์ `energy_chain_*` เพราะคอลัมน์เหล่านี้มาในรุ่น 3.15 ถ้า Backend ใหม่ขึ้นแล้วแต่ยังไม่ได้รัน migration ระบบต้องไม่ล้ม รูปแบบ "ถอยไปใช้แบบเดิมเมื่อสคีมายังไม่พร้อม" พบซ้ำหลายที่ (`recordHistoryPending`, `recordFirmwareStatus`, `saveChain`, `readTodayBookings`, `readTerms`)

### จุดที่ 3: ตัวตัดสินใจปิดแอร์ (`utils/auto-off.js`)

**ไฟล์ `backend/src/utils/auto-off.js` บรรทัด 29–56**

```js:29
export function decideAutoOff({ device, occupancy, withinClass, now }) {
  const current = now instanceof Date ? now : new Date(now);
  const counting = device?.autoOffDeadlineAt != null;
  const attempts = Number(device?.autoOffAttempts ?? 0);

  const sensorUsable = occupancy?.hasSensor === true
    && occupancy?.online === true
    && occupancy?.radarAvailable === true;

  // ไม่มีเซ็นเซอร์ที่เชื่อถือได้ = ไม่รู้ว่ามีคนไหม จึงไม่ปิดให้เด็ดขาด
  if (device?.autoOffEnabled !== true || !sensorUsable) {
    return counting
      ? { action: 'cancel', reason: sensorUsable ? 'disabled' : 'noSensor' }
      : { action: 'idle', reason: sensorUsable ? 'disabled' : 'noSensor' };
  }

  // PZEM ต้องอ่านค่าได้ ไม่งั้นเราตรวจไม่ได้ว่าแอร์หยุดจริงหรือยัง
  if (device?.pzemAvailable !== true) {
    return counting
      ? { action: 'cancel', reason: 'noPzem' }
      : { action: 'idle', reason: 'noPzem' };
  }

  if (occupancy.occupied === true) {
    return counting
      ? { action: 'cancel', reason: 'occupied' }
      : { action: 'idle', reason: 'occupied' };
  }
```

| บรรทัด | โค้ด/คำสั่ง | ความหมาย |
|---|---|---|
| 29 | `export function decideAutoOff({ device, occupancy, withinClass, now })` | รับอ็อบเจกต์เดียวแล้ว destructure เป็นสี่ตัวแปร เรียกด้วยชื่อ ไม่ต้องจำลำดับพารามิเตอร์ |
| 30 | `now instanceof Date ? now : new Date(now)` | ยอมรับทั้ง `Date` และตัวเลข/สตริงเวลา |
| 31 | `device?.autoOffDeadlineAt != null` | `?.` (optional chaining) = ถ้า `device` เป็น null/undefined ให้ได้ `undefined` แทนที่จะ error; `!= null` (เท่ากับหลวม) ครอบทั้ง `null` และ `undefined` ได้ `counting = true` เมื่อมีนาฬิกาเดินอยู่ |
| 32 | `Number(device?.autoOffAttempts ?? 0)` | จำนวนครั้งที่ยิงไปแล้ว ค่าไม่มี = 0 |
| 34–36 | `sensorUsable = hasSensor === true && online === true && radarAvailable === true` | ใช้ `=== true` ไม่ใช่แค่ truthy: `1`, `"yes"`, `undefined` จะไม่ผ่าน ต้องเป็น boolean จริงเท่านั้น |
| 39 | `autoOffEnabled !== true \|\| !sensorUsable` | ด่าน 1 `!== true` ทำให้ค่าที่หาย/แปลกตกเป็น "ปิด" (fail-safe) |
| 40–42 | `return counting ? {cancel...} : {idle...}` | รูปแบบที่ซ้ำทุกด่าน: ถ้ากำลังนับอยู่ต้อง `cancel` เพื่อล้างนาฬิกาที่ค้าง ถ้าไม่ได้นับก็ `idle` เฉย ๆ |
| 46–50 | `pzemAvailable !== true` | ด่าน 2 |
| 52–56 | `occupancy.occupied === true` | ด่าน 3 บรรทัด 52 เข้าถึง `occupancy.occupied` ตรง ๆ ได้โดยไม่ต้อง `?.` เพราะผ่านด่าน 1 มาแล้ว `sensorUsable` จริง แปลว่า `occupancy` เป็นอ็อบเจกต์แน่นอน |

**ไฟล์ `backend/src/utils/auto-off.js` บรรทัด 58–79**

```js:58
  if (device?.acRunning !== true) {
    if (counting && attempts > 0) {
      return { action: 'succeeded', reason: 'powerDropped', attempts };
    }
    return counting
      ? { action: 'cancel', reason: 'notRunning' }
      : { action: 'idle', reason: 'notRunning' };
  }

  // ถึงตรงนี้: แอร์ทำงานอยู่ ห้องว่าง เซ็นเซอร์เชื่อถือได้
  if (!counting) {
    const graceSeconds = withinClass === true
      ? AUTO_OFF_IN_CLASS_SECONDS
      : AUTO_OFF_IDLE_SECONDS;
    return {
      action: 'start',
      reason: 'emptyRoom',
      graceSeconds,
      withinClass: withinClass === true,
      deadlineAt: new Date(current.getTime() + graceSeconds * 1000),
    };
  }
```

| บรรทัด | ความหมาย |
|---|---|
| 58 | ด่าน 4: แอร์ไม่ได้กินไฟแล้ว |
| 59–61 | ถ้ากำลังนับและเคยยิงแล้ว (`attempts > 0`) แปลว่าคำสั่งของเราได้ผล → `succeeded` พร้อมเหตุผล `powerDropped` |
| 62–64 | ไม่งั้น แอร์ดับไปเองก่อนที่เราสั่ง (หรือไม่เคยเดิน) → ไม่ใช่ผลงานของระบบ แค่ `cancel`/`idle` เงียบ ๆ |
| 68–79 | ถึงตรงนี้แอร์เดินอยู่ ห้องว่าง เซ็นเซอร์ดี ถ้ายังไม่ได้นับก็เริ่ม: เลือก `graceSeconds` 900 หากอยู่ในคาบ (`withinClass === true`) ไม่งั้น 300 แล้วคืน `start` พร้อม `deadlineAt` (`current.getTime() + graceSeconds * 1000` เพราะ `getTime()` ให้มิลลิวินาที) |

**ไฟล์ `backend/src/utils/auto-off.js` บรรทัด 81–111**

```js:81
  const deadline = toDate(device.autoOffDeadlineAt);
  if (deadline == null) {
    return { action: 'cancel', reason: 'badDeadline' };
  }

  if (current.getTime() < deadline.getTime()) {
    return {
      action: 'wait',
      reason: 'countdown',
      secondsRemaining: secondsBetween(current, deadline),
    };
  }

  if (attempts >= AUTO_OFF_MAX_ATTEMPTS) {
    return { action: 'giveUp', reason: 'stillRunning', attempts };
  }

  const lastAttempt = toDate(device.autoOffLastAttemptAt);
  if (lastAttempt != null) {
    const elapsed = (current.getTime() - lastAttempt.getTime()) / 1000;
    if (elapsed < AUTO_OFF_RETRY_SECONDS) {
      return {
        action: 'wait',
        reason: 'retryCooldown',
        secondsRemaining: Math.ceil(AUTO_OFF_RETRY_SECONDS - elapsed),
      };
    }
  }

  return { action: 'fire', reason: 'deadlinePassed', attempt: attempts + 1 };
}
```

| บรรทัด | ความหมาย |
|---|---|
| 81–84 | อ่าน deadline เป็น `Date` (ฟังก์ชัน `toDate` คืน null ถ้า parse ไม่ได้) ถ้าอ่านไม่ได้ `cancel` ด้วยเหตุผล `badDeadline` ดีกว่าปล่อยให้เทียบกับ `NaN` |
| 86–92 | ยังไม่ถึงเวลา → `wait` พร้อมวินาทีที่เหลือ (`Math.ceil` ปัดขึ้นเพื่อไม่ให้เห็น 0 ก่อนถึงเวลาจริง) |
| 94–96 | ยิงครบ `AUTO_OFF_MAX_ATTEMPTS` (5) → `giveUp` |
| 98–108 | ถ้าเคยยิงมาแล้ว เทียบเวลาจากครั้งล่าสุด ถ้าห่างไม่ถึง 20 วินาที (`AUTO_OFF_RETRY_SECONDS`) → `wait` แบบ `retryCooldown` |
| 110 | ผ่านทุกอย่างแล้ว → `fire` ครั้งที่ `attempts + 1` |

### จุดที่ 4: ตัวคุมจังหวะปิดแอร์ (`services/auto-off.js`)

**ไฟล์ `backend/src/services/auto-off.js` บรรทัด 33–43**

```js:33
export function startAutoOffService() {
  if (timer) return;
  unsubscribeAir = onAirStatus(({ deviceId }) => runEvaluation(deviceId));
  unsubscribeOccupancy = onOccupancyStatus(({ roomNumber }) => {
    if (roomNumber) runEvaluation(null, roomNumber);
  });
  // จับเวลาเองด้วย เพราะถ้าอุปกรณ์เงียบไปเฉย ๆ ก็ยังต้องยิงเมื่อครบกำหนด
  timer = setInterval(() => runEvaluation(), TICK_INTERVAL_MS);
  if (typeof timer.unref === 'function') timer.unref();
  console.log('Auto-off service started');
}
```

| บรรทัด | ความหมาย |
|---|---|
| 34 | `if (timer) return;` กันเรียก start ซ้ำ ไม่งั้นจะมี `setInterval` สองตัวซ้อนกัน |
| 35 | สมัคร `onAirStatus`: ได้ `{deviceId, roomNumber, status}` เลือกใช้เฉพาะ `deviceId` (destructuring ในพารามิเตอร์ `({ deviceId }) =>`) แล้วประเมินเครื่องนั้น ค่าที่คืนจาก `onAirStatus` คือฟังก์ชันยกเลิก เก็บไว้ใน `unsubscribeAir` |
| 36–38 | สมัคร `onOccupancyStatus`: ประเมินแอร์ทุกเครื่องของห้องที่เซ็นเซอร์รายงาน (ถ้ามี `roomNumber`) |
| 40 | `setInterval(() => runEvaluation(), TICK_INTERVAL_MS)` ประเมินทุกเครื่องทุก 10 วินาที |
| 41 | `timer.unref()` ไม่ให้ timer นี้ยื้อให้โปรเซสปิดไม่ลง (ตรวจ `typeof ... === 'function'` กันกรณีสภาพแวดล้อมไม่มีเมธอดนี้) |

**ไฟล์ `backend/src/services/auto-off.js` บรรทัด 69–97**

```js:69
  if (running) return [];
  running = true;
  let lockConnection = null;
  try {
    // กันกรณีมี Backend รันพร้อมกันเกินหนึ่งตัว (เช่นเผลอ scale หรือรันทดสอบ
    // บนเครื่องเดียวกับของจริง) ถ้าไม่กัน ทั้งสองตัวจะยิงคำสั่งปิดแอร์ซ้ำกัน
    // และนับจำนวนครั้งเพี้ยน ใช้ named lock ของ MariaDB ซึ่งผูกกับ connection
    lockConnection = await acquireRunnerLock();
    if (!lockConnection) return [];

    // สวิตช์รวมของแอดมิน ปิดแล้วต้องหยุดทั้งอาคารทันที
    // และต้องล้างนาฬิกาที่ค้างอยู่ด้วย ไม่งั้นแอปจะโชว์เวลานับถอยหลัง
    // ที่ไม่มีวันยิงจริง ซึ่งหลอกตาคนใช้
    if (!(await isAutoOffEnabled())) {
      await clearAllCountdowns();
      return [];
    }

    const devices = await readDevices({ deviceId, roomNumber });
    const results = [];
    for (const device of devices) {
      results.push(await evaluateDevice(device, now));
    }
    return results;
  } finally {
    await releaseRunnerLock(lockConnection);
    running = false;
  }
}
```

| บรรทัด | ความหมาย |
|---|---|
| 69–70 | `running` เป็นธง "กำลังทำงานอยู่" ถ้ารอบก่อนยังไม่เสร็จ คืน `[]` ทันที (ไม่ต่อคิว) แล้วตั้งธง |
| 76–77 | ขอ named lock ของ MariaDB (`GET_LOCK(name, 0)` รอ 0 วินาที) ถ้าได้ล็อกจะได้ connection ที่ถือล็อกไว้ ถ้าไม่ได้ (มี Backend อีกตัวทำอยู่) → ออกเฉย ๆ ล็อกผูกกับ connection จึงต้องถือ connection นี้ไว้ตลอดรอบและ `RELEASE_LOCK` ใน `finally` |
| 82–85 | สวิตช์รวมปิดอยู่ → ล้างนาฬิกาทุกเครื่องแล้วจบรอบ |
| 87–91 | `readDevices` ดึงแอร์ตามตัวกรอง (เครื่องเดียว/ห้องเดียว/ทั้งหมด) แล้วประเมินทีละเครื่อง `await` ในลูป `for...of` จึงทำเรียงลำดับ ไม่ขนาน (ตั้งใจ: ไม่ให้ยิงคำสั่งพร้อมกันหลายเครื่องจนเกิดภาระ MQTT/DB พุ่ง) |
| 93–96 | `finally` ทำเสมอ ไม่ว่าสำเร็จหรือ error: คืนล็อกและเคลียร์ธง `running` ถ้าลืมทำ รอบถัดไปจะไม่ทำงานอีกเลย |

**ไฟล์ `backend/src/services/auto-off.js` บรรทัด 244–269**

```js:244
async function fireOffCommand(row, attempt) {
  const state = { ...parseState(row.state_json), power: false };
  try {
    await publishAirCommand(row.device_id, state);
  } catch (error) {
    // Broker ยังไม่พร้อม ไม่นับเป็นครั้ง จะได้ลองใหม่รอบหน้า
    console.error(
      `สั่งปิดแอร์ ${row.device_id} ไม่สำเร็จ`,
      error.message,
    );
    return;
  }

  await pool.query(
    `UPDATE air_conditioners
        SET auto_off_attempts = ?,
            auto_off_last_attempt_at = CURRENT_TIMESTAMP,
            state_json = ?
      WHERE device_id = ?`,
    [attempt, JSON.stringify(state), row.device_id],
  );
  console.log(
    `ปิดแอร์อัตโนมัติ ${row.device_id} ห้อง ${row.room_number} `
    + `ครั้งที่ ${attempt}/${AUTO_OFF_MAX_ATTEMPTS}`,
  );
}
```

| บรรทัด | ความหมาย |
|---|---|
| 245 | เอา `state_json` เดิมของแอร์ (อุณหภูมิ โหมด พัดลม ฯลฯ) มา spread แล้วเขียนทับ `power: false` ได้คำสั่งที่ "เหมือนเดิมทุกอย่างแต่ปิด" ถ้าส่งแค่ `{power:false}` บอร์ดอาจรีเซ็ตค่าอื่นเป็นค่าเริ่มต้น |
| 246–255 | ส่งคำสั่งผ่าน MQTT ถ้า Broker ไม่พร้อม `publishAirCommand` โยน error (503) → log แล้ว `return` โดย **ไม่เขียนฐานข้อมูล** จึงไม่นับเป็นความพยายาม รอบหน้าลองใหม่ได้โดยไม่เสียโควตา 5 ครั้ง |
| 257–264 | ส่งสำเร็จจึงบันทึก `auto_off_attempts = ?`, `auto_off_last_attempt_at = CURRENT_TIMESTAMP` และ `state_json` ใหม่ |
| 265–268 | log ว่ายิงครั้งที่เท่าไรจากกี่ครั้ง |

### จุดที่ 5: คำนวณพลังงานเป็นผลต่าง (`utils/energy-history.js` + `services/energy-recorder.js`)

**ไฟล์ `backend/src/utils/energy-history.js` บรรทัด 275–285**

```js:275
export function energyDelta(previousKwh, currentKwh) {
  const previous = toNumber(previousKwh);
  const current = toNumber(currentKwh);
  if (current == null) return 0;
  if (previous == null) return 0;
  const delta = current - previous;
  if (!Number.isFinite(delta) || delta < 0) return 0;
  // ป้องกันค่าเพี้ยนจากสัญญาณรบกวน ไม่มีแอร์เครื่องเดียวกินเกิน 50 kWh ต่อรอบ
  if (delta > 50) return 0;
  return round(delta, 3);
}
```

| บรรทัด | ความหมาย |
|---|---|
| 276–277 | แปลงทั้งสองค่าเป็นตัวเลข (`toNumber` คืน `null` ถ้าว่างหรือไม่ใช่ตัวเลข) |
| 278–279 | ไม่มีค่าใดค่าหนึ่ง → 0 (ไม่รู้ผลต่าง ก็ไม่เดา) |
| 280 | `delta = current - previous` เลขมิเตอร์เป็นค่าสะสมที่เพิ่มขึ้นเรื่อย ๆ ผลต่างคือพลังงานที่ใช้ในช่วงนั้น |
| 281 | ติดลบ (มิเตอร์รีเซ็ต/บูตใหม่) หรือไม่ใช่ตัวเลข → 0 ถ้าปล่อยติดลบ ยอดรวมชั่วโมงนั้นจะติดลบ |
| 283 | เกิน 50 kWh ในครั้งเดียวถือเป็นค่าเพี้ยน (แอร์เครื่องเดียวกินไม่ถึงระดับนั้นภายในไม่กี่นาที) → 0 |
| 284 | `round(delta, 3)` ปัดเป็นทศนิยม 3 ตำแหน่งตรงกับความละเอียดของ PZEM |

**ไฟล์ `backend/src/utils/energy-history.js` บรรทัด 291–303 และ 308–331**

```js:291
export function elapsedSeconds(previousAt, now, cap = MAX_SAMPLE_GAP_SECONDS) {
  if (!previousAt) return 0;
  const previous = previousAt instanceof Date
    ? previousAt
    : new Date(previousAt);
  const current = now instanceof Date ? now : new Date(now);
  if (Number.isNaN(previous.getTime()) || Number.isNaN(current.getTime())) {
    return 0;
  }
  const seconds = (current.getTime() - previous.getTime()) / 1000;
  if (!Number.isFinite(seconds) || seconds <= 0) return 0;
  return Math.min(Math.round(seconds), cap);
}
```

```js:308
export function buildSampleDelta({ previous, status, now }) {
  const pzemAvailable = status?.pzemAvailable === true;
  const reading = pzemAvailable ? toNumber(status?.energyKwh) : null;
  const gap = elapsedSeconds(previous?.lastSeenAt, now);
  const wasRunning = previous?.acRunning === true;

  return {
    bucketStart: bangkokHourStart(now),
    sampleCount: 1,
    pzemSamples: pzemAvailable ? 1 : 0,
    runningSamples: status?.acRunning === true ? 1 : 0,
    consumptionKwh: pzemAvailable
      ? energyDelta(previous?.energyKwh, reading)
      : 0,
    energyReading: reading,
    voltage: pzemAvailable ? toNumber(status?.voltage) : null,
    current: pzemAvailable ? toNumber(status?.current) : null,
    power: pzemAvailable ? toNumber(status?.powerWatts) : null,
    powerFactor: pzemAvailable ? toNumber(status?.powerFactor) : null,
    frequency: pzemAvailable ? toNumber(status?.frequencyHz) : null,
    runtimeSeconds: wasRunning ? gap : 0,
    onlineSeconds: previous?.isOnline === true ? gap : 0,
  };
}
```

| บรรทัด | ความหมาย |
|---|---|
| 291–293 | `elapsedSeconds(previousAt, now, cap = 300)` พารามิเตอร์ที่สามมีค่าเริ่มต้น = `MAX_SAMPLE_GAP_SECONDS` |
| 292–301 | ไม่มีเวลาก่อนหน้า (292) / แปลงเป็นวันที่ไม่ได้ (297–299) / เวลาถอยหลังหรือเท่ากัน (`seconds <= 0`, 301) → 0 |
| 302 | `Math.min(Math.round(seconds), cap)` **เพดาน 300 วินาที** บอร์ดหายไป 3 ชั่วโมงแล้วกลับมาจะนับเวลาแค่ 5 นาที |
| 309–310 | `reading` เลขมิเตอร์ใหม่ ใช้เฉพาะเมื่อ `pzemAvailable === true` ไม่งั้น `null` |
| 311 | `gap` ช่วงเวลาที่ผ่านมาตั้งแต่เห็นบอร์ดครั้งก่อน |
| 312 | `wasRunning` ดูสถานะแอร์ของ **ตัวอย่างก่อนหน้า** |
| 315 | `bucketStart: bangkokHourStart(now)` ถังของชั่วโมงปัจจุบันตามเวลาไทย |
| 316–318 | นับตัวอย่าง: `sampleCount` เสมอ 1, `pzemSamples` 1 เฉพาะที่อ่านค่าได้, `runningSamples` 1 เมื่อแอร์ทำงานตอนนี้ (ใช้คำนวณเปอร์เซ็นต์การทำงานได้) |
| 319–321 | `consumptionKwh = energyDelta(previous.energyKwh, reading)` เฉพาะเมื่อ PZEM ใช้ได้ |
| 328–329 | `runtimeSeconds` = ช่วงเวลา ถ้าก่อนหน้านี้แอร์เดินอยู่; `onlineSeconds` = ช่วงเวลา ถ้าก่อนหน้านี้ออนไลน์ |

**ไฟล์ `backend/src/services/energy-recorder.js` บรรทัด 53–84**

```js:53
  if (!deviceId || !roomNumber) return null;

  const chain = chainFromRow(previous);
  const delta = buildSampleDelta({
    previous: {
      energyKwh: chain.energyKwh,
      acRunning: chain.acRunning,
      isOnline: previous?.isOnline === true,
      lastSeenAt: chain.at,
    },
    status,
    now,
  });
  if (!delta.bucketStart) return null;

  await upsertBucket(pool, {
    deviceId,
    roomNumber,
    deviceName,
    delta: sampleDeltaToBucket(delta, now),
  });
  await saveChain(pool, deviceId, {
    at: now,
    // ตอน PZEM อ่านไม่ได้ (หรือข้อความ offline) ต้องจำเลขมิเตอร์เดิมไว้
    // ไม่งั้นรอบถัดไปจะหาผลต่างไม่ได้และพลังงานช่วงนั้นหายไป
    energyKwh: status?.pzemAvailable === true && status?.energyKwh != null
      ? status.energyKwh
      : chain.energyKwh,
    acRunning: status?.acRunning === true,
  });
  return delta;
}
```

| บรรทัด | ความหมาย |
|---|---|
| 53 | ไม่มีรหัสอุปกรณ์หรือห้อง → ไม่บันทึก (คืน `null`) |
| 55 | `chainFromRow(previous)` เลือก "จุดต่อ" ถ้ามี ไม่งั้นใช้ค่าล่าสุดของแถว |
| 56–65 | คำนวณ `delta` โดยให้ `previous` เป็นจุดต่อ (เวลา เลขมิเตอร์ สถานะแอร์) |
| 66 | `bucketStart` เป็น null (เวลาเพี้ยน) → ไม่บันทึก |
| 68–73 | `upsertBucket(pool, ...)` บวกค่าเข้าถัง `sampleDeltaToBucket` แปลงตัวอย่างเดี่ยวให้อยู่ในรูป "ผลรวม" (min = max = ค่าเดียวกัน) เพื่อใช้คำสั่ง SQL ชุดเดียวกับข้อมูลย้อนหลัง |
| 74–82 | `saveChain` เลื่อนจุดต่อไปที่ตัวอย่างนี้ ถ้า PZEM อ่านไม่ได้ **จำเลขมิเตอร์เดิม** (`chain.energyKwh`) แทนที่จะใส่ `null` |
| 83 | คืน `delta` ให้ผู้เรียก (เทสต์ใช้ตรวจ) |

### จุดที่ 6: รายชื่อ topic ที่ต้องล้างตอนถอดอุปกรณ์ (`utils/mqtt-topics.js`)

**ไฟล์ `backend/src/utils/mqtt-topics.js` บรรทัด 1–26 (ทั้งไฟล์)**

```js:1
// Topic ที่ Backend/ESP32 ส่งแบบ retain ไว้บน Broker
// ต้องล้างทั้งหมดเมื่อนำอุปกรณ์ออกจากระบบ ไม่งั้นข้อความเก่าจะค้างอยู่บน
// Broker และย้อนกลับมาเมื่อเพิ่มอุปกรณ์รหัสเดิมอีกครั้ง

export const AIR_RETAINED_SUFFIXES = Object.freeze([
  'command',
  'state',
  'status',
  'provision',
  'provision-ack',
  'schedule-status',
]);

export const OCCUPANCY_RETAINED_SUFFIXES = Object.freeze([
  'command',
  'status',
  'provision',
  'provision-ack',
]);

export function retainedTopics(prefix, deviceId, suffixes) {
  const base = String(prefix ?? '').replace(/\/+$/, '');
  const device = String(deviceId ?? '').trim();
  if (!base || !device) return [];
  return suffixes.map((suffix) => `${base}/${device}/${suffix}`);
}
```

| บรรทัด | ความหมาย |
|---|---|
| 1–3 | คำอธิบาย: ข้อความ retained ค้างอยู่ที่ Broker จนกว่าจะมีคนสั่งล้าง ถ้าไม่ล้าง เมื่อเพิ่มอุปกรณ์รหัสเดิมกลับมา ข้อความเก่า (เช่น `provision-ack` ที่ใช้ไปแล้ว) จะโผล่มาทันที |
| 5 | `Object.freeze([...])` ทำให้อาร์เรย์แก้ไขไม่ได้ (กันโค้ดส่วนอื่นเผลอ `.push` แล้วเปลี่ยนรายการกลางทาง) |
| 6–11 | ส่วนท้าย topic ของแอร์ที่ถูกส่งแบบ retained: `command`, `state`, `status`, `provision`, `provision-ack`, `schedule-status` |
| 14–19 | ของเซ็นเซอร์คน (ไม่มี `state` และ `schedule-status`) |
| 21 | `retainedTopics(prefix, deviceId, suffixes)` |
| 22 | `String(prefix ?? '').replace(/\/+$/, '')` ตัด `/` ท้าย prefix ออก (`rmutt/ac/` กับ `rmutt/ac` ให้ผลเหมือนกัน) |
| 24 | prefix หรือรหัสอุปกรณ์ว่าง → คืน `[]` ไม่สร้าง topic ที่ผิดรูป เช่น `//command` ซึ่งอาจไปล้าง topic ของคนอื่น (มีเทสต์ใน `test/mqtt.test.js`) |
| 25 | `.map` ประกอบ topic ทีละตัว `clearRetained` ใน `mqtt.js` จะ publish `''` แบบ `retain: true` ไปที่ topic เหล่านี้ทีละตัว |

### จุดที่ 7: รหัสผ่านบอร์ดและ ACL (`utils/mqtt-accounts.js`)

**ไฟล์ `backend/src/utils/mqtt-accounts.js` บรรทัด 40–51**

```js:40
/**
 * รหัสผ่าน MQTT ของบอร์ดหนึ่งตัว คำนวณซ้ำได้เสมอจากความลับของเซิร์ฟเวอร์
 * ยาว 32 ตัว (ตัวอักษร base64url) พอดีกับที่ NVS ของ ESP32 เก็บได้สบาย ๆ
 */
export function deriveDevicePassword(secret, deviceId) {
  if (!secret) throw new Error('MQTT_DEVICE_SECRET is required');
  return crypto
    .createHmac('sha256', secret)
    .update(`mqtt-device:${String(deviceId).trim().toUpperCase()}`)
    .digest('base64url')
    .slice(0, 32);
}
```

| บรรทัด | ความหมาย |
|---|---|
| 45 | ไม่มีความลับ (`MQTT_DEVICE_SECRET` ว่าง) → โยน error ทันที ไม่ปล่อยให้สร้างรหัสผ่านที่เดาได้ (`config.js` บังคับให้ยาวอย่างน้อย 32 ตัวอักษรตอนเปิดโหมด `dynsec`) |
| 46–47 | `crypto.createHmac('sha256', secret)` HMAC = แฮชที่ผสมกุญแจลับ ผู้ที่ไม่รู้ความลับคำนวณไม่ได้แม้รู้อัลกอริทึมและรหัสอุปกรณ์ |
| 48 | `.update('mqtt-device:' + รหัสอุปกรณ์ตัวใหญ่ตัดช่องว่าง)` คำนำหน้า `mqtt-device:` คือ **domain separation** ถ้าความลับเดียวกันถูกใช้ทำสิ่งอื่นด้วย HMAC ของงานอื่นจะไม่ชนกับรหัสผ่านนี้ และ `trim().toUpperCase()` ทำให้รหัสอุปกรณ์พิมพ์ตัวเล็ก/ตัวใหญ่ให้รหัสผ่านเดียวกัน |
| 49 | `.digest('base64url')` ได้สตริงที่ใช้ตัวอักษร URL-safe (ไม่มี `+` `/` `=`) |
| 50 | `.slice(0, 32)` ตัดเหลือ 32 ตัวอักษร พอดีกับที่เก็บใน NVS ของ ESP32 |

> [!WHY]
> ทำไมคำนวณจาก HMAC แทนสุ่มแล้วเก็บในฐานข้อมูล: (1) ไม่ต้องมีที่เก็บรหัสผ่านบอร์ด ฐานข้อมูลรั่วก็ไม่ได้รหัสบอร์ด (2) คำนวณซ้ำได้เสมอ ตั้งค่าบอร์ดซ้ำกี่ครั้งก็ได้รหัสเดิม บอร์ดที่ออนไลน์อยู่จึงไม่หลุดเพราะรหัสถูกเปลี่ยนกลางทาง (3) ถ้าไฟล์ Dynamic Security ของ Broker หาย สร้างบัญชีใหม่ให้ตรงของเดิมได้ทั้งหมด ข้อเสียคือถ้า `MQTT_DEVICE_SECRET` รั่ว ต้องเปลี่ยนความลับแล้วตั้งค่าทุกบอร์ดใหม่ ซึ่งชุด "ซ่อม" (`repairDeviceCommands`) ทำได้เมื่อจองบอร์ดอีกครั้ง

**ไฟล์ `backend/src/utils/mqtt-accounts.js` บรรทัด 20–33 และ 113–139**

```js:20
export const DEVICE_KINDS = {
  air: {
    pattern: /^ESP32-[0-9A-F]{12}$/,
    clientIdPrefix: 'rmutt-',
    publish: ['state', 'status', 'provision', 'provision-ack', 'history'],
    subscribe: ['command', 'provision-ack', 'schedule-status', 'history-ack'],
  },
  occupancy: {
    pattern: /^OCC32-[0-9A-F]{12}$/,
    clientIdPrefix: 'rmutt-occ-',
    publish: ['status', 'provision', 'provision-ack'],
    subscribe: ['command', 'provision-ack'],
  },
};
```

```js:113
  const spec = DEVICE_KINDS[kind];
  const rolename = deviceRoleName(deviceId);
  const acls = deviceAcls({ kind, topicPrefix, deviceId });
  return [
    {
      command: 'createRole',
      rolename,
      textname: `${kind} ${deviceId}`,
      acls,
    },
    // role ที่มีอยู่แล้วจาก Backend รุ่นก่อนอาจมี ACL ไม่ครบ เติมให้ครบทุกครั้ง
    // (ACL ที่มีอยู่แล้วตอบ error "already exists" และไม่เตะใครหลุด)
    ...acls.map((acl) => ({
      command: 'addRoleACL',
      rolename,
      ...acl,
    })),
    {
      command: 'createClient',
      username: deviceId,
      password,
      clientid: `${spec.clientIdPrefix}${deviceId}`,
      textname: `${kind} ${deviceId}`,
      roles: [{ rolename }],
    },
  ];
}
```

| บรรทัด | ความหมาย |
|---|---|
| 20–33 | ตารางสเปกต่อชนิด: `pattern` ตรวจรูปแบบรหัส, `publish` = topic ที่บอร์ดมีสิทธิ์ส่ง, `subscribe` = topic ที่มีสิทธิ์รับ (ส่วนท้ายหลังรหัสอุปกรณ์) |
| 113–115 | หา `spec`, ชื่อ role (`device-ESP32-...`) และ ACL ของบอร์ดนี้ |
| 116–122 | คำสั่งที่ 1 `createRole` สร้าง role พร้อม ACL ทั้งชุด |
| 123–129 | คำสั่ง `addRoleACL` ทีละข้อ ซ้ำกับคำสั่งที่ 1 โดยตั้งใจ: role ที่มีมาก่อนจาก Backend รุ่นเก่าอาจมี ACL ไม่ครบ ข้อที่มีแล้วจะตอบ "already exists" ซึ่งถือว่าไม่เป็นไร (idempotent) |
| 130–137 | คำสั่งสุดท้าย `createClient` สร้างบัญชีผู้ใช้ (username = รหัสอุปกรณ์, password = HMAC, client id = `rmutt-<รหัส>`) แล้วผูกกับ role ข้างบน |

บอร์ดที่ต่อด้วย username อื่นหรือ client id อื่นจะถูก Broker ปฏิเสธ (บอร์ดตั้ง client id เป็น `"rmutt-" + deviceId` ตรงกับ `clientIdPrefix`)

### จุดที่ 8: แกนของตัวนำเข้าตารางเรียน (`utils/schedule-import.js`)

ตารางเรียนของคณะเป็น Excel หนึ่งชีตต่อห้อง **ชื่อชีตคือรหัสห้อง** แถวหัวตารางที่คอลัมน์ A เขียนว่า `วัน` (หรือ `Day`) แถว **เหนือ** หัวตารางเป็นเวลาเริ่มของแต่ละคอลัมน์ ส่วนแถวหัวตารางเองเป็นเวลาเลิก แถววันถัดไปเป็นชื่อวิชา (เซลล์ที่รวมกันหลายคอลัมน์ = คาบยาวหลายช่วงเวลา) ใต้ชื่อวิชาหนึ่งแถวคือกลุ่มเรียน และอีกหนึ่งแถวคือชื่ออาจารย์

**ไฟล์ `backend/src/utils/schedule-import.js` บรรทัด 258–284**

```js:258
    for (
      let rowNumber = dayHeaderRow + 1;
      rowNumber <= worksheet.rowCount;
      rowNumber += 1
    ) {
      const dayAddress = cellAddress(rowNumber, 1);
      const dayMerge = worksheet.merges.get(dayAddress);
      if (dayMerge && dayMerge.masterAddress !== dayAddress) {
        continue;
      }
      const dayOfWeek = parseDay(getCellText(worksheet, rowNumber, 1));
      if (dayOfWeek == null) continue;

      for (let column = 2; column <= maxTimeColumn; column += 1) {
        const subjectAddress = cellAddress(rowNumber, column);
        const subjectMerge = worksheet.merges.get(subjectAddress);
        const subjectName = cleanOptionalText(
          getCellText(worksheet, rowNumber, column),
          150,
        );
        if (!subjectName) continue;
        if (
          subjectMerge &&
          subjectMerge.masterAddress !== subjectAddress
        ) {
          continue;
        }
```

| บรรทัด | ความหมาย |
|---|---|
| 257 | `findMaxTimeColumn` หาคอลัมน์ท้ายสุดที่มีทั้งเวลาเริ่มและเวลาเลิก (สูงสุด 64 คอลัมน์) |
| 258–262 | ไล่ทีละแถวใต้หัวตาราง ไปจนถึง `rowCount` |
| 263–267 | คอลัมน์ A ของแถวนั้นอาจเป็นเซลล์ที่รวมแนวตั้ง (วันเดียวกินหลายแถว: ชื่อวิชา กลุ่ม อาจารย์) `merges` คือ Map จากตำแหน่งเซลล์ไปยังช่วงที่รวม ถ้าเซลล์นี้ไม่ใช่เซลล์หลัก (`masterAddress` ต่างจากตัวเอง) ข้าม เพราะเป็นแถวย่อยของวันที่อ่านแล้ว |
| 268–269 | `parseDay` แปลงข้อความ `จันทร์`/`วันจันทร์`/`MON`/`1` เป็นเลขวัน 0–6 (ตาราง `DAY_LOOKUP` 35 รายการ) ถ้าไม่ใช่วัน ข้ามแถว |
| 271 | ไล่คอลัมน์เวลาตั้งแต่คอลัมน์ B ถึง `maxTimeColumn` |
| 272–277 | อ่านชื่อวิชาของเซลล์ (`cleanOptionalText` ตัดช่องว่างซ้ำและจำกัดความยาว 150) |
| 278 | เซลล์ว่าง = ไม่มีคาบ ข้าม |
| 279–284 | เซลล์ที่ถูกรวมแนวนอนและไม่ใช่เซลล์หลัก ข้าม (กันนับคาบเดียวซ้ำ) |

**ไฟล์ `backend/src/utils/schedule-import.js` บรรทัด 286–300**

```js:286
        const endColumn = subjectMerge?.endColumn ?? column;
        const startTime = normalizeTime(
          getCellText(worksheet, dayHeaderRow - 1, column),
        );
        const endTime = normalizeTime(
          getCellText(worksheet, dayHeaderRow, endColumn),
        );

        if (!startTime || !endTime) {
          warnings.push(
            `ข้าม ${roomNumber} แถว ${rowNumber} เพราะอ่านเวลาไม่สำเร็จ`,
          );
          column = endColumn;
          continue;
        }
```

- **บรรทัด 286:** `endColumn` = คอลัมน์ท้ายของเซลล์ที่รวม (ถ้าไม่รวมก็คือคอลัมน์เดิม) คาบยาว 2 ช่องจะได้เวลาเลิกจากคอลัมน์ท้าย
- **บรรทัด 287–292:** เวลาเริ่มอ่านจากแถว `dayHeaderRow - 1` ที่คอลัมน์เริ่ม, เวลาเลิกอ่านจากแถว `dayHeaderRow` ที่คอลัมน์ท้าย `normalizeTime` รับ `8.30`, `8:30`, `08:30:00` แล้วคืน `HH:mm` (หรือสตริงว่างถ้าผิด)
- **บรรทัด 294–300:** อ่านเวลาไม่ได้ → เพิ่มคำเตือนใน `warnings` แล้วข้ามคอลัมน์ (`column = endColumn`) ไม่โยน error ทั้งไฟล์ เพราะไฟล์จริงของคณะอาจมีเซลล์ประหลาดบางจุด และผู้ดูแลเห็นคำเตือนในหน้าตัวอย่างก่อนยืนยัน
- หลังจากนั้น (บรรทัด 302–318) สร้างรายการ `{semester, roomNumber, dayOfWeek, startTime, endTime, subjectName, section, instructor}` โดย `section` อ่านจากแถวถัดไป (`rowNumber + 1`) และ `instructor` จากอีกแถว (`rowNumber + 2`) ที่คอลัมน์เดียวกัน

**ไฟล์ `backend/src/utils/schedule-import.js` บรรทัด 434–463**

```js:434
    const validated = validateScheduleInput({
      roomNumber: schedule.roomNumber,
      dayOfWeek: schedule.dayOfWeek,
      subjectName: schedule.subjectName,
      section: schedule.section,
      instructor: schedule.instructor,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
    });
    Object.assign(schedule, validated);

    const exactKey = [
      schedule.roomNumber,
      schedule.dayOfWeek,
      schedule.startTime,
      schedule.endTime,
      schedule.subjectName,
      schedule.section,
    ].join('|');
    if (exactEntries.has(exactKey)) {
      continue;
    }
    exactEntries.add(exactKey);
    schedules.push(schedule);
  }

  schedules.sort(compareSchedules);
  assertNoImportedOverlaps(schedules);
  return schedules;
}
```

| บรรทัด | ความหมาย |
|---|---|
| 434–442 | ส่งทุกรายการผ่าน `validateScheduleInput` (กฎชุดเดียวกับการแก้คาบทีละรายการ) ผิดข้อไหนโยน `ApiError(400)` |
| 443 | `Object.assign(schedule, validated)` เอาค่าที่ผ่านการทำความสะอาดแล้วทับ |
| 445–452 | สร้างกุญแจ "ซ้ำเป๊ะ" จาก ห้อง|วัน|เริ่ม|เลิก|วิชา|กลุ่ม |
| 453–457 | `Set` ไว้จำกุญแจที่เคยเห็น ซ้ำแล้ว `continue` (ทิ้ง) ไม่ใช่ error เพราะไฟล์ที่ผู้ใช้ส่งมามักมีแถวซ้ำจากการคัดลอก ไม่ควรไปขวางทั้งไฟล์ |
| 460 | `sort(compareSchedules)` เรียงตามห้อง วัน เวลาเริ่ม ชื่อวิชา การเรียงก่อนทำให้ตรวจทับซ้อนได้ด้วยการเทียบรายการติดกันอย่างเดียว |
| 461 | ตรวจคาบทับซ้อนภายในไฟล์ |

**ไฟล์ `backend/src/utils/schedule-import.js` บรรทัด 465–481**

```js:465
function assertNoImportedOverlaps(schedules) {
  const latestByRoomDay = new Map();
  for (const schedule of schedules) {
    const key = `${schedule.roomNumber}|${schedule.dayOfWeek}`;
    const previous = latestByRoomDay.get(key);
    if (previous && schedule.startTime < previous.endTime) {
      throw new ApiError(
        409,
        `ตารางในไฟล์ซ้อนกัน: ห้อง ${schedule.roomNumber} `
          + `${DAY_CODES[schedule.dayOfWeek]} `
          + `${previous.startTime}-${previous.endTime} และ `
          + `${schedule.startTime}-${schedule.endTime}`,
      );
    }
    latestByRoomDay.set(key, schedule);
  }
}
```

- **บรรทัด 466:** `latestByRoomDay` เก็บ "คาบล่าสุดที่เห็น" ของแต่ละคู่ห้อง+วัน
- **บรรทัด 470:** เพราะเรียงตามเวลาเริ่มแล้ว คาบใหม่ทับกับคาบก่อนหน้าก็ต่อเมื่อ `เริ่มใหม่ < เลิกก่อนหน้า` การเทียบสตริง `HH:mm` ที่เติมศูนย์นำหน้าให้ผลเหมือนเทียบเวลา (เช่น `"09:00" < "10:30"`) ใช้เครื่องหมาย `<` ไม่ใช่ `<=` เพราะคาบที่เลิก 10:00 กับคาบที่เริ่ม 10:00 ต่อกันได้พอดี
- **บรรทัด 471–477:** ทับซ้อน → `ApiError(409, ...)` บอกห้อง วัน และสองช่วงเวลาที่ชนกัน ทั้งไฟล์ถูกปฏิเสธเพราะข้อมูลที่ผิดครึ่งหนึ่งจะทำให้ระบบปิดแอร์เข้าใจผิดว่าห้องมีคาบ

ส่วนที่เหลือของกระบวนการนำเข้า (ใน `routes/schedules.js`): ขั้น **preview** (`POST /api/schedules/import/preview`, รับ binary ไม่เกิน 8 MB, `includeUnknownRooms: true`) อ่านและแปลงอย่างเดียวไม่เขียนฐานข้อมูล แล้วส่ง `schedules`, `warnings`, ห้องใหม่ (`roomDefaultsForImport`) และ CSV (`schedulesToCsv` พร้อม BOM `﻿` ให้ Excel เปิดภาษาไทยถูก) กลับมาให้ผู้ดูแลตรวจ ขั้น **commit** (`POST /api/schedules/import/commit`) ทำใน transaction เดียว: สร้างห้องที่ขาด (ถ้าอนุญาต) → ลบตารางเดิมของห้องที่อยู่ในไฟล์ (หรือของทุกห้องถ้า `replaceAll`) → INSERT ทีละคาบ → บันทึกปฏิทินภาคเรียน/ภาคเรียนของตาราง ถ้าขั้นไหนล้มเหลวตารางเดิมยังอยู่ครบ จึงไม่มีช่วงที่ตารางว่างจนระบบปิดแอร์เข้าใจว่าทุกห้องอยู่นอกคาบ จากนั้น `clearTermCache()` ล้าง cache ปฏิทิน

## หลักการเขียนโค้ดที่ใช้ในส่วนนี้

**1. แยก "ตัดสินใจ" ออกจาก "ลงมือทำ" (pure core, imperative shell)**
ตัดสินใจอยู่ใน `utils/` (`decideAutoOff`, `buildSampleDelta`, `evaluateClassSchedule`, `ensureDeviceCommands`) ลงมือทำอยู่ใน `services/` ทำไม: ตรรกะที่ผิดพลาดแพงที่สุด (ปิดแอร์ใส่คน คิดค่าไฟผิด) ทดสอบได้โดยไม่ต้องมีฐานข้อมูล Broker หรือเวลาจริง เทสต์ส่ง `now` เข้ามาเองได้

**2. ผู้ฟังเหตุการณ์แทนการ import ตรง (inversion of dependency)**
`onAirStatus`, `onOccupancyStatus`, `onMqttConnected` ใน `services/mqtt.js` ทำไม: กัน circular import ระหว่าง `mqtt.js` กับ `auto-off.js`/`mqtt-accounts.js` และทำให้ `mqtt.js` ไม่ต้องรู้ว่าใครสนใจข้อมูลของมันบ้าง

**3. Fail-safe: เมื่อไม่แน่ใจ ให้ทำสิ่งที่เสียหายน้อยกว่า**
`decideAutoOff` ใช้ `=== true` / `!== true`, `normalizeOccupancyStatus` บังคับ `occupied` ต้องมี `radarAvailable`, `normalizePowerStatus` ตั้งค่าไฟเป็น `null` เมื่อ PZEM ใช้ไม่ได้ ทำไม: ความผิดพลาดสองทิศมีราคาไม่เท่ากัน ค่าไฟที่เสียเพิ่มเล็กน้อยดีกว่าปิดแอร์ใส่คน

**4. เก็บ "เวลาครบกำหนด" ไม่เก็บ "เวลาที่เหลือ"**
คอลัมน์ `auto_off_deadline_at` ทำไม: เขียนฐานข้อมูลครั้งเดียว ใครจะอ่านเมื่อไรก็คำนวณเวลาที่เหลือได้ถูกต้อง (แอปเดินนาฬิกาเอง) และรีสตาร์ท Backend กลางทางก็ยังนับต่อได้เพราะสถานะอยู่ในฐานข้อมูล ไม่ใช่ในหน่วยความจำ

**5. Idempotency ในทุกจุดที่ข้อความอาจซ้ำ**
`recordHistoryBatch` ข้ามรายการที่เวลา ≤ จุดต่อ, `raiseAlert` ไม่สร้างใบ `open` ซ้ำ, `clearCountdown` มี `WHERE auto_off_deadline_at IS NOT NULL`, `isHarmlessDynsecError` ถือ "already exists" เป็นสำเร็จ, `deriveDevicePassword` ได้รหัสเดิมทุกครั้ง ทำไม: MQTT QoS 1 รับประกันแค่ "อย่างน้อยหนึ่งครั้ง" และ timer ทำงานซ้ำทุก 10 วินาที ถ้างานไม่ idempotent ข้อมูลจะเพี้ยนสะสม

**6. คิวต่ออุปกรณ์ (per-key serialization)**
`runSerialForDevice` ใน `energy-recorder.js` เก็บ Promise ท้ายคิวใน `Map` ต่อรหัสอุปกรณ์ ทำไม: งานของเครื่องเดียวกันต้องไม่แย่งกันอ่าน/เขียนจุดต่อ ขณะที่เครื่องต่างกันทำขนานกันได้

**7. ล็อกข้ามโปรเซสด้วยฐานข้อมูล**
`GET_LOCK` ใน `services/auto-off.js` ทำไม: ธง `running` ในหน่วยความจำกันได้เฉพาะภายในโปรเซสเดียว ถ้ามีสอง Backend (เผลอ scale หรือรันเทสต์บนเครื่องเดียวกับของจริง) ล็อกที่ฐานข้อมูลเป็นตัวกลางเดียวที่ทั้งสองเห็นร่วมกัน

**8. ถอยหลังอย่างสุภาพเมื่อสคีมายังไม่พร้อม (graceful degradation)**
จับ `ER_BAD_FIELD_ERROR` / `ER_NO_SUCH_TABLE` ใน `readPreviousAirRow`, `saveChain`, `readTerms`, `readTodayBookings`, `readAll` ของ `system-settings.js` ทำไม: ตอน deploy มีช่วงสั้น ๆ ที่โค้ดใหม่ขึ้นก่อน migration ระบบเดิมต้องทำงานต่อได้ และสคริปต์ `db:doctor` (`utils/schema-doctor.js`) ไว้ตรวจว่าขาดอะไร

**9. แคชสั้น ๆ พร้อมล้างเมื่อเขียน**
`system-settings.js` (5 วินาที) และ `academic-terms.js` (15 วินาที) ทำไม: ฟังก์ชันเหล่านี้ถูกเรียกทุก 10 วินาทีต่อแอร์ทุกเครื่องและทุกครั้งที่บอร์ดส่งสถานะ อ่านฐานข้อมูลทุกครั้งเปลืองเปล่า แต่ต้อง `clearSettingsCache()`/`clearTermCache()` ทันทีที่ผู้ดูแลแก้ ไม่งั้นการตั้งค่าใหม่ไม่มีผลทันที

**10. เก็บผลรวมกับตัวนับ ไม่เก็บค่าเฉลี่ย**
`energy_hourly` เก็บ `voltage_sum`, `pzem_samples` ทำไม: ค่าเฉลี่ยบวกรวมกันไม่ได้ แต่ผลรวมบวกได้เสมอ เฉลี่ยค่อยหารตอนอ่าน

**11. SQL แบบพารามิเตอร์ + รายการที่อนุญาต (allowlist)**
`buildHistorySql` ใช้ชื่อคอลัมน์จากแคตตาล็อกในโค้ด ส่วนค่าผู้ใช้เป็น `?` ทั้งหมด regex ตรวจรหัสห้อง/รหัสอุปกรณ์/ชื่อไฟล์ firmware ทำไม: ป้องกัน SQL injection และ path traversal ตั้งแต่ขอบระบบ

**12. ไม่เชื่อไฟล์จากภายนอก**
`xlsx-reader.js` จำกัดขนาดหลังแตก จำนวนไฟล์ใน ZIP พื้นที่เซลล์ที่รวม และปิดการขยาย XML entity ทำไม: ไฟล์ Excel คือ ZIP+XML ที่ผู้ใช้ส่งมา ไฟล์ที่ออกแบบมาโจมตีเล็กนิดเดียวแต่กินหน่วยความจำเป็นกิกะไบต์ได้

**13. Transaction เมื่อหลายขั้นต้องสำเร็จพร้อมกัน**
`recordHistoryBatch` (ล็อกแถวด้วย `FOR UPDATE`) และการ commit ตารางเรียนใน `routes/schedules.js` ทำไม: ทั้งหมดสำเร็จหรือไม่มีอะไรเปลี่ยนเลย ไม่มีสถานะครึ่ง ๆ กลาง ๆ

**14. ค่าคงที่มีชื่อ และอยู่ที่เดียว**
`AUTO_OFF_*`, `MAX_SAMPLE_GAP_SECONDS`, `RATE_LIMITS`, `MAX_SPAN_DAYS`, `HISTORY_MAX_*` ทำไม: ตัวเลขเหล่านี้คือนโยบายของระบบ แก้ที่เดียวและเทสต์อ้างชื่อเดียวกัน

**15. ส่งแล้วรอคำตอบแบบมีเพดานเวลา และไม่ล้มทั้งงานเมื่อไม่มีคำตอบ**
`unprovisionDevice` ใน `services/mqtt.js` เก็บตัวรอใน `Map` ต่อรหัสบอร์ด และจบด้วย timeout 4 วินาที ทำไม: ต้องการรู้ว่าบอร์ดล้างค่าจริงไหม (เพื่อบอกแอดมิน) แต่การลบในระบบต้องไม่ขึ้นกับบอร์ดที่อาจออฟไลน์ ผลจึงเป็นแค่ข้อมูลประกอบ (`boardCleared`) ไม่ใช่เงื่อนไขของความสำเร็จ

**16. ให้อุปกรณ์เป็นแหล่งความจริงของ "ตัวเองคืออะไร"**
`protocolFromStatus` + `syncControlProtocol` แก้ `protocol` ในฐานข้อมูลตาม `controlMode` ที่บอร์ดรายงาน ทำไม: ข้อมูลที่คนกรอก (ยี่ห้อที่เลือกในแอปรุ่นเก่า) ผิดได้ แต่บอร์ดรู้แน่ว่าตัวเองต่อสายหรือยิง IR และใช้ `AND protocol <> ?` ให้การแก้ idempotent ไม่เขียนซ้ำ

## คำถามที่อาจารย์อาจถาม

> [!ASK]
> **ถาม:** ทำไมตรรกะปิดแอร์อัตโนมัติอยู่ที่ Backend ไม่ใช่ที่บอร์ด ESP32?
> **ตอบ:** เพราะข้อมูลที่ต้องใช้อยู่คนละที่ บอร์ดแอร์รู้ว่าแอร์กินไฟอยู่ไหมแต่ไม่รู้ว่ามีคนไหม เซ็นเซอร์ตรวจคนรู้เรื่องคนแต่ไม่รู้เรื่องแอร์ และสองตัวนี้ไม่ได้คุยกัน มี Backend ที่เดียวที่เห็นทั้งสองฝั่งพร้อมตารางเรียน การให้บอร์ดคุยกันเองต้องออกแบบโปรโตคอลเพิ่ม และถ้าห้องมีแอร์หลายเครื่องก็ต้องกระจายข้อมูลให้ครบทุกตัว อีกข้อคือแก้กติกาที่ Backend ได้ทันทีโดยไม่ต้องแฟลชเฟิร์มแวร์ทุกบอร์ด

> [!ASK]
> **ถาม:** ถ้าเซ็นเซอร์ตรวจคนเสียหรือหลุด ระบบจะทำอย่างไร จะปิดแอร์ใส่คนไหม?
> **ตอบ:** ไม่ปิดครับ `decideAutoOff` ต้องผ่านด่านแรกคือเซ็นเซอร์ต้องมี ออนไลน์ และเรดาร์ใช้ได้ (`hasSensor && online && radarAvailable` เป็น `true` ทั้งสาม) ถ้าขาดข้อใดจะคืน `idle` หรือ `cancel` ถ้ากำลังนับอยู่ นอกจากนี้ `normalizeOccupancyStatus` ยังบังคับว่าจะรายงาน "มีคน" ได้ต้องมีเรดาร์ใช้ได้ ไม่งั้นเรดาร์ที่สายหลุดจะรายงาน "ไม่มีคน" ตลอดแล้วโดนปิดแอร์ใส่คน หลักคือเมื่อไม่แน่ใจให้ไม่ปิด เพราะผิดทางที่เสียแค่ค่าไฟ ดีกว่าผิดทางที่ปิดแอร์ใส่คนนั่งอยู่

> [!ASK]
> **ถาม:** ค่าคงที่ของระบบปิดแอร์คืออะไรบ้าง และทำไมในคาบเรียนถึงรอนานกว่า?
> **ตอบ:** ห้องว่างนอกคาบรอ 300 วินาที (5 นาที) ในคาบรอ 900 วินาที (15 นาที) ยิง IR ซ้ำทุก 20 วินาที สูงสุด 5 ครั้ง ถ้ายังไม่ดับแจ้งเตือน ในคาบเรียนรอนานกว่าเพราะมีโอกาสสูงที่คนออกไปพักแล้วกลับมา การปิดแอร์ใส่นักศึกษากลางคาบเสียหายกว่าการเปิดค้างอีกสิบนาที ส่วน "ในคาบ" นับรวมการจองห้อง (ประชุม สอบ) ด้วย และถ้าอยู่นอกวันเปิด-ปิดภาคเรียนถือว่านอกคาบทุกห้อง

> [!ASK]
> **ถาม:** ระบบรู้ได้อย่างไรว่าสั่งปิดแล้วแอร์ปิดจริง ทั้งที่ IR เป็นการส่งทางเดียว?
> **ตอบ:** ดูจากกำลังไฟที่ PZEM วัดได้ครับ บอร์ดตัดสิน `acRunning` ด้วย hysteresis (≥ 30 W ต่อเนื่อง 3 ครั้ง ถือว่าเดิน, ≤ 10 W ต่อเนื่อง 3 ครั้ง ถือว่าหยุด) พอ Backend เห็น `acRunning` เป็นเท็จหลังจากยิงไปแล้ว (`attempts > 0`) ก็ถือว่า `succeeded` และแจ้งเตือน ถ้า PZEM อ่านไม่ได้ ระบบจะไม่ปิดเลยตั้งแต่ต้น เพราะจะไม่มีทางยืนยันผลได้ และ hysteresis ช่วยไม่ให้สถานะสลับไปมาตอนกำลังไฟอยู่ในช่วงกลาง ๆ

> [!ASK]
> **ถาม:** ทำไมตอนรับ status ต้องอ่านค่าเดิมจากฐานข้อมูลก่อนเขียนค่าใหม่?
> **ตอบ:** เพราะค่าไฟต่อชั่วโมงคำนวณจากผลต่างของเลขมิเตอร์สะสม (kWh) ระหว่างตัวอย่างนี้กับตัวอย่างก่อนหน้า ถ้าเขียนทับก่อนก็ไม่เหลือค่าเดิมให้ลบ `consumption_kwh` จะกลายเป็นเลขสะสมทั้งหมดตั้งแต่ติดตั้งแทนที่จะเป็นของชั่วโมงนั้น ใน `handleAirStatus` จึงอ่าน `previous` ก่อน แล้ว `recordEnergySample` ต่อด้วย `UPDATE` ค่าล่าสุดเป็นขั้นสุดท้าย ถ้าขั้นบันทึกค่าไฟพังก็แค่ log ค่าล่าสุดของเครื่องยังถูกเขียนเสมอ

> [!ASK]
> **ถาม:** ถ้าอินเทอร์เน็ตของบอร์ดหลุดไปหลายชั่วโมง ข้อมูลค่าไฟช่วงนั้นหายไหม?
> **ตอบ:** ไม่หายครับ บอร์ดเก็บสรุปช่วงละ 5 นาทีไว้ในตัว พอต่อเน็ตได้จะส่งไปที่ topic `history` Backend บันทึกลงถังตามเวลาจริงของแต่ละรายการแล้วตอบ `history-ack` พร้อม `upTo` บอร์ดถึงลบรายการที่ส่งแล้ว ถ้าบันทึกไม่สำเร็จจะไม่ตอบ บอร์ดก็ส่งชุดเดิมซ้ำเอง การส่งซ้ำไม่ทำให้นับซ้ำ เพราะ Backend ข้ามรายการที่เวลาไม่เกิน "จุดต่อ" ที่บันทึกไว้แล้ว และระหว่างที่ยังส่งไม่ครบ (`historyPending > 0`) ระบบไม่เอา status สดมาคิด เพื่อไม่ให้พลังงานก้อนใหญ่ไปกองที่ชั่วโมงที่ต่อเน็ตได้ ส่วน "เวลาทำงาน/ออนไลน์" ของช่วงที่เน็ตหลุดจะนับเป็นออนไลน์ 0 วินาที

> [!ASK]
> **ถาม:** ทำไมถังรายชั่วโมงต้องตัดตามเวลาไทย และทำไมเก็บผลรวมแทนค่าเฉลี่ย?
> **ตอบ:** เซิร์ฟเวอร์ตั้งเวลาเป็น UTC ถ้าตัดตาม UTC ชั่วโมง 09:00 ในรายงานจะเป็น 16:00 น. เวลาไทย ซึ่งดูเผิน ๆ เหมือนถูกจนกว่าจะมีคนเทียบกับเวลาจริง จึงใช้ `Intl.DateTimeFormat` กับ `Asia/Bangkok` ในทุกจุด ส่วนผลรวม+ตัวนับเก็บแทนค่าเฉลี่ยเพราะเฉลี่ยของสองกลุ่มบวกกันตรง ๆ ไม่ได้ ผลรวมบวกได้เสมอ แล้วหารตอนอ่าน นอกจากนี้ SQL รายงานทำสองชั้น (สรุปต่อเครื่องต่อชั่วโมงก่อน แล้วค่อยรวมตามระดับ) เพื่อไม่ให้เครื่องที่ส่งข้อมูลเยอะมีน้ำหนักเกินจริง

> [!ASK]
> **ถาม:** ทำไมใช้บัญชี MQTT แยกรายบอร์ด และรหัสผ่านเก็บที่ไหน?
> **ตอบ:** ถ้าทุกบอร์ดใช้บัญชีเดียวที่เข้าถึงทุก topic (โหมด shared) แกะบอร์ดเดียวออกมาอ่านรหัสใน flash ก็สั่งแอร์ทั้งอาคารได้ โหมด dynsec ที่ใช้จริงให้แต่ละบอร์ดมี username = Device ID และ ACL เฉพาะ topic ของตัวเอง (publish ได้แค่ `state`, `status`, `provision`, `provision-ack`, `history` ของตัวเอง) รหัสผ่านไม่ได้เก็บในฐานข้อมูล แต่คำนวณจาก HMAC-SHA256 ของ `MQTT_DEVICE_SECRET` กับ Device ID ตัดเหลือ 32 ตัวอักษร จึงคำนวณซ้ำได้เสมอ ตั้งค่าบอร์ดซ้ำได้รหัสเดิม และถ้าไฟล์ Dynamic Security ของ Mosquitto หาย Backend สร้างบัญชีทุกบอร์ดกลับมาให้เองทุกครั้งที่ต่อ Broker (`reconcileAccounts`)

> [!ASK]
> **ถาม:** ถ้าสอง Backend รันพร้อมกัน ระบบปิดแอร์จะยิงคำสั่งซ้ำไหม?
> **ตอบ:** ไม่ครับ ก่อนประเมินแต่ละรอบ ระบบขอ named lock ของ MariaDB ชื่อ `rmutt_auto_off_runner` ด้วย `GET_LOCK(..., 0)` (ไม่รอ) ตัวที่ได้ล็อกทำงาน อีกตัวคืนค่าว่างทันที ล็อกผูกกับ connection จึงต้องถือ connection ไว้ตลอดรอบและคืนใน `finally` ภายในโปรเซสเดียวมีธง `running` กันรอบซ้อนด้วย รอบที่ถูกข้ามไม่เสียหายเพราะมี tick ทุก 10 วินาทีมาชดเชย

> [!ASK]
> **ถาม:** ตัวนำเข้าตารางเรียนจาก Excel ปลอดภัยแค่ไหน และถ้าไฟล์มีข้อมูลผิดบางแถวเกิดอะไรขึ้น?
> **ตอบ:** ก่อนแตกไฟล์ `.xlsx` (ซึ่งคือ ZIP) ตัวอ่านตรวจ central directory ว่าจำนวนไฟล์ไม่เกิน 2000 และขนาดหลังแตกรวมไม่เกิน 32 MiB (กัน ZIP bomb) แตกเฉพาะไฟล์ที่ต้องใช้ ปิดการขยาย XML entity และจำกัดพื้นที่เซลล์ที่รวมกันไม่เกิน 10,000 ช่อง ส่วนข้อมูลที่ผิด: เซลล์ที่อ่านเวลาไม่ได้เป็นแค่คำเตือนในหน้า preview ผู้ดูแลเห็นก่อนยืนยัน แต่ถ้าผิดกฎจริง (เช่นเวลาเลิกก่อนเริ่ม) หรือคาบทับซ้อนกันในไฟล์เดียว จะปฏิเสธทั้งไฟล์ (400/409) และตอนบันทึกทำใน transaction เดียว ถ้าล้มเหลวตารางเดิมยังอยู่ครบ จึงไม่มีช่วงที่ตารางว่างแล้วระบบปิดแอร์เข้าใจผิดว่าทุกห้องอยู่นอกคาบ

> [!ASK]
> **ถาม:** บอร์ดสายแอร์ Daikin ต่างจากบอร์ด IR อย่างไรในมุมของ Backend?
> **ตอบ:** ในฐานข้อมูลแยกด้วย `protocol = 'DAIKIN_WIRED'` ครับ Backend ใช้ค่านี้สามที่ หนึ่ง `validateAirState` ตรวจคำสั่งตามที่รีโมตติดผนังทำได้ (โหมด Cool/Dry/Fan, ไม่มี Turbo, swing แค่ส่ายหรือหยุด, ฟังก์ชันเสริมถูกปิด) สอง `publicAirConditioner` ส่ง `controlType: 'wired'` ให้แอปซ่อนปุ่มที่ใช้ไม่ได้ สาม ตอนสั่ง OTA ยอมเฉพาะไฟล์ที่ชื่อมี `wired` หรือ `slm8` และถ้าในฐานข้อมูลยังเป็นยี่ห้อ IR แต่บอร์ดรายงาน `controlMode: "wired"` Backend แก้ `protocol` ให้เอง

> [!ASK]
> **ถาม:** ตอนลบอุปกรณ์ ทำไม Backend ต้องรอบอร์ดตอบ และถ้าบอร์ดออฟไลน์จะเป็นอย่างไร?
> **ตอบ:** รอเพื่อจะบอกแอดมินได้ว่าบอร์ดล้าง Wi-Fi/MQTT/ห้องในตัวเองแล้วจริงหรือยัง (`boardCleared`) รอไม่เกิน 4 วินาที ถ้าออฟไลน์ก็หมดเวลา ได้ `false` แต่การลบในระบบยังสำเร็จตามปกติ เพราะฟังก์ชันนี้ไม่โยน error บัญชี MQTT ของบอร์ดถูกลบแล้ว บอร์ดจึงต่อกลับเข้ามาไม่ได้ และเมื่อบอร์ดกลับมาออนไลน์แล้วถูก Broker ปฏิเสธต่อเนื่องครบ 2 นาที เฟิร์มแวร์จะล้างค่าตัวเอง (`checkMqttAccountRemoved`) ถ้าบอร์ดไม่กลับมาออนไลน์เลยต้องล้างที่ตัวบอร์ด คำสั่งไม่ได้ส่งแบบ retain เพราะไม่อยากให้บอร์ดตัวเดิมที่ถูกเพิ่มกลับมาภายหลังโดนล้างซ้ำ

> [!ASK]
> **ถาม:** Backend รู้ได้อย่างไรว่าไฟล์เฟิร์มแวร์เป็นของบอร์ดชนิดไหนและรุ่นอะไร ทำไมไม่เปิดไฟล์อ่านเอา?
> **ตอบ:** ดูจาก **ชื่อไฟล์** ครับ (`utils/firmware.js`) `firmwareKindOf` ให้ชื่อที่มี `occ` เป็นเซ็นเซอร์ มี `wired` หรือ `slm8` เป็นสายแอร์ ที่เหลือเป็นแอร์ IR และ `firmwareVersionOf` ดึงเลขรุ่นท้ายชื่อด้วย regex เช่น `rmutt_esp32_air_wired-2.5.2-slm8.bin` ได้ `2.5.2-slm8` ส่วน `compareFirmwareVersions` เทียบเป็นตัวเลขสามส่วน (`2.5.10` ใหม่กว่า `2.5.9` ซึ่งเทียบแบบสตริงจะผิด) ไม่อ่านจากเนื้อไฟล์เพราะเลขรุ่นใน `.bin` ไม่ได้อยู่ตำแหน่งคงที่และต้องแกะโครงสร้าง image ของ ESP32 ซึ่งซับซ้อนเกินจำเป็น ชื่อไฟล์จึงเป็นสัญญาที่ทั้งคนและโปรแกรมอ่านง่าย ส่วนเนื้อไฟล์ตรวจแค่ว่าเป็นโปรแกรม ESP32 จริง (`validateFirmwareImage`: ไบต์แรก `0xE9`, ไม่ว่าง, ไม่เกิน `0x1F0000` ไบต์ = ขนาดช่อง OTA ใน `partitions.csv`) และ `assertFirmwareKind` กันสั่งไฟล์ผิดชนิดให้บอร์ดตอน OTA

## สรุปและเช็กลิสต์ความเข้าใจ

ถ้าตอบข้อเหล่านี้ได้ แปลว่าเข้าใจบทนี้แล้ว

- [ ] อธิบายได้ว่า `utils/` กับ `services/` ต่างกันอย่างไร และยกตัวอย่างคู่ `utils/auto-off.js` กับ `services/auto-off.js`
- [ ] เล่าลำดับตอนเริ่มระบบใน `server.js` และเหตุผลที่ต้อง `startMqttAccounts()` ก่อน `startMqttBridge()`
- [ ] บอกได้ว่า Backend subscribe topic ไหนบ้าง (6 topic ของบอร์ด + response ของ Dynamic Security) และ publish อะไรกลับ (`command` รวม `action: unprovision`, `schedule-status`, `history-ack`, `provision-ack`)
- [ ] อธิบายได้ว่าบอร์ดออฟไลน์ถูกตรวจจับอย่างไร (LWT ที่ `/status`, `online: false`) และผลต่อฐานข้อมูล
- [ ] อธิบายกลไก `history` → `history-ack` และเหตุผลที่ไม่ตอบเมื่อบันทึกพลาด
- [ ] บอกได้ว่าทำไมต้องมี listener และ per-device queue
- [ ] อธิบายบัญชี MQTT รายบอร์ด: HMAC password, ACL ของ `air`/`occupancy`, `ensure` กับ `repair` ต่างกันอย่างไร
- [ ] ท่องค่าคงที่ปิดแอร์ได้: 300 / 900 / 20 / 5 และ tick 10 วินาที
- [ ] เล่าด่านตรวจของ `decideAutoOff` ตามลำดับ และบอกเงื่อนไข cancel ทั้งหมด
- [ ] วาดสถานะ IDLE → COUNTING → COMMANDING และเงื่อนไขกลับ IDLE (succeeded, giveUp, cancel)
- [ ] อธิบายได้ว่าทำไมเก็บ `deadline_at` และทำไมสวิตช์รวมปิดต้องล้างนาฬิกา
- [ ] อธิบายเส้นทาง ตัวอย่าง → delta → ถังรายชั่วโมง และกติกา `energyDelta` (null/ติดลบ/เกิน 50 kWh = 0), เพดาน 300 วินาที
- [ ] อธิบายจุดต่อ (chain) และเหตุผลที่ต้องจำเลขมิเตอร์เดิมเมื่อ PZEM อ่านไม่ได้
- [ ] อธิบายว่าค่าไฟ (บาท) คำนวณที่ไหน (`SUM(kWh) × rate` ใน `routes/energy.js`) อัตราเริ่มต้น 4.50 บาท/kWh และขอบเขต 0.01–100
- [ ] อธิบายขั้นตอนส่งออก Excel และโครงสร้างไฟล์ `.xlsx` ที่ `xlsx-writer.js` สร้าง (6 ไฟล์ใน ZIP, inlineStr, freeze header)
- [ ] อธิบายได้ว่า "ตอนนี้อยู่ในคาบไหม" คำนวณอย่างไร (ตารางเรียน + ภาคเรียน + การจองห้อง) และเหตุผลที่ใช้เวลาไทย
- [ ] อธิบายลำดับการอ่าน Excel ตารางเรียน (ชื่อชีต = ห้อง, แถว `วัน`, เซลล์ที่รวม, เวลาเริ่มอยู่แถวเหนือหัวตาราง) และด่านตรวจก่อนบันทึก
- [ ] อธิบายกติกาคำสั่งของ `DAIKIN_WIRED` และที่มาของ `controlType` ได้
- [ ] เล่าการทำงานของ `unprovisionDevice`: สร้าง payload → ตั้งตัวรอใน `Map` → publish ไม่ retain → รอ ack ทาง `status` ไม่เกิน 4 วินาที
- [ ] บอกกฎชนิดไฟล์เฟิร์มแวร์จากชื่อ (`occ` / `wired`,`slm8` / ที่เหลือ) และการตรวจไบต์ `0xE9` กับขนาด `0x1F0000`
- [ ] อธิบายว่าทำไม `compareFirmwareVersions` เทียบเป็นตัวเลขไม่ใช่สตริง และ `airFirmwareKind(protocol)` เลือกชนิดไฟล์ของบอร์ดแอร์อย่างไร
