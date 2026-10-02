import { pool } from '../src/db.js';

const columns = [
  ['energy_kwh', 'DECIMAL(12,3) NULL AFTER power_watts'],
  ['frequency_hz', 'DECIMAL(6,2) NULL AFTER energy_kwh'],
  ['power_factor', 'DECIMAL(5,3) NULL AFTER frequency_hz'],
  [
    'pzem_available',
    'BOOLEAN NOT NULL DEFAULT FALSE AFTER power_factor',
  ],
  ['ac_running', 'BOOLEAN NOT NULL DEFAULT FALSE AFTER pzem_available'],
  [
    'outside_schedule',
    'BOOLEAN NOT NULL DEFAULT FALSE AFTER ac_running',
  ],
];

try {
  const existing = await pool.query(
    `SELECT COLUMN_NAME
       FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()
        AND TABLE_NAME = 'air_conditioners'`,
  );
  const names = new Set(existing.map((row) => row.COLUMN_NAME));
  for (const [name, definition] of columns) {
    if (names.has(name)) continue;
    await pool.query(
      `ALTER TABLE air_conditioners ADD COLUMN ${name} ${definition}`,
    );
    console.log(`Added air_conditioners.${name}`);
  }
  console.log('PZEM v2.0.0 migration complete.');
} finally {
  await pool.end();
}
