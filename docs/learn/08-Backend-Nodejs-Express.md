# 08 · Backend — Node.js + Express

> Backend คือ "สมองกลาง" ของระบบ บทนี้สอน
> (1) JavaScript เท่าที่ต้องใช้อ่านโค้ด (2) npm และ `package.json`
> (3) Express ทำงานอย่างไร (4) ไล่โค้ดจริงทีละไฟล์ (5) ระบบล็อกอิน/OTP
> (6) รัน ทดสอบ และลองเพิ่ม API เอง
> เหตุผลการออกแบบเชิงลึก: `docs/study/02-backend.md`

---

## ส่วนที่ 1 · JavaScript ที่ต้องรู้เพื่ออ่านโค้ด Backend

ลองรันตัวอย่างได้ทันทีโดยสร้างไฟล์ `try.js` แล้วพิมพ์ `node try.js`

### 1.1 ตัวแปร

```javascript
const port = 3000;          // const = ค่าคงที่ เปลี่ยนไม่ได้ (ใช้เป็นหลัก)
let count = 0;              // let = เปลี่ยนได้
count = count + 1;
// var  = แบบเก่า โปรเจกต์ไม่ใช้
```

### 1.2 ชนิดข้อมูล

```javascript
const text = 'สวัสดี';               // string
const n = 24.5;                      // number
const on = true;                     // boolean
const nothing = null;                // ไม่มีค่า (ตั้งใจ)
let notSet;                          // undefined (ยังไม่ได้ตั้ง)
const list = [1, 2, 3];              // array
const user = { username: 'admin', role: 'admin' };   // object
console.log(user.username);          // 'admin'
console.log(list[0]);                // 1 (index เริ่มที่ 0)
```

### 1.3 Template literal — ข้อความที่แทนค่าได้

```javascript
const deviceId = 'ESP32-AABB';
const topic = `rmutt/ac/${deviceId}/command`;    // ใช้ backtick ` ไม่ใช่ '
// → 'rmutt/ac/ESP32-AABB/command'
```

### 1.4 ฟังก์ชัน

```javascript
function add(a, b) {
  return a + b;
}
const add2 = (a, b) => a + b;              // arrow function แบบสั้น
const square = (x) => {                    // arrow function หลายบรรทัด
  const result = x * x;
  return result;
};
```

### 1.5 Destructuring และ Spread

```javascript
const { username, role } = user;           // ดึงค่าจาก object ออกมาเป็นตัวแปร
const [, deviceId, type] = match;          // ดึงจาก array (ข้ามตัวแรก)
const copy = { ...user, role: 'staff' };   // คัดลอก object แล้วทับบางค่า
```

### 1.6 Optional chaining `?.` และ Nullish `??`

```javascript
const name = request.body?.username;       // ถ้า body เป็น null → ได้ undefined ไม่ error
const port = process.env.PORT ?? 3000;     // ถ้าซ้ายเป็น null/undefined → ใช้ขวา
```

เจอบ่อยมากในโปรเจกต์ เช่น `process.env.DB_HOST ?? '127.0.0.1'`

### 1.7 Array method ที่ใช้บ่อย

```javascript
[1, 2, 3].map((x) => x * 2);              // [2, 4, 6]       แปลงทุกตัว
[1, 2, 3].filter((x) => x > 1);           // [2, 3]          กรอง
[1, 2, 3].find((x) => x > 1);             // 2               หาตัวแรก
['a', 'b'].join(', ');                    // 'a, b'          ต่อเป็นข้อความ
rows.map(publicAirConditioner);           // ในโปรเจกต์: แปลงแถว DB เป็นข้อมูลที่ส่งให้แอป
```

### 1.8 Asynchronous — `async` / `await` (สำคัญที่สุด)

งานที่ต้องรอ (ถามฐานข้อมูล, ส่งอีเมล, ส่ง MQTT) ใช้เวลา ถ้าโปรแกรมหยุดรอเฉย ๆ
คนอื่นที่เรียก API พร้อมกันจะต้องรอด้วย JavaScript จึงใช้ **Promise**
= "สัญญาว่าจะได้ผลในอนาคต"

```javascript
async function getRooms() {                           // async = ฟังก์ชันนี้มีการรอ
  const rows = await pool.query('SELECT * FROM rooms'); // await = รอผลตรงนี้ (แต่ไม่บล็อกคนอื่น)
  return rows;
}
```

- `await` ใช้ได้เฉพาะในฟังก์ชันที่มี `async`
- ลืม `await` → ได้ Promise แทนข้อมูลจริง (บั๊กที่พบบ่อย)

### 1.9 Error handling

```javascript
try {
  await pool.query('...');
} catch (error) {
  console.error('พัง:', error.message);
} finally {
  await pool.end();     // ทำเสมอ
}

throw new Error('ข้อความ');           // โยน error เอง
```

### 1.10 Module — `import` / `export`

`package.json` มี `"type": "module"` → ใช้ ES Module

```javascript
// ไฟล์ utils/http.js
export class ApiError extends Error { ... }
export function asyncHandler(handler) { ... }

// ไฟล์อื่น
import { ApiError, asyncHandler } from '../utils/http.js';   // ต้องมี .js
import express from 'express';                               // จาก node_modules
import crypto from 'node:crypto';                            // โมดูลในตัว Node
```

### 1.11 Class

```javascript
export class ApiError extends Error {      // สืบทอดจาก Error
  constructor(statusCode, message) {
    super(message);                        // เรียก constructor ของแม่
    this.statusCode = statusCode;          // เก็บค่าไว้ใน object
  }
}
throw new ApiError(404, 'ไม่พบห้อง');
```

---

## ส่วนที่ 2 · Node.js, npm และ `package.json`

### 2.1 Node.js คืออะไร
JavaScript เดิมรันได้แค่ในเบราว์เซอร์ **Node.js** ทำให้รันบนคอม/เซิร์ฟเวอร์ได้
และเข้าถึงไฟล์ เครือข่าย ฐานข้อมูลได้

### 2.2 `backend/package.json` อ่านทีละส่วน

```json
{
  "name": "rmutt-save-energy-api",
  "version": "1.0.0",
  "private": true,                         // ห้ามเผลอ publish ขึ้น npm
  "type": "module",                        // ใช้ import/export
  "engines": { "node": ">=20" },           // ต้อง Node 20 ขึ้นไป
  "scripts": { ... },                      // คำสั่งลัด (ดูข้อ 2.4)
  "dependencies": { ... }                  // ไลบรารีที่ต้องใช้
}
```

### 2.3 Dependencies แต่ละตัวทำอะไร

| ไลบรารี | หน้าที่ | ใช้ที่ |
|---|---|---|
| `express` | เฟรมเวิร์กทำ HTTP server | `app.js`, `routes/*` |
| `cors` | อนุญาตให้เว็บจากโดเมนอื่นเรียก API | `app.js` |
| `helmet` | ใส่ HTTP header ด้านความปลอดภัยอัตโนมัติ | `app.js` |
| `express-rate-limit` | จำกัดจำนวนครั้งที่เรียก (กันเดารหัส) | `routes/auth.js` |
| `dotenv` | อ่านไฟล์ `.env` เข้า `process.env` | `config.js` |
| `mariadb` | ต่อฐานข้อมูล MariaDB | `db.js` |
| `bcryptjs` | hash รหัสผ่าน | `routes/auth.js`, `routes/users.js` |
| `jsonwebtoken` | สร้าง/ตรวจ JWT | `routes/auth.js`, `middleware/authenticate.js` |
| `mqtt` | MQTT client | `services/mqtt.js` |
| `nodemailer` | ส่งอีเมล SMTP | `services/mailer.js` |
| `fflate` | บีบอัด/แตกไฟล์ zip (ไฟล์ .xlsx คือ zip) | `utils/xlsx-*.js` |
| `fast-xml-parser` | อ่าน XML ในไฟล์ .xlsx | `utils/xlsx-reader.js` |

รุ่น `^5.1.0` = ใช้ 5.1.0 ขึ้นไปได้ แต่ต้องต่ำกว่า 6.0.0

### 2.4 Scripts — คำสั่ง `npm run ...` ทั้งหมด

| คำสั่ง | รันจริง | ใช้เมื่อ |
|---|---|---|
| `npm start` | `node src/server.js` | เปิด Backend ปกติ |
| `npm run dev` | `node --watch src/server.js` | ตอนแก้โค้ด — **แก้ไฟล์แล้วรีสตาร์ทเอง** |
| `npm test` | `node --test` | รันชุดทดสอบทั้งหมดใน `test/` |
| `npm run db:init` | `node scripts/init-db.js` | สร้างตาราง (บท 07) |
| `npm run db:doctor` | `node scripts/doctor.js` | ตรวจโครงฐานข้อมูล |
| `npm run db:migrate:*` | `node scripts/migrate-*.js` | อัปเกรดฐานข้อมูล (บท 07) |
| `npm run seed:admin` | `node scripts/seed-admin.js` | สร้างแอดมินจาก `.env` |
| `npm run migrate:legacy` | `node scripts/migrate-legacy-user.js` | ย้ายผู้ใช้จากตารางเก่า |
| `npm run schedules:convert` | `node scripts/convert-schedule-file.js` | แปลงไฟล์ตารางเรียน |

> 💡 `npm start` และ `npm test` พิมพ์สั้นได้ (ไม่ต้องมี `run`) คำสั่งอื่นต้องมี `run`
> ส่งอาร์กิวเมนต์ต่อให้สคริปต์ใช้ `--` เช่น `npm run db:doctor -- --fix`

### 2.5 `node_modules` และ `package-lock.json`

- `node_modules\` = ไลบรารีที่ดาวน์โหลดมา (หลายพันไฟล์) **ไม่ส่งขึ้น Git** สร้างใหม่ได้เสมอ
- `package-lock.json` = บันทึกรุ่น **ที่แน่นอน** ของทุกไลบรารี (และไลบรารีของไลบรารี)

| คำสั่ง | ความหมาย |
|---|---|
| `npm ci` | ลบ `node_modules` แล้วติดตั้งตาม lock เป๊ะ ๆ (ใช้ประจำ) |
| `npm install` | ติดตั้งและอาจอัปเดต lock |
| `npm install <ชื่อ>` | เพิ่มไลบรารีใหม่ลง `dependencies` |
| `npm uninstall <ชื่อ>` | ลบไลบรารี |
| `npm outdated` | ดูไลบรารีที่มีรุ่นใหม่ |
| `npm audit` | ตรวจช่องโหว่ความปลอดภัยที่รู้จัก |

---

## ส่วนที่ 3 · Express — เฟรมเวิร์กทำ API

### 3.1 แนวคิด: Request ไหลผ่านท่อ (Middleware chain)

```text
คำขอเข้ามา
   │
   ▼  helmet()           ใส่ header ความปลอดภัย
   ▼  cors()             ตรวจว่าโดเมนนี้เรียกได้ไหม
   ▼  express.json()     แปลง body JSON → request.body (จำกัด 256 KB)
   ▼  router ตาม path     /api/rooms → roomsRouter
       ▼ authenticate     มี token ถูกต้องไหม → request.authUser
       ▼ requireAdmin     (บางเส้นทาง) เป็น admin ไหม
       ▼ handler          ทำงานจริง → response.json(...)
   ▼  notFoundHandler    ไม่มี route ไหนตรง → 404
   ▼  errorHandler       ถ้ามี error ที่ไหน → แปลงเป็น JSON ภาษาไทย
คำตอบออกไป
```

**Middleware** = ฟังก์ชัน `(request, response, next) => {...}`
ทำงานของตัวเองแล้วเรียก `next()` ส่งต่อ หรือ `throw` เพื่อหยุด

### 3.2 Route พื้นฐาน

```javascript
import express from 'express';
const app = express();
app.use(express.json());

app.get('/api/hello', (request, response) => {
  response.json({ message: 'hi' });
});

app.post('/api/echo', (request, response) => {
  response.status(201).json({ youSent: request.body });
});

app.listen(3000);
```

| สิ่งที่ใช้ | ความหมาย |
|---|---|
| `request.body` | JSON ที่ client ส่งมา |
| `request.params.x` | ค่าใน path เช่น `/rooms/:roomNumber` → `request.params.roomNumber` |
| `request.query.x` | ค่าหลัง `?` เช่น `?floor=2` |
| `request.get('authorization')` | อ่าน header |
| `response.json(obj)` | ตอบเป็น JSON (status 200) |
| `response.status(n)` | ตั้ง status code |

---

## ส่วนที่ 4 · ไล่โค้ดจริงทีละไฟล์

### 4.1 โครงสร้างชั้น (layer)

```text
src/
├── server.js       จุดเริ่ม: ตรวจ config → เริ่มบริการเบื้องหลัง → เปิดพอร์ต
├── app.js          ประกอบ Express: middleware + ผูก router ทั้งหมด
├── config.js       อ่าน .env ที่เดียว แปลงเป็น object config
├── db.js           Connection pool ไป MariaDB + withTransaction()
├── middleware/     authenticate.js, require-admin.js
├── routes/         รับ HTTP → ตรวจข้อมูล → เรียก DB/service → ตอบ
├── services/       งานที่คุยกับโลกภายนอก/รันเบื้องหลัง: mqtt, auto-off, mailer, energy-recorder, alerts
└── utils/          ฟังก์ชันบริสุทธิ์ (รับค่า→คืนค่า ไม่แตะ DB) ทดสอบง่าย
```

กติกา: **routes เรียก services/utils ได้, utils ไม่เรียกอะไรที่มีผลข้างเคียง**
ทำให้ `utils/` ทดสอบได้โดยไม่ต้องมีฐานข้อมูล

### 4.2 `server.js` — จุดเริ่มต้น

```javascript
import { app } from './app.js';
import { assertServerConfig, config } from './config.js';
import { pool } from './db.js';
import { startAutoOffService, stopAutoOffService } from './services/auto-off.js';
import { startMqttBridge, stopMqttBridge } from './services/mqtt.js';
import { startMqttAccounts, stopMqttAccounts } from './services/mqtt-accounts.js';

assertServerConfig();        // (1) ตรวจ .env ถ้าค่าลับอ่อนหรือขาด → หยุดทันที
startMqttAccounts();         // (2) ระบบบัญชี MQTT รายบอร์ด (โหมด dynsec)
startMqttBridge();           // (3) ต่อ Mosquitto + subscribe
startAutoOffService();       // (4) ตั้งนาฬิกาตรวจปิดแอร์ทุก 10 วินาที

const server = app.listen(config.port, '0.0.0.0', () => {      // (5) เปิดพอร์ต
  console.log(`RMUTT Save Energy API listening on port ${config.port}`);
});

async function shutdown(signal) {                              // (6) ปิดอย่างสุภาพ
  server.close(async () => {
    stopAutoOffService();
    stopMqttAccounts();
    await stopMqttBridge();
    await pool.end();
    process.exit(0);
  });
}
process.on('SIGINT', () => shutdown('SIGINT'));     // Ctrl+C
process.on('SIGTERM', () => shutdown('SIGTERM'));   // docker stop
```

(5) `'0.0.0.0'` = รับจากทุกการ์ดเครือข่าย มือถือในวง Wi-Fi จึงเรียกได้
(6) ปิด MQTT และฐานข้อมูลให้เรียบร้อยก่อนออก ไม่ทิ้งการเชื่อมต่อค้าง

### 4.3 `config.js` — อ่าน `.env` ที่เดียว

```javascript
import 'dotenv/config';        // โหลด .env เข้า process.env ทันทีที่ import

export const config = {
  port: numberFromEnv('PORT', 3000),
  db: {
    host: process.env.DB_HOST ?? '127.0.0.1',
    ...
  },
  jwtSecret: process.env.JWT_SECRET ?? '',
  ...
};

function unsafeSecret(value) {
  return value.length < 32 || /replace|change|example/i.test(value);
}
```

`assertServerConfig()` ปฏิเสธถ้า `JWT_SECRET` / `OTP_PEPPER` สั้นกว่า 32 ตัว
หรือยังมีคำว่า `replace`, `change`, `example` (ค่าตัวอย่างจาก `.env.example`)
→ **กันลืมเปลี่ยนค่าตัวอย่างก่อนใช้งานจริง**

ข้อความที่จะเห็นถ้าลืม

```text
Error: Missing or unsafe environment settings: JWT_SECRET (generate at least 32 random characters), OTP_PEPPER (...)
```

### 4.4 ตาราง `.env` ของ Backend ครบทุกตัว

| ตัวแปร | ตัวอย่าง | ความหมาย |
|---|---|---|
| `NODE_ENV` | `development` / `production` | โหมด |
| `PORT` | `3000` | พอร์ตของ API |
| `APP_ORIGIN` | `*` หรือ `https://โดเมน` | โดเมนเว็บที่อนุญาต (CORS) คั่นหลายค่าด้วย `,` |
| `TRUST_PROXY` | ว่าง / `1` | จำนวนชั้น proxy ข้างหน้า (Caddy = 1) เพื่ออ่าน IP จริงของผู้ใช้ |
| `DB_HOST` `DB_PORT` `DB_USER` `DB_PASSWORD` `DB_DATABASE` | | การเชื่อมต่อ MariaDB |
| `DB_CONNECTION_LIMIT` | `5` | จำนวนการเชื่อมต่อพร้อมกันสูงสุด |
| `JWT_SECRET` | 96 ตัวอักษรสุ่ม | กุญแจเซ็น token |
| `JWT_EXPIRES_IN` | `8h` | อายุ token |
| `OTP_PEPPER` | 96 ตัวอักษรสุ่ม (**ต่างจาก JWT_SECRET**) | กุญแจ hash OTP |
| `OTP_EXPIRES_MINUTES` | `10` | อายุ OTP |
| `MAIL_MODE` | `console` / `smtp` | console = พิมพ์ OTP ลงหน้าจอ Backend |
| `SMTP_HOST` `SMTP_PORT` `SMTP_SECURE` `SMTP_USER` `SMTP_PASS` `SMTP_FROM` | Gmail: `smtp.gmail.com`, `465`, `true` | ส่งอีเมล (Gmail ต้องใช้ App Password) |
| `MQTT_REQUIRED` | `true` | ไม่มีค่า MQTT ครบ = ไม่ยอมเปิด |
| `MQTT_URL` | `mqtt://192.168.1.10:1883` | ที่อยู่ Broker (**LAN IP**) |
| `MQTT_DEVICE_URL` | `mqtts://โดเมน:8883` | ที่อยู่ที่ส่งให้ ESP32 (ถ้าไม่ตั้ง ใช้ `MQTT_URL`) |
| `MQTT_USERNAME` `MQTT_PASSWORD` | | บัญชี Broker ของ Backend |
| `MQTT_TOPIC_PREFIX` | `rmutt/ac` | prefix ของบอร์ดแอร์ |
| `MQTT_OCCUPANCY_TOPIC_PREFIX` | `rmutt/occupancy` | prefix ของเซ็นเซอร์ |
| `MQTT_DEVICE_AUTH` | `shared` / `dynsec` | บอร์ดใช้บัญชีร่วม / บัญชีรายตัว |
| `MQTT_DEVICE_SECRET` | สุ่ม ≥32 ตัว | ใช้คำนวณรหัส MQTT รายบอร์ด (โหมด dynsec) |
| `FIRMWARE_DIR` | ว่าง / `/firmware` | โฟลเดอร์ไฟล์ `.bin` สำหรับ OTA |
| `SEED_ADMIN_*` | | ใช้กับ `npm run seed:admin` |
| `LEGACY_PHONE_PREFIX` | `0` | เติมเลข 0 หน้าเบอร์ตอนย้ายข้อมูลเก่า |

สร้าง `.env` ครั้งแรก

```powershell
cd backend
Copy-Item .env.example .env
notepad .env
node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"   # รัน 2 ครั้ง ได้ 2 ค่า
```

### 4.5 `db.js` — Connection Pool

**Connection pool** = กลุ่มการเชื่อมต่อฐานข้อมูลที่เปิดค้างไว้ใช้ซ้ำ (ไม่ต้องเปิด-ปิดทุกคำขอ ซึ่งช้า)

```javascript
let instance;
export function getPool() {
  if (!instance) {                      // สร้างครั้งแรกที่มีคนใช้จริงเท่านั้น (lazy)
    instance = mariadb.createPool({ host, port, user, password, database,
      connectionLimit: config.db.connectionLimit,
      bigIntAsNumber: true,             // แปลงเลขใหญ่เป็น number ปกติ
    });
  }
  return instance;
}
export const pool = {
  query: (...args) => getPool().query(...args),
  ...
};
```

ทำไม lazy? เพราะไฟล์ทดสอบที่ import โมดูลซึ่งอ้าง `db.js` จะได้ไม่เปิดการเชื่อมต่อค้าง
จน `npm test` ไม่ยอมจบ

`withTransaction(callback)` = เปิด transaction → รัน callback → commit ถ้าสำเร็จ / rollback ถ้า error

### 4.6 `app.js` — ประกอบทุกอย่าง

```javascript
export const app = express();
app.disable('x-powered-by');                // ไม่บอกโลกว่าใช้ Express
app.set('trust proxy', config.trustProxy);  // อ่าน IP จริงหลัง Caddy
app.use(helmet());
app.use(cors(createCorsOptions()));
app.use(express.json({ limit: '256kb' }));

app.get('/api/health', asyncHandler(async (request, response) => {
  await pool.query('SELECT 1');             // ฐานข้อมูลตอบไหม
  response.json({ status: 'ok', service: 'rmutt-save-energy-api', mqtt: getMqttBridgeStatus() });
}));

app.use('/api/auth', authRouter);
app.use('/api/public', publicRouter);
app.use('/api/rooms', roomsRouter);
app.use('/api/schedules', schedulesRouter);
app.use('/api/air-conditioners', airConditionersRouter);
app.use('/api/occupancy-sensors', occupancySensorsRouter);
app.use('/api/energy', energyRouter);
app.use('/api/firmware', firmwareRouter);
app.use('/api/alerts', alertsRouter);
app.use('/api/settings', settingsRouter);
app.use('/api/users', usersRouter);

app.use(notFoundHandler);   // 404
app.use(errorHandler);      // แปลง error → JSON
```

`app.use('/api/rooms', roomsRouter)` = คำขอที่ขึ้นต้นด้วย `/api/rooms` ส่งให้ `roomsRouter`
ใน `routes/rooms.js` เขียน path ต่อจากนั้น เช่น `roomsRouter.get('/:roomNumber', ...)`
→ path เต็มคือ `/api/rooms/:roomNumber`

### 4.7 `utils/http.js` — จัดการ error ที่เดียว

```javascript
export class ApiError extends Error {
  constructor(statusCode, message) { super(message); this.statusCode = statusCode; }
}

// ห่อ handler แบบ async ให้ error ถูกส่งต่อไป errorHandler (Express 5 รองรับเอง แต่ห่อไว้ชัดเจน)
export function asyncHandler(handler) {
  return (request, response, next) => {
    Promise.resolve(handler(request, response, next)).catch(next);
  };
}

export function errorHandler(error, request, response, next) {
  if (error instanceof ApiError) {
    response.status(error.statusCode).json({ message: error.message });   // error ที่เราตั้งใจโยน
    return;
  }
  console.error(error);                                                   // error ที่ไม่คาดคิด → log
  response.status(500).json({ message: 'เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์' });  // ไม่บอกรายละเอียดให้ผู้ใช้
}
```

ดังนั้นในโค้ด route แค่ `throw new ApiError(404, 'ไม่พบห้อง')` ก็ได้คำตอบ JSON ถูกต้อง
และ **error 500 ทุกตัวจะถูกพิมพ์ในหน้าต่าง Backend** → ดูที่นั่นเวลาแอปขึ้น "เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์"

### 4.8 `middleware/authenticate.js` — ตรวจ token

```javascript
export const authenticate = asyncHandler(async (request, response, next) => {
  const authorization = request.get('authorization') ?? '';
  const [scheme, token] = authorization.split(' ');       // "Bearer eyJ..." → ["Bearer","eyJ..."]
  if (scheme !== 'Bearer' || !token) throw new ApiError(401, 'กรุณาเข้าสู่ระบบ');

  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret, {       // ตรวจลายเซ็น + วันหมดอายุ
      algorithms: ['HS256'],
      issuer: 'rmutt-save-energy-api',
      audience: 'rmutt-save-energy-app',
    });
  } catch {
    throw new ApiError(401, 'รหัสเข้าสู่ระบบหมดอายุหรือไม่ถูกต้อง');
  }

  const rows = await pool.query(
    `SELECT username, first_name, last_name, email, phone, role, token_version
       FROM users WHERE username = ? AND is_active = 1 LIMIT 1`,
    [payload.sub],                                       // sub = username
  );
  const user = rows[0];
  if (!user || Number(user.token_version) !== Number(payload.ver)) {
    throw new ApiError(401, 'กรุณาเข้าสู่ระบบใหม่');       // บัญชีถูกระงับ หรือ token ถูกเพิกถอน
  }
  request.authUser = publicUser(user);                   // ส่งข้อมูลผู้ใช้ต่อให้ handler
  next();
});
```

**`token_version` คืออะไร** — ตัวเลขในตาราง `users` ที่ฝังลงใน token ด้วย (`ver`)
เมื่อ **เปลี่ยนรหัสผ่าน / เปลี่ยนสิทธิ์ / ระงับบัญชี** Backend จะ `token_version + 1`
token เก่าทุกอันมี `ver` ไม่ตรง → ใช้ไม่ได้ทันที (ปกติ JWT เพิกถอนไม่ได้จนกว่าจะหมดอายุ
นี่คือเทคนิคแก้)

`require-admin.js` สั้นมาก: ถ้า `request.authUser.role !== 'admin'` → 403

---

## ส่วนที่ 5 · ระบบบัญชีผู้ใช้ทีละขั้น (`routes/auth.js`)

### 5.1 ล็อกอิน `POST /api/auth/login`

```text
แอป ── {username, password} ──▶ loginLimiter (10 ครั้ง/15 นาที/IP)
                                   │
                          SELECT ... FROM users WHERE username = ? AND is_active = 1
                                   │
              ┌── พบผู้ใช้ ──▶ bcrypt.compare(password, user.password_hash)
              └── ไม่พบ ────▶ bcrypt.compare(password, dummyPasswordHash)   ← ⭐
                                   │
                         ผิด → 401 "Username หรือ Password ไม่ถูกต้อง"
                         ถูก → UPDATE last_login_at
                               jwt.sign({role, ver}, JWT_SECRET, {subject: username, expiresIn: '8h'})
                               ◀── {token, user}
```

⭐ **ทำไมต้อง compare กับ hash ปลอมเมื่อไม่พบผู้ใช้?**
bcrypt ใช้เวลา ~0.2 วินาที ถ้าไม่พบผู้ใช้แล้วตอบทันที คนร้ายจะจับเวลาได้ว่า
"ชื่อนี้ตอบเร็ว = ไม่มีในระบบ" → รู้รายชื่อผู้ใช้ การเทียบกับ hash ปลอมทำให้ใช้เวลาเท่ากันเสมอ
(เรียกว่ากัน **timing attack**) และข้อความ error เหมือนกันทั้งสองกรณี

**bcrypt cost 12** = ทำซ้ำ 2¹² = 4,096 รอบ ช้าโดยตั้งใจ เพื่อให้การเดารหัสแบบล้านครั้งเป็นไปไม่ได้
bcrypt รับรหัสได้ไม่เกิน **72 ไบต์** จึงมีกติกา `isValidNewPassword`: 8 ตัวขึ้นไป และ ≤ 72 ไบต์
(ภาษาไทย 1 ตัว = 3 ไบต์ → ภาษาไทยล้วนได้ไม่เกิน 24 ตัว)

### 5.2 ลืมรหัสผ่าน (3 ขั้น)

```text
① POST /api/auth/forgot-password   {identifier: "username หรือ email"}
   - สุ่ม OTP 6 หลัก (crypto.randomInt 100000–999999)
   - เก็บ HMAC-SHA256(OTP, OTP_PEPPER) ลง password_reset_otps (ไม่เก็บ OTP จริง)
   - ยกเลิก OTP เก่าที่ยังไม่ใช้ของคนนี้
   - ส่งอีเมล (หรือพิมพ์ลงหน้าจอถ้า MAIL_MODE=console)
   ◀── {requestId, message: "หากข้อมูลถูกต้อง ระบบจะส่ง OTP..."}
       ⭐ ตอบเหมือนกันทุกกรณี ไม่บอกว่ามีบัญชีนี้หรือไม่

② POST /api/auth/verify-otp        {requestId, otp}
   - ตรวจ: ยังไม่หมดอายุ (10 นาที), ยังไม่ใช้, ผิดไม่เกิน 5 ครั้ง
   - เทียบ hash ด้วย crypto.timingSafeEqual (กัน timing attack)
   - ผิด → attempts + 1
   - ถูก → สุ่ม resetToken 64 hex เก็บ hash ไว้
   ◀── {resetToken}

③ POST /api/auth/reset-password    {resetToken, newPassword}
   - ใน transaction: หา OTP ที่ reset_token_hash ตรง + FOR UPDATE (ล็อกแถว)
   - UPDATE users SET password_hash = bcrypt(newPassword), token_version + 1
   - ทำเครื่องหมาย OTP ว่าใช้แล้ว
   ◀── {message: "เปลี่ยนรหัสผ่านสำเร็จ"}
```

**ทดสอบบนเครื่องโดยไม่มีอีเมล**: ตั้ง `MAIL_MODE=console` แล้ว OTP จะขึ้นในหน้าต่าง Backend

```text
[development email] Password reset OTP for you@example.com: 482913
```

### 5.3 เส้นทางอื่นของบัญชี

| Method + Path | ต้องล็อกอิน | ทำอะไร |
|---|---|---|
| `GET /api/auth/me` | ✔ | ข้อมูลตัวเอง |
| `PATCH /api/auth/me` | ✔ | แก้ชื่อ อีเมล เบอร์ ของตัวเอง (แก้สิทธิ์ไม่ได้) |
| `POST /api/auth/me/password` | ✔ | เปลี่ยนรหัสโดยใส่รหัสเดิม |
| `GET /api/public/admin-contact` | ✘ | ชื่อและเบอร์แอดมิน (ปุ่มติดต่อแอดมิน) |

---

## ส่วนที่ 6 · รายการ API ทั้งหมด

(✔A = ต้องเป็น admin, ✔ = ล็อกอินก็พอ)

| กลุ่ม | Method + Path | สิทธิ์ | หน้าที่ |
|---|---|---|---|
| ระบบ | `GET /api/health` | ✘ | ตรวจ DB + MQTT |
| บัญชี | `POST /api/auth/login` ฯลฯ | | ดูส่วนที่ 5 |
| ผู้ใช้ | `GET/POST /api/users` | ✔A | รายชื่อ / สร้างผู้ใช้ |
| | `PATCH/DELETE /api/users/:username` | ✔A | เปลี่ยนสิทธิ์/ระงับ / ลบ |
| ห้อง | `GET /api/rooms` | ✔ | ห้องทั้งหมด + สรุปแอร์/เซ็นเซอร์/นาฬิกาปิดอัตโนมัติ |
| | `POST /api/rooms`, `PUT/DELETE /api/rooms/:roomNumber` | ✔A | จัดการห้อง |
| ตารางเรียน | `GET/POST /api/schedules`, `PUT/DELETE /api/schedules/:id` | ✔ / ✔A | คาบเรียน |
| | `POST /api/schedules/import/preview`, `/import/commit` | ✔A | นำเข้าจาก Excel/CSV |
| แอร์ | `GET /api/air-conditioners` | ✔ | แอร์ทั้งหมด + ค่าไฟล่าสุด |
| | `POST /api/air-conditioners/reservations` | ✔A | จองช่องก่อนตั้งค่าบอร์ดผ่าน BLE |
| | `POST /api/air-conditioners/:deviceId/command` | ✔ | สั่งแอร์ → 202 |
| | `POST /api/air-conditioners/:deviceId/setup-mode` | ✔A | สั่งบอร์ดเปิด BLE ตั้งค่าใหม่ทาง MQTT |
| | `POST /api/air-conditioners/:deviceId/ota` | ✔A | สั่งอัปเดตเฟิร์มแวร์ผ่าน Wi-Fi |
| | `PATCH/DELETE /api/air-conditioners/:deviceId` | ✔A | แก้ / ถอดอุปกรณ์ |
| เซ็นเซอร์ | `/api/occupancy-sensors` (GET, reservations, setup-mode, ota, :deviceId) | | เหมือนแอร์ |
| ไฟฟ้า | `GET /api/energy/metrics` | ✔ | รายการค่าที่เลือกได้ (16 ค่า) |
| | `GET /api/energy/live` | ✔ | ค่าไฟสด |
| | `GET /api/energy/summary` | ✔ | สรุปรายวัน/สัปดาห์/เดือน สำหรับกราฟ |
| | `GET /api/energy/history`, `/export` | ✔ | ตารางย้อนหลัง / ดาวน์โหลด .xlsx |
| เฟิร์มแวร์ | `GET /api/firmware` | ✔A | ไฟล์ .bin ที่มีบนเซิร์ฟเวอร์ |
| แจ้งเตือน | `GET /api/alerts`, `POST /api/alerts/:id/acknowledge` | ✔ | การแจ้งเตือน |
| ตั้งค่า | `GET /api/settings`, `PATCH /api/settings/auto-off`, `PATCH /api/settings/rate` | ✔ / ✔A | สวิตช์รวมปิดอัตโนมัติ, อัตราค่าไฟ |

---

## ส่วนที่ 7 · Services ที่ทำงานเบื้องหลัง

| ไฟล์ | ทำอะไร |
|---|---|
| `services/mqtt.js` | ต่อ Broker, subscribe, แยกข้อความตาม topic, อัปเดต DB, publish คำสั่ง, ยืนยัน provisioning, ล้าง retained |
| `services/energy-recorder.js` | รับ status → หาผลต่าง kWh → บวกลงถัง `energy_hourly` ของชั่วโมงนั้น (เวลาไทย) |
| `services/auto-off.js` | `setInterval` ทุก 10 วินาที + ทุกครั้งที่มี status ใหม่ → เรียก `decideAutoOff()` → สั่งปิด/สร้างแจ้งเตือน |
| `services/alerts.js` | สร้าง/ปิดการแจ้งเตือนใน `system_alerts` |
| `services/mailer.js` | ส่งอีเมล OTP ด้วย nodemailer (หรือ console) |
| `services/mqtt-accounts.js` | (โหมด dynsec) สร้าง/ลบบัญชี MQTT ของแต่ละบอร์ดผ่าน Dynamic Security |
| `services/system-settings.js` | อ่าน/เขียน `system_settings` พร้อมแคช |

รายละเอียดการทำงานร่วมกันอยู่ในบท 12

---

## ส่วนที่ 8 · รัน Backend

> 📁 โฟลเดอร์ `backend` · ต้องเปิด MariaDB และ Mosquitto ก่อน

```powershell
npm ci                 # ครั้งแรก หรือเมื่อ package-lock.json เปลี่ยน
npm run db:init        # ครั้งแรก
npm run seed:admin     # ครั้งแรก
npm run dev            # ตอนพัฒนา (รีสตาร์ทเองเมื่อแก้ไฟล์)
# หรือ
npm start              # รันปกติ
```

ผลที่ควรเห็น

```text
Auto-off service started
RMUTT Save Energy API listening on port 3000
MQTT bridge connected
```

(ลำดับบรรทัดอาจสลับกันได้ เพราะการต่อ MQTT เกิดขึ้นพร้อม ๆ กับการเปิดพอร์ต)

ทดสอบ (อีกหน้าต่าง)

```powershell
Invoke-RestMethod http://127.0.0.1:3000/api/health

# ล็อกอินแล้วเก็บ token ไว้ในตัวแปร
$login = Invoke-RestMethod -Method Post -Uri http://127.0.0.1:3000/api/auth/login `
  -ContentType 'application/json' `
  -Body (@{ username = 'admin'; password = 'รหัสของคุณ' } | ConvertTo-Json)
$token = $login.token

# เรียก API ที่ต้องล็อกอิน
$headers = @{ Authorization = "Bearer $token" }
Invoke-RestMethod -Uri http://127.0.0.1:3000/api/rooms -Headers $headers
(Invoke-RestMethod -Uri http://127.0.0.1:3000/api/rooms -Headers $headers).rooms | Format-Table roomNumber, floorNumber, roomType
```

- `Format-Table` = แสดงเป็นตาราง เลือกคอลัมน์ได้

> 💡 เครื่องมือมีหน้าจอสำหรับยิง API: **Postman**, **Insomnia**,
> หรือ extension **REST Client / Thunder Client** ใน VS Code

---

## ส่วนที่ 9 · การทดสอบ (Test)

### 9.1 ทำไมต้องมี test
แก้โค้ดตรงหนึ่งแล้วอีกตรงพังโดยไม่รู้ตัว test คือโค้ดที่ **ตรวจโค้ด** อัตโนมัติ
ทุกครั้งที่แก้ให้รัน `npm test` ถ้าผ่านหมด = มั่นใจขึ้นว่าไม่ได้ทำอะไรพัง

### 9.2 รัน

```powershell
npm test                                  # ทุกไฟล์ใน test/
node --test test/security.test.js         # ไฟล์เดียว
node --test --test-name-pattern="OTP"     # เฉพาะ test ที่ชื่อมีคำว่า OTP
```

ชุดทดสอบ Backend **ไม่ต้องต่อฐานข้อมูล** (ทดสอบ utils ที่เป็นฟังก์ชันบริสุทธิ์) จบในไม่กี่วินาที

### 9.3 อ่าน test จริง: `test/security.test.js`

```javascript
import assert from 'node:assert/strict';     // ตัวตรวจค่า
import test from 'node:test';                // ตัวรัน test ในตัว Node

import { createOtp, hashSecret, isValidNewPassword, safeHashEquals } from '../src/utils/security.js';

test('OTP always contains exactly six digits', () => {
  for (let index = 0; index < 100; index += 1) {
    assert.match(createOtp(), /^\d{6}$/);    // ต้องเป็นตัวเลข 6 หลักพอดี ลอง 100 ครั้ง
  }
});

test('new passwords respect the bcrypt byte limit', () => {
  assert.equal(isValidNewPassword('short'), false);               // สั้นเกิน
  assert.equal(isValidNewPassword('long-enough-password'), true);
  assert.equal(isValidNewPassword('ก'.repeat(30)), false);        // 30×3 = 90 ไบต์ > 72
});
```

| คำสั่ง assert | ความหมาย |
|---|---|
| `assert.equal(a, b)` | a ต้องเท่ากับ b |
| `assert.deepEqual(a, b)` | object/array ข้างในต้องเหมือนกัน |
| `assert.match(text, /regex/)` | ข้อความต้องตรงรูปแบบ |
| `assert.throws(() => ...)` | ต้อง throw error |
| `assert.ok(x)` | x ต้องเป็นจริง |

ผลลัพธ์

(ถ้ารันในหน้าต่าง PowerShell ปกติจะเห็นแบบข้างล่าง ถ้ารันผ่านสคริปต์อาจเห็นรูปแบบ `ok 1 - ...` / `# pass 110` ซึ่งความหมายเหมือนกัน)

```text
✔ OTP always contains exactly six digits (3.1ms)
✔ secret hashes compare without exposing the original value (0.4ms)
✔ new passwords respect the bcrypt byte limit (0.2ms)
ℹ tests 110
ℹ pass 110
ℹ fail 0
```

---

## ส่วนที่ 10 · ลองเขียน API เอง (แบบฝึกหัดลงมือ)

เป้าหมาย: เพิ่ม `GET /api/public/time` ตอบเวลาปัจจุบันของไทย **ไม่ต้องล็อกอิน**

**ขั้น 1** เปิด `backend/src/routes/public.js` เพิ่มท้ายไฟล์

```javascript
publicRouter.get('/time', (request, response) => {
  const now = new Date();
  response.json({
    iso: now.toISOString(),
    bangkok: now.toLocaleString('th-TH', { timeZone: 'Asia/Bangkok' }),
  });
});
```

**ขั้น 2** ถ้ารัน `npm run dev` อยู่ Backend จะรีสตาร์ทเอง (ไม่งั้น Ctrl+C แล้ว `npm start`)

**ขั้น 3** ทดสอบ

```powershell
Invoke-RestMethod http://127.0.0.1:3000/api/public/time
```

**ขั้น 4 (ท้าทาย)** ย้ายการคำนวณไปเป็นฟังก์ชันใน `src/utils/` แล้วเขียน test ใน `test/`
ด้วยรูปแบบเดียวกับ `security.test.js` รัน `npm test` ให้ผ่าน

**ขั้น 5** ลบโค้ดที่ทดลองออก (หรือเก็บไว้ถ้าต้องการ)

---

## ส่วนที่ 11 · Debug เบื้องต้น

| อาการ | ดูที่ |
|---|---|
| แอปขึ้น "เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์" (500) | หน้าต่าง Backend จะมี stack trace สีแดง อ่านบรรทัดแรกของ error |
| `ER_BAD_FIELD_ERROR: Unknown column 'xxx'` | ฐานข้อมูลเก่า → `npm run db:doctor` แล้ว `node scripts/doctor.js --fix` |
| `ECONNREFUSED 127.0.0.1:3306` | MariaDB ไม่ได้เปิด → `docker start mariadb` |
| `ER_ACCESS_DENIED_ERROR` | `DB_USER`/`DB_PASSWORD` ผิด |
| `Missing or unsafe environment settings` | ค่าใน `.env` ขาดหรือยังเป็นค่าตัวอย่าง |
| `EADDRINUSE :3000` | มี Backend อีกตัวรันอยู่ → ปิดหน้าต่างเก่า |
| `/api/health` → `mqtt.connected: false` | ดู `mqtt.lastError` ในผลลัพธ์ และบท 06 / 15 |

ใส่ `console.log` ชั่วคราวเพื่อดูค่า

```javascript
console.log('body =', request.body);
```

**อ่าน stack trace**: บรรทัดที่มี `backend/src/...` คือโค้ดของเรา ตัวเลขท้ายคือ `บรรทัด:คอลัมน์`

```text
Error: Unknown column 'history_pending' in 'field list'
    at .../node_modules/mariadb/...          ← ไลบรารี (ข้าม)
    at async .../backend/src/routes/air-conditioners.js:37:18   ← ⭐ เริ่มดูตรงนี้
```

---

## สรุปบท

- JavaScript: `const`, arrow function, template literal, `?.`, `??`, `async/await`, `import`
- `npm ci` ติดตั้ง, `npm run dev` พัฒนา, `npm start` รัน, `npm test` ทดสอบ
- Express: request ไหลผ่าน middleware → router → handler → errorHandler
- ชั้นโค้ด: server → app → routes → services/utils → db
- ความปลอดภัย: bcrypt, JWT + token_version, HMAC OTP, rate limit, `?` ใน SQL, ตอบเหมือนกันไม่เปิดเผยข้อมูล

## 🧪 แบบฝึกหัด

1. เปิด `routes/rooms.js` หาว่า `POST /api/rooms` ใช้ middleware อะไรบ้าง
2. ล็อกอินด้วย PowerShell แล้วเรียก `GET /api/air-conditioners`
3. ลองเรียก `GET /api/users` ด้วยบัญชี staff — ได้ status อะไร เพราะอะไร
4. ทำแบบฝึกหัดส่วนที่ 10 ให้ครบ 5 ขั้น
5. ตั้ง `MAIL_MODE=console` แล้วทดลองลืมรหัสผ่านจากแอป ดู OTP ในหน้าต่าง Backend
6. อธิบายให้เพื่อนฟังว่าทำไมต้องมี `token_version`

ถัดไป: **บท 09 แอป Flutter**
