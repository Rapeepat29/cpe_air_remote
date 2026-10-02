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
