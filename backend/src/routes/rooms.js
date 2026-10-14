import express from 'express';

import { pool, withTransaction } from '../db.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireAdmin } from '../middleware/require-admin.js';
import { ApiError, asyncHandler } from '../utils/http.js';
import {
  publicRoom,
  validateRoomInput,
  validateRoomNumber,
} from '../utils/room.js';

export const roomsRouter = express.Router();

roomsRouter.use(authenticate);

roomsRouter.get(
  '/',
  asyncHandler(async (request, response) => {
    const rows = await pool.query(
      `SELECT r.room_number, r.floor_number, r.room_index, r.room_type,
              COUNT(DISTINCT a.device_id) AS air_conditioner_count,
              COUNT(DISTINCT s.id) AS schedule_count,
              COUNT(DISTINCT CASE
                WHEN a.ac_running = 1 THEN a.device_id
              END) AS running_air_count,
              MIN(CASE
                WHEN a.provision_status = 'active'
                  THEN a.auto_off_deadline_at
              END) AS auto_off_deadline_at,
              MAX(CASE
                WHEN a.provision_status = 'active'
                  THEN a.auto_off_attempts
              END) AS auto_off_attempts,
              MAX(CASE
                WHEN a.provision_status = 'active'
                  THEN a.auto_off_in_class
              END) AS auto_off_in_class,
              MAX(o.device_id) AS occupancy_sensor_device_id,
              MAX(o.ble_name) AS occupancy_sensor_ble_name,
              MAX(o.provision_status) AS occupancy_sensor_provision_status,
              MAX(o.is_online) AS occupancy_sensor_online,
              MAX(o.radar_available) AS occupancy_sensor_available,
              MAX(o.is_occupied) AS is_occupied,
              MAX(o.static_threshold) AS occupancy_static_threshold,
              MAX(o.last_seen_at) AS occupancy_updated_at
         FROM rooms r
         LEFT JOIN air_conditioners a
           ON a.room_number = r.room_number
         LEFT JOIN class_schedules s
           ON s.room_number = r.room_number
         LEFT JOIN occupancy_sensors o
           ON o.room_number = r.room_number
        GROUP BY r.room_number, r.floor_number, r.room_index, r.room_type
        ORDER BY r.floor_number, r.room_index, r.room_number`,
    );

    response.json({ rooms: rows.map(publicRoom) });
  }),
);

roomsRouter.post(
  '/',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const input = validateRoomInput(request.body);
    const existingRows = await pool.query(
      'SELECT room_number FROM rooms WHERE room_number = ? LIMIT 1',
      [input.roomNumber],
    );
    if (existingRows[0]) {
      throw new ApiError(409, `มีห้อง ${input.roomNumber} อยู่แล้ว`);
    }

    await pool.query(
      `INSERT INTO rooms
         (room_number, floor_number, room_index, room_type,
          created_by, updated_by)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [
        input.roomNumber,
        input.floorNumber,
        input.roomIndex,
        input.roomType,
        request.authUser.username,
        request.authUser.username,
      ],
    );

    response.status(201).json({
      room: {
        ...input,
        airConditionerCount: 0,
        scheduleCount: 0,
      },
    });
  }),
);

roomsRouter.put(
  '/:roomNumber',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const roomNumber = validateRoomNumber(request.params.roomNumber);
    const input = validateRoomInput(request.body, { requireNumber: false });
    const existingRows = await pool.query(
      `SELECT room_number
         FROM rooms
        WHERE room_number = ?
        LIMIT 1`,
      [roomNumber],
    );
    if (!existingRows[0]) {
      throw new ApiError(404, 'ไม่พบห้องนี้');
    }
    await pool.query(
      `UPDATE rooms
          SET floor_number = ?,
              room_index = ?,
              room_type = ?,
              updated_by = ?
        WHERE room_number = ?`,
      [
        input.floorNumber,
        input.roomIndex,
        input.roomType,
        request.authUser.username,
        roomNumber,
      ],
    );

    response.json({
      room: {
        roomNumber,
        ...input,
      },
    });
  }),
);

roomsRouter.delete(
  '/:roomNumber',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const roomNumber = validateRoomNumber(request.params.roomNumber);

    await withTransaction(async (connection) => {
      const roomRows = await connection.query(
        `SELECT room_number
           FROM rooms
          WHERE room_number = ?
          FOR UPDATE`,
        [roomNumber],
      );
      if (!roomRows[0]) {
        throw new ApiError(404, 'ไม่พบห้องนี้');
      }

      const dependencyRows = await connection.query(
        `SELECT
           (SELECT COUNT(*)
              FROM air_conditioners
             WHERE room_number = ?) AS air_count,
           (SELECT COUNT(*)
              FROM class_schedules
             WHERE room_number = ?) AS schedule_count,
           (SELECT COUNT(*)
              FROM occupancy_sensors
             WHERE room_number = ?) AS occupancy_count`,
        [roomNumber, roomNumber, roomNumber],
      );
      const airCount = Number(dependencyRows[0]?.air_count ?? 0);
      const scheduleCount = Number(
        dependencyRows[0]?.schedule_count ?? 0,
      );
      const occupancyCount = Number(
        dependencyRows[0]?.occupancy_count ?? 0,
      );
      if (airCount > 0 || scheduleCount > 0 || occupancyCount > 0) {
        throw new ApiError(
          409,
          `ยังลบห้อง ${roomNumber} ไม่ได้: มีแอร์ ${airCount} เครื่อง `
            + `ตารางเรียน ${scheduleCount} รายการ และเซ็นเซอร์ตรวจจับคน `
            + `${occupancyCount} ตัว กรุณาลบข้อมูลที่ผูกอยู่ก่อน`,
        );
      }

      await connection.query(
        'DELETE FROM rooms WHERE room_number = ?',
        [roomNumber],
      );
    });

    response.status(204).end();
  }),
);
