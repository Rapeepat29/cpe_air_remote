import { pool } from '../src/db.js';

try {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS class_schedules (
      id CHAR(36) NOT NULL,
      room_number VARCHAR(20) NOT NULL,
      day_of_week TINYINT UNSIGNED NOT NULL,
      subject_name VARCHAR(150) NOT NULL,
      section_name VARCHAR(80) NOT NULL DEFAULT '',
      instructor VARCHAR(150) NOT NULL DEFAULT '',
      start_time TIME NOT NULL,
      end_time TIME NOT NULL,
      created_by VARCHAR(100) NOT NULL,
      updated_by VARCHAR(100) NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (id),
      UNIQUE KEY uq_class_schedule_entry
        (room_number, day_of_week, start_time, end_time, subject_name),
      KEY idx_class_schedule_lookup
        (room_number, day_of_week, start_time)
    ) ENGINE=InnoDB
      DEFAULT CHARSET=utf8mb4
      COLLATE=utf8mb4_unicode_ci
  `);

  await pool.query(
    `INSERT IGNORE INTO class_schedules
       (id, room_number, day_of_week, subject_name,
        start_time, end_time, created_by, updated_by)
     VALUES
       (?, '16302', 1, 'Computer Network', '09:00', '12:00', 'system', 'system'),
       (?, '16302', 1, 'Embedded Systems', '13:00', '16:00', 'system', 'system'),
       (?, '16304', 1, 'Computer Network', '09:00', '12:00', 'system', 'system'),
       (?, '16304', 1, 'Embedded Systems', '13:00', '16:00', 'system', 'system')`,
    [
      '10000000-0000-4000-8000-000000000001',
      '10000000-0000-4000-8000-000000000002',
      '10000000-0000-4000-8000-000000000003',
      '10000000-0000-4000-8000-000000000004',
    ],
  );

  console.log('Class schedule migration complete.');
} finally {
  await pool.end();
}
