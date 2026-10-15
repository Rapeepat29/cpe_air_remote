// การใช้ห้องนอกตารางเรียน (room_bookings): ตรวจข้อมูล และคำนวณว่าเกิดขึ้นวันไหน
//
// ไฟล์นี้เป็นฟังก์ชันบริสุทธิ์ ไม่แตะฐานข้อมูล ใช้ร่วมกันทั้ง route และระบบปิดแอร์

import { ApiError } from './http.js';
import { bangkokClock, bangkokDate, timeToMinutes } from './class-schedule.js';

export const REPEAT_TYPES = ['once', 'daily', 'weekly'];
export const BOOKING_CATEGORIES = ['class', 'meeting', 'exam', 'event', 'other'];

/** จองล่วงหน้าหรือทำซ้ำได้ยาวสุดกี่วัน กันพิมพ์ปีผิดจนกลายเป็นจองยาวหลายสิบปี */
export const MAX_SPAN_DAYS = 400;

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;
const TIME_PATTERN = /^(?:[01]\d|2[0-3]):[0-5]\d$/;
const ROOM_PATTERN = /^[A-Z0-9][A-Z0-9_-]{1,9}$/;

function text(value, max) {
  return String(value ?? '').trim().replace(/\s+/g, ' ').slice(0, max);
}

function isRealDate(value) {
  if (!DATE_PATTERN.test(value)) return false;
  const date = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

/** วันในสัปดาห์ของวันที่ YYYY-MM-DD (0 = อาทิตย์) ไม่ขึ้นกับเขตเวลาของเครื่อง */
export function dayOfWeekOf(dateString) {
  return new Date(`${dateString}T00:00:00Z`).getUTCDay();
}

export function daysBetween(from, to) {
  return Math.round(
    (Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000,
  );
}

export function parseDays(value) {
  const list = Array.isArray(value) ? value : String(value ?? '').split(',');
  return [...new Set(
    list
      .map((item) => Number.parseInt(String(item).trim(), 10))
      .filter((day) => Number.isInteger(day) && day >= 0 && day <= 6),
  )].sort((a, b) => a - b);
}

export function validateBookingInput(body) {
  const roomNumber = text(body?.roomNumber, 10).toUpperCase();
  const title = text(body?.title, 100);
  const category = BOOKING_CATEGORIES.includes(body?.category) ? body.category : 'other';
  const note = text(body?.note, 255);
  const repeatType = String(body?.repeatType ?? '').trim();
  const startDate = String(body?.startDate ?? '').trim();
  let endDate = String(body?.endDate ?? '').trim();
  const startTime = String(body?.startTime ?? '').trim().slice(0, 5);
  const endTime = String(body?.endTime ?? '').trim().slice(0, 5);

  if (!ROOM_PATTERN.test(roomNumber)) throw new ApiError(400, 'กรุณาเลือกห้อง');
  if (!title) throw new ApiError(400, 'กรุณากรอกชื่อการใช้ห้อง เช่น ประชุมภาควิชา');
  if (!REPEAT_TYPES.includes(repeatType)) {
    throw new ApiError(400, 'รูปแบบการทำซ้ำไม่ถูกต้อง');
  }
  if (!isRealDate(startDate)) throw new ApiError(400, 'วันที่เริ่มไม่ถูกต้อง');
  if (repeatType === 'once') endDate = startDate;
  if (!isRealDate(endDate)) throw new ApiError(400, 'วันที่สิ้นสุดไม่ถูกต้อง');
  if (endDate < startDate) throw new ApiError(400, 'วันที่สิ้นสุดต้องไม่ก่อนวันที่เริ่ม');
  if (daysBetween(startDate, endDate) > MAX_SPAN_DAYS) {
    throw new ApiError(400, `ช่วงวันที่ยาวได้ไม่เกิน ${MAX_SPAN_DAYS} วัน`);
  }
  if (!TIME_PATTERN.test(startTime) || !TIME_PATTERN.test(endTime)) {
    throw new ApiError(400, 'เวลาต้องเป็นรูปแบบ HH:mm');
  }
  if (timeToMinutes(endTime) <= timeToMinutes(startTime)) {
    throw new ApiError(400, 'เวลาสิ้นสุดต้องหลังเวลาเริ่ม');
  }

  let daysOfWeek = [];
  if (repeatType === 'weekly') {
    daysOfWeek = parseDays(body?.daysOfWeek);
    if (daysOfWeek.length === 0) {
      throw new ApiError(400, 'กรุณาเลือกวันในสัปดาห์อย่างน้อยหนึ่งวัน');
    }
  }

  const input = {
    roomNumber,
    title,
    category,
    note,
    repeatType,
    daysOfWeek,
    startDate,
    endDate,
    startTime,
    endTime,
  };
  if (countOccurrences(input) === 0) {
    throw new ApiError(400, 'ในช่วงวันที่ที่เลือกไม่มีวันที่ตรงกับวันในสัปดาห์ที่เลือกเลย');
  }
  return input;
}

/** การจองนี้มีในวันที่ dateString หรือไม่ */
export function bookingOccursOn(booking, dateString) {
  if (!booking || dateString < booking.startDate || dateString > booking.endDate) {
    return false;
  }
  if (booking.repeatType === 'weekly') {
    return parseDays(booking.daysOfWeek).includes(dayOfWeekOf(dateString));
  }
  return true;
}

/** จำนวนครั้งทั้งหมดของการจอง (ใช้สรุปให้ผู้ใช้เห็นก่อนบันทึก) */
export function countOccurrences(booking) {
  const span = daysBetween(booking.startDate, booking.endDate);
  if (span < 0) return 0;
  if (booking.repeatType !== 'weekly') return booking.repeatType === 'once' ? 1 : span + 1;
  const days = new Set(parseDays(booking.daysOfWeek));
  let count = 0;
  const start = Date.parse(`${booking.startDate}T00:00:00Z`);
  for (let index = 0; index <= span; index += 1) {
    if (days.has(new Date(start + index * 86400000).getUTCDay())) count += 1;
  }
  return count;
}

/** การจองที่กำลังใช้ห้องอยู่ ณ เวลา now (ตามเวลาไทย) หรือ null */
export function activeBooking(bookings, now = new Date()) {
  const today = bangkokDate(now);
  const minutes = bangkokClock(now).minutesOfDay;
  return (
    (bookings ?? []).find((booking) => {
      if (!bookingOccursOn(booking, today)) return false;
      const start = timeToMinutes(booking.startTime);
      const end = timeToMinutes(booking.endTime);
      return start != null && end != null && minutes >= start && minutes < end;
    }) ?? null
  );
}

/**
 * รวมผลตารางเรียนกับการจองห้อง
 *
 * ห้องที่มีการจองอยู่ตอนนี้ถือว่า "ในคาบ" แม้ตารางเรียนบอกว่าไม่มีคาบ
 * หรืออยู่นอกภาคเรียน เพราะการจองคือการบอกว่าจะมีคนใช้ห้องจริง
 */
export function withBookings(classResult, bookings, now = new Date()) {
  const booking = activeBooking(bookings, now);
  return {
    ...classResult,
    configured: classResult.configured || (bookings ?? []).length > 0,
    withinSchedule: classResult.withinSchedule || booking != null,
    booking,
  };
}

/** แถวจากฐานข้อมูลเป็นรูปแบบที่ส่งให้แอป */
export function publicBooking(row) {
  return {
    id: row.id,
    roomNumber: row.room_number,
    title: row.title,
    category: row.category,
    note: row.note ?? '',
    repeatType: row.repeat_type,
    daysOfWeek: parseDays(row.days_of_week),
    startDate: row.start_date,
    endDate: row.end_date,
    startTime: String(row.start_time ?? '').slice(0, 5),
    endTime: String(row.end_time ?? '').slice(0, 5),
    createdBy: row.created_by ?? null,
    updatedBy: row.updated_by ?? null,
  };
}
