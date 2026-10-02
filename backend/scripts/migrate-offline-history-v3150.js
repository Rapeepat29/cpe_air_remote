import { pool } from '../src/db.js';

// v3.15.0 — ข้อมูลไฟฟ้าย้อนหลังตอนบอร์ดเน็ตหลุด
// เพิ่มจุดต่อของประวัติไฟฟ้าและจำนวนรายการที่บอร์ดยังส่งไม่ครบ
// ปลอดภัยที่จะรันซ้ำ คอลัมน์ที่มีอยู่แล้วจะข้ามไป

const columns = [
  ['energy_chain_kwh', 'DECIMAL(12,3) NULL'],
  ['energy_chain_at', 'DATETIME NULL'],
  ['energy_chain_running', 'BOOLEAN NOT NULL DEFAULT FALSE'],
  ['history_pending', 'SMALLINT UNSIGNED NOT NULL DEFAULT 0'],
];

try {
  const existing = await pool.query(
    `SELECT COLUMN_NAME
       FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'air_conditioners'`,
  );
  const present = new Set(existing.map((row) => row.COLUMN_NAME));
  for (const [name, definition] of columns) {
    if (present.has(name)) continue;
    await pool.query(
      `ALTER TABLE air_conditioners ADD COLUMN ${name} ${definition} AFTER last_seen_at`,
    );
    console.log(`เพิ่มคอลัมน์ air_conditioners.${name} แล้ว`);
  }
  // เริ่มจุดต่อจากค่าล่าสุดที่มีอยู่ จะได้ต่อกับประวัติเดิมได้ทันที
  const result = await pool.query(
    `UPDATE air_conditioners
        SET energy_chain_kwh = energy_kwh,
            energy_chain_at = last_seen_at,
            energy_chain_running = ac_running
      WHERE energy_chain_at IS NULL AND last_seen_at IS NOT NULL`,
  );
  console.log(`ตั้งจุดต่อเริ่มต้น ${Number(result.affectedRows ?? 0)} เครื่อง`);
  console.log('คอลัมน์ข้อมูลย้อนหลังครบแล้ว');
} finally {
  await pool.end();
}
