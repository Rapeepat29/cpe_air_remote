import { pool } from '../src/db.js';

const standardRooms = [
  ['16101', 1, 1, 'Administration Office'],
  ['16102', 1, 2, 'Meeting Room'],
  ['16103', 1, 3, 'Classroom'],
  ['16104', 1, 4, 'Laboratory'],
  ['16105', 1, 5, 'Faculty Office'],
  ['16106', 1, 6, 'Classroom'],
  ['16107', 1, 7, 'Project Room'],
  ['16201', 2, 1, 'Classroom'],
  ['16202', 2, 2, 'Classroom'],
  ['16203', 2, 3, 'Laboratory'],
  ['16204', 2, 4, 'Classroom'],
  ['16205', 2, 5, 'Network Room'],
  ['16206', 2, 6, 'Faculty Office'],
  ['16207', 2, 7, 'Classroom'],
  ['16301', 3, 1, 'Meeting Room'],
  ['16302', 3, 2, 'Storage Room'],
  ['16303', 3, 3, 'Classroom'],
  ['16304', 3, 4, 'Faculty Project Room'],
  ['16305', 3, 5, 'Equipment Storage'],
  ['16306', 3, 6, 'Faculty Office'],
  ['16307', 3, 7, 'Classroom'],
  ['CL503', 0, 503, 'Special Computer Laboratory'],
];

try {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS rooms (
      room_number VARCHAR(20) NOT NULL,
      floor_number TINYINT UNSIGNED NOT NULL DEFAULT 0,
      room_index SMALLINT UNSIGNED NOT NULL DEFAULT 0,
      room_type VARCHAR(100) NOT NULL DEFAULT 'Classroom',
      is_active BOOLEAN NOT NULL DEFAULT TRUE,
      created_by VARCHAR(100) NOT NULL,
      updated_by VARCHAR(100) NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (room_number),
      KEY idx_rooms_floor_active
        (floor_number, is_active, room_index, room_number)
    ) ENGINE=InnoDB
      DEFAULT CHARSET=utf8mb4
      COLLATE=utf8mb4_unicode_ci
  `);

  for (const room of standardRooms) {
    await pool.query(
      `INSERT IGNORE INTO rooms
         (room_number, floor_number, room_index, room_type,
          created_by, updated_by)
       VALUES (?, ?, ?, ?, 'system', 'system')`,
      room,
    );
  }

  if (await tableExists('class_schedules')) {
    await copyUnknownRoomsFrom('class_schedules');
    await pool.query(
      `ALTER TABLE class_schedules
         MODIFY room_number VARCHAR(20) NOT NULL,
         ADD COLUMN IF NOT EXISTS section_name
           VARCHAR(80) NOT NULL DEFAULT '' AFTER subject_name,
         ADD COLUMN IF NOT EXISTS instructor
           VARCHAR(150) NOT NULL DEFAULT '' AFTER section_name`,
    );
    await addForeignKeyIfMissing({
      tableName: 'class_schedules',
      constraintName: 'fk_class_schedule_room',
      sql: `ALTER TABLE class_schedules
              ADD CONSTRAINT fk_class_schedule_room
              FOREIGN KEY (room_number) REFERENCES rooms (room_number)
              ON UPDATE CASCADE
              ON DELETE RESTRICT`,
    });
  }

  if (await tableExists('air_conditioners')) {
    await copyUnknownRoomsFrom('air_conditioners');
    await pool.query(
      `ALTER TABLE air_conditioners
         MODIFY room_number VARCHAR(20) NOT NULL`,
    );
    await addForeignKeyIfMissing({
      tableName: 'air_conditioners',
      constraintName: 'fk_air_conditioner_room',
      sql: `ALTER TABLE air_conditioners
              ADD CONSTRAINT fk_air_conditioner_room
              FOREIGN KEY (room_number) REFERENCES rooms (room_number)
              ON UPDATE CASCADE
              ON DELETE RESTRICT`,
    });
  }

  console.log('Room management v1.8.0 migration complete.');
} finally {
  await pool.end();
}

async function copyUnknownRoomsFrom(tableName) {
  await pool.query(
    `INSERT IGNORE INTO rooms
       (room_number, floor_number, room_index, room_type,
        created_by, updated_by)
     SELECT DISTINCT room_number, 0, 0, 'Imported room', 'system', 'system'
       FROM ${tableName}
      WHERE room_number IS NOT NULL AND room_number <> ''`,
  );
}

async function tableExists(tableName) {
  const rows = await pool.query(
    `SELECT 1
       FROM information_schema.tables
      WHERE table_schema = DATABASE() AND table_name = ?
      LIMIT 1`,
    [tableName],
  );
  return Boolean(rows[0]);
}

async function addForeignKeyIfMissing({
  tableName,
  constraintName,
  sql,
}) {
  const rows = await pool.query(
    `SELECT 1
       FROM information_schema.table_constraints
      WHERE table_schema = DATABASE()
        AND table_name = ?
        AND constraint_name = ?
      LIMIT 1`,
    [tableName, constraintName],
  );
  if (!rows[0]) {
    await pool.query(sql);
  }
}
