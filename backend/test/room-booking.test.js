import assert from 'node:assert/strict';
import test from 'node:test';

import {
  activeBooking,
  bookingOccursOn,
  countOccurrences,
  validateBookingInput,
  withBookings,
} from '../src/utils/room-booking.js';

const base = {
  roomNumber: '16201',
  title: 'ประชุมภาควิชา',
  category: 'meeting',
  startTime: '13:00',
  endTime: '15:00',
};

test('once booking happens only on its date', () => {
  const booking = validateBookingInput({
    ...base,
    repeatType: 'once',
    startDate: '2026-10-07',
    endDate: '2026-12-31', // วันเดียวไม่สนวันสิ้นสุดที่ส่งมา
  });
  assert.equal(booking.endDate, '2026-10-07');
  assert.equal(countOccurrences(booking), 1);
  assert.equal(bookingOccursOn(booking, '2026-10-07'), true);
  assert.equal(bookingOccursOn(booking, '2026-10-08'), false);
});

test('daily booking covers every day in the range', () => {
  const booking = validateBookingInput({
    ...base,
    repeatType: 'daily',
    startDate: '2026-10-05',
    endDate: '2026-10-09',
  });
  assert.equal(countOccurrences(booking), 5);
  assert.equal(bookingOccursOn(booking, '2026-10-04'), false);
  assert.equal(bookingOccursOn(booking, '2026-10-09'), true);
});

test('weekly booking happens on the chosen weekdays only', () => {
  // ทุกวันพุธ ตลอดเดือนตุลาคม 2569 (2026): 7, 14, 21, 28
  const booking = validateBookingInput({
    ...base,
    repeatType: 'weekly',
    daysOfWeek: [3],
    startDate: '2026-10-01',
    endDate: '2026-10-31',
  });
  assert.equal(countOccurrences(booking), 4);
  assert.equal(bookingOccursOn(booking, '2026-10-07'), true);
  assert.equal(bookingOccursOn(booking, '2026-10-08'), false);
});

test('rejects bad input with a clear message', () => {
  assert.throws(
    () => validateBookingInput({ ...base, repeatType: 'weekly', daysOfWeek: [], startDate: '2026-10-01', endDate: '2026-10-31' }),
    /เลือกวันในสัปดาห์/,
  );
  assert.throws(
    () => validateBookingInput({ ...base, repeatType: 'daily', startDate: '2026-10-10', endDate: '2026-10-01' }),
    /ไม่ก่อนวันที่เริ่ม/,
  );
  assert.throws(
    () => validateBookingInput({ ...base, startTime: '15:00', endTime: '13:00', repeatType: 'once', startDate: '2026-10-07' }),
    /หลังเวลาเริ่ม/,
  );
  // ทุกวันอาทิตย์ แต่ช่วงวันที่มีแค่จันทร์-ศุกร์
  assert.throws(
    () => validateBookingInput({ ...base, repeatType: 'weekly', daysOfWeek: [0], startDate: '2026-10-05', endDate: '2026-10-09' }),
    /ไม่มีวันที่ตรง/,
  );
});

test('an active booking makes the room count as in use, even outside the term', () => {
  const booking = validateBookingInput({
    ...base,
    repeatType: 'weekly',
    daysOfWeek: [3],
    startDate: '2026-10-01',
    endDate: '2026-10-31',
  });
  // พุธ 7 ต.ค. 2026 14:00 เวลาไทย = 07:00 UTC
  const wednesdayAfternoon = new Date('2026-10-07T07:00:00Z');
  assert.equal(activeBooking([booking], wednesdayAfternoon)?.title, 'ประชุมภาควิชา');
  assert.equal(activeBooking([booking], new Date('2026-10-07T08:30:00Z')), null); // 15:30

  const outsideTerm = { configured: true, withinSchedule: false, termStatus: 'after' };
  const result = withBookings(outsideTerm, [booking], wednesdayAfternoon);
  assert.equal(result.withinSchedule, true);
  assert.equal(result.booking.title, 'ประชุมภาควิชา');

  const noSchedules = { configured: false, withinSchedule: false, termStatus: 'none' };
  assert.equal(withBookings(noSchedules, [booking], new Date('2026-10-08T07:00:00Z')).configured, true);
});
