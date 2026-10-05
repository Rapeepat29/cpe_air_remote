import assert from 'node:assert/strict';
import test from 'node:test';

import {
  validateScheduleFilters,
  validateScheduleInput,
} from '../src/utils/schedule.js';
import { requireAdmin } from '../src/middleware/require-admin.js';
import {
  deleteAllSchedules,
  ensureImportedRooms,
} from '../src/routes/schedules.js';

test('accepts a valid class schedule', () => {
  assert.deepEqual(
    validateScheduleInput({
      roomNumber: '16302',
      dayOfWeek: 1,
      subjectName: 'Computer Network',
      section: '',
      instructor: '',
      startTime: '09:00',
      endTime: '12:00',
    }),
    {
      roomNumber: '16302',
      dayOfWeek: 1,
      subjectName: 'Computer Network',
      section: '',
      instructor: '',
      startTime: '09:00',
      endTime: '12:00',
    },
  );
});

test('rejects invalid rooms and reversed class times', () => {
  assert.throws(
    () => validateScheduleInput({
      roomNumber: 'bad room',
      dayOfWeek: 1,
      subjectName: 'Computer Network',
      startTime: '09:00',
      endTime: '12:00',
    }),
    /หมายเลขห้องไม่ถูกต้อง/,
  );
  assert.throws(
    () => validateScheduleInput({
      roomNumber: '16302',
      dayOfWeek: 1,
      subjectName: 'Computer Network',
      startTime: '13:00',
      endTime: '12:00',
    }),
    /เวลาเลิกต้องอยู่หลังเวลาเริ่ม/,
  );
});

test('accepts floor and Sunday filters without treating zero as empty', () => {
  assert.deepEqual(
    validateScheduleFilters({ floor: '3', day: '0' }),
    { floor: 3, dayOfWeek: 0 },
  );
});

test('allows only administrators to modify class schedules', () => {
  let continued = false;
  requireAdmin(
    { authUser: { role: 'admin' } },
    {},
    () => {
      continued = true;
    },
  );
  assert.equal(continued, true);

  assert.throws(
    () => requireAdmin(
      { authUser: { role: 'staff' } },
      {},
      () => {},
    ),
    /เฉพาะผู้ดูแลระบบ/,
  );
});

test('clears every class schedule and returns the deleted count', async () => {
  const queries = [];
  const database = {
    async query(sql) {
      queries.push(sql);
      return { affectedRows: 151 };
    },
  };

  const deletedCount = await deleteAllSchedules(database);

  assert.equal(deletedCount, 151);
  assert.deepEqual(queries, ['DELETE FROM class_schedules']);
});

test('creates missing standard and special rooms for one import transaction', async () => {
  const queries = [];
  let selectCount = 0;
  const database = {
    async query(sql, parameters) {
      queries.push({ sql, parameters });
      if (sql.includes('SELECT room_number')) {
        selectCount += 1;
        return selectCount === 1
          ? [{ room_number: '16202' }]
          : [
              { room_number: '16202' },
              { room_number: '16306' },
              { room_number: 'CL503' },
            ];
      }
      return { affectedRows: 1 };
    },
  };

  const createdRooms = await ensureImportedRooms({
    roomNumbers: ['16202', '16306', 'CL503'],
    username: 'admin',
    allowCreate: true,
    database,
  });

  assert.deepEqual(createdRooms, [
    {
      roomNumber: '16306',
      floorNumber: 3,
      roomIndex: 6,
      roomType: 'Classroom',
    },
    {
      roomNumber: 'CL503',
      floorNumber: 0,
      roomIndex: 503,
      roomType: 'Special',
    },
  ]);
  assert.equal(
    queries.filter((query) => query.sql.includes('INSERT INTO rooms')).length,
    2,
  );
});

test('requires explicit confirmation before creating imported rooms', async () => {
  const database = {
    async query() {
      return [];
    },
  };

  await assert.rejects(
    ensureImportedRooms({
      roomNumbers: ['CL503'],
      username: 'admin',
      allowCreate: false,
      database,
    }),
    /ยืนยันการสร้างห้อง/,
  );
});

// ------------------------------------------------------- ปฏิทินภาคเรียน
import {
  bangkokDate,
  evaluateClassSchedule,
  termStatus,
} from '../src/utils/class-schedule.js';
import { validateTermInput } from '../src/services/academic-terms.js';

// วันจันทร์ 10 พ.ย. 2025 เวลา 10:00 น. ตามเวลาไทย (03:00 UTC)
const mondayMorning = new Date('2025-11-10T03:00:00Z');
const mondayClass = [{ day_of_week: 1, start_time: '09:00:00', end_time: '12:00:00' }];

test('bangkokDate uses Thai time, not UTC', () => {
  // 23:30 UTC = 06:30 วันถัดไปตามเวลาไทย
  assert.equal(bangkokDate(new Date('2025-11-09T23:30:00Z')), '2025-11-10');
});

test('termStatus compares whole days and includes the first and last day', () => {
  const term = { startDate: '2025-11-10', endDate: '2026-03-06' };
  assert.equal(termStatus(term, mondayMorning), 'active');
  assert.equal(termStatus(term, new Date('2025-11-09T10:00:00Z')), 'before');
  assert.equal(termStatus(term, new Date('2026-03-06T16:00:00Z')), 'active');
  assert.equal(termStatus(term, new Date('2026-03-06T17:30:00Z')), 'after');
  assert.equal(termStatus(null, mondayMorning), 'none');
});

test('schedule counts only inside the term dates', () => {
  const inside = evaluateClassSchedule(mondayClass, mondayMorning, {
    term: { startDate: '2025-11-01', endDate: '2026-03-06' },
  });
  assert.equal(inside.withinSchedule, true);
  assert.equal(inside.termStatus, 'active');

  const afterTerm = evaluateClassSchedule(mondayClass, mondayMorning, {
    term: { startDate: '2025-06-15', endDate: '2025-10-10' },
  });
  assert.equal(afterTerm.withinSchedule, false);
  assert.equal(afterTerm.configured, true);
  assert.equal(afterTerm.termStatus, 'after');

  const beforeTerm = evaluateClassSchedule(mondayClass, mondayMorning, {
    term: { startDate: '2025-11-17', endDate: '2026-03-06' },
  });
  assert.equal(beforeTerm.withinSchedule, false);
  assert.equal(beforeTerm.termStatus, 'before');

  // ไม่ได้ตั้งวันเปิด-ปิด: ทำงานเหมือนเดิมทุกวัน
  const noTerm = evaluateClassSchedule(mondayClass, mondayMorning);
  assert.equal(noTerm.withinSchedule, true);
  assert.equal(noTerm.termStatus, 'none');
});

test('validateTermInput checks the semester format and date order', () => {
  assert.deepEqual(
    validateTermInput({ semester: '2/2569', startDate: '2026-11-09', endDate: '2027-03-06' }),
    { semester: '2/2569', startDate: '2026-11-09', endDate: '2027-03-06' },
  );
  assert.throws(() => validateTermInput({ semester: 'เทอม 2', startDate: '2026-11-09', endDate: '2027-03-06' }));
  assert.throws(() => validateTermInput({ semester: '2/2569', startDate: '2027-03-06', endDate: '2026-11-09' }));
  assert.throws(() => validateTermInput({ semester: '2/2569', startDate: '2026-02-30', endDate: '2027-03-06' }));
});
