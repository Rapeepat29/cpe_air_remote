import { autoOffPhase, autoOffSecondsRemaining } from './auto-off.js';
import { ApiError } from './http.js';

const roomPattern = /^[A-Z0-9][A-Z0-9_-]{1,9}$/;
const devicePattern = /^ESP32-[0-9A-F]{12}$/;
const timePattern = /^(?:[01]\d|2[0-3]):[0-5]\d$/;

// DAIKIN_WIRED = บอร์ดรุ่นสายแอร์ (rmutt_esp32_air_wired) ใช้แทนรีโมตติดผนัง Daikin
// ไม่ได้ยิง IR จึงไม่ใช่ชื่อโปรโตคอลของ IRremoteESP8266
export const WIRED_PROTOCOL = 'DAIKIN_WIRED';

const protocols = new Set([
  'DAIKIN',
  WIRED_PROTOCOL,
  'ELECTRA_AC',
  'FUJITSU_AC',
  'GREE',
  'HAIER_AC',
  'HAIER_AC160',
  'HAIER_AC176',
  'HAIER_AC_YRW02',
  'HITACHI_AC',
  'KELVINATOR',
  'LG',
  'MIDEA',
  'MITSUBISHI_AC',
  'PANASONIC_AC',
  'SAIJO_DENKI',
  'SAMSUNG_AC',
  'SHARP_AC',
  'TOSHIBA_AC',
]);
const modes = new Set(['auto', 'cool', 'dry', 'fan', 'heat']);
const fanSpeeds = new Set(['auto', 'low', 'medium', 'high', 'turbo']);
const swingModes = new Set([
  'off',
  'top',
  'upper',
  'middle',
  'lower',
  'bottom',
  'auto',
]);

export function validateReservationInput(body) {
  const source = body && typeof body === 'object' ? body : {};
  const deviceId = cleanString(source.deviceId).toUpperCase();
  const roomNumber = cleanString(source.roomNumber).toUpperCase();
  const airNumber = integer(source.airNumber);
  const name = cleanString(source.name);
  const bleName = cleanString(source.bleName);
  const protocol = cleanString(source.protocol).toUpperCase();
  const dailyOn = optionalTime(source.dailyOn);
  const dailyOff = optionalTime(source.dailyOff);

  if (!devicePattern.test(deviceId)) {
    throw new ApiError(400, 'รหัส ESP32 ไม่ถูกต้อง');
  }
  if (!roomPattern.test(roomNumber)) {
    throw new ApiError(400, 'หมายเลขห้องไม่ถูกต้อง');
  }
  if (airNumber == null || airNumber < 1 || airNumber > 6) {
    throw new ApiError(400, 'หมายเลขแอร์ต้องอยู่ระหว่าง 1–6');
  }
  if (name.length < 1 || name.length > 50) {
    throw new ApiError(400, 'ชื่อแอร์ต้องมีความยาว 1–50 ตัวอักษร');
  }
  if (bleName !== `RMUTT-AC-${deviceId.slice(6)}`) {
    throw new ApiError(400, 'ชื่อ Bluetooth ไม่ตรงกับรหัส ESP32');
  }
  if (!protocols.has(protocol)) {
    throw new ApiError(400, 'Protocol ของแอร์ไม่รองรับ');
  }

  return {
    deviceId,
    roomNumber,
    airNumber,
    name,
    bleName,
    protocol,
    dailyOn,
    dailyOff,
  };
}

export function validateAirState(body, protocol = '') {
  const source = body && typeof body === 'object' ? body : {};
  const temperature = integer(source.temperature);
  const mode = cleanString(source.mode).toLowerCase();
  const fanSpeed = cleanString(source.fanSpeed).toLowerCase();
  const verticalSwing = cleanString(source.verticalSwing).toLowerCase();
  const timerOnMinutes = optionalMinutes(source.timerOnMinutes);
  const timerOffMinutes = optionalMinutes(source.timerOffMinutes);

  if (typeof source.power !== 'boolean') {
    throw new ApiError(400, 'ค่า Power ไม่ถูกต้อง');
  }
  if (temperature == null || temperature < 16 || temperature > 30) {
    throw new ApiError(400, 'อุณหภูมิต้องอยู่ระหว่าง 16–30°C');
  }
  if (!modes.has(mode)) {
    throw new ApiError(400, 'โหมดแอร์ไม่ถูกต้อง');
  }
  if (!fanSpeeds.has(fanSpeed)) {
    throw new ApiError(400, 'ระดับพัดลมไม่ถูกต้อง');
  }
  if (!swingModes.has(verticalSwing)) {
    throw new ApiError(400, 'ตำแหน่ง Swing ไม่ถูกต้อง');
  }

  const wired = cleanString(protocol).toUpperCase() === WIRED_PROTOCOL;
  if (wired) {
    if (mode !== 'cool' && mode !== 'dry' && mode !== 'fan') {
      throw new ApiError(400, 'แอร์แบบสายแอร์รองรับโหมด Cool, Dry และ Fan');
    }
    if (fanSpeed === 'turbo') {
      throw new ApiError(400, 'แอร์แบบสายแอร์ไม่มีพัดลมระดับ Turbo');
    }
    if (verticalSwing !== 'auto' && verticalSwing !== 'off') {
      throw new ApiError(400, 'แอร์แบบสายแอร์มีเฉพาะส่าย (Auto) หรือหยุด (Off)');
    }
  }

  if (cleanString(protocol).toUpperCase() === 'SAIJO_DENKI') {
    if (temperature < 18 || temperature > 29) {
      throw new ApiError(400, 'Saijo Denki รองรับอุณหภูมิ 18–29°C');
    }
    if (mode !== 'cool' && mode !== 'dry' && mode !== 'fan') {
      throw new ApiError(400, 'Saijo Denki รองรับโหมด Cool, Dry และ Fan');
    }
    if (verticalSwing === 'off') {
      throw new ApiError(400, 'Saijo Denki ชุดข้อมูลปัจจุบันไม่มีคำสั่งปิด Swing');
    }
  }

  // รุ่นสายแอร์ไม่มีฟังก์ชันเสริมเหล่านี้ ปิดไว้เลยให้ตรงกับที่แอร์ทำจริง
  // (Sleep มีจริง ยกเว้นในโหมด Dry ที่แอร์ไม่รับ)
  return {
    power: source.power,
    temperature,
    mode,
    fanSpeed,
    verticalSwing,
    horizontalSwing: wired ? false : boolean(source.horizontalSwing),
    eco: wired ? false : boolean(source.eco),
    turbo: wired ? false : boolean(source.turbo),
    sleep: wired && mode === 'dry' ? false : boolean(source.sleep),
    quiet: wired ? false : boolean(source.quiet),
    displayLight: boolean(source.displayLight, true),
    clean: wired ? false : boolean(source.clean),
    timerOnMinutes,
    timerOffMinutes,
  };
}

export function controlTypeOf(protocol) {
  return cleanString(protocol).toUpperCase() === WIRED_PROTOCOL ? 'wired' : 'ir';
}

/**
 * บอร์ดรุ่นสายแอร์บอกตัวเองใน status ว่า controlMode = "wired"
 * ถ้าในฐานข้อมูลยังเป็นยี่ห้อ IR (เช่น ตั้งค่าจากแอปรุ่นเก่า) ให้แก้เป็น DAIKIN_WIRED
 * คืนค่า null เมื่อไม่ต้องเปลี่ยนอะไร
 */
export function protocolFromStatus(message) {
  const mode = typeof message?.controlMode === 'string'
    ? message.controlMode.trim().toLowerCase()
    : '';
  return mode === 'wired' ? WIRED_PROTOCOL : null;
}

export function validateDeviceId(value) {
  const deviceId = cleanString(value).toUpperCase();
  if (!devicePattern.test(deviceId)) {
    throw new ApiError(400, 'รหัส ESP32 ไม่ถูกต้อง');
  }
  return deviceId;
}

export function publicAirConditioner(row) {
  const state = parseState(row.state_json);
  return {
    deviceId: row.device_id,
    roomNumber: row.room_number,
    airNumber: Number(row.air_number),
    name: row.name,
    bleName: row.ble_name,
    protocol: row.protocol,
    // ir = ยิงรีโมต IR · wired = ต่อสายแอร์แทนรีโมตติดผนัง
    controlType: controlTypeOf(row.protocol),
    provisionStatus: row.provision_status,
    isOnline: Boolean(row.is_online),
    mqttTopic: row.mqtt_topic,
    dailyOn: normalizeTime(row.daily_on),
    dailyOff: normalizeTime(row.daily_off),
    lastSeenAt: row.last_seen_at == null
      ? null
      : new Date(row.last_seen_at).toISOString(),
    voltage: nullableNumber(row.voltage),
    current: nullableNumber(row.current_amp),
    powerWatts: nullableNumber(row.power_watts),
    energyKwh: nullableNumber(row.energy_kwh),
    frequencyHz: nullableNumber(row.frequency_hz),
    powerFactor: nullableNumber(row.power_factor),
    pzemAvailable: Boolean(row.pzem_available),
    acRunning: Boolean(row.ac_running),
    outsideSchedule: Boolean(row.outside_schedule),
    autoOffEnabled: row.auto_off_enabled == null
      ? true
      : Boolean(row.auto_off_enabled),
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
    firmwareVersion: row.firmware_version ?? null,
    otaError: row.ota_error ?? null,
    historyPending: Number(row.history_pending ?? 0),
    state,
  };
}

function parseState(value) {
  const fallback = {
    power: false,
    temperature: 25,
    mode: 'cool',
    fanSpeed: 'auto',
    verticalSwing: 'auto',
    horizontalSwing: false,
    eco: false,
    turbo: false,
    sleep: false,
    quiet: false,
    displayLight: true,
    clean: false,
    timerOnMinutes: null,
    timerOffMinutes: null,
  };
  if (!value) return fallback;
  try {
    return { ...fallback, ...JSON.parse(String(value)) };
  } catch {
    return fallback;
  }
}

function optionalTime(value) {
  if (value == null || value === '') return null;
  const cleaned = cleanString(value);
  if (!timePattern.test(cleaned)) {
    throw new ApiError(400, 'เวลาเปิด–ปิดต้องเป็นรูปแบบ HH:mm');
  }
  return cleaned;
}

function optionalMinutes(value) {
  if (value == null) return null;
  const result = integer(value);
  if (result == null || result < 1 || result > 1440) {
    throw new ApiError(400, 'Timer ต้องอยู่ระหว่าง 1–1440 นาที');
  }
  return result;
}

function normalizeTime(value) {
  return value == null ? null : String(value).slice(0, 5);
}

function nullableNumber(value) {
  if (value == null) return null;
  const result = Number(value);
  return Number.isFinite(result) ? result : null;
}

function integer(value) {
  const result = typeof value === 'number'
    ? value
    : Number.parseInt(String(value ?? ''), 10);
  return Number.isInteger(result) ? result : null;
}

function boolean(value, fallback = false) {
  return typeof value === 'boolean' ? value : fallback;
}

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}
