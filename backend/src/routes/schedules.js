import crypto from 'node:crypto';

import express from 'express';

import { pool, withTransaction } from '../db.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireAdmin } from '../middleware/require-admin.js';
import { ApiError, asyncHandler } from '../utils/http.js';
import {
  parseScheduleFile,
  validateScheduleImportPayload,
} from '../utils/schedule-import.js';
import {
  validateScheduleFilters,
  validateScheduleInput,
} from '../utils/schedule.js';
import { roomDefaultsForImport } from '../utils/room.js';

export const schedulesRouter = express.Router();

schedulesRouter.use(authenticate);

schedulesRouter.post(
  '/import/preview',
  requireAdmin,
  express.raw({
    type: () => true,
    limit: '8mb',
  }),
  asyncHandler(async (request, response) => {
    const roomRows = await pool.query(
      'SELECT room_number FROM rooms WHERE is_active = TRUE',
    );
    const preview = await parseScheduleFile({
      buffer: request.body,
      fileName: request.get('x-file-name'),
      allowedRoomNumbers: roomRows.map((row) => row.room_number),
      includeUnknownRooms: true,
    });
    const existingRoomNumbers = new Set(
      roomRows.map((row) => row.room_number),
    );
    const newRooms = preview.roomNumbers
      .filter((roomNumber) => !existingRoomNumbers.has(roomNumber))
      .map(roomDefaultsForImport);

    response.json({
      preview: {
        ...preview,
        scheduleCount: preview.schedules.length,
        roomCount: preview.roomNumbers.length,
        existingRoomNumbers: preview.roomNumbers.filter(
          (roomNumber) => existingRoomNumbers.has(roomNumber),
        ),
        newRooms,
        newRoomCount: newRooms.length,
      },
    });
  }),
);

schedulesRouter.post(
  '/import/commit',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const input = validateScheduleImportPayload(request.body);
    let createdRooms = [];

    await withTransaction(async (connection) => {
      createdRooms = await ensureImportedRooms({
        roomNumbers: input.roomNumbers,
        username: request.authUser.username,
        allowCreate: input.createMissingRooms,
        database: connection,
      });
      const placeholders = input.roomNumbers.map(() => '?').join(', ');
      await connection.query(
        `DELETE FROM class_schedules
          WHERE room_number IN (${placeholders})`,
        input.roomNumbers,
      );

      for (const schedule of input.schedules) {
        await connection.query(
          `INSERT INTO class_schedules
             (id, room_number, day_of_week, subject_name,
              section_name, instructor, start_time, end_time,
              created_by, updated_by)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
          [
            crypto.randomUUID(),
            schedule.roomNumber,
            schedule.dayOfWeek,
            schedule.subjectName,
            schedule.section,
            schedule.instructor,
            schedule.startTime,
            schedule.endTime,
            request.authUser.username,
            request.authUser.username,
          ],
        );
      }
    });

    response.status(201).json({
      result: {
        importedCount: input.schedules.length,
        replacedRooms: input.roomNumbers,
        createdRooms,
      },
    });
  }),
);

schedulesRouter.get(
  '/',
  asyncHandler(async (request, response) => {
    const filters = validateScheduleFilters(request.query);
    const conditions = [];
    const parameters = [];

    if (filters.floor != null) {
      conditions.push('r.floor_number = ?');
      parameters.push(filters.floor);
    }
    if (filters.dayOfWeek != null) {
      conditions.push('s.day_of_week = ?');
      parameters.push(filters.dayOfWeek);
    }

    const where = conditions.length > 0
      ? `WHERE ${conditions.join(' AND ')}`
      : '';
    const rows = await pool.query(
      `SELECT s.id, s.room_number, s.day_of_week, s.subject_name,
              s.section_name, s.instructor, s.start_time, s.end_time
         FROM class_schedules s
         INNER JOIN rooms r ON r.room_number = s.room_number
         ${where}
        ORDER BY s.day_of_week, r.floor_number, r.room_index,
                 s.room_number, s.start_time, s.subject_name`,
      parameters,
    );

    response.json({
      schedules: rows.map(publicSchedule),
    });
  }),
);

schedulesRouter.post(
  '/',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const input = validateScheduleInput(request.body);
    await ensureRoomsExist([input.roomNumber]);
    await ensureNoOverlap(input);

    const id = crypto.randomUUID();
    await pool.query(
      `INSERT INTO class_schedules
         (id, room_number, day_of_week, subject_name,
          section_name, instructor, start_time, end_time,
          created_by, updated_by)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        id,
        input.roomNumber,
        input.dayOfWeek,
        input.subjectName,
        input.section,
        input.instructor,
        input.startTime,
        input.endTime,
        request.authUser.username,
        request.authUser.username,
      ],
    );

    response.status(201).json({
      schedule: {
        id,
        ...input,
      },
    });
  }),
);

schedulesRouter.delete(
  '/',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const deletedCount = await deleteAllSchedules();
    response.json({
      result: {
        deletedCount,
      },
    });
  }),
);

schedulesRouter.put(
  '/:id',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const id = validateId(request.params.id);
    const input = validateScheduleInput(request.body);
    await ensureRoomsExist([input.roomNumber]);

    const existingRows = await pool.query(
      'SELECT id FROM class_schedules WHERE id = ? LIMIT 1',
      [id],
    );
    if (!existingRows[0]) {
      throw new ApiError(404, 'ไม่พบรายการตารางเรียนนี้');
    }

    await ensureNoOverlap(input, id);
    await pool.query(
      `UPDATE class_schedules
          SET room_number = ?,
              day_of_week = ?,
              subject_name = ?,
              section_name = ?,
              instructor = ?,
              start_time = ?,
              end_time = ?,
              updated_by = ?
        WHERE id = ?`,
      [
        input.roomNumber,
        input.dayOfWeek,
        input.subjectName,
        input.section,
        input.instructor,
        input.startTime,
        input.endTime,
        request.authUser.username,
        id,
      ],
    );

    response.json({
      schedule: {
        id,
        ...input,
      },
    });
  }),
);

schedulesRouter.delete(
  '/:id',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const id = validateId(request.params.id);
    const result = await pool.query(
      'DELETE FROM class_schedules WHERE id = ?',
      [id],
    );
    if (Number(result.affectedRows) === 0) {
      throw new ApiError(404, 'ไม่พบรายการตารางเรียนนี้');
    }

    response.status(204).end();
  }),
);

export async function deleteAllSchedules(database = pool) {
  const result = await database.query('DELETE FROM class_schedules');
  return Number(result.affectedRows) || 0;
}

export async function ensureImportedRooms({
  roomNumbers,
  username,
  allowCreate,
  database = pool,
}) {
  const uniqueRoomNumbers = [...new Set(roomNumbers)];
  const placeholders = uniqueRoomNumbers.map(() => '?').join(', ');
  const rows = await database.query(
    `SELECT room_number
       FROM rooms
      WHERE is_active = TRUE
        AND room_number IN (${placeholders})`,
    uniqueRoomNumbers,
  );
  const existing = new Set(rows.map((row) => row.room_number));
  const missingRooms = uniqueRoomNumbers
    .filter((roomNumber) => !existing.has(roomNumber))
    .map(roomDefaultsForImport);

  if (missingRooms.length > 0 && !allowCreate) {
    throw new ApiError(
      400,
      `พบห้องใหม่ ${missingRooms.map((room) => room.roomNumber).join(', ')} `
        + 'กรุณาตรวจสอบ Preview และยืนยันการสร้างห้องก่อนนำเข้า',
    );
  }

  for (const room of missingRooms) {
    await database.query(
      `INSERT INTO rooms
         (room_number, floor_number, room_index, room_type,
          is_active, created_by, updated_by)
       VALUES (?, ?, ?, ?, TRUE, ?, ?)
       ON DUPLICATE KEY UPDATE
         is_active = TRUE,
         updated_by = VALUES(updated_by)`,
      [
        room.roomNumber,
        room.floorNumber,
        room.roomIndex,
        room.roomType,
        username,
        username,
      ],
    );
  }

  await ensureRoomsExist(uniqueRoomNumbers, database);
  return missingRooms;
}

async function ensureNoOverlap(input, ignoredId = null) {
  const rows = await pool.query(
    `SELECT id
       FROM class_schedules
      WHERE room_number = ?
        AND day_of_week = ?
        AND start_time < ?
        AND end_time > ?
        AND (? IS NULL OR id <> ?)
      LIMIT 1`,
    [
      input.roomNumber,
      input.dayOfWeek,
      input.endTime,
      input.startTime,
      ignoredId,
      ignoredId,
    ],
  );

  if (rows[0]) {
    throw new ApiError(
      409,
      'ช่วงเวลานี้ซ้อนกับตารางเรียนที่มีอยู่แล้ว',
    );
  }
}

async function ensureRoomsExist(roomNumbers, database = pool) {
  const uniqueRoomNumbers = [...new Set(roomNumbers)];
  const placeholders = uniqueRoomNumbers.map(() => '?').join(', ');
  const rows = await database.query(
    `SELECT room_number
       FROM rooms
      WHERE is_active = TRUE
        AND room_number IN (${placeholders})`,
    uniqueRoomNumbers,
  );
  const existing = new Set(rows.map((row) => row.room_number));
  const missing = uniqueRoomNumbers.filter(
    (roomNumber) => !existing.has(roomNumber),
  );
  if (missing.length > 0) {
    throw new ApiError(
      400,
      `ยังไม่มีห้อง ${missing.join(', ')} ในระบบ กรุณาให้ Admin เพิ่มห้องก่อน`,
    );
  }
}

function validateId(value) {
  const id = cleanString(value);
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)) {
    throw new ApiError(400, 'รหัสรายการตารางเรียนไม่ถูกต้อง');
  }
  return id;
}

function publicSchedule(row) {
  return {
    id: row.id,
    roomNumber: row.room_number,
    dayOfWeek: Number(row.day_of_week),
    subjectName: row.subject_name,
    section: row.section_name ?? '',
    instructor: row.instructor ?? '',
    startTime: normalizeTime(row.start_time),
    endTime: normalizeTime(row.end_time),
  };
}

function normalizeTime(value) {
  return String(value).slice(0, 5);
}

function cleanString(value) {
  return typeof value === 'string' ? value.trim() : '';
}
