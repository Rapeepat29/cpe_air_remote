# เฟิร์มแวร์ ESP32: บอร์ดแอร์ (IR และสายแอร์) และบอร์ดตรวจจับคน

## ภาพรวม

เฟิร์มแวร์ (firmware) คือโปรแกรมที่ฝังอยู่ในชิปไมโครคอนโทรลเลอร์ ทำงานทันทีที่จ่ายไฟและไม่มีระบบปฏิบัติการแบบคอมพิวเตอร์ครอบอยู่ โปรเจคนี้มีเฟิร์มแวร์หลัก **สามตัวแยกกัน** อยู่ในโฟลเดอร์ `firmware/` ทั้งหมดใช้ ESP32 และเขียนด้วย Arduino framework (ภาษา C++):

| บอร์ด | สเก็ตช์ | เวอร์ชันในโค้ด (`FIRMWARE_VERSION`) | หน้าที่ |
|---|---|---|---|
| บอร์ดแอร์ IR | `rmutt_esp32_air/rmutt_esp32_air.ino` | **2.5.1** | หนึ่งบอร์ดต่อแอร์หนึ่งเครื่อง: ยิง IR สั่งแอร์เหมือนรีโมตมือถือ, วัดไฟด้วย PZEM-004T, รายงานสถานะ, เก็บข้อมูลไฟฟ้าตอนเน็ตหลุด, แสดงผลบนจอ OLED |
| บอร์ดแอร์สายแอร์ | `rmutt_esp32_air_wired/rmutt_esp32_air_wired.ino` | **2.5.2-slm8** | ใช้ **แทนรีโมตติดผนัง Daikin** ที่ถอดออก: สั่งแอร์ผ่านสายของรีโมตติดผนัง (โปรโตคอล SLM8) แทน IR, ได้สถานะจริงจากแอร์ (สายตอบไหม คอมเพรสเซอร์ทำงานไหม), วัดอุณหภูมิห้องด้วย DHT11 ส่วน BLE/MQTT/PZEM/OTA/ข้อมูลย้อนหลังเหมือนบอร์ด IR |
| บอร์ดตรวจจับคน | `rmutt_esp32_occupancy/rmutt_esp32_occupancy.ino` | **1.3.3** | หนึ่งบอร์ดต่อห้องหนึ่งห้อง: อ่านเรดาร์ HLK-LD2410 แล้วตัดสินว่า "มีคน/ไม่มีคน" มีไฟ LED เขียว/แดงบอกสถานะ |

นอกจากนี้มีสเก็ตช์เครื่องมือเล็ก ๆ อีกสองตัว (`reset/reset.ino` ล้างค่าที่จำไว้ และ `ld2410_pinscan/ld2410_pinscan.ino` หาขาที่เรดาร์ส่งข้อมูลมา) กับโค้ดทดสอบ `tests/history_log_test.cpp` ที่รันบนคอมพิวเตอร์ได้โดยไม่ต้องมีบอร์ด

ในภาพรวมของระบบ บอร์ดเหล่านี้เป็น "มือและตา" ของระบบ: บอร์ดแอร์ (ทั้งรุ่น IR และรุ่นสายแอร์) เป็นมือ (สั่งแอร์) และตาที่เห็นไฟฟ้า (วัดกำลังไฟ) ส่วนบอร์ดตรวจจับคนเป็นตาที่เห็นว่าห้องมีคนหรือไม่ ทุกตัวคุยกับ Backend ผ่าน MQTT broker (Mosquitto) เท่านั้น ไม่ได้คุยกับ Backend ตรง ๆ และไม่มี HTTP server ในบอร์ด ส่วน BLE (Bluetooth Low Energy) ใช้เฉพาะตอน "ตั้งค่าครั้งแรกหรือตั้งค่าใหม่" จากแอป Flutter

```text
 แอป Flutter ──BLE (ตั้งค่า Wi-Fi/MQTT ครั้งแรก)──┐
                                                  ▼
 Backend ◄──MQTT (Mosquitto, ปกติเป็น TLS)──► ESP32 บอร์ดแอร์ IR ──IR──► แอร์ทุกยี่ห้อ
   ▲  ▲                                           │ UART      └─I2C─► จอ OLED
   │  │                                           └──► PZEM-004T (วัดไฟของแอร์)
   │  └────MQTT────────────────────────────► ESP32 บอร์ดสายแอร์ ◄─สายรีโมตผนัง (SLM8)─► แอร์ Daikin
   │                                              ├──► PZEM-004T, DHT11, จอ OLED
   └────────MQTT──────────────────────────► ESP32 บอร์ดตรวจจับคน ◄──UART── LD2410 (เรดาร์)
```

> [!NOTE]
> หัวข้อ MQTT (topic), รูปแบบ JSON และตาราง BLE characteristic แบบเต็มอยู่ใน **บทโปรโตคอลสื่อสาร** บทนี้อธิบายเฉพาะ "ฝั่งเฟิร์มแวร์ทำอะไรกับมัน" และอ้างค่าที่เห็นในโค้ดจริงเท่านั้น

> [!WARN]
> เอกสารอื่นในโปรเจกต์บางจุดยังไม่ตรงกับโค้ด: `firmware/README.md` เขียนบอร์ดตรวจคนเป็น 1.3.2 (โค้ดคือ **1.3.3**) และยังเขียนขา PZEM/LED เหลืองของบอร์ดสายแอร์เป็น 16/18/27 (โค้ดคือ **18/14/23**) เช่นเดียวกับ `README_WIRED_TH.md` ส่วนหัวเรื่องของ `README_OLED_TH.md` เป็น "2.5.0" เพราะเป็นบันทึกของรุ่นที่เพิ่มจอ ถ้าเอกสารใดไม่ตรง ให้เชื่อค่าในไฟล์ `.ino` (`FIRMWARE_VERSION` และค่าคงที่ `*_PIN`)

## ความรู้ที่ต้องมีก่อนอ่านบทนี้

### ไมโครคอนโทรลเลอร์ (MCU) ต่างจากคอมพิวเตอร์อย่างไร

คอมพิวเตอร์มี CPU, RAM ระดับ GB, ดิสก์, ระบบปฏิบัติการที่รันหลายโปรแกรมพร้อมกัน ส่วน **MCU** คือชิปเดียวที่รวม CPU + RAM + หน่วยความจำโปรแกรม (flash) + ขาสัญญาณ (pin) ไว้ด้วยกัน RAM เป็นหลักร้อย KB, flash เป็นหลัก MB, รัน **โปรแกรมเดียว** ตั้งแต่เปิดไฟจนปิดไฟ ข้อดีคือถูก กินไฟน้อย ตอบสนองต่อสัญญาณภายนอกได้เร็วและคาดเดาเวลาได้ ข้อเสียคือทรัพยากรน้อยมาก ต้องระวังเรื่อง RAM (heap) และห้ามโปรแกรม "ค้างรอ" นาน ๆ

### ESP32

ชิป MCU ของ Espressif มี CPU 2 คอร์ (Xtensa 32-bit), Wi-Fi 2.4 GHz และ Bluetooth LE ในตัว, RAM ราว 320 KB ที่ใช้ได้, flash ภายนอกต่อกับชิป (บอร์ดของโปรเจคนี้คาดว่า **4 MB** ตาม `partitions.csv`) เลือกใช้เพราะราคาถูก มี Wi-Fi + BLE ครบในตัวเดียว และมีไลบรารี Arduino รองรับกว้าง ซึ่งตรงกับงานนี้ที่ต้องทั้งคุยเน็ตและคุยมือถือ

### `setup()` และ `loop()`

Arduino framework กำหนดโครงสร้างโปรแกรมไว้ 2 ฟังก์ชัน: `setup()` ถูกเรียก **ครั้งเดียว** ตอนบูต (ตั้งค่าขา เริ่ม Serial เชื่อม Wi-Fi) แล้ว `loop()` ถูกเรียก **ซ้ำไม่รู้จบ** ทุกอย่างที่ต้อง "ทำเป็นระยะ" ต้องอยู่ใน `loop()` ภายใต้ framework จริง ๆ มี FreeRTOS (ระบบปฏิบัติการเวลาจริงขนาดเล็ก) ซ่อนอยู่ แต่โค้ดโปรเจคนี้เขียนแบบ "ลูปเดียว" เป็นหลัก

### `millis()` กับ `delay()`

`delay(500)` คือ "หยุดทั้งโปรแกรม 500 ms" ระหว่างนั้นอ่านเซ็นเซอร์ ฟัง MQTT หรือกระพริบไฟไม่ได้เลย ส่วน `millis()` คืนจำนวนมิลลิวินาทีนับจากบูต ใช้สร้าง "ตัวจับเวลาแบบไม่บล็อก": เก็บเวลาครั้งล่าสุดที่ทำงานไว้ในตัวแปร แล้วทุกรอบ `loop()` ถามว่า `millis() - lastTime >= interval` หรือยัง ถ้าถึงค่อยทำ โค้ดทั้งสองไฟล์ใช้แพทเทิร์นนี้ทุกที่ (เช่น `PZEM_READ_INTERVAL_MS`, `STATUS_INTERVAL_MS`) ส่วน `delay()` ที่เหลืออยู่มีแค่ช่วงสั้น ๆ (5–150 ms) เพื่อไม่ให้ CPU วิ่งเปล่า

`millis()` เป็นเลข 32 บิตไม่มีเครื่องหมาย จะวนกลับเป็น 0 ทุก ~49.7 วัน โค้ดจึงเขียนเงื่อนไข "ถึงเวลาแล้วหรือยัง" ว่า `static_cast<int32_t>(millis() - deadline) >= 0` ซึ่งยังถูกต้องแม้ตัวนับวนรอบ

### GPIO และ UART

**GPIO** (General-Purpose Input/Output) คือขาที่โปรแกรมสั่งให้เป็นขาออก (`digitalWrite` ทำให้ไฟ 3.3 V/0 V) หรือขาเข้า (`digitalRead`) ESP32 ใช้ระดับ 3.3 V **UART** คือการสื่อสารอนุกรมสองเส้น TX (ส่ง) และ RX (รับ) ที่ความเร็วคงที่เรียกว่า baud rate เช่น 115200 และต้อง **ต่อไขว้**: TX ของอุปกรณ์หนึ่งเข้า RX ของอีกตัว ESP32 มี UART หลายชุด โปรเจคนี้ใช้ `Serial` (UART0 ผ่าน USB สำหรับ log ที่ 115200), `Serial2` (UART2 คุยกับ PZEM) และ `HardwareSerial(1)` (UART1 คุยกับ LD2410)

### IR LED และโปรโตคอล 38 kHz

รีโมตแอร์ส่งข้อมูลด้วยแสงอินฟราเรดที่ **กะพริบที่ความถี่พาหะ (carrier) 38 kHz** เพื่อให้ตัวรับกรองแสงรบกวนออกได้ ข้อมูลถูกเข้ารหัสเป็น "ช่วงที่มีพาหะ (mark)" กับ "ช่วงเงียบ (space)" ความยาวต่างกันเป็นหน่วยไมโครวินาที เช่น บิต 1 ยาวกว่าบิต 0 แต่ละยี่ห้อมีโปรโตคอลของตัวเอง (หัวเฟรม ความยาวบิต จำนวนบิต checksum) ไลบรารี **IRremoteESP8266** รู้จักหลายสิบยี่ห้อ ส่วนแอร์ Saijo Denki ไม่มีในไลบรารี โปรเจคจึงจับสัญญาณจากรีโมตจริงแล้วเขียนไดรเวอร์เอง IR เป็นทางเดียว **ไม่มีสัญญาณตอบกลับ** บอร์ดไม่รู้ว่าแอร์รับคำสั่งหรือไม่ จึงต้องใช้ PZEM วัดไฟเพื่อยืนยันผล

### PZEM-004T

โมดูลวัดไฟ AC (แรงดัน กระแส กำลัง พลังงานสะสม ความถี่ power factor) ใช้หม้อแปลงกระแส (CT) คล้องสายไฟโดยไม่ต้องตัดสาย คุยกับ ESP32 ทาง UART (ไลบรารี `PZEM004Tv30` ตั้ง baud ให้เอง) ฝั่งไฟบ้านอันตราย ต้องให้ช่างไฟติดตั้งในตู้ปิด (ตามที่ README ระบุ) ฝั่ง ESP32 ใช้แค่สายสัญญาณ 3.3 V

### HLK-LD2410

เรดาร์คลื่นมิลลิเมตรตรวจคน แบ่งระยะเป็น **เกต (gate)** 0–8 เกตละ ~0.75 m รายงานสองแบบ: **moving** (วัตถุเคลื่อนไหว) และ **static/stationary** (คนนั่งนิ่ง ๆ ที่ยังมีการหายใจ/ขยับเล็กน้อย) แต่ละเกตมี **energy** (ค่าความแรงสัญญาณ 0–100) ในโหมดปกติโมดูลบอกแค่ผลรวม ต้องเปิด **Engineering mode** จึงจะได้พลังงานรายเกต โปรเจคนี้ใช้เฉพาะ static energy รายเกตเพราะคนที่นั่งเรียนหรือทำงานมักไม่เคลื่อนไหวมาก

### LED และปุ่ม BOOT

LED ต่อกับขา GPIO ผ่านตัวต้านทาน 220–330 Ω (ป้องกันกระแสเกิน) โค้ดเป็น **active-high**: ส่ง HIGH = ติด ปุ่ม BOOT คือปุ่มบนบอร์ดที่ต่อกับ GPIO0 โดยปกติใช้เข้าโหมดแฟลช แต่โปรเจคนี้ใช้ "กดค้างตอนรีเซ็ต" เพื่อเข้าโหมดตั้งค่า BLE (ตั้ง `INPUT_PULLUP` แล้วอ่านค่า LOW = กดอยู่ เฉพาะ **ตอนบูต** ใน `setup()` ไม่ได้ตรวจใน `loop()`)

### NVS / Preferences

**NVS** (Non-Volatile Storage) คือพื้นที่ key-value ใน flash ที่ค่าไม่หายตอนไฟดับ ใช้ผ่านคลาส `Preferences`: `begin("namespace", readOnly)` → `getString/putString` → `end()` เก็บค่าตั้งค่า Wi-Fi, MQTT, ห้อง ฯลฯ ถ้าไม่มี ต้องตั้งค่าใหม่ทุกครั้งที่ไฟดับ

### Partition table และ OTA

flash ถูกแบ่งเป็น **พาร์ติชัน** ตามตาราง `partitions.csv` (ตั้งชื่อ ชนิด ตำแหน่ง ขนาด) **OTA** (Over-The-Air update) คืออัปเดตเฟิร์มแวร์ผ่านเครือข่ายแทนการเสียบสาย USB วิธีทำคือมีช่องแอปสองช่อง (`app0`, `app1`) บอร์ดรันจากช่องหนึ่ง ดาวน์โหลดตัวใหม่ลงอีกช่อง แล้วสลับช่องที่บูต ถ้าดาวน์โหลดเสียกลางทางก็ยังบูตช่องเดิมได้

### TLS และใบรับรองรากบน MCU

เมื่อใช้ MQTT แบบ TLS (ค่าเริ่มต้นคือ `rmutt-energy.tailb292b4.ts.net` พอร์ต 8443 ผ่าน Tailscale Funnel หรือพอร์ต 8883 เมื่อต่อ Broker ตรง) บอร์ดต้องแน่ใจว่าคุยกับ broker ตัวจริง จึงฝัง **ใบรับรองราก (root CA)** ของผู้ออกใบรับรอง (Let's Encrypt) ไว้ในเฟิร์มแวร์ (`letsencrypt_ca.h`) แล้วตรวจสายใบรับรองของเซิร์ฟเวอร์กับใบรากนั้น (ใบ ts.net ที่กล่อง tailscale ใช้ที่พอร์ต 8443 และใบ DuckDNS ที่ Mosquitto ใช้ที่ 8883 ออกโดย Let's Encrypt ทั้งคู่ จึงใช้ใบรากชุดเดียวกันตรวจได้) MCU ไม่มีที่เก็บใบรับรองรากของระบบแบบคอมพิวเตอร์ ต้องฝังเอง และการตรวจ "วันหมดอายุ" ของใบรับรองต้องรู้เวลาจริง จึงต้องใช้ NTP

### NTP

**NTP** (Network Time Protocol) ขอเวลาจริงจากอินเทอร์เน็ต (`pool.ntp.org`, `time.google.com`) ESP32 ไม่มีนาฬิกาที่เดินตอนไฟดับ เริ่มบูตมาเวลาคือปี 1970 โค้ดตั้ง `configTime(7 * 3600, 0, ...)` คือเขตเวลา UTC+7 (ไทย) ไม่มีเวลาออมแสง และถือว่าเวลาถูกต้องเมื่อ `time(nullptr) >= 1700000000` (ราว พ.ย. 2023 เป็นต้นไป)

### Watchdog

watchdog timer คือตัวจับเวลาฮาร์ดแวร์ที่รีเซ็ตชิปถ้าโปรแกรมไม่ยอม "ป้อน" มันเป็นระยะ (กันโปรแกรมค้าง) **โค้ดโปรเจคนี้ไม่ได้เรียก watchdog เอง** อาศัยตัวที่ Arduino core/FreeRTOS ตั้งไว้ให้ ซึ่งป้อนให้อัตโนมัติในทุกรอบ `loop()` และตอนเรียก `delay()` เหตุผลที่ทั้งโค้ดไม่บล็อกนาน ๆ ก็เพื่อไม่ให้ชนกับกลไกนี้ด้วย (การรอ Wi-Fi ใช้ลูป `delay(50)` สั้น ๆ พร้อม timeout)

### I2C และจอ OLED SH1106

**I2C** คือบัสสื่อสารสองเส้น SDA (ข้อมูล) และ SCL (สัญญาณนาฬิกา) ต่ออุปกรณ์หลายตัวบนสายคู่เดียวกันได้ โมดูลจอมักมีตัวต้านทาน **pull-up** ดึงสายทั้งสองขึ้น 3.3 V ไว้ **OLED** คือจอที่แต่ละพิกเซลเปล่งแสงเอง (ไม่มีไฟหลังจอ) จอที่ใช้คือ 1.3 นิ้ว 128×64 พิกเซล ชิปควบคุม **SH1106** ข้อเสียของ OLED คือถ้าแสดงภาพเดิมนาน ๆ พิกเซลจะ "เบิร์น" (เสื่อมไม่เท่ากันจนเห็นเงาค้าง) โค้ดจึงมีโหมดพักจอ

### FreeRTOS task และ mutex

ใต้ Arduino มี FreeRTOS ซึ่งรันได้หลาย **task** (งานที่สลับกันใช้ CPU) `loop()` เองก็เป็น task หนึ่ง (priority 1 บน core 1) ถ้าสร้าง task ใหม่ด้วย `xTaskCreatePinnedToCore` ที่ priority สูงกว่า task นั้นจะได้ CPU ก่อนเสมอเมื่อพร้อมทำงาน แม้ `loop()` กำลังค้างรอ Wi-Fi อยู่ เมื่อสอง task ใช้ตัวแปรเดียวกันต้องมี **mutex** (กุญแจ) `xSemaphoreTake` = ขอกุญแจ, `xSemaphoreGive` = คืนกุญแจ ทำให้มีแค่ task เดียวที่อ่าน/เขียนข้อมูลชุดนั้นในเวลาหนึ่ง บอร์ดสายแอร์ใช้ task แยกส่งเฟรมเข้าสายแอร์

### สายรีโมตติดผนัง (wired controller bus) ของแอร์ Daikin

แอร์บางรุ่นมีรีโมตติดผนัง (wall panel) ต่อกับเครื่องในห้องด้วยสาย รีโมตส่ง "เฟรม" คำสั่ง (เปิด/ปิด อุณหภูมิ โหมด พัดลม และอุณหภูมิห้องที่เซนเซอร์ในรีโมตวัดได้) **ทุก 1 วินาที** ทางสายเส้นหนึ่ง และแอร์ตอบสถานะกลับทางอีกเส้นหนึ่ง ต่างจาก IR ที่ส่งครั้งเดียวและไม่มีคำตอบ ทีมถอดรหัสโปรโตคอลนี้ (เรียกว่า SLM8 ตามรุ่นรีโมต) แล้วให้ ESP32 ทำหน้าที่แทนรีโมตผนัง รายละเอียดจังหวะพัลส์ checksum และความหมายแต่ละไบต์อยู่ใน **บทโปรโตคอลสายแอร์ Daikin SLM8 (บทที่ 19)** บทนี้อธิบายเฉพาะว่าเฟิร์มแวร์หลักใช้มันอย่างไร

### ไลบรารีและเวอร์ชัน

| ไลบรารี | เวอร์ชัน (ตาม `firmware/README.md`) | ใช้ทำอะไร |
|---|---|---|
| ESP32 board package (Arduino-ESP32) | โค้ดมีหมายเหตุถึง Core 3.x | Wi-Fi, BLE, `Preferences`, `HTTPUpdate`, `WiFiClientSecure` มากับ board package |
| ArduinoJson | 6.x (ใช้ `DynamicJsonDocument`) | อ่าน/สร้าง JSON (v7 ใช้ API ต่างออกไป จึงต้องล็อกที่ 6) |
| PubSubClient | ไม่ระบุเลขเวอร์ชัน | MQTT client |
| IRremoteESP8266 | **2.9.0** (เฉพาะบอร์ดแอร์ IR, บอร์ดสายแอร์ไม่ใช้) | ส่ง IR ผ่าน `IRac` และ `IRsend` |
| PZEM004Tv30 (Jakub Mandula) | ไม่ระบุ (บอร์ดแอร์ทั้งสองรุ่น) | อ่าน PZEM |
| U8g2 (olikraus) | ไม่ระบุ (บอร์ดแอร์ทั้งสองรุ่น) | วาดจอ OLED SH1106 128×64 |
| DHT sensor library (Adafruit) + Adafruit Unified Sensor | ไม่ระบุ (เฉพาะบอร์ดสายแอร์) | อ่านอุณหภูมิห้องจาก DHT11 |
| ld2410 (Nick Reynolds) | **0.2.2 ขึ้นไป** (เฉพาะบอร์ดตรวจจับคน) | อ่านเรดาร์ ต้อง 0.2.2+ เพราะต้องใช้ API Engineering mode รายเกต |

## โครงสร้างโฟลเดอร์

```text
firmware/
├── README.md                          # คู่มือรวมของเฟิร์มแวร์ (ขา การตั้งค่า log การแก้ปัญหา)
├── update-root-ca.ps1                 # สคริปต์ดาวน์โหลดใบรับรองรากแล้วสร้าง letsencrypt_ca.h
├── rmutt_esp32_air/                   # บอร์ดแอร์ IR (สเก็ตช์ Arduino: โฟลเดอร์ชื่อเดียวกับ .ino)
│   ├── rmutt_esp32_air.ino            # โปรแกรมหลัก 2,032 บรรทัด (2.5.1)
│   ├── SaijoDenkiAC.h / .cpp          # ไดรเวอร์ IR ของแอร์ Saijo Denki (เขียนเอง)
│   ├── history_log.h                  # ring buffer เก็บข้อมูลไฟฟ้าตอนเน็ตหลุด
│   ├── ota_update.h                   # อัปเดตเฟิร์มแวร์ผ่าน HTTPS
│   ├── letsencrypt_ca.h               # ใบรับรองราก ISRG X1 + X2 (สร้างโดยสคริปต์)
│   ├── partitions.csv                 # ตารางพาร์ติชัน (มี rmuttlog)
│   ├── oled_display.h                 # ตัวขับจอ OLED: ตรวจว่ามีจอ, จังหวะวาด, พักจอ
│   ├── oled_ui.h                      # (ใหม่) ฟังก์ชันวาดหน้าจอ 5 แบบ + หน้าพิเศษ
│   ├── build_opt.h                    # (ใหม่) แฟล็กคอมไพเลอร์ ปิดส่วนที่ไม่ใช้ให้โปรแกรมพอดีแฟลช
│   └── README_OLED_TH.md              # (ใหม่) วิธีต่อจอและเหตุผลของ build_opt.h
├── rmutt_esp32_air_wired/             # บอร์ดแอร์รุ่นสายแอร์ Daikin
│   ├── rmutt_esp32_air_wired.ino      # โปรแกรมหลัก 2,031 บรรทัด (2.5.2-slm8) แตกมาจากรุ่น IR
│   ├── DaikinSLM8.h                   # โปรโตคอลสายแอร์ SLM8 (รับ/ส่งเฟรม) อธิบายในบทที่ 19
│   ├── wired_bus.h                    # ห่อ DaikinSLM8 ให้รันใน FreeRTOS task แยก + mutex
│   ├── oled_display.h / oled_ui.h     # เหมือนของบอร์ด IR ทุกไบต์
│   ├── build_opt.h                    # ปิดเฉพาะไดรเวอร์ I2C/SPI ฮาร์ดแวร์ (ไม่มี IR ให้ปิด)
│   ├── history_log.h, ota_update.h,   # เหมือนของบอร์ด IR ทุกไบต์
│   │   letsencrypt_ca.h, partitions.csv
│   └── README_WIRED_TH.md             # วงจร ต่อสาย ตารางความต่างกับรุ่น IR
├── rmutt_esp32_occupancy/             # บอร์ดตรวจจับคน
│   ├── rmutt_esp32_occupancy.ino      # โปรแกรมหลัก 1,162 บรรทัด (1.3.3)
│   ├── ota_update.h                   # เหมือนของบอร์ดแอร์ (ต่างแค่ช่องว่างท้ายบรรทัด 22)
│   ├── letsencrypt_ca.h               # เหมือนของบอร์ดแอร์ทุกไบต์
│   └── partitions.csv                 # ตารางพาร์ติชัน (มี coredump แทน rmuttlog)
├── ld2410_pinscan/ld2410_pinscan.ino  # เครื่องมือหาขาที่เรดาร์ส่งข้อมูลมา
├── reset/reset.ino                    # ล้าง NVS (factory reset)
└── tests/history_log_test.cpp         # ทดสอบ history_log.h บนคอมพิวเตอร์
```

> [!NOTE]
> ใน Arduino IDE ไฟล์ `.cpp` `.h` ที่อยู่ในโฟลเดอร์เดียวกับ `.ino` จะถูกคอมไพล์รวมเข้าสเก็ตช์อัตโนมัติ นั่นคือเหตุผลที่ `SaijoDenkiAC` ไม่ต้องติดตั้งเป็นไลบรารี และ `partitions.csv` ที่วางข้าง `.ino` จะถูก IDE ใช้เอง แต่ต้องเลือก Tools > Partition Scheme ให้ตรงขนาด (ในไฟล์เขียนว่า "No FS 4MB (2MB APP x2)")

## ตารางขาของแต่ละบอร์ด

### บอร์ดแอร์ IR (ค่าคงที่บรรทัด 43–49 ของ `rmutt_esp32_air.ino`)

| GPIO | ชื่อในโค้ด | ทิศทาง | ต่อกับ | หมายเหตุ |
|---|---|---|---|---|
| 17 | `IR_LED_PIN` | ออก | วงจรขับ IR LED | ห้ามต่อ LED กำลังสูงตรง ๆ ใช้ทรานซิสเตอร์ + ตัวต้านทาน และต้องต่อ GND ร่วม |
| 16 | `PZEM_RX_PIN` | เข้า (RX ของ Serial2) | **TX ของ PZEM** | ต่อไขว้ |
| 18 | `PZEM_TX_PIN` | ออก (TX ของ Serial2) | **RX ของ PZEM** | ต่อไขว้ |
| 25 | `GREEN_LED_PIN` | ออก | LED เขียว | active-high |
| 26 | `RED_LED_PIN` | ออก | LED แดง | active-high |
| 27 | `YELLOW_LED_PIN` | ออก | LED เหลือง | active-high |
| 0 | `SETUP_BUTTON_PIN` | เข้า `INPUT_PULLUP` | ปุ่ม BOOT บนบอร์ด | LOW ตอนบูต = เข้าโหมดตั้งค่า |
| 21 | `kSda` (ใน `oled_display.h`) | I2C SDA | ขา SDA ของจอ OLED | จอ VCC → 3V3, GND → GND ไม่ต่อจอก็ได้ |
| 22 | `kScl` (ใน `oled_display.h`) | I2C SCL | ขา SCL/SCK ของจอ OLED | |

### บอร์ดแอร์สายแอร์ (บรรทัด 46–60 ของ `rmutt_esp32_air_wired.ino`)

| GPIO | ชื่อในโค้ด | ทิศทาง | ต่อกับ | หมายเหตุ |
|---|---|---|---|---|
| 33 | `BUS_TX_PIN` | ออก | สายสั่งงาน (panel → แอร์) ผ่านไดโอด 1N4148 (ขามีแถบ → GPIO33) | ไดโอดทำให้ ESP32 ดึงสายลง LOW ได้อย่างเดียว ไม่จ่ายไฟเข้าสายแอร์ ถ้าใช้ทรานซิสเตอร์ 2N2222 ตั้ง `BUS_TX_INVERT = true` |
| 35 | `BUS_RX_PIN` | เข้า | สายสถานะ (แอร์ → panel) ผ่านตัวแบ่งแรงดัน 100k/200k | แบ่งแรงดันให้เหลือระดับที่ขา 3.3 V รับได้ |
| 34 | `BUS_ECHO_PIN` | เข้า | สายสั่งงาน ผ่าน 100k/200k | อ่านเฟรมที่ตัวเองส่งกลับมาตรวจ ไม่บังคับ (`-1` = ไม่ใช้) |
| 4 | `DHT_PIN` | เข้า/ออก (1 สาย) | DHT11 (Keyes KY-015) ขา DATA | อุณหภูมิห้องที่ส่งต่อให้แอร์ |
| 21 / 22 | (ใน `oled_display.h`) | I2C | จอ OLED | เหมือนบอร์ด IR |
| 18 | `PZEM_RX_PIN` | เข้า (RX ของ Serial2) | **TX ของ PZEM** | **ต่างจากบอร์ด IR** (บอร์ด IR ใช้ 16) |
| 14 | `PZEM_TX_PIN` | ออก (TX ของ Serial2) | **RX ของ PZEM** | **ต่างจากบอร์ด IR** (บอร์ด IR ใช้ 18) |
| 25 / 26 / 23 | LED เขียว / แดง / เหลือง | ออก | LED | เขียว/แดงเหมือนบอร์ด IR ส่วนเหลืองเป็น **23** (บอร์ด IR ใช้ 27) |
| 0 | `SETUP_BUTTON_PIN` | เข้า | ปุ่ม BOOT | เหมือนบอร์ด IR |
| — | — | — | GND สายแอร์ → GND ของ ESP32 (**ต้องต่อ**), +5 V ของสายแอร์ **ไม่ต่อ** | บอร์ดใช้แหล่งจ่ายของตัวเอง (README ระบุ HDR-15-5) |

> [!WARN]
> **ขา PZEM และ LED เหลืองของบอร์ดสายแอร์ไม่เหมือนบอร์ด IR** PZEM อยู่ที่ RX=GPIO18 / TX=GPIO14 และ LED เหลืองที่ GPIO23 ถ้าต่อสายตามบอร์ด IR (16/18/27) PZEM จะอ่านไม่ได้ เลขรุ่นของเฟิร์มแวร์นี้ (`2.5.2-slm8`) ไม่ได้ขยับตอนย้ายขา บอร์ดที่แฟลชไว้นานแล้วอาจยังเป็นขาชุดเก่า ถ้าไม่แน่ใจให้แฟลชใหม่จากโค้ดปัจจุบัน และ `firmware/README.md` กับ `README_WIRED_TH.md` ยังเขียนขาชุดเก่าอยู่ ให้เชื่อค่าในไฟล์ `.ino`

บอร์ดนี้ **ไม่มี GPIO17 (IR)** และขาส่งของสายแอร์ย้ายมาจาก GPIO25 เป็น GPIO33 เพราะ GPIO25 เป็น LED เขียวของเฟิร์มแวร์แอปอยู่แล้ว (ตาม `README_WIRED_TH.md`) ตาราง Pins ใน `firmware/README.md` ถูกแก้ จากรายการธรรมดาเป็นตารางสองคอลัมน์เทียบบอร์ด IR กับบอร์ดสายแอร์

> [!WHY]
> **ทำไมใช้ GPIO34/35 เป็นขารับ:** สองขานี้ของ ESP32 เป็น "ขาเข้าอย่างเดียว" (ไม่มีวงจรขาออก) จึงเหมาะกับการรับสัญญาณจากภายนอกที่ไม่ต้องการให้ ESP32 เผลอขับกลับ และใช้ตัวแบ่งแรงดันเพราะสายของแอร์ค้างอยู่ราว 4.7–4.9 V (วัดจริงตามบันทึก `claude/slm8_protocol_notes_TH.md` ในโปรเจค) ต่อตรงเข้าขา 3.3 V จะเสี่ยงขาเสีย ตัวแบ่ง 100k/200k ลดเหลือราว 2/3 (≈3.2 V) ที่ต้องใช้ค่าสูงถึงหลักแสนโอห์มเพราะตัวดึงขึ้น (pull-up) ในแอร์อ่อนมาก (ประมาณ 20k–60k) ถ้าใช้ 10k/20k ตามบันทึกเดียวกัน แรงดันตกเหลือ 1.4–2.9 V จน ESP32 อ่านเป็น LOW ตลอด

### บอร์ดตรวจจับคน (บรรทัด 30–40 ของ `rmutt_esp32_occupancy.ino`)

| GPIO | ชื่อในโค้ด | ทิศทาง | ต่อกับ | หมายเหตุ |
|---|---|---|---|---|
| 32 | `RADAR_RX_PIN` | เข้า (RX ของ UART1) | **TX ของ LD2410** | ต่อไขว้ |
| 33 | `RADAR_TX_PIN` | ออก (TX ของ UART1) | **RX ของ LD2410** | ใช้สั่งเปิด Engineering mode |
| 0 | `SETUP_BUTTON_PIN` | เข้า `INPUT_PULLUP` | ปุ่ม BOOT | เหมือนบอร์ดแอร์ |
| 25 | `GREEN_LED_PIN` | ออก | LED เขียว ผ่านตัวต้านทาน 220–330 Ω ลง GND | สถานะการเชื่อมต่อ |
| 26 | `RED_LED_PIN` | ออก | LED แดง ผ่านตัวต้านทาน 220–330 Ω ลง GND | มีคนในห้อง |
| — | — | — | `VCC` → 5V/VIN, `GND` → GND | ขา `OUT` ของ LD2410 ปล่อยลอย ไม่ใช้ |

UART1 เปิดที่ 256000 baud, `SERIAL_8N1` (8 บิตข้อมูล ไม่มี parity 1 stop bit) บอร์ดนี้ไม่มีการต่อไฟ AC

**ไฟ LED ของบอร์ดตรวจคน** (ฟังก์ชัน `updateStatusLeds()` บรรทัด 1149–1162)

| LED | สถานะ | ความหมาย |
|---|---|---|
| เขียว (GPIO25) | ติดค้าง | Wi-Fi และ MQTT ต่อครบ พร้อมส่งสถานะเข้าแอป |
| เขียว | กระพริบทุก 400 ms (`LED_BLINK_INTERVAL_MS`) | กำลังต่อ Wi-Fi/รอเวลา NTP (`connectionInProgress`) หรือตั้งค่าแล้วแต่ยังต่อไม่ได้และกำลังลองใหม่ |
| เขียว | ดับ | ยังไม่ได้ตั้งค่า หรืออยู่ในโหมดตั้งค่า BLE เพราะต่อไม่ได้ |
| แดง (GPIO26) | ติด / ดับ | ตามค่า `occupied` (มีคน / ไม่มีคน) ถ้าเรดาร์ไม่ส่งข้อมูล `occupied` เป็น false เสมอ แดงจึงดับ |

> [!WHY]
> **ทำไมต้องเรียก `updateStatusLeds()` ในลูปรอ Wi-Fi และ NTP ด้วย:** `connectWifiCredentials()` รอได้นานถึง 20 วินาที และ `ensureClockSynced()` นานถึง 15 วินาที ระหว่างนั้น `loop()` ไม่ได้วน ถ้าเรียกแค่ใน `loop()` ไฟเขียวจะค้างนิ่งแทนที่จะกระพริบ โค้ดจึงตั้งธง `connectionInProgress` แล้วเรียก `updateStatusLeds()` ทุก 20 ms ภายในลูปรอ (ลูปรอ NTP แบ่งการรอเป็น 10 × 20 ms ต่อรอบด้วยเหตุผลเดียวกัน)

## อธิบายทีละไฟล์

### `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` (บอร์ดแอร์ IR 2,032 บรรทัด, เวอร์ชัน 2.5.1)

ไฟล์เดียวที่เป็นหัวใจของบอร์ดแอร์ IR เรียงตามลำดับในไฟล์ได้ดังนี้ (เลขในวงเล็บคือบรรทัดของเวอร์ชันปัจจุบัน หลังเพิ่มจอ OLED และ unprovision เลขบรรทัดเลื่อนจากเดิมราว 6–67 บรรทัด)

**1) หัวไฟล์และ include (1–41)** — คอมเมนต์สรุปความสามารถ (มีบรรทัด 10 เพิ่มว่า "OLED 1.3\" SH1106 I2C (GPIO21 SDA / GPIO22 SCL)") แล้ว include ไลบรารี BLE (`BLEDevice`, `BLEServer`, `BLE2902`...), `IRac`/`IRremoteESP8266`, `PZEM004Tv30`, `Preferences`, `PubSubClient`, `WiFiClientSecure`, และไฟล์ของโปรเจค `SaijoDenkiAC.h`, `letsencrypt_ca.h`, `ota_update.h`, `history_log.h` และ `oled_display.h` (บรรทัด 38)

**2) ค่าคงที่ (43–91)** ใช้ `constexpr` (ค่าที่คอมไพเลอร์รู้ตอนคอมไพล์ ไม่กินที่ใน RAM) ตั้งชื่อลงท้าย `_MS` ทุกค่าที่เป็นเวลา ตารางสรุปอยู่ด้านล่าง

| ค่าคงที่ | ค่า | ความหมาย |
|---|---|---|
| `PZEM_READ_INTERVAL_MS` | 2000 | อ่าน PZEM ทุก 2 วินาที |
| `STATUS_INTERVAL_MS` | 10000 | ส่ง `/status` ทุก 10 วินาที (และส่งทันทีเมื่อมีเหตุการณ์) |
| `WIFI_TIMEOUT_MS` | 20000 | รอต่อ Wi-Fi ปกติสูงสุด 20 วินาที |
| `WIFI_PROVISION_TIMEOUT_MS` | 15000 | รอต่อ Wi-Fi ตอนทดสอบรหัสที่แอปส่งมา |
| `WIFI_RECOVERY_RETRY_MS` / `WIFI_RECOVERY_ATTEMPT_MS` | 30000 / 8000 | ในโหมดกู้ Wi-Fi ลองต่อซ้ำทุก 30 วินาที ครั้งละไม่เกิน 8 วินาที |
| `BLE_READVERTISE_DELAY_MS` | 600 | หน่วงก่อนประกาศ BLE ใหม่หลังถูกตัดการเชื่อมต่อ |
| `ONLINE_SETUP_WINDOW_MS` | 300000 (5 นาที) | หน้าต่างตั้งค่า BLE ตอนที่บอร์ดยังออนไลน์ |
| `YELLOW_LED_BLINK_INTERVAL_MS` | 400 | จังหวะกระพริบ LED เหลือง |
| `CLASS_SCHEDULE_TTL_MS` | 120000 (2 นาที) | ผลตารางเรียนจาก Backend ถือว่าสดไม่เกิน 2 นาที |
| `AC_RUNNING_ON_WATTS` / `AC_RUNNING_OFF_WATTS` | 30.0 / 10.0 | เกณฑ์ hysteresis ของ "แอร์ทำงาน" |
| `AC_RUNNING_CONFIRM_SAMPLES` | 3 | ต้องเจอติดกัน 3 ครั้ง |
| `PZEM_FAILURE_LIMIT` | 3 | อ่านพลาดติดกัน 3 ครั้งถือว่า PZEM ใช้ไม่ได้ |
| `MAX_CONFIG_BYTES` | 4096 | ขนาดสูงสุดของ JSON ตั้งค่าที่รับทาง BLE |
| `NTP_SYNC_TIMEOUT_MS` | 15000 | รอ NTP ตอนที่ต้องใช้ TLS/OTA |
| `HISTORY_BATCH_SIZE` | 10 | ส่งข้อมูลย้อนหลังทีละ 10 รายการ |
| `HISTORY_SEND_GAP_MS` | 1000 | เว้น 1 วินาทีหลังได้ ack ก่อนส่งชุดถัดไป |
| `HISTORY_ACK_TIMEOUT_MS` | 20000 | รอ ack 20 วินาที ไม่มาก็ส่งใหม่ |
| `HISTORY_RETRY_DELAY_MS` | 5000 | หน่วงก่อนส่งซ้ำ |
| `HISTORY_START_DELAY_MIN/MAX_MS` | 5000 / 45000 | หน่วงแบบสุ่ม 5–45 วินาทีหลังต่อ MQTT ได้ก่อนเริ่มส่งย้อนหลัง |
| `HISTORY_PARTITION_SUBTYPE` | 0x40 | subtype ของพาร์ติชัน `rmuttlog` |
| `SAIJO_DENKI_PROTOCOL` | `"SAIJO_DENKI"` | ชื่อโปรโตคอลที่แอป Backend ใช้ตรงกัน |
| `FIRMWARE_VERSION` (บรรทัด 68) | `"2.5.1"` | เวอร์ชันที่บอร์ดรายงานใน BLE IDENTITY และ `/status` |

UUID 6 ตัว (`SERVICE_UUID` ลงท้าย `0001` ... `SETTINGS_UUID` ลงท้าย `0006`, ขึ้นต้น `7b57`) คือ service และ characteristic ของ BLE ที่แอปต้องรู้ ตารางหน้าที่ของแต่ละตัวอยู่ใน **บทโปรโตคอลสื่อสาร**

**3) โครงสร้างข้อมูล (93–144)** — `DeviceConfig` (ค่าที่ได้จากการตั้งค่า: ห้อง เลขแอร์ โปรโตคอล IR Wi-Fi MQTT token เวลาเปิด/ปิดรายวัน), `AirState` (สถานะแอร์ที่ "เชื่อว่าเป็น": power, temperature, mode, fanSpeed, verticalSwing, eco, turbo ... timerOn/OffMinutes), `PowerMeasurements` (ค่าที่ PZEM อ่านได้ + `acRunning` + ตัวนับ `runningSamples/stoppedSamples/failedSamples`) การรวมค่าเป็น `struct` ทำให้ส่งต่อและบันทึกได้ง่าย แทนที่จะมีตัวแปรลอยหลายสิบตัว

**4) ตัวแปรโกลบอล (146–248)** — อ็อบเจกต์หลัก: `preferences`, `wifiClient` (TCP ธรรมดา), `secureClient` (TCP + TLS), `mqttClient` (PubSubClient เริ่มด้วย `wifiClient` แล้วสลับเป็น `secureClient` ตอนต่อ), `irAc` (`IRac` ตัวกลางของ IRremoteESP8266), `saijoAc`, `pzem(Serial2, 16, 18)`, ตัวแปร `config`, `airState`, `powerMeasurements` และ `oledDisplay` (อ็อบเจกต์จอ, บรรทัด 158) กับ `oledReason` (ข้อความเหตุผลที่เข้าโหมดตั้งค่า ไว้แสดงบนจอ, บรรทัด 159)
ถัดมาคือ `PartitionFlash` (ตัวห่อ API พาร์ติชัน flash ให้ `HistoryLog` ใช้) และ `HistoryInterval` (ตัวสะสมค่าในช่วง 5 นาที) กับกลุ่มตัวแปรสถานะ BLE (`bleClientConnected`, `bleBlocksNormalOperation`, `bleWifiOnlyMode`...) และ flag สื่อสารระหว่าง callback กับลูป (`mqttCommandReady`, `otaRequested`, `historyAckReady`, `configReady`)

**5) Forward declaration (250–293)** — ประกาศชื่อฟังก์ชันล่วงหน้า เพื่อให้เรียกใช้ก่อนที่จะนิยามได้ (C++ ต้องรู้จักชื่อก่อนใช้) เพิ่ม `unprovisionAndRestart` (บรรทัด 274) และ `refreshOled` (บรรทัด 290)

**6) คลาส callback ของ BLE (295–424)**
- `ServerCallbacks` — `onConnect` ตั้ง `bleClientConnected = true`, `onDisconnect` ไม่เรียกประกาศใหม่ทันที แต่ตั้งเวลา `bleReadvertiseAt = millis() + 600` ให้ `loop()` ทำ (คอมเมนต์บอกว่าทำใน callback task ไม่เสถียรบน Windows)
- `ConfigCallbacks::onWrite` — รับ JSON ตั้งค่าที่แอปส่งมาเป็นชิ้น ๆ ทุกแพ็กเก็ตมีหัว 6 ไบต์: ไบต์ 0 และ 1 ต้องเป็น `1` (เวอร์ชัน), ไบต์ 2–3 ลำดับแพ็กเก็ต (big-endian), ไบต์ 4–5 จำนวนแพ็กเก็ตทั้งหมด (สูงสุด 32) ตรวจลำดับให้ต่อเนื่อง ตรวจขนาดรวมไม่เกิน `MAX_CONFIG_BYTES` พอครบจึงเก็บใส่ `pendingConfig` แล้วตั้ง `configReady = true` **ไม่ประมวลผลใน callback** เพราะต้องทดสอบ Wi-Fi นานหลายวินาที ซึ่งจะบล็อก BLE stack
- `WifiScanCallbacks::onRead` — เมื่อแอป "อ่าน" characteristic `WIFI_SCAN_UUID` บอร์ดสแกน Wi-Fi (`WiFi.scanNetworks`) ตัดชื่อซ้ำ เก็บไม่เกิน 8 เครือข่าย และตัด JSON ไม่ให้เกิน ~480 ไบต์ (ขนาดที่อ่านทีเดียวผ่าน BLE ได้) ในรูป `[ssid, rssi, มีรหัสหรือไม่]`

**7) `setup()` และ `loop()` (426–555)** — อธิบายละเอียดในหัวข้อเจาะโค้ด (บรรทัด 436 เพิ่ม `oledDisplay.begin()` ตรวจและเริ่มจอ)

**8) ฟังก์ชันช่วย (557–594)** — `createDeviceId()` สร้างรหัส `ESP32-XXXXXXXXXXXX` จาก eFuse MAC address (เลขประจำชิป ไม่ซ้ำกัน) จึงไม่ต้องตั้งชื่อเอง `isValidRoomNumber()` ยอมรับเฉพาะ `A–Z 0–9 _ -` ยาว 2–20 ตัว `isSupportedAirProtocol()` ยอม `SAIJO_DENKI` หรือชื่อที่ `IRac::isProtocolSupported(strToDecodeType(...))` รู้จัก

**9) NVS (596–671)** — `loadConfig/saveConfig` ใช้ namespace `"rmutt-air"`, `loadAirState/saveAirState` ใช้ namespace `"rmutt-state"` ตารางคีย์:

| namespace | คีย์ |
|---|---|
| `rmutt-air` | `configured`, `room`, `air_no`, `air_name`, `protocol`, `wifi_ssid`, `wifi_pass`, `mqtt_host`, `mqtt_port`, `mqtt_user`, `mqtt_pass`, `mqtt_tls`, `mqtt_topic`, `prov_token`, `daily_on`, `daily_off` |
| `rmutt-state` | `power`, `temp`, `mode`, `fan`, `swing_v`, `swing_h`, `eco`, `turbo`, `sleep`, `quiet`, `light`, `clean`, และ `hist_ack` (ts สุดท้ายที่ Backend ยืนยันรับข้อมูลย้อนหลัง) |

แยก namespace เพราะ "ค่าตั้งค่า" เปลี่ยนนาน ๆ ครั้ง ส่วน "สถานะแอร์" เขียนบ่อย การจำสถานะแอร์ไว้ทำให้บูตใหม่ (เช่นไฟดับ) แล้วบอร์ดยังรู้ว่าล่าสุดสั่งอะไรไป (ตัวจับเวลา timerOn/Off **ไม่ถูกเก็บ** จึงหายเมื่อรีบูต)

**10) BLE server (673–776)** — `startBleProvisioning()` สร้าง BLE server ครั้งเดียว (`BLEDevice::init(config.bleName)` ชื่อ `RMUTT-AC-` + 12 หลักท้ายของ Device ID) สร้าง service + 5 characteristic: `CONFIG` (WRITE), `STATUS` (READ+NOTIFY พร้อม descriptor `BLE2902` เพื่อให้แอปสมัครรับแจ้งเตือน), `IDENTITY` (READ), `SETTINGS` (READ), `WIFI_SCAN` (READ) บรรทัด 710 ใส่ `identity["controlType"] = "ir"` ลงใน IDENTITY ให้แอปรู้ว่าเป็นบอร์ด IR (แยกจากบอร์ดสายแอร์ที่ส่ง `"wired"`) ตั้งใจให้ `IDENTITY` สั้น (ไม่เกิน 256 ไบต์ของ JSON buffer) เพราะ Windows ที่ MTU ปกติอ่านค่าใหญ่ไม่ได้ ค่าตั้งค่าเดิมจึงแยกไปอยู่ใน `SETTINGS` `startBleAdvertising()` หยุด-หน่วง 80 ms-เริ่มประกาศใหม่ ไม่ทำถ้ามีแอปต่ออยู่

**11) โหมดกู้และตั้งค่า (778–966)**
- `enterBleRecovery(reason, retryWifi)` — บรรทัด 813 เก็บ `reason` ไม่เกิน 25 ตัวอักษรลง `oledReason` ให้หน้า SETUP MODE บนจอแสดงว่าทำไมเข้าโหมดนี้ (จอกว้าง 128 พิกเซล ฟอนต์ 5×7 ใส่ได้ราว 25 ตัว) จากนั้นตั้ง `bleBlocksNormalOperation = true` (หยุดงานปกติ), ถ้า `retryWifi` ตั้ง `wifiRecoveryActive`, ตัด MQTT/Wi-Fi แล้วเปิด BLE ใช้เมื่อ: ยังไม่เคยตั้งค่า, กด BOOT ตอนบูต, ต่อ Wi-Fi เดิมไม่ได้ตอนบูต, หรือ Wi-Fi หลุดระหว่างใช้งาน
- `attemptWifiRecovery()` — ในโหมดกู้ที่เกิดจาก Wi-Fi ลองต่อ Wi-Fi เดิมซ้ำทุก 30 วินาที (ครั้งละ 8 วินาที) ไม่ลองถ้ามีแอปต่อ BLE อยู่หรือกำลังจะรีสตาร์ต ถ้าต่อได้ก็ปิด BLE กลับไปทำงานปกติเอง (`connectMqtt()`) **ทำไม:** ถ้าไม่มีกลไกนี้ ต้องมีคนเดินไปกด BOOT+RESET ทุกครั้งที่ router รีบูต
- `enterBleReconfiguration()` — ถูกเรียกเมื่อ Backend ส่ง `{"action":"enter_setup"}` ทาง MQTT บอร์ดยังออนไลน์อยู่ และเปิด BLE ไว้ 5 นาที (`ONLINE_SETUP_WINDOW_MS`) โดยค่าเดิมยังใช้งานต่อจนกว่าจะกดบันทึก
- `keepsServerAssignment()` — คืน `true` ถ้าการตั้งค่าใหม่ "ไม่แตะ" ห้อง เลขแอร์ และ MQTT ทุกตัว ใช้กับ `bleWifiOnlyMode` (ดูด้านล่าง)
- `processPendingConfig()` — ถูกเรียกจาก `loop()` เมื่อ `configReady` อ่าน JSON → สร้าง `DeviceConfig incoming` → ตรวจความถูกต้อง (Device ID ตรงกับบอร์ดนี้, ห้องถูกรูปแบบ, `airNumber` 1–6, มีชื่อแอร์, มี token, มี SSID, **รหัส Wi-Fi ≥ 8 ตัว**, มี MQTT host/topic, โปรโตคอลรองรับ) → ถ้าอยู่ใน Wi-Fi-only mode ต้อง `keepsServerAssignment` → **ทดสอบต่อ Wi-Fi ด้วยรหัสใหม่ก่อน** (`connectWifiCredentials` 15 วินาที) ถ้าไม่ผ่านก็ไม่บันทึก แจ้งแอปว่า `wifi_connection_failed` แล้วกู้ค่าเดิมกลับ ถ้าผ่านจึง `saveConfig` แล้วแจ้ง `config_saved` และตั้ง `restartAt = millis() + 1500` ให้รีสตาร์ต
- `notifyBle()` — ตอบแอปด้วย JSON `{ok, code, message}` ทาง characteristic STATUS (อ่านหรือ notify)

> [!WHY]
> **ทำไมต้องมี Wi-Fi-only mode:** ถ้าบอร์ดเข้าโหมดตั้งค่า BLE เพราะ Wi-Fi หลุด ใครก็ตามที่ยืนใกล้บอร์ดสามารถต่อ BLE ได้ หากยอมให้เปลี่ยนห้องหรือ MQTT server ได้ คนแปลกหน้าจะชี้บอร์ดไปหา broker ของตัวเองแล้วสั่งแอร์ห้องนั้นได้ จึงล็อกให้แก้ได้เฉพาะ Wi-Fi ถ้าจะเปลี่ยนห้อง/เซิร์ฟเวอร์ต้องกด BOOT ค้างตอนรีเซ็ต (ต้องเข้าถึงตัวบอร์ด) หรือให้แอดมินส่ง `enter_setup` จาก Backend (`bleWifiOnlyMode = false`)

**12) Wi-Fi และเวลา (980–1047)** — `connectWifi()` เรียก `connectWifiCredentials(ssid, password, timeoutMs)` ซึ่งตั้ง `WIFI_STA`, `WiFi.begin`, วนรอด้วย `delay(50)` จนต่อได้หรือครบเวลา ระหว่างรอเรียก `updateStatusLeds()` ให้ LED เหลืองกระพริบ ถ้า `WL_CONNECT_FAILED` หรือ `WL_NO_SSID_AVAIL` ออกทันที เมื่อต่อสำเร็จครั้งแรกจะเรียก `configTime(7 * 3600, 0, "pool.ntp.org", "time.nist.gov")` เริ่มซิงก์เวลาแบบไม่รอ ส่วน `ensureClockSynced()` เป็นตัวที่ "รอจริง" (สูงสุด 15 วินาที ใช้ `time.google.com`) เรียกก่อนต่อ MQTT แบบ TLS และก่อน OTA

**13) MQTT (1049–1333)** — `connectMqtt()`, `mqttCallback()`, `unprovisionAndRestart()` (บรรทัด 1167–1209), `processMqttCommand()` (เริ่มบรรทัด 1211) ดูหัวข้อเจาะโค้ด ตารางด้านล่าง และหัวข้อ "ล้างบอร์ดเมื่อถูกลบออกจากแอป (unprovision)"

**14) ส่ง IR (1335–1452)** — `sendCurrentIrState()` ทางทั่วไปผ่าน `IRac` และ `sendSaijoCurrentIrState()` ทางไดรเวอร์ของเรา (ดูส่วน IR ด้านล่าง)

**15) publish (1454–1549)** — `publishStatus()` สร้าง JSON ของ `/status` (online, deviceId, firmwareVersion, otaError ถ้ามี, roomNumber, airNumber, ip, rssi, pzemAvailable, acRunning, outsideSchedule, scheduleConfigured, classScheduleConfigured, **historyPending**, และ voltage/current/powerWatts/energyKwh/frequencyHz/powerFactor ถ้า PZEM พร้อม ไม่พร้อมก็ส่ง `null`) ส่งแบบ retained (`publish(..., true)`) `publishState()` (เริ่มบรรทัด 1499) เรียก `oledDisplay.poke()` ก่อน (บรรทัด 1500) ให้จอวาดค่าใหม่ทันทีที่สถานะแอร์เปลี่ยน แล้วส่ง `/state` (สถานะแอร์ + `commandId` ถ้ามี) retained `publishProvisioningToken()` ส่ง `/provision` ทุก 10 วินาทีจนกว่า Backend จะตอบ ack

**16) OTA (1551–1579)** — `performOtaUpdate()` ดูหัวข้อเจาะโค้ดคู่กับ `ota_update.h`

**17) ตัวจับเวลา (1581–1633)** — `processTimers()` ตัวตั้งเวลาเปิด/ปิดที่ผู้ใช้สั่งจากแอป (คิดจาก `millis()` + นาที × 60000) และ `processDailySchedule()` เปิด/ปิดตามเวลา `dailyOn`/`dailyOff` รูปแบบ `"HH:MM"` ที่ตั้งตอน BLE: ใช้ `getLocalTime` (ต้องมี NTP) ตรวจครั้งเดียวต่อนาที (`lastScheduleMinute`) เมื่อเวลาตรงก็ยิง IR และ `publishState()`

**18) PZEM, LED, ตาราง (1635–1775)** — `readPowerMeter()` (เจาะโค้ด, บรรทัด 1698 เพิ่ม `oledDisplay.pushPower(powerWatts)`), `updateStatusLeds()` (ตาราง LED ด้านล่าง, บรรทัด 1735 เพิ่ม `refreshOled()` ท้ายฟังก์ชัน จอจึงถูกอัปเดตทุกรอบ `loop()` เพราะ `updateStatusLeds()` ถูกเรียกทุกรอบอยู่แล้ว), `isWithinConfiguredSchedule()` (ตรวจ "อยู่ในช่วง dailyOn–dailyOff หรือไม่" รองรับช่วงข้ามเที่ยงคืนเช่น 22:00–06:00, ถ้าตั้งไม่ครบหรือไม่รู้เวลาให้ถือว่า "อยู่ในช่วง" เพื่อไม่กล่าวหาผู้ใช้ผิด), `isWithinAllowedSchedule()` (ถ้าผลตารางเรียนจาก Backend ยังสด ≤ 2 นาทีและห้องมีตารางเรียน ใช้ `withinClassSchedule` ไม่งั้นถอยไปใช้ตารางรายวันบนบอร์ด), `parseMinutesOfDay()` (แปลง `"HH:MM"` เป็นนาทีของวัน)

**19) ข้อมูลย้อนหลัง (1777–1981)** — `initHistoryLog`, `accumulateHistorySample`, `finalizeHistoryInterval`, `processHistoryUpload`, `applyHistoryAck` (ดูหัวข้อ "ข้อมูลย้อนหลังตอนเน็ตหลุด")

**20) จอ OLED (1983–2032)** — `refreshOled()` รวบรวมค่าจาก `config`, `airState`, `powerMeasurements`, Wi-Fi/MQTT และนาฬิกา ใส่ `OledData` แล้วเลือกหน้าจอ SETUP / CONNECTING / NORMAL (ดูหัวข้อ "จอ OLED 1.3 นิ้ว")

### ลำดับงานใน `loop()` ของบอร์ดแอร์

| ลำดับ | งาน | ความถี่ |
|---|---|---|
| 1 | `readPowerMeter()` | ทุก 2 วินาที (`PZEM_READ_INTERVAL_MS`) |
| 2 | `finalizeHistoryInterval()` | ทุกรอบ (ข้างในเช็กว่าถึงรอยต่อ 5 นาทีหรือยัง) |
| 3 | `updateStatusLeds()` | ทุกรอบ |
| 4 | ปิดหน้าต่าง BLE เมื่อหมด 5 นาที | ทุกรอบ |
| 5 | ประกาศ BLE ใหม่เมื่อถึงเวลา / `processPendingConfig()` / รีสตาร์ตเมื่อถึงเวลา | ทุกรอบ ตามเงื่อนไข |
| 6 | ถ้าอยู่โหมดกู้: `attemptWifiRecovery()` แล้ว `return` | ทุก 30 วินาที (ลองต่อ) |
| 7 | ตรวจ Wi-Fi หลุด → `enterBleRecovery` | ทุกรอบ |
| 8 | ตรวจ MQTT หลุด → `connectMqtt()` | ลองใหม่ทุก 3 วินาที |
| 9 | `mqttClient.loop()`, ล้าง `provision-ack`, ส่ง token ทุก 10 วินาที, `applyHistoryAck`, `processHistoryUpload` | ทุกรอบ ตามเงื่อนไข |
| 10 | `processMqttCommand`, `performOtaUpdate`, `processTimers`, `processDailySchedule` | เมื่อมี flag / ทุกรอบ |
| 11 | `publishStatus()` | ทุก 10 วินาที หรือเมื่อ `statusPublishRequested` |
| 12 | `delay(5)` | ท้ายรอบ |

### BLE provisioning (ฝั่งบอร์ด)

ลำดับที่เกิดขึ้นตอนตั้งค่าครั้งแรก (ตารางข้อมูลบน BLE ดูบทโปรโตคอลสื่อสาร):

1. บูตแล้วไม่มี `configured` ใน NVS → `enterBleRecovery("No saved configuration")` → เปิด BLE ชื่อ `RMUTT-AC-XXXXXXXXXXXX`
2. แอปเชื่อมต่อ อ่าน `IDENTITY` (ได้ deviceId, firmwareVersion, configured), อ่าน `WIFI_SCAN` เพื่อให้ผู้ใช้เลือกเครือข่าย
3. แอปเขียน JSON ทาง `CONFIG` เป็นชิ้น ๆ (ห้อง, เลขแอร์, ชื่อ, โปรโตคอล IR, Wi-Fi, MQTT host/port/user/password/topic/tls, token ครั้งเดียว, เวลา dailyOn/dailyOff) ซึ่ง **Backend เป็นผู้ออกค่า MQTT และ token** ให้แอปส่งต่อ
4. บอร์ดทดสอบ Wi-Fi → บันทึก NVS → แจ้ง `config_saved` → รีสตาร์ตใน 1.5 วินาที
5. บูตใหม่ ต่อ Wi-Fi + MQTT แล้วส่ง token ที่ `/provision` ทุก 10 วินาที (retained)
6. Backend ตรวจ token แล้วตอบ `{"activated": true, "token": ...}` ที่ `/provision-ack` บอร์ดลบ `prov_token` ออกจาก NVS (ใช้ได้ครั้งเดียว) และเคลียร์ข้อความ retained ของ `/provision-ack` โดยส่ง payload ว่างแบบ retained

### Wi-Fi และการกู้คืน

- ปกติต่อ Wi-Fi ด้วยค่าใน NVS (รอ 20 วินาที) ถ้าไม่ได้ตอนบูต → BLE recovery พร้อมลองซ้ำเบื้องหลัง
- ระหว่างทำงาน `WiFi.status() != WL_CONNECTED` → `connectWifi()` ครั้งหนึ่ง ถ้าไม่ได้ → BLE recovery เช่นกัน
- `loop()` ยังอ่าน PZEM และเก็บข้อมูลย้อนหลังต่อแม้อยู่ในโหมดกู้ (เพราะ `readPowerMeter()`/`finalizeHistoryInterval()` อยู่ก่อนบล็อกเช็ก Wi-Fi/BLE) แต่ **ไม่รับคำสั่ง MQTT และไม่ยิง IR ตามตัวจับเวลา** ระหว่างนี้

### MQTT ของบอร์ดแอร์ (สิ่งที่เห็นในโค้ด)

| หัวข้อ | โค้ดทำอะไร |
|---|---|
| client id | `"rmutt-" + deviceId` เช่น `rmutt-ESP32-AABBCCDDEEFF` |
| host / port | อ่านจาก NVS (`mqtt_host`, `mqtt_port`) ซึ่งเป็นค่าที่ Backend ส่งมาตอน provisioning จาก `MQTT_DEVICE_URL` ค่าเริ่มต้นคือ `rmutt-energy.tailb292b4.ts.net` พอร์ต 8443 (ผ่าน Funnel) หรือ `<DOMAIN>` พอร์ต 8883 ถ้าตั้งให้ต่อตรง โค้ดไม่ได้ผูกกับพอร์ตใดพอร์ตหนึ่ง |
| ผู้ใช้/รหัสผ่าน | จาก NVS (Backend ออกให้ตอน provision); ถ้า `mqttUsername` ว่างจะเชื่อมแบบไม่ใช้บัญชี |
| TLS | ถ้า `config.mqttTls` เป็น true: `ensureClockSynced()` → `secureClient.setCACert(LETSENCRYPT_CA)` → `setTimeout(15)` → ใช้ `secureClient` |
| LWT (Last Will) | หัวข้อ `<topic>/status`, QoS 1, retained, payload `{"online":false,"deviceId":"..."}` |
| subscribe (QoS 1) | `<topic>/command`, `/provision-ack`, `/schedule-status`, `/history-ack` |
| publish | `/status` (retained), `/state` (retained), `/provision` (retained), `/history` (ไม่ retained) และ คำตอบ unprovision `{"deviceId":...,"online":false,"unprovisioned":true}` ที่ `/status` แบบ **ไม่** retained ตามด้วย payload ว่าง retained ที่ `/status` และ `/state` เพื่อล้างของตัวเอง |
| action ที่รับทาง `/command` | `enter_setup`, `unprovision`, `ota` หรือไม่มี `action` = คำสั่งสถานะแอร์ |
| buffer | `mqttClient.setBufferSize(2048)` (ค่าปกติ 256 ไบต์ ไม่พอสำหรับ JSON ใหญ่) |

`<topic>` คือค่า `config.mqttTopic` ที่ Backend กำหนดตอน provision (README ยกตัวอย่าง `rmutt/ac/ESP32-AABBCCDDEEFF`)

> [!WHY]
> **ทำไมใช้ LWT:** ถ้าบอร์ดไฟดับหรือ Wi-Fi ตัดกะทันหัน บอร์ดเองไม่มีโอกาสบอกใครว่า "ฉันออฟไลน์" Last Will คือข้อความที่ broker เก็บไว้ล่วงหน้าตอนเชื่อมต่อ แล้วส่งให้เองเมื่อตรวจพบว่าการเชื่อมต่อขาด ทำให้ Backend/แอปรู้สถานะออฟไลน์ได้ทันทีโดยไม่ต้องรอ timeout ใด ๆ และ retained ทำให้ผู้ที่เพิ่งสมัครรับข้อมูลได้สถานะล่าสุดเสมอ

### การตัดสินแอร์ทำงาน (running detection) และ LED

| ค่า | ความหมาย |
|---|---|
| `powerWatts >= 30` ติดกัน 3 ครั้ง | `acRunning = true` |
| `powerWatts <= 10` ติดกัน 3 ครั้ง | `acRunning = false` |
| 10 < W < 30 | คงสถานะเดิม และรีเซ็ตตัวนับทั้งสอง |
| อ่าน PZEM พลาดติดกัน 3 ครั้ง | `available = false`, `acRunning = false` |

เพราะอ่านทุก 2 วินาที การยืนยันใช้ประมาณ 6 วินาที

| LED | เงื่อนไขใน `updateStatusLeds()` |
|---|---|
| เขียว (GPIO25) | `acRunning` |
| แดง (GPIO26) | `acRunning && outsideSchedule` (เขียวติดด้วย) |
| เหลือง (GPIO27) | Wi-Fi ต่อแล้ว = ติดค้าง; กำลังต่อ (`wifiConnectionInProgress`) = กระพริบทุก 400 ms; อื่น ๆ = ดับ |
| เขียว/แดงดับทั้งคู่ | แอร์หยุด หรืออ่าน PZEM ไม่ได้ |

### IR: สองเส้นทาง

บอร์ดเลือกเส้นทางจาก `config.airProtocol` (เก็บใน NVS) ถ้าเป็น `SAIJO_DENKI` ไปทางไดรเวอร์ของเรา ถ้าไม่ใช่ใช้ `IRac`

**เส้นทางทั่วไป `IRac` (`sendCurrentIrState`, บรรทัด 1335–1393)** — `strToDecodeType(config.airProtocol)` แปลงชื่อเป็นชนิด แล้วกรอกฟิลด์ใน `irAc.next` (protocol, power, celsius, degrees, mode, fanspeed, swingv, swingh, econo, turbo, quiet, light, clean, filter, sleep, clock) ด้วยการแปลงสตริงจากแอป (`"cool"`, `"low"`, `"top"` ฯลฯ) เป็น enum ของไลบรารี แล้ว `irAc.sendAc()` ไลบรารีจะประกอบเฟรมตามยี่ห้อ (รวม checksum) และจำสถานะเก่าไว้เพื่อให้ยี่ห้อที่ต้องใช้ "toggle" ส่งถูก ฟังก์ชันที่ยี่ห้อนั้นไม่มีจะถูกข้ามเงียบ ๆ

**เส้นทาง Saijo (`sendSaijoCurrentIrState`, บรรทัด 1395–1452)** — ส่งเฉพาะ "ส่วนที่เปลี่ยน" เทียบกับสถานะก่อนหน้า: ถ้า power เปลี่ยน ส่ง `powerOn()`/`powerOff()` **แล้วจบทันที** (ไม่ส่งอย่างอื่นในคำสั่งเดียวกัน) ถ้าแอร์ปิดอยู่ไม่ส่งอะไร ถ้าเปิดอยู่: mode เปลี่ยน → `cool/dry/fanOnly`, อุณหภูมิเปลี่ยน → `setTemperature`, พัดลมเปลี่ยน → `setFan` (low→Level1, medium→Level2, high→Level3, turbo→Turbo, อื่น→Auto), swing เปลี่ยน → `setSwing` (top→Position1 ... bottom→Position5, อื่น→Auto) **ทำไมส่งทีละส่วน:** เฟรมของ Saijo ที่จับมาแต่ละเฟรมเป็น "สถานะเต็มของรีโมต ณ ตอนกดปุ่มนั้น" ไม่ใช่ค่าที่ประกอบแยกฟิลด์ได้ (README ระบุว่ายังไม่รู้โครงบิตและ checksum) จึงทำได้แค่ส่งเฟรมที่จับมา ผลข้างเคียงคือบางเฟรมอาจเปลี่ยนค่าอื่นพร้อมกัน ต้องทดสอบกับแอร์จริง

### ข้อมูลย้อนหลังตอนเน็ตหลุด (offline history)

สรุปลำดับ (รายละเอียดโค้ดอยู่ใน `history_log.h` และหัวข้อเจาะโค้ด):

1. ทุกครั้งที่อ่าน PZEM สำเร็จ `accumulateHistorySample()` สะสมค่าเข้า `historyInterval` (ผลรวม ค่าต่ำสุด/สูงสุด จำนวนครั้ง เวลาที่แอร์ทำงาน) — ต้องรู้เวลาจริงก่อน (`endTs != 0`)
2. `finalizeHistoryInterval()` ตรวจทุกรอบว่าเวลาจริงถึง "รอยต่อ 5 นาที" ที่ตรงกับนาฬิกา (นาที 0, 5, 10, ...) หรือยัง (`nextBoundary = (now / 300 + 1) * 300`) ถ้าถึงและ **(ต่อ MQTT ไม่ได้ หรือยังมีข้อมูลเก่าค้างส่ง)** จึงสร้าง `HistoryRecord` เขียนลง flash ถ้าออนไลน์และไม่มีของค้าง ไม่เขียน เพราะ Backend ได้ค่าสดจาก `/status` อยู่แล้ว
3. พอ MQTT ต่อได้ `processHistoryUpload()` รอ 5–45 วินาทีแบบสุ่ม แล้วส่งทีละ 10 รายการ (เรียงเก่า→ใหม่) ไปที่ `<topic>/history` รอ `<topic>/history-ack` `{"upTo": <ts>}`
4. ได้ ack → `applyHistoryAck()` → `historyLog.acknowledge(upTo)` ลบ sector ที่ส่งครบ → บันทึก `hist_ack` ใน NVS → ส่งชุดถัดไปหลังเว้น 1 วินาที
5. ไม่ได้ ack ภายใน 20 วินาที → ส่งชุดเดิมซ้ำ (Backend ข้ามรายการที่เคยบันทึกแล้วเอง)
6. `/status` มีฟิลด์ `historyPending` เพื่อให้ Backend รู้ว่าไม่ควรบันทึกประวัติจากค่าสดจนกว่าข้อมูลย้อนหลังจะส่งครบ ไม่เช่นนั้นพลังงานช่วงที่เน็ตหลุดจะถูกนับสองครั้ง

### `firmware/rmutt_esp32_air/SaijoDenkiAC.h` และ `SaijoDenkiAC.cpp`

ไดรเวอร์ IR ที่เขียนเองสำหรับแอร์ Saijo Denki โดยจับสัญญาณจากรีโมตจริงด้วยตัวรับ IR แล้วเก็บเฟรม 72 บิต (9 ไบต์) ของแต่ละปุ่มไว้เป็นตาราง

- `.h` ประกาศ `enum class SaijoFan` (`kAuto`, `kLevel1`, `kLevel2`, `kLevel3`, `kTurbo`), `enum class SaijoSwing` (`kAuto`, `kPosition1`–`kPosition5`) และคลาส `SaijoDenkiAC` ที่มีเมธอด `begin()`, `powerOn()`, `powerOff()`, `cool()`, `dry()`, `fanOnly()`, `setTemperature(uint8_t)`, `setFan(SaijoFan)`, `setSwing(SaijoSwing)` (สามตัวหลังคืน `bool` เป็น false ถ้าค่าไม่รองรับ) และเมธอด private `sendState()` กับตัวแปร `IRsend irsend_`
- `.cpp` เก็บค่าเวลาของสัญญาณและตารางเฟรมใน unnamed namespace (ใช้ได้แค่ในไฟล์นี้) รายละเอียดอยู่ในหัวข้อเจาะโค้ด
- เรียกใช้โดย `rmutt_esp32_air.ino` (`saijoAc` ตัวเดียวชื่อ global) ผ่าน `sendSaijoCurrentIrState`
- **ทำไมแยกเป็นไฟล์ของตัวเอง:** ตัดความรู้เรื่องโปรโตคอลที่เฉพาะเจาะจงออกจากตรรกะ MQTT/BLE ใน `.ino` และใส่ไว้ข้าง `.ino` เพื่อไม่ต้องให้ผู้ติดตั้งลงไลบรารีเพิ่ม

### `firmware/rmutt_esp32_air/oled_display.h` (126 บรรทัด)

คลาส `OledDisplay` ตัวเดียว เป็น "ตัวขับจอ" ที่ห่อไลบรารี U8g2 ไว้ หน้าที่: ตรวจว่ามีจอต่ออยู่ไหม (`begin()`), จำกัดจังหวะวาดไม่ให้ถี่เกิน 400 ms (`due()`, `show()`), สั่งวาดใหม่ทันทีเมื่อสถานะแอร์เปลี่ยน (`poke()`), เก็บค่ากำลังไฟย้อนหลัง 64 จุดไว้วาดกราฟ (`pushPower()`), และพักจอเมื่อแอร์ปิดนาน (`saver()`) ค่าที่ปรับได้อยู่ต้นไฟล์เป็น `#define` ที่ห่อด้วย `#ifndef` (ตั้งทับได้จากภายนอก): `OLED_LAYOUT` (1–5, ตอนนี้ 1), `OLED_ROTATE_180` (false), `OLED_CONTRAST` (160), `OLED_SAVER_AFTER_MS` (10 นาที)

- **ใครเรียก:** `rmutt_esp32_air.ino` สร้าง `OledDisplay oledDisplay;` (บรรทัด 158) แล้วเรียก `begin()` ใน `setup()`, `poke()` ใน `publishState()`, `pushPower()` ใน `readPowerMeter()`, `due()`/`show()` ใน `refreshOled()`
- **เรียกใคร:** `U8g2lib.h` และฟังก์ชันวาดใน `oled_ui.h`
- **ทำไมแยกจาก `oled_ui.h`:** ไฟล์นี้รู้เรื่อง "ฮาร์ดแวร์และเวลา" (ขา, millis, ความถี่วาด, พักจอ) ส่วน `oled_ui.h` รู้แค่ "วาดอะไรตรงไหน" แยกแบบนี้จะเปลี่ยนหน้าจอโดยไม่แตะตรรกะจังหวะ หรือย้ายไปจอรุ่นอื่นโดยไม่แตะหน้าจอก็ได้ บอร์ดสายแอร์ใช้สำเนาที่เหมือนกันทุกไบต์

### `firmware/rmutt_esp32_air/oled_ui.h` (382 บรรทัด)

รวมฟังก์ชันวาดทั้งหมดใน `namespace oled` (กันชื่อชนกับโค้ดส่วนอื่น) ทุกฟังก์ชันเป็น `inline` และ **วาดลงบัฟเฟอร์ของ U8g2 อย่างเดียว** ไม่ส่งไปจอเอง (คอมเมนต์บรรทัด 4: ผู้เรียกเป็นคน `clearBuffer()`/`sendBuffer()`)

| ส่วน | บรรทัด | หน้าที่ |
|---|---|---|
| `struct OledData` | 11–43 | "กล่องข้อมูล" ทุกค่าที่จออาจแสดง: ห้อง/เลขแอร์, สถานะที่สั่ง (power, setC, mode, fan, swing, sleep), ค่าที่วัด (roomC, watts, kwh, volts, amps, pf, hz, acRunning, outsideSchedule), เครือข่าย (wifiOk, mqttOk, rssi, ssid, ip, clock, fw, deviceId), ฟิลด์เฉพาะบอร์ดสายแอร์ (`wired`, `busOk`, `compressor`) และ pointer ไปยังกราฟ (`history`, `historyLen`) ทุกฟิลด์มีค่าเริ่มต้น ผู้เรียกกรอกเฉพาะที่มี |
| helper | 48–134 | `modeLabel`, `fanLevel`, `fanLabel`, `wifiBars` (RSSI → 0–4 ขีด), ไอคอน `iconWifi`, `iconTag` (กล่องตัวอักษร ทึบ = เปิด), `iconMode` (เกล็ดหิมะ/หยดน้ำ/ใบพัด/พระอาทิตย์/A ในวงกลม วาดด้วยเส้นและวงกลม ไม่ใช้รูปภาพ), `iconFan` (แท่ง 4 ระดับ), `fmt`/`fmtWatts` (ค่า `NAN` แสดง `--`) |
| `topBar` | 137–152 | แถบบนสูง 9 พิกเซล: ห้อง #เครื่อง ซ้าย, Wi-Fi และ `M` (MQTT) ขวา, (`BUS` ถ้าเป็นบอร์ดสายแอร์), นาฬิกาตรงกลางถ้ามีที่ว่าง |
| แบบ 1 `screenBig` | 157–187 | **ที่ใช้จริง** อุณหภูมิที่ตั้งตัวโต (ฟอนต์ logisoso32) กลางจอเหมือนรีโมตแอร์ |
| แบบ 2 `screenTiles` | 192–221 | 4 ช่อง SET / ROOM / POWER / ENERGY |
| แบบ 3 `screenList` | 226–255 | ตัวหนังสือ 6 บรรทัด |
| แบบ 4 `screenEnergy` | 260–294 | วัตต์ตัวโต + กราฟแท่งย้อนหลัง 64 จุด (จุดละ 5 วินาที ≈ 5 นาที) |
| แบบ 5 `screenPages` | 299–352 | สลับ 3 หน้าทุก 5 วินาที (แอร์ / มิเตอร์ไฟ / เครือข่าย+เวอร์ชัน) |
| หน้าพิเศษ | 357–380 | `screenSetup` (SETUP MODE + ไอคอนบลูทูธ + ชื่อ BLE + เหตุผล), `screenConnecting` (ชื่อ Wi-Fi + จุดวิ่ง 5 จุด), `screenAlert` (สามเหลี่ยมเตือน + 2 บรรทัด ใช้โดยบอร์ดสายแอร์ตอนสายแอร์ไม่ตอบ) |

- **ใครเรียก:** `oled_display.h` เท่านั้น (เลือกแบบด้วย `#if OLED_LAYOUT`)
- **ทำไมมี 5 แบบแต่ใช้แบบเดียว:** ทีมออกแบบไว้ให้เลือกตอนติดตั้ง แต่ `#if` ทำให้คอมไพเลอร์ใส่เฉพาะแบบที่เลือกลงเฟิร์มแวร์ แบบอื่นไม่กินแฟลช (ฟอนต์แต่ละขนาดกินแฟลชหลาย KB) `README_OLED_TH.md` เตือนว่าแบบอื่นอาจทำให้เกินแฟลช ต้องลองคอมไพล์ก่อน

### `firmware/rmutt_esp32_air/build_opt.h` (1 บรรทัด)

ไม่ใช่ไฟล์ C++ แม้นามสกุลจะเป็น `.h` แต่เป็น **รายการแฟล็กคอมไพเลอร์** (`-D...`) ที่ Arduino-ESP32 core อ่านแล้วส่งให้คอมไพเลอร์ตอนคอมไพล์ **ทุกไฟล์** รวมถึงไลบรารี ใช้ปิดไดรเวอร์ I2C/SPI ฮาร์ดแวร์ของ U8g2 และปิดโปรโตคอล IR 28 ยี่ห้อที่แอปไม่มีให้เลือก เพื่อให้เฟิร์มแวร์ที่เพิ่มจอแล้วยังพอดีช่องแอป 1,984 KB อธิบายละเอียดในหัวข้อ "`build_opt.h`: ทำให้เฟิร์มแวร์พอดีแฟลช" บอร์ดสายแอร์มี `build_opt.h` ของตัวเองที่สั้นกว่า (มีแค่ `-DU8X8_NO_HW_I2C -DU8X8_NO_HW_SPI` เพราะไม่มี IRremoteESP8266 ให้ปิด)

### `firmware/rmutt_esp32_air/README_OLED_TH.md`

คู่มือภาษาไทยของจอ: ตารางต่อสาย 4 เส้น, หน้าจอแบบ 1 แสดงอะไรบ้าง, ไลบรารีที่ต้องเพิ่ม (U8g2 by olikraus), เหตุผลของ `build_opt.h` พร้อมรายชื่อยี่ห้อ IR ที่ปิด/ที่ยังอยู่, ผลคอมไพล์ (ESP32 core 3.0.7: **2,001,365 ไบต์ (98%)** แม้เพิ่มโค้ดจอ ขนาดรวมยังเล็กกว่าตอนไม่มีจอ 2,007,985 ไบต์ เพราะ `build_opt.h` ปิดยี่ห้อ IR ที่ไม่ใช้) และตารางค่าที่ปรับได้ใน `oled_display.h` หัวไฟล์เขียน "rmutt_esp32_air 2.5.0" (รุ่นที่เพิ่มจอ) โค้ดปัจจุบันคือ 2.5.1

### `firmware/rmutt_esp32_air/history_log.h`

ที่เก็บข้อมูลแบบ ring buffer บนพาร์ติชัน `rmuttlog` เป็นเทมเพลต `HistoryLog<Storage>` ที่ไม่รู้จักฮาร์ดแวร์ ผู้ใช้ส่ง "ตัวเก็บข้อมูล" ที่มีเมธอด `size/read/write/eraseSector` เข้ามา บนบอร์ดจริงคือ `PartitionFlash` ในไฟล์ `.ino` และบนคอมพิวเตอร์คือ `FakeFlash` ใน `tests/history_log_test.cpp` ฟังก์ชันสำคัญ: `HistoryLog::begin/append/nextBatch/acknowledge`, `historyChecksum`, `historyRecordValid`, `historyRecordBlank` รายละเอียดทีละบรรทัดอยู่ในหัวข้อเจาะโค้ด

### `firmware/rmutt_esp32_air/ota_update.h` และ `firmware/rmutt_esp32_occupancy/ota_update.h` (และ `rmutt_esp32_air_wired/ota_update.h`)

สามไฟล์ **เนื้อหาเหมือนกัน** (ตรวจด้วย `diff`; สำเนาของบอร์ดตรวจคนต่างแค่ช่องว่างเกินท้าย `#include <esp_ota_ops.h>` บรรทัด 22 ซึ่งไม่มีผลกับโปรแกรม) ฟังก์ชัน: `otaUrlAllowed(url, host)` ตรวจ URL, `otaPartitionAvailable()` เช็กว่ามีช่องแอปว่าง, `runHttpsOta(url, caCert, currentVersion)` ดาวน์โหลดและเขียน flash เรียกใช้จาก `performOtaUpdate()` ของทุกบอร์ด ทำไมคัดลอกแทนที่จะแชร์ไฟล์: Arduino IDE คอมไพล์เฉพาะไฟล์ในโฟลเดอร์สเก็ตช์ของตัวเอง การแชร์ข้ามโฟลเดอร์ต้องทำเป็นไลบรารีซึ่งยุ่งกับผู้ติดตั้งกว่า (ข้อแลกเปลี่ยนคือถ้าแก้ต้องแก้ทุกสำเนา ตอนนี้มีสามที่)

### `firmware/rmutt_esp32_air/letsencrypt_ca.h` และ `firmware/rmutt_esp32_occupancy/letsencrypt_ca.h` (และ `rmutt_esp32_air_wired/letsencrypt_ca.h`)

ประกาศ `static const char LETSENCRYPT_CA[] PROGMEM = R"EOF(...)EOF";` เป็นข้อความ PEM ของใบรับรองรากสองใบต่อกัน: **ISRG Root X1** (สาย RSA หมดอายุ 2035-06-04) และ **ISRG Root X2** (สาย ECDSA หมดอายุ 2040-09-17) ตามคอมเมนต์หัวไฟล์ ใส่ทั้งสองเพราะ Let's Encrypt ออกใบรับรองได้ทั้งสองสาย ถ้ามีใบเดียวแล้วเซิร์ฟเวอร์เปลี่ยนสาย บอร์ดทุกตัวจะต่อไม่ได้ `PROGMEM` คือเก็บไว้ใน flash ไม่ใช่ RAM `R"EOF(...)EOF"` เป็น raw string literal ของ C++ (ไม่ต้อง escape ขึ้นบรรทัดใหม่) ไฟล์นี้ **สร้างโดยสคริปต์** `update-root-ca.ps1` ห้ามแก้มือ ทุกบอร์ดได้ไฟล์เหมือนกัน (สำเนาในบอร์ดสายแอร์ตรงกับของบอร์ด IR ทุกไบต์) ใบรากชุดนี้ตรวจผ่านทั้งใบ ts.net (Funnel 8443) และใบ DuckDNS (8883) เพราะทั้งคู่ออกโดย Let's Encrypt

### `firmware/rmutt_esp32_air/partitions.csv` และ `firmware/rmutt_esp32_occupancy/partitions.csv`

ตารางพาร์ติชัน flash 4 MB อธิบายทีละบรรทัดในหัวข้อ "ตารางพาร์ติชัน" บอร์ดสายแอร์ใช้สำเนาที่เหมือนของบอร์ด IR ทุกไบต์ (มี `rmuttlog` เพราะเก็บข้อมูลย้อนหลังเหมือนกัน)

### `firmware/rmutt_esp32_occupancy/rmutt_esp32_occupancy.ino` (บอร์ดตรวจจับคน 1,162 บรรทัด, เวอร์ชัน 1.3.3)

โครงสร้างคล้ายบอร์ดแอร์มากเพราะใช้กลไก BLE/Wi-Fi/MQTT/OTA ชุดเดียวกัน (UUID ของ BLE ใช้ชุดเดียวกัน ต่างกันที่ชื่อ `RMUTT-OCC-` และฟิลด์ `deviceType: "occupancy"` ใน IDENTITY) สิ่งที่ต่างหรือเพิ่ม:

| ส่วน | บรรทัด | รายละเอียด |
|---|---|---|
| ค่าคงที่เรดาร์และ LED | 30–62 | `RADAR_RX_PIN=32`, `RADAR_TX_PIN=33`, `RADAR_BAUD=256000`, `GREEN_LED_PIN=25`, `RED_LED_PIN=26`, `LED_BLINK_INTERVAL_MS=400`, `STATIC_ENERGY_THRESHOLD=15`, `FIRST_GATE=0`, `LAST_GATE=8`, `PRESENCE_READ_INTERVAL_MS=250`, `STATUS_INTERVAL_MS=10000`, `RADAR_RETRY_INTERVAL_MS=10000`, `DIAGNOSTIC_INTERVAL_MS=10000`, `RADAR_DATA_TIMEOUT_MS=3000`, `MAX_CONFIG_BYTES=3072` |
| `DeviceConfig` | 80–94 | ไม่มี airNumber/airName/protocol/dailyOn/dailyOff |
| NVS | 443–473 | namespace `"rmutt-occ"` คีย์ `configured, room, wifi_ssid, wifi_pass, mqtt_host, mqtt_port, mqtt_user, mqtt_pass, mqtt_tls, mqtt_topic, prov_token` |
| `createDeviceId()` | 418 | รหัส `OCC32-XXXXXXXXXXXX` |
| `initialiseRadar()` | 943–973 | เริ่ม LD2410 และเปิด Engineering mode |
| `updateOccupancy()` | 975–1011 | ตัดสินมีคน/ไม่มีคน (เจาะโค้ด) |
| `captureRadarRawBytes()` | 1043–1053 | นับไบต์ดิบตอนเรดาร์ยังเริ่มไม่ได้ เพื่อแยก "ไม่มีสัญญาณเลย" กับ "baud ผิด" |
| `printDiagnostics()` | 1055–1130 | พิมพ์ `[diag]` ทุก 10 วินาที |
| `publishStatus()` | 1013–1039 | ส่ง `/status` retained |
| `connectMqtt()` | 772–826 | client id `"rmutt-occ-" + deviceId`; LWT payload `{"online":false,"deviceId":...,"radarAvailable":false,"occupied":false}`; subscribe แค่ `/command` และ `/provision-ack` |
| `mqttCallback()` | 828–877 | จัดการ `provision-ack`, `enter_setup`, `unprovision` (บรรทัด 853–864 ตั้งธง `unprovisionRequested`), `ota` (ไม่มี `schedule-status`/`history-ack`) |
| `unprovisionAndRestart()` | 884–912 | ตอบ Backend, ล้าง retained `/status`, ล้าง NVS namespace `"rmutt-occ"` แล้วรีบูต เรียกจาก `loop()` บรรทัด 413 |
| `updateStatusLeds()` | 1149–1162 | ไฟเขียวบอกการเชื่อมต่อ ไฟแดงบอกมีคน เรียกจาก `loop()` และจากลูปรอ Wi-Fi/NTP |

ในโหมดต่อ Wi-Fi `connectWifiCredentials()` ของบอร์ดนี้เรียก `radar.read()` ระหว่างรอ (บรรทัด 733) เพื่อไม่ให้ buffer UART ของเรดาร์ล้นขณะรอ Wi-Fi นาน

บอร์ดนี้ **ไม่อ่านค่าไฟ ไม่ยิง IR ไม่เก็บข้อมูลย้อนหลัง** (มี LED สองดวง) `loop()` ของบอร์ดนี้: ลองเริ่มเรดาร์ใหม่ทุก 10 วินาทีถ้ายังไม่พร้อม, `radar.read()` ถ้า background task ไม่ได้ทำงาน, พิมพ์ diag ทุก 10 วินาที, `updateOccupancy()` ทุก 250 ms, `updateStatusLeds()` ทุกรอบ, จากนั้นงาน BLE/Wi-Fi/MQTT เหมือนบอร์ดแอร์ และ `publishStatus()` เมื่อผลเปลี่ยนหรือครบ 10 วินาที

### `firmware/rmutt_esp32_air_wired/` (เฟิร์มแวร์ตัวที่สาม: บอร์ดแอร์สายแอร์ Daikin SLM8)

**คืออะไร:** เฟิร์มแวร์บอร์ดแอร์อีกรุ่นที่ใช้ **แทนรีโมตติดผนังของแอร์ Daikin** ที่ถอดออก ESP32 ต่อกับสายรีโมตผนังโดยตรง แล้วส่งเฟรมคำสั่งตามโปรโตคอลที่ทีมถอดรหัสเอง (เรียกว่า SLM8 ตามรุ่นรีโมต) ทุก 1 วินาที และอ่านเฟรมสถานะที่แอร์ตอบกลับ เวอร์ชันในโค้ดคือ **`2.5.2-slm8`** (บรรทัด 78)

**ต่างจากบอร์ด IR อย่างไร (สรุป):**

| เรื่อง | บอร์ด IR (`rmutt_esp32_air`) | บอร์ดสายแอร์ (`rmutt_esp32_air_wired`) |
|---|---|---|
| ช่องทางสั่งแอร์ | ยิง IR ครั้งเดียว ไม่มีคำตอบ | ส่งเฟรมเข้าสายทุก 1 วินาทีใน FreeRTOS task แยก (`wired_bus.h` สร้าง task `slm8bus` priority 3 บน core 1) และได้สถานะตอบกลับ |
| รู้สถานะจริงของแอร์ | ต้องเดาจาก PZEM | รู้จากสาย: สายตอบไหม (`busOk`), คอมเพรสเซอร์ทำงานไหม (`compressor`) |
| ยี่ห้อ/โปรโตคอล | ผู้ใช้เลือก (IRac หรือ `SAIJO_DENKI`) | ตายตัว `DAIKIN_WIRED` (บรรทัด 82) แอปแสดง "Daikin · สายแอร์" |
| BLE IDENTITY | `"controlType":"ir"` | `"controlType":"wired"` (ค่าคงที่ `CONTROL_TYPE` บรรทัด 80) |
| `/status` | ไม่มี `controlMode` | มี `"controlMode":"wired"` (บรรทัด 1458) ให้ Backend แก้โปรโตคอลในฐานข้อมูลเป็น `DAIKIN_WIRED` เองถ้ายังเป็นยี่ห้อ IR |
| เซนเซอร์เพิ่ม | — | DHT11 (GPIO4) วัดอุณหภูมิห้องส่งต่อให้แอร์ และแสดง `RM xx°` บนจอ |
| จอ OLED | หน้า NORMAL/SETUP/CONNECTING | เหมือนกัน + หน้า ALERT "AIRCON BUS / No reply from unit" เมื่อสายไม่ตอบ และป้าย `BUS`, `COMP ON` |
| ไลบรารี | IRremoteESP8266 2.9.0 | ไม่ใช้ IRremoteESP8266 ใช้ DHT sensor library (Adafruit) แทน |

**ไฟล์ในโฟลเดอร์:** ไฟล์ที่ **คัดลอกมาเหมือนบอร์ด IR ทุกไบต์** (ตรวจด้วย `cmp`) คือ `oled_display.h`, `oled_ui.h`, `history_log.h`, `ota_update.h`, `letsencrypt_ca.h`, `partitions.csv` ไฟล์ที่ **มีเฉพาะบอร์ดนี้** คือ `rmutt_esp32_air_wired.ino` (2,031 บรรทัด แตกมาจาก `.ino` ของบอร์ด IR จึงมี BLE/MQTT/PZEM/LED/OTA/ข้อมูลย้อนหลัง/unprovision ชุดเดียวกัน), `DaikinSLM8.h` (321 บรรทัด: ประกอบ/ถอดเฟรม SLM8), `wired_bus.h` (102 บรรทัด: task + mutex), `README_WIRED_TH.md` ส่วน `build_opt.h` มีแต่ไม่เหมือนกัน (ปิดแค่ I2C/SPI ฮาร์ดแวร์)

**ทำไมทำเป็นสเก็ตช์แยก ไม่ใส่ `#if` ในไฟล์เดียว:** สองรุ่นต่างกันทั้งไลบรารี (IR กับ DHT) ขา (GPIO17 กับ GPIO33/34/35/4) และวิธีส่งคำสั่ง (ครั้งเดียว กับส่งซ้ำทุกวินาทีใน task แยก) ถ้ารวมไฟล์เดียวจะมี `#if` กระจายทั่ว 2,000 บรรทัด อ่านยากและเสี่ยงทำบอร์ด IR ที่ใช้งานอยู่พัง ข้อแลกเปลี่ยนคือแก้ส่วนร่วม (เช่น unprovision) ต้องแก้สองที่ ซึ่งเกิดขึ้นจริงในคอมมิต `1f09946`

> [!NOTE]
> บทนี้อธิบายเฉพาะว่าบอร์ดสายแอร์ "อยู่ตรงไหนในชุดเฟิร์มแวร์" และใช้ส่วนร่วมอะไรบ้าง รายละเอียดโปรโตคอล SLM8 (จังหวะพัลส์ ความหมายแต่ละไบต์ checksum), วงจรต่อสาย, `DaikinSLM8.h`, `wired_bus.h` และการทำงานของ task แยก อยู่ใน **บท 19 (โปรโตคอลสายแอร์ Daikin SLM8)**

### `firmware/reset/reset.ino`

สเก็ตช์สั้น ๆ (35 บรรทัด) สำหรับ factory reset: `nvs_flash_erase()` ล้าง NVS ทั้งหมด, `WiFi.disconnect(true, true)` ลบ Wi-Fi ที่จำไว้ (ทั้ง `wifioff` และ `eraseap` เป็น true), `nvs_flash_init()` เริ่ม NVS ใหม่ `loop()` ว่าง ใช้กับบอร์ดที่ออฟไลน์หรือไม่ตอบ (ถ้าบอร์ดออนไลน์อยู่ การกดลบอุปกรณ์ในแอปจะสั่ง `unprovision` ให้บอร์ดล้างตัวเองได้โดยไม่ต้องเสียบสาย) **ไม่แตะพาร์ติชัน `rmuttlog`** (ข้อมูลย้อนหลังในนั้นยังอยู่ แต่ `hist_ack` ใน NVS หายไป ทำให้ `ackedTs = 0`)

### `firmware/ld2410_pinscan/ld2410_pinscan.ino`

เครื่องมือวินิจฉัยเมื่อเรดาร์ไม่ส่งข้อมูลเลย (0 ไบต์) ดูรายละเอียดหัวข้อ "เครื่องมือ: `ld2410_pinscan` และ `reset`"

### `firmware/tests/history_log_test.cpp`

โปรแกรม C++ ธรรมดา (มี `main`) ทดสอบ `history_log.h` บนคอมพิวเตอร์ ดูหัวข้อ "ทดสอบบนคอมพิวเตอร์"

### `firmware/update-root-ca.ps1`

PowerShell สร้าง `letsencrypt_ca.h` ให้ทั้งสองบอร์ด: รับพารามิเตอร์ `-Urls` (ค่าเริ่มต้น `https://letsencrypt.org/certs/isrgrootx1.pem` และ `.../isrg-root-x2.pem`) ดาวน์โหลดด้วย `Invoke-WebRequest` ตรวจว่ามี `-----BEGIN CERTIFICATE-----` จริง รวมเป็นข้อความเดียว สร้างเนื้อหา header (`#pragma once` + `static const char LETSENCRYPT_CA[] PROGMEM = R"EOF(...)EOF";`) แล้วเขียนทับใน `rmutt_esp32_air/` และ `rmutt_esp32_occupancy/` (เขียนเป็น UTF-8 ไม่มี BOM, ใช้ LF) **ข้อสังเกต:** รายการโฟลเดอร์ปลายทางในสคริปต์ (บรรทัด 19–20) ยังไม่มี `rmutt_esp32_air_wired/` ถ้ารันสคริปต์ต้องคัดลอก `letsencrypt_ca.h` ไปโฟลเดอร์บอร์ดสายแอร์เองด้วย ใช้เมื่อเซิร์ฟเวอร์เปลี่ยนผู้ออกใบรับรอง (ส่ง `-Urls` เป็นใบรากของผู้ออกใหม่) หลังรันต้องอัปโหลดเฟิร์มแวร์ใหม่ `$ErrorActionPreference = 'Stop'` ทำให้สคริปต์หยุดทันทีเมื่อมีข้อผิดพลาด

### `firmware/README.md`

คู่มือรวม: รายการไลบรารี ขา การตั้งค่า (setup flow) การกู้ Wi-Fi ตัวอย่าง log การต่อสายเรดาร์ ตารางรหัส MQTT state ของ PubSubClient (`-4` timeout, `-2` เชื่อมไม่ได้, `4` รหัสผิด, `5` ไม่ได้รับอนุญาต) และคำอธิบาย `[diag]` ย่อหน้าต้นไฟล์บอกว่ามีบอร์ดแอร์ **สองรุ่น** (`rmutt_esp32_air` ควบคุมด้วย IR และ `rmutt_esp32_air_wired` ควบคุมผ่านสายรีโมตผนัง Daikin, แอปแสดงยี่ห้อ **Daikin · Wired** `DAIKIN_WIRED`), บอกว่าทั้งสองรุ่นต้องใช้ไลบรารี **U8g2** สำหรับจอ OLED (รุ่นสายแอร์ใช้ DHT sensor library เพิ่มและไม่ใช้ IRremoteESP8266) และเตือนว่า **ห้ามลบ `build_opt.h`** ไม่เช่นนั้นสเก็ตช์ IR จะใหญ่เกินแฟลช ส่วน Pins เป็นตารางเทียบสองบอร์ด (รวม GPIO21/22 ของจอ และ GPIO33/35/34/4 ของบอร์ดสายแอร์) พร้อมหมายเหตุว่าจอ VCC → 3V3, GND → GND, ไม่มีจอก็ทำงานได้ (Serial พิมพ์ `OLED: not found on GPIO21/22 (display disabled)`) ใช้ประกอบบทนี้ได้ แต่ตารางขายังเขียนว่าบอร์ดสายแอร์ใช้ PZEM 16/18 และ LED เหลือง 27 เหมือนบอร์ด IR ซึ่งไม่ตรงโค้ด (โค้ดคือ 18/14 และ 23)

## บอร์ดตรวจจับคน: การอ่านเรดาร์และการตัดสินใจ

### ลำดับตั้งแต่บูตถึงส่งสถานะ

1. `setup()` เปิด `radarSerial.begin(256000, SERIAL_8N1, 32, 33)` แล้ว `initialiseRadar()`: เรียก `radar.begin(radarSerial)` (คืน true เมื่อเรดาร์ตอบ) แล้ว `radar.requestStartEngineeringMode()` สั่งให้เรดาร์ส่งพลังงานรายเกต และ `radar.autoReadTask()` ให้ไลบรารีสร้าง task พื้นหลังอ่าน UART ต่อเนื่อง (ถ้าสร้างไม่ได้ ใช้ `radar.read()` ในลูปแทน)
2. ถ้าเรดาร์ไม่ตอบ จะพิมพ์ข้อความครั้งเดียว (`radarFailureReported`) และ `loop()` ลองใหม่ทุก 10 วินาที (`RADAR_RETRY_INTERVAL_MS`) โดยไม่ต้องรีบูต ระหว่างนั้น `captureRadarRawBytes()` นับไบต์ที่เข้ามาเพื่อให้ `[diag]` บอกได้ว่าปัญหาคือสายหรือ baud
3. ทุก 250 ms (`PRESENCE_READ_INTERVAL_MS`) `updateOccupancy()` ทำงาน (เจาะโค้ดด้านล่าง)
4. ถ้าผล `occupied` หรือ `radarAvailable` เปลี่ยน ตั้ง `statusPublishRequested = true` แล้ว `loop()` ส่ง `/status` ทันที มิฉะนั้นส่งซ้ำทุก 10 วินาที

### กฎตัดสินใจ

```text
radarAvailable = เรดาร์เริ่มสำเร็จ + เปิด Engineering mode แล้ว + ได้เฟรมใหม่ภายใน 3 วินาที
occupied       = radarAvailable AND (มีเกตใดใน 0..8 ที่ stationaryEnergy > 15)
```

- **เกณฑ์:** `STATIC_ENERGY_THRESHOLD = 15` (มากกว่า 15 เท่านั้น ค่าเท่ากับ 15 = ว่าง) เกณฑ์ยิ่งต่ำยิ่งไว จับคนนั่งนิ่งที่สัญญาณอ่อนได้มากขึ้น แต่ก็มีโอกาสนับสิ่งที่ไม่ใช่คน (เช่นพัดลมหรือม่านที่ขยับ) เป็นคนมากขึ้น ค่านี้เป็นค่าคงที่ในเฟิร์มแวร์ ค่า `staticThreshold` ที่ Backend ส่งมาตอนตั้งค่าบอร์ดไม่ได้ใช้ และ Backend/แอปแสดงเป็น 25 ซึ่งไม่ตรงกับบอร์ด
- **เกต:** 0 ถึง 8 (`FIRST_GATE`, `LAST_GATE`) ใช้เฉพาะ static energy ส่วน moving energy ระยะเป้าหมาย และค่าอื่นของ LD2410 ถูกทิ้งหมด
- **ไม่มี hold time/ดีบาวซ์ในเฟิร์มแวร์:** ผลเปลี่ยนตามเฟรมล่าสุดทันที ไม่มีการหน่วง "ยังถือว่ามีคนอีก N นาที" ในบอร์ดนี้ การหน่วงก่อนสั่งปิดแอร์ไปอยู่ฝั่ง Backend (ดูบทระบบปิดแอร์อัตโนมัติ)
- **หมดเวลาข้อมูล:** `RADAR_DATA_TIMEOUT_MS = 3000` เรดาร์ส่งราว 10 เฟรมต่อวินาที (ตาม README) ถ้าเงียบ 3 วินาทีถือว่าเรดาร์เสีย → `radarAvailable = false` → `occupied = false` และแอปแสดง "Sensor unavailable" แทน "ว่าง"

> [!WHY]
> **ทำไม availability ต้องใช้เวลา ไม่ใช้ `engineeringRetrieved()` ตรง ๆ:** ฟังก์ชันนี้คืน true "ครั้งเดียวต่อหนึ่งเฟรม" แล้วล้างธงของมันเอง ถ้าใช้เป็นเงื่อนไข "พร้อมใช้งาน" สถานะจะกระพริบระหว่างพร้อม/ไม่พร้อมหลายครั้งต่อนาที และทุกครั้งที่กระพริบมีการ publish retained ทำให้แอปสลับไปมา เวอร์ชันนี้จำเวลา `lastRadarDataAt` และผลล่าสุด `lastRadarDetected` ไว้แทน และไม่เรียกฟังก์ชันนั้นในโค้ดวินิจฉัย (`printDiagnostics` มีคอมเมนต์เตือนไว้)

### สิ่งที่ส่งออกไป

`publishStatus()` ส่ง JSON (retained) ไปที่ `<topic>/status`:

```json
{"online":true,"deviceId":"OCC32-AABBCCDDEEFF","firmwareVersion":"1.3.3",
 "roomNumber":"16203","radarAvailable":true,"occupied":true,"staticThreshold":15}
```

ถ้าเพิ่งพยายามอัปเดต OTA ไม่สำเร็จจะมี `"otaError"` เพิ่ม ไม่มีค่าเรดาร์ดิบรายเกตใน payload (ส่งเฉพาะ boolean) ซึ่งช่วยลดทราฟฟิกและความเป็นส่วนตัวของข้อมูล ส่วน LWT ตอนบอร์ดหลุดคือ `{"online":false,"deviceId":...,"radarAvailable":false,"occupied":false}`

### Provisioning และ OTA

ใช้โค้ดเดียวกับบอร์ดแอร์ทุกขั้น (BLE `RMUTT-OCC-...`, ส่ง token ที่ `/provision` ทุก 10 วินาที, รับ `/provision-ack`, รับ `enter_setup`, `unprovision` และ `ota` ที่ `/command`) ที่ต่างคือไม่ต้องมีเลขแอร์/โปรโตคอล IR/เวลาเปิดปิด ในการตรวจ config ใช้เงื่อนไขน้อยกว่า (ไม่ตรวจ `airNumber`, `airProtocol`) และ Wi-Fi-only mode ล็อกห้องและ MQTT เหมือนกัน

## ตารางพาร์ติชัน (`partitions.csv`) ทีละบรรทัด

รูปแบบคอลัมน์: `Name, Type, SubType, Offset, Size, Flags` (flash 4 MB = `0x400000`)

**ไฟล์ `firmware/rmutt_esp32_air/partitions.csv`**

```text:1
# RMUTT Save Energy (A/C board) - 4MB flash, two 1.9MB app slots (OTA capable)
# Arduino IDE uses this file automatically because it sits next to the .ino.
# Select Tools > Partition Scheme > "No FS 4MB (2MB APP x2)" (size limit check).
# nvs is at the same offset as the stock layouts, so saved settings survive.
# rmuttlog (64KB) keeps energy records while the board is offline (~7 days).
# It replaces the crash-dump partition; the board only logs a notice about it.
# Name,   Type, SubType, Offset,  Size, Flags
nvs,      data, nvs,     0x9000,  0x5000,
otadata,  data, ota,     0xe000,  0x2000,
app0,     app,  ota_0,   0x10000, 0x1F0000,
app1,     app,  ota_1,   0x200000,0x1F0000,
rmuttlog, data, 0x40,    0x3F0000,0x10000,
```

| บรรทัด | พาร์ติชัน | offset → จบ | ขนาด | หน้าที่ |
|---|---|---|---|---|
| 1–6 | (คอมเมนต์ขึ้นต้น `#`) | | | บอกว่าไฟล์ใช้กับ Arduino IDE อัตโนมัติ, ให้เลือก Partition Scheme "No FS 4MB (2MB APP x2)" เพื่อให้ IDE ตรวจขนาดโปรแกรม, `nvs` อยู่ offset เดียวกับตารางมาตรฐานจึง **ค่าที่บันทึกไว้ไม่หายเมื่ออัปเดต**, `rmuttlog` 64 KB เก็บ ~7 วัน และมันมาแทนพาร์ติชัน crash-dump |
| 8 | `nvs` (data/nvs) | `0x9000` → `0xE000` | `0x5000` = 20 KB | ที่เก็บ `Preferences` ทั้งหมด |
| 9 | `otadata` (data/ota) | `0xE000` → `0x10000` | `0x2000` = 8 KB | บันทึกว่าบูตจาก `app0` หรือ `app1` — OTA แก้ที่นี่เพื่อสลับช่อง |
| 10 | `app0` (app/ota_0) | `0x10000` → `0x200000` | `0x1F0000` = 1,984 KB | ช่องแอปที่ 1 |
| 11 | `app1` (app/ota_1) | `0x200000` → `0x3F0000` | `0x1F0000` = 1,984 KB | ช่องแอปที่ 2 (OTA เขียนลงช่องที่ไม่ได้ใช้อยู่) |
| 12 | `rmuttlog` (data/**0x40**) | `0x3F0000` → `0x400000` | `0x10000` = 64 KB = 16 sector | ring buffer ข้อมูลย้อนหลัง subtype `0x40` เป็นเลขที่โปรเจคกำหนดเอง (ช่วง custom ของ data) ตรงกับ `HISTORY_PARTITION_SUBTYPE` ใน `.ino` |

**ไฟล์ `firmware/rmutt_esp32_occupancy/partitions.csv`**

```text:1
# RMUTT Save Energy - 4MB flash, two 1.9MB app slots (OTA capable)
# Arduino IDE uses this file automatically because it sits next to the .ino.
# Select Tools > Partition Scheme > "No FS 4MB (2MB APP x2)" (size limit check).
# nvs is at the same offset as the stock layouts, so saved settings survive.
# Name,   Type, SubType, Offset,  Size, Flags
nvs,      data, nvs,     0x9000,  0x5000,
otadata,  data, ota,     0xe000,  0x2000,
app0,     app,  ota_0,   0x10000, 0x1F0000,
app1,     app,  ota_1,   0x200000,0x1F0000,
coredump, data, coredump,0x3F0000,0x10000,
```

เหมือนกันทุกบรรทัดยกเว้นบรรทัดสุดท้าย (บรรทัด 10): `coredump` (data/coredump) ที่ `0x3F0000` ขนาด `0x10000` เก็บ core dump (บันทึกตอนโปรแกรมแครช ไว้วิเคราะห์) ตามตารางมาตรฐาน บอร์ดตรวจจับคนไม่เก็บข้อมูลย้อนหลังจึงไม่ต้องใช้ `rmuttlog`

> [!WHY]
> **ทำไมต้องมีช่องแอปสองช่อง:** OTA เขียนเฟิร์มแวร์ใหม่ลงช่อง "ที่ยังไม่ได้ใช้" ขณะที่ช่องปัจจุบันยังรันอยู่ ถ้าไฟดับหรือไฟล์เสียระหว่างดาวน์โหลด ช่องเก่ายังสมบูรณ์และบอร์ดบูตต่อได้ ถ้ามีช่องเดียว (แบบ factory) การอัปเดตที่พังจะทำให้บอร์ดกลายเป็นอิฐ ต้องเสียบสายแฟลชใหม่ ราคาที่จ่ายคือโปรแกรมใหญ่ได้แค่ ~1.9 MB ต่อช่อง (`README_WIFI_RECOVERY_TH.txt` ที่รากโปรเจคซึ่งเก่ากว่าโค้ดเขียนให้ใช้ Huge APP ซึ่งไม่มีช่อง OTA ตารางของโปรเจคปัจจุบันใช้ `partitions.csv` ข้างสเก็ตช์แทน)

> [!WARN]
> บอร์ดที่เพิ่งได้เฟิร์มแวร์ 2.x ผ่าน USB ต้อง "แฟลชตารางพาร์ติชันใหม่ผ่าน USB ครั้งหนึ่ง" (OTA เปลี่ยนตารางพาร์ติชันไม่ได้) ถ้าไม่มีช่องแอปที่สอง `runHttpsOta` จะคืนข้อความ `no_ota_partition: flash partitions.csv via USB once` และถ้าไม่มี `rmuttlog` บอร์ดแอร์จะพิมพ์ `Offline history disabled: partition rmuttlog not found` แล้วทำงานต่อโดยไม่เก็บประวัติ

## ข้อมูลย้อนหลังตอนเน็ตหลุด: `history_log.h` ในภาพรวม

### รูปแบบข้อมูล: `HistoryRecord` 32 ไบต์

โครงสร้างถูกกำหนดด้วย `#pragma pack(push, 1)` (ห้ามคอมไพเลอร์เว้นช่องว่างจัดแนว) และมี `static_assert(sizeof(HistoryRecord) == 32)` ป้องกันขนาดเพี้ยน ค่าทศนิยมเก็บเป็นจำนวนเต็ม × สเกล เพื่อประหยัดที่

| ออฟเซต | ฟิลด์ | ชนิด | ความหมาย |
|---|---|---|---|
| 0 | `ts` | uint32 | epoch วินาทีของ **ปลาย** ช่วง (ช่วง = ts−300 ถึง ts) |
| 4 | `energyKwh` | float | เลขมิเตอร์สะสมของ PZEM ตอนปลายช่วง |
| 8 / 10 / 12 | `voltageAvg10`, `voltageMin10`, `voltageMax10` | uint16 | แรงดัน × 10 (230.5 V → 2305) |
| 14 / 16 | `currentAvg1000`, `currentMax1000` | uint16 | กระแส × 1000 (mA) |
| 18 / 20 / 22 | `powerAvg10`, `powerMin10`, `powerMax10` | uint16 | กำลัง × 10 (สูงสุด 6,553.5 W) |
| 24 | `powerFactor100` | uint8 | PF × 100 |
| 25 | `frequencyOffset10` | uint8 | (Hz − 40) × 10 |
| 26 | `runtimeSeconds` | uint16 | วินาทีที่แอร์ทำงานในช่วงนี้ (ไม่เกิน 300) |
| 28 | `samples` | uint8 | จำนวนครั้งที่อ่าน PZEM ในช่วง (ไม่เกิน 255) |
| 29 | `flags` | uint8 | bit0 = แอร์ทำงานตอนปลายช่วง |
| 30 | `magic` | uint8 | `0xA5` ตัวบอกว่าเป็นรายการของเรา |
| 31 | `checksum` | uint8 | ตรวจความสมบูรณ์ |

ขนาดพาร์ติชัน 64 KB ÷ 4096 = 16 sector, 4096 ÷ 32 = 128 รายการต่อ sector → 2,048 รายการ × 5 นาที ≈ 7.1 วัน ถ้าเต็มจะทับ sector ที่เก่าที่สุดทีละ sector (128 รายการ)

> [!WHY]
> **ทำไมต้องเขียนเป็น sector และ "ลบก่อนเขียน":** flash แบบ NOR เขียนได้เฉพาะเปลี่ยนบิตจาก 1 เป็น 0 จะคืนเป็น 1 ได้ต้อง "erase" ทั้ง sector (4096 ไบต์) ซึ่งช้าและมีอายุการลบจำกัด (หลักแสนครั้ง) การเขียนรายการ 32 ไบต์ต่อกันไปเรื่อย ๆ แล้วลบทีละ sector ตอนที่ส่งครบ/ต้องทับ ทำให้ลบน้อยครั้งและกระจายการสึกหรอทั่วพาร์ติชัน แทนที่จะลบทุกครั้งที่เขียนหนึ่งรายการ

## จอ OLED 1.3 นิ้ว

ตั้งแต่บอร์ด IR 2.5.0 (และบอร์ดสายแอร์) บอร์ดแอร์มีจอเล็ก ๆ ให้คนที่อยู่หน้าบอร์ด (ช่างหรือเจ้าหน้าที่) เห็นสถานะได้ทันทีโดยไม่ต้องเปิดแอปหรือเสียบสาย USB ดู Serial Monitor เช่น บอร์ดอยู่ห้องไหน แอร์ถูกสั่งเป็นกี่องศา Wi-Fi/MQTT ต่ออยู่ไหม กินไฟกี่วัตต์ หรือกำลังรอตั้งค่าผ่านบลูทูธด้วยชื่ออะไร

### ฮาร์ดแวร์และไลบรารี

| เรื่อง | ค่า | เหตุผล |
|---|---|---|
| จอ | OLED 1.3" 128×64 พิกเซล ขาวดำ ชิป **SH1106** ต่อแบบ I2C | ราคาถูก มีขายทั่วไป อ่านได้ในที่มืดและมุมกว้าง ไม่มีไฟหลังจอ |
| ต่อสาย | VCC → 3V3, GND → GND, SDA → **GPIO21**, SCL → **GPIO22** | 21/22 เป็นขา I2C มาตรฐานของ ESP32 และว่างอยู่ในบอร์ดนี้ |
| ไลบรารี | **U8g2** by olikraus | รองรับ SH1106 มีฟอนต์ในตัวหลายขนาด และมีโหมด "full buffer" (`_F_`) วาดในหน่วยความจำก่อนแล้วส่งทีเดียว |
| คลาส U8g2 ที่ใช้ | `U8G2_SH1106_128X64_NONAME_F_SW_I2C` | `F` = full buffer 1,024 ไบต์ (128×64÷8), `SW_I2C` = I2C แบบซอฟต์แวร์ (bit-bang) |
| ไม่มีจอ | ทำงานต่อปกติ | `begin()` ตรวจไม่เจอจะปิดส่วนจอเอง แฟลชเฟิร์มแวร์เดียวกันให้บอร์ดที่มีและไม่มีจอได้ |

> [!WHY]
> **ทำไม SH1106 ไม่ใช่ SSD1306 ที่นิยมกว่า:** จอ 1.3 นิ้วส่วนใหญ่ในตลาดใช้ SH1106 (จอ 0.96 นิ้วมักเป็น SSD1306) สองชิปสั่งงานต่างกันเล็กน้อย (SH1106 มีหน่วยความจำ 132 คอลัมน์) ถ้าเลือกคลาสผิดภาพจะเลื่อนหรือมีขยะที่ขอบ U8g2 แยกคลาสไว้ให้ จึงต้องระบุชื่อชิปให้ตรงกับจอจริง

### ภาพรวมการไหลของข้อมูลไปที่จอ

```text
setup()        ── oledDisplay.begin()              ตรวจว่ามีจอ + ตั้งค่าจอ
readPowerMeter ── oledDisplay.pushPower(W)         เก็บกราฟ (จริงทุก 5 วินาที)
publishState   ── oledDisplay.poke()               สถานะแอร์เปลี่ยน → วาดใหม่รอบถัดไปทันที
loop() ทุกรอบ ── updateStatusLeds() ── refreshOled()
                       │ due()? ไม่ถึงเวลา → return ทันที (ไม่เตรียมข้อมูล)
                       ▼ ถึงเวลา (ทุก 400 ms หรือหลัง poke)
                 กรอก OledData จาก config / airState / powerMeasurements / WiFi / mqtt / นาฬิกา
                       ▼
                 show(SETUP | CONNECTING | NORMAL) ── clearBuffer → oled::screenXxx() → sendBuffer
```

### `begin()`: ตรวจว่ามีจอโดยไม่ทำให้บอร์ดค้าง

**ไฟล์ `firmware/rmutt_esp32_air/oled_display.h` บรรทัด 31–49**

```cpp:31
  bool begin() {
    // ตรวจว่ามีจอ: โมดูลจอมีตัวต้านทาน pull-up ที่ SDA/SCL ถ้าไม่มีจอ ขาจะถูก pull-down ภายในดึงลง
    pinMode(kSda, INPUT_PULLDOWN);
    pinMode(kScl, INPUT_PULLDOWN);
    delay(2);
    present_ = digitalRead(kSda) == HIGH && digitalRead(kScl) == HIGH;
    pinMode(kSda, INPUT);
    pinMode(kScl, INPUT);
    if (!present_) {
      Serial.println("OLED: not found on GPIO21/22 (display disabled)");
      return false;
    }
    u8g2_.begin();
    u8g2_.setDisplayRotation(OLED_ROTATE_180 ? U8G2_R2 : U8G2_R0);
    u8g2_.setContrast(OLED_CONTRAST);
    for (int i = 0; i < kHist; i++) hist_[i] = NAN;
    Serial.printf("OLED: SH1106 128x64 ready, layout %d\n", OLED_LAYOUT);
    return true;
  }
```

| บรรทัด | โค้ด | ความหมาย / เหตุผล |
|---|---|---|
| 33–34 | `pinMode(..., INPUT_PULLDOWN)` | ตั้ง SDA/SCL เป็นขาเข้าและเปิดตัวต้านทาน **ดึงลง** ภายในชิป (อ่อน ~45 kΩ) |
| 35 | `delay(2)` | รอ 2 ms ให้แรงดันที่ขานิ่ง |
| 36 | `present_ = ... HIGH && ... HIGH` | โมดูลจอ I2C มีตัวต้านทาน **ดึงขึ้น** ที่แรงกว่า (มักราว 4.7–10 kΩ) ถ้ามีจอ ขาจะยังอ่านได้ HIGH ทั้งสองขา ถ้าไม่มีจอ pull-down จะดึงลงเป็น LOW |
| 37–38 | `pinMode(..., INPUT)` | ปล่อยขาคืน (ปิด pull-down) ก่อนให้ U8g2 ใช้ |
| 39–42 | `if (!present_) ... return false` | ไม่มีจอ: พิมพ์ log ครั้งเดียวแล้วจบ ทุกฟังก์ชันอื่นเช็ก `present_` ก่อนเสมอ จึงไม่มีการสื่อสาร I2C เลย |
| 43 | `u8g2_.begin()` | ส่งคำสั่งเริ่มต้นไปที่ชิป SH1106 |
| 44 | `setDisplayRotation(... U8G2_R2 : U8G2_R0)` | `R2` = หมุน 180° สำหรับติดจอกลับหัว |
| 45 | `setContrast(OLED_CONTRAST)` | ความสว่าง 160 จาก 255 ไม่สว่างสุด เพื่อถนอมอายุพิกเซล OLED |
| 46 | `hist_[i] = NAN` | ล้างกราฟเป็น "ไม่มีค่า" (`NAN` = not a number) ไม่ใช่ 0 กราฟจึงไม่วาดแท่งช่วงที่ยังไม่มีข้อมูล |

> [!WHY]
> **ทำไมต้องตรวจก่อน แทนที่จะสั่ง `u8g2_.begin()` เลย:** I2C แบบซอฟต์แวร์ของ U8g2 "ส่งอย่างเดียว" ไม่รอคำตอบ (ACK) จากจอ ถ้าไม่มีจอ มันก็ยังเสียเวลาส่งข้อมูลทั้งเฟรมทุก 400 ms ไปเปล่า ๆ การตรวจ pull-up ใช้เวลา 2 ms ครั้งเดียวตอนบูต ทำให้บอร์ดที่ไม่ได้ติดจอไม่เสียเวลา CPU กับจอเลย และไม่ต้องมีเฟิร์มแวร์สองชุด (มีจอ/ไม่มีจอ) ข้อจำกัดคือถ้าเสียบจอทีหลังตอนบอร์ดเปิดอยู่ ต้องรีเซ็ตบอร์ดหนึ่งครั้งจอจึงจะทำงาน

### `pushPower()`, `poke()`, `due()`: จังหวะการวาด

**ไฟล์ `firmware/rmutt_esp32_air/oled_display.h` บรรทัด 52–63**

```cpp:52
  // เก็บค่ากำลังไฟลงกราฟ (ทุก 5 วินาที ไม่ว่าเรียกถี่แค่ไหน)
  void pushPower(float watts) {
    if (millis() - lastHistAt_ < 5000 && lastHistAt_ != 0) return;
    lastHistAt_ = millis();
    memmove(hist_, hist_ + 1, sizeof(float) * (kHist - 1));
    hist_[kHist - 1] = watts;
  }

  // บังคับวาดใหม่รอบถัดไปทันที (เช่น เพิ่งรับคำสั่งจากแอป)
  void poke() { dirty_ = true; }
  // ถึงรอบวาดหรือยัง (ให้ผู้เรียกข้ามการเตรียมข้อมูลได้ถ้ายังไม่ถึง)
  bool due() const { return present_ && (dirty_ || millis() - lastDrawAt_ >= 400); }
```

| บรรทัด | ความหมาย |
|---|---|
| 54 | ตัวจับเวลาแบบไม่บล็อก: ถ้ายังไม่ครบ 5000 ms นับจากครั้งก่อน ให้ทิ้งค่านี้ (`lastHistAt_ != 0` ทำให้ค่าแรกถูกเก็บเสมอ) `readPowerMeter()` เรียกทุก 2 วินาที แต่กราฟเก็บแค่ทุก 5 วินาที |
| 56 | `memmove` เลื่อนข้อมูลทั้งแถวไปทางซ้ายหนึ่งช่อง (ทิ้งค่าเก่าสุด) ใช้ `memmove` ไม่ใช่ `memcpy` เพราะต้นทางกับปลายทางเป็นหน่วยความจำที่ทับกัน |
| 57 | ใส่ค่าใหม่ที่ช่องท้าย ได้กราฟ 64 จุด × 5 วินาที ≈ 5 นาทีล่าสุด (`kHist = 64`) |
| 61 | `poke()` แค่ตั้งธง `dirty_` ไม่วาดเอง การวาดจริงเกิดในรอบ `loop()` ถัดไป |
| 63 | `due()` คืน true เมื่อมีจอ **และ** (มีคน poke หรือผ่านมาแล้ว ≥ 400 ms) |

**ไฟล์ `firmware/rmutt_esp32_air/oled_display.h` บรรทัด 65–88**

```cpp:65
  // เรียกได้ถี่ ๆ  วาดจริงทุก 400 ms หรือเมื่อ poke()
  void show(Screen screen, OledData& d, const char* a = "", const char* b = "", const char* c = "") {
    if (!present_) return;
    const uint32_t now = millis();
    if (!dirty_ && now - lastDrawAt_ < 400) return;
    dirty_ = false;
    lastDrawAt_ = now;

    if (d.power) offSince_ = 0; else if (offSince_ == 0) offSince_ = now;
    d.history = hist_;
    d.historyLen = kHist;

    u8g2_.clearBuffer();
    switch (screen) {
      case SETUP:      oled::screenSetup(u8g2_, a, b); break;
      case CONNECTING: oled::screenConnecting(u8g2_, a, (now / 400) % 5); break;
      case ALERT:      oled::screenAlert(u8g2_, a, b, c); break;
      default:
        if (screen == NORMAL && offSince_ != 0 && now - offSince_ > OLED_SAVER_AFTER_MS) saver(d, now);
        else drawLayout(d, now);
        break;
    }
    u8g2_.sendBuffer();
  }
```

| บรรทัด | ความหมาย / เหตุผล |
|---|---|
| 66 | `a`, `b`, `c` เป็นข้อความเสริมของหน้าพิเศษ (เช่นชื่อ BLE, เหตุผล) มีค่าเริ่มต้น `""` ผู้เรียกจึงไม่ต้องส่งครบทุกตัว `OledData&` เป็น reference (ส่งตัวจริงไม่คัดลอก) |
| 67–71 | ตรวจซ้ำแบบเดียวกับ `due()` (กันผู้เรียกที่ไม่ได้เช็ก `due()` ก่อน) แล้วล้างธงและจดเวลาวาด |
| 73 | จำเวลาที่แอร์เริ่ม "ปิด" (`offSince_`) ถ้าเปิดอยู่ล้างเป็น 0 ใช้ตัดสินโหมดพักจอ |
| 74–75 | ชี้ `OledData` ไปที่กราฟของคลาสนี้ ผู้เรียกไม่ต้องรู้ว่ากราฟเก็บที่ไหน |
| 77 | `clearBuffer()` ล้างบัฟเฟอร์ 1,024 ไบต์ใน RAM (ยังไม่แตะจอ) |
| 78–86 | เลือกหน้าตาม `screen` หน้า CONNECTING ส่ง `(now / 400) % 5` เป็นตำแหน่งจุดที่วิ่ง (เปลี่ยนทุก 400 ms) หน้า NORMAL ถ้าแอร์ปิดนานเกิน 10 นาทีไปที่ `saver()` ไม่งั้นวาดตามแบบที่เลือก |
| 87 | `sendBuffer()` ส่งทั้งบัฟเฟอร์ไปจอครั้งเดียว ภาพจึงเปลี่ยนทั้งจอพร้อมกัน ไม่กระพริบหรือเห็นการวาดทีละส่วน |

> [!WHY]
> **ทำไมวาดทุก 400 ms ไม่วาดทุกรอบ `loop()`:** `loop()` หมุนหลายร้อยครั้งต่อวินาที (มี `delay(5)` ท้ายรอบ) การส่งบัฟเฟอร์ 1 KB ผ่าน I2C แบบซอฟต์แวร์ต้องใช้ CPU ขยับขาเองทุกบิต ใช้เวลาเป็นหลักสิบมิลลิวินาทีต่อเฟรม (ประมาณการ ไม่มีตัวเลขวัดในโค้ด) ถ้าวาดทุกรอบ `loop()` จะแทบไม่มีเวลาเหลือให้ `mqttClient.loop()` รับคำสั่ง ข้อมูลบนจอส่วนใหญ่ (วัตต์อ่านทุก 2 วินาที นาฬิกาเปลี่ยนทุกนาที) ไม่ต้องสดกว่า 0.4 วินาที ส่วนค่าที่ผู้ใช้เพิ่งสั่ง (`publishState()` เรียก `poke()`) ได้วาดทันทีในรอบถัดไป จึงยังรู้สึกว่าจอตอบสนองเร็ว ส่วน `due()` ช่วยให้ `refreshOled()` ข้ามการเตรียมข้อมูล (สร้างสตริง IP, อ่านนาฬิกา) ได้ในรอบที่ยังไม่ถึงเวลา ซึ่งเป็นรอบส่วนใหญ่

### ตัวแปรภายในและ I2C แบบซอฟต์แวร์

**ไฟล์ `firmware/rmutt_esp32_air/oled_display.h` บรรทัด 90–97**

```cpp:90
 private:
  static const int kHist = 64;
  static const int kSda = 21, kScl = 22;
  // I2C แบบซอฟต์แวร์: ไม่ต้องดึงไดรเวอร์ I2C ของ ESP-IDF เข้ามา (ประหยัดแฟลช ~14 KB)
  U8G2_SH1106_128X64_NONAME_F_SW_I2C u8g2_{U8G2_R0, /*clock=*/kScl, /*data=*/kSda, U8X8_PIN_NONE};
  bool present_ = false, dirty_ = true;
  uint32_t lastDrawAt_ = 0, lastHistAt_ = 0, offSince_ = 0;
  float hist_[kHist];
```

| บรรทัด | ความหมาย |
|---|---|
| 91–92 | ค่าคงที่ของคลาส: กราฟ 64 จุด และขา 21/22 (เปลี่ยนขาที่นี่ที่เดียว) |
| 93–94 | สร้างอ็อบเจกต์ U8g2 ด้วย brace initialization `{...}` : หมุน R0, ขา clock = 22, data = 21, ไม่มีขารีเซ็ต (`U8X8_PIN_NONE`) คอมเมนต์ให้เหตุผลว่า I2C แบบซอฟต์แวร์ประหยัดแฟลช ~14 KB เพราะไม่ต้องลากไดรเวอร์ I2C ของ ESP-IDF เข้ามา (ใช้คู่กับ `-DU8X8_NO_HW_I2C` ใน `build_opt.h`) |
| 95 | `dirty_ = true` ตั้งแต่ต้น เฟรมแรกจึงวาดทันทีหลังบูต |
| 96 | เวลาเป็น `uint32_t` เหมือน `millis()` การลบ `now - lastDrawAt_` จึงถูกต้องแม้ `millis()` วนรอบ |
| 97 | กราฟ 64 × 4 ไบต์ = 256 ไบต์ใน RAM |

### หน้าจอแบบ 1 "ตัวเลขใหญ่" (`screenBig`)

**ไฟล์ `firmware/rmutt_esp32_air/oled_ui.h` บรรทัด 157–187**

```cpp:157
inline void screenBig(U8G2& d, const OledData& s) {
  topBar(d, s);
  d.drawHLine(0, 10, 128);
  char b[24];
  if (s.power) {
    iconMode(d, 2, 15, s.mode);
    d.setFont(u8g2_font_5x7_tr);
    d.drawStr(10 - d.getStrWidth(modeLabel(s.mode)) / 2, 41, modeLabel(s.mode));
    d.setFont(u8g2_font_logisoso32_tn);
    snprintf(b, sizeof b, "%d", s.setC);
    int w = d.getStrWidth(b);
    int x = 64 - (w + 8) / 2;
    d.drawStr(x, 47, b);
    degree(d, x + w + 2, 15, 2);
    d.setFont(u8g2_font_helvB08_tr); d.drawStr(x + w + 2, 27, "C");
    iconFan(d, 106, 33, s.fan);
    d.setFont(u8g2_font_5x7_tr);
    d.drawStr(113 - d.getStrWidth(fanLabel(s.fan)) / 2, 41, fanLabel(s.fan));
    if (s.swing) iconTag(d, 103, 51, "SW", true);
    if (s.sleep) iconTag(d, 2, 51, "ZZ", true);
  } else {
    d.setFont(u8g2_font_helvB18_tr);
    d.drawStr(64 - d.getStrWidth("OFF") / 2, 40, "OFF");
  }
  d.drawHLine(0, 53, 128);
  d.setFont(u8g2_font_5x7_tr);
  fmtWatts(b, sizeof b, s.watts); d.drawStr(0, 63, b);
  if (s.outsideSchedule) iconTag(d, 46, 63, "OUT OF CLASS", true);
  else if (s.wired && s.power) { d.drawStr(46, 63, s.compressor ? "COMP ON" : "COMP --"); }
  if (!isnan(s.roomC)) { snprintf(b, sizeof b, "RM %.0f", s.roomC); int w = d.getStrWidth(b); d.drawStr(122 - w, 63, b); degree(d, 123, 57); }
}
```

ผังจอ (128×64) ที่ได้:

```text
y 0-9   │ 16203 #1        14:32      [M] ▂▄▆█ │  แถบบน: ห้อง#เครื่อง · นาฬิกา · MQTT · Wi-Fi
y 10    ├──────────────────────────────────────┤
y 15-47 │ ❄            2 5 °C           ▮▮▯▯ │  ไอคอนโหมด · อุณหภูมิตัวโต · แท่งพัดลม
        │ COOL                             MED │
        │ [ZZ]                            [SW] │  Sleep / ส่าย (แสดงเมื่อเปิด)
y 53    ├──────────────────────────────────────┤
y 63    │ 845 W   [OUT OF CLASS]               │  แถบล่าง: วัตต์ · เตือนนอกเวลาเรียน
```

| บรรทัด | ความหมาย |
|---|---|
| 157 | `U8G2& d` คือตัววาด, `const OledData& s` ข้อมูลแบบอ่านอย่างเดียว (`const` = ฟังก์ชันวาดแก้ข้อมูลไม่ได้) |
| 158–159 | แถบบนร่วม แล้วขีดเส้นแนวนอนที่ y = 10 |
| 160 | บัฟเฟอร์สตริง 24 ไบต์บน stack (ไม่ใช้ `String` เพื่อไม่จอง heap ทุก 400 ms) |
| 161–176 | แอร์เปิด: ไอคอนโหมด 16×16 ที่มุมซ้าย ชื่อโหมดใต้ไอคอน (จัดกลางด้วย `10 - width/2`), อุณหภูมิฟอนต์ `logisoso32_tn` (ตัวเลขสูง 32 พิกเซล; `_tn` = มีแค่ตัวเลข ไฟล์ฟอนต์เล็กลง) จัดกลางจอที่ x = 64, วาดวงกลมเล็กเป็นเครื่องหมายองศาแล้วตามด้วย "C", แท่งพัดลมและชื่อระดับทางขวา, ป้าย `SW` และ `ZZ` เมื่อเปิดส่าย/Sleep |
| 177–180 | แอร์ปิด: ตัว `OFF` ใหญ่กลางจอ |
| 181–183 | เส้นคั่นที่ y = 53 แล้ววัตต์ที่มุมซ้ายล่าง (`fmtWatts`: ไม่มีค่า → `-- W`, ≥ 10,000 W → แสดงเป็น kW) |
| 184 | แอร์ทำงานนอกเวลาเรียน → ป้ายทึบ `OUT OF CLASS` (ตรงกับ LED แดง) |
| 185 | เฉพาะบอร์ดสายแอร์ (`s.wired`): แสดงคอมเพรสเซอร์ `COMP ON`/`COMP --` บอร์ด IR ไม่ตั้ง `wired` จึงไม่เห็นบรรทัดนี้ |
| 186 | อุณหภูมิห้อง `RM xx°` เฉพาะเมื่อมีค่า บอร์ด IR ไม่มีเซนเซอร์ (`roomC` ค่าเริ่มต้น `NAN`) จึงไม่แสดง |

> [!WHY]
> **ทำไมเลือกแบบ "ตัวเลขใหญ่" เป็นค่าเริ่มต้น:** คนที่มองจอส่วนใหญ่ยืนห่างบอร์ดและอยากรู้แค่ "แอร์เปิดไหม ตั้งกี่องศา" จึงทำให้เหมือนหน้าจอรีโมตแอร์ที่ทุกคนคุ้น ค่าที่ละเอียดกว่า (แรงดัน กระแส IP) ดูได้จากแอป/เว็บอยู่แล้ว อีกเหตุผลคือแฟลช: แบบ 1 ใช้ฟอนต์ไม่กี่ขนาด ส่วนแบบ 5 ต้องมีฟอนต์ `logisoso26` และ `6x10` เพิ่ม ซึ่งอาจทำให้เกินช่องแอป

### หน้าจอตามสถานะของบอร์ด: `refreshOled()`

**ไฟล์ `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 1987–1999**

```cpp:1987
void refreshOled() {
  if (!oledDisplay.due()) return;
  static char clockText[6];
  static char ipText[16];
  struct tm timeInfo;
  if (getLocalTime(&timeInfo, 0)) {
    snprintf(clockText, sizeof(clockText), "%02d:%02d", timeInfo.tm_hour, timeInfo.tm_min);
  } else {
    clockText[0] = '\0';
  }
  snprintf(ipText, sizeof(ipText), "%s", WiFi.localIP().toString().c_str());

  OledData d;
```

| บรรทัด | ความหมาย / เหตุผล |
|---|---|
| 1988 | ยังไม่ถึงรอบวาด → ออกทันที รอบส่วนใหญ่ของ `loop()` จบที่บรรทัดนี้ จึงเกือบไม่มีต้นทุน |
| 1989–1990 | `static char` = ตัวแปรที่อยู่ตลอดอายุโปรแกรม (ไม่หายเมื่อออกจากฟังก์ชัน) จำเป็นเพราะ `OledData` เก็บแค่ **pointer** (`const char*`) ไปยังข้อความ ถ้าเป็นตัวแปร local ธรรมดา pointer จะชี้ไปหน่วยความจำที่ถูกคืนแล้ว |
| 1992 | `getLocalTime(&timeInfo, 0)` พารามิเตอร์ตัวที่สอง `0` = **ไม่รอ** (ค่าเริ่มต้นของฟังก์ชันรอได้ถึง 5 วินาที) ถ้ายังไม่ได้เวลาจาก NTP ก็แค่ไม่แสดงนาฬิกา ไม่ทำให้ `loop()` ค้าง |
| 1993–1995 | ได้เวลา → `"HH:MM"` ไม่ได้ → สตริงว่าง (`topBar` ข้ามนาฬิกาเมื่อ `clock[0]` เป็น `'\0'`) |
| 1997 | แปลง IP เป็นข้อความเก็บไว้ (ใช้ในหน้าเครือข่ายของแบบ 5) |
| 1999 | สร้าง `OledData` ใหม่ทุกครั้ง ฟิลด์ที่ไม่กรอกได้ค่าเริ่มต้นจาก struct |

บรรทัด 2000–2024 กรอกฟิลด์ทีละตัวจาก `config` (ห้อง, เลขแอร์, SSID, deviceId), `airState` (power, temperature, mode, fanSpeed, `verticalSwing != "off"`, sleep), `powerMeasurements` (ค่าไฟทุกตัว ถ้า PZEM ไม่พร้อมใส่ `NAN` ให้จอแสดง `--` แทนค่าเก่าที่อาจผิด), `WiFi.status()`, `mqttClient.connected()`, `WiFi.RSSI()` และ `FIRMWARE_VERSION`

**ไฟล์ `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 2025–2032**

```cpp:2025
  if (bleBlocksNormalOperation) {
    oledDisplay.show(OledDisplay::SETUP, d, config.bleName.c_str(), oledReason.c_str());
  } else if (wifiConnectionInProgress) {
    oledDisplay.show(OledDisplay::CONNECTING, d, config.wifiSsid.c_str());
  } else {
    oledDisplay.show(OledDisplay::NORMAL, d);
  }
}
```

| บรรทัด | สถานะของบอร์ด | หน้าจอ |
|---|---|---|
| 2025–2026 | อยู่ในโหมดตั้งค่า/กู้ BLE (`bleBlocksNormalOperation`) | **SETUP MODE**: ไอคอนบลูทูธ, "Bluetooth name:" + ชื่อ `RMUTT-AC-xxxx`, "Open RMUTT app > Add AC" และเหตุผลจาก `oledReason` (ตัดไม่เกิน 25 ตัวอักษรใน `enterBleRecovery`) เช่น `No saved configuration` |
| 2027–2028 | กำลังรอต่อ Wi-Fi (`wifiConnectionInProgress` ตั้งใน `connectWifiCredentials`) | **Connecting Wi-Fi** + ชื่อ SSID + จุด 5 จุดวิ่ง |
| 2029–2030 | ทำงานปกติ | แบบที่เลือก (`OLED_LAYOUT` = 1 → `screenBig`) หรือพักจอถ้าแอร์ปิดนาน |

บอร์ด IR ไม่ได้ใช้หน้า `ALERT` (มีเฉพาะบอร์ดสายแอร์ที่ใช้เตือนเมื่อสายแอร์ไม่ตอบ)

> [!NOTE]
> **ทำไมหน้า Connecting ขึ้นได้ทั้งที่ `connectWifiCredentials()` วนรออยู่:** ฟังก์ชันนั้นวน `delay(50)` รอ Wi-Fi นานได้ถึง 20 วินาที (ไม่กลับไปที่ `loop()`) แต่ในวงรอมันเรียก `updateStatusLeds()` อยู่แล้วเพื่อกระพริบ LED เหลือง และ `refreshOled()` ถูกเรียกท้าย `updateStatusLeds()` (บรรทัด 1735) จอจึงอัปเดตไปด้วยโดยไม่ต้องเพิ่มโค้ดในวงรอ การผูกจอกับ `updateStatusLeds()` จึงเป็นการ "เกาะ" จุดที่ถูกเรียกบ่อยอยู่แล้วทุกที่

### พักจอเมื่อแอร์ปิดนาน (screen saver)

**ไฟล์ `firmware/rmutt_esp32_air/oled_display.h` บรรทัด 113–125**

```cpp:113
  // พักจอ: แอร์ปิดนาน ตัวหนังสือเล็ก ๆ ย้ายตำแหน่งทุกนาที กันจุดเดิมติดค้างบนจอ OLED
  void saver(const OledData& d, uint32_t now) {
    char b[32];
    if (d.airNo > 0) snprintf(b, sizeof b, "%s #%d OFF", d.room, d.airNo);
    else snprintf(b, sizeof b, "%s OFF", d.room);
    u8g2_.setFont(u8g2_font_5x7_tr);
    int w = u8g2_.getStrWidth(b);
    uint32_t m = now / 60000UL;
    int x = (int)((m * 37) % (uint32_t)(128 - w));
    int y = 8 + (int)((m * 23) % 50);
    u8g2_.drawStr(x, y, b);
    if (d.clock[0]) u8g2_.drawStr(x, y + 9, d.clock);
  }
```

| บรรทัด | ความหมาย |
|---|---|
| 116–117 | ข้อความสั้น เช่น `16203 #1 OFF` |
| 118–119 | ฟอนต์เล็กสุด 5×7 แล้ววัดความกว้างข้อความ |
| 120 | `m` = จำนวนนาทีนับจากบูต ค่านี้เปลี่ยนทุก 60 วินาที ตำแหน่งจึงย้ายทุกนาที |
| 121–122 | ตำแหน่งแบบ "สุ่มเทียม": คูณด้วยจำนวนเฉพาะ 37 และ 23 แล้ว `%` ด้วยพื้นที่ที่วางได้ (x ไม่เกิน `128 - w` ข้อความจึงไม่ล้นขอบ, y อยู่ช่วง 8–57) ได้ตำแหน่งกระจายทั่วจอโดยไม่ต้องใช้ตัวสุ่ม |
| 123–124 | วาดข้อความและนาฬิกาใต้ข้อความ |

เงื่อนไขเข้าโหมดนี้อยู่ใน `show()` บรรทัด 83: หน้า NORMAL และ `offSince_` ไม่เป็น 0 และ `now - offSince_ > OLED_SAVER_AFTER_MS` (10 นาที) พอแอร์ถูกเปิด (`d.power` เป็น true) บรรทัด 73 รีเซ็ต `offSince_` จอกลับเป็นหน้าปกติในรอบวาดถัดไปทันที

> [!WHY]
> **ทำไมต้องพักจอ:** พิกเซล OLED แต่ละจุดเปล่งแสงเองและเสื่อมตามเวลาที่ติด ถ้าแสดง `OFF` ตัวใหญ่ที่เดิมทั้งคืนทั้งวันหยุด (ห้องเรียนปิดแอร์นานกว่าเปิด) พิกเซลบริเวณนั้นจะหรี่กว่าส่วนอื่นจนเห็นเงาค้าง (burn-in) โหมดพักจอทำให้มีพิกเซลติดน้อยมาก (ข้อความเล็กบรรทัดเดียว) และย้ายที่ทุกนาทีจึงไม่มีจุดใดติดค้าง ที่ไม่ปิดจอดำสนิทเพราะคนที่เดินผ่านยังต้องเห็นว่าบอร์ดยังทำงานและอยู่ห้องไหน ส่วนตอนแอร์เปิดไม่พัก เพราะค่าบนจอเปลี่ยนอยู่แล้วและเป็นช่วงที่คนต้องการดูมากที่สุด

### ผลต่อส่วนอื่นของเฟิร์มแวร์

| จุดที่แก้ใน `rmutt_esp32_air.ino` | บรรทัด | ทำไม |
|---|---|---|
| `#include "oled_display.h"` | 38 | ดึงคลาสจอเข้ามา |
| `OledDisplay oledDisplay;` + `String oledReason;` | 158–159 | อ็อบเจกต์จอแบบ global ตัวเดียว และเหตุผลเข้าโหมดตั้งค่า |
| `oledDisplay.begin()` ใน `setup()` | 436 | ตรวจ/เริ่มจอก่อนทุกอย่างที่อาจบล็อก |
| `oledReason = reason...substring(0, 25)` ใน `enterBleRecovery()` | 813 | จอกว้างพอแค่ ~25 ตัวในฟอนต์ 5×7 |
| `oledDisplay.poke()` ใน `publishState()` | 1500 | สถานะแอร์เปลี่ยน → วาดใหม่ทันที (เรียกก่อนเช็ก MQTT จึงทำงานแม้ MQTT หลุด เช่นตอนตัวตั้งเวลาปิดแอร์เอง) |
| `oledDisplay.pushPower(powerWatts)` ใน `readPowerMeter()` | 1698 | เก็บกราฟ |
| `refreshOled()` ท้าย `updateStatusLeds()` | 1735 | อัปเดตจอทุกรอบ `loop()` และระหว่างรอ Wi-Fi |
| `refreshOled()` | 1987–2032 | ประกอบข้อมูลและเลือกหน้าจอ |

ไม่มีการแก้ BLE/MQTT/IR/PZEM/OTA/ข้อมูลย้อนหลังเพื่อจอ (ตาม `README_OLED_TH.md`) จอเป็น "ผู้อ่าน" สถานะเท่านั้น ไม่เคยเปลี่ยนสถานะของระบบ ถ้าจอเสียหรือถอดออก การควบคุมแอร์ไม่ได้รับผลกระทบ

## `build_opt.h`: ทำให้เฟิร์มแวร์พอดีแฟลช

### ปัญหา

ช่องแอปแต่ละช่องใน `partitions.csv` มีขนาด `0x1F0000` = 2,031,616 ไบต์ (ต้องมีสองช่องเพื่อ OTA) ตาม `README_OLED_TH.md` เฟิร์มแวร์ IR 2.4.1 ก่อนเพิ่มจอใช้ไปแล้ว **98.8%** (2,007,985 ไบต์) เหลือราว 23 KB ส่วนจอ OLED (U8g2 + ฟอนต์ + โค้ดหน้าจอ) กินเพิ่ม **~24 KB** ใส่เพิ่มตรง ๆ จะคอมไพล์ไม่ผ่าน (Arduino IDE แจ้ง "Sketch too big") ส่วนที่กินแฟลชมากคือ IRremoteESP8266 ซึ่งคอมไพล์โปรโตคอลแอร์ทุกยี่ห้อ (หลายสิบยี่ห้อ) เข้ามา เพราะ `IRac` เลือกยี่ห้อตอนรันจากชื่อที่ผู้ใช้ตั้ง คอมไพเลอร์จึงตัดยี่ห้อที่ไม่ใช้ทิ้งเองไม่ได้

### เนื้อหาไฟล์

**ไฟล์ `firmware/rmutt_esp32_air/build_opt.h` บรรทัด 1**

```text:1
-DU8X8_NO_HW_I2C -DU8X8_NO_HW_SPI -DSEND_AIRTON=false -DSEND_AIRWELL=false -DSEND_AMCOR=false -DSEND_ARGO=false -DSEND_BOSCH144=false -DSEND_CARRIER_AC64=false -DSEND_CORONA_AC=false -DSEND_DELONGHI_AC=false -DSEND_ECOCLIM=false -DSEND_EUROM=false -DSEND_GOODWEATHER=false -DSEND_KELON=false -DSEND_NEOCLIMA=false -DSEND_RHOSS=false -DSEND_SANYO_AC=false -DSEND_SANYO_AC88=false -DSEND_TCL112AC=false -DSEND_TECHNIBEL_AC=false -DSEND_TECO=false -DSEND_TEKNOPOINT=false -DSEND_TRANSCOLD=false -DSEND_TROTEC=false -DSEND_TROTEC_3550=false -DSEND_TRUMA=false -DSEND_VESTEL_AC=false -DSEND_VOLTAS=false -DSEND_WHIRLPOOL_AC=false -DSEND_YORK=false
```

| แฟล็ก | ผล | เหตุผล |
|---|---|---|
| `-DNAME=ค่า` (รูปแบบทั่วไป) | เท่ากับเขียน `#define NAME ค่า` ไว้บนสุดของ **ทุกไฟล์** ที่คอมไพล์ รวมถึงไฟล์ของไลบรารี | ไลบรารีอ่านค่าพวกนี้ด้วย `#ifndef`/`#if` ตอนคอมไพล์ จึงปรับไลบรารีได้โดยไม่ต้องแก้ไฟล์ของไลบรารี |
| `-DU8X8_NO_HW_I2C` | U8g2 ไม่คอมไพล์ส่วน I2C ฮาร์ดแวร์ (ไม่ดึง `Wire`/ไดรเวอร์ I2C ของ ESP-IDF) | ใช้ `SW_I2C` อยู่แล้ว ไดรเวอร์ฮาร์ดแวร์จึงเป็นของเกิน ประหยัด ~14 KB ตามคอมเมนต์ใน `oled_display.h` |
| `-DU8X8_NO_HW_SPI` | ไม่คอมไพล์ส่วน SPI ฮาร์ดแวร์ของ U8g2 | จอนี้ไม่ใช้ SPI เลย |
| `-DSEND_xxx=false` × 28 | IRremoteESP8266 ไม่คอมไพล์ฟังก์ชันส่ง IR ของยี่ห้อนั้น (Airton, Airwell, Amcor, Argo, Bosch144, Carrier AC64, Corona, Delonghi, Ecoclim, Eurom, Goodweather, Kelon, Neoclima, Rhoss, Sanyo AC/AC88, TCL112, Technibel, Teco, Teknopoint, Transcold, Trotec/Trotec 3550, Truma, Vestel, Voltas, Whirlpool, York) | ยี่ห้อเหล่านี้ไม่มีในรายการที่แอปให้เลือก ยี่ห้อที่แอปใช้ (Daikin, Mitsubishi, Panasonic, Gree, Midea/Coolix, LG, Samsung, Toshiba, Hitachi, Fujitsu, Kelvinator, Sharp, Electra, Haier และ Saijo Denki ที่เป็นไดรเวอร์ของเราเอง) ยังอยู่ครบทุกรุ่นย่อย |

ผล (ตาม `README_OLED_TH.md`, ESP32 core 3.0.7): เฟิร์มแวร์ที่ **เพิ่มจอแล้ว** มีขนาด **2,001,365 ไบต์ (98%)** เล็กกว่ารุ่นเดิมที่ไม่มีจอ (2,007,985 ไบต์) ราว 6.6 KB

### ทำไมใช้ `build_opt.h` และข้อแลกเปลี่ยน

- **ทำไมไม่ใส่ `#define` ใน `.ino`:** `#define` ใน `.ino` มีผลเฉพาะไฟล์นั้น แต่ไลบรารี (`.cpp` ของ IRremoteESP8266/U8g2) ถูกคอมไพล์แยกเป็นคนละหน่วย จึงมองไม่เห็น ต้องส่งเป็นแฟล็กให้คอมไพเลอร์ทุกไฟล์ ซึ่ง Arduino-ESP32 core 3.x ทำให้โดยอ่าน `build_opt.h` ที่วางข้าง `.ino` อัตโนมัติ (ไม่ต้องตั้งอะไรใน IDE)
- **ทำไมไม่ขยายช่องแอป:** ถ้าขยายช่องแอปต้องลดช่องอื่น (ช่อง OTA ที่สองหรือ `rmuttlog`) และการเปลี่ยนตารางพาร์ติชันทำผ่าน OTA ไม่ได้ ต้องเสียบสาย USB ทุกบอร์ดใหม่ การตัดโค้ดที่ไม่ใช้ปลอดภัยกว่า
- **ข้อแลกเปลี่ยน 1:** ถ้าวันหนึ่งแอปเพิ่มยี่ห้อที่ถูกปิดไว้ (เช่น TCL หรือ York) ต้องลบแฟล็กของยี่ห้อนั้นออกแล้วคอมไพล์ใหม่ ไม่เช่นนั้น `IRac` จะไม่ส่งสัญญาณของยี่ห้อนั้น
- **ข้อแลกเปลี่ยน 2:** เหลือที่ว่างแค่ ~2% (ราว 30 KB) ฟีเจอร์ใหญ่ถัดไป (เช่นเปลี่ยนเป็นหน้าจอแบบ 5 ที่ใช้ฟอนต์เพิ่ม) อาจต้องตัดอย่างอื่นอีก
- **ข้อแลกเปลี่ยน 3:** ไฟล์นี้ "มองไม่เห็น" ในโค้ด ถ้ามีคนลบทิ้งเพราะคิดว่าเป็น header ว่าง ๆ จะคอมไพล์ไม่ผ่านโดยไม่รู้สาเหตุ จึงมีคำเตือน "อย่าลบ" ทั้งใน `README_OLED_TH.md` และ `firmware/README.md` และถ้าแก้ไฟล์นี้ต้องปิด-เปิด IDE หรือลบโฟลเดอร์ build ชั่วคราว ไลบรารีจึงจะถูกคอมไพล์ใหม่ด้วยแฟล็กใหม่

## ล้างบอร์ดเมื่อถูกลบออกจากแอป (unprovision)

### ปัญหาที่แก้

ถ้าแอดมินลบแอร์หรือเซนเซอร์ออกจากแอปแล้ว Backend ลบแค่แถวในฐานข้อมูลและบัญชี MQTT ตัวบอร์ดจะยังจำ Wi-Fi, MQTT host/บัญชี, ห้อง ไว้ใน NVS และพยายามต่อ MQTT ด้วยบัญชีที่ถูกลบไปแล้วซ้ำทุก 3 วินาทีไม่รู้จบ จะนำไปติดห้องอื่นก็ต้องเสียบสาย USB แฟลช `reset.ino` ก่อน ทั้งสามเฟิร์มแวร์จึงมีคำสั่ง MQTT `{"action":"unprovision"}` ให้บอร์ด **ล้างตัวเองกลับเป็นเหมือนใหม่**

### ลำดับระหว่าง Backend กับบอร์ด

```text
แอดมินกดลบในแอป
 Backend: ลบแถวในฐานข้อมูล
 Backend ──/command {"action":"unprovision","deviceId":"ESP32-...",commandId,sentAt} (QoS 1, ไม่ retained)──► บอร์ด
 บอร์ด: ตรวจ deviceId ตรงกับตัวเองไหม
 บอร์ด ──/status {"deviceId":...,"online":false,"unprovisioned":true} (ไม่ retained)──► Backend (รอได้ไม่เกิน 4 วินาที)
 บอร์ด ──/status "" (retained), /state "" (retained)──► Broker   (ล้างข้อความค้างของตัวเอง)
 บอร์ด: disconnect แบบปกติ → ล้าง NVS (+ ล้าง rmuttlog สำหรับบอร์ดแอร์) → ESP.restart()
 Backend: ล้าง retained ที่เหลือ → ลบบัญชี MQTT ของบอร์ด
 บอร์ดบูตใหม่: ไม่มี configured → โหมด BLE ตั้งค่า (จอขึ้น SETUP MODE "No saved configuration")
```

ฝั่ง Backend (`backend/src/utils/unprovision.js`, `services/mqtt.js` ฟังก์ชัน `unprovisionDevice`) รอคำตอบ `unprovisioned:true` ได้ไม่เกิน 4,000 ms (`UNPROVISION_ACK_TIMEOUT_MS`) ถ้าบอร์ดออฟไลน์ คำสั่งไปไม่ถึง (Backend ตั้งใจไม่ส่งแบบ retained เพราะถ้าเพิ่มบอร์ดตัวเดิมกลับมาภายหลัง คำสั่งที่ค้างอยู่จะล้างบอร์ดทิ้งอีกรอบ) กรณีนั้นยังต้องใช้ `reset.ino` หรือกด BOOT ตั้งค่าใหม่

### บอร์ดแอร์ IR: `unprovisionAndRestart()`

คำสั่งถูกรับใน `processMqttCommand()` (บรรทัด 1229–1239 ดูหัวข้อเจาะโค้ด 3) ซึ่งทำงานใน `loop()` อยู่แล้ว (callback แค่ตั้ง `mqttCommandReady`) จึงเรียกฟังก์ชันล้างได้ตรง ๆ

**ไฟล์ `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 1174–1193**

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
```

| บรรทัด | ความหมาย / เหตุผล |
|---|---|
| 1176 | ตอบ/ล้างได้เฉพาะเมื่อยังต่อ MQTT อยู่ (ปกติต่ออยู่ เพราะเพิ่งรับคำสั่งมา) |
| 1178–1183 | สร้าง JSON ยืนยัน `{"deviceId":...,"online":false,"unprovisioned":true}` ใส่ `deviceId` ให้ Backend จับคู่ได้ว่าใครตอบ (`isUnprovisionAck` ตรวจทั้ง `unprovisioned === true` และ `deviceId`) |
| 1185 | ส่งที่ `/status` แบบ **ไม่ retained** (`false`) เพราะเป็นข้อความเหตุการณ์ครั้งเดียว ไม่ใช่สถานะที่ควรค้างใน Broker |
| 1188–1189 | ส่ง payload ว่างแบบ retained ที่ `/status` และ `/state` = วิธีมาตรฐานของ MQTT ในการ **ลบ** ข้อความ retained ไม่งั้น Broker จะเก็บสถานะสุดท้ายของบอร์ดที่ถูกลบไปตลอด และส่งให้ผู้สมัครใหม่ |
| 1190–1191 | `mqttClient.loop()` + รอ 300 ms ให้ข้อความออกจากบัฟเฟอร์ไปถึง Broker ก่อนตัด (PubSubClient ส่ง QoS 0 จึงไม่มีการยืนยัน ต้องเผื่อเวลา) |
| 1192 | `disconnect()` แบบปกติ (ส่งแพ็กเก็ต DISCONNECT) Broker จึง **ไม่** ปล่อย Last Will `online:false` แบบ retained ออกมาทับสิ่งที่เพิ่งล้าง (คอมเมนต์บรรทัด 1186–1187) ถ้าปล่อยให้หลุดเองตอนรีบูต LWT จะกลับมาค้างใน Broker |

**ไฟล์ `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 1195–1209**

```cpp:1195
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

| บรรทัด | ความหมาย / เหตุผล |
|---|---|
| 1195–1197 | เปิด namespace `rmutt-air` แบบเขียนได้ (`false` = ไม่ใช่ read-only) แล้ว `clear()` ลบทุกคีย์ (Wi-Fi, MQTT, ห้อง, เลขแอร์, โปรโตคอล, token, เวลาเปิดปิด) รวม `configured` ด้วย |
| 1198–1200 | ลบ namespace `rmutt-state` (สถานะแอร์ล่าสุด + `hist_ack`) บอร์ดใหม่จะได้ไม่เริ่มด้วยสถานะของห้องเดิม |
| 1202–1204 | ลบพาร์ติชัน `rmuttlog` ทั้งหมด (64 KB) ข้อมูลไฟฟ้าย้อนหลังของห้องเดิมต้องไม่ถูกส่งไปปนกับห้องใหม่ เช็ก `nullptr` ก่อนเพราะบอร์ดที่ยังไม่ได้แฟลชตารางพาร์ติชันใหม่จะไม่มีพาร์ติชันนี้ (ต่างจาก `reset.ino` ที่ไม่แตะ `rmuttlog`) |
| 1206–1208 | พิมพ์ log รอ 300 ms ให้ Serial ส่งออกหมด แล้วรีบูต พอบูตใหม่ `configured` เป็น false → `enterBleRecovery("No saved configuration")` |

สิ่งที่ **ไม่** เปลี่ยน: Device ID (สร้างจาก eFuse MAC ไม่ได้เก็บใน NVS) และแอร์ไม่ถูกสั่งอะไรเพิ่ม (IR ส่งครั้งเดียว แอร์จึงค้างที่สถานะล่าสุด ตามคอมเมนต์บรรทัด 1171–1172) บอร์ดสายแอร์มีฟังก์ชันเดียวกัน (บรรทัด 1203 ของ `rmutt_esp32_air_wired.ino`)

### บอร์ดตรวจจับคน: ตั้งธงใน callback แล้วทำใน `loop()`

บอร์ดตรวจจับคนจัดการ `/command` **ใน `mqttCallback()` โดยตรง** (ไม่มี `processMqttCommand()` แบบบอร์ดแอร์) จึงต้องเลื่อนงานออกไปแบบเดียวกับ OTA

**ไฟล์ `firmware/rmutt_esp32_occupancy/rmutt_esp32_occupancy.ino` บรรทัด 853–864**

```cpp:853
  if (action == "unprovision") {
    // Backend ส่งมาเมื่อแอดมินกดนำเซ็นเซอร์ออกในแอป
    // ตรวจ deviceId ซ้ำอีกชั้น กันข้อความหลงมาผิด topic
    // ทำต่อใน loop ไม่ใช่ใน callback เพราะต้อง publish และตัด MQTT
    const String target = document["deviceId"] | "";
    if (target != config.deviceId) {
      Serial.printf("Unprovision ignored: deviceId '%s' is not this board\n", target.c_str());
      return;
    }
    unprovisionRequested = true;
    return;
  }
```

| บรรทัด | ความหมาย / เหตุผล |
|---|---|
| 857–861 | ตรวจ `deviceId` ในคำสั่งต้องตรงกับบอร์ดนี้ (ป้องกันเป็นชั้น: แม้ ACL จะกันแล้ว แต่ถ้า topic ตั้งผิดหรือข้อความหลง บอร์ดจะไม่ล้างตัวเองผิดตัว ซึ่งเป็นความเสียหายที่ย้อนไม่ได้) |
| 862 | ตั้งธง `unprovisionRequested` (ประกาศบรรทัด 145) แทนการเรียกตรง เพราะอยู่ใน `mqttClient.loop()` อยู่ ถ้า publish แล้ว `disconnect()` จากใน callback ของ PubSubClient เองจะเป็นการตัดการเชื่อมต่อที่ตัวเองกำลังใช้ประมวลผลข้อความอยู่ |

`loop()` บรรทัด 413 `if (unprovisionRequested) unprovisionAndRestart("removed from the app");` เรียกฟังก์ชัน (บรรทัด 884–912) ที่ทำเหมือนบอร์ดแอร์ แต่ต่างกันสามจุด: ล้างธงก่อน (บรรทัด 885), ล้าง retained แค่ `/status` (บอร์ดนี้ไม่มี `/state`), และล้าง NVS namespace เดียว `rmutt-occ` (ไม่มีสถานะแอร์และไม่มี `rmuttlog`)

> [!WHY]
> **ทำไมให้บอร์ดตอบก่อน แล้ว Backend จึงลบบัญชี MQTT:** ถ้า Backend ลบบัญชีก่อน Broker (Dynamic Security) จะตัดบอร์ดออกทันที คำสั่ง unprovision จะไปไม่ถึง ลำดับ "สั่ง → รอคำยืนยัน (ไม่เกิน 4 วินาที) → ลบบัญชี" ทำให้แน่ใจว่าบอร์ดที่ออนไลน์ได้รับคำสั่ง และการลบในฐานข้อมูลไม่ต้องรอบอร์ด (ถ้าบอร์ดไม่ตอบ Backend ก็ลบต่อตามปกติ ตามคอมเมนต์ใน `unprovisionDevice`)

## เครื่องมือ: `ld2410_pinscan` และ `reset`

**`ld2410_pinscan.ino`** ใช้เมื่อ `[diag]` ของบอร์ดตรวจจับคนบอกว่า "UART1 rx bytes = 0" แต่ตรวจทางบลูทูธแล้วโมดูลเรดาร์ปกติ ปัญหาจึงเหลือแค่ขา ESP32 เสีย หรือสายเสียบผิดแพด (แพดที่พิมพ์ว่า TX อาจไม่ใช่ TX จริง) วิธีทำงาน:

- ตาราง `PINS[]` (บรรทัด 48–50) คือ GPIO ที่สแกนได้ 18 ขา: 2, 4, 5, 12, 13, 14, 16, 17, 18, 19, 21, 22, 23, 25, 26, 27, 32, 33 ตัดออกโดยตั้งใจ: GPIO 6–11 (ต่อ flash ภายใน แตะแล้วบอร์ดค้าง), 1 และ 3 (Serial USB), 0 (BOOT), 34–39 (ขาเข้าอย่างเดียว ไม่มี pull ภายใน สแกนไม่ได้)
- `inspectPin()` ตรวจขาทีละขา 3 ขั้น: เปิด pull-up ภายในแล้วอ่าน, เปิด pull-down แล้วอ่าน, แล้ว `countTransitions()` นับจำนวนครั้งที่ระดับเปลี่ยนใน 250 ms (`SAMPLE_MS`)
- `judge()` ตัดสิน: เปลี่ยน > 8000 ครั้ง (`ACTIVITY_MAX`) = `VERDICT_UNSTABLE` (เร็วเกินกว่าเป็นข้อมูล เช่นคริสตัล 32.768 kHz ที่บางบอร์ดต่อกับ GPIO32/33 ≈ 16,000 ครั้ง/250 ms), 20–8000 (`ACTIVITY_MIN`) = `VERDICT_UART` (เฟรม LD2410 ราว ~30 ไบต์ทุก 100 ms ให้หลักร้อย), ไม่เปลี่ยนแต่ตาม pull = `VERDICT_FREE` (ว่าง), ไม่ตาม pull และเป็น HIGH = `VERDICT_HIGH`, เป็น LOW = `VERDICT_LOW`
- พอเจอขา UART `confirmWithUart()` เปิด UART1 ที่ baud 256000, 115200, 57600 ทีละค่า อ่าน 800 ms หา header ของเฟรม `F4 F3 F2 F1` (ข้อมูล) หรือ `FD FC FB FA` (คำตอบคำสั่ง) ด้วยหน้าต่างเลื่อน 4 ไบต์ ถ้าเจอจะพิมพ์ค่าที่ต้องไปแก้ `RADAR_RX_PIN` และ `RADAR_BAUD` ในสเก็ตช์หลัก
- สแกนซ้ำทุก 2 วินาที (`delay(2000)` ใน `loop()`) แสดงเฉพาะขาที่ไม่ว่างเพื่อให้ขยับสายดูผลสดได้ ไม่ลบ NVS
- คำเตือนในหัวไฟล์: ห้ามค้างสายไว้ที่ GPIO12 ตอนกดรีเซ็ต เพราะ GPIO12 คือ strapping pin ถ้าถูกดึงเป็น HIGH ตอนบูตจะตั้งแรงดัน flash ผิดและบอร์ดไม่บูต

**`reset.ino`** (35 บรรทัด) ทำสามอย่างตามลำดับ: `nvs_flash_erase()` (ล้างทั้ง NVS) → `WiFi.disconnect(true, true)` (ลืม Wi-Fi) → `nvs_flash_init()` (สร้าง NVS ใหม่ให้พร้อมใช้) พิมพ์ผลทาง Serial 115200 และ `loop()` ว่าง หลังรันแล้วบอร์ดจะเข้าโหมด BLE ตั้งค่าเมื่ออัปโหลดสเก็ตช์หลักกลับไป เพราะ `configured` หายไป

## ทดสอบบนคอมพิวเตอร์: `tests/history_log_test.cpp`

คอมไพล์ด้วย `g++ -std=c++17 -I../rmutt_esp32_air history_log_test.cpp -o t && ./t` (ผู้เขียนบทนี้รันแล้ว ผลคือ `history_log: 2099 checks passed`) ใช้ `FakeFlash` ที่จำลอง NOR flash: `write` ทำ `bytes[i] &= data[i]` (เปลี่ยนได้แค่ 1→0) และ `eraseSector` ตั้งทั้ง sector เป็น `0xFF` แล้วนับจำนวนครั้งที่ลบ มีกรณีทดสอบ 4 กลุ่ม:

1. เก็บ 5 รายการ → ขอ batch 3 → ack → ที่เหลือ 2 ตรงตามที่คาด (sector ที่ยังมีของค้างต้องไม่ถูกลบ) → ack ครบ → flash ว่างทั้งหมด → เขียนต่อได้
2. รีบูตกลางทาง (สร้าง `HistoryLog` ใหม่บน flash เดิมโดยส่ง `ackedTs` จาก "NVS") → pending ถูกต้อง, เขียนต่อได้, ปฏิเสธรายการที่เวลาถอยหลัง
3. เขียนเกินความจุ (2048+10 รายการ) → `lostRecords() == 128` (ทับ 1 sector) → รายการแรกที่เหลือคือลำดับที่ 129 → บูตใหม่หลังวนรอบยังหาตำแหน่งเขียนถัดไปถูก
4. พาร์ติชันเต็มไปด้วยขยะ (เช่นข้อมูล coredump เก่า) → ไม่ถูกนับเป็นรายการ (magic/checksum ไม่ตรง) และเขียนทับได้

> [!WHY]
> **ทำไมแยก `history_log.h` ไม่ให้รู้จัก ESP32:** ตรรกะ ring buffer + ack + ลบ sector ซับซ้อนและผิดพลาดง่าย ถ้าฝังอยู่กับ `esp_partition_*` ต้องแฟลชบอร์ดทุกครั้งเพื่อทดสอบ และทดสอบเคสหายาก (ไฟดับกลางทาง, วนรอบ) ได้ยากมาก การส่ง "ตัวเก็บข้อมูล" เป็นพารามิเตอร์ของเทมเพลต (dependency injection แบบ compile-time) ทำให้ทดสอบเคสเหล่านี้บนคอมพิวเตอร์ได้ภายในเสี้ยววินาที

## เจาะโค้ดทีละบรรทัด

### 1) `setup()` ของบอร์ดแอร์

**ไฟล์ `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` บรรทัด 426–436**

```cpp:426
void setup() {
  Serial.begin(115200);
  pinMode(SETUP_BUTTON_PIN, INPUT_PULLUP);
  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(YELLOW_LED_PIN, OUTPUT);
  digitalWrite(GREEN_LED_PIN, LOW);
  digitalWrite(RED_LED_PIN, LOW);
  digitalWrite(YELLOW_LED_PIN, LOW);
  delay(80);
  oledDisplay.begin();
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 426 | `void setup() {` | ถูกเรียกครั้งเดียวหลังบูต/รีเซ็ต |
| 427 | `Serial.begin(115200)` | เปิด UART0 (ผ่าน USB) ที่ 115200 baud ไว้พิมพ์ log ดูใน Serial Monitor |
| 428 | `pinMode(SETUP_BUTTON_PIN, INPUT_PULLUP)` | ตั้ง GPIO0 เป็นขาเข้าพร้อมตัวต้านทาน pull-up ภายใน ปล่อยปุ่ม = อ่านได้ HIGH, กดปุ่ม (ต่อลง GND) = LOW ไม่ต้องใช้ตัวต้านทานภายนอก |
| 429–431 | `pinMode(..., OUTPUT)` | ตั้งขา LED ทั้งสามเป็นขาออก |
| 432–434 | `digitalWrite(..., LOW)` | ดับ LED ทั้งหมดก่อน เพราะสถานะขาตอนเพิ่งบูตไม่แน่นอน |
| 435 | `delay(80)` | รอสั้น ๆ ให้ไฟนิ่งและ pull-up เสถียรก่อนอ่านปุ่ม |
| 436 | `oledDisplay.begin()` | ตรวจว่ามีจอ OLED ต่ออยู่ไหม ถ้ามีก็เริ่มจอ ถ้าไม่มีก็ปิดส่วนจอแล้วทำงานต่อ (ดูหัวข้อ "จอ OLED 1.3 นิ้ว") เรียกตั้งแต่ต้นเพื่อให้หน้า SETUP MODE หรือ Connecting Wi-Fi ขึ้นได้ตั้งแต่ขั้นแรกของการบูต |

**บรรทัด 438–443 และ 454–460**

```cpp:438
  config.deviceId = createDeviceId();
  config.bleName = "RMUTT-AC-" + config.deviceId.substring(6);
  Serial.println();
  Serial.println("RMUTT ESP32 Air Controller");
  Serial.printf("Firmware: %s\n", FIRMWARE_VERSION);
  Serial.printf("Device ID: %s\n", config.deviceId.c_str());
```

```cpp:454
  saijoAc.begin();
  initHistoryLog();
  loadConfig();
  loadAirState();
  mqttClient.setBufferSize(2048);
  mqttClient.setCallback(mqttCallback);

```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 438 | `config.deviceId = createDeviceId()` | ได้ `ESP32-XXXXXXXXXXXX` จาก eFuse MAC ของชิป ไม่ซ้ำกันและไม่ต้องตั้งเอง |
| 439 | `config.bleName = "RMUTT-AC-" + config.deviceId.substring(6)` | ตัด 6 ตัวแรก (`ESP32-`) ออก เหลือ 12 หลัก ได้ชื่อ BLE ที่ผู้ใช้เห็นในแอป |
| 442–443 | `Serial.printf("Firmware: %s\n", ...)` | พิมพ์เวอร์ชัน (ปัจจุบัน `2.5.1`) เป็นวิธียืนยันว่าแฟลชสำเร็จจริง |
| 454 | `saijoAc.begin()` | เริ่มขา IR (`irsend_.begin()` ตั้งขา GPIO17 เป็นขาออก) |
| 455 | `initHistoryLog()` | หา partition `rmuttlog`, อ่าน `hist_ack` จาก NVS, สแกนหาตำแหน่งเขียนและนับรายการค้างส่ง ทำก่อน `loadConfig` เพราะไม่ต้องใช้ค่า Wi-Fi |
| 456–457 | `loadConfig(); loadAirState();` | อ่านค่าตั้งค่าและสถานะแอร์จาก NVS |
| 458 | `mqttClient.setBufferSize(2048)` | ขยาย buffer ของ PubSubClient (ค่าปกติ 256 ไบต์ ไม่พอสำหรับ JSON ของ `/status` และ `/history`) |
| 459 | `mqttClient.setCallback(mqttCallback)` | ลงทะเบียนฟังก์ชันที่ถูกเรียกเมื่อมีข้อความเข้า |

**บรรทัด 461–475**

```cpp:461
  const bool setupRequested = digitalRead(SETUP_BUTTON_PIN) == LOW;
  if (!config.configured || setupRequested) {
    enterBleRecovery(
        setupRequested
            ? "BOOT button requested setup"
            : "No saved configuration");
    return;
  }

  if (!connectWifi()) {
    enterBleRecovery("Stored Wi-Fi could not connect", true);
    return;
  }
  connectMqtt();
}
```

- **บรรทัด 461:** อ่านปุ่มจริงเพียงครั้งเดียวที่นี่ LOW = ผู้ใช้กดค้างตอนรีเซ็ต
- **บรรทัด 462–468:** ถ้ายังไม่เคยตั้งค่า หรือผู้ใช้ขอตั้งค่า เข้าโหมด BLE (`enterBleRecovery` ไม่ส่ง `retryWifi` จึงเป็น false = ไม่ลองต่อ Wi-Fi เบื้องหลัง และแก้ได้ทุกช่อง) และ `return` จาก `setup()` (แล้ว `loop()` จะทำงานต่อโดยอยู่ในโหมดกู้) ตัวเลือก `? :` เป็น ternary เลือกข้อความ log
- **บรรทัด 470–473:** ต่อ Wi-Fi ด้วยค่าที่เก็บไว้ ถ้าไม่ได้ เข้า BLE recovery แบบ `retryWifi = true`
- **บรรทัด 474:** ต่อ MQTT (ถ้าไม่สำเร็จจะลองใหม่ใน `loop()` ทุก 3 วินาที)

> [!WHY]
> อ่านปุ่มเฉพาะตอนบูตเพราะเป็นการตัดสินใจ "ครั้งเดียวว่าจะเข้าโหมดไหน" ไม่ต้องเสียเวลาตรวจปุ่มทุกรอบ `loop()` และกันการกดโดยไม่ตั้งใจระหว่างใช้งาน

> [!WARN]
> ข้อสังเกตจากการอ่านโค้ด (ไม่ได้ทดสอบกับบอร์ดจริง): ใน ESP32 ถ้า GPIO0 เป็น LOW ณ จังหวะที่ชิปพ้นจากการรีเซ็ต ROM bootloader จะเข้าโหมดดาวน์โหลดและไม่รันสเก็ตช์เลย ส่วนโค้ดนี้อ่านปุ่มที่บรรทัด 461 ซึ่งอยู่หลังขั้นตอนเริ่มต้นหลายอย่าง (เริ่ม flash/NVS, สแกนพาร์ติชันประวัติ) ดังนั้นในทางปฏิบัติให้ลองกดปุ่ม BOOT ค้างไว้ช่วงที่บอร์ดกำลังบูตหลังปล่อยปุ่มรีเซ็ต ถ้าบอร์ดเข้าโหมดดาวน์โหลดให้เปลี่ยนจังหวะการกด

### 2) `loop()` ของบอร์ดแอร์

**บรรทัด 477–496**

```cpp:477
void loop() {
  if (millis() - lastPzemReadAt >= PZEM_READ_INTERVAL_MS) {
    lastPzemReadAt = millis();
    readPowerMeter();
  }
  // ทำก่อนเช็ก Wi-Fi/BLE เพราะต้องเก็บข้อมูลต่อแม้บอร์ดอยู่ในโหมดกู้ Wi-Fi
  finalizeHistoryInterval();
  updateStatusLeds();

  if (bleAdvertisingEnabled &&
      !bleBlocksNormalOperation &&
      onlineSetupExpiresAt != 0 &&
      static_cast<int32_t>(millis() - onlineSetupExpiresAt) >= 0 &&
      !bleClientConnected) {
    bleAdvertisingEnabled = false;
    bleReadvertisePending = false;
    BLEDevice::getAdvertising()->stop();
    Serial.println(
        "BLE setup window closed; Wi-Fi and MQTT stayed connected");
  }
```

- **478–481:** แพทเทิร์น millis ตัวอย่างแรก: ถ้าผ่านมาครบ 2000 ms ตั้ง `lastPzemReadAt` ใหม่แล้วอ่าน PZEM ตรงนี้ไม่ใช้ `delay` จึงไม่บล็อกงานอื่น
- **483:** `finalizeHistoryInterval()` เรียกทุกรอบ ข้างในกรองเองว่าถึงรอยต่อ 5 นาทีหรือยัง ใส่ไว้ **ก่อน** บล็อกเช็ก Wi-Fi/BLE เพื่อให้เก็บข้อมูลต่อแม้อยู่ในโหมดกู้
- **484:** `updateStatusLeds()` อัปเดต LED ทุกรอบ (กระพริบ LED เหลืองต้องเรียกบ่อย)
- **486–496:** ถ้าเปิด BLE ไว้ในโหมดออนไลน์ (`!bleBlocksNormalOperation`) และมีเวลาหมดอายุ (`onlineSetupExpiresAt != 0`) และถึงเวลาแล้ว และไม่มีแอปต่ออยู่ ให้หยุดประกาศ BLE การเปรียบเทียบ `static_cast<int32_t>(millis() - onlineSetupExpiresAt) >= 0` คือวิธีเทียบเวลาที่ปลอดภัยจากการที่ `millis()` วนรอบ (เป็น unsigned ลบกันแล้วแปลงเป็น signed)

**บรรทัด 498–514**

```cpp:498
  if (bleReadvertisePending &&
      static_cast<int32_t>(millis() - bleReadvertiseAt) >= 0) {
    bleReadvertisePending = false;
    startBleAdvertising();
  }

  if (configReady) processPendingConfig();

  if (restartAt != 0 && static_cast<int32_t>(millis() - restartAt) >= 0) {
    ESP.restart();
  }

  if (bleBlocksNormalOperation || !config.configured) {
    attemptWifiRecovery();
    delay(10);
    return;
  }
```

- **498–502:** ถ้ามีคำขอประกาศ BLE ใหม่ (ตั้งใน `onDisconnect`) และถึงเวลา → `startBleAdvertising()`
- **504:** ถ้า callback ฝั่ง BLE รับ config ครบแล้ว (`configReady`) ค่อยประมวลผลที่นี่ใน loop ไม่ใช่ใน callback
- **506–508:** ถ้าตั้งเวลารีสตาร์ตไว้ (หลังบันทึก config) และถึงเวลา → `ESP.restart()`
- **510–514:** ถ้าอยู่โหมดกู้ (หรือยังไม่เคยตั้งค่า) ลองต่อ Wi-Fi เบื้องหลัง `delay(10)` แล้ว `return` ข้ามงานปกติที่เหลือทั้งหมด

**บรรทัด 516–542**

```cpp:516
  if (WiFi.status() != WL_CONNECTED) {
    if (!connectWifi()) {
      enterBleRecovery("Wi-Fi connection was lost", true);
      return;
    }
  }
  if (!mqttClient.connected()) {
    if (millis() - lastMqttReconnectAttempt >= 3000) {
      lastMqttReconnectAttempt = millis();
      connectMqtt();
    }
  } else {
    mqttClient.loop();
    if (provisionAckClearReady &&
        mqttClient.publish(
            (config.mqttTopic + "/provision-ack").c_str(),
            "",
            true)) {
      provisionAckClearReady = false;
    }
    if (!config.provisioningToken.isEmpty() &&
        millis() - lastProvisionAt >= 10000) {
      publishProvisioningToken();
    }
    if (historyAckReady) applyHistoryAck();
    processHistoryUpload();
  }
```

- **516–521:** ถ้า Wi-Fi หลุด ลอง `connectWifi()` (บล็อกได้สูงสุด 20 วินาที) ถ้าไม่ได้ → เข้า BLE recovery แล้ว `return`
- **522–526:** ถ้า MQTT ไม่ต่อ ลองต่อใหม่ แต่ห่างกันอย่างน้อย 3000 ms (`lastMqttReconnectAttempt`) เพื่อไม่ถล่ม broker และไม่บล็อก loop ติด ๆ กัน
- **528:** `mqttClient.loop()` ให้ PubSubClient รับข้อความเข้า (เรียก `mqttCallback`) และส่ง keep-alive ต้องเรียกบ่อย ๆ
- **529–535:** ถ้า Backend ตอบ ack ของ provisioning แล้ว (`provisionAckClearReady`) ส่ง payload ว่างแบบ retained ไปที่ `/provision-ack` เพื่อล้างข้อความ retained ที่ค้างอยู่ (กันไม่ให้ได้ ack เก่ากลับมาทุกครั้งที่ต่อใหม่) ล้างสำเร็จแล้วค่อยปิดธง
- **536–539:** ยังมี token ค้าง (ยังไม่ถูก activate) → ส่ง `/provision` ซ้ำทุก 10 วินาที
- **540–541:** ถ้ามี ack ข้อมูลย้อนหลังรออยู่ ให้ลบ flash ใน loop แล้วเรียก `processHistoryUpload()` ซึ่งตัดสินเองว่าถึงเวลาส่งหรือยัง

**บรรทัด 544–555**

```cpp:544
  if (mqttCommandReady) processMqttCommand();
  if (otaRequested) performOtaUpdate();
  processTimers();
  processDailySchedule();

  if (statusPublishRequested ||
      millis() - lastStatusAt >= STATUS_INTERVAL_MS) {
    lastStatusAt = millis();
    publishStatus();
  }
  delay(5);
}
```

- **544:** ถ้า callback ฝากคำสั่งไว้ (`mqttCommandReady`) ประมวลผลที่นี่
- **545:** มีคำขอ OTA → `performOtaUpdate()` ซึ่งจะบล็อกนาน (ดาวน์โหลดไฟล์)
- **546–547:** ตัวจับเวลาเปิด/ปิดที่ผู้ใช้สั่ง และตารางเปิด/ปิดรายวัน
- **549–553:** ส่ง `/status` ถ้ามีคำขอ (`statusPublishRequested` เช่นสถานะแอร์เปลี่ยน) หรือครบ 10 วินาที
- **554:** `delay(5)` ให้ CPU/FreeRTOS มีเวลาทำงานเบื้องหลัง (Wi-Fi stack ฯลฯ) และป้อน watchdog

### 3) `connectMqtt()` และ `mqttCallback()`

**บรรทัด 1055–1063 (เลือกตัวเชื่อมต่อ)**

```cpp:1055
  if (config.mqttTls) {
    if (!ensureClockSynced()) return;
    secureClient.setCACert(LETSENCRYPT_CA);
    secureClient.setTimeout(15);
    mqttClient.setClient(secureClient);
  } else {
    mqttClient.setClient(wifiClient);
  }
  mqttClient.setServer(config.mqttHost.c_str(), config.mqttPort);
```

- **1055–1059:** ถ้าตั้งให้ใช้ TLS: ต้องรู้เวลาจริงก่อน (`ensureClockSynced()`) ไม่เช่นนั้นออกจากฟังก์ชัน (จะลองใหม่ในอีก 3 วินาที) แล้วฝังใบรับรอง `LETSENCRYPT_CA` ให้ `secureClient` ตั้ง timeout 15 วินาทีและสลับ PubSubClient ไปใช้ `secureClient`
- **1060–1062:** ไม่ใช้ TLS ใช้ TCP ธรรมดา (`wifiClient`) ซึ่งใช้ในวง LAN ตอนพัฒนา
- **1063:** ตั้ง host และ port ของ broker จากค่าที่ provisioning ไว้ (ค่าเริ่มต้น ts.net:8443) เปลี่ยนเส้นทางไป Funnel โดยไม่ต้องแก้เฟิร์มแวร์

**บรรทัด 1064–1089 (LWT + connect)**

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
```

- **1064:** หัวข้อ `<topic>/status` ที่จะเป็นทั้งที่ประกาศสถานะปกติและที่ LWT
- **1065:** client id = `"rmutt-"` + deviceId ต้องไม่ซ้ำกันในหมู่ client ของ broker (ถ้าซ้ำ broker จะตัดตัวเก่าออก) การใช้ MAC ทำให้ไม่ซ้ำ
- **1066–1070:** สร้าง payload ของ LWT `{"online":false,"deviceId":"..."}` ด้วย ArduinoJson (`DynamicJsonDocument offline(96)` จองหน่วยความจำ 96 ไบต์บน heap)
- **1073–1079:** ถ้าไม่มี username ใช้ `connect(clientId, willTopic, willQos=1, willRetain=true, willMessage)`
- **1080–1089:** ถ้ามี username ใช้อีก overload ที่รับ `(clientId, username, password, willTopic, 1, true, willMessage)` (บัญชีนี้ Backend ออกให้ตอน provision ส่วนสิทธิ์ของแต่ละบัญชีควบคุมด้วย ACL ของ Mosquitto Dynamic Security ตามที่คอมเมนต์ใน `ota_update.h` อ้างถึง ดูบทเครือข่ายและเซิร์ฟเวอร์)

**ไฟล์ `rmutt_esp32_air.ino` บรรทัด 1090–1112**

```cpp:1090
  if (!connected) {
    Serial.printf("MQTT connection failed, state: %d\n", mqttClient.state());
    return;
  }

  mqttClient.subscribe((config.mqttTopic + "/command").c_str(), 1);
  mqttClient.subscribe((config.mqttTopic + "/provision-ack").c_str(), 1);
  mqttClient.subscribe((config.mqttTopic + "/schedule-status").c_str(), 1);
  mqttClient.subscribe((config.mqttTopic + "/history-ack").c_str(), 1);
  // เริ่มส่งข้อมูลย้อนหลังหลังหน่วงแบบสุ่ม ไม่ส่งทันทีที่ต่อได้
  historyAwaitingAck = false;
  historyNextSendAt =
      millis() + static_cast<uint32_t>(random(
                     HISTORY_START_DELAY_MIN_MS,
                     HISTORY_START_DELAY_MAX_MS + 1));
  Serial.println("MQTT connected");
  Serial.printf(
      "Subscribed: %s/command\n",
      config.mqttTopic.c_str());
  publishStatus();
  publishState();
  publishProvisioningToken();
}
```

- **1090–1093:** ถ้าต่อไม่ได้ พิมพ์ `mqttClient.state()` (รหัสตามตารางใน README: `-4` timeout, `-2` เชื่อมไม่ได้, `4` รหัสผิด, `5` ไม่ได้รับอนุญาต) แล้วกลับ
- **1095–1098:** สมัครรับ 4 หัวข้อด้วย QoS 1 (อย่างน้อยหนึ่งครั้ง): `/command`, `/provision-ack`, `/schedule-status`, `/history-ack`
- **1100–1104:** ตั้งเวลาเริ่มส่งข้อมูลย้อนหลังแบบ **สุ่ม** 5–45 วินาทีนับจากนี้ **ทำไม:** ถ้า router ดับทั้งอาคารแล้วกลับมา บอร์ดทุกตัวจะต่อ MQTT ได้พร้อมกัน ถ้าทุกตัวส่งทันทีจะถล่ม broker/Backend การสุ่มกระจายโหลด
- **1109–1111:** ส่ง `/status`, `/state` และ token ทันทีที่ต่อได้ (ทำให้ข้อความ retained ของบอร์ดนี้สดเสมอหลังเชื่อมต่อใหม่ ซึ่งแทนที่ข้อความ LWT `online:false`)

**ฟังก์ชัน `mqttCallback` บรรทัด 1114–1133**

```cpp:1114
void mqttCallback(char *topic, byte *payload, unsigned int length) {
  if (length == 0 || length > 2048) return;
  const String incomingTopic(topic);
  if (incomingTopic == config.mqttTopic + "/schedule-status") {
    DynamicJsonDocument scheduleStatus(384);
    if (deserializeJson(scheduleStatus, payload, length)) return;
    classScheduleConfigured =
        scheduleStatus["classScheduleConfigured"] | false;
    withinClassSchedule =
        scheduleStatus["withinClassSchedule"] | true;
    classScheduleReceivedAt = millis();
    powerMeasurements.outsideSchedule =
        powerMeasurements.acRunning && !isWithinAllowedSchedule();
    updateStatusLeds();
    Serial.printf(
        "Class schedule: configured=%s, within=%s\n",
        classScheduleConfigured ? "yes" : "no",
        withinClassSchedule ? "yes" : "no");
    return;
  }
```

- **1114:** ลายเซ็นที่ PubSubClient กำหนด: `topic` เป็นสตริง C, `payload` เป็นไบต์ **ไม่มี `\0` ปิดท้าย** จึงต้องส่ง `length` ให้ตัวแยก JSON
- **1115:** ทิ้งข้อความว่างหรือใหญ่เกิน 2048 ไบต์
- **1116:** แปลง `topic` เป็น `String` เพื่อใช้ `==` เทียบ
- **1117–1133:** ถ้าเป็น `<topic>/schedule-status`: แยก JSON, อ่าน `classScheduleConfigured` (ห้องมีตารางเรียนในฐานข้อมูลหรือไม่) และ `withinClassSchedule` (ตอนนี้อยู่ในคาบเรียนหรือไม่) ตัวดำเนินการ `|` ของ ArduinoJson (`doc["x"] | false`) คือ "ถ้าไม่มีคีย์/ชนิดไม่ตรง ใช้ค่านี้แทน" จดเวลาที่ได้รับ (`classScheduleReceivedAt`) แล้วคำนวณ `outsideSchedule` และ LED ใหม่ทันที
- **หลักสำคัญ:** callback ทำงานเร็ว ๆ แล้วกลับ งานหนักถูกเลื่อนไปทำใน `loop()`

**บรรทัด 1134–1165**

```cpp:1134
  if (incomingTopic == config.mqttTopic + "/history-ack") {
    // ลบข้อมูลใน flash ใช้เวลา จึงทำต่อใน loop ไม่ทำใน callback
    DynamicJsonDocument acknowledgement(256);
    if (deserializeJson(acknowledgement, payload, length)) return;
    const uint32_t upTo = acknowledgement["upTo"] | 0UL;
    if (upTo > historyPendingAckTs) historyPendingAckTs = upTo;
    historyAckReady = true;
    return;
  }
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

- **1134–1142 (`/history-ack`):** อ่าน `upTo` (ts สูงสุดที่ Backend บันทึกแล้ว) เก็บเข้า `historyPendingAckTs` และตั้ง `historyAckReady` ส่วนการลบ flash ซึ่งช้า (หลายสิบ ms ต่อ sector) ให้ `loop()` ทำ ไม่ทำใน callback (คอมเมนต์บรรทัด 1135 บอกเหตุผล)
- **1143–1157 (`/provision-ack`):** ถ้า `activated == true` และ token ที่ตอบกลับตรงกับ token ที่บอร์ดถืออยู่ → ลบ `prov_token` ออกจาก NVS, ล้างตัวแปร และตั้ง `provisionAckClearReady` เหตุผลที่ตรวจ token ซ้ำ: ป้องกัน ack ของ token ตัวอื่น/ตัวเก่า
- **1158–1165 (`/command`):** ถ้าไม่ใช่หัวข้อ command ก็จบ ถ้าใช่ คัดลอก payload ทีละไบต์ต่อเป็น `String pendingMqttCommand` (เพราะ buffer ของ PubSubClient จะถูกทับด้วยข้อความถัดไป) แล้วตั้ง `mqttCommandReady` ให้ loop ไปทำต่อใน `processMqttCommand()`

**ไฟล์ `rmutt_esp32_air.ino` — `processMqttCommand()` ส่วนที่ตัดสินประเภทคำสั่ง บรรทัด 1223–1251** (เพิ่ม `unprovision`)

```cpp:1223
  const String action = document["action"] | "";
  if (action == "enter_setup") {
    Serial.println("MQTT requested BLE setup mode");
    enterBleReconfiguration("Flutter app requested reconfiguration");
    return;
  }
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
  if (action == "ota") {
    const String url = document["url"] | "";
    if (!otaUrlAllowed(url, config.mqttHost)) {
      Serial.printf("OTA rejected: URL not allowed: %s\n", url.c_str());
      lastOtaError = "url_rejected";
      statusPublishRequested = true;
      return;
    }
    pendingOtaUrl = url;
    otaRequested = true;
    return;
  }
```

- มี action พิเศษ **3 แบบ** ถ้าไม่มี `action` ถือว่าเป็นคำสั่งสถานะแอร์ (`state` object) ซึ่งผ่านการตรวจช่วงอุณหภูมิ (Saijo 18–29 °C, ยี่ห้ออื่น 16–30 °C) และค่าที่รองรับของ Saijo ก่อนจะ `saveAirState()`, `sendCurrentIrState(&previousState)` และ `publishState(commandId)` เพื่อตอบกลับพร้อม `commandId` ให้ Backend จับคู่คำสั่งกับผลได้
- `enter_setup` (1224–1228): เปิด BLE ให้ตั้งค่าใหม่ (เฉพาะแอดมินผ่าน Backend)
- `unprovision` (1229–1239): Backend ส่งมาเมื่อแอดมินลบแอร์ในแอป บรรทัด 1232 อ่าน `deviceId` จากคำสั่ง (`| ""` = ถ้าไม่มีให้เป็นสตริงว่าง) บรรทัด 1233–1236 ถ้าไม่ตรงกับ `config.deviceId` ของบอร์ดนี้ให้พิมพ์ log แล้ว **ไม่ทำอะไร** บรรทัด 1237 ถ้าตรงจึงเรียก `unprovisionAndRestart()` (อธิบายเต็มในหัวข้อ "ล้างบอร์ดเมื่อถูกลบออกจากแอป (unprovision)" ด้านล่าง)
- `ota` (1240–1251): ตรวจ URL ด้วย `otaUrlAllowed` (ถ้าไม่ผ่านบันทึก `lastOtaError = "url_rejected"`) แล้วตั้ง `pendingOtaUrl` + `otaRequested` ให้ loop ทำต่อ

### 4) การอ่าน PZEM และ hysteresis

**บรรทัด 1635–1645 (อ่านและกรองค่าเสีย)**

```cpp:1635
void readPowerMeter() {
  const float voltage = pzem.voltage();
  const float current = pzem.current();
  const float powerWatts = pzem.power();
  const bool valid =
      !isnan(voltage) && !isnan(current) && !isnan(powerWatts);

  if (!valid) {
    if (powerMeasurements.failedSamples < UINT8_MAX) {
      powerMeasurements.failedSamples++;
    }
```

- **1636–1638:** เรียกไลบรารีอ่านแรงดัน กระแส กำลัง แต่ละฟังก์ชันคุย UART กับ PZEM หนึ่งรอบและคืน `float` หรือ `NaN` (Not a Number) ถ้าอ่านพลาด
- **1639–1640:** ถือว่าใช้ได้เมื่อทั้งสามค่าไม่ใช่ NaN (`isnan`)
- **1642–1645:** ถ้าไม่ได้ นับความล้มเหลวติดกัน (กันล้น `uint8_t` ด้วยการเทียบกับ `UINT8_MAX`) ถ้าล้มเหลวติดกันถึง `PZEM_FAILURE_LIMIT` (3) ก็ทำให้ `available`, `acRunning`, `outsideSchedule` เป็น false และตัวนับเป็น 0 (บรรทัด 1646–1655) แล้วขอส่ง status ถ้าสถานะเปลี่ยน และ `return`

**บรรทัด 1660–1671 (บันทึกค่าที่อ่านได้)**

```cpp:1660
  const bool previousAvailable = powerMeasurements.available;
  const bool previousRunning = powerMeasurements.acRunning;
  const bool previousOutsideSchedule = powerMeasurements.outsideSchedule;
  powerMeasurements.available = true;
  powerMeasurements.failedSamples = 0;
  powerMeasurements.voltage = voltage;
  powerMeasurements.current = current;
  powerMeasurements.powerWatts = powerWatts;
  powerMeasurements.energyKwh = pzem.energy();
  powerMeasurements.frequencyHz = pzem.frequency();
  powerMeasurements.powerFactor = pzem.pf();

```

- **1660–1662:** จำค่าเดิมไว้เทียบทีหลังว่า "มีอะไรเปลี่ยนไหม" เพื่อตัดสินว่าต้องส่ง status ทันทีหรือไม่
- **1663–1664:** อ่านสำเร็จ → `available = true` และรีเซ็ตตัวนับความล้มเหลว
- **1665–1671:** เก็บค่า หมายเหตุ: `energy()`, `frequency()`, `pf()` อ่านเพิ่มอีก 3 ครั้ง (รวม 6 ค่า)

**บรรทัด 1672–1693 (hysteresis)**

```cpp:1672
  if (powerWatts >= AC_RUNNING_ON_WATTS) {
    powerMeasurements.stoppedSamples = 0;
    if (powerMeasurements.runningSamples < AC_RUNNING_CONFIRM_SAMPLES) {
      powerMeasurements.runningSamples++;
    }
    if (powerMeasurements.runningSamples >= AC_RUNNING_CONFIRM_SAMPLES) {
      powerMeasurements.acRunning = true;
    }
  } else if (powerWatts <= AC_RUNNING_OFF_WATTS) {
    powerMeasurements.runningSamples = 0;
    if (powerMeasurements.stoppedSamples < AC_RUNNING_CONFIRM_SAMPLES) {
      powerMeasurements.stoppedSamples++;
    }
    if (powerMeasurements.stoppedSamples >= AC_RUNNING_CONFIRM_SAMPLES) {
      powerMeasurements.acRunning = false;
    }
  } else {
    // Values inside the hysteresis band keep the current state but do not
    // count toward either confirmation window.
    powerMeasurements.runningSamples = 0;
    powerMeasurements.stoppedSamples = 0;
  }
```

- **1672–1673:** ถ้ากำลังไฟ ≥ 30 W (`AC_RUNNING_ON_WATTS`): ล้างตัวนับ "หยุด" (เพราะไม่ติดกันแล้ว)
- **1674–1676:** เพิ่มตัวนับ "ทำงาน" จนถึงเพดาน 3 (ไม่ให้เพิ่มเกิน)
- **1677–1679:** ถึง 3 ครั้งติดกัน (≈ 6 วินาที) จึงตั้ง `acRunning = true`
- **1680–1687:** ถ้ากำลังไฟ ≤ 10 W (`AC_RUNNING_OFF_WATTS`): สลับกัน ล้างตัวนับ "ทำงาน" นับ "หยุด" ถึง 3 → `acRunning = false`
- **1688–1693:** ค่าอยู่ระหว่าง 10 ถึง 30 W (**แถบ hysteresis**): ไม่เปลี่ยนสถานะ และเคลียร์ตัวนับทั้งสอง คือต้อง "ติดกัน" จริง ๆ

> [!WHY]
> คอมเพรสเซอร์แอร์ตัด-ต่อเป็นช่วง ๆ กำลังไฟตกจากหลายร้อยวัตต์เหลือแค่พัดลม (หลักสิบวัตต์) การตัดสินจากค่าเดียวจะเห็นแอร์ "ปิด" ทุกครั้งที่คอมเพรสเซอร์พัก และเกณฑ์ขึ้น/ลงที่ต่างกัน (30 และ 10) ป้องกันการกระพริบเมื่อกำลังไฟแกว่งรอบเกณฑ์เดียว การนับ 3 ครั้งติดกันป้องกันสัญญาณรบกวนครั้งเดียว ตรรกะนี้ทำที่บอร์ดเพราะบอร์ดเห็นทุกค่าทุก 2 วินาทีและมีตัวนับอยู่แล้ว ส่งค่าดิบทุกค่าขึ้นเซิร์ฟเวอร์จะเปลืองเครือข่ายและต้องเก็บ state ต่อบอร์ดฝั่งเซิร์ฟเวอร์

**ไฟล์ `rmutt_esp32_air.ino` บรรทัด 1695–1703**

```cpp:1695
  powerMeasurements.outsideSchedule =
      powerMeasurements.acRunning && !isWithinAllowedSchedule();
  accumulateHistorySample();
  oledDisplay.pushPower(powerWatts);
  if (!previousAvailable ||
      previousRunning != powerMeasurements.acRunning ||
      previousOutsideSchedule != powerMeasurements.outsideSchedule) {
    statusPublishRequested = true;
  }
```

- **1695–1696:** `outsideSchedule` จริงเมื่อแอร์ทำงานจริง **และ** ตอนนี้ไม่อยู่ในเวลาที่อนุญาต (`isWithinAllowedSchedule()` เลือกระหว่างตารางเรียนจาก Backend ที่สดไม่เกิน 2 นาที กับตารางรายวันบนบอร์ด)
- **1697:** สะสมค่าเข้าช่วง 5 นาทีของ offline history
- **1698:** `oledDisplay.pushPower(powerWatts)` ส่งค่าวัตต์ให้จอ OLED เก็บไว้วาดกราฟ (ข้างใน `pushPower` เก็บจริงแค่ทุก 5 วินาที แม้เรียกทุก 2 วินาที)
- **1699–1703:** ถ้าค่าที่ Backend ควรรู้เปลี่ยน (เพิ่งพร้อมใช้งาน/สถานะทำงานเปลี่ยน/นอกตารางเปลี่ยน) ขอส่ง status ทันทีแทนที่จะรอ 10 วินาที

### 5) การเข้ารหัสสัญญาณของ `SaijoDenkiAC`

**ไฟล์ `firmware/rmutt_esp32_air/SaijoDenkiAC.cpp` บรรทัด 3–14 (ค่าเวลา)**

```cpp:3
namespace {

constexpr uint16_t kHeaderMark = 9050;
constexpr uint16_t kHeaderSpace = 4550;
constexpr uint16_t kBitMark = 650;
constexpr uint16_t kOneSpace = 1670;
constexpr uint16_t kZeroSpace = 550;
constexpr uint16_t kFooterMark = 650;
constexpr uint32_t kMessageGap = 100000;
constexpr uint16_t kFrequencyKhz = 38;
constexpr uint8_t kSaijoDutyCycle = 50;
constexpr uint16_t kSaijoNoRepeat = 0;
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 3 | `namespace {` | unnamed namespace: ทุกอย่างข้างในมองเห็นเฉพาะไฟล์นี้ ไม่ชนชื่อกับโค้ดอื่น |
| 5 | `kHeaderMark = 9050` | หัวเฟรม: ส่งพาหะ 38 kHz นาน 9050 µs (ส่วน "mark") |
| 6 | `kHeaderSpace = 4550` | แล้วเงียบ 4550 µs (ส่วน "space") บอกตัวรับว่าเฟรมเริ่ม |
| 7 | `kBitMark = 650` | ทุกบิตเริ่มด้วยพาหะ 650 µs |
| 8 | `kOneSpace = 1670` | ถ้าเป็นบิต **1** เงียบ 1670 µs (รวมบิตละ 2320 µs) |
| 9 | `kZeroSpace = 550` | ถ้าเป็นบิต **0** เงียบ 550 µs (รวมบิตละ 1200 µs) |
| 10 | `kFooterMark = 650` | ท้ายเฟรมส่งพาหะ 650 µs เป็นตัวปิดบิตสุดท้าย |
| 11 | `kMessageGap = 100000` | เว้นช่องว่าง 100 ms หลังจบเฟรม |
| 12 | `kFrequencyKhz = 38` | ความถี่พาหะ 38 kHz |
| 13 | `kSaijoDutyCycle = 50` | duty cycle 50% (พาหะเปิด 50% ของคาบ) |
| 14 | `kSaijoNoRepeat = 0` | ไม่ส่งซ้ำ (ส่งเฟรมเดียว) |

เฟรมหนึ่งยาวราว 100–180 ms ขึ้นกับว่ามีบิต 1 มากแค่ไหน (72 บิต × 1200 ถึง 2320 µs + หัวเฟรม ~13.6 ms) ค่าเวลาทั้งหมดได้จากการจับสัญญาณรีโมตจริง ไม่ใช่สเปกจากผู้ผลิต

**บรรทัด 16–18 และ 60–69 (ตารางเฟรมและตัวส่ง)**

```cpp:16
// Captured from the user's Saijo Denki remote. Bytes are sent LSB-first.
const uint8_t kPowerOff[] = {0x05, 0x00, 0x2D, 0x80, 0x54, 0x91, 0x54, 0xFF, 0xAD};
const uint8_t kPowerOn[] = {0x05, 0x09, 0x2D, 0x80, 0x94, 0x91, 0x94, 0xFF, 0xC4};
```

```cpp:60
void SaijoDenkiAC::sendState(const uint8_t state[kStateLength]) {
  irsend_.sendGeneric(
      kHeaderMark, kHeaderSpace,
      kBitMark, kOneSpace,
      kBitMark, kZeroSpace,
      kFooterMark, kMessageGap,
      state, kStateLength,
      kFrequencyKhz, false,
      kSaijoNoRepeat, kSaijoDutyCycle);
}
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 16 | คอมเมนต์ | ไบต์ถูกส่ง **LSB-first** คือส่งบิตน้อยสุด (บิต 0) ของแต่ละไบต์ก่อน |
| 17 | `kPowerOff[] = {0x05, 0x00, 0x2D, 0x80, 0x54, 0x91, 0x54, 0xFF, 0xAD}` | อาร์เรย์ 9 ไบต์ = 72 บิต คือเฟรม "ปิดเครื่อง" ที่จับจากรีโมตจริง (`const` อยู่ใน flash) |
| 18 | `kPowerOn[]` | เฟรม "เปิดเครื่อง" ต่างจากปิดที่ไบต์ 1, 4, 6, 8 |
| 60 | `void SaijoDenkiAC::sendState(const uint8_t state[kStateLength])` | เมธอด private ที่ส่งเฟรมหนึ่งเฟรม `kStateLength = 9` ไบต์ (กำหนดใน `.h`) |
| 61 | `irsend_.sendGeneric(` | เรียกตัวส่งทั่วไปของ IRremoteESP8266: ประกอบรูปคลื่นจากพารามิเตอร์ที่เราให้ |
| 62 | `kHeaderMark, kHeaderSpace,` | รูปหัวเฟรม |
| 63 | `kBitMark, kOneSpace,` | mark/space ของบิต 1 |
| 64 | `kBitMark, kZeroSpace,` | mark/space ของบิต 0 |
| 65 | `kFooterMark, kMessageGap,` | ท้ายเฟรมและช่องว่างหลังเฟรม |
| 66 | `state, kStateLength,` | ข้อมูลและจำนวนไบต์ |
| 67 | `kFrequencyKhz, false,` | 38 kHz และ `MSBfirst = false` คือส่ง LSB ก่อน |
| 68 | `kSaijoNoRepeat, kSaijoDutyCycle);` | ไม่ส่งซ้ำ, duty 50% |

ส่วนที่เหลือของไฟล์เป็นตารางเฟรมตามฟังก์ชัน: `kDry`, `kFanOnly`, `kCool` (โหมด), `kFanAuto/1/2/3/Turbo` (พัดลม; ไบต์ 3 ต่างกัน เช่น Level1 = `0xC4`, Level2 = `0xC2`, Level3 = `0xC6`, Turbo = `0xC1`), `kSwingAuto/1..5` (ไบต์ 5 ต่างกัน) และ `kTemp18..kTemp29` (ไบต์ 2 กับ 4 และ 6 ต่างกัน) ไบต์สุดท้ายของทุกเฟรมแตกต่างกันตามเนื้อหา น่าจะเป็น checksum แต่ **โปรเจคยังไม่ได้ถอดสูตร** (README_SAIJO_DENKI_TH.txt บอกว่าต้องจับข้อมูลเพิ่มเพื่อหาโครงบิตและ checksum) จึงเก็บเฟรมสำเร็จรูปแบบ "ค้นตาราง" แทนการคำนวณ `setTemperature/setFan/setSwing` ใช้ `switch` เลือกตัวชี้ไปยังเฟรม แล้ว `sendState(state)` คืน `false` เมื่อค่าไม่อยู่ในช่วงที่รองรับ (เช่นอุณหภูมิ 17 หรือ 30)

### 6) `history_log.h`: checksum, `append`, `nextBatch`, `acknowledge`

**ไฟล์ `firmware/rmutt_esp32_air/history_log.h` บรรทัด 52–66**

```cpp:52
inline uint8_t historyChecksum(const HistoryRecord &record) {
  const uint8_t *bytes = reinterpret_cast<const uint8_t *>(&record);
  uint8_t sum = 0x5A;
  for (size_t index = 0; index < sizeof(HistoryRecord) - 1; index++) {
    sum = static_cast<uint8_t>((sum << 1) | (sum >> 7)) ^ bytes[index];
  }
  return sum;
}

inline bool historyRecordValid(const HistoryRecord &record) {
  return record.magic == HISTORY_MAGIC &&
         record.ts != 0xFFFFFFFFUL &&
         record.ts != 0 &&
         record.checksum == historyChecksum(record);
}
```

- **52–59 `historyChecksum`:** แปลง record เป็นอาร์เรย์ไบต์ (`reinterpret_cast`) เริ่มค่าที่ `0x5A` แล้ววนไบต์ 0–30 (ไม่รวมไบต์ checksum เอง = `sizeof - 1`) แต่ละรอบ "หมุนซ้าย 1 บิต" (`(sum << 1) | (sum >> 7)`) แล้ว XOR กับไบต์ถัดไป การหมุนทำให้ลำดับไบต์มีผลต่อผลลัพธ์ (ต่างจากการบวกธรรมดา) เหมาะจับข้อมูลเสียหรือเขียนไม่ครบ (ตัวอย่างไฟดับกลางการเขียน)
- **61–66 `historyRecordValid`:** รายการต้องผ่านสี่เงื่อนไข: `magic == 0xA5`, `ts` ไม่ใช่ `0xFFFFFFFF` (ค่าของ flash ที่ว่าง) และไม่เป็น 0, และ checksum ตรง ถ้าพาร์ติชันเคยเก็บข้อมูลอื่น (ขยะ) จะแทบไม่ผ่านทั้งสี่ข้อ
- `historyRecordBlank` (68–74) ตรวจว่าทั้ง 32 ไบต์เป็น `0xFF` (สถานะหลัง erase) ใช้แยก "ว่างจริง" ออกจาก "มีขยะ"

**`append` บรรทัด 119–139**

```cpp:119
  bool append(HistoryRecord record) {
    if (!ready_) return false;
    // เวลาถอยหลัง (เช่น NTP แก้เวลา) ไม่เก็บ เพราะจะส่งผิดลำดับ
    if (record.ts <= newestTs_ || record.ts <= ackedTs_) return false;
    record.magic = HISTORY_MAGIC;
    record.checksum = historyChecksum(record);

    size_t slot = writeSlot_;
    if (slot % HISTORY_RECORDS_PER_SECTOR == 0) {
      if (!prepareSector(slot / HISTORY_RECORDS_PER_SECTOR)) return false;
    } else {
      HistoryRecord existing;
      if (!readSlot(slot, existing)) return false;
      if (!historyRecordBlank(existing)) {
        // ช่องถัดไปไม่ว่าง (เช่นมีขยะจากพาร์ติชันเดิม) ข้ามไปต้น sector ถัดไป
        const size_t nextSector =
            (slot / HISTORY_RECORDS_PER_SECTOR + 1) % sectors_;
        slot = nextSector * HISTORY_RECORDS_PER_SECTOR;
        if (!prepareSector(nextSector)) return false;
      }
    }
```

| บรรทัด | ความหมาย |
|---|---|
| 120 | ยังไม่พร้อม (เริ่มต้นไม่สำเร็จ) ไม่รับ |
| 121–122 | **ปฏิเสธเวลาถอยหลัง:** ถ้า `ts` ไม่มากกว่ารายการใหม่สุดที่มี หรือไม่มากกว่า ts ที่ ack แล้ว (เช่น NTP แก้เวลาย้อนหลัง) เพราะจะส่งผิดลำดับ และ `acknowledge(upTo)` ที่ใช้ "ลบทุกอย่างที่ ts ≤ upTo" จะลบผิด |
| 123–124 | ใส่ `magic` และคำนวณ `checksum` (ต้องคำนวณหลังกรอกทุกฟิลด์) |
| 126 | `slot = writeSlot_` ช่องที่จะเขียน (ตำแหน่งถัดจากรายการใหม่สุด) |
| 127–128 | ถ้าเป็นช่องแรกของ sector (`slot % 128 == 0`) เรียก `prepareSector` ลบ sector ก่อน (ถ้ามีข้อมูลเดิม) |
| 129–139 | ถ้าอยู่กลาง sector ให้อ่านช่องนั้นดู ถ้าไม่ว่าง (เช่นมีขยะ) ข้ามไปต้น sector ถัดไปแล้วเตรียม sector นั้นแทน |

**บรรทัด 140–149**

```cpp:140

    if (!storage_.write(slot * sizeof(HistoryRecord), &record,
                        sizeof(HistoryRecord))) {
      return false;
    }
    writeSlot_ = (slot + 1) % slots_;
    newestTs_ = record.ts;
    pending_++;
    return true;
  }
```

- **141–144:** เขียน 32 ไบต์ที่ offset `slot * 32` ถ้าเขียนไม่สำเร็จคืน false
- **145:** เลื่อนตำแหน่งเขียนไปช่องถัดไป ใช้ `% slots_` เพื่อวนกลับไปต้นพาร์ติชันเมื่อเต็ม (นี่คือส่วนที่ทำให้เป็น ring buffer)
- **146–148:** อัปเดต ts ใหม่สุดและจำนวนค้างส่ง

**`prepareSector` บรรทัด 227–240** (เรียกก่อนเขียนช่องแรกของ sector)

```cpp:227
  bool prepareSector(size_t sector) {
    if (!readSector(sector)) return false;
    bool dirty = false;
    for (size_t index = 0; index < HISTORY_RECORDS_PER_SECTOR; index++) {
      const HistoryRecord &record = buffer_[index];
      if (!historyRecordBlank(record)) dirty = true;
      if (historyRecordValid(record) && record.ts > ackedTs_) {
        lost_++;
        if (pending_ > 0) pending_--;
      }
    }
    if (!dirty) return true;
    return storage_.eraseSector(sector * HISTORY_SECTOR_BYTES);
  }
```

อ่านทั้ง sector มาไว้ใน `buffer_` ถ้ามีรายการที่ valid และยังไม่ถูก ack (`ts > ackedTs_`) แปลว่ากำลังจะทับข้อมูลที่ยังไม่ได้ส่ง ก็นับเป็น `lost_` และลด `pending_` จากนั้นลบ sector ถ้า "สกปรก" ถ้าสะอาดอยู่แล้วไม่ต้องลบ (ลดการสึกหรอ)

**`nextBatch` บรรทัด 152–173**

```cpp:152
  size_t nextBatch(HistoryRecord *out, size_t max) {
    if (!ready_ || max == 0) return 0;
    size_t count = 0;
    forEachSlot([&](size_t, const HistoryRecord &record) {
      if (!historyRecordValid(record) || record.ts <= ackedTs_) return;
      if (count < max) {
        out[count++] = record;
      } else if (record.ts < out[count - 1].ts) {
        out[count - 1] = record;
      } else {
        return;
      }
      // insertion sort ตัวล่าสุดเข้าที่
      for (size_t index = count - 1;
           index > 0 && out[index].ts < out[index - 1].ts; index--) {
        const HistoryRecord swap = out[index];
        out[index] = out[index - 1];
        out[index - 1] = swap;
      }
    });
    return count;
  }
```

เลือก `max` รายการที่ **เก่าสุดที่ยังไม่ได้ ack** เรียงจากเก่าไปใหม่ โดยไม่ต้องเรียงทั้งพาร์ติชัน: ผ่านทุกช่อง (`forEachSlot` อ่านทีละ sector ใส่ `buffer_`) ข้ามรายการเสีย/ที่ ack แล้ว ถ้า `out` ยังไม่เต็มก็ใส่ท้าย ถ้าเต็มแล้วและรายการนี้เก่ากว่าตัวท้ายสุด (ใหม่สุดในกลุ่ม) ก็แทนที่ตัวนั้น (บรรทัด 159–160) ไม่เช่นนั้นข้าม แล้ว insertion sort (บรรทัด 165–170) เลื่อนตัวล่าสุดที่ใส่เข้าไปให้อยู่ถูกลำดับ ใช้หน่วยความจำคงที่ ไม่ต้องจัดสรรเพิ่ม

**`acknowledge` บรรทัด 177–201**

```cpp:177
  bool acknowledge(uint32_t upToTs) {
    if (!ready_) return false;
    if (upToTs > ackedTs_) ackedTs_ = upToTs;

    pending_ = 0;
    for (size_t sector = 0; sector < sectors_; sector++) {
      bool hasData = false;
      bool allAcked = true;
      if (!readSector(sector)) return false;
      for (size_t index = 0; index < HISTORY_RECORDS_PER_SECTOR; index++) {
        const HistoryRecord &record = buffer_[index];
        if (historyRecordBlank(record)) continue;
        hasData = true;
        if (historyRecordValid(record) && record.ts > ackedTs_) {
          allAcked = false;
          pending_++;
        }
      }
      if (hasData && allAcked) {
        if (!storage_.eraseSector(sector * HISTORY_SECTOR_BYTES)) return false;
        erasedSectors_++;
      }
    }
    return true;
  }
```

- **179:** ยกระดับ `ackedTs_` ให้สูงขึ้นเท่านั้น (ไม่ลดย้อน)
- **181–199:** ผ่านทุก sector: อ่านมาไว้ใน buffer, ดูว่า "มีข้อมูล" (`hasData`) และ "ทุกรายการที่ valid มี ts ≤ ackedTs" (`allAcked`) พร้อมนับ `pending_` ใหม่ไปในตัว
- **195–198:** sector ที่มีข้อมูลและ ack หมดแล้วจะถูกลบทั้ง sector ถ้าไม่เหลือค้างเลย ทุก sector ที่มีข้อมูลก็ถูกลบจนว่าง

> [!WHY]
> **ทำไมต้อง "ส่ง → รอ ack → ลบ" ไม่ลบทันทีที่ส่ง:** MQTT QoS 0 ที่บอร์ดใช้ส่ง `/history` ไม่รับประกันว่าข้อความถึง ถ้าลบทันที ข้อมูลที่หายระหว่างทางไม่มีทางกู้ ระบบจึงลบเมื่อ Backend ตอบว่า "บันทึกถึง ts นี้แล้ว" เท่านั้น ถ้าไม่ได้คำตอบก็ส่งซ้ำ และ Backend ต้องรับซ้ำได้โดยไม่ซ้ำ (idempotent) ลำดับการลบแล้วจึงบันทึก `hist_ack` ลง NVS ปลอดภัยทั้งสองทิศ ถ้าไฟดับหลังลบก่อนบันทึก NVS: ไม่มีข้อมูลให้ส่งซ้ำ ถ้าบันทึก NVS แล้วแต่ยังไม่ลบ: รายการ ts ≤ ack ถูกกรองออกอยู่ดี

### 7) OTA: `ota_update.h` และ `performOtaUpdate()`

**ไฟล์ `firmware/rmutt_esp32_air/ota_update.h` บรรทัด 24–39**

```cpp:24
constexpr size_t OTA_MAX_URL_LENGTH = 300;

inline bool otaUrlAllowed(const String &url, const String &host) {
  if (host.isEmpty() || url.length() > OTA_MAX_URL_LENGTH) return false;
  const String prefix = "https://" + host + "/firmware/";
  if (!url.startsWith(prefix) || !url.endsWith(".bin")) return false;
  if (url.indexOf("..") >= 0) return false;
  for (size_t index = prefix.length(); index < url.length(); index++) {
    const char c = url.charAt(index);
    const bool ok = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
                    (c >= '0' && c <= '9') || c == '.' || c == '_' ||
                    c == '-';
    if (!ok) return false;
  }
  return true;
}
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 24 | `OTA_MAX_URL_LENGTH = 300` | จำกัดความยาว URL กัน input ใหญ่ผิดปกติ |
| 26 | `inline bool otaUrlAllowed(const String &url, const String &host)` | `inline` ให้นิยามในไฟล์ `.h` ได้โดยไม่ชนกันเมื่อถูก include หลายที่; `const String &` ส่งแบบอ้างอิง ไม่คัดลอก |
| 27 | `if (host.isEmpty() ... url.length() > OTA_MAX_URL_LENGTH) return false` | (เชื่อมสองเงื่อนไขด้วย "หรือ") ไม่มี host หรือ URL ยาวเกิน 300 → ปฏิเสธ |
| 28 | `prefix = "https://" + host + "/firmware/"` | URL ต้องขึ้นต้นด้วย **MQTT host เดิมของบอร์ด** (host เดียวกับที่บอร์ดเชื่อถืออยู่แล้ว) ตามด้วย `/firmware/` |
| 29 | `if (!url.startsWith(prefix) ... !url.endsWith(".bin")) return false` | (เชื่อมด้วย "หรือ") ต้องขึ้นต้นตาม prefix และลงท้าย `.bin` |
| 30 | `url.indexOf("..") >= 0` | ห้ามมี `..` กัน path traversal (ไต่ออกนอกโฟลเดอร์) |
| 31–37 | วนตรวจทุกตัวอักษรหลัง prefix | อนุญาตเฉพาะ `A–Z a–z 0–9 . _ -` ตัดอักขระพิเศษ เช่น `/ ? # %` ที่อาจใช้หลบเลี่ยงการตรวจ |
| 38 | `return true` | ผ่านทุกด่าน |

**บรรทัด 41–68**

```cpp:41
inline bool otaPartitionAvailable() {
  return esp_ota_get_next_update_partition(nullptr) != nullptr;
}

// คืนข้อความว่างเมื่อสำเร็จ (ผู้เรียกต้องรีบูตเอง) หรือข้อความบอกสาเหตุที่ล้มเหลว
inline String runHttpsOta(
    const String &url,
    const char *caCert,
    const char *currentVersion) {
  if (!otaPartitionAvailable()) {
    return "no_ota_partition: flash partitions.csv via USB once";
  }
  WiFiClientSecure client;
  client.setCACert(caCert);
  httpUpdate.rebootOnUpdate(false);
  httpUpdate.setFollowRedirects(HTTPC_DISABLE_FOLLOW_REDIRECTS);
  const t_httpUpdate_return result =
      httpUpdate.update(client, url, currentVersion);
  switch (result) {
    case HTTP_UPDATE_OK:
      return "";
    case HTTP_UPDATE_NO_UPDATES:
      return "no_updates";
    default:
      return String("failed(") + httpUpdate.getLastError() + "): " +
             httpUpdate.getLastErrorString();
  }
}
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 41–43 | `otaPartitionAvailable()` | `esp_ota_get_next_update_partition(nullptr)` คืนพาร์ติชันที่ใช้เขียนรอบถัดไป ถ้าเป็น `nullptr` แปลว่าตารางพาร์ติชันไม่มีช่อง OTA ที่สอง |
| 46–49 | `runHttpsOta(url, caCert, currentVersion)` | คืน `String`: ว่าง = สำเร็จ ไม่ว่าง = ข้อความสาเหตุ (ผู้เรียกเป็นคนรีบูต) |
| 50–52 | ไม่มีช่อง OTA | คืนข้อความให้แฟลช `partitions.csv` ผ่าน USB ก่อน |
| 53–54 | `WiFiClientSecure client; client.setCACert(caCert)` | สร้างการเชื่อมต่อ TLS ที่ตรวจเซิร์ฟเวอร์กับใบรากที่ฝังไว้ (สร้างเป็นตัวแปรโลคัล หมดฟังก์ชันก็ถูกทำลายและคืนหน่วยความจำ) |
| 55 | `httpUpdate.rebootOnUpdate(false)` | ไม่ให้ไลบรารีรีบูตเอง ให้ผู้เรียกควบคุม |
| 56 | `setFollowRedirects(HTTPC_DISABLE_FOLLOW_REDIRECTS)` | ไม่ตาม redirect (กัน URL ที่ผ่านการตรวจถูกเด้งไปที่อื่น) |
| 57–58 | `httpUpdate.update(client, url, currentVersion)` | ดาวน์โหลด `.bin` แล้วเขียนลงพาร์ติชัน OTA ที่ว่าง ส่งเวอร์ชันปัจจุบันไปในส่วนหัวของคำขอ ถ้าไฟล์สมบูรณ์ ไลบรารีตั้ง `otadata` ให้บูตจากช่องใหม่ |
| 59–67 | `switch (result)` | `HTTP_UPDATE_OK` → `""`; `HTTP_UPDATE_NO_UPDATES` → `"no_updates"`; อย่างอื่น → `failed(รหัส): ข้อความ` |

**ไฟล์ `rmutt_esp32_air.ino` บรรทัด 1553–1579**

```cpp:1553
void performOtaUpdate() {
  otaRequested = false;
  const String url = pendingOtaUrl;
  pendingOtaUrl = "";
  Serial.printf("OTA: downloading %s\n", url.c_str());
  if (!ensureClockSynced()) {
    lastOtaError = "clock_not_synced";
    statusPublishRequested = true;
    return;
  }
  // ปิดการเชื่อมต่อ MQTT (TLS) ก่อน หน่วยความจำไม่พอเปิด TLS สองชุดพร้อมกัน
  // วงรอบ loop จะต่อ MQTT กลับเองถ้าอัปเดตไม่สำเร็จ
  if (mqttClient.connected()) mqttClient.disconnect();
  secureClient.stop();

  const String error = runHttpsOta(url, LETSENCRYPT_CA, FIRMWARE_VERSION);
  if (error.isEmpty()) {
    Serial.println("OTA: update written, restarting");
    delay(300);
    ESP.restart();
    return;
  }
  lastOtaError = error.substring(0, 100);
  Serial.printf("OTA failed: %s\n", lastOtaError.c_str());
  statusPublishRequested = true;
  lastMqttReconnectAttempt = 0;
}
```

- **1554–1556:** เคลียร์ธงทันที (กันทำซ้ำ) และย้าย URL ไปตัวแปรโลคัล
- **1558–1562:** ต้องมีเวลาจริงก่อน มิฉะนั้นการตรวจวันหมดอายุของใบรับรองล้ม ถ้าไม่ได้บันทึก `clock_not_synced` ใน `lastOtaError` ซึ่งไปปรากฏในฟิลด์ `otaError` ของ `/status`
- **1565–1566:** ปิดการเชื่อมต่อ MQTT (TLS) และ `secureClient.stop()` ก่อนดาวน์โหลด เพราะ RAM ของ ESP32 ไม่พอเปิด TLS สองชุดพร้อมกัน (คอมเมนต์ในโค้ด) ถ้า OTA ล้ม `loop()` จะต่อ MQTT ใหม่เอง (`lastMqttReconnectAttempt = 0` ที่บรรทัด 1578 ทำให้ลองต่อทันที)
- **1568–1574:** เรียก `runHttpsOta` ถ้าว่าง (สำเร็จ) รอ 300 ms ให้ log ออก แล้ว `ESP.restart()` จะบูตเข้าเฟิร์มแวร์ใหม่
- **1575–1578:** ล้มเหลว: เก็บข้อความ (ตัดไม่เกิน 100 ตัวอักษร) ใส่ `lastOtaError` ขอส่ง status และทำงานต่อด้วยเฟิร์มแวร์เดิม

> [!WHY]
> **ป้องกันเฟิร์มแวร์ปลอมสามชั้น** (ตามคอมเมนต์ในหัวไฟล์ `ota_update.h`): (1) คำสั่ง OTA มาทาง `/command` ซึ่งตาม ACL ของ Mosquitto Dynamic Security มีแต่ Backend ที่ส่งได้ (2) URL ต้องอยู่ใต้ `https://<MQTT host>/firmware/` ชี้ไปเซิร์ฟเวอร์อื่นไม่ได้ (host นี้คือชื่อ ts.net ตามค่าเริ่มต้น ดาวน์โหลดผ่าน Funnel 443 → Caddy หรือชื่อ DuckDNS เมื่อต่อตรง) (3) การดาวน์โหลดตรวจใบรับรอง HTTPS กับใบรากที่ฝังไว้ ผลคือแม้ใครแอบส่งข้อความ OTA ได้ ก็บังคับให้บอร์ดโหลดจากเซิร์ฟเวอร์ของเราเท่านั้น และไฟล์ที่เสียระหว่างทางจะไม่ถูกสลับไปใช้ **ข้อจำกัดที่ควรรู้:** โค้ดไม่มีลายเซ็นดิจิทัลของไฟล์ .bin เอง และไม่ได้เขียนกลไกยืนยันหลังบูต/rollback อัตโนมัติ ความปลอดภัยจึงอยู่ที่ช่องทางและเซิร์ฟเวอร์

### 8) การตัดสินว่ามีคน: `updateOccupancy()`

**ไฟล์ `firmware/rmutt_esp32_occupancy/rmutt_esp32_occupancy.ino` บรรทัด 975–996**

```cpp:975
void updateOccupancy() {
  const bool previousAvailable = radarAvailable;
  const bool previousOccupied = occupied;

  // engineeringRetrieved() คืนค่า true ครั้งเดียวต่อหนึ่งเฟรมที่อ่านได้
  // จึงใช้เป็นเงื่อนไข "พร้อมใช้งาน" ตรง ๆ ไม่ได้ ต้องจำเวลาที่ได้ข้อมูลล่าสุด
  const bool freshFrame =
      radarInitialised &&
      radarEngineeringEnabled &&
      radar.isConnected() &&
      radar.engineeringRetrieved();
  if (freshFrame) {
    lastRadarDataAt = millis();
    bool detected = false;
    for (uint8_t gate = FIRST_GATE; gate <= LAST_GATE; gate++) {
      if (radar.stationaryEnergyAtGate(gate) > STATIC_ENERGY_THRESHOLD) {
        detected = true;
        break;
      }
    }
    lastRadarDetected = detected;
  }
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 976–977 | `previousAvailable`, `previousOccupied` | เก็บค่าก่อนหน้าเพื่อเทียบตอนท้ายว่า "เปลี่ยนไหม" |
| 981–985 | `freshFrame = a && b && c && d` | มีเฟรมใหม่เมื่อ: เรดาร์เริ่มแล้ว, เปิด Engineering mode แล้ว, `radar.isConnected()` (ไลบรารีเพิ่งได้เฟรมจากเรดาร์ในช่วงสั้น ๆ ที่ผ่านมา) และ `engineeringRetrieved()` คืน true `&&` ลัดวงจร (short-circuit) ดังนั้น `engineeringRetrieved()` ซึ่ง "กินธงเฟรม" ถูกเรียกเฉพาะเมื่อสามข้อแรกจริง |
| 986–987 | `if (freshFrame) { lastRadarDataAt = millis();` | จำเวลาที่ได้ข้อมูลล่าสุด |
| 988 | `bool detected = false;` | สมมติว่าไม่มีคนก่อน |
| 989 | `for (uint8_t gate = FIRST_GATE; gate <= LAST_GATE; gate++)` | วนเกต 0–8 (9 เกต) |
| 990 | `radar.stationaryEnergyAtGate(gate) > STATIC_ENERGY_THRESHOLD` | ถามพลังงานนิ่ง (0–100) ของเกตนี้ เทียบ **มากกว่า** 15 |
| 991–992 | `detected = true; break;` | เจอเกตเดียวก็พอ หยุดวนทันที |
| 995 | `lastRadarDetected = detected;` | เก็บผลของเฟรมล่าสุด |

**บรรทัด 998–1011**

```cpp:998
  radarAvailable =
      radarInitialised &&
      radarEngineeringEnabled &&
      lastRadarDataAt != 0 &&
      millis() - lastRadarDataAt < RADAR_DATA_TIMEOUT_MS;
  occupied = radarAvailable && lastRadarDetected;
  if (previousAvailable != radarAvailable || previousOccupied != occupied) {
    statusPublishRequested = true;
    Serial.printf(
        "Room occupancy: %s (radar %s)\n",
        occupied ? "occupied" : "vacant",
        radarAvailable ? "available" : "unavailable");
  }
}
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 998–1002 | `radarAvailable = init && engineering && lastRadarDataAt != 0 && millis() - lastRadarDataAt < 3000` | เรดาร์ถือว่าพร้อมเมื่อมีเฟรมภายใน 3 วินาทีที่ผ่านมา `lastRadarDataAt != 0` กันกรณียังไม่เคยได้เฟรมเลย |
| 1003 | `occupied = radarAvailable && lastRadarDetected` | **มีคน = เรดาร์พร้อม และเฟรมล่าสุดเห็นเกตที่เกินเกณฑ์** ถ้าเรดาร์ไม่พร้อม จะรายงาน `occupied = false` แต่แอปดูจาก `radarAvailable` จึงแสดง "ไม่พร้อม" ไม่ใช่ "ว่าง" |
| 1004–1010 | `if (previousAvailable != ... ) { statusPublishRequested = true; Serial.printf(...) }` | เมื่อใดสองค่านี้เปลี่ยน ขอส่ง status ทันทีและพิมพ์ log เช่น `Room occupancy: occupied (radar available)` |

> [!NOTE]
> ฟังก์ชันนี้ถูกเรียกทุก 250 ms แต่เรดาร์ส่งเฟรมราว ๆ 10 ครั้งต่อวินาที จึงมีบางรอบที่ไม่มีเฟรมใหม่ รอบเหล่านั้น `freshFrame` เป็น false และฟังก์ชันใช้ค่าที่จำไว้ (`lastRadarDetected`) ต่อ การออกแบบนี้คือสิ่งที่ทำให้สถานะไม่กระพริบ

## หลักการเขียนโค้ดที่ใช้ในส่วนนี้

### 1) ตัวจับเวลาแบบไม่บล็อก (non-blocking timer)

**คืออะไร:** แทนที่จะ `delay()` รอ ให้จำเวลา `millis()` ครั้งล่าสุดแล้วเทียบทุกรอบ **ใช้ที่ไหน:** ทุกที่ใน `rmutt_esp32_air.ino` และ `rmutt_esp32_occupancy.ino` เช่น `lastPzemReadAt`, `lastStatusAt`, `lastMqttReconnectAttempt`, `lastPresenceReadAt` **ทำไม:** บอร์ดต้องทำหลายอย่างพร้อมกัน (ฟัง MQTT, อ่านเซ็นเซอร์, กระพริบไฟ) ถ้าใช้ `delay(2000)` ระหว่างอ่าน PZEM จะฟังคำสั่งไม่ทัน การเทียบเวลาแบบ `static_cast<int32_t>(millis() - deadline) >= 0` ยังถูกต้องเมื่อ `millis()` วนรอบทุก ~49.7 วัน

### 2) Callback ทำสั้น ๆ แล้วใช้ flag ส่งต่อให้ `loop()`

**ใช้ที่ไหน:** `ConfigCallbacks::onWrite` → `configReady`; `mqttCallback` → `mqttCommandReady`, `otaRequested`, `historyAckReady`, `provisionAckClearReady` **ทำไม:** callback ถูกเรียกจาก BLE task หรือใน `mqttClient.loop()` งานช้า (ทดสอบ Wi-Fi 15 วินาที, ลบ flash, ดาวน์โหลด OTA) ในนั้นจะบล็อกการรับส่งและอาจทำให้ stack ล้ม จึงแค่จดว่า "มีงาน" แล้วให้ลูปหลักทำในจังหวะที่ควบคุมได้ ลดปัญหาการเข้าถึงตัวแปรจากหลาย task พร้อมกัน

### 3) Hysteresis และการยืนยันหลายครั้ง (debounce)

**ใช้ที่ไหน:** `readPowerMeter()` (30 W ขึ้น / 10 W ลง / ติดกัน 3 ครั้ง) **ทำไม:** สัญญาณจริงมีสัญญาณรบกวนและแกว่งใกล้เกณฑ์ ถ้าเกณฑ์เดียวสถานะจะกระพริบ และการส่ง status ซ้ำ ๆ ทำให้ล้นเครือข่าย ช่องว่างระหว่างเกณฑ์ทำให้ต้องเปลี่ยน "ชัดเจน" จึงสลับ

### 4) ตัดสินที่ขอบ (edge) ส่งเฉพาะข้อสรุป

**ใช้ที่ไหน:** `acRunning` ตัดสินที่บอร์ดแอร์, `occupied` ตัดสินที่บอร์ดตรวจจับคน (ส่งเป็น boolean ไม่ส่งค่ารายเกต) **ทำไม:** ลดทราฟฟิก ลดภาระ Backend และคงความถูกต้องแม้เครือข่ายขาด เพราะตรรกะที่ต้องมี "ประวัติค่าติดกัน" ใช้ตัวแปรในบอร์ดได้เลย

### 5) State เปรียบเทียบก่อน-หลัง (diff-based sending)

**ใช้ที่ไหน:** `sendSaijoCurrentIrState(previousState)` **ทำไม:** เฟรม IR ของ Saijo เป็นเฟรมสำเร็จรูปต่อหนึ่งปุ่ม การส่งเฉพาะสิ่งที่เปลี่ยนทำให้ส่ง "ปุ่มที่ผู้ใช้กดจริง" และไม่ส่งซ้ำเมื่อไม่มีอะไรเปลี่ยน (ซึ่งอาจสลับสถานะบางอย่างของแอร์โดยไม่ตั้งใจ)

### 6) Retained message และ LWT

**ใช้ที่ไหน:** `/status` และ `/state` publish แบบ retained; LWT ตั้งไว้ใน `connect()` **ทำไม:** ผู้สมัครรับข้อมูลใหม่ (Backend หลังรีสตาร์ต, แอปที่เพิ่งเปิด) ได้ค่าล่าสุดทันทีโดยไม่ต้องรอรอบต่อไป และ LWT ทำให้รู้ว่าบอร์ดหลุดแม้บอร์ดเองไม่ได้ส่งอะไรออกมา

### 7) ส่ง → รอ ack → ลบ และส่งซ้ำได้ (at-least-once + idempotent)

**ใช้ที่ไหน:** `processHistoryUpload` / `applyHistoryAck` / `HistoryLog::acknowledge` **ทำไม:** เครือข่ายไม่น่าเชื่อถือ ถ้าลบก่อนยืนยันข้อมูลอาจหาย ถ้าส่งซ้ำได้ ฝั่งรับต้องไม่นับซ้ำ (Backend ข้ามรายการที่มีแล้ว ตามคอมเมนต์ในโค้ด) ผลคือ "ไม่หาย" โดยแลกกับความซับซ้อนเล็กน้อย

### 8) Jitter (หน่วงแบบสุ่ม)

**ใช้ที่ไหน:** `connectMqtt()` สุ่ม 5–45 วินาทีก่อนส่งข้อมูลย้อนหลัง **ทำไม:** กัน "thundering herd" บอร์ดหลายสิบตัวกลับมาพร้อมกันหลังไฟ/เน็ตดับแล้วส่งพร้อมกันหมด

### 9) Dependency injection ด้วย template + แยกตรรกะออกจากฮาร์ดแวร์

**ใช้ที่ไหน:** `HistoryLog<Storage>` ใน `history_log.h` รับ `PartitionFlash` (บนบอร์ด) หรือ `FakeFlash` (ในเทสต์) **ทำไม:** ทดสอบตรรกะซับซ้อนบนคอมพิวเตอร์ได้โดยไม่ต้องมีบอร์ด และเคสหายาก (ไฟดับ, วนรอบ, ขยะในพาร์ติชัน) จำลองได้

### 10) ป้องกันเป็นชั้น (defense in depth) และ fail-safe

**ใช้ที่ไหน:** OTA (ช่องทาง MQTT + ตรวจ URL + ตรวจใบรับรอง + ช่อง A/B), Wi-Fi-only mode (`keepsServerAssignment`), ทดสอบ Wi-Fi ก่อนบันทึกลง NVS (`processPendingConfig`), token ครั้งเดียว **ทำไม:** แต่ละชั้นอาจพลาดได้ ผู้โจมตีหรือความผิดพลาดต้องผ่านหลายด่าน และเมื่อพลาดระบบต้องกลับสู่สถานะที่ใช้งานได้ (เฟิร์มแวร์เดิม ค่า Wi-Fi เดิม)

### 11) ค่าคงที่ตั้งชื่อ (`constexpr`) แทน magic number

**ใช้ที่ไหน:** ค่าตั้งต้นทั้งหมดต้นไฟล์ `.ino` **ทำไม:** แก้เกณฑ์ที่เดียว (README ระบุว่าแก้ `AC_RUNNING_ON_WATTS`/`AC_RUNNING_OFF_WATTS` ได้) และอ่านโค้ดรู้ความหมายทันที `constexpr` ไม่กิน RAM เพิ่ม

### 12) แยก "ข้อมูล" ออกจาก "การวาด" และจำกัดอัตรา (rate limit)

**ใช้ที่ไหน:** จอ OLED: `refreshOled()` ใน `.ino` กรอก `struct OledData`, `oled_ui.h` วาดจาก `OledData` อย่างเดียว (ไม่รู้จัก `config`, `airState`, `mqttClient`), `oled_display.h` คุมจังหวะ 400 ms + `poke()` **ทำไม:** ฟังก์ชันวาดไม่ผูกกับตัวแปร global ของเฟิร์มแวร์ จึงใช้ไฟล์เดียวกันได้ทั้งบอร์ด IR และบอร์ดสายแอร์ (คัดลอกได้ทุกไบต์) และงานที่ช้า (ส่งภาพทาง I2C ซอฟต์แวร์) ถูกจำกัดความถี่ไม่ให้แย่งเวลา `mqttClient.loop()` ส่วน `poke()` ทำให้ค่าที่ผู้ใช้เพิ่งสั่งขึ้นจอทันทีแม้มีการจำกัดอัตรา

### 13) ตรวจตัวตนก่อนทำสิ่งที่ย้อนกลับไม่ได้

**ใช้ที่ไหน:** `unprovision` ทั้งสามเฟิร์มแวร์ตรวจ `deviceId` ในคำสั่งกับ `config.deviceId` ก่อนล้าง NVS **ทำไม:** การล้างค่าทำให้บอร์ดหลุดจากระบบจนกว่าจะมีคนไปตั้งค่าใหม่ถึงหน้างาน การเช็กซ้ำหนึ่งบรรทัดกันความผิดพลาดของ topic หรือข้อความหลงได้ในราคาถูกมาก

## คำถามที่อาจารย์อาจถาม

> [!ASK]
> **ถาม: ทำไมใช้ ESP32 ไม่ใช้ Arduino Uno หรือ Raspberry Pi?**
> ตอบ: ต้องการ Wi-Fi และ BLE ในตัวเดียวและราคาถูก ESP32 มีทั้งสองอย่างพร้อม flash พอทำ OTA และเก็บข้อมูลย้อนหลังได้ Uno ไม่มี Wi-Fi/BLE ส่วน Raspberry Pi เป็นคอมพิวเตอร์เต็มรูปแบบ แพงและกินไฟกว่า เกินความจำเป็นสำหรับงานที่แค่ยิง IR อ่านเซ็นเซอร์และส่ง MQTT

> [!ASK]
> **ถาม: บอร์ดรู้ได้อย่างไรว่าแอร์ "ทำงานอยู่จริง" ในเมื่อ IR เป็นทางเดียว?**
> ตอบ: ไม่เชื่อคำสั่งที่ส่ง แต่วัดกำลังไฟจริงด้วย PZEM-004T ทุก 2 วินาที ถ้ากำลังไฟ ≥ 30 W ติดกัน 3 ครั้ง ถือว่าทำงาน ถ้า ≤ 10 W ติดกัน 3 ครั้ง ถือว่าหยุด ระหว่างนั้นคงสถานะเดิม (hysteresis) เพราะคอมเพรสเซอร์ตัดต่อเป็นช่วง ๆ ถ้าตัดสินจากค่าเดียวสถานะจะกระพริบ

> [!ASK]
> **ถาม: ถ้า Wi-Fi ล่มหรือเน็ตหลุด ข้อมูลการใช้ไฟหายไหม?**
> ตอบ: ไม่หาย บอร์ดสรุปค่าเป็นช่วง 5 นาที (แรงดัน กระแส กำลัง พลังงานสะสม เวลาที่แอร์ทำงาน) เขียนลงพาร์ติชัน `rmuttlog` ใน flash แบบ ring buffer 2,048 รายการ (~7 วัน) พอต่อ MQTT ได้ก็ส่งทีละ 10 รายการไปที่ `/history` รอ Backend ตอบ `/history-ack` แล้วจึงลบ ถ้าไม่ตอบจะส่งซ้ำ ข้อมูลอยู่ใน flash จึงรอดแม้บอร์ดรีบูตหรือไฟดับ ข้อจำกัดคือต้องเคยได้เวลาจริงจาก NTP ก่อน ถ้าบูตตอนไม่มีเน็ตเลยจะยังเก็บไม่ได้ และถ้าหลุดเกิน ~7 วัน ข้อมูลเก่าสุดจะถูกทับ

> [!ASK]
> **ถาม: ทำไมต้องฝังใบรับรอง Let's Encrypt และต้องใช้ NTP?**
> ตอบ: เพื่อให้บอร์ดแน่ใจว่าคุยกับ broker/เซิร์ฟเวอร์ตัวจริง (ไม่ใช่คนกลาง) ไมโครคอนโทรลเลอร์ไม่มีที่เก็บใบรับรองรากของระบบเหมือนคอมพิวเตอร์ จึงฝัง ISRG Root X1 และ X2 ไว้ใน `letsencrypt_ca.h` (ทั้ง RSA และ ECDSA เผื่อเซิร์ฟเวอร์เปลี่ยนสาย) การตรวจใบรับรองต้องเทียบกับวันหมดอายุ จึงต้องมีเวลาจริง โค้ดจึงเรียก `ensureClockSynced()` ก่อนต่อ TLS และก่อน OTA ใบ ts.net ของ Funnel 8443 กับใบ DuckDNS ของ 8883 ออกโดย Let's Encrypt ทั้งคู่ ใบรากชุดนี้จึงใช้ได้ทั้งสองทาง

> [!ASK]
> **ถาม: OTA ปลอดภัยแค่ไหน ถ้าไฟล์เฟิร์มแวร์เสียหรือมีคนส่งคำสั่งปลอมล่ะ?**
> ตอบ: มีสามชั้นตามคอมเมนต์ใน `ota_update.h`: คำสั่งมาทาง `/command` ซึ่งตาม ACL มีแต่ Backend ส่งได้, URL ต้องเป็น `https://<MQTT host เดิม>/firmware/<ชื่อไฟล์>.bin` ผ่านการตรวจอักขระและห้าม `..`, และดาวน์โหลดตรวจใบรับรอง HTTPS กับใบรากที่ฝังไว้ ถ้าไฟล์เสียระหว่างดาวน์โหลด บอร์ดไม่สลับช่องแอป (มี app0/app1) และทำงานด้วยเฟิร์มแวร์เดิมต่อ พร้อมรายงาน `otaError` ใน status ข้อจำกัดที่ควรยอมรับตรง ๆ คือไม่มีลายเซ็นของไฟล์ .bin และไม่มี rollback อัตโนมัติถ้าเฟิร์มแวร์ใหม่ตัวเองมีบั๊ก

> [!ASK]
> **ถาม: ถ้ารหัส Wi-Fi ที่ผู้ใช้กรอกผิด บอร์ดจะกลายเป็นอิฐไหม?**
> ตอบ: ไม่ `processPendingConfig()` ทดสอบต่อ Wi-Fi ด้วยรหัสใหม่ก่อน (15 วินาที) ถ้าไม่ผ่านจะไม่บันทึกลง NVS แจ้งแอปว่า `wifi_connection_failed` ให้แก้แล้วกดใหม่ได้ และค่าเดิมยังอยู่ ถ้าบูตแล้วต่อ Wi-Fi เดิมไม่ได้ บอร์ดเข้า BLE recovery เองและลองต่อ Wi-Fi เดิมซ้ำทุก 30 วินาที พอ router กลับมาก็กลับมาทำงานเอง

> [!ASK]
> **ถาม: ในโหมดกู้ Wi-Fi ทำไมแก้ได้แค่ Wi-Fi ไม่ให้แก้ห้องหรือ MQTT?**
> ตอบ: เพราะ BLE เป็นช่องทางที่ใครอยู่ใกล้ก็ต่อได้ ถ้าเปลี่ยน MQTT host ได้ คนแปลกหน้าจะชี้บอร์ดไปหา broker ของตัวเองแล้วสั่งแอร์ห้องนั้นหรือส่งข้อมูลปลอมได้ โค้ด `keepsServerAssignment()` เปรียบเทียบค่าห้อง เลขแอร์ และ MQTT ทั้งหมดกับค่าที่เก็บไว้ ถ้าต่างจะตอบ `wifi_only_mode` การเปลี่ยนห้องหรือเซิร์ฟเวอร์ต้องกด BOOT ที่ตัวบอร์ดหรือให้แอดมินสั่งผ่าน Backend

> [!ASK]
> **ถาม: บอร์ดตรวจจับคนตัดสินว่า "มีคน" อย่างไร และถ้าคนนั่งนิ่ง ๆ ล่ะ?**
> ตอบ: เปิด Engineering mode ของ LD2410 แล้วอ่านพลังงาน "นิ่ง" (stationary) ของเกต 0–8 ถ้ามีเกตใดมากกว่า 25 ถือว่ามีคน (เท่ากับ 25 ถือว่าว่าง) ใช้ค่านิ่งเพราะคนที่นั่งทำงานแทบไม่เคลื่อนไหวแต่ยังมีการหายใจ/ขยับเล็กน้อยที่เรดาร์จับได้ ส่วน moving energy และระยะไม่ถูกนำมาใช้ ถ้าไม่ได้เฟรมจากเรดาร์เกิน 3 วินาที จะรายงานว่าเรดาร์ไม่พร้อม แอปจึงแสดง "Sensor unavailable" ไม่ใช่ "ว่าง" เพื่อไม่ให้ระบบปิดแอร์ทั้งที่ยังมีคนอยู่เพราะเซ็นเซอร์เสีย (การหน่วงเวลาก่อนปิดแอร์ทำที่ Backend ไม่ใช่ในบอร์ด)

> [!ASK]
> **ถาม: ทำไมโค้ดไม่ใช้ `delay()` และ `loop()` มีหลายงานได้อย่างไร?**
> ตอบ: `delay()` หยุดทั้งโปรแกรม ระหว่างนั้นฟัง MQTT หรืออ่านเซ็นเซอร์ไม่ได้ โค้ดจึงใช้ `millis()` เทียบเวลาแทน (non-blocking) แต่ละงานมีตัวจับเวลาของตัวเอง `loop()` วิ่งเร็วและเช็กว่างานไหนถึงเวลา งานที่ต้องรอ (ลบ flash, ทดสอบ Wi-Fi, OTA) ถูกเลื่อนจาก callback มาทำใน loop ในจังหวะที่ควบคุมได้

> [!ASK]
> **ถาม: ทดสอบเฟิร์มแวร์โดยไม่มีบอร์ดได้ไหม?**
> ตอบ: ส่วนที่ซับซ้อนที่สุดคือ ring buffer เก็บข้อมูลย้อนหลัง ถูกเขียนให้ไม่ผูกกับ ESP32 (`history_log.h` เป็น template รับตัวเก็บข้อมูลเข้ามา) มีเทสต์ `tests/history_log_test.cpp` ที่จำลอง NOR flash บนคอมพิวเตอร์ คอมไพล์ด้วย `g++ -std=c++17` รันแล้วผ่าน 2,099 checks ครอบคลุมการส่ง-ack-ลบ, รีบูตกลางทาง, เขียนเกินความจุ และพาร์ติชันที่มีขยะ ส่วนที่ผูกกับฮาร์ดแวร์ เช่น IR และเรดาร์ ต้องทดสอบกับของจริงและ Serial Monitor

> [!ASK]
> **ถาม: จอ OLED ทำให้บอร์ดช้าลงหรือพลาดคำสั่ง MQTT ไหม?**
> ตอบ: ออกแบบไม่ให้เป็นอย่างนั้น จอวาดจริงแค่ทุก 400 ms (`due()`/`show()` ใน `oled_display.h`) รอบอื่นของ `loop()` จบที่บรรทัดแรกของ `refreshOled()` ทันที ไม่เตรียมข้อมูลด้วย การอ่านนาฬิกาใช้ `getLocalTime(&timeInfo, 0)` ที่ไม่รอ และการวาดทำในบัฟเฟอร์ RAM ก่อนส่งทีเดียว เมื่อผู้ใช้สั่งแอร์ `publishState()` เรียก `poke()` ให้วาดรอบถัดไปทันที ถ้าไม่มีจอ `begin()` ตรวจ pull-up ไม่เจอก็ปิดส่วนจอทั้งหมด ไม่มีการส่ง I2C เลย และจอเป็นแค่ผู้อ่านสถานะ ถ้าจอเสียการควบคุมแอร์ไม่กระทบ

> [!ASK]
> **ถาม: ทำไมมีโหมดพักจอ และทำไมไม่ปิดจอไปเลย?**
> ตอบ: OLED แต่ละพิกเซลเปล่งแสงเองและเสื่อมตามเวลาที่ติด ห้องเรียนปิดแอร์นานกว่าเปิด ถ้าโชว์ `OFF` ตัวใหญ่ที่เดิมทั้งคืนจะเกิดเงาค้าง (burn-in) โค้ดจึงเปลี่ยนเป็นข้อความเล็ก "ห้อง #เครื่อง OFF" กับนาฬิกาที่ย้ายตำแหน่งทุกนาทีเมื่อแอร์ปิดเกิน 10 นาที (`OLED_SAVER_AFTER_MS`) ไม่ปิดจอดำเพราะคนที่เดินผ่านยังต้องรู้ว่าบอร์ดยังทำงานอยู่และเป็นของห้องไหน เปิดแอร์เมื่อไรจอกลับหน้าปกติทันที

> [!ASK]
> **ถาม: `build_opt.h` คืออะไร ถ้าลบทิ้งจะเกิดอะไร?**
> ตอบ: เป็นรายการแฟล็กคอมไพเลอร์ (`-D...`) ที่ Arduino-ESP32 core 3.x ใส่ให้ทุกไฟล์รวมถึงไลบรารี ใช้ปิด I2C/SPI ฮาร์ดแวร์ของ U8g2 และปิดโปรโตคอล IR 28 ยี่ห้อที่แอปไม่มีให้เลือก เพราะเฟิร์มแวร์เดิมใช้ช่องแอปไป 98.8% แล้ว จอเพิ่มอีก ~24 KB หลังใส่ไฟล์นี้ เฟิร์มแวร์ที่มีจอเหลือ 98% (2,001,365 ไบต์) ถ้าลบทิ้งสเก็ตช์ IR จะใหญ่เกินช่องแอปและคอมไพล์ไม่ผ่าน ข้อแลกคือถ้าแอปเพิ่มยี่ห้อที่ถูกปิดไว้ ต้องเอาแฟล็กของยี่ห้อนั้นออกก่อน

> [!ASK]
> **ถาม: ลบอุปกรณ์ในแอปแล้ว บอร์ดรู้ได้อย่างไร และล้างอะไรบ้าง?**
> ตอบ: Backend ส่ง `{"action":"unprovision","deviceId":...}` ที่ `/command` บอร์ดตรวจว่า `deviceId` ตรงกับตัวเอง แล้วตอบ `{"unprovisioned":true}` ที่ `/status` (ไม่ retained) ล้างข้อความ retained ของตัวเอง ตัด MQTT แบบปกติ (เพื่อไม่ให้ LWT ค้าง) ล้าง NVS ทั้งหมด (บอร์ดแอร์ล้าง `rmutt-air`, `rmutt-state` และพาร์ติชัน `rmuttlog`; บอร์ดตรวจจับคนล้าง `rmutt-occ`) แล้วรีบูตเข้าโหมดตั้งค่า BLE Device ID ไม่เปลี่ยนเพราะมาจาก MAC Backend รอคำตอบไม่เกิน 4 วินาทีก่อนลบบัญชี MQTT ถ้าบอร์ดออฟไลน์คำสั่งจะไปไม่ถึง ต้องใช้ `reset.ino` หรือปุ่ม BOOT แทน

> [!ASK]
> **ถาม: บอร์ดสายแอร์ต่างจากบอร์ด IR อย่างไร ทำไมไม่รวมเป็นเฟิร์มแวร์เดียว?**
> ตอบ: บอร์ดสายแอร์ใช้แทนรีโมตติดผนังของ Daikin ส่งคำสั่งเข้าสายทุก 1 วินาทีใน task แยก และได้สถานะจริงกลับมา (สายตอบไหม คอมเพรสเซอร์ทำงานไหม) ส่วน IR ยิงครั้งเดียวไม่มีคำตอบ ทั้งไลบรารี ขา และวิธีส่งต่างกันมาก จึงแยกเป็นสเก็ตช์ `rmutt_esp32_air_wired` (2.5.2-slm8) แต่ใช้ส่วนร่วมชุดเดียวกัน (BLE, MQTT topic, PZEM, OTA, ข้อมูลย้อนหลัง, จอ OLED; ไฟล์ `.h` ส่วนร่วมคัดลอกมาทุกไบต์) แอปแยกสองแบบจาก `controlType` ใน BLE IDENTITY (`"ir"`/`"wired"`) รายละเอียดอยู่ในบท 19

## สรุปและเช็กลิสต์ความเข้าใจ

ถ้าตอบข้อเหล่านี้ได้ แปลว่าเข้าใจบทนี้แล้ว

- [ ] บอกได้ว่ามีเฟิร์มแวร์หลักกี่ตัว (สาม: บอร์ดแอร์ IR **2.5.1**, บอร์ดแอร์สายแอร์ **2.5.2-slm8**, บอร์ดตรวจจับคน **1.3.3**) ตัวไหนทำอะไร และคุยกับ Backend ผ่านอะไร (MQTT เท่านั้น; BLE ไว้ตั้งค่า)
- [ ] อธิบายความต่าง MCU กับคอมพิวเตอร์, `setup()`/`loop()`, `millis()` กับ `delay()` และยกตัวอย่างในโค้ดได้
- [ ] บอกขา GPIO17/16/18/25/26/27/0 และ 21/22 (จอ OLED) ของบอร์ดแอร์ IR, ขาเพิ่มของบอร์ดสายแอร์ (33/35/34/4) และ GPIO32/33/0 ของบอร์ดตรวจจับคนได้ พร้อมบอกว่าต่อไขว้ TX/RX
- [ ] อธิบาย 38 kHz, mark/space, 72 บิต ของ Saijo และทำไมใช้ตารางเฟรมสำเร็จรูป
- [ ] บอกเกณฑ์ 30 W / 10 W / 3 ครั้ง / อ่านทุก 2 วินาที และเหตุผลของ hysteresis
- [ ] เล่าลำดับ BLE provisioning ตั้งแต่เปิด BLE → เขียน config เป็นชิ้น ๆ → ทดสอบ Wi-Fi → บันทึก NVS → รีสตาร์ต → ส่ง token → ack
- [ ] อธิบายโหมดกู้ Wi-Fi (ลองซ้ำทุก 30 วินาที ครั้งละ 8 วินาที) และเหตุผลของ Wi-Fi-only mode
- [ ] บอกตัวเลือก MQTT ในโค้ด: client id, LWT (QoS 1 retained), TLS + ใบรากฝัง, หัวข้อที่ subscribe, buffer 2048
- [ ] อธิบาย offline history: ช่วง 5 นาที, `HistoryRecord` 32 ไบต์, ring buffer 64 KB = 2,048 รายการ ≈ 7 วัน, ส่งทีละ 10, ack, ลบเป็น sector, ส่งซ้ำ, สุ่มหน่วง 5–45 วินาที
- [ ] อธิบาย OTA: partition app0/app1, ตรวจ URL สามชั้น, ปิด MQTT ก่อนโหลด, ไม่สำเร็จก็ใช้ของเดิม
- [ ] อธิบายกฎมีคน: static energy เกต 0–8 > 15, ไฟ LED เขียว/แดงของบอร์ดตรวจคนบอกอะไร, availability หมดเวลา 3 วินาที, ตรวจทุก 250 ms, ส่ง status เมื่อเปลี่ยนหรือทุก 10 วินาที
- [ ] อธิบายความต่างของ `partitions.csv` สองไฟล์ (`rmuttlog` กับ `coredump`) และทำไม nvs offset เดิมทำให้ค่าไม่หาย
- [ ] บอกหน้าที่ `reset.ino`, `ld2410_pinscan.ino`, `update-root-ca.ps1` และ `history_log_test.cpp`
- [ ] รู้ว่าเลขรุ่นจริงอยู่ที่ `FIRMWARE_VERSION` ในไฟล์ `.ino` (2.5.1 / 2.5.2-slm8 / 1.3.3) และเครื่องมือวินิจฉัยเรดาร์คือ `ld2410_pinscan`
- [ ] อธิบายจอ OLED: SH1106 1.3" I2C ซอฟต์แวร์บน GPIO21/22, U8g2 full buffer, ตรวจจอด้วย pull-up/pull-down, วาดทุก 400 ms หรือเมื่อ `poke()`, หน้า SETUP / CONNECTING / NORMAL (แบบ 1 ตัวเลขใหญ่), กราฟ 64 จุดทุก 5 วินาที, พักจอเมื่อแอร์ปิดเกิน 10 นาที
- [ ] อธิบายว่าทำไมจอไม่ทำให้ MQTT/IR สะดุด (`due()` ออกเร็ว, `getLocalTime(..., 0)` ไม่รอ, ผูกกับ `updateStatusLeds()` ที่ถูกเรียกแม้ระหว่างรอ Wi-Fi)
- [ ] อธิบาย `build_opt.h`: แฟล็ก `-D` ใส่ทุกไฟล์รวมไลบรารี, ปิด HW I2C/SPI ของ U8g2 และ IR 28 ยี่ห้อ, ผล 98% ของช่องแอป, ข้อแลกเปลี่ยน
- [ ] เล่าลำดับ unprovision: คำสั่ง `/command` → ตรวจ `deviceId` → ตอบ `unprovisioned:true` → ล้าง retained → disconnect ปกติ → ล้าง NVS (+ `rmuttlog`) → รีบูตเข้า BLE และบอกความต่างของบอร์ดตรวจจับคน (ตั้งธงใน callback แล้วทำใน `loop()`)
- [ ] บอกได้ว่าบอร์ดสายแอร์ใช้ไฟล์ร่วมอะไรกับบอร์ด IR (คัดลอกทุกไบต์: `oled_display.h`, `oled_ui.h`, `history_log.h`, `ota_update.h`, `letsencrypt_ca.h`, `partitions.csv`) และไปอ่านรายละเอียดโปรโตคอลที่บท 19
