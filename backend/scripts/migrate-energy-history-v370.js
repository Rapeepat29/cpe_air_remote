import { pool } from '../src/db.js';

// สร้างตารางเก็บค่าไฟรายชั่วโมง ปลอดภัยที่จะรันซ้ำ
try {
  await pool.query(
    `CREATE TABLE IF NOT EXISTS energy_hourly (
      device_id VARCHAR(32) NOT NULL,
      bucket_start DATETIME NOT NULL,
      room_number VARCHAR(20) NOT NULL,
      device_name VARCHAR(60) NOT NULL DEFAULT '',
      sample_count INT UNSIGNED NOT NULL DEFAULT 0,
      pzem_samples INT UNSIGNED NOT NULL DEFAULT 0,
      running_samples INT UNSIGNED NOT NULL DEFAULT 0,
      first_sample_at DATETIME NULL,
      last_sample_at DATETIME NULL,
      energy_start_kwh DECIMAL(12,3) NULL,
      energy_end_kwh DECIMAL(12,3) NULL,
      consumption_kwh DECIMAL(12,3) NOT NULL DEFAULT 0,
      voltage_sum DECIMAL(16,2) NOT NULL DEFAULT 0,
      voltage_min DECIMAL(8,2) NULL,
      voltage_max DECIMAL(8,2) NULL,
      current_sum DECIMAL(16,3) NOT NULL DEFAULT 0,
      current_min DECIMAL(8,3) NULL,
      current_max DECIMAL(8,3) NULL,
      power_sum DECIMAL(18,2) NOT NULL DEFAULT 0,
      power_min DECIMAL(10,2) NULL,
      power_max DECIMAL(10,2) NULL,
      power_factor_sum DECIMAL(14,3) NOT NULL DEFAULT 0,
      frequency_sum DECIMAL(14,2) NOT NULL DEFAULT 0,
      runtime_seconds INT UNSIGNED NOT NULL DEFAULT 0,
      online_seconds INT UNSIGNED NOT NULL DEFAULT 0,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (device_id, bucket_start),
      KEY idx_energy_hourly_bucket (bucket_start),
      KEY idx_energy_hourly_room (room_number, bucket_start)
    ) ENGINE=InnoDB
      DEFAULT CHARSET=utf8mb4
      COLLATE=utf8mb4_unicode_ci`,
  );

  const rows = await pool.query(
    'SELECT COUNT(*) AS total FROM energy_hourly',
  );
  console.log(
    'Energy history v3.7.0 migration complete. '
    + `energy_hourly has ${Number(rows[0]?.total ?? 0)} row(s).`,
  );
} finally {
  await pool.end();
}
