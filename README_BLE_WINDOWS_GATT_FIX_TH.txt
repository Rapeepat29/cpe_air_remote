RMUTT Save Energy - แก้ Windows BLE เชื่อมได้แต่ค้นหา Service ไม่จบ
================================================================

เวอร์ชัน
-------
- Flutter app 3.3.7+17
- ESP32 firmware ใช้ 1.6.0 เดิม ไม่ต้องแฟลชใหม่

สาเหตุ
------
ชุด 3.3.6+16 ใช้ autoConnect แล้วเรียก discoverServices ทันที บน Windows
ตัวเชื่อม WinRT มีการค้นหา GATT ภายใน connect อยู่แล้ว จึงเกิดการค้นหาซ้อนกัน
จากนั้นแอปตัดและเชื่อมใหม่อย่างรวดเร็ว 3 รอบ ทำให้หน้าตั้งค่าไม่เปิด

สิ่งที่แก้
---------
- เปลี่ยนกลับเป็นการเชื่อมต่อปกติและรอ connect ให้เสร็จ
- เพิ่มเวลารอขั้น connect เป็น 45 วินาทีสำหรับ Windows
- ค้นหา Service ซ้ำบนการเชื่อมต่อเดิม ไม่ตัด/ต่อบอร์ดทุกครั้ง
- เว้นช่วงให้ WinRT และ GATT พร้อมก่อนอ่าน Service
- แสดง error จริงของขั้น connect หรือ service discovery บนหน้าจอ
- ล็อก flutter_blue_plus_winrt 0.0.20 ซึ่งมีการแก้ connection stability

วิธีใช้
------
1. ใช้โฟลเดอร์ cpe_air_remote ใน ZIP นี้แทนชุดเดิม
2. ไม่ต้องแฟลช ESP32 ซ้ำ หาก Serial Monitor แสดง Firmware 1.6.0 แล้ว
3. ปิดแอป Flutter เดิมทุกหน้าต่าง
4. เปิด PowerShell ในโฟลเดอร์ cpe_air_remote แล้วรัน:

   flutter clean
   flutter pub get
   flutter pub deps | findstr flutter_blue_plus_winrt
   flutter test
   flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000/api --dart-define=MQTT_DEFAULT_HOST=192.168.1.153

5. ผลจากคำสั่ง flutter pub deps ต้องมี flutter_blue_plus_winrt 0.0.20
6. เข้า ห้อง 16101 > เพิ่มแอร์ > ค้นหาบลูทูธ
7. เลือก RMUTT-AC-705F1971FE68 เพียงครั้งเดียว แล้วรอจนแสดง Device ID

ถ้ายังไม่สำเร็จ
--------------
ให้ส่งภาพข้อความสีแดงรอบใหม่มา ข้อความในเวอร์ชันนี้จะระบุชัดว่าเสียที่
connection stage หรือ service discovery พร้อม error จริงจาก Windows
จึงไม่ต้องเดาจากข้อความรวมเหมือนเวอร์ชันก่อน
