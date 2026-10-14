import { pool } from '../src/db.js';

try {
  await pool.query(
    `CREATE TABLE IF NOT EXISTS occupancy_sensors (
      device_id VARCHAR(32) NOT NULL,
      room_number VARCHAR(20) NOT NULL,
      ble_name VARCHAR(40) NOT NULL,
      mqtt_topic VARCHAR(160) NOT NULL,
      mqtt_host VARCHAR(253) NOT NULL,
      mqtt_port SMALLINT UNSIGNED NOT NULL DEFAULT 1883,
      mqtt_username VARCHAR(100) NULL,
      provision_status ENUM('reserved', 'active')
        NOT NULL DEFAULT 'reserved',
      provisioning_token_hash CHAR(64) NULL,
      provisioning_expires_at DATETIME NULL,
      static_threshold TINYINT UNSIGNED NOT NULL DEFAULT 25,
      is_online BOOLEAN NOT NULL DEFAULT FALSE,
      radar_available BOOLEAN NOT NULL DEFAULT FALSE,
      is_occupied BOOLEAN NOT NULL DEFAULT FALSE,
      last_seen_at DATETIME NULL,
      created_by VARCHAR(100) NOT NULL,
      updated_by VARCHAR(100) NOT NULL,
      created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
      PRIMARY KEY (device_id),
      UNIQUE KEY uq_occupancy_room (room_number),
      UNIQUE KEY uq_occupancy_ble_name (ble_name),
      UNIQUE KEY uq_occupancy_mqtt_topic (mqtt_topic),
      KEY idx_occupancy_status (provision_status, is_online),
      CONSTRAINT fk_occupancy_room
        FOREIGN KEY (room_number) REFERENCES rooms (room_number)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
    ) ENGINE=InnoDB
      DEFAULT CHARSET=utf8mb4
      COLLATE=utf8mb4_unicode_ci`,
  );
  console.log('Occupancy sensor v2.1.0 migration complete.');
} finally {
  await pool.end();
}
