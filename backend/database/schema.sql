CREATE TABLE IF NOT EXISTS users (
  username VARCHAR(100) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  first_name VARCHAR(100) NOT NULL DEFAULT '',
  last_name VARCHAR(100) NOT NULL DEFAULT '',
  email VARCHAR(190) NOT NULL,
  phone VARCHAR(30) NULL,
  role ENUM('admin', 'staff') NOT NULL DEFAULT 'staff',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  token_version INT UNSIGNED NOT NULL DEFAULT 0,
  last_login_at DATETIME NULL,
  password_changed_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (username),
  UNIQUE KEY uq_users_email (email),
  KEY idx_users_role_active (role, is_active)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS password_reset_otps (
  id CHAR(36) NOT NULL,
  username VARCHAR(100) NOT NULL,
  otp_hash CHAR(64) NOT NULL,
  reset_token_hash CHAR(64) NULL,
  expires_at DATETIME NOT NULL,
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  verified_at DATETIME NULL,
  used_at DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_password_reset_token_hash (reset_token_hash),
  KEY idx_password_reset_username (username, created_at),
  KEY idx_password_reset_expiry (expires_at),
  CONSTRAINT fk_password_reset_username
    FOREIGN KEY (username) REFERENCES users (username)
    ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS rooms (
  room_number VARCHAR(20) NOT NULL,
  floor_number TINYINT UNSIGNED NOT NULL DEFAULT 0,
  room_index SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  room_type VARCHAR(100) NOT NULL DEFAULT 'Classroom',
  created_by VARCHAR(100) NOT NULL,
  updated_by VARCHAR(100) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (room_number),
  KEY idx_rooms_floor_order
    (floor_number, room_index, room_number)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

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
    (room_number, day_of_week, start_time),
  CONSTRAINT fk_class_schedule_room
    FOREIGN KEY (room_number) REFERENCES rooms (room_number)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

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
  provision_status ENUM(
    'reserved',
    'active'
  ) NOT NULL DEFAULT 'reserved',
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
  auto_off_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  auto_off_started_at DATETIME NULL,
  auto_off_deadline_at DATETIME NULL,
  auto_off_attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  auto_off_last_attempt_at DATETIME NULL,
  auto_off_in_class BOOLEAN NOT NULL DEFAULT FALSE,
  firmware_version VARCHAR(20) NULL,
  ota_error VARCHAR(120) NULL,
  -- จุดต่อของประวัติไฟฟ้า: ตัวอย่างล่าสุดที่บันทึกลง energy_hourly แล้ว
  -- ใช้ทั้งข้อมูลสดและข้อมูลย้อนหลังตอนเน็ตหลุด กันนับซ้ำหรือขาดช่วง
  energy_chain_kwh DECIMAL(12,3) NULL,
  energy_chain_at DATETIME NULL,
  energy_chain_running BOOLEAN NOT NULL DEFAULT FALSE,
  -- จำนวนรายการย้อนหลังที่บอร์ดยังส่งไม่ครบ
  history_pending SMALLINT UNSIGNED NOT NULL DEFAULT 0,
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
  KEY idx_air_online (is_online, last_seen_at),
  CONSTRAINT fk_air_conditioner_room
    FOREIGN KEY (room_number) REFERENCES rooms (room_number)
    ON UPDATE CASCADE
    ON DELETE RESTRICT
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS occupancy_sensors (
  device_id VARCHAR(32) NOT NULL,
  room_number VARCHAR(20) NOT NULL,
  ble_name VARCHAR(40) NOT NULL,
  mqtt_topic VARCHAR(160) NOT NULL,
  mqtt_host VARCHAR(253) NOT NULL,
  mqtt_port SMALLINT UNSIGNED NOT NULL DEFAULT 1883,
  mqtt_username VARCHAR(100) NULL,
  provision_status ENUM(
    'reserved',
    'active'
  ) NOT NULL DEFAULT 'reserved',
  provisioning_token_hash CHAR(64) NULL,
  provisioning_expires_at DATETIME NULL,
  static_threshold TINYINT UNSIGNED NOT NULL DEFAULT 25,
  is_online BOOLEAN NOT NULL DEFAULT FALSE,
  radar_available BOOLEAN NOT NULL DEFAULT FALSE,
  is_occupied BOOLEAN NOT NULL DEFAULT FALSE,
  firmware_version VARCHAR(20) NULL,
  ota_error VARCHAR(120) NULL,
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
  COLLATE=utf8mb4_unicode_ci;

-- การแจ้งเตือนที่ระบบสร้างเอง เก็บเป็นรหัสชนิดไม่ใช่ข้อความสำเร็จรูป
-- แอปจึงแปลเป็นภาษาไหนก็ได้ และแก้ถ้อยคำภายหลังโดยไม่ต้องแตะข้อมูลเก่า
CREATE TABLE IF NOT EXISTS system_alerts (
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
  COLLATE=utf8mb4_unicode_ci;

-- ถังเก็บค่าไฟรายชั่วโมงของแอร์แต่ละเครื่อง หนึ่งแถวคือหนึ่งเครื่องต่อหนึ่ง
-- ชั่วโมงตามเวลาไทย เก็บเป็นผลรวมกับตัวนับ ค่าเฉลี่ยคำนวณตอนดึงรายงาน
CREATE TABLE IF NOT EXISTS energy_hourly (
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
  COLLATE=utf8mb4_unicode_ci;

-- ค่าตั้งระดับระบบ เป็นคู่คีย์-ค่า
--
-- ใช้เก็บของที่กระทบทั้งอาคาร เช่นสวิตช์รวมของระบบปิดแอร์อัตโนมัติ
-- ต้องอยู่ที่นี่เพราะตัวที่ยิงคำสั่งปิดคือ Backend ไม่ใช่แอปบนมือถือ
CREATE TABLE IF NOT EXISTS system_settings (
  setting_key VARCHAR(64) NOT NULL PRIMARY KEY,
  setting_value VARCHAR(255) NOT NULL,
  updated_by VARCHAR(64) NULL,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ปฏิทินภาคเรียน: วันเปิด-ปิดของแต่ละเทอม เช่น 1/2569
--
-- ตารางเรียนที่ใช้อยู่จะมีผลเฉพาะระหว่างวันเปิด-ปิดของภาคเรียนของมัน
-- (ภาคเรียนดูจาก system_settings.timetable_semester) นอกช่วงนั้นระบบถือว่า
-- ทุกห้องอยู่นอกคาบ ห้องว่างช่วงปิดภาคจึงถูกปิดแอร์เร็ว (5 นาที) และมีแจ้งเตือน
-- โดยไม่ต้องลบตารางทิ้ง ภาคเรียนที่ไม่ได้ตั้งวันไว้ ใช้ตารางได้ทุกวันเหมือนเดิม
CREATE TABLE IF NOT EXISTS academic_terms (
  semester VARCHAR(30) NOT NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  updated_by VARCHAR(100) NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (semester),
  KEY idx_academic_terms_dates (start_date, end_date)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

-- การใช้ห้องนอกตารางเรียน เช่น ประชุมทุกวันพุธ สอบชดเชย กิจกรรม
--
-- ต่างจาก class_schedules ตรงที่มีวันที่กำกับเสมอ และทำซ้ำได้สามแบบ:
--   once   = วันเดียว (start_date = end_date)
--   daily  = ทุกวันตั้งแต่ start_date ถึง end_date
--   weekly = ทุกวันในสัปดาห์ที่เลือก (days_of_week เช่น "1,3") ในช่วงวันที่นั้น
-- ระหว่างเวลาที่จองไว้ ระบบปิดแอร์อัตโนมัติถือว่าห้องอยู่ในคาบ (รอ 15 นาที
-- และไม่แจ้งเตือน) แม้อยู่นอกภาคเรียน ลบห้องแล้วการจองของห้องนั้นหายไปด้วย
CREATE TABLE IF NOT EXISTS room_bookings (
  id CHAR(36) NOT NULL,
  room_number VARCHAR(20) NOT NULL,
  title VARCHAR(150) NOT NULL,
  category VARCHAR(20) NOT NULL DEFAULT 'other',
  note VARCHAR(255) NOT NULL DEFAULT '',
  repeat_type VARCHAR(10) NOT NULL DEFAULT 'once',
  days_of_week VARCHAR(20) NOT NULL DEFAULT '',
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  created_by VARCHAR(100) NOT NULL,
  updated_by VARCHAR(100) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
    ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_room_bookings_lookup (room_number, start_date, end_date),
  KEY idx_room_bookings_dates (start_date, end_date),
  CONSTRAINT fk_room_booking_room
    FOREIGN KEY (room_number) REFERENCES rooms (room_number)
    ON UPDATE CASCADE
    ON DELETE CASCADE
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO system_settings (setting_key, setting_value)
VALUES ('auto_off_enabled', 'true');

INSERT IGNORE INTO rooms
  (room_number, floor_number, room_index, room_type,
   created_by, updated_by)
VALUES
  ('16101', 1, 1, 'Administration Office', 'system', 'system'),
  ('16102', 1, 2, 'Meeting Room', 'system', 'system'),
  ('16103', 1, 3, 'Classroom', 'system', 'system'),
  ('16104', 1, 4, 'Laboratory', 'system', 'system'),
  ('16105', 1, 5, 'Faculty Office', 'system', 'system'),
  ('16106', 1, 6, 'Classroom', 'system', 'system'),
  ('16107', 1, 7, 'Project Room', 'system', 'system'),
  ('16201', 2, 1, 'Classroom', 'system', 'system'),
  ('16202', 2, 2, 'Classroom', 'system', 'system'),
  ('16203', 2, 3, 'Laboratory', 'system', 'system'),
  ('16204', 2, 4, 'Classroom', 'system', 'system'),
  ('16205', 2, 5, 'Network Room', 'system', 'system'),
  ('16206', 2, 6, 'Faculty Office', 'system', 'system'),
  ('16207', 2, 7, 'Classroom', 'system', 'system'),
  ('16301', 3, 1, 'Meeting Room', 'system', 'system'),
  ('16302', 3, 2, 'Storage Room', 'system', 'system'),
  ('16303', 3, 3, 'Classroom', 'system', 'system'),
  ('16304', 3, 4, 'Faculty Project Room', 'system', 'system'),
  ('16305', 3, 5, 'Equipment Storage', 'system', 'system'),
  ('16306', 3, 6, 'Faculty Office', 'system', 'system'),
  ('16307', 3, 7, 'Classroom', 'system', 'system'),
  ('CL503', 0, 503, 'Special Computer Laboratory', 'system', 'system');

INSERT IGNORE INTO class_schedules
  (id, room_number, day_of_week, subject_name,
   start_time, end_time, created_by, updated_by)
VALUES
  ('10000000-0000-4000-8000-000000000001',
   '16302', 1, 'Computer Network', '09:00', '12:00', 'system', 'system'),
  ('10000000-0000-4000-8000-000000000002',
   '16302', 1, 'Embedded Systems', '13:00', '16:00', 'system', 'system'),
  ('10000000-0000-4000-8000-000000000003',
   '16304', 1, 'Computer Network', '09:00', '12:00', 'system', 'system'),
  ('10000000-0000-4000-8000-000000000004',
   '16304', 1, 'Embedded Systems', '13:00', '16:00', 'system', 'system');
