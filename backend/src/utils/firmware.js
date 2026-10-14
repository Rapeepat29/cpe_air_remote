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

/**
 * ชนิดบอร์ดจากชื่อไฟล์ ใช้จัดกลุ่มในหน้าจอ และกันสั่งไฟล์ผิดชนิดให้บอร์ด
 *   occupancy = เซ็นเซอร์ LD2410 (ชื่อมีคำว่า occ)
 *   wired     = แอร์สาย Daikin SLM8 (ชื่อมีคำว่า wired หรือ slm8)
 *   air       = แอร์ IR (นอกนั้นทั้งหมด)
 */
export function firmwareKindOf(fileName) {
  const name = String(fileName ?? '');
  if (/occ/i.test(name)) return 'occupancy';
  if (/wired|slm8/i.test(name)) return 'wired';
  return 'air';
}

export const FIRMWARE_KIND_LABELS = Object.freeze({
  air: 'แอร์ IR',
  wired: 'สายแอร์ Daikin',
  occupancy: 'เซ็นเซอร์ LD2410',
});

/** ชนิดไฟล์ที่บอร์ดแอร์ตัวนี้ใช้ได้ ตาม protocol ในฐานข้อมูล */
export function airFirmwareKind(protocol) {
  return String(protocol ?? '').trim().toUpperCase() === 'DAIKIN_WIRED'
    ? 'wired'
    : 'air';
}

/** ไฟล์ต้องเป็นชนิดเดียวกับบอร์ด ไม่งั้นบอร์ดจะรีบูตเข้าโปรแกรมของบอร์ดอีกชนิด */
export function assertFirmwareKind(fileName, expectedKind) {
  const kind = firmwareKindOf(fileName);
  if (kind !== expectedKind) {
    throw new ApiError(
      400,
      `ไฟล์ ${fileName} เป็นของ${FIRMWARE_KIND_LABELS[kind]} `
        + `ใช้กับบอร์ด${FIRMWARE_KIND_LABELS[expectedKind]}ไม่ได้`,
    );
  }
}

/**
 * รุ่นจากชื่อไฟล์ เช่น rmutt_esp32_air_wired-2.5.2-slm8.bin -> 2.5.2-slm8
 * คืน null ถ้าชื่อไม่มีเลขรุ่น
 */
export function firmwareVersionOf(fileName) {
  const match = String(fileName ?? '').match(
    /-(\d+\.\d+(?:\.\d+)?(?:-[A-Za-z0-9]+)*)\.bin$/,
  );
  return match ? match[1] : null;
}

/**
 * เทียบรุ่นด้วยตัวเลขข้างหน้า (2.5.10 ใหม่กว่า 2.5.9) ส่วนท้ายอย่าง -slm8 ไม่นับ
 * คืนค่าลบ/0/บวก แบบ comparator ปกติ ถ้าอ่านรุ่นไม่ได้ถือว่าเก่ากว่า
 */
export function compareFirmwareVersions(a, b) {
  const parts = (value) => {
    const match = String(value ?? '').match(/^(\d+)\.(\d+)(?:\.(\d+))?/);
    return match ? [match[1], match[2], match[3] ?? '0'].map(Number) : null;
  };
  const left = parts(a);
  const right = parts(b);
  if (!left && !right) return 0;
  if (!left) return -1;
  if (!right) return 1;
  for (let index = 0; index < 3; index += 1) {
    if (left[index] !== right[index]) return left[index] - right[index];
  }
  return 0;
}

// ช่องโปรแกรมใน partitions.csv (app0/app1) ขนาด 0x1F0000 ไฟล์ใหญ่กว่านี้ใส่ไม่ลง
export const FIRMWARE_MAX_BYTES = 0x1f0000;

/**
 * ตรวจว่าเป็นไฟล์โปรแกรม ESP32 จริง (Sketch > Export Compiled Binary)
 * ไบต์แรกของ ESP image คือ 0xE9 เสมอ ไฟล์ .merged.bin ขึ้นต้นด้วย bootloader
 * ที่ offset 0x1000 จึงไม่ผ่าน ซึ่งถูกแล้ว เพราะ OTA ใช้ได้เฉพาะไฟล์ .ino.bin
 */
export function validateFirmwareImage(buffer) {
  if (!Buffer.isBuffer(buffer) || buffer.length === 0) {
    throw new ApiError(400, 'ไม่ได้แนบไฟล์เฟิร์มแวร์มา');
  }
  if (buffer.length > FIRMWARE_MAX_BYTES) {
    throw new ApiError(
      413,
      `ไฟล์ใหญ่เกินช่องโปรแกรมของบอร์ด (สูงสุด ${Math.floor(FIRMWARE_MAX_BYTES / 1024)} KB)`,
    );
  }
  if (buffer.length < 256 || buffer[0] !== 0xe9) {
    throw new ApiError(
      400,
      'ไฟล์นี้ไม่ใช่โปรแกรม ESP32 ให้ใช้ไฟล์ .ino.bin จาก Sketch → Export Compiled Binary '
        + '(ไม่ใช่ .merged.bin หรือ .bootloader.bin)',
    );
  }
}
