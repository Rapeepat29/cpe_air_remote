import { pool } from '../src/db.js';

// v3.14.0 — เก็บรุ่นเฟิร์มแวร์และผลการอัปเดตผ่าน Wi-Fi (OTA) ของบอร์ด
// ปลอดภัยที่จะรันซ้ำ คอลัมน์ที่มีอยู่แล้วจะข้ามไป

const columns = [
  ['firmware_version', 'VARCHAR(20) NULL'],
  ['ota_error', 'VARCHAR(120) NULL'],
];

try {
  for (const table of ['air_conditioners', 'occupancy_sensors']) {
    const existing = await pool.query(
      `SELECT COLUMN_NAME
         FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = ?`,
      [table],
    );
    const present = new Set(existing.map((row) => row.COLUMN_NAME));
    for (const [name, definition] of columns) {
      if (present.has(name)) continue;
      await pool.query(
        `ALTER TABLE ${table} ADD COLUMN ${name} ${definition} AFTER last_seen_at`,
      );
      console.log(`เพิ่มคอลัมน์ ${table}.${name} แล้ว`);
    }
  }
  console.log('คอลัมน์เฟิร์มแวร์ครบแล้ว');
} finally {
  await pool.end();
}
