#!/usr/bin/env node
// สร้างตาราง system_settings สำหรับค่าตั้งระดับระบบ
//
// v3.10.0 — สวิตช์รวมของระบบปิดแอร์อัตโนมัติ (auto_off_enabled)
// v3.13.0 — อัตราค่าไฟต่อ kWh ที่เว็บแอปและแอปมือถือใช้ร่วมกัน
//            (electricity_rate)
//
// รันซ้ำได้ ถ้ามีตารางหรือค่าอยู่แล้วจะข้ามให้เอง ไม่ทับค่าที่คนตั้งไว้
import { pool } from '../src/db.js';

const CREATE_TABLE = `
CREATE TABLE IF NOT EXISTS system_settings (
  setting_key VARCHAR(64) NOT NULL PRIMARY KEY,
  setting_value VARCHAR(255) NOT NULL,
  updated_by VARCHAR(64) NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci`;

// ค่าเริ่มต้นของแต่ละคีย์
//
// ใช้ INSERT IGNORE ทุกตัว เพื่อให้สคริปต์นี้รันซ้ำได้ทุกครั้งที่ deploy
// โดยไม่ทับค่าที่แอดมินตั้งไว้ — ถ้าใช้ REPLACE หรือ ON DUPLICATE KEY UPDATE
// การอัปเดตเซิร์ฟเวอร์ครั้งถัดไปจะรีเซ็ตอัตราค่าไฟกลับเป็นค่าโรงงานเงียบ ๆ
const SEEDS = [
  ['auto_off_enabled', 'true', 'สวิตช์รวมของระบบปิดแอร์อัตโนมัติ'],
  ['electricity_rate', '4.50', 'อัตราค่าไฟ (บาทต่อ kWh)'],
];

async function main() {
  await pool.query(CREATE_TABLE);
  console.log('ตาราง system_settings พร้อมแล้ว');

  for (const [key, value, description] of SEEDS) {
    const result = await pool.query(
      `INSERT IGNORE INTO system_settings (setting_key, setting_value, updated_by)
       VALUES (?, ?, NULL)`,
      [key, value],
    );
    const inserted = Number(result?.affectedRows ?? 0);
    console.log(
      inserted > 0
        ? `ตั้งค่าเริ่มต้น ${key} = ${value} (${description})`
        : `มีค่า ${key} อยู่แล้ว ไม่แตะของเดิม`,
    );
  }

  const rows = await pool.query(
    'SELECT setting_key, setting_value, updated_by FROM system_settings',
  );
  for (const row of rows) {
    console.log(
      `  ${row.setting_key} = ${row.setting_value}` +
        (row.updated_by ? ` (แก้ล่าสุดโดย ${row.updated_by})` : ''),
    );
  }
}

main()
  .then(() => pool.end())
  .then(() => process.exit(0))
  .catch(async (error) => {
    console.error('migrate system settings ไม่สำเร็จ:', error.message);
    await pool.end().catch(() => {});
    process.exit(1);
  });
