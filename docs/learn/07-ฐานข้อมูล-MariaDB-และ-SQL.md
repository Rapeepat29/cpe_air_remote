# 07 · ฐานข้อมูล MariaDB และภาษา SQL

> ทุกอย่างที่ระบบ "จำ" อยู่ในฐานข้อมูล บทนี้สอนแนวคิด ภาษา SQL
> ตารางทั้ง 9 ของโปรเจกต์ และเครื่องมือดูแลฐานข้อมูล (init, migrate, doctor, backup)
> เหตุผลการออกแบบแต่ละคอลัมน์แบบละเอียด อยู่ใน `docs/study/01-database.md`

---

## 1. ฐานข้อมูลคืออะไร

**ฐานข้อมูลแบบตาราง (Relational Database)** = ชุดของ **ตาราง** เหมือน Excel หลายชีต
แต่ต่างจาก Excel ตรงที่
- มีกติกาเข้มงวด (คอลัมน์นี้ต้องเป็นตัวเลข, ห้ามว่าง, ห้ามซ้ำ)
- หลายโปรแกรมอ่าน/เขียนพร้อมกันได้โดยไม่พัง
- ค้นหาข้อมูลล้านแถวได้ในเสี้ยววินาที
- สั่งงานด้วยภาษา **SQL**

**MariaDB** = โปรแกรมฐานข้อมูล (แยกสายมาจาก MySQL ใช้คำสั่งเหมือนกันเกือบหมด)
- **Database** (ฐานข้อมูล) ของโปรเจกต์ชื่อ `rmutt_save_energy`
- ในนั้นมี **Table** (ตาราง) 9 ตาราง
- แต่ละตารางมี **Column** (คอลัมน์/ฟิลด์) และ **Row** (แถว/เรคคอร์ด)

```text
ตาราง rooms
┌─────────────┬──────────────┬────────────┬───────────────┬───────────┐
│ room_number │ floor_number │ room_index │ room_type     │ is_active │  ← คอลัมน์
├─────────────┼──────────────┼────────────┼───────────────┼───────────┤
│ 16101       │ 1            │ 1          │ Admin Office  │ 1         │  ← แถว
│ 16302       │ 3            │ 2          │ Storage Room  │ 1         │
└─────────────┴──────────────┴────────────┴───────────────┴───────────┘
```

---

## 2. ชนิดข้อมูล (Data Type) ที่ใช้ในโปรเจกต์

| ชนิด | ความหมาย | ตัวอย่างในโปรเจกต์ |
|---|---|---|
| `VARCHAR(n)` | ข้อความยาวไม่เกิน n ตัว | `username VARCHAR(100)` |
| `CHAR(n)` | ข้อความยาวเท่ากับ n เป๊ะ | `otp_hash CHAR(64)` (hash ยาว 64 เสมอ), `id CHAR(36)` (UUID) |
| `LONGTEXT` | ข้อความยาวมาก | `state_json` (เก็บ JSON สถานะแอร์) |
| `TINYINT UNSIGNED` | จำนวนเต็ม 0–255 | `floor_number`, `day_of_week` |
| `SMALLINT UNSIGNED` | 0–65,535 | `mqtt_port` |
| `INT UNSIGNED` | 0–4 พันล้าน | `token_version`, `runtime_seconds` |
| `DECIMAL(p,s)` | ทศนิยมแม่นยำ p หลัก มี s หลักหลังจุด | `voltage DECIMAL(8,2)` → 229.80, `energy_kwh DECIMAL(12,3)` |
| `BOOLEAN` | จริง/เท็จ (เก็บเป็น 1/0) | `is_online`, `ac_running` |
| `ENUM(...)` | เลือกได้เฉพาะค่าที่กำหนด | `role ENUM('admin','staff')` |
| `TIME` | เวลา ชม:นาที:วินาที | `start_time`, `daily_on` |
| `DATETIME` | วันที่+เวลา | `last_seen_at`, `bucket_start` |
| `TIMESTAMP` | คล้าย DATETIME แต่อิงเขตเวลา | `system_settings.updated_at` |

> 💡 ทำไมเงิน/ไฟฟ้าใช้ `DECIMAL` ไม่ใช้ `FLOAT`? FLOAT เก็บแบบประมาณ
> `0.1 + 0.2` อาจได้ `0.30000000000000004` ค่าไฟรวมหลายพันแถวจะคลาดเคลื่อน

### คุณสมบัติเพิ่มของคอลัมน์

| คำ | ความหมาย |
|---|---|
| `NOT NULL` | ห้ามว่าง |
| `NULL` | ว่างได้ (ไม่มีค่า ≠ 0 ≠ ข้อความว่าง) |
| `DEFAULT x` | ถ้าไม่ใส่ ใช้ค่า x |
| `DEFAULT CURRENT_TIMESTAMP` | ใส่เวลาปัจจุบันให้เอง |
| `ON UPDATE CURRENT_TIMESTAMP` | ทุกครั้งที่แถวถูกแก้ ใส่เวลาปัจจุบันให้เอง (ใช้กับ `updated_at`) |

---

## 3. Key — กุญแจของตาราง

### Primary Key (PK) — บัตรประชาชนของแถว
ค่าที่ **ไม่ซ้ำและไม่ว่าง** ใช้ระบุแถวหนึ่งแถว

| ตาราง | Primary Key |
|---|---|
| `users` | `username` |
| `rooms` | `room_number` |
| `air_conditioners` | `device_id` (เช่น `ESP32-AABBCCDDEEFF`) |
| `occupancy_sensors` | `device_id` (เช่น `OCC32-...`) |
| `class_schedules`, `password_reset_otps`, `system_alerts` | `id` (UUID สุ่ม) |
| `energy_hourly` | `(device_id, bucket_start)` — **PK สองคอลัมน์** = แอร์หนึ่งเครื่อง มีได้แถวเดียวต่อชั่วโมง |
| `system_settings` | `setting_key` |

### Unique Key — ห้ามซ้ำ
```sql
UNIQUE KEY uq_users_email (email)                         -- อีเมลห้ามซ้ำ
UNIQUE KEY uq_air_room_number (room_number, air_number)   -- ห้องเดียวกันมีแอร์หมายเลขซ้ำไม่ได้
```

### Foreign Key (FK) — ความสัมพันธ์ระหว่างตาราง
```sql
CONSTRAINT fk_air_conditioner_room
  FOREIGN KEY (room_number) REFERENCES rooms (room_number)
  ON UPDATE CASCADE
  ON DELETE RESTRICT
```
อ่านว่า: `air_conditioners.room_number` **ต้องมีอยู่จริง** ใน `rooms.room_number`
- `ON UPDATE CASCADE` = ถ้าเปลี่ยนเลขห้อง ให้แอร์เปลี่ยนตามอัตโนมัติ
- `ON DELETE RESTRICT` = **ห้ามลบห้อง** ถ้ายังมีแอร์อยู่ในห้องนั้น
- `ON DELETE CASCADE` (ใช้ใน `password_reset_otps`) = ลบผู้ใช้ แล้ว OTP ของเขาหายตามไปด้วย

### Index (KEY) — สารบัญช่วยค้นเร็ว
```sql
KEY idx_energy_hourly_room (room_number, bucket_start)
```
ทำให้คำสั่ง "หาค่าไฟของห้อง X ช่วงวันที่ Y" ไม่ต้องไล่ทุกแถว

---

## 4. แผนผังตารางทั้ง 9 ของโปรเจกต์

```text
┌──────────────┐ 1      n ┌──────────────────────┐
│ users        │─────────▶│ password_reset_otps  │  OTP ลืมรหัสผ่าน
│ PK username  │          │ FK username          │
└──────────────┘          └──────────────────────┘

┌──────────────┐ 1      n ┌──────────────────────┐
│ rooms        │─────────▶│ class_schedules      │  ตารางเรียนของห้อง
│ PK room_number│         │ FK room_number       │
│              │ 1      n ┌──────────────────────┐
│              │─────────▶│ air_conditioners     │  แอร์ (1 แถว = 1 ESP32)
│              │          │ PK device_id         │
│              │          │ FK room_number       │
│              │ 1      1 ┌──────────────────────┐
│              │─────────▶│ occupancy_sensors    │  เซ็นเซอร์ตรวจคน (ห้องละ 1)
└──────────────┘          │ FK room_number       │
                          └──────────────────────┘

┌──────────────────────┐    ┌──────────────────────┐    ┌───────────────────┐
│ energy_hourly        │    │ system_alerts        │    │ system_settings   │
│ PK device_id +       │    │ การแจ้งเตือน         │    │ ค่าตั้งทั้งระบบ     │
│    bucket_start      │    │ (ปิดอัตโนมัติสำเร็จ/  │    │ auto_off_enabled  │
│ ค่าไฟรายชั่วโมง       │    │  ล้มเหลว, มีคนนอกคาบ) │    │ electricity_rate  │
└──────────────────────┘    └──────────────────────┘    └───────────────────┘
```

### สรุปแต่ละตาราง

| ตาราง | เก็บอะไร | คอลัมน์ที่ควรรู้ |
|---|---|---|
| `users` | บัญชีผู้ใช้ | `password_hash` (bcrypt), `role` (admin/staff), `is_active`, `token_version` |
| `password_reset_otps` | OTP ที่ส่งทางอีเมล | `otp_hash`, `expires_at`, `attempts` (ผิดได้ 5), `used_at` |
| `rooms` | ห้อง | `room_number` เช่น `16302`, `floor_number`, `room_type` |
| `class_schedules` | คาบเรียน | `day_of_week` (0=อาทิตย์ 1=จันทร์ … 6=เสาร์), `start_time`, `end_time`, `subject_name` |
| `air_conditioners` | แอร์และบอร์ด | `provision_status` (reserved/active/removed), `protocol` (ยี่ห้อ IR), `is_online`, ค่า PZEM ล่าสุด (`voltage`, `power_watts`, `energy_kwh`...), `ac_running`, คอลัมน์ `auto_off_*` |
| `occupancy_sensors` | เซ็นเซอร์ | `is_online`, `radar_available`, `is_occupied`, `static_threshold` |
| `energy_hourly` | ถังค่าไฟรายชั่วโมง | `bucket_start` (ต้นชั่วโมง), `consumption_kwh`, `*_sum/min/max`, `runtime_seconds` |
| `system_alerts` | การแจ้งเตือน | `kind`, `status` (open/acknowledged/resolved) |
| `system_settings` | ค่าตั้ง | `setting_key`, `setting_value` |

> 💡 ทำไม `energy_hourly` เก็บ `voltage_sum` ไม่เก็บค่าเฉลี่ย?
> เพราะรวมหลายชั่วโมงเป็นวันได้ถูกต้อง: เฉลี่ยทั้งวัน = Σsum ÷ Σsample_count
> (เฉลี่ยของค่าเฉลี่ย ผิดเมื่อจำนวนตัวอย่างแต่ละชั่วโมงไม่เท่ากัน)

---

## 5. ภาษา SQL — สอนจากตัวอย่างจริงของโปรเจกต์

> เปิด HeidiSQL ต่อฐานข้อมูล (บท 04 หัวข้อ 6) แล้วกดแท็บ **Query**
> พิมพ์คำสั่ง แล้วกด **F9** (หรือปุ่ม ▶) เพื่อรัน
> หรือใช้บรรทัดคำสั่ง: `docker exec -it mariadb mariadb -uroot -p rmutt_save_energy`

### 5.1 SELECT — อ่านข้อมูล

```sql
-- ทุกคอลัมน์ ทุกแถว (* = ทุกคอลัมน์)
SELECT * FROM rooms;

-- เลือกบางคอลัมน์
SELECT room_number, room_type FROM rooms;

-- กรองด้วย WHERE
SELECT * FROM rooms WHERE floor_number = 3;

-- หลายเงื่อนไข
SELECT * FROM rooms WHERE floor_number = 2 AND room_type = 'Classroom';

-- เรียงลำดับ (ASC น้อย→มาก, DESC มาก→น้อย) และจำกัดจำนวน
SELECT * FROM rooms ORDER BY floor_number ASC, room_index ASC LIMIT 5;

-- ค้นแบบมีบางส่วน (% = อะไรก็ได้)
SELECT * FROM rooms WHERE room_type LIKE '%Lab%';

-- ค่าว่าง ต้องใช้ IS NULL ไม่ใช่ = NULL
SELECT device_id FROM air_conditioners WHERE last_seen_at IS NULL;
```

คำสั่งจริงจาก Backend (`routes/public.js`) — หาเบอร์แอดมินสำหรับปุ่ม "ติดต่อแอดมิน"

```sql
SELECT first_name, last_name, username, phone
  FROM users
 WHERE role = 'admin'
   AND is_active = 1
   AND phone IS NOT NULL
   AND phone <> ''         -- <> แปลว่า "ไม่เท่ากับ"
 ORDER BY username ASC
 LIMIT 1;
```

### 5.2 ฟังก์ชันรวม (Aggregate) และ GROUP BY

```sql
-- นับแถว
SELECT COUNT(*) FROM air_conditioners WHERE provision_status = 'active';

-- จำนวนห้องแต่ละชั้น
SELECT floor_number, COUNT(*) AS rooms
  FROM rooms
 GROUP BY floor_number;

-- ค่าไฟรวมรายวันของทั้งอาคาร 7 วันล่าสุด
SELECT DATE(bucket_start) AS day,
       ROUND(SUM(consumption_kwh), 3) AS kwh
  FROM energy_hourly
 WHERE bucket_start >= CURDATE() - INTERVAL 7 DAY
 GROUP BY DATE(bucket_start)
 ORDER BY day;

-- ห้องที่ใช้ไฟมากที่สุดเดือนนี้
SELECT room_number, ROUND(SUM(consumption_kwh), 2) AS kwh
  FROM energy_hourly
 WHERE bucket_start >= DATE_FORMAT(CURDATE(), '%Y-%m-01')
 GROUP BY room_number
 ORDER BY kwh DESC
 LIMIT 5;
```

| ฟังก์ชัน | ทำอะไร |
|---|---|
| `COUNT(*)` | นับแถว |
| `SUM(x)` / `AVG(x)` | ผลรวม / ค่าเฉลี่ย |
| `MIN(x)` / `MAX(x)` | ต่ำสุด / สูงสุด |
| `ROUND(x, n)` | ปัดทศนิยม n ตำแหน่ง |
| `DATE(dt)` | ตัดเอาแค่วันที่ |
| `CURDATE()` / `NOW()` | วันนี้ / ตอนนี้ |
| `AS ชื่อ` | ตั้งชื่อเล่นให้ผลลัพธ์ |

### 5.3 JOIN — รวมข้อมูลจากหลายตาราง

```sql
-- แอร์ทุกเครื่อง พร้อมชั้นและชนิดของห้อง
SELECT a.device_id, a.name, a.room_number, r.floor_number, r.room_type,
       a.is_online, a.power_watts
  FROM air_conditioners AS a
  JOIN rooms AS r ON r.room_number = a.room_number
 WHERE a.provision_status = 'active'
 ORDER BY r.floor_number, a.room_number, a.air_number;

-- ห้องที่แอร์เปิดอยู่ แต่เซ็นเซอร์บอกว่าไม่มีคน
SELECT a.room_number, a.name, a.power_watts, o.is_occupied
  FROM air_conditioners a
  JOIN occupancy_sensors o ON o.room_number = a.room_number
 WHERE a.ac_running = 1
   AND o.is_occupied = 0
   AND o.provision_status = 'active';

-- LEFT JOIN = เอาห้องทุกห้อง แม้ไม่มีแอร์ (ห้องที่ไม่มีแอร์จะได้ NULL)
SELECT r.room_number, COUNT(a.device_id) AS air_count
  FROM rooms r
  LEFT JOIN air_conditioners a
         ON a.room_number = r.room_number AND a.provision_status <> 'removed'
 GROUP BY r.room_number;
```

- `AS a` = ตั้งชื่อย่อให้ตาราง (เขียน `AS` หรือไม่เขียนก็ได้)
- `JOIN ... ON` = จับคู่แถวที่เงื่อนไขตรงกัน
- `LEFT JOIN` = ตารางซ้ายมาครบทุกแถว

### 5.4 INSERT — เพิ่มข้อมูล

```sql
INSERT INTO rooms (room_number, floor_number, room_index, room_type, created_by, updated_by)
VALUES ('16399', 3, 99, 'Classroom', 'me', 'me');

-- ถ้าซ้ำ PK ให้ข้าม (ไม่ error) — ใช้ใน schema.sql
INSERT IGNORE INTO system_settings (setting_key, setting_value)
VALUES ('auto_off_enabled', 'true');

-- ถ้าซ้ำ ให้อัปเดตแทน — ใช้ใน scripts/seed-admin.js
INSERT INTO users (username, password_hash, email, role)
VALUES ('admin', '$2b$12$...', 'admin@example.com', 'admin')
ON DUPLICATE KEY UPDATE role = 'admin', is_active = 1;
```

### 5.5 UPDATE — แก้ข้อมูล

```sql
UPDATE rooms SET room_type = 'Laboratory' WHERE room_number = '16399';

-- บวกค่าเพิ่ม (ใช้จริงตอนเปลี่ยนรหัสผ่าน ทำให้ token เก่าใช้ไม่ได้)
UPDATE users SET token_version = token_version + 1 WHERE username = 'somchai';
```

> ⚠️ **UPDATE/DELETE โดยไม่มี WHERE = แก้/ลบทุกแถวทั้งตาราง**
> ฝึกนิสัย: เขียน `SELECT ... WHERE ...` ก่อนเพื่อดูว่าจะโดนแถวไหน แล้วค่อยเปลี่ยนเป็น UPDATE

### 5.6 DELETE — ลบข้อมูล

```sql
DELETE FROM rooms WHERE room_number = '16399';
```

ถ้าห้องมีแอร์อยู่ จะ error เพราะ FK `ON DELETE RESTRICT` — นี่คือการป้องกันที่ตั้งใจ

### 5.7 ดูโครงสร้างตาราง

```sql
SHOW DATABASES;
USE rmutt_save_energy;
SHOW TABLES;
DESCRIBE air_conditioners;           -- คอลัมน์และชนิด
SHOW CREATE TABLE air_conditioners;  -- คำสั่ง CREATE TABLE เต็ม
SHOW INDEX FROM energy_hourly;
```

### 5.8 Transaction — ทำหลายคำสั่งแบบ "ได้ทั้งหมดหรือไม่ได้เลย"

```sql
START TRANSACTION;
UPDATE users SET role = 'staff' WHERE username = 'a';
UPDATE users SET role = 'admin' WHERE username = 'b';
COMMIT;      -- ยืนยัน   (หรือ ROLLBACK; เพื่อยกเลิกทั้งหมด)
```

Backend ใช้ transaction ตอนเปลี่ยนสิทธิ์ผู้ใช้ พร้อม `SELECT ... FOR UPDATE` (ล็อกแถว)
เพื่อรับประกันว่า **ต้องเหลือแอดมินที่ใช้งานได้อย่างน้อย 1 คนเสมอ** แม้สองคนกดพร้อมกัน
ดูฟังก์ชัน `withTransaction()` ใน `backend/src/db.js`

---

## 6. SQL Injection และการใช้ `?` (สำคัญมาก)

**ผิด** — เอาข้อความจากผู้ใช้ต่อเข้า SQL ตรง ๆ

```javascript
pool.query(`SELECT * FROM users WHERE username = '${username}'`);
```

ถ้าผู้ใช้พิมพ์ชื่อว่า `' OR '1'='1` คำสั่งจะกลายเป็น
`SELECT * FROM users WHERE username = '' OR '1'='1'` → ได้ทุกแถว!

**ถูก** — ใช้ `?` แล้วส่งค่าแยก (parameter binding) ทุกที่ในโปรเจกต์ทำแบบนี้

```javascript
pool.query(
  'SELECT username, password_hash FROM users WHERE username = ? AND is_active = 1 LIMIT 1',
  [username],
);
```

ไลบรารีจะใส่ค่าให้อย่างปลอดภัย ไม่ว่าผู้ใช้จะพิมพ์อะไร

---

## 7. เครื่องมือดูแลฐานข้อมูลของโปรเจกต์ (`backend/scripts/`)

> 📁 ทุกคำสั่งรันที่โฟลเดอร์ `backend` และต้องตั้ง `DB_*` ใน `backend/.env` ให้ถูกก่อน

### 7.1 `npm run db:init` — สร้างตารางครั้งแรก
- อ่าน `database/schema.sql` ทั้งไฟล์ แล้วรันทีเดียว (`multipleStatements: true`)
- ใช้ `CREATE TABLE IF NOT EXISTS` → **รันซ้ำได้ ไม่ลบข้อมูลเดิม**
- ใส่ห้องตัวอย่าง (16101…) และคาบเรียนตัวอย่างด้วย `INSERT IGNORE`
- ถ้าขึ้น `Database schema initialized in "rmutt_save_energy".` = สำเร็จ

### 7.2 Migration — ปรับโครงสร้างฐานข้อมูลเก่าให้ทันรุ่นใหม่

**Migration** คือสคริปต์ที่ "อัปเกรด" ฐานข้อมูลที่มีข้อมูลอยู่แล้ว เช่นเพิ่มคอลัมน์ใหม่
โดย **ไม่ลบข้อมูลเดิม** ทุกตัวในโปรเจกต์ **ปลอดภัยที่จะรันซ้ำ** (ตรวจก่อนว่ามีแล้วหรือยัง)

ตัวอย่าง `scripts/migrate-pzem-v200.js`

```javascript
const columns = [
  ['energy_kwh', 'DECIMAL(12,3) NULL AFTER power_watts'],
  ...
];
const existing = await pool.query(
  `SELECT COLUMN_NAME FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'air_conditioners'`,
);                                        // (1) ดูว่าตอนนี้มีคอลัมน์อะไรบ้าง
const names = new Set(existing.map((row) => row.COLUMN_NAME));
for (const [name, definition] of columns) {
  if (names.has(name)) continue;          // (2) มีแล้ว ข้าม
  await pool.query(`ALTER TABLE air_conditioners ADD COLUMN ${name} ${definition}`);  // (3) เพิ่ม
  console.log(`Added air_conditioners.${name}`);
}
```

- `information_schema` = ฐานข้อมูลพิเศษที่บอกโครงสร้างของทุกตาราง
- `ALTER TABLE ... ADD COLUMN` = เพิ่มคอลัมน์ในตารางที่มีอยู่

รายการ migration ทั้งหมด

| คำสั่ง | เพิ่มอะไร |
|---|---|
| `npm run db:migrate:username` | เปลี่ยน `users` จากใช้ `id` เป็นใช้ `username` เป็น PK |
| `npm run db:migrate:schedules` | ตาราง `class_schedules` |
| `npm run db:migrate:air` | ตาราง `air_conditioners` |
| `npm run db:migrate:rooms` | ตาราง `rooms` (v1.8.0) |
| `npm run db:migrate:pzem` | คอลัมน์ค่าไฟ PZEM (v2.0.0) |
| `npm run db:migrate:occupancy` | ตาราง `occupancy_sensors` (v2.1.0) |
| `npm run db:migrate:energy` | ตาราง `energy_hourly` (v3.7.0) |
| `npm run db:migrate:autooff` | คอลัมน์ `auto_off_*` + ตาราง `system_alerts` (v3.8.0) |
| `npm run db:migrate:settings` | ตาราง `system_settings` + ค่าไฟเริ่มต้น (v3.10.0) |
| `npm run db:migrate:firmware` | คอลัมน์ `firmware_version`, `ota_error` (v3.14.0) |
| `npm run db:migrate:history` | คอลัมน์ข้อมูลย้อนหลังตอนเน็ตหลุด (v3.15.0) |

> 💡 ฐานข้อมูลใหม่เอี่ยม: แค่ `db:init` ก็พอ (schema.sql เป็นรุ่นล่าสุดแล้ว)
> ฐานข้อมูลเก่า: รัน migration ที่ขาด หรือใช้ `doctor --fix` ด้านล่าง

### 7.3 `npm run db:doctor` — หมอตรวจฐานข้อมูล

```powershell
npm run db:doctor               # ตรวจอย่างเดียว
node scripts/doctor.js --fix    # ตรวจ + ซ่อม
```

- อ่าน `schema.sql` → เทียบกับตารางจริงทีละคอลัมน์
- รายงานสถานะอุปกรณ์ (reserved/active) และสรุปข้อมูลค่าไฟ
- `--fix` สร้างตารางที่หาย และเพิ่มคอลัมน์ที่ขาด **ไม่ลบ ไม่แก้ของเดิม**
- ข้ามคอลัมน์ที่เป็น `NOT NULL` แต่ไม่มี `DEFAULT` (เพราะใส่ค่าให้แถวเดิมไม่ได้) แล้วบอกให้เติมเอง

> 💡 เวลาเจอ "เกิดข้อผิดพลาดภายในเซิร์ฟเวอร์" หลังอัปเดตโค้ด ให้ลอง `db:doctor` ก่อนเสมอ
> สาเหตุอันดับหนึ่งคือโค้ดใหม่ `SELECT` คอลัมน์ที่ฐานข้อมูลเก่ายังไม่มี

### 7.4 ใส่ผู้ใช้คนแรก (เลือก 1 วิธี)

**วิธี A** — สร้างแอดมินจาก `.env`

```env
SEED_ADMIN_USERNAME=admin
SEED_ADMIN_PASSWORD=รหัสอย่างน้อย8ตัว
SEED_ADMIN_EMAIL=you@example.com
SEED_ADMIN_PHONE=0800000000
```

```powershell
npm run seed:admin
```

รันซ้ำได้ ถ้ามีแล้วจะรีเซ็ตรหัสและบังคับเป็น admin + active (ใช้กู้แอดมินที่ลืมรหัสได้)

**วิธี B** — ย้ายจากตาราง `user` รุ่นเก่า

```powershell
npm run migrate:legacy
```

### 7.5 ตรวจการเชื่อมต่อจาก Backend

```powershell
npm start
# อีกหน้าต่าง
Invoke-RestMethod http://127.0.0.1:3000/api/health
```

`/api/health` รัน `SELECT 1` กับฐานข้อมูลจริง ถ้าต่อไม่ได้จะได้ 500

---

## 8. สำรองและกู้คืน (Backup / Restore)

### บนเครื่องตัวเอง (container ชื่อ mariadb)

```powershell
# สำรอง
docker exec mariadb mariadb-dump -uroot -p<รหัส> --single-transaction rmutt_save_energy > backup.sql

# กู้คืน
Get-Content backup.sql -Raw | docker exec -i mariadb mariadb -uroot -p<รหัส> rmutt_save_energy
```

- `mariadb-dump` = โปรแกรมส่งออกฐานข้อมูลเป็นไฟล์คำสั่ง SQL
- `--single-transaction` = อ่านข้อมูลชุดเดียวกันทั้งไฟล์โดยไม่ล็อกตาราง
- `>` = เขียนผลลัพธ์ลงไฟล์
- `-i` = ให้ container รับข้อมูลจาก pipe

> ⚠️ `-p<รหัส>` ต้องติดกัน ไม่มีเว้นวรรค และรหัสจะติดอยู่ในประวัติคำสั่ง
> ถ้าไม่อยากให้ติด ใช้ `-p` เฉย ๆ แล้วพิมพ์ตอนถาม (ใช้ได้กับ `-it` เท่านั้น)

หรือใช้ HeidiSQL: คลิกขวาที่ฐานข้อมูล → **Export database as SQL**

### บนเซิร์ฟเวอร์จริง
มี `deploy/backup-db.sh` รันอัตโนมัติทุกวัน 02:30 เก็บ 14 วัน (บท 14)

---

## 9. สรุปบท

- ฐานข้อมูล = ตาราง + คอลัมน์ + แถว, สั่งด้วย SQL
- PK ระบุแถว, FK ผูกตาราง, UNIQUE ห้ามซ้ำ, INDEX ค้นเร็ว
- `SELECT/INSERT/UPDATE/DELETE` + `WHERE` + `JOIN` + `GROUP BY` ครอบคลุมงาน 90%
- โค้ดใช้ `?` เสมอเพื่อกัน SQL injection
- `db:init` สร้างครั้งแรก, `db:migrate:*` อัปเกรด, `db:doctor --fix` ตรวจและซ่อม

## 🧪 แบบฝึกหัด (ทำใน HeidiSQL)

1. นับจำนวนห้องแต่ละชนิด (`room_type`)
2. หาคาบเรียนทั้งหมดของวันจันทร์ (`day_of_week = 1`) เรียงตามเวลาเริ่ม
3. เขียน JOIN แสดงชื่อวิชา + ชั้นของห้อง จาก `class_schedules` และ `rooms`
4. ลองเพิ่มห้อง `16399` ด้วย INSERT แล้วลบทิ้งด้วย DELETE
5. อธิบายว่าทำไมลบห้องที่มีแอร์ไม่ได้ และจะลบให้ได้ต้องทำอะไรก่อน
6. รัน `npm run db:doctor` แล้วอ่านรายงานทีละบรรทัด

ถัดไป: **บท 08 Backend Node.js + Express**
