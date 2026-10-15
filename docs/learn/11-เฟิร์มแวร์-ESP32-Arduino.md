# 11 · เฟิร์มแวร์ ESP32 ด้วย Arduino

> เฟิร์มแวร์ (firmware) = โปรแกรมที่ฝังอยู่ในบอร์ดอิเล็กทรอนิกส์
> บทนี้สอนตั้งแต่ไฟฟ้าเบื้องต้น การต่อสาย การอัปโหลดโปรแกรม จนถึงอ่านโค้ดทั้งสองบอร์ด
> เชิงลึก: `docs/study/04-esp32-firmware.md`, `firmware/README.md`

> ⚠️ **ความปลอดภัยไฟฟ้า** — PZEM-004T ต่อกับ **ไฟบ้าน 220V** ซึ่งอันตรายถึงชีวิต
> ต้องให้ **ช่างไฟฟ้าที่มีใบอนุญาต** ติดตั้งในกล่องปิดมิดชิด และห้ามแตะขั้วขณะมีไฟ
> ส่วนที่นักศึกษาต่อเองได้คือฝั่ง **ไฟต่ำ** (USB 5V, 3.3V) เท่านั้น

---

## ส่วนที่ 1 · ESP32 คืออะไร

**ESP32** = ไมโครคอนโทรลเลอร์ (คอมพิวเตอร์จิ๋วบนชิปเดียว) ของบริษัท Espressif
- CPU 2 คอร์ 240 MHz, RAM ~520 KB, Flash 4 MB (บอร์ดทั่วไป)
- **Wi-Fi 2.4 GHz** และ **Bluetooth (BLE)** ในตัว
- ขา **GPIO** ~30 ขา ใช้อ่าน/ส่งสัญญาณได้
- ราคาไม่กี่ร้อยบาท
- ทำงานที่แรงดัน **3.3V** (ขา GPIO รับเกิน 3.3V ไม่ได้)

บอร์ดที่ใช้ทั่วไปเรียกว่า **ESP32 DevKit** / **ESP32 Dev Module** มีช่อง USB, ปุ่ม **BOOT** และปุ่ม **EN/RST**

> ⚠️ ESP32 ใช้ได้เฉพาะ **Wi-Fi 2.4 GHz** ถ้าเราเตอร์เป็น 5 GHz อย่างเดียว บอร์ดจะมองไม่เห็น

---

## ส่วนที่ 2 · ไฟฟ้าและอิเล็กทรอนิกส์เบื้องต้นที่ต้องรู้

| คำ | ความหมาย |
|---|---|
| **แรงดัน (V, Volt)** | "แรงดัน" ของไฟ — USB = 5V, ESP32 logic = 3.3V, ไฟบ้าน = 220V |
| **กระแส (A, Ampere)** | ปริมาณไฟที่ไหล |
| **กำลัง (W, Watt)** | V × A (โดยประมาณ) — แอร์ ~500–1500W |
| **พลังงาน (kWh)** | กำลัง × เวลา — แอร์ 1000W เปิด 1 ชม. = 1 kWh = 1 หน่วยในบิล |
| **GND (Ground)** | จุดอ้างอิง 0V **อุปกรณ์ที่คุยกันต้องต่อ GND ร่วมกันเสมอ** |
| **GPIO** | General Purpose Input/Output — ขาที่โปรแกรมควบคุมได้ |
| **HIGH / LOW** | สถานะของขา: HIGH = 3.3V, LOW = 0V |
| **Active-high** | อุปกรณ์ทำงานเมื่อขาเป็น HIGH (LED ในโปรเจกต์เป็นแบบนี้) |
| **Pull-up** | ตัวต้านทานดึงขาไว้ที่ HIGH เมื่อไม่มีอะไรต่อ (ปุ่ม BOOT ใช้ `INPUT_PULLUP` กดแล้วเป็น LOW) |
| **UART / Serial** | การส่งข้อมูลทีละบิตผ่าน 2 สาย: **TX** (ส่ง) และ **RX** (รับ) |
| **Baud rate** | ความเร็ว UART (บิต/วินาที) สองฝั่งต้องตั้งเท่ากัน: PZEM ใช้ 9600, LD2410 ใช้ 256000, Serial Monitor ใช้ 115200 |
| **Power factor (PF)** | ประสิทธิภาพการใช้ไฟ AC (0–1) ใกล้ 1 ดี |

### กฎการต่อ UART: **ไขว้สาย**

```text
  อุปกรณ์           ESP32
   TX  ───────────▶  RX        ← ส่งของอุปกรณ์ ต้องไปเข้ารับของ ESP32
   RX  ◀───────────  TX
   GND ────────────  GND       ← ต้องมี!
```

ถ้าต่อ TX→TX ตรง ๆ จะไม่ได้ข้อมูลเลย (ข้อผิดพลาดยอดฮิต)

### ตัวต้านทานสำหรับ LED
LED ต้องต่อผ่านตัวต้านทาน **220–330 Ω** เสมอ ไม่งั้นกระแสเกินจนพังทั้ง LED และขา ESP32

### IR LED ต้องมีทรานซิสเตอร์ขับ
IR LED กำลังสูงกินกระแสเกินกว่าขา GPIO จ่ายได้ ต้องใช้ทรานซิสเตอร์เป็น "สวิตช์" (GPIO17 → ขา base ผ่านตัวต้านทาน)

---

## ส่วนที่ 3 · บอร์ดในโปรเจกต์ (3 เฟิร์มแวร์) และการต่อสาย

### 3.1 บอร์ดแอร์ (`rmutt_esp32_air`, เฟิร์มแวร์ 2.5.1)

| ขา ESP32 | ต่อกับ | หน้าที่ |
|---|---|---|
| `GPIO17` | ทรานซิสเตอร์ขับ IR LED | ส่งสัญญาณรีโมต |
| `GPIO16` (RX) | PZEM **TX** | รับค่าไฟ |
| `GPIO18` (TX) | PZEM **RX** | ส่งคำขอไป PZEM |
| `GPIO25` | LED เขียว + 220–330Ω | แอร์กำลังทำงาน (PZEM วัดได้) |
| `GPIO26` | LED แดง + 220–330Ω | แอร์ทำงาน **นอกเวลาที่อนุญาต** (เปิดคู่กับเขียว) |
| `GPIO27` | LED เหลือง + 220–330Ω | กระพริบ = กำลังต่อ Wi-Fi, ติดค้าง = ต่อแล้ว |
| `GPIO0` | ปุ่ม BOOT (มีบนบอร์ด) | กดค้างตอนรีเซ็ต = เข้าโหมดตั้งค่า |
| `GPIO21` / `GPIO22` | จอ OLED 1.3" SH1106 (SDA / SCL) | แสดงสถานะ (เพิ่มตั้งแต่ 2.5.0) |

### 3.2 บอร์ดตรวจคน (`rmutt_esp32_occupancy`, เฟิร์มแวร์ 1.3.2)

| ขา LD2410C | ต่อกับ ESP32 |
|---|---|
| `VCC` | `5V` / `VIN` (ตรวจแรงดันที่รุ่นของโมดูลต้องการก่อน) |
| `GND` | `GND` |
| `TX` | `GPIO32` (RX ของ ESP32) |
| `RX` | `GPIO33` (TX ของ ESP32) |
| `OUT` | **ไม่ต่อ** (ปล่อยลอยปลอดภัย ห้ามต่อกับ 5V/GND) |

> ⚠️ ห้ามคาสายไว้ที่ `GPIO12` ตอนกดรีเซ็ต — ถ้าเป็น HIGH ตอนบูต ESP32 จะบูตไม่ขึ้น

### 3.3 บอร์ดแอร์แบบต่อสาย Daikin (`rmutt_esp32_air_wired`, เฟิร์มแวร์ 2.5.2-slm8)

ใช้กับแอร์ Daikin ที่ถอดรีโมตติดผนัง (panel SLM8) ออก แล้วให้ ESP32 คุยกับแอร์ทางสายควบคุมแทนการยิง IR
ขา PZEM, LED และปุ่ม BOOT เหมือนบอร์ด IR ทุกอย่าง ที่ต่างคือ:

| ขา ESP32 | ต่อกับ | หมายเหตุ |
|---|---|---|
| `GPIO33` | ขาที่มีแถบของไดโอด 1N4148 → สายสั่งงาน (panel → แอร์) | ส่งคำสั่ง (ถ้าใช้ทรานซิสเตอร์ 2N2222 แทน ต้องตั้ง `BUS_TX_INVERT = true`) |
| `GPIO35` | สายสถานะ (แอร์ → panel) ผ่านตัวแบ่ง 100k / 200k | อ่านสถานะแอร์ |
| `GPIO34` | สายสั่งงาน ผ่านตัวแบ่ง 100k / 200k | ตรวจสัญญาณตัวเอง (ไม่บังคับ) |
| `GPIO4` | DHT11 ขา DATA | วัดอุณหภูมิห้อง |
| `GPIO21` / `GPIO22` | OLED SDA / SCL | เหมือนบอร์ด IR |

> สายแดง +5V ของแอร์ **ไม่ต่อ** · GND ต้องต่อร่วมกัน · รายละเอียดโปรโตคอลอยู่ใน `firmware/rmutt_esp32_air_wired/README_WIRED_TH.md`

### 3.4 อัปเดตเฟิร์มแวร์ผ่านหน้าเว็บ

ตั้งแต่ 14 ต.ค. 2569 อัปโหลดไฟล์ `.bin` ได้จากหน้า **เฟิร์มแวร์** ในเว็บแอป (`webapp/assets/js/views/firmware.js`)
ซึ่งเรียก `POST /api/firmware` ของ backend มีทั้งลบไฟล์และสั่ง OTA ทีละหลายบอร์ด จึงไม่ต้อง `scp` ขึ้นเซิร์ฟเวอร์เองอีก
(วิธี `scp` ในส่วนที่ 6 ยังใช้ได้)

---

## ส่วนที่ 4 · อัปโหลดโปรแกรมลงบอร์ดด้วย Arduino IDE (ทำตามทีละข้อ)

> ต้องติดตั้ง Arduino IDE + ESP32 board + ไลบรารีตามบท 04 หัวข้อ 10 ก่อน

1. **เปิดไฟล์** — File → Open → `firmware\rmutt_esp32_air\rmutt_esp32_air.ino`
   (ไฟล์ `.h` และ `.cpp` ในโฟลเดอร์เดียวกันจะเปิดเป็นแท็บให้เอง **ห้ามแยกไฟล์ออกจากโฟลเดอร์**
   เพราะ Arduino ต้องการให้ชื่อโฟลเดอร์ตรงกับชื่อไฟล์ `.ino`)
2. **เลือกบอร์ด** — Tools → Board → esp32 → **ESP32 Dev Module**
3. **เลือก Partition Scheme** — Tools → Partition Scheme → **"No FS 4MB (2MB APP x2)"**
   (มีไฟล์ `partitions.csv` ในโฟลเดอร์สเก็ตช์ Arduino จะใช้ตารางในไฟล์นั้น ตัวเลือกนี้ใช้ตรวจขนาดโปรแกรม)
4. **เสียบ USB** แล้วเลือก Port — Tools → Port → `COM5` (เลขของคุณอาจต่าง)
   ไม่เห็น Port → ไดรเวอร์/สาย USB (บท 04 หัวข้อ 10.3)
5. **Verify** (ปุ่ม ✓) = คอมไพล์อย่างเดียว ดูว่ามี error ไหม (ครั้งแรกนานหลายนาที)
6. **Upload** (ปุ่ม →) = คอมไพล์ + เขียนลงบอร์ด
   - ถ้าค้างที่ `Connecting........_____` ให้ **กดปุ่ม BOOT ค้าง** จนเห็นตัวเลขเปอร์เซ็นต์ขึ้น แล้วปล่อย
7. **เปิด Serial Monitor** — Tools → Serial Monitor (หรือ `Ctrl+Shift+M`)
   ตั้งความเร็วมุมขวาล่างเป็น **115200 baud** แล้วกดปุ่ม **EN/RST** บนบอร์ด

ผลที่ควรเห็นเมื่อบอร์ดใหม่ (ยังไม่เคยตั้งค่า)

```text
RMUTT ESP32 Air Controller
Firmware: 2.5.1
Device ID: ESP32-AABBCCDDEEFF
IR output: GPIO17
PZEM UART: RX GPIO16, TX GPIO18
Status LEDs: green GPIO25, red GPIO26, yellow GPIO27
Mode: BLE recovery - No saved configuration
...
```

จด **Device ID** ไว้ — ชื่อ Bluetooth จะเป็น `RMUTT-AC-AABBCCDDEEFF`

> 💡 ถ้าตัวหนังสือเป็นขยะ `⸮⸮⸮` = ความเร็ว Serial Monitor ไม่ตรง 115200

### ข้อความ error ที่พบบ่อยตอนคอมไพล์

| ข้อความ | แก้ |
|---|---|
| `ArduinoJson.h: No such file or directory` | ยังไม่ได้ติดตั้งไลบรารี ArduinoJson |
| `'DynamicJsonDocument' is deprecated` / error เกี่ยวกับ JsonDocument | ติด ArduinoJson 7 → ลดเป็น 6.x |
| `ld2410.h: No such file` | ติดตั้งไลบรารี ld2410 (บอร์ดตรวจคน) |
| `Sketch too big` | ยังไม่ได้เลือก Partition Scheme ตามข้อ 3 |
| `A fatal error occurred: Failed to connect to ESP32` | กด BOOT ค้างตอนอัปโหลด / เปลี่ยนสาย / ปิดโปรแกรมอื่นที่ใช้ COM port (เช่น Serial Monitor อีกหน้าต่าง) |

---

## ส่วนที่ 5 · โครงสร้างโปรแกรม Arduino

### 5.1 `setup()` และ `loop()`

ทุกโปรแกรม Arduino มี 2 ฟังก์ชันหลัก

```cpp
void setup() {
  // ทำครั้งเดียวตอนเปิดเครื่อง/รีเซ็ต
}

void loop() {
  // ทำวนซ้ำไปเรื่อย ๆ ไม่มีวันจบ (หลายพันรอบต่อวินาที)
}
```

### 5.2 C++ ที่เจอในโค้ด

```cpp
constexpr uint8_t IR_LED_PIN = 17;        // ค่าคงที่ (uint8_t = จำนวนเต็ม 0–255)
constexpr uint32_t STATUS_INTERVAL_MS = 10000;   // uint32_t = 0–4 พันล้าน
String deviceId;                          // ข้อความแบบ Arduino
bool configured = false;
float watts = 465.2F;

struct DeviceConfig {                     // struct = กลุ่มตัวแปร
  bool configured = false;
  String roomNumber;
  String wifiSsid;
  ...
};
DeviceConfig config;
config.roomNumber = "16302";

void connectMqtt();                       // ประกาศล่วงหน้า (ตัวจริงอยู่ข้างล่าง)
Serial.printf("Device ID: %s\n", config.deviceId.c_str());   // พิมพ์ลง Serial Monitor
#include <WiFi.h>                         // โหลดไลบรารี
#include "SaijoDenkiAC.h"                 // โหลดไฟล์ในโฟลเดอร์เดียวกัน
```

### 5.3 หัวใจสำคัญ: **ห้ามใช้ `delay()` ยาว ๆ ใน `loop()`** — ใช้ `millis()` แทน

`delay(10000)` = หยุดทุกอย่าง 10 วินาที ระหว่างนั้นรับคำสั่ง MQTT ไม่ได้ อ่านเรดาร์ไม่ได้
วิธีที่ถูก: จดเวลาครั้งล่าสุด แล้วเช็กว่าผ่านไปนานพอหรือยัง

```cpp
if (millis() - lastPzemReadAt >= PZEM_READ_INTERVAL_MS) {   // ผ่านไป 2 วินาทีหรือยัง
  lastPzemReadAt = millis();
  readPowerMeter();
}
if (millis() - lastStatusAt >= STATUS_INTERVAL_MS) {        // ผ่านไป 10 วินาทีหรือยัง
  lastStatusAt = millis();
  publishStatus();
}
```

`millis()` = จำนวนมิลลิวินาทีตั้งแต่เปิดเครื่อง ทำแบบนี้ทุกงานทำ "พร้อมกัน" ได้ (non-blocking)

### 5.4 ลำดับการทำงานของบอร์ดแอร์ (สรุปจาก `setup()` / `loop()`)

```text
setup():
  ตั้งขา LED และปุ่ม
  สร้าง Device ID จาก MAC (ESP.getEfuseMac) → "ESP32-XXXXXXXXXXXX"
  โหลดค่าจาก NVS (loadConfig) และสถานะแอร์ล่าสุด (loadAirState)
  ถ้า ยังไม่เคยตั้งค่า  หรือ  กดปุ่ม BOOT ค้างอยู่
        → เปิด BLE รอแอปมาตั้งค่า (enterBleRecovery) แล้วจบ setup
  ต่อ Wi-Fi ไม่ได้ → เปิด BLE + ลอง Wi-Fi เดิมซ้ำทุก 30 วินาทีเบื้องหลัง
  ต่อได้ → เดินต่อ

loop():  (วนตลอด)
  ทุก 2 วินาที อ่าน PZEM
  สรุปข้อมูลไฟทุก 5 นาทีเก็บลง flash (สำหรับช่วงเน็ตหลุด)
  อัปเดต LED
  ถ้ามี config ใหม่จาก BLE → ประมวลผล
  ถ้า Wi-Fi หลุด → ต่อใหม่ / เข้า BLE recovery
  ถ้า MQTT หลุด → ต่อใหม่ทุก 3 วินาที
  mqttClient.loop() → รับข้อความ
  มีคำสั่ง MQTT รออยู่ → ยิง IR
  ส่งข้อมูลย้อนหลังที่ค้าง (ถ้ามี)
  ทุก 10 วินาที publish status
  มีคำขอ OTA → อัปเดตเฟิร์มแวร์
```

---

## ส่วนที่ 6 · แต่ละโมดูลทำงานอย่างไร

### 6.1 NVS / Preferences — ความจำถาวรของบอร์ด

**NVS** (Non-Volatile Storage) = พื้นที่ในหน่วยความจำ flash ที่ **ไฟดับข้อมูลไม่หาย**
ไลบรารี `Preferences` ใช้เก็บแบบ key-value

```cpp
preferences.begin("rmutt-air", false);               // เปิด namespace (false = เขียนได้)
preferences.putString("wifi_ssid", newConfig.wifiSsid);
preferences.putString("mqtt_host", newConfig.mqttHost);
preferences.putUShort("mqtt_port", newConfig.mqttPort);
preferences.putBool("configured", true);
preferences.end();

// อ่าน
config.configured = preferences.getBool("configured", false);   // ไม่มี → false
```

เก็บ: ห้อง, หมายเลขแอร์, ชื่อ, ยี่ห้อ IR, Wi-Fi, MQTT host/port/user/pass/TLS/topic, token, เวลาเปิด-ปิดประจำวัน
→ นี่คือเหตุผลที่ **เปลี่ยน LAN IP แล้วต้องตั้งค่าบอร์ดใหม่** เพราะ MQTT host ถูกจำไว้ใน NVS

**ล้างค่าทั้งหมด (factory reset)**: อัปโหลด `firmware\reset\reset.ino`
(เรียก `nvs_flash_erase()`) แล้วอัปโหลดเฟิร์มแวร์หลักกลับ

### 6.2 BLE — ช่องทางตั้งค่าครั้งแรก

**BLE** (Bluetooth Low Energy) ใช้แนวคิด **GATT**
- **Service** = กลุ่มของข้อมูล (UUID `7b570001-...`)
- **Characteristic** = ช่องข้อมูลแต่ละช่อง อ่าน/เขียน/แจ้งเตือนได้

| Characteristic | UUID ท้าย | ทำอะไร |
|---|---|---|
| Config | `...0002` | แอป **เขียน** ค่าตั้ง (Wi-Fi, MQTT, ห้อง...) |
| Status/ACK | `...0003` | บอร์ด **แจ้ง** ผลกลับ (notify) |
| Identity | `...0004` | แอป **อ่าน** Device ID, รุ่นเฟิร์มแวร์ |
| Nearby Wi-Fi | `...0005` | แอปอ่าน → บอร์ด **สแกน Wi-Fi รอบตัว** ส่งรายชื่อกลับ (ไม่มีรหัส) |
| Saved settings | `...0006` | อ่านค่าที่ตั้งไว้แล้ว (ไม่ส่งรหัสผ่านกลับ) |

BLE ส่งได้ทีละไม่กี่ร้อยไบต์ JSON ค่าตั้งจึงถูก **หั่นเป็นชิ้น** แต่ละชิ้นมีหัว 6 ไบต์
`[เวอร์ชัน=1][ชนิด=1][ลำดับที่ 2 ไบต์][จำนวนทั้งหมด 2 ไบต์][ข้อมูล JSON...]`
บอร์ดต่อชิ้นกลับจนครบ (โค้ดใน `ConfigCallbacks::onWrite`)

บอร์ดเปิด BLE เมื่อ
- ยังไม่เคยตั้งค่า
- กด **BOOT ค้างขณะกด EN/RST** (โหมดตั้งค่าใหม่)
- ต่อ Wi-Fi ที่บันทึกไว้ไม่ได้ (BLE recovery)
- แอดมินกด "ตั้งค่าบอร์ด" ในแอป → Backend ส่ง MQTT สั่งเปิด BLE 5 นาที โดยไม่ต้องไปกดปุ่ม

### 6.3 Wi-Fi

```cpp
WiFi.mode(WIFI_STA);                  // โหมด station (ลูกข่าย)
WiFi.begin(ssid, password);
while (WiFi.status() != WL_CONNECTED && ยังไม่หมดเวลา 20 วินาที) { ... }
```

ตอนตั้งค่าผ่าน BLE บอร์ด **ทดสอบต่อ Wi-Fi ก่อน** บันทึกลง NVS
ถ้ารหัสผิด ค่าเดิมยังอยู่ แก้แล้วกดบันทึกซ้ำได้

### 6.4 MQTT (ไลบรารี PubSubClient)
ดูบท 06 หัวข้อ 11 — ต่อ, ฝาก Last Will, subscribe 4 topic, publish status ทุก 10 วินาที

### 6.5 เวลา (NTP) และ TLS
- บอร์ดไม่มีนาฬิกาที่จำเวลาได้ ต้องถาม **NTP server** ทางอินเทอร์เน็ตทุกครั้งที่บูต
- **จำเป็นสำหรับ TLS** เพราะต้องเช็กว่าใบรับรองของเซิร์ฟเวอร์ยังไม่หมดอายุ
  ถ้าได้ `NTP sync failed; TLS certificate check will fail` = บอร์ดออกเน็ตไม่ได้
- ใบรับรองรากของ Let's Encrypt ฝังอยู่ใน `letsencrypt_ca.h`
  (`secureClient.setCACert(LETSENCRYPT_CA)`) อัปเดตด้วย `firmware\update-root-ca.ps1`

### 6.6 IR — ยิงรีโมตแอร์ (IRremoteESP8266)

ไลบรารีรู้จักรหัสรีโมตหลายสิบยี่ห้อ ใช้คลาส `IRac` แบบกลาง

```cpp
IRac irAc(IR_LED_PIN);                                  // ขา 17

irAc.next.protocol = strToDecodeType("DAIKIN");         // ยี่ห้อ (ได้มาตอนตั้งค่า)
irAc.next.power    = true;
irAc.next.degrees  = 24;
irAc.next.mode     = stdAc::opmode_t::kCool;
irAc.next.fanspeed = stdAc::fanspeed_t::kAuto;
irAc.next.swingv   = stdAc::swingv_t::kAuto;
irAc.sendAc();                                          // ยิง!
```

ยี่ห้อที่รองรับ เช่น `DAIKIN`, `MITSUBISHI_AC`, `PANASONIC_AC`, `GREE`, `MIDEA`, `LG`,
`SAMSUNG_AC`, `TOSHIBA_AC`, `HITACHI_AC`, `FUJITSU_AC`, `HAIER_AC160` (ค่าเริ่มต้น) ฯลฯ
และ **`SAIJO_DENKI`** ที่โปรเจกต์เขียนเอง (`SaijoDenkiAC.cpp/.h`) จากการจับสัญญาณรีโมตจริง

> ⚠️ ต้องเลือกยี่ห้อให้ตรงรีโมตจริง ฟังก์ชันที่แอร์รุ่นนั้นไม่มี (Eco, Clean, Swing) จะถูกข้ามเงียบ ๆ
> IR ต้อง **มองเห็นตัวรับของแอร์** ไม่มีสิ่งกีดขวาง

### 6.7 PZEM-004T — วัดไฟ

```cpp
PZEM004Tv30 pzem(Serial2, PZEM_RX_PIN, PZEM_TX_PIN);   // ใช้ UART2 บนขา 16/18

const float voltage = pzem.voltage();     // V
const float current = pzem.current();     // A
const float power   = pzem.power();       // W
// + pzem.energy() (kWh สะสม), pzem.frequency() (Hz), pzem.pf()
if (isnan(voltage)) { /* อ่านไม่ได้ */ }
```

- อ่านทุก 2 วินาที, ล้มเหลว 3 ครั้งติด → `pzemAvailable = false`
- **ตัดสินว่าแอร์ทำงาน** แบบมี hysteresis (กันค่ากระเพื่อม):
  - ≥ 30W ติดกัน 3 ครั้ง → กำลังทำงาน (`acRunning = true`, LED เขียวติด)
  - ≤ 10W ติดกัน 3 ครั้ง → หยุด
  - ระหว่าง 10–30W → คงสถานะเดิม
- `energy_kwh` เป็นเลข **สะสม** เหมือนมิเตอร์บ้าน Backend เอาผลต่างมาคิดรายชั่วโมง

### 6.8 LD2410 — เรดาร์ตรวจคน (บอร์ดตรวจคน)

**HLK-LD2410** เป็นเรดาร์คลื่นมิลลิเมตร 24 GHz จับได้ทั้งคนที่ **ขยับ** และคนที่ **นั่งนิ่ง** (จากการหายใจ)
แบ่งระยะเป็น **gate** 0–8 (gate ละ ~0.75 m) แต่ละ gate ให้ค่า "พลังงาน" 0–100

กติกาของโปรเจกต์ (อ่านทุก 250 ms)

```text
ถ้าค่า static (นิ่ง) ของ gate ใด gate หนึ่งใน 0–8  >  25   →  occupied = true
ทุก gate ≤ 25                                            →  occupied = false
(= 25 พอดี ถือว่าว่าง)
```

- ใช้ **Engineering mode** ของโมดูลเพื่อให้ได้ค่ารายเกต
- ไม่ใช้ขา `OUT` ของโมดูล เพราะใช้เกณฑ์โรงงานซึ่งปรับไม่ได้
- ส่งแค่ผลสุดท้าย `occupied` + `radarAvailable` ไม่ส่งค่าดิบ
- บอร์ดพิมพ์ `[diag]` และ `[gates]` ทุก 10 วินาทีใน Serial Monitor ช่วยปรับเกณฑ์ในห้องจริง

ถ้า `[diag] UART1 rx bytes in the last 10s: 0` = เรดาร์ไม่ส่งอะไรเลย → สาย/ไฟ
ใช้ `firmware\ld2410_pinscan\ld2410_pinscan.ino` ช่วยหาว่าสายไปถึงขาไหนจริง

### 6.9 เก็บข้อมูลตอนเน็ตหลุด (`history_log.h`)
- ถ้าต่อ MQTT ไม่ได้ บอร์ดแอร์สรุปค่าไฟทุก 5 นาที เก็บลงพาร์ติชัน flash `rmuttlog` (64 KB)
- เก็บได้ 2,048 รายการ ≈ 7 วัน เต็มแล้วทับของเก่าสุด
- ต่อได้อีกครั้ง → รอสุ่ม 5–45 วินาที (กันทั้งตึกส่งพร้อมกัน) → ส่งทีละ 10 รายการทาง `.../history`
  → รอ `history-ack` → ลบชุดนั้น → ส่งชุดถัดไป
- ทดสอบโค้ดส่วนนี้บนคอมได้โดยไม่ต้องมีบอร์ด (ต้องมี g++ เช่นใน Git Bash + MinGW หรือ WSL)
  ```bash
  cd firmware/tests
  g++ -std=c++17 -I../rmutt_esp32_air history_log_test.cpp -o t && ./t
  ```

### 6.10 ตารางพาร์ติชัน (`partitions.csv`)

```text
# Name,   Type, SubType, Offset,  Size
nvs,      data, nvs,     0x9000,  0x5000     ← ค่าตั้ง (Wi-Fi, MQTT...)
otadata,  data, ota,     0xe000,  0x2000     ← บอกว่าบูตจากช่องไหน
app0,     app,  ota_0,   0x10000, 0x1F0000   ← โปรแกรมช่องที่ 1 (~1.9 MB)
app1,     app,  ota_1,   0x200000,0x1F0000   ← โปรแกรมช่องที่ 2 (สำหรับ OTA)
rmuttlog, data, 0x40,    0x3F0000,0x10000    ← ข้อมูลไฟตอนเน็ตหลุด (64 KB)
```

Flash 4 MB ถูกแบ่งเป็นห้อง ๆ แบบนี้ **ต้องแฟลชผ่าน USB อย่างน้อยครั้งแรก**
(OTA เปลี่ยนตารางพาร์ติชันไม่ได้)

### 6.11 OTA — อัปเดตเฟิร์มแวร์ผ่าน Wi-Fi (`ota_update.h`)
มีโปรแกรมสองช่อง (app0/app1) บอร์ดดาวน์โหลดเฟิร์มแวร์ใหม่ลงช่องที่ **ไม่ได้ใช้อยู่**
ตรวจความถูกต้อง แล้วสลับไปบูตช่องใหม่ ถ้าล้มเหลวก็ยังใช้ช่องเดิมได้ ไม่เสียบอร์ด

ขั้นตอน (จาก `deploy/DEPLOY.md`)
1. Arduino IDE → **Sketch → Export Compiled Binary** → ได้ไฟล์ `*.ino.bin` ในโฟลเดอร์สเก็ตช์
2. เปลี่ยนชื่อให้มีชนิดและรุ่น เช่น `rmutt_esp32_air-2.5.1.bin` (บอร์ดตรวจคนต้องมีคำว่า `occ`)
3. อัปโหลดขึ้นเซิร์ฟเวอร์ `scp rmutt_esp32_air-2.5.1.bin <user>@<host>:/opt/rmutt/firmware/`
4. เว็บแอป → ห้องและอุปกรณ์ → กด **อัปเดตเฟิร์มแวร์**
5. Backend ส่ง MQTT บอกที่อยู่ไฟล์ → บอร์ดดาวน์โหลดทาง HTTPS (ยอมรับเฉพาะ URL `https://<โดเมนเดียวกับ MQTT>/firmware/...` กันถูกหลอกให้โหลดไฟล์จากที่อื่น) → รีบูต

อย่าลืมเปลี่ยน `FIRMWARE_VERSION` ในโค้ดก่อน build ทุกครั้ง

---

## ส่วนที่ 7 · อ่าน Serial Monitor ให้เป็น

ข้อความสำคัญของบอร์ดแอร์

| ข้อความ | ความหมาย |
|---|---|
| `Mode: BLE recovery - No saved configuration` | บอร์ดใหม่ รอตั้งค่า |
| `Mode: BLE recovery - BOOT button requested setup` | เข้าโหมดตั้งค่าเพราะกด BOOT |
| `Mode: BLE recovery - Stored Wi-Fi could not connect` | ต่อ Wi-Fi ที่บันทึกไว้ไม่ได้ (จะลองซ้ำทุก 30 วินาที) |
| `BLE app connected` | แอปต่อ Bluetooth แล้ว |
| `Wi-Fi connected, IP: 192.168.1.72` | ต่อ Wi-Fi ได้ IP นี้ |
| `Connecting MQTT: 192.168.1.10:1883` | กำลังต่อ Broker ที่อยู่นี้ (ค่าจาก NVS) |
| `MQTT connection failed, state: -2` | ต่อ Broker ไม่ได้ (ดูตาราง state ในบท 06) |
| `IR sent: protocol=DAIKIN power=ON temp=24 mode=cool fan=auto` | ยิงรีโมตแล้ว |
| `BLE setup window closed; Wi-Fi and MQTT stayed connected` | หน้าต่างตั้งค่า 5 นาทีหมด |
| `Wi-Fi is back: leaving BLE recovery and resuming` | Wi-Fi กลับมาเอง |

---

## ส่วนที่ 8 · เครื่องมือเสริมในโฟลเดอร์ `firmware/`

| ไฟล์ | ใช้เมื่อ |
|---|---|
| `reset/reset.ino` | ล้าง NVS ทั้งหมด (บอร์ดกลับเป็นเหมือนใหม่) |
| `ld2410_pinscan/ld2410_pinscan.ino` | หาว่าสาย TX ของเรดาร์ไปถึงขาไหน + baud อะไร |
| `tests/history_log_test.cpp` | ทดสอบโค้ดเก็บประวัติบนคอม |
| `update-root-ca.ps1` | ดาวน์โหลดใบรับรองราก Let's Encrypt มาสร้าง `letsencrypt_ca.h` ใหม่ |

```powershell
.\firmware\update-root-ca.ps1
.\firmware\update-root-ca.ps1 -Urls https://ผู้ออกใบรับรองอื่น/root.pem
```

การอัปโหลดสเก็ตช์เครื่องมือ **ไม่ลบ NVS** (ยกเว้น `reset.ino`) แฟลชเฟิร์มแวร์หลักกลับแล้วใช้ต่อได้ทันที

---

## สรุปบท

- ESP32 = คอมจิ๋ว 3.3V มี Wi-Fi 2.4GHz + BLE
- UART ต้องไขว้ TX↔RX และต่อ GND ร่วม
- Arduino IDE: เลือก ESP32 Dev Module, Partition "No FS 4MB (2MB APP x2)", Port, แล้ว Upload
- Serial Monitor 115200 คือหน้าต่างเดียวที่บอกว่าบอร์ดคิดอะไรอยู่
- `setup()` ครั้งเดียว, `loop()` วนตลอด, ใช้ `millis()` ไม่ใช้ `delay()` ยาว
- ค่าตั้งอยู่ใน NVS → เปลี่ยน IP ของ Broker ต้องตั้งค่าบอร์ดใหม่
- BOOT ค้าง + กด EN = เข้าโหมดตั้งค่าผ่าน Bluetooth

## 🧪 แบบฝึกหัด

1. อัปโหลด `reset.ino` แล้วเปิด Serial Monitor อ่านผล
2. อัปโหลด `rmutt_esp32_air.ino` จด Device ID และชื่อ BLE
3. หาในโค้ดว่า LED เหลืองกระพริบเร็วเท่าไร (ใบ้: `YELLOW_LED_BLINK_INTERVAL_MS`)
4. ถ้าอยากให้เซ็นเซอร์ไวขึ้น (ตรวจคนนั่งนิ่งได้ง่ายขึ้น) ต้องแก้ค่าอะไร เพิ่มหรือลด?
   (ตอบ: ลด `STATIC_ENERGY_THRESHOLD` — แต่ต้องทดสอบว่าห้องว่างไม่กลายเป็น "มีคน")
5. อธิบายว่าทำไมการเก็บข้อมูลตอนเน็ตหลุดต้องรอเวลาสุ่มก่อนส่ง

ถัดไป: **บท 12 การทำงานร่วมกันทั้งระบบ**
