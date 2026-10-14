# โปรโตคอลสื่อสาร: MQTT และ Bluetooth Low Energy

## ภาพรวม

บทนี้ไม่ได้อธิบายโปรแกรมตัวใดตัวหนึ่ง แต่อธิบาย **"สัญญา" ที่ทุกส่วนของระบบต้องทำตรงกัน** ได้แก่ ESP32 บอร์ดแอร์, ESP32 บอร์ดตรวจคน, Mosquitto Broker, Backend (Node.js) และแอป Flutter ถ้าฝ่ายใดฝ่ายหนึ่งสะกดชื่อ topic ผิดหนึ่งตัวอักษร หรือส่ง JSON ฟิลด์ชื่อไม่ตรง ระบบจะ "เงียบ" ไปเฉย ๆ โดยไม่มี error ให้เห็น จึงต้องรู้สัญญาเหล่านี้ให้ละเอียด

ระบบใช้ **สองโปรโตคอลที่มีหน้าที่คนละอย่าง**

| โปรโตคอล | ใช้ตอนไหน | ใครคุยกับใคร | ระยะ |
|---|---|---|---|
| **BLE** (Bluetooth Low Energy) | ตั้งค่าบอร์ดครั้งแรก / เปลี่ยน Wi-Fi / กู้บอร์ดที่ Wi-Fi หลุด | แอป Flutter ↔ ESP32 โดยตรง | ไม่กี่เมตร |
| **MQTT** | ใช้งานปกติทุกวัน: สั่งแอร์ รับสถานะ รับค่าไฟ รับสถานะคนในห้อง | ESP32 ↔ Broker ↔ Backend | ผ่าน Wi-Fi/อินเทอร์เน็ต |

ทำไมต้องมีสองอย่าง: บอร์ดที่เพิ่งแฟลชยังไม่รู้ชื่อ Wi-Fi จึงเข้าอินเทอร์เน็ตไม่ได้ ช่องทางเดียวที่คุยได้คือ BLE (ใกล้ตัว ไม่ต้องมีเครือข่าย) พอบอร์ดได้ Wi-Fi และข้อมูล Broker แล้วก็เปลี่ยนไปใช้ MQTT ตลอด

สิ่งสำคัญที่ต้องจำ: **แอป Flutter ไม่เคยคุย MQTT เอง** แอปคุยกับ Backend ด้วย HTTP เท่านั้น (ยกเว้นตอน BLE) แล้ว Backend เป็นฝ่ายแปลงเป็นข้อความ MQTT ถึงบอร์ด ฝั่งแอปของ BLE อธิบายรายบรรทัดไว้แล้วใน **บท Flutter ตอนที่ 2** (`11b-flutter-admin-screens.md`) บทนี้จะเน้น "สัญญา" และฝั่งบอร์ด/Backend แทน

![ขั้นตอน provisioning](img/05-provisioning.svg)

## ความรู้ที่ต้องมีก่อนอ่านบทนี้

### MQTT ตั้งแต่ศูนย์

**MQTT** คือโปรโตคอลส่งข้อความแบบ publish/subscribe ที่เบามาก ออกแบบมาให้อุปกรณ์เล็ก ๆ (IoT) ใช้ รูปแบบคือ

- **Broker** = ไปรษณีย์กลาง (ในโปรเจคนี้คือ Mosquitto) ไม่มีใครคุยกันตรง ๆ ทุกคนคุยผ่าน Broker
- **Client** = ใครก็ตามที่ต่อเข้า Broker: ESP32 แต่ละตัว และ Backend ก็เป็น client เหมือนกัน
- **Publish** = ส่งข้อความเข้า topic หนึ่ง **Subscribe** = บอกว่าอยากรับข้อความจาก topic นั้น Broker จะส่งต่อให้ทุกคนที่ subscribe
- **Topic** = "ที่อยู่" ของข้อความ เป็นสตริงคั่นด้วย `/` เช่น `rmutt/ac/ESP32-AABBCCDDEEFF/command` ผู้ส่งไม่ต้องรู้ว่าใครรับ ผู้รับไม่ต้องรู้ว่าใครส่ง

**Wildcard** ใช้ตอน subscribe เท่านั้น
- `+` แทนหนึ่งระดับ เช่น `rmutt/ac/+/status` = status ของทุกบอร์ด (Backend ใช้อันนี้)
- `#` แทนทุกระดับที่เหลือ เช่น `rmutt/ac/#` = ทุก topic ใต้ `rmutt/ac/` (ใช้ใน ACL ของ Backend)

**QoS** (Quality of Service) = ระดับความมั่นใจว่าข้อความถึง
- QoS 0 = ส่งครั้งเดียว ไม่สน (เร็วสุด อาจหาย)
- QoS 1 = ส่งจนกว่าจะได้ใบตอบรับ (ถึงอย่างน้อยหนึ่งครั้ง อาจซ้ำ)
- QoS 2 = ถึงพอดีหนึ่งครั้ง (ช้าสุด โปรเจคนี้ไม่ใช้)

โปรเจคนี้: Backend ส่งและ subscribe ด้วย **QoS 1** ทั้งหมด ส่วนฝั่งบอร์ดใช้ไลบรารี `PubSubClient` ซึ่งฟังก์ชัน `publish()` **ส่งได้แค่ QoS 0** (ไม่มีพารามิเตอร์ QoS ให้เลือก) แต่ตอน `subscribe(..., 1)` ขอ QoS 1 และตอนตั้ง Last Will ระบุ QoS 1 ผลคือคำสั่งจาก Backend ถึงบอร์ดอย่างน้อยหนึ่งครั้ง (ข้อความที่บอร์ดส่งขึ้นไปบางข้อความอาจหายได้ แต่บอร์ดส่ง status ซ้ำทุก 10 วินาที จึงไม่เป็นปัญหา)

**Retained message** = Broker จำข้อความล่าสุดของ topic นั้นไว้ แล้วส่งให้ทุกคนที่ subscribe ทีหลังทันที เหมือนป้ายประกาศที่ติดผนัง ใช้กับ "สถานะล่าสุด" เพื่อให้ Backend ที่เพิ่งเปิดเห็นสถานะบอร์ดได้ทันทีโดยไม่ต้องรอ ล้างได้โดย publish ข้อความ **ว่าง** แบบ retained ไปที่ topic เดิม (โปรเจคนี้ทำในฟังก์ชัน `clearRetained`)

**Last Will and Testament (LWT)** = ตอนต่อ Broker บอร์ดฝากข้อความ "พินัยกรรม" ไว้ ถ้าบอร์ดหลุดแบบไม่บอกลา (ไฟดับ Wi-Fi หลุด) Broker จะ publish ข้อความนี้แทนให้ ทำให้ Backend รู้ทันทีว่าบอร์ด offline โดยบอร์ดไม่ต้องพูดอะไรเลย

**Keep-alive** = ช่วงเวลาที่ client ต้องส่งอะไรมาอย่างน้อยหนึ่งครั้ง (ไม่งั้นส่ง PINGREQ) ถ้า Broker ไม่ได้ยินเกิน ~1.5 เท่า จะถือว่าหลุดและปล่อย LWT โค้ดบอร์ดไม่ได้ตั้งค่าเอง ใช้ค่าเริ่มต้นของ PubSubClient (15 วินาที) ส่วนฝั่ง Backend ใช้ค่าเริ่มต้นของไลบรารี `mqtt` (60 วินาที)

**Clean session** = ต่อใหม่แล้วเริ่มสถานะ subscribe ใหม่หมด (Broker ไม่จำว่าเคย subscribe อะไร) Backend ตั้ง `clean: true` ชัดเจน (บรรทัด 90 ของ `services/mqtt.js`) ส่วน PubSubClient ตั้ง clean session ให้เองทุกครั้ง ผลคือทุกครั้งที่ต่อใหม่ ต้อง subscribe ใหม่ (โค้ดทั้งสองฝั่งทำตอน `connect`)

**Client ID** = ชื่อเฉพาะของ client บน Broker ถ้ามีสอง client ใช้ ID ซ้ำ Broker จะเตะตัวเก่าออก โปรเจคนี้: บอร์ดแอร์ `rmutt-ESP32-<MAC>`, บอร์ดตรวจคน `rmutt-occ-OCC32-<MAC>`, Backend `rmutt-api-<pid>`

**Authentication / TLS**
- **Auth** = ต้องมี username/password (`allow_anonymous false`) ไม่งั้นต่อไม่ได้
- **TLS** = เข้ารหัสการเชื่อมต่อ พอร์ตมาตรฐานคือ **8883** (ส่วน 1883 คือไม่เข้ารหัส) แต่ในระบบจริงค่าเริ่มต้นที่บอร์ดใช้คือ `rmutt-energy.tailb292b4.ts.net` พอร์ต **8443** (ผ่าน Tailscale Funnel ซึ่งถอด TLS ที่กล่อง tailscale แล้วส่งต่อไป `mqtt:1883`) ส่วนพอร์ต 8883 ของ Mosquitto ยังใช้ได้เมื่อบอร์ดต่อตรงในอาคาร บอร์ดตรวจใบรับรองที่ปลายทางส่งมา (ใบ ts.net หรือใบ DuckDNS ก็ได้ ออกโดย Let's Encrypt ทั้งคู่) กับใบรากที่ฝังไว้ใน `letsencrypt_ca.h` (ISRG Root X1 และ X2) และต้อง sync เวลา NTP ก่อน เพราะตรวจวันหมดอายุของใบรับรองต้องรู้เวลาจริง (ฟังก์ชัน `ensureClockSynced()`)
- **Dynamic Security** = ปลั๊กอินของ Mosquitto ที่สร้าง user/role/ACL ได้ตอนรัน ผ่านการ publish คำสั่ง JSON ไปที่ topic พิเศษ `$CONTROL/dynamic-security/v1` Backend ใช้อันนี้สร้างบัญชีให้บอร์ดแต่ละตัวอัตโนมัติ (อธิบายในหัวข้อ "บัญชี MQTT รายอุปกรณ์")

**ทำไมใช้ MQTT ไม่ใช่ทางเลือกอื่น**

| ทางเลือก | ปัญหาสำหรับงานนี้ |
|---|---|
| HTTP polling (บอร์ดถามเซิร์ฟเวอร์ทุกไม่กี่วินาทีว่ามีคำสั่งไหม) | เปลืองแบนด์วิดท์และไฟ คำสั่งช้า (ต้องรอรอบถามถัดไป) และเซิร์ฟเวอร์ต้องเปิดรับการเชื่อมต่อจากบอร์ดนับสิบตัว |
| WebSocket | คงการเชื่อมต่อค้างได้ แต่ต้องเขียนเองทั้งเรื่องห้อง/การกระจายข้อความ/การรู้ว่าใคร offline ไม่มี retained/LWT ให้ |
| MQTT | การเชื่อมต่อค้างตลอด ส่งคำสั่งถึงบอร์ดทันที มี retained (สถานะล่าสุด) และ LWT (รู้ว่า offline) ในตัว header เล็ก ไลบรารีบนบอร์ดมีพร้อม และบอร์ดอยู่หลัง NAT ก็รับคำสั่งได้เพราะเป็นฝ่ายต่อออกไปเอง |

### BLE ตั้งแต่ศูนย์

**BLE** (Bluetooth Low Energy) คือบลูทูธโหมดประหยัดพลังงาน ต่างจาก Bluetooth Classic (ที่ใช้กับหูฟัง สตรีมเสียง) ตรงที่ส่งข้อมูลก้อนเล็กและกินไฟน้อย เชื่อมต่อได้เร็ว เหมาะกับการตั้งค่าอุปกรณ์ ทั้งสองไม่ใช่ของที่คุยข้ามกันได้

- **Advertising / Scan**: อุปกรณ์ที่รอให้คนมาต่อ (**Peripheral** = ESP32) ตะโกนประกาศตัวเป็นระยะ ๆ พร้อมชื่อ (เช่น `RMUTT-AC-AABBCCDDEEFF`) ส่วนอีกฝั่ง (**Central** = แอป) ทำ scan ฟังประกาศเหล่านั้น แล้วเลือกต่อ
- **GATT** = โครงสร้างข้อมูลที่ Peripheral เปิดให้อ่าน/เขียน จัดเป็นชั้น: **Service** (กลุ่มของฟังก์ชัน) → **Characteristic** (ช่องข้อมูลหนึ่งช่อง เหมือน "ตัวแปร" ที่อ่านหรือเขียนได้)
- **UUID** = รหัสยาว 128 บิตที่ระบุ Service/Characteristic เพื่อไม่ให้ชนกับของคนอื่น โปรเจคนี้สร้าง UUID ของตัวเอง
- **Property** ของ characteristic: **Read** (แอปอ่านค่า), **Write** (แอปเขียนค่า), **Notify** (บอร์ดผลักค่าใหม่มาให้แอปเองเมื่อมีการเปลี่ยน โดยแอปต้อง "สมัครรับ" ก่อน)
- **MTU และการหั่นแพ็กเก็ต**: BLE ส่งได้ทีละไม่กี่สิบถึงสองสามร้อยไบต์ต่อ packet (ค่าเริ่มต้น MTU 23 ไบต์ ใช้งานได้จริง 20 ไบต์ ต่อรองให้ใหญ่ขึ้นได้แต่ขึ้นกับอุปกรณ์) JSON ตั้งค่าของเราเกิน จึงต้อง **หั่นเป็นชิ้น** ใส่หมายเลขลำดับ แล้วให้บอร์ดประกอบกลับ (โปรเจคนี้ใช้ชิ้นละ 150 ไบต์ข้อมูล ดูหัวข้อ "รูปแพ็กเก็ตตั้งค่า")

## ตัวตนอุปกรณ์ (Device Identity)

ทุกบอร์ดมีเลข MAC ฝังมาจากโรงงานใน eFuse ของชิป เฟิร์มแวร์เอามาทำเป็น Device ID ด้วยฟังก์ชัน `createDeviceId()`:

| บอร์ด | Device ID | ชื่อ BLE | Client ID บน MQTT | Topic prefix (ค่าเริ่มต้น) |
|---|---|---|---|---|
| คุมแอร์ | `ESP32-<MAC 12 หลัก hex ตัวพิมพ์ใหญ่>` เช่น `ESP32-AABBCCDDEEFF` | `RMUTT-AC-AABBCCDDEEFF` | `rmutt-ESP32-AABBCCDDEEFF` | `rmutt/ac` |
| ตรวจคน | `OCC32-<MAC 12 หลัก>` เช่น `OCC32-AABBCCDDEEFF` | `RMUTT-OCC-AABBCCDDEEFF` | `rmutt-occ-OCC32-AABBCCDDEEFF` | `rmutt/occupancy` |

ในโค้ดบอร์ด `snprintf(buffer, ..., "ESP32-%04X%08X", chipId >> 32, chipId)` ดึง 16 บิตบน + 32 บิตล่างของ MAC 48 บิต เป็น hex 4 + 8 = 12 หลัก ชื่อ BLE ตัด `ESP32-`/`OCC32-` ออกด้วย `substring(6)` แล้วต่อท้าย `RMUTT-AC-`/`RMUTT-OCC-`

- ตรวจรูปแบบที่ Backend ด้วย regex `^ESP32-[0-9A-F]{12}$` และ `^OCC32-[0-9A-F]{12}$` (ใน `handleIncomingMessage` และ `DEVICE_KINDS`)
- แอปใช้คำนำหน้าชื่อ BLE แยกชนิด: สแกนหา `RMUTT-AC-` (ค่าเริ่มต้นของ `scan()`) หรือ `RMUTT-OCC-`
- ฐานข้อมูล: หนึ่งแถวของแอร์ = หนึ่ง `(roomNumber, airNumber)` เซ็นเซอร์ตรวจคนหนึ่งตัวต่อหนึ่งห้อง
- MAC ไม่ใช่ความลับ (พิมพ์บนบอร์ดและประกาศผ่าน BLE) จึงต้องมี token พิสูจน์ตัวตนตอน provisioning (ดูหัวข้อ provisioning)
- **บอร์ดสายแอร์ Daikin** (`firmware/rmutt_esp32_air_wired/`, เพิ่ม 11 ต.ค. 2569) ใช้รูปแบบเดียวกับบอร์ดแอร์ IR ทุกอย่าง (`ESP32-<MAC>`, `RMUTT-AC-…`, `rmutt-ESP32-…`, prefix `rmutt/ac`) เพราะในมุม MQTT มันคือ "บอร์ดคุมแอร์" เหมือนกัน ต่างแค่วิธีสั่งแอร์ (ต่อสายแทนรีโมตติดผนัง แทนการยิง IR) ระบบแยกสองรุ่นด้วยฟิลด์ `controlType` ใน Identity ของ BLE และ `controlMode` ใน `status` (ดูด้านล่าง) ไม่ได้แยกด้วยชื่อ จึงไม่ต้องแก้ ACL, regex หรือ topic เลย

## ตาราง Topic ทั้งหมด

ทุก topic อยู่ในรูป `<prefix>/<deviceId>/<suffix>` ค่าด้านล่างดึงจากโค้ดจริง: `services/mqtt.js` (ฝั่ง Backend), `rmutt_esp32_air.ino` และ `rmutt_esp32_occupancy.ino` (ฝั่งบอร์ด), `utils/mqtt-accounts.js` (ACL)

### บอร์ดแอร์ `rmutt/ac/ESP32-<MAC>/…`

| suffix | ทิศทาง | Retained | QoS | ใครส่ง / ใครรับ | เนื้อหาหลัก |
|---|---|---|---|---|---|
| `command` | Backend → บอร์ด | ไม่ | 1 | Backend `publishAirCommand` / บอร์ด `mqttCallback` | `state` (สั่งแอร์) หรือ `action` = `enter_setup`, `ota`, `unprovision` (เพิ่ม 13 ต.ค. 2569) |
| `state` | บอร์ด → Backend | **ใช่** | 0 | บอร์ด `publishState` / Backend อัปเดต `state_json` | สถานะ IR ที่ใช้อยู่ + `commandId` ที่ตอบรับ |
| `status` | บอร์ด → Backend | **ใช่** (ยกเว้นคำตอบ unprovision) | 0 (LWT = 1) | บอร์ด `publishStatus` ทุก 10 วินาที / Backend `handleAirStatus` | online, PZEM, ค่าไฟ, เวอร์ชัน, `historyPending` บอร์ดสายแอร์มี `controlMode` ฯลฯ เพิ่ม และคำตอบ `{"unprovisioned":true}` (ไม่ retained) |
| `provision` | บอร์ด → Backend | **ใช่** | 0 | บอร์ด `publishProvisioningToken` ทุก 10 วินาที จนได้ ack | `token`, `deviceId`, `roomNumber`, `airNumber` |
| `provision-ack` | Backend → บอร์ด | **ใช่** | 1 | Backend `activateProvisioning` | `activated`, `token` เดิม |
| `schedule-status` | Backend → บอร์ด | **ใช่** | 1 | Backend `publishScheduleEvaluation` | อยู่ในคาบเรียนหรือไม่ |
| `history` | บอร์ด → Backend | ไม่ | 0 | บอร์ด `processHistoryUpload` / Backend `handleAirHistory` | ข้อมูลไฟย้อนหลังตอนเน็ตหลุด (ชุดละ 10 รายการ) |
| `history-ack` | Backend → บอร์ด | ไม่ | 1 | Backend `handleAirHistory` | `upTo`, `stored`, `skipped` |

> [!NOTE]
> `docs/BLE_MQTT_PROTOCOL.md` (ปรับ 14 ต.ค. 2569) อธิบาย `history` และ `history-ack` แล้ว (เพิ่มในเฟิร์มแวร์ 2.4.0: ส่งค่าที่เก็บไว้ตอนเน็ตหลุดครั้งละ 10 รายการ แล้วลบเมื่อ Backend ตอบ) ส่วน "retained/QoS" ของ `state` และ `status` เอกสารไม่ได้ระบุ ค่าในตารางนี้อ่านจากโค้ดจริง (`mqttClient.publish(topic, payload, true)` = retained) เอกสารเพิ่มฟิลด์ `controlType` ของ Identity และฟิลด์ `status` ของบอร์ดสายแอร์ (11 ต.ค. 2569) และหัวข้อ "Unprovision" (13 ต.ค. 2569) แล้ว (ตรงกับที่อธิบายในบทนี้)

**ตัวอย่าง `command` (สั่งแอร์)** — Backend สร้างใน `publishAirCommand`

```json
{
  "version": 1,
  "commandId": "3f2b8c1e-0a52-4d6e-9a47-7c2d1b9e5f10",
  "sentAt": "2026-08-19T09:30:00.000Z",
  "state": {
    "power": true, "temperature": 25, "mode": "cool",
    "fanSpeed": "auto", "verticalSwing": "auto", "horizontalSwing": false,
    "eco": false, "turbo": false, "sleep": false, "quiet": false,
    "displayLight": true, "clean": false,
    "timerOnMinutes": null, "timerOffMinutes": null
  }
}
```

`commandId` เป็น UUID สุ่มจาก `crypto.randomUUID()` ใช้ให้ตามได้ว่าคำสั่งไหนถูกทำแล้ว (บอร์ดส่งกลับใน `state`) `sentAt` เป็น ISO-8601

**คำสั่งแบบ action** (ไม่มี `state`): `{"version":1,"commandId":"…","sentAt":"…","action":"enter_setup"}` และ `{"version":1,…,"action":"ota","url":"https://<host>/firmware/<ไฟล์>.bin"}`

**คำสั่ง `unprovision`** (เพิ่ม 13 ต.ค. 2569) Backend สร้างด้วย `buildUnprovisionCommand` ใน `utils/unprovision.js` ตอนแอดมินลบอุปกรณ์ ใช้กับทั้งบอร์ดแอร์ (IR 2.5.1, สายแอร์ 2.5.2-slm8) และบอร์ดตรวจคน (1.3.2) ขึ้นไป

```json
{ "version": 1, "commandId": "UUID", "sentAt": "2026-10-13T12:00:00.000Z",
  "action": "unprovision", "deviceId": "ESP32-AABBCCDDEEFF" }
```

ต่างจาก action อื่นตรงที่ **ใส่ `deviceId` ซ้ำในเนื้อข้อความ** บอร์ดเทียบกับรหัสตัวเองก่อนทำ ไม่ตรงก็ทิ้ง (กันข้อความหลงผิด topic เพราะผลของคำสั่งนี้ย้อนกลับไม่ได้) บอร์ดตอบทาง `status` **แบบไม่ retained**:

```json
{ "deviceId": "ESP32-AABBCCDDEEFF", "online": false, "unprovisioned": true }
```

ลำดับเต็มและกรณีบอร์ดออฟไลน์ อธิบายในหัวข้อ "ลบอุปกรณ์ในแอป → ล้างค่าในบอร์ด (unprovision)" ด้านล่าง

**ตัวอย่าง `state`** — บอร์ดตอบหลังทำคำสั่ง (`publishState(commandId)`)

```json
{
  "commandId": "3f2b8c1e-0a52-4d6e-9a47-7c2d1b9e5f10",
  "state": {
    "power": true, "temperature": 25, "mode": "cool", "fanSpeed": "auto",
    "verticalSwing": "auto", "horizontalSwing": false, "eco": false,
    "turbo": false, "sleep": false, "quiet": false, "displayLight": true,
    "clean": false, "timerOnMinutes": null, "timerOffMinutes": null
  }
}
```

Backend เก็บเฉพาะ `message.state ?? message` ลงคอลัมน์ `air_conditioners.state_json` พร้อมตั้ง `is_online = 1` และ `last_seen_at`

**ตัวอย่าง `status`** (ฟิลด์ตามฟังก์ชัน `publishStatus` ในเฟิร์มแวร์ 2.4.1)

```json
{
  "online": true,
  "deviceId": "ESP32-AABBCCDDEEFF",
  "firmwareVersion": "2.4.1",
  "roomNumber": "16101",
  "airNumber": 1,
  "ip": "192.168.1.50",
  "rssi": -58,
  "pzemAvailable": true,
  "acRunning": true,
  "outsideSchedule": false,
  "scheduleConfigured": true,
  "classScheduleConfigured": true,
  "historyPending": 0,
  "voltage": 229.8,
  "current": 2.145,
  "powerWatts": 465.2,
  "energyKwh": 12.345,
  "frequencyHz": 50.0,
  "powerFactor": 0.94
}
```

**ฟิลด์เพิ่มของบอร์ดสายแอร์** (`rmutt_esp32_air_wired`, เพิ่ม 11 ต.ค. 2569) บอร์ดส่งทุกฟิลด์ข้างบนเหมือนเดิม แล้วต่อท้ายด้วย

```json
{
  "controlMode": "wired",
  "airBrand": "Daikin",
  "busOk": true,
  "compressorRunning": true,
  "unitRoomTemperature": 27,
  "roomTemperature": 27.4
}
```

`controlMode` บอกว่าบอร์ดคุมแอร์ทางสาย `busOk` = คุยกับแอร์ทางสายได้ไหม `compressorRunning` = คอมเพรสเซอร์ทำงานอยู่ไหม (อ่านจากแอร์ ไม่ใช่เดาจากไฟ) `unitRoomTemperature` = อุณหภูมิห้องที่แอร์วัดเอง (มีเฉพาะตอน `busOk`) `roomTemperature` = เซนเซอร์ของบอร์ด (`null` ถ้าอ่านไม่ได้) บอร์ด IR เดิมไม่ส่งฟิลด์เหล่านี้ และ Backend/แอปรุ่นเก่าที่ไม่รู้จักก็แค่ไม่อ่าน (เพิ่มฟิลด์ได้โดยไม่ทำให้ใครพัง)

Backend ใช้ `controlMode` ทำสองอย่าง (ฟังก์ชัน `protocolFromStatus` ใน `utils/air-conditioner.js` และ `syncControlProtocol` ใน `services/mqtt.js`):
1. **แก้ protocol ในฐานข้อมูลให้เอง** ถ้า `controlMode` เป็น `wired` แต่แถวยังเป็นยี่ห้อ IR (เช่น จองจากแอปรุ่นเก่าที่ยังไม่รู้จักบอร์ดสายแอร์) Backend `UPDATE ... SET protocol = 'DAIKIN_WIRED' WHERE ... AND protocol <> ?` ใส่เงื่อนไข `<>` จึงเขียนฐานข้อมูลเฉพาะครั้งที่ค่ายังไม่ตรง ไม่ใช่ทุก 10 วินาที
2. **คำสั่งที่ส่งไปบอร์ด `DAIKIN_WIRED` ถูกจำกัด** ตาม `validateAirState(body, protocol)` รับเฉพาะโหมด Cool/Dry/Fan, พัดลม Auto/Low/Medium/High (ไม่มี Turbo), สวิงแนวตั้ง Auto/Off และ Sleep (ยกเว้นโหมด Dry) ส่วน Eco, Turbo, Quiet, Clean และสวิงแนวนอนถูกบังคับเป็น `false` เพราะรีโมตติดผนังของ Daikin ไม่มีฟังก์ชันเหล่านี้ ถ้าส่งไปบอร์ดก็ทำไม่ได้แต่แอปจะแสดงว่าเปิดอยู่ ซึ่งหลอกผู้ใช้

และ REST API คืน `controlType: "wired" | "ir"` ในข้อมูลแอร์ทุกเครื่อง (`controlTypeOf(protocol)` ใน `publicAirConditioner`) แอปจึงไม่ต้องรู้ชื่อโปรโตคอลเอง แค่ดูฟิลด์นี้เพื่อซ่อนปุ่มที่ใช้ไม่ได้ (รายละเอียดฝั่ง Backend อยู่ในบท Backend ตอนที่ 2)

ถ้า PZEM อ่านไม่ได้ ฟิลด์ voltage…powerFactor จะเป็น `null` (ไม่ใช่ 0 เพื่อไม่ให้แอปเข้าใจผิดว่าแอร์ไม่กินไฟ) ถ้ามี `otaError` จะมีฟิลด์นั้นเพิ่ม Backend ผ่าน `normalizePowerStatus` ซึ่งบังคับกติกา เช่น ถ้า `pzemAvailable` ไม่ใช่ `true` พอร์ตค่าไฟทั้งหมดจะถูกตั้งเป็น `null` และ `acRunning` เป็น `false`

**LWT ของบอร์ดแอร์** (ที่ Broker ปล่อยแทนเมื่อบอร์ดหลุด): topic `…/status`, QoS 1, retained

```json
{ "online": false, "deviceId": "ESP32-AABBCCDDEEFF" }
```

**ตัวอย่าง `provision`** และ **`provision-ack`**

```json
{ "token": "<24 ไบต์ base64url>", "deviceId": "ESP32-AABBCCDDEEFF", "roomNumber": "16101", "airNumber": 1 }
```

```json
{ "version": 1, "activated": true, "deviceId": "ESP32-AABBCCDDEEFF", "token": "<token เดิม>" }
```

**`schedule-status`** (Backend ส่งทุกครั้งที่ได้รับ status ที่ `online`)

```json
{
  "version": 1,
  "classScheduleConfigured": true,
  "withinClassSchedule": false,
  "evaluatedAt": "2026-08-19T12:00:00.000Z",
  "timezone": "Asia/Bangkok"
}
```

บอร์ดเอาไปคำนวณ `outsideSchedule` (แอร์ทำงานนอกคาบเรียน) และขึ้นไฟ LED เหลือง/แดง

**`history`** — บอร์ดส่งเป็น array ของตัวเลข 15 ช่อง ต่อ 1 รายการ (ช่วงละ 5 นาที) เรียงตามลำดับ: `ts, energyKwh, voltageAvg×10, voltageMin×10, voltageMax×10, currentAvg×1000, currentMax×1000, powerAvg×10, powerMin×10, powerMax×10, powerFactor×100, frequencyOffset×10, runtimeSeconds, samples, flags` ใช้ array แทน object เพื่อประหยัดขนาดข้อความ

```json
{ "v": 1, "deviceId": "ESP32-AABBCCDDEEFF", "records": [ [1755590400, 12.3, 2298, 2290, 2310, 2145, 2200, 4650, 4400, 4900, 94, 100, 300, 150, 0] ] }
```

(ค่าในตัวอย่างเป็นตัวเลขสมมติเพื่อให้เห็นรูปร่าง) และ `history-ack`

```json
{ "version": 1, "upTo": 1755590400, "stored": 10, "skipped": 0 }
```

### บอร์ดตรวจคน `rmutt/occupancy/OCC32-<MAC>/…`

| suffix | ทิศทาง | Retained | QoS | เนื้อหา |
|---|---|---|---|---|
| `status` | บอร์ด → Backend | **ใช่** (LWT ก็ retained, QoS 1) | 0 (LWT = 1) | online, radarAvailable, occupied |
| `provision` | บอร์ด → Backend | **ใช่** | 0 | `token`, `deviceId`, `roomNumber` |
| `provision-ack` | Backend → บอร์ด | **ใช่** | 1 | `activated`, `token` |
| `command` | Backend → บอร์ด | ไม่ | 1 | `action` = `enter_setup`, `ota` หรือ `unprovision` (เพิ่ม 13 ต.ค. 2569) |

บอร์ดตรวจคน **ไม่มี** `state`, `history`, `schedule-status` เพราะไม่ควบคุมอะไรและไม่ต้องรู้ตารางเรียน

```json
{
  "online": true,
  "deviceId": "OCC32-AABBCCDDEEFF",
  "firmwareVersion": "1.3.1",
  "roomNumber": "16203",
  "radarAvailable": true,
  "occupied": true,
  "staticThreshold": 25
}
```

LWT ของบอร์ดตรวจคน: `{"online":false,"deviceId":"OCC32-…","radarAvailable":false,"occupied":false}` — สังเกตว่ามี `radarAvailable:false` ด้วย เพราะถ้าแค่ `occupied:false` ผู้ใช้จะเข้าใจว่า "ห้องว่าง" ทั้งที่จริงคือ "ไม่รู้" กฎคือ **ถ้า `online` หรือ `radarAvailable` เป็น false ให้ถือว่า "ไม่มีข้อมูล" ไม่ใช่ "ว่าง"** (ระบบปิดแอร์อัตโนมัติก็ใช้กฎนี้: `sensorUsable`)

บอร์ดตรวจคนส่ง status ทุก 10 วินาที (`STATUS_INTERVAL_MS`) และทันทีเมื่อ `occupied` หรือ `radarAvailable` เปลี่ยน (`statusPublishRequested = true`) การตัดสิน `occupied`: อ่านพลังงาน stationary ของ LD2410 โหมด Engineering เกต 0–8 ถ้าเกตใดเกิน `STATIC_ENERGY_THRESHOLD = 25` = มีคน และไม่ส่งตำแหน่ง/พลังงานดิบขึ้นเน็ตเลย (เพื่อความเป็นส่วนตัว)

### Topic พิเศษของ Dynamic Security

| Topic | ใครส่ง | ใช้ทำอะไร |
|---|---|---|
| `$CONTROL/dynamic-security/v1` | Backend | ส่งคำสั่ง `{"commands":[…]}` สร้าง/แก้/ลบ role, client |
| `$CONTROL/dynamic-security/v1/response` | Broker | คำตอบ จับคู่กับคำสั่งด้วย `correlationData` = `<batch>:<index>` |

## บัญชี MQTT รายอุปกรณ์ (Dynamic Security)

**ปัญหาเดิม**: ถ้าทุกบอร์ดใช้ username/password เดียวกันที่อ่านเขียน `rmutt/#` ได้ ใครถอดบอร์ดตัวหนึ่งออกจากฝ้า อ่านรหัสใน flash ได้ ก็สั่งแอร์ทั้งอาคารได้

**วิธีแก้** (เปิดด้วย `MQTT_DEVICE_AUTH=dynsec`, ไฟล์ `utils/mqtt-accounts.js` + `services/mqtt-accounts.js`):
- บอร์ดแต่ละตัวมี **username = Device ID**, **client ID** ตายตัว, และ **role** ของตัวเอง
- รหัสผ่าน = `HMAC-SHA256(MQTT_DEVICE_SECRET, "mqtt-device:<DEVICE_ID>")` เป็น base64url ตัดเหลือ 32 ตัว (ฟังก์ชัน `deriveDevicePassword`) คำนวณซ้ำได้เสมอ จึงไม่ต้องเก็บรหัสในฐานข้อมูล และตั้งค่าบอร์ดซ้ำกี่ครั้งก็ได้รหัสเดิม
- ACL ของบอร์ดแอร์ (`DEVICE_KINDS.air`): **publish** ได้เฉพาะ `state, status, provision, provision-ack, history` และ **subscribe** ได้เฉพาะ `command, provision-ack, schedule-status, history-ack` ของ **ตัวเองเท่านั้น**
- ACL ของบอร์ดตรวจคน: publish `status, provision, provision-ack` / subscribe `command, provision-ack`
- Backend ใช้ role `rmutt-backend` ที่ publish/subscribe `rmutt/ac/#` และ `rmutt/occupancy/#` ได้ (`backendAcls`)
- `reconcileAccounts()` รันทุกครั้งที่ Backend ต่อ Broker ได้ (ผ่าน `onMqttConnected`): ให้สิทธิ์ Backend แล้วสร้างบัญชีให้ทุกบอร์ดที่ยังไม่ `removed` ถ้าไฟล์ `dynamic-security.json` หายหรือย้ายเซิร์ฟเวอร์ บอร์ดเดิมจะกลับมาต่อได้เอง
- ตอนจองช่อง (`prepareDeviceCredentials`) ใช้ `repair: true` เพื่อให้รหัส/client ID ตรงกับที่จะส่งให้บอร์ด (บอร์ดที่ออนไลน์อยู่จะถูกเตะหนึ่งครั้งแล้วต่อกลับเองใน 3 วินาที)
- ตอนลบอุปกรณ์: `removeDeviceCommands` ลบ client และ role

โหมด `shared` (ค่าเริ่มต้นของ config ถ้าไม่ตั้ง) = ทุกบอร์ดใช้บัญชีเดียวกับ Backend ใช้ตอนพัฒนาเท่านั้น (config.js จะพิมพ์คำเตือน)

## BLE GATT ของโปรเจค

บอร์ดทั้งสองชนิดใช้ GATT เหมือนกันทุกตัวอักษร ประกาศเป็นค่าคงที่ในเฟิร์มแวร์ (`SERVICE_UUID` ฯลฯ) และในแอป (`BleProvisioningService`)

| ชื่อ | UUID | Property | ใช้ทำอะไร |
|---|---|---|---|
| Service | `7b570001-a243-4e5b-8f13-179af81b2457` | Primary service | ครอบทุก characteristic ด้านล่าง |
| Config | `7b570002-a243-4e5b-8f13-179af81b2457` | **Write** | แอปเขียนค่าตั้งค่า (หั่นเป็น packet) |
| Status/ACK | `7b570003-a243-4e5b-8f13-179af81b2457` | **Read, Notify** | บอร์ดแจ้งผล `{ok, code, message}` |
| Identity | `7b570004-a243-4e5b-8f13-179af81b2457` | **Read** | ตัวตนบอร์ด (สั้น) |
| Nearby Wi-Fi | `7b570005-a243-4e5b-8f13-179af81b2457` | **Read** | อ่านแล้วบอร์ดสแกน Wi-Fi รอบตัวเอง |
| Saved settings | `7b570006-a243-4e5b-8f13-179af81b2457` | **Read** | ค่าที่บันทึกไว้ (เฟิร์มแวร์ 1.6+) |

Status characteristic มี descriptor `BLE2902` (CCCD) ซึ่งเป็นตัวที่ทำให้แอป "สมัครรับ" Notify ได้

**Identity** (เล็กโดยตั้งใจ ขนาด document 256 ไบต์):

```json
{ "deviceId": "ESP32-AABBCCDDEEFF", "bleName": "RMUTT-AC-AABBCCDDEEFF", "firmwareVersion": "2.4.1", "configured": false }
```

ตั้งแต่เฟิร์มแวร์ 2.5.0 (เพิ่ม 11 ต.ค. 2569) Identity มี `"controlType"` เพิ่ม: บอร์ด IR ส่ง `"ir"` บอร์ดสายแอร์ส่ง `"wired"` พร้อม `"brand": "Daikin"` บอร์ดรุ่นเก่าที่ไม่ส่งฟิลด์นี้ แอปถือว่าเป็น `"ir"` ถ้าเป็น `wired` แอปล็อกช่องยี่ห้อเป็น *Daikin · สายแอร์* และจองแอร์ด้วย protocol `DAIKIN_WIRED` แทนการให้เลือกโปรโตคอล IR (ฝั่งบอร์ดสายแอร์เองก็บันทึก `DAIKIN_WIRED` เสมอไม่ว่าแอปส่งโปรโตคอลอะไรมา กันแอปรุ่นเก่าส่งชื่อ IR) ทำไมใส่ใน Identity: แอปอ่าน Identity เป็นอย่างแรกหลังต่อ BLE จึงรู้ชนิดบอร์ดก่อนแสดงฟอร์ม และ Identity ต้องเล็ก (256 ไบต์) จึงเพิ่มแค่สองฟิลด์สั้น ๆ

ถ้าตั้งค่าแล้ว (`configured: true`) จะมี `roomNumber` และ `airNumber` เพิ่ม บอร์ดตรวจคนมี `"deviceType": "occupancy"` ด้วย (แอปใช้ตรวจว่าชื่อ BLE กับ Device ID ตรงกัน กัน spoof)

**Saved settings** (อ่านเฉพาะถ้า `configured`): `roomNumber, airNumber, name, airProtocol, wifiSsid, hasWifiPassword, mqttHost, mqttPort, mqttUsername, hasMqttPassword, dailyOn, dailyOff` — **ไม่มีรหัสผ่านจริง** ส่งแค่ธง `hasWifiPassword`/`hasMqttPassword` ให้แอปรู้ว่ามีรหัสเก่าอยู่ (ใช้ร่วมกับ `keepPassword` ตอนบันทึกใหม่ ดูบท Flutter ตอนที่ 2)

**Nearby Wi-Fi**: การ **อ่าน** characteristic นี้ทำให้ `onRead` ของ `WifiScanCallbacks` สั่ง `WiFi.scanNetworks()` ที่ตำแหน่งติดตั้งจริง ได้สูงสุด 8 SSID ไม่ซ้ำ เรียงแรงสุดก่อน (ตัดทิ้งถ้า JSON เกิน 480 ไบต์) รูปแบบกะทัดรัดเป็น `[SSID, RSSI, isSecure]`:

```json
{ "ok": true, "networks": [["RMUTT-WiFi", -42, true], ["Guest", -68, false]] }
```

ทำไมให้บอร์ดสแกนแทนแอป: Wi-Fi ที่คอมของแอดมินเห็นไม่ใช่ Wi-Fi ที่บอร์ดบนฝ้าเห็น และบอร์ดรองรับเฉพาะ 2.4 GHz เลือกจากรายการที่บอร์ดเห็นจริงจึงตรงที่สุด

### รูปแพ็กเก็ตตั้งค่า (Config)

JSON ตั้งค่าถูกแปลงเป็น UTF-8 แล้วหั่นชิ้นละ **150 ไบต์** (`dataBytesPerPacket = 150` ในแอป) ใส่หัว 6 ไบต์:

| ไบต์ | ค่า |
|---|---|
| 0 | เวอร์ชันโปรโตคอล = `1` |
| 1 | ชนิดข้อความ = `1` (config) |
| 2–3 | ลำดับ packet เริ่มจาก 0 (big-endian: ไบต์สูงก่อน) |
| 4–5 | จำนวน packet ทั้งหมด (big-endian) |
| 6… | ไบต์ของ JSON |

**JSON ตั้งค่าของบอร์ดแอร์** (`toBleJson` ใน `lib/models/provisioning.dart`):

```json
{
  "version": 1,
  "deviceId": "ESP32-AABBCCDDEEFF",
  "token": "<provisioning token>",
  "roomNumber": "16101",
  "airNumber": 1,
  "name": "แอร์ 1",
  "airProtocol": "DAIKIN",
  "wifi": { "ssid": "RMUTT-WiFi", "password": "<รหัส Wi-Fi>", "keepPassword": false },
  "mqtt": {
    "host": "rmutt-energy.tailb292b4.ts.net", "port": 8443,
    "username": "ESP32-AABBCCDDEEFF", "password": "<รหัสที่ Backend ออกให้>",
    "keepPassword": false, "topic": "rmutt/ac/ESP32-AABBCCDDEEFF", "tls": true
  },
  "schedule": { "dailyOn": "07:00", "dailyOff": "18:00", "timezone": "Asia/Bangkok" }
}
```

บอร์ดตรวจคนส่ง JSON คล้ายกัน แต่มี `"deviceType":"occupancy"`, ไม่มี `airNumber/name/airProtocol/schedule` และมี `staticThreshold`

**ผลตอบกลับทาง Notify** (`notifyBle`): `{"ok":bool,"code":"…","message":"…"}` โค้ดที่เป็นไปได้ในเฟิร์มแวร์แอร์:

| code | ความหมาย |
|---|---|
| `invalid_packet` | สั้นกว่า 6 ไบต์ หรือ `total` เป็น 0 / > 32 / `sequence >= total` |
| `unsupported_version` | ไบต์ 0 หรือ 1 ไม่ใช่ 1 |
| `sequence_error` | packet มาไม่เรียง หรือ `total` เปลี่ยนกลางทาง |
| `config_too_large` | รวมเกิน `MAX_CONFIG_BYTES` (แอร์ 4096, ตรวจคน 3072) |
| `invalid_json` | แปลง JSON ไม่ได้ |
| `invalid_config` | ฟิลด์ไม่ครบ/ไม่ถูก (Device ID ไม่ตรงบอร์ด, ห้องผิดรูปแบบ, `airNumber` ไม่อยู่ใน 1–6, รหัส Wi-Fi สั้นกว่า 8, โปรโตคอลไม่รองรับ ฯลฯ) |
| `wifi_only_mode` | อยู่ในโหมดกู้ Wi-Fi แต่พยายามเปลี่ยนห้อง/เซิร์ฟเวอร์ |
| `wifi_connection_failed` | ทดสอบ Wi-Fi ใหม่ไม่ผ่าน (ค่าเดิมใน NVS ยังอยู่) |
| `config_saved` | สำเร็จ บอร์ดรีสตาร์ตใน 1.5 วินาที |

`airProtocol` ต้องเป็นชื่อ decode type ตัวพิมพ์ใหญ่ที่ `IRac` รองรับ (เช่น `DAIKIN`, `MITSUBISHI_AC`, `GREE`, `HAIER_AC160`, …) หรือค่าพิเศษ `SAIJO_DENKI` ที่ใช้ไดรเวอร์ 72 บิตของโปรเจคเอง (รองรับ Cool/Dry/Fan, 18–29 °C ตามโค้ดตรวจใน `processMqttCommand`)

### ข้อจำกัดและเรื่องเฉพาะของ Windows

แอป Windows ใช้ `flutter_blue_plus_winrt` (ล็อกเวอร์ชัน 0.0.20) ซึ่งสร้างปัญหาเฉพาะตัว ที่ไล่แก้ตาม README สามฉบับ และมีผลต่อการออกแบบ **ทั้งฝั่งบอร์ดและฝั่งแอป**:

| อาการ | สาเหตุ | วิธีแก้ในโค้ด |
|---|---|---|
| อ่าน Identity ครั้งแรกหมดเวลา (~15 วินาที) | Windows WinRT อ่านค่า GATT ก้อนใหญ่ที่ MTU เริ่มต้นไม่ทัน | เฟิร์มแวร์ 1.6 ทำ Identity ให้สั้น (256 ไบต์) แล้วแยกค่าตั้งเดิมไป characteristic `…0006` ส่วนแอปอ่าน `settings` แยก และถ้าอ่านไม่ได้ก็ไปต่อได้ |
| เชื่อมได้แต่ค้นหา Service ไม่จบ | แอปใช้ `autoConnect` แล้วเรียก `discoverServices` ทันที ขณะที่ WinRT ค้นหา GATT ภายใน `connect()` อยู่แล้ว เกิดซ้อนกัน | เชื่อมแบบปกติ รอ `connect` เสร็จ (timeout 45 วินาที) หน่วง 1.2 วินาที แล้วค้นหา Service ซ้ำได้สูงสุด 3 ครั้ง **บนการเชื่อมเดิม** |
| scan ด้วย `withServices` ไม่เจอบอร์ดที่กู้แล้ว | บางไดรเวอร์ไม่จับคู่เมื่อชื่ออยู่ใน scan response แต่ UUID อยู่ใน advertisement หลัก | แอป scan โดยไม่กรอง Service กรองด้วยคำนำหน้าชื่อ แล้วค่อยยืนยัน identity |
| ต่อใหม่หลังล้มเหลวแล้วบอร์ดเงียบ | callback `onDisconnect` ของ BLE รันบน task ของ BLE ไม่เสถียรที่จะสั่งโฆษณาใหม่ตรงนั้น | เฟิร์มแวร์ตั้งธง `bleReadvertisePending` แล้วให้ `loop()` เริ่ม advertising ใหม่หลังหน่วง 600 ms (`BLE_READVERTISE_DELAY_MS`) |

รายละเอียดฝั่งแอป (`_connect`, `provision`) อยู่ใน **บท Flutter ตอนที่ 2** บทนี้ไม่ซ้ำ

## ลำดับ Provisioning ทั้งหมด

**Provisioning** = กระบวนการลงทะเบียนบอร์ดใหม่เข้าระบบ: บอก Wi-Fi, บอก Broker, บอกว่าบอร์ดนี้อยู่ห้องไหน แล้วให้ระบบยืนยันว่าบอร์ดตัวนี้จริง

ขั้นตอน (ฝั่งแอร์ ส่วนตรวจคนเหมือนกันแต่เรียก `/api/occupancy-sensors/reservations`):

1. แอดมินเปิดหน้าตั้งค่าในแอป แอป scan BLE เลือกบอร์ด `RMUTT-AC-…` แล้ว **อ่าน Identity** เพื่อยืนยัน Device ID ตรงกับชื่อ BLE
2. แอปกด **สแกน Wi-Fi** (อ่าน characteristic `…0005`) แล้วแอดมินเลือก SSID พิมพ์รหัส เลือกห้อง/หมายเลขแอร์/โปรโตคอล
3. แอปเรียก **`POST /api/air-conditioners/reservations`** (เฉพาะ admin) Backend: ตรวจว่าห้องมีอยู่, ลบแถว `reserved` ที่หมดอายุ, ตรวจ Device ID/ตำแหน่งซ้ำ (ซ้ำตอบ **409** ก่อนเขียน BLE), สร้าง token สุ่ม 24 ไบต์, เก็บ **เฉพาะ hash** ของ token (`hashSecret(token, otpPepper)`) พร้อมหมดอายุ **15 นาที**, เตรียมบัญชี MQTT ของบอร์ด, แทรกแถว `provision_status = 'reserved'` แล้วตอบ `provisioningToken`, `mqttHost`, `mqttPort`, `mqttUsername`, `mqttPassword`, `mqttTls`, `mqttTopic`
4. แอป **เขียน Config** ผ่าน BLE (หั่น packet) พร้อม token และค่า MQTT
5. บอร์ดประกอบ JSON → ตรวจความถูกต้อง → **ทดสอบต่อ Wi-Fi จริง** ด้วยรหัสที่ได้ (15 วินาที) → ถ้าผ่าน บันทึกลง **NVS** (หน่วยความจำถาวรที่ไม่หายเมื่อไฟดับ) → แจ้ง `config_saved` ทาง Notify → รีสตาร์ต
6. บอร์ดบูตใหม่ ต่อ Wi-Fi ต่อ MQTT (TLS ถ้า `tls` เช่นพอร์ต 8443 ผ่าน Funnel หรือ 8883 ต่อตรง) แล้ว publish `…/provision` (retained) ที่มี token ซ้ำทุก 10 วินาทีจนกว่าจะได้ ack
7. Backend subscribe `rmutt/ac/+/provision` ได้ข้อความ → ดึง hash จากแถว (ต้องเป็น `reserved`/`active`, ยังไม่หมดอายุ) → hash token ที่ได้เทียบด้วย `safeHashEquals` (เทียบแบบ constant-time กัน timing attack) → ถ้าตรง ตั้ง `provision_status = 'active'`
8. Backend publish `…/provision-ack` (retained, QoS 1) ที่มี token เดิม, ล้าง `provisioning_token_hash` ในฐานข้อมูล, และ **ล้าง retained ของ `/provision`** ด้วยข้อความว่าง
9. บอร์ดได้ ack → เช็คว่า `activated == true` และ token ตรงกับของตัวเอง → **ลบ token ออกจาก NVS** แล้ว publish ข้อความว่างล้าง retained ของ `/provision-ack` เอง

```text
แอป Flutter          Backend (HTTP)          Broker (MQTT)          ESP32
    |  scan BLE ---------------------------------------------------> | (advertising)
    |  <--------------- อ่าน Identity (BLE) ------------------------ |
    |  POST /reservations ->|                                          |
    |                       |-- สร้างบัญชี MQTT (dynsec) ->|           |
    |                       |-- INSERT status=reserved, token hash     |
    |  <- token + ค่า MQTT -|                                          |
    |  เขียน Config เป็น packet ผ่าน BLE ----------------------------> |
    |                                                  ทดสอบ Wi-Fi, บันทึก NVS
    |  <---------------- Notify {ok:true,config_saved} --------------- |
    |                                                  รีสตาร์ต, ต่อ Wi-Fi + MQTT
    |                       |<------ /provision {token} (retained) ----|
    |                       | hash(token) เทียบกับที่เก็บไว้            |
    |                       | status = 'active'                        |
    |                       |-- /provision-ack {token} retained ------>|
    |                       |-- /provision "" (ล้าง retained)          |
    |                       |                                  ลบ token จาก NVS
```

> [!WHY]
> **ทำไมต้องมี token**: Device ID มาจาก MAC ซึ่งไม่ใช่ความลับ ถ้าไม่มี token ใครก็ต่อ MQTT แล้วอ้างเป็นบอร์ดนั้นเพื่อทำให้ระบบเปลี่ยนเป็น active ได้ token ส่งมาทาง BLE เท่านั้น ซึ่งต้องอยู่ใกล้บอร์ดจริง และ Backend เก็บแค่ hash (ถ้าฐานข้อมูลรั่วก็เอา token ไปใช้ไม่ได้) **ทำไมต้อง `reserved` ก่อน `active`**: ขั้น 4–6 ใช้เวลาเป็นนาที ถ้าไม่จองตำแหน่งไว้ก่อน คนที่สองจองห้อง+แอร์เบอร์เดียวกันซ้ำได้ ค่า UNIQUE ของ (ห้อง, เบอร์แอร์) ทำงานตั้งแต่ขั้น 3

**ตั้งค่าบอร์ดเดิมซ้ำ**: ถ้า Device ID เดิมอยู่ที่ห้อง+เบอร์เดิม (สถานะ `active`) Backend อัปเดตแถวเดิม ออก token ใหม่ และตอบ 200 (ไม่ใช่ 201) ถ้าเป็น Device ID อื่นหรือช่องมีคนใช้แล้ว ตอบ 409 ก่อนเริ่มเขียน BLE

## การไหลของคำสั่งและข้อมูลเซนเซอร์

### คำสั่ง "เปิดแอร์ 25°C"

1. ผู้ใช้กดปุ่มในแอป → `AirConditionerService.sendCommand` ยิง `POST /api/air-conditioners/<deviceId>/command` พร้อม JSON ของสถานะ (`toCommandJson`)
2. Backend (route ใน `routes/air-conditioners.js`): ตรวจว่ามีแถวนี้และ `provision_status = 'active'` (ไม่งั้น 409) → `validateAirState(body, protocol)` ตรวจค่า (ช่วงอุณหภูมิ, โหมด ฯลฯ ตามยี่ห้อ) → เรียก `publishAirCommand(deviceId, state)`
3. `publishAirCommand` สร้าง `commandId` (UUID) + `sentAt` แล้ว publish ไป `rmutt/ac/<deviceId>/command` QoS 1 ไม่ retained (คำสั่งเก่าต้องไม่ถูกส่งซ้ำตอนบอร์ดเพิ่งต่อกลับ ไม่งั้นแอร์จะเปิดเองหลังไฟดับ!) Backend ตอบ HTTP **202 Accepted** `{accepted, commandId, state}` (ย้ำว่า "รับเรื่องแล้ว" ไม่ใช่ "แอร์เปิดแล้ว") ถ้า Broker ไม่ต่อ ตอบ 503
4. Broker ส่งต่อให้บอร์ดที่ subscribe `/command` → `mqttCallback` **ไม่ประมวลผลในนั้น** แค่คัดลอกข้อความเก็บใน `pendingMqttCommand` แล้วตั้งธง `mqttCommandReady` (ดูหัวข้อเจาะโค้ด)
5. `loop()` เห็นธง → `processMqttCommand()` แปลง JSON, ตรวจช่วงอุณหภูมิ (16–30 หรือ Saijo 18–29), ตรวจค่าของ Saijo, อัปเดต `airState`, `saveAirState()` ลง NVS, `sendCurrentIrState()` ส่งสัญญาณ **IR** ออก LED ไปที่แอร์จริง
6. บอร์ด `publishState(commandId)` สะท้อนสถานะจริงกลับไปที่ `…/state` (retained) พร้อม `commandId`
7. Backend ได้ `state` → อัปเดต `state_json`; แอปที่ดึงข้อมูลห้องทุก 10 วินาทีเห็นสถานะใหม่

> [!NOTE]
> ไม่มีการ "รอ" ผลแบบ request/response ระหว่าง HTTP กับบอร์ด: HTTP ตอบทันทีที่ publish แล้ว ผลจริงเห็นทาง `state`/`status` ทีหลัง การออกแบบแบบ asynchronous นี้ทำให้ Backend ไม่ค้างถ้าบอร์ด offline และแสดงสถานะจริงจากบอร์ดไม่ใช่ที่เดา

### เซนเซอร์ตรวจคน → ปิดแอร์อัตโนมัติ

1. LD2410 ส่งข้อมูลทาง UART ให้ ESP32 ตรวจคน (บอร์ด `OCC32-…`) ทุก 250 ms (`PRESENCE_READ_INTERVAL_MS`) บอร์ดตัดสิน `occupied` จากพลังงาน stationary เกต 0–8 > 25
2. บอร์ด publish `rmutt/occupancy/OCC32-…/status` (retained) ทุก 10 วินาทีและทันทีที่เปลี่ยน
3. Backend `handleOccupancyMessage` บันทึก `is_online`, `radar_available`, `is_occupied` ลง `occupancy_sensors` แล้ว `notify(occupancyStatusListeners, …)` พร้อมเลขห้อง
4. `services/auto-off.js` (สมัครเป็น listener ไว้ผ่าน `onOccupancyStatus`/`onAirStatus` และมี timer ทุก 10 วินาที) ประเมินแอร์ในห้องนั้น ผ่านฟังก์ชันตัดสิน `decideAutoOff` (ไฟล์ `utils/auto-off.js`): แอร์กินไฟอยู่ + ห้องว่าง → เริ่มนับถอยหลัง 300 วินาที (900 วินาทีถ้ามีคาบเรียน) → ครบเวลายังว่างก็ `publishAirCommand` สั่งปิด → ถ้ายังกินไฟ ยิงซ้ำทุก 20 วินาที สูงสุด 5 ครั้ง แล้วแจ้งเตือน
5. ถ้าเซนเซอร์ไม่ online/radar ไม่พร้อม หรือ PZEM อ่านไม่ได้ → **ไม่ปิดเด็ดขาด** (ไม่รู้ว่ามีคนไหม / ตรวจไม่ได้ว่าแอร์หยุดจริงไหม)

ทำไม logic นี้อยู่ที่ Backend ไม่ใช่บอร์ด: บอร์ดแอร์กับบอร์ดตรวจคนเป็นคนละตัว คุยกันเองไม่ได้ (ACL ก็ไม่เปิดให้) Backend เป็นที่เดียวที่เห็นทั้งสองฝั่งและรู้ตารางเรียน (รายละเอียดอยู่ในบทเรื่องปิดแอร์อัตโนมัติ)

## กรณีพิเศษ

### Wi-Fi หลุด: BLE Recovery (กู้ Wi-Fi)

เงื่อนไข 5 ทางที่บอร์ดเปิด BLE: ไม่เคยตั้งค่า, กด BOOT (GPIO0) ค้างตอน RESET, ต่อ Wi-Fi ที่เก็บไว้ไม่ได้ตอนบูต (รอ 20 วินาที), Wi-Fi หลุดระหว่างใช้งาน, และคำสั่ง MQTT `enter_setup`

**ถ้า Wi-Fi เป็นสาเหตุ** (`enterBleRecovery(reason, retryWifi = true)` และบอร์ด `config.configured`) บอร์ดเข้า **โหมดกู้ Wi-Fi** (`bleWifiOnlyMode = true`):
- หยุดงานปกติ (`bleBlocksNormalOperation`), ตัด MQTT, เปิด BLE
- **ลองต่อ Wi-Fi เดิมซ้ำเองเบื้องหลังทุก 30 วินาที** (`WIFI_RECOVERY_RETRY_MS`) ครั้งละไม่เกิน 8 วินาที (`WIFI_RECOVERY_ATTEMPT_MS`) ถ้าเราเตอร์กลับมา บอร์ดปิด BLE ต่อ MQTT ทำงานต่อเอง ไม่ลองถ้ามีแอปเชื่อม BLE อยู่
- **ยอมให้เปลี่ยนได้เฉพาะ Wi-Fi** ฟังก์ชัน `keepsServerAssignment()` เทียบว่า ห้อง เบอร์แอร์ MQTT host/port/tls/username/password/topic ต้อง **เท่าเดิมทุกตัว** ไม่งั้นตอบ `wifi_only_mode`

> [!WHY]
> ตอน Wi-Fi หลุด ใครอยู่ใกล้บอร์ดก็ต่อ BLE ได้ (BLE ไม่มีรหัสผ่านในโปรเจคนี้) ถ้าเปลี่ยนห้องหรือ MQTT server ได้ คนแปลกหน้าจะชี้บอร์ดไปหา MQTT ของตัวเองแล้วสั่งแอร์ห้องนั้น จึงล็อกไว้ ต้องการเปลี่ยนห้องหรือเซิร์ฟเวอร์ ต้องกด BOOT + RESET ที่ตัวบอร์ด (ต้องเข้าถึงตัวเครื่องจริง) ซึ่งเป็น "หลักฐานการอยู่ตรงนั้น" ในอีกรูปแบบ

ส่วนกรณีที่แอดมินสั่ง `enter_setup` ผ่านแอป (`POST /api/air-conditioners/:deviceId/setup-mode`, admin เท่านั้น, ตอบ 202): `enterBleReconfiguration` เปิด BLE **5 นาที** (`ONLINE_SETUP_WINDOW_MS`) โดยบอร์ดยังออนไลน์อยู่ และ **แก้ได้ทุกช่อง** (`bleWifiOnlyMode = false`) เพราะคำสั่งมาจากแอดมินผ่าน Backend ที่ยืนยันตัวตนแล้ว ค่าเดิมยังใช้งานจนกว่าจะกดบันทึกสำเร็จ ถ้าทดสอบ Wi-Fi ใหม่ไม่ผ่านจะกู้ Wi-Fi/MQTT เดิมคืน

**MQTT หลุด** (Wi-Fi ปกติ) ไม่เปิด BLE แต่ `loop()` ลองต่อใหม่ทุก 3 วินาที ไปเรื่อย ๆ

### ล้างเครื่อง (Factory reset) vs. ตั้งค่าใหม่

- **BOOT + RESET**: ไม่ลบอะไร แค่บังคับเข้าโหมด BLE ให้ตั้งค่าใหม่ได้ทุกช่อง
- **ล้าง NVS จริง**: แฟลชสเก็ตช์ `firmware/reset/reset.ino` (เรียก `nvs_flash_erase()` ลบทุกค่าที่บันทึก, `WiFi.disconnect(true, true)`, แล้ว `nvs_flash_init()`) จากนั้นแฟลชเฟิร์มแวร์จริงกลับ บอร์ดจะ "ยังไม่ตั้งค่า" และเปิด BLE เอง
- **ลบอุปกรณ์ออกจากระบบ**: `DELETE /api/air-conditioners/:deviceId` ลบแถวใน DB → **สั่งบอร์ดล้างค่าตัวเอง (`unprovision`) แล้วรอคำตอบ ≤ 4 วินาที** (เพิ่ม 13 ต.ค. 2569) → **ล้าง retained** ทั้ง 6 topic (`AIR_RETAINED_SUFFIXES` ใน `utils/mqtt-topics.js`) → ลบบัญชี MQTT ของบอร์ด ถ้าบอร์ดออนไลน์ ผลจะเหมือนแฟลช `reset.ino` แต่ทำจากแอปได้เลย (หัวข้อถัดไป)

### ลบอุปกรณ์ในแอป → ล้างค่าในบอร์ด (unprovision) (เพิ่ม 13 ต.ค. 2569)

**ปัญหาเดิม:** ก่อนหน้านี้การลบอุปกรณ์ทำแค่ฝั่งเซิร์ฟเวอร์ (ลบแถว ล้าง retained ลบบัญชี MQTT) ตัวบอร์ดยังเก็บรหัส Wi-Fi, ที่อยู่ Broker, username/password MQTT และเลขห้องไว้ใน NVS ครบ และยังพยายามต่อ Broker ทุก 3 วินาทีไปเรื่อย ๆ ผลเสีย: (1) บอร์ดที่ถอดไปทิ้งหรือย้ายไปที่อื่นยังพกรหัส Wi-Fi ของคณะไปด้วย (2) ในโหมด `shared` ที่ทุกบอร์ดใช้บัญชีเดียวกัน การลบบัญชีรายบอร์ดไม่มีผล บอร์ดที่ถูกลบยังต่อและส่งข้อมูลได้ (3) จะเอาบอร์ดไปใช้ห้องอื่นต้องไปกด BOOT + RESET หรือแฟลช `reset.ino` ที่ตัวบอร์ด

**ลำดับทั้งหมด** (แอร์และเซ็นเซอร์เหมือนกัน ต่างแค่ prefix ของ topic):

```text
แอป/เว็บ (แอดมิน)      Backend                        Broker                  บอร์ด
DELETE /api/...  ───► 1. DELETE แถวในฐานข้อมูล
                       2. publish command ─────────► <prefix>/<id>/command ─► ตรวจ deviceId ตรงกับตัวเอง
                          {"action":"unprovision",     (QoS 1, ไม่ retained)    ├ publish status {"unprovisioned":true} (ไม่ retained)
                           "deviceId":"<id>"}                                    ├ publish ข้อความว่าง retained ที่ status (+ state ของแอร์)
                          รอคำตอบ ≤ 4 วินาที ◄──────── <prefix>/<id>/status ◄──┤ disconnect แบบปกติ (ไม่เกิด Last Will)
                       3. ล้าง retained ทุก topic ──► ข้อความว่าง retained       ├ preferences.clear() ล้าง NVS
                       4. ลบบัญชี MQTT (dynsec) ────► บอร์ดต่อกลับไม่ได้อีก      ├ (แอร์) ลบพาร์ติชันประวัติ rmuttlog
◄── 200 {..., boardCleared: true/false}                                          └ ESP.restart() → โหมดตั้งค่า BLE
```

**ทำไมลำดับต้องเป็นแบบนี้**
- **ส่งคำสั่งก่อนลบบัญชี MQTT:** ลบบัญชีแล้ว Broker ตัดบอร์ดออกทันที (Dynamic Security เตะ client ที่ถูกลบ) และบอร์ดต่อกลับไม่ได้อีก คำสั่งจะไปไม่ถึงตลอดไป
- **รอคำตอบก่อนล้าง retained:** บอร์ดล้าง retained ของตัวเองแล้ว Backend ล้างซ้ำอีกรอบ (รวม `command`, `provision`, `provision-ack`, `schedule-status` ที่บอร์ดล้างเองไม่ได้เพราะ ACL ไม่ให้ publish) ล้างซ้ำไม่เสียหายเพราะข้อความว่างคือ "ไม่มี retained" เหมือนเดิม
- **ลบแถวในฐานข้อมูลก่อนสุด:** การลบในระบบต้องสำเร็จเสมอแม้บอร์ดไม่ตอบ `unprovisionDevice` จึงไม่โยน error คืนแค่ `{sent, acknowledged}`
- **บอร์ดตัดการเชื่อมต่อแบบปกติ (`disconnect()`):** ถ้าแค่รีบูต Broker จะเห็นว่าหลุดแบบไม่บอกลาแล้วปล่อย Last Will `{"online":false}` แบบ retained ทับข้อความว่างที่เพิ่งล้าง ทำให้มี retained ค้างอีก

**การจัดการ retained ในขั้นนี้**
- คำสั่ง `unprovision` **ไม่ retained** โดยตั้งใจ ถ้า retained แล้วบอร์ดออฟไลน์ตอนลบ คำสั่งจะค้างบน Broker วันหลังถ้าเพิ่มบอร์ดตัวเดิมกลับเข้าระบบ (Device ID เดิมเพราะมาจาก MAC) บอร์ดจะได้คำสั่งค้างทันทีที่ subscribe แล้วล้างตัวเองทิ้งอีกรอบ (ขั้น 3 ของ Backend ก็ล้าง `command` อยู่แล้วเพื่อกันกรณีนี้)
- คำตอบ `{"unprovisioned":true}` ไม่ retained เพราะเป็นเหตุการณ์ครั้งเดียว ถ้า retained จะค้างเป็น "status ล่าสุด" ของรหัสบอร์ดนี้
- Backend แยกคำตอบออกจาก status ปกติด้วย `isUnprovisionAck(message, deviceId)`: ต้องมี `unprovisioned === true` (boolean จริง สตริง `"true"` ไม่นับ) และ `deviceId` ตรงกับ topic ถ้าใช่ `consumeUnprovisionAck` ปลุกตัวที่รออยู่แล้ว `return` ไม่ส่งต่อให้ `handleAirStatus` (ไม่บันทึกเป็นสถานะ)
- ข้อความว่างที่บอร์ดล้าง retained ไหลมาถึง Backend ด้วย แต่ `JSON.parse('')` ล้มเหลวจึงถูกทิ้งเงียบ ๆ (defensive parsing)

**กรณีขอบ (edge cases)**

| สถานการณ์ | เกิดอะไรขึ้น | ผลต่อผู้ใช้ |
|---|---|---|
| บอร์ดออนไลน์ เฟิร์มแวร์ใหม่ | ล้างค่า ตอบภายในไม่ถึงวินาที | `boardCleared: true` บอร์ดกลับเป็นสภาพใหม่ รอตั้งค่าผ่าน BLE |
| บอร์ดออฟไลน์ตอนกดลบ | คำสั่งไม่ retained จึงไม่ค้าง Backend รอครบ 4 วินาที (`UNPROVISION_ACK_TIMEOUT_MS`) แล้วลบต่อ | `boardCleared: false` บอร์ดยังเก็บค่าเดิม แต่บัญชี MQTT ถูกลบ (โหมด dynsec) จึงต่อ Broker ไม่ได้อีก ต้องล้างที่ตัวบอร์ดเอง: แฟลช `reset.ino`, BOOT + RESET แล้วตั้งค่าใหม่ หรือแฟลชเฟิร์มแวร์ใหม่ |
| บอร์ดเฟิร์มแวร์เก่า (ก่อน IR 2.5.1 / สายแอร์ 2.5.2-slm8 / เซ็นเซอร์ 1.3.2) | ไม่รู้จัก action นี้ (บอร์ดแอร์รุ่นเก่าตกไปตรวจ `state` ไม่พบ พิมพ์ `MQTT command rejected: state is missing` แล้วทิ้ง) ไม่ตอบ | เหมือนบอร์ดออฟไลน์: รอ 4 วินาที `boardCleared: false` |
| Backend ไม่ได้ต่อ Broker | `unprovisionDevice` คืน `{sent:false}` ทันที ไม่รอ | ลบในฐานข้อมูลสำเร็จ `boardCleared: false` |
| `deviceId` ในข้อความไม่ตรงกับบอร์ด | บอร์ดพิมพ์ `Unprovision ignored` แล้วไม่ทำอะไร | ไม่มีบอร์ดผิดตัวถูกล้าง |
| กดลบเครื่องเดิมซ้ำระหว่างยังรอ | ตัวรอเก่าถูกปิดด้วย `false` ก่อนตั้งตัวใหม่ (`unprovisionWaiters.get(deviceId)?.(false)`) | ไม่มี Promise ค้าง |

> [!WARN]
> โหมด `shared` (บัญชี MQTT เดียวทุกบอร์ด ใช้ตอนพัฒนา) ไม่มีบัญชีรายบอร์ดให้ลบ ถ้าบอร์ดออฟไลน์ตอนลบแล้วกลับมาทีหลัง มันจะต่อ Broker และส่ง `status` ได้ตามเดิม (Backend ไม่บันทึกเพราะไม่มีแถวของบอร์ดนี้ `UPDATE` จึงไม่โดนแถวไหน) นี่เป็นอีกเหตุผลที่ระบบจริงต้องใช้ `MQTT_DEVICE_AUTH=dynsec`

> [!NOTE]
> หลังล้าง Device ID **ไม่เปลี่ยน** เพราะสร้างจาก MAC ใน eFuse ไม่ได้เก็บใน NVS เอาบอร์ดไปตั้งค่าใหม่ก็ได้รหัสเดิม และบอร์ดแอร์ IR ไม่สั่งแอร์เพิ่ม (แอร์ค้างสถานะล่าสุด) ส่วนบอร์ดสายแอร์ล้างสถานะแอร์ที่จำไว้ด้วย หลังรีบูตจึงส่งเฟรม "ปิด" ทางสาย (ตามคอมเมนต์ใน `rmutt_esp32_air_wired.ino`)

### ข้อมูลย้อนหลังตอนเน็ตหลุด (offline history) พร้อม ack

ถ้าบอร์ดต่อ MQTT ไม่ได้ ค่าไฟยังถูกวัด สรุปทุก 5 นาที (`HISTORY_INTERVAL_SECONDS = 300`) เขียนลง flash (partition `rmuttlog` 64 KB เป็น ring buffer 2,048 รายการ ≈ 7 วัน) เมื่อกลับมาออนไลน์:
1. รอแบบสุ่ม 5–45 วินาที (`HISTORY_START_DELAY_*`) กันบอร์ดทั้งตึกส่งพร้อมกันหลัง Wi-Fi กลับมา
2. ส่ง `…/history` ชุดละ 10 รายการ (`HISTORY_BATCH_SIZE`) แล้ว **หยุดรอ ack** (`historyAwaitingAck`)
3. Backend `recordHistoryBatch` บันทึก แล้วตอบ `…/history-ack` `{upTo, stored, skipped}`
4. บอร์ดได้ ack → `applyHistoryAck()` ลบรายการถึง `upTo` ออกจาก flash แล้วส่งชุดถัดไปหลังเว้น 1 วินาที
5. ถ้า 20 วินาทีไม่มี ack (`HISTORY_ACK_TIMEOUT_MS`) ส่งชุดเดิมซ้ำ (หลัง 5 วินาที) Backend ข้ามรายการที่เคยบันทึกแล้ว จึงไม่นับซ้ำ

ระหว่างยังส่งไม่ครบ ฟิลด์ `historyPending` ใน `status` > 0 และ Backend **ไม่บันทึกค่าสดลงประวัติ** (`status.historyPending === 0` ใน `handleAirStatus`) ไม่งั้นพลังงานช่วงนั้นจะถูกนับสองรอบ (ครั้งหนึ่งจากค่าสด อีกครั้งจากข้อมูลย้อนหลัง) นี่คือเหตุผลของ ack: ลบจาก flash เฉพาะเมื่อ Backend ยืนยันว่าเก็บแล้ว จึงไม่มีข้อมูลหายแม้ไฟดับกลางทาง

### OTA (อัปเดตเฟิร์มแวร์ผ่าน Wi-Fi)

1. แอดมินเลือกไฟล์ `.bin` บนเซิร์ฟเวอร์ (ตั้งแต่ 14 ต.ค. 2569 อัปโหลดจากหน้า **เฟิร์มแวร์** ในเว็บได้ด้วย `POST /api/firmware` ไม่ต้อง `scp`) → `POST /api/air-conditioners/:deviceId/ota` (หรือ `/api/occupancy-sensors/:deviceId/ota`) ตรวจว่า **ชนิดไฟล์ตรงกับชนิดบอร์ด** (`assertFirmwareKind`: ชื่อมี `occ` = เซ็นเซอร์, มี `wired`/`slm8` = สายแอร์ ใช้กับแอร์ที่ protocol `DAIKIN_WIRED`, นอกนั้น = แอร์ IR ผิดตอบ 400) ตรวจว่าบอร์ด `active` และ **online** → Backend สร้าง URL `https://<mqtt_host>/firmware/<ชื่อไฟล์>` (`firmwareUrl`) → `publishOtaCommand` ส่ง `{"action":"ota","url":…}` ไป `/command` → ตอบ 202
2. บอร์ดเช็ก `otaUrlAllowed(url, config.mqttHost)`: ต้องขึ้นต้น `https://<MQTT host เดิมของบอร์ด>/firmware/`, ลงท้าย `.bin`, ยาวไม่เกิน 300, ไม่มี `..`, ตัวอักษรชื่อไฟล์จำกัด ไม่ผ่านจะตั้ง `otaError = "url_rejected"` ใน status
3. `performOtaUpdate()` sync เวลา, **ตัด MQTT ก่อน** (หน่วยความจำไม่พอเปิด TLS สองชุดพร้อมกัน), ดาวน์โหลดผ่าน HTTPS ตรวจใบรับรองกับใบราก, สำเร็จ → รีสตาร์ต ล้มเหลว → ใช้เฟิร์มแวร์เดิมต่อ รายงาน `otaError` และ `firmwareVersion` ใน `status` ซึ่ง Backend เก็บผ่าน `recordFirmwareStatus`

> [!WHY]
> ป้องกันเฟิร์มแวร์ปลอม 3 ชั้น: (1) คำสั่งมาจาก topic `command` ที่มีแต่ Backend ส่งได้ตาม ACL (2) URL ชี้ได้เฉพาะเซิร์ฟเวอร์เดียวกับ MQTT ของบอร์ดเอง (3) ตรวจใบรับรอง HTTPS
>
> ทำไมต้องตรวจชนิดไฟล์ (เพิ่ม 14 ต.ค. 2569): โปรโตคอล OTA ไม่มีฟิลด์ "ชนิดบอร์ด" บอร์ดรับไฟล์ `.bin` อะไรก็ได้ที่ URL ผ่านเงื่อนไข ถ้าสั่งไฟล์ของบอร์ด IR ให้บอร์ดสายแอร์ (ชิปเดียวกัน ESP32) มันจะติดตั้งได้สำเร็จแล้วรีบูตเป็นโปรแกรมผิดชนิด ขาที่ต่อก็ผิด จึงต้องกันไว้ที่ Backend ซึ่งรู้ทั้งชื่อไฟล์และ protocol ของบอร์ด

## Broker แบบพัฒนา เทียบกับแบบใช้งานจริง

| หัวข้อ | พัฒนา (`mqtt/`) | ใช้งานจริง (`deploy/`) |
|---|---|---|
| ไฟล์ตั้งค่า | `mqtt/config/mosquitto.conf` | `deploy/mosquitto/config/mosquitto.conf` |
| ผู้ใช้ | บัญชีเดียว `rmutt_air` ใช้ร่วมทุกบอร์ดและ Backend (`MQTT_DEVICE_AUTH=shared`) | Backend หนึ่งบัญชี + บอร์ดละบัญชี (Dynamic Security, `MQTT_DEVICE_AUTH=dynsec`) |
| สิทธิ์ | ไฟล์ `acl`: `topic readwrite rmutt/ac/#`, `rmutt/occupancy/#`, `read $SYS/#` | role/ACL รายอุปกรณ์สร้างโดย Backend |
| รหัสผ่าน | สุ่มโดย `setup_mqtt.ps1` ไฟล์ `passwords` (hash ด้วย `mosquitto_passwd`) | `deploy/init-env.sh` สร้าง `MQTT_PASSWORD`, `MQTT_DEVICE_SECRET` และ `mosquitto_ctrl dynsec init` |
| พอร์ต | 1883 ไม่เข้ารหัส เปิดให้ LAN | 1883 ภายใน Docker network เท่านั้น (Backend ใช้ `mqtt://mqtt:1883`) และเป็นปลายทางที่กล่อง tailscale ส่งต่อมาจาก Funnel **8443** (ค่าเริ่มต้นที่ส่งให้บอร์ด: `MQTT_DEVICE_URL=mqtts://rmutt-energy.tailb292b4.ts.net:8443`) ส่วน **8883 TLS** ยังเปิดไว้สำหรับบอร์ดที่ต่อตรงในอาคาร (ตั้ง `MQTT_DEVICE_URL=mqtts://<โดเมน>:8883` ใน `.env`) |
| ใบรับรอง | ไม่มี | ทาง 8883: `fullchain.pem`/`privkey.pem` copy จาก Caddy โดย `sync-mqtt-cert.sh` (cron รายวัน), `tls_version tlsv1.2` ทาง Funnel 8443: ใบ ts.net ที่กล่อง tailscale ใช้ถอด TLS (Mosquitto ไม่เห็น) |
| `per_listener_settings` | `true` | `false` (Dynamic Security ต้องใช้กติกาเดียวทุก listener) |
| ฝั่งบอร์ด | `tls=false` ต่อ IP ของ LAN | `tls=true` ตรวจใบรับรองกับ ISRG Root X1/X2 (ใบ ts.net และใบ DuckDNS ออกโดย Let's Encrypt จึงตรวจผ่านด้วยใบรากชุดเดียวกัน) |

ทำไมแยก: ตอนพัฒนาอยากได้ตัวที่ตั้งง่ายใน 1 คำสั่ง บนเครื่องตัวเอง ส่วนของจริงเปิดสู่อินเทอร์เน็ต (ผ่าน Funnel 8443) ต้องเข้ารหัสและแยกสิทธิ์ ไม่งั้นบอร์ดตัวเดียวที่ถูกถอดไปอ่าน flash ก็ควบคุมทั้งอาคารได้

> [!WARN]
> บอร์ดคุยกับ Broker ที่ `127.0.0.1` ไม่ได้ เพราะ 127.0.0.1 บนบอร์ดคือตัวบอร์ดเอง (README_MQTT_HOST_EDIT) `MQTT_URL` ใน `backend/.env` ต้องใช้ LAN IP ของคอม ถ้าไม่งั้น `resolveMqttProvisioningSettings` จะส่ง host ที่บอร์ดต่อไม่ได้ให้ ฟังก์ชันนี้ใช้ `MQTT_DEVICE_URL` ก่อน (ถ้าตั้ง) แล้วค่อยถอยไปใช้ `MQTT_URL` เพราะ Backend ในของจริงต่อ `mqtt://mqtt:1883` ภายใน Docker แต่บอร์ดต้องต่อ `mqtts://` ที่เข้าถึงจากภายนอก (ค่าเริ่มต้น `mqtts://rmutt-energy.tailb292b4.ts.net:8443`)

### `setup_mqtt.ps1` ทีละส่วน (ไฟล์ `mqtt/setup_mqtt.ps1`)

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 2–10 | `param(... $Username='rmutt_air', $Port=1883, $BrokerHost='')` | พารามิเตอร์ ตรวจรูปแบบชื่อผู้ใช้ด้วย `ValidatePattern` และพอร์ตด้วย `ValidateRange` |
| 12–13 | `$ErrorActionPreference='Stop'` / `Set-StrictMode -Version Latest` | หยุดทันทีเมื่อผิดพลาด ไม่ให้สคริปต์เดินต่อทั้งที่พังครึ่งทาง |
| 32–45 | `Get-LanIPv4` | หา IPv4 ของการ์ดเครือข่ายที่ `Up` และมี default gateway ตัด `127.*` กับ `169.254.*` (IP ที่ระบบตั้งเองเมื่อไม่มี DHCP) |
| 47–61 | `New-RandomPassword` | สุ่ม 24 ไบต์ด้วย `RandomNumberGenerator` (ใช้ตัวสุ่มเข้ารหัสลับ ไม่ใช่ `Get-Random`) แปลง Base64 แล้วแทน `+`→`A`, `/`→`B` ตัด `=` เพื่อไม่ให้มีตัวอักษรที่ทำให้ `.env`/URL มีปัญหา |
| 102–114 | หา `$BrokerHost` + ปฏิเสธ `localhost`, `0.0.0.0`, `127.*` | กันความผิดพลาดที่กล่าวข้างต้น (บอร์ดต่อ 127.0.0.1 ไม่ได้) |
| 122–136 | เขียน `passwords` แล้ว `docker run eclipse-mosquitto:2.0 mosquitto_passwd -U` | ใส่ `user:password` แบบ plain ไว้ก่อน แล้วให้ `mosquitto_passwd -U` แปลงเป็น hash ในไฟล์เดิม (ไฟล์ไม่เก็บรหัสจริง) ถ้าพังลบไฟล์ทิ้ง |
| 138–143 | เขียน `acl` | `user rmutt_air` + `topic readwrite rmutt/ac/#` + `rmutt/occupancy/#` + `topic read $SYS/#` สิทธิ์อ่านเขียนเฉพาะสอง prefix ของโปรเจค (บอร์ดตรวจคนต้องมี prefix ที่สอง ถ้าตกไป Broker จะ "ปฏิเสธเงียบ ๆ" ข้อความหาย ทั้งที่ต่อติดและรหัสถูก) |
| 145–149 | เขียน `mqtt/.env` | `MQTT_USERNAME`, `MQTT_PASSWORD` ให้ docker compose ใช้ (healthcheck) |
| 151–161 | `Set-DotEnvValue` ใส่ `backend/.env` | ตั้ง `MQTT_REQUIRED=true`, `MQTT_URL=mqtt://<IP>:<Port>`, username/password, และ prefix ทั้งสอง **โดยไม่ลบค่าอื่น** (อัปเดตเฉพาะบรรทัดชื่อนั้น ไม่เจอก็เติมท้าย) |
| 163–172 | `docker compose --env-file .env up -d` แล้วเรียก `test_mqtt.ps1` | เปิด container แล้วทดสอบทันที |

### `test_mqtt.ps1` ทีละส่วน (ไฟล์ `mqtt/test_mqtt.ps1`)

| บรรทัด | ความหมาย |
|---|---|
| 4–20 | อ่าน `mqtt/.env` เป็นคู่ชื่อ=ค่า ตรวจว่ามี username/password ไม่งั้น throw |
| 22–23 | `$topic = "rmutt/ac/diagnostic-$PID"`: topic ทดสอบใต้ prefix ที่ ACL อนุญาต ต่อท้ายด้วย PID ของ PowerShell กันชนกัน |
| 24–40 | วนรอสูงสุด 35 วินาที จน `docker inspect` รายงาน health = `healthy` ไม่ทัน → พิมพ์ log 60 บรรทัดท้ายแล้ว throw |
| 42–47 | `mosquitto_pub ... -q 1 -r -t $topic -m $payload`: ส่ง QoS 1 แบบ **retained** (`-r`) |
| 49–55 | `mosquitto_sub ... -q 1 -C 1 -W 8`: รับ 1 ข้อความ (`-C 1`) รอไม่เกิน 8 วินาที (`-W 8`) แล้วเทียบกับ payload ที่ส่ง เพราะส่งแบบ retained การ subscribe ทีหลังก็ยังได้รับ จึงทดสอบทั้ง publish และ subscribe ได้ในคำสั่งเรียงกัน |
| 57–62 | `mosquitto_pub ... -r -n -t $topic`: `-n` = payload ว่าง + `-r` = ล้าง retained ไม่ทิ้งขยะบน Broker |

`start_mqtt.ps1` ตรวจว่ามี `.env` กับ `config/passwords` แล้ว `docker compose up -d` + `ps`; `stop_mqtt.ps1` ตรวจ `.env` แล้ว `docker compose down` (ข้อมูล retained อยู่ใน `data/` จึงไม่หาย)

## เจาะโค้ดทีละบรรทัด

### 1) `backend/src/utils/mqtt-topics.js` — รายการ topic ที่ต้องล้าง

**ไฟล์ `backend/src/utils/mqtt-topics.js` บรรทัด 1–26**

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
| 5 | `export const` = ให้ไฟล์อื่น import ไปใช้ได้ `Object.freeze` ทำให้ array แก้ไขต่อไม่ได้ กันโค้ดอื่นแอบ `push` เพิ่มจนรายการเพี้ยน |
| 6–11 | suffix ของ topic ที่อาจมี retained ค้างอยู่ของบอร์ดแอร์ สังเกตว่ามี `command` แม้ปกติ Backend ส่งไม่ retained (กันกรณีเวอร์ชันเก่าเคยส่ง retained) แต่ไม่มี `history`, `history-ack` เพราะส่งแบบไม่ retained เสมอ |
| 20 | ประกาศฟังก์ชัน รับ prefix (เช่น `rmutt/ac`), Device ID และรายการ suffix |
| 21 | `String(prefix ?? '')` — `??` คืนค่าขวาถ้าซ้ายเป็น `null/undefined` แล้วแปลงเป็นสตริงเสมอ; `.replace(/\/+$/, '')` ตัด `/` ท้ายสุดทุกตัวออก (regex: `\/+` = สแลชหนึ่งตัวขึ้นไป, `$` = ท้ายข้อความ) กัน `rmutt/ac//ESP32…` |
| 22 | `.trim()` ตัดช่องว่างหัวท้าย |
| 23 | ถ้าไม่มี prefix หรือ device ให้คืน array ว่าง ไม่สร้าง topic เพี้ยน เช่น `rmutt/ac//command` ซึ่งอาจไปล้าง topic ผิดที่ |
| 24 | `map` สร้าง topic เต็มทีละ suffix ด้วย template literal `` `${base}/${device}/${suffix}` `` |

ฟังก์ชัน `clearRetained` ใน `services/mqtt.js` เอา array นี้ไป publish **ข้อความว่าง + `retain: true`** ทีละ topic ซึ่งตามกติกา MQTT คือคำสั่ง "ลบ retained ของ topic นี้" ทำไมต้องล้าง: ถ้าไม่ล้าง `status`/`provision` เก่าจะค้างบน Broker แล้วย้อนกลับมาหลอกระบบ เมื่อเพิ่มบอร์ดรหัสเดิมกลับเข้ามาใหม่

### 2) เฟิร์มแวร์: ต่อ MQTT พร้อม LWT — `connectMqtt()`

**ไฟล์ `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 1064–1098**

```cpp:1064
  const String statusTopic = config.mqttTopic + "/status";
  const String clientId = "rmutt-" + config.deviceId;
  DynamicJsonDocument offline(96);
  offline["online"] = false;
  offline["deviceId"] = config.deviceId;
  String willPayload;
  serializeJson(offline, willPayload);

  bool connected;
  if (config.mqttUsername.isEmpty()) {
    connected = mqttClient.connect(
        clientId.c_str(),
        statusTopic.c_str(),
        1,
        true,
        willPayload.c_str());
  } else {
    connected = mqttClient.connect(
        clientId.c_str(),
        config.mqttUsername.c_str(),
        config.mqttPassword.c_str(),
        statusTopic.c_str(),
        1,
        true,
        willPayload.c_str());
  }
  if (!connected) {
    Serial.printf("MQTT connection failed, state: %d\n", mqttClient.state());
    return;
  }

  mqttClient.subscribe((config.mqttTopic + "/command").c_str(), 1);
  mqttClient.subscribe((config.mqttTopic + "/provision-ack").c_str(), 1);
  mqttClient.subscribe((config.mqttTopic + "/schedule-status").c_str(), 1);
  mqttClient.subscribe((config.mqttTopic + "/history-ack").c_str(), 1);
```

| บรรทัด | ความหมาย |
|---|---|
| 1064 | `config.mqttTopic` คือ `rmutt/ac/ESP32-<MAC>` (ได้จาก Backend ผ่าน BLE) ต่อ `/status` = topic ที่จะฝากพินัยกรรม `const String` = ตัวแปรสตริงของ Arduino ที่แก้ไม่ได้ |
| 1065 | client ID `rmutt-ESP32-<MAC>` ต้องตรงกับที่ Backend ลงทะเบียนในบัญชี Dynamic Security (`clientIdPrefix: 'rmutt-'`) ไม่ตรง Broker ปฏิเสธ |
| 1066–1070 | สร้าง JSON พินัยกรรม `{"online":false,"deviceId":…}` ด้วย ArduinoJson (`DynamicJsonDocument` ขนาด 96 ไบต์ในหน่วยความจำ heap) แล้ว `serializeJson` ลงสตริง |
| 1073–1079 | กรณีไม่มี username (โหมด Broker ไม่ต้อง auth) เรียก `connect(clientId, willTopic, willQoS, willRetain, willMessage)` อาร์กิวเมนต์ที่ 3 = `1` = **Will QoS 1** และที่ 4 = `true` = **Will retained** |
| 1080–1089 | กรณีมี username: เพิ่มอาร์กิวเมนต์ username/password เข้าไปก่อน (ลำดับพารามิเตอร์ของ `PubSubClient::connect`) Dynamic Security ใช้ username = Device ID |
| 1090–1093 | ต่อไม่ติด → พิมพ์ `state` (รหัสข้อผิดพลาดของ PubSubClient เช่น 5 = ไม่ได้รับอนุญาต) แล้ว `return` โดย `loop()` จะลองใหม่ทุก 3 วินาที |
| 1095–1098 | subscribe 4 topic ด้วย QoS 1 ทุกครั้งที่ต่อติด (เพราะ clean session) ตรงกับ ACL `subscribe` ของบอร์ดแอร์พอดี ถ้า subscribe topic ที่ไม่มีสิทธิ์ Broker จะเงียบ |

หลังบรรทัด 1098 โค้ดตั้งหน่วงสุ่มก่อนส่งประวัติ แล้วเรียก `publishStatus()`, `publishState()` และ `publishProvisioningToken()` ทันที ทำไม publish `status` ทันทีที่ต่อติด: เพื่อ **ทับพินัยกรรมเก่า** (retained `online:false`) ที่ Broker ปล่อยไว้ตอนหลุดครั้งก่อน ให้กลับเป็น `online:true`

> [!WHY]
> **ทำไม LWT ต้อง retained**: ถ้า Backend รีสตาร์ตระหว่างที่บอร์ดหลุด แล้ว LWT ไม่ retained Backend จะไม่เคยรู้ว่าบอร์ด offline เพราะข้อความหลุดไปตอนมันไม่ได้ฟัง retained ทำให้ Backend ได้ "สถานะล่าสุดจริง" ทันทีที่ subscribe

### 3) เฟิร์มแวร์: callback ตอนรับ MQTT — `mqttCallback()`

**ไฟล์ `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 1114–1116 และ 1143–1165**

```cpp:1114
void mqttCallback(char *topic, byte *payload, unsigned int length) {
  if (length == 0 || length > 2048) return;
  const String incomingTopic(topic);
```

```cpp:1143
  if (incomingTopic == config.mqttTopic + "/provision-ack") {
    DynamicJsonDocument acknowledgement(512);
    if (deserializeJson(acknowledgement, payload, length)) return;
    const String acknowledgedToken = acknowledgement["token"] | "";
    if (acknowledgement["activated"] == true &&
        !config.provisioningToken.isEmpty() &&
        acknowledgedToken == config.provisioningToken) {
      preferences.begin("rmutt-air", false);
      preferences.remove("prov_token");
      preferences.end();
      config.provisioningToken = "";
      provisionAckClearReady = true;
    }
    return;
  }
  if (incomingTopic != config.mqttTopic + "/command") return;
  pendingMqttCommand = "";
  pendingMqttCommand.reserve(length);
  for (unsigned int index = 0; index < length; index++) {
    pendingMqttCommand += static_cast<char>(payload[index]);
  }
  mqttCommandReady = true;
}
```

| บรรทัด | ความหมาย |
|---|---|
| 1114 | ลายเซ็น callback ที่ PubSubClient บังคับ: `char *topic` (ชื่อ topic), `byte *payload` (ไบต์ดิบ ไม่มี `\0` ปิดท้าย), `length` (จำนวนไบต์) `*` คือ pointer = ที่อยู่ของหน่วยความจำที่เก็บข้อมูล |
| 1115 | ทิ้งข้อความว่าง (เช่นข้อความล้าง retained) หรือใหญ่เกิน 2048 ไบต์ (ขนาด buffer ที่ตั้ง `setBufferSize(2048)` ใน `setup`) |
| 1116 | แปลง topic เป็น `String` เพื่อเทียบด้วย `==` |
| 1143 | แยกตามชนิด topic: นี่คือ ack ของ provisioning |
| 1145 | `deserializeJson(doc, payload, length)` คืนค่า error (ไม่ใช่ศูนย์ = true) ถ้า JSON เสีย → `return` ทิ้ง ต้องส่ง `length` เพราะ payload ไม่มี `\0` |
| 1146 | `acknowledgement["token"] \| ""` — ใน ArduinoJson `\|` ใช้ให้ค่าเริ่มต้นถ้าไม่มีฟิลด์ (ต่างจาก `\|\|` ของภาษาอื่น) |
| 1147–1149 | เงื่อนไข 3 ข้อพร้อมกัน: ack บอกว่า `activated == true`, บอร์ดยังมี token เก็บอยู่ และ token ใน ack **ตรงกับของตัวเอง** (กันใครส่ง ack ปลอม/ของบอร์ดอื่นมา) |
| 1150–1152 | ลบ key `prov_token` ออกจาก NVS (namespace `rmutt-air`) ผ่าน `Preferences` ลบแล้ว token ที่เคยส่งผ่านอากาศไม่มีเหลือที่บอร์ด |
| 1153–1154 | ล้าง token ในหน่วยความจำ และตั้งธง `provisionAckClearReady` ให้ `loop()` ไป publish ข้อความว่างล้าง retained ของ `/provision-ack` |
| 1158 | ถ้าไม่ใช่ `/command` ทิ้ง (เช่น `schedule-status`, `history-ack` ถูกจัดการก่อนหน้านี้แล้ว) |
| 1159–1164 | **คัดลอกคำสั่งไปเก็บ** แล้วตั้งธง `mqttCommandReady` ไม่ได้ประมวลผลทันที |

**ทำไมไม่ทำงานใน callback**: callback ถูกเรียกขณะ `mqttClient.loop()` ทำงานอยู่ ถ้าทำงานหนัก (ส่งสัญญาณ IR ซึ่งใช้เวลา, เขียน NVS, parse JSON ใหญ่, publish ตอบกลับซึ่งเรียก PubSubClient ซ้ำซ้อนกลางการประมวลผล) อาจทำให้เชื่อมต่อค้างหรือหลุด keep-alive และ buffer ชนกัน จึงใช้แพทเทิร์น "callback แค่ฝากของ แล้วให้ `loop()` เป็นคนทำ" (`if (mqttCommandReady) processMqttCommand();` ใน `loop`) เช่นเดียวกับ OTA (`otaRequested`) และการลบ flash ของ history

### 4) เฟิร์มแวร์: ตัวรับคำสั่งเขียน BLE — `ConfigCallbacks::onWrite`

**ไฟล์ `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 315–338**

```cpp:315
  void onWrite(BLECharacteristic *characteristic) override {
    auto raw = characteristic->getValue();
    const size_t length = raw.length();
    if (length < 6) {
      notifyBle(false, "invalid_packet", "BLE packet is too short");
      return;
    }
    // ESP32 Arduino Core 3.x returns Arduino String here.
    // String has c_str(), but does not provide data() on every core version.
    const uint8_t *data =
        reinterpret_cast<const uint8_t *>(raw.c_str());
    if (data[0] != 1 || data[1] != 1) {
      notifyBle(false, "unsupported_version", "Unsupported BLE protocol");
      return;
    }

    const uint16_t sequence =
        (static_cast<uint16_t>(data[2]) << 8) | data[3];
    const uint16_t total =
        (static_cast<uint16_t>(data[4]) << 8) | data[5];
    if (total == 0 || total > 32 || sequence >= total) {
      notifyBle(false, "invalid_packet", "Invalid BLE sequence");
      return;
    }
```

**บรรทัด 339–368 (ประกอบข้อมูล)**

```cpp:339
    if (sequence == 0) {
      receivedConfig = "";
      expectedSequence = 0;
      expectedTotal = total;
      receivedConfig.reserve(MAX_CONFIG_BYTES);
    }
    if (sequence != expectedSequence || total != expectedTotal) {
      receivedConfig = "";
      expectedSequence = 0;
      expectedTotal = 0;
      notifyBle(false, "sequence_error", "BLE packets arrived out of order");
      return;
    }
    if (receivedConfig.length() + length - 6 > MAX_CONFIG_BYTES) {
      receivedConfig = "";
      notifyBle(false, "config_too_large", "Configuration is too large");
      return;
    }

    for (size_t index = 6; index < length; index++) {
      receivedConfig += static_cast<char>(data[index]);
    }
    expectedSequence++;
    if (expectedSequence == expectedTotal) {
      pendingConfig = receivedConfig;
      configReady = true;
      receivedConfig = "";
      expectedSequence = 0;
      expectedTotal = 0;
    }
  }
```

| บรรทัด | ความหมาย |
|---|---|
| 315 | `onWrite` = callback ที่ไลบรารี BLE เรียกทุกครั้งที่แอปเขียน characteristic `…0002` `override` = บอกว่าเป็นการเขียนทับเมธอดของคลาสแม่ `BLECharacteristicCallbacks` |
| 316–317 | `auto` ให้คอมไพเลอร์เดาชนิด `getValue()` ได้ข้อมูลที่แอปเพิ่งเขียน |
| 318–321 | หัว packet 6 ไบต์ ถ้าสั้นกว่านั้นผิดแน่ แจ้ง error ทาง Notify |
| 324–325 | `reinterpret_cast<const uint8_t*>` = ตีความตัวอักษรของสตริงเป็น "อาร์เรย์ไบต์ไม่มีเครื่องหมาย" เพื่ออ่านค่า 0–255 ได้ตรง ๆ |
| 326 | ตรวจ `data[0]` (เวอร์ชัน) และ `data[1]` (ชนิดข้อความ) ต้องเป็น 1 ทั้งคู่ — ถ้าปรับโปรโตคอลในอนาคต บอร์ดเก่าจะปฏิเสธชัดเจน |
| 331–332 | ประกอบเลข 16 บิตแบบ **big-endian**: ไบต์ `data[2]` เป็นครึ่งบน เลื่อนซ้าย 8 บิต (`<< 8`) แล้ว `\|` ไบต์ล่าง `data[3]` ตัวอย่าง `0x01 0x2C` → 256 + 44 = 300 `static_cast<uint16_t>` กันไม่ให้ไบต์ถูกเลื่อนบิตจนล้นก่อนแปลง |
| 333–334 | `total` จากไบต์ 4–5 ด้วยวิธีเดียวกัน |
| 335 | กันข้อมูลเพี้ยน: `total` ต้อง 1–32 และ `sequence` ต้องน้อยกว่า `total` (จำกัด 32 packet = 32×150 ≈ 4.8 KB เกิน `MAX_CONFIG_BYTES` พอดี เป็นแนวกันชั้นแรก) |
| 339–344 | packet แรก (`sequence == 0`) → เริ่มประกอบใหม่: ล้างบัฟเฟอร์ จำจำนวน packet ทั้งหมด จองหน่วยความจำ 4096 ไบต์ล่วงหน้า (`reserve`) ลดการจัดสรรใหม่ซ้ำ ๆ ที่ทำให้หน่วยความจำแตกเป็นชิ้น |
| 345–351 | ถ้า packet ที่มาไม่ใช่ลำดับที่รอ หรือ `total` เปลี่ยน → ทิ้งทั้งหมดแล้วให้แอปเริ่มใหม่ (ใช้ write-with-response ของแอปจึงปกติมาเรียง แต่ป้องกันไว้) |
| 352–356 | กันบัฟเฟอร์ล้น: ขนาดสะสม + ขนาดชิ้นนี้ (ตัดหัว 6 ไบต์) ต้องไม่เกิน 4096 |
| 358–360 | วนต่อไบต์ข้อมูล (ตั้งแต่ index 6) ลงสตริงทีละตัว |
| 361–368 | นับ packet ที่ได้รับ ถ้าครบ → ย้ายไป `pendingConfig`, ตั้งธง `configReady`, ล้างตัวแปรประกอบ — แล้วจบ **ไม่ประมวลผลที่นี่** |

**ทำไมใช้ธง `configReady` แล้วให้ `loop()` เรียก `processPendingConfig()`**: การประมวลผลต้องทดสอบ Wi-Fi (นานถึง 15 วินาที), เขียน NVS, ซึ่งทำใน callback ของ BLE ไม่ได้ (callback รันบน task ของ BLE stack การบล็อกนานทำให้การเชื่อมต่อหลุด/หมดเวลา) แพทเทิร์นเดียวกับ MQTT ข้างบน และผลลัพธ์ส่งกลับทาง Notify (`notifyBle`) ซึ่งแอปรอได้สูงสุด 40 วินาที

### 5) เฟิร์มแวร์: ล้างค่าเมื่อถูกลบออกจากแอป — `unprovisionAndRestart()` (เพิ่ม 13 ต.ค. 2569)

**ไฟล์ `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 1229–1239** (กิ่ง `unprovision` ใน `processMqttCommand`)

```cpp:1229
  if (action == "unprovision") {
    // Backend ส่งมาเมื่อแอดมินกดลบอุปกรณ์ในแอป
    // ตรวจ deviceId ซ้ำอีกชั้น กันข้อความหลงมาผิด topic
    const String target = document["deviceId"] | "";
    if (target != config.deviceId) {
      Serial.printf("Unprovision ignored: deviceId '%s' is not this board\n", target.c_str());
      return;
    }
    unprovisionAndRestart("removed from the app");
    return;
  }
```

| บรรทัด | ความหมาย |
|---|---|
| 1229 | `action` อ่านมาก่อนหน้านี้ด้วย `document["action"] \| ""` (ไม่มีฟิลด์ได้สตริงว่าง) โค้ดนี้อยู่ใน `processMqttCommand()` ที่ `loop()` เรียก ไม่ใช่ใน callback จึง publish/disconnect ได้อย่างปลอดภัย |
| 1232 | ดึง `deviceId` ที่ Backend ใส่มาในข้อความ ถ้าไม่มีได้ `""` |
| 1233–1236 | ไม่ตรงกับรหัสของตัวเอง → พิมพ์ลง Serial แล้ว `return` **ไม่ล้าง** ปกติ topic ก็บอกอยู่แล้วว่าเป็นของบอร์ดไหน แต่คำสั่งนี้ทำลายค่าทั้งหมดและย้อนกลับไม่ได้ จึงตรวจซ้ำอีกชั้น (defense in depth) |
| 1237 | ผ่านแล้วเรียกฟังก์ชันล้างค่า ซึ่งจบด้วย `ESP.restart()` (ไม่กลับมาที่บรรทัด 1238 จริง ๆ แต่เขียน `return` ไว้ให้อ่านง่ายและปลอดภัยถ้าแก้ฟังก์ชันภายหลัง) |

บอร์ดตรวจคน (`rmutt_esp32_occupancy.ino`) ต่างนิดเดียว: ตรวจ `deviceId` ใน `mqttCallback` แล้ว**ตั้งธง** `unprovisionRequested = true` ให้ `loop()` เรียก `unprovisionAndRestart` ภายหลัง เพราะบอร์ดนั้นประมวลผลคำสั่งใน callback โดยตรง และการ publish + disconnect ภายใน callback ของ PubSubClient เสี่ยงทำให้ไลบรารีพัง (แพทเทิร์นเดียวกับ `otaRequested`)

**ไฟล์ `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 1174–1208**

```cpp:1174
void unprovisionAndRestart(const String &reason) {
  Serial.printf("Unprovision: %s - clearing all saved settings\n", reason.c_str());
  if (mqttClient.connected()) {
    // ตอบ Backend ว่าล้างค่าแล้ว (Backend รอคำตอบนี้ก่อนลบบัญชี MQTT ของบอร์ด)
    DynamicJsonDocument ack(128);
    ack["deviceId"] = config.deviceId;
    ack["online"] = false;
    ack["unprovisioned"] = true;
    String ackPayload;
    serializeJson(ack, ackPayload);
    const String statusTopic = config.mqttTopic + "/status";
    mqttClient.publish(statusTopic.c_str(), ackPayload.c_str(), false);
    // ล้าง retained ของตัวเอง แล้วตัดการเชื่อมต่อแบบปกติ
    // (ตัดแบบปกติ Broker จะไม่ส่ง Last Will "online:false" กลับมาค้างเป็น retained)
    mqttClient.publish(statusTopic.c_str(), "", true);
    mqttClient.publish((config.mqttTopic + "/state").c_str(), "", true);
    mqttClient.loop();
    delay(300);
    mqttClient.disconnect();
  }

  preferences.begin("rmutt-air", false);
  preferences.clear();
  preferences.end();
  preferences.begin("rmutt-state", false);
  preferences.clear();   // สถานะแอร์ + hist_ack
  preferences.end();

  if (historyFlash.partition != nullptr) {
    esp_partition_erase_range(historyFlash.partition, 0, historyFlash.partition->size);
  }

  Serial.println("Unprovision: done, restarting into BLE setup mode");
  delay(300);
  ESP.restart();
}
```

| บรรทัด | ความหมาย |
|---|---|
| 1174 | `const String &reason` = รับสตริงแบบอ้างอิง (reference `&`) ไม่คัดลอก และ `const` = ห้ามแก้ ใช้แค่พิมพ์ลง Serial |
| 1176 | ส่งคำตอบได้เฉพาะตอนยังต่อ MQTT อยู่ (ปกติต่ออยู่เพราะเพิ่งได้คำสั่งมา) ถ้าไม่ต่อก็ข้ามไปล้าง NVS เลย ไม่ค้างรอ |
| 1178–1183 | สร้าง JSON คำตอบ `{"deviceId":…,"online":false,"unprovisioned":true}` ขนาด 128 ไบต์ ใส่ `online:false` ด้วยเพื่อให้ Backend รุ่นเก่าที่ไม่รู้จัก `unprovisioned` อย่างน้อยเข้าใจว่าบอร์ดออฟไลน์ |
| 1185 | publish คำตอบที่ `…/status` อาร์กิวเมนต์สุดท้าย `false` = **ไม่ retained** (เหตุการณ์ครั้งเดียว) ใช้ topic `status` เพราะ ACL ของบอร์ดอนุญาตให้ publish อยู่แล้ว ไม่ต้องเพิ่ม topic ใหม่ |
| 1188–1189 | publish ข้อความว่าง `""` แบบ retained (`true`) ที่ `status` และ `state` = ลบ retained ของตัวเองบน Broker บอร์ดตรวจคนล้างแค่ `status` เพราะไม่มี `state` |
| 1190–1191 | `mqttClient.loop()` + หน่วง 300 ms ให้ PubSubClient ส่งข้อความในบัฟเฟอร์ออกไปจริงก่อนตัด |
| 1192 | `disconnect()` ส่งแพ็กเก็ต DISCONNECT ตามมาตรฐาน Broker จึงรู้ว่า "ลาอย่างปกติ" และ **ทิ้ง Last Will** ไม่ปล่อย `online:false` แบบ retained กลับมาทับ |
| 1195–1197 | เปิด namespace `rmutt-air` ของ NVS แบบเขียนได้ (`false` = ไม่ใช่ read-only) แล้ว `clear()` ลบทุก key: Wi-Fi SSID/รหัส, MQTT host/port/username/password, ห้อง, เบอร์แอร์, token, ตารางเปิดปิด |
| 1198–1200 | ล้าง namespace `rmutt-state` (สถานะแอร์ล่าสุดและตัวชี้ `hist_ack` ของประวัติ) |
| 1202–1204 | ลบพาร์ติชันประวัติ `rmuttlog` ทั้งก้อนด้วย `esp_partition_erase_range` (flash ต้อง erase เป็นบล็อก) ไม่ให้ข้อมูลไฟของห้องเก่าถูกส่งขึ้นไปในนามห้องใหม่หลังตั้งค่าใหม่ ตรวจ `nullptr` ก่อนเพราะถ้าแฟลชด้วย partition table ที่ไม่มี `rmuttlog` ตัวชี้จะว่าง |
| 1206–1208 | หน่วงให้ Serial พิมพ์ทัน แล้ว `ESP.restart()` บูตใหม่ บอร์ดพบว่า `configured` เป็น false (ถูกล้าง) จึงเปิด BLE รอตั้งค่าเหมือนบอร์ดใหม่ |

> [!WHY]
> ทำไมไม่ใช้ `nvs_flash_erase()` แบบ `reset.ino` ที่ล้างทั้งชิป: `preferences.clear()` ล้างเฉพาะ namespace ของโปรแกรมเรา ไม่ไปยุ่งกับข้อมูลระบบอื่นใน NVS (เช่นค่าคาลิเบรตของ Wi-Fi/PHY ที่ไลบรารีเก็บ) และทำได้ขณะโปรแกรมรันอยู่ ไม่ต้อง deinit NVS ก่อน ผลที่ต้องการ (ลืม Wi-Fi/MQTT/ห้อง) ได้ครบเหมือนกัน

## หลักการเขียนโค้ดที่ใช้ในส่วนนี้

- **สัญญาร่วม (shared contract) เขียนซ้ำในหลายที่โดยต้องตรงกัน**: UUID ซ้ำใน `.ino` สองไฟล์และ `ble_provisioning_service.dart`; ชื่อ topic ใน `.ino`, `services/mqtt.js`, `utils/mqtt-accounts.js` (ACL) ไม่มี codegen ดังนั้นไฟล์ `docs/BLE_MQTT_PROTOCOL.md` เป็นศูนย์กลางอ้างอิงและเวลาเพิ่ม topic ต้องแก้ครบทั้งสามที่ (รวม ACL ไม่งั้นถูกปฏิเสธเงียบ)
- **Callback ฝากของ แล้ว loop ทำงาน** (`mqttCallback`, `ConfigCallbacks`, `WifiScanCallbacks` เป็นข้อยกเว้นเพราะเบา) เหตุผลคือกันบล็อก stack ของไลบรารี
- **Retained = "สถานะล่าสุด", ไม่ retained = "คำสั่งครั้งเดียว"**: `state`/`status`/`provision`/`schedule-status` retained เพราะผู้มาทีหลังต้องเห็นค่าล่าสุด; `command`/`history` ไม่ retained เพราะการเล่นซ้ำจะเป็นอันตราย (เปิดแอร์ซ้ำ นับพลังงานซ้ำ)
- **สั่งก่อนเพิกถอน (notify before revoke)** (`unprovision`, เพิ่ม 13 ต.ค. 2569): ส่งคำสั่งล้างค่าและรอคำตอบ (มี timeout 4 วินาที) ก่อนลบบัญชี MQTT เพราะหลังเพิกถอนสิทธิ์แล้วจะคุยกับบอร์ดไม่ได้อีก และ timeout ทำให้การลบไม่ค้างเมื่อบอร์ดออฟไลน์ คำสั่งทำลายข้อมูลแบบนี้ไม่ retained และใส่ `deviceId` ซ้ำในเนื้อข้อความให้บอร์ดตรวจ
- **เพิ่มฟิลด์ได้โดยไม่ทำให้ใครพัง (backward-compatible fields)**: `controlType` ใน Identity, `controlMode`/`busOk` ฯลฯ ใน `status` ฝ่ายที่ไม่รู้จักแค่ไม่อ่าน ฝ่ายที่รู้จักใช้ค่าเริ่มต้นเมื่อไม่มีฟิลด์ (ไม่มี `controlType` = `ir`)
- **Ack-then-delete** (`history-ack`, `provision-ack`): ผู้ส่งเก็บข้อมูลจนกว่าผู้รับยืนยัน ทำให้ไม่มีข้อมูลหาย และส่งซ้ำได้โดยผู้รับต้องทน duplicate (idempotent) Backend ข้ามรายการที่เคยบันทึก
- **Least privilege (สิทธิ์น้อยที่สุด)**: ACL รายอุปกรณ์ (`deviceAcls`) ให้เห็นเฉพาะ topic ตัวเอง
- **Pure function แยกจากการทำงานจริง**: `utils/mqtt-accounts.js`, `utils/mqtt-topics.js`, `utils/mqtt-provisioning.js` คำนวณล้วน ๆ (ทดสอบง่าย) ส่วน `services/mqtt*.js` เป็นตัวคุยกับ Broker จริง
- **Observer / listener** (`onAirStatus`, `onOccupancyStatus`, `onMqttConnected` ใน `services/mqtt.js`): ให้ `auto-off.js` และ `mqtt-accounts.js` สมัครรับเหตุการณ์ได้ โดย `mqtt.js` ไม่ต้อง import ไฟล์เหล่านั้น หลีกเลี่ยง import วน (circular dependency) และ `notify()` จับ error ของ listener แต่ละตัวไม่ให้ล้มทั้งระบบ
- **Defense in depth**: OTA มีสามชั้น, provisioning ใช้ token + hash + หมดอายุ 15 นาที + constant-time compare, โหมดกู้ Wi-Fi ล็อกค่า server
- **Serial per device** (`runSerialForDevice`): ข้อความ `status`/`history` ของบอร์ดเดียวกันถูกประมวลผลทีละอัน กัน race condition ตอนอ่านค่าเดิมแล้วเขียนทับ
- **Defensive parsing**: ข้อความที่ JSON เสียถูกทิ้งเงียบ ๆ (`catch { return; }`) เพราะ MQTT ไม่มีใครรอตอบ error และไม่ควรให้ข้อความขยะทำให้ Backend ล้ม

## คำถามที่อาจารย์อาจถาม

> [!ASK]
> **ทำไมใช้ MQTT ไม่ใช้ HTTP polling หรือ WebSocket?**
> MQTT คงการเชื่อมต่อค้าง ส่งคำสั่งถึงบอร์ดได้ทันทีโดยบอร์ดไม่ต้องถามซ้ำ ๆ ประหยัดทั้งแบนด์วิดท์และไฟ มี retained (เก็บสถานะล่าสุด) และ Last Will (รู้ว่าบอร์ดหลุด) ให้ในตัว ซึ่ง HTTP polling กับ WebSocket ต้องเขียนเองทั้งหมด และบอร์ดอยู่หลัง NAT ก็ใช้ได้เพราะเป็นฝ่ายต่อออกไปหา Broker

> [!ASK]
> **แอปสั่งแอร์ผ่าน MQTT โดยตรงไหม?**
> ไม่ แอปยิง HTTP ไปที่ Backend (`POST /api/air-conditioners/:id/command`) Backend ตรวจสิทธิ์ ตรวจค่า แล้วค่อย publish ไป `rmutt/ac/<deviceId>/command` เหตุผล: (1) ไม่ต้องแจกรหัส MQTT ให้ทุกเครื่องผู้ใช้ (2) Backend ตรวจสิทธิ์/ความถูกต้องได้ที่จุดเดียว (3) บันทึกประวัติและทำปิดแอร์อัตโนมัติได้

> [!ASK]
> **Retained message คืออะไร และโปรเจคใช้กับอะไร?**
> Broker จำข้อความสุดท้ายของ topic ไว้ส่งให้คนที่ subscribe ทีหลัง ใช้กับ `status`, `state`, `provision`, `provision-ack`, `schedule-status` เพื่อให้ Backend/บอร์ดที่เพิ่งเริ่มทำงานเห็นสถานะล่าสุดทันที ส่วน `command` ไม่ retained เพราะถ้า retained บอร์ดที่ต่อกลับหลังไฟดับจะได้รับคำสั่ง "เปิดแอร์" เก่าซ้ำ

> [!ASK]
> **Last Will ใช้ทำอะไร?**
> ตอนต่อ Broker บอร์ดฝากข้อความ `{"online":false,…}` ไว้ที่ topic `status` (QoS 1, retained) ถ้าบอร์ดหลุดแบบไม่ปกติ Broker ปล่อยข้อความนี้แทน Backend จึงรู้ว่า offline ทันทีโดยไม่ต้องรอหมดเวลา ตอนกลับมาออนไลน์บอร์ดส่ง `online:true` ทับ

> [!ASK]
> **ทำไมต้องมี BLE ทั้งที่มี Wi-Fi และ MQTT?**
> บอร์ดใหม่ไม่รู้ SSID/รหัสผ่านและไม่รู้ที่อยู่ Broker จึงเข้าเครือข่ายไม่ได้ BLE เป็นช่องทางระยะใกล้ที่ไม่ต้องมีเครือข่าย ใช้ส่งค่าตั้งต้นครั้งแรก และกู้บอร์ดเมื่อ Wi-Fi หลุด ช่องทางนี้ต้องอยู่ใกล้ตัวบอร์ดจริงซึ่งเป็นการป้องกันอีกชั้น

> [!ASK]
> **Provisioning token มีไว้ทำไม ในเมื่อมี Device ID แล้ว?**
> Device ID มาจาก MAC ซึ่งไม่ใช่ความลับ (ประกาศผ่าน BLE) ถ้าไม่มี token ใครก็อ้างเป็นบอร์ดนั้นได้ token สุ่ม 24 ไบต์ส่งทาง BLE เท่านั้น (ต้องอยู่ใกล้) Backend เก็บแค่ hash หมดอายุใน 15 นาที เทียบแบบ constant-time เมื่อบอร์ดส่งกลับมาทาง MQTT และใช้ได้แค่ครั้งเดียว (เคลียร์ทั้งสองฝั่งหลัง ack)

> [!ASK]
> **ข้อความ BLE ใหญ่เกิน MTU ทำอย่างไร?**
> หั่น JSON เป็นชิ้นละ 150 ไบต์ ใส่หัว 6 ไบต์ (เวอร์ชัน, ชนิด, ลำดับ 2 ไบต์, จำนวนทั้งหมด 2 ไบต์) บอร์ดตรวจลำดับ รวมเป็นสตริง เมื่อครบจึงประมวลผล ผิดลำดับ/ใหญ่เกิน/เวอร์ชันไม่ตรงจะตอบ error ทาง Notify แอปรอผลสุดท้ายสูงสุด 40 วินาที เพราะบอร์ดต้องทดสอบ Wi-Fi ก่อนบันทึก

> [!ASK]
> **ถ้าใส่รหัส Wi-Fi ผิดแล้วบันทึกเกิดอะไร?**
> บอร์ดทดสอบต่อ Wi-Fi ด้วยค่าใหม่ก่อน (15 วินาที) ถ้าไม่ผ่านจะไม่เขียนทับ NVS ตอบ `wifi_connection_failed` แอปอยู่หน้าเดิมให้แก้แล้วกดบันทึกใหม่ได้ ไม่ต้องล้าง flash และถ้าเป็นการตั้งค่าซ้ำบนบอร์ดที่ออนไลน์อยู่ บอร์ดกู้ Wi-Fi/MQTT เดิมกลับมา

> [!ASK]
> **ถ้าบอร์ดหลุดเน็ตหลายชั่วโมง ข้อมูลค่าไฟหายไหม?**
> ไม่หาย บอร์ดสรุปทุก 5 นาทีเก็บลง flash (ราว 7 วัน) พอกลับมาก็ส่ง `history` ทีละ 10 รายการ รอ `history-ack` จาก Backend แล้วจึงลบจาก flash ถ้าไม่ได้รับ ack จะส่งซ้ำ และ Backend ข้ามรายการที่เคยบันทึก (ไม่นับซ้ำ) ระหว่างนั้น Backend ไม่บันทึกค่าสดลงประวัติเพื่อไม่ให้นับซ้ำ

> [!ASK]
> **ปลอดภัยแค่ไหนถ้ามีคนขโมยบอร์ดหนึ่งตัวไปอ่านรหัสใน flash?**
> ใช้โหมด Dynamic Security: แต่ละบอร์ดมี username/รหัสของตัวเอง (HMAC จาก Device ID กับ secret ของเซิร์ฟเวอร์) และ ACL อนุญาตเฉพาะ topic ของตัวเอง จึงสั่งแอร์ห้องอื่นไม่ได้ ถอดอุปกรณ์ออกจากระบบแล้วบัญชีถูกลบ นอกจากนี้การเชื่อมต่อจริงใช้ TLS (ค่าเริ่มต้นผ่าน Funnel พอร์ต 8443 หรือ 8883 เมื่อต่อตรง) ตรวจใบรับรองกับใบราก และ Broker ที่เข้าถึงจากอินเทอร์เน็ตได้ก็ยังบังคับบัญชีรายบอร์ด

> [!ASK]
> **ลบแอร์ในแอปแล้ว บอร์ดยังจำรหัส Wi-Fi อยู่ไหม?**
> ถ้าบอร์ดออนไลน์ตอนลบ ไม่จำครับ (ตั้งแต่ 13 ต.ค. 2569) Backend ส่ง `{"action":"unprovision","deviceId":…}` ไปที่ `command` ก่อนลบบัญชี MQTT บอร์ดตรวจว่า `deviceId` เป็นของตัวเอง ตอบ `{"unprovisioned":true}` ทาง `status` ล้าง retained ของตัวเอง ตัดการเชื่อมต่อแบบปกติ แล้ว `preferences.clear()` ลบ Wi-Fi, MQTT, ห้องใน NVS และรีบูตเข้าโหมดตั้งค่า BLE API ตอบ `boardCleared: true` ถ้าบอร์ดออฟไลน์ คำสั่งไปไม่ถึง (ไม่ได้ส่งแบบ retained) API ตอบ `boardCleared: false` บอร์ดยังเก็บค่าเดิมแต่ต่อ Broker ไม่ได้แล้วเพราะบัญชีถูกลบ ต้องไปล้างที่ตัวบอร์ด

> [!ASK]
> **ทำไมคำสั่ง unprovision ไม่ส่งแบบ retained จะได้ถึงบอร์ดที่ออฟไลน์ตอนกลับมา?**
> เพราะ Device ID มาจาก MAC ไม่เปลี่ยน ถ้าคำสั่งค้างบน Broker แล้ววันหลังเราเพิ่มบอร์ดตัวเดิมกลับเข้าระบบ บอร์ดจะได้คำสั่งค้างทันทีที่ subscribe แล้วล้างตัวเองทิ้งอีกรอบ อีกอย่างบัญชี MQTT ของบอร์ดถูกลบไปแล้ว บอร์ดที่กลับมาก็ต่อ Broker ไม่ได้อยู่ดี คำสั่ง retained จึงไม่มีประโยชน์และมีโทษ

> [!ASK]
> **บอร์ดสายแอร์กับบอร์ด IR แยกกันอย่างไรในโปรโตคอล?**
> ใช้ Device ID, ชื่อ BLE, topic และ ACL ชุดเดียวกัน แยกด้วยฟิลด์ข้อมูล: Identity BLE มี `controlType: "wired"` และ `brand: "Daikin"` (บอร์ด IR ส่ง `"ir"`) และ `status` มี `controlMode: "wired"` ถ้าฐานข้อมูลยังเก็บยี่ห้อ IR Backend แก้เป็น `DAIKIN_WIRED` ให้เอง และ REST API ส่ง `controlType` ให้แอปรู้ว่าต้องซ่อนปุ่มที่รีโมตติดผนังไม่มี (Eco, Turbo, Quiet, Clean, สวิงแนวนอน)

> [!ASK]
> **ถ้าแอดมินสั่งไฟล์เฟิร์มแวร์ของบอร์ด IR ให้บอร์ดสายแอร์ จะเกิดอะไร?**
> Backend ปฏิเสธตั้งแต่ต้น (400) ด้วย `assertFirmwareKind` ซึ่งดูชนิดจากชื่อไฟล์ (`wired`/`slm8` = สายแอร์, `occ` = เซ็นเซอร์) เทียบกับ protocol ของบอร์ด เพราะตัวบอร์ดเองตรวจแค่ URL ไม่รู้ว่าไฟล์เป็นของรุ่นไหน ถ้าปล่อยผ่าน บอร์ดจะติดตั้งได้ (ชิปเดียวกัน) แล้วรีบูตเป็นโปรแกรมผิดชนิด

## สรุปและเช็กลิสต์ความเข้าใจ

ถ้าตอบข้อเหล่านี้ได้ แปลว่าเข้าใจบทนี้แล้ว

- [ ] อธิบายได้ว่า Broker, client, topic, publish/subscribe, wildcard `+`/`#` คืออะไร และใครเป็น client บ้างในระบบ (บอร์ดแอร์ บอร์ดตรวจคน Backend — แอปไม่ใช่)
- [ ] บอกได้ว่า QoS 0/1 ต่างกันอย่างไร และโปรเจคใช้อะไรที่ไหน (Backend ใช้ 1, `PubSubClient.publish` ของบอร์ดเป็น 0, LWT/subscribe เป็น 1)
- [ ] บอกได้ว่าอะไร retained อะไรไม่ retained พร้อมเหตุผล (`command`/`history` ไม่, `state`/`status`/`provision`/`provision-ack`/`schedule-status` ใช่)
- [ ] เขียน topic ของบอร์ดแอร์และบอร์ดตรวจคนได้ครบ พร้อมทิศทาง และรู้ว่า `history`/`history-ack` เป็นของแอร์เท่านั้น
- [ ] อธิบายรูปแบบ Device ID (`ESP32-`/`OCC32-` + MAC 12 หลัก), ชื่อ BLE (`RMUTT-AC-`/`RMUTT-OCC-`), client ID
- [ ] อธิบาย LWT ว่าทำงานอย่างไรและทำไม payload ของบอร์ดตรวจคนมี `radarAvailable:false`
- [ ] บอก UUID ทั้ง 6 ตัว (`7b57000N-a243-4e5b-8f13-179af81b2457`, N = 1–6) และ property ของแต่ละตัวได้
- [ ] อธิบายหัว packet 6 ไบต์, ทำไมต้องหั่นชิ้น, รหัสผลลัพธ์ที่บอร์ดแจ้งกลับ
- [ ] เล่าลำดับ provisioning 9 ขั้นได้ พร้อมเหตุผลของ token, hash, `reserved`→`active`, หมดอายุ 15 นาที
- [ ] เล่าเส้นทาง "เปิดแอร์ 25°C" ตั้งแต่แอปถึง IR และ echo `state` พร้อมอธิบายว่าทำไม HTTP ตอบ 202
- [ ] อธิบายเส้นทาง LD2410 → `status` → Backend → `auto-off` → `command` ปิดแอร์
- [ ] แยกให้ได้ระหว่างโหมดกู้ Wi-Fi (เปลี่ยนได้เฉพาะ Wi-Fi) กับ `enter_setup` (เปลี่ยนได้ทุกช่อง 5 นาที) กับ BOOT+RESET กับ `reset.ino`
- [ ] อธิบาย offline history + ack และ OTA (3 ชั้นป้องกัน)
- [ ] เปรียบเทียบ Broker แบบพัฒนา (บัญชีเดียว 1883) กับแบบใช้งานจริง (Dynamic Security รายอุปกรณ์ + TLS ผ่าน Funnel 8443 หรือ 8883 ตรง)
- [ ] อธิบายเหตุผลที่ `mqttCallback` และ `ConfigCallbacks::onWrite` ไม่ประมวลผลหนัก ๆ เองทันที
- [ ] เล่าลำดับ unprovision ได้ครบ (ลบแถว → ส่ง `unprovision` → รอคำตอบ ≤ 4 วินาที → ล้าง retained → ลบบัญชี MQTT) และบอกได้ว่าทำไมต้องส่งก่อนลบบัญชี (เพิ่ม 13 ต.ค. 2569)
- [ ] บอกได้ว่าบอร์ดทำอะไรบ้างเมื่อได้ `unprovision` (ตรวจ `deviceId`, ตอบไม่ retained, ล้าง retained ตัวเอง, disconnect ปกติเพื่อไม่เกิด Last Will, ล้าง NVS, รีบูต) และผลเมื่อบอร์ดออฟไลน์ (`boardCleared: false`)
- [ ] บอกฟิลด์ที่แยกบอร์ดสายแอร์ (`controlType` ใน Identity, `controlMode` ใน status, `controlType` ใน REST) และกติกาคำสั่งของ `DAIKIN_WIRED` ได้
- [ ] อธิบายว่าทำไม OTA ต้องตรวจชนิดไฟล์ตรงชนิดบอร์ดที่ Backend
