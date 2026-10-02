import { pool } from '../src/db.js';

const sql = `
CREATE TABLE IF NOT EXISTS air_conditioners (
  device_id VARCHAR(32) NOT NULL,
  room_number VARCHAR(20) NOT NULL,
  air_number TINYINT UNSIGNED NOT NULL,
  name VARCHAR(60) NOT NULL,
  ble_name VARCHAR(40) NOT NULL,
  protocol VARCHAR(40) NOT NULL DEFAULT 'HAIER_AC160',
  mqtt_topic VARCHAR(160) NOT NULL,
  mqtt_host VARCHAR(253) NOT NULL,
  mqtt_port SMALLINT UNSIGNED NOT NULL DEFAULT 1883,
  mqtt_username VARCHAR(100) NULL,
  provision_status ENUM('reserved','active','removed')
    NOT NULL DEFAULT 'reserved',
  provisioning_token_hash CHAR(64) NULL,
  provisioning_expires_at DATETIME NULL,
  daily_on TIME NULL,
  daily_off TIME NULL,
  is_online BOOLEAN NOT NULL DEFAULT FALSE,
  state_json LONGTEXT NULL,
  voltage DECIMAL(8,2) NULL,
  current_amp DECIMAL(8,3) NULL,
  power_watts DECIMAL(10,2) NULL,
  energy_kwh DECIMAL(12,3) NULL,
  frequency_hz DECIMAL(6,2) NULL,
  power_factor DECIMAL(5,3) NULL,
  pzem_available BOOLEAN NOT NULL DEFAULT FALSE,
  ac_running BOOLEAN NOT NULL DEFAULT FALSE,
  outside_schedule BOOLEAN NOT NULL DEFAULT FALSE,
  last_seen_at DATETIME NULL,
  created_by VARCHAR(100) NOT NULL,
  updated_by VARCHAR(100) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (device_id),
  UNIQUE KEY uq_air_room_number (room_number, air_number),
  UNIQUE KEY uq_air_ble_name (ble_name),
  UNIQUE KEY uq_air_mqtt_topic (mqtt_topic),
  KEY idx_air_room_status (room_number, provision_status),
  KEY idx_air_online (is_online, last_seen_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
`;

try {
  await pool.query(sql);
  await pool.query(
    `ALTER TABLE air_conditioners
       MODIFY protocol VARCHAR(40) NOT NULL DEFAULT 'HAIER_AC160'`,
  );
  await pool.query('UPDATE air_conditioners SET protocol = UPPER(protocol)');
  console.log('Air-conditioner migration complete.');
} finally {
  await pool.end();
}
