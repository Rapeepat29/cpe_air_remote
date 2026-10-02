import { pool } from '../db.js';

// ค่าตั้งระดับระบบ เก็บเป็นคู่คีย์-ค่าในตารางเดียว
//
// ต่างจากค่าตั้งในแอปตรงที่ค่าพวกนี้เป็นของ "ทั้งอาคาร" ไม่ใช่ของเครื่องใคร
// สวิตช์ปิดแอร์อัตโนมัติต้องอยู่ตรงนี้ เพราะตัวที่ยิงคำสั่งปิดคือ Backend
// ถ้าเก็บไว้ในมือถือ ปิดแล้วเครื่องอื่นก็ยังโดนสั่งปิดอยู่ดี

export const SETTING_KEYS = {
  /** สวิตช์รวมของระบบปิดแอร์อัตโนมัติ */
  AUTO_OFF_ENABLED: 'auto_off_enabled',
  /** อัตราค่าไฟต่อ kWh ที่ใช้คำนวณตัวเลขค่าใช้จ่ายโดยประมาณ */
  ELECTRICITY_RATE: 'electricity_rate',
  /**
   * ภาคเรียนของตารางเรียนที่ใช้อยู่ (เช่น "2/2569") พร้อมผู้นำเข้าและเวลา
   * (updated_by / updated_at) มีไว้ให้คนดูแลเห็นว่าตารางในระบบเป็นของเทอมไหน
   * ไม่ได้ใช้ตัดสินอะไรในระบบปิดแอร์อัตโนมัติ
   */
  TIMETABLE_SEMESTER: 'timetable_semester',
};

/**
 * ค่าเริ่มต้นเมื่อยังไม่เคยมีใครตั้ง
 *
 * เปิดไว้ เพราะระบบนี้คือเหตุผลหลักของโปรเจกต์ ถ้าปิดไว้เป็นค่าเริ่มต้น
 * แล้วลืมเปิด จะดูเหมือนระบบพังทั้งที่แค่ยังไม่ได้เปิด
 *
 * อัตราค่าไฟตั้งต้น 4.50 บาท/kWh เป็นค่าที่ใช้ในเอกสารของอาคาร ปรับได้
 * จากหน้า `อัตราค่าไฟ` บนเว็บแอป
 */
const DEFAULTS = {
  [SETTING_KEYS.AUTO_OFF_ENABLED]: true,
  [SETTING_KEYS.ELECTRICITY_RATE]: 4.5,
};

/** ขอบเขตของอัตราค่าไฟที่ยอมรับ กันพิมพ์ผิดจนตัวเลขค่าไฟเพี้ยนทั้งระบบ */
export const RATE_LIMITS = { min: 0.01, max: 100 };

// ตัวคุมจังหวะเรียกทุก 10 วินาที และเรียกซ้ำทุกครั้งที่บอร์ดส่งสถานะเข้ามา
// ถ้าอ่านฐานข้อมูลทุกครั้งจะเปลืองเปล่า จึงพักค่าไว้สั้น ๆ
const CACHE_TTL_MS = 5000;

let cachedAt = 0;
let cachedValues = null;

/** ล้างค่าที่พักไว้ ใช้ในเทสต์และทันทีที่มีการเขียนค่าใหม่ */
export function clearSettingsCache() {
  cachedAt = 0;
  cachedValues = null;
}

function parseBoolean(raw, fallback) {
  if (raw === null || raw === undefined) return fallback;
  const text = String(raw).trim().toLowerCase();
  if (['1', 'true', 'on', 'yes'].includes(text)) return true;
  if (['0', 'false', 'off', 'no'].includes(text)) return false;
  return fallback;
}

/**
 * แปลงอัตราค่าไฟจากข้อความในฐานข้อมูล
 *
 * ค่าที่อ่านไม่ออกหรืออยู่นอกขอบเขตจะถอยไปใช้ค่าเริ่มต้น แทนที่จะปล่อย NaN
 * ออกไป เพราะ NaN จะไหลไปโผล่เป็น "NaN บาท" ทุกหน้าจอโดยไม่มีใครรู้ต้นเหตุ
 */
export function parseRate(raw, fallback = DEFAULTS[SETTING_KEYS.ELECTRICITY_RATE]) {
  const value = Number.parseFloat(String(raw ?? '').trim());
  if (!Number.isFinite(value)) return fallback;
  if (value < RATE_LIMITS.min || value > RATE_LIMITS.max) return fallback;
  return Math.round(value * 100) / 100;
}

async function readAll() {
  const now = Date.now();
  if (cachedValues && now - cachedAt < CACHE_TTL_MS) {
    return cachedValues;
  }

  const values = { ...DEFAULTS };
  try {
    const rows = await pool.query(
      'SELECT setting_key, setting_value FROM system_settings',
    );
    for (const row of rows) {
      if (row.setting_key === SETTING_KEYS.AUTO_OFF_ENABLED) {
        values[row.setting_key] = parseBoolean(
          row.setting_value,
          DEFAULTS[row.setting_key],
        );
      } else if (row.setting_key === SETTING_KEYS.ELECTRICITY_RATE) {
        values[row.setting_key] = parseRate(row.setting_value);
      }
    }
  } catch (error) {
    // ตารางยังไม่ถูกสร้าง (ยังไม่ได้รัน migration) ให้ถอยไปใช้ค่าเริ่มต้น
    // ระบบเดิมจะได้ทำงานต่อเหมือนก่อนอัปเดต แทนที่จะล้มทั้งตัวคุมจังหวะ
    if (error?.code !== 'ER_NO_SUCH_TABLE') throw error;
  }

  cachedValues = values;
  cachedAt = now;
  return values;
}

/** สวิตช์รวมของระบบปิดแอร์อัตโนมัติเปิดอยู่หรือไม่ */
export async function isAutoOffEnabled() {
  const values = await readAll();
  return values[SETTING_KEYS.AUTO_OFF_ENABLED];
}

/** อัตราค่าไฟต่อ kWh ที่ใช้อยู่ */
export async function readElectricityRate() {
  const values = await readAll();
  return values[SETTING_KEYS.ELECTRICITY_RATE];
}

/** ค่าตั้งทั้งหมดในรูปแบบที่แอปใช้ได้เลย */
export async function readPublicSettings() {
  const values = await readAll();
  return {
    autoOffEnabled: values[SETTING_KEYS.AUTO_OFF_ENABLED],
    electricityRate: values[SETTING_KEYS.ELECTRICITY_RATE],
  };
}

/**
 * เขียนค่าหนึ่งช่อง
 *
 * บันทึกชื่อคนกดไว้ด้วย เพราะเป็นค่าที่กระทบทั้งอาคาร เวลามีคนถามว่า
 * ทำไมแอร์ไม่ปิดเอง หรือทำไมค่าไฟที่คำนวณเปลี่ยนไป จะได้ตอบได้ว่าใครแก้
 */
async function writeSetting(key, value, username) {
  await pool.query(
    `INSERT INTO system_settings (setting_key, setting_value, updated_by)
     VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value),
                             updated_by = VALUES(updated_by),
                             updated_at = CURRENT_TIMESTAMP`,
    [key, value, username ?? null],
  );
  clearSettingsCache();
  return readPublicSettings();
}

/** เขียนสวิตช์รวมของระบบปิดแอร์อัตโนมัติ */
export async function setAutoOffEnabled(enabled, username) {
  return writeSetting(
    SETTING_KEYS.AUTO_OFF_ENABLED,
    enabled ? 'true' : 'false',
    username,
  );
}

/**
 * เขียนอัตราค่าไฟ
 *
 * เก็บเป็นข้อความสองตำแหน่งทศนิยมคงที่ เพื่อให้ค่าที่อ่านกลับมาเท่าเดิมเป๊ะ
 * ไม่ต้องลุ้นเรื่องการปัดเศษของเลขทศนิยมฐานสอง
 */
export async function setElectricityRate(rate, username) {
  const value = Number(rate);
  if (
    !Number.isFinite(value)
    || value < RATE_LIMITS.min
    || value > RATE_LIMITS.max
  ) {
    const error = new Error(
      `อัตราค่าไฟต้องอยู่ระหว่าง ${RATE_LIMITS.min} ถึง ${RATE_LIMITS.max} บาทต่อ kWh`,
    );
    error.statusCode = 400;
    throw error;
  }
  return writeSetting(
    SETTING_KEYS.ELECTRICITY_RATE,
    (Math.round(value * 100) / 100).toFixed(2),
    username,
  );
}

// ------------------------------------------------------- ข้อมูลตารางเรียน

/**
 * ภาคเรียนของตารางเรียนที่ใช้อยู่ และใครนำเข้าเมื่อไร
 *
 * คืน null ถ้ายังไม่เคยนำเข้าจากไฟล์ (หรือเพิ่งล้างตารางทั้งหมด)
 * ไม่ผ่านแคชของค่าตั้งอื่น เพราะอ่านเฉพาะตอนเปิดหน้าตารางเรียน
 */
export async function readTimetableInfo(database = pool) {
  try {
    const rows = await database.query(
      `SELECT setting_value, updated_by, updated_at
         FROM system_settings
        WHERE setting_key = ?
        LIMIT 1`,
      [SETTING_KEYS.TIMETABLE_SEMESTER],
    );
    const row = rows[0];
    if (!row) return null;
    return {
      semester: String(row.setting_value ?? ''),
      importedBy: row.updated_by ?? null,
      importedAt: row.updated_at == null
        ? null
        : new Date(row.updated_at).toISOString(),
    };
  } catch (error) {
    if (error?.code === 'ER_NO_SUCH_TABLE') return null;
    throw error;
  }
}

/**
 * บันทึกว่าเพิ่งนำเข้าตารางเรียน
 *
 * ไฟล์ CSV บางไฟล์ไม่มีคอลัมน์ภาคเรียน: ถ้านำเข้าบางห้องก็คงภาคเรียนเดิมไว้
 * แต่ถ้าล้างทุกห้อง (เปลี่ยนภาคเรียน) ภาคเรียนเดิมไม่จริงแล้ว จึงเว้นว่าง
 */
export async function recordTimetableImport(
  { semester, replaceAll, username },
  database = pool,
) {
  let value = String(semester ?? '').trim();
  if (!value && !replaceAll) {
    value = (await readTimetableInfo(database))?.semester ?? '';
  }
  await database.query(
    `INSERT INTO system_settings (setting_key, setting_value, updated_by)
     VALUES (?, ?, ?)
     ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value),
                             updated_by = VALUES(updated_by),
                             updated_at = CURRENT_TIMESTAMP`,
    [SETTING_KEYS.TIMETABLE_SEMESTER, value.slice(0, 255), username ?? null],
  );
}

/** ลืมภาคเรียนที่บันทึกไว้ ใช้ตอนล้างตารางเรียนทั้งหมด */
export async function clearTimetableInfo(database = pool) {
  try {
    await database.query(
      'DELETE FROM system_settings WHERE setting_key = ?',
      [SETTING_KEYS.TIMETABLE_SEMESTER],
    );
  } catch (error) {
    if (error?.code !== 'ER_NO_SUCH_TABLE') throw error;
  }
}
