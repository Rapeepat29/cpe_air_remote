# 10 · เว็บแอป — HTML, CSS และ JavaScript ล้วน

> เว็บแอปอยู่ในโฟลเดอร์ `webapp/` ใช้ API ชุดเดียวกับแอปมือถือ
> ไม่มีขั้นตอน build ไม่มี npm แก้ไฟล์แล้วรีเฟรชเบราว์เซอร์ก็เห็นผล
> คู่มือเฉพาะของเว็บ: `webapp/README.md`

---

## 1. เว็บเพจประกอบด้วย 3 ภาษา

| ภาษา | หน้าที่ | เปรียบเทียบ | ไฟล์ในโปรเจกต์ |
|---|---|---|---|
| **HTML** | โครงสร้าง / เนื้อหา | โครงบ้าน | `index.html`, `status.html` |
| **CSS** | หน้าตา สี ระยะ ขนาด | สีทาบ้าน เฟอร์นิเจอร์ | `assets/css/*.css` |
| **JavaScript** | พฤติกรรม ดึงข้อมูล ตอบสนองการกด | ไฟฟ้า ประปา | `assets/js/*.js` |

### 1.1 HTML เบื้องต้น

```html
<!DOCTYPE html>
<html lang="th">
<head>
  <meta charset="UTF-8">                       <!-- รองรับภาษาไทย -->
  <title>RMUTT Save Energy</title>             <!-- ชื่อบนแท็บ -->
  <link rel="stylesheet" href="assets/css/base.css">   <!-- โหลด CSS -->
</head>
<body>
  <div class="app" id="app" hidden>            <!-- กล่อง มี class และ id -->
    <aside class="sidebar" id="sidebar">...</aside>
    <main>...</main>
  </div>
  <script type="module" src="assets/js/main.js"></script>   <!-- โหลด JS -->
</body>
</html>
```

- **Tag** = `<ชื่อ> ... </ชื่อ>`
- **Attribute** = ข้อมูลประกอบในแท็ก เช่น `class="app"`, `id="app"`, `hidden`
- `id` = ชื่อเฉพาะ ห้ามซ้ำในหน้า, `class` = กลุ่ม ใช้ซ้ำได้ (CSS ใช้จัดสไตล์)

### 1.2 CSS เบื้องต้น

```css
/* เลือกด้วย class ใส่จุดนำหน้า */
.sidebar {
  width: 240px;
  background: var(--panel);       /* ใช้ตัวแปรสีที่ประกาศใน tokens.css */
}

/* ตัวแปร CSS ประกาศใน :root */
:root {
  --accent: #3ecf8e;              /* สีเขียวหลักของเว็บ (อยู่ใน tokens.css จริง) */
}

/* จอเล็กกว่า 900px (มือถือ) ให้ซ่อนแถบข้าง */
@media (max-width: 900px) {
  .sidebar { display: none; }
}
```

โปรเจกต์แยก CSS เป็น 4 ไฟล์

| ไฟล์ | เนื้อหา |
|---|---|
| `tokens.css` | ตัวแปรสี ระยะห่าง ฟอนต์ — **แก้ธีมที่นี่ที่เดียว** |
| `base.css` | โครงหน้า, การย่อจอ |
| `components.css` | ชิ้นส่วนใช้ซ้ำ (ปุ่ม การ์ด ตาราง) |
| `views.css` | สไตล์เฉพาะแต่ละหน้า |

### 1.3 JavaScript ในเบราว์เซอร์ (ต่างจาก Node อย่างไร)

ภาษาเดียวกับ Backend (บท 08) แต่มีของเพิ่ม

| ของในเบราว์เซอร์ | ใช้ทำอะไร |
|---|---|
| `document` (DOM) | เข้าถึง/สร้าง/แก้ HTML ด้วยโค้ด |
| `fetch()` | เรียก HTTP (แทนไลบรารี http) |
| `localStorage` | เก็บข้อมูลเล็ก ๆ ในเบราว์เซอร์ ปิดเปิดใหม่ยังอยู่ |
| `window.location` | URL ปัจจุบัน |
| `setInterval()` | ทำซ้ำทุก ๆ x มิลลิวินาที |

```javascript
const el = document.createElement('div');   // สร้างกล่อง
el.textContent = 'ห้อง 16302';               // ใส่ข้อความ (ปลอดภัย)
document.getElementById('app').append(el);  // ใส่ลงหน้า
```

---

## 2. ทำไมเว็บนี้ไม่ใช้ React / Vue / build tool

(จาก `README.md` หัวข้อ "ทำไมเป็น HTML + JavaScript ล้วน")
- ผู้ดูแลต่อไปแก้ได้ทันทีด้วย Notepad ไม่ต้องติดตั้ง Node เพื่อ build
- deploy = คัดลอกไฟล์ขึ้นเซิร์ฟเวอร์ Caddy เสิร์ฟทันที
- ใช้ **ES Modules** (`import`/`export`) ที่เบราว์เซอร์รองรับในตัวแทน bundler

---

## 3. โครงสร้างไฟล์ JavaScript

```text
webapp/assets/js/
├── main.js      จุดเริ่ม: startClock(), startApp()
├── config.js    ที่อยู่ API, จังหวะดึงข้อมูล, คีย์ localStorage
├── api.js       ★ ชั้นเดียวที่คุยกับ Backend (ทุกหน้าเรียกผ่านที่นี่)
├── store.js     สถานะกลาง (state) + ดึงข้อมูลซ้ำเป็นรอบ
├── app.js       เมนู แถบบน สลับหน้า ลิ้นชัก
├── auth.js      หน้าเข้าสู่ระบบ / ลืมรหัสผ่าน
├── charts.js    วาดกราฟด้วย SVG เอง
├── format.js    จัดรูปแบบตัวเลข วันที่
├── dom.js       ตัวช่วยสร้าง element
├── icons.js     ไอคอน SVG
├── ui.js        แถบแจ้งผล (toast), กล่องยืนยัน
├── status.js    ใช้กับ status.html
└── views/       9 หน้าจอ
    ├── overview.js   ภาพรวมอาคาร
    ├── rooms.js      ห้อง
    ├── devices.js    ห้องและอุปกรณ์ (แอร์ เซ็นเซอร์ อัปเดตเฟิร์มแวร์)
    ├── energy.js     ข้อมูลไฟฟ้า
    ├── schedule.js   ตารางเรียน
    ├── alerts.js     การแจ้งเตือน
    ├── rates.js      อัตราค่าไฟ
    ├── users.js      จัดการผู้ใช้
    └── settings.js   ตั้งค่า
```

### 3.1 `config.js` — API อยู่ที่ไหน

```javascript
function resolveApiBase() {
  const fromQuery = new URLSearchParams(window.location.search).get('api');  // (1)
  if (fromQuery) {
    window.localStorage.setItem('rmutt.apiBase', fromQuery);                  // (2)
    return fromQuery;
  }
  const saved = window.localStorage.getItem('rmutt.apiBase');                 // (3)
  if (saved) return saved;
  return '/api';                                                               // (4)
}
```

1. ถ้า URL มี `?api=...` ใช้ค่านั้น
2. และจำไว้ใน localStorage
3. ถ้าไม่มีใน URL ใช้ค่าที่เคยจำไว้
4. ไม่มีเลย → `/api` (โดเมนเดียวกับเว็บ — กรณีบนเซิร์ฟเวอร์จริง)

ทำไมบนเซิร์ฟเวอร์ใช้ `/api` เฉย ๆ ได้? เพราะ **Caddy** เสิร์ฟทั้งเว็บและ API ที่โดเมนเดียวกัน
`https://โดเมน/` → ไฟล์เว็บ, `https://โดเมน/api/...` → ส่งต่อไป Backend
โดเมนเดียวกัน = ไม่ติด **CORS** (หัวข้อ 5)

จังหวะดึงข้อมูลใหม่ (`POLL`)

| ข้อมูล | ทุก |
|---|---|
| ค่าไฟสด (`live`) | 10 วินาที |
| ห้อง/เซ็นเซอร์ (`rooms`) | 10 วินาที |
| แจ้งเตือน (`alerts`) | 30 วินาที |
| สรุปค่าไฟ (`summary`) | 2 นาที |

### 3.2 `api.js` — จุดเดียวที่เรียก Backend

```javascript
async function request(method, path, { body = null, query = null } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;          // แนบ token อัตโนมัติ
  if (body != null) headers['Content-Type'] = 'application/json';

  let response;
  try {
    response = await fetch(buildUrl(path, query), {
      method, headers,
      body: body == null ? undefined : JSON.stringify(body),
    });
  } catch (error) {
    throw new ApiError(0, 'ต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจอินเทอร์เน็ต');   // เน็ตหลุด
  }

  if (response.status === 401) {                                // token หมดอายุ
    notifyUnauthorized(message);                                 // ล้าง token → เด้งไปหน้าล็อกอิน
    throw new ApiError(401, message);
  }
  if (!response.ok) {                                            // 4xx/5xx อื่น ๆ
    const payload = await safeJson(response);
    throw new ApiError(response.status, payload?.message ?? `เซิร์ฟเวอร์ตอบกลับรหัส ${response.status}`);
  }
  return safeJson(response);
}
```

ทำไมต้องมีจุดเดียว
1. ไม่มีหน้าไหนลืมแนบ token
2. 401 จัดการที่เดียว พฤติกรรมเหมือนกันทุกหน้า
3. ข้อความ error ภาษาไทยจาก Backend ส่งถึงผู้ใช้ตรง ๆ

### 3.3 `store.js` — สถานะกลาง
- `state` = object เก็บข้อมูลทั้งหมด (ห้อง แอร์ ค่าไฟ แจ้งเตือน)
- `subscribe(listener)` = หน้าจอลงทะเบียนรอรับการเปลี่ยนแปลง
- `startPolling()` = เริ่มดึงข้อมูลซ้ำตาม `POLL`
- เปลี่ยนข้อมูลแล้ว `emit()` → หน้าจอวาดใหม่

แนวคิดเดียวกับ `ChangeNotifier` ใน Flutter (บท 09)

### 3.4 เก็บ token ที่ไหน
`localStorage` (คีย์ `rmutt.token`) — ไม่ใช้ cookie เพราะ Backend ตรวจสิทธิ์จาก header
`Authorization` อย่างเดียว การใช้ cookie จะต้องป้องกัน CSRF เพิ่ม

---

## 4. รันเว็บบนเครื่องตัวเอง

> ⚠️ **ดับเบิลคลิก `index.html` จะไม่ทำงาน** เพราะเบราว์เซอร์ไม่ยอมโหลด ES Module
> จาก `file://` ต้องเปิดผ่าน HTTP server

> 📁 โฟลเดอร์ `webapp`

```powershell
cd webapp
python -m http.server 5500
```

- `python -m http.server` = เปิด web server ง่าย ๆ ที่มากับ Python เสิร์ฟไฟล์ในโฟลเดอร์ปัจจุบัน
- `5500` = พอร์ต
- หยุดด้วย `Ctrl + C`

เปิดเบราว์เซอร์ที่ (ใส่ `?api=` ครั้งแรกครั้งเดียว)

```text
http://127.0.0.1:5500/?api=http://127.0.0.1:3000/api
```

### ต้องตั้ง CORS ที่ Backend

เว็บอยู่ที่ `http://127.0.0.1:5500` แต่ API อยู่ที่ `http://127.0.0.1:3000` = **คนละ origin**
(origin = scheme + host + port ต่างกันตัวเดียวก็นับเป็นคนละ origin)

ใน `backend/.env`

```env
APP_ORIGIN=*
```

หรือเจาะจง

```env
APP_ORIGIN=http://127.0.0.1:5500
```

แล้วรีสตาร์ท Backend

ถ้าลืม จะเห็นใน DevTools (F12 → Console)

```text
Access to fetch at 'http://127.0.0.1:3000/api/...' from origin 'http://127.0.0.1:5500'
has been blocked by CORS policy
```

### เปลี่ยนกลับไปใช้เซิร์ฟเวอร์จริง / ล้างค่าที่จำไว้
เปิด DevTools (F12) → แท็บ Console → พิมพ์

```javascript
localStorage.removeItem('rmutt.apiBase')
```

---

## 5. CORS คืออะไร (อธิบายสั้น)

เบราว์เซอร์มีกฎ **Same-Origin Policy**: หน้าเว็บจากโดเมน A เรียก API ที่โดเมน B ไม่ได้
**เว้นแต่** B บอกว่า "ฉันอนุญาต A" ผ่าน header `Access-Control-Allow-Origin`
ไลบรารี `cors` ใน Backend ใส่ header นี้ตาม `APP_ORIGIN`

- แอป Flutter **ไม่ติด CORS** (กฎนี้มีแค่ในเบราว์เซอร์)
- บนเซิร์ฟเวอร์จริง เว็บกับ API โดเมนเดียวกัน จึงไม่ติด

---

## 6. DevTools — เครื่องมือนักพัฒนาในเบราว์เซอร์ (กด F12)

| แท็บ | ใช้ทำอะไร |
|---|---|
| **Console** | ดู error สีแดง, พิมพ์ JavaScript ทดลอง |
| **Network** | ดูทุกคำขอ HTTP: URL, status, เวลา, ข้อมูลที่ส่ง/รับ (**ใช้บ่อยที่สุด**) |
| **Elements** | ดู/แก้ HTML และ CSS สด ๆ (แก้แล้วไม่บันทึกลงไฟล์) |
| **Application** | ดู localStorage (token, apiBase) |

> 💡 เวลาเว็บ "ไม่ขึ้นข้อมูล" เปิด Network แล้วรีเฟรช ดูว่าคำขอไหนแดง และ status อะไร

---

## 7. ความปลอดภัยของเว็บ

- ข้อมูลจากฐานข้อมูล (ชื่อวิชา ชื่ออาจารย์ ชื่อแอร์) ใส่ลงหน้าด้วย `textContent` เสมอ
  **ไม่ใช้ `innerHTML`** กับข้อมูลผู้ใช้ — กัน **XSS** (คนใส่ `<script>` เป็นชื่อวิชาแล้วขโมย token)
- Caddy ส่ง **Content-Security-Policy** ให้รันได้เฉพาะสคริปต์ที่เป็นไฟล์บนโดเมนเดียวกัน
  (นี่คือเหตุผลที่ `main.js` แยกเป็นไฟล์ ไม่ฝังใน `<script>` ของ HTML)
- ปุ่มที่ซ่อนตามสิทธิ์เป็นแค่ความสะดวก การบังคับจริงอยู่ที่ `requireAdmin` ของ Backend

---

## 8. นำเว็บขึ้นเซิร์ฟเวอร์

```powershell
.\deploy\deploy-web.ps1        # แก้แต่เว็บ — เร็ว ไม่ต้อง build ไม่ต้องรีสตาร์ท
.\deploy\update-server.ps1     # แก้ทั้ง Backend และเว็บ
```

ทั้งสองอัปโหลดไป `/opt/rmutt/www.new` ก่อน แล้ว **คัดลอกเข้า** `/opt/rmutt/www` ตัวเดิม
(ไม่ใช้ `mv` สลับโฟลเดอร์ เพราะ Docker ผูกโฟลเดอร์ตาม inode — สลับแล้ว Caddy จะชี้โฟลเดอร์เก่า
ที่ถูกลบไป และตอบ 404 ทุกหน้า) รายละเอียดในบท 14

Caddy ตั้งแคช: ไฟล์ใน `/assets/` เก็บ 1 ชั่วโมง, หน้า HTML ไม่เก็บแคช
→ ถ้าแก้ CSS/JS แล้วผู้ใช้ยังเห็นของเก่า ให้กด `Ctrl + F5` หรือรอ 1 ชั่วโมง

---

## สรุปบท

- HTML = โครง, CSS = หน้าตา, JS = พฤติกรรม
- เว็บนี้ไม่ต้อง build ใช้ ES Modules
- ทุกคำขอผ่าน `api.js`, สถานะกลางอยู่ `store.js`
- รันบนเครื่อง: `python -m http.server 5500` + `?api=http://127.0.0.1:3000/api` + ตั้ง `APP_ORIGIN`
- F12 → Network คือเครื่องมือแก้ปัญหาอันดับหนึ่ง

## 🧪 แบบฝึกหัด

1. รันเว็บบนเครื่องตามหัวข้อ 4 แล้วล็อกอิน
2. เปิด F12 → Network ดูว่าหน้าภาพรวมเรียก API อะไรบ้าง ทุกกี่วินาที
3. เปิด `assets/css/tokens.css` เปลี่ยนสีหลักหนึ่งสี รีเฟรชดูผล แล้วเปลี่ยนกลับ
4. ในแท็บ Application ของ DevTools หา token ที่เก็บไว้ ลองลบแล้วรีเฟรช เกิดอะไรขึ้น
5. อธิบายว่าทำไมแอป Flutter ไม่ต้องสนใจ CORS แต่เว็บต้องสนใจ

ถัดไป: **บท 11 เฟิร์มแวร์ ESP32**
