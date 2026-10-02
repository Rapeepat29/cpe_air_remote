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
export function evaluateClassSchedule(schedules, now) {
  const values = Array.isArray(schedules) ? schedules : [];
  const clock = bangkokClock(now);
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
    dayOfWeek: clock.dayOfWeek,
    minutesOfDay: clock.minutesOfDay,
  };
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
