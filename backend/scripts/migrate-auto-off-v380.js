import { pool } from '../src/db.js';

// เพิ่มคอลัมน์ปิดแอร์อัตโนมัติและตารางแจ้งเตือน ปลอดภัยที่จะรันซ้ำ

const columns = [
  ['auto_off_enabled', 'BOOLEAN NOT NULL DEFAULT TRUE'],
  ['auto_off_started_at', 'DATETIME NULL'],
  ['auto_off_deadline_at', 'DATETIME NULL'],
  ['auto_off_attempts', 'TINYINT UNSIGNED NOT NULL DEFAULT 0'],
  ['auto_off_last_attempt_at', 'DATETIME NULL'],
  ['auto_off_in_class', 'BOOLEAN NOT NULL DEFAULT FALSE'],
];

try {
  const existing = await pool.query(
    `SELECT COLUMN_NAME
       FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'air_conditioners'`,
  );
  const present = new Set(existing.map((row) => row.COLUMN_NAME));

  let added = 0;
  for (const [name, definition] of columns) {
    if (present.has(name)) continue;
    await pool.query(
      `ALTER TABLE air_conditioners ADD COLUMN ${name} ${definition}`,
    );
    added += 1;
    console.log(`เพิ่มคอลัมน์ air_conditioners.${name} แล้ว`);
  }
  if (added === 0) {
    console.log('คอลัมน์ปิดแอร์อัตโนมัติครบอยู่แล้ว');
  }

  await pool.query(
    `CREATE TABLE IF NOT EXISTS system_alerts (
      id CHAR(36) NOT NULL,
      kind ENUM(
        'outside_schedule_occupied',
        'auto_off_succeeded',
        'auto_off_failed'
      ) NOT NULL,
      room_number VARCHAR(20) NOT NULL,
      device_id VARCHAR(32) NULL,
      device_name VARCHAR(60) NOT NULL DEFAULT '',
      detail VARCHAR(255) NOT NULL DEFAULT '',
      status ENUM('open', 'acknowledged', 'resolved') NOT NULL DEFAULT 'open',
      acknowledged_at DATETIME NULL,
      acknowledged_by VARCHAR(100) NULL,
      resolved_at DATETIME NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      KEY idx_system_alerts_feed (created_at),
      KEY idx_system_alerts_open (status, kind, room_number, device_id)
    ) ENGINE=InnoDB
      DEFAULT CHARSET=utf8mb4
      COLLATE=utf8mb4_unicode_ci`,
  );

  const alertRows = await pool.query(
    'SELECT COUNT(*) AS total FROM system_alerts',
  );
  console.log(
    'Auto-off v3.8.0 migration complete. '
    + `system_alerts has ${Number(alertRows[0]?.total ?? 0)} row(s).`,
  );
} finally {
  await pool.end();
}
