import { ApiError } from './http.js';

// ชื่อไฟล์เฟิร์มแวร์ต้องเป็นอักษรที่ปลอดภัยใน URL และลงท้าย .bin
// (บอร์ดตรวจกฎเดียวกันอีกชั้นก่อนดาวน์โหลด)
const FILE_PATTERN = /^[A-Za-z0-9][A-Za-z0-9._-]{0,118}\.bin$/;

export function validateFirmwareFileName(value) {
  const name = typeof value === 'string' ? value.trim() : '';
  if (!FILE_PATTERN.test(name) || name.includes('..')) {
    throw new ApiError(
      400,
      'ชื่อไฟล์เฟิร์มแวร์ไม่ถูกต้อง (ใช้ได้เฉพาะ A–Z, 0–9, จุด, ขีด และลงท้าย .bin)',
    );
  }
  return name;
}

/**
 * URL ที่บอร์ดจะดาวน์โหลด ต้องเป็นโฮสต์เดียวกับ MQTT host ที่บอร์ดถูกตั้งไว้
 * เพราะเฟิร์มแวร์ปฏิเสธ URL ที่ชี้ไปโฮสต์อื่น
 */
export function firmwareUrl(host, fileName) {
  const cleanHost = String(host ?? '').trim();
  if (!cleanHost || !/^[A-Za-z0-9.-]+$/.test(cleanHost)) {
    throw new ApiError(409, 'บอร์ดนี้ไม่มีชื่อโฮสต์ของเซิร์ฟเวอร์ที่ใช้ดาวน์โหลดได้');
  }
  return `https://${cleanHost}/firmware/${validateFirmwareFileName(fileName)}`;
}

/** เดาชนิดบอร์ดจากชื่อไฟล์ ใช้จัดกลุ่มในหน้าจอเท่านั้น */
export function firmwareKindOf(fileName) {
  return /occ/i.test(fileName) ? 'occupancy' : 'air';
}
