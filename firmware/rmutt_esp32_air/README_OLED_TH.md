# rmutt_esp32_air 2.5.0 — เพิ่มจอ OLED 1.3"

เฟิร์มแวร์ IR เดิม (2.4.1) + จอ OLED SH1106 128×64 I2C หน้าจอแบบ 1 "ตัวเลขใหญ่"
ส่วน BLE / MQTT / IR / PZEM / LED / OTA / ข้อมูลย้อนหลัง ไม่ได้แตะ แอปและ Backend ใช้ได้เหมือนเดิม
เพิ่มอย่างเดียวคือ identity บลูทูธมี `"controlType":"ir"` ให้แอปขึ้น "ชนิดบอร์ด: รีโมต IR" (แยกจากบอร์ดสายแอร์)

## ต่อจอ

| จอ OLED | ESP32 |
|---|---|
| VCC | 3V3 |
| GND | GND |
| SDA | GPIO21 |
| SCL (SCK) | GPIO22 |

ไม่มีจอต่ออยู่ก็แฟลชได้ เฟิร์มแวร์ตรวจไม่เจอจะปิดส่วนจอเอง (Serial ขึ้น `OLED: not found`)

## หน้าจอ

- แถบบน: ห้อง #เครื่อง · นาฬิกา · `M` (MQTT ทึบ = ต่ออยู่) · สัญญาณ Wi-Fi
- กลาง: ไอคอน+ชื่อโหมด · อุณหภูมิที่ตั้งตัวใหญ่ · แท่งพัดลม · `SW` เมื่อส่าย · `ZZ` เมื่อ Sleep
- แถบล่าง: กำลังไฟจาก PZEM · `OUT OF CLASS` เมื่อแอร์ทำงานนอกเวลาเรียน
- ปิดแอร์: ตัวใหญ่ `OFF` · ปิดนานเกิน 10 นาที → พักจอ (ตัวหนังสือเล็กย้ายที่ทุกนาที กันจอเบิร์น)
- โหมดตั้งค่า BLE: ขึ้นชื่อบลูทูธของบอร์ด · กำลังต่อ Wi-Fi: ขึ้นชื่อ Wi-Fi

## ไลบรารีที่ต้องเพิ่ม

- **U8g2** by olikraus (Library Manager)

## build_opt.h (ไฟล์ใหม่ อย่าลบ)

แฟลชของบอร์ดเหลือน้อยมาก (รุ่น 2.4.1 ใช้ 98.8% ของช่องแอป) จอ OLED กินเพิ่ม ~24 KB
ไฟล์นี้ทำ 2 อย่างให้ใส่จอได้ โดยรวมแล้วเล็กลงกว่าเดิม:

1. `-DU8X8_NO_HW_I2C -DU8X8_NO_HW_SPI` — จอใช้ I2C แบบซอฟต์แวร์ ไม่ดึงไดรเวอร์ I2C/SPI ของ ESP-IDF
2. `-DSEND_xxx=false` — ปิดโปรโตคอล IR ยี่ห้อที่แอปไม่มีให้เลือก (Airton, Airwell, Amcor, Argo,
   Bosch, Carrier64, Corona, Delonghi, Ecoclim, Eurom, Goodweather, Kelon, Neoclima, Rhoss,
   Sanyo, TCL, Technibel, Teco, Teknopoint, Transcold, Trotec, Truma, Vestel, Voltas, Whirlpool, York)
   ยี่ห้อที่แอปใช้ (Daikin, Mitsubishi, Panasonic, Gree, Midea/Coolix, LG, Samsung, Toshiba,
   Hitachi, Fujitsu, Kelvinator, Sharp, Electra, Haier, Saijo Denki) ยังอยู่ครบทุกรุ่นย่อย

Arduino IDE ใช้ `build_opt.h` เองอัตโนมัติ (ESP32 core 3.x) ถ้าแก้ไฟล์นี้ ให้ปิด-เปิด IDE หรือลบโฟลเดอร์
build ชั่วคราว เพื่อให้คอมไพล์ไลบรารีใหม่

ผลคอมไพล์ (ESP32 core 3.0.7): 2,001,365 ไบต์ (98%) · รุ่นเดิม 2,007,985 ไบต์

## ปรับค่าใน oled_display.h

| ค่า | ใช้ทำอะไร |
|---|---|
| `OLED_LAYOUT` | หน้าจอแบบ 1–5 (ตอนนี้ 1) · แบบอื่นใช้ฟอนต์เพิ่ม อาจเกินแฟลช ต้องลองคอมไพล์ก่อน |
| `OLED_ROTATE_180` | ติดจอกลับหัว |
| `OLED_CONTRAST` | ความสว่าง 0–255 |
| `OLED_SAVER_AFTER_MS` | เวลาก่อนพักจอเมื่อแอร์ปิด |
