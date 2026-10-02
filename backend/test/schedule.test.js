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
