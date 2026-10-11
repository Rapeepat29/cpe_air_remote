/**
 * การจัดรูปแบบตัวเลขและเวลาทั้งหมดของเว็บแอป
 *
 * ยกมาจากกติกาเดียวกับแอปมือถือ (lib/utils/number_format.dart) เพื่อให้ตัวเลข
 * บนเว็บกับบนมือถือตรงกัน ถ้าคนละที่ปัดเศษไม่เหมือนกัน ผู้ใช้จะคิดว่าข้อมูลผิด
 */

const thaiDays = [
  'อาทิตย์',
  'จันทร์',
  'อังคาร',
  'พุธ',
  'พฤหัสบดี',
  'ศุกร์',
  'เสาร์',
];

const thaiDaysShort = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

const thaiMonths = [
  'มกราคม',
  'กุมภาพันธ์',
  'มีนาคม',
  'เมษายน',
  'พฤษภาคม',
  'มิถุนายน',
  'กรกฎาคม',
  'สิงหาคม',
  'กันยายน',
  'ตุลาคม',
  'พฤศจิกายน',
  'ธันวาคม',
];

export const DAY_NAMES = thaiDays;
export const DAY_NAMES_SHORT = thaiDaysShort;

/** ตัวเลขทั่วไป มีคอมมาคั่นหลักพัน */
export function decimal(value, digits = 2) {
  const number = Number(value);
  if (!Number.isFinite(number)) return '—';
  return number.toLocaleString('en-US', {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  });
}

/** จำนวนเต็ม */
export function integer(value) {
  const number = Number(value);
  if (!Number.isFinite(number)) return '—';
  return Math.round(number).toLocaleString('en-US');
}

/**
 * จำนวนทศนิยมที่เหมาะกับขนาดของตัวเลข
 *
 * 0.004 kWh ถ้าปัดเหลือ 2 ตำแหน่งจะกลายเป็น 0.00 แล้วดูเหมือนไม่มีข้อมูล
 * ตัวเลขยิ่งเล็กจึงยิ่งต้องการทศนิยมมากขึ้น
 */
function energyDigits(kwh) {
  const size = Math.abs(kwh);
  if (size >= 100) return 0;
  if (size >= 10) return 1;
  if (size >= 1) return 2;
  return 3;
}

/**
 * แสดงพลังงานพร้อมหน่วยที่อ่านง่าย
 *
 * `scaleReference` คือค่าที่ใหญ่ที่สุดในชุดเดียวกัน ส่งมาด้วยเพื่อให้ทุกจุด
 * ในกราฟเดียวกันใช้หน่วยเดียวกัน ไม่ใช่บางจุดเป็น Wh บางจุดเป็น kWh
 */
export function energy(kwh, { scaleReference = null, withUnit = true } = {}) {
  const number = Number(kwh);
  if (!Number.isFinite(number)) return withUnit ? '— kWh' : '—';
  // ศูนย์พอดีเขียนว่า 0 เฉย ๆ ไม่ใช่ 0.000 เพราะทศนิยมสามตำแหน่งของค่าศูนย์
  // ทำให้ช่องที่ไม่มีข้อมูลดูเหมือนมีข้อมูลที่ละเอียดมาก
  if (number === 0) return withUnit ? '0 kWh' : '0';

  const reference = Math.abs(
    scaleReference == null ? number : Number(scaleReference),
  );

  if (reference > 0 && reference < 1) {
    const watts = number * 1000;
    return `${decimal(watts, watts >= 100 ? 0 : 1)}${withUnit ? ' Wh' : ''}`;
  }
  if (reference >= 1000) {
    const mega = number / 1000;
    return `${decimal(mega, 2)}${withUnit ? ' MWh' : ''}`;
  }
  return `${decimal(number, energyDigits(number))}${withUnit ? ' kWh' : ''}`;
}

/** หน่วยที่ชุดตัวเลขชุดนี้จะใช้ ใช้เขียนกำกับแกนกราฟ */
export function energyUnit(scaleReference) {
  const reference = Math.abs(Number(scaleReference) || 0);
  if (reference > 0 && reference < 1) return 'Wh';
  if (reference >= 1000) return 'MWh';
  return 'kWh';
}

/** ค่าที่ใหญ่ที่สุดในชุด ใช้เป็นตัวอ้างอิงหน่วย */
export function scaleReference(values) {
  let max = 0;
  for (const value of values) {
    const size = Math.abs(Number(value) || 0);
    if (size > max) max = size;
  }
  return max;
}

/** เงินบาท */
export function baht(value) {
  return `${decimal(value, 2)} บาท`;
}

/** เวลานับถอยหลัง mm:ss */
export function clock(totalSeconds) {
  const seconds = Math.max(0, Math.floor(Number(totalSeconds) || 0));
  const minutes = Math.floor(seconds / 60);
  const rest = seconds % 60;
  return `${String(minutes).padStart(2, '0')}:${String(rest).padStart(2, '0')}`;
}

/** ระยะเวลาเป็นคำอ่าน เช่น 2 ชม. 15 นาที */
export function duration(minutes) {
  const total = Math.max(0, Math.round(Number(minutes) || 0));
  if (total < 60) return `${total} นาที`;
  const hours = Math.floor(total / 60);
  const rest = total % 60;
  return rest === 0 ? `${hours} ชม.` : `${hours} ชม. ${rest} นาที`;
}

function toDate(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

/** เวลา HH:mm ตามเวลาเครื่องผู้ใช้ */
export function time(value) {
  const date = toDate(value);
  if (!date) return '—';
  return `${String(date.getHours()).padStart(2, '0')}:${String(
    date.getMinutes(),
  ).padStart(2, '0')}`;
}

/** วันที่แบบไทยเต็ม เช่น วันอังคารที่ 25 สิงหาคม 2569 */
export function thaiFullDate(value = new Date()) {
  const date = toDate(value);
  if (!date) return '—';
  return (
    `วัน${thaiDays[date.getDay()]}ที่ ${date.getDate()} ` +
    `${thaiMonths[date.getMonth()]} ${date.getFullYear() + 543}`
  );
}

/**
 * ชื่อเดือนย่อตามแบบราชการ ตัดสามตัวแรกของชื่อเต็มไม่ได้
 * (ตุลาคม → "ตุล." สิงหาคม → "สิง." ซึ่งไม่มีใครเขียนแบบนั้น)
 */
const thaiMonthsShort = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

/** วันที่สั้น 25 ส.ค. 69 */
export function thaiShortDate(value) {
  const date = toDate(value);
  if (!date) return '—';
  const month = thaiMonthsShort[date.getMonth()];
  return `${date.getDate()} ${month} ${String((date.getFullYear() + 543) % 100).padStart(2, '0')}`;
}

/**
 * วันที่ย่อแบบปีเต็ม เช่น 25 ส.ค. 2569
 *
 * รับ YYYY-MM-DD ของ Backend ได้ตรง ๆ โดยอ่านเป็นวันท้องถิ่น
 * (new Date('2026-08-25') ตีเป็นเที่ยงคืน UTC ซึ่งบางเขตเวลาเลื่อนไปเป็นวันก่อน)
 */
export function thaiDate(value) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value ?? ''));
  const date = match
    ? new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]))
    : toDate(value);
  if (!date) return value ? String(value) : '—';
  return `${date.getDate()} ${thaiMonthsShort[date.getMonth()]} ${date.getFullYear() + 543}`;
}

/** เวลาที่ผ่านมาแล้ว เช่น 5 นาทีที่แล้ว */
export function relativeTime(value) {
  const date = toDate(value);
  if (!date) return '—';
  const seconds = Math.round((Date.now() - date.getTime()) / 1000);
  if (seconds < 45) return 'เมื่อสักครู่';
  if (seconds < 3600) return `${Math.round(seconds / 60)} นาทีที่แล้ว`;
  if (seconds < 86400) return `${Math.round(seconds / 3600)} ชม.ที่แล้ว`;
  if (seconds < 604800) return `${Math.round(seconds / 86400)} วันที่แล้ว`;
  return thaiShortDate(date);
}

/** YYYY-MM-DD ของเวลาท้องถิ่น (ไม่ใช้ toISOString เพราะมันแปลงเป็น UTC) */
export function isoDate(value = new Date()) {
  const date = toDate(value) ?? new Date();
  return (
    `${date.getFullYear()}-` +
    `${String(date.getMonth() + 1).padStart(2, '0')}-` +
    `${String(date.getDate()).padStart(2, '0')}`
  );
}

/** เลื่อนวันแบบไม่แตะเวลา */
export function shiftDays(isoText, days) {
  const [year, month, day] = String(isoText)
    .split('-')
    .map((part) => Number.parseInt(part, 10));
  const date = new Date(year, month - 1, day);
  date.setDate(date.getDate() + days);
  return isoDate(date);
}

/** ชื่อชั้นที่คนอ่านเข้าใจ */
export function floorLabel(floorNumber) {
  const floor = Number(floorNumber);
  if (!Number.isFinite(floor) || floor <= 0) return 'ห้องพิเศษ';
  return `ชั้น ${floor}`;
}

/**
 * รหัสรายละเอียดที่ Backend ใส่มาในช่อง detail (ดู services/auto-off.js)
 * เก็บเป็นรหัสเพื่อให้แปลได้หลายภาษา ถ้าเอาไปแสดงตรง ๆ ผู้ใช้จะเห็น
 * "noScheduleAtAll" ซึ่งไม่มีความหมายอะไรสำหรับคนดูแลอาคาร
 */
const ALERT_DETAIL_TEXT = {
  noClassNow: 'มีคนอยู่ในห้องและแอร์ทำงานอยู่ แต่ช่วงเวลานี้ไม่มีคาบเรียน',
  noScheduleAtAll:
    'มีคนอยู่ในห้องและแอร์ทำงานอยู่ แต่ห้องนี้ยังไม่มีตารางเรียนในระบบ',
  outsideTerm: 'มีคนอยู่ในห้องและแอร์ทำงานอยู่ ระหว่างช่วงปิดภาคเรียน',
};

/** ดึงจำนวนครั้งจากรายละเอียดรูปแบบ "attempts=3" ที่ระบบปิดอัตโนมัติใส่มา */
function attemptsOf(alert) {
  const match = /^attempts=(\d+)$/.exec(String(alert.detail ?? '').trim());
  return match ? Number(match[1]) : null;
}

function alertDetail(alert, fallback) {
  const detail = String(alert.detail ?? '').trim();
  if (!detail || attemptsOf(alert) != null) return fallback;
  return ALERT_DETAIL_TEXT[detail] ?? detail;
}

/** ข้อความอธิบายการแจ้งเตือนแต่ละชนิด ให้ตรงกับที่แอปมือถือใช้ */
export function describeAlert(alert) {
  const room = alert.roomNumber ?? '—';
  const device = alert.deviceName || alert.deviceId || '';
  switch (alert.kind) {
    case 'outside_schedule_occupied': {
      const body = alertDetail(
        alert,
        'มีคนอยู่ในห้องและแอร์ทำงานอยู่ แต่ช่วงเวลานี้ไม่มีคาบเรียน',
      );
      return {
        title: `ห้อง ${room} ใช้แอร์นอกคาบเรียน`,
        body: device ? `${device} · ${body}` : body,
      };
    }
    case 'auto_off_succeeded': {
      const attempts = attemptsOf(alert);
      return {
        title: `ปิดแอร์อัตโนมัติสำเร็จ · ห้อง ${room}`,
        body: alertDetail(
          alert,
          `${device} หยุดทำงานแล้วหลังจากห้องว่าง` +
            (attempts ? ` (ส่งคำสั่ง ${attempts} ครั้ง)` : ''),
        ),
      };
    }
    case 'auto_off_failed': {
      const attempts = attemptsOf(alert);
      return {
        title: `สั่งปิดแอร์ไม่สำเร็จ · ห้อง ${room}`,
        body: alertDetail(
          alert,
          attempts
            ? `${device} ยังทำงานอยู่ แม้ส่งคำสั่งปิดครบ ${attempts} ครั้งแล้ว ควรไปตรวจที่ห้อง`
            : `${device} ยังทำงานอยู่หลังส่งคำสั่งปิดครบจำนวนครั้งแล้ว`,
        ),
      };
    }
    default:
      return {
        title: `ห้อง ${room}`,
        body: alertDetail(alert, alert.kind),
      };
  }
}

/** ชื่อสถานะการแจ้งเตือน */
export const ALERT_STATUS_LABEL = {
  open: 'รอดำเนินการ',
  acknowledged: 'รับทราบแล้ว',
  resolved: 'จบแล้ว',
};

/** ชื่อโหมดแอร์ */
export const MODE_LABEL = {
  auto: 'อัตโนมัติ',
  cool: 'ทำความเย็น',
  dry: 'ลดความชื้น',
  fan: 'พัดลม',
  heat: 'ทำความร้อน',
};

export const FAN_LABEL = {
  auto: 'อัตโนมัติ',
  low: 'ระดับ 1',
  medium: 'ระดับ 2',
  high: 'ระดับ 3',
  turbo: 'เทอร์โบ',
};

export const SWING_LABEL = {
  off: 'ปิด',
  top: 'บนสุด',
  upper: 'ค่อนบน',
  middle: 'กลาง',
  lower: 'ค่อนล่าง',
  bottom: 'ล่างสุด',
  auto: 'ส่ายอัตโนมัติ',
};

/** บอร์ดรุ่นสายแอร์ (ต่อสายแอร์แทนรีโมตติดผนัง Daikin) */
export const WIRED_PROTOCOL = 'DAIKIN_WIRED';

export const isWiredProtocol = (protocol) =>
  String(protocol ?? '').trim().toUpperCase() === WIRED_PROTOCOL;

const BRAND_BY_PROTOCOL = {
  DAIKIN_WIRED: 'Daikin',
  DAIKIN: 'Daikin',
  SAIJO_DENKI: 'Saijo Denki',
  MITSUBISHI_AC: 'Mitsubishi Electric',
  PANASONIC_AC: 'Panasonic',
  GREE: 'Gree',
  MIDEA: 'Midea',
  LG: 'LG',
  SAMSUNG_AC: 'Samsung',
  TOSHIBA_AC: 'Toshiba',
  HITACHI_AC: 'Hitachi',
  FUJITSU_AC: 'Fujitsu',
  KELVINATOR: 'Kelvinator',
  SHARP_AC: 'Sharp',
  ELECTRA_AC: 'Electra',
  HAIER_AC: 'Haier',
  HAIER_AC160: 'Haier',
  HAIER_AC176: 'Haier',
  HAIER_AC_YRW02: 'Haier',
};

/** ยี่ห้อแอร์จากชื่อโปรโตคอล เช่น HAIER_AC160 → Haier */
export function airBrand(protocol) {
  const key = String(protocol ?? '').trim().toUpperCase();
  return BRAND_BY_PROTOCOL[key] ?? (key || '—');
}

/** "สายแอร์" หรือ "รีโมต IR" */
export function controlTypeLabel(protocol) {
  return isWiredProtocol(protocol) ? 'สายแอร์' : 'รีโมต IR';
}

/** ข้อความสั้นสำหรับรายการ เช่น "Daikin · สายแอร์" หรือ "Haier · รีโมต IR (HAIER_AC160)" */
export function airControlSummary(protocol) {
  if (isWiredProtocol(protocol)) return `${airBrand(protocol)} · สายแอร์`;
  return `${airBrand(protocol)} · รีโมต IR (${protocol})`;
}
