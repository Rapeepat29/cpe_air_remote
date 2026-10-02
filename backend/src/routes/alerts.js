import express from 'express';

import { pool } from '../db.js';
import { authenticate } from '../middleware/authenticate.js';
import { publicAlert } from '../services/alerts.js';
import { ApiError, asyncHandler } from '../utils/http.js';

export const alertsRouter = express.Router();

alertsRouter.use(authenticate);

const STATUSES = new Set(['open', 'acknowledged', 'resolved']);

// รายการแจ้งเตือนล่าสุด ใช้กับการ์ด `การแจ้งเตือนระบบ` ในหน้าหลัก
alertsRouter.get(
  '/',
  asyncHandler(async (request, response) => {
    const limit = clampLimit(request.query.status, request.query.limit);
    const status = String(request.query.status ?? '').trim();

    const filters = [];
    const params = [];
    if (STATUSES.has(status)) {
      filters.push('status = ?');
      params.push(status);
    }
    if (request.query.room) {
      filters.push('room_number = ?');
      params.push(String(request.query.room).trim().toUpperCase());
    }

    const where = filters.length > 0
      ? `WHERE ${filters.join(' AND ')}`
      : '';

    const rows = await pool.query(
      `SELECT id, kind, room_number, device_id, device_name, detail,
              status, acknowledged_at, acknowledged_by, resolved_at,
              created_at
         FROM system_alerts
         ${where}
        ORDER BY status = 'open' DESC, created_at DESC
        LIMIT ${limit}`,
      params,
    );

    const counts = await pool.query(
      `SELECT status, COUNT(*) AS total
         FROM system_alerts
        GROUP BY status`,
    );

    response.json({
      alerts: rows.map(publicAlert),
      counts: Object.fromEntries(
        counts.map((row) => [row.status, Number(row.total)]),
      ),
    });
  }),
);

// รับทราบแล้ว ใบนั้นจะเลื่อนลงไปอยู่ท้ายรายการ
alertsRouter.post(
  '/:id/acknowledge',
  asyncHandler(async (request, response) => {
    const id = String(request.params.id ?? '').trim();
    if (!/^[0-9a-f-]{36}$/i.test(id)) {
      throw new ApiError(400, 'รหัสการแจ้งเตือนไม่ถูกต้อง');
    }

    const result = await pool.query(
      `UPDATE system_alerts
          SET status = 'acknowledged',
              acknowledged_at = CURRENT_TIMESTAMP,
              acknowledged_by = ?
        WHERE id = ? AND status = 'open'`,
      [request.authUser.username, id],
    );
    if (Number(result?.affectedRows ?? 0) === 0) {
      throw new ApiError(404, 'ไม่พบการแจ้งเตือนนี้ หรือรับทราบไปแล้ว');
    }

    const rows = await pool.query(
      `SELECT id, kind, room_number, device_id, device_name, detail,
              status, acknowledged_at, acknowledged_by, resolved_at,
              created_at
         FROM system_alerts
        WHERE id = ?
        LIMIT 1`,
      [id],
    );
    response.json({ alert: publicAlert(rows[0]) });
  }),
);

function clampLimit(_status, value) {
  const limit = Number.parseInt(String(value ?? ''), 10);
  if (!Number.isInteger(limit) || limit < 1) return 30;
  return Math.min(limit, 200);
}
