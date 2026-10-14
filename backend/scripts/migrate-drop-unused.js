import { pool } from '../src/db.js';

// เอาส่วนที่โค้ดไม่ได้ใช้แล้วออกจากฐานข้อมูล (14 ต.ค. 2569)
//
// 1. สถานะ 'removed' ของ air_conditioners / occupancy_sensors
//    รุ่นปัจจุบันถอดอุปกรณ์ด้วยการลบแถวจริง ไม่ตั้ง 'removed' แล้ว
//    แถว 'removed' ที่ค้างจากรุ่นเก่าเป็นอุปกรณ์ที่ถูกถอดไปแล้ว จึงลบทิ้ง
//    แล้วเหลือ ENUM แค่ 'reserved' กับ 'active'
// 2. คอลัมน์ rooms.is_active
//    ทุก query เคยกรอง is_active = TRUE แต่ไม่มีโค้ดไหนตั้งเป็น FALSE
//    (ลบห้อง = ลบแถวจริง) ห้องที่ is_active = FALSE (ถ้ามี ต้องมีคนแก้ด้วย SQL เอง)
//    คือห้องที่ถูกซ่อน ลบทิ้งถ้าไม่มีอะไรผูกอยู่ ถ้ายังมีแอร์ เซ็นเซอร์ หรือ
//    ตารางเรียนผูกอยู่ จะไม่ลบคอลัมน์และบอกให้ผู้ดูแลจัดการก่อน
//
// ปลอดภัยที่จะรันซ้ำ ส่วนที่ทำไปแล้วจะข้าม
// ดูก่อนว่าจะทำอะไร (ไม่แก้อะไร):  node scripts/migrate-drop-unused.js --dry-run
//
// ลำดับตอนอัปเดตเซิร์ฟเวอร์: Backend รุ่นใหม่ขึ้นก่อน (ไม่อ้างถึงสองอย่างนี้แล้ว)
// แล้วสคริปต์นี้จึงรัน (ดู deploy/update-remote.sh) ถ้ารันกับ Backend รุ่นเก่า
// คำสั่งที่ยังกรอง is_active จะพัง

const dryRun = process.argv.includes('--dry-run');
const DEVICE_TABLES = ['air_conditioners', 'occupancy_sensors'];
let pendingRoomsColumn = false;

try {
  if (dryRun) console.log('[dry-run] แสดงสิ่งที่จะทำ ไม่แก้ฐานข้อมูล');

  for (const table of DEVICE_TABLES) {
    await dropRemovedStatus(table);
  }
  await dropRoomsIsActive();

  if (dryRun) console.log('[dry-run] จบ');
  else if (pendingRoomsColumn) console.log('เก็บกวาดแล้วบางส่วน: rooms.is_active ยังอยู่ (ดูข้อความด้านบน) ระบบทำงานได้ตามปกติ');
  else console.log('เก็บกวาดส่วนที่ไม่ใช้แล้วเรียบร้อย');
} finally {
  await pool.end();
}

async function dropRemovedStatus(table) {
  const columnType = await readColumnType(table, 'provision_status');
  if (columnType == null) {
    console.log(`[ข้าม] ยังไม่มีตาราง ${table}`);
    return;
  }
  if (!columnType.includes("'removed'")) {
    console.log(`[ครบ] ${table}.provision_status ไม่มี 'removed' แล้ว`);
    return;
  }

  const rows = await pool.query(
    `SELECT device_id, room_number
       FROM ${table}
      WHERE provision_status = 'removed'`,
  );
  if (rows.length > 0) {
    const list = rows
      .map((row) => `${row.device_id} (ห้อง ${row.room_number})`)
      .join(', ');
    console.log(`${table}: แถว 'removed' ${rows.length} แถว: ${list}`);
  }

  if (dryRun) {
    console.log(
      `[dry-run] จะลบ ${rows.length} แถวข้างบน แล้วเปลี่ยน `
        + `${table}.provision_status เป็น ENUM('reserved','active')`,
    );
    return;
  }

  if (rows.length > 0) {
    const result = await pool.query(
      `DELETE FROM ${table} WHERE provision_status = 'removed'`,
    );
    console.log(`ลบแถว 'removed' ของ ${table} แล้ว ${Number(result.affectedRows ?? 0)} แถว`);
  }
  await pool.query(
    `ALTER TABLE ${table}
       MODIFY provision_status ENUM('reserved', 'active')
         NOT NULL DEFAULT 'reserved'`,
  );
  console.log(`เปลี่ยน ${table}.provision_status เหลือ 'reserved', 'active' แล้ว`);
}

async function dropRoomsIsActive() {
  if ((await readColumnType('rooms', 'room_number')) == null) {
    console.log('[ข้าม] ยังไม่มีตาราง rooms');
    return;
  }
  if ((await readColumnType('rooms', 'is_active')) == null) {
    console.log('[ครบ] rooms ไม่มีคอลัมน์ is_active แล้ว');
    await ensureRoomsOrderIndex();
    return;
  }

  const hidden = await pool.query(
    `SELECT r.room_number,
            (SELECT COUNT(*) FROM air_conditioners a
              WHERE a.room_number = r.room_number) AS air_count,
            (SELECT COUNT(*) FROM occupancy_sensors o
              WHERE o.room_number = r.room_number) AS sensor_count,
            (SELECT COUNT(*) FROM class_schedules s
              WHERE s.room_number = r.room_number) AS schedule_count
       FROM rooms r
      WHERE r.is_active = FALSE`,
  );
  const blocked = hidden.filter((row) => (
    Number(row.air_count) + Number(row.sensor_count) + Number(row.schedule_count)
  ) > 0);
  if (blocked.length > 0) {
    // ห้องที่ซ่อนอยู่แต่ยังมีของผูก ถ้าลบคอลัมน์ ห้องเหล่านี้จะโผล่กลับมาในแอป
    // ให้คนตัดสินใจเองว่าจะเปิดใช้คืนหรือถอดของออกแล้วลบห้อง
    console.log('[ยังไม่ลบ rooms.is_active] มีห้องที่ถูกซ่อน (is_active = FALSE) แต่ยังมีของผูกอยู่:');
    for (const row of blocked) {
      console.log(
        `  ห้อง ${row.room_number}: แอร์ ${row.air_count} เครื่อง, `
          + `เซ็นเซอร์ ${row.sensor_count} ตัว, ตารางเรียน ${row.schedule_count} คาบ`,
      );
    }
    console.log(
      '  แก้ได้สองทาง: เปิดห้องคืนด้วย UPDATE rooms SET is_active = TRUE '
        + 'WHERE room_number = ... หรือถอดอุปกรณ์/ลบตารางของห้องนั้นก่อน แล้วรันสคริปต์นี้ใหม่',
    );
    pendingRoomsColumn = true;
    return;
  }

  const removable = hidden.map((row) => row.room_number);
  if (removable.length > 0) {
    console.log(
      `ห้องที่ถูกซ่อนและไม่มีอะไรผูก ${removable.length} ห้อง: ${removable.join(', ')}`,
    );
  }
  if (dryRun) {
    console.log(
      `[dry-run] จะลบห้องข้างบน (การจองของห้องเหล่านี้ถูกลบตาม) `
        + 'แล้วลบคอลัมน์ rooms.is_active และเปลี่ยน index เป็น idx_rooms_floor_order',
    );
    return;
  }

  if (removable.length > 0) {
    const result = await pool.query('DELETE FROM rooms WHERE is_active = FALSE');
    console.log(`ลบห้องที่ถูกซ่อนแล้ว ${Number(result.affectedRows ?? 0)} ห้อง`);
  }
  if (await indexExists('rooms', 'idx_rooms_floor_active')) {
    await pool.query('ALTER TABLE rooms DROP INDEX idx_rooms_floor_active');
  }
  await pool.query('ALTER TABLE rooms DROP COLUMN is_active');
  console.log('ลบคอลัมน์ rooms.is_active แล้ว');
  await ensureRoomsOrderIndex();
}

async function ensureRoomsOrderIndex() {
  if (await indexExists('rooms', 'idx_rooms_floor_order')) return;
  if (dryRun) {
    console.log('[dry-run] จะเพิ่ม index idx_rooms_floor_order');
    return;
  }
  await pool.query(
    `ALTER TABLE rooms
       ADD KEY idx_rooms_floor_order (floor_number, room_index, room_number)`,
  );
  console.log('เพิ่ม index idx_rooms_floor_order แล้ว');
}

async function readColumnType(table, column) {
  const rows = await pool.query(
    `SELECT COLUMN_TYPE
       FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ?
        AND COLUMN_NAME = ?`,
    [table, column],
  );
  return rows[0] ? String(rows[0].COLUMN_TYPE) : null;
}

async function indexExists(table, indexName) {
  const rows = await pool.query(
    `SELECT 1
       FROM information_schema.STATISTICS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = ?
        AND INDEX_NAME = ?
      LIMIT 1`,
    [table, indexName],
  );
  return rows.length > 0;
}
