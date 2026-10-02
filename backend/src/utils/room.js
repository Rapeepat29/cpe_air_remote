import { autoOffPhase, autoOffSecondsRemaining } from './auto-off.js';
import { ApiError } from './http.js';

const roomNumberPattern = /^[A-Z0-9][A-Z0-9_-]{1,19}$/;

export function validateRoomInput(body, { requireNumber = true } = {}) {
  const source = body && typeof body === 'object' ? body : {};
  const roomNumber = normalizeRoomNumber(source.roomNumber);
  const floorNumber = integer(source.floorNumber);
  const roomIndex = integer(source.roomIndex);
  const roomType = cleanString(source.roomType);

  if (requireNumber && !roomNumberPattern.test(roomNumber)) {
    throw new ApiError(
      400,
      'รหัสห้องต้องมี 2–20 ตัว และใช้เฉพาะ A–Z, 0–9, _ หรือ -',
    );
  }
  if (floorNumber == null || floorNumber < 0 || floorNumber > 99) {
    throw new ApiError(
      400,
      'ชั้นต้องอยู่ระหว่าง 0–99 โดยใช้ 0 สำหรับห้องพิเศษ',
    );
  }
  if (roomIndex == null || roomIndex < 0 || roomIndex > 9999) {
    throw new ApiError(400, 'ลำดับห้องต้องอยู่ระหว่าง 0–9999');
  }
  if (roomType.length < 1 || roomType.length > 100) {
    throw new ApiError(400, 'ประเภทหรือชื่อห้องต้องมีความยาว 1–100 ตัวอักษร');
  }

  return {
    ...(requireNumber ? { roomNumber } : {}),
    floorNumber,
    roomIndex,
    roomType,
  };
}

export function validateRoomNumber(value) {
  const roomNumber = normalizeRoomNumber(value);
  if (!roomNumberPattern.test(roomNumber)) {
    throw new ApiError(400, 'รหัสห้องไม่ถูกต้อง');
  }
  return roomNumber;
}

export function publicRoom(row) {
  return {
    roomNumber: row.room_number,
    floorNumber: Number(row.floor_number),
    roomIndex: Number(row.room_index),
    roomType: row.room_type,
    airConditionerCount: Number(row.air_conditioner_count ?? 0),
    scheduleCount: Number(row.schedule_count ?? 0),
    occupancySensorDeviceId: row.occupancy_sensor_device_id ?? null,
    occupancySensorBleName: row.occupancy_sensor_ble_name ?? null,
    occupancySensorProvisionStatus:
      row.occupancy_sensor_provision_status ?? null,
    occupancySensorOnline: Boolean(row.occupancy_sensor_online),
    occupancySensorAvailable: Boolean(row.occupancy_sensor_available),
    isOccupied: Boolean(row.is_occupied),
    occupancyStaticThreshold:
      Number(row.occupancy_static_threshold ?? 25),
    occupancyUpdatedAt: row.occupancy_updated_at == null
      ? null
      : new Date(row.occupancy_updated_at).toISOString(),
    runningAirCount: Number(row.running_air_count ?? 0),
    // นาฬิกาปิดแอร์อัตโนมัติของห้อง ใช้เครื่องที่ใกล้ครบกำหนดที่สุด
    autoOffDeadlineAt: row.auto_off_deadline_at == null
      ? null
      : new Date(row.auto_off_deadline_at).toISOString(),
    autoOffSecondsRemaining: autoOffSecondsRemaining({
      autoOffDeadlineAt: row.auto_off_deadline_at,
    }),
    autoOffAttempts: Number(row.auto_off_attempts ?? 0),
    autoOffInClass: Boolean(row.auto_off_in_class),
    autoOffPhase: autoOffPhase({
      autoOffDeadlineAt: row.auto_off_deadline_at,
      autoOffAttempts: row.auto_off_attempts,
    }),
  };
}

export function roomDefaultsForImport(value) {
  const roomNumber = validateRoomNumber(value);
  const standardRoom = /^16([1-9])(\d{2})$/.exec(roomNumber);
  if (standardRoom) {
    return {
      roomNumber,
      floorNumber: Number(standardRoom[1]),
      roomIndex: Number(standardRoom[2]),
      roomType: 'Classroom',
    };
  }

  const trailingNumber = /(\d{1,4})$/.exec(roomNumber);
  return {
    roomNumber,
    floorNumber: 0,
    roomIndex: trailingNumber ? Number(trailingNumber[1]) : 0,
    roomType: 'Special',
  };
}

function normalizeRoomNumber(value) {
  return cleanString(value).toUpperCase();
}

function integer(value) {
  if (typeof value === 'number') {
    return Number.isInteger(value) ? value : null;
  }
  const text = String(value ?? '');
  if (!/^\d+$/.test(text)) return null;
  const result = Number.parseInt(text, 10);
  return Number.isInteger(result) ? result : null;
}

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}
