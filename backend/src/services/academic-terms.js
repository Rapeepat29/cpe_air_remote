import { pool } from '../db.js';
import { ApiError } from '../utils/http.js';
import { bangkokDate, termStatus } from '../utils/class-schedule.js';
import { readTimetableInfo } from './system-settings.js';

// ปฏิทินภาคเรียน: วันเปิด-ปิดของแต่ละเทอม
//
// ตารางเรียนในระบบมีชุดเดียว (ของภาคเรียนใน system_settings.timetable_semester)
// ถ้าภาคเรียนนั้นมีวันเปิด-ปิดในตารางนี้ ตารางจะมีผลเฉพาะในช่วงนั้น นอกช่วงถือว่า
// ทุกห้องอยู่นอกคาบ ห้องจึงถูกปิดแอร์เร็วช่วงปิดภาคโดยไม่ต้องลบตารางทิ้ง
// และนำเข้าตารางเทอมหน้าไว้ล่วงหน้าได้ พอถึงวันเปิดภาคจะเริ่มใช้เอง

const SEMESTER_PATTERN = /^[1-3]\/\d{4}$/;
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

// ตัวคุมจังหวะปิดแอร์อ่านทุกเครื่องทุก 10 วินาที และ MQTT อ่านทุกครั้งที่บอร์ด
// ส่งสถานะ จึงพักค่าไว้สั้น ๆ แล้วล้างทันทีที่มีการแก้ปฏิทินหรือนำเข้าตาราง
const CACHE_TTL_MS = 15000;
let cachedAt = 0;
let cachedGate;

export function clearTermCache() {
  cachedAt = 0;
  cachedGate = undefined;
}

export function validateTermInput(body) {
  const semester = String(body?.semester ?? '').trim();
  const startDate = String(body?.startDate ?? '').trim();
  const endDate = String(body?.endDate ?? '').trim();

  if (!SEMESTER_PATTERN.test(semester)) {
    throw new ApiError(400, 'ภาคเรียนต้องเป็นรูปแบบ เทอม/ปีการศึกษา เช่น 1/2569');
  }
  if (!isRealDate(startDate) || !isRealDate(endDate)) {
    throw new ApiError(400, 'วันเปิดและวันปิดภาคเรียนต้องเป็นวันที่ที่ถูกต้อง');
  }
  if (endDate < startDate) {
    throw new ApiError(400, 'วันปิดภาคเรียนต้องไม่ก่อนวันเปิดภาคเรียน');
  }
  return { semester, startDate, endDate };
}

function isRealDate(value) {
  if (!DATE_PATTERN.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function publicTerm(row, now) {
  const term = {
    semester: row.semester,
    startDate: row.start_date,
    endDate: row.end_date,
    updatedBy: row.updated_by ?? null,
  };
  return { ...term, status: termStatus(term, now) };
}

/** ภาคเรียนทั้งหมด เรียงตามวันเปิด คืน [] ถ้ายังไม่ได้สร้างตาราง (ยังไม่ได้ deploy schema) */
export async function readTerms(database = pool, now = new Date()) {
  try {
    const rows = await database.query(
      `SELECT semester,
              DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
              DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date,
              updated_by
         FROM academic_terms
        ORDER BY start_date, semester`,
    );
    return rows.map((row) => publicTerm(row, now));
  } catch (error) {
    if (error?.code === 'ER_NO_SUCH_TABLE') return [];
    throw error;
  }
}

export async function upsertTerm(input, username, database = pool) {
  const term = validateTermInput(input);
  await database.query(
    `INSERT INTO academic_terms (semester, start_date, end_date, updated_by)
     VALUES (?, ?, ?, ?)
     ON DUPLICATE KEY UPDATE start_date = VALUES(start_date),
                             end_date = VALUES(end_date),
                             updated_by = VALUES(updated_by)`,
    [term.semester, term.startDate, term.endDate, username ?? null],
  );
  clearTermCache();
  return { ...term, status: termStatus(term) };
}

export async function deleteTerm(semester, database = pool) {
  const value = String(semester ?? '').trim();
  const result = await database.query(
    'DELETE FROM academic_terms WHERE semester = ?',
    [value],
  );
  clearTermCache();
  if (Number(result.affectedRows) === 0) {
    throw new ApiError(404, 'ไม่พบภาคเรียนนี้ในปฏิทิน');
  }
}

/**
 * วันเปิด-ปิดของภาคเรียนที่ตารางเรียนปัจจุบันเป็นของมัน
 *
 * คืน null เมื่อไม่รู้ว่าตารางเป็นภาคเรียนไหน หรือภาคเรียนนั้นไม่ได้ตั้งวันไว้
 * ซึ่งแปลว่าใช้ตารางทุกวันเหมือนก่อนมีฟีเจอร์นี้
 */
export async function readActiveTermGate() {
  const now = Date.now();
  if (cachedGate !== undefined && now - cachedAt < CACHE_TTL_MS) {
    return cachedGate;
  }
  let gate = null;
  try {
    const info = await readTimetableInfo();
    if (info?.semester) {
      const rows = await pool.query(
        `SELECT semester,
                DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
                DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date
           FROM academic_terms
          WHERE semester = ?
          LIMIT 1`,
        [info.semester],
      );
      if (rows[0]) {
        gate = {
          semester: rows[0].semester,
          startDate: rows[0].start_date,
          endDate: rows[0].end_date,
        };
      }
    }
  } catch (error) {
    // ยังไม่มีตาราง academic_terms = ยังไม่ได้ตั้งปฏิทิน ใช้ตารางเรียนแบบเดิม
    // ความผิดพลาดอื่นก็ไม่ควรทำให้ระบบปิดแอร์ล้มทั้งตัว จึงถอยไปใช้แบบเดิมเช่นกัน
    if (error?.code !== 'ER_NO_SUCH_TABLE') {
      console.warn('[academic-terms] อ่านปฏิทินภาคเรียนไม่สำเร็จ:', error?.message ?? error);
    }
    gate = null;
  }
  cachedGate = gate;
  cachedAt = now;
  return gate;
}

/** ข้อมูลสำหรับหน้าเว็บ: ปฏิทินทั้งหมด + วันนี้ตามเวลาไทย */
export async function readCalendar() {
  const now = new Date();
  return {
    today: bangkokDate(now),
    terms: await readTerms(pool, now),
  };
}
