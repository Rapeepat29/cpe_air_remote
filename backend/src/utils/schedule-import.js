import { ApiError } from './http.js';
import { validateScheduleInput } from './schedule.js';
import {
  cellAddress,
  readXlsxWorksheets,
} from './xlsx-reader.js';

const ROOM_PATTERN = /^[A-Z0-9][A-Z0-9_-]{1,19}$/;
const MAX_IMPORT_ROWS = 500;
const DAY_CODES = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
const DAY_LOOKUP = new Map([
  ['0', 0],
  ['SUN', 0],
  ['SUNDAY', 0],
  ['อาทิตย์', 0],
  ['วันอาทิตย์', 0],
  ['1', 1],
  ['MON', 1],
  ['MONDAY', 1],
  ['จันทร์', 1],
  ['วันจันทร์', 1],
  ['2', 2],
  ['TUE', 2],
  ['TUESDAY', 2],
  ['อังคาร', 2],
  ['วันอังคาร', 2],
  ['3', 3],
  ['WED', 3],
  ['WEDNESDAY', 3],
  ['พุธ', 3],
  ['วันพุธ', 3],
  ['4', 4],
  ['THU', 4],
  ['THURSDAY', 4],
  ['พฤหัสบดี', 4],
  ['วันพฤหัสบดี', 4],
  ['5', 5],
  ['FRI', 5],
  ['FRIDAY', 5],
  ['ศุกร์', 5],
  ['วันศุกร์', 5],
  ['6', 6],
  ['SAT', 6],
  ['SATURDAY', 6],
  ['เสาร์', 6],
  ['วันเสาร์', 6],
]);

export async function parseScheduleFile({
  buffer,
  fileName,
  allowedRoomNumbers,
  includeUnknownRooms = false,
}) {
  if (!Buffer.isBuffer(buffer) || buffer.length === 0) {
    throw new ApiError(400, 'ไฟล์ตารางเรียนว่างเปล่า');
  }

  const safeFileName = cleanFileName(fileName);
  const extension = extensionOf(safeFileName);
  const allowed = allowedRoomNumbers == null
    ? null
    : new Set(
        allowedRoomNumbers.map((roomNumber) =>
          String(roomNumber).trim().toUpperCase()),
      );
  let parsed;

  if (extension === 'xlsx') {
    parsed = await parseExcelWorkbook(
      buffer,
      includeUnknownRooms ? null : allowed,
    );
  } else if (extension === 'csv') {
    parsed = parseNormalizedCsv(buffer.toString('utf8'));
  } else {
    throw new ApiError(400, 'รองรับเฉพาะไฟล์ .xlsx และ .csv');
  }

  const warnings = [...parsed.warnings];
  const skippedSheets = new Set(parsed.skippedSheets);
  let rawSchedules = parsed.schedules;
  if (allowed != null && !includeUnknownRooms) {
    rawSchedules = rawSchedules.filter((schedule) => {
      const roomNumber = String(
        schedule?.roomNumber ?? '',
      ).trim().toUpperCase();
      if (allowed.has(roomNumber)) return true;
      skippedSheets.add(roomNumber);
      return false;
    });
    for (const roomNumber of skippedSheets) {
      if (!allowed.has(roomNumber)) {
        warnings.push(
          `ข้ามห้อง ${roomNumber} เพราะ Admin ยังไม่ได้เพิ่มห้องนี้ในระบบ`,
        );
      }
    }
  }

  const schedules = normalizeImportedSchedules(rawSchedules);
  const roomNumbers = [...new Set(
    schedules.map((schedule) => schedule.roomNumber),
  )].sort();

  return {
    fileName: safeFileName,
    semester: parsed.semester,
    schedules,
    roomNumbers,
    warnings: [...new Set(warnings)],
    skippedSheets: [...skippedSheets],
    csv: schedulesToCsv(schedules, parsed.semester),
  };
}

export function validateScheduleImportPayload(body) {
  if (!Array.isArray(body?.schedules)) {
    throw new ApiError(400, 'ไม่พบรายการตารางเรียนสำหรับนำเข้า');
  }

  const schedules = normalizeImportedSchedules(body.schedules);
  return {
    schedules,
    createMissingRooms: body?.createMissingRooms === true,
    roomNumbers: [...new Set(
      schedules.map((schedule) => schedule.roomNumber),
    )].sort(),
  };
}

export function scheduleLabelForDatabase(schedule) {
  const section = cleanOptionalText(schedule.section, 80);
  const label = section
    ? `${schedule.subjectName} · ${section}`
    : schedule.subjectName;

  if (label.length > 150) {
    return label.slice(0, 147).trimEnd() + '...';
  }
  return label;
}

export function schedulesToCsv(schedules, semester = '') {
  const header = [
    'semester',
    'room_code',
    'day',
    'start_time',
    'end_time',
    'subject',
    'section',
    'instructor',
    'enabled',
  ];
  const rows = schedules.map((schedule) => [
    schedule.semester || semester,
    schedule.roomNumber,
    DAY_CODES[schedule.dayOfWeek],
    schedule.startTime,
    schedule.endTime,
    schedule.subjectName,
    schedule.section,
    schedule.instructor,
    'true',
  ]);

  return '\uFEFF' + [header, ...rows]
    .map((row) => row.map(escapeCsvValue).join(','))
    .join('\r\n') + '\r\n';
}

async function parseExcelWorkbook(buffer, allowedRoomNumbers = null) {
  let worksheets;
  try {
    worksheets = readXlsxWorksheets(buffer);
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(
      400,
      'เปิดไฟล์ Excel ไม่สำเร็จ กรุณาตรวจว่าเป็นไฟล์ .xlsx ที่ไม่เสียหาย',
    );
  }

  const schedules = [];
  const warnings = [];
  const skippedSheets = [];
  let semester = '';

  for (const worksheet of worksheets) {
    const roomNumber = worksheet.name.trim().toUpperCase();
    if (!ROOM_PATTERN.test(roomNumber)) {
      skippedSheets.push(roomNumber);
      warnings.push(
        `ข้ามชีต ${roomNumber} เพราะรูปแบบรหัสห้องไม่ถูกต้อง`,
      );
      continue;
    }
    if (
      allowedRoomNumbers != null &&
      !allowedRoomNumbers.has(roomNumber)
    ) {
      skippedSheets.push(roomNumber);
      warnings.push(
        `ข้ามห้อง ${roomNumber} เพราะ Admin ยังไม่ได้เพิ่มห้องนี้ในระบบ`,
      );
      continue;
    }

    const sheetSemester = extractSemester(worksheet);
    if (!semester && sheetSemester) {
      semester = sheetSemester;
    } else if (
      sheetSemester &&
      semester &&
      sheetSemester !== semester
    ) {
      warnings.push(
        `ชีต ${roomNumber} ระบุภาคเรียน ${sheetSemester} ซึ่งต่างจาก ${semester}`,
      );
    }

    const dayHeaderRow = findDayHeaderRow(worksheet);
    if (dayHeaderRow == null) {
      warnings.push(`ข้ามชีต ${roomNumber} เพราะไม่พบแถวหัวตารางวันและเวลา`);
      continue;
    }

    const maxTimeColumn = findMaxTimeColumn(worksheet, dayHeaderRow);
    for (
      let rowNumber = dayHeaderRow + 1;
      rowNumber <= worksheet.rowCount;
      rowNumber += 1
    ) {
      const dayAddress = cellAddress(rowNumber, 1);
      const dayMerge = worksheet.merges.get(dayAddress);
      if (dayMerge && dayMerge.masterAddress !== dayAddress) {
        continue;
      }
      const dayOfWeek = parseDay(getCellText(worksheet, rowNumber, 1));
      if (dayOfWeek == null) continue;

      for (let column = 2; column <= maxTimeColumn; column += 1) {
        const subjectAddress = cellAddress(rowNumber, column);
        const subjectMerge = worksheet.merges.get(subjectAddress);
        const subjectName = cleanOptionalText(
          getCellText(worksheet, rowNumber, column),
          150,
        );
        if (!subjectName) continue;
        if (
          subjectMerge &&
          subjectMerge.masterAddress !== subjectAddress
        ) {
          continue;
        }

        const endColumn = subjectMerge?.endColumn ?? column;
        const startTime = normalizeTime(
          getCellText(worksheet, dayHeaderRow - 1, column),
        );
        const endTime = normalizeTime(
          getCellText(worksheet, dayHeaderRow, endColumn),
        );

        if (!startTime || !endTime) {
          warnings.push(
            `ข้าม ${roomNumber} แถว ${rowNumber} เพราะอ่านเวลาไม่สำเร็จ`,
          );
          column = endColumn;
          continue;
        }

        schedules.push({
          semester: sheetSemester || semester,
          roomNumber,
          dayOfWeek,
          startTime,
          endTime,
          subjectName,
          section: cleanOptionalText(
            getCellText(worksheet, rowNumber + 1, column),
            80,
          ),
          instructor: cleanOptionalText(
            getCellText(worksheet, rowNumber + 2, column),
            150,
          ),
        });
        column = endColumn;
      }
    }
  }

  if (schedules.length === 0) {
    throw new ApiError(
      400,
      'ไม่พบตารางเรียนที่นำเข้าได้จากไฟล์ Excel',
    );
  }

  return {
    semester,
    schedules,
    warnings,
    skippedSheets,
  };
}

function parseNormalizedCsv(text) {
  const records = parseCsv(text.replace(/^\uFEFF/, ''));
  if (records.length < 2) {
    throw new ApiError(400, 'ไฟล์ CSV ไม่มีข้อมูลตารางเรียน');
  }

  const headers = records[0].map(normalizeHeader);
  const column = {
    semester: findHeader(headers, ['semester', 'term']),
    room: findHeader(headers, ['roomcode', 'roomnumber', 'room']),
    day: findHeader(headers, ['day', 'dayofweek']),
    start: findHeader(headers, ['starttime', 'start']),
    end: findHeader(headers, ['endtime', 'end']),
    subject: findHeader(headers, ['subject', 'subjectname']),
    section: findHeader(headers, ['section', 'classsection']),
    instructor: findHeader(headers, ['instructor', 'teacher', 'lecturer']),
    enabled: findHeader(headers, ['enabled', 'active']),
  };

  for (const required of ['room', 'day', 'start', 'end', 'subject']) {
    if (column[required] === -1) {
      throw new ApiError(
        400,
        'หัวคอลัมน์ CSV ไม่ครบ กรุณาใช้ไฟล์ CSV ที่ระบบสร้างให้',
      );
    }
  }

  const schedules = [];
  for (let index = 1; index < records.length; index += 1) {
    const record = records[index];
    if (record.every((value) => value.trim() === '')) continue;
    if (
      column.enabled !== -1 &&
      /^(false|0|no|off)$/i.test(valueAt(record, column.enabled))
    ) {
      continue;
    }

    const dayOfWeek = parseDay(valueAt(record, column.day));
    if (dayOfWeek == null) {
      throw new ApiError(
        400,
        `CSV แถว ${index + 1} ระบุวันในสัปดาห์ไม่ถูกต้อง`,
      );
    }

    schedules.push({
      semester: valueAt(record, column.semester),
      roomNumber: valueAt(record, column.room),
      dayOfWeek,
      startTime: normalizeTime(valueAt(record, column.start)),
      endTime: normalizeTime(valueAt(record, column.end)),
      subjectName: valueAt(record, column.subject),
      section: valueAt(record, column.section),
      instructor: valueAt(record, column.instructor),
    });
  }

  return {
    semester: schedules.find((item) => item.semester)?.semester ?? '',
    schedules,
    warnings: [],
    skippedSheets: [],
  };
}

function normalizeImportedSchedules(rawSchedules) {
  if (rawSchedules.length === 0) {
    throw new ApiError(400, 'ไม่พบรายการตารางเรียนสำหรับนำเข้า');
  }
  if (rawSchedules.length > MAX_IMPORT_ROWS) {
    throw new ApiError(
      400,
      `ไฟล์หนึ่งชุดนำเข้าได้ไม่เกิน ${MAX_IMPORT_ROWS} รายการ`,
    );
  }

  const schedules = [];
  const exactEntries = new Set();
  for (let index = 0; index < rawSchedules.length; index += 1) {
    const raw = rawSchedules[index] ?? {};
    const dayOfWeek = Number(raw.dayOfWeek);
    const startTime = normalizeTime(raw.startTime);
    const endTime = normalizeTime(raw.endTime);
    const schedule = {
      semester: cleanOptionalText(raw.semester, 30),
      roomNumber: cleanOptionalText(raw.roomNumber, 20).toUpperCase(),
      dayOfWeek,
      startTime,
      endTime,
      subjectName: cleanOptionalText(raw.subjectName, 150),
      section: cleanOptionalText(raw.section, 80),
      instructor: cleanOptionalText(raw.instructor, 150),
    };

    const validated = validateScheduleInput({
      roomNumber: schedule.roomNumber,
      dayOfWeek: schedule.dayOfWeek,
      subjectName: schedule.subjectName,
      section: schedule.section,
      instructor: schedule.instructor,
      startTime: schedule.startTime,
      endTime: schedule.endTime,
    });
    Object.assign(schedule, validated);

    const exactKey = [
      schedule.roomNumber,
      schedule.dayOfWeek,
      schedule.startTime,
      schedule.endTime,
      schedule.subjectName,
      schedule.section,
    ].join('|');
    if (exactEntries.has(exactKey)) {
      continue;
    }
    exactEntries.add(exactKey);
    schedules.push(schedule);
  }

  schedules.sort(compareSchedules);
  assertNoImportedOverlaps(schedules);
  return schedules;
}

function assertNoImportedOverlaps(schedules) {
  const latestByRoomDay = new Map();
  for (const schedule of schedules) {
    const key = `${schedule.roomNumber}|${schedule.dayOfWeek}`;
    const previous = latestByRoomDay.get(key);
    if (previous && schedule.startTime < previous.endTime) {
      throw new ApiError(
        409,
        `ตารางในไฟล์ซ้อนกัน: ห้อง ${schedule.roomNumber} `
          + `${DAY_CODES[schedule.dayOfWeek]} `
          + `${previous.startTime}-${previous.endTime} และ `
          + `${schedule.startTime}-${schedule.endTime}`,
      );
    }
    latestByRoomDay.set(key, schedule);
  }
}

function extractSemester(worksheet) {
  const lastRow = Math.min(worksheet.rowCount, 6);
  const lastColumn = Math.min(worksheet.columnCount, 14);
  for (let row = 1; row <= lastRow; row += 1) {
    for (let column = 1; column <= lastColumn; column += 1) {
      const text = getCellText(worksheet, row, column).trim();
      const match = text.match(/(?:ภาคเรียนที่\s*)?(\d{1,2}\/\d{4})/);
      if (match) return match[1];
    }
  }
  return '';
}

function findDayHeaderRow(worksheet) {
  const lastRow = Math.min(worksheet.rowCount, 20);
  for (let row = 1; row <= lastRow; row += 1) {
    const value = getCellText(worksheet, row, 1).trim();
    if (value === 'วัน' || /^day$/i.test(value)) {
      return row;
    }
  }
  return null;
}

function findMaxTimeColumn(worksheet, dayHeaderRow) {
  let last = 1;
  const upperBound = Math.min(worksheet.columnCount, 64);
  for (let column = 2; column <= upperBound; column += 1) {
    if (
      normalizeTime(getCellText(worksheet, dayHeaderRow - 1, column)) &&
      normalizeTime(getCellText(worksheet, dayHeaderRow, column))
    ) {
      last = column;
    }
  }
  if (last === 1) {
    throw new ApiError(400, 'ไม่พบช่วงเวลาในหัวตาราง Excel');
  }
  return last;
}

function getCellText(worksheet, row, column) {
  const address = cellAddress(row, column);
  const merge = worksheet.merges.get(address);
  return String(
    worksheet.cells.get(merge?.masterAddress ?? address) ?? '',
  );
}

function normalizeTime(value) {
  const text = String(value ?? '').trim();
  const match = text.match(/^(\d{1,2})[.:](\d{2})(?::\d{2})?$/);
  if (!match) return '';
  const hour = Number(match[1]);
  const minute = Number(match[2]);
  if (hour > 23 || minute > 59) return '';
  return `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`;
}

function parseDay(value) {
  const key = String(value ?? '').trim().toUpperCase();
  return DAY_LOOKUP.get(key) ?? null;
}

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = '';
  let quoted = false;

  for (let index = 0; index < text.length; index += 1) {
    const character = text[index];
    if (quoted) {
      if (character === '"' && text[index + 1] === '"') {
        field += '"';
        index += 1;
      } else if (character === '"') {
        quoted = false;
      } else {
        field += character;
      }
    } else if (character === '"') {
      quoted = true;
    } else if (character === ',') {
      row.push(field);
      field = '';
    } else if (character === '\n') {
      row.push(field.replace(/\r$/, ''));
      rows.push(row);
      row = [];
      field = '';
    } else {
      field += character;
    }
  }

  if (quoted) {
    throw new ApiError(400, 'รูปแบบเครื่องหมายคำพูดใน CSV ไม่สมบูรณ์');
  }
  if (field.length > 0 || row.length > 0) {
    row.push(field.replace(/\r$/, ''));
    rows.push(row);
  }
  return rows;
}

function findHeader(headers, names) {
  return headers.findIndex((header) => names.includes(header));
}

function normalizeHeader(value) {
  return value.trim().toLowerCase().replace(/[^a-z0-9]/g, '');
}

function valueAt(row, index) {
  return index === -1 ? '' : String(row[index] ?? '').trim();
}

function extensionOf(fileName) {
  const match = fileName.toLowerCase().match(/\.([a-z0-9]+)$/);
  return match?.[1] ?? '';
}

function cleanFileName(value) {
  const decoded = safeDecodeURIComponent(String(value ?? ''));
  const name = decoded.split(/[\\/]/).pop()?.trim() ?? '';
  if (!name || name.length > 255) {
    throw new ApiError(400, 'ชื่อไฟล์ไม่ถูกต้อง');
  }
  return name;
}

function safeDecodeURIComponent(value) {
  try {
    return decodeURIComponent(value);
  } catch {
    return value;
  }
}

function cleanOptionalText(value, maxLength) {
  const text = String(value ?? '').trim().replace(/\s+/g, ' ');
  return text.slice(0, maxLength);
}

function escapeCsvValue(value) {
  const text = String(value ?? '');
  if (!/[",\r\n]/.test(text)) return text;
  return `"${text.replaceAll('"', '""')}"`;
}

function compareSchedules(first, second) {
  const roomComparison = first.roomNumber.localeCompare(second.roomNumber);
  if (roomComparison !== 0) return roomComparison;
  const dayComparison = first.dayOfWeek - second.dayOfWeek;
  if (dayComparison !== 0) return dayComparison;
  const timeComparison = first.startTime.localeCompare(second.startTime);
  if (timeComparison !== 0) return timeComparison;
  return first.subjectName.localeCompare(second.subjectName);
}
