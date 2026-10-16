หมายเหตุ (ต.ค. 2569): ยังเป็นพฤติกรรมปัจจุบัน (แอปไม่มีช่อง MQTT ให้กรอก Backend ส่งค่าให้บอร์ดเอง)
ที่เปลี่ยนไป: ตอนใช้งานจริงบนเซิร์ฟเวอร์ MQTT_URL เป็น mqtts:// ผ่านพอร์ต 8883 (ค่า MQTT_DEVICE_URL ใช้บอกที่อยู่ที่บอร์ดต่อ)
และตั้ง MQTT_DEVICE_AUTH=dynsec ให้บอร์ดแต่ละตัวมีบัญชี MQTT ของตัวเอง (ดู deploy/DEPLOY.md)
ส่วน MQTT_URL=mqtt://192.168.1.153 ด้านล่างใช้กับ Broker ทดสอบในโฟลเดอร์ mqtt/ เท่านั้น
วิธีติดตั้ง/อัปเดตปัจจุบัน: ดึงโค้ดด้วย git pull แล้วรัน .\deploy\update-server.ps1 (รัน migration ให้เอง)
  แอปรันด้วย flutter pub get แล้ว flutter run --dart-define=API_BASE_URL=... (ไม่ต้องใช้ MQTT_DEFAULT_HOST แล้ว)
  ขั้นตอนแบบแตก ZIP ทับโปรเจกต์ และ MQTT_URL/ACL แบบ LAN IP ด้านล่างเป็นของรุ่นนั้น ใช้เป็นประวัติเท่านั้น
รุ่นปัจจุบัน (ต.ค. 2569): แอป 3.16.0+32 · เฟิร์มแวร์แอร์ IR 2.5.2 · สายแอร์ Daikin 2.5.5-slm8 · เซ็นเซอร์ LD2410 1.3.9
รายละเอียดทุกรุ่นดู RELEASE_NOTES.md และ README.md
============================================================

RMUTT Save Energy 3.3.8+18 — MQTT อัตโนมัติ
================================================

สิ่งที่เปลี่ยน
-------------
- หน้าตั้งค่า ESP32 ไม่มีช่อง MQTT Host, Port, Username และ Password
- เลือกชื่อ Wi-Fi จากรายการที่ ESP32 ตรวจพบ
- พิมพ์เองเฉพาะรหัสผ่าน Wi-Fi
- Backend ส่งค่า MQTT_URL, MQTT_USERNAME และ MQTT_PASSWORD จาก backend/.env
  ให้ ESP32 โดยอัตโนมัติ
- รหัส MQTT ไม่ถูกฝังในโค้ด Flutter และไม่แสดงบนหน้าจอ

ค่าที่ต้องมีใน backend/.env
-------------------------
MQTT_REQUIRED=true
MQTT_URL=mqtt://192.168.1.153:1883
MQTT_USERNAME=<ค่าที่ mqtt/setup_mqtt.ps1 สร้างให้>
MQTT_PASSWORD=<ค่าที่ mqtt/setup_mqtt.ps1 สร้างให้>
MQTT_TOPIC_PREFIX=rmutt/ac

ถ้า IP คอมไม่ใช่ 192.168.1.153 ให้ใช้ IP ที่แสดงจาก ipconfig และรัน
mqtt/setup_mqtt.ps1 ใหม่โดยระบุ -BrokerHost ให้ถูกต้อง

วิธีติดตั้งชุดอัปเดต
------------------
1. วางโฟลเดอร์ cpe_air_remote ทับโปรเจกต์เดิมแล้วเลือก Replace
2. ปิด Backend เดิมด้วย Ctrl+C
3. รัน Backend ใหม่:

   cd backend
   npm install
   npm test
   npm run dev

4. รันแอปใหม่:

   flutter clean
   flutter pub get
   flutter test
   flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api

ไม่ต้อง Migration ฐานข้อมูล และไม่ต้องแฟลช Firmware 1.6.0 ใหม่
