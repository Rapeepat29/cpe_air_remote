# Backend ตอนที่ 1: โครงหลัก ระบบสมาชิก และ REST API

## ภาพรวม

Backend ของ RMUTT Save Energy คือโปรแกรม Node.js ตัวเดียว (โฟลเดอร์ `backend/`) ที่ทำหน้าที่เป็น "สมองกลาง" ของระบบ มันเปิดพอร์ต HTTP (ค่าเริ่มต้น 3000) ให้แอป Flutter และเว็บแอปเรียกใช้ ผ่านรูปแบบ **REST API** แลกเปลี่ยนข้อมูลเป็น JSON ด้านหลังมันคุยกับ MariaDB (เก็บผู้ใช้ ห้อง ตารางเรียน ข้อมูลไฟฟ้า) และคุยกับ Mosquitto ผ่าน MQTT เพื่อสั่งแอร์และรับค่าจาก ESP32

บทนี้ครอบคลุม "ชั้นหน้า" ของ Backend คือส่วนที่รับคำขอ HTTP: ลำดับการเริ่มโปรแกรม (`server.js`, `app.js`), การอ่านค่าตั้ง (`config.js`), ระบบสมาชิก (login, JWT, OTP ลืมรหัสผ่าน), middleware, และไฟล์ route ทั้ง 12 ไฟล์ที่นิยาม endpoint ทั้งหมด ส่วน "ชั้นหลัง" เช่น `services/mqtt.js`, `services/auto-off.js`, `utils/energy-history.js` อยู่ในบท "Backend ตอนที่ 2" บทนี้จะบอกแค่ว่า route เรียกอะไรต่อ

โครงคิดของ Backend มี 3 ชั้นซ้อนกัน เพื่อให้แต่ละชั้นทดสอบและแก้ไขแยกกันได้

| ชั้น | โฟลเดอร์ | หน้าที่ |
|---|---|---|
| route | `src/routes/` | รับ request ตรวจสิทธิ์ เรียก SQL แล้วตอบ response |
| service | `src/services/` | งานที่มีสถานะหรือต่อระบบนอก (MQTT, อีเมล, timer ปิดแอร์) |
| util | `src/utils/` | ฟังก์ชัน pure: ตรวจ input แปลงข้อมูล คำนวณ ไม่แตะ DB/เครือข่าย |

## ความรู้ที่ต้องมีก่อนอ่านบทนี้

### Backend และ API
**Backend** คือโปรแกรมฝั่งเซิร์ฟเวอร์ที่ผู้ใช้ไม่เห็นหน้าจอ แต่เป็นคนเก็บข้อมูลและตัดสินใจ **API** (Application Programming Interface) คือ "ช่องทางที่โปรแกรมอื่นเรียกใช้" ในที่นี้คือ URL เช่น `GET /api/rooms` แอปมือถือไม่ต่อฐานข้อมูลตรง ๆ เพราะจะต้องฝังรหัสผ่านฐานข้อมูลไว้ในแอป (ใครแกะแอปก็ได้ไป) และตรวจสิทธิ์ไม่ได้ จึงให้ Backend เป็นด่านเดียวที่เข้าถึงข้อมูล

### HTTP method และ status code
Method บอก "ต้องการทำอะไร" กับทรัพยากร:

| Method | ความหมาย | ตัวอย่างในโปรเจค |
|---|---|---|
| GET | อ่านข้อมูล ไม่เปลี่ยนอะไร | `GET /api/rooms` |
| POST | สร้างใหม่ หรือสั่งให้ทำอะไรบางอย่าง | `POST /api/auth/login`, `POST /api/rooms` |
| PUT | แทนที่ข้อมูลทั้งชุด | `PUT /api/rooms/:roomNumber` |
| PATCH | แก้บางฟิลด์ | `PATCH /api/users/:username` |
| DELETE | ลบ | `DELETE /api/schedules/:id` |

Status code บอกผลลัพธ์ ที่โค้ดนี้ใช้จริง:

| รหัส | ความหมาย | ใช้เมื่อ |
|---|---|---|
| 200 | สำเร็จ | อ่าน/แก้สำเร็จ |
| 201 | สร้างสำเร็จ | `POST` เพิ่มห้อง เพิ่มผู้ใช้ |
| 202 | รับคำสั่งแล้ว แต่ยังไม่เสร็จ | สั่งแอร์ผ่าน MQTT (ส่งคำสั่งออกไปแล้ว ยังไม่รู้ว่าแอร์ทำตามหรือยัง) |
| 204 | สำเร็จ ไม่มีเนื้อหาตอบกลับ | `DELETE` สำเร็จ |
| 400 | ข้อมูลที่ส่งมาไม่ถูกต้อง | validation ไม่ผ่าน |
| 401 | ยังไม่ได้ยืนยันตัวตน | ไม่มี/token เสีย/รหัสผ่านผิด |
| 403 | ยืนยันตัวตนแล้วแต่ไม่มีสิทธิ์ | staff เรียก endpoint ของ admin |
| 404 | ไม่พบ | ไม่มีห้อง/ไม่มี endpoint |
| 409 | ขัดแย้งกับข้อมูลเดิม | ห้องซ้ำ คาบเรียนซ้อน ลบแอดมินคนสุดท้าย |
| 413 | ข้อมูลที่ส่งมาใหญ่เกิน | body เกิน 256 KB |
| 429 | เรียกถี่เกินไป | ติด rate limit |
| 500 | เซิร์ฟเวอร์พังเอง | ข้อผิดพลาดที่ไม่คาดคิด |
| 503 | บริการที่พึ่งพายังไม่พร้อม | Backend ยังไม่ต่อ MQTT Broker |

หลักคือ 4xx = ความผิดของผู้เรียก 5xx = ความผิดของเซิร์ฟเวอร์ แอปใช้รหัสนี้แยกว่าจะแสดงข้อความอะไร

### JSON และ REST
**JSON** คือรูปแบบข้อความที่เก็บข้อมูลแบบ `{"ชื่อ": ค่า}` อ่านได้ทั้งคนและเครื่อง ทุก endpoint ของโปรเจคนี้รับและตอบเป็น JSON (ยกเว้นส่งออก Excel และอัปโหลดไฟล์ตารางเรียน) **REST** คือแนวออกแบบ API ที่ใช้ URL เป็น "ชื่อสิ่งของ" (`/api/rooms/16203`) และใช้ method เป็น "กริยา" ไม่ใส่กริยาใน URL (ไม่ทำ `/api/deleteRoom`) และไม่เก็บสถานะผู้ใช้ไว้ที่เซิร์ฟเวอร์ ทุก request ต้องพกหลักฐานตัวตน (token) มาเองทุกครั้ง

### Node.js และ event loop
Node.js คือตัวรันภาษา JavaScript นอกเบราว์เซอร์ ทำงานแบบ **single thread + event loop**: มีเธรดหลักเดียว แต่เมื่อเจองานรอ (ถามฐานข้อมูล รอเครือข่าย) มันไม่ยืนรอ แต่ฝากงานไว้แล้วไปรับ request อื่นต่อ พอผลกลับมา event loop ค่อยหยิบ callback มาทำ ข้อดีคือรับ request พร้อมกันได้เยอะโดยใช้ RAM น้อย ข้อเสียคือถ้ามีงานคำนวณหนัก ๆ ที่ไม่ยอมคืนเธรด ทุก request จะค้าง นี่คือเหตุผลที่การคำนวณ bcrypt ใช้ไลบรารีที่แบ่งงาน (และเลือก cost 12 ไม่สูงกว่านั้น)

### async/await และ Promise
งานที่ต้องรอส่งค่ากลับเป็น **Promise** (สัญญาว่าจะมีผลทีหลัง) `await` คือ "รอ Promise นี้เสร็จก่อนค่อยทำบรรทัดถัดไป" แต่ไม่บล็อกเธรด ฟังก์ชันที่ใช้ `await` ได้ต้องประกาศ `async` ถ้า Promise ล้มเหลว `await` จะ throw error ออกมา จึงใช้ `try/catch` จับได้เหมือนโค้ดปกติ

### ES modules
`package.json` มี `"type": "module"` จึงใช้ `import ... from '...'` และ `export` แทน `require()` แบบเก่า ข้อควรรู้: ต้องเขียนนามสกุล `.js` ตอน import ไฟล์ของเราเอง (`'./app.js'`), `import` ถูกยกขึ้นไปทำก่อนโค้ดอื่นในไฟล์เสมอ (hoisting) และ `await` ระดับบนสุดของไฟล์ทำได้ (ได้ใช้ในไฟล์ test)

### npm และ package.json
`npm` คือตัวจัดการแพ็กเกจของ Node `package.json` คือ "บัตรประจำตัวโปรเจค" บอกชื่อ เวอร์ชัน สคริปต์ที่สั่งด้วย `npm run <ชื่อ>` และรายการ `dependencies` ที่ต้องติดตั้ง เครื่องหมาย `^3.0.2` หมายถึงยอมรับเวอร์ชัน 3.x.x ที่ใหม่กว่า แต่ไม่ข้ามไป 4.0.0 (เพราะเลขหลักเปลี่ยน = อาจแตกหัก)

### Express
Express คือเฟรมเวิร์กเว็บของ Node หัวใจคือ **middleware chain**: request วิ่งผ่านฟังก์ชันเรียงกันไป แต่ละตัวมีรูป `(request, response, next)` จะทำอะไรสักอย่างแล้วเรียก `next()` เพื่อส่งต่อ หรือตอบกลับเองเพื่อจบ ถ้าเรียก `next(error)` หรือ throw มันจะข้ามไปหา **error handler** (ฟังก์ชันที่รับ 4 พารามิเตอร์ `(error, request, response, next)`) `Router` คือกลุ่มของ route ที่แยกเป็นไฟล์ แล้วนำไปติดที่ prefix ด้วย `app.use('/api/rooms', roomsRouter)`

**Express 5 กับ async error:** โปรเจคใช้ Express `^5.1.0` ซึ่ง handler ที่เป็น `async` ถ้า Promise ถูก reject จะถูกส่งเข้า error handler เองอัตโนมัติ (Express 4 ไม่ทำ ต้องห่อเอง) โค้ดนี้ยังห่อด้วย `asyncHandler` ทุก route อยู่ ซึ่งไม่เสียหาย เป็นการกันไว้ให้โค้ดทำงานเหมือนเดิมแม้ถอยกลับไปใช้ Express 4 และเห็นรูปแบบเดียวกันทุกไฟล์

### Environment variable
ค่าตั้งที่ต่างกันตามเครื่อง (รหัสผ่าน DB, secret) ไม่ควรเขียนฝังในโค้ด เพราะโค้ดขึ้น Git จึงเก็บในไฟล์ `.env` (ไม่ขึ้น Git ดู `.gitignore`) แล้วไลบรารี `dotenv` โหลดเข้าเป็น `process.env.ชื่อ` ตอนเริ่มโปรแกรม ตัวอย่างค่าอยู่ใน `.env.example` ที่ใส่ค่าหลอกไว้ ใครคัดลอกไปใช้โดยไม่แก้ โปรแกรมจะไม่ยอมเริ่ม (ดู `config.js`)

### JWT
**JSON Web Token** คือบัตรผ่านที่เซิร์ฟเวอร์ออกให้หลังล็อกอิน หน้าตาเป็นสามท่อนคั่นด้วยจุด `header.payload.signature`:

- **header** บอกอัลกอริทึม (ที่นี่ `HS256` = HMAC-SHA256)
- **payload** เนื้อหา (claims) เข้ารหัส base64url แค่ "แปลงรูป" ไม่ใช่ความลับ ใครก็อ่านได้ ห้ามใส่รหัสผ่าน
- **signature** ลายเซ็นที่คำนวณจาก header+payload+`JWT_SECRET` ถ้าใครแก้ payload ลายเซ็นจะไม่ตรง

claims ที่โปรเจคนี้ใส่: `sub` (username), `role`, `ver` (token_version), `iat` (เวลาออก), `exp` (เวลาหมดอายุ), `iss` (ผู้ออก `rmutt-save-energy-api`), `aud` (ผู้รับ `rmutt-save-energy-app`) อายุตาม `JWT_EXPIRES_IN` (ค่าเริ่มต้น `8h`)

ข้อเสียธรรมชาติของ JWT คือ "เพิกถอนยาก" เพราะเซิร์ฟเวอร์ไม่ได้จำ token ไว้ โปรเจคแก้ด้วย **`token_version`**: คอลัมน์ในตาราง `users` ที่ฝังเลขเวอร์ชันลงใน token (`ver`) ทุกครั้งที่ตรวจ จะเทียบ `ver` กับเลขในฐานข้อมูล ถ้าเปลี่ยนรหัสผ่านหรือเปลี่ยนสิทธิ์ผู้ใช้ จะ `token_version + 1` ทำให้ token เก่าทุกใบที่ค้างอยู่ตามเครื่องต่าง ๆ ใช้ไม่ได้ทันที

### การเก็บรหัสผ่าน (hashing)
ห้ามเก็บรหัสผ่านตรง ๆ เก็บเป็น **hash** (ผ่านฟังก์ชันทางเดียว ย้อนกลับไม่ได้) โปรเจคใช้ไลบรารี **`bcryptjs`** (เวอร์ชัน JavaScript ล้วนของ bcrypt ไม่ต้อง compile) ด้วย cost factor 12 หมายถึงคำนวณ 2^12 รอบ ตั้งใจให้ช้า (ราวหลายร้อยมิลลิวินาที) เพื่อให้คนร้ายที่ขโมยฐานข้อมูลไปไล่เดาได้ช้าลงมาก bcrypt ใส่ salt (ค่าสุ่ม) ให้เองและเก็บรวมในสตริง hash รหัสเดียวกันของสองคนจึงได้ hash ต่างกัน **ข้อจำกัด:** bcrypt อ่านรหัสผ่านแค่ 72 ไบต์แรก ตัวที่เกินถูกทิ้งเงียบ ๆ โปรเจคจึงบังคับด้วย `isValidNewPassword()` ว่าต้อง 8 ตัวขึ้นไป และไม่เกิน 72 **ไบต์** (ภาษาไทย 1 ตัวอักษร = 3 ไบต์ UTF-8 จึงนับเป็นไบต์ ไม่ใช่ตัวอักษร)

### OTP และ pepper
**OTP** (One-Time Password) คือรหัส 6 หลักใช้ครั้งเดียว ส่งไปอีเมลเพื่อพิสูจน์ว่าเป็นเจ้าของบัญชีตอนลืมรหัสผ่าน ในฐานข้อมูลไม่เก็บ OTP ตรง ๆ แต่เก็บ `HMAC-SHA256(otp, OTP_PEPPER)` **pepper** คือ "เกลือลับ" ที่อยู่ในไฟล์ `.env` ไม่ได้อยู่ในฐานข้อมูล ต่างจาก salt ที่เก็บคู่กับ hash ถ้าคนร้ายได้แค่ฐานข้อมูล (แต่ไม่ได้ `.env`) ก็คำนวณ hash ของ 1,000,000 ความเป็นไปได้ของ OTP เพื่อเทียบไม่ได้ เพราะไม่มี pepper

### Rate limiting
จำกัดจำนวนคำขอต่อช่วงเวลาต่อ IP เพื่อกันการเดารหัสผ่านซ้ำ ๆ ใช้ไลบรารี `express-rate-limit` ตัวนับเก็บใน RAM ของโปรเซส (รีสตาร์ท = นับใหม่) ตัวเลขทั้งหมดอยู่ในหัวข้อ "ระบบสมาชิก"

### CORS และ security header
**CORS** เป็นกติกาของ *เบราว์เซอร์*: เว็บจากโดเมน A จะเรียก API ของโดเมน B ได้ก็ต่อเมื่อ B ตอบ header บอกอนุญาต แอป Flutter ไม่ใช่เบราว์เซอร์ จึงไม่เกี่ยวกับ CORS เลย (CORS ใช้กับเว็บแอปเท่านั้น) **helmet** คือไลบรารีที่ใส่ HTTP header ความปลอดภัยมาตรฐานให้อัตโนมัติ เช่น `X-Content-Type-Options: nosniff`, `Strict-Transport-Security`, `X-Frame-Options` ลดช่องโหว่ฝั่งเบราว์เซอร์

### Parameter binding (กัน SQL injection)
**SQL injection** คือการที่ผู้ใช้พิมพ์ SQL แทรกในช่องกรอกจนคำสั่งเปลี่ยนความหมาย ป้องกันโดยไม่ต่อสตริงข้อมูลเข้า SQL แต่เขียน `?` เป็นช่องว่าง แล้วส่งค่าแยกเป็นอาร์เรย์ `pool.query('... WHERE username = ?', [username])` ไดรเวอร์จะส่งค่าเป็นข้อมูลล้วน ๆ ไม่ถูกตีความเป็นคำสั่ง SQL

## โครงสร้างโฟลเดอร์

```text
backend/
├── package.json            ชื่อโปรเจค, สคริปต์ npm, dependencies
├── .env.example            ตัวอย่างค่าตั้ง (คัดลอกเป็น .env)
├── .gitignore              ไม่ให้ Git เก็บ node_modules และ .env
├── .dockerignore           ไม่ให้ .env/test ติดเข้า Docker image
├── database/schema.sql     โครงตารางทั้งหมด (บทฐานข้อมูล)
├── scripts/                สคริปต์ db:init, migrate, seed (บทตอนที่ 2)
├── src/
│   ├── server.js           จุดเริ่มโปรเซส + ปิดระบบอย่างสุภาพ
│   ├── app.js              ประกอบ Express app + ผูก router
│   ├── config.js           อ่าน/ตรวจ environment variable
│   ├── db.js               Connection Pool ของ MariaDB (lazy) + withTransaction
│   ├── middleware/
│   │   ├── authenticate.js ตรวจ JWT + token_version
│   │   └── require-admin.js ตรวจ role = admin
│   ├── routes/             12 ไฟล์ = endpoint ทั้งหมด
│   ├── services/           mailer (บทนี้), mqtt/auto-off/... (ตอนที่ 2)
│   └── utils/              http, security, user (บทนี้), ที่เหลือ (ตอนที่ 2)
└── test/                   21 ไฟล์ *.test.js รันด้วย node --test (136 เทสต์)
```

## ลำดับการเริ่มระบบ (startup sequence)

```text
node src/server.js
 1. import ./app.js          → โหลด config.js (dotenv อ่าน .env), db.js (ยังไม่ต่อ DB),
                               ทุก router, express.json, helmet, cors  (ยังไม่เปิดพอร์ต)
 2. assertServerConfig()     → ตรวจ secret/SMTP/MQTT ถ้าผิด throw → โปรเซสตาย (fail-fast)
 3. startMqttAccounts()      → ลงทะเบียนตัวจัดการบัญชี MQTT ก่อนต่อ Broker
 4. startMqttBridge()        → ต่อ Mosquitto, subscribe topic จากบอร์ด
 5. startAutoOffService()    → timer ตรวจห้องว่างเพื่อปิดแอร์อัตโนมัติ
 6. app.listen(port,'0.0.0.0') → เริ่มรับ HTTP
 7. ผูก SIGINT / SIGTERM     → shutdown อย่างสุภาพ
```

ข้อสังเกตสำคัญ: `app.js` เป็นเพียง "การประกอบ" ไม่เริ่มบริการเบื้องหลังและไม่เปิดพอร์ต ทำให้ไฟล์ test `import { app }` แล้วสั่ง `app.listen(0)` (พอร์ตสุ่ม) ได้โดยไม่ไปต่อ MQTT จริง นี่คือเหตุผลที่แยก `server.js` กับ `app.js` ออกจากกัน

## อธิบายทีละไฟล์

### `package.json`
บอกว่าโปรเจคเป็น ES module (`"type": "module"`), ต้องใช้ Node 20 ขึ้นไป (`engines`) เพราะใช้ `node --test`, `fetch` ในตัว และ `crypto.randomInt` ฯลฯ ฟิลด์ `description` ยังเขียนว่า "Authentication and password reset API" ซึ่งเก่ากว่าขอบเขตงานจริง (ตอนนี้เป็น API ทั้งระบบ) ไม่กระทบการทำงาน

**สคริปต์ npm (`npm run ...`)**

| สคริปต์ | สั่งอะไร | ใช้เมื่อ |
|---|---|---|
| `start` | `node src/server.js` | รันจริง (Docker ใช้ตัวนี้) |
| `dev` | `node --watch src/server.js` | พัฒนา รีสตาร์ทเองเมื่อแก้ไฟล์ |
| `test` | `node --test` | รันเทสต์ทั้งหมด |
| `db:init` | `scripts/init-db.js` | สร้างตารางจาก schema.sql |
| `db:doctor` | `scripts/doctor.js` | เทียบ DB จริงกับ schema.sql |
| `db:migrate:*` (10 ตัว) | `scripts/migrate-*.js` | อัปเกรดฐานข้อมูลเก่า |
| `seed:admin` | `scripts/seed-admin.js` | สร้างแอดมินคนแรกจาก `SEED_ADMIN_*` |
| `schedules:convert`, `migrate:legacy` | สคริปต์แปลงไฟล์/ย้ายข้อมูลเก่า | งานครั้งเดียว |

**Dependencies (ทุกตัวถูกใช้จริง)**

| แพ็กเกจ | ทำอะไร | ใช้ที่ไหน |
|---|---|---|
| `express` ^5.1 | เฟรมเวิร์กเว็บ | `app.js` และทุก route |
| `cors` | ใส่ header CORS | `app.js` |
| `helmet` | ใส่ security header | `app.js` |
| `express-rate-limit` | จำกัดจำนวน request | `routes/auth.js` |
| `jsonwebtoken` | ออก/ตรวจ JWT | `routes/auth.js`, `middleware/authenticate.js` |
| `bcryptjs` | hash/เทียบรหัสผ่าน | `routes/auth.js`, `routes/users.js` |
| `dotenv` | โหลด `.env` | `config.js` |
| `mariadb` | ไดรเวอร์ฐานข้อมูล + pool | `db.js` |
| `mqtt` | ไคลเอนต์ MQTT | `services/mqtt.js` |
| `nodemailer` | ส่งอีเมล SMTP | `services/mailer.js` |
| `fflate` | บีบ/แตก zip (.xlsx คือ zip ของ XML) | `utils/xlsx-reader.js`, `xlsx-writer.js` |
| `fast-xml-parser` | อ่าน XML ในไฟล์ .xlsx | `utils/xlsx-reader.js` |

ไม่มี `devDependencies` เพราะเทสต์ใช้ตัวรันและ `assert` ที่มากับ Node เอง (ไม่ต้องติดตั้ง Jest/Mocha)

### `.env.example`
แม่แบบของ `.env` จัดเป็นกลุ่ม: ทั่วไป (`NODE_ENV`, `PORT`, `APP_ORIGIN`, `TRUST_PROXY`), ฐานข้อมูล (`DB_*`), ความลับ (`JWT_SECRET`, `JWT_EXPIRES_IN`, `OTP_PEPPER`, `OTP_EXPIRES_MINUTES`), อีเมล (`MAIL_MODE`, `SMTP_*`), MQTT (`MQTT_*`, `MQTT_DEVICE_AUTH`, `MQTT_DEVICE_SECRET`), `FIRMWARE_DIR`, ค่า seed แอดมิน (`SEED_ADMIN_*`) และ `LEGACY_PHONE_PREFIX` ค่าความลับทั้งหมดเป็นคำว่า `replace_with...`/`change_this...` ตั้งใจให้ `unsafeSecret()` จับได้ ถ้าลืมแก้ ตัวอย่างบอกวิธีสุ่มความลับ: `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"` ซึ่งได้ 96 ตัวอักษร hex

> [!NOTE]
> `.env.example` ตั้ง `MAIL_MODE=console` (เหมาะตอนพัฒนา: OTP โผล่ในเทอร์มินัล) แต่ค่าเริ่มต้นใน `config.js` เมื่อไม่ตั้งเลยคือ `smtp` ถ้า deploy จริงแล้วลืมตั้ง SMTP จะถูก `assertServerConfig()` ตีกลับ ซึ่งปลอดภัยกว่า

### `.gitignore` และ `.dockerignore`
`.gitignore` กัน `node_modules/`, `.env`, `npm-debug.log*`, `coverage/` ไม่ให้ขึ้น Git `.dockerignore` กัน `.env`, `.env.*`, `*.bak-*`, `node_modules`, `test`, `coverage`, `*.tmp`, `*.log` ไม่ให้ถูก `COPY . .` เข้า image เพราะ image ถูก build บนเซิร์ฟเวอร์และเก็บถาวร ถ้าไฟล์ความลับหลุดเข้าไปจะฝังอยู่ในทุกชั้นของ image การตัด `test` ออกทำให้ image เล็กลงและไม่มีโค้ดทดสอบบนเครื่องจริง

### `src/server.js`
หน้าที่: จุดเริ่มต้นโปรเซส ฟังก์ชัน `shutdown(signal)` เรียกโดย signal handler ไฟล์นี้เรียกใช้ `app.js`, `config.js`, `db.js`, และ service สามตัว (`auto-off`, `mqtt`, `mqtt-accounts`) ดูการเจาะโค้ดด้านล่าง

### `src/app.js`
หน้าที่: ประกอบ Express app และ export เป็น `app` ฟังก์ชันภายใน `createCorsOptions()` สร้างตัวเลือก CORS ใครเรียก: `server.js` และไฟล์ test เรียกใคร: ทุก router, `utils/http.js`, `services/mqtt.js` (เฉพาะ `getMqttBridgeStatus` สำหรับ health) ดูการเจาะโค้ดด้านล่าง

### `src/config.js`
หน้าที่: จุดเดียวที่อ่าน `process.env` ไฟล์อื่นห้ามอ่านเอง ให้ `import { config }` แทน เหตุผลคือค่าเริ่มต้น การแปลงชนิด (string → number/boolean) และการตรวจความถูกต้องอยู่ที่เดียว ฟังก์ชัน: `numberFromEnv`, `trustProxyFromEnv`, `booleanFromEnv`, `assertServerConfig`, `isValidFromAddress` (export เพื่อให้ test เรียก), `unsafeSecret` ดูการเจาะโค้ดด้านล่าง

### `src/db.js`
หน้าที่: ให้ `pool` (Connection Pool = กลุ่มการเชื่อมต่อที่เปิดค้างไว้ใช้ซ้ำ แทนการเปิด/ปิดทุก query) และ `withTransaction(callback)` จุดที่ควรรู้:

- **สร้าง pool แบบขี้เกียจ (lazy)**: `getPool()` สร้างตอนมี query ครั้งแรก ไม่ใช่ตอน import ถ้าสร้างตอน import ไฟล์ test ที่แค่ import ฟังก์ชัน util จะเปิดการเชื่อมต่อค้างไว้ และ `node --test` จะไม่ยอมจบ
- `pool` ที่ export เป็นอ็อบเจกต์ห่อ (`query`, `batch`, `getConnection`, `end`) ที่เรียก `getPool()` ทุกครั้ง การที่เป็นอ็อบเจกต์ธรรมดาทำให้ test เขียนทับ `pool.query = ...` ได้ (ดู `profile-email.test.js`)
- ตัวเลือก `acquireTimeout: 10000` (รอ connection ว่างไม่เกิน 10 วินาที), `connectionLimit` จาก `DB_CONNECTION_LIMIT` (ค่าเริ่มต้น 5), `bigIntAsNumber: true` และ `insertIdAsNumber: true` สองตัวหลังจำเป็น เพราะไดรเวอร์ `mariadb` ส่ง `COUNT(*)` และ id เป็นชนิด `BigInt` ซึ่ง `JSON.stringify` ทำเป็นข้อความไม่ได้ (จะ error) ตั้งให้เป็น `Number` เลย
- `withTransaction`: เปิด connection → `beginTransaction` → รัน callback → `commit` ถ้า error `rollback` แล้ว throw ต่อ → `finally` คืน connection เข้า pool เสมอ **Transaction** คือกลุ่มคำสั่งที่ "สำเร็จทั้งหมดหรือไม่ทำเลย" ใช้ตอนต้องแก้หลายตารางให้สอดคล้องกัน เช่น รีเซ็ตรหัสผ่าน (แก้ `users` + ปิด `password_reset_otps`)

### `src/middleware/authenticate.js`
ด่านตรวจตัวตน ดูการเจาะโค้ดด้านล่าง ใช้ที่: ทุก router ยกเว้น `public.js` และ endpoint สาธารณะใน `auth.js`

### `src/middleware/require-admin.js`
ด่านตรวจสิทธิ์ ต้องวางหลัง `authenticate` เสมอ (เพราะอ่าน `request.authUser`) ใช้ `request.authUser?.role` ถ้าไม่มี `authUser` ก็ถือว่าไม่ใช่ admin จึงปลอดภัยแม้ลืมใส่ `authenticate` (ตอบ 403 ไม่ผ่านโดยบังเอิญ) เป็นฟังก์ชัน sync ธรรมดา `throw` ตรง ๆ ได้ เพราะ Express จับ error ของฟังก์ชัน sync เอง และเพราะเป็นฟังก์ชันเล็กไม่มี I/O ไฟล์ test จึงเรียกมันตรง ๆ ได้ (ดู `schedule.test.js`)

### `src/utils/http.js`
ชุดเครื่องมือกลางของ HTTP:

| สิ่งที่ export | ทำอะไร |
|---|---|
| `ApiError(statusCode, message)` | error ที่ "ตั้งใจโยน" พร้อมรหัสสถานะ route เขียน `throw new ApiError(404, '...')` แล้ว error handler แปลงเป็น response ให้ |
| `asyncHandler(handler)` | ห่อ handler: `Promise.resolve(handler(...)).catch(next)` ส่ง error เข้า Express ทุกกรณี |
| `notFoundHandler` | ตอบ 404 `{message: 'ไม่พบ API ที่เรียกใช้งาน'}` สำหรับ URL ที่ไม่มี route ใดจับ |
| `errorHandler` | จัด error ทั้งหมดเป็น JSON: `ApiError` → รหัสของมัน, `entity.too.large` → 413, อื่น ๆ → log แล้วตอบ 500 ข้อความกลาง ๆ |

เหตุผลที่แยกข้อความ 500 ออก: ไม่ส่งรายละเอียด error ภายใน (ชื่อตาราง, stack) ให้ผู้ใช้ เพราะเป็นข้อมูลให้ผู้โจมตี รายละเอียดเต็มลง `console.error` (ดูได้ใน docker log) ถ้า `response.headersSent` เป็นจริง (ตอบไปครึ่งทางแล้ว) ต้องส่งต่อให้ตัวจัดการ default ของ Express ไม่งั้นจะตอบซ้ำ

> [!WARN]
> `errorHandler` ไม่มีกรณีเฉพาะสำหรับ JSON ที่พิมพ์ผิดรูปแบบ (`entity.parse.failed`) และ error ของ CORS (`Origin is not allowed by CORS`) ทั้งสองจะตกไปที่ 500 ทั้งที่ควรเป็น 400/403 เป็นข้อจำกัดที่เห็นจากโค้ด ไม่กระทบความปลอดภัย แต่แอปจะเห็นข้อความ "เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์"

### `src/utils/security.js`
ฟังก์ชัน pure ด้านความปลอดภัย (พึ่งพาแค่ `node:crypto` กับ `config.otpPepper`):

| ฟังก์ชัน | ทำอะไร | ทำไมเขียนแบบนี้ |
|---|---|---|
| `createOtp()` | `crypto.randomInt(100000, 1000000)` → สตริง 6 หลัก | ใช้ตัวสุ่มระดับ crypto ไม่ใช่ `Math.random()` (เดาลำดับได้) ช่วง 100000–999999 ทำให้ไม่ขึ้นต้นด้วย 0 จึงเป็น 6 หลักเสมอ |
| `createResetToken()` | `randomBytes(32).toString('hex')` → 64 อักขระ hex | บัตรผ่านชั่วคราวหลังยืนยัน OTP มี entropy 256 บิต เดาไม่ได้ |
| `hashSecret(value, pepper)` | HMAC-SHA256 ด้วย pepper → hex 64 ตัว | ใช้ทั้งกับ OTP, reset token และ provisioning token ของบอร์ด (`routes/air-conditioners.js`) พารามิเตอร์ `pepper` มีค่าเริ่มต้นเป็น `config.otpPepper` และรับค่าอื่นได้ เพื่อให้เทสต์ใส่ pepper ของตัวเอง |
| `safeHashEquals(a, b)` | แปลง hex เป็น Buffer แล้วเทียบด้วย `timingSafeEqual` | การเทียบสตริงด้วย `===` หยุดทันทีที่เจอตัวต่าง เวลาที่ใช้จึง "รั่ว" ว่าตรงกันกี่ตัวแรก `timingSafeEqual` ใช้เวลาเท่ากันเสมอ (ต้องเช็กความยาวก่อน เพราะฟังก์ชันนี้ throw ถ้ายาวไม่เท่ากัน) |
| `isValidNewPassword(p)` | เป็น string, ยาว ≥ 8, `Buffer.byteLength` ≤ 72 | ขีดจำกัดของ bcrypt |

> [!WHY]
> ทำไม OTP ใช้ HMAC เร็ว ๆ ไม่ใช้ bcrypt? รหัสผ่านต้องช้าเพราะผู้ใช้ตั้งเองและมีโอกาสถูกเดา แต่ OTP อายุแค่ 10 นาที ใช้ได้ผิดสูงสุด 5 ครั้ง (ฝั่งเซิร์ฟเวอร์) ความเสี่ยงอยู่ที่ฐานข้อมูลรั่วภายใน 10 นาทีนั้น pepper ที่อยู่นอกฐานข้อมูลจึงพอ และ HMAC ทำให้ตรวจเร็วไม่ถ่วง Node

### `src/utils/user.js`
ตรวจและแปลงข้อมูลผู้ใช้ ทั้งหมด pure:

- รูปแบบ: `usernamePattern = /^[A-Za-z0-9][A-Za-z0-9._-]{2,99}$/` (3–100 ตัว ขึ้นต้นด้วยตัวอักษร/ตัวเลข ห้ามมี `/` หรือเว้นวรรค กัน path traversal เช่น `../admin`), `emailPattern`, `phonePattern = /^[0-9+()\- ]{6,30}$/`, roles = `admin` | `staff`
- `cleanString(value, maxLength)`: ไม่ใช่ string → `''`, นอกนั้น `trim()` แล้วตัดความยาว กัน input ใหญ่/ชนิดผิด (เช่นส่งอาร์เรย์มาแทนสตริง)
- `publicUser(row)` แปลงแถว DB (snake_case) เป็น JSON (camelCase) **เลือกเฉพาะฟิลด์ที่ปลอดภัย** (ไม่มี `password_hash`, `token_version`, id ภายใน) ค่า `null` กลายเป็น `''`
- `managedUser(row)` = `publicUser` + `isActive`, `lastLoginAt`, `createdAt` สำหรับหน้าจัดการผู้ใช้
- `validateUsername`, `validateRole`, `validateNewUserInput` (สร้างผู้ใช้ใหม่, role ไม่ระบุ = `staff`, อีเมลแปลงเป็นตัวพิมพ์เล็ก), `validateUserUpdate` (รับแค่ `role`/`isActive` ต้องมีอย่างน้อยหนึ่งตัว), `validateProfileUpdate` (ผู้ใช้แก้ตัวเอง **ไม่รับ role/isActive โดยตั้งใจ**)
- `toIsoString`: วันที่ที่แปลงไม่ได้ → `null` ไม่ใช่ข้อความ `Invalid Date`

ไฟล์นี้ import `ApiError` แต่ไม่แตะ DB ข้อผิดพลาดจึงตรวจได้ใน test โดยไม่ต้องมีเซิร์ฟเวอร์

### `src/services/mailer.js`
ส่งอีเมล OTP ฟังก์ชันเดียว `sendPasswordResetOtp({to, displayName, otp})`:

- `config.mail.mode === 'console'` → `console.log` OTP ลงเทอร์มินัลแล้วจบ ไม่ส่งจริง (ตอนพัฒนา ไม่ต้องมี SMTP)
- นอกนั้น → ส่งผ่าน `nodemailer` ด้วย SMTP (`getTransporter()` สร้างครั้งแรกแล้วเก็บในตัวแปร `transporter` ใช้ซ้ำ) ส่งทั้งข้อความล้วน (`text`) และ HTML
- `escapeHtml()` แปลง `& < > " '` ในชื่อผู้ใช้ก่อนใส่ HTML กันคนตั้งชื่อเป็นโค้ด HTML แล้วอีเมลกลายเป็นช่องโจมตี (OTP ไม่ต้อง escape เพราะระบบสร้างเองเป็นตัวเลข)
- เนื้อหาบอกอายุ OTP จาก `config.otpExpiresMinutes` ไม่ฝังเลข 10 ไว้ในข้อความ

### `src/routes/*.js` และ `test/*.js`
อธิบายในหัวข้อ "ไฟล์ route" และ "การทดสอบ" ด้านล่าง

## การตั้งค่าและ fail-fast

`assertServerConfig()` ถูกเรียกก่อนเปิดพอร์ต ถ้ามีค่าผิดจะ `throw Error('Missing or unsafe environment settings: ...')` ทำให้โปรเซสจบทันที (Docker จะแสดงว่า container ล้ม) หลักการนี้เรียก **fail-fast**: ถ้าตั้งค่าผิด ให้ล้มตั้งแต่เริ่ม ดีกว่าเริ่มได้แล้วไปพังตอนผู้ใช้ใช้งาน (เช่น ล็อกอินได้แต่เซ็น token ด้วย secret ว่าง)

| ตรวจอะไร | เงื่อนไขล้ม |
|---|---|
| `JWT_SECRET`, `OTP_PEPPER` | สั้นกว่า 32 ตัว หรือมีคำว่า `replace`/`change`/`example` (ไม่สนตัวพิมพ์) |
| `MAIL_MODE=smtp` | ขาด `SMTP_HOST`/`SMTP_USER`/`SMTP_PASS`/`SMTP_FROM` หรือ `SMTP_FROM` ไม่มีที่อยู่อีเมล |
| `MQTT_REQUIRED=true` | ขาด `MQTT_URL`/`MQTT_USERNAME`/`MQTT_PASSWORD` |
| `MQTT_DEVICE_AUTH=dynsec` | `MQTT_DEVICE_SECRET` ไม่ผ่าน `unsafeSecret` |

กรณีเตือนแต่ไม่หยุด (`console.warn`): `MAIL_MODE=console` ตอน `NODE_ENV=production` และ `MQTT_DEVICE_AUTH=shared` ตอน production

## การเจาะโค้ดทีละบรรทัด

### 1. `server.js` ทั้งไฟล์

**ไฟล์ `backend/src/server.js` บรรทัด 1–33**

```js:1
import { app } from './app.js';
import { assertServerConfig, config } from './config.js';
import { pool } from './db.js';
import { startAutoOffService, stopAutoOffService } from './services/auto-off.js';
import { startMqttBridge, stopMqttBridge } from './services/mqtt.js';
import {
  startMqttAccounts,
  stopMqttAccounts,
} from './services/mqtt-accounts.js';

assertServerConfig();
// ต้องลงทะเบียนก่อนต่อ Broker เพื่อให้ทันรอบ connect แรก
startMqttAccounts();
startMqttBridge();
startAutoOffService();

const server = app.listen(config.port, '0.0.0.0', () => {
  console.log(`RMUTT Save Energy API listening on port ${config.port}`);
});

async function shutdown(signal) {
  console.log(`${signal} received, shutting down...`);
  server.close(async () => {
    stopAutoOffService();
    stopMqttAccounts();
    await stopMqttBridge();
    await pool.end();
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 1–9 | `import ...` | ดึง app, config, pool และคู่ start/stop ของบริการเบื้องหลัง 3 ตัว `import` ทำงานก่อนโค้ดอื่นทั้งหมด จึงโหลด `config.js` (และ dotenv) ก่อนเสมอ |
| 11 | `assertServerConfig()` | ตรวจค่าตั้ง ถ้าผิด throw ออกนอกโปรแกรม → โปรเซสจบด้วย error (fail-fast) |
| 12–13 | `startMqttAccounts()` | ต้องมาก่อน `startMqttBridge()` เพราะตัวจัดการบัญชีต้องพร้อมรอรับเหตุการณ์ "ต่อ Broker สำเร็จ" ของรอบแรก ถ้าลงทะเบียนช้ากว่า อาจพลาดรอบ connect แรก |
| 14 | `startMqttBridge()` | ต่อ MQTT Broker และ subscribe (ไม่ `await` ถ้าต่อไม่ติด Backend ยังเปิดพอร์ตได้ เมื่อ `MQTT_REQUIRED` ไม่บังคับ ระบบ REST ยังใช้งานได้ และสั่งแอร์จะได้ 503) |
| 15 | `startAutoOffService()` | เริ่ม timer ตรวจห้องว่างปิดแอร์ (บทตอนที่ 2) |
| 17 | `app.listen(port, '0.0.0.0', cb)` | เปิดพอร์ต `0.0.0.0` = รับจากทุกการ์ดเครือข่าย (จำเป็นใน Docker เพราะ `127.0.0.1` จะรับได้แค่ภายใน container) คืนอ็อบเจกต์ server เก็บไว้ใน `server` เพื่อปิดทีหลัง |
| 21 | `async function shutdown(signal)` | ฟังก์ชันปิดระบบ รับชื่อ signal มาแสดงใน log |
| 23 | `server.close(callback)` | หยุดรับการเชื่อมต่อใหม่ และเรียก callback เมื่อ request ที่ค้างอยู่ทำเสร็จหมด (graceful = ไม่ตัดกลางคัน) |
| 24–27 | stop services, `pool.end()` | หยุด timer ปิดแอร์, ตัวจัดการบัญชี, ตัดการเชื่อมต่อ MQTT และคืน connection ฐานข้อมูลทั้งหมด **ตามลำดับ** เพื่อไม่ให้ timer ไปยิง query ใส่ pool ที่ปิดแล้ว |
| 28 | `process.exit(0)` | จบโปรเซสแบบปกติ (รหัส 0) |
| 32–33 | `process.on('SIGINT'/'SIGTERM', ...)` | SIGINT = กด Ctrl+C, SIGTERM = `docker stop` ส่งมา ถ้าไม่ดักสัญญาณ Node จะตายทันทีโดยไม่ปิด MQTT/DB |

ข้อสังเกต: ไม่มี timeout บังคับปิด ถ้ามี keep-alive connection ค้าง `server.close` อาจไม่เรียก callback แต่ Docker จะส่ง SIGKILL เองหลังครบเวลา (ค่าเริ่มต้น 10 วินาที) และไม่มี handler `unhandledRejection` (Node 20 ค่าเริ่มต้นคือให้โปรเซสล้ม แล้ว Docker restart policy จะเริ่มใหม่)

### 2. `app.js`

**ไฟล์ `backend/src/app.js` บรรทัด 26–36 และ 74–98**

```js:26
export const app = express();

app.disable('x-powered-by');
// Backend อยู่หลัง Caddy เสมอเมื่อ deploy จริง ถ้าไม่บอก Express ว่าเชื่อ
// X-Forwarded-For จาก proxy หนึ่งชั้น ทุกคำขอจะดูเหมือนมาจาก IP ของ Caddy
// แล้ว rate limit ของหน้า login จะนับรวมทุกคนในตึกเป็นคนเดียว
// คนหนึ่งกรอกรหัสผิด 10 ครั้ง = ทุกคนล็อกอินไม่ได้ 15 นาที
app.set('trust proxy', config.trustProxy);
app.use(helmet());
app.use(cors(createCorsOptions()));
app.use(express.json({ limit: '256kb' }));
```

```js:74
app.use(notFoundHandler);
app.use(errorHandler);

function createCorsOptions() {
  if (config.appOrigin === '*') {
    return {};
  }

  const allowed = new Set(
    config.appOrigin
      .split(',')
      .map((origin) => origin.trim())
      .filter(Boolean),
  );

  return {
    origin(origin, callback) {
      if (!origin || allowed.has(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error('Origin is not allowed by CORS'));
    },
  };
}
```

| บรรทัด | ความหมาย |
|---|---|
| 26 | `express()` สร้างแอป `export` เพื่อให้ `server.js` และ test ใช้ |
| 28 | `disable('x-powered-by')` ซ่อนส่วนหัว `X-Powered-By: Express` ไม่บอกผู้โจมตีว่าใช้เฟรมเวิร์กอะไร (helmet ก็ซ่อนให้ แต่ประกาศซ้ำชัดเจน) |
| 33 | `trust proxy`: ใน production มี Caddy (reverse proxy) อยู่ข้างหน้า ทุก request มาจาก IP ของ Caddy ถ้าไม่ตั้ง `TRUST_PROXY=1` Express จะเชื่อว่าทุกคนคือ IP เดียว แล้ว rate limit ของหน้า login จะนับรวมทั้งอาคาร (คนเดียวกรอกผิด 10 ครั้ง = ทุกคนล็อกอินไม่ได้ 15 นาที) ตั้งเป็นตัวเลข "จำนวนชั้น proxy" ไม่ตั้งเป็น `true` เพราะ `true` ทำให้ใครก็ส่ง `X-Forwarded-For` ปลอมได้ |
| 34 | `helmet()` ต้องอยู่ต้นสายเพื่อให้ response ทุกอันได้ header |
| 35 | `cors(...)` ตัวเลือกมาจากฟังก์ชันด้านล่าง |
| 36 | `express.json({limit:'256kb'})` อ่าน body ที่ `Content-Type: application/json` แปลงเป็นอ็อบเจกต์ใน `request.body` จำกัด 256 KB กัน request ใหญ่ถล่ม RAM (เกินแล้ว error → 413) route ที่รับไฟล์ใหญ่ (นำเข้าตารางเรียน) ใช้ `express.raw` ของตัวเองแทน |
| 38–59 | `/api/health`: `SELECT 1` ทดสอบว่า DB ยังตอบ แล้วคืนสถานะ MQTT บน production ตัดรายละเอียดภายใน (ที่อยู่ Broker) เหลือ `connected`, `deviceAuth`, `topicPrefix` เพราะ endpoint นี้ไม่ต้องล็อกอิน |
| 61–72 | `app.use(prefix, router)` ผูก 12 router ที่ prefix ของมัน (ตารางในหัวข้อ API) ลำดับของ prefix เหล่านี้ไม่ซ้อนทับกัน จึงสลับที่กันได้ |
| 74 | `notFoundHandler` อยู่หลังทุก route: ถ้ามาถึงตรงนี้แปลว่าไม่มี route ไหนจับ → 404 |
| 75 | `errorHandler` ต้องอยู่ **ท้ายสุด** เพราะ Express ส่ง error ไปหา handler ที่อยู่ถัดลงไปเท่านั้น |
| 77–80 | ถ้า `APP_ORIGIN=*` คืน `{}` = ค่าเริ่มต้นของ `cors` คือ "อนุญาตทุกที่" (ใช้ตอนพัฒนา) |
| 82–87 | แยก `APP_ORIGIN` ที่คั่นด้วยจุลภาค เป็น `Set` ของ origin ที่อนุญาต (`trim`, `filter(Boolean)` ตัดช่องว่าง/ค่าว่าง) |
| 90–96 | ฟังก์ชัน `origin`: ถ้า request **ไม่มี** header `Origin` (แอปมือถือ, curl, เซิร์ฟเวอร์ด้วยกัน ไม่ใช่เบราว์เซอร์) หรืออยู่ใน whitelist → อนุญาต ไม่งั้นส่ง Error |

### 3. `config.js`

**ไฟล์ `backend/src/config.js` บรรทัด 5–25 และ 137–139**

```js:5
function numberFromEnv(name, fallback) {
  const value = Number.parseInt(process.env[name] ?? '', 10);
  return Number.isFinite(value) ? value : fallback;
}

// TRUST_PROXY: จำนวนชั้นของ reverse proxy ที่อยู่หน้า Backend (Caddy = 1)
// ไม่ตั้ง = false คือไม่เชื่อ X-Forwarded-For เลย เหมาะกับตอนรันตรงบนเครื่อง
function trustProxyFromEnv(name) {
  const raw = (process.env[name] ?? '').trim();
  if (raw === '' || raw.toLowerCase() === 'false') return false;
  if (/^\d+$/.test(raw)) return Number.parseInt(raw, 10);
  // ค่า true จะทำให้ใครก็ปลอม IP ได้ และ express-rate-limit จะปฏิเสธ
  if (raw.toLowerCase() === 'true') return 1;
  return raw;
}

function booleanFromEnv(name, fallback = false) {
  const value = process.env[name];
  if (value == null) return fallback;
  return value.toLowerCase() === 'true';
}
```

```js:137
function unsafeSecret(value) {
  return value.length < 32 || /replace|change|example/i.test(value);
}
```

| บรรทัด | ความหมาย |
|---|---|
| 1 (`import 'dotenv/config'`) | import แบบไม่เอาชื่ออะไรมา แต่ให้ไฟล์ทำงานก็โหลด `.env` เข้า `process.env` ทันที ต้องเป็นบรรทัดแรกก่อนอ่านค่าใด ๆ |
| 5–8 | `numberFromEnv`: env ทุกตัวเป็น **string** เสมอ จึงต้องแปลงเป็นเลข `process.env[name] ?? ''` ถ้าไม่ตั้งใช้สตริงว่าง (`??` = ใช้ค่าขวาเมื่อซ้ายเป็น `null/undefined`) `parseInt(…, 10)` ฐานสิบ ถ้าได้ `NaN` (ไม่ตั้ง/พิมพ์ผิด) `isFinite` เป็น false → ใช้ค่า fallback ผลคือค่าผิดไม่ทำให้โปรแกรมพัง แต่ถอยไปค่าเริ่มต้น |
| 12–19 | `trustProxyFromEnv`: ว่างหรือ `false` → `false` (ไม่เชื่อ proxy) เป็นตัวเลขล้วน → จำนวนชั้น `'true'` → แปลงเป็น `1` แทนที่จะปล่อยเป็น `true` อันตราย อย่างอื่น (เช่น `loopback`, ช่วง IP) → ส่งต่อเป็นสตริงให้ Express ตีความ |
| 21–25 | `booleanFromEnv`: ไม่ตั้ง → fallback, ตั้ง → จริงเฉพาะเมื่อเป็น `true` (ไม่สนตัวพิมพ์) ค่าอื่นทั้งหมด (`1`, `yes`) เป็น false |
| 27–72 | ออบเจกต์ `config` ค่าเริ่มต้นสำคัญ: `port` 3000, `appOrigin` `*`, `db.host` `127.0.0.1`, `db.port` 3306, `db.user` `root`, `db.database` `test`, `db.connectionLimit` 5, `jwtExpiresIn` `8h`, `otpExpiresMinutes` 10, `mail.mode` `smtp`, `mail.port` 465, `mail.secure` true, `mqtt.topicPrefix` `rmutt/ac`, `mqtt.occupancyTopicPrefix` `rmutt/occupancy`, `mqtt.required` false ความลับ (`jwtSecret`, `otpPepper`) ไม่มีค่าเริ่มต้นที่ใช้ได้ (สตริงว่าง) เพื่อบังคับให้ตั้งเอง |
| 61 | `deviceUrl` = `MQTT_DEVICE_URL` ถ้าไม่มีใช้ `MQTT_URL` เพราะที่อยู่ที่ Backend ใช้ภายใน Docker (`mqtt://mqtt:1883`) ต่างจากที่ ESP32 ต้องใช้จากอินเทอร์เน็ต (ค่าเริ่มต้นใน compose คือ `mqtts://rmutt-energy.tailb292b4.ts.net:8443` ผ่าน Tailscale Funnel หรือตั้งเป็น `mqtts://<โดเมน>:8883` เพื่อให้บอร์ดในมหาวิทยาลัยต่อตรง) |
| 69 | `deviceAuth: normalizeDeviceAuthMode(...)` ค่าที่ไม่ใช่ `dynsec` ถอยเป็น `shared` (ฟังก์ชันอยู่ใน `utils/mqtt-accounts.js` ทดสอบใน `mqtt-accounts.test.js`) |
| 74–126 | `assertServerConfig`: สะสมชื่อที่ผิดลงอาร์เรย์ `missing` แล้ว throw ครั้งเดียวรวมทุกข้อ ผู้ติดตั้งแก้ได้ครบในรอบเดียว ไม่ต้องรันแล้วเจอทีละข้อ |
| 130–135 | `isValidFromAddress`: ยอมรับ `Name <a@b.co>` หรือ `a@b.co` เหตุที่ต้องตรวจ: ถ้า `SMTP_FROM` ไม่มีอีเมล ส่งไม่ออก และเพราะหน้าลืมรหัสผ่านตอบเหมือนกันทุกกรณีโดยตั้งใจ OTP จะหายเงียบโดยไม่มีใครรู้ |
| 137–139 | `unsafeSecret`: สั้นกว่า 32 หรือมีคำชวนสงสัย ใช้ regex `/.../i` (`i` = ไม่สนตัวพิมพ์) |

> [!NOTE]
> ข้อความ error บอกว่า `OTP_PEPPER` ต้อง "different" จาก JWT_SECRET และ `MQTT_DEVICE_SECRET` "ห้ามซ้ำกับค่าอื่น" แต่โค้ดจริงตรวจแค่ความยาวกับคำต้องห้าม **ไม่ได้เทียบว่าซ้ำกันหรือไม่** ผู้ดูแลต้องสุ่มแยกกันเอง (ตามคำแนะนำใน `.env.example`)

### 4. `middleware/authenticate.js`

**ไฟล์ `backend/src/middleware/authenticate.js` บรรทัด 8–43**

```js:8
export const authenticate = asyncHandler(async (request, response, next) => {
  const authorization = request.get('authorization') ?? '';
  const [scheme, token] = authorization.split(' ');

  if (scheme !== 'Bearer' || !token) {
    throw new ApiError(401, 'กรุณาเข้าสู่ระบบ');
  }

  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret, {
      algorithms: ['HS256'],
      issuer: 'rmutt-save-energy-api',
      audience: 'rmutt-save-energy-app',
    });
  } catch {
    throw new ApiError(401, 'รหัสเข้าสู่ระบบหมดอายุหรือไม่ถูกต้อง');
  }

  const rows = await pool.query(
    `SELECT username, first_name, last_name, email, phone, role,
            token_version
       FROM users
      WHERE username = ? AND is_active = 1
      LIMIT 1`,
    [payload.sub],
  );
  const user = rows[0];

  if (!user || Number(user.token_version) !== Number(payload.ver)) {
    throw new ApiError(401, 'กรุณาเข้าสู่ระบบใหม่');
  }

  request.authUser = publicUser(user);
  next();
});
```

| บรรทัด | ความหมาย |
|---|---|
| 8 | `authenticate` คือ middleware ที่ห่อด้วย `asyncHandler` จึง `throw` ได้ในฟังก์ชัน async |
| 9 | อ่าน header `Authorization` (ถ้าไม่มี ใช้สตริงว่างกัน `undefined.split` พัง) แอปส่งรูปแบบ `Authorization: Bearer <token>` |
| 10 | แยกด้วยช่องว่าง ด้วย destructuring ของอาร์เรย์: `scheme='Bearer'`, `token='eyJ...'` |
| 12–14 | ถ้าไม่ใช่ `Bearer` หรือไม่มี token → 401 |
| 18 | `jwt.verify` ตรวจ 3 อย่างพร้อมกัน: ลายเซ็นตรงกับ `JWT_SECRET`, `exp` ยังไม่หมด, และตัวเลือกด้านล่าง |
| 19 | `algorithms: ['HS256']` **กำหนดอัลกอริทึมที่ยอมรับ** กันการโจมตีสลับ algorithm (เช่นส่ง token ที่อ้างว่า `alg: none` แล้วไม่มีลายเซ็น) |
| 20–21 | `issuer` และ `audience` ต้องตรงกับที่ออกไว้ใน `auth.js` token ของระบบอื่นที่ใช้ secret เดียวกันจะไม่ผ่าน |
| 23–25 | `catch {` (ไม่ต้องตั้งชื่อตัวแปร error) ไม่ว่าจะหมดอายุหรือเสียหาย ตอบข้อความเดียวกัน ไม่บอกรายละเอียดผู้โจมตี |
| 27–34 | ดึงผู้ใช้จาก DB ด้วย `payload.sub` (username) เฉพาะที่ `is_active = 1` ตรวจ DB **ทุก request** ทำให้บัญชีที่แอดมินปิดใช้งานเข้าไม่ได้ทันที ไม่ต้องรอ token หมดอายุ ราคาที่จ่ายคือ query เพิ่มหนึ่งครั้งต่อ request (ตาราง `users` ใช้ primary key `username` จึงเร็ว) |
| 37 | ไม่พบผู้ใช้ หรือ `token_version` ในฐานข้อมูลไม่เท่ากับ `ver` ใน token → token ถูกเพิกถอน (หลังเปลี่ยนรหัสผ่าน/เปลี่ยนสิทธิ์) ใช้ `Number(...)` ทั้งสองข้างเพราะชนิดอาจเป็นสตริง/ตัวเลขต่างกัน |
| 41 | `request.authUser = publicUser(user)` แนบผู้ใช้ให้ handler ถัดไป **role มาจากฐานข้อมูล ไม่ใช่จากคำ `role` ใน token** แม้ token จะมี `role` แต่ไม่เคยถูกใช้ตัดสินสิทธิ์ การเลื่อน/ลดสิทธิ์จึงมีผลทันที |
| 42 | `next()` ส่งต่อไป middleware/handler ตัวถัดไป |

> [!ASK]
> **ถาม:** ถ้ามีคนขโมย token ไป ทำอะไรได้บ้าง?
> **ตอบ:** ใช้ได้จนกว่าจะหมดอายุ (8 ชั่วโมง) หรือจนกว่า `token_version` ของบัญชีจะเพิ่ม (เปลี่ยนรหัสผ่าน หรือแอดมินเปลี่ยนสิทธิ์/ปิดบัญชี) แต่ปิดบัญชีมีผลทันทีเพราะตรวจ `is_active` ทุก request ระบบนี้ไม่มีปุ่ม "ออกจากระบบทุกเครื่อง" โดยตรง วิธีใกล้เคียงที่สุดคือเปลี่ยนรหัสผ่าน

### 5. Handler ล็อกอิน `POST /api/auth/login`

**ไฟล์ `backend/src/routes/auth.js` บรรทัด 24–33 และ 54–109**

```js:24
const dummyPasswordHash =
  '$2b$12$l6JjOOe7XokI9qoxrAqZMupSpyJicZzJy1.dbUG0PjJdPk.6mk3wi';

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { message: 'ลองเข้าสู่ระบบหลายครั้งเกินไป กรุณารอ 15 นาที' },
});
```

```js:54
authRouter.post(
  '/login',
  loginLimiter,
  asyncHandler(async (request, response) => {
    const username = cleanString(request.body?.username, 100);
    const password = typeof request.body?.password === 'string'
      ? request.body.password
      : '';

    if (!username || !password || password.length > 256) {
      throw new ApiError(400, 'กรุณากรอก Username และ Password');
    }

    const rows = await pool.query(
      `SELECT username, password_hash, first_name, last_name, email, phone,
              role, token_version
         FROM users
        WHERE username = ? AND is_active = 1
        LIMIT 1`,
      [username],
    );
    const user = rows[0];
    const isCorrect = user
      ? await bcrypt.compare(password, user.password_hash)
      : await bcrypt.compare(password, dummyPasswordHash);

    if (!user || !isCorrect) {
      throw new ApiError(401, 'Username หรือ Password ไม่ถูกต้อง');
    }

    await pool.query(
      'UPDATE users SET last_login_at = NOW() WHERE username = ?',
      [user.username],
    );

    const token = jwt.sign(
      {
        role: user.role,
        ver: Number(user.token_version),
      },
      config.jwtSecret,
      {
        algorithm: 'HS256',
        subject: user.username,
        expiresIn: config.jwtExpiresIn,
        issuer: 'rmutt-save-energy-api',
        audience: 'rmutt-save-energy-app',
      },
    );

    response.json({
      token,
      user: publicUser(user),
    });
  }),
);
```

| บรรทัด | ความหมาย |
|---|---|
| 24–25 | `dummyPasswordHash` คือ bcrypt hash (cost 12) ของรหัสสุ่มที่ไม่มีใครรู้ ใช้เป็นตัว "หลอกให้เสียเวลาเท่ากัน" |
| 27–33 | `loginLimiter`: หน้าต่าง 15 นาที (`windowMs`) อนุญาต 10 ครั้ง (`limit`) ต่อ IP ครั้งที่ 11 ได้ 429 พร้อมข้อความในช่อง `message` `standardHeaders: 'draft-7'` ส่ง header `RateLimit` มาตรฐานให้ client รู้โควตา `legacyHeaders: false` ปิด `X-RateLimit-*` แบบเก่า **นับทุกครั้งที่เรียก ทั้งสำเร็จและไม่สำเร็จ** (ต่างจาก `passwordConfirmLimiter`) |
| 54–56 | ลำดับ: path `/login` → `loginLimiter` → handler limiter มาก่อน เพื่อให้คนที่เดารหัสถูกตัดก่อนจะเสียเวลา bcrypt |
| 58 | `request.body?.username` `?.` (optional chaining) = ถ้า `body` เป็น `undefined` (ไม่ได้ส่ง JSON) ให้ผลเป็น `undefined` แทนที่จะ error `cleanString` ตัดช่องว่างและจำกัดไม่เกิน 100 ตัว |
| 59–61 | ต้องเป็น string จริง ถ้าส่งตัวเลข/อ็อบเจกต์มา ถือเป็นว่าง (กัน NoSQL-style injection และ error แปลก ๆ) |
| 63 | ว่าง หรือรหัสยาวเกิน 256 ตัว → 400 ขีดบนกัน DoS ด้วยรหัสยาวมหาศาลให้ bcrypt คำนวณ |
| 67–74 | ค้นหาด้วย username (ผูก `?`) และ `is_active = 1` บัญชีที่ถูกปิดจึงล็อกอินไม่ได้ `LIMIT 1` หยุดค้นเมื่อเจอ (username เป็น PK อยู่แล้ว) |
| 76–78 | **จุดสำคัญ:** ถ้าไม่พบผู้ใช้ ก็ยังเรียก `bcrypt.compare` กับ hash หลอก ผลคือเวลาตอบของ "username ไม่มีจริง" กับ "รหัสผิด" ใกล้เคียงกัน ผู้โจมตีใช้เวลาตอบเดาไม่ได้ว่า username นี้มีในระบบหรือไม่ (ป้องกัน user enumeration แบบ timing) |
| 80–82 | ข้อความเดียวกัน `Username หรือ Password ไม่ถูกต้อง` ทั้งสองกรณี เหตุผลเดียวกัน คืนรหัส 401 |
| 84–87 | บันทึกเวลาเข้าสู่ระบบล่าสุด (`NOW()` คือเวลาของ DB) |
| 89–102 | `jwt.sign(payload, secret, options)`: payload มี `role` และ `ver`; ส่วน `sub` (ผ่าน `subject:`), `exp` (จาก `expiresIn`), `iss`, `aud` ใส่ผ่านตัวเลือก `iat` ใส่ให้อัตโนมัติ |
| 104–107 | ตอบ `{ token, user }` ผ่าน `publicUser` (ไม่มี hash) แอปเก็บ token ไว้ แนบ header ทุกครั้งที่เรียก |

### 6. Route CRUD ตัวอย่าง: `POST /api/rooms` (และ DELETE)

**ไฟล์ `backend/src/routes/rooms.js` บรรทัด 84–120**

```js:84
roomsRouter.post(
  '/',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const input = validateRoomInput(request.body);
    const existingRows = await pool.query(
      'SELECT room_number FROM rooms WHERE room_number = ? LIMIT 1',
      [input.roomNumber],
    );
    if (existingRows[0]) {
      throw new ApiError(409, `มีห้อง ${input.roomNumber} อยู่แล้ว`);
    }

    await pool.query(
      `INSERT INTO rooms
         (room_number, floor_number, room_index, room_type,
          created_by, updated_by)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        input.roomNumber,
        input.floorNumber,
        input.roomIndex,
        input.roomType,
        request.authUser.username,
        request.authUser.username,
      ],
    );

    response.status(201).json({
      room: {
        ...input,
        airConditionerCount: 0,
        scheduleCount: 0,
      },
    });
  }),
);
```

| บรรทัด | ความหมาย |
|---|---|
| 15 (บนสุดไฟล์) | `roomsRouter.use(authenticate)` ทุก route ในไฟล์ต้องผ่านการล็อกอินก่อน |
| 85–86 | ลำดับ middleware ของ route นี้: (authenticate จาก `use`) → `requireAdmin` → handler เฉพาะแอดมินจึงเพิ่มห้องได้ |
| 88 | `validateRoomInput(request.body)` (ใน `utils/room.js`) ตรวจและ normalize: รหัสห้องแปลงเป็นตัวพิมพ์ใหญ่ (`cl503` → `CL503`) ต้องตรง `^[A-Z0-9][A-Z0-9_-]{1,19}$`, ชั้น 0–99, ลำดับ 0–9999, ประเภทห้อง 1–100 ตัว ไม่ผ่านจะ throw `ApiError 400` ออกจาก handler ทันที |
| 89–96 | เช็กห้องซ้ำก่อน เพื่อตอบ 409 พร้อมข้อความที่เข้าใจได้ (ถ้าปล่อยให้ `INSERT` ล้มเอง จะได้ error ดิบของ DB) |
| 97–110 | `INSERT` ด้วย `?` ทุกค่า (parameter binding) บันทึกผู้สร้าง/ผู้แก้ไขล่าสุด (`created_by`, `updated_by`) จาก `request.authUser` (ที่ `authenticate` แนบมา) ไม่รับจาก body เพราะผู้ใช้ปลอมได้ |
| 112–118 | ตอบ 201 พร้อมห้องที่เพิ่ง สร้าง (`...input` คือ spread คัดลอกฟิลด์ทั้งหมดของ `input`) ห้องใหม่ย่อมยังไม่มีแอร์/ตารางเรียน จึงใส่ 0 ได้เลยโดยไม่ query ซ้ำ |

**ตรรกะเด่นของ route ข้างเคียงในไฟล์เดียวกัน**

- `PUT /:roomNumber`: แก้ได้เฉพาะ `floorNumber`, `roomIndex`, `roomType` (เรียก `validateRoomInput(body, {requireNumber:false})` และใช้รหัสห้องจาก URL ไม่ใช่จาก body) รหัสห้องเป็นคีย์หลักจึงเปลี่ยนไม่ได้
- `DELETE /:roomNumber` ใช้ `withTransaction`: ล็อกแถวห้อง (`FOR UPDATE`) → ลบแอร์/เซ็นเซอร์ที่สถานะ `removed` ทิ้งก่อน → นับแอร์ ตารางเรียน เซ็นเซอร์ที่เหลือ → ถ้ามี ตอบ 409 พร้อมจำนวน (ต้องให้ผู้ใช้ลบข้อมูลที่ผูกอยู่ก่อน) → ไม่มีจึง `DELETE` ห้อง ตอบ 204 ทำใน transaction เพื่อไม่ให้ระหว่างนับกับลบ มีคนเพิ่มแอร์เข้าห้องนั้นพอดี
- `GET /` เป็น query ใหญ่: `rooms` LEFT JOIN `air_conditioners`, `class_schedules`, `occupancy_sensors` แล้ว `GROUP BY` ห้อง ใช้ `COUNT(DISTINCT CASE WHEN ... END)` นับแอร์ที่ไม่ถูก `removed` และที่กำลังทำงาน และ `MIN/MAX(CASE ...)` ดึงนาฬิกานับถอยหลังปิดแอร์ (`auto_off_deadline_at`) ที่ใกล้สุดและข้อมูลเซ็นเซอร์ของห้อง แล้วส่งผ่าน `publicRoom()` (ใน `utils/room.js`) แปลงเป็น camelCase และคำนวณ `autoOffSecondsRemaining`/`autoOffPhase` ให้หน้าจอแสดงนับถอยหลังได้ **ทำไมใช้ SQL เดียว:** หน้ารายการห้องต้องการทั้งหมดในหนเดียว ถ้าวนถามทีละห้อง (N+1 query) จะช้าเมื่อห้องมากขึ้น

### 7. ตัวอย่างเทสต์: `profile-email.test.js`

**ไฟล์ `backend/test/profile-email.test.js` บรรทัด 7–15**

```js:7
process.env.JWT_SECRET = 'test-jwt-secret-'.padEnd(48, 'x');
process.env.OTP_PEPPER = 'test-otp-pepper-'.padEnd(48, 'y');

const bcrypt = (await import('bcryptjs')).default;
const jwt = (await import('jsonwebtoken')).default;
const { pool } = await import('../src/db.js');
const { app } = await import('../src/app.js');

const passwordHash = await bcrypt.hash('correct-password', 4);
```

**ไฟล์ `backend/test/profile-email.test.js` บรรทัด 33–46**

```js:33
  pool.query = async (sql, params = []) => {
    if (/UPDATE users/.test(sql)) {
      user = {
        ...user,
        first_name: params[0],
        last_name: params[1],
        email: params[2],
        phone: params[3],
      };
      return { affectedRows: 1 };
    }
    if (/FROM users/.test(sql)) return [user];
    throw new Error(`unexpected SQL: ${sql}`);
  };
```

**ไฟล์ `backend/test/profile-email.test.js` บรรทัด 90–94**

```js:90
test('เปลี่ยนอีเมลโดยไม่ใส่รหัสผ่าน ถูกปฏิเสธ', async () => {
  const result = await patchProfile({ email: 'attacker@example.com' });
  assert.equal(result.status, 400);
  assert.equal(user.email, 'alice@example.com');
});
```

นอกจากนี้ `before(...)` (บรรทัด 21) สร้างผู้ใช้ปลอม, แทน `pool.query`, เปิดเซิร์ฟเวอร์ที่บรรทัด 48 และออก token ที่บรรทัด 51

| ตอน | ความหมาย |
|---|---|
| ตั้ง `process.env.JWT_SECRET/OTP_PEPPER` | ต้องตั้ง **ก่อน** โหลด `app.js` เพราะ `config.js` อ่าน env ตอน import |
| `await import(...)` แทน `import` ด้านบน | `import` แบบ static ถูกยกไปทำก่อนโค้ดทุกบรรทัด ทำให้ตั้ง env ไม่ทัน การ `import()` แบบ dynamic คือฟังก์ชันที่ทำตามลำดับบรรทัด ใช้คู่กับ top-level `await` |
| `bcrypt.hash('correct-password', 4)` | cost 4 (แทน 12) ให้เทสต์เร็ว hash นี้ใช้ได้กับ `bcrypt.compare` ใน route จริง |
| `before(...)` / `after(...)` | hook ของ `node:test`: รันครั้งเดียวก่อน/หลังเทสต์ทั้งไฟล์ |
| `pool.query = async (...) => ...` | **แทนที่ฐานข้อมูลจริงด้วยของปลอม** ที่จำผู้ใช้หนึ่งคนไว้ในตัวแปร ทำได้เพราะ `pool` เป็นอ็อบเจกต์ธรรมดา (ดู `db.js`) ถ้า SQL ไม่ตรงรูปแบบที่คาดจะ throw (เทสต์ล้ม) กันโค้ดแอบยิง SQL ที่ไม่ได้คิดไว้ ลำดับ `UPDATE users` ก่อน `FROM users` สำคัญ เพราะ `UPDATE ... FROM` ไม่มี แต่ `SELECT ... FROM users` มี |
| `app.listen(0, '127.0.0.1')` | พอร์ต 0 = ให้ระบบเลือกพอร์ตว่าง ไม่ชนกับเทสต์ไฟล์อื่นที่รันขนาน |
| `jwt.sign(... ver: 1 ...)` | ออก token จริงด้วย secret ของเทสต์ ผ่าน `authenticate` ด้วยการเทียบกับ `token_version: 1` ของผู้ใช้ปลอม จึงเทสต์ `authenticate` จริงไปด้วย |
| `fetch(...)` | `fetch` ในตัว Node ยิง HTTP จริงเข้าเซิร์ฟเวอร์ที่เปิดไว้ จึงเป็น integration test เล็ก ๆ ที่ครอบ helmet → json → authenticate → limiter → handler |
| `assert.equal(user.email, 'alice@example.com')` | นอกจากเช็กสถานะ 400 ยังเช็กว่าข้อมูลใน "DB" **ไม่ถูกเปลี่ยน** นี่คือสิ่งที่สำคัญจริง |

### 8. อัปโหลดเฟิร์มแวร์ `POST /api/firmware` (เพิ่ม 14 ต.ค. 2569)

เดิมการวางไฟล์ `.bin` ต้อง `scp` เข้าเซิร์ฟเวอร์ (ต้องมีบัญชี SSH) ตอนนี้แอดมินลากไฟล์วางในหน้า "เฟิร์มแวร์" ของเว็บได้ เส้นนี้จึงเป็นเส้นแรกที่ "เขียนไฟล์ลงดิสก์ของเซิร์ฟเวอร์ตามที่ผู้ใช้ส่งมา" ต้องตรวจหนักกว่าเส้นอื่น

**ไฟล์ `backend/src/routes/firmware.js` บรรทัด 45–68** (ตรวจก่อนเขียน)

```js:45
firmwareRouter.post(
  '/',
  express.raw({ type: () => true, limit: FIRMWARE_MAX_BYTES + 1024 }),
  asyncHandler(async (request, response) => {
    if (!config.firmwareDir) {
      throw new ApiError(
        503,
        'เซิร์ฟเวอร์ยังไม่ได้ตั้ง FIRMWARE_DIR จึงเก็บไฟล์เฟิร์มแวร์ไม่ได้',
      );
    }
    const fileName = validateFirmwareFileName(
      decodeHeader(request.get('x-file-name')),
    );
    const kind = firmwareKindOf(fileName);
    const expected = String(request.query.kind ?? '').trim();
    if (expected && expected !== kind) {
      throw new ApiError(
        400,
        `ชื่อไฟล์บอกว่าเป็นของ${FIRMWARE_KIND_LABELS[kind]} `
          + `แต่กำลังอัปโหลดในหมวด${FIRMWARE_KIND_LABELS[expected] ?? expected} `
          + '(ไฟล์เซ็นเซอร์ต้องมีคำว่า occ ไฟล์สายแอร์ต้องมีคำว่า wired)',
      );
    }
    validateFirmwareImage(request.body);
```

| บรรทัด | โค้ด/คำสั่ง | ความหมาย |
|---|---|---|
| 47 | `express.raw({ type: () => true, limit: ... })` | middleware เฉพาะเส้นนี้ อ่าน body เป็น `Buffer` (ไบต์ดิบ) ไม่ว่า `Content-Type` จะเป็นอะไร (`type: () => true`) เพดาน `0x1F0000 + 1024` ไบต์ ส่วน `express.json` ทั้งแอปจำกัด 256 KB ซึ่งเล็กเกินไฟล์เฟิร์มแวร์ (ราว 1–2 MB) เพิ่ม 1024 ไว้เผื่อ เพื่อให้ไฟล์ที่ใหญ่เกินนิดเดียวยังเข้ามาถึง `validateFirmwareImage` แล้วได้ข้อความไทยที่อ่านรู้เรื่อง แทน error ทั่วไปของ Express |
| 49–54 | `if (!config.firmwareDir)` | ไม่ได้ตั้ง `FIRMWARE_DIR` (เช่น รันบนเครื่องพัฒนา) ตอบ 503 เพราะไม่มีที่เก็บ |
| 55–57 | `validateFirmwareFileName(decodeHeader(request.get('x-file-name')))` | ชื่อไฟล์อยู่ใน header `X-File-Name` แบบ percent-encoding (วิธีเดียวกับการนำเข้าตารางเรียน เพราะ header HTTP ใส่อักษรไทยตรง ๆ ไม่ได้) ถอดแล้วต้องผ่าน regex ชื่อไฟล์ ชื่อจึงมีได้แค่ `A–Z a–z 0–9 . _ -` ลงท้าย `.bin` และไม่มี `..` หรือ `/` |
| 58 | `firmwareKindOf(fileName)` | ชนิดจากชื่อ: `occ` → `occupancy`, `wired`/`slm8` → `wired`, นอกนั้น `air` |
| 59–67 | `request.query.kind` | หน้าเว็บส่งชนิดของแท็บที่ผู้ใช้อยู่ (`?kind=air`, `wired` หรือ `occupancy`) ถ้าไม่ตรงกับชนิดจากชื่อ ตอบ 400 พร้อมบอกกฎตั้งชื่อ `?? expected` ใช้ค่าที่ส่งมาเองถ้าไม่ใช่ชนิดที่รู้จัก |
| 68 | `validateFirmwareImage(request.body)` | ตรวจเนื้อไฟล์: ไม่ว่าง, ไม่เกิน `0x1F0000` (413), ยาว ≥ 256 ไบต์ และไบต์แรกเป็น `0xE9` |

> [!WHY]
> ทำไมเช็กไบต์แรก `0xE9`: ไฟล์โปรแกรมของ ESP32 (ESP image) ขึ้นต้นด้วย "magic byte" `0xE9` เสมอ การเช็กหนึ่งไบต์นี้กันไฟล์ผิดประเภทได้เกือบหมด เช่น ลากไฟล์ `.merged.bin` มาผิด (ไฟล์นี้รวม bootloader ไว้ข้างหน้า ซึ่งบน ESP32 อยู่ที่ offset 0x1000 ไบต์แรกจึงไม่ใช่ `0xE9`) ไฟล์นั้นใช้ OTA ไม่ได้ ถ้าบอร์ดดาวน์โหลดไป `Update` ของ ESP32 จะปฏิเสธอยู่ดี แต่กว่าจะรู้ต้องรอบอร์ดลองจริง เช็กที่ Backend จึงบอกผู้ใช้ได้ทันทีตอนอัปโหลด

> [!WHY]
> ทำไมเพดาน `0x1F0000`: ตาราง `partitions.csv` ของเฟิร์มแวร์แบ่งช่องโปรแกรม `app0` และ `app1` ไว้ช่องละ `0x1F0000` ไบต์ (OTA เขียนโปรแกรมใหม่ลงช่องที่ไม่ได้ใช้อยู่ แล้วสลับ) ไฟล์ใหญ่กว่านั้นใส่ไม่ลง ข้อความ error แสดงเป็น `Math.floor(0x1F0000 / 1024)` = 1984 KB

**ไฟล์ `backend/src/routes/firmware.js` บรรทัด 70–102** (เขียนไฟล์)

```js:70
    const target = path.join(config.firmwareDir, fileName);
    if (request.query.replace !== '1' && await fileExists(target)) {
      throw new ApiError(
        409,
        `มีไฟล์ ${fileName} อยู่แล้ว ถ้าต้องการแทนที่ให้ยืนยันการเขียนทับ`,
      );
    }

    // เขียนลงไฟล์ชั่วคราวก่อนแล้วค่อยเปลี่ยนชื่อ บอร์ดที่กำลังดาวน์โหลด
    // ไฟล์ชื่อเดิมอยู่จะไม่ได้ไฟล์ที่เขียนไปครึ่งเดียว
    // (ชื่อชั่วคราวไม่ลงท้าย .bin จึงไม่โผล่ในรายการไฟล์)
    const temporary = `${target}.${process.pid}.part`;
    try {
      await fs.writeFile(temporary, request.body, { mode: 0o644 });
      await fs.rename(temporary, target);
    } catch (error) {
      await fs.rm(temporary, { force: true }).catch(() => {});
      if (error?.code === 'EACCES' || error?.code === 'EROFS') {
        throw new ApiError(
          500,
          'Backend เขียนโฟลเดอร์ firmware ไม่ได้ (ตรวจว่า mount แบบอ่านอย่างเดียว '
            + 'หรือสิทธิ์ของโฟลเดอร์ /opt/rmutt/firmware)',
        );
      }
      throw error;
    }

    console.log(
      `[firmware] อัปโหลด ${fileName} (${request.body.length} bytes) `
        + `โดย ${request.authUser.username}`,
    );
    const file = (await listFirmwareFiles()).find((item) => item.name === fileName);
    response.status(201).json({ file });
```

| บรรทัด | โค้ด/คำสั่ง | ความหมาย |
|---|---|---|
| 70 | `path.join(config.firmwareDir, fileName)` | ต่อ path ปลายทาง ปลอดภัยเพราะ `fileName` ผ่าน regex แล้ว ไม่มี `/` หรือ `..` จึงหลุดออกนอกโฟลเดอร์ไม่ได้ |
| 71–76 | `request.query.replace !== '1' && await fileExists(target)` | มีไฟล์ชื่อเดียวกันอยู่แล้ว ตอบ 409 เว็บจะถามผู้ใช้ "เขียนทับไหม" แล้วส่งใหม่พร้อม `?replace=1` กันเผลอทับไฟล์รุ่นที่บอร์ดใช้อยู่ |
| 81 | `` `${target}.${process.pid}.part` `` | ชื่อไฟล์ชั่วคราว ลงท้าย `.part` (ไม่ใช่ `.bin`) `listFirmwareFiles` จึงไม่แสดงในรายการ และใส่เลขโปรเซส (`process.pid`) ไว้ในชื่อ |
| 83 | `fs.writeFile(temporary, request.body, { mode: 0o644 })` | เขียนทั้งก้อน `0o644` = เลขฐานแปด เจ้าของ (user `node` uid 1000) อ่านเขียนได้ คนอื่นอ่านได้อย่างเดียว (Caddy ซึ่งอยู่คนละ container และ mount โฟลเดอร์เดียวกันแบบอ่านอย่างเดียว ต้องอ่านได้เพื่อเสิร์ฟให้บอร์ด) |
| 84 | `fs.rename(temporary, target)` | เปลี่ยนชื่อเป็นชื่อจริง การ rename ในโฟลเดอร์เดียวกันบน Linux เป็น atomic คือคนอื่นเห็นไฟล์เก่าทั้งก้อนหรือไฟล์ใหม่ทั้งก้อน ไม่มีครึ่ง ๆ |
| 85–95 | `catch` | ลบไฟล์ชั่วคราวทิ้ง (`force: true` ไม่ error ถ้าไม่มี) ถ้าสาเหตุคือไม่มีสิทธิ์ (`EACCES`) หรือ mount แบบอ่านอย่างเดียว (`EROFS`) ตอบ 500 พร้อมบอกจุดที่ต้องตรวจ ซึ่งคือสองเรื่องที่ต้องแก้ตอน deploy รุ่นนี้ (ดูบท Deploy) |
| 97–100 | `console.log(...)` | log ชื่อไฟล์ ขนาด และ **ใครอัปโหลด** ไว้ตรวจย้อนหลัง |
| 101–102 | `listFirmwareFiles().find(...)` | ตอบ 201 พร้อมข้อมูลไฟล์ในรูปเดียวกับรายการ (มี `kind`, `version`) ให้หน้าเว็บเพิ่มแถวได้ทันที |

> [!WHY]
> ทำไมเขียนไฟล์ชั่วคราวก่อน: บอร์ดหลายตัวอาจกำลังดาวน์โหลดไฟล์ชื่อนี้อยู่ (อัปเดตหลายบอร์ดพร้อมกัน) ถ้าเขียนทับไฟล์เดิมตรง ๆ บอร์ดที่อ่านกลางทางจะได้ไฟล์ครึ่งเก่าครึ่งใหม่ แม้ ESP32 จะตรวจ checksum แล้วปฏิเสธ แต่ OTA ของบอร์ดนั้นก็ล้มโดยไม่จำเป็น การ rename ทำให้ผู้อ่านเห็นไฟล์สมบูรณ์เสมอ

> [!NOTE]
> ไฟล์ที่อัปโหลดชื่อยังไม่มีเลขรุ่น (เช่น `rmutt_esp32_air.ino.bin` ตรงจาก Arduino IDE) หน้าเว็บจะถามรุ่นแล้วตั้งชื่อเป็น `<สเก็ตช์>-<รุ่น>.bin` ก่อนส่ง Backend ไม่ได้บังคับว่าต้องมีเลขรุ่น (`version` เป็น `null` ได้) แต่ถ้าไม่มี หน้าเว็บจะบอกไม่ได้ว่าบอร์ดไหนเก่ากว่าไฟล์

### 9. ลบอุปกรณ์ `DELETE /api/air-conditioners/:deviceId` และการล้างค่าบอร์ด (แก้ 13 ต.ค. 2569)

ก่อน 13 ต.ค. การลบอุปกรณ์ลบแค่ข้อมูลฝั่งเซิร์ฟเวอร์ ตัวบอร์ดยังจำ Wi-Fi, ที่อยู่ Broker, ชื่อผู้ใช้/รหัส MQTT และห้องไว้ใน NVS (หน่วยความจำถาวรของ ESP32) ตอนนี้ Backend สั่งบอร์ดล้างตัวเองด้วย

**ไฟล์ `backend/src/routes/air-conditioners.js` บรรทัด 413–448**

```js:413
airConditionersRouter.delete(
  '/:deviceId',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const deviceId = validateDeviceId(request.params.deviceId);
    const result = await pool.query(
      'DELETE FROM air_conditioners WHERE device_id = ?',
      [deviceId],
    );
    const deletedRows = Number(result.affectedRows ?? 0);
    // สั่งบอร์ดล้างค่าในตัวเองก่อนลบบัญชี MQTT (ลบบัญชีแล้วคำสั่งจะไปไม่ถึง)
    const board = await unprovisionDevice('air', deviceId);
    const retainedTopicsCleared = await clearRetainedAirTopics(deviceId);
    const mqttAccountRemoved = await removeDeviceAccount(deviceId);

    console.log(
      `[air] ลบ ${deviceId} โดย ${request.authUser.username}: `
        + `deletedRows=${deletedRows} `
        + `retainedTopicsCleared=${retainedTopicsCleared} `
        + `mqttAccountRemoved=${mqttAccountRemoved} `
        + `boardCleared=${board.acknowledged}`,
    );

    // ลบซ้ำถือว่าสำเร็จ เพื่อไม่ให้แอปค้างกับแถวที่หายไปแล้ว
    response.json({
      removed: true,
      deviceId,
      deletedRows,
      retainedTopicsCleared,
      mqttAccountRemoved,
      // true = บอร์ดยืนยันว่าล้างค่าแล้ว, false = บอร์ดออฟไลน์หรือไม่ตอบ
      // (ต้องล้างที่ตัวบอร์ดเอง: อัปโหลด firmware/reset หรือตั้งค่าใหม่ผ่านบลูทูธ)
      boardCleared: board.acknowledged,
    });
  }),
);
```

| บรรทัด | โค้ด/คำสั่ง | ความหมาย |
|---|---|---|
| 415 | `requireAdmin` | ลบอุปกรณ์ได้เฉพาะแอดมิน |
| 417 | `validateDeviceId(...)` | รหัสต้องเป็น `ESP32-` + ฐานสิบหก 12 ตัว ก่อนนำไปใช้ใน SQL และ topic |
| 418–422 | `DELETE FROM air_conditioners ...` | **ขั้น 1** ลบแถวก่อน `affectedRows` = จำนวนแถวที่ลบจริง (0 = ลบซ้ำ) |
| 424 | `await unprovisionDevice('air', deviceId)` | **ขั้น 2** ส่ง `{"action":"unprovision"}` ไปที่ `rmutt/ac/<id>/command` แล้วรอบอร์ดตอบ `{"unprovisioned":true}` ไม่เกิน 4 วินาที คืน `{sent, acknowledged}` ไม่โยน error |
| 425 | `clearRetainedAirTopics(deviceId)` | **ขั้น 3** ส่งข้อความว่างแบบ retained ไปทุก topic ของบอร์ด (`command`, `state`, `status`, `provision`, `provision-ack`, `schedule-status`) คืนจำนวนที่ล้างได้ |
| 426 | `removeDeviceAccount(deviceId)` | **ขั้น 4** ลบบัญชี MQTT ของบอร์ดใน Mosquitto Dynamic Security |
| 428–434 | `console.log(...)` | log ทุกผลรวม `boardCleared` ใช้ตรวจย้อนหลังว่าบอร์ดไหนยังอาจมีค่าค้าง |
| 437–446 | `response.json({... boardCleared: board.acknowledged })` | ตอบ 200 เสมอ (ลบซ้ำก็สำเร็จ) ฟิลด์ใหม่ `boardCleared` ให้แอปเตือนแอดมินเมื่อเป็น `false` ว่าต้องไปล้างที่ตัวบอร์ดเอง |

> [!WHY]
> ทำไมลำดับต้องเป็น ส่ง unprovision → รอ → ล้าง retained → ลบบัญชี MQTT:
> 1. **unprovision ต้องมาก่อนลบบัญชี** ลบบัญชีแล้ว Broker ตัดบอร์ดออกทันที และบอร์ดต่อกลับไม่ได้ คำสั่งล้างค่าจะไปไม่ถึงตลอดกาล
> 2. **ต้องรอคำตอบก่อนไปขั้นถัดไป** ถ้าลบบัญชีทันทีหลัง publish บอร์ดอาจยังไม่ทันได้รับข้อความ การรอ ack (หรือหมดเวลา 4 วินาที) ทำให้มั่นใจว่าบอร์ดที่ออนไลน์ได้รับและทำแล้ว
> 3. **ล้าง retained หลังบอร์ดล้างตัวเองเสร็จ** ระหว่างล้างค่า บอร์ดเองก็ publish ข้อความ (ack และล้าง retained ของ `status`/`state` ตัวเอง) แล้วตัดการเชื่อมต่อแบบปกติ (Broker จึงไม่ส่ง Last Will `online:false` ไปค้าง) Backend ล้าง retained ทุก topic เป็นขั้นสุดท้ายฝั่งข้อความ จึงไม่มีอะไรค้างให้บอร์ดรหัสเดิมเจอเมื่อเพิ่มกลับมา
> 4. **ลบแถวก่อนทั้งหมด** แอปเห็นว่าลบแล้วไม่ว่าบอร์ดจะตอบหรือไม่ และ status ที่บอร์ดส่งมาระหว่างรอจะ `UPDATE` แถวที่ไม่มีอยู่ จึงไม่มีผลอะไร

> [!NOTE]
> เส้นนี้ช้าลงได้สูงสุดประมาณ 4 วินาทีเมื่อบอร์ดออฟไลน์ (รอจนหมดเวลา) ถ้า Backend ไม่ได้ต่อ Broker อยู่ `unprovisionDevice` คืนทันทีโดยไม่รอ ส่วน `routes/occupancy-sensors.js` บรรทัด 291–326 เขียนเหมือนกันทุกขั้น ต่างแค่ใช้ `unprovisionDevice('occupancy', ...)` และ `clearRetainedOccupancyTopics`

## ลำดับการทำงานของ request

### `POST /api/auth/login`

```text
แอปส่ง  POST /api/auth/login   {"username":"...","password":"..."}
 1. helmet            → ใส่ security header ให้ response
 2. cors              → ตรวจ Origin (แอปมือถือไม่มี Origin = ผ่าน)
 3. express.json      → แปลง body เป็น request.body (ใหญ่เกิน 256KB → 413)
 4. app.use('/api/auth', authRouter) จับ prefix → authRouter.post('/login')
 5. loginLimiter      → นับต่อ IP: เกิน 10 ครั้ง/15 นาที → 429 จบ
 6. asyncHandler → handler:
      cleanString/ตรวจชนิด → 400 ถ้าขาด
      SELECT users WHERE username=? AND is_active=1
      bcrypt.compare (กับ hash จริง หรือ dummy)
      ไม่ผ่าน → ApiError 401
      UPDATE last_login_at
      jwt.sign → response.json({token,user})
 7. ถ้า throw ที่ขั้นใดก็ตาม → asyncHandler → next(error) → errorHandler → JSON {message}
```

### `GET /api/rooms`

```text
แอปส่ง  GET /api/rooms   Authorization: Bearer <token>
 1–3. helmet → cors → express.json (ไม่มี body)
 4. app.use('/api/rooms', roomsRouter) → roomsRouter.use(authenticate)
 5. authenticate:
      แยก Bearer → jwt.verify → SELECT users (is_active) → เทียบ token_version
      → request.authUser = publicUser(row) → next()
 6. roomsRouter.get('/'):  pool.query(SQL JOIN/GROUP BY) → rows.map(publicRoom)
 7. response.json({ rooms: [...] })  (200)
    ถ้า authenticate ล้ม → 401 ผ่าน errorHandler (handler ของ GET ไม่ถูกเรียกเลย)
```

## ระบบสมาชิก (Auth)

### ตัวเลข rate limit และความปลอดภัย

| ตัวจำกัด | ใช้กับ | หน้าต่าง | จำนวน | หมายเหตุ |
|---|---|---|---|---|
| `loginLimiter` | `POST /login` | 15 นาที | 10 | นับทุกครั้ง |
| `passwordConfirmLimiter` | `PATCH /me`, `POST /me/password` | 15 นาที | 10 | `skipSuccessfulRequests: true` นับเฉพาะที่ตอบผิด (status ≥ 400) |
| `resetLimiter` | `POST /forgot-password`, `/verify-otp`, `/reset-password` | 60 นาที | 8 | **ตัวนับเดียวใช้ร่วมกันทั้งสามเส้น** ต่อ IP |

| รายการ | ค่า |
|---|---|
| อายุ JWT | `JWT_EXPIRES_IN` ค่าเริ่มต้น `8h` |
| bcrypt cost | 12 |
| รหัสผ่านใหม่ | ≥ 8 ตัวอักษร และ ≤ 72 ไบต์ |
| OTP | 6 หลัก, อายุ `OTP_EXPIRES_MINUTES` (10 นาที), ผิดได้ไม่เกิน 5 ครั้งต่อคำขอ (`attempts >= 5` = ปฏิเสธ) |
| Reset token | 32 ไบต์สุ่ม (hex 64 ตัว) เก็บเฉพาะ HMAC hash |
| Body JSON สูงสุด | 256 KB |
| รหัสผ่านที่ login ยอมรับ | ยาวไม่เกิน 256 ตัวอักษร |

**เรื่องที่ควรรู้:** ตัวนับอยู่ใน RAM ของโปรเซส (รีสตาร์ท = นับใหม่ และถ้ารันหลายโปรเซสจะนับแยกกัน) ซึ่งพอสำหรับ Backend ตัวเดียว ตัวจำกัดนับตาม IP จึงต้องตั้ง `TRUST_PROXY` ให้ถูกตอน deploy หลัง Caddy

### ผังการลืมรหัสผ่าน (OTP flow)

```text
 [1] POST /api/auth/forgot-password  {identifier: username หรือ email}
       - สร้าง requestId (UUID) ก่อนค้นหา
       - ค้นผู้ใช้ (username = ? OR email = ?) ที่ is_active = 1
       - ถ้าพบและมีอีเมล:
           otp = createOtp()                    (6 หลัก)
           transaction: ปิด OTP เก่าที่ยังไม่ใช้ (used_at = NOW())
                        INSERT password_reset_otps (id=requestId, otp_hash=HMAC(otp), expires_at)
           sendPasswordResetOtp()  → อีเมล หรือ console
           ถ้าส่งไม่ได้ → DELETE แถวนั้น + console.error
       - ตอบ {requestId, message} เหมือนกันทุกกรณี (พบ/ไม่พบ)
 [2] POST /api/auth/verify-otp  {requestId, otp}
       - ตรวจรูปแบบ (uuid 36 ตัว / ตัวเลข 6 หลัก)
       - ไม่พบ/ใช้แล้ว/ผิด ≥5 ครั้ง/หมดอายุ → 400 "OTP ไม่ถูกต้องหรือหมดอายุแล้ว"
       - เทียบ HMAC ด้วย safeHashEquals; ผิด → attempts+1, 400
       - ถูก → resetToken = createResetToken(); เก็บ HMAC(resetToken) + verified_at
       - ตอบ {resetToken}
 [3] POST /api/auth/reset-password  {resetToken, newPassword}
       - ตรวจ token เป็น hex 64 ตัว และรหัสใหม่ผ่าน isValidNewPassword
       - bcrypt.hash(newPassword, 12)
       - transaction: SELECT ... WHERE reset_token_hash = ? FOR UPDATE
           ต้อง ไม่ used, verified แล้ว, ไม่หมดอายุ
           UPDATE users: password_hash, password_changed_at, token_version + 1
           UPDATE password_reset_otps SET used_at = NOW()
       - ตอบ "เปลี่ยนรหัสผ่านสำเร็จ"
```

เหตุผลของแต่ละขั้น:

- **ตอบเหมือนกันทั้งกรณีพบ/ไม่พบ ผู้ใช้** (และตอบ `requestId` ทุกครั้ง) ไม่ให้คนนอกใช้หน้านี้สำรวจว่ามีบัญชีไหนในระบบ ราคาที่จ่ายคือ ถ้าอีเมลส่งไม่ออก ผู้ใช้จะไม่รู้สาเหตุ (จึงต้องตรวจ `SMTP_FROM` ตอนเริ่มระบบ)
- **สองขั้น (verify แล้วค่อย reset ด้วย token แยก):** token ของขั้นที่ 3 ไม่ใช่ OTP 6 หลักที่เดาได้ 1 ใน 1,000,000 แต่เป็น 256 บิต และ OTP ผ่านการจำกัดจำนวนครั้งผิดไว้แล้ว
- **`FOR UPDATE` ใน transaction:** ล็อกแถวไว้ ถ้ามีสองคำขอ reset ด้วย token เดียวกันพร้อมกัน ตัวที่สองจะรอและพบว่า `used_at` ถูกตั้งแล้ว จึงใช้ซ้ำไม่ได้
- **`token_version + 1`:** ทุกเครื่องที่ล็อกอินค้างอยู่ต้องล็อกอินใหม่ (เผื่อบัญชีถูกแฮ็กอยู่)
- **ปิด OTP เก่าก่อนสร้างใหม่:** มี OTP ที่ใช้ได้ทีละใบต่อผู้ใช้
- **หมายเหตุ:** หมดอายุของ reset token ใช้ `expires_at` ของ OTP เดิม จึงต้องทำสามขั้นให้จบภายใน 10 นาทีนับจากขอ OTP

### เปลี่ยนอีเมลและรหัสผ่านโดยรู้รหัสเดิม

- `PATCH /api/auth/me`: แก้ชื่อ นามสกุล อีเมล เบอร์ (ไม่แตะ role/isActive) ถ้า **อีเมลเปลี่ยน** (เทียบแบบตัวพิมพ์เล็ก ตัดช่องว่าง) ต้องส่ง `currentPassword` และ `bcrypt.compare` ผ่าน มิฉะนั้น 400 เหตุผล (จากคอมเมนต์ในโค้ด): OTP ลืมรหัสผ่านส่งไปที่อีเมล ถ้าใครได้ token ไป (เครื่องที่ลืมออกจากระบบ) แล้วเปลี่ยนอีเมลเป็นของตัวเองได้ ก็ใช้ "ลืมรหัสผ่าน" ยึดบัญชีถาวร อีเมลซ้ำ (`ER_DUP_ENTRY` จาก `UNIQUE KEY uq_users_email`) ตอบ 409
- `POST /api/auth/me/password`: ต้องส่ง `currentPassword` และ `newPassword` ตรวจ: รหัสเดิมไม่ว่าง ≤ 256, รหัสใหม่ผ่าน `isValidNewPassword`, รหัสใหม่ต้องไม่เท่ารหัสเดิม แล้วเทียบ bcrypt ผ่านจึง `UPDATE` พร้อม `token_version + 1` (เครื่องอื่นหลุด แต่ token ที่เครื่องปัจจุบันใช้อยู่ก็หลุดด้วย แอปต้องให้ล็อกอินใหม่)
- ทั้งสองเส้นผ่าน `passwordConfirmLimiter` ที่นับเฉพาะครั้งที่ล้มเหลว ผู้ใช้ที่ถูกต้องไม่ถูกจำกัด แต่คนที่ถือ token ที่ขโมยมาเดารหัสจะติดเพดาน 10 ครั้ง/15 นาที

## ตารางอ้างอิง API ทั้งหมด

คำอธิบายคอลัมน์: **ล็อกอิน** = ต้องส่ง Bearer token, **admin** = ต้องเป็น role admin เพิ่ม (`requireAdmin`) ทุก path ขึ้นต้นด้วย `/api` ส่วน path ที่นำหน้าด้วยโดเมนเต็มไม่มี (เรียกผ่าน Caddy)

### ระบบ / สาธารณะ / สมาชิก

| Method | Path | ล็อกอิน | admin | หน้าที่ | ตาราง |
|---|---|---|---|---|---|
| GET | `/api/health` | ไม่ | ไม่ | ตรวจว่า API + DB ยังทำงาน และสถานะ MQTT | (SELECT 1) |
| GET | `/api/public/admin-contact` | ไม่ | ไม่ | ชื่อ-เบอร์แอดมินคนแรก (เรียงตาม username) ที่มีเบอร์ ใช้ในหน้าล็อกอิน | `users` |
| POST | `/api/auth/login` | ไม่ (limiter 10/15น.) | ไม่ | ล็อกอิน ได้ token + user | `users` |
| GET | `/api/auth/me` | ใช่ | ไม่ | ข้อมูลผู้ใช้ปัจจุบัน | `users` |
| PATCH | `/api/auth/me` | ใช่ | ไม่ | แก้โปรไฟล์ตัวเอง (เปลี่ยนอีเมลต้องใส่รหัสปัจจุบัน) | `users` |
| POST | `/api/auth/me/password` | ใช่ | ไม่ | เปลี่ยนรหัสผ่านด้วยรหัสเดิม | `users` |
| POST | `/api/auth/forgot-password` | ไม่ (limiter 8/ชม.) | ไม่ | ขอ OTP ทางอีเมล | `users`, `password_reset_otps` |
| POST | `/api/auth/verify-otp` | ไม่ (limiter ร่วม) | ไม่ | ตรวจ OTP แล้วรับ reset token | `password_reset_otps` |
| POST | `/api/auth/reset-password` | ไม่ (limiter ร่วม) | ไม่ | ตั้งรหัสใหม่ด้วย reset token | `users`, `password_reset_otps` |

### ผู้ใช้ (`routes/users.js` — `use(authenticate)` และ `use(requireAdmin)` ทั้งไฟล์)

| Method | Path | ล็อกอิน | admin | หน้าที่ | ตาราง |
|---|---|---|---|---|---|
| GET | `/api/users` | ใช่ | ใช่ | รายชื่อผู้ใช้ทั้งหมด (admin ก่อน, ใช้งานก่อน, ตาม username) | `users` |
| POST | `/api/users` | ใช่ | ใช่ | สร้างผู้ใช้ใหม่ (201) | `users` |
| PATCH | `/api/users/:username` | ใช่ | ใช่ | เปลี่ยน role / is_active (ขึ้น `token_version`) | `users` |
| DELETE | `/api/users/:username` | ใช่ | ใช่ | ลบผู้ใช้ (204) | `users` |

### ห้อง ตารางเรียน การใช้ห้อง

| Method | Path | ล็อกอิน | admin | หน้าที่ | ตาราง |
|---|---|---|---|---|---|
| GET | `/api/rooms` | ใช่ | ไม่ | รายการห้อง + จำนวนแอร์/ตาราง + สถานะเซ็นเซอร์/นับถอยหลัง | `rooms`, `air_conditioners`, `class_schedules`, `occupancy_sensors` |
| POST | `/api/rooms` | ใช่ | ใช่ | เพิ่มห้อง (201, ซ้ำ 409) | `rooms` |
| PUT | `/api/rooms/:roomNumber` | ใช่ | ใช่ | แก้ชั้น/ลำดับ/ประเภท | `rooms` |
| DELETE | `/api/rooms/:roomNumber` | ใช่ | ใช่ | ลบห้อง (มีของผูกอยู่ 409) | `rooms`, `air_conditioners`, `occupancy_sensors`, `class_schedules` |
| GET | `/api/schedules` | ใช่ | ไม่ | ตารางเรียน กรองด้วย `floor`, `day` + ข้อมูลภาคเรียนที่ใช้ | `class_schedules`, `rooms`, `system_settings` |
| POST | `/api/schedules` | ใช่ | ใช่ | เพิ่มคาบเรียน (ห้องต้องมี, เวลาห้ามซ้อน 409) | `class_schedules`, `rooms` |
| PUT | `/api/schedules/:id` | ใช่ | ใช่ | แก้คาบเรียน | `class_schedules`, `rooms` |
| DELETE | `/api/schedules/:id` | ใช่ | ใช่ | ลบคาบเดียว (204) | `class_schedules` |
| DELETE | `/api/schedules` | ใช่ | ใช่ | ลบตารางเรียนทั้งหมด + ล้างข้อมูลภาคเรียน | `class_schedules`, `system_settings` |
| POST | `/api/schedules/import/preview` | ใช่ | ใช่ | อัปโหลดไฟล์ (raw ≤ 8 MB, ชื่อไฟล์ใน header `x-file-name`) แล้วดูตัวอย่างก่อนนำเข้า | `rooms` (อ่าน) |
| POST | `/api/schedules/import/commit` | ใช่ | ใช่ | นำเข้าตารางจริงใน transaction (201) สร้างห้องใหม่ถ้าอนุญาต | `class_schedules`, `rooms`, `academic_terms`, `system_settings` |
| GET | `/api/schedules/terms` | ใช่ | ไม่ | ปฏิทินภาคเรียน | `academic_terms` |
| PUT | `/api/schedules/terms` | ใช่ | ใช่ | เพิ่ม/แก้ภาคเรียน (upsert) | `academic_terms` |
| DELETE | `/api/schedules/terms?semester=` | ใช่ | ใช่ | ลบภาคเรียน (204) | `academic_terms` |
| GET | `/api/bookings` | ใช่ | ไม่ | รายการใช้ห้องนอกตาราง กรอง `from`/`to` (YYYY-MM-DD) | `room_bookings` |
| POST | `/api/bookings` | ใช่ | ใช่ | เพิ่มการใช้ห้อง (201) + จำนวนครั้งที่เกิดขึ้น | `room_bookings`, `rooms` |
| PUT | `/api/bookings/:id` | ใช่ | ใช่ | แก้ | `room_bookings`, `rooms` |
| DELETE | `/api/bookings/:id` | ใช่ | ใช่ | ลบ (204) | `room_bookings` |

### อุปกรณ์ (แอร์ / เซ็นเซอร์ / firmware)

| Method | Path | ล็อกอิน | admin | หน้าที่ | ตาราง |
|---|---|---|---|---|---|
| GET | `/api/air-conditioners` | ใช่ | ไม่ | รายการแอร์ทุกเครื่อง พร้อมค่า PZEM, สถานะ, นับถอยหลัง และ `controlType` (`ir`/`wired`, เพิ่ม 11 ต.ค. 2569) | `air_conditioners` |
| POST | `/api/air-conditioners/reservations` | ใช่ | ใช่ | จองอุปกรณ์ให้ ESP32 ตอน provisioning: ออก token ใช้ได้ 15 นาที + ข้อมูล MQTT | `air_conditioners`, `rooms` |
| POST | `/api/air-conditioners/:deviceId/command` | ใช่ | **ไม่** | สั่งแอร์ผ่าน MQTT (202) ใครล็อกอินก็สั่งได้ แอร์ `DAIKIN_WIRED` รับเฉพาะ Cool/Dry/Fan, ไม่มีพัดลม Turbo, สวิง Auto/Off (แก้ 11 ต.ค. 2569) | `air_conditioners` |
| POST | `/api/air-conditioners/:deviceId/setup-mode` | ใช่ | ใช่ | สั่งบอร์ดเข้าโหมดตั้งค่า (202) | `air_conditioners` |
| PATCH | `/api/air-conditioners/:deviceId` | ใช่ | ใช่ | แก้ชื่อ / เปิด-ปิด auto-off รายเครื่อง | `air_conditioners` |
| POST | `/api/air-conditioners/:deviceId/ota` | ใช่ | ใช่ | สั่งอัปเดตเฟิร์มแวร์ผ่าน MQTT (202) ไฟล์ต้องตรงชนิดบอร์ด: `DAIKIN_WIRED` ใช้ไฟล์ `wired` ที่เหลือใช้ไฟล์ `air` (แก้ 14 ต.ค. 2569) | `air_conditioners` |
| DELETE | `/api/air-conditioners/:deviceId` | ใช่ | ใช่ | ลบแอร์ → สั่งบอร์ดล้างค่า (unprovision) รอ ≤ 4 วินาที → ล้าง retained topic → ลบบัญชี MQTT ตอบ `boardCleared` ด้วย (แก้ 13 ต.ค. 2569) | `air_conditioners` (+ Broker + บอร์ด) |
| GET | `/api/occupancy-sensors` | ใช่ | ไม่ | รายการเซ็นเซอร์ตรวจจับคน | `occupancy_sensors` |
| POST | `/api/occupancy-sensors/reservations` | ใช่ | ใช่ | จองอุปกรณ์เซ็นเซอร์ (หนึ่งห้องหนึ่งตัว) | `occupancy_sensors`, `rooms` |
| POST | `/api/occupancy-sensors/:deviceId/setup-mode` | ใช่ | ใช่ | เข้าโหมดตั้งค่า (202) | `occupancy_sensors` |
| POST | `/api/occupancy-sensors/:deviceId/ota` | ใช่ | ใช่ | สั่ง OTA (202) ไฟล์ต้องเป็นชนิด `occupancy` (แก้ 14 ต.ค. 2569) | `occupancy_sensors` |
| DELETE | `/api/occupancy-sensors/:deviceId` | ใช่ | ใช่ | ลบเซ็นเซอร์ ลำดับเดียวกับแอร์ (unprovision → retained → บัญชี MQTT) ตอบ `boardCleared` (แก้ 13 ต.ค. 2569) | `occupancy_sensors` (+ Broker + บอร์ด) |
| GET | `/api/firmware` | ใช่ | ใช่ | `{configured, maxBytes, files}` รายการไฟล์ `.bin` พร้อม `kind` (`air`/`wired`/`occupancy`) และ `version` จากชื่อไฟล์ (แก้ 14 ต.ค. 2569) | (ระบบไฟล์) |
| POST | `/api/firmware` | ใช่ | ใช่ | อัปโหลดไฟล์ดิบ ชื่อใน header `X-File-Name` (percent-encoded) `?kind=` ต้องตรงชนิดจากชื่อ `?replace=1` ยอมเขียนทับ ตอบ 201 `{file}` (เพิ่ม 14 ต.ค. 2569) | (ระบบไฟล์) |
| DELETE | `/api/firmware/:fileName` | ใช่ | ใช่ | ลบไฟล์ ตอบ `{removed, fileName}` ไม่มีไฟล์ตอบ `removed: false` (เพิ่ม 14 ต.ค. 2569) | (ระบบไฟล์) |

### ไฟฟ้า แจ้งเตือน ตั้งค่า

| Method | Path | ล็อกอิน | admin | หน้าที่ | ตาราง |
|---|---|---|---|---|---|
| GET | `/api/energy/metrics` | ใช่ | ไม่ | แคตตาล็อกค่าที่เลือกส่งออกได้ | (ค่าคงที่ใน `energy-history.js`) |
| GET | `/api/energy/live` | ใช่ | ไม่ | ค่าล่าสุดทุกเครื่อง + ยอดรวม | `air_conditioners`, `rooms` |
| GET | `/api/energy/sources` | ใช่ | ไม่ | ห้อง/เครื่องที่มีข้อมูลให้เลือก + ช่วงข้อมูลเก่าสุด-ใหม่สุด | `air_conditioners`, `energy_hourly`, `rooms` |
| GET | `/api/energy/summary` | ใช่ | ไม่ | สรุปช่วง (`period`/`from`/`to`/`floor`) เทียบช่วงก่อน + กราฟ + แยกห้อง/เครื่อง | `energy_hourly`, `rooms`, `air_conditioners` |
| GET | `/api/energy/history` | ใช่ | ไม่ | ประวัติรายชั่วโมง/วัน ตาม scope (building/room/device) | `energy_hourly`, `air_conditioners` |
| GET | `/api/energy/export` | ใช่ | ไม่ | ส่งออกไฟล์ `.xlsx` (404 ถ้าไม่มีข้อมูล) | `energy_hourly`, `air_conditioners` |
| GET | `/api/alerts` | ใช่ | ไม่ | รายการแจ้งเตือน กรอง `status`, `room`, `limit` (ค่าเริ่ม 30, สูงสุด 200) + จำนวนแยกสถานะ | `system_alerts` |
| POST | `/api/alerts/:id/acknowledge` | ใช่ | ไม่ | รับทราบแจ้งเตือน (ต้องเป็น `open`) | `system_alerts` |
| GET | `/api/settings` | ใช่ | ไม่ | ค่าตั้งสาธารณะ: สถานะ auto-off, อัตราค่าไฟ | `system_settings` |
| PATCH | `/api/settings/auto-off` | ใช่ | ใช่ | เปิด/ปิดระบบปิดแอร์อัตโนมัติทั้งอาคาร | `system_settings` |
| PATCH | `/api/settings/rate` | ใช่ | ใช่ | ตั้งอัตราค่าไฟ (บาท/kWh) ต้องอยู่ระหว่าง 0.01–100 | `system_settings` |

รวม **57 endpoint** (นับ `/api/health` ด้วย; เดิม 55 เพิ่ม `POST` และ `DELETE /api/firmware` เมื่อ 14 ต.ค. 2569)

> [!NOTE]
> `POST /api/air-conditioners/:deviceId/command` ไม่มี `requireAdmin` โดยตั้งใจ เพราะเจ้าหน้าที่ (staff) ต้องเปิด-ปิดแอร์ได้ ส่วนการจอง/ลบ/OTA/เข้าโหมดตั้งค่าซึ่งกระทบอุปกรณ์ถาวรเป็นของแอดมินเท่านั้น

## ไฟล์ route ทีละไฟล์

### `routes/auth.js` (426 บรรทัด)
ดูรายละเอียดในหัวข้อ "ระบบสมาชิก" และ "เจาะโค้ด" ฟังก์ชันภายใน `cleanString(value, maxLength)` มีสำเนาในไฟล์นี้เองซ้ำกับ `utils/user.js` (ไม่ได้ export) ใช้ `rateLimit` 3 ตัว ใช้ `withTransaction` ในสองจุด (forgot-password และ reset-password)

### `routes/public.js` (39 บรรทัด)
endpoint เดียว ไม่ผ่าน `authenticate` เพราะหน้าล็อกอินต้องแสดง "ติดต่อแอดมินเมื่อลืม/ล็อกอินไม่ได้" ก่อนมีใครล็อกอิน เลือกเฉพาะ `first_name, last_name, username, phone` (ไม่เปิดเผยอีเมลหรือ role คนอื่น) ถ้าไม่มีแอดมินที่มีเบอร์ ตอบ 404

### `routes/users.js` (189 บรรทัด)
ใช้ `usersRouter.use(authenticate)` และ `.use(requireAdmin)` ครั้งเดียวคลุมทั้งไฟล์ รหัสผ่านผู้ใช้ใหม่ผ่าน `isValidNewPassword` แล้ว `bcrypt.hash(…, 12)` ตรรกะเด่น:

- `PATCH /:username`: ห้ามแก้ตัวเอง (กันแอดมินปิดบัญชี/ลดสิทธิ์ตัวเองแล้วล็อกตัวเองออก), ใช้ transaction + `FOR UPDATE` อ่านผู้ใช้เป้าหมาย, ถ้ากำลังจะเปลี่ยน "แอดมินที่ใช้งานอยู่" ให้ไม่ใช่ ต้องมีแอดมินที่ใช้งานอยู่คนอื่นอย่างน้อยหนึ่งคน (`assertAnotherActiveAdminExists` → 409) ถ้าไม่มีอะไรเปลี่ยนจริงจะไม่ `UPDATE` ถ้าเปลี่ยนจะ `token_version + 1` เพื่อเพิกถอน token เดิมของคนนั้น
- `DELETE /:username`: กฎเดียวกัน (ห้ามลบตัวเอง ห้ามลบแอดมินคนสุดท้าย) ลบผู้ใช้จะลบ `password_reset_otps` ตามด้วย (`ON DELETE CASCADE` ใน schema)
- ลำดับเรียงรายการ `ORDER BY role = 'admin' DESC, is_active DESC, username` ให้แอดมินที่ใช้งานอยู่ขึ้นก่อน
- `ER_DUP_ENTRY` → 409 (username/อีเมลซ้ำ)

### `routes/rooms.js` (230 บรรทัด)
ดูหัวข้อเจาะโค้ดข้อ 6 ใช้ `validateRoomInput`, `validateRoomNumber`, `publicRoom` จาก `utils/room.js`

### `routes/schedules.js` (500 บรรทัด)
ไฟล์ใหญ่ ประกอบด้วยสามกลุ่ม:

1. **นำเข้าไฟล์:** `import/preview` ใช้ `express.raw({type: () => true, limit: '8mb'})` เป็น middleware เฉพาะ route นี้ (รับไบนารีของไฟล์ Excel/CSV ตรง ๆ แทน JSON และเพิ่มเพดานเป็น 8 MB เพราะ `express.json` ที่ใช้ทั่วไปจำกัดแค่ 256 KB) แล้วส่งให้ `parseScheduleFile` (บทตอนที่ 2) แยกห้องที่มีอยู่แล้วกับห้องใหม่ (`roomDefaultsForImport` เดาชั้น/ประเภท) `import/commit` ใน `withTransaction` เดียว: สร้างห้องที่ขาด (ถ้าผู้ใช้ยืนยัน `createMissingRooms`) → ลบตารางเดิม (ทั้งหมดถ้า `replaceAll` หรือเฉพาะห้องที่อยู่ในไฟล์) → `INSERT` ทุกคาบ (id เป็น `crypto.randomUUID()`) → บันทึกภาคเรียน → บันทึกว่านำเข้าเมื่อไร ทำใน transaction เดียวเพื่อไม่ให้มีช่วงที่ตารางว่างครึ่งทาง ซึ่งระบบปิดแอร์อัตโนมัติจะเข้าใจว่าทุกห้อง "ไม่มีคาบเรียน" แล้วปิดแอร์ระหว่างสอน
2. **ปฏิทินภาคเรียน:** `GET/PUT/DELETE /terms` เรียก `readCalendar`, `upsertTerm`, `deleteTerm` ของ `services/academic-terms.js` **ต้องประกาศก่อน `/:id`** (ดูหมายเหตุ) และเรียก `clearTermCache()` หลังแก้เพื่อล้างแคชที่ระบบปิดแอร์ใช้
3. **CRUD คาบเรียน:** `validateScheduleInput` ตรวจ, `ensureRoomsExist` (ห้องต้องมีในตาราง `rooms`), `ensureNoOverlap` ตรวจการซ้อนด้วยเงื่อนไขคลาสสิก `start_time < ใหม่.end AND end_time > ใหม่.start` (ไม่ซ้อนถ้าคาบหนึ่งจบตอนอีกคาบเริ่มพอดี) พร้อมข้าม id ตัวเองตอนแก้ `validateId` บังคับรูปแบบ UUID เวอร์ชัน 1–5 export `deleteAllSchedules` และ `ensureImportedRooms` ให้ test เรียกด้วย "database ปลอม" ได้

> [!WARN]
> ลำดับการประกาศ route สำคัญ Express จับ route ตามลำดับที่ประกาศ ถ้าประกาศ `PUT /:id` ก่อน `PUT /terms` คำขอ `PUT /terms` จะถูกจับเป็นแก้คาบเรียนที่มี id = "terms" โค้ดจึงวาง `/terms` ไว้ก่อน (มีคอมเมนต์เตือนในไฟล์)

### `routes/bookings.js` (162 บรรทัด)
การใช้ห้องนอกตารางเรียน (ประชุม สอบ กิจกรรม) `GET` คืนรายการที่ช่วงวันที่ทับกับ `from`/`to` (ถ้าไม่ส่ง `from` ใช้ `end_date >= CURDATE()` คือเฉพาะที่ยังไม่จบ) เก็บ `days_of_week` เป็นสตริงคั่นจุลภาค (`input.daysOfWeek.join(',')`) ใช้ `DATE_FORMAT` ให้วันที่เป็นข้อความ `YYYY-MM-DD` ไม่ให้ไดรเวอร์แปลงเป็น Date ที่เวลาเพี้ยนตามเขตเวลา `POST/PUT` ตอบ `occurrences` = `countOccurrences(input)` (จำนวนวันที่เกิดขึ้นจริง) `GET` ดัก `ER_NO_SUCH_TABLE` แล้วคืนรายการว่าง เพื่อให้ Backend รุ่นใหม่ยังทำงานได้กับฐานข้อมูลที่ยังไม่รัน migration ตารางนี้

### `routes/air-conditioners.js` (448 บรรทัด)
ตัวใหญ่ที่สุดของฝั่งอุปกรณ์ จุดสำคัญคือ `POST /reservations` (ขั้นจองก่อนบอร์ดจะ provisioning):

1. ตรวจ input (`validateReservationInput`) และว่าห้องมีอยู่ (400 ถ้าไม่มี)
2. ลบการจอง `reserved` ที่หมดอายุทิ้ง และล้าง token ของที่ `active` แล้วหมดอายุ
3. ตรวจซ้ำ: ห้อง+หมายเลขแอร์นั้นถูกใช้โดยอีกบอร์ด → 409; บอร์ดนี้ไปลงทะเบียนที่อื่นแล้ว → 409
4. สร้าง token สุ่ม `randomBytes(24).toString('base64url')` เก็บเฉพาะ hash (`hashSecret(token)`) ส่งตัวจริงให้แอปหนเดียว เพื่อแอปส่งต่อให้ ESP32 ทาง Bluetooth
5. เรียก `prepareDeviceCredentials` สร้างบัญชี MQTT ของบอร์ด **ก่อนเขียน DB** เพื่อไม่ให้ถ้า Broker ล้มแล้วค้างแถวจองไว้ (ล้มแล้วตอบ 503)
6. `INSERT` แถวใหม่สถานะ `reserved` หมดอายุ 15 นาที (`expiresInSeconds: 900`) หรือ `UPDATE` ถ้าบอร์ดเดิมที่ `active` มาตั้งค่าใหม่ (ตอบ 200 แทน 201)

`POST /:deviceId/command`: ต้อง `provision_status = 'active'` (409 ถ้าบอร์ดยังไม่ยืนยันตัวผ่าน MQTT) ตรวจคำสั่งด้วย `validateAirState(body, protocol)` (`protocol` อ่านจากแถวในฐานข้อมูล ถ้าเป็น `DAIKIN_WIRED` จะรับเฉพาะคำสั่งที่รีโมตติดผนังทำได้ ดูบท Backend ตอนที่ 2) แล้ว `publishAirCommand` ตอบ 202 พร้อม `commandId` ("รับคำสั่งแล้ว" ไม่ใช่ "แอร์ทำแล้ว" เพราะผลมาทาง MQTT status ภายหลัง) ถ้า Broker ไม่ต่อ ตอบ 503 `PATCH /:deviceId`: สร้าง `SET` แบบประกอบฟิลด์ที่ส่งมา (`fields.push('name = ?')`) ชื่อคอลัมน์เป็นข้อความคงที่ในโค้ด ไม่ใช่ข้อความจากผู้ใช้ ค่าผู้ใช้ผูกด้วย `?` ปิด auto-off จะรีเซ็ตนาฬิกานับถอยหลังด้วย `POST /:deviceId/ota`: ตรวจชื่อไฟล์ (`validateFirmwareFileName`), ไฟล์มีจริง (`assertFirmwareFileExists` จาก `firmware.js`), อ่าน `protocol` ของบอร์ดแล้ว `assertFirmwareKind(fileName, airFirmwareKind(row.protocol))` (เพิ่ม 14 ต.ค. 2569: บอร์ดสายแอร์รับเฉพาะไฟล์ที่ชื่อมี `wired`/`slm8` บอร์ด IR รับเฉพาะไฟล์ IR ผิดตอบ 400), บอร์ด `active` และออนไลน์ แล้วสร้าง URL ดาวน์โหลด `https://<mqtt_host>/firmware/<ไฟล์>` และสั่งผ่าน MQTT `DELETE`: ลบแถว → `unprovisionDevice('air', id)` สั่งบอร์ดล้างค่าแล้วรอคำตอบ ≤ 4 วินาที (เพิ่ม 13 ต.ค. 2569) → `clearRetainedAirTopics` (ล้างข้อความ retained ของบอร์ดบน Broker กันค่าเก่าค้าง) → `removeDeviceAccount` (ลบบัญชี MQTT) ตอบ `boardCleared` บอกว่าบอร์ดยืนยันการล้างหรือไม่ ลบซ้ำถือว่าสำเร็จ (ตอบ 200 เสมอ) เพื่อไม่ให้แอปค้างกับแถวที่หายไปแล้ว (ดูเจาะโค้ดข้อ 9)

### `routes/occupancy-sensors.js` (326 บรรทัด)
โครงเหมือน `air-conditioners.js` แต่ผูก **หนึ่งห้องหนึ่งเซ็นเซอร์** (ตรวจ `room_number` ซ้ำ ไม่มี `air_number`) และใช้ topic prefix `rmutt/occupancy` กับค่า `STATIC_ENERGY_THRESHOLD` ของ LD2410 ใช้ `publishOtaCommand('occupancy', ...)` ต่างจากแอร์ที่ใช้ `'air'` OTA ตรวจ `assertFirmwareKind(fileName, 'occupancy')` ตั้งแต่ก่อนอ่านฐานข้อมูล (เพิ่ม 14 ต.ค. 2569 เพราะเซ็นเซอร์มีชนิดเดียว ไม่ต้องรู้ protocol) และ `DELETE` เรียก `unprovisionDevice('occupancy', id)` ก่อนล้าง retained และลบบัญชี MQTT ตอบ `boardCleared` เหมือนแอร์ (เพิ่ม 13 ต.ค. 2569)

### `routes/firmware.js` (185 บรรทัด, แก้ 14 ต.ค. 2569)
`firmwareRouter.use(authenticate, requireAdmin)` (ส่งสอง middleware ในการเรียกเดียว คลุมทุกเส้นในไฟล์ รวมเส้นอัปโหลดและลบที่เพิ่มใหม่)

- `GET /` คืน `{configured, maxBytes, files}` `maxBytes` = `FIRMWARE_MAX_BYTES` ให้หน้าเว็บเตือนไฟล์ใหญ่เกินก่อนส่ง ฟังก์ชัน `listFirmwareFiles` อ่านโฟลเดอร์ `FIRMWARE_DIR` เอาเฉพาะ `.bin` ที่เป็นไฟล์ เรียงใหม่สุดก่อน แต่ละไฟล์มี `name`, `size`, `modifiedAt`, `kind` (`firmwareKindOf`) และ `version` (`firmwareVersionOf`, เพิ่ม 14 ต.ค.) ไม่ตั้งโฟลเดอร์หรือโฟลเดอร์ไม่มี คืนอาร์เรย์ว่าง
- `POST /` (เพิ่ม 14 ต.ค. 2569) รับไฟล์ `.bin` จากหน้าเว็บแทนการ `scp` เข้าเซิร์ฟเวอร์ ใช้ `express.raw` เฉพาะเส้นนี้ (เพดาน `FIRMWARE_MAX_BYTES + 1024`) ตรวจชื่อ ชนิด เนื้อไฟล์ แล้วเขียนแบบไฟล์ชั่วคราว + `rename` (ดูเจาะโค้ดข้อ 8)
- `DELETE /:fileName` (เพิ่ม 14 ต.ค. 2569) ตรวจชื่อด้วย `validateFirmwareFileName` แล้ว `fs.unlink` ไม่มีไฟล์ (`ENOENT`) ตอบ `{removed: false}` แบบไม่ error (ลบซ้ำได้) เขียนไม่ได้ (`EACCES`/`EROFS`) ตอบ 500 พร้อมข้อความไทย
- ฟังก์ชันภายใน `decodeHeader` (ถอด percent-encoding ของ `X-File-Name` ถอดไม่ได้คืน `''` ซึ่งจะไม่ผ่านการตรวจชื่อ) และ `fileExists`
- `assertFirmwareFileExists` export ให้ route แอร์/เซ็นเซอร์ใช้ ตรวจว่าไฟล์มีและขนาด > 0 ไม่งั้น 404 ถ้าไม่ได้ตั้ง `FIRMWARE_DIR` จะข้ามการตรวจ (ตอนพัฒนา)

### `routes/energy.js` (555 บรรทัด)
อ่านอย่างเดียว (ทุก route ล็อกอินอย่างเดียว) เรียก util ใน `utils/energy-history.js` (บทตอนที่ 2) ที่ควรรู้: `/summary` ใช้ `Promise.all` ยิง 5 query พร้อมกัน (ยอดช่วงนี้, ช่วงก่อนหน้า, กราฟ, แยกห้อง, แยกเครื่อง) แทนรอทีละอัน ตัวกรองชั้นผ่าน `floorFilter()` ซึ่งสร้างข้อความ WHERE จากชิ้นส่วนคงที่และผูกค่า `?` เสมอ `/export` ตั้ง header `Content-Disposition` ด้วย `filename=` (ชื่อ ASCII) และ `filename*=UTF-8''...` (ชื่อไทยที่ encode แล้ว) เพราะ header HTTP รับได้เฉพาะ Latin ส่งไฟล์ด้วย `response.send(Buffer.from(workbook))` และบอกจำนวนแถวใน `X-Export-Rows` ข้อมูลผ่าน `/history`/`/export` สร้างด้วย SQL ซ้อนสองชั้น (ชั้นในรวมต่ออุปกรณ์ต่อชั่วโมง ชั้นนอกรวมตามระดับที่เลือก) เพื่อให้ค่าเฉลี่ยของหลายเครื่องถูกต้อง

### `routes/alerts.js` (100 บรรทัด)
`GET /` กรองตามสถานะ (`open`/`acknowledged`/`resolved`) และห้อง สร้าง `WHERE` จากเงื่อนไขคงที่ + ค่าผูก `?` และใส่ `LIMIT ${limit}` แบบแทรกตัวเลข ซึ่งปลอดภัยเพราะ `clampLimit` แปลงเป็นจำนวนเต็ม (1–200 ค่าเริ่มต้น 30) แล้วเท่านั้น `ORDER BY status = 'open' DESC` ให้ที่ยังไม่รับทราบขึ้นก่อน และคืน `counts` แยกตามสถานะให้แสดงตัวเลขบนไอคอน `POST /:id/acknowledge`: `UPDATE ... WHERE id = ? AND status = 'open'` แล้วดู `affectedRows` ถ้า 0 = ไม่พบหรือรับทราบไปแล้ว → 404 (วิธีนี้ปลอดภัยต่อการกดซ้ำพร้อมกัน) สถานะ `resolved` ถูกตั้งโดย `services/alerts.js` ไม่ใช่ API นี้ (พารามิเตอร์แรก `_status` ของ `clampLimit` ไม่ได้ถูกใช้)

### `routes/settings.js` (72 บรรทัด)
`GET /` ทุกคนที่ล็อกอินอ่านได้ (ทุกหน้าจอต้องใช้อัตราค่าไฟคูณ kWh และคนทั่วไปต้องรู้ว่า auto-off ถูกปิดอยู่เพื่อไม่ต้องสงสัยเมื่อไม่มีนับถอยหลัง) `PATCH /auto-off` รับ `{enabled: boolean}` (ชนิดต้องเป็น boolean จริง ไม่รับ `"true"`) `PATCH /rate` รับ `{rate}` แปลงเป็นตัวเลข ต้องอยู่ระหว่าง `RATE_LIMITS.min`=0.01 ถึง `max`=100 ทั้งสองแก้ได้เฉพาะแอดมิน และบันทึกชื่อผู้แก้ (`request.authUser?.username`) ผ่าน `services/system-settings.js`

## การทดสอบ

### วิธีทำงาน
รัน `npm test` = `node --test` ตัวรันเทสต์ที่มากับ Node (ตั้งแต่ v18) จะหาไฟล์ `*.test.js` ใต้โฟลเดอร์โปรเจค (โฟลเดอร์ `test/` ทั้งหมดอยู่ในกลุ่มนี้) แล้วรันแต่ละไฟล์ในโปรเซสแยกกัน แต่ละกรณีเขียนด้วย `test('ชื่อ', () => {...})` และตรวจด้วย `assert` จาก `node:assert/strict` (`assert.equal`, `assert.deepEqual`, `assert.throws`, `assert.match`) ไม่ต้องติดตั้ง Jest/Mocha รวม 136 กรณีใน 21 ไฟล์ (นับ ณ 14 ต.ค. 2569; เดิม 126 กรณีใน 20 ไฟล์)

### ทำไม util เป็น pure function
ฟังก์ชันใน `utils/` ไม่เปิดฐานข้อมูล ไม่ยิงเครือข่าย ไม่อ่านเวลาปัจจุบันตรง ๆ (หลายตัวรับเวลาเป็นพารามิเตอร์) ข้อมูลเข้าเหมือนกัน ผลออกเหมือนกันเสมอ การทดสอบจึงแค่ `import` แล้วเรียก ไม่ต้องจัดฉาก (เปิด DB, MQTT) รันเป็นมิลลิวินาที และเขียนกรณีขอบ (ค่า null, ภาษาไทย 72 ไบต์, วันสิ้นปี) ได้ง่าย นอกจากนี้ `db.js` สร้าง pool แบบ lazy เพื่อไม่ให้การ import ไฟล์เหล่านี้ลากการเชื่อมต่อค้างจน `node --test` ไม่จบ เมื่อ logic อยู่ที่ util และ route เป็นเพียงตัวประกอบบาง ๆ ส่วนที่ต้องเทสต์ผ่าน HTTP จริงมีน้อย

### ไฟล์เทสต์แต่ละไฟล์

| ไฟล์ | จำนวน | ตรวจอะไร |
|---|---|---|
| `security.test.js` | 3 | OTP เป็นเลข 6 หลักเสมอ (วน 100 ครั้ง), `hashSecret`/`safeHashEquals` (ค่าเดียวกันตรง ค่าต่างไม่ตรง และ hash ≠ ค่าเดิม), `isValidNewPassword` (สั้นเกินไม่ผ่าน ภาษาไทย 30 ตัว = 90 ไบต์ไม่ผ่าน) |
| `user.test.js` | 2 | `publicUser` ไม่ปล่อย id ภายใน; เบอร์ `null` กลายเป็น `''` |
| `user-management.test.js` | 7 | `managedUser` ไม่มี hash และ null date คง null, `validateRole`, `validateUsername` (กัน `../admin`), `validateNewUserInput`, `validateUserUpdate` |
| `profile-email.test.js` | 4 | `PATCH /api/auth/me` ผ่านเซิร์ฟเวอร์จริง + pool ปลอม: แก้ชื่อไม่ต้องใส่รหัส, เปลี่ยนอีเมลไม่ใส่รหัส 400, รหัสผิด 400, รหัสถูก 200 |
| `room.test.js` | 4 | รหัสห้อง (`cl503` → `CL503`), กัน `../CL503`, เดาชั้น/ประเภทตอนนำเข้า, แยก "เซ็นเซอร์ไม่พร้อม" ออกจาก "ห้องว่าง" |
| `schedule.test.js` | 11 | `validateScheduleInput`, ตัวกรอง (วัน 0 = อาทิตย์ ไม่ถือว่าว่าง), **`requireAdmin`** (admin ผ่าน staff ถูก throw), `deleteAllSchedules` ด้วย DB ปลอม, `ensureImportedRooms` (สร้างห้องเมื่อยืนยันเท่านั้น), วันที่เวลาไทย, ภาคเรียน |
| `schedule-import.test.js` | 9 | แปลงไฟล์ Excel (เซลล์รวม) / CSV เป็นคาบเรียน, ข้ามห้องที่ยังไม่เพิ่ม, ตรวจคาบซ้อน, ป้ายชื่อวิชา, `pickSemester` |
| `room-booking.test.js` | 5 | การจองครั้งเดียว รายวัน รายสัปดาห์, input ผิด, ห้องที่จองถือว่าใช้งานแม้นอกภาคเรียน |
| `air-conditioner.test.js` | 10 | การจอง ESP32, ห้อง/หมายเลข/ชื่อ BLE ผิด, โปรโตคอล IRac และ Saijo Denki, คำสั่ง MQTT, ช่วงค่าที่รับได้ + (เพิ่ม 11 ต.ค. 2569) จองด้วย `daikin_wired` ได้ `DAIKIN_WIRED`, คำสั่งสายแอร์ (ปฏิเสธ auto/heat/turbo/swing กลาง, ตัดฟังก์ชันเสริม, sleep ปิดใน dry, Daikin IR ไม่กระทบ), `controlTypeOf`/`controlType`, `protocolFromStatus` |
| `occupancy-sensor.test.js` | 5 | ตัวตนเซ็นเซอร์ LD2410, การเก็บสถานะ occupied, JSON สาธารณะ |
| `firmware.test.js` | 7 | ชื่อไฟล์ `.bin` ที่ปลอดภัย (ปฏิเสธ `../`, `/`, `.exe`, ช่องว่าง, `..`), URL ใช้โฮสต์ MQTT (ปฏิเสธ `evil.com/x`), เดาชนิดบอร์ด + (เพิ่ม 14 ต.ค. 2569) แยกไฟล์ `wired` ออกจาก `air`, `assertFirmwareKind` ห้ามไฟล์ผิดชนิด, อ่านรุ่นจากชื่อและเทียบรุ่น (`2.5.10` > `2.5.9`), `validateFirmwareImage` (ไบต์ `0xE9`, ใหญ่เกิน, ไฟล์ว่าง) |
| `unprovision.test.js` | 2 | (เพิ่ม 13 ต.ค. 2569) payload คำสั่ง `unprovision` มี `deviceId` ของบอร์ดเป้าหมาย; นับเป็นคำตอบเฉพาะ `unprovisioned === true` และ `deviceId` ตรง |
| `auto-off.test.js` | 15 | ตรรกะปิดแอร์อัตโนมัติ: เริ่มนับ 5 นาที (ในคาบนานกว่า), ไม่มี/เสียเซ็นเซอร์ไม่ปิด, ยกเลิกเมื่อมีคน, ยิงซ้ำทุก 20 วินาที, ยอมแพ้แล้วแจ้งเตือน |
| `energy-history.test.js` | 17 | ถังรายชั่วโมงเวลาไทย, ผลต่างมิเตอร์, ช่วงเงียบนานไม่นับเวลา, SQL ผูกพารามิเตอร์, หัวตาราง Excel, ช่วงเวลาและเทียบช่วงก่อนหน้า |
| `offline-history.test.js` | 4 | แปลงข้อมูลย้อนหลังที่บอร์ดเก็บตอนออฟไลน์ และลงถัง |
| `pzem-status.test.js` | 4 | normalize ค่า PZEM, เวอร์ชันเฟิร์มแวร์/OTA error, คาบเรียนเวลา Asia/Bangkok |
| `mqtt.test.js` | 3 | health ของ MQTT ไม่เผยรหัสผ่าน, รายการ retained topic ที่ต้องล้าง |
| `mqtt-accounts.test.js` | 7 | รหัสผ่าน MQTT คำนวณซ้ำได้, ACL ต่อ topic, คำสั่ง Dynamic Security, **`isValidFromAddress`** |
| `mqtt-provisioning.test.js` | 5 | เลือก URL/พอร์ต Broker (mqtts → 8883) ให้ ESP32 |
| `schema-doctor.test.js` | 6 | ตัวอ่าน `schema.sql` อ่านทุกตาราง, `air_conditioners` ต้องมี 43 คอลัมน์ (ตรวจกับไฟล์จริง จึงเตือนเมื่อ schema กับเทสต์เหลื่อมกัน), diff ตาราง/คอลัมน์ที่ขาด |
| `xlsx-writer.test.js` | 6 | โครงไฟล์ xlsx ครบ ข้อความ/ตัวเลขคนละชนิด escape XML ชื่อแท็บ ชื่อคอลัมน์ `AA` |

**ช่องว่างของการทดสอบที่ควรบอกตรง ๆ:** ไม่มีเทสต์ที่เรียก `POST /login`, `forgot-password`, `verify-otp`, `reset-password` ผ่าน HTTP โดยตรง (ฟังก์ชันที่เป็นหัวใจ `createOtp`, `hashSecret`, `safeHashEquals`, `isValidNewPassword` มีเทสต์ แต่ logic ที่ประกอบเข้าด้วยกันใน route ไม่มี) ส่วน `authenticate` ถูกเทสต์ทางอ้อมผ่าน `profile-email.test.js` และ route ส่วนใหญ่ที่ต่อ DB ไม่มีเทสต์ตรง ๆ

## หลักการเขียนโค้ดที่ใช้ในส่วนนี้

- **แยก app ออกจาก server (`app.js` / `server.js`)** `app.js` ประกอบแอปล้วน ๆ ไม่มีผลข้างเคียง `server.js` เป็นตัวเริ่มของจริง ผลคือ test เรียก `app.listen(0)` ได้โดยไม่เปิด MQTT/timer
- **Fail-fast** (`config.js` `assertServerConfig`) ล้มตั้งแต่เริ่มเมื่อตั้งค่าผิด ดีกว่าเสี่ยงทำงานด้วย secret ว่างหรือค่าตัวอย่าง
- **Defense in depth** ซ้อนหลายชั้น: helmet, CORS, ขนาด body, rate limit, ตรวจชนิดและความยาวทุก input (`cleanString`), parameter binding, token_version, ตรวจ `is_active` ทุก request ถ้าชั้นหนึ่งพลาด ชั้นอื่นยังกันได้
- **Middleware chain / ตรวจสิทธิ์เป็นชั้น** `use(authenticate)` ทั้ง router แล้ว `requireAdmin` เป็นรายเส้นหรือทั้งไฟล์ (`users.js`, `firmware.js`) ทำให้ "ลืมใส่" ยากขึ้นเพราะ default ของแต่ละไฟล์คือ "ต้องล็อกอิน"
- **Error เป็นข้อมูล (`ApiError` + error handler กลาง)** route ไม่ต้องเขียน `response.status(...).json(...)` ซ้ำทุกที่ แค่ `throw` และรูปแบบ response ผิดพลาดเหมือนกันหมด (`{message}`) แอปจึงเขียนตัวจัดการข้อผิดพลาดตัวเดียว
- **Validation แยกเป็น pure function (`utils/*.js`)** ตรวจและ normalize input ที่เดียว (เช่น รหัสห้องเป็นตัวพิมพ์ใหญ่) ทดสอบได้ไม่ต้องมี HTTP route จึงบางและอ่านง่าย
- **Public DTO (`publicUser`, `publicRoom`, `managedUser`)** ไม่ส่งแถว DB ดิบออกไป เลือกฟิลด์ที่ส่งและแปลงชื่อเป็น camelCase ที่เดียว ป้องกันการหลุดของ `password_hash`/`token_version` และถ้า schema เปลี่ยน แอปไม่พังทันที
- **ไม่เปิดเผยว่าบัญชีมีอยู่หรือไม่** (login ใช้ dummy hash + ข้อความเดียว, forgot-password ตอบเหมือนกันเสมอ)
- **Transaction + `FOR UPDATE`** (`users.js`, `rooms.js`, `schedules.js`, `auth.js reset-password`) เมื่อ "อ่านแล้วตัดสินใจแล้วเขียน" ต้องกันไม่ให้ใครแทรกกลาง เช่น แอดมินสองคนลดสิทธิ์กันเองพร้อมกันจนเหลือแอดมินศูนย์คน
- **Lazy initialization** (`getPool()`, `getTransporter()`) สร้างของที่ต้องเชื่อมต่อเมื่อถึงเวลาใช้ ทำให้ import ไฟล์ได้ฟรีและเทสต์ไม่ค้าง
- **Idempotent / เขียนซ้ำได้ปลอดภัย** ลบอุปกรณ์ซ้ำถือว่าสำเร็จ, acknowledge ใช้ `WHERE status='open'`, ปิด OTP เก่าก่อนออกใบใหม่
- **ผูกค่าเสมอ ข้อความ SQL ประกอบเฉพาะจากชิ้นส่วนคงที่** (`where`/`fields`/`placeholders` ใน `alerts.js`, `schedules.js`, `air-conditioners.js`) ตัวเลขที่แทรกตรง (`LIMIT`) ผ่านการแปลงเป็นจำนวนเต็มก่อน

## คำถามที่อาจารย์อาจถาม

> [!ASK]
> **ถาม:** ทำไมไม่ให้แอปต่อฐานข้อมูลตรง ๆ แต่ต้องมี Backend คั่น?
> **ตอบ:** ถ้าแอปต่อ DB ตรง รหัสผ่านฐานข้อมูลจะอยู่ในแอปที่ใครก็ถอดได้ และคุมสิทธิ์รายแถวไม่ได้ Backend เป็นด่านเดียวที่ตรวจตัวตน ตรวจสิทธิ์ ตรวจ input และยังเป็นตัวเดียวที่คุยกับ MQTT เพื่อสั่งแอร์ ซึ่งแอปทำเองไม่ได้ให้ปลอดภัย

> [!ASK]
> **ถาม:** JWT คืออะไร ปลอดภัยไหม ถ้ามีคนแก้ role ใน token เป็น admin?
> **ตอบ:** JWT คือบัตรสามท่อน header.payload.signature payload อ่านได้แต่แก้ไม่ได้ เพราะลายเซ็นคำนวณจาก `JWT_SECRET` ที่มีแต่เซิร์ฟเวอร์ ถ้าแก้ payload ลายเซ็นไม่ตรงและ `jwt.verify` ปฏิเสธ นอกจากนี้ระบบนี้ไม่ได้เชื่อ `role` ใน token เลย `authenticate` ดึง role จากฐานข้อมูลทุกครั้ง จึงแก้ไม่ได้แม้ลายเซ็นหลุด และเปลี่ยนสิทธิ์มีผลทันที

> [!ASK]
> **ถาม:** ถ้าแอดมินเปลี่ยนสิทธิ์หรือผู้ใช้เปลี่ยนรหัสผ่าน token เก่าที่แจกไปแล้วจะทำอย่างไร?
> **ตอบ:** ใช้ `token_version` ใน `users` ฝังเลขนี้ลงใน token (`ver`) ทุก request `authenticate` เทียบเลขกับ DB เมื่อเปลี่ยนรหัสผ่านหรือสิทธิ์ เลขเพิ่มหนึ่ง token เก่าทุกใบเลขไม่ตรงและใช้ไม่ได้ทันที แลกกับการ query DB หนึ่งครั้งต่อ request

> [!ASK]
> **ถาม:** เก็บรหัสผ่านอย่างไร และทำไมไม่ใช้ SHA-256 ธรรมดา?
> **ตอบ:** ใช้ bcrypt (ไลบรารี `bcryptjs`) cost 12 มี salt ในตัว SHA-256 เร็วมาก คนร้ายที่ได้ฐานข้อมูลลองเดาได้พันล้านครั้งต่อวินาทีบน GPU bcrypt ถูกออกแบบให้ช้าและปรับความช้าได้ ข้อจำกัดคือรับได้ 72 ไบต์ ระบบจึงปฏิเสธรหัสที่ยาวกว่านั้นตั้งแต่ตอนตั้งรหัส

> [!ASK]
> **ถาม:** ลืมรหัสผ่านทำงานอย่างไร ปลอดภัยแค่ไหน?
> **ตอบ:** ขอ OTP 6 หลักส่งอีเมล (เก็บเป็น HMAC พร้อม pepper อายุ 10 นาที ผิดได้ 5 ครั้ง) → ตรวจ OTP ได้ reset token สุ่ม 256 บิต (เก็บเป็น hash) → ตั้งรหัสใหม่ด้วย token ซึ่งทำใน transaction และ `FOR UPDATE` ใช้ได้ครั้งเดียว ตอบเหมือนกันทั้งกรณีมีและไม่มีบัญชี ไม่ให้เดาได้ว่าใครมีบัญชี และมี rate limit 8 ครั้งต่อชั่วโมงต่อ IP ร่วมกันทั้งสามขั้น

> [!ASK]
> **ถาม:** ป้องกัน SQL injection อย่างไร?
> **ตอบ:** ทุกค่าที่มาจากผู้ใช้ส่งผ่านพารามิเตอร์ `?` ของไดรเวอร์ `mariadb` ซึ่งส่งเป็นข้อมูลแยกจากคำสั่ง ส่วนที่ต่อสตริงจริง (เช่น `WHERE` ที่ประกอบแบบไดนามิก) ประกอบจากข้อความคงที่ในโค้ดเท่านั้น และตัวเลขที่แทรกตรงอย่าง `LIMIT` ถูกแปลงเป็นจำนวนเต็มก่อน นอกจากนี้ยังตรวจรูปแบบ input (เช่น username/รหัสห้อง/UUID) ด้วย regex

> [!ASK]
> **ถาม:** Rate limit คืออะไร ทำไมต้องตั้ง `TRUST_PROXY`?
> **ตอบ:** จำกัดจำนวนครั้งต่อ IP เพื่อกันเดารหัส (login 10 ครั้ง/15 นาที) แต่ Backend อยู่หลัง Caddy ถ้าไม่บอก Express ว่ามี proxy หนึ่งชั้น (`TRUST_PROXY=1`) ทุก request จะมี IP ของ Caddy เดียวกัน คนเดียวกรอกผิดจะทำให้ทั้งอาคารถูกล็อก และไม่ตั้งเป็น `true` เพราะจะเชื่อ header ที่ใครก็ปลอมได้

> [!ASK]
> **ถาม:** admin กับ staff ต่างกันอย่างไร และตรวจสิทธิ์ตรงไหน?
> **ตอบ:** role ในตาราง `users` มีสองค่า `admin` กับ `staff` ทุกเส้น (ยกเว้นสาธารณะ) ต้องผ่าน `authenticate` ส่วนเส้นที่แก้ไขข้อมูลระบบ (ห้อง ตารางเรียน อุปกรณ์ ผู้ใช้ ค่าตั้ง) ต้องผ่าน `requireAdmin` เพิ่ม staff ดูข้อมูลและสั่งเปิด-ปิดแอร์ได้ แต่แก้โครงสร้างไม่ได้ และระบบกันไม่ให้ลบหรือลดสิทธิ์แอดมินคนสุดท้ายหรือตัวเอง

> [!ASK]
> **ถาม:** ทำไม Backend ตอบ 202 ตอนสั่งแอร์ ไม่ใช่ 200?
> **ตอบ:** เพราะ Backend แค่ส่งคำสั่งเข้า MQTT ซึ่งเป็นการส่งแบบไม่รอผล ยังไม่รู้ว่าแอร์ทำตามหรือไม่ 202 Accepted คือ "รับคำสั่งแล้ว" ผลจริงรู้จากสถานะที่ ESP32 ส่งกลับมาทาง MQTT แล้ว Backend เก็บลง DB ให้แอปอ่านผ่าน `GET /api/air-conditioners`

> [!ASK]
> **ถาม:** Express 5 ต่างจาก 4 อย่างไรในโปรเจคนี้ ทำไมยังมี `asyncHandler`?
> **ตอบ:** Express 5 ส่ง error ของ handler แบบ async เข้า error handler ให้เองโดยไม่ต้องห่อ (ใน 4 ถ้าไม่ห่อ โปรเซสอาจค้างหรือล้ม) โปรเจคยังห่อด้วย `asyncHandler` เพื่อรูปแบบเดียวกันทุกไฟล์และไม่พึ่งพฤติกรรมเฉพาะเวอร์ชัน

> [!ASK]
> **ถาม:** รันเทสต์อย่างไร และเทสต์อะไรไปแล้วบ้าง?
> **ตอบ:** `npm test` ใช้ตัวรันเทสต์ของ Node (`node --test`) รวม 136 กรณีใน 21 ไฟล์ (ณ 14 ต.ค. 2569) ส่วนใหญ่เป็นเทสต์ของฟังก์ชัน pure ใน `utils/` ที่เรียกได้ตรง ๆ และมีเทสต์แบบ integration หนึ่งไฟล์ (`profile-email.test.js`) ที่เปิดเซิร์ฟเวอร์จริงแต่แทน DB ด้วยของปลอม จุดที่ยังไม่มีเทสต์ตรงคือ flow login และ OTP ผ่าน HTTP

> [!ASK]
> **ถาม:** ให้แอดมินอัปโหลดไฟล์ขึ้นเซิร์ฟเวอร์ผ่านเว็บ ไม่อันตรายเหรอ ตรวจอะไรบ้าง?
> **ตอบ:** ตรวจห้าชั้นครับ (เพิ่ม 14 ต.ค. 2569) หนึ่ง เส้นนี้อยู่ใต้ `authenticate` + `requireAdmin` ทั้ง router สอง ชื่อไฟล์ต้องผ่าน regex `^[A-Za-z0-9][A-Za-z0-9._-]{0,118}\.bin$` และห้าม `..` จึงเขียนนอกโฟลเดอร์ `FIRMWARE_DIR` ไม่ได้ สาม ชนิดจากชื่อต้องตรงแท็บที่อัปโหลด สี่ เนื้อไฟล์ต้องขึ้นต้นด้วยไบต์ `0xE9` ของโปรแกรม ESP32 และไม่เกิน `0x1F0000` ไบต์ ห้า ไม่เขียนทับไฟล์เดิมถ้าไม่ยืนยัน `?replace=1` และเขียนผ่านไฟล์ชั่วคราวแล้ว rename ไฟล์ที่อัปโหลดไม่ถูกรันบนเซิร์ฟเวอร์ แค่ถูกเสิร์ฟให้บอร์ดดาวน์โหลด

> [!ASK]
> **ถาม:** ลบอุปกรณ์ในแอปแล้ว ข้อมูลในตัวบอร์ดหายด้วยไหม?
> **ตอบ:** ตั้งแต่ 13 ต.ค. 2569 หายครับถ้าบอร์ดออนไลน์ Backend ส่งคำสั่ง `unprovision` ให้บอร์ดล้าง Wi-Fi, MQTT, ห้อง และสถานะแอร์ใน NVS แล้วรีบูตเข้าโหมดตั้งค่าบลูทูธ Backend รอคำตอบ 4 วินาทีแล้วตอบแอปว่า `boardCleared` เป็น true หรือ false ถ้าออฟไลน์ ต้องไปล้างที่ตัวบอร์ดเอง แต่บอร์ดก็ใช้บัญชี MQTT เดิมต่อไม่ได้แล้ว เพราะบัญชีถูกลบ

> [!ASK]
> **ถาม:** API ของแอร์มีฟิลด์ `controlType` มาทำไม ในเมื่อมี `protocol` อยู่แล้ว?
> **ตอบ:** (เพิ่ม 11 ต.ค. 2569) `controlType` สรุปให้แอปและเว็บเหลือแค่สองค่า `"wired"` (บอร์ดต่อสายแทนรีโมตติดผนัง Daikin, `protocol = DAIKIN_WIRED`) กับ `"ir"` (ยิงรีโมต ทุกโปรโตคอลที่เหลือ) คำนวณใน `publicAirConditioner` ด้วย `controlTypeOf(row.protocol)` ไม่ได้เก็บเป็นคอลัมน์ จึงไม่มีทางขัดกับ `protocol` หน้าจอใช้ค่านี้ซ่อนปุ่มที่รีโมตติดผนังไม่มี (Eco, Turbo, Quiet, Clean, สวิงแนวนอน) โดยไม่ต้องรู้รายชื่อโปรโตคอลทั้งหมด ถ้าวันหนึ่งมีบอร์ดสายแอร์ยี่ห้ออื่น แก้ที่ Backend จุดเดียว ส่วนการตรวจจริงยังอยู่ที่ `validateAirState(body, protocol)` ตอนรับคำสั่ง ถ้าแอปส่งค่าที่ใช้ไม่ได้มาก็ถูกปฏิเสธหรือปิดให้

## สรุปและเช็กลิสต์ความเข้าใจ

ถ้าตอบข้อเหล่านี้ได้ แปลว่าเข้าใจบทนี้แล้ว

- [ ] อธิบายความต่างของ GET / POST / PUT / PATCH / DELETE และรหัส 200, 201, 202, 204, 400, 401, 403, 404, 409, 429, 500, 503 ได้
- [ ] เล่าลำดับ `server.js` → `app.js` ได้ รวมว่าทำไมแยกสองไฟล์ และ `assertServerConfig()` ล้มเมื่อไหร่
- [ ] บอกได้ว่า `config.js` อ่านอะไร ค่าเริ่มต้นสำคัญคืออะไร และ `unsafeSecret` ตรวจอย่างไร
- [ ] อธิบายลำดับ middleware: helmet → cors → express.json → router → authenticate → (requireAdmin) → handler → notFound/error handler
- [ ] อธิบายโครง JWT (header.payload.signature), claims ที่ใส่ (`sub`, `role`, `ver`, `iss`, `aud`, `exp`) และว่า `authenticate` ตรวจอะไรบ้างทีละขั้น
- [ ] อธิบาย `token_version` และเมื่อไหร่ที่มันเพิ่ม (เปลี่ยนรหัสผ่านทั้งสองวิธี, แอดมินเปลี่ยน role/is_active)
- [ ] อธิบายว่าทำไม login มี dummy hash และตอบข้อความเดียว
- [ ] จำตัวเลข: login 10/15 นาที, ยืนยันรหัสผ่าน 10/15 นาที (นับเฉพาะที่ผิด), reset 8/ชั่วโมง (ใช้ร่วมกัน), OTP 6 หลัก/10 นาที/ผิด 5 ครั้ง, bcrypt cost 12, รหัสผ่าน 8 ตัว–72 ไบต์, JWT 8 ชั่วโมง, body 256 KB
- [ ] เล่า flow ลืมรหัสผ่านสามขั้น และอธิบาย pepper, HMAC, `safeHashEquals`, `FOR UPDATE`
- [ ] อธิบายเหตุผลที่เปลี่ยนอีเมลต้องใส่รหัสผ่านปัจจุบัน
- [ ] ยกตัวอย่าง endpoint ของแต่ละไฟล์ route และบอกได้ว่า endpoint ไหนต้องเป็น admin / ไม่ต้องล็อกอิน / staff ก็ทำได้ (`command`)
- [ ] อธิบาย parameter binding และจุดที่ SQL ถูกประกอบเป็นสตริง (`where`, `fields`, `LIMIT`) ว่าทำไมยังปลอดภัย
- [ ] อธิบายว่าทำไม `pool` เป็น lazy และ `withTransaction` ทำงานอย่างไร
- [ ] อธิบายว่าทำไมการนำเข้าตารางเรียนทำใน transaction เดียว และทำไม `/terms` ต้องประกาศก่อน `/:id`
- [ ] อธิบายว่า `node --test` ทำงานอย่างไร, ทำไม `profile-email.test.js` ใช้ `await import` และแทน `pool.query`, และ util pure ช่วยการทดสอบอย่างไร
- [ ] บอกข้อจำกัดที่ตรวจพบ: JSON เสียรูปแบบ/CORS ถูกปฏิเสธ ตอบ 500, ตัวนับ rate limit อยู่ใน RAM, ไม่มีเทสต์ตรงของ login/OTP, `package.json` description เก่า
- [ ] อธิบายการอัปโหลดเฟิร์มแวร์ `POST /api/firmware`: `express.raw`, `X-File-Name`, `?kind`, `?replace=1`, ไบต์ `0xE9`, เพดาน `0x1F0000`, ไฟล์ `.part` + rename (เพิ่ม 14 ต.ค. 2569)
- [ ] เล่าลำดับการลบอุปกรณ์ 4 ขั้น (ลบแถว → unprovision รอ ≤ 4 วินาที → ล้าง retained → ลบบัญชี MQTT) และความหมายของ `boardCleared` (เพิ่ม 13 ต.ค. 2569)
