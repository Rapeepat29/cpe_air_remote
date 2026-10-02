import assert from 'node:assert/strict';
import test from 'node:test';

import { strToU8, zipSync } from 'fflate';

import {
  parseScheduleFile,
  pickSemester,
  scheduleLabelForDatabase,
  validateScheduleImportPayload,
} from '../src/utils/schedule-import.js';

test('converts merged timetable cells in Excel into normalized schedules', async () => {
  const buffer = createXlsxFixture();
  const preview = await parseScheduleFile({
    buffer,
    fileName: 'ตาราง.xlsx',
    allowedRoomNumbers: ['16202'],
  });

  assert.equal(preview.semester, '1/2569');
  assert.deepEqual(preview.roomNumbers, ['16202']);
  assert.deepEqual(preview.skippedSheets, ['CL503']);
  assert.equal(preview.schedules.length, 1);
  assert.deepEqual(preview.schedules[0], {
    semester: '1/2569',
    roomNumber: '16202',
    dayOfWeek: 1,
    startTime: '09:00',
    endTime: '12:00',
    subjectName: 'Operating System',
    section: '(T) 68346CPE',
    instructor: 'ดร.พชร ศรีมุกข์',
  });
  assert.match(preview.csv, /semester,room_code,day,start_time/);
  assert.match(preview.csv, /1\/2569,16202,MON,09:00,12:00/);
});

test('accepts a special room when Admin has added it', async () => {
  const csv = [
    'room_code,day,start_time,end_time,subject,section,instructor',
    'CL503,MON,09:00,12:00,Operating System,(T) 68346CPE,Teacher A',
  ].join('\n');

  const preview = await parseScheduleFile({
    buffer: Buffer.from(csv),
    fileName: 'special-room.csv',
    allowedRoomNumbers: ['16202', 'CL503'],
  });

  assert.deepEqual(preview.roomNumbers, ['CL503']);
  assert.equal(preview.schedules[0].instructor, 'Teacher A');
});

test('skips a room that Admin has not added', async () => {
  const csv = [
    'room_code,day,start_time,end_time,subject',
    'CL999,MON,09:00,12:00,Operating System',
    '16202,MON,13:00,16:00,Computer Network',
  ].join('\n');

  const preview = await parseScheduleFile({
    buffer: Buffer.from(csv),
    fileName: 'unknown-room.csv',
    allowedRoomNumbers: ['16202'],
  });

  assert.deepEqual(preview.roomNumbers, ['16202']);
  assert.deepEqual(preview.skippedSheets, ['CL999']);
  assert.match(preview.warnings[0], /Admin/);
});

test('keeps new rooms in the preview when automatic creation is enabled', async () => {
  const csv = [
    'room_code,day,start_time,end_time,subject',
    'CL999,MON,09:00,12:00,Operating System',
    '16202,MON,13:00,16:00,Computer Network',
  ].join('\n');

  const preview = await parseScheduleFile({
    buffer: Buffer.from(csv),
    fileName: 'new-rooms.csv',
    allowedRoomNumbers: ['16202'],
    includeUnknownRooms: true,
  });

  assert.deepEqual(preview.roomNumbers, ['16202', 'CL999']);
  assert.deepEqual(preview.skippedSheets, []);
  assert.equal(preview.schedules.length, 2);
});

function createXlsxFixture() {
  const workbook = `<?xml version="1.0" encoding="UTF-8"?>
    <workbook xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
      <sheets>
        <sheet name="16202" sheetId="1" r:id="rId1"/>
        <sheet name="CL503" sheetId="2" r:id="rId2"/>
      </sheets>
    </workbook>`;
  const relationships = `<?xml version="1.0" encoding="UTF-8"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
      <Relationship Id="rId1" Target="worksheets/sheet1.xml"/>
      <Relationship Id="rId2" Target="worksheets/sheet2.xml"/>
    </Relationships>`;
  const sharedStrings = `<?xml version="1.0" encoding="UTF-8"?>
    <sst>
      <si><t>ตารางการใช้ห้องเรียน ภาคเรียนที่ 1/2569 ห้อง 16202</t></si>
      <si><t>จันทร์</t></si>
      <si><t>Operating System</t></si>
      <si><t>(T) 68346CPE</t></si>
      <si><t>ดร.พชร ศรีมุกข์</t></si>
    </sst>`;

  const startCells = [];
  const endCells = [];
  for (let index = 0; index < 13; index += 1) {
    const column = String.fromCharCode(66 + index);
    startCells.push(
      `<c r="${column}6" t="str"><v>${8 + index}.00</v></c>`,
    );
    endCells.push(
      `<c r="${column}7" t="str"><v>${9 + index}.00</v></c>`,
    );
  }

  const firstSheet = `<?xml version="1.0" encoding="UTF-8"?>
    <worksheet>
      <sheetData>
        <row r="3"><c r="A3" t="s"><v>0</v></c></row>
        <row r="6"><c r="A6" t="inlineStr"><is><t>เวลา</t></is></c>${startCells.join('')}</row>
        <row r="7"><c r="A7" t="inlineStr"><is><t>วัน</t></is></c>${endCells.join('')}</row>
        <row r="8"><c r="A8" t="s"><v>1</v></c><c r="C8" t="s"><v>2</v></c></row>
        <row r="9"><c r="C9" t="s"><v>3</v></c></row>
        <row r="10"><c r="C10" t="s"><v>4</v></c></row>
      </sheetData>
      <mergeCells count="4">
        <mergeCell ref="A8:A10"/>
        <mergeCell ref="C8:E8"/>
        <mergeCell ref="C9:E9"/>
        <mergeCell ref="C10:E10"/>
      </mergeCells>
    </worksheet>`;
  const secondSheet = `<?xml version="1.0" encoding="UTF-8"?>
    <worksheet><sheetData>
      <row r="7"><c r="A7" t="inlineStr"><is><t>วัน</t></is></c></row>
    </sheetData></worksheet>`;

  return Buffer.from(zipSync({
    'xl/workbook.xml': strToU8(workbook),
    'xl/_rels/workbook.xml.rels': strToU8(relationships),
    'xl/sharedStrings.xml': strToU8(sharedStrings),
    'xl/worksheets/sheet1.xml': strToU8(firstSheet),
    'xl/worksheets/sheet2.xml': strToU8(secondSheet),
  }));
}

test('accepts the normalized CSV produced by the importer', async () => {
  const csv = [
    'semester,room_code,day,start_time,end_time,subject,section,instructor,enabled',
    '1/2569,16306,WED,13:00,16:00,"Image, Audio Processing",(T) 67346CPE,Teacher,true',
  ].join('\r\n');

  const preview = await parseScheduleFile({
    buffer: Buffer.from(csv),
    fileName: 'class-schedules.csv',
  });

  assert.equal(preview.schedules.length, 1);
  assert.equal(preview.schedules[0].dayOfWeek, 3);
  assert.equal(preview.schedules[0].subjectName, 'Image, Audio Processing');
});

test('rejects overlapping classes in the same imported room and day', async () => {
  const csv = [
    'room_code,day,start_time,end_time,subject',
    '16202,MON,09:00,12:00,Operating System',
    '16202,MON,11:00,13:00,Computer Network',
  ].join('\n');

  await assert.rejects(
    parseScheduleFile({
      buffer: Buffer.from(csv),
      fileName: 'overlap.csv',
    }),
    /ตารางในไฟล์ซ้อนกัน/,
  );
});

test('adds the section to the database display label', () => {
  assert.equal(
    scheduleLabelForDatabase({
      subjectName: 'Operating System',
      section: '(T) 68346CPE',
    }),
    'Operating System · (T) 68346CPE',
  );
});

const importRow = (overrides = {}) => ({
  semester: '2/2569',
  roomNumber: '16201',
  dayOfWeek: 1,
  startTime: '09:00',
  endTime: '12:00',
  subjectName: 'Computer Network',
  section: '',
  instructor: '',
  ...overrides,
});

test('import commit replaces only rooms in the file unless replaceAll is true', () => {
  const partial = validateScheduleImportPayload({
    schedules: [importRow()],
  });
  assert.equal(partial.replaceAll, false);

  // แอปมือถือรุ่นเดิมไม่ส่ง replaceAll และค่าที่ไม่ใช่ true จริงต้องไม่ล้างทุกห้อง
  for (const value of ['true', 1, 'yes', null]) {
    assert.equal(
      validateScheduleImportPayload({ schedules: [importRow()], replaceAll: value })
        .replaceAll,
      false,
    );
  }

  const all = validateScheduleImportPayload({
    schedules: [importRow()],
    replaceAll: true,
  });
  assert.equal(all.replaceAll, true);
  assert.equal(all.semester, '2/2569');
});

test('pickSemester uses the most common semester and ignores blanks', () => {
  assert.equal(
    pickSemester([
      importRow({ semester: '2/2569' }),
      importRow({ semester: '2/2569' }),
      importRow({ semester: '1/2569' }),
      importRow({ semester: '' }),
    ]),
    '2/2569',
  );
  assert.equal(pickSemester([importRow({ semester: '' })]), '');
  assert.equal(pickSemester([]), '');
});
