import crypto from 'node:crypto';

import express from 'express';

import { pool } from '../db.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireAdmin } from '../middleware/require-admin.js';
import { ApiError, asyncHandler } from '../utils/http.js';
import {
  countOccurrences,
  publicBooking,
  validateBookingInput,
} from '../utils/room-booking.js';

// การใช้ห้องนอกตารางเรียน: ประชุม สอบ กิจกรรม หรือคาบเรียนที่มีวันที่กำกับ
// ดูทุกคนได้ เพิ่ม/แก้/ลบเฉพาะแอดมิน เหมือนตารางเรียน

export const bookingsRouter = express.Router();

bookingsRouter.use(authenticate);

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

const SELECT_COLUMNS = `
  id, room_number, title, category, note, repeat_type, days_of_week,
  DATE_FORMAT(start_date, '%Y-%m-%d') AS start_date,
  DATE_FORMAT(end_date, '%Y-%m-%d') AS end_date,
  start_time, end_time, created_by, updated_by`;

/**
 * GET /bookings?from=YYYY-MM-DD&to=YYYY-MM-DD
 * คืนการจองที่ช่วงวันที่ทับกับช่วงที่ขอ (ไม่ส่งช่วงมา = ทุกรายการที่ยังไม่จบ)
 */
bookingsRouter.get(
  '/',
  asyncHandler(async (request, response) => {
    const from = String(request.query.from ?? '');
    const to = String(request.query.to ?? '');
    const conditions = [];
    const parameters = [];
    if (DATE_PATTERN.test(from)) {
      conditions.push('end_date >= ?');
      parameters.push(from);
    } else {
      conditions.push('end_date >= CURDATE()');
    }
    if (DATE_PATTERN.test(to)) {
      conditions.push('start_date <= ?');
      parameters.push(to);
    }
    let rows = [];
    try {
      rows = await pool.query(
        `SELECT ${SELECT_COLUMNS}
           FROM room_bookings
          WHERE ${conditions.join(' AND ')}
          ORDER BY start_date, start_time, room_number`,
        parameters,
      );
    } catch (error) {
      if (error?.code !== 'ER_NO_SUCH_TABLE') throw error;
    }
    response.json({ bookings: rows.map(publicBooking) });
  }),
);

bookingsRouter.post(
  '/',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const input = validateBookingInput(request.body);
    await ensureRoomExists(input.roomNumber);
    const id = crypto.randomUUID();
    await pool.query(
      `INSERT INTO room_bookings
         (id, room_number, title, category, note, repeat_type, days_of_week,
          start_date, end_date, start_time, end_time, created_by, updated_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        input.roomNumber,
        input.title,
        input.category,
        input.note,
        input.repeatType,
        input.daysOfWeek.join(','),
        input.startDate,
        input.endDate,
        input.startTime,
        input.endTime,
        request.authUser.username,
        request.authUser.username,
      ],
    );
    response.status(201).json({
      booking: { id, ...input },
      occurrences: countOccurrences(input),
    });
  }),
);

bookingsRouter.put(
  '/:id',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const id = validateId(request.params.id);
    const input = validateBookingInput(request.body);
    await ensureRoomExists(input.roomNumber);
    const result = await pool.query(
      `UPDATE room_bookings
          SET room_number = ?, title = ?, category = ?, note = ?,
              repeat_type = ?, days_of_week = ?, start_date = ?, end_date = ?,
              start_time = ?, end_time = ?, updated_by = ?
        WHERE id = ?`,
      [
        input.roomNumber,
        input.title,
        input.category,
        input.note,
        input.repeatType,
        input.daysOfWeek.join(','),
        input.startDate,
        input.endDate,
        input.startTime,
        input.endTime,
        request.authUser.username,
        id,
      ],
    );
    if (Number(result.affectedRows) === 0) {
      throw new ApiError(404, 'ไม่พบการใช้ห้องรายการนี้');
    }
    response.json({ booking: { id, ...input }, occurrences: countOccurrences(input) });
  }),
);

bookingsRouter.delete(
  '/:id',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const id = validateId(request.params.id);
    const result = await pool.query('DELETE FROM room_bookings WHERE id = ?', [id]);
    if (Number(result.affectedRows) === 0) {
      throw new ApiError(404, 'ไม่พบการใช้ห้องรายการนี้');
    }
    response.status(204).end();
  }),
);

function validateId(value) {
  const id = String(value ?? '').trim();
  if (!/^[0-9a-f-]{36}$/i.test(id)) throw new ApiError(400, 'รหัสรายการไม่ถูกต้อง');
  return id;
}

async function ensureRoomExists(roomNumber) {
  const rows = await pool.query(
    'SELECT room_number FROM rooms WHERE room_number = ? LIMIT 1',
    [roomNumber],
  );
  if (!rows[0]) throw new ApiError(400, `ไม่พบห้อง ${roomNumber} ในระบบ`);
}
