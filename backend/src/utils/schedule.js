import { ApiError } from './http.js';

export function validateScheduleFilters(query) {
  const floor = parseOptionalInteger(query?.floor);
  const dayOfWeek = parseOptionalInteger(query?.day);

  if (floor != null && (floor < 0 || floor > 99)) {
    throw new ApiError(400, 'ชั้นต้องอยู่ระหว่าง 0 ถึง 99');
  }
  if (dayOfWeek != null && (dayOfWeek < 0 || dayOfWeek > 6)) {
    throw new ApiError(400, 'วันในสัปดาห์ไม่ถูกต้อง');
  }

  return { floor, dayOfWeek };
}

export function validateScheduleInput(body) {
  const roomNumber = cleanString(body?.roomNumber);
  const subjectName = cleanString(body?.subjectName);
  const section = cleanString(body?.section);
  const instructor = cleanString(body?.instructor);
  const dayOfWeek = Number(body?.dayOfWeek);
  const startTime = cleanString(body?.startTime);
  const endTime = cleanString(body?.endTime);

  if (!/^[A-Z0-9][A-Z0-9_-]{1,19}$/.test(roomNumber)) {
    throw new ApiError(400, 'หมายเลขห้องไม่ถูกต้อง');
  }
  if (
    !Number.isInteger(dayOfWeek) ||
    dayOfWeek < 0 ||
    dayOfWeek > 6
  ) {
    throw new ApiError(400, 'วันในสัปดาห์ไม่ถูกต้อง');
  }
  if (!subjectName || subjectName.length > 150) {
    throw new ApiError(
      400,
      'ชื่อวิชาต้องมีความยาว 1 ถึง 150 ตัวอักษร',
    );
  }
  if (section.length > 80) {
    throw new ApiError(400, 'กลุ่มเรียนต้องไม่เกิน 80 ตัวอักษร');
  }
  if (instructor.length > 150) {
    throw new ApiError(400, 'ชื่ออาจารย์ต้องไม่เกิน 150 ตัวอักษร');
  }
  if (!isValidTime(startTime) || !isValidTime(endTime)) {
    throw new ApiError(400, 'รูปแบบเวลาต้องเป็น HH:mm');
  }
  if (startTime >= endTime) {
    throw new ApiError(400, 'เวลาเลิกต้องอยู่หลังเวลาเริ่ม');
  }

  return {
    roomNumber,
    dayOfWeek,
    subjectName,
    section,
    instructor,
    startTime,
    endTime,
  };
}

function parseOptionalInteger(value) {
  if (value == null || value === '') return null;
  const text = Array.isArray(value) ? value[0] : value;
  if (!/^-?\d+$/.test(String(text))) {
    throw new ApiError(400, 'ตัวกรองตารางเรียนไม่ถูกต้อง');
  }
  return Number.parseInt(String(text), 10);
}

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}

function isValidTime(value) {
  return /^([01]\d|2[0-3]):[0-5]\d$/.test(value);
}
