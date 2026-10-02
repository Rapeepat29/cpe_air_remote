# เริ่มใช้งาน RMUTT Save Energy

ระบบนี้ประกอบด้วย Flutter App, Node.js Backend, MariaDB, Mosquitto MQTT Broker
ESP32 Firmware หนึ่งบอร์ดต่อแอร์หนึ่งเครื่อง และบอร์ด ESP32 + LD2410 แยก
อีกหนึ่งบอร์ดต่อห้องที่ต้องการตรวจคน

## 1. เตรียมโปรแกรม

- Docker Desktop
- Node.js 20 ขึ้นไป
- MariaDB
- Flutter SDK
- Arduino IDE และ ESP32 board package

## 2. ตั้งค่า MQTT

เปิด Docker Desktop แล้วเปิด PowerShell ที่โฟลเดอร์โปรเจกต์:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
cd mqtt
.\setup_mqtt.ps1
cd ..
```

สคริปต์จะสร้าง Broker, Username/Password และใส่ MQTT settings ลง
`backend/.env` ให้โดยอัตโนมัติ หาก LAN IP ที่แสดงไม่ตรงกับ `ipconfig` ให้รัน:

```powershell
cd mqtt
.\setup_mqtt.ps1 -BrokerHost 192.168.1.10
cd ..
```

## 3. ตั้งค่า Backend และ MariaDB

เปิด `backend/.env` แล้วแก้ค่า `DB_*` ให้ตรงกับ MariaDB จากนั้นสร้าง
`JWT_SECRET` และ `OTP_PEPPER` คนละค่าด้วยคำสั่งนี้สองครั้ง:

```powershell
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"
```

ติดตั้งและสร้างตาราง:

```powershell
cd backend
npm ci
npm run db:init
npm test
npm start
```

ถ้าใช้ฐานข้อมูลเก่าที่มีข้อมูลอยู่แล้ว ให้สำรองฐานข้อมูลก่อน แล้วใช้ migration
ตามหัวข้อ Backend ใน `README.md` แทน `npm run db:init`

สำหรับรุ่นที่เพิ่ม PZEM และ LD2410 ให้รัน migration ต่อไปนี้หนึ่งครั้ง:

```powershell
npm run db:migrate:pzem
npm run db:migrate:occupancy
```

## 4. ตรวจทั้ง Backend และ MQTT

เปิด PowerShell อีกหน้าต่างที่โฟลเดอร์โปรเจกต์:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\check_system.ps1
```

ต้องเห็น `ระบบหลักพร้อม: MariaDB + Backend + MQTT`

## 5. รัน Flutter บน Windows

```powershell
flutter create --platforms=windows .
flutter clean
flutter pub get
flutter test
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api
```

## 6. อัปโหลด ESP32 Firmware

เปิดไฟล์:

```text
firmware/rmutt_esp32_air/rmutt_esp32_air.ino
```

ติดตั้ง ArduinoJson 6.x, PubSubClient และ IRremoteESP8266 2.9.0 แล้วอัปโหลด
ลง ESP32 จากนั้นเข้าแอปด้วย Admin เปิดห้อง และเลือกเพิ่มแอร์ผ่าน Bluetooth

ในหน้า Bluetooth ให้เลือกชื่อ Wi-Fi ที่ ESP32 สแกนพบและกรอกเฉพาะรหัสผ่าน
Wi-Fi เท่านั้น ค่า MQTT ทั้งหมดมาจาก `backend/.env` อัตโนมัติ

สำหรับเซ็นเซอร์คน ให้เปิด
`firmware/rmutt_esp32_occupancy/rmutt_esp32_occupancy.ino` และติดตั้งไลบรารี
`ld2410` by Nick Reynolds เวอร์ชัน 0.2.2 ขึ้นไป จากนั้น Admin เปิดห้องและ
เลือกเพิ่มเซ็นเซอร์ตรวจจับคน ชื่อ Bluetooth จะขึ้นต้นด้วย `RMUTT-OCC-`

เมื่อบันทึกสำเร็จ เส้นทางคำสั่งคือ:

```text
Flutter -> Backend API -> Mosquitto -> ESP32 -> IR -> แอร์
```
