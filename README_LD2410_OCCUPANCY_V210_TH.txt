คู่มืออัปเกรด ESP32 + HLK-LD2410 ตรวจคนในห้อง (App 3.6.0+23)
================================================================

สรุปการทำงาน
-------------

ระบบใช้ ESP32 + HLK-LD2410 แยกอีกหนึ่งชุดต่อหนึ่งห้อง ไม่ใช่บอร์ดตัวเดียว
กับ ESP32 ที่ควบคุมเครื่องปรับอากาศ

Firmware จะเปิด Engineering mode ทุกครั้งหลังบูต แล้วอ่านเฉพาะค่า
Static/Stationary target energy ของเกต 0 ถึง 8 เท่านั้น

  มีเกตใดเกตหนึ่ง > 25   = มีคนอยู่ภายในห้อง
  ทุกเกตมีค่า <= 25      = ไม่มีคนอยู่ภายในห้อง

ค่าเท่ากับ 25 จัดเป็น “ไม่มีคน” เพราะเงื่อนไขเป็นมากกว่า 25 เท่านั้น
Moving target, ระยะเป้าหมาย, Detection range และค่าอื่นทั้งหมดไม่ถูกนำมาใช้
และไม่ถูกส่งไปยังแอป

ไฟล์ที่เกี่ยวข้อง
-----------------

Firmware:
  firmware/rmutt_esp32_occupancy/rmutt_esp32_occupancy.ino

Migration:
  backend/scripts/migrate-occupancy-v210.js

Protocol:
  docs/BLE_MQTT_PROTOCOL.md

1. ต่อฮาร์ดแวร์แรงดันต่ำ
-----------------------

  LD2410C VCC -> ESP32 5V/VIN
  LD2410C GND -> ESP32 GND
  LD2410C TX  -> ESP32 GPIO32 (UART RX)
  LD2410C RX  -> ESP32 GPIO33 (UART TX)
  LD2410C OUT -> ไม่ต้องต่อ ปล่อยลอยไว้
  GPIO0       -> ปุ่ม BOOT/เข้าโหมดตั้งค่า

โมดูล LD2410C มี 5 ขา แต่ระบบนี้ใช้แค่ 4 ขา ขา OUT เป็นขาที่โมดูลตัดสินใจ
เรื่องมีคน/ไม่มีคนเองตามค่าโรงงาน ระบบไม่ได้ใช้เพราะเราตัดสินจากค่าพลังงาน
รายเกตที่อ่านผ่าน UART (เกตใดเกตหนึ่ง > 25) ปล่อยขา OUT ลอยไว้ได้ปลอดภัย
เพราะเป็นขาขาออกของโมดูล ไม่ส่งผลต่อ UART หรือ ESP32 แต่ห้ามต่อ OUT เข้ากับ
5V หรือ GND เด็ดขาด

ตรวจฉลากแรงดันของโมดูลรุ่นที่มีอยู่จริงก่อนจ่ายไฟ ใช้แหล่งจ่าย USB แรงดันต่ำ
ที่เสถียร ปิดไฟก่อนต่อหรือย้ายสาย และอย่านำวงจรชุดนี้ไปต่อไฟบ้าน

2. อัปโหลด Firmware
--------------------

ใน Arduino IDE ติดตั้ง:

  - ESP32 board package
  - ArduinoJson 6.x
  - PubSubClient
  - ld2410 by Nick Reynolds เวอร์ชัน 0.2.2 หรือใหม่กว่า

ต้องใช้ ld2410 0.2.2 ขึ้นไป เพราะ Firmware เรียก Engineering-mode API เพื่อ
อ่าน stationaryEnergyAtGate() และจะขอเปิด Engineering mode ใหม่ทุกครั้งที่
เปิดบอร์ด

เปิด rmutt_esp32_occupancy.ino เลือกบอร์ด/พอร์ตให้ถูก แล้ว Upload
เมื่ออยู่ Setup mode ชื่อ Bluetooth จะเป็น:

  RMUTT-OCC-XXXXXXXXXXXX

และ Device ID จะเป็น:

  OCC32-XXXXXXXXXXXX

3. อัปเกรดฐานข้อมูลและ Backend
------------------------------

สำรองฐานข้อมูลก่อนอัปเกรด แล้วเปิด PowerShell ในโฟลเดอร์ backend:

  npm install
  npm run db:migrate:occupancy
  npm test
  npm start

Migration สร้างตาราง occupancy_sensors และบังคับหนึ่งเซ็นเซอร์ต่อหนึ่งห้อง
โดยไม่ลบข้อมูลห้อง แอร์ ตารางเรียน หรือผู้ใช้เดิม

ตรวจ backend/.env ให้มี:

  MQTT_OCCUPANCY_TOPIC_PREFIX=rmutt/occupancy

4. อนุญาต MQTT Topic
---------------------

ถ้าตั้ง Broker ใหม่ด้วย setup_mqtt.ps1 รุ่นนี้ สคริปต์จะเพิ่มสิทธิ์ให้แล้ว

ถ้าใช้ Broker เดิม ห้ามรัน Setup ซ้ำโดยไม่จำเป็น เพราะรหัสผ่าน MQTT อาจเปลี่ยน
ให้เพิ่มบรรทัดต่อไปนี้ใน mqtt/config/acl ใต้สิทธิ์ของ user เดิม:

  topic readwrite rmutt/occupancy/#

จากโฟลเดอร์ mqtt ให้ Restart Broker:

  docker compose --env-file .env restart broker

5. ตั้งค่าจากแอป
----------------

1) เข้าสู่ระบบด้วย Admin
2) เปิดห้องที่ติดตั้งเซ็นเซอร์
3) เลือก “เพิ่มเซ็นเซอร์ตรวจจับคน”
4) เลือกบอร์ด RMUTT-OCC- ที่ตรงกับ Device ID
5) เลือก Wi-Fi ที่บอร์ดสแกนพบและกรอกรหัสผ่าน Wi-Fi
6) กดบันทึก Backend จะส่ง MQTT Host/User/Password และ Token แบบใช้ครั้งเดียว
   ให้บอร์ดผ่าน BLE
7) บอร์ด Restart, เชื่อม Wi-Fi/MQTT และเริ่มส่งสถานะห้อง

เมื่อต้องตั้งค่าใหม่ ให้กด BOOT ค้างขณะ Reset แล้วเลือกตั้งค่าใหม่ในแอป
ระบบจะยอมให้บอร์ดเดิมกลับเข้าห้องเดิมเท่านั้น เพื่อป้องกัน Device ID ซ้ำ

6. สถานะที่แอปแสดง
-------------------

  มีคน              = radar พร้อม และมีอย่างน้อยหนึ่งเกต > 25
  ไม่มีคน            = radar พร้อม และทุกเกต <= 25
  เซ็นเซอร์ไม่พร้อม  = ESP32 offline หรือ LD2410 อ่านไม่ได้
  ยังไม่มีเซ็นเซอร์  = ห้องยังไม่ได้ผูกกับ occupancy sensor

แอป Refresh สถานะทุก 10 วินาที ส่วน ESP32 ส่งทันทีเมื่อผลมีคน/ไม่มีคนเปลี่ยน
และส่งยืนยันซ้ำอย่างน้อยทุก 10 วินาที

7. MQTT Payload ที่ส่งจริง
-------------------------

Topic:
  rmutt/occupancy/OCC32-XXXXXXXXXXXX/status

ตัวอย่าง:
  {"online":true,"deviceId":"OCC32-AABBCCDDEEFF","roomNumber":"16203",
   "radarAvailable":true,"occupied":true,"staticThreshold":25}

ไม่มีข้อมูล Moving target, ระยะ หรืออาร์เรย์ค่าดิบของแต่ละเกตใน Payload

ข้อควรตรวจหากแอปขึ้น “เซ็นเซอร์ไม่พร้อม”
-------------------------------------------

- ตรวจว่า ESP32 และ Server ออก Internet/เข้าถึง MQTT Broker ได้
- ตรวจ MQTT_URL ใน backend/.env ว่าเป็น IP/โดเมนที่บอร์ดเข้าถึงได้
- ตรวจ ACL ว่ามี rmutt/occupancy/#
- ตรวจสาย TX/RX ว่าสลับทิศถูกต้องและมี GND ร่วมกัน
- ตรวจ Serial Monitor ว่าพบ LD2410 และเปิด Engineering mode สำเร็จ
- ตรวจว่าใช้ไลบรารี ld2410 เวอร์ชัน 0.2.2 ขึ้นไป
