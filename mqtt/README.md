# Mosquitto MQTT Broker

โฟลเดอร์นี้เป็น MQTT Broker ที่ Backend และ ESP32 ใช้ร่วมกัน โดยรัน
Eclipse Mosquitto 2 ผ่าน Docker Compose

## ตั้งค่าครั้งแรกบน Windows

ต้องติดตั้งและเปิด Docker Desktop ก่อน จากนั้นเปิด PowerShell ในโฟลเดอร์นี้:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup_mqtt.ps1
```

สคริปต์จะ:

1. หา LAN IPv4 ของคอมพิวเตอร์
2. สร้างรหัสผ่าน MQTT แบบสุ่ม
3. สร้าง Mosquitto password file และ ACL
4. อัปเดตค่า MQTT ใน `backend/.env` โดยไม่ลบค่าฐานข้อมูลหรือ SMTP เดิม
5. เปิด Broker และทดสอบ Publish/Subscribe

ถ้าสคริปต์เลือก IP ผิด ให้ระบุ IP เอง:

```powershell
.\setup_mqtt.ps1 -BrokerHost 192.168.1.10
```

ค่า MQTT ใน `mqtt/.env` จะถูกใส่ใน `backend/.env` โดยสคริปต์ และ Backend
จะส่งค่าเหล่านี้ให้ ESP32 อัตโนมัติ ผู้ใช้ไม่ต้องกรอก MQTT ในแอป

ACL ที่สคริปต์สร้างอนุญาตทั้ง `rmutt/ac/#` สำหรับบอร์ดควบคุมแอร์ และ
`rmutt/occupancy/#` สำหรับ ESP32 + LD2410 ประจำห้อง

หาก Broker ถูกตั้งค่าด้วยโปรเจกต์เวอร์ชันเก่าแล้ว ไม่ต้องรัน Setup ซ้ำเพราะ
จะทำให้รหัสผ่าน MQTT เปลี่ยน ให้เปิด `mqtt/config/acl` แล้วเพิ่มบรรทัดนี้ใต้
สิทธิ์ของผู้ใช้เดิม จากนั้น Restart Broker:

```text
topic readwrite rmutt/occupancy/#
```

```powershell
docker compose --env-file .env restart broker
```

## คำสั่งใช้งาน

```powershell
.\start_mqtt.ps1
.\test_mqtt.ps1
.\stop_mqtt.ps1
```

ดู Log:

```powershell
docker compose --env-file .env logs -f broker
```

หาก ESP32 อยู่ Wi-Fi เดียวกันแต่ต่อพอร์ต 1883 ไม่ได้ ให้เปิด Windows Firewall
เฉพาะเครือข่าย Private:

```powershell
New-NetFirewallRule -DisplayName "RMUTT MQTT 1883" `
  -Direction Inbound -Action Allow -Protocol TCP -LocalPort 1883 `
  -Profile Private
```

ข้อมูลถาวรอยู่ใน `data/` และ Log อยู่ใน `log/` ส่วน `.env`, password file
และ ACL ถูกกันออกจาก Git และ ZIP สำหรับแจกจ่าย
