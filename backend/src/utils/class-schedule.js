// ตัวช่วยอ่านตารางเรียนตามเวลาไทย
//
// แยกออกมาจาก services/mqtt.js เพราะทั้ง MQTT bridge และระบบปิดแอร์อัตโนมัติ
// ต้องใช้ร่วมกัน ถ้าปล่อยไว้ที่เดิมจะเกิดการ import วนกันเอง

export const BANGKOK_TIMEZONE = 'Asia/Bangkok';

/**
 * ตอนนี้อยู่ในคาบเรียนของห้องนั้นหรือไม่
 *
 * @param {Array<{day_of_week:number,start_time:string,end_time:string}>} schedules
 * @param {Date} now
 */
export function evaluateClassSchedule(schedules, now, { term = null } = {}) {
  const values = Array.isArray(schedules) ? schedules : [];
  const clock = bangkokClock(now);
  const termState = termStatus(term, now);

  // นอกวันเปิด-ปิดภาคเรียน: ตารางยังอยู่ แต่ไม่มีคาบไหนมีผล ห้องถือว่าอยู่นอกคาบ
  // configured ยังเป็น true เพื่อให้บอร์ดเชื่อผลนี้ ไม่ถอยไปใช้เวลาเปิด-ปิดประจำวันของตัวเอง
  if (termState === 'before' || termState === 'after') {
    return {
      configured: values.length > 0,
      withinSchedule: false,
      termStatus: termState,
      dayOfWeek: clock.dayOfWeek,
      minutesOfDay: clock.minutesOfDay,
    };
  }

  const withinSchedule = values.some((schedule) => {
    if (Number(schedule.day_of_week) !== clock.dayOfWeek) return false;
    const start = timeToMinutes(schedule.start_time);
    const end = timeToMinutes(schedule.end_time);
    return start != null &&
      end != null &&
      clock.minutesOfDay >= start &&
      clock.minutesOfDay < end;
  });
  return {
    configured: values.length > 0,
    withinSchedule,
    termStatus: termState,
    dayOfWeek: clock.dayOfWeek,
    minutesOfDay: clock.minutesOfDay,
  };
}

/**
 * วันนี้ (ตามเวลาไทย) อยู่ตรงไหนของภาคเรียน
 *
 * 'none'   = ไม่ได้ตั้งวันเปิด-ปิดไว้ ใช้ตารางทุกวันเหมือนเดิม
 * 'before' = ยังไม่ถึงวันเปิดภาค, 'active' = อยู่ในภาค (รวมวันเปิดและวันปิด),
 * 'after'  = เลยวันปิดภาคแล้ว
 *
 * @param {{startDate:string,endDate:string}|null} term วันที่รูปแบบ YYYY-MM-DD
 */
export function termStatus(term, now = new Date()) {
  const start = normalizeDate(term?.startDate);
  const end = normalizeDate(term?.endDate);
  if (!start || !end) return 'none';
  const today = bangkokDate(now);
  if (today < start) return 'before';
  if (today > end) return 'after';
  return 'active';
}

/** วันที่ปัจจุบันตามเวลาไทยในรูป YYYY-MM-DD (เรียงแบบข้อความได้ตรงกับเรียงตามวัน) */
export function bangkokDate(value = new Date()) {
  const date = value instanceof Date ? value : new Date(value);
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: BANGKOK_TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).formatToParts(date);
  const part = (type) => parts.find((item) => item.type === type)?.value;
  return `${part('year')}-${part('month')}-${part('day')}`;
}

function normalizeDate(value) {
  if (value instanceof Date) {
    if (Number.isNaN(value.getTime())) return '';
    const pad = (n) => String(n).padStart(2, '0');
    return `${value.getFullYear()}-${pad(value.getMonth() + 1)}-${pad(value.getDate())}`;
  }
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(value ?? ''));
  return match ? `${match[1]}-${match[2]}-${match[3]}` : '';
}

export function bangkokClock(value) {
  const date = value instanceof Date ? value : new Date(value);
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone: BANGKOK_TIMEZONE,
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const part = (type) => parts.find((item) => item.type === type)?.value;
  const dayOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
    .indexOf(part('weekday'));
  const hour = Number(part('hour'));
  const minute = Number(part('minute'));
  return { dayOfWeek, minutesOfDay: hour * 60 + minute };
}

export function timeToMinutes(value) {
  const match = /^(\d{2}):(\d{2})/.exec(String(value ?? ''));
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return null;
  return hour * 60 + minute;
}
