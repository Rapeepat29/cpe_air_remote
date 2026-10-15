import { ApiError } from './http.js';

export const STATIC_ENERGY_THRESHOLD = 25;

const devicePattern = /^OCC32-[0-9A-F]{12}$/;
const roomPattern = /^[A-Z0-9][A-Z0-9_-]{1,9}$/;

export function validateOccupancyReservationInput(body) {
  const source = body && typeof body === 'object' ? body : {};
  const deviceId = cleanString(source.deviceId).toUpperCase();
  const roomNumber = cleanString(source.roomNumber).toUpperCase();
  const bleName = cleanString(source.bleName);

  if (!devicePattern.test(deviceId)) {
    throw new ApiError(400, 'รหัส ESP32 ของเซ็นเซอร์ตรวจจับคนไม่ถูกต้อง');
  }
  if (!roomPattern.test(roomNumber)) {
    throw new ApiError(400, 'หมายเลขห้องไม่ถูกต้อง');
  }
  if (bleName !== `RMUTT-OCC-${deviceId.slice(6)}`) {
    throw new ApiError(400, 'ชื่อ Bluetooth ไม่ตรงกับรหัสเซ็นเซอร์');
  }

  return { deviceId, roomNumber, bleName };
}

export function validateOccupancyDeviceId(value) {
  const deviceId = cleanString(value).toUpperCase();
  if (!devicePattern.test(deviceId)) {
    throw new ApiError(400, 'รหัสเซ็นเซอร์ตรวจจับคนไม่ถูกต้อง');
  }
  return deviceId;
}

export function publicOccupancySensor(row) {
  return {
    deviceId: row.device_id,
    roomNumber: row.room_number,
    bleName: row.ble_name,
    mqttTopic: row.mqtt_topic,
    provisionStatus: row.provision_status,
    isOnline: Boolean(row.is_online),
    radarAvailable: Boolean(row.radar_available),
    isOccupied: Boolean(row.is_occupied),
    staticThreshold: Number(row.static_threshold ?? STATIC_ENERGY_THRESHOLD),
    lastSeenAt: toIsoString(row.last_seen_at),
    firmwareVersion: row.firmware_version ?? null,
    otaError: row.ota_error ?? null,
  };
}

export function normalizeOccupancyStatus(message) {
  const source = message && typeof message === 'object' ? message : {};
  const online = source.online !== false;
  const radarAvailable = online && source.radarAvailable === true;
  return {
    online,
    radarAvailable,
    occupied: radarAvailable && source.occupied === true,
  };
}

function toIsoString(value) {
  if (value == null) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}
