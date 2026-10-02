# 06 · MQTT และ Mosquitto — ไปรษณีย์ของอุปกรณ์ IoT

> MQTT คือเส้นเลือดใหญ่ระหว่าง Backend กับ ESP32 ทุกตัว
> ถ้าเข้าใจบทนี้ จะแก้ปัญหา "สั่งแอร์ไม่ได้" / "เซ็นเซอร์ไม่พร้อมใช้งาน" ได้เองเกือบทั้งหมด

---

## 1. ทำไมไม่ใช้ HTTP กับ ESP32

HTTP เป็นแบบ **ถาม-ตอบ** ใครอยากได้ข้อมูลต้องถามก่อน

ถ้า ESP32 ใช้ HTTP จะต้อง "ถาม Backend ทุก 1 วินาทีว่ามีคำสั่งใหม่ไหม" (เรียกว่า polling)
- เปลืองเน็ตและไฟ
- ช้า (สูงสุด 1 วินาที)
- Backend ต้องรับคำขอ 20 บอร์ด × 1 ครั้ง/วินาที ตลอดเวลาทั้งที่ 99% ไม่มีอะไร

MQTT เป็นแบบ **Publish / Subscribe** (ส่ง / สมัครรับ)
- ESP32 ต่อค้างไว้หนึ่งเส้น แล้วบอกว่า "ฉันสนใจข่าวหัวข้อนี้"
- มีคำสั่งเมื่อไร Broker ส่งมาถึง **ทันที**
- ข้อความเล็กมาก เหมาะกับไมโครคอนโทรลเลอร์

---

## 2. แนวคิด Publish / Subscribe

```text
                    ┌────────────────────────────┐
  Publisher         │       MQTT Broker          │        Subscriber
 (คนส่ง)            │       (Mosquitto)          │        (คนรับ)
                    │                            │
 Backend ──publish──▶  topic: rmutt/ac/ESP32-X/command ──▶ ESP32-X
                    │                            │   (subscribe ไว้แล้ว)
 ESP32-X ──publish──▶  topic: rmutt/ac/ESP32-X/status  ──▶ Backend
                    │                            │   (subscribe rmutt/ac/+/status)
                    └────────────────────────────┘
```

เปรียบเทียบกับกลุ่ม LINE

| MQTT | กลุ่ม LINE |
|---|---|
| Broker | เซิร์ฟเวอร์ LINE |
| Topic | ชื่อกลุ่ม |
| Subscribe | เข้ากลุ่ม |
| Publish | ส่งข้อความในกลุ่ม |
| Client | คนแต่ละคน |

จุดสำคัญ: **คนส่งไม่ต้องรู้ว่าใครรับ คนรับไม่ต้องรู้ว่าใครส่ง** ทุกคนรู้จักแค่ Broker

---

## 3. Topic — ชื่อหัวข้อแบบลำดับชั้น

Topic เป็นข้อความคั่นด้วย `/` เหมือน path

```text
rmutt/ac/ESP32-AABBCCDDEEFF/command
└─┬─┘ └┬┘ └──────┬────────┘ └──┬──┘
 องค์กร ชนิด     รหัสบอร์ด        ประเภทข้อความ
```

### Wildcard (ใช้ได้ตอน subscribe เท่านั้น)

| สัญลักษณ์ | ความหมาย | ตัวอย่าง | ตรงกับ |
|---|---|---|---|
| `+` | แทน **หนึ่งชั้น** | `rmutt/ac/+/status` | `rmutt/ac/ESP32-A/status`, `rmutt/ac/ESP32-B/status` |
| `#` | แทน **ทุกชั้นที่เหลือ** (ต้องอยู่ท้ายสุด) | `rmutt/#` | ทุก topic ที่ขึ้นต้นด้วย `rmutt/` |

Backend ใช้ wildcard ฟังข้อความจากบอร์ดทุกตัวในคำสั่งเดียว (`backend/src/services/mqtt.js`)

```javascript
client.subscribe([
  `${config.mqtt.topicPrefix}/+/state`,       // rmutt/ac/+/state
  `${config.mqtt.topicPrefix}/+/status`,      // rmutt/ac/+/status
  `${config.mqtt.topicPrefix}/+/provision`,   // rmutt/ac/+/provision
  `${config.mqtt.topicPrefix}/+/history`,     // rmutt/ac/+/history
  ...
]);
```

### Topic `$SYS/...`
Topic ที่ขึ้นต้นด้วย `$` เป็นของ Broker เอง เช่น `$SYS/broker/version` บอกรุ่นของ Mosquitto
healthcheck ใช้ topic นี้ทดสอบ

---

## 4. Topic ทั้งหมดของโปรเจกต์

### บอร์ดแอร์ — prefix `rmutt/ac/<deviceId>/`  (deviceId เช่น `ESP32-AABBCCDDEEFF`)

| Topic ท้าย | ใครส่ง → ใครรับ | Retain | เนื้อหา |
|---|---|---|---|
| `command` | Backend → ESP32 | ไม่ | คำสั่งแอร์ `{version, commandId, state:{power, temperature, mode, ...}}` หรือ action พิเศษ (เช่นเข้าโหมดตั้งค่า, OTA) |
| `state` | ESP32 → Backend | | สถานะรีโมตที่ยิงไปล่าสุด |
| `status` | ESP32 → Backend | ✔ | ออนไลน์ไหม + ค่าไฟจาก PZEM ทุก 10 วินาที + Last Will |
| `provision` | ESP32 → Backend | ✔ | token ครั้งเดียว ยืนยันว่าตั้งค่าสำเร็จ |
| `provision-ack` | Backend → ESP32 | ✔ | ตอบรับ token (บอร์ดจะลบ token ออก) |
| `schedule-status` | Backend → ESP32 | ✔ | ตอนนี้อยู่ในคาบเรียนไหม (ใช้กับไฟ LED แดง) |
| `history` | ESP32 → Backend | | ข้อมูลไฟย้อนหลังช่วงเน็ตหลุด ทีละ 10 รายการ |
| `history-ack` | Backend → ESP32 | | บันทึกแล้ว ลบชุดนั้นได้ |

### บอร์ดตรวจคน — prefix `rmutt/occupancy/<deviceId>/`  (deviceId เช่น `OCC32-AABBCCDDEEFF`)

| Topic ท้าย | ใครส่ง → ใครรับ | เนื้อหา |
|---|---|---|
| `status` | ESP32 → Backend | `{online, deviceId, roomNumber, radarAvailable, occupied, staticThreshold}` |
| `provision` / `provision-ack` | เหมือนบอร์ดแอร์ | |
| `command` | Backend → ESP32 | เข้าโหมดตั้งค่า, OTA |

ตัวอย่าง status ของเซ็นเซอร์

```json
{
  "online": true,
  "deviceId": "OCC32-AABBCCDDEEFF",
  "roomNumber": "16203",
  "radarAvailable": true,
  "occupied": true,
  "staticThreshold": 25
}
```

สัญญาฉบับเต็ม: `docs/BLE_MQTT_PROTOCOL.md`

---

## 5. QoS — รับประกันการส่งแค่ไหน

| QoS | ชื่อ | ความหมาย |
|---|---|---|
| 0 | At most once | ส่งครั้งเดียว หายก็หาย |
| 1 | At least once | ส่งซ้ำจนผู้รับตอบรับ (อาจได้ซ้ำ) |
| 2 | Exactly once | ได้ครั้งเดียวแน่นอน (ช้าสุด) |

โปรเจกต์ใช้ **QoS 1** เกือบทั้งหมด เพราะคำสั่งแอร์หายไม่ได้ และถ้าได้ซ้ำก็ไม่เป็นไร
(สั่ง "เปิด 24°C" สองครั้ง ผลเหมือนครั้งเดียว — เรียกว่า **idempotent**)
แต่ละคำสั่งมี `commandId` (UUID) ไว้แยกคำสั่งด้วย

---

## 6. Retain — ข้อความที่ Broker จำไว้

ปกติข้อความส่งผ่านแล้วหายไป ใครมา subscribe ทีหลังจะไม่เห็น
ถ้าส่งแบบ **retain = true** Broker จะ **จำข้อความล่าสุดของ topic นั้นไว้** แล้วส่งให้ทุกคนที่มา subscribe ใหม่ทันที

ใช้กับ
- `status` → Backend รีสตาร์ทแล้วรู้สถานะล่าสุดของบอร์ดทุกตัวทันที
- `provision` → ถ้า Backend ปิดอยู่ตอนบอร์ดตั้งค่าเสร็จ ข้อความยังรออยู่
- `schedule-status` → บอร์ดรีบูตแล้วรู้ทันทีว่าอยู่ในคาบเรียนไหม

**ล้าง retain** = publish ข้อความ **ว่าง** (0 ไบต์) แบบ retain ลง topic นั้น
Backend ทำอัตโนมัติเมื่อลบอุปกรณ์ (`clearRetained()` ใน `services/mqtt.js`) ไม่งั้นข้อความเก่าจะ "ผี" กลับมาตอนเพิ่มบอร์ดรหัสเดิม

---

## 7. Last Will (LWT) — จดหมายลาตาย

ตอนต่อ Broker ESP32 ฝาก "จดหมาย" ไว้ว่า **ถ้าฉันหายไปโดยไม่บอกลา ให้ส่งข้อความนี้แทน**

จาก `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` ฟังก์ชัน `connectMqtt()`

```cpp
DynamicJsonDocument offline(96);
offline["online"] = false;                 // เนื้อหาจดหมาย: {"online":false,...}
offline["deviceId"] = config.deviceId;
serializeJson(offline, willPayload);

connected = mqttClient.connect(
    clientId.c_str(),                      // "rmutt-ESP32-AABB..."
    config.mqttUsername.c_str(),
    config.mqttPassword.c_str(),
    statusTopic.c_str(),                   // ส่งจดหมายไปที่ .../status
    1,                                     // QoS 1
    true,                                  // retain
    willPayload.c_str());
```

ถ้าปลั๊กบอร์ดหลุด Broker รอจนหมดเวลา keep-alive แล้ว publish `{"online":false}`
ลง `.../status` ให้ Backend รู้ว่าบอร์ด **ออฟไลน์** โดยอัตโนมัติ

---

## 8. Mosquitto — Broker ที่ใช้

**Eclipse Mosquitto** เป็น MQTT Broker แบบ open source ที่นิยมที่สุด เบามาก

### 8.1 ค่าตั้งบนเครื่องพัฒนา: `mqtt/config/mosquitto.conf`

```conf
per_listener_settings true

listener 1883 0.0.0.0               # (1) ฟังพอร์ต 1883 ทุกการ์ดเครือข่าย
protocol mqtt
allow_anonymous false               # (2) ห้ามต่อโดยไม่มีรหัส
password_file /mosquitto/config/passwords   # (3) ไฟล์รหัส
acl_file /mosquitto/config/acl              # (4) ไฟล์สิทธิ์

persistence true                    # (5) จำ retained message ข้ามการรีสตาร์ท
persistence_location /mosquitto/data/
autosave_interval 60                #     บันทึกลงดิสก์ทุก 60 วินาที

log_dest stdout                     # (6) log ออกหน้าจอ (docker logs)
log_dest file /mosquitto/log/mosquitto.log   #     และลงไฟล์
log_type error
log_type warning
log_type notice
connection_messages true            #     บันทึกทุกครั้งที่มีคนต่อ/หลุด
```

### 8.2 ไฟล์รหัส `mqtt/config/passwords`
รูปแบบ `ชื่อผู้ใช้:hash` สร้างโดยคำสั่ง `mosquitto_passwd`
`setup_mqtt.ps1` ทำให้โดย

```powershell
Set-Content -LiteralPath $passwordFile -Value "$Username`:$password" -Encoding ascii -NoNewline
docker run --rm `
  --mount "type=bind,source=$configDirectory,target=/mosquitto/config" `
  eclipse-mosquitto:2.0 `
  mosquitto_passwd -U /mosquitto/config/passwords
```

1. เขียนรหัส **แบบอ่านออก** ลงไฟล์ชั่วคราว
2. เปิดกล่อง Mosquitto ชั่วคราว (`--rm` = ลบทิ้งเมื่อเสร็จ) ผูกโฟลเดอร์ config เข้าไป
3. สั่ง `mosquitto_passwd -U` = **แปลงรหัสในไฟล์เป็น hash** ทับที่เดิม

### 8.3 ไฟล์สิทธิ์ `mqtt/config/acl` — จุดที่พังบ่อยที่สุด

```text
user rmutt_air
topic readwrite rmutt/ac/#
topic readwrite rmutt/occupancy/#
topic read $SYS/#
```

อ่านว่า: ผู้ใช้ `rmutt_air` อ่าน-เขียนได้ทุก topic ใต้ `rmutt/ac/` และ `rmutt/occupancy/`
และอ่าน `$SYS/` ได้

> ⚠️ **กับดักใหญ่**: ถ้าขาดบรรทัด `rmutt/occupancy/#` (ไฟล์ที่สร้างก่อนเวอร์ชัน 2.1.0)
> Mosquitto จะ **ปฏิเสธแบบเงียบ ๆ** — บอร์ดขึ้น `MQTT connected` ปกติ
> ล็อกอินผ่าน แต่ข้อความไม่ไปถึงใครเลย แอปขึ้น "เซ็นเซอร์ไม่พร้อมใช้งาน" ตลอด
> หลักฐานอยู่ใน `mqtt/log/mosquitto.log` จะเห็นคำว่า `not authorised`
> `run_all.ps1` ตรวจและซ่อมไฟล์นี้ให้อัตโนมัติแล้ว

### 8.4 ค่าตั้งบนเซิร์ฟเวอร์จริง: `deploy/mosquitto/config/mosquitto.conf`

ต่างจากบนเครื่อง 2 จุดใหญ่

1. **มีสองพอร์ต**
   - `1883` ไม่เข้ารหัส **ใช้เฉพาะในเครือข่าย Docker** (Backend) ไม่เปิดออกนอก
   - `8883` เข้ารหัส TLS ใช้ใบรับรองของโดเมน สำหรับ ESP32 จากภายนอก
2. **ใช้ Dynamic Security Plugin** แทนไฟล์ passwords/acl
   - บอร์ดแต่ละตัวมี **บัญชีของตัวเอง** (username = Device ID)
   - เห็นเฉพาะ topic ของตัวเอง → บอร์ดห้อง A ถูกแฮ็กก็สั่งแอร์ห้อง B ไม่ได้
   - Backend สร้าง/ลบบัญชีให้อัตโนมัติ (`backend/src/services/mqtt-accounts.js`)
   - เลือกโหมดด้วย `MQTT_DEVICE_AUTH=shared` (บนเครื่อง) หรือ `dynsec` (จริง)

---

## 9. คำสั่งทดสอบ MQTT ด้วยมือ

Mosquitto มาพร้อมโปรแกรม `mosquitto_pub` (ส่ง) และ `mosquitto_sub` (รับ)
เราเรียกใช้ผ่านกล่อง Docker ได้เลย ไม่ต้องติดตั้งบน Windows

> 📁 รันที่โฟลเดอร์ `mqtt`
> แทน `<user>` และ `<pass>` ด้วยค่าใน `mqtt\.env` (เปิดด้วย `notepad .env`)

### 9.1 ทดสอบอัตโนมัติด้วยสคริปต์

```powershell
.\test_mqtt.ps1
```

สคริปต์ทำ 3 ขั้น: publish ข้อความทดสอบแบบ retain → subscribe อ่านกลับมาเทียบ → ล้าง retain
ผ่านจะขึ้น `MQTT publish/subscribe test ผ่าน`

### 9.2 ฟังทุกข้อความ (เปิดหน้าต่างหนึ่งค้างไว้)

```powershell
docker exec rmutt-mosquitto mosquitto_sub -h 127.0.0.1 -p 1883 -u <user> -P <pass> -v -t 'rmutt/#'
```

| ตัวเลือก | ความหมาย |
|---|---|
| `-h 127.0.0.1` | host ของ Broker (ในกล่องเอง) |
| `-p 1883` | port |
| `-u` / `-P` | username / password (P ใหญ่) |
| `-v` | verbose = แสดงชื่อ topic หน้าข้อความ |
| `-t 'rmutt/#'` | topic ที่จะฟัง |
| `-C 1` | รับครบ 1 ข้อความแล้วจบ |
| `-W 8` | รอสูงสุด 8 วินาที |

ถ้ามีบอร์ดออนไลน์ จะเห็นประมาณทุก 10 วินาที

```text
rmutt/ac/ESP32-AABBCCDDEEFF/status {"online":true,"deviceId":"ESP32-AABBCCDDEEFF","pzemAvailable":true,"acRunning":true,"voltage":229.8,...}
rmutt/occupancy/OCC32-112233445566/status {"online":true,"occupied":false,...}
```

> 💡 `.\diagnose.ps1` ขั้นที่ 7 ทำแบบนี้ให้อัตโนมัติ 20 วินาที

### 9.3 ส่งข้อความเอง (อีกหน้าต่าง)

```powershell
docker exec rmutt-mosquitto mosquitto_pub -h 127.0.0.1 -p 1883 -u <user> -P <pass> -t 'rmutt/ac/test' -m '{"hello":"world"}'
```

| ตัวเลือก | ความหมาย |
|---|---|
| `-t` | topic |
| `-m` | ข้อความ |
| `-q 1` | QoS 1 |
| `-r` | retain |
| `-n` | ส่งข้อความว่าง (ใช้ล้าง retain คู่กับ `-r`) |

> ⚠️ อย่าส่งเข้า `.../command` ของบอร์ดจริงด้วยมือ ถ้าไม่แน่ใจรูปแบบ JSON
> ให้สั่งผ่านแอปดีกว่า เพราะ Backend ตรวจค่าให้ก่อน

### 9.4 ทดสอบจากเครื่องอื่นในวง Wi-Fi
ถ้าติดตั้ง Mosquitto บน Windows หรือใช้โปรแกรม **MQTT Explorer** (มีหน้าจอ ใช้ง่าย)
ใส่ Host = LAN IP ของคอม, Port = 1883, Username/Password จาก `mqtt\.env`
ถ้าต่อไม่ได้แต่ในเครื่องได้ → **Windows Firewall บล็อกพอร์ต 1883** (ดูบท 15)

---

## 10. Backend ต่อ MQTT อย่างไร

ไลบรารี `mqtt` ของ npm (`backend/src/services/mqtt.js`)

- ต่อด้วยค่าใน `.env`: `MQTT_URL`, `MQTT_USERNAME`, `MQTT_PASSWORD`
- subscribe wildcard ทุก topic ที่ต้องฟัง
- ข้อความเข้ามา → `handleIncomingMessage(topic, payload)`
  ใช้ regex แยก deviceId และประเภท

```javascript
const match = topic.match(
  new RegExp(`^${prefix}/(ESP32-[0-9A-F]{12})/(state|status|provision|history)$`),
);
const [, deviceId, type] = match;   // เช่น "ESP32-AABBCCDDEEFF", "status"
```

- สถานะการเชื่อมต่อดูได้ที่ `GET /api/health` → `mqtt.connected`

```json
{"status":"ok","service":"rmutt-save-energy-api",
 "mqtt":{"connected":true,"broker":"mqtt://192.168.1.10:1883","topicPrefix":"rmutt/ac", ...}}
```

`MQTT_REQUIRED=true` = ถ้าตั้งค่า MQTT ไม่ครบ Backend จะไม่ยอมเปิดเลย (ดีกว่าเปิดแล้วสั่งแอร์ไม่ได้แบบเงียบ ๆ)

---

## 11. ESP32 ต่อ MQTT อย่างไร

ไลบรารี **PubSubClient**

```cpp
mqttClient.setServer(host, port);            // ที่อยู่ Broker (ได้มาตอนตั้งค่าผ่าน BLE)
mqttClient.setCallback(mqttCallback);        // ฟังก์ชันที่จะถูกเรียกเมื่อมีข้อความเข้า
mqttClient.setBufferSize(2048);              // ขยาย buffer (ค่าเริ่มต้น 256 ไบต์ไม่พอ)
mqttClient.connect(clientId, user, pass, willTopic, 1, true, willPayload);
mqttClient.subscribe(".../command", 1);
mqttClient.publish(".../status", payload, true);   // true = retain
mqttClient.loop();                           // ต้องเรียกบ่อย ๆ ใน loop() เพื่อรับข้อความ
```

ถ้าหลุด บอร์ดพยายามต่อใหม่ทุก 3 วินาที
ถ้า `connect` ล้มเหลว Serial Monitor จะพิมพ์ `MQTT connection failed, state: <เลข>`

| state | ความหมาย |
|---|---|
| `-4` | หมดเวลา (Broker ไม่ตอบ) |
| `-2` | ต่อ TCP ไม่ได้ (IP/พอร์ตผิด, firewall, Broker ไม่รัน) |
| `4` | username/password ผิด |
| `5` | ไม่ได้รับอนุญาต |

---

## 12. สรุปบท

- MQTT = publish/subscribe ผ่าน Broker, เหมาะกับ IoT กว่า HTTP
- Topic แบ่งชั้นด้วย `/`, subscribe ใช้ `+` (ชั้นเดียว) และ `#` (ทั้งหมด)
- QoS 1 = ส่งจนได้รับ, Retain = Broker จำข้อความล่าสุด, LWT = ประกาศออฟไลน์อัตโนมัติ
- Mosquitto บนเครื่อง: พอร์ต 1883 + passwords + acl
- Mosquitto จริง: พอร์ต 8883 TLS + Dynamic Security (บัญชีต่อบอร์ด)
- ACL ที่ขาด `rmutt/occupancy/#` คือสาเหตุ "ปฏิเสธเงียบ" ที่พบบ่อยที่สุด

## 🧪 แบบฝึกหัด

1. เปิด Mosquitto (`.\mqtt\start_mqtt.ps1`) แล้วรัน `.\mqtt\test_mqtt.ps1`
2. เปิดสองหน้าต่าง หน้าหนึ่ง `mosquitto_sub -t 'rmutt/#'` อีกหน้า `mosquitto_pub` ไปที่
   `rmutt/ac/test` ดูว่าข้อความขึ้นอีกฝั่งไหม
3. ส่งแบบ `-r` แล้วปิดหน้าต่าง sub เปิดใหม่ ข้อความยังขึ้นไหม? ล้างอย่างไร?
4. ลองแก้ `acl` ให้ขาดบรรทัด `rmutt/ac/#` แล้ว `docker compose restart broker`
   ส่งข้อความอีกครั้ง ดูใน `mqtt\log\mosquitto.log` (แล้วแก้กลับ!)
5. ถ้า Backend subscribe `rmutt/ac/+/status` ข้อความใน topic `rmutt/ac/ESP32-A/sub/status` จะถึงไหม? ทำไม?

ถัดไป: **บท 07 ฐานข้อมูล MariaDB และ SQL**
