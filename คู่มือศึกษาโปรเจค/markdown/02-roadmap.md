# เริ่มจากอะไร และต้องเรียนรู้อะไรบ้าง

## ภาพรวม

โปรเจคนี้มีโค้ดราว 61,000 บรรทัด ใน 6 ภาษา/เทคโนโลยี (Dart, JavaScript, C++, SQL, PowerShell/Bash, HTML/CSS) ถ้าเปิดไฟล์แรกที่เจอแล้วอ่านไปเรื่อย ๆ จะหลงแน่นอน
บทนี้บอก **ลำดับ** ว่าควรเริ่มตรงไหน ต่อด้วยอะไร และต้องมีความรู้พื้นฐานอะไรก่อนเข้าแต่ละส่วน

หลักคิดคือ **อ่านจากภาพใหญ่ลงไปรายละเอียด และตามเส้นทางของข้อมูล** ไม่ใช่อ่านตามโฟลเดอร์

```text
ภาพรวม (บท 1–3) → โครงสร้างพื้นฐาน (เครือข่าย, ฐานข้อมูล) → สมองกลาง (Backend)
   → ภาษาที่ใช้คุยกัน (MQTT/BLE) → ปลายทาง (ESP32, แอป, เว็บ) → การติดตั้งจริง/ความปลอดภัย
```

## ขั้นที่ 0: เตรียมตัว (ครึ่งวัน)

1. เปิดโฟลเดอร์โปรเจคใน **VS Code** (ติดตั้งส่วนเสริม Dart, Flutter, ESLint, Thai language pack ถ้าต้องการ)
2. อ่านไฟล์ `START_HERE.md` ที่รากโปรเจค มันสั้นและบอกว่าระบบมีอะไรบ้าง
3. ดูโครงโฟลเดอร์ระดับบนให้จำได้

```text
cpe_air_remote/
├── lib/          แอป Flutter (Dart)              → บท 10–12
├── test/         เทสต์ของแอป Flutter
├── backend/      เซิร์ฟเวอร์ Node.js + SQL        → บท 5–7
├── webapp/       เว็บแอป HTML/CSS/JS              → บท 13
├── firmware/     โค้ด ESP32 (Arduino C++)         → บท 9
├── mqtt/         Broker สำหรับพัฒนาบนเครื่องตัวเอง → บท 8
├── deploy/       ไฟล์ขึ้นเซิร์ฟเวอร์จริง (Docker)   → บท 4, 14
├── docs/         เอกสารเดิมของโปรเจค (docs/learn, docs/study)
├── คู่มือศึกษาโปรเจค/  คู่มือนี้ (เปิด index.html)
└── *.ps1         สคริปต์ PowerShell ช่วยรัน/สร้างแอป → บท 14
```

## ลำดับการอ่านคู่มือนี้

| ลำดับ | บท | เป้าหมาย | เวลาโดยประมาณ |
|---|---|---|---|
| 1 | แนวคิดและหลักการคิด | ตอบได้ว่าทำไมต้องมีระบบนี้ และทำไมออกแบบแบบนี้ | 1 ชม. |
| 2 | เริ่มจากอะไร (บทนี้) | รู้ว่าต้องเรียนอะไร | 30 นาที |
| 3 | สถาปัตยกรรมและเส้นทางข้อมูล | เห็นภาพการไหลของข้อมูลครบวง | 2 ชม. |
| 4 | เครือข่าย เซิร์ฟเวอร์ และ Tailscale | เข้าใจว่าเซิร์ฟเวอร์อยู่ที่ไหน คนเข้ามาทางไหน | 4 ชม. |
| 5 | ฐานข้อมูล | รู้ว่าข้อมูลเก็บอะไรไว้ที่ไหน | 4 ชม. |
| 6–7 | Backend ตอนที่ 1–2 | เข้าใจ API, ระบบสมาชิก, ตรรกะปิดแอร์, การเก็บค่าไฟ | 1–2 วัน |
| 8 | MQTT และ BLE | เข้าใจ "ภาษา" ที่บอร์ดกับเซิร์ฟเวอร์ใช้คุยกัน | 4 ชม. |
| 9 | เฟิร์มแวร์ ESP32 | เข้าใจฝั่งฮาร์ดแวร์ | 1 วัน |
| 10–12 | แอป Flutter ตอนที่ 1–3 | เข้าใจแอปมือถือ | 1–2 วัน |
| 13 | เว็บแอป | เข้าใจหน้าเว็บ | ครึ่งวัน |
| 14 | การติดตั้งและการทดสอบ | รู้ว่าเอาขึ้นเซิร์ฟเวอร์และทดสอบยังไง | ครึ่งวัน |
| 15 | ความปลอดภัย | ตอบคำถามเรื่องความปลอดภัยได้ | 2 ชม. |
| 16 | เตรียมนำเสนอและคำถามอาจารย์ | ซ้อมตอบ | 2 ชม. |

> [!TIP]
> ถ้าเวลาน้อย (เช่นต้องนำเสนอพรุ่งนี้) ให้อ่านแค่ **บท 1 → 3 → 4 (ส่วน Tailscale) → 7 (ส่วนปิดแอร์อัตโนมัติ) → 16** ก่อน แล้วค่อยกลับมาอ่านส่วนที่เหลือ

## วิธีอ่านโค้ดให้ไม่หลง

1. **ตามเส้นทางข้อมูลหนึ่งเส้นให้จบก่อน** เช่น "กดเปิดแอร์ในแอป" ไล่จาก `lib/widgets/air_control_card.dart` → `lib/services/air_conditioner_service.dart` → `backend/src/routes/air-conditioners.js` → `backend/src/services/mqtt.js` → `firmware/rmutt_esp32_air/rmutt_esp32_air.ino` (บท 3 มีเส้นทางให้แล้ว)
2. **อ่านจุดเริ่มต้นของแต่ละโปรแกรมก่อน**: `lib/main.dart`, `backend/src/server.js`, `webapp/assets/js/main.js`, ฟังก์ชัน `setup()` / `loop()` ในไฟล์ `.ino`
3. **อ่านเทสต์ประกอบ** เทสต์บอกว่าฟังก์ชันควรทำอะไรกับข้อมูลแบบไหน เช่น `backend/test/auto-off.test.js`
4. **รันจริงแล้วลองแก้ทีละนิด** เช่น เปลี่ยนข้อความในหน้าจอ แล้วดูว่าเปลี่ยนตรงไหน
5. **ใช้ค้นหาทั้งโปรเจค** (Ctrl+Shift+F ใน VS Code) หาชื่อฟังก์ชันหรือชื่อ topic เพื่อดูว่าใครเรียกใช้

## ความรู้ที่ต้องศึกษา (แยกตามหมวด)

ระดับความสำคัญ: **★★★ ต้องรู้ก่อนนำเสนอ** · **★★ ควรรู้** · **★ รู้ไว้ช่วยตอบคำถามเชิงลึก**

### พื้นฐานคอมพิวเตอร์และการเขียนโปรแกรม

| หัวข้อ | ระดับ | ใช้ตรงไหน |
|---|---|---|
| ตัวแปร, ฟังก์ชัน, if/loop, object/class | ★★★ | ทุกส่วน |
| JSON (รูปแบบข้อมูลแบบ `{ "key": value }`) | ★★★ | API, MQTT, BLE ทั้งหมดส่งข้อมูลเป็น JSON |
| การทำงานแบบ asynchronous (`async`/`await`, Promise/Future) | ★★★ | Backend, แอป, เว็บ |
| Command line / Terminal / PowerShell | ★★ | รันสคริปต์ทุกตัว |
| Git และ `.gitignore` | ★★ | เก็บโค้ด ไม่ให้ secret หลุด |

### เครือข่าย (บท 4)

| หัวข้อ | ระดับ | ใช้ตรงไหน |
|---|---|---|
| IP address, IP ส่วนตัว/สาธารณะ, LAN, NAT | ★★★ | เหตุผลที่ต้องใช้ Tailscale |
| Port และพอร์ตที่โปรเจคใช้ (22, 80, 443, 1883, 8443, 8883, 3000, 3306, 8080) | ★★★ | docker-compose, firewall |
| DNS และโดเมน | ★★★ | DuckDNS, ts.net |
| HTTP vs HTTPS, TLS, ใบรับรอง (certificate), CA, Let's Encrypt | ★★★ | Caddy, MQTTS, ESP32 |
| Reverse proxy | ★★ | Caddy ส่ง `/api` ไป Backend |
| VPN / Tailscale / Funnel | ★★★ | ทางเข้าจากอินเทอร์เน็ต |
| Firewall, SSH, SSH tunnel | ★★ | ดูแลเซิร์ฟเวอร์, เปิดดูฐานข้อมูล |
| DNS-01 vs HTTP-01 challenge | ★ | ขอใบรับรองตอนเซิร์ฟเวอร์อยู่หลัง firewall |

### เซิร์ฟเวอร์และการ deploy (บท 4, 14)

| หัวข้อ | ระดับ | ใช้ตรงไหน |
|---|---|---|
| Docker: image, container, volume, network | ★★★ | `deploy/docker-compose.yml` |
| docker compose (`up`, `ps`, `logs`, `exec`) | ★★ | ดูแลระบบ |
| Linux/Ubuntu พื้นฐาน, sudo, cron | ★★ | `setup-vps.sh`, สำรองข้อมูลรายวัน |
| Environment variables และไฟล์ `.env` | ★★★ | ค่าตั้งและ secret ทั้งหมด |
| Healthcheck และ monitoring | ★ | `/api/health` |

### ฐานข้อมูล (บท 5)

| หัวข้อ | ระดับ | ใช้ตรงไหน |
|---|---|---|
| ตาราง แถว คอลัมน์ ชนิดข้อมูล | ★★★ | `backend/database/schema.sql` |
| PRIMARY KEY, FOREIGN KEY, UNIQUE, INDEX | ★★★ | ทุกตาราง |
| SQL: SELECT / INSERT / UPDATE / DELETE / JOIN / GROUP BY | ★★★ | routes และ services ของ Backend |
| Transaction และการล็อกแถว | ★★ | จัดการผู้ใช้, บันทึกค่าไฟ |
| SQL injection และ parameterized query | ★★★ | `db.js` และทุก query |
| Migration | ★★ | `backend/scripts/migrate-*.js` |

### Backend (บท 6–7)

| หัวข้อ | ระดับ | ใช้ตรงไหน |
|---|---|---|
| Node.js, npm, `package.json` | ★★★ | `backend/` |
| ES Modules (`import` / `export`) | ★★ | ทุกไฟล์ |
| HTTP method, status code, REST API | ★★★ | `backend/src/routes/` |
| Express: router, middleware, error handler | ★★★ | `app.js`, `middleware/` |
| JWT (token เข้าสู่ระบบ) | ★★★ | `middleware/authenticate.js`, `routes/auth.js` |
| Hash รหัสผ่าน (bcrypt), OTP, pepper | ★★ | ระบบลืมรหัสผ่าน |
| Rate limiting, CORS, security headers | ★★ | `app.js`, `routes/auth.js` |
| Timer/งานเบื้องหลัง (`setInterval`) | ★★ | `services/auto-off.js` |
| State machine และ pure function | ★★★ | ตรรกะปิดแอร์ `utils/auto-off.js` |
| Unit test (`node --test`) | ★★ | `backend/test/` |

### MQTT และ Bluetooth (บท 8)

| หัวข้อ | ระดับ | ใช้ตรงไหน |
|---|---|---|
| Publish/Subscribe, Broker, Topic, wildcard `+` `#` | ★★★ | การคุยระหว่าง Backend กับบอร์ด |
| QoS, retained message, Last Will | ★★★ | สถานะออนไลน์/ออฟไลน์ของบอร์ด |
| Mosquitto + Dynamic Security (บัญชีและสิทธิ์รายบอร์ด) | ★★ | `mosquitto.conf`, `services/mqtt-accounts.js` |
| BLE: advertising, GATT, service, characteristic, UUID | ★★★ | การตั้งค่าบอร์ดครั้งแรก |
| MTU และการแบ่งข้อมูลเป็นชิ้น (chunk) | ★ | ส่งค่าตั้งยาว ๆ ผ่าน BLE |

### ฮาร์ดแวร์และเฟิร์มแวร์ (บท 9)

| หัวข้อ | ระดับ | ใช้ตรงไหน |
|---|---|---|
| ESP32 คืออะไร (Wi-Fi + BLE + หลาย UART) | ★★★ | ทั้งสองบอร์ด |
| Arduino: `setup()`, `loop()`, `millis()` แทน `delay()` | ★★★ | ไฟล์ `.ino` |
| GPIO, UART/Serial | ★★ | ต่อ PZEM, LD2410 |
| รีโมตอินฟราเรด (IR 38 kHz) | ★★ | ยิงคำสั่งแอร์, `SaijoDenkiAC.cpp` |
| PZEM-004T วัดแรงดัน/กระแส/กำลัง/พลังงาน | ★★★ | วัดค่าไฟ |
| HLK-LD2410 เรดาร์ mmWave ตรวจคน | ★★★ | บอร์ดตรวจจับคน |
| Hysteresis / debounce | ★★ | ตัดสินว่าแอร์ทำงานจริงไหม |
| NVS, partition table, OTA | ★★ | จำค่าตั้ง, อัปเดตเฟิร์มแวร์ผ่าน Wi-Fi |

### แอปมือถือ (บท 10–12)

| หัวข้อ | ระดับ | ใช้ตรงไหน |
|---|---|---|
| ภาษา Dart: class, null safety (`?`, `!`, `??`), `final`/`const` | ★★★ | `lib/` ทั้งหมด |
| Flutter: Widget, StatelessWidget/StatefulWidget, `build()` | ★★★ | `lib/screens/`, `lib/widgets/` |
| State management ด้วย `ChangeNotifier` | ★★★ | `lib/controllers/` |
| เรียก HTTP และแปลง JSON เป็น object (`fromJson`) | ★★★ | `lib/services/`, `lib/models/` |
| Repository pattern | ★★ | `*_repository.dart` |
| `flutter_blue_plus` และสิทธิ์ Android | ★★ | หน้าตั้งค่าบอร์ด |
| `--dart-define` | ★ | สลับเซิร์ฟเวอร์ตอน build |

### เว็บ (บท 13)

| หัวข้อ | ระดับ | ใช้ตรงไหน |
|---|---|---|
| HTML, CSS (flex/grid, ตัวแปร CSS), JavaScript DOM | ★★★ | `webapp/` |
| `fetch`, `localStorage`, ES modules ในเบราว์เซอร์ | ★★ | `api.js`, `config.js` |
| Single Page App และการสลับหน้าด้วย hash | ★★ | `app.js` |
| XSS และ Content-Security-Policy | ★★ | `dom.js`, `Caddyfile` |

## แหล่งเรียนรู้แนะนำ (เอกสารทางการ)

| เรื่อง | แหล่ง |
|---|---|
| HTML/CSS/JavaScript | developer.mozilla.org (MDN) |
| Node.js / Express | nodejs.org/docs, expressjs.com |
| MariaDB / SQL | mariadb.com/kb |
| Dart / Flutter | dart.dev, docs.flutter.dev |
| MQTT / Mosquitto | mqtt.org, mosquitto.org/documentation |
| ESP32 / Arduino | docs.espressif.com, docs.arduino.cc |
| Docker | docs.docker.com |
| Caddy | caddyserver.com/docs |
| Tailscale (Funnel, Serve) | tailscale.com/kb |
| Let's Encrypt | letsencrypt.org/docs |

เอกสารเดิมในโปรเจค `docs/learn/` (18 บท) สอนพื้นฐานแต่ละเทคโนโลยีไว้แล้ว ใช้เสริมคู่มือนี้ได้ ส่วน `docs/study/` (9 บท) เป็นบันทึกสั้นแยกตามส่วน ทั้งสองชุดปรับเลขรุ่น บอร์ดสายแอร์ Daikin จอ OLED และหน้าเฟิร์มแวร์บนเว็บแล้ว (14 ต.ค. 2569) แต่บางหัวข้อยังเขียนตามแผนเดิม (เช่นการเปิดพอร์ต 80/443 ใน `docs/learn/14`) ถ้าขัดกันให้เชื่อโค้ดและคู่มือนี้

## แบบฝึกหัดลงมือทำ (แนะนำมาก)

การได้รันระบบจริงช่วยให้เข้าใจเร็วกว่าอ่านอย่างเดียวหลายเท่า

1. **รันระบบบนเครื่องตัวเอง** ด้วย `run_all.ps1` (ต้องมี Docker Desktop, Node.js, Flutter) แล้วเปิด `http://127.0.0.1:3000/api/health` ดูผล
2. **ลองเรียก API** ล็อกอินด้วย `curl` หรือ Postman ที่ `POST /api/auth/login` ได้ token แล้วใช้เรียก `GET /api/rooms`
3. **ดูข้อความ MQTT สด ๆ** ใช้ `mosquitto_sub -t 'rmutt/#' -v` (ผ่าน `mqtt/test_mqtt.ps1` หรือ `docker exec`) แล้วกดคำสั่งในแอป ดูว่ามีข้อความอะไรวิ่ง
4. **เปิดฐานข้อมูล** ด้วย HeidiSQL/DBeaver แล้วลองรัน SQL ตัวอย่างในบทฐานข้อมูล
5. **รันเทสต์** `cd backend; npm test` และ `flutter test` อ่านชื่อเทสต์ที่ผ่าน
6. **แก้ค่าเล็ก ๆ** เช่นเวลานับถอยหลังใน `backend/src/utils/auto-off.js` แล้วดูว่าเทสต์ไหนพัง (เข้าใจว่าเทสต์ปกป้องอะไร) แล้วแก้กลับ
7. **วาดแผนภาพเอง** บนกระดาษ: ระบบทั้งหมด + เส้นทางคำสั่ง "เปิดแอร์" ถ้าวาดได้โดยไม่ดู แปลว่าเข้าใจจริง

## แผนเรียน 2 สัปดาห์ (ตัวอย่าง)

| วัน | เรียนอะไร | ผลลัพธ์ที่ควรได้ |
|---|---|---|
| 1 | บท 1–3 + รัน `run_all.ps1` | เล่าโปรเจคได้ 2 นาที, ระบบรันบนเครื่อง |
| 2 | บท 4 เครือข่าย + Tailscale | อธิบายทางเข้า 3 ทางของเซิร์ฟเวอร์ได้ |
| 3 | บท 5 ฐานข้อมูล | วาดความสัมพันธ์ตารางได้ รัน SQL ได้ |
| 4–5 | บท 6 Backend ตอนที่ 1 | อธิบายการล็อกอินและ JWT ได้ ลองเรียก API ได้ |
| 6 | บท 7 Backend ตอนที่ 2 | อธิบาย auto-off และถังค่าไฟรายชั่วโมงได้ |
| 7 | บท 8 MQTT/BLE + แบบฝึกหัด mosquitto_sub | บอก topic หลักได้ เล่าขั้นตอน provisioning ได้ |
| 8 | บท 9 เฟิร์มแวร์ | อธิบาย `loop()` และเกณฑ์แอร์ทำงานได้ |
| 9–10 | บท 10–12 Flutter | อธิบายชั้น model/service/controller/screen ได้ |
| 11 | บท 13 เว็บแอป | อธิบายว่าเว็บเรียก API อย่างไร |
| 12 | บท 14–15 | อธิบายการ deploy และความปลอดภัยได้ |
| 13 | บท 16 ซ้อมตอบคำถาม | ตอบคำถามท้ายบทได้ทุกข้อ |
| 14 | ทบทวน + ซ้อมนำเสนอจริง | พร้อมนำเสนอ |

## สรุปและเช็กลิสต์ความเข้าใจ

- [ ] รู้ว่าแต่ละโฟลเดอร์ระดับบนคือส่วนไหนของระบบ
- [ ] รู้ลำดับการอ่าน และรู้ว่าถ้าเวลาน้อยควรอ่านบทไหนก่อน
- [ ] รู้ว่าแต่ละส่วนต้องมีความรู้พื้นฐานอะไร และตัวเองยังขาดอะไร
- [ ] รันระบบบนเครื่องตัวเองได้อย่างน้อยหนึ่งครั้ง
