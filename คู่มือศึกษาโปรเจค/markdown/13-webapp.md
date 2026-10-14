# เว็บแอป: HTML, CSS และ JavaScript ล้วน

## ภาพรวม

เว็บแอปคือหน้าจอ "ฝั่งคอมพิวเตอร์" ของระบบ RMUTT Save Energy อยู่ในโฟลเดอร์ `webapp/` ใช้ฐานข้อมูลและ API ชุดเดียวกับแอป Flutter บนมือถือทุกอย่าง (ผู้ใช้ชุดเดียวกัน รหัสผ่านชุดเดียวกัน) ต่างกันที่จอกว้างกว่า จึงออกแบบให้ "ดูข้อมูลละเอียดและทำงานกรอกข้อมูลเร็วกว่า" เช่น หน้าข้อมูลไฟฟ้าที่วางตารางสิบกว่าคอลัมน์ นำเข้าตารางเรียนจาก Excel จองการใช้ห้อง จัดการห้องและอุปกรณ์ และ (เพิ่ม 14 ต.ค. 2569) อัปโหลดไฟล์เฟิร์มแวร์แล้วสั่งอัปเดตบอร์ดหลายตัวพร้อมกันจากหน้า "เฟิร์มแวร์"

ในภาพรวมของระบบ เว็บแอปคุยกับ **Backend อย่างเดียว** ผ่าน HTTP ที่ path `/api/*` มันไม่ได้ต่อ MQTT เองและไม่ได้แตะฐานข้อมูลตรง ๆ เมื่อผู้ใช้กดสั่งแอร์ เว็บส่ง `POST /api/air-conditioners/<deviceId>/command` ให้ Backend แล้ว Backend เป็นคนส่งต่อเข้า MQTT ไปหา ESP32 เอง

```text
เบราว์เซอร์ (webapp)  --HTTPS-->  Caddy  --/api/*-->  Backend (Express)  -->  MariaDB / MQTT
                                    |
                                    +--ส่วนที่เหลือ--> ไฟล์ static ใน /srv/www  (index.html, assets/*)
```

Caddy เป็นตัวเดียวที่อยู่หน้าสุด ส่ง `/api/*` ต่อให้ Backend และเสิร์ฟไฟล์ HTML/CSS/JS ที่เหลือจากดิสก์ตรง ๆ เว็บแอปจึงไม่มีขั้นตอน build เลย: ไฟล์ที่เขียนอยู่ในโปรเจกต์ คือไฟล์เดียวกับที่เบราว์เซอร์ดาวน์โหลดไปรัน

โค้ดมี 3 ชั้นที่ควรจำให้ได้ก่อนอ่านต่อ
1. **ชั้นข้อมูล** (`config.js`, `api.js`, `store.js`): รู้ว่า API อยู่ไหน ดึงข้อมูลยังไง เก็บไว้ที่ไหน
2. **ชั้นประกอบหน้า** (`main.js`, `app.js`, `auth.js`): ตัดสินว่าล็อกอินหรือยัง สลับหน้า วาดเมนู
3. **ชั้นหน้าจอ** (`views/*.js` + `charts.js`, `ui.js`, `dom.js`, `format.js`): วาด DOM จากข้อมูลใน store

## ความรู้ที่ต้องมีก่อนอ่านบทนี้

**HTML (โครงของหน้า)** — เป็นแท็กซ้อนกันเป็นต้นไม้ เช่น `<aside>` (แถบข้าง) `<nav>` (กลุ่มเมนู) `<main>` (เนื้อหาหลัก) เบราว์เซอร์อ่านแล้วสร้างเป็น **DOM** (Document Object Model) คือต้นไม้ของ object ที่ JavaScript จับมาแก้ได้ แอตทริบิวต์ `hidden` ซ่อนอิลิเมนต์ ส่วน `data-xxx="..."` คือที่เก็บข้อมูลของเราเองบนแท็ก (ในเว็บนี้ใช้ `data-palette` กับ `data-text` ที่ `<html>` เพื่อสลับธีมและขนาดตัวอักษร)

**CSS (หน้าตา)** — กฎแบบ `ตัวเลือก { คุณสมบัติ: ค่า }`
- **Cascade (การไล่ลำดับ)**: ถ้ามีหลายกฎมาแย่งกำหนดค่าเดียวกัน เบราว์เซอร์เลือกด้วย ความเจาะจงของตัวเลือก (selector) ก่อน แล้วถ้าเท่ากัน กฎที่ "มาทีหลัง" ชนะ นี่คือเหตุผลที่ลำดับโหลดไฟล์ `tokens → base → components → views` สำคัญ
- **Custom properties (ตัวแปร CSS)**: `--accent: #6edb9f;` ประกาศครั้งเดียว ใช้ด้วย `var(--accent)` ที่ไหนก็ได้ ต่างจากตัวแปร Sass ตรงที่เปลี่ยนค่าตอนรันได้ และสืบทอดลงไปตามต้นไม้ ถ้าเปลี่ยน `--accent` ที่ `<html>` ทุกอย่างข้างในเปลี่ยนตาม
- **Design tokens**: ชุดตัวแปรที่ตั้งชื่อตาม "ความหมาย" (`--panel`, `--text-mid`, `--danger`) ไม่ใช่ตามสี (`--green`) ทุกที่ในโค้ดเรียกชื่อความหมาย ธีมจึงเปลี่ยนได้โดยแก้แค่ไฟล์เดียว
- **Flexbox / Grid**: ระบบจัดเรียงอิลิเมนต์ Flex จัดทีละแถว/คอลัมน์ (เมนู ปุ่มเรียงกัน) Grid จัดเป็นตาราง 2 มิติ (`grid-template-columns: repeat(auto-fill, minmax(250px, 1fr))` = ใส่การ์ดเท่าที่พอดีความกว้าง)
- **Media query**: `@media (max-width: 820px) { ... }` ใช้กฎเฉพาะเมื่อจอแคบกว่า 820px เว็บนี้ยังใช้ `(pointer: coarse)` (จอสัมผัส) `(prefers-color-scheme: dark)` (เครื่องตั้งโหมดมืด) และ `(prefers-reduced-motion: reduce)` (ผู้ใช้ขอลดแอนิเมชัน)

**JavaScript ในเบราว์เซอร์** (ต่างจาก Node ตรงที่มี `document` `window` แต่ไม่มี `require`/`fs`)
- **DOM API**: `document.createElement('div')`, `node.textContent = '...'`, `node.appendChild(child)`, `node.classList.add('open')`
- **Event**: `button.addEventListener('click', handler)` เบราว์เซอร์เรียก handler เมื่อผู้ใช้กด
- **fetch + Promise + async/await**: `fetch(url)` ส่งคำขอ HTTP แล้วคืน Promise (ค่าที่ "จะมาในอนาคต") `await` รอจนได้ค่าโดยไม่บล็อกหน้าจอ ใช้ได้เฉพาะใน `async function`
- **ES Modules**: `import { x } from './a.js'` / `export` เบราว์เซอร์โหลดไฟล์ตามที่ import ให้เอง (ต้องใส่ `<script type="module">`) แต่ละไฟล์มีขอบเขตของตัวเอง และโหลดครั้งเดียวต่อ URL จึงเป็น **singleton** โดยปริยาย: `state` ใน `store.js` เป็นตัวเดียวกันทุกไฟล์ที่ import
- **localStorage**: ที่เก็บคู่ key/value ถาวรในเบราว์เซอร์ของเครื่องนั้น (ไม่ส่งไปเซิร์ฟเวอร์) เก็บได้แต่ข้อความ อ่านเขียนอาจ throw error ได้ (โหมดส่วนตัว) จึงต้องห่อ `try/catch` เสมอ

**SPA (Single Page Application)** — โหลด `index.html` ครั้งเดียว แล้วใช้ JavaScript สลับเนื้อหาในหน้าเดิมเมื่อผู้ใช้กดเมนู ไม่โหลดหน้าใหม่ทั้งหน้า ข้อดีคือสลับหน้าเร็วและเก็บสถานะ (เช่น ข้อมูลที่ดึงมาแล้ว) ไว้ได้ ข้อเสียคือต้องจัดการเส้นทางเอง (ในเว็บนี้ใช้ `#/rooms` ใน URL ดูหัวข้อ app.js)

**ทำไมไม่ใช้ framework (React/Vue)** — ข้อดีของมันคือจัดการ "วาดหน้าใหม่เมื่อข้อมูลเปลี่ยน" ให้ แต่ต้องแลกกับขั้นตอน build (Node, npm, bundler) เว็บนี้มี 10 หน้า (หน้าที่ 10 "เฟิร์มแวร์" เพิ่ม 14 ต.ค. 2569) ผู้ดูแลต่อไปเป็นนักศึกษารุ่นน้อง และเซิร์ฟเวอร์แค่คัดลอกไฟล์ขึ้นไปก็จบ จึงเลือกไม่มี build ราคาที่ต้องจ่ายคือ เขียนโค้ดวาด DOM เอง (ดูหัวข้อ dom.js) เปิดไฟล์ด้วยดับเบิลคลิก (`file://`) ไม่ได้ และไม่มีตัวช่วยตรวจ type

**CSP (Content-Security-Policy)** — HTTP header ที่เซิร์ฟเวอร์ส่งไปบอกเบราว์เซอร์ว่า "หน้านี้อนุญาตให้โหลด/รันอะไรจากไหนบ้าง" ของเราตั้งที่ Caddy: `script-src 'self'` = รันได้เฉพาะสคริปต์ที่เป็นไฟล์จากโดเมนเดียวกัน **สคริปต์ที่เขียนฝังในหน้า HTML (`<script>...</script>`) และ handler แบบ `onclick="..."` ถูกบล็อกหมด** จึงไม่มี JavaScript ฝังใน `index.html` เลย (นี่คือเหตุผลที่ `main.js` และ `status.js` ต้องเป็นไฟล์แยก)

**XSS (Cross-Site Scripting)** — ผู้โจมตีใส่ข้อความที่เป็นโค้ด เช่น ชื่อวิชา `<img src=x onerror=...>` เข้าฐานข้อมูล ถ้าหน้าเว็บเอาข้อความนั้นไปต่อเป็น HTML (`innerHTML`) เบราว์เซอร์จะรันมัน โค้ดนั้นอ่าน token จาก localStorage แล้วขโมยได้ วิธีกันของเรามี 2 ชั้น: (1) ข้อมูลจากฐานข้อมูลใส่ด้วย `textContent` เสมอ ซึ่งถือเป็นข้อความล้วน ไม่ตีความเป็น HTML (2) CSP กันสคริปต์แปลกปลอมไว้อีกชั้น

**Same-origin กับ CORS** — **origin** = โปรโตคอล + โดเมน + พอร์ต ปกติเบราว์เซอร์ไม่ยอมให้หน้าจาก origin A อ่านคำตอบจาก origin B เว้นแต่ B ส่ง header CORS บอกว่าอนุญาต เว็บของเรากับ API อยู่ origin เดียวกัน (Caddy เสิร์ฟทั้งคู่) `fetch('/api/...')` จึงไม่ติด CORS และไม่ต้องฝังชื่อโดเมนไว้ในโค้ด ตอนพัฒนาบนเครื่อง (เว็บพอร์ต 5500, API พอร์ต 3000) เป็นคนละ origin ต้องตั้ง `APP_ORIGIN` ที่ Backend ให้อนุญาต (Backend ใช้แพ็กเกจ `cors` ใน `backend/src/app.js` ตรวจ origin กับรายการใน `config.appOrigin`)

**Polling** — ถามเซิร์ฟเวอร์ซ้ำทุกช่วงเวลา (เช่นทุก 10 วินาที) แทนที่จะให้เซิร์ฟเวอร์ผลักข้อมูลมาเอง (WebSocket) ง่ายกว่า ทนกว่า แต่ข้อมูลช้าได้เท่ากับรอบ polling

**PWA manifest** — ไฟล์ JSON (`site.webmanifest`) บอกเบราว์เซอร์ว่าเว็บนี้ชื่ออะไร ไอคอนอะไร สีธีมอะไร และเปิดแบบ `standalone` (ไม่มีแถบ URL) เมื่อผู้ใช้ "ติดตั้ง/เพิ่มลงหน้าจอหลัก" เว็บนี้มีแค่ manifest ไม่มี service worker จึง**ติดตั้งเป็นไอคอนได้ แต่ไม่ทำงานออฟไลน์**

## โครงสร้างโฟลเดอร์

```text
webapp/
├── index.html            เปลือกของแอป: แถบข้าง แถบบน พื้นที่เนื้อหา ลิ้นชัก (ไม่มี JS ฝัง)
├── status.html           หน้าสถานะเบา ๆ (API/MQTT ปกติไหม) ไม่ต้องล็อกอิน
├── site.webmanifest      ข้อมูล PWA: ชื่อ ไอคอน สีธีม
├── README.md             เอกสารของโฟลเดอร์
├── favicon.*, *.png, assets/brand/*.svg   ไอคอนและโลโก้ (ไม่อยู่ในสำเนาโค้ดที่อ่าน แต่ index.html อ้างถึง)
└── assets/
    ├── css/
    │   ├── tokens.css        ตัวแปรทั้งหมด: สี 4 ธีม ขนาดตัวอักษร ระยะ  (ภาษาของหน้าตา)
    │   ├── base.css          reset, โครงหน้า, แถบข้าง, แถบบน, แถบเมนูล่าง, การย่อจอ
    │   ├── components.css    ชิ้นส่วนใช้ซ้ำ: การ์ด ปุ่ม ฟอร์ม ตาราง ลิ้นชัก modal toast
    │   └── views.css         สไตล์เฉพาะของแต่ละหน้า
    └── js/
        ├── main.js           จุดเริ่ม
        ├── app.js            ประกอบร่าง: เมนู สลับหน้า ลิ้นชักรีโมต
        ├── auth.js           หน้าล็อกอิน + ลืมรหัสผ่าน
        ├── config.js         API_BASE, STORAGE, POLL, BUILDING
        ├── api.js            ชั้นเดียวที่เรียก fetch
        ├── store.js          state กลาง + loaders + polling
        ├── format.js         จัดรูปแบบตัวเลข/วันที่/ข้อความแจ้งเตือน
        ├── thai-date-input.js ช่องวันที่ พ.ศ.
        ├── theme.js          ธีมสี 4 แบบ + ตามเครื่อง
        ├── prefs.js          ขนาดตัวอักษร
        ├── charts.js         กราฟ SVG, แถบอันดับ, สี heat
        ├── icons.js          ไอคอน SVG ชุดหลัก
        ├── icons-ui.js       ไอคอน SVG ชุดเสริม
        ├── ui.js             toast, modal, ฟอร์ม, withBusy
        ├── dom.js            ตัวช่วยสร้าง DOM
        ├── status.js         สคริปต์ของ status.html
        └── views/            overview, rooms, energy, schedule (+ schedule-import, term-calendar, booking-form),
                              alerts, rates, devices, firmware (เพิ่ม 14 ต.ค. 2569), users, settings
```

> [!NOTE]
> `docs/learn/10-*.md` เขียนก่อนโค้ดชุดล่าสุด รายการไฟล์ในนั้นไม่ครบ (ไม่มี `prefs.js` `theme.js` `icons-ui.js` `thai-date-input.js` และ `views/firmware.js` ของหน้าเฟิร์มแวร์ ส่วนหน้าเฟิร์มแวร์อธิบายไว้ใน `docs/learn/11-*.md` หัวข้อ 3.4 แทน และมี 3 ไฟล์ช่วยของหน้าตารางเรียน) และโค้ด `config.js` ในนั้นเป็นรุ่นเก่าที่ยอมรับ `?api=` จากทุกโดเมน ในบทนี้ใช้ตามโค้ดจริง

### แผนผัง import ของโมดูล

ลูกศรอ่านว่า "import จาก" (ไม่รวมไฟล์ที่ import เหมือนกันหมด จะเขียนเฉพาะที่สำคัญ)

```text
index.html
  └─ <script type="module"> main.js
        ├─ prefs.js ──────► theme.js ──► dom.js
        ├─ theme.js
        └─ app.js
             ├─ api.js ──────► config.js
             ├─ auth.js ─────► api.js, dom.js, icons.js, ui.js, config.js
             ├─ store.js ────► api.js, config.js (POLL), format.js
             ├─ ui.js ───────► dom.js, icons.js, thai-date-input.js ──► dom.js
             ├─ format.js        (ไม่ import ใคร: ฟังก์ชันล้วน)
             ├─ icons.js, icons-ui.js   (ไม่ import ใคร)
             ├─ theme.js, prefs.js, dom.js, config.js
             └─ views/*.js   (import แบบ static ทั้ง 10 หน้า)
                  ├─ overview.js    ► api, charts, dom, format, icons, thai-date-input, store, ui
                  ├─ rooms.js       ► api, charts, dom, format, icons, icons-ui, store, ui
                  ├─ energy.js      ► api, charts, dom, format, icons, store, ui, thai-date-input
                  ├─ schedule.js    ► api, dom, format, icons, icons-ui, store, ui
                  │                   + schedule-import.js, term-calendar.js, booking-form.js
                  ├─ alerts.js      ► dom, format, store, overview.js (ใช้ alertRow ซ้ำ)
                  ├─ rates.js, devices.js, users.js, settings.js  ► api, dom, format, icons, store, ui
                  ├─ firmware.js    ► api, dom, format, icons-ui, store, ui   (เพิ่ม 14 ต.ค. 2569)
                  └─ settings.js    ► + prefs.js, theme.js
charts.js ► dom.js, format.js
```

กฎที่ถือในโค้ด: ลูกศรชี้ลง "ชั้นล่าง" เท่านั้น `api.js` ไม่รู้จัก `store.js`, `store.js` ไม่รู้จักหน้าจอ, หน้าจอ import `store` และ `api` ได้ ไม่มีวงกลม (A import B แล้ว B import A) ถ้ามี ES Modules จะเริ่มสับสนว่าไฟล์ไหนพร้อมก่อน

### ลำดับการบูต

1. เบราว์เซอร์โหลด `index.html` → อ่าน `<link rel=stylesheet>` 4 ไฟล์ → เจอ `<script type="module" src="assets/js/main.js?v=4.4">` ซึ่งดาวน์โหลดแบบไม่บล็อกการวาดหน้า
2. `main.js` ทำ 4 อย่างตามลำดับ: `applyPrefs()` `applyTheme()` `startClock()` `startApp()`
3. `startApp()` (ใน `app.js`) เก็บอิลิเมนต์สำคัญไว้ (`cacheDom`), ผูกปุ่มและคีย์ลัด (`wireShell`), ลงทะเบียน handler 401 (`onUnauthorized`) แล้วดูว่ามีผู้ใช้เก็บไว้ใน localStorage ไหม
4. **ไม่มี** → `showLogin()` ซ่อน `#app` แล้ววาดหน้าล็อกอินจาก `auth.js` เมื่อสำเร็จเรียก `enterApp(user, { verify: false })`
5. **มี** → `enterApp(cached, { verify: true })` วาดเมนู สมัครรับแจ้งจาก store แล้ว `navigate()` ไปหน้าตาม hash ทันที (ตอนนี้ state ยังว่าง หน้าจึงวาด "กำลังโหลด") แล้วถาม `api.me()` ยืนยันโทเคนกับเซิร์ฟเวอร์
6. ผ่านแล้ว `await bootstrap()` (ดึงข้อมูลชุดแรกขนานกัน) → `startPolling()` ดึงเป็นรอบต่อ ทุกครั้งที่ state เปลี่ยน `emit()` จะเรียก `current.update()` ของหน้าที่เปิดอยู่ให้วาดใหม่

## อธิบายทีละไฟล์

### `index.html`

เปลือกของแอป ไม่มีเนื้อหาจริง มีแค่โครงที่ JavaScript เอามาเติม
- `<html lang="th">`, `<meta viewport ... viewport-fit=cover>` (ให้เนื้อหาไปถึงขอบจอ iPhone แล้ว CSS ใช้ `env(safe-area-inset-*)` เว้นรอยบาก), `<meta name="color-scheme" content="dark light">` (บอกเบราว์เซอร์ว่ารองรับทั้งสองโหมด ให้ scrollbar/ฟอร์มดั้งเดิมเปลี่ยนสีตาม), `<meta name="theme-color">` (สีแถบเบราว์เซอร์บนมือถือ `theme.js` เปลี่ยนค่านี้ตามธีม)
- `<link rel="icon">` ×2, `apple-touch-icon`, `manifest` → ไอคอนและ PWA
- Google Fonts เป็น "ของเสริม": `preconnect` ไว้ก่อน ถ้าเครือข่ายมหาวิทยาลัยบล็อก ฟอนต์จะถอยไปใช้ Sarabun/Leelawadee UI/Tahoma ตาม `--font-thai` ใน `tokens.css`
- CSS 4 ไฟล์เรียง tokens → base → components → views และ `?v=` เป็นเลขเวอร์ชันบังคับให้เบราว์เซอร์โหลดใหม่หลัง deploy
- `<div class="app" id="app" hidden>` ซ่อนไว้จนกว่าจะล็อกอิน ข้างในมี `<aside class="sidebar">` (โลโก้ SVG ฝังตรง ๆ, `<nav id="navMain">`, `<nav id="navSystem">`, ปุ่ม `userChip`), `<header class="topbar">` (`pageTitle` `pageSub` `todayLine` `topbarRight`) และ `<main class="view active" id="viewRoot">` ที่หน้าต่าง ๆ จะถูกวาดลงมา
- นอก `#app` มี `drawer-overlay` + `<aside id="drawer">` (ลิ้นชักรีโมตแอร์) `scrim` (ฉากทึบหลังเมนูมือถือ) และ `<noscript>` บอกให้เปิด JavaScript
- ท้ายสุดมีสคริปต์ตัวเดียว `type="module"`

ทำไมเมนูว่างเปล่าแล้วให้ JS เติม? เพราะเมนูของแอดมินกับเจ้าหน้าที่ไม่เหมือนกัน ต้องรู้บทบาทก่อนจึงวาดได้

### `status.html` + `assets/js/status.js`

หน้าเล็กอิสระ ไม่ใช้ CSS/JS ของแอปหลัก เปิดได้ที่ `/status.html` โดยไม่ต้องล็อกอิน ใช้ตรวจเร็ว ๆ ว่าระบบหลังบ้านยังมีชีวิตอยู่ไหม หน้าแสดง 4 แถว: API, MQTT Broker, Topic, เวลาตรวจล่าสุด
- `status.js` มี `set(id, state, text)` (ตั้ง class `ok`/`bad`/`wait` ให้ป้าย) และ `check()` ที่ `fetch('/api/health', { cache: 'no-store' })` (บอกเบราว์เซอร์ว่าห้ามใช้ของแคช) แล้วอ่าน `data.status` (`'ok'` = API ปกติ), `data.mqtt.connected`, `data.mqtt.topicPrefix` (แสดงเป็น `<prefix>/#`)
- เรียก `check()` ทันที แล้ว `setInterval(check, 15000)` ทุก 15 วินาที (polling ที่ง่ายที่สุด)
- ถ้า fetch ล้มเหลวทั้งก้อน (`catch`) แสดง "ติดต่อไม่ได้" / "ไม่ทราบสถานะ"
- ฝั่ง Backend `/api/health` ทำ `SELECT 1` ก่อน (ถ้า DB ล่ม จะไม่ตอบ ok) และบนโหมด production ซ่อนที่อยู่ Broker ไว้ เปิดเผยแค่ `connected`, `deviceAuth`, `topicPrefix`
- ใช้ `<style>` ฝังใน HTML ได้ เพราะ CSP อนุญาต `style-src 'unsafe-inline'` แต่ใช้ `<script>` ฝังไม่ได้ จึงแยก `status.js` ออกมา และ `status.js` ไม่ใช่ module (ไม่มี import) จึงโหลดด้วย `<script src>` ธรรมดา
- `el.innerHTML = '<i class="dot"></i>' + text` ปลอดภัยเพราะ `text` เป็นข้อความคงที่ในไฟล์เอง ไม่ใช่ข้อมูลจาก API

### `site.webmanifest`

```json
{ "name": "RMUTT Save Energy", "short_name": "RMUTT Energy",
  "icons": [192x192, 512x512, maskable 512x512 (purpose: "maskable")],
  "theme_color": "#2F3438", "background_color": "#2F3438", "display": "standalone" }
```
`short_name` ใช้ใต้ไอคอนบนหน้าจอหลัก `purpose: "maskable"` คือไอคอนที่เผื่อขอบไว้ให้ Android ตัดเป็นวงกลม/สี่เหลี่ยมมุมโค้งได้ `theme_color` กับ `background_color` ใช้สีเทาถ่านเดียวกับโลโก้ ไม่มี `start_url`/`scope` เบราว์เซอร์จึงใช้ URL ที่ติดตั้งเป็นจุดเริ่ม

### `main.js`

จุดเริ่ม 15 บรรทัด ดูในหัวข้อเจาะโค้ด สิ่งสำคัญ: เรียก `applyPrefs()` กับ `applyTheme()` **ก่อน** วาดอะไร เพื่อไม่ให้หน้ากะพริบ (เห็นธีมเทาแวบหนึ่งแล้วเปลี่ยนเป็นขาว)

### `config.js`

ค่าตั้งของแอป 4 อย่างที่ export: `API_BASE` (ที่อยู่ API), `STORAGE` (ชื่อคีย์ localStorage: `token` = `rmutt.token`, `user` = `rmutt.user`, `lastView` = `rmutt.view`, `apiBase` = `rmutt.apiBase`), `POLL` (ช่วง polling ms: `live` 10000, `rooms` 10000, `alerts` 30000, `summary` 120000) และ `BUILDING` (ชื่อ "อาคาร 16" กับคำบรรยาย) ฟังก์ชันภายใน: `isLocalPage`, `normalizeApiBase`, `resolveApiBase` อธิบายทีละบรรทัดในหัวข้อเจาะโค้ด

### `api.js`

ชั้นเดียวที่เรียก `fetch` (ไม่มีหน้าไหนเรียกเอง) export: `ApiError` (error ที่มี `status` และ `payload`), `getToken/setToken`, `getCachedUser/setCachedUser`, `onUnauthorized(handler)`, และออบเจ็กต์ `api` ที่รวม method ของทุก endpoint (ดูตารางด้านล่าง) ภายในมี `request()` `buildUrl()` `safeJson()` และตัวย่อ `get/post/patch/put/remove`

เหตุผลที่รวมไว้ที่เดียว: (1) แนบ `Authorization: Bearer <token>` ทุกคำขอโดยไม่ต้องจำ (2) 401 จัดการที่เดียว (3) ข้อความ error ภาษาไทยจาก Backend ส่งถึงผู้ใช้ตรง ๆ

| กลุ่ม | method ใน `api` → endpoint |
|---|---|
| ระบบ | `health` → GET `/health`; `adminContact` → GET `/public/admin-contact` |
| ล็อกอิน | `login` POST `/auth/login`; `me` GET `/auth/me`; `updateProfile` PATCH `/auth/me`; `changePassword` POST `/auth/me/password`; `forgotPassword` POST `/auth/forgot-password`; `verifyOtp` POST `/auth/verify-otp`; `resetPassword` POST `/auth/reset-password`; `logout` (ล้างโทเคนในเครื่องเท่านั้น ไม่เรียกเซิร์ฟเวอร์) |
| ห้อง | `rooms` GET `/rooms`; `createRoom` POST; `updateRoom` PUT `/rooms/:roomNumber`; `deleteRoom` DELETE |
| แอร์ | `airConditioners` GET `/air-conditioners`; `sendCommand` POST `/air-conditioners/:id/command`; `enterSetupMode` POST `.../setup-mode`; `updateAirConditioner` PATCH; `deleteAirConditioner` DELETE; `reserveAirConditioner` POST `/air-conditioners/reservations`; `otaAirConditioner` POST `.../ota` |
| เซ็นเซอร์คน | `occupancySensors` GET `/occupancy-sensors`; `reserveOccupancySensor` POST `/occupancy-sensors/reservations`; `occupancySetupMode`; `deleteOccupancySensor`; `otaOccupancySensor` |
| เฟิร์มแวร์ | `firmwareFiles` GET `/firmware` (ได้ `configured`, `maxBytes`, `files[]` ที่แต่ละไฟล์มี `name` `kind` `version` `size` `modifiedAt`); **เพิ่ม 14 ต.ค. 2569:** `uploadFirmware(file, fileName, kind, replace)` POST `/firmware` (ไฟล์ดิบ + header `X-File-Name`, query `?kind=` และ `?replace=1`); `deleteFirmware(fileName)` DELETE `/firmware/:fileName` |
| พลังงาน | `energyMetrics` GET `/energy/metrics`; `energyLive` `/energy/live`; `energySources` `/energy/sources`; `energySummary` `/energy/summary`; `energyHistory` `/energy/history`; `exportEnergy` GET `/energy/export` (ดึงเป็น blob) |
| แจ้งเตือน | `alerts` GET `/alerts`; `acknowledgeAlert` POST `/alerts/:id/acknowledge` |
| ตารางเรียน | `schedules`/`schedulesWithInfo` GET `/schedules`; `academicTerms` GET `/schedules/terms`; `saveAcademicTerm` PUT / `deleteAcademicTerm` DELETE `/schedules/terms`; `createSchedule` POST; `updateSchedule` PUT; `deleteSchedule` DELETE; `deleteAllSchedules` DELETE `/schedules`; `previewScheduleImport` POST `/schedules/import/preview`; `commitScheduleImport` POST `/schedules/import/commit` |
| การใช้ห้อง | `bookings` GET `/bookings`; `createBooking` POST; `updateBooking` PUT; `deleteBooking` DELETE |
| ผู้ใช้ | `users` GET `/users`; `createUser` POST; `updateUser` PATCH `/users/:username`; `deleteUser` DELETE |
| ตั้งค่า | `settings` GET `/settings`; `setAutoOffEnabled` PATCH `/settings/auto-off`; `setElectricityRate` PATCH `/settings/rate` |

ทุก path ที่มีค่าจากผู้ใช้ผ่าน `encodeURIComponent(...)` (กัน `/` หรือ `?` ในรหัสห้อง/ชื่อผู้ใช้ทำให้ URL เพี้ยน)

> [!NOTE]
> **แก้ 14 ต.ค. 2569:** `api.js` เพิ่มขึ้น 16 บรรทัด แต่เป็น method ใหม่แค่ **2 ตัว** (`uploadFirmware`, `deleteFirmware`) ที่เหลือคือคอมเมนต์และการจัดบรรทัด `uploadFirmware` ใช้ช่อง `upload` ของ `request()` แบบเดียวกับ `previewScheduleImport` (ส่งไฟล์ดิบ ไม่ห่อ JSON) อธิบายทีละบรรทัดในหัวข้อเจาะโค้ดข้อ 10

### `store.js`

สมองกลางของฝั่งข้อมูล export: `state` (ออบเจ็กต์เดียวทั้งแอป), `subscribe(listener)`, `emit()`, `patchState`, `loaders` (ฟังก์ชันดึงข้อมูลทีละชุด), `startPolling/stopPolling/refreshAll`, `bootstrap`, `resetState` และตัวช่วยอ่าน `airConditionersOf`, `liveReading`, `sensorOf`, `roomsByFloor`, `roomEnergyMap`, `defaultHistoryRange` หัวข้อเจาะโค้ดอธิบาย `load()` และ `tick()`

ฟิลด์ใน `state`: `user`, `settings` (`autoOffEnabled`, `electricityRate` เริ่มต้น 4.5), `health`, `rooms`, `airConditioners`, `occupancySensors`, `live` (`readings`, `totals`, `serverTime`), `alerts` (`alerts`, `counts`), `summary` + `summaryQuery` (`period: 'week'`, `floor: null`), `schedules`, `timetable`, `terms`, `today`, `bookings` + `bookingsRange`, `users`, `metricCatalog`, `loading`, `errors`

ค่า `undefined` กับ `null` ใน `timetable`/`terms`/`bookings` มีความหมายต่างกันโดยตั้งใจ: `undefined` = Backend รุ่นเก่าที่ยังไม่มีฟีเจอร์นี้ (หน้าจอจะซ่อนส่วนนั้น) `null` = มีฟีเจอร์แต่ยังไม่มีข้อมูล

### `format.js`

ฟังก์ชันจัดรูปแบบล้วน ๆ (ไม่แตะ DOM ไม่แตะ state) ยกกติกามาจาก `lib/utils/number_format.dart` ของแอปมือถือเพื่อให้ตัวเลขสองฝั่งตรงกัน
- ตัวเลข: `decimal(value, digits)` (ใส่คอมมา, ไม่ใช่ตัวเลข → `—`), `integer`, `baht`, `energy(kwh, { scaleReference, withUnit })`, `energyUnit`, `scaleReference(values)`
- กติกาหน่วยพลังงาน: ถ้าค่าอ้างอิงใหญ่สุดของชุด < 1 ใช้ **Wh**; ≥ 1000 ใช้ **MWh**; นอกนั้น **kWh** และจำนวนทศนิยมตามขนาด (≥100 → 0 หลัก, ≥10 → 1, ≥1 → 2, น้อยกว่านั้น 3) `0` พอดีเขียน `0 kWh`
- เวลา: `clock(seconds)` → `mm:ss`, `duration(minutes)`, `time(value)` → `HH:mm`, `relativeTime` ("5 นาทีที่แล้ว")
- วันที่ไทย (พ.ศ. = ค.ศ. + 543): `thaiFullDate`, `thaiShortDate` (`25 ส.ค. 69`), `thaiDate` (`25 ส.ค. 2569` อ่าน `YYYY-MM-DD` เป็นวันท้องถิ่น กัน `new Date('2026-08-25')` ที่ตีเป็น UTC แล้วเลื่อนวัน), `isoDate`, `shiftDays`
- **ยี่ห้อและวิธีควบคุมแอร์ (เพิ่ม 11 ต.ค. 2569)**: `WIRED_PROTOCOL` = `'DAIKIN_WIRED'` (บอร์ดสายแอร์ที่ต่อแทนรีโมตติดผนัง Daikin), `isWiredProtocol(protocol)`, ตาราง `BRAND_BY_PROTOCOL` (19 โปรโตคอล → ชื่อยี่ห้อ เช่น `HAIER_AC160` → Haier), `airBrand(protocol)`, `controlTypeLabel(protocol)` ("สายแอร์" / "รีโมต IR"), `airControlSummary(protocol)` ("Daikin · สายแอร์" หรือ "Haier · รีโมต IR (HAIER_AC160)") ใช้ใน `rooms.js` `devices.js` และ `firmware.js` เพื่อให้ผู้ใช้เห็น "ยี่ห้อ" แทนชื่อโปรโตคอลดิบ
- ชื่อ/ป้าย: `floorLabel` (ชั้น ≤ 0 → "ห้องพิเศษ"), `describeAlert(alert)` แปลงรหัส `kind` (`outside_schedule_occupied`, `auto_off_succeeded`, `auto_off_failed`) และรหัส `detail` (`noClassNow`, `noScheduleAtAll`, `outsideTerm`, `attempts=N`) เป็นข้อความไทย, ค่าคงที่ `ALERT_STATUS_LABEL`, `MODE_LABEL`, `FAN_LABEL`, `SWING_LABEL`, `DAY_NAMES`

### `thai-date-input.js`

ช่องวันที่ที่แสดง/พิมพ์เป็น **พ.ศ.** `<input type="date">` ของเบราว์เซอร์แสดงปีตามภาษาเครื่อง ซึ่งมักเป็น ค.ศ. คนพิมพ์ 2569 จะได้ปี ค.ศ. 2569 จริง ๆ ไฟล์นี้ export `thaiDateInput({ name, value, min, max, onChange })`, `isoToThaiText`, `thaiTextToIso`
- ค่าที่อ่านผ่าน `.value` ยังเป็น `YYYY-MM-DD` (ค.ศ.) เหมือน input ธรรมดา โค้ดส่วนอื่นและ API จึงไม่ต้องรู้ว่ามี พ.ศ. (ใช้ `Object.defineProperty(wrapper, 'value', { get, set })` ทำให้ `<div>` ตัวหนึ่ง "เลียนแบบ" input ได้)
- `thaiTextToIso` ยอมรับ `วว/ดด/ปปปป` คั่นด้วย `/` `.` `-` ปี ≥ 2400 ถือเป็น พ.ศ. (ลบ 543) และตรวจว่าวันนั้นมีจริงโดยสร้าง `Date` แล้วเทียบกลับ (31 ก.พ. จะถูกปฏิเสธ)
- มีปฏิทินป๊อปอัป (`paintCalendar`) ปิดเมื่อคลิกนอกกรอบหรือกด Esc และ `min`/`max` ปิดปุ่มวันที่นอกช่วง
- ใช้ใน: `ui.js` (`openForm` ชนิด `date`), `overview.js` (ช่วงวันเอง), `energy.js`, `booking-form.js`

### `theme.js` และ `prefs.js`

ค่าแสดงผลต่อเครื่อง เก็บใน localStorage ไม่ส่งขึ้นเซิร์ฟเวอร์ (เป็นเรื่อง "จอเครื่องนี้" ไม่ใช่ของบัญชี คนเดียวกันอาจอยากได้ธีมสว่างบนคอมแต่ธีมมืดบนมือถือ)

| ไฟล์ | คีย์ localStorage | ค่า | ผลต่อหน้าเว็บ |
|---|---|---|---|
| `theme.js` | `rmutt.palette` (และอ่านคีย์เก่า `rmutt.theme`: `light`→`white`, `dark`→`gray`) | `gray` (ค่าเริ่มต้น) `white` `black` `green` `auto` | ตั้ง `document.documentElement.dataset.palette` + แก้ `<meta name="theme-color">` |
| `prefs.js` | `rmutt.textSize` | `normal` `large` `xlarge` | ตั้ง `dataset.text` (ลบออกถ้า `normal`) → `tokens.css` เปลี่ยน `--text-scale` เป็น 1.1 / 1.22 |

- `theme.js` export `THEMES` (สี swatch + คำอธิบาย), `AUTO`, `THEME_CHOICES`, `themeChoice()` (ที่ผู้ใช้เลือก อาจเป็น `auto`), `activeTheme()` (ที่ใช้จริง: `auto` → ถ้า `matchMedia('(prefers-color-scheme: dark)').matches === false` ใช้ `white` ไม่งั้น `gray`), `applyTheme`, `setTheme`, `onThemeChange`, `themeDots()` (จุดสี 4 จุดบนแถบบน) และฟัง event `change` ของ `darkQuery` เพื่อตามเครื่องเมื่อ OS สลับโหมดเอง
- `prefs.js` export `TEXT_SIZES`, `prefs`, `applyPrefs`, `setTextSize`, `onPrefsChange` และยังคง `THEMES/setTheme/toggleTheme` ไว้เป็น wrapper ให้โค้ดรุ่นเก่าที่ค้างในแคชเรียกได้ (คอมเมนต์หัวไฟล์ยังเขียนว่าใส่ `data-theme` ซึ่งเป็นของเก่า โค้ดจริงตั้งแค่ `data-text`)
- ทำไมแยก `theme.js` ออกจาก `prefs.js`? เพราะไฟล์ใน `/assets` ถูกแคช 1 ชั่วโมง ถ้าเพิ่ม export ใหม่ในไฟล์เดิม เบราว์เซอร์ที่ถือ `prefs.js` เก่าจะหา export ไม่เจอแล้วจอขาวทั้งเว็บ (ดูหลักการ "ไฟล์ใหม่แทน export ใหม่")
- ทำไมใช้ `data-palette` แทน `data-theme`? กัน `prefs.js` รุ่นเก่าที่ค้างแคชและยังเขียน `data-theme="dark"` มาทับธีมใหม่

### `charts.js`

กราฟวาดเองเป็น **SVG** ไม่ใช้ไลบรารี (เหตุผล: ต้องการแค่ 2 แบบ และไลบรารีมักดึงจาก CDN ที่เครือข่ายมหาวิทยาลัยอาจบล็อก) export: `areaChart(points, options)`, `rankBars(items, iconMarkup)`, `heatColor(value, max)`, `metricBox(value, unitText, label, digits)` ภายในมี `node()` (สร้างอิลิเมนต์ SVG ด้วย `createElementNS`) และ `attachTooltip()` อธิบายการวาดในหัวข้อเจาะโค้ด

### `icons.js` และ `icons-ui.js`

ฟังก์ชันที่คืนสตริง SVG (`stroke(path, size, width)` สร้างกรอบ `<svg ... stroke="currentColor">`) `icons.js` มี `bolt grid building calendar coin chart bell chip users gear warning pulseLine board clock close menu refresh save download meter person logout plus trash edit check wifi radar` และ `firmware` (ชิปกับลูกศรขึ้น ไอคอนเมนูเฟิร์มแวร์ เพิ่ม 14 ต.ค. 2569) ส่วน `icons-ui.js` (`uiIcons`) มี `sun moon search more textSize upload sheet checkCircle alert` ใช้ `stroke="currentColor"` ไอคอนจึงเปลี่ยนสีตามสีตัวหนังสือ (ธีมเปลี่ยนแล้วไอคอนตามเอง) เขียนเองเพื่อไม่ต้องพึ่ง CDN ไอคอน และแยกไฟล์ที่สองเพราะเรื่องแคชเหมือน `theme.js`

### `ui.js`

ชิ้นส่วนหน้าจอที่ทุกหน้าใช้ร่วมกัน
- `toast(message, kind, ms)` + `toastOk/toastError/toastInfo`: แถบแจ้งผลมุมจอ หายเอง (4.2 วินาที, error 6 วินาที) ใช้แทน `alert()` ที่บล็อกทั้งหน้า
- `openModal({ title, subtitle, body, actions })`: คืน **Promise** ที่ resolve เมื่อผู้ใช้กดปุ่ม จึง `await` ได้เหมือน `confirm()` แต่ไม่บล็อก กด Esc หรือคลิกฉากหลัง = `null`
- `confirmAction({ title, subtitle, confirmLabel, danger })`: modal ยืนยันสองปุ่ม คืน `true/false`
- `openForm({ title, fields, submitLabel })`: สร้างฟอร์มจากรายการช่อง (`type`: text, number, password, email, time, select, date, textarea) ตรวจ `required` ให้ คืนออบเจ็กต์ค่า หรือ `null` ถ้ายกเลิก
- `iconButton`, `render` (= `replace`), `withBusy(button, task, label)`: ปิดปุ่มระหว่างรอ กันกดรัวจนยิงคำสั่ง MQTT ซ้ำ

### `dom.js`

ตัวช่วยสร้าง DOM ที่ทุกไฟล์ใช้ (รายละเอียดในหัวข้อเจาะโค้ด) export: `el(tag, props, children)`, `append`, `replace`, `$`, `$$`, `svg(markup)`, `emptyState(text)`, `skeleton(height, width)`, `toggle(on, { disabled, onclick, title })` (สวิตช์เปิด/ปิดที่เป็น `<button class="switch on" aria-pressed>`)

### `auth.js`

`mountLoginScreen(onSuccess)` สร้างหน้าล็อกอิน (ฟอร์ม username/password, ปุ่ม "ลืมรหัสผ่าน") ใส่ลง `document.body` เรียก `api.login()` สำเร็จแล้ว `screen.remove()` และเรียก `onSuccess(user)` ถ้าผิดแสดงข้อความ error จาก Backend ล้างช่องรหัสผ่านและโฟกัสกลับ `forgotPasswordFlow()` ทำ 3 ขั้นต่อกันด้วย `await openForm`: ขอ OTP (`api.forgotPassword` → ได้ `requestId`) → กรอก OTP 6 หลัก (`api.verifyOtp` → ได้ `resetToken`) → ตั้งรหัสใหม่ (`api.resetPassword`, ตรวจว่าสองช่องตรงกันก่อน) ถ้าไม่ได้ `requestId` กลับมา ก็แสดงข้อความกลาง ๆ "ถ้ามีบัญชีนี้ในระบบ จะได้รับอีเมล" (ถ้อยคำแบบนี้เป็นแนวปฏิบัติทั่วไปที่ไม่บอกคนนอกว่าบัญชีนั้นมีอยู่จริงหรือไม่) โทเคนเก็บ localStorage ไม่ใช่ cookie เพราะ Backend ตรวจจาก header `Authorization` อย่างเดียว ใช้ cookie แล้วต้องคิดเรื่อง CSRF เพิ่มโดยไม่ได้อะไรกลับมา

### `app.js`

ตัวประกอบร่าง (533 บรรทัด หลังเพิ่มหน้าเฟิร์มแวร์ 14 ต.ค. 2569) มีตารางหน้า `VIEWS`, ลิ้นชักรีโมต, เมนู, แถบบน

| ส่วน | ฟังก์ชัน | ทำอะไร |
|---|---|---|
| ตารางหน้า | `VIEWS`, `BOTTOM_NAV` (`overview rooms energy alerts`), `NAV_LABELS`, `SHORT_LABELS` | รายชื่อ 10 หน้าแบ่งกลุ่ม `main` (6 หน้า) กับ `system` (4 หน้า: devices firmware users settings; `firmware` เพิ่ม 14 ต.ค. 2569) |
| เริ่ม/จบ | `startApp`, `enterApp`, `teardownSession`, `logout`, `showLogin` | ล็อกอิน/ออก เก็บกวาด state |
| เมนู | `renderNav`, `renderBottomNav`, `renderNavBadges`, `highlightNav`, `renderUserChip`, `renderTopbar` | แถบข้างเดสก์ท็อป แถบล่างมือถือ ป้ายตัวเลขแจ้งเตือน (99+) ป้ายสถานะ MQTT และ "x / y ESP32 ออนไลน์" |
| สลับหน้า | `readHash`, `navigate` | อ่าน `#/ชื่อหน้า` เรียก `destroy` หน้าเก่า `mount` หน้าใหม่ |
| ลิ้นชัก | `context.openRoom/refreshDrawer/logout`, `closeDrawer`, `renderDrawer` | รีโมตของห้อง ใช้ร่วมกันทุกหน้า |
| อื่น ๆ | `startClock` | แสดงวันที่ไทยบนแถบบน อัปเดตทุก 60 วินาที |

**การเพิ่มหน้าเฟิร์มแวร์ (แก้ 14 ต.ค. 2569)** ใช้แค่ 3 บรรทัดใน `app.js`: `import firmware from './views/firmware.js';` (บรรทัด 40), แถวใน `VIEWS` และป้ายใน `NAV_LABELS` (บรรทัด 78 `firmware: 'เฟิร์มแวร์'`)

**ไฟล์ `webapp/assets/js/app.js` บรรทัด 44–55**

```js:44
const VIEWS = [
  { key: 'overview', icon: 'grid', group: 'main', module: overview },
  { key: 'rooms', icon: 'building', group: 'main', module: rooms },
  { key: 'energy', icon: 'chart', group: 'main', module: energy },
  { key: 'schedule', icon: 'calendar', group: 'main', module: schedule },
  { key: 'alerts', icon: 'bell', group: 'main', module: alerts },
  { key: 'rates', icon: 'coin', group: 'main', module: rates },
  { key: 'devices', icon: 'chip', group: 'system', module: devices },
  { key: 'firmware', icon: 'firmware', group: 'system', module: firmware },
  { key: 'users', icon: 'users', group: 'system', module: users },
  { key: 'settings', icon: 'gear', group: 'system', module: settings },
];
```

| บรรทัด | อธิบาย |
|---|---|
| 44 | `VIEWS` คือรายการหน้าทั้งหมดตามลำดับที่แสดงในเมนู |
| 45–50 | กลุ่ม `main` 6 หน้า วาดใน `<nav id="navMain">` |
| 51–54 | กลุ่ม `system` วาดใน `<nav id="navSystem">` ตอนนี้มี 4 หน้า หน้าเฟิร์มแวร์อยู่ถัดจาก "ห้องและอุปกรณ์" เพราะเป็นงานดูแลบอร์ดเหมือนกัน |
| 52 | `icon: 'firmware'` ชี้ไปที่ `icons.firmware` (เพิ่มใน `icons.js` บรรทัด 63) ส่วน `module: firmware` คือออบเจ็กต์ที่ `firmware.js` export default |

หน้าเฟิร์มแวร์ไม่อยู่ใน `BOTTOM_NAV` (แถบล่างมือถือ) เพราะใช้ไม่บ่อย บนมือถือเข้าได้จากปุ่ม "เมนู" ช่องสุดท้าย และเมนูนี้มองเห็นเฉพาะแอดมิน เพราะ `firmware.js` ประกาศ `adminOnly: true` (`renderNav` ข้ามหน้าที่ `adminOnly` ถ้าผู้ใช้ไม่ใช่แอดมิน และ `navigate` เด้งกลับ `#/overview`)

> [!WHY]
> การเพิ่มหน้าใหม่ไม่ต้องแตะส่วนอื่นของ `app.js` เลย เพราะทุกหน้าใช้สัญญาเดียวกัน (`title`, `subtitle`, `adminOnly`, `mount` ที่คืน `{ update }`) `navigate()`, การวาดเมนู และการเรียก `update()` เมื่อ state เปลี่ยน ทำงานจากตาราง `VIEWS` ทั้งหมด นี่คือประโยชน์ของการกำหนด "สัญญา" ของหน้าไว้ตั้งแต่แรก

**วิธีสลับหน้า (หัวใจของ SPA นี้)** ทุกหน้าใน `views/` ส่ง `export default` เป็นออบเจ็กต์สัญญาเดียวกัน

```js
export default {
  title: 'ชื่อหน้า',
  subtitle: 'คำอธิบาย',
  adminOnly: true,           // ไม่ใส่ = ทุกคนเห็น
  mount(root, context) {     // เรียกครั้งเดียวตอนเข้าหน้า (จะ async ก็ได้)
    ...วาด DOM ลง root...
    return { update() {...}, destroy() {...} };   // update เรียกทุกครั้งที่ state เปลี่ยน
  },
};
```

`navigate(key)`: (1) หา view จาก `VIEWS` (2) ถ้า `adminOnly` แต่ไม่ใช่ admin → `toastError` แล้ว `#/overview` (3) ปิดลิ้นชักและเมนูที่เปิดค้าง (4) ถ้าหน้าเดิมคือหน้านี้ → จบ (5) เรียก `current.destroy?.()` (6) จำ `currentKey` + เก็บลง `localStorage['rmutt.view']` (7) ตั้งชื่อหน้า/`document.title` ล้าง `viewRoot` เลื่อนกลับบนสุด (8) `current = await view.module.mount(dom.viewRoot, context)` และทุกครั้งที่ state เปลี่ยน callback ที่ `subscribe` ไว้ใน `enterApp` จะเรียก `current?.update?.()`

เหตุผลของการแยก `mount` กับ `update`: `mount` สร้างโครงที่ "ต้องคงอยู่" (ช่องค้นหา ช่องวันที่ แท็บ) ส่วน `update` วาดเฉพาะส่วนที่ข้อมูลเปลี่ยน ถ้าวาดทั้งหน้าใหม่ทุก 10 วินาที ช่องที่ผู้ใช้กำลังพิมพ์จะถูกลบแล้วสร้างใหม่ ตัวอักษรหายและเคอร์เซอร์หลุด

> [!WHY]
> เหตุผลที่ใช้ hash (`#/rooms`) แทน path จริง (`/rooms`): เว็บเสิร์ฟเป็นไฟล์ static ถ้าผู้ใช้กด F5 ที่ `/rooms` Caddy จะหาไฟล์ชื่อ `rooms` ไม่เจอและตอบ 404 ส่วนข้อความหลัง `#` เบราว์เซอร์ไม่ส่งไปเซิร์ฟเวอร์เลย การเปลี่ยน hash ยังยิง event `hashchange` ให้ฟัง และปุ่ม Back/Forward ของเบราว์เซอร์ใช้ได้ฟรี

ลิ้นชักรีโมตเป็นของ `app.js` ไม่ใช่ของหน้า `rooms` เพราะเปิดได้จากหลายหน้า (การ์ดห้องในหน้า rooms และช่อง Building Pulse ในหน้า overview) หน้าจอเรียกผ่าน `context.openRoom(roomNumber)` เนื้อหาในลิ้นชักมาจาก `roomDrawerContent()` และ `roomDrawerTitle()` ของ `views/rooms.js` และ `renderDrawer()` วาดใหม่ทุกครั้งที่ state เปลี่ยน โดยจำ `scrollTop` ไว้ก่อน (ไม่งั้นหน้าจะกระโดดกลับบนสุดทุก 10 วินาทีขณะที่คนกำลังปรับอุณหภูมิ)

## หน้าจอทั้งหมดใน `views/`

ทุกหน้าใช้สัญญา `title/subtitle/mount/update` ข้างต้น และอ่านข้อมูลจาก `state` (ผ่าน `store.js`) ไม่เรียก `fetch` เอง การ "ซ่อนปุ่มตามสิทธิ์" ในหน้าเป็นแค่ความสะดวก การบังคับสิทธิ์จริงอยู่ที่ Backend (`requireAdmin`) เสมอ ถ้าใครแก้ JS ในเบราว์เซอร์เปิดปุ่ม คำขอก็ยังถูกปฏิเสธที่เซิร์ฟเวอร์

### `views/overview.js` — ภาพรวม (ทุกคน)

- **ข้อมูลที่ใช้**: `state.summary` (จาก `/energy/summary`), `state.live.totals`, `state.alerts`, `state.settings.electricityRate`, `state.rooms`/`airConditioners` (สำหรับ Building Pulse)
- **ส่วนที่วาด** (5 ฟังก์ชันที่ `update()` เรียก): `renderHero` (kWh รวมช่วงที่เลือกตัวเลขใหญ่ ทศนิยม 1 ตำแหน่งเสมอ + ค่าไฟโดยประมาณ `kwh × rate` + เปรียบเทียบกับช่วงก่อนหน้า `changePercent` + กราฟ `areaChart` + เวลาทำงานรวม/กำลังสูงสุด/จำนวนเครื่อง), `renderHeroTabs`, `renderStats` (การ์ดเล็ก 4 ใบ: แอร์ทำงานอยู่ / แจ้งเตือนรอดำเนินการ / ESP32 ออนไลน์ / อัตราค่าไฟ กดแล้วไปหน้านั้น), `renderPulse` (Building Pulse), `renderAlerts` (6 รายการล่าสุด ให้ `open` ขึ้นก่อน), `renderRank` (5 ห้องใช้ไฟมากสุดด้วย `rankBars`)
- **การกระทำ**: เลือกช่วง "วันนี้ / 7 วัน / 30 วัน / เลือกวัน" → `loaders.summary({ period, from, to })` ช่วงเองตรวจว่าเริ่มไม่เกินสิ้นสุด และไม่เกิน `MAX_CUSTOM_DAYS = 366` (ตรงกับที่ Backend จำกัดใน `resolvePeriod`) ช่องวันที่เป็น `thaiDateInput` ที่ `max` = วันนี้, กดช่องใน Building Pulse → `context.openRoom()`, กด "รับทราบ" → `api.acknowledgeAlert(id)` แล้ว `loaders.alerts()`
- **Building Pulse**: ทุกห้องเป็นกล่อง จัดกลุ่มตามชั้น (`roomsByFloor`) สีพื้นไล่ตามค่าไฟด้วย `heatColor(kwh, max)` ความกว้าง `flex: 1 + (kwh/max)*2.4` จุดกะพริบคือมีแอร์ทำงาน (สีเหลืองถ้ากำลังนับถอยหลังปิดอัตโนมัติ)
- `alertRow` ถูก `export` ให้ `alerts.js` ใช้ซ้ำ
- **แยกตามสิทธิ์**: ไม่มีปุ่มเฉพาะแอดมินในหน้านี้ ยกเว้นการ์ด "ESP32 ออนไลน์" ที่กดไปหน้า `devices` ได้เฉพาะแอดมิน (เจ้าหน้าที่เห็นแต่ไม่กดไม่ได้)

### `views/rooms.js` — ห้องและควบคุม (ทุกคน, ปุ่มบางอัน admin)

- **ข้อมูล**: `state.rooms`, `airConditioners`, `occupancySensors`, `live.readings`, `summary.rooms` (ค่าไฟรายห้อง)
- **การ์ดห้อง** (`roomCard`): ชื่อห้อง ประเภท ชิป "แอร์เปิด x/y" ชิปสถานะคน ("มีคนอยู่" / "ไม่มีคน" / "เซ็นเซอร์ออฟไลน์" / "ยังไม่ติดตั้งเซ็นเซอร์") กำลังนับถอยหลังปิดอัตโนมัติ (`countdownStrip`) หรือค่าไฟของช่วงที่เลือก และสถานะบอร์ดออนไลน์ ห้องที่ยังไม่มีแอร์วาดแบบย่อ
- **ตัวกรอง** (ออบเจ็กต์ `view` ระดับโมดูล จึงจำข้ามการสลับหน้า): แท็บชั้น (ค่าเริ่มต้น "ทุกชั้น"), ช่องค้นหา (รหัสห้อง/ประเภท), ชิป "เฉพาะห้องที่แอร์ทำงาน" ช่องค้นหาสร้างครั้งเดียวใน `mount`
- **นาฬิกานับถอยหลัง**: เซิร์ฟเวอร์ส่ง `autoOffDeadlineAt` (เวลาเส้นตาย) เบราว์เซอร์นับเองทุก 1 วินาทีด้วย `setInterval(tick, 1000)` ในฟังก์ชัน `countdownStrip` บรรทัด 400–445 (ตัว `tick` อยู่ที่ 420–440) เมื่อเลยเส้นตายแสดง "กำลังส่งคำสั่งปิด" และ `autoOffAttempts` การเคลียร์ interval ซับซ้อนเพราะแถบถูกวาดใหม่บ่อย (ตรวจ `strip.isConnected`)
- **ลิ้นชักรีโมต** (`roomDrawerContent`): การ์ดข้อมูลห้อง + การ์ดแอร์ทีละเครื่อง (`acCard`) ปรับ **ร่างคำสั่ง** (`drafts` Map เก็บแยกจากสถานะจริง) ได้แก่ สวิตช์เปิด/ปิด (ส่งคำสั่งทันที) อุณหภูมิ ± ภายในขอบเขตตามรุ่น (`limitsFor`: `SAIJO_DENKI` 18–29°C โหมด cool/dry/fan และไม่มี swing `off`; `DAIKIN_WIRED` 16–30°C โหมด cool/dry/fan พัดลมไม่มี turbo ทิศลมแค่ auto/off ฟังก์ชันเสริมมีแค่ Sleep (เพิ่ม 11 ต.ค. 2569); รุ่นอื่น 16–30°C), โหมด, พัดลม, ทิศลม, ฟังก์ชันเสริม 7 อย่าง (eco turbo sleep quiet displayLight clean horizontalSwing) กด "ส่งคำสั่งผ่าน MQTT" → `sendCommand()` → `api.sendCommand(deviceId, payload)` ซึ่ง Backend จะส่งต่อเข้า MQTT; "คืนค่าเดิม" ทิ้งร่าง
- **ปุ่มตามความสามารถของเครื่อง (เพิ่ม 11 ต.ค. 2569)**: `limitsFor` คืน `fans` และ `extras(mode)` เพิ่มจากเดิม การ์ดแอร์จึงวาดเฉพาะปุ่มพัดลม/ฟังก์ชันเสริมที่เครื่องนั้นมี และบอร์ดสายแอร์เรียก `fitDraft` ปรับร่างให้อยู่ในขอบเขตก่อนวาดและทุกครั้งที่เปลี่ยนโหมด หัวการ์ดแสดง "รหัส · ยี่ห้อ" (บอร์ด IR ต่อท้ายชื่อโปรโตคอลในวงเล็บ) และมีชิปใหม่ "ยี่ห้อ · สายแอร์" (สี `info`) หรือ "ยี่ห้อ · รีโมต IR" (สี `off`) อธิบายทีละบรรทัดในหัวข้อเจาะโค้ดข้อ 11
- ค่าที่อ่านจาก PZEM (แรงดัน กระแส กำลังไฟ พลังงานสะสม ตัวประกอบกำลัง ความถี่) จาก `liveReading(deviceId)` และคำเตือนถ้า `pzemAvailable` เป็น false (ระบบปิดอัตโนมัติจะไม่ทำงานกับเครื่องนั้น เพราะยืนยันไม่ได้ว่าปิดสำเร็จ)
- **เฉพาะแอดมิน** (เงื่อนไข `isAdmin` ใน `acCard`): สวิตช์ "ปิดอัตโนมัติเครื่องนี้" (`api.updateAirConditioner(..., { autoOffEnabled })`), "เปลี่ยนชื่อ", "สั่งเข้าโหมดตั้งค่า" (`api.enterSetupMode` บอร์ดจะหลุด Wi-Fi และเปิด Bluetooth รอตั้งค่าใหม่ ต้องมี `confirmAction` ก่อน)
- IR (รีโมตอินฟราเรด) ไม่มีสัญญาณตอบกลับ หลังส่งคำสั่ง toast บอกให้ดูค่ากำลังไฟว่าเปลี่ยนไหม และตั้ง `setTimeout 2500ms` ดึง `airConditioners` + `live` ใหม่ ถ้าคำสั่งล้มเหลว ร่างจะถูกรีเซ็ตกลับเป็นสถานะจริง ("ไม่งั้นหน้าจอจะโกหก")


> [!NOTE]
> **อัปเดต 9 ต.ค. 2569:** ฟังก์ชัน `draftFor(unit)` ใน `webapp/assets/js/views/rooms.js` (บรรทัด 451–462 หลังโค้ดสายแอร์ 11 ต.ค. ดันลงมา 40 บรรทัด) สร้างร่างคำสั่งของแอร์แต่ละเครื่อง เดิมคัดลอก `unit.state` ตรง ๆ ซึ่ง `state.power` คือคำสั่งล่าสุดที่ระบบส่ง ถ้ามีคนเปิดแอร์ด้วยรีโมตจริง ค่านี้ยังเป็น `false` สวิตช์บนเว็บจึงขึ้นว่าปิด ตอนนี้ตั้ง `power` เป็นจริงด้วยถ้า `unit.pzemAvailable === true && unit.acRunning === true` (กติกาเดียวกับ `isPoweredOn` ในแอป Flutter)

```js:451
function draftFor(unit) {
  if (!drafts.has(unit.deviceId)) {
    // state.power คือคำสั่งล่าสุดที่ระบบส่ง ถ้ามีคนเปิดด้วยรีโมตจริง ค่านี้ยังเป็น false
    // จึงถือว่าเปิดอยู่ด้วยถ้า PZEM ยืนยันแล้วว่าแอร์กินไฟ (เหมือนแอปมือถือ)
    const running = unit.pzemAvailable === true && unit.acRunning === true;
    drafts.set(unit.deviceId, {
      ...unit.state,
      power: Boolean(unit.state?.power) || running,
    });
  }
  return drafts.get(unit.deviceId);
}
```

ใช้ `=== true` แทนการเช็กว่าเป็นจริงเฉย ๆ เพื่อกันค่าแปลก ๆ (เช่น `undefined` หรือสตริง) ทำให้เข้าใจผิดว่าแอร์ทำงาน `Boolean(unit.state?.power)` ใช้ `?.` กันกรณีไม่มี `state` เลย

### `views/energy.js` — ข้อมูลไฟฟ้า (ทุกคน)

หน้าที่เว็บทำได้ดีกว่ามือถือ
- **ข้อมูล**: `state.metricCatalog` (รายการค่าที่เลือกได้ ดึงจาก `/energy/metrics` ไม่เขียนตายในหน้า), `api.energySources()` (รายการห้อง/เครื่อง/ช่วงข้อมูลที่มี), `api.energyHistory(query)`
- **ตัวกรอง** (ออบเจ็กต์ `filters` ระดับโมดูล): `scope` (`building` รวมอาคาร / `room` รายห้อง / `device` รายเครื่อง), ช่วงวัน (ปุ่มลัด 0/6/29/89 วันย้อนหลัง หรือพิมพ์ พ.ศ.), `detail` (`summary` ย่อ / `high` ละเอียด ซ่อนค่าที่ `detailOnly` ในโหมดย่อ), `rooms[]`/`devices[]` (ชิปติ๊ก `multiSelect` แทน `<select multiple>`), `metrics[]` (ชิปติ๊ก), `language` ของ Excel (`th`/`en`)
- **ผลลัพธ์**: กราฟพื้นที่ของค่าแรกที่เลือก + ตารางที่หัวตาราง/แถวรวมค้าง (sticky) แถวแรกของแต่ละวันมีเส้นคั่น
- **ยุบหลายแถวเป็นจุดเดียวบนกราฟ** (`combineMode`): ค่าชนิด "ปริมาณ" (kWh, W, A, บาท, นาที) บวกกัน (`sum`); แรงดัน (V) ความถี่ (Hz) `powerFactorAvg` เฉลี่ย (`avg`) เพราะ 220V + 221V ไม่ใช่ 441V; คีย์ลงท้าย `Min`/`Max` ใช้ต่ำสุด/สูงสุด
- **ส่งออก Excel** (`downloadExcel`): `api.exportEnergy` ดึง **blob** ผ่าน `fetch` (ต้องแนบ header `Authorization` ซึ่ง `<a href>` ทำไม่ได้) ชื่อไฟล์ภาษาไทยอ่านจาก header `X-Export-Filename` (percent-encoded) แล้ว `URL.createObjectURL(blob)` สร้างลิงก์ชั่วคราวกด `click()` เอง และ `revokeObjectURL` หลัง 4 วินาที
- ค่าไฟเป็นเงิน = `kWh × state.settings.electricityRate` คำนวณฝั่งหน้าจอและ Excel ฐานข้อมูลเก็บแต่ kWh
- `update()` ของหน้านี้ตั้งใจ**ไม่วาดใหม่ทุกรอบ** วาดเฉพาะเมื่อ `filterSignature()` (มี catalog แล้วหรือยัง + อัตราค่าไฟ) เปลี่ยน กันช่องวันที่ที่กำลังพิมพ์ถูกสร้างใหม่

### `views/schedule.js` (+ 3 ไฟล์ช่วย) — ตารางเรียน (ทุกคนดู, แอดมินแก้)

- **ข้อมูล**: `state.schedules`, `timetable` (ภาคเรียนที่ใช้อยู่ ใครนำเข้า เมื่อไร), `terms` (ปฏิทินภาคเรียน), `today` (วันนี้ตามเวลาไทยจาก Backend), `bookings` (การใช้ห้องของสัปดาห์ที่ดูอยู่), `rooms`
- **การแสดงผล**: ดูเป็นรายวันตามวันที่จริง เลื่อนทีละสัปดาห์ (`weekNav`, แท็บ อา–ส, แท็บชั้น) แต่ละห้องเป็นการ์ดรวม "คาบเรียนประจำ" (`class_schedules` ที่ `dayOfWeek` ตรงวันนั้น) กับ "การใช้ห้อง" ที่มีวันที่ (`bookingOccursOn`) เรียงตามเวลาเริ่ม คาบที่กำลังเกิดขึ้น (เวลาปัจจุบันอยู่ระหว่างเริ่ม–เลิก และเป็นวันนี้) ถูกเน้น ถ้าวันที่ดูอยู่นอกช่วงภาคเรียน (`outsideTerm`) ตารางเรียนถูกข้าม มีป้ายอธิบาย
- **ทำไมหน้านี้ต้องแก้ไขได้ ไม่ใช่แค่ดู**: ระบบปิดแอร์อัตโนมัติใช้ตารางนี้ตัดสินว่า "ในคาบเรียน" (รอ 15 นาที) หรือ "นอกคาบ" (รอ 5 นาที และแจ้งเตือนถ้ามีคนเปิดแอร์) ข้อมูลผิด = แอร์ถูกปิดผิดจังหวะ
- **เฉพาะแอดมิน**: ปุ่ม "นำเข้าจาก Excel / CSV", "เพิ่มการใช้ห้อง", "ล้างตารางทั้งหมด" (`api.deleteAllSchedules`, ไม่ลบข้อมูลไฟฟ้า), แก้/ลบคาบ (`editSchedule`/`removeSchedule`), แก้/ลบ booking ("หยุดตั้งแต่วันนี้" เก็บครั้งก่อนไว้ หรือ "ลบทั้งชุด") ทุกคนมีปุ่ม "ดาวน์โหลด CSV" สำรอง (`schedulesToCsv`)
- ฟังก์ชัน `addSchedule` ยังอยู่ในไฟล์แต่ไม่ถูกเรียกแล้ว (ปุ่ม "เพิ่มการใช้ห้อง" ใช้ `openBookingForm` ซึ่งมีตัวเลือก "ในตารางเรียน" แทน)

**`views/schedule-import.js`** — กล่องนำเข้า 3 ขั้น (`openScheduleImport`): (1) เลือกไฟล์ `.xlsx`/`.csv` (กดเลือกหรือลากวาง `dragenter/dragover/drop`, ไม่เกิน 8 MB ตรงกับ `express.raw({ limit: '8mb' })` ของ Backend, `.xls` เก่าปฏิเสธพร้อมแนะนำ) (2) ส่งไฟล์ดิบให้ `api.previewScheduleImport` **ที่ยังไม่บันทึกอะไร** ได้สรุป (จำนวนห้อง/คาบ/ห้องใหม่/ข้อสังเกต) และตารางตัวอย่างให้ตรวจ (3) ยืนยัน → `api.commitScheduleImport(preview, { replaceAll })` ซึ่ง Backend ทำใน transaction เดียว ถ้าไม่สำเร็จตารางเดิมอยู่ครบ โหมดนำเข้า: `rooms` (แทนที่เฉพาะห้องในไฟล์) กับ `all` (เปลี่ยนภาคเรียน ล้างทุกห้อง) ระบบเลือกให้ตามว่าภาคเรียนในไฟล์ต่างจากที่ใช้อยู่หรือไม่ การอ่าน Excel (รวมเซลล์ผสาน) ทำที่ Backend (`backend/src/utils/xlsx-reader.js`) เพื่อให้เว็บกับมือถือได้ผลเหมือนกัน และมีชุดทดสอบ นอกจากนี้ export `schedulesToCsv` (มี BOM `﻿` นำหน้าให้ Excel อ่านภาษาไทยไม่เพี้ยน) และ `downloadText`

**`views/term-calendar.js`** — ปฏิทินภาคเรียน (กล่อง `<details>` พับได้): `createTermCalendar` วาดตารางภาคเรียน (`semester`, `startDate`, `endDate`, `status`: `active` กำลังเปิด / `before` ยังไม่เปิด / `after` ปิดแล้ว) แอดมินเพิ่ม/แก้ (`api.saveAcademicTerm`) ลบ (`api.deleteAcademicTerm`) และ `termStatusLine`, `termFor` เป็นตัวช่วยที่หน้าอื่นใช้ การตัดสินว่า "วันนี้อยู่ในภาคหรือไม่" ทำที่ Backend ตามเวลาไทย ไม่ใช่เวลาเครื่องผู้ใช้

**`views/booking-form.js`** — ฟอร์ม "เพิ่มการใช้ห้อง" (`openBookingForm`) เขียน modal เอง ไม่ใช้ `openForm` เพราะช่องเปลี่ยนตามแบบทำซ้ำ และต้องเปิดค้างเมื่อบันทึกไม่ผ่าน ทำซ้ำได้: `once` วันเดียว, `daily` ทุกวันในช่วง, `weekly` ทุกสัปดาห์ (เลือกวัน) บันทึกที่ `/bookings` และ `timetable` = สร้างคาบเรียนประจำใน `class_schedules` ทีละวัน (ผ่าน `api.createSchedule` มือถือเห็นด้วย) export `CATEGORY_LABEL` (meeting, class, exam, event, other), `bookingOccursOn`, `describeRepeat`, `addDays`, `dayOfWeekOf` (ใช้ UTC ทั้งหมดกันวันเลื่อนข้ามเขตเวลา)

### `views/alerts.js` — การแจ้งเตือน (ทุกคน)

- **ข้อมูล**: `state.alerts` (`alerts[]`, `counts`) ดึงด้วย `loaders.alerts({ limit: 200, status, room })` ทุกครั้งที่เปลี่ยนตัวกรอง
- **ตัวกรอง** (ตัวแปรระดับโมดูล `status` เริ่มที่ `'open'`, `roomFilter`): แท็บสถานะ ทั้งหมด / `open` รอดำเนินการ / `acknowledged` รับทราบแล้ว / `resolved` จบแล้ว (ใส่จำนวนจาก `counts`) และเลือกห้อง
- **การกระทำ**: ปุ่ม "รับทราบ" ของ `alertRow` (import มาจาก `overview.js`) → `api.acknowledgeAlert` แจ้งเตือนที่ระบบปิดเองเมื่อเงื่อนไขหมดจะย้ายเป็น `resolved` เอง
- ไม่มีส่วนเฉพาะแอดมิน (รับทราบได้ทุกคน เก็บชื่อผู้กดไว้ที่ `acknowledgedBy`)

### `views/rates.js` — อัตราค่าไฟ (ทุกคนดู, แอดมินแก้)

- **ข้อมูล**: `state.settings.electricityRate` (จาก `/settings` ตาราง `system_settings` ที่เซิร์ฟเวอร์ ไม่ใช่ในเบราว์เซอร์ เพราะตัวเลขเงินต้องตรงกันทุกเครื่อง) และ `state.summary.totals.kwh` เป็นตัวอย่างคำนวณ
- วาดอัตราปัจจุบัน ช่องแก้ไข และตัวอย่าง "พลังงานที่ใช้ × อัตรา = ค่าไฟโดยประมาณ" ที่คำนวณสดขณะพิมพ์ (`input` event → `drawPreview`)
- **เฉพาะแอดมิน**: ช่องกรอก (`disabled: !isAdmin`) และปุ่มบันทึก (`save()` ตรวจ 0.01–100 → `api.setElectricityRate` → `loaders.settings()`) ถ้าได้ 404 บอกว่าต้อง deploy Backend รุ่นใหม่ก่อน
- ระบบ**ไม่เก็บเงินลงฐานข้อมูล** เก็บแต่ kWh เปลี่ยนอัตราแล้วตัวเลขเก่าคิดใหม่ตามอัตราล่าสุดทั้งหมด

### `views/devices.js` — ห้องและอุปกรณ์ (**แอดมินเท่านั้น**: `adminOnly: true`)

3 แท็บ (`tab` ตัวแปรระดับโมดูล): **ห้อง** (เพิ่ม/แก้/ลบ `api.createRoom/updateRoom/deleteRoom` — รหัสห้องแก้ไม่ได้เพราะผูกกับแอร์และตารางเรียน, รหัสต้องเป็น A–Z 0–9 _ - ยาว 2–20), **เครื่องปรับอากาศ** และ **เซ็นเซอร์ตรวจจับคน**
- **จองช่องติดตั้ง** (`reserveAir`, `reserveOccupancy`): สิ่งที่เว็บทำแทนมือถือไม่ได้คือขั้นตอน Bluetooth (ต้องยืนใกล้บอร์ด) เว็บจึงทำได้แค่ "จองช่อง" = สร้างแถวในฐานข้อมูลพร้อมโทเคนอายุ **15 นาที ใช้ได้ครั้งเดียว** (`showReservation` แสดงโทเคน ชื่อ Bluetooth host/port/topic ของ MQTT) แล้วคนถือโทรศัพท์ไปตั้งค่าบอร์ดผ่านแอปมือถือต่อ รหัสอุปกรณ์ต้องขึ้นต้น `ESP32-` (แอร์) หรือ `OCC32-` (เซ็นเซอร์) ตามด้วยเลขฐานสิบหก 12 ตัว ชื่อ Bluetooth คำนวณให้เอง (`RMUTT-AC-<เลขฐานสิบหก 12 ตัว>` / `RMUTT-OCC-<…>` ได้จาก `deviceId.slice(6)` คือตัดคำนำหน้า `ESP32-`/`OCC32-` ออก) กันพิมพ์ผิดแล้ว Backend ปฏิเสธ และมีรายการ `PROTOCOLS` 19 ตัว (`WIRED_PROTOCOL` = `DAIKIN_WIRED` เป็นตัวแรก ตามด้วยโปรโตคอล IR 18 แบบ DAIKIN, LG, SAIJO_DENKI ...) ค่าเริ่มต้น `SAIJO_DENKI` (**แก้ 11 ต.ค. 2569:** ช่องเลือกเปลี่ยนชื่อจาก "โปรโตคอลรีโมต" เป็น "ยี่ห้อแอร์ / วิธีควบคุม" และแต่ละตัวเลือกแสดงเป็น "Daikin · สายแอร์ (บอร์ดแทนรีโมตติดผนัง)" หรือ "<ยี่ห้อ> · รีโมต IR (<โปรโตคอล>)" ค่าที่ส่งไป Backend ยังเป็นชื่อโปรโตคอลเดิม)
- **อัปเดตเฟิร์มแวร์ผ่าน Wi-Fi ทีละเครื่อง** (`startOta`): ดึงรายการ `.bin` ในโฟลเดอร์ `/opt/rmutt/firmware` บนเซิร์ฟเวอร์ (`api.firmwareFiles`) กรองเฉพาะ `file.kind` ที่ตรงกับชนิดบอร์ดให้เลือก (**แก้ 14 ต.ค. 2569:** ปุ่มของแอร์ส่ง `kind` เป็น `'wired'` ถ้า `isWiredProtocol(unit.protocol)` ไม่งั้น `'air'` เพราะไฟล์บอร์ดสายแอร์ใช้กับบอร์ด IR ไม่ได้ และถ้าไม่มีไฟล์ ข้อความเปลี่ยนจาก "ให้วางไฟล์ .bin ไว้ที่ /opt/rmutt/firmware ก่อน" เป็น "อัปโหลดไฟล์ .bin ได้ที่เมนู "เฟิร์มแวร์"" ไม่ต้อง scp เข้าเซิร์ฟเวอร์เองแล้ว) แล้ว `api.otaAirConditioner` / `otaOccupancySensor` บอร์ดดาวน์โหลดเอง รีบูต รายงานรุ่นใหม่กลับมา (`firmwareLine` แสดงรุ่น ข้อผิดพลาด OTA และจำนวนข้อมูลค้างส่ง `historyPending`)
- ถอดอุปกรณ์ (`removeAir` → ล้างข้อความ retained บน MQTT ตามจำนวน `retainedTopicsCleared`), สั่งเข้าโหมดตั้งค่า, สวิตช์ปิดอัตโนมัติรายเครื่อง, เปลี่ยนชื่อ
- **บรรทัดย่อยของแอร์แต่ละเครื่อง (แก้ 11 ต.ค. 2569)**: `airRow` แสดง `airControlSummary(unit.protocol)` แทนชื่อโปรโตคอลดิบ เช่น `ESP32-… · Daikin · สายแอร์ · active · ออนไลน์ · …`

**ไฟล์ `webapp/assets/js/views/devices.js` บรรทัด 494–507** (ช่องเลือกยี่ห้อตอนจองช่องติดตั้งแอร์ แก้ 11 ต.ค. 2569)

```js:494
      {
        name: 'protocol',
        label: 'ยี่ห้อแอร์ / วิธีควบคุม',
        type: 'select',
        value: 'SAIJO_DENKI',
        options: PROTOCOLS.map((item) => ({
          value: item,
          label:
            item === WIRED_PROTOCOL
              ? 'Daikin · สายแอร์ (บอร์ดแทนรีโมตติดผนัง)'
              : `${airBrand(item)} · รีโมต IR (${item})`,
        })),
        required: true,
      },
```

| บรรทัด | อธิบาย |
|---|---|
| 495–498 | ช่อง `select` ชื่อ `protocol` ค่าเริ่มต้นยัง `SAIJO_DENKI` (แอร์ส่วนใหญ่ในอาคาร) |
| 499–500 | `PROTOCOLS.map(...)` แปลงทุกโปรโตคอลเป็นตัวเลือก `value` ยังเป็นชื่อโปรโตคอลจริงที่ Backend รู้จัก |
| 501–504 | `label` คือสิ่งที่คนเห็น: ตัวเลือกสายแอร์อธิบายว่า "บอร์ดแทนรีโมตติดผนัง" ส่วน IR แสดงยี่ห้อจาก `airBrand(item)` แล้วต่อท้ายชื่อโปรโตคอล (เพราะยี่ห้อเดียวมีหลายโปรโตคอล เช่น Haier 4 แบบ) |

> [!WHY]
> แยก "สิ่งที่คนอ่าน" (`label`) ออกจาก "สิ่งที่เครื่องอ่าน" (`value`) ทำให้เปลี่ยนคำบนหน้าจอได้โดยไม่กระทบฐานข้อมูลหรือ Backend เจ้าหน้าที่ที่ติดตั้งรู้แค่ว่าแอร์ห้องนี้ "Daikin ต่อสาย" ไม่จำเป็นต้องรู้ว่าโปรโตคอลชื่อ `DAIKIN_WIRED`


### `views/firmware.js` — เฟิร์มแวร์ (**แอดมินเท่านั้น**, เพิ่ม 14 ต.ค. 2569)

หน้าใหม่ 718 บรรทัด (commit `2432faf`) ทำงานแทนการ "scp ไฟล์ `.bin` เข้าเซิร์ฟเวอร์แล้วกดอัปเดตทีละเครื่องในหน้าห้องและอุปกรณ์" ทั้งหมดอยู่ในหน้าเดียว: ดูไฟล์ที่มี อัปโหลดรุ่นใหม่ ดูว่าบอร์ดไหนยังเก่า เลือกหลายตัวแล้วสั่งอัปเดต และเฝ้าดูจนบอร์ดรายงานรุ่นใหม่

- **3 แท็บตามชนิดบอร์ด** (ค่าคงที่ `KINDS`): `air` "แอร์ IR" (สเก็ตช์ `rmutt_esp32_air`), `wired` "สายแอร์ Daikin" (`rmutt_esp32_air_wired`), `occupancy` "เซ็นเซอร์ LD2410" (`rmutt_esp32_occupancy`) แยกแท็บเพราะไฟล์ใช้ข้ามชนิดไม่ได้ ถ้าสั่งไฟล์ผิดชนิด บอร์ดจะรีบูตเข้าโปรแกรมของบอร์ดอีกแบบ
- **ชนิดและรุ่นอ่านจากชื่อไฟล์**: มี `occ` = เซ็นเซอร์, มี `wired` หรือ `slm8` = สายแอร์, นอกนั้น = แอร์ IR รุ่นคือท้ายชื่อ เช่น `rmutt_esp32_air_wired-2.5.2-slm8.bin` → `2.5.2-slm8` (กติกาเดียวกับ `firmwareKindOf`/`firmwareVersionOf` ใน `backend/src/utils/firmware.js`)
- **ข้อมูลที่ใช้**: `api.firmwareFiles()` (โหลดเองตอน `mount` และหลังอัปโหลด/ลบ ไม่อยู่ใน polling ของ `store.js`), `state.airConditioners` แยกด้วย `isWiredProtocol` เป็นแท็บแอร์ IR กับสายแอร์, `state.occupancySensors` สำหรับแท็บเซ็นเซอร์ ฟิลด์ที่ใช้จากบอร์ด: `firmwareVersion`, `otaError`, `isOnline`, `provisionStatus`, `lastSeenAt`
- **โครงหน้า**: แถวหัว (`fw-head`: คำอธิบาย + ป้าย "ออนไลน์ x / y บอร์ด") → แถบแท็บ (ป้าย "N ต้องอัปเดต" / "ล่าสุดครบ" / "ไม่มีบอร์ด") → แผง (`fw-panel`) ที่มี การ์ดรายการไฟล์ (`filesCard`) คู่กับช่องลากไฟล์ (`dropZone`) ในกริด `fw-grid`, การ์ดตารางบอร์ด (`devicesCard`), และแถบอัปเดตหลายบอร์ด (`bulkBar`) ที่ค้างด้านล่างจอเมื่อมีบอร์ดที่เลือก
- **การกระทำ**: อัปโหลด (`handleFile` → `uploadWithReplace` → `api.uploadFirmware`, ชื่อซ้ำได้ 409 แล้วถามเขียนทับ), ลบไฟล์ (`removeFile` → `api.deleteFirmware`), อัปเดตทีละตัวหรือหลายตัว (`startUpdates` → `api.otaAirConditioner` / `api.otaOccupancySensor` ทีละบอร์ด)
- **การติดตามผล**: บอร์ดที่สั่งแล้วถูกจำใน `pending` (Map) แล้ว `settlePending()` ตรวจทุกครั้งที่วาดหน้าใหม่ว่าบอร์ดรายงานรุ่นเป้าหมายแล้วหรือยัง, มี `otaError` ใหม่ไหม หรือรอเกิน 5 นาที (`PENDING_MS`)
- **มือถือ**: ที่จอ ≤ 620px ตารางบอร์ดกลายเป็นการ์ดเรียงลง (ดูหัวข้อ CSS ด้านล่าง)

| ฟังก์ชัน | บรรทัด | หน้าที่ |
|---|---|---|
| `mount` | 64–75 | สร้างโครง 3 ช่อง วาดครั้งแรก โหลดรายการไฟล์ แล้ววาดอีกครั้ง คืน `{ update }` |
| `loadFiles` | 78–89 | เรียก `api.firmwareFiles()` เก็บ `files`, `configured`, `maxBytes` หรือ `filesError` |
| `kindOfFileName`, `versionOfFileName`, `compareVersions` | 94–122 | อ่านชนิด/รุ่นจากชื่อไฟล์ และเทียบรุ่นแบบตัวเลข |
| `devicesOf`, `filesOf`, `latestFileOf`, `deviceTitle` | 124–149 | ดึงบอร์ด/ไฟล์ของชนิดหนึ่ง เรียงไฟล์รุ่นใหม่สุดก่อน |
| `statusOf` | 155–170 | ตัดสินสถานะบอร์ด 6 แบบ: `updating` `notready` `offline` `nofile` `uptodate` `outdated` |
| `settlePending` | 176–194 | ปิดงานที่รอ: สำเร็จ / ล้มเหลว / หมดเวลา พร้อม toast |
| `outdatedCount` | 196–201 | นับบอร์ดที่ยังเก่า ใช้กับป้ายบนแท็บและการเลือกแท็บเริ่มต้น |
| `render` | 205–266 | วาดหัว แท็บ และแผงของแท็บที่เลือก |
| `filesCard` | 268–318 | การ์ดรายการไฟล์ ไฟล์แรก (ล่าสุด) เน้นสี ปุ่ม "ลบ" ทุกไฟล์ |
| `dropZone` | 320–371 | `<label>` ที่ห่อ `<input type="file">` + รับลากวาง |
| `devicesCard`, `deviceRow`, `statusBadge` | 373–523 | ตารางบอร์ด ช่องติ๊ก รุ่นปัจจุบัน → รุ่นใหม่ ป้ายสถานะ ปุ่ม "อัปเดต" |
| `bulkBar` | 525–555 | แถบ "เลือก N บอร์ด · ใช้ไฟล์ …" + ปุ่ม "อัปเดต N บอร์ดที่เลือก" |
| `startUpdates` | 559–604 | ยืนยัน แล้วส่งคำสั่ง OTA ทีละบอร์ด จด `pending` รวมผลเป็น toast |
| `handleFile` | 606–668 | ตรวจไฟล์ฝั่งเบราว์เซอร์ ถามรุ่นถ้าชื่อไม่มีรุ่น ตรวจชนิดตรงแท็บ แล้วอัปโหลด |
| `uploadWithReplace` | 670–693 | อัปโหลด ถ้าได้ 409 ถามเขียนทับแล้วส่งซ้ำพร้อม `replace` |
| `removeFile`, `formatSize` | 695–717 | ลบไฟล์ (ยืนยันก่อน) และแปลงขนาดเป็น KB/MB |

> [!NOTE]
> หน้าห้องและอุปกรณ์ (`devices.js`) ยังมีปุ่ม "อัปเดตเฟิร์มแวร์" ทีละเครื่องเหมือนเดิม (`startOta`) หน้าเฟิร์มแวร์ไม่ได้มาแทน แต่เพิ่มการอัปโหลดไฟล์ การเห็นภาพรวมว่าบอร์ดไหนเก่า และการสั่งหลายตัวพร้อมกัน

### `views/users.js` — ผู้ใช้งาน (**แอดมินเท่านั้น**)

- **ข้อมูล**: `state.users` (`loaders.users()` เรียกตอน mount เท่านั้น ไม่อยู่ใน polling)
- รายการบัญชีเป็นการ์ด (ชื่อ อีเมล โทรศัพท์ เข้าใช้ล่าสุด สร้างเมื่อ) พร้อม dropdown สิทธิ์ (`staff` เจ้าหน้าที่ / `admin` ผู้ดูแลระบบ) สวิตช์เปิดใช้งาน ปุ่มลบ และปุ่ม "เพิ่มผู้ใช้" (`api.createUser`, รหัสผ่านเริ่มต้นอย่างน้อย 8 ตัวอักษร)
- กฎที่ Backend ป้องกันไว้และหน้าจอปิดปุ่มล่วงหน้า (ไม่ให้กดแล้วเจอข้อความปฏิเสธ): แก้สิทธิ์/ปิด/ลบบัญชีตัวเองไม่ได้ (`isSelf`) และปิดแอดมินคนสุดท้ายไม่ได้ (`isLastAdmin`) เปลี่ยนสิทธิ์แล้วผู้ใช้นั้นต้องเข้าสู่ระบบใหม่

### `views/settings.js` — ตั้งค่า (ทุกคน, สวิตช์รวมเป็นของแอดมิน)

ประกอบจาก 5 การ์ด: `displayCard` (ธีมสี 5 แบบ + ขนาดตัวอักษร 3 ระดับ "มีผลเฉพาะเครื่องนี้" ใช้ `theme.js`/`prefs.js` ไม่เรียก API), `autoOffCard` (สวิตช์รวมระบบปิดแอร์อัตโนมัติทั้งอาคาร `api.setAutoOffEnabled` ปิดแล้วต้องผ่าน `confirmAction` เพราะกดทีเดียวหยุดทั้งอาคาร: เจ้าหน้าที่เห็นสถานะแต่เปลี่ยนไม่ได้ `disabled: !isAdmin`), `profileCard` (ดู/แก้ข้อมูลส่วนตัว `api.updateProfile` เปลี่ยนอีเมลต้องกรอกรหัสผ่านปัจจุบันเพราะ OTP ลืมรหัสส่งไปอีเมลนี้, เปลี่ยนรหัสผ่าน `api.changePassword`), `healthCard` (สถานะ API/MQTT จาก `state.health` เวลาเซิร์ฟเวอร์ และรายการ `state.errors` ถ้ามีชุดข้อมูลโหลดไม่สำเร็จ + ปุ่ม `refreshAll`), `sessionCard` (ออกจากระบบ `context.logout()` ลบโทเคนในเครื่องนี้เท่านั้น)

## CSS: สถาปัตยกรรม 4 ชั้น

ลำดับโหลดใน `index.html` คือลำดับความรับผิดชอบ จากนามธรรมไปเฉพาะเจาะจง และเพราะ cascade ให้ไฟล์ที่มาทีหลังชนะเมื่อความเจาะจงเท่ากัน ลำดับนี้จึงสำคัญ

| ชั้น | ไฟล์ (บรรทัด) | ใส่อะไร | ตัวอย่าง |
|---|---|---|---|
| 1 tokens | `tokens.css` (275) | **ตัวแปรล้วน** ไม่มีกฎของ element ใด | `--accent`, `--panel`, `--fs-base`, `--radius-md` |
| 2 base | `base.css` (573) | reset, `body`, โครงหน้า (`.app` `.sidebar` `.topbar` `.view`), แถบเมนูล่าง, การย่อจอ | `.sidebar { width: var(--sidebar-w) }` |
| 3 components | `components.css` (1302) | ชิ้นส่วนใช้ซ้ำ ไม่ผูกกับหน้า | `.card` `.btn` `.pill` `.switch` `table.data` `.drawer` `.modal` `.toast` `.skeleton` |
| 4 views | `views.css` (2897 หลังเพิ่มสไตล์หน้าเฟิร์มแวร์ 243 บรรทัด 14 ต.ค. 2569) | เฉพาะหน้า | `.hero-row` `.pulse-cell` `.room-card` `.sched-card` `.import-modal` |

กฎเหล็ก: **ไม่เขียนสีหรือ px ของตัวอักษรตรง ๆ ในชั้น 2–4** ต้องอ่านจาก token (`var(--text-mid)`, `var(--fs-sm)`) ผลที่ได้คือเปลี่ยนธีม/ขนาดตัวอักษรที่ที่เดียวแล้วทุกที่เปลี่ยนตาม

### ธีมด้วย `data-palette`

`tokens.css` ประกาศตัวแปรชุดเต็มสำหรับธีมเทาที่ `:root, [data-palette='gray']` (บรรทัด 62–112) แล้วอีก 3 ธีมเขียนทับเฉพาะค่า: `[data-palette='white']` (115), `'black'` (164), `'green'` (213) ซึ่งต้องกำหนดตัวแปรครบทุกตัว (คอมเมนต์ในไฟล์เตือนไว้) `theme.js` แค่ตั้ง `<html data-palette="white">` เบราว์เซอร์คำนวณค่า `var(--...)` ใหม่ทั้งหน้าเอง ไม่ต้องไล่แก้ DOM ใด ๆ

ตัวอย่างพิเศษ: หน้าตั้งค่าแสดงตัวอย่างสีของแต่ละธีมได้พร้อมกัน เพราะ selector `[data-palette='white']` ใช้ได้กับ element ใดก็ได้ ไม่ใช่แค่ `<html>` (`el('span', { class: 'theme-preview', dataset: { palette: 'white' } })`)

ธีม `green` ต่างจากสามธีมแรก: แถบข้างเป็นสีเขียวเข้มแต่เนื้อหาพื้นสว่าง จึงแยกตัวแปรกลุ่ม `--side-*` ออกจาก `--panel/--text-*` และ `base.css` มีกฎเฉพาะ `:root[data-palette='green'] .sidebar .nav-badge`

### คอนทราสต์ (Contrast)

`tokens.css` ตั้งเป้า **WCAG AA = 4.5:1** (อัตราส่วนความสว่างตัวหนังสือต่อพื้น) สำหรับ `--text-hi/mid/low` บนทั้ง `--panel` และ `--panel-raised` ตัวอย่างที่คอมเมนต์บันทึกไว้: ธีมสว่างใช้ `#0F7D45` เป็นสีเน้น ไม่ใช้ `#128C4E` ของโลโก้ เพราะบนพื้นขาวได้แค่ 4.3:1 อีกจุดคือ `--fs-2xs` = 12px เป็นขนาดเล็กสุดของทั้งเว็บ เพราะภาษาไทยที่เล็กกว่านี้วรรณยุกต์ชนกันจนอ่านไม่ออก และ `--lh-thai: 1.6` เพราะสระบน-ล่างต้องการระยะบรรทัดมากกว่าค่าเริ่มต้น (~1.2) ข้อมูลสำคัญไม่พึ่งสีอย่างเดียว (ชิปมีข้อความ เมนูที่เลือกมีแถบสีด้านซ้ายและตัวหนา)

### ขนาดตัวอักษรและความรับรู้อุปกรณ์

ทุก `--fs-*` เป็น `calc(Npx * var(--text-scale))` ผู้ใช้เลือก "ใหญ่" → `prefs.js` ตั้ง `<html data-text="large">` → `tokens.css` ตั้ง `--text-scale: 1.1` ("ใหญ่มาก" = 1.22) ทุกที่ที่ใช้ `--fs-*` ขยายพร้อมกัน `@media (pointer: coarse)` เพิ่ม `--tap` จาก 40px เป็น 44px ให้ปุ่มกดด้วยนิ้วโดนง่าย

### Responsive

| จุดเปลี่ยน | ใน | เกิดอะไร |
|---|---|---|
| `max-width: 820px` | `base.css` | แถบข้างกลายเป็นลิ้นชักซ้อนบน (`transform: translateX(-100%)` → `.open`), แถบเมนูล่าง 5 ปุ่ม (`grid-template-columns: repeat(5, 1fr)`, `position: fixed`), แถบบนไม่ค้างหน้าจอ, ซ่อนปุ่มสามขีดและจุดธีม |
| `min-width: 1500px` | `base.css` | เพิ่ม padding ซ้าย-ขวา เนื้อหากว้างสุด `--content-max: 1680px` (บรรทัดยาวเกินอ่านยาก) |
| `max-width: 1100px` | `views.css` | `.hero-row` จาก 2 คอลัมน์ `1.5fr 1fr` เป็นคอลัมน์เดียว |
| `max-width: 620px` | หลายไฟล์ | `.drawer` เต็มจอ, `.room-grid` 2 คอลัมน์ (≤380px คอลัมน์เดียว), modal กลายเป็น bottom sheet เลื่อนขึ้นจากล่าง (`align-items: flex-end`, `animation: sheet-in`) |
| `max-width: 620px` (`.fw-table`) | `views.css` | ตารางบอร์ดของหน้าเฟิร์มแวร์กลายเป็นการ์ด (เพิ่ม 14 ต.ค. 2569 ดูหัวข้อถัดไป) |
| `prefers-reduced-motion` | `components.css`, `views.css` | ปิดแอนิเมชัน `.skeleton` (แถบโครงกระดูกตอนโหลด) และจุดกะพริบ `.pulse-live::after` ทำ `.spinner` หมุนช้าลง และ (เพิ่ม 14 ต.ค. 2569) หยุดหมุน `.fw-spinner` ของหน้าเฟิร์มแวร์ |

`env(safe-area-inset-bottom)` เว้นพื้นที่ให้แถบ home indicator ของ iPhone, `100dvh` (dynamic viewport height) แก้ปัญหา `100vh` ที่ไม่นับแถบ URL ของมือถือที่ยืด/หดได้

### หน้าเฟิร์มแวร์ใน `views.css` (เพิ่ม 14 ต.ค. 2569)

สไตล์ใหม่ 243 บรรทัดต่อท้าย `views.css` (บรรทัด 2656–2897) ขึ้นต้นด้วย `fw-` ทั้งหมด (ย่อจาก firmware) กันชื่อชนกับหน้าอื่น แนวคิดหลัก

| ส่วน | class | แนวคิด |
|---|---|---|
| โครงแผง | `.fw-panel` (flex แนวตั้ง gap 16px), `.fw-grid` | `grid-template-columns: repeat(auto-fit, minmax(300px, 1fr))` การ์ดไฟล์กับช่องลากไฟล์วางคู่กันบนจอกว้าง และตกลงเป็นแถวเดียวเองเมื่อจอแคบกว่า ~600px โดยไม่ต้องเขียน media query |
| ช่องลากไฟล์ | `.drop-zone` (ของเดิมจากหน้านำเข้าตารางเรียน), `.drop-zone.busy` | ใช้สไตล์เดิมซ้ำ เพิ่มแค่ `.busy` (`opacity: 0.7; pointer-events: none`) กันลากไฟล์ซ้อนระหว่างอัปโหลด |
| ป้าย | `.fw-badge.warn` / `.ok`, `.tab.active .fw-badge` | สีจาก token (`--warn`, `--accent`) และเมื่ออยู่บนแท็บที่ถูกเลือก (พื้นสีเน้น) เปลี่ยนเป็น `--on-accent` ให้ยังอ่านออก |
| รายการไฟล์ | `.fw-file`, `.fw-file.latest`, `.fw-version` | ไฟล์ล่าสุดพื้น `--accent-soft` + กรอบ ชื่อไฟล์ยาว `overflow-wrap: anywhere` ตัดคำได้ทุกตำแหน่ง ไม่ดันการ์ดล้นจอ |
| สถานะบอร์ด | `.fw-state.on` / `.off`, `.fw-updating`, `.fw-spinner` | จุดสีหน้าป้ายทำด้วย `::before` ป้ายออฟไลน์เป็นวงกลมกลวง (ไม่พึ่งสีอย่างเดียว) วงหมุน `@keyframes fw-spin` ปิดเมื่อ `prefers-reduced-motion` |
| แถบหลายบอร์ด | `.fw-bar` | `position: sticky` ค้างล่างจอ ดูทีละบรรทัดด้านล่าง |
| มือถือ | `@media (max-width: 620px)` ของ `.fw-table` | ตาราง → การ์ด ดูทีละบรรทัดด้านล่าง |

**ไฟล์ `webapp/assets/css/views.css` บรรทัด 2835–2850**

```css:2835
.fw-bar {
  position: sticky;
  bottom: calc(var(--bottom-nav-h) + 12px);
  z-index: 5;
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: space-between;
  gap: 10px 16px;
  padding: 12px 16px;
  border-radius: var(--radius-md);
  border: 1px solid var(--accent-dim);
  background: var(--panel-raised);
  box-shadow: var(--shadow-drop);
  font-size: var(--fs-sm);
}
```

| บรรทัด | อธิบาย |
|---|---|
| 2836 | `position: sticky` = เลื่อนตามเนื้อหาปกติ แต่ "ติด" ขอบล่างของหน้าต่างเมื่อจะหลุดจอ แถบนี้จึงอยู่ใต้ตาราง และลอยค้างให้เห็นเสมอถ้าตารางยาวเกินจอ |
| 2837 | ระยะจากล่าง = ความสูงแถบเมนูล่าง + 12px ตัวแปร `--bottom-nav-h` เป็น `0px` บนเดสก์ท็อป (`tokens.css`) และ `64px` บนจอ ≤ 820px (`base.css`) แถบจึงไม่จมใต้เมนูล่างของมือถือ |
| 2838 | `z-index: 5` ให้อยู่เหนือแถวตารางที่เลื่อนผ่านข้างใต้ |
| 2839–2843 | flex แบบ `wrap` ข้อความกับปุ่มอยู่คนละฝั่ง จอแคบก็ขึ้นบรรทัดใหม่เองแทนที่จะล้น |
| 2847–2848 | พื้น `--panel-raised` + เงา ให้ดูเป็นแผงลอยที่แยกจากเนื้อหา |

**ไฟล์ `webapp/assets/css/views.css` บรรทัด 2854–2883**

```css:2854
@media (max-width: 620px) {
  .fw-table,
  .fw-table tbody {
    display: block;
    white-space: normal;
  }

  .fw-table thead {
    display: none;
  }

  .fw-table tr {
    display: grid;
    grid-template-columns: 32px minmax(0, 1fr) auto;
    gap: 4px 10px;
    padding: 12px;
    border-top: 1px solid var(--hairline-soft);
  }

  .fw-table tbody tr:first-child {
    border-top: none;
  }

  table.data.fw-table td {
    display: block;
    padding: 0;
    border: none;
    background: none !important;
    grid-column: 2;
  }
```

**ไฟล์ `webapp/assets/css/views.css` บรรทัด 2885–2896**

```css:2885
  table.data.fw-table td.fw-check {
    grid-column: 1;
    grid-row: 1 / span 3;
    width: auto;
    text-align: left;
  }

  table.data.fw-table td.fw-act {
    grid-column: 3;
    grid-row: 1 / span 3;
    align-self: center;
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 2854 | ทำงานเมื่อจอกว้างไม่เกิน 620px (จุดเดียวกับที่ modal กลายเป็น bottom sheet) |
| 2855–2859 | เปลี่ยน `<table>` และ `<tbody>` จาก `display: table` เป็น `block` เลิกจัดเป็นคอลัมน์ และ `white-space: normal` ให้ข้อความตัดบรรทัดได้ |
| 2861–2863 | ซ่อนหัวตาราง (`thead`) เพราะในการ์ดแต่ละช่องอธิบายตัวเองอยู่แล้ว |
| 2865–2871 | แต่ละแถว `<tr>` กลายเป็น **grid 3 คอลัมน์**: 32px (ช่องติ๊ก) · `minmax(0, 1fr)` (เนื้อหา ยืดได้แต่หดต่ำกว่าเนื้อหาได้ กันชื่อยาวดันล้น) · `auto` (ปุ่ม) คั่นแถวด้วยเส้นบน |
| 2873–2875 | แถวแรกไม่มีเส้นบน (ไม่งั้นเส้นซ้อนกับขอบการ์ด) |
| 2877–2883 | ทุก `<td>` เป็น block ไม่มี padding/เส้น และวางในคอลัมน์ที่ 2 จึงซ้อนกันลงมา: ชื่อบอร์ด → รุ่น → สถานะ `!important` ทับพื้นสลับสีของ `table.data` ใน `components.css` |
| 2885–2890 | ช่องติ๊กย้ายไปคอลัมน์ 1 และกินความสูง 3 แถว (`grid-row: 1 / span 3`) |
| 2892–2895 | ช่องปุ่ม "อัปเดต" ไปคอลัมน์ 3 กิน 3 แถว และ `align-self: center` อยู่กลางแนวตั้ง |

> [!WHY]
> ตารางบอร์ดมี 5 คอลัมน์ บนมือถือถ้าใช้ตารางจริงต้องเลื่อนข้าง (`.table-wrap` ทำได้) แต่คนที่ยืนหน้าตู้ไฟจะเห็นแค่ครึ่งแถวและกดปุ่มอัปเดตยาก การเปลี่ยน "แถว" เป็น "การ์ด" ด้วย CSS ล้วนทำให้ HTML ชุดเดียวใช้ได้ทั้งสองจอ ไม่ต้องให้ JavaScript รู้ขนาดจอแล้ววาดสองแบบ และยังคง `<table>` ไว้ซึ่งโปรแกรมอ่านหน้าจอเข้าใจโครงสร้างบนเดสก์ท็อป ข้อแลกคือใช้ selector `table.data.fw-table td` ที่เจาะจงสูงเพื่อชนะสไตล์ตารางกลาง และต้องใช้ `!important` หนึ่งจุด

> [!WARN]
> commit นี้ไม่ได้เปลี่ยนเลข `?v=` ใน `index.html` (`views.css?v=4.2`, `main.js?v=4.4` เท่าเดิม) และเพิ่ม export ใหม่ลงไฟล์เดิม (`icons.firmware` ใน `icons.js`, `api.uploadFirmware` ใน `api.js`, และ 11 ต.ค. `WIRED_PROTOCOL`/`airBrand`/… ใน `format.js`) ซึ่งสวนกับหลักการข้อ 10 ของบทนี้ ภายใน 1 ชั่วโมงหลัง deploy เบราว์เซอร์ที่ถือไฟล์เก่าในแคชอาจได้ไฟล์ใหม่ปนเก่า เช่น `app.js` ใหม่เรียก `icons[view.icon](16)` กับ `icons.js` เก่าที่ไม่มี `firmware` ทำให้วาดเมนูพัง หรือ `rooms.js` ใหม่ import `airBrand` จาก `format.js` เก่าไม่เจอแล้วทั้งเว็บโหลดไม่ขึ้น ทางแก้หน้างานคือ Ctrl+F5 ครั้งเดียว ถ้าจะกันจริงควรขยับ `?v=` และแยก export ใหม่ไว้ในไฟล์ใหม่ตามหลักการเดิม

## เจาะโค้ดทีละบรรทัด

### 1) `index.html`: โครงเปลือกและการโหลดสคริปต์

**ไฟล์ `webapp/index.html` บรรทัด 31–38**

```html:31
<link rel="stylesheet" href="assets/css/tokens.css?v=4.2">
<link rel="stylesheet" href="assets/css/base.css?v=4.2">
<link rel="stylesheet" href="assets/css/components.css?v=4.4">
<link rel="stylesheet" href="assets/css/views.css?v=4.2">
</head>
<body>

<div class="app" id="app" hidden>
```

| บรรทัด | โค้ด | ความหมาย |
|---|---|---|
| 31–34 | `<link rel="stylesheet" href="assets/css/....css?v=4.x">` | โหลด CSS 4 ไฟล์ตามลำดับ tokens → base → components → views ตามลำดับนี้กฎของ views ชนะ components ชนะ base เมื่อความเจาะจงเท่ากัน `?v=4.2` ไม่ใช่ส่วนของชื่อไฟล์ เป็น query string ที่เซิร์ฟเวอร์ไม่สนใจ แต่ทำให้ URL ต่างไปจากเดิม เบราว์เซอร์จึงถือเป็นไฟล์ใหม่และไม่ใช้ของแคช |
| 35 | `</head>` | จบส่วนหัว: ไม่มี `<script>` ใน `<head>` เลย |
| 36 | `<body>` | เริ่มส่วนที่มองเห็น |
| 38 | `<div class="app" id="app" hidden>` | ตัวแอปทั้งก้อน แอตทริบิวต์ `hidden` ซ่อนไว้ก่อนจนกว่า `app.js` รู้ว่าล็อกอินแล้ว (ถ้าไม่ซ่อน ผู้ใช้ที่ยังไม่ล็อกอินจะเห็นเมนูเปล่า ๆ แวบหนึ่ง) `base.css` มีกฎ `[hidden] { display: none !important; }` กันไม่ให้กฎ `display: flex` ของ `.app` มาทับ `hidden` |


**ไฟล์ `webapp/index.html` บรรทัด 98–99**

```html:98
<!-- สคริปต์อยู่ในไฟล์แยก เพราะ Content-Security-Policy ไม่อนุญาตสคริปต์ในหน้า -->
<script type="module" src="assets/js/main.js?v=4.4"></script>
```

- บรรทัด 98 คอมเมนต์อธิบายตรง ๆ ว่าทำไมสคริปต์ต้องอยู่ในไฟล์แยก (CSP)
- บรรทัด 99 `type="module"` ทำให้เบราว์เซอร์: (1) ตีความไฟล์เป็น ES Module (ใช้ `import/export` ได้) (2) โหลดแบบ deferred คือไม่บล็อกการวาด HTML และรันหลัง HTML ถูกอ่านครบ จึงหา `#app` เจอแน่นอนโดยไม่ต้องรอ event `DOMContentLoaded` (3) ใช้ strict mode อัตโนมัติ และเปิดเฉพาะผ่าน `http(s)://` เท่านั้น (จึงดับเบิลคลิกเปิดไฟล์ไม่ได้)
- เฉพาะ `main.js` มี `?v=4.4` ไฟล์ที่ `main.js` import ต่อ (`./app.js` ฯลฯ) **ไม่มี** `?v=` ดังนั้นการเปลี่ยนเลขนี้ไม่ได้ล้างแคชของโมดูลลูก เป็นเหตุผลที่โค้ดมีมาตรการกันไฟล์เก่า-ใหม่ปนกัน (ดูหัวข้อหลักการ)

### 2) `main.js`: จุดเริ่มต้น

**ไฟล์ `webapp/assets/js/main.js` บรรทัด 7–15**

```js:7
import { applyPrefs } from './prefs.js';
import { applyTheme } from './theme.js';
import { startApp, startClock } from './app.js';

// ใส่ธีมและขนาดตัวอักษรก่อนวาดอะไรทั้งนั้น หน้าจอจะได้ไม่กะพริบเปลี่ยนสี
applyPrefs();
applyTheme();
startClock();
startApp();
```

| บรรทัด | ความหมาย |
|---|---|
| 7–9 | `import { ... } from './x.js'` ดึงฟังก์ชันมาจากโมดูลอื่น ต้องมี `./` และนามสกุล `.js` เสมอ (เบราว์เซอร์ไม่เดาให้เหมือน Node) `{ startApp, startClock }` คือ named export เลือกเอาเฉพาะที่ต้องการ |
| 12 | `applyPrefs()` อ่านขนาดตัวอักษรจาก localStorage แล้วตั้ง `data-text` บน `<html>` |
| 13 | `applyTheme()` อ่านธีมแล้วตั้ง `data-palette` บน `<html>` ทั้งสองต้องทำ**ก่อนวาด**: ถ้าวาดก่อน ผู้ใช้ธีมขาวจะเห็นหน้าสีเทา (ค่าเริ่มต้นใน CSS) แวบหนึ่งแล้วค่อยเปลี่ยน |
| 14 | `startClock()` ใส่วันที่ไทยบนแถบบนและตั้ง `setInterval` ทุก 60 วินาที |
| 15 | `startApp()` ตัดสินล็อกอินและวาดแอป จากจุดนี้ไป `app.js` คุมต่อ |

ไฟล์นี้ไม่มี `DOMContentLoaded` เพราะ module ถูก defer อยู่แล้ว

### 3) `config.js`: `?api=` เปิดใช้เฉพาะ localhost (ทีละบรรทัด)

**ไฟล์ `webapp/assets/js/config.js` บรรทัด 16–38**

```js:16
const STORAGE_API = 'rmutt.apiBase';

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]', '::1']);

function isLocalPage() {
  return LOCAL_HOSTS.has(window.location.hostname);
}

/** รับเฉพาะ path บนโดเมนเดียวกัน หรือ URL แบบ http/https เท่านั้น */
function normalizeApiBase(value) {
  const text = String(value ?? '').trim();
  if (!text) return null;
  if (text.startsWith('/') && !text.startsWith('//')) {
    return text.replace(/\/+$/, '') || '/api';
  }
  try {
    const url = new URL(text);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    return url.href.replace(/\/+$/, '');
  } catch {
    return null;
  }
}
```

| บรรทัด | ความหมาย |
|---|---|
| 16 | ชื่อคีย์ localStorage ที่ใช้จำที่อยู่ API ของโหมดพัฒนา |
| 18 | `Set` ของชื่อโฮสต์ที่ถือว่า "เครื่องตัวเอง" (`localhost`, `127.0.0.1`, และ IPv6 loopback สองรูปแบบ) `Set.has()` เร็วและอ่านง่ายกว่า `array.includes` |
| 20–22 | `window.location.hostname` คือชื่อโฮสต์ของหน้าที่เปิดอยู่ (ไม่รวมพอร์ต) ใช่เครื่องตัวเองหรือไม่ |
| 25–26 | ฟังก์ชัน `normalizeApiBase` บรรทัด 26: `String(value ?? '')` แปลงอะไรก็ได้เป็นข้อความ (`??` คือถ้า `null/undefined` ให้ใช้ `''`) `.trim()` ตัดช่องว่าง |
| 27 | ว่างเปล่า → ไม่ใช้ (`null`) |
| 28–30 | ถ้าขึ้นต้นด้วย `/` (path บนโดเมนเดียวกัน เช่น `/api`) **แต่ไม่ใช่ `//`** ให้รับ เพราะ `//evil.com/x` เป็น "protocol-relative URL" ที่เบราว์เซอร์ตีความเป็นเว็บอื่นได้ จึงต้องกันไว้ `.replace(/\/+$/, '')` ตัดเครื่องหมาย `/` ท้ายทั้งหมด (regex: `/+` = ซ้ำหนึ่งตัวขึ้นไป, `$` = ท้ายข้อความ) ถ้าเหลือว่างให้ใช้ `/api` |
| 31–37 | ไม่ใช่ path → ลองแปลงเป็น URL เต็มด้วย `new URL(text)` (ถ้า parse ไม่ได้จะ throw → `catch` คืน `null`) แล้วรับเฉพาะ `http:` กับ `https:` เท่านั้น กันรูปแบบอย่าง `javascript:` และ `data:` |

**ไฟล์ `webapp/assets/js/config.js` บรรทัด 40–62**

```js:40
function resolveApiBase() {
  try {
    if (!isLocalPage()) {
      // ล้างค่าที่อาจถูกฝังไว้จากลิงก์แปลก ๆ ก่อนหน้านี้ แล้วใช้ API ของโดเมนนี้เสมอ
      window.localStorage.removeItem(STORAGE_API);
      return '/api';
    }
    const fromQuery = normalizeApiBase(
      new URLSearchParams(window.location.search).get('api'),
    );
    if (fromQuery) {
      window.localStorage.setItem(STORAGE_API, fromQuery);
      return fromQuery;
    }
    const saved = normalizeApiBase(window.localStorage.getItem(STORAGE_API));
    if (saved) return saved;
  } catch {
    // เบราว์เซอร์บล็อก localStorage (โหมดส่วนตัว) ใช้ค่าเริ่มต้นต่อไปได้
  }
  return '/api';
}

export const API_BASE = resolveApiBase();
```

| บรรทัด | ความหมาย |
|---|---|
| 41, 56 | ห่อทั้งหมดด้วย `try/catch` เพราะ `localStorage` อาจ throw ในโหมดส่วนตัว/ถูกบล็อก ถ้าพังก็ตกลงไปใช้ค่าเริ่มต้น (บรรทัด 59) |
| 42–45 | **ถ้าไม่ได้เปิดจากเครื่องตัวเอง (= ใช้งานจริง)**: ลบค่าที่เคยจำไว้ทิ้ง (`removeItem`) แล้วคืน `/api` ทันที ไม่อ่าน `?api=` เลย |
| 47–49 | (เฉพาะ localhost) อ่าน `?api=` จาก URL ด้วย `URLSearchParams(location.search).get('api')` แล้วผ่าน `normalizeApiBase` |
| 50–53 | ถ้าได้ค่าถูกต้อง → จำลง localStorage และใช้ เปิดครั้งเดียวพอ ครั้งหน้าไม่ต้องใส่ |
| 54–55 | ไม่มีใน URL → ลองค่าที่จำไว้ (ผ่าน normalize อีกรอบ เผื่อมีใครแก้ค่าในเครื่อง) |
| 59 | ตกหล่นทุกกรณี → `/api` (โดเมนเดียวกับหน้าเว็บ) |
| 62 | `export const API_BASE = resolveApiBase();` คำนวณ**ครั้งเดียว**ตอนโมดูลถูกโหลด (โมดูลรันครั้งเดียวต่อหน้า) ทุกไฟล์ที่ import ได้ค่าเดียวกัน |

**ทำไมต้องจำกัดเฉพาะ localhost (เหตุผลด้านความปลอดภัย)**

สมมติยอมรับ `?api=` ทุกโดเมน ผู้โจมตีส่งลิงก์ `https://โดเมนจริง/?api=https://evil.example/api` ให้เหยื่อ
1. หน้าเว็บที่โหลดมาเป็นของจริง (ใบรับรอง HTTPS ถูกต้อง เหยื่อไม่สงสัย)
2. `config.js` จำ `https://evil.example/api` ไว้ใน localStorage
3. เมื่อเหยื่อกรอก Username/Password แล้วกดเข้าสู่ระบบ `api.js` ส่งคำขอ `POST /auth/login` ไปที่ evil.example **รหัสผ่านรั่วทันที** และเพราะค่าถูก "จำ" ไว้ ทุกครั้งที่เข้าเว็บต่อไปก็ยังรั่ว

มาตรการในโค้ด: (ก) บรรทัด 42–45 ไม่ฟัง `?api=` นอก localhost (ข) ยัง **ล้างค่าที่อาจถูกฝังไว้ก่อนหน้า** ด้วย (ค) `normalizeApiBase` กัน `//` และโปรโตคอลแปลก ๆ แม้ในโหมดพัฒนา และมีชั้นสำรองคือ CSP `connect-src 'self'` ที่ Caddy ซึ่งบล็อกการ `fetch` ไปโดเมนอื่นอยู่แล้ว (defense in depth: ชั้นหนึ่งพลาดอีกชั้นยังกัน)

> [!WARN]
> `docs/learn/10-*.md` ยังแสดง `resolveApiBase()` รุ่นเก่าที่ยอมรับ `?api=` ทุกโดเมน ใช้โค้ดจริงในไฟล์นี้เป็นหลัก

### 4) `api.js`: แกนของ `request()`

**ไฟล์ `webapp/assets/js/api.js` บรรทัด 96–126**

```js:96
async function request(
  method,
  path,
  {
    body = null,
    query = null,
    raw = false,
    signal = null,
    // ส่งไฟล์ (Blob/File) ตรง ๆ ไม่แปลงเป็น JSON ใช้กับการอัปโหลดตารางเรียน
    upload = null,
    headers: extraHeaders = null,
  } = {},
) {
  const headers = { ...(extraHeaders ?? {}) };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body != null) headers['Content-Type'] = 'application/json';

  let response;
  try {
    response = await fetch(buildUrl(path, query), {
      method,
      headers,
      signal,
      body: upload ?? (body == null ? undefined : JSON.stringify(body)),
    });
  } catch (error) {
    if (error?.name === 'AbortError') throw error;
    // แยกกรณี "ต่อเซิร์ฟเวอร์ไม่ได้" ออกจาก "เซิร์ฟเวอร์ตอบว่าไม่ผ่าน"
    // เพราะวิธีแก้คนละเรื่องกันโดยสิ้นเชิง
    throw new ApiError(0, 'ต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจอินเทอร์เน็ต');
  }
```

| บรรทัด | ความหมาย |
|---|---|
| 96 | `async function request(method, path, {...} = {})` ฟังก์ชัน async คืน Promise เสมอ ตัวที่สามเป็น **destructuring** ของออบเจ็กต์ตัวเลือก พร้อมค่าเริ่มต้นแต่ละตัว และ `= {}` ท้ายสุดทำให้เรียกโดยไม่ส่งตัวเลือกได้ |
| 100–103 | `body` (ข้อมูลที่จะส่ง JSON) `query` (พารามิเตอร์ใน URL) `raw` (ขอ Response ดิบ ไม่แปลง JSON) `signal` (สำหรับยกเลิกคำขอด้วย `AbortController`) |
| 105 | `upload` ส่งไฟล์ดิบ (Blob/File) ใช้กับนำเข้าตารางเรียน |
| 106 | `headers: extraHeaders = null` เปลี่ยนชื่อตัวแปรตอน destructure (ชื่อ `headers` ถูกใช้ข้างล่างแล้ว) |
| 109 | `{ ...(extraHeaders ?? {}) }` **spread** คัดลอก header เพิ่มเติมเป็นออบเจ็กต์ใหม่ (ไม่แก้ของผู้เรียก) |
| 110 | มี token → ใส่ `Authorization: Bearer <token>` นี่คือจุดเดียวในแอปที่ใส่ token |
| 111 | มี body → บอกเซิร์ฟเวอร์ว่าเป็น JSON |
| 113–126 | `try { response = await fetch(...) } catch { ... }` `fetch` จะ throw **เฉพาะ**เมื่อ "ต่อเซิร์ฟเวอร์ไม่ได้" (เน็ตหลุด DNS พัง) ไม่ throw เมื่อได้ 404/500 บรรทัด 122 ถ้าเป็น `AbortError` (เราเองสั่งยกเลิก) โยนต่อให้ผู้เรียกเงียบ ๆ บรรทัด 125 นอกนั้นแปลงเป็น `ApiError(0, ...)` สถานะ 0 = ไม่มี HTTP status เพราะไม่มีคำตอบ |
| 119 | `body: upload ?? (body == null ? undefined : JSON.stringify(body))` ถ้ามีไฟล์ส่งไฟล์ ถ้ามี body แปลงเป็นข้อความ JSON ถ้าไม่มีทั้งคู่ `undefined` (ไม่ส่ง body) |

**ไฟล์ `webapp/assets/js/api.js` บรรทัด 128–147**

```js:128
  if (response.status === 401) {
    const payload = await safeJson(response);
    const message = payload?.message ?? 'กรุณาเข้าสู่ระบบใหม่';
    notifyUnauthorized(message);
    throw new ApiError(401, message, payload);
  }

  if (!response.ok) {
    const payload = await safeJson(response);
    throw new ApiError(
      response.status,
      payload?.message ?? `เซิร์ฟเวอร์ตอบกลับรหัส ${response.status}`,
      payload,
    );
  }

  if (raw) return response;
  if (response.status === 204) return null;
  return safeJson(response);
}
```

| บรรทัด | ความหมาย |
|---|---|
| 128 | `response.status === 401` = Unauthorized โทเคนหมดอายุ ถูกเพิกถอน หรือผู้ใช้ถูกปิดบัญชี/เปลี่ยนสิทธิ์ |
| 129–130 | `safeJson` อ่าน body (อาจไม่ใช่ JSON) แล้วใช้ `payload?.message` (**optional chaining**: ถ้า `payload` เป็น `null` ให้ได้ `undefined` ไม่ error) ถ้าไม่มีใช้ข้อความมาตรฐาน |
| 131 | `notifyUnauthorized(message)` ล้างโทเคนและผู้ใช้ที่จำไว้ แล้วเรียก handler ทุกตัวที่ `onUnauthorized` ลงทะเบียน (ใน `app.js` คือเคลียร์ session โชว์ toast และกลับหน้าล็อกอิน) |
| 132 | แล้วยัง `throw` ต่อ เพื่อให้โค้ดที่เรียก `await api.xxx()` ไม่ทำงานต่อด้วยข้อมูลว่าง |
| 135–142 | สถานะ 4xx/5xx อื่น: ใช้ `message` ภาษาไทยที่ Backend ส่งมา ถ้าไม่มี ใช้ "เซิร์ฟเวอร์ตอบกลับรหัส N" `ApiError` เก็บ `status` และ `payload` ให้หน้าจอเช็กได้ (เช่น `error.status === 404` แปลว่า Backend ยังไม่ใช่รุ่นใหม่) |
| 144 | `raw` → คืน Response ดิบ (ใช้ตอนดาวน์โหลด Excel ที่ต้องอ่าน header และ blob) |
| 145 | `204 No Content` ไม่มี body → `null` |
| 146 | ปกติ → `safeJson(response)` แปลง JSON (ล้มเหลวคืน `null` ไม่ throw) |

### 5) `dom.js`: สร้าง DOM อย่างปลอดภัย

**ไฟล์ `webapp/assets/js/dom.js` บรรทัด 10–34**

```js:10
export function el(tag, props = {}, children = []) {
  const node = document.createElement(tag);
  for (const [key, value] of Object.entries(props)) {
    if (value == null || value === false) continue;
    if (key === 'class') {
      node.className = value;
    } else if (key === 'text') {
      node.textContent = String(value);
    } else if (key === 'html') {
      node.innerHTML = value;
    } else if (key === 'dataset') {
      Object.assign(node.dataset, value);
    } else if (key === 'style' && typeof value === 'object') {
      Object.assign(node.style, value);
    } else if (key.startsWith('on') && typeof value === 'function') {
      node.addEventListener(key.slice(2).toLowerCase(), value);
    } else if (value === true) {
      node.setAttribute(key, '');
    } else {
      node.setAttribute(key, String(value));
    }
  }
  append(node, children);
  return node;
}
```

| บรรทัด | ความหมาย |
|---|---|
| 10 | `el('div', { class: 'card', text: 'สวัสดี' }, [ลูก...])` สร้างอิลิเมนต์จากชื่อแท็ก + ออบเจ็กต์คุณสมบัติ + ลูก (ค่าเริ่มต้น `{}` และ `[]` ทำให้เรียกสั้น ๆ ได้) |
| 11 | `document.createElement` สร้างโหนดเปล่า |
| 12 | `Object.entries(props)` แปลงออบเจ็กต์เป็นรายการคู่ `[key, value]` แล้ว `for (const [key, value] of ...)` แยกค่าทีละคู่ |
| 13 | ค่า `null`/`undefined`/`false` → ข้าม จึงเขียน `disabled: !isAdmin` หรือ `hidden: true` ได้ตรง ๆ และเงื่อนไขอย่าง `onclick: target ? fn : null` ก็ใช้ได้ |
| 14–15 | `class` → `className` (`class` เป็นคำสงวนของ JS) |
| 16–17 | **`text` → `textContent`** ซึ่งเบราว์เซอร์ถือเป็นข้อความล้วน แม้ค่าเป็น `<script>alert(1)</script>` ก็แสดงเป็นตัวอักษรเฉย ๆ ไม่รัน นี่คือเส้นทางหลักที่ข้อมูลจากฐานข้อมูลเข้าสู่หน้า |
| 18–19 | `html` → `innerHTML` (ช่องทางหลบ) ใช้เฉพาะสตริง SVG ของไอคอนที่เขียนเอง ห้ามใช้กับข้อมูลผู้ใช้ ได้ตรวจแล้วว่าทุกจุดที่ใช้ `html:`/`innerHTML` ในโปรเจกต์ส่งค่าจาก `icons.*`/`uiIcons.*` หรือสตริง SVG คงที่ |
| 20–21 | `dataset` → `Object.assign(node.dataset, value)` ตั้ง `data-*` หลายตัวพร้อมกัน |
| 22–23 | `style` เป็นออบเจ็กต์ → `Object.assign(node.style, value)` เช่น `{ marginTop: '14px' }` |
| 24–25 | `onclick`, `oninput`, `onchange` ... **ที่เป็นฟังก์ชัน** → `addEventListener(ชื่อ event ตัวพิมพ์เล็กโดยตัด on ออก)` ถ้าค่าเป็นสตริงจะไม่เข้าเงื่อนไขนี้ ไปตก `setAttribute` ซึ่งถ้ามีค่าเป็นโค้ดก็จะถูก CSP (ไม่มี `unsafe-inline` สำหรับสคริปต์) บล็อก |
| 26–27 | ค่า `true` → ตั้งแอตทริบิวต์แบบ boolean (`hidden=""`) |
| 28–30 | ที่เหลือ → `setAttribute(key, String(value))` เช่น `type`, `placeholder`, `aria-label` |
| 32–33 | `append(node, children)` ใส่ลูก (รับข้อความ, `Node`, อาเรย์ซ้อน) ข้อความทุกชนิดผ่าน `document.createTextNode(String(child))` ซึ่งเป็นข้อความล้วนเช่นกัน แล้วคืน `node` |

เทียบ: `box.innerHTML = '<b>' + subject + '</b>'` ถ้า `subject` = `<img src=x onerror="...">` เบราว์เซอร์สร้าง `<img>` จริงและรัน `onerror` นั่นคือ XSS แต่ `el('b', { text: subject })` แสดงข้อความทั้งก้อนเป็นตัวอักษร

### 6) `store.js`: polling และการแจ้งหน้าจอ

**ไฟล์ `webapp/assets/js/store.js` บรรทัด 52–80** (pub/sub และการรวมการแจ้ง)

```js:52
const listeners = new Set();

/** สมัครรับแจ้งเมื่อสถานะเปลี่ยน คืนฟังก์ชันสำหรับยกเลิก */
export function subscribe(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

let emitQueued = false;

/**
 * แจ้งผู้ติดตาม
 *
 * รวบหลายการเปลี่ยนแปลงในรอบเดียวกันให้แจ้งครั้งเดียว เพราะการโหลดข้อมูล
 * ชุดหนึ่งมักเขียนสถานะหลายก้อนติดกัน ถ้าแจ้งทุกก้อนหน้าจอจะวาดใหม่ซ้ำ ๆ
 */
export function emit() {
  if (emitQueued) return;
  emitQueued = true;
  queueMicrotask(() => {
    emitQueued = false;
    for (const listener of listeners) listener(state);
  });
}

export function patchState(partial) {
  Object.assign(state, partial);
  emit();
}
```

| บรรทัด | ความหมาย |
|---|---|
| 52 | `listeners` เป็น `Set` ของฟังก์ชันที่รอรับแจ้ง (`Set` กันลงทะเบียนซ้ำ ลบง่าย) |
| 55–58 | `subscribe(listener)` ลงทะเบียนและ **คืนฟังก์ชันยกเลิก** (`() => listeners.delete(listener)`) นี่คือแพทเทิร์นสำคัญ ผู้เรียกเก็บไว้เรียกตอนเลิกใช้ (ดู `unsubscribe` ใน `app.js`) |
| 60–66 | `emitQueued` ธงกันแจ้งซ้ำ |
| 68–75 | `emit()` ถ้ามีการแจ้งรออยู่แล้วก็ไม่ทำซ้ำ มิฉะนั้น `queueMicrotask(...)` ขอให้เบราว์เซอร์รันฟังก์ชันนี้ "หลังโค้ดปัจจุบันจบ แต่ก่อนวาดหน้าจอ" ทำให้หลาย ๆ `emit()` ที่เกิดติดกัน (โหลด 7 ชุดพร้อมกัน) รวมเป็นการแจ้งครั้งเดียว หน้าจอวาดใหม่ครั้งเดียว ไม่ใช่ 7 ครั้ง |
| 77–80 | `patchState(partial)` รวมค่าเข้า `state` แล้ว `emit()` |

**ไฟล์ `webapp/assets/js/store.js` บรรทัด 97–114** (ตัวห่อการโหลด)

```js:97
async function load(key, task) {
  setLoading(key, true);
  emit();
  try {
    const result = await task();
    setError(key, null);
    return result;
  } catch (error) {
    if (error?.status !== 401 && error?.name !== 'AbortError') {
      setError(key, error);
      console.warn(`[store] โหลด ${key} ไม่สำเร็จ:`, error?.message ?? error);
    }
    return null;
  } finally {
    setLoading(key, false);
    emit();
  }
}
```

| บรรทัด | ความหมาย |
|---|---|
| 97 | `load(key, task)` รับชื่อชุดข้อมูล (`'rooms'`) กับฟังก์ชัน async ที่ดึงจริง (`() => api.rooms()`) |
| 98–99 | ตั้ง `state.loading[key] = true` แล้ว `emit()` ให้หน้าจอรู้ว่ากำลังโหลด |
| 101–102 | รอผล ถ้าสำเร็จล้างข้อความ error ของชุดนี้ |
| 104–109 | ถ้าล้มเหลว: **ไม่ทำอะไรกับ 401** (เพราะ `api.js` พากลับหน้าล็อกอินแล้ว ถ้าโชว์ error ซ้ำจะค้างป้ายแดงบนหน้าล็อกอิน) และไม่สนใจ `AbortError` นอกนั้นเก็บข้อความใน `state.errors[key]` และ `console.warn` แล้ว `return null` (**ไม่ throw**) เพื่อให้ `tick()` ที่วนหลายชุดไม่ล้มทั้งรอบเพราะชุดเดียวพัง |
| 110–113 | `finally` ทำเสมอ: ปิดธงโหลดและ `emit()` |

และ loader แต่ละตัวเป็นรูปแบบเดียวกัน เช่น

```js:141
  async rooms() {
    const result = await load('rooms', () => api.rooms());
    if (result) {
      state.rooms = result;
      emit();
    }
    return state.rooms;
  },
```

ได้ `null` (พัง) ก็**คงข้อมูลเดิมไว้** (`if (result)`) หน้าจอจึงไม่ว่างเปล่าเพียงเพราะเน็ตกระตุก

**ไฟล์ `webapp/assets/js/store.js` บรรทัด 254–313** (ตารางงาน polling แบ่งเป็น 3 ช่วง)

```js:254
const tasks = [
  { key: 'live', every: POLL.live, run: () => loaders.live() },
  { key: 'rooms', every: POLL.rooms, run: () => loaders.rooms() },
  {
    key: 'airConditioners',
    every: POLL.rooms,
    run: () => loaders.airConditioners(),
  },
  { key: 'alerts', every: POLL.alerts, run: () => loaders.alerts() },
  { key: 'summary', every: POLL.summary, run: () => loaders.summary() },
  { key: 'health', every: POLL.summary, run: () => loaders.health() },
];
```

```js:267
const lastRun = new Map();
let timer = null;
let running = false;

async function tick(force = false) {
  if (running) return;
  // แท็บที่ถูกซ่อนไว้ไม่ต้องถามเซิร์ฟเวอร์ ประหยัดทั้งแบตและโควตาเน็ต
  // แล้วค่อยดึงใหม่ทันทีตอนกลับมาดู (ดูตัวจัดการ visibilitychange ข้างล่าง)
  if (!force && document.hidden) return;

  running = true;
  const now = Date.now();
  try {
    for (const task of tasks) {
      const previous = lastRun.get(task.key) ?? 0;
      if (!force && now - previous < task.every) continue;
      lastRun.set(task.key, now);
      await task.run();
    }
  } finally {
    running = false;
  }
}
```

```js:291
/** เริ่มดึงข้อมูลเป็นรอบ เรียกหลังเข้าสู่ระบบสำเร็จ */
export function startPolling() {
  stopPolling();
  tick(true);
  timer = window.setInterval(() => tick(false), 5000);
}

export function stopPolling() {
  if (timer != null) {
    window.clearInterval(timer);
    timer = null;
  }
  lastRun.clear();
}

/** บังคับดึงใหม่ทั้งหมดเดี๋ยวนี้ ใช้กับปุ่มรีเฟรช */
export function refreshAll() {
  return tick(true);
}

document.addEventListener('visibilitychange', () => {
  if (!document.hidden && timer != null) tick(true);
});
```

| บรรทัด | ความหมาย |
|---|---|
| 254–265 | ตารางงาน: แต่ละงานมีชื่อ ช่วงเวลา (`every` ms จาก `POLL`) และฟังก์ชันที่รัน (`live`/`rooms`/`airConditioners` ทุก 10 วิ, `alerts` 30 วิ, `summary` และ `health` 120 วิ) |
| 267 | `lastRun` เก็บเวลาที่รันงานนั้นครั้งล่าสุด |
| 271–272 | `tick(force)`: ถ้ารอบก่อนยังไม่จบ (`running`) ข้าม กันคำขอซ้อนกันเมื่อเซิร์ฟเวอร์ช้า |
| 275 | `document.hidden` = แท็บถูกซ่อน/ย่อ ไม่ถามเซิร์ฟเวอร์ ประหยัดแบตและโควตาเน็ต |
| 280–285 | วนทุกงาน ข้ามงานที่ยังไม่ถึงเวลา (`now - previous < task.every`) ไม่งั้นบันทึกเวลาแล้ว `await task.run()` **ทีละงานตามลำดับ** (ไม่ขนาน) |
| 286–288 | `finally { running = false }` ปลดล็อกแม้มี error |
| 292–296 | `startPolling()`: ล้างของเก่า, `tick(true)` ดึงทุกอย่างทันที, แล้ว `setInterval(() => tick(false), 5000)` **นาฬิกาปลุกทุก 5 วินาที** ไม่ใช่ 10 วินาที ตัว `tick` เองตัดสินว่างานไหนถึงรอบ (ละเอียดกว่าและให้ช่วงต่าง ๆ ใช้ตัวจับเวลาตัวเดียว) |
| 298–304 | `stopPolling()` `clearInterval` และล้าง `lastRun` |
| 307–309 | `refreshAll()` บังคับดึงทุกอย่างทันที (ปุ่มรีเฟรช) |
| 311–313 | event `visibilitychange`: กลับมาดูแท็บ (`!document.hidden`) และกำลัง polling อยู่ (`timer != null`) → ดึงใหม่ทันที ผู้ใช้จึงไม่ต้องรอข้อมูลเก่าถึง 10 วินาทีหลังสลับกลับมา |

ค่า `POLL` มาจาก `config.js` (10000 / 10000 / 30000 / 120000 ms) ตรงกับ README เมื่อรวมกับการ **รอทีละงาน** ข้อมูลสดในทางปฏิบัติช้าได้ราว 10–15 วินาที

### 7) หนึ่งหน้าจอ: `alerts.js` ตั้งแต่ `mount` ถึง `update`

**ไฟล์ `webapp/assets/js/views/alerts.js` บรรทัด 21–45 และ 47–64**

```js:21
let status = 'open';
let roomFilter = '';

export default {
  title: 'การแจ้งเตือน',
  subtitle: 'รายการเหตุการณ์ที่ระบบตรวจพบและต้องการการติดตาม',

  async mount(root) {
    const tabs = el('div', { class: 'tabbar' });
    const filterRow = el('div', {
      class: 'row',
      style: { marginTop: '14px' },
    });
    const list = el('div', { class: 'card', style: { marginTop: '16px' } });

    replace(root, [tabs, filterRow, list]);

    async function reload() {
      await loaders.alerts({
        limit: 200,
        status: status || undefined,
        room: roomFilter || undefined,
      });
      update();
    }
```

```js:47
    function update() {
      replace(
        tabs,
        STATUS_TABS.map((tab) =>
          el('button', {
            class: `tab small${tab.key === status ? ' active' : ''}`,
            type: 'button',
            text:
              tab.key === ''
                ? tab.label
                : `${tab.label} (${state.alerts.counts?.[tab.key] ?? 0})`,
            onclick: () => {
              status = tab.key;
              reload();
            },
          }),
        ),
      );
```

| บรรทัด | ความหมาย |
|---|---|
| 21–22 | ตัวแปรระดับ**โมดูล** (`status`, `roomFilter`) จึงอยู่ข้ามการสลับหน้า: ผู้ใช้ไปหน้าอื่นแล้วกลับมา ตัวกรองยังเหมือนเดิม (ค่าเริ่มต้น `'open'` = ดูเฉพาะที่ค้าง) |
| 24–26 | `export default { title, subtitle, mount }` คือ "สัญญา" ของหน้าที่ `app.js` อ่าน |
| 28 | `async mount(root)`: `root` = `#viewRoot` ที่ `app.js` ล้างให้แล้ว |
| 29–34 | สร้างโครง 3 กล่องครั้งเดียว: แท็บ แถวตัวกรอง การ์ดรายการ |
| 36 | `replace(root, [tabs, filterRow, list])` ใส่ลงหน้า |
| 38–45 | `reload()` ดึงข้อมูลตามตัวกรองจาก Backend (`status: status \|\| undefined` ถ้าเป็นสตริงว่างให้เป็น `undefined` เพื่อไม่ส่งพารามิเตอร์ ซึ่ง `buildUrl` ใน `api.js` จะข้ามค่าว่าง) แล้ว `update()` |
| 47 | `update()` ล้างและวาดเนื้อหาใหม่จาก `state` เท่านั้น (ฟังก์ชัน "บริสุทธิ์" ของ state: state เดียวกัน ได้หน้าตาเดียวกัน) |
| 50–63 | สร้างปุ่มแท็บจาก `STATUS_TABS` ด้วย `.map()` ใส่จำนวนจาก `state.alerts.counts` ตอนกดตั้ง `status` แล้ว `reload()` (`?.` กับ `?? 0` กัน `counts` ยังว่างตอนโหลดครั้งแรก) |

ท้ายไฟล์ (บรรทัด 115–118) `update(); await reload(); return { update };` คือ: วาดทันทีจากข้อมูลที่มี → ดึงข้อมูลใหม่ → คืน `update` ให้ `app.js` เรียกทุกครั้งที่ state เปลี่ยน

หลักการเดียวกันซ้ำในทุกหน้า: **state เปลี่ยน → `update()` วาดใหม่จาก state** (เหมือน `build()` ของ Flutter ในบทแอป Flutter)

### 8) `charts.js`: วาดกราฟ SVG ด้วยมือ

กราฟเส้นพื้นที่ (`areaChart`) สร้าง `<svg viewBox="0 0 1000 H">` ใช้พิกัดภายใน 1000 หน่วยกว้างเสมอ แล้วให้เบราว์เซอร์ยืดตามความกว้างจริง (`width: '100%'`, `preserveAspectRatio: 'none'`)

**ไฟล์ `webapp/assets/js/charts.js` บรรทัด 53–72**

```js:53
  const width = 1000;
  const padTop = showLabels ? 26 : 8;
  const padBottom = 4;
  const values = points.map((point) => Number(point.value) || 0);
  const reference = scaleReference(values);
  // ถ้าผู้เรียกบอกหน่วยมาเอง (เช่น W หรือ บาท) ห้ามใช้กติกาแปลงหน่วยของ kWh
  // ไม่งั้น 1,200 W จะถูกเขียนเป็น 1.20 MWh ซึ่งผิดความหมายไปคนละเรื่อง
  const fixedUnit = unitOverride != null;
  const unit = fixedUnit ? unitOverride : energyUnit(reference);
  const labelOf = (value) =>
    fixedUnit
      ? decimal(value, value >= 100 ? 1 : 2)
      : energy(value, { scaleReference: reference, withUnit: false });
  // เพดานแกนตั้งเผื่อไว้ 15% เพื่อให้ป้ายค่าของจุดสูงสุดไม่ชนขอบบน
  const max = Math.max(...values) * 1.15 || 1;
  const innerHeight = height - padTop - padBottom;
  const step = points.length > 1 ? width / (points.length - 1) : 0;

  const x = (index) => (points.length > 1 ? index * step : width / 2);
  const y = (value) => padTop + innerHeight - (value / max) * innerHeight;
```

| บรรทัด | ความหมาย |
|---|---|
| 53 | กว้าง 1000 หน่วยคงที่ ไม่ใช่พิกเซลจริง |
| 54–55 | เว้นขอบบน 26 หน่วยถ้ามีป้ายตัวเลข (ไว้ใส่ป้าย) ไม่งั้น 8 |
| 56–57 | `values` = ค่าตัวเลขของทุกจุด (`Number(...) \|\| 0` กัน `NaN`) `reference` = ค่ามากสุดของชุด ใช้เลือกหน่วย |
| 60–65 | ถ้าผู้เรียกระบุหน่วยเอง (`unitOverride` เช่น W หรือ V) ห้ามใช้กติกาแปลง kWh มิฉะนั้น 1,200 W จะกลายเป็น "1.20 MWh" ผิดความหมาย |
| 67 | `max` = ค่าสูงสุด × 1.15 เผื่อที่ว่าง 15% ให้ป้ายจุดสูงสุดไม่ชนขอบบน (`\|\| 1` กันหารศูนย์ถ้าทุกค่าเป็น 0) |
| 69 | ระยะห่างแนวนอนระหว่างจุด = 1000 / (จำนวนจุด − 1) |
| 71 | `x(index)` พิกัดแนวนอนของจุดที่ index (จุดเดียววางกลาง) |
| 72 | `y(value)` พิกัดแนวตั้ง: **แกน y ของ SVG ชี้ลง** (0 อยู่บนสุด) จึงต้อง `padTop + innerHeight - สัดส่วน × innerHeight` ค่ามากยิ่งอยู่สูง (y น้อย) |

**ไฟล์ `webapp/assets/js/charts.js` บรรทัด 100–116**

```js:100
  const line = points.map((point, index) => `${x(index)},${y(values[index])}`);
  svg.appendChild(
    node('path', {
      d: `M${line.join(' L')} L${x(points.length - 1)},${height} L${x(0)},${height} Z`,
      fill: `url(#${gradientId})`,
    }),
  );
  const polyline = node('polyline', {
    points: line.join(' '),
    fill: 'none',
    'stroke-width': 2.4,
    'stroke-linecap': 'round',
    'stroke-linejoin': 'round',
    'vector-effect': 'non-scaling-stroke',
  });
  polyline.style.stroke = color;
  svg.appendChild(polyline);
```

| บรรทัด | ความหมาย |
|---|---|
| 100 | สร้างข้อความพิกัด `"x,y"` ของทุกจุด |
| 101–106 | `<path d="M x0,y0 L x1,y1 ... L xท้าย,H L x0,H Z">` เส้นทึบรูปปิด: `M` ย้ายปากกา `L` ลากเส้นไป ปิดด้วยเส้นลงมาที่ก้นกราฟ (`height`) แล้ว `Z` ปิดรูป ใช้ระบายสีไล่เฉด (`fill: url(#areaFill-xxxx)`) ใต้เส้น |
| 107–114 | `<polyline>` เส้นกราฟจริง `fill: 'none'` `stroke-linecap/linejoin: round` มุมมน และ **`vector-effect: 'non-scaling-stroke'`** ให้ความหนาเส้นคงที่ 2.4px แม้ SVG ถูกยืดกว้าง |
| 115 | `polyline.style.stroke = color` สีตั้งผ่าน `style` ไม่ใช่ attribute `stroke` เพราะ **attribute ของ SVG ไม่เข้าใจ `var(--accent)`** แต่ CSS property เข้าใจ กราฟจึงเปลี่ยนสีตามธีมได้ (ดู `gradient` ที่บรรทัด 91–94 ใช้ `stopColor` ผ่าน `style` เช่นกัน) |

ป้ายตัวเลขและกล่องค่าเป็น **HTML ทับบน SVG** ไม่ใช่ `<text>` ใน SVG เพราะ SVG ถูกยืดตามความกว้าง ตัวหนังสือข้างในจะเพี้ยนยืดไปด้วย

**ไฟล์ `webapp/assets/js/charts.js` บรรทัด 245–271** (เส้นตามเมาส์/นิ้ว)

```js:245
  const show = (clientX) => {
    const box = svgNode.getBoundingClientRect();
    if (box.width === 0) return;
    const ratio = Math.min(1, Math.max(0, (clientX - box.left) / box.width));
    const index =
      points.length > 1 ? Math.round(ratio * (points.length - 1)) : 0;
    const left = x(index) * box.width;
    const top = y(index) * height;
    const content = text(index);
    tip.firstChild.textContent = content.head;
    tip.lastChild.textContent = content.value;
    cursor.style.left = `${left}px`;
    dot.style.left = `${left}px`;
    dot.style.top = `${top}px`;
    // กันกล่องค่าล้นขอบซ้าย-ขวาของการ์ด
    const half = tip.offsetWidth / 2;
    tip.style.left = `${Math.min(box.width - half, Math.max(half, left))}px`;
    tip.style.top = `${Math.max(top, 30)}px`;
    wrapper.classList.add('hovering');
  };
  const hide = () => wrapper.classList.remove('hovering');

  svgNode.addEventListener('pointermove', (event) => show(event.clientX));
  svgNode.addEventListener('pointerdown', (event) => show(event.clientX));
  svgNode.addEventListener('pointerleave', hide);
  svgNode.addEventListener('pointercancel', hide);
}
```

| บรรทัด | ความหมาย |
|---|---|
| 246–248 | `getBoundingClientRect()` ขนาดและตำแหน่ง SVG จริงบนจอ แล้วแปลงตำแหน่งเมาส์ `clientX` เป็นสัดส่วน 0–1 (`Math.min/max` ตรึงไว้ในช่วง) |
| 249–250 | **จุดที่ใกล้ที่สุดเลือกจากตำแหน่งแนวนอนอย่างเดียว** `Math.round(ratio × (n−1))` ผู้ใช้ไม่ต้องเล็งจุดเล็ก ๆ ให้โดน (บนมือถือแทบทำไม่ได้) |
| 251–258 | วางเส้นตั้ง จุด และกล่องค่าที่ตำแหน่งนั้น ข้อความใส่ด้วย `textContent` |
| 260–262 | กันกล่องค่าล้นขอบซ้าย-ขวา โดย clamp ตำแหน่งด้วยครึ่งความกว้างของกล่อง |
| 267–270 | ใช้ **Pointer Events** (`pointermove/down/leave/cancel`) ที่ครอบคลุมเมาส์ นิ้ว และปากกาในชุดเดียว ไม่ต้องเขียน `mouse*` กับ `touch*` แยก |

ส่วนสีของช่อง Building Pulse อยู่ที่ `heatColor` (บรรทัด 317–322)

```js:317
export function heatColor(value, max) {
  const amount = max > 0 ? Math.sqrt(Math.max(0, value) / max) : 0;
  // ผสมสีด้วย color-mix ให้เปลี่ยนตามธีมเอง (--heat ของธีมมืดกับสว่างคนละค่า)
  const percent = Math.round(amount * 100);
  return `color-mix(in srgb, var(--heat) ${percent}%, var(--panel-raised))`;
}
```

`Math.sqrt(value / max)` ใช้ "รากที่สอง" เพื่อให้ห้องที่ใช้น้อยแต่ไม่ใช่ศูนย์ยังต่างจากศูนย์ที่ตามองเห็น (ถ้าไล่เส้นตรง เมื่อห้องหนึ่งใช้ 90 kWh ห้อง 0 กับ 5 kWh จะดำเหมือนกัน) `color-mix(in srgb, var(--heat) 40%, var(--panel-raised))` ผสมสีสองสีใน CSS เอง จึงเปลี่ยนตามธีมโดยไม่ต้องคำนวณสีใน JS

### 9) `tokens.css`: ตัวแปรและธีม

**ไฟล์ `webapp/assets/css/tokens.css` บรรทัด 44–53**

```css:44
  --text-scale: 1;
  --fs-2xs: calc(12px * var(--text-scale));
  --fs-xs: calc(12.5px * var(--text-scale));
  --fs-sm: calc(13.5px * var(--text-scale));
  --fs-base: calc(14.5px * var(--text-scale));
  --fs-md: calc(15.5px * var(--text-scale));
  --fs-lg: calc(17px * var(--text-scale));
  --fs-xl: calc(20px * var(--text-scale));
  --fs-2xl: calc(24px * var(--text-scale));
  --lh-thai: 1.6;
```

| บรรทัด | ความหมาย |
|---|---|
| 44 | `--text-scale: 1` ตัวคูณขนาดตัวอักษร ผู้ใช้ปรับผ่าน `data-text` |
| 45–52 | `--fs-*` แต่ละขนาดเป็น `calc(Npx * var(--text-scale))` เมื่อ `--text-scale` เปลี่ยนเป็น 1.1 ขนาดทุกขนาดขยายตามเอง |
| 53 | `--lh-thai: 1.6` ความสูงบรรทัดสำหรับภาษาไทย |

**ไฟล์ `webapp/assets/css/tokens.css` บรรทัด 62–76 และ 114–125**

```css:62
:root,
[data-palette='gray'] {
  color-scheme: dark;

  --bg: #2a2f33;
  --panel: #33393e;
  --panel-raised: #3d4449;
  --panel-sunken: #2e3337;
  --hairline: #4a5257;
  --hairline-soft: #40474c;
  --accent: #6edb9f;
  --accent-strong: #2eb872;
  --accent-dim: #3e8f66;
  --accent-soft: rgba(110, 219, 159, 0.14);
  --on-accent: #0b1a12;
```

```css:114
/* ---------- ธีมขาว ---------- */
[data-palette='white'] {
  color-scheme: light;

  --bg: #f3f5f6;
  --panel: #ffffff;
  --panel-raised: #eceff1;
  --panel-sunken: #f7f8f9;
  --hairline: #d8dde0;
  --hairline-soft: #e6eaec;
  --accent: #0f7d45;
  --accent-strong: #0f7d45;
```

| บรรทัด | ความหมาย |
|---|---|
| 62–63 | ตัวเลือกคู่ `:root, [data-palette='gray']` : ธีมเทาเป็น**ค่าเริ่มต้น**ของ `<html>` (`:root`) และใช้กับอิลิเมนต์ใดก็ตามที่มี `data-palette="gray"` ได้ด้วย |
| 64 | `color-scheme: dark` บอกเบราว์เซอร์ให้วาด scrollbar, ช่องกรอก, checkbox ที่เป็นของเบราว์เซอร์เองเป็นโทนมืด |
| 66–71 | พื้น (`--bg`), การ์ด (`--panel`), การ์ดยกระดับ (`--panel-raised`), เส้นขอบ (`--hairline`) |
| 72–75 | สีเน้น (`--accent`) และเฉดอื่น `--accent-soft` เป็น `rgba(...)` โปร่งใสไว้ทำพื้นป้าย |
| 115–116 | ธีมขาว: `[data-palette='white']` มีความเจาะจงเท่ากับ `[data-palette='gray']` แต่มา**ทีหลัง** จึงชนะตัวแปรชื่อเดียวกันเมื่อ `<html data-palette="white">` (ส่วน `:root` ที่เจาะจงน้อยกว่าก็แพ้) |
| 124–125 | สีเน้นของธีมสว่างเป็นเขียวเข้ม `#0f7d45` เพื่อให้ตัวหนังสือสีเน้นบนพื้นขาวผ่านคอนทราสต์ 4.5:1 |

**ไฟล์ `webapp/assets/css/tokens.css` บรรทัด 261–268**

```css:261
/* ---------- ขนาดตัวอักษรที่ผู้ใช้เลือก ---------- */
:root[data-text='large'] {
  --text-scale: 1.1;
}

:root[data-text='xlarge'] {
  --text-scale: 1.22;
}
```

`:root[data-text='large']` เจาะจงกว่า `:root` เฉย ๆ จึงทับ `--text-scale: 1` ได้ ผู้ใช้กด "ใหญ่" → `prefs.js` ตั้ง `<html data-text="large">` → ทุกอย่างที่ใช้ `--fs-*` ขยาย 10% โดย JavaScript ไม่แตะ element ใดเลย

นี่คือเหตุผลที่ธีมและขนาดตัวอักษรเปลี่ยนได้ทันทีทั้งเว็บ: ฝั่ง JS เปลี่ยนแค่ "แอตทริบิวต์เดียว" ที่ `<html>` แล้ว CSS cascade จัดการที่เหลือ

### 10) `views/firmware.js`: หน้าเฟิร์มแวร์ (เพิ่ม 14 ต.ค. 2569)

หน้านี้เป็นหน้าเดียวในเว็บที่ "สั่งงานแล้วต้องรอผลหลายนาที" (บอร์ดดาวน์โหลดไฟล์ รีบูต แล้วรายงานรุ่นใหม่) จึงมีสถานะของตัวเองมากกว่าหน้าอื่น อ่านตามลำดับนี้: สถานะระดับโมดูล → อ่านชื่อไฟล์ → ตัดสินสถานะบอร์ด → ติดตามผล → วาดหน้า → อัปโหลด → สั่งอัปเดต

**10.1 สถานะระดับโมดูล** — ไฟล์ `webapp/assets/js/views/firmware.js` บรรทัด 44–57

```js:44
// หลังสั่งอัปเดต รอบอร์ดรายงานรุ่นใหม่ได้นานเท่านี้ เกินแล้วถือว่าไม่สำเร็จ
// (บอร์ดใช้ประมาณ 1–2 นาที เผื่อ Wi-Fi ช้าและบอร์ดต่อ MQTT ใหม่)
const PENDING_MS = 5 * 60 * 1000;

let activeKind = null;
const selected = { air: new Set(), wired: new Set(), occupancy: new Set() };
// deviceId -> { target, startedAt } บอร์ดที่สั่งไปแล้ว รอรายงานรุ่นใหม่
const pending = new Map();

let files = null;
let filesError = '';
let configured = true;
let maxBytes = 0x1f0000;
let uploading = false;
```

| บรรทัด | อธิบาย |
|---|---|
| 46 | `PENDING_MS` = 5 นาที (`5 * 60 * 1000` มิลลิวินาที) เวลารอสูงสุดหลังสั่ง ปกติบอร์ดใช้ 1–2 นาที เผื่อ Wi-Fi ช้าและเวลาต่อ MQTT ใหม่ |
| 48 | `activeKind` แท็บที่เลือก เริ่มเป็น `null` เพื่อให้ `render` เลือกแท็บเริ่มต้นเองจากข้อมูล |
| 49 | `selected` แยก `Set` ต่อแท็บ บอร์ดที่ติ๊กไว้ในแท็บหนึ่งไม่ปนไปอีกแท็บ (`Set` = กลุ่มค่าไม่ซ้ำ `add/delete/has` เร็ว) |
| 51 | `pending` เป็น `Map` จาก `deviceId` → งานที่รอ `{ target, startedAt, previousError }` |
| 53–57 | ผลจาก `api.firmwareFiles()`: `files` (`null` = ยังไม่โหลด), `filesError`, `configured` (เซิร์ฟเวอร์ตั้ง `FIRMWARE_DIR` หรือยัง), `maxBytes` เริ่มที่ `0x1f0000` (2,031,616 ไบต์ ≈ 1.94 MB ขนาดช่องโปรแกรม OTA ของบอร์ด) และ `uploading` ใช้ปิดช่องอัปโหลดระหว่างส่ง |

> [!WHY]
> ตัวแปรเหล่านี้อยู่ "นอก" `mount` เพราะโมดูล ES โหลดครั้งเดียว ค่าจึงอยู่รอดข้ามการสลับหน้า ถ้าแอดมินสั่งอัปเดต 5 บอร์ดแล้วไปดูหน้าอื่น กลับมา `pending` ยังอยู่ ป้าย "กำลังอัปเดต" ยังเดินต่อ (แนวเดียวกับตัวกรอง `view` ใน `rooms.js`) ข้อแลกคือถ้ากด F5 ทั้งหน้า `pending` หาย หน้าจะกลับไปตัดสินจาก `firmwareVersion` ของบอร์ดตามปกติ ซึ่งยังถูกต้อง แค่ไม่มี toast บอกผล

**10.2 อ่านชนิดและรุ่นจากชื่อไฟล์** — ไฟล์ `webapp/assets/js/views/firmware.js` บรรทัด 93–122

```js:93
/** ชนิดไฟล์จากชื่อ ต้องตรงกับ firmwareKindOf ใน backend/src/utils/firmware.js */
function kindOfFileName(name) {
  if (/occ/i.test(name)) return 'occupancy';
  if (/wired|slm8/i.test(name)) return 'wired';
  return 'air';
}

function versionOfFileName(name) {
  const match = String(name ?? '').match(
    /-(\d+\.\d+(?:\.\d+)?(?:-[A-Za-z0-9]+)*)\.bin$/,
  );
  return match ? match[1] : null;
}

/** เทียบเลขรุ่นข้างหน้า (2.5.10 > 2.5.9) ส่วนท้ายอย่าง -slm8 ไม่นับ */
function compareVersions(a, b) {
  const parts = (value) => {
    const match = String(value ?? '').match(/^(\d+)\.(\d+)(?:\.(\d+))?/);
    return match ? [match[1], match[2], match[3] ?? '0'].map(Number) : null;
  };
  const left = parts(a);
  const right = parts(b);
  if (!left && !right) return 0;
  if (!left) return -1;
  if (!right) return 1;
  for (let index = 0; index < 3; index += 1) {
    if (left[index] !== right[index]) return left[index] - right[index];
  }
  return 0;
}
```

| บรรทัด | อธิบาย |
|---|---|
| 95 | `/occ/i.test(name)` regex หา `occ` ที่ไหนก็ได้ในชื่อ (`i` = ไม่สนตัวพิมพ์เล็กใหญ่) เช็กก่อนเพราะเป็นเงื่อนไขที่ชัดที่สุด |
| 96 | `wired` หรือ `slm8` (ชื่อโปรโตคอลสายแอร์ Daikin) = บอร์ดสายแอร์ |
| 97 | นอกนั้นถือเป็นแอร์ IR (ชื่อไฟล์ `rmutt_esp32_air-…` เดิม ไม่ต้องเปลี่ยน) |
| 101–103 | regex จับ "ขีด + ตัวเลข.ตัวเลข(.ตัวเลข) + ส่วนท้ายแบบ `-slm8` ได้หลายท่อน" ที่อยู่ก่อน `.bin` ตรงท้ายชื่อ (`$`) `match[1]` คือส่วนในวงเล็บแรก |
| 104 | ไม่ตรงรูปแบบคืน `null` (เช่น `rmutt_esp32_air.ino.bin` ที่ Arduino IDE ตั้งให้) |
| 109–112 | `parts` ดึงเลข 3 ส่วนหน้าเป็นตัวเลขจริง ส่วนที่สามไม่มีถือเป็น `'0'` (`2.5` = `2.5.0`) |
| 115–117 | อ่านไม่ได้ทั้งคู่ = เท่ากัน, อ่านไม่ได้ฝั่งเดียว = ฝั่งนั้นเก่ากว่า |
| 118–120 | เทียบทีละหลักแบบตัวเลข คืนค่าลบ/0/บวก แบบ comparator ที่ `Array.sort` ใช้ |

> [!WHY]
> ทำไมไม่เทียบรุ่นเป็นข้อความตรง ๆ? เพราะ `'2.5.10' < '2.5.9'` เมื่อเทียบเป็นข้อความ (`'1'` มาก่อน `'9'`) ทำให้รุ่นใหม่ดูเหมือนเก่า จึงต้องแยกเป็นตัวเลขก่อน และตัดส่วนท้ายอย่าง `-slm8` ทิ้งเพราะเป็นป้ายบอกชนิด ไม่ใช่ลำดับรุ่น ส่วนการใช้ "ชื่อไฟล์" เป็นแหล่งข้อมูลชนิด/รุ่น (แทนการอ่านจากในไฟล์ `.bin`) ทำให้คนดูโฟลเดอร์บนเซิร์ฟเวอร์ก็รู้ทันที และ Backend ใช้กติกาเดียวกันได้โดยไม่ต้องแกะไบนารี คอมเมนต์บรรทัด 93 ย้ำว่าต้องตรงกับ `firmwareKindOf` ใน `backend/src/utils/firmware.js`

**10.3 ตัดสินสถานะบอร์ด** — ไฟล์ `webapp/assets/js/views/firmware.js` บรรทัด 155–170

```js:155
function statusOf(device, latest) {
  const job = pending.get(device.deviceId);
  if (job) return { code: 'updating', target: job.target, startedAt: job.startedAt };
  if (device.provisionStatus && device.provisionStatus !== 'active') {
    return { code: 'notready' };
  }
  if (!device.isOnline) return { code: 'offline' };
  if (!latest) return { code: 'nofile' };
  if (
    device.firmwareVersion &&
    compareVersions(device.firmwareVersion, latest.version) >= 0
  ) {
    return { code: 'uptodate' };
  }
  return { code: 'outdated' };
}
```

| บรรทัด | อธิบาย |
|---|---|
| 156–157 | มีงานรอใน `pending` → `updating` เช็กก่อนอย่างอื่น เพราะระหว่างรีบูตบอร์ดจะออฟไลน์ชั่วคราว ถ้าเช็กออฟไลน์ก่อน ป้ายจะกระโดดเป็น "ออฟไลน์" ทำให้คนตกใจ |
| 158–160 | `provisionStatus` ไม่ใช่ `active` (ยังตั้งค่าผ่าน Bluetooth/MQTT ไม่เสร็จ) → `notready` สั่ง OTA ไม่ได้ (Backend ก็ตอบ 409) |
| 161 | ออฟไลน์ → สั่งไม่ได้ (Backend ตอบ 409 "บอร์ดออฟไลน์อยู่") |
| 162 | ยังไม่มีไฟล์ของชนิดนี้ → `nofile` |
| 163–168 | บอร์ดรายงานรุ่นแล้ว และรุ่น ≥ ไฟล์ล่าสุด → `uptodate` |
| 169 | ที่เหลือ = `outdated` รวมถึงบอร์ดที่ไม่รายงานรุ่น (`firmwareVersion` เป็น `null` เช่นเฟิร์มแวร์รุ่นเก่ามาก) ซึ่งควรอัปเดตอยู่แล้ว |

มีแค่ `outdated` ที่ติ๊กเลือกและกดปุ่ม "อัปเดต" ได้ (`deviceRow` บรรทัด 449 `canUpdate = status.code === 'outdated'`) ดังนั้นปุ่มจะไม่โผล่ให้บอร์ดที่ออฟไลน์หรือกำลังอัปเดตอยู่

> [!TIP]
> ลำดับของ `if` ในฟังก์ชันนี้คือ "ลำดับความสำคัญ" ของสถานะ ถ้าอาจารย์ถามว่าบอร์ดที่ออฟไลน์และรุ่นเก่าแสดงอะไร ตอบได้จากลำดับ: เช็ก `offline` (บรรทัด 161) ก่อน `outdated` จึงขึ้น "ออฟไลน์ · เห็นล่าสุด …" และกดอัปเดตไม่ได้

**10.4 ติดตามผลหลังสั่ง** — ไฟล์ `webapp/assets/js/views/firmware.js` บรรทัด 176–194

```js:176
function settlePending() {
  if (pending.size === 0) return;
  const devices = [...(state.airConditioners ?? []), ...(state.occupancySensors ?? [])];
  for (const [deviceId, job] of pending) {
    const device = devices.find((item) => item.deviceId === deviceId);
    if (!device) {
      pending.delete(deviceId);
    } else if (device.firmwareVersion && device.firmwareVersion === job.target) {
      pending.delete(deviceId);
      toastOk(`${deviceId} เป็นรุ่น ${job.target} แล้ว`);
    } else if (device.otaError && device.otaError !== job.previousError) {
      pending.delete(deviceId);
      toastError(`${deviceId} อัปเดตไม่สำเร็จ: ${device.otaError}`);
    } else if (Date.now() - job.startedAt >= PENDING_MS) {
      pending.delete(deviceId);
      toastError(`${deviceId} ยังไม่รายงานรุ่น ${job.target} ภายใน 5 นาที`);
    }
  }
}
```

| บรรทัด | อธิบาย |
|---|---|
| 177 | ไม่มีงานรอก็จบเลย (ฟังก์ชันนี้ถูกเรียกทุกครั้งที่วาด จึงต้องเบา) |
| 178 | รวมแอร์กับเซ็นเซอร์เป็นอาร์เรย์เดียวด้วย spread `...` เพราะ `pending` เก็บรวมทุกชนิด |
| 179 | `for (const [deviceId, job] of pending)` วนคู่ key/value ของ `Map` (การลบ key ระหว่างวน `Map` ทำได้ ไม่ข้ามตัว) |
| 181–182 | บอร์ดหายจากรายการ (ถูกถอดระหว่างรอ) → ทิ้งงาน |
| 183–185 | รุ่นที่บอร์ดรายงาน **เท่ากับ** รุ่นเป้าหมาย → สำเร็จ toast สีเขียว |
| 186–188 | มี `otaError` และไม่ใช่ข้อความเดิมก่อนสั่ง → บอร์ดรายงานว่าล้มเหลว แสดงข้อความจากบอร์ด |
| 189–191 | ครบ 5 นาทียังไม่มีอะไร → ถือว่าไม่สำเร็จ |

> [!WHY]
> ทำไมไม่รอผลจาก `await api.otaAirConditioner(...)` ตรง ๆ? เพราะ Backend ตอบทันทีที่ส่งคำสั่งเข้า MQTT สำเร็จ ส่วนการดาวน์โหลดและรีบูตเกิดในบอร์ดหลังจากนั้น ความจริงเรื่องผลมีที่เดียวคือข้อมูลที่บอร์ดรายงานกลับ (`firmwareVersion`, `otaError`) ซึ่งมากับ polling อยู่แล้ว หน้านี้จึงไม่ต้องตั้ง `setInterval` ของตัวเอง แค่เรียก `settlePending()` ใน `render` ที่ถูกเรียกทุกครั้งที่ store เปลี่ยน การเก็บ `previousError` (บรรทัด 591) ไว้เทียบกันการตัดสินผิดจากข้อความ error ของรอบก่อนที่ยังค้างในฐานข้อมูล

> [!WARN]
> ข้อสังเกตจากโค้ด: ความถี่ในการตรวจขึ้นกับ polling ของ `store.js` ซึ่งดึง `airConditioners` ทุก 10 วินาที แต่ **ไม่มี `occupancySensors` อยู่ในรายการ polling** (`tasks` ใน `store.js` มีแค่ live, rooms, airConditioners, alerts, summary, health; เซ็นเซอร์โหลดแค่ตอน `bootstrap` และหลังการกระทำในหน้า `devices.js`) และ `firmware.js` ก็ไม่ได้เรียก `loaders.occupancySensors()` เอง ผลคือแท็บเซ็นเซอร์ LD2410 อาจไม่เห็นรุ่นใหม่จนครบ 5 นาทีแล้วขึ้น "ยังไม่รายงานรุ่น … ภายใน 5 นาที" ทั้งที่บอร์ดอัปเดตสำเร็จ (กด F5 แล้วจะเห็นรุ่นจริง) อีกข้อคือเงื่อนไขสำเร็จเทียบข้อความ **ตรงตัว** (`===`) ถ้าชื่อไฟล์บอกรุ่น `2.5.2` แต่ `FIRMWARE_VERSION` ในโค้ดบอร์ดเป็น `2.5.2-slm8` จะไม่ขึ้น toast สำเร็จ (แต่ตารางยังแสดง "ล่าสุดแล้ว" เพราะ `statusOf` เทียบด้วย `compareVersions`) จึงควรตั้งรุ่นในชื่อไฟล์ให้ตรงกับ `FIRMWARE_VERSION` ทุกตัวอักษร

**10.5 เลือกแท็บเริ่มต้นอย่างฉลาด** — ไฟล์ `webapp/assets/js/views/firmware.js` บรรทัด 205–215

```js:205
function render(ctx) {
  const { head, tabBar, panel } = ctx;
  settlePending();

  if (!activeKind && files) {
    activeKind =
      KINDS.find((kind) => outdatedCount(kind.key) > 0)?.key ??
      KINDS.find((kind) => devicesOf(kind.key).length > 0)?.key ??
      'air';
  }
  const kind = activeKind ?? 'air';
```

| บรรทัด | อธิบาย |
|---|---|
| 207 | ปิดงานที่รอก่อนวาด สถานะในตารางจึงเป็นปัจจุบันเสมอ |
| 209 | เลือกแท็บเองแค่ครั้งแรก (`activeKind` ยังว่าง) และต้องโหลดไฟล์แล้ว (ไม่งั้นนับบอร์ดเก่าไม่ได้) |
| 211 | ตัวเลือกแรก: แท็บแรกที่มีบอร์ด "ต้องอัปเดต" (`?.key` = ถ้า `find` ไม่เจอได้ `undefined` แทนที่จะ error) |
| 212 | ถ้าไม่มี: แท็บแรกที่มีบอร์ดเลย |
| 213 | ถ้าไม่มีอะไรเลย: แท็บแอร์ IR (`??` = ใช้ค่าขวาเมื่อซ้ายเป็น `null`/`undefined`) |
| 215 | ระหว่างที่ไฟล์ยังไม่มา วาดแท็บแอร์ IR ไปก่อน |

`render` ที่เหลือ (บรรทัด 217–265) วาดใหม่ทั้ง 3 ส่วนด้วย `replace()` ทุกครั้ง ต่างจากหน้าอื่นที่แยก mount/update อย่างระมัดระวัง ทำได้เพราะหน้านี้ไม่มีช่องพิมพ์ข้อความค้างอยู่ (รุ่นของไฟล์ถามผ่าน `openForm` ซึ่งเป็น modal แยก ไม่ถูกลบตอนวาดใหม่) สิ่งที่ผู้ใช้เลือกไว้เก็บใน `selected`/`activeKind` นอก DOM จึงไม่หายตอนวาดใหม่ ป้ายเวลา "กำลังอัปเดตเป็น … · m:ss" ใน `statusBadge` (บรรทัด 500–505) ก็เดินตามรอบการวาดนี้ จึงขยับทีละประมาณ 5–10 วินาที ไม่ใช่ทุกวินาที

**10.6 ช่องลากไฟล์** — ไฟล์ `webapp/assets/js/views/firmware.js` บรรทัด 348–369

```js:348
  const stop = (event) => {
    event.preventDefault();
    event.stopPropagation();
  };
  zone.addEventListener('dragenter', (event) => {
    stop(event);
    zone.classList.add('dragging');
  });
  zone.addEventListener('dragover', (event) => {
    stop(event);
    zone.classList.add('dragging');
  });
  zone.addEventListener('dragleave', (event) => {
    stop(event);
    if (!zone.contains(event.relatedTarget)) zone.classList.remove('dragging');
  });
  zone.addEventListener('drop', (event) => {
    stop(event);
    zone.classList.remove('dragging');
    const file = event.dataTransfer?.files?.[0];
    if (file && !uploading) handleFile(file, meta, ctx);
  });
```

| บรรทัด | อธิบาย |
|---|---|
| 348–351 | `preventDefault()` ยกเลิกพฤติกรรมเดิมของเบราว์เซอร์ที่ **เปิดไฟล์ที่ลากมาวางแทนหน้าเว็บ** และ `stopPropagation()` ไม่ให้ event ไหลต่อไปยัง element ข้างนอก |
| 352–359 | ลากเข้ามา/ลากอยู่เหนือกรอบ → ใส่ class `dragging` ให้กรอบเปลี่ยนสี (ต้องยกเลิก `dragover` ด้วย ไม่งั้นเบราว์เซอร์ไม่ยอมให้ `drop`) |
| 360–363 | ลากออก: เอาสีออกเฉพาะเมื่อเมาส์ออกนอกกรอบจริง (`relatedTarget` คือ element ที่เมาส์ไปถึง ถ้ายังอยู่ใน `zone` แปลว่าแค่ผ่านลูก เช่นไอคอน ไม่ต้องเอาสีออก กันกรอบกะพริบ) |
| 367 | `event.dataTransfer?.files?.[0]` ไฟล์แรกที่ลากมา (`?.[0]` = ถ้าไม่มีรายการไฟล์ก็ได้ `undefined`) |
| 368 | ไม่รับไฟล์ใหม่ระหว่างกำลังอัปโหลด |

กรอบทั้งหมดเป็น `<label>` ที่ห่อ `<input type="file" accept=".bin" class="sr-only">` (บรรทัด 321–333) การคลิกที่ไหนก็ได้ใน label จึงเปิดหน้าต่างเลือกไฟล์โดยไม่ต้องเขียน JS และ `sr-only` ซ่อนช่องจากสายตาแต่โปรแกรมอ่านหน้าจอยังเห็น บรรทัด 328 `event.target.value = ''` ล้างค่าหลังอ่าน เพื่อให้เลือก **ไฟล์เดิมซ้ำ** แล้วยังยิง `change` อีกครั้ง (เช่นอัปโหลดไม่ผ่านแล้วแก้ชื่อรุ่นใหม่)

**10.7 ตรวจไฟล์ก่อนส่ง** — ไฟล์ `webapp/assets/js/views/firmware.js` บรรทัด 606–618 และ 620–647

```js:606
async function handleFile(file, meta, ctx) {
  if (!/\.bin$/i.test(file.name)) {
    toastError('เลือกไฟล์ .bin ที่ได้จาก Sketch → Export Compiled Binary');
    return;
  }
  if (file.size > maxBytes) {
    toastError(`ไฟล์ใหญ่เกินช่องโปรแกรมของบอร์ด (สูงสุด ${formatSize(maxBytes)})`);
    return;
  }
  if (/\.(merged|bootloader|partitions)\.bin$/i.test(file.name)) {
    toastError('ใช้ไฟล์ .ino.bin เท่านั้น ไม่ใช่ .merged.bin หรือ .bootloader.bin');
    return;
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 607 | ต้องลงท้าย `.bin` (`i` = `.BIN` ก็ได้) |
| 611 | ใหญ่กว่า `maxBytes` (ค่าจากเซิร์ฟเวอร์ ไม่ได้เขียนตายในหน้า) → ปฏิเสธก่อนเสียเวลาส่ง |
| 615 | Arduino IDE "Export Compiled Binary" สร้างหลายไฟล์ เฉพาะ `.ino.bin` ที่ใช้ OTA ได้ ไฟล์ `.merged.bin` มี bootloader อยู่ข้างหน้า ถ้าส่งไปบอร์ดจะเขียนผิดตำแหน่ง |

ไฟล์ `webapp/assets/js/views/firmware.js` บรรทัด 620–647 (ถามรุ่นเมื่อชื่อไฟล์ไม่มีรุ่น)

```js:620
  // ชื่อไฟล์บนเซิร์ฟเวอร์ต้องมีชื่อสเก็ตช์และรุ่น
  // Arduino IDE ตั้งชื่อเป็น <สเก็ตช์>.ino.bin จึงถามรุ่นเพิ่ม
  let fileName = file.name.replace(/\s+/g, '_');
  if (!versionOfFileName(fileName)) {
    const base = fileName.replace(/(\.ino)?\.bin$/i, '');
    const values = await openForm({
      title: 'ระบุรุ่นของไฟล์นี้',
      subtitle:
        `${file.name} ยังไม่มีเลขรุ่นในชื่อ ` +
        'ดูเลขรุ่นได้จาก FIRMWARE_VERSION ในโค้ด หรือบรรทัด "Firmware:" ใน Serial Monitor',
      submitLabel: 'อัปโหลด',
      fields: [
        {
          name: 'version',
          label: 'รุ่น',
          placeholder: meta.key === 'wired' ? 'เช่น 2.5.2-slm8' : 'เช่น 2.5.1',
          required: true,
        },
      ],
    });
    if (!values) return;
    const version = values.version.replace(/^v/i, '');
    if (!/^\d+\.\d+(\.\d+)?(-[A-Za-z0-9]+)*$/.test(version)) {
      toastError('รุ่นต้องเป็นตัวเลขแบบ 2.5.1 หรือ 2.5.2-slm8');
      return;
    }
    fileName = `${base}-${version}.bin`;
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 622 | แทนช่องว่างในชื่อด้วย `_` (ชื่อไฟล์บนเซิร์ฟเวอร์และใน URL ที่บอร์ดดาวน์โหลดไม่ควรมีช่องว่าง) |
| 623 | ชื่อยังไม่มีรุ่น (กรณีปกติของไฟล์จาก Arduino IDE: `<สเก็ตช์>.ino.bin`) → ต้องถามรุ่น |
| 624 | ตัด `.ino.bin` หรือ `.bin` ท้ายชื่อออกเหลือชื่อสเก็ตช์ |
| 625–639 | `await openForm(...)` เปิดฟอร์มหนึ่งช่องแล้วรอ (Promise-based dialog) ตัวอย่างในช่องเปลี่ยนตามแท็บ: สายแอร์ `2.5.2-slm8` อื่น ๆ `2.5.1` และบอกว่าหาเลขรุ่นได้จาก `FIRMWARE_VERSION` หรือบรรทัด "Firmware:" ใน Serial Monitor |
| 640 | กดยกเลิก (`null`) → หยุด |
| 641 | ตัด `v` นำหน้าออก (`v2.5.1` → `2.5.1`) |
| 642–645 | ตรวจรูปแบบรุ่นด้วย regex เดียวกับที่ `versionOfFileName` อ่านได้ ไม่งั้นตั้งชื่อแล้วอ่านรุ่นกลับไม่ได้ |
| 646 | ประกอบชื่อใหม่ `<สเก็ตช์>-<รุ่น>.bin` เช่น `rmutt_esp32_air_wired-2.5.2-slm8.bin` |

ต่อจากนี้ (บรรทัด 649–657) ตรวจว่าชนิดที่อ่านจากชื่อตรงกับแท็บ ถ้าไม่ตรงบอกให้ไปแท็บที่ถูก แล้ว (บรรทัด 659–667) ตั้ง `uploading = true` วาดใหม่ (ช่องอัปโหลดขึ้น "กำลังอัปโหลด…" และกดไม่ได้) อัปโหลด โหลดรายการไฟล์ใหม่ และคืนค่า `uploading` ใน `finally` ซึ่งทำงานเสมอแม้เกิด error

> [!WHY]
> ทำไมให้เบราว์เซอร์เติมรุ่นเข้าไปในชื่อไฟล์ แทนที่จะให้ผู้ใช้เปลี่ยนชื่อไฟล์เอง? เพราะทั้งระบบ (ตาราง "ต้องอัปเดต" และการติดตามผล) อาศัยรุ่นในชื่อไฟล์ ถ้าปล่อยให้อัปโหลด `rmutt_esp32_air.ino.bin` ตรง ๆ จะเทียบรุ่นไม่ได้ และอัปโหลดรุ่นถัดไปก็ชนชื่อเดิม การถามรุ่นตอนอัปโหลดจึงบังคับให้ทุกไฟล์บนเซิร์ฟเวอร์มีรุ่นเสมอ

**10.8 อัปโหลดเป็นไฟล์ดิบ และเขียนทับเมื่อชื่อซ้ำ** — ไฟล์ `webapp/assets/js/api.js` บรรทัด 233–243

```js:233
  uploadFirmware: (file, fileName, kind, replace = false) =>
    request('POST', '/firmware', {
      upload: file,
      query: { kind, replace: replace ? '1' : null },
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-File-Name': encodeURIComponent(fileName),
      },
    }).then((r) => r.file),
  deleteFirmware: (fileName) =>
    remove(`/firmware/${encodeURIComponent(fileName)}`),
```

| บรรทัด | อธิบาย |
|---|---|
| 235 | `upload: file` ส่งออบเจ็กต์ `File` ของเบราว์เซอร์เป็น body ตรง ๆ (`request()` ใช้ `upload ?? JSON.stringify(body)`) `fetch` อ่านไฟล์และส่งไบต์เองโดยไม่ต้องโหลดทั้งไฟล์เข้า JS |
| 236 | query `kind` บอกแท็บที่อัปโหลด, `replace` เป็น `'1'` หรือ `null` (`buildUrl` ข้ามค่า `null` จึงไม่มี `?replace=` เลยในการส่งปกติ) |
| 238 | `application/octet-stream` = "ไบต์ดิบ ไม่ระบุชนิด" Backend รับด้วย `express.raw(...)` |
| 239 | ชื่อไฟล์ไปทาง header `X-File-Name` และต้อง `encodeURIComponent` เพราะ HTTP header รับได้แค่อักขระ ASCII (ฝั่ง Backend ถอดกลับด้วย `decodeHeader`) |
| 241 | คำตอบ 201 มี `{ file }` คืนเฉพาะข้อมูลไฟล์ใหม่ |
| 242–243 | ลบด้วย `DELETE /firmware/<ชื่อ>` ชื่อไฟล์ผ่าน `encodeURIComponent` เหมือนทุก path ในไฟล์นี้ |

> [!WHY]
> ทำไมส่งไฟล์ดิบแทน `multipart/form-data` (แบบฟอร์มอัปโหลดทั่วไป)? เพราะต้องการส่งไฟล์เดียว และ Backend มีแบบเดียวกันอยู่แล้วกับการนำเข้าตารางเรียน (`previewScheduleImport`) ไม่ต้องเพิ่มไลบรารีแยก multipart ฝั่ง Express ไฟล์ทั้งก้อนเป็น `request.body` ที่ตรวจขนาดและไบต์แรกได้ทันที

ไฟล์ `webapp/assets/js/views/firmware.js` บรรทัด 670–693 (ใช้ API ข้างบน)

```js:670
async function uploadWithReplace(file, fileName, kind) {
  try {
    await api.uploadFirmware(file, fileName, kind);
    toastOk(`อัปโหลด ${fileName} แล้ว`);
  } catch (error) {
    if (error.status !== 409) {
      toastError(error.message);
      return;
    }
    const replaceIt = await confirmAction({
      title: `มีไฟล์ ${fileName} อยู่แล้ว`,
      subtitle: 'เขียนทับด้วยไฟล์ใหม่ไหม บอร์ดที่สั่งด้วยชื่อนี้หลังจากนี้จะได้ไฟล์ใหม่',
      confirmLabel: 'เขียนทับ',
      danger: true,
    });
    if (!replaceIt) return;
    try {
      await api.uploadFirmware(file, fileName, kind, true);
      toastOk(`เขียนทับ ${fileName} แล้ว`);
    } catch (retryError) {
      toastError(retryError.message);
    }
  }
}
```

| บรรทัด | อธิบาย |
|---|---|
| 672–673 | ส่งครั้งแรก **ไม่** ขอเขียนทับ สำเร็จก็จบ |
| 675–678 | error อื่นที่ไม่ใช่ 409 (เช่น 400 ไม่ใช่ไฟล์ ESP32, 413 ใหญ่เกิน, 503 ไม่ได้ตั้ง `FIRMWARE_DIR`) แสดงข้อความไทยจาก Backend ตรง ๆ (`ApiError` เก็บ `status` ไว้ให้เช็ก) |
| 679–685 | 409 = มีไฟล์ชื่อนี้แล้ว ถามยืนยันแบบปุ่มแดง (`danger: true`) |
| 686–691 | ยืนยันแล้วส่งซ้ำพร้อม `replace = true` |

> [!WHY]
> ทำไมไม่ให้เขียนทับเงียบ ๆ? ไฟล์ชื่อเดียวกันคือ "รุ่นเดียวกัน" ถ้าเนื้อในเปลี่ยนโดยไม่รู้ตัว บอร์ดที่อัปเดตไปแล้วกับบอร์ดที่อัปเดตทีหลังจะได้โปรแกรมต่างกันทั้งที่รายงานรุ่นเหมือนกัน การให้เซิร์ฟเวอร์ตอบ 409 ก่อน แล้วให้คนตัดสินใจ ทำให้การเขียนทับเป็นการกระทำที่ตั้งใจเสมอ (Backend ยังเขียนไฟล์ชั่วคราว `.part` แล้วค่อย `rename` เพื่อไม่ให้บอร์ดที่กำลังดาวน์โหลดได้ไฟล์ครึ่งเดียว)

**10.9 สั่งอัปเดตหลายบอร์ด** — ไฟล์ `webapp/assets/js/views/firmware.js` บรรทัด 579–604 (ต่อจากกล่องยืนยันในบรรทัด 559–577)

```js:579
  let sent = 0;
  const failures = [];
  for (const device of devices) {
    try {
      if (meta.key === 'occupancy') {
        await api.otaOccupancySensor(device.deviceId, latest.name);
      } else {
        await api.otaAirConditioner(device.deviceId, latest.name);
      }
      pending.set(device.deviceId, {
        target,
        startedAt: Date.now(),
        previousError: device.otaError ?? null,
      });
      selected[meta.key].delete(device.deviceId);
      sent += 1;
    } catch (error) {
      failures.push(`${device.deviceId}: ${error.message}`);
    }
  }
  if (sent > 0) {
    toastOk(`ส่งคำสั่งแล้ว ${sent} บอร์ด รอบอร์ดรีบูตและรายงานรุ่นใหม่`);
  }
  for (const message of failures) toastError(message);
  ctx.update();
}
```

| บรรทัด | อธิบาย |
|---|---|
| 579–580 | นับที่ส่งสำเร็จ และเก็บข้อความของตัวที่ล้มเหลว |
| 581 | วน **ทีละบอร์ดตามลำดับ** (`for ... of` + `await`) ไม่ยิงพร้อมกันทั้งหมด |
| 583–587 | เซ็นเซอร์เรียก `otaOccupancySensor` แอร์ (ทั้ง IR และสายแอร์) เรียก `otaAirConditioner` ทั้งคู่ส่งชื่อไฟล์ล่าสุดของแท็บ |
| 588–592 | Backend รับแล้ว → จดงานรอ: รุ่นเป้าหมาย เวลาเริ่ม และ `otaError` ที่มีอยู่ก่อนสั่ง |
| 593 | เอาบอร์ดนี้ออกจากที่เลือก แถบหลายบอร์ดจะหดลงตามจริง |
| 595–597 | บอร์ดไหนล้มเหลว (เช่น 409 เพิ่งออฟไลน์) เก็บข้อความไว้ แต่ **วนต่อ** บอร์ดอื่นยังได้คำสั่ง |
| 599–602 | สรุปเป็น toast เดียวสำหรับที่สำเร็จ และ toast แยกต่อบอร์ดที่ล้มเหลว |
| 603 | วาดใหม่ ป้าย "กำลังอัปเดต" ขึ้นทันที |

> [!WHY]
> ทำไมส่งทีละบอร์ด ไม่ใช้ `Promise.all`? ทุกบอร์ดดาวน์โหลดไฟล์ ~1–2 MB จากเซิร์ฟเวอร์เดียวกันผ่าน Wi-Fi ของอาคาร การส่งตามลำดับทำให้คำสั่งไปถึงบอร์ดห่างกันเล็กน้อย และทำให้รู้ผลรายบอร์ดชัดเจน ถ้าใช้ `Promise.all` ตัวเดียวพังจะทำให้ทั้งชุด reject ต้องใช้ `Promise.allSettled` แทน ส่วนกล่องยืนยัน (บรรทัด 566–576) เตือนว่า "ระหว่างนั้นสั่งงานบอร์ดจากแอปไม่ได้ … แนะนำให้อัปเดตนอกเวลาเรียน" เพราะบอร์ดแอร์ที่รีบูตจะสั่งเปิด-ปิดแอร์ไม่ได้ 1–2 นาที

**10.10 ช่องติ๊กที่เลือกได้เฉพาะบอร์ดที่ยังเก่า** — ไฟล์ `webapp/assets/js/views/firmware.js` บรรทัด 379–383

```js:379
  // บอร์ดที่เลือกไว้แต่ไม่ต้องอัปเดตแล้ว (เช่นเพิ่งอัปเดตเสร็จ) เอาออกจากที่เลือก
  for (const { device, status } of rows) {
    if (status.code !== 'outdated') chosen.delete(device.deviceId);
  }
  const outdated = rows.filter((row) => row.status.code === 'outdated');
```

| บรรทัด | อธิบาย |
|---|---|
| 380–382 | ทุกครั้งที่วาดตาราง เอาบอร์ดที่ไม่ใช่ `outdated` ออกจาก `selected` (เช่น อัปเดตเสร็จแล้ว หรือเพิ่งออฟไลน์) จำนวนบนแถบหลายบอร์ดจึงไม่นับบอร์ดที่สั่งไม่ได้ |
| 383 | `outdated` ใช้กับปุ่ม "เลือกทุกตัวที่ยังเก่า (N)" และช่องติ๊กบนหัวตาราง (บรรทัด 407–426) ที่ติ๊กหรือเอาออกทั้งกลุ่ม |

### 11) บอร์ดสายแอร์ Daikin บนหน้าเว็บ: `format.js` + `rooms.js` (เพิ่ม 11 ต.ค. 2569)

commit `a5a227f` เพิ่มบอร์ดรุ่นใหม่ที่ต่อ "สายแอร์" (สายของรีโมตติดผนัง Daikin) แทนการยิงอินฟราเรด ในฐานข้อมูลบอร์ดนี้มี `protocol` = `DAIKIN_WIRED` หน้าเว็บต้องทำ 2 อย่าง: บอกผู้ใช้ให้รู้ว่าเครื่องนี้ควบคุมแบบไหน และแสดงเฉพาะปุ่มที่เครื่องนี้ทำได้

**11.1 ตัวช่วยยี่ห้อ** — ไฟล์ `webapp/assets/js/format.js` บรรทัด 347–351 และ 375–390

```js:347
/** บอร์ดรุ่นสายแอร์ (ต่อสายแอร์แทนรีโมตติดผนัง Daikin) */
export const WIRED_PROTOCOL = 'DAIKIN_WIRED';

export const isWiredProtocol = (protocol) =>
  String(protocol ?? '').trim().toUpperCase() === WIRED_PROTOCOL;
```

ไฟล์ `webapp/assets/js/format.js` บรรทัด 375–390

```js:375
/** ยี่ห้อแอร์จากชื่อโปรโตคอล เช่น HAIER_AC160 → Haier */
export function airBrand(protocol) {
  const key = String(protocol ?? '').trim().toUpperCase();
  return BRAND_BY_PROTOCOL[key] ?? (key || '—');
}

/** "สายแอร์" หรือ "รีโมต IR" */
export function controlTypeLabel(protocol) {
  return isWiredProtocol(protocol) ? 'สายแอร์' : 'รีโมต IR';
}

/** ข้อความสั้นสำหรับรายการ เช่น "Daikin · สายแอร์" หรือ "Haier · รีโมต IR (HAIER_AC160)" */
export function airControlSummary(protocol) {
  if (isWiredProtocol(protocol)) return `${airBrand(protocol)} · สายแอร์`;
  return `${airBrand(protocol)} · รีโมต IR (${protocol})`;
}
```

| บรรทัด | อธิบาย |
|---|---|
| 348 | ชื่อโปรโตคอลของบอร์ดสายแอร์ประกาศเป็นค่าคงที่ที่เดียว ไฟล์อื่น import ไปใช้ ไม่พิมพ์ `'DAIKIN_WIRED'` ซ้ำ |
| 350–351 | `String(protocol ?? '')` กันค่า `null`/`undefined` แล้ว `trim().toUpperCase()` ให้ `' daikin_wired'` ก็นับ ใช้ arrow function ย่อ (`=>` ตามด้วยนิพจน์ = คืนค่านั้นเลย) |
| 376–378 | หา `BRAND_BY_PROTOCOL[key]` (ตารางบรรทัด 353–373 ที่ map 19 โปรโตคอลเป็นยี่ห้อ) ถ้าไม่เจอใช้ชื่อโปรโตคอลเอง และถ้าโปรโตคอลเป็นสตริงว่างใช้ `—` |
| 382–384 | ป้ายวิธีควบคุม "สายแอร์" หรือ "รีโมต IR" |
| 387–390 | ข้อความสั้นสำหรับบรรทัดย่อยในรายการ บอร์ด IR ต่อท้ายโปรโตคอลในวงเล็บ เพราะยี่ห้อเดียวอาจมีหลายโปรโตคอล (Haier 4 แบบ) ช่างต้องรู้ว่าเลือกแบบไหนไว้ |

> [!WHY]
> ทำไมใส่ไว้ใน `format.js`? เพราะเป็นฟังก์ชันล้วน (รับโปรโตคอล คืนข้อความ) และถูกใช้ 3 หน้า (`rooms.js`, `devices.js`, `firmware.js`) ถ้าแต่ละหน้าเขียนตารางยี่ห้อเอง วันหนึ่งจะสะกดไม่ตรงกัน

**11.2 ขอบเขตของเครื่องสายแอร์** — ไฟล์ `webapp/assets/js/views/rooms.js` บรรทัด 57–72

```js:57
function limitsFor(protocol) {
  if (isWiredProtocol(protocol)) {
    // บอร์ดสายแอร์ ใช้ได้เท่าที่รีโมตติดผนัง Daikin มี
    return {
      minTemp: 16,
      maxTemp: 30,
      modes: ['cool', 'dry', 'fan'],
      fans: ['auto', 'low', 'medium', 'high'],
      swings: ['auto', 'off'],
      extras: (mode) =>
        mode === 'dry' ? [] : EXTRA_TOGGLES.filter((item) => item.key === 'sleep'),
      note:
        'ควบคุมผ่านสายแอร์แทนรีโมตติดผนัง Daikin · Cool / Dry / Fan · ' +
        'ส่ายหรือหยุด · Sleep (ยกเว้นโหมด Dry)',
    };
  }
```

| บรรทัด | อธิบาย |
|---|---|
| 58 | เช็กสายแอร์ก่อน Saijo Denki และค่าเริ่มต้น |
| 61–62 | อุณหภูมิ 16–30°C |
| 63 | โหมดมีแค่ cool / dry / fan (ไม่มี auto และ heat) |
| 64 | พัดลมไม่มี `turbo` (ต่างจาก `FANS` ปกติที่มี 5 ระดับ) |
| 65 | ทิศลมมีแค่ส่าย (`auto`) กับหยุด (`off`) ไม่มีการเลือกตำแหน่งบานสวิง |
| 66–67 | `extras` เป็น **ฟังก์ชันของโหมด** ไม่ใช่รายการคงที่: โหมด dry ไม่มีฟังก์ชันเสริมเลย โหมดอื่นมีแค่ `sleep` |
| 68–70 | ข้อความใต้การ์ดอธิบายข้อจำกัดเป็นภาษาคน |

ส่วน Saijo Denki และรุ่นอื่น (บรรทัด 73–92) ได้ฟิลด์ใหม่ `fans: FANS` และ `extras: () => EXTRA_TOGGLES` เพื่อให้ทุกรุ่นคืนออบเจ็กต์รูปร่างเดียวกัน โค้ดที่เรียก (`acCard`) จึงใช้ `limits.fans`, `limits.extras(mode)` ได้โดยไม่ต้องเช็กว่ารุ่นนี้มีฟิลด์ไหม

**11.3 ปรับร่างให้อยู่ในขอบเขต** — ไฟล์ `webapp/assets/js/views/rooms.js` บรรทัด 96–111

```js:96
function fitDraft(draft, limits) {
  if (!limits.modes.includes(draft.mode)) draft.mode = limits.modes[0];
  if (!limits.fans.includes(draft.fanSpeed)) {
    draft.fanSpeed = limits.fans.includes('high') ? 'high' : limits.fans[0];
  }
  if (!limits.swings.includes(draft.verticalSwing)) {
    draft.verticalSwing = limits.swings[0];
  }
  const allowed = new Set(limits.extras(draft.mode).map((item) => item.key));
  for (const item of EXTRA_TOGGLES) {
    // ไฟหน้าจอเปิดไว้เป็นค่าเริ่มต้น และ Backend ไม่ได้บังคับปิด จึงไม่แตะ
    if (item.key !== 'displayLight' && !allowed.has(item.key)) {
      draft[item.key] = false;
    }
  }
}
```

| บรรทัด | อธิบาย |
|---|---|
| 97 | โหมดที่ร่างไว้ไม่อยู่ในรายการ (เช่น `auto` จากสถานะเดิม) → ใช้โหมดแรก `cool` |
| 98–100 | พัดลมที่ใช้ไม่ได้ (เช่น `turbo`) → ใช้ `high` ถ้ามี (ใกล้กับ turbo ที่สุด) ไม่งั้นตัวแรก |
| 101–103 | ทิศลมที่ใช้ไม่ได้ (เช่น `middle`) → ตัวแรกของรายการ (`auto`) |
| 104 | `Set` ของฟังก์ชันเสริมที่โหมดปัจจุบันอนุญาต |
| 105–110 | ปิดทุกฟังก์ชันเสริมที่ไม่อนุญาต ยกเว้น `displayLight` (ไฟหน้าจอเปิดเป็นค่าเริ่มต้น และ Backend ไม่ได้บังคับปิด) |

ใน `acCard` เรียก `fitDraft` 2 จุด เฉพาะบอร์ดสายแอร์: บรรทัด 551 `if (wired) fitDraft(draft, limits);` ก่อนวาดการ์ด และบรรทัด 673 ทุกครั้งที่กดเปลี่ยนโหมด (เปลี่ยนเป็น dry ต้องปิด sleep ทันที) ส่วนแถว "ฟังก์ชันเสริม" (บรรทัด 693–712) วาดจาก `limits.extras(draft.mode)` ถ้าว่างแสดง "ไม่มีในโหมดนี้" แทนแถวปุ่มว่าง ๆ

> [!WHY]
> ทำไมต้องปรับร่าง ไม่ใช่แค่ซ่อนปุ่ม? ร่าง (`drafts`) ถูกสร้างจาก `unit.state` ซึ่งอาจมีค่าที่เครื่องนี้ไม่รองรับค้างอยู่ (เช่น `fanSpeed: 'turbo'` จากค่าเริ่มต้นของระบบ) ถ้าซ่อนปุ่มอย่างเดียว ค่า turbo ยังถูกส่งไปตอนกด "ส่งคำสั่ง" แล้ว Backend ตอบ 400 "แอร์แบบสายแอร์ไม่มีพัดลมระดับ Turbo" (`backend/src/utils/air-conditioner.js`) ผู้ใช้จะไม่เข้าใจเพราะไม่เห็นปุ่ม turbo บนจอเลย `fitDraft` ทำให้สิ่งที่เห็นบนจอกับสิ่งที่จะส่งตรงกันเสมอ และตรงกับกติกาฝั่งเซิร์ฟเวอร์

**11.4 ชิปยี่ห้อบนการ์ดแอร์** — ไฟล์ `webapp/assets/js/views/rooms.js` บรรทัด 598–604

```js:598
      el('span', {
        class: `status-chip ${wired ? 'info' : 'off'}`,
        title: wired
          ? 'สั่งงานผ่านสายแอร์ แทนรีโมตติดผนัง'
          : 'สั่งงานด้วยอินฟราเรด เหมือนรีโมตแบบถือ',
        text: `${airBrand(unit.protocol)} · ${controlTypeLabel(unit.protocol)}`,
      }),
```

| บรรทัด | อธิบาย |
|---|---|
| 599 | สายแอร์ใช้สี `info` (ฟ้า) ให้เด่น IR ใช้สี `off` (เทา) เพราะเป็นกรณีปกติ |
| 600–602 | `title` = ข้อความที่ขึ้นเมื่อเอาเมาส์ชี้ อธิบายความต่างแบบคนทั่วไปเข้าใจ |
| 603 | ข้อความบนชิป เช่น "Daikin · สายแอร์" หรือ "Saijo Denki · รีโมต IR" |

## หลักการเขียนโค้ดที่ใช้ในส่วนนี้

**1. ชั้นเดียวคุยกับ Backend (API gateway pattern)** — `api.js` เท่านั้นที่เรียก `fetch` ทำให้แนบ token ไม่มีวันลืม จัดการ 401 และแปลง error เป็น `ApiError` ที่เดียว ถ้าให้แต่ละหน้าเรียกเอง สักหน้าจะลืมแนบ token หรือจัดการ 401 ต่างจากหน้าอื่น

**2. State กลางที่ทุกหน้าอ่าน (single source of truth) + pub/sub** — `store.js` (`state`, `subscribe`, `emit`) หน้าภาพรวมกับหน้าห้องใช้ `/rooms` ชุดเดียวกัน ถ้าต่างคนต่างดึง เซิร์ฟเวอร์ถูกถามซ้ำเท่าตัวโดยไม่ได้ข้อมูลเพิ่ม และเมื่อสั่งแอร์แล้วข้อมูลเปลี่ยน ทุกหน้าที่เปิดค้างเห็นตรงกัน คล้าย `ChangeNotifier` ของ Flutter

**3. สร้าง DOM แบบไม่ผ่าน innerHTML (safe DOM building)** — `dom.js` `el()` ใส่ข้อความด้วย `textContent`/`createTextNode` เสมอ กัน XSS โดยโครงสร้าง ไม่ต้องจำ "escape ทุกครั้ง"

**4. แยก mount กับ update** — ทุกไฟล์ใน `views/` สร้างโครงที่ต้องคงอยู่ใน `mount` และวาดเฉพาะส่วนข้อมูลใน `update` กันช่องที่กำลังพิมพ์ถูกลบทุก 10 วินาที (เช่น ช่องค้นหาใน `rooms.js` สร้างครั้งเดียว, `energy.js` วาดตัวกรองใหม่ต่อเมื่อ `filterSignature()` เปลี่ยน)

**5. รวมการแจ้งด้วย microtask (batching)** — `emit()` ใน `store.js` ใช้ `queueMicrotask` รวมหลายการเปลี่ยนแปลงเป็นการวาดครั้งเดียว

**6. ร่างแยกจากความจริง (draft state)** — `drafts` ใน `rooms.js` เก็บคำสั่งที่ผู้ใช้กำลังแก้ (อุณหภูมิ โหมด) แยกจากสถานะจริงของแอร์ที่ถูกอัปเดตทุก 10 วินาที ถ้าใช้ state เดียว ข้อมูลสดที่เข้ามาจะทับสิ่งที่ผู้ใช้เพิ่งกด และถ้าส่งคำสั่งล้มเหลวต้องคืนร่างกลับเป็นสถานะจริง

**7. Promise-based dialog** — `openModal`/`openForm`/`confirmAction` คืน Promise ผู้เรียกเขียน `const ok = await confirmAction({...}); if (!ok) return;` อ่านเหมือนโค้ดลำดับตรง ๆ แทนที่จะซ้อน callback

**8. ป้องกันการกดซ้ำ** — `withBusy` และ `button.disabled = true` ใน `finally` (เช่น `rooms.js` `sendCommand`) กันกดรัวจนยิงคำสั่ง MQTT ซ้ำ ซึ่งแอร์บางรุ่นตีความเป็นการสลับเปิด-ปิด

**9. ให้เซิร์ฟเวอร์เป็นผู้ตัดสิน เบราว์เซอร์แค่แสดงผล** — ภาคเรียนเปิด/ปิด (`status`), "วันนี้" (`state.today` ตามเวลาไทย), กติกาปิดแอร์อัตโนมัติ, สิทธิ์แอดมิน ทั้งหมดตัดสินที่ Backend เว็บแค่แสดง เพราะเวลาและนาฬิกาของเครื่องผู้ใช้เชื่อไม่ได้ และปุ่มที่ซ่อนก็แก้ใน DevTools ได้

**10. Defensive coding รับมือไฟล์รุ่นเก่าค้างแคช** — เพราะ `/assets` ถูกแคช 1 ชั่วโมง ผู้ใช้อาจได้ไฟล์ใหม่ปนไฟล์เก่า โค้ดจึง: (ก) ใส่ export ใหม่ในไฟล์ใหม่ ไม่ใส่ในไฟล์เดิม (`theme.js`, `prefs.js`, `icons-ui.js` ที่เกิดจากเหตุผลนี้) (ข) เช็ก `typeof api.academicTerms !== 'function'` หรือ `api.schedulesWithInfo ?? ...` ก่อนเรียก (`store.js` บรรทัด 199–200, 211, 222) (ค) สร้างแถบเมนูล่างจาก JS ไม่เขียนใน `index.html` เพื่อไม่ให้ไฟล์เก่าทิ้งแถบว่างไว้ (ง) แยก `undefined` (Backend เก่า) กับ `null` (ไม่มีข้อมูล)

**11. Defense in depth** — XSS ป้องกันหลายชั้น: `textContent` + CSP `script-src 'self'` + (หากโค้ดชั้นแรกพลาด) `connect-src 'self'` ไม่ให้ส่งข้อมูลออกไปเว็บอื่น + token ใน localStorage ที่ Backend ตรวจสิทธิ์ซ้ำทุกคำขอ

**12. Design tokens** — ทุกสีและขนาดมาจาก `tokens.css` ห้ามเขียนสี/px ตรง ๆ ในไฟล์อื่น เปลี่ยนธีมที่เดียว

**13. ฟังก์ชันจัดรูปแบบล้วน (pure function)** — `format.js` รับค่า คืนข้อความ ไม่แตะ DOM/state ทดสอบง่ายและเหมือนกับ `number_format.dart` ของแอปมือถือ

**15. สถานะ "รอผล" ฝั่งเบราว์เซอร์ + เวลาหมดอายุ (เพิ่ม 14 ต.ค. 2569)** — `firmware.js` จด `pending` ทันทีหลัง Backend รับคำสั่ง OTA แล้วตัดสินผลจากข้อมูลที่ polling นำมา (รุ่นตรงเป้า / มี `otaError` ใหม่ / เกิน 5 นาที) แทนที่จะรอคำตอบจากคำขอเดียว เพราะ OTA เป็นงานที่บอร์ดทำเองหลังคำขอ HTTP จบไปนานแล้ว ต้องมีเวลาหมดอายุเสมอ ไม่งั้นบอร์ดที่ดับไปจะค้าง "กำลังอัปเดต" ตลอดกาล

**16. ตรวจสองชั้น เบราว์เซอร์เพื่อความสะดวก เซิร์ฟเวอร์เพื่อความถูกต้อง** — `handleFile` ตรวจนามสกุล ขนาด (`maxBytes` จากเซิร์ฟเวอร์) ชื่อ `.merged.bin` และชนิดตรงแท็บก่อนส่ง เพื่อบอกผู้ใช้เร็วโดยไม่ต้องอัปโหลด 2 MB ก่อน แต่ Backend ตรวจซ้ำทุกข้อ (และตรวจไบต์แรก `0xE9` ของไฟล์ ESP32 ที่เบราว์เซอร์ไม่ได้ตรวจ) เช่นเดียวกับ `fitDraft` ใน `rooms.js` ที่ปรับร่างให้ตรงกับกติกาของ `backend/src/utils/air-conditioner.js` ก่อนส่ง

**17. กติกาเดียวเขียนสองที่ต้องตรงกัน** — `kindOfFileName`/`versionOfFileName`/`compareVersions` ใน `firmware.js` เป็นสำเนาของ `firmwareKindOf`/`firmwareVersionOf`/`compareFirmwareVersions` ใน `backend/src/utils/firmware.js` (คอมเมนต์บรรทัด 93 เตือนไว้) และ `limitsFor` ของ `rooms.js` ต้องตรงกับ `utils/air-conditioner.js` ข้อดีคือหน้าเว็บตอบสนองทันที ข้อเสียคือแก้ฝั่งเดียวแล้วสองฝั่งจะไม่ตรงกัน (หน้าเว็บบอกว่าใช้ได้ แต่เซิร์ฟเวอร์ตอบ 400)

**14. รับมือ localStorage พัง** — ทุกการอ่าน/เขียนห่อ `try/catch` (`config.js`, `api.js` `read/write`, `theme.js`, `prefs.js`, `app.js`) แล้วถอยไปใช้ค่าเริ่มต้น แอปทำงานได้แม้อยู่ในโหมดส่วนตัว (แค่ไม่จำค่า)

## การ deploy และแคช

### `deploy/deploy-web.ps1`

สคริปต์ PowerShell อัปโหลดเฉพาะโฟลเดอร์ `webapp/` ขึ้นเซิร์ฟเวอร์ ไม่ build ไม่รีสตาร์ท Backend เร็วกว่า `update-server.ps1` มาก เพราะ Caddy อ่านไฟล์จากดิสก์ทุกครั้งที่มีคนขอ ไฟล์ใหม่มีผลทันที

| ขั้น | โค้ด | ทำไม |
|---|---|---|
| รับค่า | `param([string]$Server = '', [string]$User = '')` + `. ServerConfig.ps1` + `Get-RmuttServer` | ไม่ต้องใส่ถ้ามี `deploy\server.config.json` อ่านค่า host/user/ช่องทาง SSH จากไฟล์ตั้งค่า |
| ตรวจ | `Test-Path $webDirectory` | ไม่พบ `webapp/` = หยุดพร้อมข้อความ |
| เตรียม | `ssh ... 'rm -rf /opt/rmutt/www.new && mkdir -p /opt/rmutt/www.new'` | โฟลเดอร์ชั่วคราวใหม่เอี่ยม ล้างของค้างจากรอบก่อน |
| อัปโหลด | `scp -r <ทุกอย่างในเว็บ> target:/opt/rmutt/www.new/` | ส่งไปโฟลเดอร์ชั่วคราวก่อน ถ้าสายหลุดกลางทาง `www` ที่ใช้งานอยู่ไม่เสียหาย |
| สลับ | `cd /opt/rmutt && mkdir -p www && find www -mindepth 1 -delete && cp -a www.new/. www/ && rm -rf www.new && ls -la www` | **คัดลอกเข้าไปใน `www` ตัวเดิม ไม่เปลี่ยนชื่อโฟลเดอร์** |

> [!WHY]
> ทำไมไม่ `mv www.new www`: Docker ผูกโฟลเดอร์ `./www` เข้ากับ container ของ Caddy (`docker-compose.yml`: `./www:/srv/www:ro`) ตาม **inode** ไม่ใช่ตามชื่อ ถ้าลบ `www` แล้วเปลี่ยนชื่อโฟลเดอร์ใหม่มาแทน Caddy จะยังชี้ที่โฟลเดอร์เก่าที่ถูกลบไป แล้วตอบ 404 ทุกหน้าโดยไม่มีข้อความบอกอะไร การลบ "เนื้อใน" (`find -mindepth 1 -delete`) แล้วคัดลอกเนื้อใหม่ใส่โฟลเดอร์เดิม โฟลเดอร์ (inode) เดิมจึงยังอยู่ และยังล้างไฟล์ที่ถูกลบจากโปรเจกต์แล้วออกด้วย (กันหน้าเดิมที่ผู้ใช้เปิดค้างไว้ไปเรียก JS เก่า) ในไฟล์เขียนว่า "สลับโฟลเดอร์ทีเดียว" ซึ่งเป็นสำนวนที่ไม่ตรงกับสิ่งที่ทำ: ระหว่าง `find -delete` กับ `cp` สั้น ๆ ผู้ใช้อาจเจอไฟล์ไม่ครบ ไม่ใช่การสลับแบบ atomic

ข้อสังเกต: `Get-ChildItem -Force` ส่งทุกไฟล์ในโฟลเดอร์ `webapp/` ขึ้นไป รวมถึง `README.md` ซึ่งหมายถึงจะถูกเสิร์ฟสาธารณะที่ `/README.md` ด้วย ไม่มีความลับในไฟล์นั้น แต่ควรรู้ว่าอะไรก็ตามที่วางในโฟลเดอร์นี้จะเป็นไฟล์สาธารณะ

### Caddy: แคชและหัวความปลอดภัย (`deploy/Caddyfile`)

Caddy คือเว็บเซิร์ฟเวอร์ตัวหน้าสุด (ขอใบรับรอง HTTPS อัตโนมัติ) บล็อก `(app)` เป็น snippet ที่ใช้ร่วมกันทั้งโดเมนหลัก (`{$DOMAIN}`) และทางเข้า Tailscale Funnel (`http://:8080`) ผ่าน `import app`

| คำสั่ง | บรรทัด | ผล |
|---|---|---|
| `encode gzip` | 11 | บีบอัดคำตอบ ไฟล์ JS/CSS เล็กลง |
| `header { Content-Security-Policy ... }` | 20–27 | หัวความปลอดภัยทุกหน้า (ตารางด้านล่าง) |
| `handle /api/* { reverse_proxy backend:3000 }` | 29–31 | ส่งทุกอย่างใต้ `/api/` ต่อให้ Backend (ชื่อ `backend` คือชื่อ service ในเครือข่าย Docker) |
| `handle /firmware/* { root * /srv; header Cache-Control "no-store"; file_server }` | 35–39 | ไฟล์ `.bin` สำหรับ OTA ห้ามแคช |
| `handle { root * /srv/www ... file_server }` | 41–55 | **ที่เหลือทั้งหมด** เสิร์ฟจากโฟลเดอร์เว็บ |
| `@assets path /assets/*` + `header @assets Cache-Control "public, max-age=3600"` | 46–47 | ไฟล์ CSS/JS/รูปใน `/assets/` แคชได้ **1 ชั่วโมง** |
| `@html path / /index.html /status.html` + `Cache-Control "no-cache"` | 51–52 | หน้า HTML ต้อง**ตรวจกับเซิร์ฟเวอร์ทุกครั้ง** (`no-cache` ไม่ได้แปลว่าห้ามเก็บ แปลว่าต้อง revalidate ก่อนใช้ ถ้าไฟล์ไม่เปลี่ยนเซิร์ฟเวอร์ตอบ 304 สั้น ๆ) |

ผลต่อการ deploy: หลัง `deploy-web.ps1` ผู้ใช้ได้ `index.html` ใหม่ทันที (ไม่แคช) ซึ่งมี `?v=` ใหม่ → CSS 4 ไฟล์และ `main.js` ถูกโหลดใหม่ แต่ **โมดูลที่ `main.js` import ต่อ** (`app.js`, `store.js`, `views/*.js` ...) URL ไม่มี `?v=` จึงอาจถูกใช้จากแคชได้นานสูงสุด 1 ชั่วโมง นี่คือที่มาของมาตรการกันไฟล์เก่า-ใหม่ปนกัน (หลักการข้อ 10) ถ้ายังเห็นของเก่า กด Ctrl+F5 หนึ่งครั้ง

**หัวความปลอดภัยแต่ละตัว** (จากบรรทัด 21–26)

| Header | ค่า | กันอะไร |
|---|---|---|
| `Content-Security-Policy` | `default-src 'self'` | ค่าเริ่มต้น: โหลดได้เฉพาะจากโดเมนเดียวกัน |
|  | `script-src 'self'` | รันสคริปต์ได้เฉพาะไฟล์จากโดเมนนี้ (ไม่มี inline) |
|  | `style-src 'self' 'unsafe-inline' https://fonts.googleapis.com` | CSS จากโดเมนนี้ + Google Fonts + `style=""`/`<style>` ฝัง (ยอมเพราะหน้าเว็บใช้ `style` ในหลายจุด ความเสี่ยงต่ำกว่าสคริปต์) |
|  | `font-src 'self' https://fonts.gstatic.com` | ไฟล์ฟอนต์ |
|  | `img-src 'self' data: blob:` | รูปจากโดเมนนี้ `data:` และ `blob:` |
|  | `connect-src 'self'` | `fetch`/XHR ไปได้เฉพาะโดเมนนี้ (ชั้นกันขโมย token และกัน `?api=` ชี้ออกนอก) |
|  | `object-src 'none'`, `base-uri 'self'`, `form-action 'self'` | ไม่รับปลั๊กอิน กันเปลี่ยน `<base>` และกันฟอร์มส่งข้อมูลไปเว็บอื่น |
|  | `frame-ancestors 'none'` | ห้ามเว็บอื่นเอาไปใส่ `<iframe>` (กัน clickjacking) |
| `Strict-Transport-Security` | `max-age=31536000` | บอกเบราว์เซอร์ให้ใช้ HTTPS เท่านั้นเป็นเวลา 1 ปี |
| `X-Content-Type-Options` | `nosniff` | ห้ามเบราว์เซอร์เดาชนิดไฟล์เอง |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | ไม่ส่ง URL เต็มไปเว็บอื่น |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` | ปิดสิทธิ์กล้อง ไมค์ ตำแหน่ง |
| `-Server` | (ลบ header) | ไม่โชว์ชื่อ/รุ่นเซิร์ฟเวอร์ |

## คำถามที่อาจารย์อาจถาม

> [!ASK]
> **ถาม:** ทำไมต้องมีทั้งแอป Flutter และเว็บแอป ทำอันเดียวไม่ได้หรือ
> **ตอบ:** สองอันใช้ Backend และฐานข้อมูลชุดเดียวกัน ผู้ใช้และรหัสผ่านชุดเดียวกัน แต่ถนัดคนละงาน แอปมือถือทำสิ่งที่เว็บทำไม่ได้: **ตั้งค่าบอร์ด ESP32 ผ่าน Bluetooth** ซึ่งต้องยืนใกล้บอร์ดแล้วใช้บลูทูธของโทรศัพท์ส่ง Wi-Fi/MQTT เข้าไป (เว็บเบราว์เซอร์เข้าถึงบลูทูธในแบบที่บอร์ดต้องการไม่ได้) ส่วนเว็บเหมาะกับงานหน้าจอกว้างและงานกรอกข้อมูล: ตารางข้อมูลไฟฟ้าสิบกว่าคอลัมน์ นำเข้าตารางเรียนจาก Excel จัดการห้องและอุปกรณ์ ส่งออก Excel และไม่ต้องติดตั้งอะไร แค่เปิดเบราว์เซอร์ เว็บจึงมีฟีเจอร์ "จองช่อง" บอร์ดใหม่ (สร้างโทเคน 15 นาที) ให้คนพิมพ์ข้อมูลบนคอมแล้วให้คนหน้างานถือมือถือไปทำขั้น Bluetooth ต่อ

> [!ASK]
> **ถาม:** ทำไมไม่ใช้ React หรือ Vue
> **ตอบ:** เว็บมี 10 หน้า ไม่มีขั้นตอน build ไม่ต้องมี Node บนเครื่อง deploy แค่คัดลอกไฟล์ขึ้นเซิร์ฟเวอร์ Caddy เสิร์ฟทันที เวลาส่งต่อโปรเจกต์ให้รุ่นน้อง ไม่ต้องไล่แก้ว่า `npm run build` พังเพราะเวอร์ชัน ใช้ ES Modules ของเบราว์เซอร์แทน bundler ข้อเสียที่ยอมรับ: เขียนโค้ดสร้าง DOM เองด้วย `el()` (แต่ก็ได้ความปลอดภัยจาก XSS ติดมาโดยโครงสร้าง) ต้องเปิดผ่าน `http://` ไม่ใช่ดับเบิลคลิกไฟล์ และไม่มีตัวตรวจ type ถ้าเว็บโตขึ้นมาก ค่อยย้ายไป framework ได้ เพราะ `api.js` กับ `store.js` ไม่ผูกกับหน้าจอ

> [!ASK]
> **ถาม:** token เก็บใน localStorage ปลอดภัยหรือ ถ้าโดน XSS ก็ถูกขโมยได้
> **ตอบ:** จริงครับ ความเสี่ยงของ localStorage คือ XSS เราจึงกันที่ต้นทาง 2 ชั้น: ข้อมูลจากฐานข้อมูลใส่หน้าด้วย `textContent` เสมอ (ไม่ใช้ `innerHTML` กับข้อมูลผู้ใช้) และ CSP `script-src 'self'` ที่บล็อกสคริปต์ฝัง ถ้าสคริปต์หลุดมาได้ `connect-src 'self'` ยังกันไม่ให้ส่ง token ไปเว็บอื่น ส่วนที่ไม่ใช้ cookie เพราะ Backend ตรวจสิทธิ์จากหัว `Authorization` อย่างเดียว การใช้ cookie จะต้องเพิ่มการป้องกัน CSRF และ cookie แบบ HttpOnly ก็ไม่ได้กัน XSS ยิงคำขอในนามผู้ใช้ได้อยู่ดี (แค่อ่านค่าไม่ได้)

> [!ASK]
> **ถาม:** `?api=` ใน `config.js` มีไว้ทำไม แล้วทำไมจำกัดเฉพาะ localhost
> **ตอบ:** ตอนพัฒนาเว็บรันที่ `127.0.0.1:5500` แต่ Backend รันที่ `:3000` จึงต้องบอกว่า API อยู่ไหน ใส่ `?api=http://127.0.0.1:3000/api` ครั้งเดียวแล้วจำใน localStorage แต่ถ้ายอมรับ `?api=` บนโดเมนจริง ผู้โจมตีส่งลิงก์ที่ต่อท้าย `?api=https://เว็บของเขา/api` เบราว์เซอร์จะจำไว้ และส่งรหัสผ่านไปเว็บของเขาทุกครั้งที่ล็อกอิน (หน้าเว็บเป็นของจริง HTTPS ถูกต้อง เหยื่อไม่ระแวง) จึงรับค่านี้เฉพาะเมื่อ hostname เป็น localhost/127.0.0.1/::1 และบนโดเมนจริงยังลบค่าเก่าที่อาจถูกฝังไว้ทุกครั้งที่โหลด

> [!ASK]
> **ถาม:** ทำไมใช้ polling ไม่ใช้ WebSocket ข้อมูลช้าแค่ไหน
> **ตอบ:** Backend ปัจจุบันไม่มีช่องผลักข้อมูลออกมา การเพิ่ม WebSocket ต้องแก้ทั้ง Express, Caddy (proxy) และ Docker ซึ่งเสี่ยงเกินประโยชน์ในระบบขนาด 15 บอร์ด `store.js` ถามข้อมูลสด/ห้องทุก 10 วินาที แจ้งเตือนทุก 30 วินาที สรุปค่าไฟทุก 2 นาที (ค่าใน `config.js` `POLL`) จึงช้าได้ประมาณ 10–15 วินาที ซึ่งพอสำหรับการดูค่าไฟและสถานะแอร์ แท็บที่ถูกซ่อนจะหยุดถามและถามใหม่ทันทีเมื่อกลับมาดู และมีปุ่มรีเฟรชบนแถบบน

> [!ASK]
> **ถาม:** ซ่อนปุ่มของแอดมินในหน้าเว็บ เจ้าหน้าที่แก้ JavaScript เปิดปุ่มเองได้ไหม ปลอดภัยหรือ
> **ตอบ:** ซ่อนปุ่มเป็นแค่ความสะดวก ไม่ใช่ความปลอดภัย (`adminOnly`, `isAdmin` ในหน้าต่าง ๆ) ถึงเปิดปุ่มได้ คำขอที่ส่งไปจะถูก Backend ตรวจสิทธิ์ใหม่ด้วย `requireAdmin` จากโทเคนทุกครั้งและตอบปฏิเสธ ความปลอดภัยจริงอยู่ที่เซิร์ฟเวอร์เสมอ

> [!ASK]
> **ถาม:** เว็บนี้เป็น SPA สลับหน้ายังไง ทำไมใช้ `#` ใน URL
> **ตอบ:** `index.html` โหลดครั้งเดียว `app.js` อ่านส่วนหลัง `#` (เช่น `#/rooms`) หาหน้าใน `VIEWS` แล้วเรียก `mount()` ของหน้านั้นลงใน `#viewRoot` และเรียก `destroy()` ของหน้าเก่า ฟัง event `hashchange` จึงรองรับปุ่ม Back/Forward ใช้ hash เพราะเสิร์ฟเป็นไฟล์ static: ถ้าใช้ path จริง `/rooms` แล้วกด F5 Caddy จะหาไฟล์ `rooms` ไม่เจอและตอบ 404 ส่วนข้อความหลัง `#` เบราว์เซอร์ไม่ส่งไปเซิร์ฟเวอร์ จึงไม่ต้องตั้ง rewrite ใน Caddyfile

> [!ASK]
> **ถาม:** ถ้าใครตั้งชื่อวิชาเป็น `<script>alert(1)</script>` จะเกิดอะไรขึ้น
> **ตอบ:** ไม่เกิดอะไร ชื่อวิชาจะแสดงเป็นตัวอักษร `<script>alert(1)</script>` ตรง ๆ เพราะ `el('div', { text: item.subjectName })` ใช้ `textContent` ซึ่งเบราว์เซอร์ไม่ตีความเป็น HTML ต่อให้โค้ดชั้นนั้นพลาด CSP ก็บล็อกสคริปต์ที่ไม่ได้มาจากไฟล์บนโดเมนเราอยู่ดี

> [!ASK]
> **ถาม:** deploy เว็บใหม่แล้วทำไมบางคนยังเห็นหน้าเก่า และคุณรับมืออย่างไร
> **ตอบ:** Caddy ให้เบราว์เซอร์แคชไฟล์ใน `/assets/` ได้ 1 ชั่วโมง (`max-age=3600`) เพื่อความเร็ว แต่ `index.html` ตั้ง `no-cache` จึงได้เลขเวอร์ชัน `?v=` ใหม่เสมอ ซึ่งบังคับโหลด CSS 4 ไฟล์และ `main.js` ใหม่ แต่โมดูลที่ถูก import ต่อไม่มี `?v=` จึงอาจค้างในแคชได้ถึง 1 ชั่วโมง เราจึงออกแบบให้ทนไฟล์เก่า-ใหม่ปน: ไม่เพิ่ม export ใหม่ในไฟล์เดิม (สร้างไฟล์ใหม่ เช่น `theme.js` `icons-ui.js`), เช็ก `typeof api.xxx === 'function'` ก่อนเรียก, และถ้ายังเห็นของเก่าให้กด Ctrl+F5 หนึ่งครั้ง

> [!ASK]
> **ถาม:** นาฬิกานับถอยหลังปิดแอร์เดินในเบราว์เซอร์ ถ้านาฬิกาเครื่องผู้ใช้เพี้ยนจะเป็นอย่างไร ใครเป็นคนสั่งปิดจริง
> **ตอบ:** เซิร์ฟเวอร์ส่งเวลาเส้นตาย `autoOffDeadlineAt` มา เบราว์เซอร์เอามาลบกับ `Date.now()` ของเครื่องแล้วนับถอยหลังเอง (`rooms.js` `countdownStrip`) ไม่ถามเซิร์ฟเวอร์ทุกวินาทีเพราะเส้นตายเป็นค่าคงที่ ถ้านาฬิกาเครื่องผู้ใช้เพี้ยน ตัวเลขบนจอก็เพี้ยนตาม แต่เป็นแค่การแสดงผล คนที่ตัดสินใจและสั่งปิดจริงคือ Backend (ระบบปิดอัตโนมัติ) ตามเวลาของเซิร์ฟเวอร์ และถ้าเลยเส้นตายแล้วหน้าจอจะเปลี่ยนเป็น "กำลังส่งคำสั่งปิด" แทนค้างที่ 00:00

> [!ASK]
> **ถาม:** หน้าเฟิร์มแวร์รู้ได้อย่างไรว่าบอร์ดอัปเดตสำเร็จ ในเมื่อ HTTP ตอบกลับทันทีตั้งแต่ส่งคำสั่ง
> **ตอบ:** คำตอบ HTTP แค่บอกว่า Backend ส่งคำสั่ง OTA เข้า MQTT แล้ว บอร์ดยังต้องดาวน์โหลดไฟล์ รีบูต และต่อ MQTT ใหม่อีก 1–2 นาที หน้าเว็บจึงจดบอร์ดนั้นไว้ใน `pending` พร้อมรุ่นเป้าหมาย เวลาเริ่ม และ `otaError` เดิม แล้วทุกครั้งที่ polling นำข้อมูลแอร์ชุดใหม่มา (`state.airConditioners` ทุก 10 วินาที) `settlePending()` จะเช็ก 3 ทาง: `firmwareVersion` เท่ากับรุ่นเป้าหมาย = สำเร็จ, มี `otaError` ใหม่ที่ไม่ใช่ค่าเดิม = ล้มเหลว, เกิน 5 นาที = ถือว่าไม่สำเร็จ (บอร์ดใช้รุ่นเดิมต่อ) เก็บ `otaError` เดิมไว้เทียบเพราะถ้าบอร์ดเคยพังครั้งก่อน ข้อความเก่าจะทำให้ตัดสินผิดว่าครั้งนี้ก็พัง

> [!ASK]
> **ถาม:** ถ้าแอดมินอัปโหลดไฟล์เซ็นเซอร์เข้าไปในแท็บแอร์ หรือสั่งไฟล์แอร์ IR ให้บอร์ดสายแอร์ จะเกิดอะไรขึ้น
> **ตอบ:** ถูกกันไว้ 3 ชั้น ชั้นแรกหน้าเว็บ: `handleFile` อ่านชนิดจากชื่อไฟล์ (`occ` = เซ็นเซอร์, `wired`/`slm8` = สายแอร์) ถ้าไม่ตรงแท็บจะแจ้งให้ไปอัปโหลดในแท็บที่ถูก และแต่ละแท็บแสดงเฉพาะไฟล์และบอร์ดของชนิดนั้น จึงเลือกผิดไม่ได้ ชั้นสองตอนอัปโหลด: เว็บส่ง `?kind=` ไปด้วย Backend ตอบ 400 ถ้าชื่อไฟล์บอกชนิดอื่น ชั้นสามตอนสั่งบอร์ด: route `/ota` ของ Backend เช็กชนิดไฟล์กับโปรโตคอลของบอร์ดอีกครั้ง ที่ต้องเข้มขนาดนี้เพราะถ้าบอร์ดได้โปรแกรมผิดชนิด มันจะรีบูตเป็นบอร์ดอีกแบบที่ขาต่อและหัวข้อ MQTT ไม่ตรงกับฮาร์ดแวร์ ต้องไปเสียบ USB แก้ที่หน้างาน

> [!ASK]
> **ถาม:** บนหน้าเว็บ แอร์ Daikin แบบต่อสาย กับแอร์ IR ต่างกันอย่างไร
> **ตอบ:** ต่างที่ชิปและปุ่ม ชิปบนการ์ดแอร์บอก "Daikin · สายแอร์" หรือ "<ยี่ห้อ> · รีโมต IR" (`airBrand` + `controlTypeLabel` ใน `format.js`) ส่วนปุ่ม `limitsFor` ของบอร์ดสายแอร์คืนเฉพาะสิ่งที่รีโมตติดผนัง Daikin ทำได้: โหมด cool/dry/fan, พัดลม auto/low/medium/high (ไม่มี turbo), ทิศลม auto/off, ฟังก์ชันเสริมมีแค่ Sleep และไม่มีในโหมด Dry หน้าเว็บจึงไม่แสดงปุ่มที่กดไปแล้วเซิร์ฟเวอร์จะปฏิเสธ และ `fitDraft` ปรับค่าที่ร่างค้างไว้ (เช่น พัดลม turbo) ให้อยู่ในขอบเขตก่อนส่ง

> [!ASK]
> **ถาม:** Arduino IDE ส่งออกไฟล์ชื่อ `rmutt_esp32_air.ino.bin` ไม่มีเลขรุ่น หน้าเฟิร์มแวร์รู้รุ่นได้อย่างไร (เพิ่ม 14 ต.ค. 2569)
> **ตอบ:** `handleFile` เรียก `versionOfFileName` ถ้าชื่อไม่มีรูปแบบ `-x.y.z.bin` จะเปิดฟอร์มถามรุ่น (แนะนำให้ดู `FIRMWARE_VERSION` ในโค้ดหรือบรรทัด "Firmware:" ใน Serial Monitor) ตรวจรูปแบบ `2.5.1` หรือ `2.5.2-slm8` แล้วตั้งชื่อใหม่เป็น `rmutt_esp32_air-2.5.1.bin` ก่อนอัปโหลด ทุกไฟล์บนเซิร์ฟเวอร์จึงมีรุ่นในชื่อเสมอ ทั้งตาราง "ต้องอัปเดต" และการเช็กว่าอัปเดตสำเร็จพึ่งชื่อนี้ ควรพิมพ์ให้ตรงกับ `FIRMWARE_VERSION` ทุกตัวอักษร ไม่งั้นป้าย "กำลังอัปเดต" จะไม่จบด้วย toast สำเร็จ

> [!ASK]
> **ถาม:** หน้าเฟิร์มแวร์ตัดสินว่าบอร์ด "ยังเก่า" อย่างไร ทำไมไม่เทียบรุ่นเป็นข้อความ (เพิ่ม 14 ต.ค. 2569)
> **ตอบ:** `statusOf` เทียบ `firmwareVersion` ที่บอร์ดรายงานกับรุ่นของไฟล์ล่าสุดในแท็บด้วย `compareVersions` ซึ่งแยกเลขสามส่วนหน้าเป็นตัวเลขแล้วเทียบทีละส่วน เพราะถ้าเทียบเป็นข้อความ `'2.5.10'` จะน้อยกว่า `'2.5.9'` ส่วนท้ายอย่าง `-slm8` ไม่นับเพราะบอกชนิด ไม่ใช่ลำดับ แต่สถานะอื่นมาก่อน: กำลังอัปเดต → ตั้งค่าไม่เสร็จ → ออฟไลน์ → ไม่มีไฟล์ แล้วจึงเป็นล่าสุด/ยังเก่า มีแค่บอร์ด "ยังเก่า" ที่ติ๊กเลือกและกดอัปเดตได้

## สรุปและเช็กลิสต์ความเข้าใจ

ถ้าตอบข้อเหล่านี้ได้ แปลว่าเข้าใจบทนี้แล้ว

- [ ] อธิบายได้ว่าเว็บแอปคุยกับใคร (Backend ที่ `/api/*` อย่างเดียว) และ Caddy ทำอะไร (เสิร์ฟไฟล์ static + ส่ง `/api/*` ต่อ + ใส่หัวความปลอดภัย + กำหนดแคช)
- [ ] เล่าลำดับบูตได้: `index.html` → `main.js` (applyPrefs, applyTheme, startClock, startApp) → login หรือ `enterApp` → `navigate` → `bootstrap` → `startPolling`
- [ ] อธิบายสัญญาของหน้าใน `views/` (`title`, `subtitle`, `adminOnly`, `mount`, `update`, `destroy`) และเหตุผลที่แยก mount กับ update
- [ ] อธิบายได้ว่าทำไมทุกคำขอต้องผ่าน `api.js` และ 401 ถูกจัดการอย่างไร (ล้างโทเคน → handler → กลับหน้าล็อกอิน)
- [ ] อธิบาย `state`, `subscribe`, `emit` และทำไม `emit` ใช้ `queueMicrotask`
- [ ] บอกค่า `POLL` (10 / 10 / 30 / 120 วินาที) และว่าทำไมแท็บที่ซ่อนจึงหยุดถาม
- [ ] อธิบาย `?api=` แบบทีละบรรทัดและช่องโหว่ที่กัน (credential ถูกส่งไปเว็บของผู้โจมตี)
- [ ] ยกตัวอย่าง XSS และอธิบายว่า `textContent` / `el()` / CSP กันอย่างไร และ `innerHTML` ในโปรเจกต์ใช้กับอะไรเท่านั้น
- [ ] อธิบายสถาปัตยกรรม CSS 4 ชั้น และธีมทำงานผ่าน `data-palette` + custom properties
- [ ] บอกได้ว่าหน้าไหนเป็นแอดมินเท่านั้น (`devices`, `firmware`, `users`) และส่วนไหนในหน้าอื่นที่เฉพาะแอดมิน (นำเข้า/ล้างตาราง, แก้อัตราค่าไฟ, สวิตช์รวมปิดอัตโนมัติ, ปุ่มบางอันในรีโมต)
- [ ] อธิบายทำไมต้องมีทั้ง Flutter กับเว็บ
- [ ] อธิบายขั้นตอน `deploy-web.ps1` และทำไมต้อง "คัดลอกเข้า" `www` เดิมแทน `mv`
- [ ] อธิบายแคช: `/assets/*` 1 ชั่วโมง, `index.html` `no-cache`, `?v=` และผลข้างเคียงที่ต้องออกแบบรับมือ
- [ ] อธิบายว่าทำไมการซ่อนปุ่มตามสิทธิ์ไม่ใช่ความปลอดภัยจริง
- [ ] (เพิ่ม 14 ต.ค. 2569) อธิบายหน้าเฟิร์มแวร์ได้: 3 แท็บตามชนิดบอร์ด, ชนิด/รุ่นอ่านจากชื่อไฟล์, อัปโหลดเป็นไฟล์ดิบ + `X-File-Name` + `?kind` + `?replace=1`, สถานะบอร์ด 6 แบบจาก `statusOf`, และการติดตามผลด้วย `pending` + `settlePending` + 5 นาที
- [ ] (เพิ่ม 14 ต.ค. 2569) บอกลำดับสถานะใน `statusOf` (updating → notready → offline → nofile → uptodate/outdated) และอธิบายได้ว่าทำไม `compareVersions` ต้องเทียบเป็นตัวเลข และทำไมต้องถามรุ่นเมื่อชื่อไฟล์จาก Arduino IDE ไม่มีรุ่น
- [ ] อธิบายได้ว่าตารางบอร์ดกลายเป็นการ์ดบนมือถือด้วย CSS grid อย่างไร และแถบ `.fw-bar` ค้างล่างจออย่างไร
- [ ] (เพิ่ม 11 ต.ค. 2569) อธิบายได้ว่าเว็บแสดงยี่ห้อ/วิธีควบคุมแอร์จากโปรโตคอลอย่างไร (`airBrand`, `controlTypeLabel`, `airControlSummary`) และทำไมการ์ดแอร์สายแอร์มีปุ่มน้อยกว่า (`limitsFor`, `fitDraft`)
