# แอป Flutter ตอนที่ 3: หน้าจอผู้ดูแลระบบและการตั้งค่า

บทนี้อธิบายหน้าจอกลุ่ม "หลังบ้าน" ของแอป Flutter ทั้งหมด ได้แก่ หน้าตั้งค่าบอร์ด ESP32 ผ่านบลูทูธ (ทั้งบอร์ดคุมแอร์และบอร์ดเซ็นเซอร์ตรวจจับคน) หน้าจัดการห้อง หน้าจัดการและนำเข้าตารางเรียน หน้าฐานข้อมูลพลังงาน หน้าจัดการผู้ใช้ และหน้าตั้งค่าต่าง ๆ ของบัญชีและของแอป หัวใจของบทคือ **การ Provisioning** (การตั้งค่าอุปกรณ์ใหม่ให้พร้อมใช้งาน) ซึ่งเป็นจุดที่แอป Backend และ ESP32 ทำงานประสานกันครบทั้งสามฝ่าย อ่านจบแล้วจะอธิบายได้ว่าตั้งแต่แอดมินกดปุ่ม "ค้นหาบลูทูธ" จนแอร์ขึ้นสถานะออนไลน์ในระบบ มีอะไรเกิดขึ้นบ้างทีละขั้น ทั้งในมุมผู้ใช้และในโค้ด รวมถึงรู้ว่าแต่ละหน้าจอเรียก Controller ตัวไหน และ Backend บังคับกฎอะไรไว้

## ภาพรวม

หน้าจอในบทนี้เป็นชั้นบนสุด (UI) ของแอป ส่วนใหญ่ไม่คุยกับเซิร์ฟเวอร์เองตรง ๆ แต่เรียกผ่าน Controller (ตัวถือสถานะและตรรกะ ซึ่งอธิบายไว้ในบทของ Controllers) และ Service/Repository (ตัวยิง HTTP ไปยัง Backend) มีข้อยกเว้นสำคัญคือหน้าตั้งค่าบอร์ดผ่านบลูทูธ ซึ่งคุยกับ ESP32 **โดยตรง** ผ่านคลื่นวิทยุ Bluetooth Low Energy (BLE) โดยไม่ผ่านเซิร์ฟเวอร์ เพราะตอนนั้นบอร์ดยังไม่มี Wi-Fi จึงยังต่อเน็ตไม่ได้

```text
                ┌──────────────────────────────┐
                │   หน้าจอ (บทนี้)              │
                └──────┬──────────────┬────────┘
                       │              │ BLE (เฉพาะ Provisioning)
        Controller / Service          ▼
                       │        ┌──────────┐
                HTTP + JWT      │  ESP32   │──Wi-Fi──┐
                       ▼        └──────────┘         │ MQTT
                ┌──────────────┐                ┌────▼──────┐
                │ Backend API  │◄──── MQTT ────►│ Mosquitto │
                │ + MariaDB    │                └───────────┘
                └──────────────┘
```

ตารางต่อไปนี้สรุปทุกหน้าจอในขอบเขตของบท ว่าใครใช้ได้ เปิดจากไหน และฝั่ง Backend ป้องกันไว้อย่างไร

| หน้าจอ | ไฟล์ | เปิดจาก | ผู้ใช้ | การบังคับสิทธิ์ฝั่ง Backend |
|---|---|---|---|---|
| ตั้งค่าแอร์ผ่านบลูทูธ | `ble_provisioning_screen.dart` | หน้าควบคุมห้อง (`room_control_screen.dart`) ปุ่มเพิ่มแอร์/ตั้งค่าใหม่ | Admin | `POST /air-conditioners/reservations` มี `requireAdmin` |
| ตั้งค่าเซ็นเซอร์ตรวจจับคน | `occupancy_provisioning_screen.dart` | หน้าควบคุมห้อง | Admin | `POST /occupancy-sensors/reservations` มี `requireAdmin` |
| จัดการห้อง | `room_management_screen.dart` | หน้า Rooms ปุ่มจัดการ (แสดงเฉพาะ Admin) | Admin | `POST/PUT/DELETE /rooms` มี `requireAdmin` |
| จัดการตารางเรียน | `schedule_management_screen.dart` | หน้า Schedule ปุ่มจัดการ (แสดงเฉพาะ Admin) | Admin | `POST/PUT/DELETE /schedules` มี `requireAdmin` และตรวจเวลาทับซ้อนซ้ำ |
| นำเข้าตาราง Excel/CSV | `schedule_import_screen.dart` | ปุ่มอัปโหลดในหน้าจัดการตาราง | Admin | `/schedules/import/preview` และ `/import/commit` มี `requireAdmin` |
| เพิ่ม/แก้การใช้ห้อง | `booking_editor_screen.dart` | หน้า Schedule ปุ่มบนแถบหัว / ปุ่ม ⊕ บนการ์ดห้อง / แตะรายการ | Admin | `POST/PUT/DELETE /bookings` มี `requireAdmin` |
| ปฏิทินภาคเรียน | `term_calendar_screen.dart` | หน้า Schedule ปุ่ม "ปฏิทินภาคเรียน" | ทุกคนดู, Admin แก้ | `PUT/DELETE /schedules/terms` มี `requireAdmin` |
| ฐานข้อมูลพลังงาน | `energy_database_screen.dart` | เมนูในหน้าโปรไฟล์ | Admin และ Staff | `/energy/*` ต้องเข้าสู่ระบบ (`authenticate`) เท่านั้น |
| จัดการผู้ใช้ | `user_management_screen.dart` | เมนูในหน้าโปรไฟล์ (แสดงเฉพาะ Admin) | Admin | ทั้ง Router ใช้ `requireAdmin` |
| โปรไฟล์ | `profile_screen.dart` | แท็บโปรไฟล์ใน `app_shell.dart` | ทุกคน (เมนูต่างกันตามสิทธิ์) | ไม่มี (เป็นเมนูนำทาง) |
| ตั้งค่าบัญชี | `account_settings_screen.dart` | เมนูในหน้าโปรไฟล์ | ทุกคน (แก้ได้เฉพาะบัญชีตัวเอง) | `PATCH /auth/me`, `POST /auth/me/password` |
| ตั้งค่าแอป | `application_settings_screen.dart` | เมนูในหน้าโปรไฟล์ | ทุกคน แต่สวิตช์ปิดแอร์อัตโนมัติกดได้เฉพาะ Admin | `PATCH /settings/...` มี `requireAdmin` |
| ตั้งค่าการแจ้งเตือน | `notification_settings_screen.dart` | แถว "การแจ้งเตือน" ในหน้าตั้งค่าแอป | ทุกคน | ไม่มี (เก็บในเครื่อง) |
| อัตราค่าไฟ | `electricity_rate_screen.dart` | เมนูในหน้าโปรไฟล์ | ทุกคน | ไม่มี (เก็บในเครื่อง) |

> [!WHY] ทำไมต้องซ่อนปุ่มในแอป และยังต้องเช็กสิทธิ์ที่ Backend อีกชั้น
> การซ่อนปุ่ม (เช่น `if (_isAdmin)` ในหน้าโปรไฟล์) เป็นแค่เรื่องความสะดวกของผู้ใช้ ไม่ใช่ความปลอดภัย เพราะใครก็ยิง HTTP ไปที่ API เองได้โดยไม่ผ่านแอป ความปลอดภัยจริงจึงอยู่ที่ Middleware `requireAdmin` ของ Backend ซึ่งอ่านสิทธิ์จาก Token ที่เซิร์ฟเวอร์เซ็นเอง แอปปลอมไม่ได้

## โครงสร้างไฟล์

| ไฟล์ | หน้าที่ |
|---|---|
| `lib/screens/ble_provisioning_screen.dart` | ฟอร์ม 4 ขั้นสำหรับเพิ่มหรือตั้งค่าใหม่บอร์ดคุมแอร์ `RMUTT-AC-*` ผ่านบลูทูธ แยกบอร์ด IR กับบอร์ดสายแอร์ Daikin และล็อกยี่ห้อให้บอร์ดสายแอร์ |
| `lib/screens/occupancy_provisioning_screen.dart` | ฟอร์มแบบเดียวกันแต่สำหรับบอร์ดเซ็นเซอร์เรดาร์ LD2410 `RMUTT-OCC-*` |
| `lib/screens/room_management_screen.dart` | รายการห้อง เพิ่ม แก้ไข ลบห้อง (รวมห้องพิเศษอย่าง `CL503`) |
| `lib/screens/schedule_management_screen.dart` | เลือกชั้น ห้อง วัน แล้วเพิ่ม/แก้/ลบคาบเรียน และล้างตารางทั้งหมด |
| `lib/screens/schedule_import_screen.dart` | เลือกไฟล์ Excel/CSV ดูตัวอย่าง (Preview) กรอกภาคเรียน แล้วยืนยันนำเข้า (Commit) |
| `lib/screens/energy_database_screen.dart` | แท็บค่าไฟสดจาก PZEM-004T และแท็บเลือกข้อมูลเพื่อส่งออกเป็น Excel |
| `lib/screens/user_management_screen.dart` | รายชื่อผู้ใช้ สลับสิทธิ์ Admin/Staff ระงับบัญชี ลบ และสร้างบัญชีใหม่ |
| `lib/screens/profile_screen.dart` | หน้าโปรไฟล์และเมนูเข้าสู่หน้าตั้งค่าอื่น ๆ |
| `lib/screens/account_settings_screen.dart` | แก้ชื่อ อีเมล เบอร์โทร และเปลี่ยนรหัสผ่าน |
| `lib/screens/application_settings_screen.dart` | ภาษา ธีมสี ขนาดตัวอักษร การแจ้งเตือน และสวิตช์ปิดแอร์อัตโนมัติทั้งอาคาร |
| `lib/screens/notification_settings_screen.dart` | สวิตช์หลักและสวิตช์รายประเภทของการแจ้งเตือนบนเครื่อง |
| `lib/screens/electricity_rate_screen.dart` | ตั้งอัตราค่าไฟต่อหน่วย พร้อมตัวอย่างคำนวณ |
| `lib/services/ble_provisioning_service.dart` | (บริบท) ชั้นคุยกับ BLE: สแกน เชื่อมต่อ อ่าน เขียน รอ Notify |
| `lib/models/provisioning.dart` | (บริบท) โมเดลข้อมูลของการ Provisioning และรูปแบบ JSON ที่ส่งให้บอร์ด |
| `lib/utils/file_saver.dart` | (บริบท) บันทึกไฟล์ Excel/CSV แยกวิธีระหว่าง Windows (กล่องบันทึกเป็น) กับมือถือ (เมนูแชร์) |

---

## ความรู้พื้นฐาน Bluetooth Low Energy ที่ต้องรู้ก่อน

> [!LEARN] ทำไมต้องใช้บลูทูธตอนตั้งค่า
> ESP32 ที่เพิ่งแฟลชเฟิร์มแวร์ยังไม่รู้ชื่อ Wi-Fi และรหัสผ่าน จึงต่ออินเทอร์เน็ตไม่ได้ และ Backend ก็คุยกับมันไม่ได้ ช่องทางเดียวที่เหลือคือคุยกันแบบใกล้ตัว ระยะไม่กี่เมตร ESP32 มีวิทยุ BLE ในตัวอยู่แล้ว แอปบนคอมพิวเตอร์ Windows หรือมือถือ Android ก็มีบลูทูธ จึงใช้ BLE เป็น "สายชั่วคราว" ส่งค่า Wi-Fi และค่าเซิร์ฟเวอร์ให้บอร์ด หลังจากนั้นบอร์ดจะใช้ Wi-Fi และ MQTT ตลอดไป

### บทบาท Central และ Peripheral

ใน BLE มีสองบทบาท อุปกรณ์ที่ "ประกาศตัวรอให้คนมาต่อ" เรียกว่า **Peripheral** (ในที่นี้คือ ESP32) ส่วนอุปกรณ์ที่ "ค้นหาแล้วเข้าไปต่อ" เรียกว่า **Central** (ในที่นี้คือแอป Flutter) แอปใช้แพ็กเกจ `flutter_blue_plus` เวอร์ชัน `2.3.11` และบน Windows ใช้ `flutter_blue_plus_winrt` เวอร์ชัน `0.0.20` (ล็อกเวอร์ชันไว้ใน `pubspec.yaml`)

### Advertising และ Scan

- **Advertising** (การประกาศตัว) — Peripheral ส่งแพ็กเก็ตสั้น ๆ ออกอากาศเป็นระยะ บอกชื่อ (เช่น `RMUTT-AC-705F1971FE68`) และ UUID ของ Service ที่มี แพ็กเก็ตหลักมีพื้นที่น้อยมาก (ราว 31 ไบต์) จึงมี **Scan Response** เป็นแพ็กเก็ตเสริมที่ส่งเมื่อมีคนถาม เฟิร์มแวร์ ESP32 เปิด `advertising->setScanResponse(true)` ไว้ ทำให้ชื่อกับ UUID อาจถูกแยกไปอยู่คนละแพ็กเก็ต (เรื่องนี้สำคัญกับปัญหาบน Windows)
- **Scan** (การสแกน) — Central ฟังแพ็กเก็ตโฆษณารอบตัวช่วงเวลาหนึ่ง ได้รายการอุปกรณ์พร้อม **RSSI** (ความแรงสัญญาณ หน่วย dBm ค่ายิ่งใกล้ 0 ยิ่งแรง เช่น -45 แรงกว่า -80)

### GATT, Service และ Characteristic

หลังเชื่อมต่อแล้ว ข้อมูลทั้งหมดถูกจัดระเบียบตาม **GATT** (Generic Attribute Profile) ให้นึกภาพเป็นตู้เอกสาร

- **Service** = ลิ้นชัก หนึ่งลิ้นชักรวมเรื่องเดียวกัน มี UUID 128 บิตเป็นชื่อเฉพาะ
- **Characteristic** = แฟ้มในลิ้นชัก แต่ละแฟ้มเก็บค่าหนึ่งค่า มี UUID ของตัวเอง และมี "คุณสมบัติ" บอกว่าทำอะไรกับมันได้ (อ่าน เขียน แจ้งเตือน)
- **Service Discovery** = การเปิดตู้ดูว่ามีลิ้นชักและแฟ้มอะไรบ้าง ต้องทำทุกครั้งหลังเชื่อมต่อก่อนจะอ่าน/เขียนได้

โปรเจคนี้ออกแบบ Service ของตัวเองหนึ่งตัว ใช้ร่วมกันทั้งบอร์ดแอร์ บอร์ดสายแอร์ และบอร์ดเซ็นเซอร์ (UUID ตรงกันทั้งใน `ble_provisioning_service.dart`, `rmutt_esp32_air.ino`, `rmutt_esp32_air_wired.ino` และ `rmutt_esp32_occupancy.ino`)

| ชื่อในแอป | UUID | คุณสมบัติ | หน้าที่ |
|---|---|---|---|
| `serviceUuid` | `7b570001-a243-4e5b-8f13-179af81b2457` | Service | ลิ้นชักหลักของ RMUTT |
| `configUuid` | `7b570002-a243-4e5b-8f13-179af81b2457` | Write | แอปเขียน JSON การตั้งค่า (หั่นเป็นแพ็กเก็ต) |
| `statusUuid` | `7b570003-a243-4e5b-8f13-179af81b2457` | Notify | บอร์ดแจ้งผลกลับ เช่น `{"ok":true,"code":"config_saved",...}` |
| `identityUuid` | `7b570004-a243-4e5b-8f13-179af81b2457` | Read | ตัวตนบอร์ด: `deviceId`, `bleName`, `firmwareVersion`, `configured` และ `controlType` (`ir`/`wired`) กับ `brand` |
| `wifiScanUuid` | `7b570005-a243-4e5b-8f13-179af81b2457` | Read | อ่านเมื่อไรบอร์ดจะสแกน Wi-Fi รอบตัวแล้วตอบรายชื่อกลับ |
| `settingsUuid` | `7b570006-a243-4e5b-8f13-179af81b2457` | Read | ค่าที่บันทึกไว้เดิม (ห้อง แอร์ SSID MQTT เวลาเปิดปิด) ใช้ตอนตั้งค่าใหม่ |

### Read, Write และ Notify

- **Read** — Central ขอค่าจาก Characteristic แล้ว Peripheral ตอบกลับ (เหมือน HTTP GET) ในโปรเจคนี้ ESP32 ผูก Callback `onRead` ไว้กับ `wifiScanUuid` ทำให้ "การอ่าน" กลายเป็น "คำสั่งให้สแกน Wi-Fi" ไปในตัว
- **Write** — Central ส่งค่าไปเขียน มีสองแบบ คือ *Write With Response* (รอให้อีกฝั่งตอบรับว่าได้รับ) และ *Write Without Response* (ยิงแล้วไปต่อ) แอปใช้แบบมีการตอบรับ (`withoutResponse: false`) เพื่อให้แน่ใจว่าทุกแพ็กเก็ตถึงครบตามลำดับ
- **Notify** — Peripheral ส่งค่าใหม่มาหา Central เองโดยไม่ต้องถาม (เหมือน Push) Central ต้อง "สมัครรับ" ก่อนด้วยการเปิด Notify (เบื้องหลังคือเขียนค่าลง Descriptor ชื่อ CCCD) แอปใช้ Notify เพื่อรอผลว่าบอร์ดทดสอบ Wi-Fi ผ่านหรือไม่ เพราะใช้เวลาหลายวินาที ถ้าใช้ Read ต้องถามวนซ้ำ (Polling) ซึ่งเปลืองและช้ากว่า

### MTU และเหตุที่ต้องหั่นข้อมูล

**MTU** (Maximum Transmission Unit) คือขนาดสูงสุดของหนึ่งแพ็กเก็ตในระดับ ATT ค่าเริ่มต้นตามมาตรฐานคือ 23 ไบต์ (ใช้ส่งข้อมูลจริงได้ 20 ไบต์) ทั้งสองฝั่งต่อรองขยายได้หลังเชื่อมต่อ แอปไม่ได้เรียก `requestMtu` เอง แต่พึ่งค่าเริ่มต้นของแพลตฟอร์ม คือ `flutter_blue_plus` บน Android ขอ MTU 512 ให้อัตโนมัติตอน `connect()` และ Windows ต่อรอง MTU เองในระดับระบบปฏิบัติการ

JSON การตั้งค่ามีขนาดหลายร้อยไบต์ (มี SSID รหัสผ่าน ที่อยู่ Broker Token ฯลฯ) ซึ่งใหญ่เกินหนึ่งแพ็กเก็ต แอปจึง **หั่นเป็นชิ้นละ 150 ไบต์** แล้วเติมหัว 6 ไบต์ (รวม 156 ไบต์ต่อแพ็กเก็ต) ให้บอร์ดนำมาต่อกลับ ขนาด 150 เลือกให้เล็กพอจะผ่าน MTU ที่ต่อรองได้จริงบนเครื่องส่วนใหญ่ และใหญ่พอที่จะส่งเสร็จในไม่กี่รอบ

> [!NOTE] ฝั่งอ่านก็เจอปัญหา MTU เหมือนกัน
> ตอนอ่านค่ายาว ๆ Central ต้องอ่านเป็นหลายท่อน (Long Read) บน Windows พบว่าการอ่าน Identity ก้อนใหญ่ก้อนเดียวหมดเวลาบ่อย เฟิร์มแวร์ 1.6 ขึ้นไปจึงทำ Identity ให้สั้นที่สุด (ขนาดเอกสาร JSON 256) แล้วย้ายค่าที่บันทึกไว้ไปอยู่ใน `settingsUuid` ที่อ่านแยกภายหลัง และฝั่งสแกน Wi-Fi บอร์ดก็จำกัดคำตอบไม่เกิน 8 เครือข่ายและไม่เกิน 480 ไบต์

---

## เส้นทาง Provisioning ทั้งหมด

### มุมมองของผู้ดูแลระบบ (สิ่งที่เห็นบนหน้าจอ)

1. เข้าหน้าห้อง เช่น ห้อง 16101 แล้วกด "เพิ่มแอร์" แอปเปิดหน้า "Configure ESP32 via Bluetooth"
2. **ขั้นที่ 1** กด "ค้นหาบลูทูธ" รอประมาณ 8 วินาที รายชื่อบอร์ดที่ขึ้นต้นด้วย `RMUTT-AC-` แสดงพร้อม RSSI เรียงจากแรงไปอ่อน
3. แตะเลือกบอร์ด แอปขึ้น "กำลังเชื่อมต่อและตรวจสอบ ESP32..." เมื่อสำเร็จจะแสดงกล่องสีเขียวมี Device ID (เช่น `ESP32-705F1971FE68`) เวอร์ชันเฟิร์มแวร์ และ ชนิดบอร์ด "ชนิดบอร์ด: รีโมต IR" หรือ "ชนิดบอร์ด: ควบคุมผ่านสายแอร์ (ใช้แทนรีโมตติดผนัง)" แล้วเลื่อนหน้าจอลงไปที่ฟอร์มให้เอง
4. **ขั้นที่ 2** เลือกหมายเลขแอร์ (1–6 เฉพาะเลขที่ยังว่าง) ตั้งชื่อ และเลือกยี่ห้อ/โปรโตคอลรีโมต (บอร์ด IR) ถ้าเป็นบอร์ดสายแอร์ ช่องยี่ห้อถูกล็อกเป็น "Daikin · สายแอร์ (ใช้แทนรีโมตติดผนัง)" พร้อมกล่องฟ้าบอกฟังก์ชันที่ใช้ได้
5. **ขั้นที่ 3** แตะช่อง SSID แอปสั่งให้ **ESP32 เป็นคนสแกน Wi-Fi** แล้วแสดงรายชื่อใน Bottom Sheet เลือกเครือข่ายแล้วพิมพ์รหัสผ่าน (ส่วน MQTT ไม่ต้องกรอก เซิร์ฟเวอร์จัดการให้)
6. **ขั้นที่ 4** (ไม่บังคับ) ตั้งเวลาเปิด/ปิดอัตโนมัติรายวัน
7. กด "บันทึกการตั้งค่าลง ESP32" รอจนขึ้นข้อความ "Wi-Fi verified and configuration saved. ESP32 is connecting to MQTT." หน้าจอปิดกลับไปหน้าห้อง ซึ่งรอ 2 วินาทีแล้วรีเฟรชรายการแอร์
8. ถ้ารหัส Wi-Fi ผิด จะเห็นกล่องแดงพร้อมคำแนะนำว่าให้แก้รหัสแล้วกดบันทึกใหม่ได้เลย ไม่ต้องสแกนบอร์ดใหม่

### มุมมองของระบบ (ใครคุยกับใคร)

```text
แอป Flutter           Backend (REST)            ESP32 (BLE→Wi-Fi)        Mosquitto
    │  1 scan() ─────────────── BLE advertising ◄──┤
    │  2 connect + discoverServices ──────────────►│
    │  3 read identityUuid (+ settingsUuid) ──────►│
    │  4 read wifiScanUuid ───────────────────────►│ (สแกน Wi-Fi จริง)
    │◄──────────────────────── รายชื่อ SSID ───────┤
    │  5 POST /air-conditioners/reservations ─►│
    │◄── token + MQTT host/port/user/pass/topic┤ (แถว 'reserved' หมดอายุ 15 นาที)
    │  6 เปิด Notify statusUuid                   │
    │  7 write configUuid (หั่น 150 ไบต์/แพ็กเก็ต) ►│
    │                                             │ 8 ต่อ JSON, ตรวจค่า, ทดสอบ Wi-Fi
    │◄───────────── Notify {"ok":true} ───────────┤ 9 บันทึก NVS
    │  10 ตัดการเชื่อมต่อ ปิดหน้าจอ                 │ 10 รีสตาร์ตใน 1.5 วินาที
    │                                             │ 11 ต่อ Wi-Fi + MQTT
    │                                             │──publish …/provision {token}──►│
    │                      │◄──────────── subscribe …/+/provision ──────────────────│
    │                      │ 12 เทียบ hash ของ token → provision_status='active'
    │                      │──publish …/provision-ack {activated:true}────────────►│
    │                                             │◄──────────────────────────────│
    │                                             │ 13 ลบ token ออกจาก NVS
```

ส่วนต่อไปจะไล่โค้ดทีละชั้น เริ่มจาก Service ที่คุย BLE ไปจนถึงหน้าจอ แล้วปิดด้วยฝั่ง Backend และ ESP32

---

## ble_provisioning_service.dart — ชั้นคุยกับ BLE

ไฟล์นี้ซ่อนรายละเอียดของ BLE ไว้ทั้งหมด หน้าจอเรียกแค่ 4 เมธอดสาธารณะ คือ `scan()`, `readIdentity()`, `scanWifiNetworks()` และ `provision()` ทุกเมธอดยกเว้น `scan()` ใช้รูปแบบเดียวกัน คือ **เชื่อมต่อ → ทำงาน → ตัดการเชื่อมต่อใน `finally`** ทุกครั้ง

> [!WHY] ทำไมเชื่อมต่อใหม่ทุกขั้นแทนการต่อค้างไว้
> ระหว่างขั้นต่าง ๆ ผู้ใช้อาจใช้เวลานาน เช่น นั่งพิมพ์รหัสผ่านหลายนาที ถ้าต่อค้างไว้ การเชื่อมต่ออาจหลุดเงียบ ๆ แล้วขั้นถัดไปพังแบบงง ๆ การต่อใหม่ทุกครั้งทำให้แต่ละขั้นเริ่มจากสถานะที่รู้แน่ชัด และ `finally` รับประกันว่าบอร์ดจะถูกปล่อยเสมอ บอร์ดจึงกลับไปประกาศตัว (Advertising) ใหม่ได้ ไม่ค้างอยู่กับแอปที่ปิดไปแล้ว

### scan() — ค้นหาบอร์ดตามคำนำหน้าชื่อ

ไฟล์: `lib/services/ble_provisioning_service.dart`

```dart
  Future<List<BleDeviceCandidate>> scan({
    Duration duration = const Duration(seconds: 8),
    String namePrefix = 'RMUTT-AC-',
  }) async {
    if (!await FlutterBluePlus.isSupported) {
      throw const BleProvisioningException(
        'Bluetooth Low Energy is not supported on this computer.',
      );
    }
    await FlutterBluePlus.adapterState
        .where((state) => state == BluetoothAdapterState.on)
        .first
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw const BleProvisioningException(
            'Please turn on Bluetooth and try again.',
          ),
        );

    final found = <String, BleDeviceCandidate>{};
    final subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (final result in results) {
        final name = (result.advertisementData.advName.isNotEmpty
            ? result.advertisementData.advName
            : result.device.platformName)
            .trim();
        if (!name.startsWith(namePrefix)) continue;
        found[result.device.remoteId.str] = BleDeviceCandidate(
          device: result.device,
          name: name,
          rssi: result.rssi,
        );
      }
    });
```

- **บรรทัด 1–4** — รับพารามิเตอร์ระยะเวลาสแกน (ค่าเริ่มต้น 8 วินาที) และคำนำหน้าชื่อ ค่าเริ่มต้นคือ `'RMUTT-AC-'` สำหรับบอร์ดแอร์ หน้าจอเซ็นเซอร์จะส่ง `'RMUTT-OCC-'` มาแทน จึงใช้โค้ดเดียวกันได้ทั้งสองแบบ
- **บรรทัด 5–9** — ถามก่อนว่าเครื่องนี้มีฮาร์ดแวร์ BLE ไหม ถ้าไม่มีให้โยน Exception ที่อ่านรู้เรื่อง แทนที่จะพังกลางทาง
- **บรรทัด 10–18** — `adapterState` เป็น Stream (สายข้อมูลที่ส่งค่ามาเรื่อย ๆ) ของสถานะบลูทูธ กรองเอาเฉพาะสถานะ `on` แล้วรอค่าแรก (`.first`) ถ้าภายใน 5 วินาทียังไม่เปิด แปลว่าผู้ใช้ปิดบลูทูธอยู่ จึงแจ้ง "Please turn on Bluetooth"
- **บรรทัด 20** — ใช้ `Map` โดยมี `remoteId` (ที่อยู่ของอุปกรณ์) เป็นคีย์ เพราะระหว่างสแกนบอร์ดตัวเดียวถูกพบซ้ำหลายรอบ การใช้ Map ทำให้เหลือหนึ่งรายการต่อบอร์ด และ RSSI เป็นค่าล่าสุดเสมอ
- **บรรทัด 21** — สมัครฟังผลสแกนก่อนเริ่มสแกน (ถ้าเริ่มสแกนก่อนอาจพลาดผลชุดแรก)
- **บรรทัด 23–26** — เลือกชื่อจากแพ็กเก็ตโฆษณา (`advName`) ก่อน ถ้าว่างค่อยใช้ชื่อที่ระบบปฏิบัติการจำไว้ (`platformName`) เพราะบางเครื่องได้ชื่อมาจาก Scan Response เท่านั้น
- **บรรทัด 27** — กรองด้วย **คำนำหน้าชื่อ** ทิ้งอุปกรณ์อื่นทั้งหมด (หูฟัง เมาส์ ฯลฯ)
- **บรรทัด 28–32** — เก็บอุปกรณ์ ชื่อ และ RSSI ลงในโมเดล `BleDeviceCandidate`

```dart
    try {
      // Scan without a service filter. On Windows, a recovered ESP32 can place
      // its name in the scan response and its service UUID in the primary
      // advertisement; some Bluetooth drivers fail to match that combination
      // when withServices is used. We still accept only the requested name
      // prefix and verify the service/identity before provisioning.
      await FlutterBluePlus.startScan(
        timeout: duration,
      );
      await FlutterBluePlus.isScanning
          .where((scanning) => !scanning)
          .first
          .timeout(duration + const Duration(seconds: 2));
    } finally {
      await FlutterBluePlus.stopScan();
      await subscription.cancel();
    }

    final results = found.values.toList()
      ..sort((left, right) => right.rssi.compareTo(left.rssi));
    return results;
  }
```

- **บรรทัด 2–6** — คอมเมนต์อธิบายการตัดสินใจสำคัญ: **ไม่ใช้ตัวกรอง Service UUID** (`withServices`) ตอนสแกน เพราะ ESP32 ใส่ชื่อไว้ใน Scan Response และใส่ UUID ไว้ในแพ็กเก็ตหลัก ไดรเวอร์บลูทูธบางตัวบน Windows จับคู่สองส่วนนี้ไม่ได้ ทำให้หาไม่เจอทั้งที่บอร์ดเปิดอยู่ จึงกรองด้วยชื่ออย่างเดียว แล้วไปพิสูจน์ตัวตนจริงหลังเชื่อมต่อแทน
- **บรรทัด 7–9** — เริ่มสแกนพร้อมตั้งเวลาหยุดเอง
- **บรรทัด 10–13** — รอจนสถานะ `isScanning` กลายเป็น `false` (สแกนเสร็จ) โดยเผื่อเวลาอีก 2 วินาทีกันค้าง
- **บรรทัด 14–17** — `finally` หยุดสแกนและยกเลิกการฟังเสมอ แม้เกิด Error ไม่งั้นวิทยุจะสแกนค้างกินแบตเตอรี่และขวางการเชื่อมต่อครั้งถัดไป
- **บรรทัด 19–21** — เรียงผลจาก RSSI มากไปน้อย บอร์ดที่อยู่ใกล้ที่สุดจึงขึ้นบนสุด ช่วยให้แอดมินเลือกถูกตัวเมื่อมีหลายบอร์ด

### _connect() — เชื่อมต่อและค้นหา Service (จุดที่แก้ปัญหา Windows)

เมธอดส่วนตัวนี้ถูกเรียกจากทุกเมธอดที่ต้องเชื่อมต่อ ผลลัพธ์คือ `_BleConnection` ที่ถือ Characteristic ทั้ง 5 ตัวไว้พร้อมใช้

```dart
  Future<_BleConnection> _connect(BluetoothDevice device) async {
    await FlutterBluePlus.stopScan();
    if (device.isConnected) {
      await device.disconnect();
      await Future<void>.delayed(const Duration(milliseconds: 900));
    }

    Object? connectError;
    try {
      // WinRT performs an uncached GATT query inside connect(). Wait for that
      // operation before asking for services. Calling discoverServices() while
      // autoConnect is still discovering can leave both operations waiting.
      await device.connect(
        license: License.nonprofit,
        timeout: const Duration(seconds: 45),
      );
    } catch (error) {
      connectError = error;
    }

    if (!device.isConnected) {
      try {
        await device.connectionState
            .where(
              (state) => state == BluetoothConnectionState.connected,
            )
            .first
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        throw BleProvisioningException(
          'Bluetooth connection stage failed: ${_bleError(connectError)}',
        );
      }
    }

    // A connect timeout can be reported just before WinRT publishes its final
    // state. Keep the valid physical link instead of rapidly reconnecting.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
```

- **บรรทัด 2** — หยุดสแกนก่อนเสมอ วิทยุบลูทูธในเครื่องส่วนใหญ่ทำสแกนกับเชื่อมต่อพร้อมกันได้ไม่ดี (เป็นหนึ่งในการแก้ปัญหาบอร์ดตัวที่สอง)
- **บรรทัด 3–6** — ถ้ายังมีการเชื่อมต่อเก่าค้างอยู่ ให้ตัดก่อนแล้วรอ 900 มิลลิวินาที ให้ทั้งสองฝั่งเคลียร์สถานะ
- **บรรทัด 8** — เก็บ Error ของขั้นเชื่อมต่อไว้ ยังไม่โยนทันที (เหตุผลอยู่บรรทัด 21)
- **บรรทัด 10–12** — คอมเมนต์อธิบายว่าบน Windows (WinRT คือ API บลูทูธของ Windows) คำสั่ง `connect()` แอบค้นหา GATT ไว้ข้างในแล้ว ต้องรอให้จบก่อน ถ้าไปเรียก `discoverServices()` ซ้อนตอนมันยังค้นอยู่ ทั้งสองคำสั่งจะรอกันเองจนค้าง
- **บรรทัด 13–16** — เชื่อมต่อแบบปกติ (ไม่ใช้ autoConnect) ให้เวลานานถึง **45 วินาที** เพราะ Windows ช้ากว่า Android มาก `license: License.nonprofit` เป็นพารามิเตอร์บังคับของ `flutter_blue_plus` รุ่น 2 ที่ประกาศประเภทการใช้งาน
- **บรรทัด 17–19** — ถ้า `connect()` โยน Error (เช่น Timeout) ให้จดไว้ก่อน
- **บรรทัด 21–34** — ตรวจซ้ำว่าเชื่อมต่อได้จริงหรือไม่ บน Windows บางครั้งรายงาน Timeout ออกมา **ก่อน** ที่สถานะจะเปลี่ยนเป็นเชื่อมต่อแล้วเพียงเสี้ยววินาที จึงรอดู `connectionState` อีก 3 วินาที ถ้ายังไม่เชื่อมต่อจริงค่อยโยน Error ที่ขึ้นต้นด้วย `Bluetooth connection stage failed:` ตามด้วย Error จริงจาก Windows ทำให้รู้ทันทีว่าพังที่ขั้นเชื่อมต่อ
- **บรรทัด 36–38** — หน่วงอีก 1.2 วินาทีให้ WinRT และ GATT ของบอร์ดพร้อมก่อนค้นหา Service

```dart
    Object? lastDiscoveryError = connectError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      if (!device.isConnected) {
        throw BleProvisioningException(
          'ESP32 disconnected during Bluetooth service discovery '
          '(attempt $attempt/3).',
        );
      }

      try {
        final services = await device
            .discoverServices()
            .timeout(const Duration(seconds: 20));
        BluetoothService? target;
        for (final service in services) {
          if (service.uuid == serviceUuid) target = service;
        }
        if (target == null) {
          throw const BleProvisioningException(
            'RMUTT ESP32 service was not found after connecting.',
          );
        }
```

- **บรรทัด 2** — ค้นหา Service ได้สูงสุด **3 ครั้งบนการเชื่อมต่อเดิม** (ไม่ตัดแล้วต่อใหม่ทุกครั้ง ซึ่งเป็นต้นเหตุของบั๊กในเวอร์ชันก่อน)
- **บรรทัด 3–8** — ถ้าระหว่างลองบอร์ดหลุดไปแล้ว ไม่มีประโยชน์จะลองต่อ แจ้งเลยว่าหลุดตอนรอบที่เท่าไร
- **บรรทัด 11–13** — สั่งค้นหา Service ทั้งหมด จำกัดเวลา 20 วินาที
- **บรรทัด 14–17** — วนหา Service ที่ UUID ตรงกับ `serviceUuid` ของ RMUTT
- **บรรทัด 18–22** — ไม่เจอ แปลว่าชื่อตรงแต่ไม่ใช่บอร์ดของเรา (หรือเฟิร์มแวร์ผิด) โยน Error

```dart
        BluetoothCharacteristic? config;
        BluetoothCharacteristic? status;
        BluetoothCharacteristic? identity;
        BluetoothCharacteristic? wifiScan;
        BluetoothCharacteristic? settings;
        for (final characteristic in target.characteristics) {
          if (characteristic.uuid == configUuid) config = characteristic;
          if (characteristic.uuid == statusUuid) status = characteristic;
          if (characteristic.uuid == identityUuid) identity = characteristic;
          if (characteristic.uuid == wifiScanUuid) wifiScan = characteristic;
          if (characteristic.uuid == settingsUuid) settings = characteristic;
        }
        if (config == null || status == null || identity == null) {
          throw const BleProvisioningException(
            'ESP32 Bluetooth characteristics are incomplete.',
          );
        }
        return _BleConnection(
          config: config,
          status: status,
          identity: identity,
          wifiScan: wifiScan,
          settings: settings,
        );
```

- **บรรทัด 1–12** — วนหา Characteristic ทั้ง 5 ตัวด้วย UUID
- **บรรทัด 13–17** — สามตัว `config`, `status`, `identity` **บังคับต้องมี** เพราะขาดตัวใดก็ตั้งค่าไม่ได้ ส่วน `wifiScan` และ `settings` **เป็นทางเลือก** (Nullable) เพื่อให้ใช้กับเฟิร์มแวร์รุ่นเก่าที่ยังไม่มีสองตัวนี้ได้ (Backward Compatibility)
- **บรรทัด 18–24** — คืนชุด Characteristic ให้เมธอดที่เรียก

```dart
      } catch (error) {
        lastDiscoveryError = error;
        if (attempt < 3 && device.isConnected) {
          await Future<void>.delayed(Duration(milliseconds: 900 * attempt));
        }
      }
    }

    try {
      await device.disconnect();
    } catch (_) {
      // The discovery error below is more useful than a cleanup error.
    }
    throw BleProvisioningException(
      'Bluetooth service discovery failed after 3 attempts: '
      '${_bleError(lastDiscoveryError)}',
    );
  }
```

- **บรรทัด 1–6** — ถ้ารอบนี้พลาด จด Error ไว้แล้วรอแบบเพิ่มขึ้นเรื่อย ๆ (900, 1800 มิลลิวินาที) เรียกว่า **Backoff** ให้เวลาอุปกรณ์ฟื้นตัวมากขึ้นในแต่ละรอบ
- **บรรทัด 9–13** — ครบ 3 รอบแล้วยังไม่สำเร็จ ให้ตัดการเชื่อมต่อทิ้ง ถ้าการตัดเองพังก็เงียบไว้ เพราะ Error ของการค้นหาสำคัญกว่า
- **บรรทัด 14–17** — โยน Error ที่ขึ้นต้นด้วย `Bluetooth service discovery failed after 3 attempts:` แยกชัดจากกรณีพังที่ขั้นเชื่อมต่อ เมธอด `_bleError()` จะยุบช่องว่างและตัดข้อความให้ยาวไม่เกิน 260 ตัวอักษรเพื่อแสดงบนจอได้ ถ้าไม่มี Error ใดเลยจะแสดง `no error details were returned by Windows`

### readIdentity() — อ่านตัวตนและพิสูจน์ว่าเป็นบอร์ดจริง

```dart
  Future<BleDeviceIdentity> readIdentity(BleDeviceCandidate candidate) async {
    final connection = await _connect(candidate.device);
    try {
      final value = await connection.identity.read(timeout: 12);
      final decoded = jsonDecode(utf8.decode(value));
      if (decoded is! Map<String, dynamic>) {
        throw const BleProvisioningException(
          'ESP32 returned invalid identity data.',
        );
      }
      final identityJson = Map<String, dynamic>.from(decoded);

      // Firmware 1.6+ keeps the first identity read intentionally short for
      // reliable WinRT/Windows GATT reads. Saved board settings live in an
      // optional second characteristic. Older firmware remains compatible
      // because it already returns those fields in the identity value.
      if (identityJson['configured'] == true && connection.settings != null) {
        try {
          final settingsValue = await connection.settings!.read(timeout: 8);
          final settingsDecoded = jsonDecode(utf8.decode(settingsValue));
          if (settingsDecoded is Map<String, dynamic>) {
            identityJson.addAll(settingsDecoded);
          }
        } catch (_) {
          // The core identity is enough to add/verify the board. Reconfigure
          // can continue with database values if the optional read fails.
        }
      }
```

- **บรรทัด 2** — เชื่อมต่อผ่าน `_connect()` ข้างบน
- **บรรทัด 4–5** — อ่าน `identityUuid` (หมดเวลา 12 วินาที) ได้เป็นรายการไบต์ แปลงเป็นข้อความ UTF-8 แล้ว `jsonDecode` เป็น Map
- **บรรทัด 6–10** — ถ้าไม่ใช่ JSON Object ถือว่าข้อมูลเสีย
- **บรรทัด 17** — ถ้าบอร์ดบอกว่า `configured == true` (เคยตั้งค่ามาแล้ว) และมี `settingsUuid` ให้อ่านค่าเดิมเพิ่ม
- **บรรทัด 18–23** — อ่าน `settingsUuid` แล้วรวม (`addAll`) เข้ากับ Identity กลายเป็น Map เดียว
- **บรรทัด 24–27** — ถ้าอ่านส่วนเสริมนี้พลาดก็ **ไม่ล้มทั้งขั้น** เพราะ Identity หลักพอสำหรับยืนยันบอร์ดแล้ว เป็นตัวอย่างของการออกแบบให้ "ส่วนเสริมพังได้โดยไม่ลากส่วนหลักพังตาม"

```dart
      final identity = BleDeviceIdentity.fromJson(identityJson);
      final isAirIdentity = candidate.name.startsWith('RMUTT-AC-') &&
          RegExp(r'^ESP32-[0-9A-F]{12}$').hasMatch(identity.deviceId);
      final isOccupancyIdentity =
          candidate.name.startsWith('RMUTT-OCC-') &&
          RegExp(r'^OCC32-[0-9A-F]{12}$').hasMatch(identity.deviceId) &&
          identity.deviceType == 'occupancy';
      if ((!isAirIdentity && !isOccupancyIdentity) ||
          identity.bleName != candidate.name) {
        throw const BleProvisioningException(
          'Bluetooth name and ESP32 Device ID do not match.',
        );
      }
      return identity;
    } finally {
      await candidate.device.disconnect();
    }
  }
```

- **บรรทัด 1** — แปลง Map เป็นโมเดล `BleDeviceIdentity` (ฟิลด์ที่ไม่มีได้ค่าเริ่มต้น เช่น `deviceType` ไม่มีถือเป็น `'air'`)
- **บรรทัด 2–3** — บอร์ดแอร์ต้องชื่อขึ้นต้น `RMUTT-AC-` และ Device ID ต้องตรงรูปแบบ `ESP32-` ตามด้วยเลขฐานสิบหก 12 ตัว (มาจาก MAC Address ที่ฝังใน eFuse ของชิป จึงไม่ซ้ำกันระหว่างบอร์ด)
- **บรรทัด 4–7** — บอร์ดเซ็นเซอร์ต้องชื่อขึ้นต้น `RMUTT-OCC-` Device ID รูปแบบ `OCC32-...` และประกาศ `deviceType == 'occupancy'`
- **บรรทัด 8–13** — ถ้าไม่เข้าแบบใดเลย หรือชื่อที่บอร์ดรายงานใน Identity (`bleName`) ไม่ตรงกับชื่อที่เห็นตอนสแกน ให้ปฏิเสธ นี่คือการ **พิสูจน์ตัวตนหลังเชื่อมต่อ** ที่ชดเชยการไม่กรอง UUID ตอนสแกน
- **บรรทัด 15–17** — ตัดการเชื่อมต่อเสมอ

### scanWifiNetworks() — ให้ ESP32 สแกน Wi-Fi แทนแอป

เมธอดนี้เชื่อมต่อ ตรวจว่ามี `wifiScanUuid` (ถ้าไม่มีแจ้งให้อัปเดตเฟิร์มแวร์) แล้วอ่านค่า ส่วนที่น่าสนใจคือการแปลงผล

```dart
      final value = await wifiScan.read(timeout: 20);
      final decoded = jsonDecode(utf8.decode(value));
      if (decoded is! Map<String, dynamic> || decoded['ok'] != true) {
        throw BleProvisioningException(
          decoded is Map<String, dynamic>
              ? decoded['message'] as String? ?? 'ESP32 could not scan Wi-Fi.'
              : 'ESP32 returned invalid Wi-Fi scan data.',
        );
      }
      final rawNetworks = decoded['networks'];
      if (rawNetworks is! List) {
        throw const BleProvisioningException(
          'ESP32 returned invalid Wi-Fi scan data.',
        );
      }

      final networks = <WifiNetworkCandidate>[];
      for (final rawNetwork in rawNetworks) {
        if (rawNetwork is! List) continue;
        try {
          final network = WifiNetworkCandidate.fromCompactJson(rawNetwork);
          if (network.ssid.trim().isNotEmpty) networks.add(network);
        } on FormatException {
          // Ignore one malformed entry while keeping the other scan results.
        }
      }
      networks.sort((left, right) => right.rssi.compareTo(left.rssi));
      return networks;
```

- **บรรทัด 1** — การอ่านครั้งนี้ใช้เวลานานเพราะบอร์ดต้องสแกนวิทยุ Wi-Fi จริง (Callback `onRead` ในเฟิร์มแวร์เรียก `WiFi.scanNetworks`) จึงให้เวลาถึง 20 วินาที
- **บรรทัด 3–9** — บอร์ดตอบ `{"ok":false,"message":...}` ได้ถ้าสแกนล้มเหลว แอปจะแสดงข้อความของบอร์ดตรง ๆ
- **บรรทัด 10–15** — ตรวจว่า `networks` เป็นรายการ
- **บรรทัด 17–26** — แต่ละเครือข่ายมาในรูป **Compact JSON** คืออาร์เรย์ 3 ช่อง `[ssid, rssi, isSecure]` แทน Object ที่มีชื่อฟิลด์ เพื่อประหยัดไบต์ (เหตุผลเรื่อง MTU) ถ้ารายการไหนรูปแบบเพี้ยน `fromCompactJson` จะโยน `FormatException` แล้วข้ามเฉพาะรายการนั้น
- **บรรทัด 27–28** — เรียงตามความแรงสัญญาณ

> [!WHY] ทำไมให้ ESP32 สแกน Wi-Fi ไม่ใช่ให้แอปสแกนเอง
> สิ่งที่สำคัญคือ "บอร์ดมองเห็นเครือข่ายไหน" ไม่ใช่ "โน้ตบุ๊กมองเห็นเครือข่ายไหน" บอร์ดอาจติดตั้งอยู่บนเพดานห้องที่สัญญาณต่างจากจุดที่แอดมินยืน และ ESP32 รองรับเฉพาะ Wi-Fi 2.4 GHz ถ้าแอปสแกนเองอาจโชว์เครือข่าย 5 GHz ที่บอร์ดต่อไม่ได้ การให้บอร์ดสแกนจึงตัดปัญหาเลือก SSID ผิดตั้งแต่ต้น (ข้อความในหน้าจอเขียนชัดว่า "Only Wi-Fi detected by this ESP32 can be selected.")

### provision() — หั่นแพ็กเก็ต เขียน และรอผลทาง Notify

นี่คือเมธอดที่สำคัญที่สุดของไฟล์

```dart
  Future<void> provision(
    BleDeviceCandidate candidate,
    Map<String, dynamic> config,
  ) async {
    final connection = await _connect(candidate.device);
    StreamSubscription<List<int>>? statusSubscription;
    try {
      final completer = Completer<Map<String, dynamic>>();
      statusSubscription = connection.status.onValueReceived.listen((value) {
        try {
          final decoded = jsonDecode(utf8.decode(value));
          if (decoded is Map<String, dynamic> && !completer.isCompleted) {
            completer.complete(decoded);
          }
        } catch (_) {
          // Ignore malformed notifications and keep waiting for a valid ACK.
        }
      });
      candidate.device.cancelWhenDisconnected(statusSubscription);
      await connection.status.setNotifyValue(true);
```

- **บรรทัด 3** — รับ `config` ที่เป็น Map ของ JSON ทั้งก้อน (สร้างโดย `toBleJson()` ในโมเดล)
- **บรรทัด 8** — `Completer` คือ "สัญญาว่าจะมีค่าในอนาคต" ที่เราเป็นคนกำหนดเองว่าจะเติมค่าเมื่อไร ใช้แปลงเหตุการณ์ Notify (ซึ่งมาแบบ Callback) ให้กลายเป็น `Future` ที่ `await` รอได้
- **บรรทัด 9–18** — ฟังค่าที่ถูก Notify มาจาก `statusUuid` ทุกครั้งที่ได้ JSON ถูกต้องและ Completer ยังไม่ถูกเติม ก็เติมค่าลงไป (เอาเฉพาะคำตอบแรก) ถ้า JSON เสียก็ข้าม รอค่าถัดไป
- **บรรทัด 19** — ผูกให้การฟังนี้ถูกยกเลิกอัตโนมัติถ้าการเชื่อมต่อหลุด ป้องกัน Memory Leak (หน่วยความจำรั่ว)
- **บรรทัด 20** — **เปิด Notify หลังจากสมัครฟังแล้ว** ลำดับนี้สำคัญ ถ้าเปิดก่อน คำตอบที่มาเร็วอาจหลุดไปโดยไม่มีใครรับ

```dart
      final payload = utf8.encode(jsonEncode(config));
      const dataBytesPerPacket = 150;
      final total = (payload.length / dataBytesPerPacket).ceil();
      for (var sequence = 0; sequence < total; sequence++) {
        final start = sequence * dataBytesPerPacket;
        final end = min(start + dataBytesPerPacket, payload.length);
        final packet = <int>[
          1,
          1,
          sequence >> 8,
          sequence & 0xFF,
          total >> 8,
          total & 0xFF,
          ...payload.sublist(start, end),
        ];
        await connection.config.write(
          packet,
          withoutResponse: false,
          timeout: 15,
        );
      }
```

- **บรรทัด 1** — แปลง Map เป็นข้อความ JSON แล้วเป็นไบต์ UTF-8 (ต้องเป็นไบต์ เพราะ SSID ภาษาไทยหนึ่งตัวอักษรใช้ 3 ไบต์ การนับเป็นตัวอักษรจะผิด)
- **บรรทัด 2–3** — ชิ้นละ 150 ไบต์ คำนวณจำนวนชิ้นด้วยการหารปัดขึ้น เช่น 420 ไบต์ ได้ 3 ชิ้น
- **บรรทัด 4–6** — หาช่วงไบต์ของชิ้นนี้ ชิ้นสุดท้ายอาจสั้นกว่า 150 จึงใช้ `min`
- **บรรทัด 7–15** — สร้างแพ็กเก็ต = **หัว 6 ไบต์** + ข้อมูล
  - ไบต์ 0 = `1` เวอร์ชันโปรโตคอล
  - ไบต์ 1 = `1` ประเภทข้อความ (ข้อมูลตั้งค่า)
  - ไบต์ 2–3 = ลำดับชิ้น (Sequence) แบบ 16 บิต แยกเป็นไบต์สูง (`>> 8`) และไบต์ต่ำ (`& 0xFF`) เรียกว่าแบบ Big-Endian
  - ไบต์ 4–5 = จำนวนชิ้นทั้งหมด (Total) แบบเดียวกัน
  - `...payload.sublist(start, end)` คือ Spread Operator เทข้อมูลชิ้นนี้ต่อท้าย
- **บรรทัด 16–20** — เขียนแบบ **มีการตอบรับ** และ `await` ทีละชิ้น จึงรับประกันลำดับ ชิ้นถัดไปจะไม่ถูกส่งจนกว่าชิ้นก่อนหน้าจะถูกยืนยันว่าถึงแล้ว

```dart
      final ack = await completer.future.timeout(
        const Duration(seconds: 40),
        onTimeout: () => throw const BleProvisioningException(
          'ESP32 did not finish testing Wi-Fi or saving the configuration.',
        ),
      );
      if (ack['ok'] != true) {
        throw BleProvisioningException(
          ack['message'] as String? ?? 'ESP32 rejected the configuration.',
        );
      }
    } finally {
      await statusSubscription?.cancel();
      await candidate.device.disconnect();
    }
  }
```

- **บรรทัด 1–6** — รอคำตอบจาก Notify ได้นานสุด 40 วินาที เพราะบอร์ดต้องต่อ JSON ตรวจค่า แล้ว **ลองเชื่อม Wi-Fi จริง** (เฟิร์มแวร์ให้เวลา `WIFI_PROVISION_TIMEOUT_MS = 15000` คือ 15 วินาที) ก่อนจะตอบ
- **บรรทัด 7–11** — ถ้า `ok` ไม่ใช่ `true` ให้แสดง `message` ที่บอร์ดส่งมา เช่น `"Unable to connect to Wi-Fi. Check the SSID and password, then try again."` หรือ `"Required settings are invalid"`
- **บรรทัด 12–15** — ยกเลิกการฟังและตัดการเชื่อมต่อเสมอ

ฝั่ง ESP32 จะนำชิ้นมาต่อกันใน Callback `onWrite` ของ `ConfigCallbacks` (อธิบายละเอียดในบทเฟิร์มแวร์) ส่วนที่ตรวจหัวแพ็กเก็ตมีหน้าตาแบบนี้

ไฟล์: `firmware/rmutt_esp32_air/rmutt_esp32_air.ino`

```cpp
    const uint16_t sequence =
        (static_cast<uint16_t>(data[2]) << 8) | data[3];
    const uint16_t total =
        (static_cast<uint16_t>(data[4]) << 8) | data[5];
    if (total == 0 || total > 32 || sequence >= total) {
      notifyBle(false, "invalid_packet", "Invalid BLE sequence");
      return;
    }
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
```

- **บรรทัด 1–4** — ประกอบเลข 16 บิตกลับจากสองไบต์ ตรงข้ามกับที่แอปแยก
- **บรรทัด 5–8** — รับไม่เกิน 32 ชิ้น และลำดับต้องน้อยกว่าจำนวนทั้งหมด (ขนาด JSON รวมยังถูกจำกัดด้วย `MAX_CONFIG_BYTES = 4096` อีกชั้น)
- **บรรทัด 9–14** — ชิ้นที่ 0 คือสัญญาณเริ่มข้อความใหม่ ล้างบัฟเฟอร์เก่าทิ้ง ทำให้ "กดบันทึกซ้ำ" ได้โดยไม่มีเศษข้อมูลรอบก่อนปน
- **บรรทัด 15–21** — ถ้าชิ้นมาผิดลำดับ ทิ้งทั้งหมดแล้ว Notify กลับว่า `sequence_error`

---

## models/provisioning.dart — รูปร่างข้อมูลที่ไหลในระบบ

ไฟล์นี้กำหนดโมเดลทั้งหมดของการ Provisioning

| คลาส | มาจาก/ไปที่ | สาระสำคัญ |
|---|---|---|
| `BleDeviceCandidate` | ผลสแกน | `device`, `name`, `rssi` |
| `WifiNetworkCandidate` | ผลอ่าน `wifiScanUuid` | สร้างจาก `fromCompactJson([ssid, rssi, isSecure])` และตรวจชนิดทุกช่อง |
| `BleDeviceIdentity` | Identity + Settings | `deviceId`, `bleName`, `firmwareVersion`, `configured`, `deviceType`, ค่าที่บันทึกไว้ และ `hasWifiPassword` / `hasMqttPassword` (บอร์ดบอกแค่ว่า "มีรหัสแล้ว" ไม่ส่งรหัสจริงออกมา) `controlType` ค่าสำรอง `'ir'`, `brand` ค่าสำรองว่าง และ getter `isWired` (โค้ดทีละบรรทัดอยู่ในบทสถาปัตยกรรม) |
| `AirProvisioningRequest` | ค่าที่แอดมินกรอก | มีเมธอด `toReservationJson()` (ส่ง Backend) และ `toBleJson()` (ส่งบอร์ด) |
| `AirProvisioningReservation` | คำตอบจาก Backend | `provisioningToken`, `mqttHost`, `mqttPort`, `mqttUsername`, `mqttPassword`, `mqttTls`, `mqttTopic` |
| `OccupancyProvisioningRequest` / `OccupancyProvisioningReservation` | คู่ของเซ็นเซอร์ | เหมือนกันแต่ไม่มีหมายเลขแอร์ ชื่อ โปรโตคอล และเวลาอัตโนมัติ มี `staticThreshold` แทน |

จุดที่ควรเข้าใจคือ **ข้อมูลถูกส่งสองทาง** ข้อมูลที่ส่งให้ Backend (`toReservationJson`) มีแค่ `deviceId`, `bleName`, `roomNumber`, `airNumber`, `name`, `protocol`, `dailyOn`, `dailyOff` ไม่มีรหัส Wi-Fi เลย ส่วนข้อมูลที่ส่งให้บอร์ดคือ

ไฟล์: `lib/models/provisioning.dart`

```dart
  Map<String, dynamic> toBleJson(AirProvisioningReservation reservation) => {
    'version': 1,
    'deviceId': identity.deviceId,
    'token': reservation.provisioningToken,
    'roomNumber': roomNumber,
    'airNumber': airNumber,
    'name': name,
    'airProtocol': protocol,
    'wifi': {
      'ssid': wifiSsid,
      'password': wifiPassword,
      'keepPassword': keepWifiPassword,
    },
    'mqtt': {
      'host': reservation.mqttHost,
      'port': reservation.mqttPort,
      'username': reservation.mqttUsername,
      'password': reservation.mqttPassword,
      'keepPassword': false,
      'topic': reservation.mqttTopic,
      'tls': reservation.mqttTls,
    },
    'schedule': {
      'dailyOn': dailyOn,
      'dailyOff': dailyOff,
      'timezone': 'Asia/Bangkok',
    },
  };
```

- **บรรทัด 1** — รับ `reservation` ที่ได้จาก Backend เข้ามาผสม แปลว่าสร้าง JSON นี้ได้ **หลังจาก** จองกับ Backend สำเร็จแล้วเท่านั้น
- **บรรทัด 2** — `version` เผื่ออนาคตเปลี่ยนรูปแบบ JSON บอร์ดจะรู้ว่าต้องอ่านแบบไหน
- **บรรทัด 3** — `deviceId` บอร์ดจะเทียบกับ ID ของตัวเอง ถ้าไม่ตรงจะปฏิเสธ (กันส่งค่าผิดบอร์ด)
- **บรรทัด 4** — `token` คือ Provisioning Token แบบใช้ครั้งเดียวที่ Backend ออกให้ บอร์ดจะใช้ยืนยันตัวกับ Backend ผ่าน MQTT ภายหลัง
- **บรรทัด 5–8** — ห้อง หมายเลขแอร์ ชื่อ และโปรโตคอล (ยี่ห้อรีโมต IR หรือ `DAIKIN_WIRED` สำหรับบอร์ดสายแอร์)
- **บรรทัด 9–13** — ข้อมูล Wi-Fi ที่แอดมินกรอก `keepPassword` บอกบอร์ดว่า "ใช้รหัสเดิมที่เก็บไว้" (ใช้ตอนตั้งค่าใหม่โดยไม่เปลี่ยนรหัส)
- **บรรทัด 14–22** — ข้อมูล MQTT **ทั้งหมดมาจาก Backend** ไม่ใช่จากแอดมิน รวมถึงชื่อผู้ใช้และรหัสผ่าน MQTT เฉพาะบอร์ดตัวนั้น และ `tls` บอกว่าต้องต่อแบบเข้ารหัส (พอร์ต 8883) หรือไม่
- **บรรทัด 23–27** — เวลาเปิด/ปิดอัตโนมัติรายวัน พร้อมเขตเวลา `Asia/Bangkok`

> [!WHY] ทำไมไม่ให้แอดมินกรอกค่า MQTT เอง
> รุ่นแรก ๆ ของโปรเจคให้กรอก Host/Port/Username/Password ของ MQTT ในหน้าจอ ซึ่งผิดพลาดง่ายและทำให้รหัส Broker กระจายอยู่ในมือคน การย้ายมาให้ Backend เป็นผู้ออกค่าทำให้ (1) แอดมินกรอกน้อยลง (2) Backend สร้างบัญชี MQTT เฉพาะบอร์ดได้ (โหมด `dynsec` ของ Mosquitto ที่แต่ละบอร์ดเห็นเฉพาะ Topic ของตัวเอง) และ (3) เปลี่ยนเซิร์ฟเวอร์ได้ที่จุดเดียว หน้าจอจึงเขียนบอกผู้ใช้ว่า "MQTT is configured automatically by the server."

---

## ble_provisioning_screen.dart — หน้าจอตั้งค่าบอร์ดแอร์

### ค่าที่หน้าจอรับเข้ามาและสถานะภายใน

หน้าจอนี้เป็น `StatefulWidget` รับค่าจากหน้าห้อง ได้แก่ `roomNumber` (ห้องที่จะติดตั้ง), `usedAirNumbers` (หมายเลขแอร์ที่มีแล้วในห้อง), `repository` (ตัวยิง API ของแอร์), `bleService` และ `existingAir` (ถ้าไม่ใช่ `null` แปลว่าเป็นโหมด **ตั้งค่าใหม่** ของแอร์ที่มีอยู่แล้ว)

สถานะภายในสำคัญ ได้แก่ `_devices` (ผลสแกน), `_selectedDevice`, `_identity` (ผลยืนยันบอร์ด ถ้ายังเป็น `null` ฟอร์มขั้น 2–4 จะยังไม่แสดง), `_airNumber`, `_protocol` (ค่าเริ่มต้น `'HAIER_AC160'` ถ้าเป็นโหมดตั้งค่าใหม่ใช้ `protocol` ของแอร์เดิม และบอร์ดสายแอร์ถูกบังคับเป็น `'DAIKIN_WIRED'` หลังอ่าน identity), `_dailyOn`/`_dailyOff` และธงสถานะการทำงาน `_isScanning`, `_isScanningWifi`, `_isReadingIdentity`, `_isProvisioning` ซึ่งใช้ปิดปุ่มระหว่างทำงานเพื่อกันกดซ้ำ

หมายเลขแอร์ที่เลือกได้คำนวณจาก Getter `_availableAirNumbers` คือเลข 1–6 ที่ยังไม่อยู่ใน `usedAirNumbers` ถ้าเป็นโหมดตั้งค่าใหม่จะล็อกไว้ที่หมายเลขเดิมเท่านั้น (Dropdown ถูกปิดด้วย `onChanged: null`) และใน `initState` ถ้าเป็นโหมดตั้งค่าใหม่ จะสั่ง `_scan()` ให้อัตโนมัติหลังเฟรมแรกวาดเสร็จ (`addPostFrameCallback`)

### _scan() — สแกนและเลือกบอร์ดเดิมให้อัตโนมัติ

เมธอดล้างสถานะเก่า เรียก `widget.bleService.scan()` แล้วจัดการกรณีพิเศษของโหมดตั้งค่าใหม่

ไฟล์: `lib/screens/ble_provisioning_screen.dart`

```dart
      BleDeviceCandidate? matchingDevice;
      final expectedName = widget.existingAir?.bleName;
      final expectedDeviceId = widget.existingAir?.deviceId;
      for (final candidate in devices) {
        if ((expectedName != null && candidate.name == expectedName) ||
            (expectedDeviceId != null &&
                candidate.name == 'RMUTT-AC-${expectedDeviceId.substring(6)}')) {
          matchingDevice = candidate;
          break;
        }
      }
```

- **บรรทัด 2–3** — ดึงชื่อ BLE และ Device ID ที่บันทึกไว้ในฐานข้อมูลของแอร์เครื่องเดิม
- **บรรทัด 5–7** — เทียบชื่อตรง ๆ หรือสร้างชื่อจาก Device ID (`substring(6)` ตัด `ESP32-` ออก แล้วต่อท้าย `RMUTT-AC-`) ซึ่งเป็นกฎเดียวกับที่เฟิร์มแวร์ตั้งชื่อตัวเอง
- **บรรทัด 8–9** — เจอแล้วจะเรียก `_selectDevice()` ต่อทันที แอดมินจึงไม่ต้องหาบอร์ดเองในรายการ

ถ้าไม่พบบอร์ดเลยจะแสดง "No RMUTT ESP32 was found nearby." และทุก Error จะถูกเก็บใน `_errorMessage` แล้วแสดงใน `_BleErrorCard`

### _selectDevice() — ยืนยันตัวตนบอร์ด

```dart
  Future<void> _selectDevice(BleDeviceCandidate candidate) async {
    setState(() {
      _selectedDevice = candidate;
      _identity = null;
      _isReadingIdentity = true;
      _errorMessage = null;
    });
    try {
      final identity = await widget.bleService.readIdentity(candidate);
      if (!mounted) return;
      final expectedDeviceId = widget.existingAir?.deviceId;
      if (expectedDeviceId != null && identity.deviceId != expectedDeviceId) {
        throw BleProvisioningException(
          context.tr(
            'Select the same ESP32 that is already assigned to this air conditioner.',
          ),
        );
      }
      setState(() {
        _identity = identity;
        _applySavedBoardSettings(identity);
        _protocolForBoard(identity);
      });
```

- **บรรทัด 2–7** — ตั้งสถานะว่ากำลังอ่าน ล้าง Identity เก่า (ฟอร์มด้านล่างจะหายไปก่อน) และล้าง Error
- **บรรทัด 9** — เรียก `readIdentity()` ซึ่งเชื่อมต่อ อ่าน และพิสูจน์ตัวตนตามที่อธิบายแล้ว
- **บรรทัด 10** — `mounted` คือการเช็กว่าหน้าจอยังเปิดอยู่ไหม ถ้าผู้ใช้กดย้อนกลับไประหว่างรอ ห้ามเรียก `setState` ต่อ (จะเกิด Error)
- **บรรทัด 11–18** — โหมดตั้งค่าใหม่ต้องเลือกบอร์ด **ตัวเดิม** เท่านั้น กันกรณีแอดมินเผลอเลือกบอร์ดข้างห้อง
- **บรรทัด 19–23** — เก็บ Identity (ทำให้ฟอร์มขั้น 2–4 แสดง) และเติมค่าที่บอร์ดบันทึกไว้ลงฟอร์มผ่าน `_applySavedBoardSettings()` (ทำเฉพาะโหมดตั้งค่าใหม่และบอร์ดที่ `configured` แล้ว: ชื่อ โปรโตคอล SSID เวลาอัตโนมัติ และ **ล้างช่องรหัสผ่านให้ว่าง**) แล้ว `_protocolForBoard()` แก้โปรโตคอลให้เข้ากับชนิดบอร์ด เรียก **หลัง** `_applySavedBoardSettings` เพื่อให้ชนะค่าที่อ่านมาจากบอร์ดหรือฐานข้อมูล (ดูหัวข้อถัดไป)

ส่วนที่เหลือของเมธอดใช้ `Scrollable.ensureVisible` เลื่อนหน้าจอไปที่กล่อง Device ID (อ้างด้วย `GlobalKey` ชื่อ `_detailsKey`) และในบล็อก `finally` ปิดธง `_isReadingIdentity`

### บอร์ดสายแอร์ Daikin: ล็อกยี่ห้อ

บอร์ด `rmutt_esp32_air_wired` ใช้ชื่อ BLE `RMUTT-AC-...` เหมือนบอร์ด IR การสแกนและเชื่อมต่อจึงเหมือนเดิมทุกอย่าง ต่างกันแค่ identity ที่อ่านได้มี `controlType: "wired"` และ `brand: "Daikin"` หน้าจอใช้ค่านี้ 3 จุด

**จุดที่ 1: กล่องเขียวบอกชนิดบอร์ด** — ไฟล์ `lib/screens/ble_provisioning_screen.dart` บรรทัด 186–206

```dart:186
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_identity!.deviceId}\n'
                            'Firmware ${_identity!.firmwareVersion}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.tr(
                              _identity!.isWired
                                  ? 'Board type: wired controller (replaces the wall remote)'
                                  : 'Board type: IR remote',
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
```

| บรรทัด | อธิบาย |
|---|---|
| 186–188 | ใช้ `Column` ชิดซ้ายเพื่อซ้อนสองข้อความ (ชื่อบอร์ดกับป้ายชนิดการควบคุม) |
| 189–195 | Device ID กับเวอร์ชันเฟิร์มแวร์ (เหมือนเดิม) `\n` คือขึ้นบรรทัดใหม่ และสตริงสองท่อนที่วางติดกันถูกต่อเป็นสตริงเดียว |
| 197–204 | `_identity!` (`!` = ยืนยันว่าไม่เป็น null เพราะส่วนนี้แสดงเฉพาะหลังยืนยันบอร์ดแล้ว) ถ้า `isWired` แสดง "ชนิดบอร์ด: ควบคุมผ่านสายแอร์ (ใช้แทนรีโมตติดผนัง)" ไม่งั้น "ชนิดบอร์ด: รีโมต IR" |

**จุดที่ 2: เลือกช่องยี่ห้อตามชนิดบอร์ด** — ไฟล์ `lib/screens/ble_provisioning_screen.dart` บรรทัด 265–273

```dart:265
              if (_identity!.isWired)
                _WiredBrandField(brand: _wiredBrand(_identity!))
              else
                DropdownButtonFormField<String>(
                  key: ValueKey('protocol-${_identity!.deviceId}'),
                  initialValue: _protocol,
                  decoration: InputDecoration(
                    labelText: context.tr('Air Conditioner Brand / Protocol'),
                  ),
```

| บรรทัด | อธิบาย |
|---|---|
| 265–266 | บอร์ดสายแอร์ แสดงช่องแบบล็อก `_WiredBrandField` (เลือกไม่ได้) |
| 267–268 | บอร์ด IR แสดง Dropdown 18 ยี่ห้อ/รุ่นเหมือนเดิม (ไม่มี `DAIKIN_WIRED` ในรายการ) |
| 269 | **ใหม่:** `key: ValueKey('protocol-<deviceId>')` บังคับให้สร้าง Dropdown ใหม่เมื่อเปลี่ยนบอร์ด |
| 270 | `initialValue` ค่าที่เลือกตอนสร้าง |

> [!WHY]
> **ทำไม Dropdown ต้องมี `key`** `DropdownButtonFormField` อ่าน `initialValue` **ครั้งเดียวตอนสร้าง** แล้วจำค่าที่เลือกไว้ใน State ของตัวเอง ถ้าแอดมินเลือกบอร์ดหนึ่งแล้วเปลี่ยนไปเลือกอีกบอร์ด และ `_protocol` ถูกเปลี่ยนในโค้ด (เช่น จาก `DAIKIN_WIRED` เป็น `DAIKIN`) Flutter จะใช้วิดเจ็ตเดิมซ้ำ ช่องบนจอยังแสดงค่าเก่าทั้งที่ตัวแปรเปลี่ยนแล้ว การใส่ `key` ที่มี Device ID ทำให้ Flutter เห็นว่าเป็น "วิดเจ็ตคนละตัว" เมื่อเปลี่ยนบอร์ด จึงสร้างใหม่และอ่าน `initialValue` ใหม่ จอกับตัวแปรจึงตรงกัน

**จุดที่ 3: บังคับโปรโตคอลให้ตรงกับบอร์ด** — ไฟล์ `lib/screens/ble_provisioning_screen.dart` บรรทัด 775–789

```dart:775
  /// บอร์ดสายแอร์ใช้ DAIKIN_WIRED เสมอ (ผู้ใช้ไม่ต้องเลือกยี่ห้อ)
  /// บอร์ด IR ห้ามใช้ DAIKIN_WIRED (เช่น เปลี่ยนบอร์ดสายแอร์ออกแล้วใส่บอร์ด IR แทน)
  void _protocolForBoard(BleDeviceIdentity identity) {
    if (identity.isWired) {
      _protocol = daikinWiredProtocol;
    } else if (_protocol == daikinWiredProtocol) {
      _protocol = 'DAIKIN';
    }
  }

  String _wiredBrand(BleDeviceIdentity identity) {
    return identity.brand.isNotEmpty
        ? identity.brand
        : airBrandOf(daikinWiredProtocol);
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 778–779 | บอร์ดสายแอร์: ตั้ง `_protocol = 'DAIKIN_WIRED'` เสมอ ไม่ว่าเดิมจะเป็นอะไร ค่านี้คือค่าที่ส่งไปจองกับ Backend (`protocol` ใน `toReservationJson`) และเขียนลงบอร์ด (`airProtocol` ใน `toBleJson`) |
| 780–781 | บอร์ด IR แต่ค่าค้างเป็น `DAIKIN_WIRED` (เช่น ถอดบอร์ดสายแอร์ออกแล้วติดบอร์ด IR ที่แอร์เครื่องเดิม ซึ่งแอร์เดิมมี `protocol` เป็น `DAIKIN_WIRED`) เปลี่ยนเป็น `DAIKIN` ซึ่งเป็นยี่ห้อเดียวกันแบบ IR และเป็นค่าที่อยู่ในรายการ Dropdown |
| 785–789 | ชื่อยี่ห้อที่แสดง: ใช้ที่บอร์ดบอก ถ้าบอร์ดไม่บอก (ว่าง) ใช้ `airBrandOf('DAIKIN_WIRED')` = `'Daikin'` |

> [!WHY]
> **ทำไมไม่ให้แอดมินเลือกยี่ห้อเองสำหรับบอร์ดสายแอร์** บอร์ดนี้คุยกับแอร์ด้วยโปรโตคอลของสายรีโมตติดผนัง Daikin เท่านั้น ถ้าเลือกยี่ห้ออื่น เช่น Haier ระบบจะคิดว่ามีปุ่ม Eco/Turbo แต่บอร์ดสั่งไม่ได้ การล็อกไว้ตัดความผิดพลาดนี้ทิ้งตั้งแต่หน้าตั้งค่า และกรณีกลับกัน (บอร์ด IR ห้ามเป็น `DAIKIN_WIRED`) ก็จำเป็น เพราะ `DAIKIN_WIRED` ไม่มีใน Dropdown ถ้าปล่อยไว้ `DropdownButtonFormField` จะได้ `initialValue` ที่ไม่ตรงกับรายการใดเลย ซึ่ง Flutter ตรวจแล้วโยน assertion ตอนรันโหมด debug ส่วน Backend มีด่านสุดท้ายอีกชั้น: บอร์ดสายแอร์รายงาน `controlMode: "wired"` ใน status ทุกครั้ง ถ้าแถวในฐานข้อมูลยังเป็นยี่ห้อ IR Backend แก้เป็น `DAIKIN_WIRED` ให้เอง (`protocolFromStatus` / `syncControlProtocol`)

**ช่องยี่ห้อแบบล็อก `_WiredBrandField`** — ไฟล์ `lib/screens/ble_provisioning_screen.dart` บรรทัด 941–973

```dart:941
/// ช่องยี่ห้อของบอร์ดสายแอร์: แสดงยี่ห้อกับชนิดบอร์ดแบบล็อกไว้ ไม่ให้เลือกยี่ห้อ IR
class _WiredBrandField extends StatelessWidget {
  const _WiredBrandField({required this.brand});

  final String brand;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: context.tr('Air Conditioner Brand / Protocol'),
            suffixIcon: Tooltip(
              message: context.tr('Set by the board'),
              child: const Icon(Icons.lock_outline_rounded),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.cable_rounded, size: 20, color: AppColors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$brand · ${context.tr('Wired (replaces the wall remote)')}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
```

| บรรทัด | อธิบาย |
|---|---|
| 942 | ชื่อขึ้นต้น `_` = ใช้ได้เฉพาะในไฟล์นี้ |
| 953 | `InputDecorator` วาด "กรอบและป้ายชื่อ" แบบเดียวกับช่องกรอกอื่นในฟอร์ม แต่ข้างในใส่อะไรก็ได้ และ **ไม่รับการพิมพ์** ช่องนี้จึงหน้าตาเข้าชุดกับฟอร์มแต่แก้ไม่ได้ |
| 955 | ป้ายชื่อเดียวกับ Dropdown ("ยี่ห้อแอร์ / โปรโตคอล") ผู้ใช้รู้ว่าเป็นช่องเดียวกัน |
| 956–959 | ไอคอนแม่กุญแจท้ายช่อง ชี้แล้วขึ้น "บอร์ดกำหนดให้" |
| 963 | ไอคอนสายไฟสีฟ้า สีและไอคอนเดียวกับ `AirControlBadge` ของสายแอร์ |
| 965–970 | ข้อความ "Daikin · สายแอร์ (ใช้แทนรีโมตติดผนัง)" `Expanded` ให้ข้อความยาวตัดบรรทัดได้ไม่ล้นจอ |

บรรทัด 974–997 ต่อด้วยกล่องฟ้า (`Container` พื้น `AppColors.blue` โปร่ง 10% ขอบโปร่ง 35%) ไอคอน ⓘ และข้อความ "บอร์ดนี้ต่อเข้ากับสายแอร์แทนรีโมตติดผนัง Daikin ใช้ได้: เปิด/ปิด, 16–30 °C, Cool / Dry / Fan, พัดลม Low / Medium / High / Auto, ส่าย เปิด/ปิด และ Sleep" ซึ่งตรงกับกติกาใน `AirConditioner.supportsXxx` ทุกข้อ แอดมินจึงรู้ข้อจำกัดก่อนบันทึก

### _scanWifiNetworks() — เลือก SSID จากรายการของบอร์ด

ช่อง SSID เป็น `readOnly: true` แตะแล้วเรียกเมธอดนี้ ซึ่งตรวจว่ายืนยันบอร์ดแล้ว เรียก `scanWifiNetworks()` แล้วเปิด `showModalBottomSheet` แสดงรายการ แต่ละแถวมีไอคอนกุญแจล็อก/ปลดล็อก (`isSecure`) ชื่อ และ dBm แตะแล้ว Sheet ปิดพร้อมคืนชื่อ SSID มาใส่ช่อง ถ้าไม่พบเครือข่ายเลยจะแจ้งว่า "No Wi-Fi network was detected. You can enter the SSID manually."

### กฎการเก็บรหัส Wi-Fi เดิม

```dart
  bool _shouldKeepWifiPassword(BleDeviceIdentity identity) {
    return _wifiPassword.text.isEmpty &&
        identity.configured &&
        identity.hasWifiPassword &&
        _wifiSsid.text.trim() == identity.wifiSsid;
  }

  String? _validateWifiPassword(String? value) {
    final password = value ?? '';
    if (password.length >= 8) return null;
    final identity = _identity;
    if (identity != null &&
        _shouldKeepWifiPassword(identity)) {
      return null;
    }
    return context.tr('Enter at least 8 characters');
  }
```

- **บรรทัด 1–6** — จะ "ใช้รหัสเดิม" ได้ต้องครบ 4 เงื่อนไข: ช่องรหัสว่าง บอร์ดเคยตั้งค่าแล้ว บอร์ดมีรหัสเก็บอยู่ และ SSID ยังเป็นตัวเดิม (ถ้าเปลี่ยน SSID แต่ไม่ใส่รหัส ก็ไม่มีรหัสที่ถูกต้องให้ใช้)
- **บรรทัด 8–17** — Validator ของช่องรหัสผ่าน ผ่านถ้ายาวอย่างน้อย 8 ตัว (ความยาวขั้นต่ำของ WPA2) หรือเข้ากรณีใช้รหัสเดิม

> [!WHY] ทำไมบอร์ดไม่ส่งรหัส Wi-Fi เดิมกลับมาให้แอป
> ถ้าบอร์ดยอมส่งรหัส Wi-Fi ออกทาง BLE ใครก็ตามที่อยู่ใกล้ ๆ ตอนบอร์ดอยู่ในโหมดตั้งค่าจะอ่านรหัสได้ บอร์ดจึงบอกแค่ `hasWifiPassword: true` แล้วให้แอปส่ง `keepPassword: true` กลับไป บอร์ดค่อยใช้รหัสในหน่วยความจำของมันเอง รหัสจึงไม่เคยออกจากบอร์ดเลย

### _provision() — ปุ่มบันทึก (แกนหลักของหน้าจอ)

```dart
  Future<void> _provision() async {
    if (!_formKey.currentState!.validate()) return;
    final identity = _identity;
    final candidate = _selectedDevice;
    final airNumber = _airNumber;
    if (identity == null || candidate == null || airNumber == null) {
      setState(() {
        _errorMessage = context.tr(
          'Select and verify an ESP32 before saving.',
        );
      });
      return;
    }

    setState(() {
      _isProvisioning = true;
      _errorMessage = null;
    });
    final request = AirProvisioningRequest(
      identity: identity,
      roomNumber: widget.roomNumber,
      airNumber: airNumber,
      name: _name.text.trim(),
      protocol: _protocol,
      wifiSsid: _wifiSsid.text.trim(),
      wifiPassword: _wifiPassword.text,
      keepWifiPassword: _shouldKeepWifiPassword(identity),
      dailyOn: _timeValue(_dailyOn),
      dailyOff: _timeValue(_dailyOff),
    );
```

- **บรรทัด 2** — รัน Validator ทุกช่องในฟอร์ม (ชื่อห้ามว่าง SSID ห้ามว่าง รหัสตามกฎข้างบน) ถ้าไม่ผ่าน Flutter จะแสดงข้อความใต้ช่องเอง แล้วหยุด
- **บรรทัด 3–13** — คัดลอกค่าลงตัวแปรท้องถิ่นก่อน (เพราะเป็น Nullable และอาจเปลี่ยนระหว่าง `await`) แล้วตรวจว่าครบ
- **บรรทัด 15–18** — เปิดธง `_isProvisioning` ปุ่มบันทึกจะกลายเป็นวงหมุนและกดซ้ำไม่ได้
- **บรรทัด 19–30** — รวมค่าทั้งหมดเป็น `AirProvisioningRequest` สังเกตว่า SSID ถูก `trim()` แต่ **รหัสผ่านไม่ถูก trim** เพราะช่องว่างอาจเป็นส่วนหนึ่งของรหัสจริง เวลาแปลงจาก `TimeOfDay` เป็นข้อความ `HH:mm` ด้วย `_timeValue()`

```dart
    try {
      final reservation = await widget.repository.reserve(request);
      await widget.bleService.provision(
        candidate,
        request.toBleJson(reservation),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Wi-Fi verified and configuration saved. ESP32 is connecting to MQTT.',
            ),
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        final retryHint = context.tr(
          'Correct the Wi-Fi password and press Save again. You do not need to scan for the ESP32 again.',
        );
        setState(() {
          _errorMessage = '${context.tr('$error')}\n$retryHint';
        });
      }
    } finally {
      if (mounted) setState(() => _isProvisioning = false);
    }
  }
```

- **บรรทัด 2** — **ขั้นจองกับ Backend ก่อน** (`POST /air-conditioners/reservations`) Backend ตรวจห้องมีจริง Device ID ไม่ซ้ำ ห้อง+หมายเลขแอร์ไม่ซ้ำ แล้วคืน Token และค่า MQTT ถ้าซ้ำจะได้ HTTP 409 พร้อมข้อความภาษาไทย เช่น "ห้อง 16101 มีแอร์หมายเลข 2 แล้ว" และ **จะไม่มีอะไรถูกเขียนลงบอร์ดเลย**
- **บรรทัด 3–6** — จองสำเร็จแล้วจึงสร้าง JSON (`toBleJson(reservation)`) และเขียนลงบอร์ดผ่าน BLE
- **บรรทัด 7–16** — สำเร็จ แสดง SnackBar ข้อความสื่อชัดว่า "Wi-Fi ผ่านแล้ว บอร์ดกำลังต่อ MQTT" (ยังไม่ใช่ Active สมบูรณ์)
- **บรรทัด 17** — ปิดหน้าจอพร้อมคืนค่า `true` ให้หน้าห้องรู้ว่าต้องรีเฟรช
- **บรรทัด 18–26** — ทุก Error (ทั้งจาก API และจาก BLE) แสดงพร้อมคำแนะนำว่าแก้รหัสแล้วกดบันทึกซ้ำได้เลย เพราะ `_selectedDevice` และ `_identity` ยังอยู่ ไม่ต้องสแกนใหม่
- **บรรทัด 27–29** — ปิดธงทำงานเสมอ

> [!WHY] ทำไมต้องจองกับ Backend ก่อนเขียนลงบอร์ด
> ถ้าเขียนลงบอร์ดก่อนแล้วค่อยไปบอก Backend อาจเกิดกรณีบอร์ดถูกตั้งค่าเรียบร้อย แต่ Backend ปฏิเสธเพราะหมายเลขแอร์ซ้ำ บอร์ดจะกลายเป็น "ผี" ที่ต่อ MQTT ด้วยค่าที่ไม่มีใครรู้จัก การจองก่อนทำให้ Backend เป็นผู้ตัดสินกฎทั้งหมดก่อนแตะฮาร์ดแวร์ และยังได้ Token กับรหัส MQTT ที่ต้องใช้ใน JSON ด้วย ส่วนกรณีจองแล้วแต่เขียนบอร์ดไม่สำเร็จ (เช่น รหัส Wi-Fi ผิด) แถวที่จองจะอยู่ในสถานะ `reserved` และหมดอายุเองใน 15 นาที ถ้ากดบันทึกซ้ำ Backend จะลบแถว `reserved` ของบอร์ดเดิมแล้วออก Token ใหม่ให้ จึงไม่มีขยะค้าง

### ส่วน UI ที่เหลือ

ฟอร์มเป็น `ListView` เรียง 4 ขั้นด้วย Widget `_StepHeader` (วงกลมเลขขั้น + หัวข้อ) รายการบอร์ดใช้ `RadioGroup` คู่กับ `RadioListTile` (คอมเมนต์ในโค้ดบอกว่า Flutter 3.35 ขึ้นไปให้ `RadioGroup` ถือค่าที่เลือกแทน `groupValue` ของแต่ละปุ่ม) Dropdown โปรโตคอล (แสดงเฉพาะบอร์ด IR) มี 18 ตัวเลือก ตั้งแต่ `SAIJO_DENKI`, `DAIKIN`, `MITSUBISHI_AC` ไปจนถึงตระกูล Haier หลายรุ่น บอร์ดสายแอร์เห็น `_WiredBrandField` แทน เวลาเปิด/ปิดใช้ `showTimePicker` (ค่าเริ่มต้น 08:00 และ 17:00) และมี Widget `_InfoCard` สำหรับกล่องคำอธิบาย `_BleErrorCard` สำหรับกล่องแดงพร้อมปุ่ม "Try connecting again" ที่เรียก `_selectDevice` ซ้ำกับบอร์ดตัวเดิม

---

## หลังกดบันทึก: Backend และ ESP32 ปิดวงจรให้ครบ

### Backend: POST /air-conditioners/reservations

ไฟล์: `backend/src/routes/air-conditioners.js` (อธิบายละเอียดในบท Backend) ลำดับการทำงานโดยย่อ

1. `requireAdmin` ตรวจสิทธิ์ แล้ว `validateReservationInput` ตรวจรูปแบบข้อมูล
2. ตรวจว่าห้องมีอยู่ ถ้าไม่มีตอบ 400 "ยังไม่มีห้อง ... ในระบบ"
3. ลบแถว `reserved` ที่หมดอายุแล้ว
4. ตรวจซ้ำสองแบบ: ห้อง+หมายเลขแอร์ถูกบอร์ดอื่นใช้ (409) และบอร์ดนี้ถูกลงทะเบียนไว้ที่ห้อง/หมายเลขอื่น (409)
5. สร้าง Token และเก็บเฉพาะ Hash

```js
    const token = crypto.randomBytes(24).toString('base64url');
    const mqttTopic = `${config.mqtt.topicPrefix}/${input.deviceId}`;
    const tokenHash = hashSecret(token, config.otpPepper);
```

- **บรรทัด 1** — สุ่ม 24 ไบต์ด้วยตัวสุ่มที่ปลอดภัยทางการเข้ารหัส แปลงเป็นข้อความ base64url
- **บรรทัด 2** — Topic ของบอร์ดคือ `rmutt/ac/<deviceId>` (ค่าเริ่มต้นของ `MQTT_TOPIC_PREFIX`)
- **บรรทัด 3** — ฐานข้อมูลเก็บแค่ Hash ของ Token (เติม Pepper) ถ้าฐานข้อมูลรั่ว ผู้โจมตีก็เอา Hash ไปแอบอ้างเป็นบอร์ดไม่ได้

6. เตรียมบัญชี MQTT ของบอร์ด (`prepareDeviceCredentials`) ก่อนเขียนฐานข้อมูล ถ้า Broker ไม่พร้อมตอบ 503 โดยไม่ทิ้งแถวค้าง
7. ถ้าเป็นบอร์ดใหม่ `INSERT` สถานะ `'reserved'` หมดอายุ `INTERVAL 15 MINUTE` ถ้าเป็นบอร์ดที่ `active` อยู่แล้ว (ตั้งค่าใหม่) ใช้ `UPDATE` แทน
8. ตอบกลับ `reservation` ที่มี `provisioningToken` (ตัวจริง ส่งครั้งเดียว) ค่า MQTT ทั้งหมด และ `expiresInSeconds: 900`

### ESP32: ตรวจ ทดสอบ Wi-Fi บันทึก แล้วรีสตาร์ต

เมื่อต่อชิ้นครบ เฟิร์มแวร์เรียก `processPendingConfig()` ใน `loop()` ซึ่งอ่าน JSON ตรวจว่า `deviceId` ตรงกับตัวเอง ห้องถูกรูปแบบ หมายเลขแอร์ 1–6 มี Token รหัส Wi-Fi ยาวอย่างน้อย 8 ตัว และโปรโตคอลรองรับ จากนั้น **ลองเชื่อม Wi-Fi จริงก่อนบันทึก** ถ้าไม่ผ่านจะ Notify `wifi_connection_failed` และ **คงค่าเดิมใน NVS ไว้** (NVS คือหน่วยความจำถาวรของ ESP32) ถ้าผ่านจะทำส่วนท้ายนี้

ไฟล์: `firmware/rmutt_esp32_air/rmutt_esp32_air.ino`

```cpp
  incoming.configured = true;
  incoming.bleName = config.bleName;
  saveConfig(incoming);
  config = incoming;
  Serial.println("Configuration saved to NVS");
  Serial.printf(
      "Assigned to room %s, air %u\n",
      config.roomNumber.c_str(),
      config.airNumber);
  notifyBle(
      true,
      "config_saved",
      "Wi-Fi verified and configuration saved to NVS");
  restartAt = millis() + 1500;
}
```

- **บรรทัด 1–4** — ทำเครื่องหมายว่าตั้งค่าแล้ว บันทึกลง NVS และใช้เป็นค่าปัจจุบัน
- **บรรทัด 5–9** — พิมพ์ลง Serial Monitor (ข้อความเดียวกับที่ README บอกให้สังเกต)
- **บรรทัด 10–13** — Notify กลับไปที่แอป `{"ok":true,"code":"config_saved",...}` ตรงนี้เองที่ทำให้ `completer` ในแอปถูกเติมค่า
- **บรรทัด 14** — นัดรีสตาร์ตในอีก 1.5 วินาที (ให้เวลา Notify ส่งออกไปก่อน) ไม่รีสตาร์ตทันทีใน Callback

### MQTT: บอร์ดยืนยันตัวด้วย Token แล้ว Backend เปลี่ยนเป็น active

หลังรีสตาร์ต บอร์ดต่อ Wi-Fi และ MQTT ด้วยค่าใหม่ แล้วเรียก `publishProvisioningToken()` ซ้ำทุก 10 วินาทีจนกว่าจะได้รับการยืนยัน โดย Publish ไปที่ `rmutt/ac/<deviceId>/provision` (แบบ Retained) เนื้อหาเป็น `{"token":...,"deviceId":...,"roomNumber":...,"airNumber":...}` Backend Subscribe Topic `rmutt/ac/+/provision` ไว้ แล้วเรียกฟังก์ชันนี้

ไฟล์: `backend/src/services/mqtt.js`

```js
async function activateProvisioning(deviceId, message) {
  const token = typeof message.token === 'string' ? message.token : '';
  if (!token) return;

  const rows = await pool.query(
    `SELECT provisioning_token_hash
      FROM air_conditioners
      WHERE device_id = ?
        AND provision_status IN ('reserved', 'active')
        AND provisioning_token_hash IS NOT NULL
        AND provisioning_expires_at > CURRENT_TIMESTAMP
      LIMIT 1`,
    [deviceId],
  );
  const row = rows[0];
  if (!row) return;

  const suppliedHash = hashSecret(token, config.otpPepper);
  if (!safeHashEquals(row.provisioning_token_hash, suppliedHash)) return;

  await pool.query(
    `UPDATE air_conditioners
        SET provision_status = 'active',
            is_online = 1,
            last_seen_at = CURRENT_TIMESTAMP
      WHERE device_id = ?`,
    [deviceId],
  );
```

- **บรรทัด 2–3** — ไม่มี Token ก็ไม่ทำอะไร
- **บรรทัด 5–16** — หาแถวของบอร์ดที่ยังมี Token รออยู่และ **ยังไม่หมดอายุ** (15 นาที)
- **บรรทัด 18–19** — Hash Token ที่บอร์ดส่งมาแล้วเทียบกับที่เก็บไว้ด้วย `safeHashEquals` (เทียบแบบใช้เวลาคงที่ ป้องกัน Timing Attack ที่เดาค่าจากเวลาตอบสนอง) ไม่ตรงก็เงียบ
- **บรรทัด 21–28** — ตรงแล้วเปลี่ยนสถานะเป็น `'active'` และออนไลน์

ส่วนที่เหลือของฟังก์ชัน Publish `{"version":1,"activated":true,"deviceId":...,"token":...}` ไปที่ `.../provision-ack` ล้าง Token ออกจากฐานข้อมูล (ใช้ได้ครั้งเดียว) และ Publish ข้อความว่างไปที่ `.../provision` เพื่อลบข้อความ Retained ฝั่งบอร์ดเมื่อได้ `provision-ack` ที่ Token ตรงกับของตัวเอง จะลบ `prov_token` ออกจาก NVS และหยุดส่งซ้ำ

> [!NOTE] แอปไม่ได้รอให้ถึงขั้น active
> แอปปิดหน้าจอทันทีที่ได้ Notify `ok:true` จากบอร์ด (ขั้นที่ 9) ส่วนขั้น active เกิดขึ้นเบื้องหลังภายในไม่กี่วินาที หน้าห้องจึงรอ 2 วินาทีแล้วเรียก `controller.refresh()` โมเดล `AirConditioner` มี Getter `isProvisioned` ที่เป็นจริงเมื่อ `provisionStatus == 'active'` ถ้าสถานะยังเป็น `reserved` UI ก็จะแสดงตามนั้นจนรอบรีเฟรชถัดไป

### กรณีตั้งค่าใหม่บอร์ดที่ออนไลน์อยู่

บอร์ดที่ใช้งานปกติจะปิดการประกาศตัว BLE ไว้ เมื่อแอดมินกด "ตั้งค่าใหม่" หน้าห้อง (`room_control_screen.dart`) จะเรียก `repository.enterSetupMode(deviceId)` ก่อน ซึ่งยิง `POST /air-conditioners/<deviceId>/setup-mode` ให้ Backend Publish คำสั่ง `{"action":"enter_setup",...}` ไปที่ `rmutt/ac/<deviceId>/command` บอร์ดจึงเปิด BLE ชั่วคราว แอปรอ 1.2 วินาทีแล้วเปิดหน้าจอนี้ ถ้าคำสั่งนี้ล้มเหลว (เช่นบอร์ดออฟไลน์) แอปแนะนำให้ลองค้นหาเลย เพราะบอร์ดอาจอยู่ในโหมดกู้คืน Wi-Fi อยู่แล้ว หรือให้กด BOOT ค้างแล้ว RESET

> [!NOTE]
> ** บอร์ดที่ถูกลบในแอปกลับมาโหมดตั้งค่าเอง** ถ้าแอดมินกด "Remove Unit" หรือลบเซ็นเซอร์ในหน้าห้องขณะบอร์ดออนไลน์ Backend ส่ง `{"action":"unprovision"}` ไปที่ topic `command` บอร์ดล้าง NVS แล้วรีบูตเข้าโหมดตั้งค่าบลูทูธ จึงนำบอร์ดไปติดห้องอื่นด้วยหน้าจอนี้ได้ทันที (เหมือนบอร์ดใหม่ ไม่ต้องกด "ตั้งค่าใหม่") ถ้าบอร์ดออฟไลน์ตอนลบ บอร์ดยังจำค่าเดิมจนกว่าจะกลับมาออนไลน์ แล้วจะล้างตัวเองเมื่อ Broker ปฏิเสธบัญชีที่ถูกลบต่อเนื่องครบ 2 นาที (บทโปรโตคอล) ถ้าไม่กลับมาออนไลน์ต้องรีเซ็ตที่ตัวบอร์ด

---

## การจัดการข้อผิดพลาด และการแก้ปัญหาบน Windows

### ตารางข้อผิดพลาดที่พบบ่อย

| อาการ/ข้อความ | เกิดที่ | สาเหตุ | ผู้ใช้ทำอย่างไร |
|---|---|---|---|
| `Please turn on Bluetooth and try again.` | `scan()` | บลูทูธของเครื่องปิดอยู่ | เปิดบลูทูธ |
| `No RMUTT ESP32 was found nearby.` | หน้าจอ | บอร์ดไม่อยู่ในโหมดตั้งค่า หรือไกลเกินไป | กด RESET หรือขยับเข้าใกล้ |
| `Bluetooth connection stage failed: ...` | `_connect()` | เชื่อมต่อทางกายภาพไม่สำเร็จ | กด "Try connecting again" |
| `Bluetooth service discovery failed after 3 attempts: ...` | `_connect()` | เชื่อมได้แต่ค้นหา GATT ไม่จบ | ลองใหม่ หรือรีเซ็ตบอร์ด |
| `Bluetooth name and ESP32 Device ID do not match.` | `readIdentity()` | ไม่ใช่บอร์ดของระบบ หรือเฟิร์มแวร์ผิดประเภท | ตรวจเฟิร์มแวร์ |
| `Update the ESP32 firmware before scanning nearby Wi-Fi.` | `scanWifiNetworks()` | เฟิร์มแวร์เก่าไม่มี `wifiScanUuid` | แฟลชเฟิร์มแวร์ใหม่ หรือพิมพ์ SSID เอง |
| ข้อความ 409 ภาษาไทยจาก Backend | `reserve()` | หมายเลขแอร์หรือบอร์ดซ้ำ | เลือกหมายเลขอื่น |
| `Unable to connect to Wi-Fi. ...` | Notify จากบอร์ด | รหัส Wi-Fi ผิด | แก้รหัสแล้วกดบันทึกซ้ำ |
| `ESP32 did not finish testing Wi-Fi or saving the configuration.` | `provision()` | ไม่ได้ Notify ภายใน 40 วินาที | ลองใหม่ |

### ปัญหา "เพิ่ม ESP32 ตัวที่ 2 ไม่ขึ้นหน้าตั้งค่า"

จาก `README_BLE_SECOND_DEVICE_FIX_TH.txt` อาการคือเลือกบอร์ดแล้วเห็นแค่วงกลมเลือก ไม่มีฟอร์มและไม่มีข้อความ ทั้งที่ Serial Monitor ของบอร์ดขึ้น "BLE app connected" สาเหตุคือรุ่นเก่ามี Timeout แค่ราว 15 วินาที และ **ซ่อนข้อความ Error** เมื่ออ่าน Device ID ไม่สำเร็จ การแก้ที่เห็นได้ในโค้ดปัจจุบัน ได้แก่

- รอ `connectionState` จริงบน Windows และลองค้นหา GATT สูงสุด 3 ครั้ง
- `stopScan()` ก่อนเชื่อมต่อทุกครั้ง
- แสดงสถานะ "Connecting and checking ESP32..." กล่อง Error และปุ่ม "Try connecting again" (`_BleErrorCard` มี Key `ble-connection-error`)
- เลื่อนไปยังฟอร์มอัตโนมัติเมื่อยืนยันบอร์ดสำเร็จ
- ฝั่งเฟิร์มแวร์ 1.6.0 ทำ Identity แพ็กเก็ตแรกให้เล็กลง และย้ายค่าเดิมไปที่ `settingsUuid`
- Device ID ยังมาจาก eFuse MAC จึงไม่ซ้ำกันระหว่างบอร์ด และ Backend ยังตรวจซ้ำเหมือนเดิม

### ปัญหา "Windows เชื่อมได้แต่ค้นหา Service ไม่จบ"

จาก `README_BLE_WINDOWS_GATT_FIX_TH.txt` ถ้าใช้ autoConnect แล้วเรียก `discoverServices()` ทันที ขณะที่ WinRT กำลังค้นหา GATT อยู่ภายใน `connect()` จะเกิดการค้นหาซ้อนกัน และถ้าตัดแล้วต่อใหม่ถี่ ๆ อาการจะหนักขึ้น โค้ด `_connect()` จึง (ตามคอมเมนต์ในโค้ด) ใช้การเชื่อมต่อปกติและรอให้ `connect()` จบ เพิ่มเวลาเป็น 45 วินาที ค้นหา Service ซ้ำบนการเชื่อมต่อเดิม เว้นช่วงให้ WinRT พร้อม แสดง Error จริงของแต่ละขั้น และล็อก `flutter_blue_plus_winrt` ไว้ที่ 0.0.20

> [!TIP] วิธีอธิบายสั้น ๆ ให้อาจารย์ฟัง
> "บน Windows คำสั่ง connect แอบค้นหา Service ไว้แล้ว ถ้าเราไปสั่งค้นหาซ้อนจะค้างกันเอง เลยแก้เป็นรอให้ connect จบก่อน หน่วงเวลาให้พร้อม แล้วค่อยค้นหา ถ้าพลาดก็ลองใหม่บนสายเดิมได้ 3 ครั้ง แทนที่จะตัดแล้วต่อใหม่ และแยกข้อความ Error ของขั้นเชื่อมต่อกับขั้นค้นหาออกจากกัน จะได้รู้ว่าพังตรงไหน"

---

## occupancy_provisioning_screen.dart — ตั้งค่าเซ็นเซอร์ตรวจจับคน

หน้าจอนี้ใช้ `BleProvisioningService` ตัวเดียวกันทุกเมธอด โครงสร้างโค้ดคล้ายหน้าบอร์ดแอร์มาก (`_scan`, `_selectDevice`, `_scanWifi`, `_save`) ต่างกันตามตารางนี้

| เรื่อง | บอร์ดแอร์ | บอร์ดเซ็นเซอร์ |
|---|---|---|
| คำนำหน้าชื่อ BLE | `RMUTT-AC-` | `RMUTT-OCC-` (ส่ง `namePrefix: 'RMUTT-OCC-'`) |
| รูปแบบ Device ID | `ESP32-XXXXXXXXXXXX` | `OCC32-XXXXXXXXXXXX` |
| ตรวจประเภทเฟิร์มแวร์ | ไม่ต้อง (ค่าเริ่มต้นเป็น `air`) | ต้อง `deviceType == 'occupancy'` ไม่งั้นแจ้ง "This ESP32 is not occupancy-sensor firmware." |
| ค่าที่รับจากหน้าก่อน | `roomNumber`, `usedAirNumbers`, `existingAir` | วัตถุ `Room` ทั้งก้อน |
| โหมดตั้งค่าใหม่ | `existingAir != null` | `room.hasOccupancySensor` (มี `occupancySensorDeviceId`) |
| ขั้นที่ 2 | เลือกหมายเลขแอร์ ชื่อ โปรโตคอล | แสดงห้องแบบอ่านอย่างเดียว และกฎตรวจจับ "Occupied when any LD2410 static target gate is greater than 25" |
| ขั้นที่ 4 (เวลาอัตโนมัติ) | มี | ไม่มี |
| ช่อง SSID | `readOnly` ต้องเลือกจากรายการ | พิมพ์เองได้ และมีปุ่มค้นหา |
| UI รายการ Wi-Fi | Bottom Sheet | `SimpleDialog` |
| API จอง | `POST /air-conditioners/reservations` | `POST /occupancy-sensors/reservations` |
| JSON ที่ส่งบอร์ด | มี `airNumber`, `name`, `airProtocol`, `schedule` | มี `deviceType: 'occupancy'` และ `staticThreshold` (ค่าจาก Backend `STATIC_ENERGY_THRESHOLD = 25` แต่เฟิร์มแวร์ไม่ได้อ่านฟิลด์นี้ ใช้ค่าคงที่ของตัวเอง ซึ่งตั้งแต่ 1.3.3 คือ 15) |
| Topic | `rmutt/ac/<id>` | `rmutt/occupancy/<id>` |
| ฟังก์ชันยืนยันใน Backend | `activateProvisioning` | `activateOccupancyProvisioning` (ตรรกะเดียวกันแต่ตาราง `occupancy_sensors`) |

> [!WHY] ทำไมไม่ให้แอดมินตั้งเกณฑ์เอง
> เกณฑ์ "พลังงานเป้าหมายนิ่ง" ของเรดาร์ LD2410 เป็นค่าที่ต้องทดลองกับห้องจริง ถ้าให้ตั้งเองรายห้องจะเพิ่มโอกาสตั้งผิดจนระบบปิดแอร์ใส่คนที่นั่งอยู่ ค่าที่ใช้ตัดสินจริงจึงฝังอยู่ในเฟิร์มแวร์ (`STATIC_ENERGY_THRESHOLD` ใน `.ino`) ส่วนค่าที่ Backend ส่งใน JSON ตอนตั้งค่า บอร์ดไม่ได้อ่าน หน้าจอแค่แสดงกฎให้รู้

> [!WARN] ค่าที่แสดงกับค่าที่บอร์ดใช้ไม่ตรงกัน
> เฟิร์มแวร์ตรวจคนใช้เกณฑ์ **15** แต่ Backend ยังเป็น 25 แอปและเว็บจึงแสดง "เกณฑ์ 25" ทั้งที่บอร์ดใช้ 15 บอร์ดส่ง `"staticThreshold":15` มากับ `/status` อยู่แล้ว แต่ Backend ไม่ได้บันทึกฟิลด์นี้ ถ้าอาจารย์ถาม ให้ตอบตามเฟิร์มแวร์ (15) และบอกว่าค่าที่แสดงยังไม่ได้ปรับตาม

---

## room_management_screen.dart — จัดการห้อง

หน้าจอเป็น `StatelessWidget` ที่ใช้ `AnimatedBuilder` ฟัง `RoomController` (อธิบายในบท Controllers) เมื่อ Controller เรียก `notifyListeners()` รายการจะวาดใหม่เอง มีปุ่มเพิ่มห้องสองที่ (ไอคอนบน AppBar และ FloatingActionButton) และดึงลงเพื่อรีเฟรช (`RefreshIndicator` เรียก `controller.reload`)

### CRUD ของห้อง

- **Create/Update** — `_openEditor()` เปิด Bottom Sheet `_RoomEditorSheet` ถ้าส่ง `room` มาคือโหมดแก้ไข ช่องรหัสห้องจะถูกปิด (`enabled: !_isEditing`) เพราะรหัสห้องเป็น Primary Key ที่แอร์และตารางเรียนอ้างถึง
- **Read** — การ์ด `_ManagedRoomCard` แสดงรหัสห้อง กลุ่ม (ชั้น หรือ Special ถ้าชั้นเป็น 0) ประเภท และจำนวนแอร์/คาบเรียนที่ผูกอยู่
- **Delete** — `_confirmDelete()` เปิด Dialog ยืนยัน

### การตรวจข้อมูลก่อนบันทึก (`_save()` ใน `_RoomEditorSheetState`)

ไฟล์: `lib/screens/room_management_screen.dart`

```dart
    final number = _numberController.text.trim().toUpperCase();
    final floor = int.tryParse(_floorController.text.trim());
    final index = int.tryParse(_indexController.text.trim());
    final type = _typeController.text.trim();

    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{1,19}$').hasMatch(number)) {
      setState(
        () => _errorMessage =
            'Room code must be 2–20 characters using A–Z, 0–9, _ or -.',
      );
      return;
    }
    if (floor == null || floor < 0 || floor > 99) {
      setState(
        () => _errorMessage =
            'Floor must be 0–99. Use 0 for a special room.',
      );
      return;
    }
```

- **บรรทัด 1** — แปลงรหัสห้องเป็นตัวพิมพ์ใหญ่ ทำให้ `cl503` กับ `CL503` เป็นห้องเดียวกัน
- **บรรทัด 2–3** — `int.tryParse` คืน `null` แทนการโยน Error ถ้าแปลงไม่ได้
- **บรรทัด 6–12** — Regex บังคับ 2–20 ตัว ขึ้นต้นด้วยตัวอักษรหรือตัวเลข ตามด้วย A–Z, 0–9, `_` หรือ `-` (ช่องกรอกยังมี `FilteringTextInputFormatter` กันพิมพ์อักขระอื่นตั้งแต่แรก)
- **บรรทัด 13–19** — ชั้น 0–99 โดย **ชั้น 0 หมายถึงกลุ่มห้องพิเศษ** เช่น `CL503`

หลังจากนั้นตรวจลำดับการแสดงผล 0–9999 และชื่อประเภท 1–100 ตัว แล้วสร้าง `Room` โดยคงค่าที่ไม่ได้แก้ (รายการแอร์ สถานะมีคน ฯลฯ) จากห้องเดิม เรียก `controller.updateRoom()` หรือ `controller.createRoom()` ซึ่งยิง `PUT` หรือ `POST /rooms`

### กฎการลบห้อง

Dialog ปิดปุ่มลบ (`onPressed: null`) ถ้าห้องยังมีแอร์ (`displayedAirCount > 0`) หรือมีคาบเรียน (`scheduleCount > 0`) และบอกให้ลบข้อมูลที่ผูกอยู่ก่อน ฝั่ง Backend (`DELETE /rooms/:roomNumber`) ตรวจซ้ำใน Transaction อีกชั้น โดยนับแอร์ที่ไม่ใช่ `removed` คาบเรียน และ **เซ็นเซอร์ตรวจจับคน** ถ้ามีอย่างใดอย่างหนึ่งตอบ 409

> [!WHY] ทำไมห้ามลบห้องที่ยังมีข้อมูลผูกอยู่
> ถ้าลบห้องได้ทั้งที่ยังมีแอร์ บอร์ด ESP32 ที่ตั้งค่าไว้กับห้องนั้นจะยังส่งข้อมูลเข้ามาโดยไม่มีห้องให้ผูก ข้อมูลพลังงานกลายเป็นข้อมูลกำพร้า (Orphan) การบังคับให้ลบของที่ผูกก่อนคือการรักษา **Referential Integrity** (ความถูกต้องของการอ้างอิงระหว่างตาราง)

> [!NOTE] รายการห้องอัปเดตเองทุก 10 วินาที
> `RoomController.initialize()` ตั้ง `Timer.periodic` ทุก 10 วินาทีให้ `reload(silent: true)` และ `RoomController.rooms` เป็น List ตัวเดิมที่ถูกล้างแล้วเติมใหม่ (`clear()` แล้ว `addAll()`) หน้าจออื่นที่ถือ List เดียวกัน เช่น หน้าจัดการตาราง จึงเห็นห้องใหม่ทันทีโดยไม่ต้องส่งค่าใหม่เข้าไป

---

## schedule_management_screen.dart — จัดการตารางเรียน

หน้าจอนี้รับ `rooms` (List จาก `RoomController`), `ScheduleController`, ชั้นและวันเริ่มต้น และ Callback `onRoomsChanged` ผู้ใช้เลือกชั้นด้วย `FloorSelector` เลือกห้องด้วย `ChoiceChip` และเลือกวันด้วย `WeekdaySelector` (วัน 0 = อาทิตย์ ถึง 6 = เสาร์) แล้วรายการคาบของห้อง+วันนั้นได้จาก `controller.schedulesFor(roomNumber, dayOfWeek)`

ตอนเปิดหน้า `_preferredRoomNumber()` จะเลือกห้องแรกในชั้นนั้นที่ **มีคาบเรียนในวันนั้น** ให้อัตโนมัติ ผู้ใช้จะไม่เจอหน้าว่างโดยไม่จำเป็น

AppBar มีปุ่ม 2 ปุ่ม คือ **นำเข้า Excel/CSV** (เปิด `ScheduleImportScreen` แล้วถ้านำเข้าสำเร็จจะปรับชั้น/ห้องที่เลือกให้ยังถูกต้อง) และ **ล้างตารางทั้งหมด** (Dialog เตือนว่าลบทุกคาบของทุกห้องแต่ไม่แตะห้อง แอร์ หรือผู้ใช้ แล้วเรียก `controller.deleteAllSchedules()` ซึ่งยิง `DELETE /schedules`)

### การตรวจเวลาทับซ้อน (Overlap Validation)

ในฟอร์ม `_ScheduleEditorSheet` เมธอด `_save()` ตรวจตามลำดับ: ชื่อวิชาไม่ว่างและไม่เกิน 150 ตัว กลุ่มเรียนไม่เกิน 80 ตัว ชื่ออาจารย์ไม่เกิน 150 ตัว เวลาจบต้องหลังเวลาเริ่ม และสุดท้ายต้องไม่ทับคาบอื่น

ไฟล์: `lib/screens/schedule_management_screen.dart`

```dart
    if (startTime.compareTo(endTime) >= 0) {
      setState(
        () => _errorMessage = context.tr('End time must be after start time.'),
      );
      return;
    }
    if (widget.controller.overlaps(
      roomNumber: widget.roomNumber,
      dayOfWeek: widget.dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      ignoredId: widget.schedule?.id,
    )) {
      setState(
        () =>
            _errorMessage = context.tr('This time overlaps an existing class.'),
      );
      return;
    }
```

- **บรรทัด 1** — เวลาเป็นข้อความรูปแบบ `HH:mm` เติมศูนย์หน้าเสมอ (ทำโดย `_format24Hour`) จึง **เทียบแบบข้อความได้ถูกต้อง** เช่น `"08:00" < "13:30"` (ถ้าไม่เติมศูนย์ `"8:00"` จะมากกว่า `"13:30"` ผิด)
- **บรรทัด 6–12** — เรียก `overlaps()` ของ Controller ส่ง `ignoredId` เป็น id ของคาบที่กำลังแก้ ไม่งั้นคาบจะชนกับตัวเอง

ตัวตรวจจริงอยู่ในโมเดลและ Controller

ไฟล์: `lib/models/class_schedule.dart`

```dart
  static bool timesOverlap(
    String firstStart,
    String firstEnd,
    String secondStart,
    String secondEnd,
  ) {
    return firstStart.compareTo(secondEnd) < 0 &&
        firstEnd.compareTo(secondStart) > 0;
  }
```

- **บรรทัด 7–8** — สูตรมาตรฐานของช่วงเวลาทับซ้อน: ช่วง A ทับช่วง B ก็ต่อเมื่อ **A เริ่มก่อน B จบ และ A จบหลัง B เริ่ม** ใช้ `<` และ `>` (ไม่ใช่ `<=`) ทำให้คาบที่ต่อกันพอดี เช่น 09:00–12:00 กับ 12:00–15:00 **ไม่นับว่าทับ**

ฝั่ง `ScheduleController.overlaps()` วนดูทุกคาบที่ id ไม่ใช่ `ignoredId` ห้องตรงกัน วันตรงกัน แล้วเรียก `timesOverlap` และ Backend ก็ตรวจซ้ำด้วยฟังก์ชัน `ensureNoOverlap()` ซึ่งเป็น SQL สูตรเดียวกัน (`start_time < ? AND end_time > ?`) ถ้าชนตอบ 409 "ช่วงเวลานี้ซ้อนกับตารางเรียนที่มีอยู่แล้ว"

> [!WHY] ทำไมตรวจทั้งในแอปและใน Backend
> ตรวจในแอปเพื่อ **ความเร็ว** ผู้ใช้รู้ทันทีโดยไม่ต้องรอเน็ต ตรวจใน Backend เพื่อ **ความถูกต้อง** เพราะข้อมูลในแอปอาจเก่า (แอดมินอีกคนเพิ่งเพิ่มคาบจากเว็บ) และคนอาจยิง API ตรง Backend จึงเป็นด่านสุดท้ายที่เชื่อถือได้

---

## schedule_import_screen.dart — นำเข้าตารางจาก Excel/CSV

### ขั้นตอนแบบสองจังหวะ: Preview แล้วค่อย Commit

1. **เลือกไฟล์** — `_chooseFile()` ใช้ `openFile` ของแพ็กเกจ `file_selector` กรองเฉพาะ `.xlsx` และ `.csv`
2. **ส่งไปให้ Backend อ่าน** (ยังไม่บันทึก) — ไฟล์ถูกส่งเป็นไบต์ดิบ (`application/octet-stream`) ไปที่ `POST /schedules/import/preview` พร้อม Header `X-File-Name` Backend อ่านทุกชีต (รวมเซลล์ที่ Merge ไว้) แปลงเป็นหนึ่งแถวต่อหนึ่งคาบ ตรวจรหัสห้อง รูปแบบเวลา รายการซ้ำ และเวลาทับกัน แล้วคืนตัวอย่าง
3. **ตรวจตัวอย่าง** — หน้าจอแสดงจำนวนห้อง คาบ คำเตือน ห้องใหม่ที่จะถูกสร้าง และตัวอย่าง 25 แถวแรก
4. **กรอกภาคเรียนและช่วงวันที่** — บังคับก่อนนำเข้า
5. **ยืนยัน** — Dialog สรุป แล้วส่ง `POST /schedules/import/commit` บันทึกจริงใน Transaction เดียว

```dart
    try {
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      if (bytes.length > 8 * 1024 * 1024) {
        throw Exception(context.tr('The file must not exceed 8 MB.'));
      }

      final preview = await widget.controller.previewScheduleFile(
        fileName: file.name,
        bytes: bytes,
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        // ไฟล์ใหม่อาจเป็นคนละเทอม ให้เลือกช่วงวันใหม่ทุกครั้ง
        _semesterController.text = preview.semester;
        _termRange = null;
        _replaceAll = _defaultReplaceAll(preview);
      });
```

- **บรรทัด 2** — อ่านไฟล์ทั้งไฟล์เป็นไบต์
- **บรรทัด 4–6** — จำกัด 8 MB ในแอปก่อน (Backend ก็ตั้ง `limit: '8mb'` ไว้ตรงกัน) ไม่ต้องเสียเวลาอัปโหลดไฟล์ที่รู้อยู่แล้วว่าจะโดนปฏิเสธ
- **บรรทัด 8–11** — ส่งไป Backend ผ่าน Controller (ฝั่ง Service ตั้ง Timeout 45 วินาที เพราะไฟล์ Excel ใหญ่ใช้เวลาอ่าน)
- **บรรทัด 13–18** — เก็บผล เติมภาคเรียนที่อ่านได้จากไฟล์ลงช่อง **ล้างช่วงวันที่ทุกครั้ง** บังคับให้ผู้ใช้เลือกใหม่ กันลืมแล้วใช้ช่วงวันของเทอมก่อน และ ตั้งวิธีนำเข้าเริ่มต้นตามไฟล์ใหม่ (`_defaultReplaceAll` อธิบายในหัวข้อถัดไป)

> [!WHY] ทำไมต้องแยก Preview กับ Commit
> ไฟล์ตารางเรียนจากฝ่ายทะเบียนมักมีความผิดปกติ เช่น เซลล์รวม เวลาเขียนผิดรูปแบบ หรือชีตของห้องที่ยังไม่มีในระบบ ถ้านำเข้าทันทีแล้วผิด ตารางเดิมจะหายและระบบปิดแอร์อัตโนมัติจะตัดสินใจผิดทั้งอาคาร Preview ให้มนุษย์ตรวจก่อนโดย **ไม่มีอะไรถูกบันทึก** (แม้แต่ห้องใหม่ก็ยังไม่ถูกสร้าง ข้อความในหน้าจอเขียนว่า "Rooms are created only after you confirm the import.")

### ช่วงภาคเรียน

Widget `_TermCard` ให้กรอกภาคเรียน ตรวจด้วย Regex `^[1-3]/\d{4}$` (เช่น `1/2569`) และเลือกช่วงวันด้วย `showAppDateRangePicker` ซึ่งเป็นปฏิทินของแอปเองที่แสดงปี พ.ศ. เมื่อใช้ภาษาไทย (ปฏิทินของ Flutter แสดงได้แค่ ค.ศ.) ปุ่มนำเข้าด้านล่างจะกดได้ก็ต่อเมื่อ `_termReady` เป็นจริง และข้อความปุ่มจะบอกว่า "Choose the semester dates first" จนกว่าจะครบ นอกช่วงวันนี้ระบบถือว่าทุกห้องไม่มีคาบเรียน (เช่นช่วงปิดภาค)

### เลือกวิธีนำเข้า: "เปลี่ยนภาคเรียน" หรือ "แทนที่เฉพาะห้องในไฟล์"

ถ้านำเข้าแบบแทนที่เฉพาะห้องที่อยู่ในไฟล์ ปัญหาคือไฟล์ของเทอมใหม่มักไม่มีชีตของห้องที่เทอมนี้ไม่มีเรียน ห้องพวกนั้นจะ **ค้างตารางของเทอมเก่า** ระบบปิดแอร์จึงคิดว่ายังมีคาบ (รอ 15 นาทีแทน 5 และไม่แจ้งเตือน) ดังนั้นถ้ามีห้องที่ "มีตารางในระบบแต่ไม่อยู่ในไฟล์" หน้าจอจะขึ้นการ์ด `_ImportModeCard` ให้เลือกก่อนนำเข้า

ไฟล์ `lib/screens/schedule_import_screen.dart` บรรทัด 140–165

```dart:140
  /// ห้องที่มีตารางในระบบแต่ไม่อยู่ในไฟล์ พร้อมจำนวนคาบ
  Map<String, int> _roomsOutsideFile(ScheduleImportPreview preview) {
    final inFile = preview.roomNumbers.toSet();
    final counts = <String, int>{};
    for (final schedule in widget.controller.schedules) {
      if (inFile.contains(schedule.roomNumber)) continue;
      counts[schedule.roomNumber] = (counts[schedule.roomNumber] ?? 0) + 1;
    }
    return counts;
  }

  bool _needsModeChoice(ScheduleImportPreview preview) =>
      widget.controller.supportsReplaceAll &&
      _roomsOutsideFile(preview).isNotEmpty;

  /// ค่าเริ่มต้นของวิธีนำเข้า (เหมือนเว็บ)
  /// ภาคเรียนในไฟล์ต่างจากในระบบ = น่าจะเปลี่ยนเทอม เลือก "ล้างทุกห้อง" ไว้ให้
  /// ภาคเรียนเดียวกัน = แก้บางห้อง, ไม่รู้ภาคเรียนฝั่งใดฝั่งหนึ่ง = ให้เลือกเอง
  bool? _defaultReplaceAll(ScheduleImportPreview preview) {
    if (!_needsModeChoice(preview)) return false;
    final current = widget.controller.timetable?.semester ?? '';
    if (preview.semester.isNotEmpty && current.isNotEmpty) {
      return preview.semester != current;
    }
    return null;
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 141–149 | นับคาบของแต่ละห้องที่อยู่ในระบบแต่ไม่อยู่ในไฟล์ `toSet()` ทำให้เช็ก "อยู่ในไฟล์ไหม" ได้เร็ว (O(1)) `(counts[x] ?? 0) + 1` คือนับเพิ่ม เริ่มที่ 0 ถ้ายังไม่มี |
| 151–153 | ต้องถามก็ต่อเมื่อ Backend รองรับ **และ** มีห้องที่จะได้รับผลกระทบจริง ถ้าไฟล์ครอบคลุมทุกห้องอยู่แล้ว สองวิธีให้ผลเท่ากัน ไม่ต้องถาม |
| 158 | ไม่ต้องถาม = ใช้วิธีเดิม (แทนที่เฉพาะห้องในไฟล์) |
| 160–162 | รู้ภาคเรียนทั้งสองฝั่ง: ไฟล์คนละเทอมกับระบบ → เลือก "เปลี่ยนภาคเรียน" ไว้ให้ (`true`) เทอมเดียวกัน → น่าจะแค่แก้บางห้อง (`false`) |
| 164 | ไม่รู้ภาคเรียนฝั่งใดฝั่งหนึ่ง → `null` = **ยังไม่เลือก** บังคับให้ผู้ใช้ตัดสินเอง |

ตัวแปร `_replaceAll` จึงเป็น `bool?` สามสถานะ: `true` ล้างทุกห้อง, `false` เก็บห้องอื่นไว้, `null` ยังไม่เลือก ตอน `null` ปุ่มนำเข้ากดไม่ได้และเขียนว่า "เลือกวิธีนำเข้าก่อน" กรอบการ์ดเป็นสีส้มเพื่อดึงสายตา

> [!WHY]
> **ทำไมไม่เลือกค่าเริ่มต้นให้เสมอ** การล้างตารางทุกห้องเป็นการกระทำที่ย้อนไม่ได้ง่าย (ต้องหาไฟล์เก่ามานำเข้าใหม่) ถ้าระบบเดาผิดว่า "เปลี่ยนเทอม" ห้องที่ไม่อยู่ในไฟล์จะหายตารางทั้งหมด แอร์ห้องนั้นจะถูกปิดเร็วกลางคาบ แต่ถ้าเดาผิดอีกทางว่า "ไม่เปลี่ยนเทอม" ห้องเหล่านั้นจะค้างตารางเก่า หลักการคือ **เดาเฉพาะเมื่อมีหลักฐาน** (ชื่อภาคเรียนต่างกัน) ไม่มีหลักฐานก็ให้คนตัดสิน

การ์ด `_ImportModeCard` แสดง

- หัวข้อ "อีก N ห้องมีตารางอยู่ในระบบแต่ไม่อยู่ในไฟล์นี้ ให้ทำอย่างไร?"
- เหตุผลของค่าที่เลือกไว้ เช่น "ไฟล์นี้เป็นภาคเรียน 2/2569 แต่ตารางในระบบเป็น 1/2569 จึงเลือก "เปลี่ยนภาคเรียน" ไว้ให้"
- ตัวเลือก **เปลี่ยนภาคเรียน — ล้างตารางเดิมของทุกห้อง** พร้อมรายชื่อห้องที่จะไม่มีคาบเหลือ (แสดง 8 ห้องแรก "และอีก N ห้อง") และจำนวนคาบที่จะหาย
- ตัวเลือก **แทนที่เฉพาะห้องในไฟล์** ห้องอื่นเก็บตารางเดิมไว้

ตอนยืนยัน `_confirmImport()` สร้างสำเนาด้วย `.withTerm(...).withReplaceAll(_replaceAll == true)` และข้อความในกล่องยืนยันเปลี่ยนตามวิธี เช่น "เปลี่ยนภาคเรียน: ล้างตารางเดิมของทุกห้อง แล้วนำเข้า 312 รายการให้ 18 ห้อง"

### ข้อมูลที่ส่งตอน Commit

ไฟล์: `lib/models/schedule_import.dart`

```dart
  Map<String, dynamic> toCommitJson() {
    return {
      'createMissingRooms': newRooms.isNotEmpty,
      if (replaceAll) 'replaceAll': true,
      'schedules': schedules.map((schedule) => schedule.toJson()).toList(),
      if (termSemester != null) 'semester': termSemester,
      if (hasTerm) 'startDate': termStartDate,
      if (hasTerm) 'endDate': termEndDate,
    };
  }
```

- **บรรทัด 3** — ถ้าตัวอย่างพบห้องใหม่ ขออนุญาตให้ Backend สร้างห้องเหล่านั้น (กฎสร้างห้องจาก `README_AUTO_CREATE_ROOMS_TH.txt`: `16101` เป็นชั้น 1 ลำดับ 1 ประเภท Classroom ส่วน `CL503` เป็นชั้น 0 ห้องพิเศษ)
- **บรรทัด 4** — ส่ง `replaceAll: true` เฉพาะตอนเลือก "เปลี่ยนภาคเรียน" ถ้าไม่เลือกก็ไม่ใส่ฟิลด์เลย Backend อ่าน `body?.replaceAll === true` จึงถือว่าเป็นโหมดปกติ (และ Backend รุ่นเก่าที่ไม่รู้จักฟิลด์นี้ก็ไม่สับสน)
- **บรรทัด 5** — ส่งรายการคาบทั้งหมด **กลับไป** ให้ Backend (ไม่ส่งไฟล์ซ้ำ) Backend จะตรวจรูปแบบอีกรอบใน `validateScheduleImportPayload`
- **บรรทัด 6–8** — ใช้ไวยากรณ์ `if` ภายใน Map Literal (Collection If) ใส่ภาคเรียนและวันเปิด-ปิดเฉพาะเมื่อมีค่า

ฝั่ง Backend ทำทุกอย่างใน `withTransaction` เดียว: สร้างห้องที่ขาด ลบตารางเดิม แทรกตารางใหม่ บันทึกช่วงภาคเรียน และบันทึกประวัติการนำเข้า ถ้าขั้นใดพังจะย้อนกลับทั้งหมด (Rollback) ส่วนการลบตารางเดิมมีสองโหมด

ไฟล์: `backend/src/routes/schedules.js`

```js
      if (input.replaceAll) {
        // เปลี่ยนภาคเรียน: ห้องที่เทอมก่อนมีเรียนแต่ไม่อยู่ในไฟล์ใหม่ต้องไม่ค้าง
        // ตารางเก่า ไม่งั้นระบบจะคิดว่ายังมีคาบ (รอ 15 นาทีแทน 5 และไม่แจ้งเตือน)
        removedCount = await deleteAllSchedules(connection);
      } else {
        const placeholders = input.roomNumbers.map(() => '?').join(', ');
        const deleted = await connection.query(
          `DELETE FROM class_schedules
            WHERE room_number IN (${placeholders})`,
          input.roomNumbers,
        );
        removedCount = Number(deleted.affectedRows) || 0;
      }
```

- **บรรทัด 1–4** — โหมด `replaceAll` (เปลี่ยนภาคเรียน) ลบตารางของ **ทุกห้อง** ก่อน
- **บรรทัด 5–12** — โหมดปกติ ลบเฉพาะห้องที่อยู่ในไฟล์ ห้องอื่นไม่เปลี่ยน สร้าง `?` ตามจำนวนห้องแล้วส่งค่าแยก (Parameterized Query) ป้องกัน SQL Injection

> [!WHY] ทำไมส่ง `replaceAll` ไปให้ Backend ทำ ไม่กด "ล้างตารางทั้งหมด" ก่อนแล้วค่อยนำเข้า
> สองคำขอแยกกัน **ไม่อยู่ใน Transaction เดียวกัน** จะมีช่วงสั้น ๆ ที่ไม่มีตารางเลย (ระบบปิดแอร์อาจปิดแอร์ในคาบเรียนช่วงนั้น) และถ้านำเข้าล้มหลังล้างไปแล้ว ตารางจะหายหมด `toCommitJson()` จึงส่ง `replaceAll` เหมือนเว็บแอป (`webapp/assets/js/views/schedule-import.js` ส่ง `replaceAll: mode === 'all'`) การล้างและนำเข้าจึงเกิดใน Transaction เดียวของ Backend

### บันทึก CSV

ปุ่ม "Save CSV" ใน `_downloadCsv()` นำข้อความ CSV (UTF-8) ที่ Backend แนบมาในตัวอย่าง ไปบันทึกเป็นไฟล์ ไฟล์นี้นำกลับเข้าแอปได้อีก

ใช้ตัวบันทึกกลาง `saveExportFile(fileName: 'rmutt_class_schedules_${preview.semester.replaceAll('/', '-')}.csv', ..., fileExtension: 'csv', mimeType: 'text/csv', typeLabel: 'CSV')` มือถือจึงเปิดเมนูแชร์ คอมพิวเตอร์เปิดกล่องบันทึกเป็น และชื่อไฟล์เป็น `rmutt_class_schedules_1-2569.csv` (เปลี่ยน `/` ของภาคเรียนเป็น `-` เพราะ `/` ใช้ในชื่อไฟล์ไม่ได้ และไม่เรียก `getSaveLocation` ของ `file_selector` ตรง ๆ เพราะบน Android/iOS ไม่มีกล่องบันทึกเป็น)

---

## energy_database_screen.dart — ฐานข้อมูลพลังงาน

หน้าจอมี `TabController` 2 แท็บ คือ **Live readings** (ค่าไฟสด) และ **Export to Excel** ตอน `initState` เรียก `controller.initialize()` (โหลดรายการค่าที่เลือกได้และแหล่งข้อมูล) และ `controller.startLiveUpdates()` ตอน `dispose` เรียก `stopLiveUpdates()` เพื่อหยุดยิงคำขอเมื่อออกจากหน้า

### แท็บค่าไฟสด: Polling พร้อมเลือกรอบเวลาและหยุดชั่วคราว

ข้อมูลมาจาก `GET /energy/live` แบบ **Polling** (แอปถามซ้ำเป็นรอบ) ตัวเลือกรอบเวลาประกาศไว้ใน Controller

ไฟล์: `lib/controllers/energy_controller.dart`

```dart
const kEnergyRefreshChoices = <int>[2, 5, 10, 30, 60];
```

ค่าเริ่มต้นคือ `refreshSeconds = 5` คอมเมนต์ในไฟล์อธิบายว่า ESP32 อ่าน PZEM ทุก 2 วินาทีและส่งขึ้น MQTT เป็นระยะ 5 วินาทีจึงเห็นการเปลี่ยนแปลงเกือบทันทีโดยไม่ยิงถี่เกินไป

```dart
  void startLiveUpdates() {
    _isStreaming = true;
    _restartTimer();
    notifyListeners();
  }

  void stopLiveUpdates() {
    _isStreaming = false;
    _liveTimer?.cancel();
    _liveTimer = null;
    notifyListeners();
  }

  void setRefreshSeconds(int seconds) {
    if (!kEnergyRefreshChoices.contains(seconds)) return;
    refreshSeconds = seconds;
    if (_isStreaming) _restartTimer();
    notifyListeners();
  }

  void _restartTimer() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(
      Duration(seconds: refreshSeconds),
      (_) => refreshLive(silent: true),
    );
  }
```

- **บรรทัด 1–5** — เริ่มสตรีม เรียก `_restartTimer()` ซึ่งยกเลิกตัวจับเวลาเก่าก่อนเสมอ เรียกซ้ำกี่ครั้งก็ไม่เกิดตัวจับเวลาซ้อน
- **บรรทัด 7–12** — ปุ่ม Pause ยกเลิกตัวจับเวลาและตั้งเป็น `null`
- **บรรทัด 14–19** — เปลี่ยนรอบเวลา รับเฉพาะค่าในรายการที่อนุญาต ถ้ากำลังสตรีมอยู่ให้เริ่มตัวจับเวลาใหม่ด้วยรอบใหม่ทันที
- **บรรทัด 21–27** — `Timer.periodic` เรียก `refreshLive(silent: true)` ทุกรอบ โหมด `silent` จะไม่แสดงวงหมุน และ **ข้ามรอบถ้ารอบก่อนยังไม่เสร็จ** (เช็ก `_liveInFlight`) ป้องกันคำขอซ้อนกันเมื่อเน็ตช้า

ในหน้าจอ ตัวเลือกเหล่านี้แสดงเป็น `ChoiceChip` และมี `FilterChip` สลับ Pause/Resume ส่วนข้อมูลแสดงเป็น `_LiveSummaryCard` (กำลังไฟรวมเป็น kW จำนวนเครื่องที่ทำงาน/ออนไลน์/ทั้งหมด) และ `_LiveReadingCard` ต่อเครื่อง ซึ่งแสดง 6 ค่าที่ PZEM-004T v3.0 วัดได้ คือ แรงดัน กระแส กำลังไฟ พลังงานสะสม ความถี่ และตัวประกอบกำลัง (Power Factor) พร้อมสถานะ Running/Idle/Offline

### แท็บส่งออก: ตั้งเงื่อนไข → ดูตัวอย่าง → ดาวน์โหลด

1. **ช่วงวันที่** — วันเดียวหรือช่วงวัน (`SegmentedButton`) วันแรกย้อนได้ถึงข้อมูลชุดแรกที่มีจริงแต่ไม่ต่ำกว่าปี 2024 วันสุดท้ายไม่เกินวันนี้ และแสดงช่วงข้อมูลที่มีเก็บไว้
2. **ระดับรายละเอียด** (`EnergyScope`) — `building` ทั้งอาคาร, `room` รายห้อง, `device` รายเครื่อง ทุกระดับเป็นหนึ่งแถวต่อชั่วโมง ระดับห้องขึ้นไปถือเป็น "High detail" (`isHighDetail`) ซึ่งปลดล็อกคอลัมน์ต่ำสุด สูงสุด และเวลาทำงาน
3. **เลือกห้อง/เครื่อง** — ไม่ติ๊กเลยหมายถึงเอาทั้งหมด และเมื่อเปลี่ยนห้อง `_pruneDevices()` จะถอดเครื่องที่ไม่อยู่ในห้องที่เลือกออก
4. **ค่าที่ต้องการ** — `FilterChip` ต่อ Metric (รายการมาจาก Backend `GET /energy/metrics`) ต้องเหลืออย่างน้อยหนึ่งค่าเสมอ และสวิตช์ "เพิ่มคอลัมน์ค่าไฟประมาณการ" ซึ่งใช้อัตราค่าไฟที่ตั้งไว้ **ในเครื่องนี้**
5. **Preview** — `GET /energy/history` แสดง `DataTable` 50 แถวแรก ทุกครั้งที่เปลี่ยนเงื่อนไข `clearPreview()` จะล้างตัวอย่างเก่าทิ้ง กันผู้ใช้ดูตัวอย่างที่ไม่ตรงกับเงื่อนไขปัจจุบัน
6. **Download Excel** — `GET /energy/export` พร้อมพารามิเตอร์ `language` (`th` หรือ `en` ตามภาษาแอป) ได้ไฟล์ .xlsx ที่ Backend สร้าง ชื่อไฟล์อ่านจาก Header ของคำตอบ แล้วส่งให้ `saveExportFile()`

### file_saver.dart — บันทึกไฟล์ต่างกันบน Windows กับ Android

ไฟล์: `lib/utils/file_saver.dart`

```dart
  try {
    if (Platform.isAndroid || Platform.isIOS) {
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}$safeName');
      await file.writeAsBytes(bytes, flush: true);

      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: mimeType)],
          subject: safeName,
        ),
      );

      if (result.status == ShareResultStatus.dismissed) {
        return const FileSaveResult(FileSaveStatus.cancelled);
      }
      return FileSaveResult(FileSaveStatus.shared, path: file.path);
    }
```

- **บรรทัด 2** — มือถือ Android/iOS ไม่มีกล่อง "บันทึกเป็น" แบบเดสก์ท็อป
- **บรรทัด 3–5** — เขียนไฟล์ลงโฟลเดอร์ชั่วคราวของแอป (`path_provider`) `flush: true` บังคับเขียนลงดิสก์จริงก่อนไปต่อ
- **บรรทัด 7–12** — เปิดเมนูแชร์ของระบบ (`share_plus`) ให้ผู้ใช้เลือกเองว่าจะบันทึกลง Files ส่ง LINE หรืออีเมล
- **บรรทัด 14–17** — ผู้ใช้ปิดเมนูไป = ยกเลิก (ไม่ใช่ Error) ไม่งั้นถือว่าแชร์แล้ว

```dart
    final location = await picker.getSaveLocation(
      suggestedName: safeName,
      acceptedTypeGroups: [
        picker.XTypeGroup(
          label: typeLabel,
          extensions: [fileExtension],
          mimeTypes: [mimeType],
        ),
      ],
    );
    if (location == null) {
      return const FileSaveResult(FileSaveStatus.cancelled);
    }

    final path = location.path.toLowerCase().endsWith('.$fileExtension')
        ? location.path
        : '${location.path}.$fileExtension';
    await File(path).writeAsBytes(bytes, flush: true);
    return FileSaveResult(FileSaveStatus.saved, path: path);
  } catch (error) {
    return FileSaveResult(FileSaveStatus.failed, error: error.toString());
  }
```

- **บรรทัด 1–9** — บน Windows เปิดกล่อง "บันทึกเป็น" ของระบบ (`file_selector`) เสนอชื่อไฟล์ไว้ให้
- **บรรทัด 10–12** — กดยกเลิกได้ `null`
- **บรรทัด 14–16** — ถ้าผู้ใช้ลบนามสกุลออก เติมนามสกุลที่ส่งมาให้ (`.xlsx` หรือ `.csv`)
- **บรรทัด 17–18** — เขียนไฟล์แล้วคืน `saved` พร้อม Path เพื่อแสดงใน SnackBar ว่าบันทึกไว้ที่ไหน
- **บรรทัด 19–21** — ทุก Error ถูกแปลงเป็นผลลัพธ์ `failed` ไม่โยนต่อ หน้าจอจึงใช้ `switch` บน `result.status` แสดงข้อความได้ครบ 4 กรณี

ก่อนบันทึก `sanitizeFileName()` จะแทนอักขระที่ระบบไฟล์ไม่รับ (`\ / : * ? " < > |`) ด้วย `_` และบังคับนามสกุล (ชื่อภาษาไทยยังใช้ได้)

> [!NOTE] ฟังก์ชันนี้ใช้ได้ทั้ง Excel และ CSV
> `saveExportFile` รับ `fileExtension`, `mimeType`, `typeLabel` (ค่าเริ่มต้นเป็น Excel ทุกตัว หน้าส่งออกพลังงานจึงเรียกแบบไม่ส่งพารามิเตอร์) บรรทัด `acceptedTypeGroups:` เป็น `[...]` ไม่ใช่ `const [...]` เพราะข้างในใช้ตัวแปร ใส่ใน `const` ไม่ได้

> [!WHY] ทำไมคืนผลเป็น enum แทนการโยน Exception
> การบันทึกไฟล์มีผลลัพธ์ที่ "ไม่ใช่ Error" อยู่ด้วย เช่น ผู้ใช้กดยกเลิก ถ้าใช้ Exception จะต้องแยกว่า Exception ไหนคือการยกเลิก `FileSaveStatus` ที่มี `saved`, `shared`, `cancelled`, `failed` ทำให้หน้าจอจัดการทุกกรณีได้ชัดเจนและครบด้วย `switch` แบบ Exhaustive (คอมไพเลอร์เตือนถ้าลืมกรณีใด)

---

## user_management_screen.dart — จัดการผู้ใช้และสิทธิ์

เปิดได้เฉพาะ Admin (หน้าโปรไฟล์แสดงเมนูนี้เมื่อ `_isAdmin`) และ Router `/users` ทั้งหมดใช้ `authenticate` ตามด้วย `requireAdmin`

### สิ่งที่ทำได้

- **ดูรายชื่อ** — `UserController` เรียงให้ Admin ขึ้นก่อน บัญชีที่ใช้งานอยู่ก่อนบัญชีที่ถูกระงับ แล้วเรียงตาม Username การ์ดแต่ละใบแสดงอักษรย่อ ชื่อ อีเมล และเวลาเข้าระบบครั้งล่าสุด บัญชีของตัวเองมีป้าย "You"
- **สลับสิทธิ์** — `SegmentedButton` ระหว่าง `admin` กับ `staff` มี Dialog ยืนยันที่เตือนว่า "They will be signed out and must sign in again."
- **ระงับ/เปิดบัญชี** — สวิตช์ `Switch` ป้าย Active/Suspended (ขอบการ์ดเป็นสีแดงเมื่อถูกระงับ)
- **ลบบัญชี** — Dialog เตือนว่าลบถาวร และแนะนำว่าการระงับจะเก็บประวัติไว้
- **สร้างบัญชี** — Bottom Sheet `_CreateUserSheet` ตรวจ Username อย่างน้อย 3 ตัว (อนุญาต `A–Z a–z 0–9 . _ -`) รหัสผ่านอย่างน้อย 8 ตัว (สูงสุด 72 เพราะ bcrypt ใช้ได้แค่ 72 ไบต์) ชื่อ-นามสกุลไม่ว่าง และอีเมลมี `@` ค่าเริ่มต้นของสิทธิ์คือ Staff

ทุกการกระทำวิ่งผ่าน `_runGuarded()` ซึ่งตั้ง `_busyUsername` (การ์ดนั้นแสดงวงหมุนและปิดปุ่ม) เรียก Action แล้วแสดง SnackBar ทั้งกรณีสำเร็จและ Error ในการ์ดมี `canEdit = !isSelf && !isBusy` จึง **ปิดทุกปุ่มบนการ์ดของตัวเอง**

### กฎที่ Backend บังคับ

ไฟล์: `backend/src/routes/users.js`

```js
      const nextRole = update.role ?? target.role;
      const nextActive = update.isActive ?? Boolean(target.is_active);
      const wasActiveAdmin = target.role === 'admin'
        && Boolean(target.is_active);
      const staysActiveAdmin = nextRole === 'admin' && nextActive;

      if (wasActiveAdmin && !staysActiveAdmin) {
        await assertAnotherActiveAdminExists(connection, username);
      }

      if (
        nextRole === target.role
        && nextActive === Boolean(target.is_active)
      ) {
        return;
      }

      await connection.query(
        `UPDATE users
            SET role = ?,
                is_active = ?,
                token_version = token_version + 1
          WHERE username = ?`,
        [nextRole, nextActive ? 1 : 0, username],
      );
```

- **บรรทัด 1–2** — ค่าที่ไม่ได้ส่งมาให้ใช้ค่าเดิม (`??`)
- **บรรทัด 3–5** — คำนวณว่าก่อนแก้เป็น "แอดมินที่ใช้งานอยู่" ไหม และหลังแก้ยังเป็นอยู่ไหม
- **บรรทัด 7–9** — ถ้าการแก้นี้ทำให้แอดมินคนหนึ่งหายไป (ถูกลดสิทธิ์หรือถูกระงับ) ต้องมีแอดมินที่ใช้งานอยู่คนอื่นเหลืออย่างน้อยหนึ่งคน ไม่งั้นตอบ 409 "ระบบต้องมีผู้ดูแลระบบที่ใช้งานอยู่อย่างน้อย 1 บัญชี"
- **บรรทัด 11–16** — ถ้าไม่มีอะไรเปลี่ยนก็ไม่ต้องเขียน
- **บรรทัด 18–25** — อัปเดตสิทธิ์/สถานะ และ **เพิ่ม `token_version` อีก 1** ทำให้ Token ที่ผู้ใช้คนนั้นถืออยู่ใช้ไม่ได้ทันที

กฎอื่นที่ Backend บังคับ ได้แก่ แก้สิทธิ์หรือระงับบัญชีของตัวเองไม่ได้ (400) ลบบัญชีของตัวเองไม่ได้ (400) ลบแอดมินที่ใช้งานอยู่คนสุดท้ายไม่ได้ (409) และ Username หรืออีเมลซ้ำตอนสร้าง (409) ทุกการแก้ทำใน Transaction พร้อม `SELECT ... FOR UPDATE` ล็อกแถวไว้ กันแอดมินสองคนลดสิทธิ์กันเองพร้อมกันจนไม่เหลือแอดมิน

> [!LEARN] token_version ทำงานอย่างไร
> ตอนเข้าสู่ระบบ Backend ใส่ค่า `ver: Number(user.token_version)` ลงใน JWT ทุกคำขอ Middleware `authenticate` อ่านผู้ใช้จากฐานข้อมูลแล้วเช็ก `Number(user.token_version) !== Number(payload.ver)` ถ้าไม่เท่ากันตอบ 401 "กรุณาเข้าสู่ระบบใหม่" และยังเลือกเฉพาะ `is_active = 1` บัญชีที่ถูกระงับจึงใช้ไม่ได้ทันทีเช่นกัน วิธีนี้ทำให้ "เพิกถอน JWT" ได้ ทั้งที่ JWT ปกติเป็น Stateless (ตรวจได้โดยไม่ต้องถามฐานข้อมูล) และเพิกถอนไม่ได้จนกว่าจะหมดอายุ

---

## profile_screen.dart — หน้าโปรไฟล์

เป็น `StatelessWidget` ส่วนหัวสีหลักแสดงชื่อ Username อีเมล และป้ายสิทธิ์ ด้านล่างเป็นเมนู `_ProfileTile` แบ่งสองหมวด

- **System Management** — "Manage User Permissions" (เฉพาะ `_isAdmin` ซึ่งเทียบ `user.role.toLowerCase() == 'admin'`) และ "Database" (ทุกคน)
- **Account & Settings** — Account Settings, Electricity Rate, Application Settings (ส่ง `isAdmin` ต่อไปให้) และ Log Out (มี Dialog ยืนยัน แล้วเรียก Callback `onLogout`)

หน้านี้ทำหน้าที่ **ฉีดพึ่งพา** (Dependency Injection แบบส่งผ่าน Constructor) คือรับ Controller ทั้งหมดมาจาก `app_shell.dart` แล้วส่งต่อให้หน้าที่เปิด หน้าลูกจึงไม่ต้องสร้าง Controller เอง และทุกหน้าใช้ Controller ตัวเดียวกัน สถานะจึงตรงกันทั้งแอป

---

## account_settings_screen.dart — ตั้งค่าบัญชีตัวเอง

มีสองฟอร์มแยก `GlobalKey<FormState>` กัน (`_profileFormKey` และ `_passwordFormKey`) กดบันทึกฟอร์มหนึ่งจึงไม่ไปตรวจอีกฟอร์ม

### แก้ข้อมูลส่วนตัว

Validator ตรวจชื่อ-นามสกุลไม่ว่าง อีเมลตาม Regex `^[^\s@]+@[^\s@]+\.[^\s@]{2,}$` และเบอร์โทร (ถ้ากรอก) ตาม `^[0-9+()\- ]{6,30}$` ถ้า **อีเมลเปลี่ยน** จะเปิด Dialog ถามรหัสผ่านปัจจุบันก่อน (`_askPasswordForEmailChange`) แล้วส่ง `PATCH /auth/me` พร้อม `currentPassword` ซึ่ง Backend ตรวจด้วย bcrypt อีกชั้น

> [!WHY] ทำไมเปลี่ยนอีเมลต้องยืนยันรหัสผ่าน
> คอมเมนต์ในโค้ดอธิบายว่า OTP สำหรับลืมรหัสผ่านถูกส่งไปที่อีเมลนี้ ถ้าใครหยิบเครื่องที่ล็อกอินค้างไว้ไปเปลี่ยนเป็นอีเมลตัวเองได้ ก็จะกด "ลืมรหัสผ่าน" แล้วยึดบัญชีได้ทันที การถามรหัสเดิมปิดช่องนี้

### เปลี่ยนรหัสผ่าน → token_version → บังคับเข้าระบบใหม่

Validator ของรหัสใหม่ต้องยาวอย่างน้อย 8 ตัวและไม่ซ้ำรหัสเดิม ช่องยืนยันต้องตรงกัน จากนั้น Dialog เตือนว่า "Every device signed in with this account will be signed out, including this one."

ไฟล์: `lib/screens/account_settings_screen.dart`

```dart
    setState(() => _savingPassword = true);
    try {
      await widget.controller.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      // เปลี่ยนสำเร็จแล้วจะถูกพากลับไปหน้าเข้าสู่ระบบเองโดยตัวควบคุม
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      _notify(
        error.toString().replaceFirst('ApiException: ', ''),
        isError: true,
      );
      if (mounted) setState(() => _savingPassword = false);
    }
```

- **บรรทัด 3–6** — เรียก `AuthController.changePassword()` ซึ่งเรียก Service ยิง `POST /auth/me/password`
- **บรรทัด 8** — สำเร็จแล้วปิดทุกหน้าที่ซ้อนอยู่จนเหลือหน้าแรก (`popUntil(route.isFirst)`) เพราะ Controller ได้ตั้งสถานะเป็น `signedOut` แล้ว หน้าแรกจะสลับไปเป็นหน้าเข้าสู่ระบบเอง
- **บรรทัด 9–15** — ถ้าผิด (เช่น "รหัสผ่านปัจจุบันไม่ถูกต้อง") แสดง SnackBar สีแดง และปิดธงเฉพาะกรณีพลาด (กรณีสำเร็จหน้าจอจะถูกปิดไปแล้ว)

ลำดับเหตุการณ์ทั้งหมด

1. Backend ตรวจรหัสใหม่ 8–72 ไบต์ ไม่ซ้ำรหัสเดิม เทียบรหัสเดิมด้วย `bcrypt.compare` แล้ว `UPDATE users SET password_hash = ?, password_changed_at = NOW(), token_version = token_version + 1`
2. `AuthService.changePassword()` ลบ Token ที่เก็บใน Secure Storage (`rmutt_access_token`) และล้างการจำรหัสผ่าน (`clearRememberedLogin()`) เพราะรหัสที่จำไว้เป็นรหัสเก่าแล้ว
3. `AuthController` ตั้ง `user = null` และ `status = AuthStatus.signedOut` แล้ว `notifyListeners()`
4. เครื่องอื่นที่ยังถือ Token เก่า เมื่อยิงคำขอครั้งถัดไปจะโดน 401 จาก Middleware เพราะ `ver` ใน Token ไม่ตรงกับ `token_version` ใหม่

---

## application_settings_screen.dart — ตั้งค่าแอป

หน้าจอนี้เป็นรายการเรียบแบ่งสามหมวด และใช้ `AnimatedBuilder` ฟังทั้ง `AppSettingsController` และ `SystemSettingsController` พร้อมกันด้วย `Listenable.merge`

| หมวด | แถว | ค่าถูกเก็บที่ |
|---|---|---|
| General | ภาษา (ภาษาไทย/English) ด้วย `_MiniSegmented` | เครื่องนี้ |
| General | ธีมสี เปิด Bottom Sheet `_ThemeSheet` | เครื่องนี้ |
| General | การแจ้งเตือน (แตะข้อความไปหน้าตั้งค่าแจ้งเตือน สวิตช์ขวาเปิด/ปิดทั้งหมด) | เครื่องนี้ |
| Text display | ขนาดตัวอักษร 4 ระดับ พร้อมตัวอย่างข้อความ | เครื่องนี้ |
| For administrators | สวิตช์ปิดแอร์อัตโนมัติทั้งอาคาร + สวิตช์โหมดทดสอบ (30 วิ / 1 นาที) | **เซิร์ฟเวอร์** |

### ธีมสี (Theme Palette)

`AppThemeChoice` มี 5 ค่า: `white`, `gray`, `black`, `green` และ `system` (ขาวเมื่อเครื่องอยู่โหมดสว่าง เทาเมื่อโหมดมืด) แต่ละตัวเลือกใน Sheet วาด `_MiniScreen` เป็นหน้าจอย่อส่วนจากสี 4 สีของธีมนั้น (พื้น แถบหัว การ์ด สีเน้น จาก `AppTheme.previewColors`) ให้เห็นก่อนเลือก

### ขนาดตัวอักษร

`AppTextScale` มี `small` (0.90), `normal` (1.00), `large` (1.15), `extraLarge` (1.30) ค่านี้เป็น **ตัวคูณ** ไม่ใช่ขนาดตายตัว

ไฟล์: `lib/controllers/app_settings_controller.dart`

```dart
  double resolvedTextScale(double systemScale) {
    final combined = systemScale * _textScale.factor;
    if (!combined.isFinite || combined <= 0) return _textScale.factor;
    return combined.clamp(0.8, 2.0);
  }
```

- **บรรทัด 2** — คูณค่าที่ผู้ใช้ตั้งไว้ทั้งเครื่อง (เช่นใน Android) กับที่เลือกในแอป คนที่ตั้งเครื่องตัวใหญ่ไว้แล้วจะไม่ถูกแอปบังคับให้เล็กลง
- **บรรทัด 3** — กันค่าผิดปกติ
- **บรรทัด 4** — จำกัดช่วง 0.8–2.0 กันตัวอักษรใหญ่จนปุ่มล้นจอกดไม่ได้

### การเก็บค่าลง Secure Storage

ทุก Setter ใน `AppSettingsController` ทำตามแบบเดียวกัน

```dart
  Future<void> setTheme(AppThemeChoice choice) async {
    if (_theme == choice) {
      return;
    }

    _theme = choice;
    notifyListeners();

    try {
      await _store.saveThemeCode(choice.code);
      // เก็บค่าแบบเดิมไว้ด้วย ถ้าย้อนไปลงแอปรุ่นก่อนจะยังได้โหมดใกล้เคียง
      await _store.saveDarkMode(isDarkMode);
    } catch (_) {
      // The selected theme still applies for the current session.
    }
  }
```

- **บรรทัด 2–4** — ค่าเดิมไม่ต้องทำอะไร (ไม่ต้องวาดใหม่ ไม่ต้องเขียนดิสก์)
- **บรรทัด 6–7** — **เปลี่ยนในหน่วยความจำและแจ้ง UI ก่อน** ผู้ใช้เห็นผลทันที
- **บรรทัด 9–15** — แล้วค่อยบันทึก ถ้าบันทึกพลาด ค่ายังใช้ได้ในรอบนี้ แค่ไม่ถูกจำ (Graceful Degradation)

ค่าทั้งหมดเก็บผ่าน `SecureAppSettingsStore` ซึ่งห่อ `FlutterSecureStorage` ด้วยคีย์ `app_theme`, `app_dark_mode` (ค่าเก่าก่อน v3.13 เก็บไว้ให้ย้อนรุ่นได้), `app_language_code`, `app_electricity_rate`, `app_text_scale` และ `app_alert_preferences` ตอนเปิดแอป `initialize()` อ่านทีละค่าใน `try` แยกกัน ค่าไหนอ่านไม่ได้ก็ใช้ค่าเริ่มต้นของค่านั้น (ธีมขาว ภาษาไทย 4.50 บาท ขนาดปกติ แจ้งเตือนเปิดหมด) และถ้าไม่เคยมีค่าธีมใหม่แต่เคยเปิดโหมดมืดไว้ จะแปลงเป็นธีมเทา (Migration ค่าเก่า)

> [!NOTE] ทำไมใช้ Secure Storage กับค่าที่ไม่ลับ
> ภาษาหรือธีมไม่ใช่ความลับ แต่แอปใช้ `flutter_secure_storage` อยู่แล้วสำหรับ Token และรหัสที่จำไว้ การใช้ที่เก็บเดียวทำให้ไม่ต้องเพิ่มแพ็กเกจ (เช่น shared_preferences) และ Interface `AppSettingsStore` ทำให้เทสต์ใส่ที่เก็บปลอมได้

### สวิตช์ปิดแอร์อัตโนมัติและโหมดทดสอบ (ค่าระดับระบบ)

`_AutoOffRow` ใช้ `SystemSettingsController` ไม่ใช่ `AppSettingsController` เพราะผู้ที่ส่งคำสั่งปิดแอร์จริงคือ Backend สวิตช์ในมือถือหยุดระบบเองไม่ได้ ต้องสั่งไปเก็บที่ตาราง `system_settings` บนเซิร์ฟเวอร์

```text
โครงสร้าง UI ของ _AutoOffRow ในหน้าตั้งค่าแอป (หมวดสำหรับผู้ดูแลระบบ):
┌────────────────────────────────────────────────────────────────────┐
│  [ไอคอน]  ปิดแอร์อัตโนมัติทั้งอาคาร                   [สวิตช์หลัก]  │
│           คำอธิบายเปลี่ยนตามโหมดที่เปิดอยู่ (5-15 นาที / 30 วิ-1 นาที) │
│ ────────────────────────────────────────────────────────────────── │
│  [ไอคอน]  โหมดทดสอบการปิดอัตโนมัติ                    [สวิตช์ทดสอบ] │
│           นอกคาบเรียน 30 วินาที · ในคาบเรียน 1 นาที                   │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │ ⏱ โหมดทดสอบเปิดอยู่: นอกคาบ 30 วินาที · ในคาบ 1 นาที        │  │  <-- แสดงเฉพาะตอนเปิดทั้งคู่
│  └──────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────┘
```

- **สวิตช์หลัก (`Key('auto-off-master-switch')`)**: เปิด/ปิดระบบปิดแอร์อัตโนมัติทั้งอาคาร ถ้าผู้ใช้ไม่ใช่ Admin หรือกำลังบันทึก (`controller.isSaving`) ค่า `onChanged` จะเป็น `null` (กดไม่ได้ แต่เห็นสถานะปัจจุบัน)
- **สวิตช์โหมดทดสอบ (`Key('auto-off-test-mode-switch')`)**: เปิด/ปิดโหมดทดสอบ (นอกคาบ 30 วินาที / ในคาบเรียน 1 นาที) จะกดได้ก็ต่อเมื่อ `isAdmin && !controller.isSaving && enabled` (ถ้าสวิตช์หลักปิดอยู่ แถวโหมดทดสอบจะจางลงด้วย `Opacity(opacity: 0.5)` และกดไม่ได้ เพราะระบบปิดแอร์ไม่ได้ทำงานอยู่)
- **ป้ายเตือนสีส้ม (Amber Banner)**: เมื่อ `enabled && testMode` เป็นจริงทั้งคู่ จะแสดงป้ายเตือนสีส้มด้านล่างเพื่อให้แอดมินสังเกตได้ทันทีว่าตึกกำลังอยู่ในโหมดทดสอบ (ไม่ลืมเปิดทิ้งไว้หลังสาธิตเสร็จ)
- ทั้งสองสวิตช์ใช้ **Optimistic Update** คือขยับสวิตช์ทันทีที่กด ถ้าเซิร์ฟเวอร์ปฏิเสธจะถอยกลับค่าเดิมแล้วแสดง SnackBar สีแดง

---

## notification_settings_screen.dart — ตั้งค่าการแจ้งเตือน

มีสวิตช์หลัก "Allow notifications" และสวิตช์รายประเภท 3 ชนิดตาม `AlertPreferences.configurableKinds`

| ชนิด (`SystemAlertKind`) | ชื่อบนจอ | สีไอคอน |
|---|---|---|
| `outsideScheduleOccupied` | Running outside class hours | warn |
| `autoOffSucceeded` | Air conditioner switched off | accent |
| `autoOffFailed` | Automatic shutdown failed | danger |

เมื่อปิดสวิตช์หลัก แถวรายประเภทจะจาง (`Opacity 0.5`) และกดไม่ได้ แต่ **ค่าที่เลือกไว้ยังถูกจำ** เปิดกลับมาจะได้แบบเดิม สวิตช์เหล่านี้คุมเฉพาะการ "เด้ง" บนเครื่อง (`push`) ส่วนรายการแจ้งเตือนภายในแอปแสดงทุกชนิดเสมอ (`showsInApp` คืน `true` ตลอด) เงื่อนไขการเด้งจริงคือ `pushesToPhone(kind) => enabled && channelsFor(kind).push`

ค่าเก็บเป็น JSON ก้อนเดียวผ่าน `AlertPreferences.encode()` ใช้ชื่อ enum เป็นคีย์ ตอนอ่าน (`decode`) ถ้ารูปแบบเพี้ยนจะกลับไปใช้ค่าเริ่มต้น และชนิดใหม่ที่ไม่มีในข้อมูลเก่าได้ค่าเริ่มต้นของมันเอง ชนิด `unknown` (ชนิดที่ Backend เพิ่มในอนาคตแต่แอปรุ่นนี้ยังไม่รู้จัก) จะขึ้นในรายการเสมอแต่ไม่เด้ง และผู้ใช้ปิดไม่ได้ เพื่อไม่ให้ข้อมูลใหม่หายไปเงียบ ๆ

> [!WHY] ทำไมค่าแจ้งเตือนเก็บในเครื่อง ไม่ใช่บนเซิร์ฟเวอร์
> การเด้งแจ้งเตือนทำโดยแอปบนเครื่องนั้นเอง (`AlertNotifier` ใช้การแจ้งเตือนในเครื่องซึ่งทำงานเมื่อแอปยังไม่ถูกปิดสนิท) คนเดียวอาจอยากให้คอมที่ห้องควบคุมเด้งทุกอย่าง แต่มือถือส่วนตัวเงียบตอนกลางคืน การเก็บแยกรายเครื่องจึงตรงกับการใช้งานจริง

---

## electricity_rate_screen.dart — อัตราค่าไฟ

ผู้ใช้กรอกอัตราบาทต่อหน่วย (kWh) ช่องกรอกรับเฉพาะ `0-9 . ,` ยาวไม่เกิน 6 ตัว และ `_parseRate` แปลง `,` เป็น `.` (รองรับคนพิมพ์ทศนิยมแบบยุโรป) ระหว่างพิมพ์ `_updatePreview` คำนวณตัวอย่างค่าไฟของพลังงานสมมติ 270.5 kWh ตามสูตร "Cost = Energy (kWh) × Electricity rate" ให้เห็นทันที

ไฟล์: `lib/controllers/app_settings_controller.dart`

```dart
  static bool isValidElectricityRate(double? rate) {
    return rate != null &&
        rate.isFinite &&
        rate >= minimumElectricityRate &&
        rate <= maximumElectricityRate;
  }
```

- **บรรทัด 2–5** — ต้องเป็นตัวเลขจริง (`isFinite` กัน NaN และอนันต์) และอยู่ในช่วง `0.01` ถึง `100.00` บาท ฟังก์ชันเป็น `static` จึงใช้ได้ทั้งใน Validator ของหน้าจอและใน `setElectricityRate()` ของ Controller (ตรวจสองชั้น)

อัตรานี้เก็บในเครื่องและใช้กับ `calculateElectricityCost()` ในหน้าสรุปพลังงาน รวมถึงคอลัมน์ค่าไฟประมาณการในไฟล์ Excel ที่ส่งออก ค่าเริ่มต้นคือ `defaultElectricityRate = 4.50`

---

## จุดที่ยังไม่สอดคล้องกันในโค้ด (ควรรู้ไว้ก่อนถูกถาม)

> [!WARN] ปุ่มลบห้องไม่ได้นับเซ็นเซอร์ตรวจจับคน
> Dialog ใน `room_management_screen.dart` เปิดปุ่มลบเมื่อไม่มีแอร์และไม่มีคาบเรียน แต่ Backend ยังปฏิเสธ (409) ถ้ามีเซ็นเซอร์ตรวจจับคนผูกอยู่ ผู้ใช้จะกดลบได้แล้วเจอ Error แทนการเห็นเหตุผลล่วงหน้า

> [!WARN]
> ** ผลการล้างบอร์ดตอนลบอุปกรณ์ไม่ถูกแสดง** Backend ตอบ `boardCleared: true/false` ใน `DELETE /air-conditioners/:deviceId` และ `DELETE /occupancy-sensors/:deviceId` แต่ไม่มีโค้ด Dart อ่านค่านี้ (`remove()` คืน `Future<void>`) แอดมินจึงไม่รู้จากแอปว่าบอร์ดที่ออฟไลน์อยู่ยังไม่ถูกล้าง

> [!NOTE]
> ** import ที่ยังไม่ได้ใช้** `ble_provisioning_screen.dart` import `../widgets/air_control_badge.dart` แต่ในไฟล์ไม่มีการเรียก `AirControlBadge` (ช่องยี่ห้อใช้ `_WiredBrandField` ที่เขียนเอง) ไม่กระทบการทำงาน แต่ `flutter analyze` อาจเตือน `unused_import`

> [!WARN] Wi-Fi แบบไม่มีรหัสผ่านใช้ไม่ได้ ทั้งที่รายการแสดงให้เลือก
> รายการ Wi-Fi แสดงไอคอนกุญแจเปิดสำหรับเครือข่ายเปิด แต่ Validator ของแอปและเฟิร์มแวร์ (`incoming.wifiPassword.length() >= 8`) บังคับรหัสอย่างน้อย 8 ตัว เลือกเครือข่ายเปิดแล้วจะบันทึกไม่ได้

> [!WARN] อัตราค่าไฟถูกปัดเหลือ 2 ตำแหน่งตอนบันทึก
> ช่องกรอกรับได้ถึง 6 ตัวอักษร (เช่น `4.1234`) และหน้าส่งออกแสดงอัตรา 4 ตำแหน่ง แต่ `saveElectricityRate` เก็บด้วย `toStringAsFixed(2)` หลังเปิดแอปใหม่ค่าจะกลายเป็น `4.12` ส่วนในรอบที่ตั้งค่ายังใช้ `4.1234` อยู่

> [!NOTE] ข้อความบางจุดยังไม่ผ่านตัวแปลภาษา
> เช่น หัว Bottom Sheet `'Add Room'`/`'Edit Room'` ข้อความ Validator ในหน้าจัดการห้องและหน้าสร้างผู้ใช้ ป้าย `'Active'`/`'Suspended'` ชื่อวันในหัวรายการของหน้าจัดการตาราง และชื่อธีมในแผ่นเลือกธีม (แถวหลักใช้ `context.tr(choice.label)` แต่ `_ThemeChoiceTile` ใช้ `choice.label` ตรง ๆ) เมื่อแอปเป็นภาษาไทยจุดเหล่านี้จะยังเป็นภาษาอังกฤษ

---

## หลักการออกแบบที่ควรจำ

- **Backend เป็นผู้ตัดสินกฎเสมอ** — แอปซ่อนปุ่มและตรวจข้อมูลล่วงหน้าเพื่อความสะดวก แต่สิทธิ์ ความซ้ำ เวลาทับซ้อน และกฎแอดมินคนสุดท้ายถูกบังคับซ้ำที่ Backend
- **จองก่อน แล้วค่อยแตะฮาร์ดแวร์** — การ Provisioning ขอ Token และค่า MQTT จาก Backend ก่อนเขียนลงบอร์ด ถ้าผิดกฎจะไม่มีอะไรถูกเขียนลงบอร์ด และการจองที่ค้างหมดอายุเองใน 15 นาที
- **ความลับไม่เดินทางเกินจำเป็น** — รหัส Wi-Fi ไม่ถูกส่งให้ Backend และบอร์ดไม่ส่งรหัสเดิมออกทาง BLE (ใช้ `keepPassword`) Token ถูกเก็บเป็น Hash และใช้ได้ครั้งเดียว ค่า MQTT ออกโดยเซิร์ฟเวอร์ ไม่ผ่านมือคน
- **ทดสอบก่อนบันทึก** — ESP32 ลองต่อ Wi-Fi จริงก่อนเขียน NVS ถ้าไม่ผ่านค่าเดิมยังอยู่ บอร์ดไม่เสีย
- **ทุกการเชื่อมต่อ BLE ปิดใน finally** — แต่ละขั้นเริ่มจากสถานะที่รู้แน่ชัด และบอร์ดกลับไปประกาศตัวได้เสมอ
- **ทนความต่างของแพลตฟอร์ม** — ไม่กรอง UUID ตอนสแกน รอ `connect()` ให้จบ ลองค้นหา Service ซ้ำบนสายเดิม แยกข้อความ Error ตามขั้น บันทึกไฟล์ด้วยกล่อง Save บน Windows และเมนูแชร์บน Android
- **ให้ฮาร์ดแวร์บอกความสามารถของตัวเอง** — บอร์ดสายแอร์ส่ง `controlType: "wired"` ใน identity แอปล็อกยี่ห้อให้ ส่วนบอร์ดเก่าที่ไม่ส่งถือเป็น `ir` จึงยังใช้ได้ตามเดิม
- **ส่วนเสริมพังได้โดยไม่ลากส่วนหลัก** — อ่าน `settingsUuid` ไม่ได้ก็ยังยืนยันบอร์ดได้ ไม่มี `wifiScanUuid` ก็พิมพ์ SSID เองได้ บันทึกค่าตั้งลงที่เก็บไม่ได้ก็ยังใช้ในรอบนั้นได้
- **ดูก่อนแล้วค่อยยืนยัน** — นำเข้าตารางและส่งออกพลังงานต่างมีขั้น Preview ก่อนการกระทำจริง และการนำเข้าทั้งหมดอยู่ใน Transaction เดียว
- **แยกค่าตั้งตามเจ้าของ** — ค่าระดับเครื่อง (ภาษา ธีม ขนาดตัวอักษร ค่าไฟ การแจ้งเตือน) อยู่ใน Secure Storage ใครก็แก้ได้ ค่าระดับระบบ (ปิดแอร์อัตโนมัติ) อยู่บนเซิร์ฟเวอร์และแก้ได้เฉพาะแอดมิน
- **เพิกถอนสิทธิ์ทันทีด้วย token_version** — เปลี่ยนรหัสผ่าน เปลี่ยนสิทธิ์ หรือระงับบัญชี ทำให้ Token เก่าทุกใบใช้ไม่ได้ในคำขอถัดไป

## คำถามที่อาจารย์อาจถาม

1. **ถาม:** ทำไมต้องใช้ BLE ตั้งค่า ESP32 แทนการต่อผ่าน Wi-Fi หรือเซิร์ฟเวอร์เลย?
   **ตอบ:** ตอนแรกบอร์ดยังไม่รู้ชื่อและรหัส Wi-Fi จึงต่อเน็ตไม่ได้และเซิร์ฟเวอร์คุยกับมันไม่ได้ BLE เป็นช่องทางระยะใกล้ที่ทั้ง ESP32 และคอมพิวเตอร์มีอยู่แล้ว ใช้ส่งค่าเริ่มต้นครั้งเดียว หลังจากนั้นบอร์ดใช้ Wi-Fi และ MQTT

2. **ถาม:** Service กับ Characteristic ต่างกันอย่างไร และโปรเจคนี้ใช้อะไรบ้าง?
   **ตอบ:** Service คือกลุ่ม Characteristic คือค่าแต่ละตัวที่อ่าน เขียน หรือ Notify ได้ โปรเจคมี Service เดียว (`7b570001-...`) และ Characteristic 5 ตัว: config (Write), status (Notify), identity (Read), wifiScan (Read) และ settings (Read)

3. **ถาม:** ทำไมต้องหั่นข้อมูลเป็นชิ้นละ 150 ไบต์ และบอร์ดรู้ได้อย่างไรว่าได้ครบ?
   **ตอบ:** เพราะหนึ่งแพ็กเก็ต BLE ถูกจำกัดด้วย MTU แต่ JSON ยาวหลายร้อยไบต์ แต่ละชิ้นมีหัว 6 ไบต์ คือเวอร์ชัน ประเภท ลำดับชิ้น และจำนวนชิ้นทั้งหมด บอร์ดต่อชิ้นตามลำดับ ถ้าผิดลำดับจะทิ้งแล้วแจ้ง `sequence_error` เมื่อได้ครบตามจำนวนจึงเริ่มประมวลผล

4. **ถาม:** แอปรู้ได้อย่างไรว่าบอร์ดต่อ Wi-Fi ได้จริง?
   **ตอบ:** แอปเปิด Notify ที่ status characteristic แล้วรอได้สูงสุด 40 วินาที บอร์ดลองต่อ Wi-Fi จริงก่อนบันทึก แล้ว Notify กลับ `{"ok":true}` หรือ `{"ok":false,"message":...}` แอปใช้ Completer แปลง Notify เป็น Future ที่ await รอได้

5. **ถาม:** ถ้ามีคนเอา ESP32 ปลอมมาส่งข้อมูลเข้า MQTT แล้วอ้างว่าเป็นแอร์ห้องหนึ่ง ระบบป้องกันอย่างไร?
   **ตอบ:** บอร์ดจะ active ได้ต้องส่ง Provisioning Token ที่ Backend ออกให้ตอนแอดมินจอง Backend เก็บเฉพาะ Hash ของ Token เทียบแบบเวลาคงที่ Token หมดอายุใน 15 นาทีและใช้ได้ครั้งเดียว นอกจากนี้ในโหมด dynsec บอร์ดแต่ละตัวมีบัญชี MQTT ของตัวเองที่เห็นเฉพาะ Topic ของตัวเอง

6. **ถาม:** ปัญหาบลูทูธบน Windows คืออะไร แก้อย่างไร?
   **ตอบ:** บน Windows คำสั่ง connect ค้นหา GATT อยู่ภายในแล้ว รุ่นเก่าไปสั่ง discoverServices ซ้อนจึงค้าง และยังตัดต่อใหม่ถี่ ๆ แก้โดยรอ connect ให้จบ (45 วินาที) เช็กสถานะเชื่อมต่อซ้ำ หน่วงเวลาให้พร้อม แล้วค้นหา Service ซ้ำได้ 3 ครั้งบนสายเดิม และแยกข้อความ Error ระหว่างขั้นเชื่อมต่อกับขั้นค้นหา นอกจากนี้ยังไม่กรอง UUID ตอนสแกน เพราะไดรเวอร์บางตัวจับคู่ชื่อใน Scan Response กับ UUID ไม่ได้

7. **ถาม:** ทำไมนำเข้าตาราง Excel ต้องมีขั้น Preview?
   **ตอบ:** ไฟล์จริงมักมีความผิดปกติ ขั้น Preview ให้ Backend อ่านและตรวจทุกอย่างโดยยังไม่บันทึก ผู้ใช้เห็นจำนวนห้อง คาบ คำเตือน และห้องใหม่ก่อน เมื่อยืนยันแล้ว Backend บันทึกทั้งหมดใน Transaction เดียว ถ้าพังก็ย้อนกลับทั้งหมด ตารางเดิมไม่หาย

8. **ถาม:** ตรวจเวลาเรียนทับกันอย่างไร คาบ 9:00–12:00 กับ 12:00–15:00 ทับกันไหม?
   **ตอบ:** ใช้สูตร A เริ่มก่อน B จบ และ A จบหลัง B เริ่ม โดยใช้เครื่องหมายมากกว่า/น้อยกว่าแท้ คาบที่ต่อกันพอดีจึงไม่นับว่าทับ เวลาเก็บเป็น `HH:mm` เติมศูนย์จึงเทียบแบบข้อความได้ ตรวจทั้งในแอปและใน Backend

9. **ถาม:** เปลี่ยนรหัสผ่านแล้วทำไมเครื่องอื่นหลุดด้วย?
   **ตอบ:** Backend เพิ่ม `token_version` ของผู้ใช้ JWT ทุกใบมีค่า `ver` ตอนออก Middleware เทียบทุกคำขอ ถ้าไม่ตรงตอบ 401 ฝั่งแอปเครื่องที่เปลี่ยนก็ลบ Token และรหัสที่จำไว้ แล้วกลับไปหน้าเข้าสู่ระบบ

10. **ถาม:** ทำไมแอดมินลดสิทธิ์ตัวเองหรือลบแอดมินคนสุดท้ายไม่ได้?
    **ตอบ:** เพื่อกันระบบไม่เหลือใครจัดการได้เลย Backend ห้ามแก้หรือลบบัญชีตัวเอง และก่อนลดสิทธิ์ ระงับ หรือลบแอดมิน จะตรวจใน Transaction ที่ล็อกแถวไว้ว่ายังมีแอดมินที่ใช้งานอยู่คนอื่น ไม่งั้นตอบ 409 แอปก็ปิดปุ่มบนการ์ดของตัวเองไว้ด้วย

11. **ถาม:** บอร์ดสายแอร์ Daikin กับบอร์ด IR ใช้หน้าตั้งค่าเดียวกัน แอปแยกได้อย่างไร?
    **ตอบ:** ชื่อ BLE ขึ้นต้น `RMUTT-AC-` เหมือนกัน แต่ตอนอ่าน identity บอร์ดสายแอร์ส่ง `controlType: "wired"` และ `brand: "Daikin"` มาด้วย `BleDeviceIdentity.isWired` จึงเป็นจริง หน้าจอแสดง "ชนิดบอร์ด: ควบคุมผ่านสายแอร์" ล็อกช่องยี่ห้อเป็น "Daikin · สายแอร์" และ `_protocolForBoard` ตั้งโปรโตคอลเป็น `DAIKIN_WIRED` ให้เอง บอร์ดเฟิร์มแวร์เก่าที่ไม่ส่งช่องนี้ถือเป็น `ir` และเลือกยี่ห้อจาก Dropdown ตามเดิม Backend ยังมีด่านสุดท้ายแก้ `protocol` เป็น `DAIKIN_WIRED` ถ้าบอร์ดรายงานว่าเป็นสายแอร์

12. **ถาม:** ถ้าเปลี่ยนบอร์ดในห้องจากบอร์ดสายแอร์กลับเป็นบอร์ด IR ระบบจะเผลอใช้โปรโตคอล `DAIKIN_WIRED` ต่อไหม?
    **ตอบ:** ไม่ `_protocolForBoard()` ถูกเรียกหลัง `_applySavedBoardSettings()` ทุกครั้งที่อ่าน identity ถ้าบอร์ดเป็นสายแอร์จะบังคับ `DAIKIN_WIRED` แต่ถ้าบอร์ดเป็น IR และค่าที่ค้างอยู่เป็น `DAIKIN_WIRED` จะเปลี่ยนเป็น `DAIKIN` (Daikin แบบ IR) ให้ และ Dropdown มี `key` ตาม Device ID จึงสร้างใหม่และแสดงค่าที่ถูกต้อง ไม่ค้างค่าของบอร์ดก่อนหน้า

13. **ถาม:** บอร์ดที่ถูกลบออกจากห้องในแอป จะเอาไปตั้งค่าห้องใหม่ได้เลยไหม?
    **ตอบ:** ได้ ถ้าตอนลบบอร์ดออนไลน์อยู่ Backend ส่ง `{"action":"unprovision"}` ให้บอร์ดก่อนลบบัญชี MQTT บอร์ดล้าง NVS แล้วรีบูตเข้าโหมดตั้งค่าบลูทูธเอง หน้าตั้งค่า BLE จะเห็นบอร์ดนี้เหมือนบอร์ดใหม่ ไม่ต้องกด "ตั้งค่าใหม่" ก่อน แต่ถ้าบอร์ดออฟไลน์ตอนลบ บอร์ดจะล้างตัวเองเมื่อกลับมาออนไลน์แล้วถูก Broker ปฏิเสธบัญชีต่อเนื่องครบ 2 นาที ถ้าไม่กลับมาออนไลน์เลยต้องกด BOOT ค้าง + RESET หรือแฟลช `reset.ino` ส่วนแอปเองไม่ได้แสดงว่าบอร์ดถูกล้างแล้วหรือยัง (`boardCleared` ไม่ถูกอ่าน)

## สรุปและเช็กลิสต์ความเข้าใจ

ถ้าตอบข้อเหล่านี้ได้โดยไม่เปิดโค้ด แปลว่าเข้าใจบทนี้แล้ว

- [ ] เล่าเส้นทาง Provisioning ได้ครบ: สแกน → เชื่อมต่อ อ่าน identity → กรอกฟอร์ม → จองกับ Backend → เขียนลงบอร์ดผ่าน BLE → รอ ACK → Backend เปิดใช้งานเมื่อบอร์ดส่ง token
- [ ] อธิบาย Service, Characteristic และ 5 Characteristic ของโปรเจกต์ (config, status, identity, wifiScan, settings)
- [ ] อธิบายการหั่นข้อมูล 150 ไบต์พร้อมหัว 6 ไบต์ และการรอ ACK 40 วินาทีด้วย `Completer`
- [ ] อธิบายว่าทำไมต้องจองกับ Backend ก่อนแตะบอร์ด และ provisioning token ป้องกันบอร์ดปลอมอย่างไร
- [ ] บอกปัญหา BLE บน Windows และวิธีแก้ (รอ `connect()` จบ, ไม่สั่ง discover ซ้อน)
- [ ] อธิบายได้ว่าหน้าตั้งค่ารู้ชนิดบอร์ดจาก `controlType` ใน identity และเปลี่ยน 3 จุดอะไรบ้างสำหรับบอร์ดสายแอร์ (ข้อความชนิดบอร์ด, `_WiredBrandField` ล็อกยี่ห้อ, `_protocolForBoard`)
- [ ] อธิบายได้ว่าทำไม Dropdown ยี่ห้อต้องมี `key: ValueKey('protocol-<deviceId>')`
- [ ] อธิบายได้ว่าบอร์ดที่ถูกลบในแอปกลับเข้าโหมดตั้งค่าบลูทูธเองเมื่อไหร่ และเมื่อไหร่ต้องรีเซ็ตที่ตัวบอร์ด
- [ ] อธิบายการนำเข้าตารางจาก Excel แบบ Preview แล้วค่อย Commit และการตรวจเวลาทับกัน
- [ ] อธิบายกฎแอดมินคนสุดท้าย และ `token_version` ที่ทำให้เปลี่ยนรหัสผ่านแล้วเครื่องอื่นหลุด
