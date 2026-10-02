import express from 'express';

import { pool } from '../db.js';
import { ApiError, asyncHandler } from '../utils/http.js';

export const publicRouter = express.Router();

publicRouter.get(
  '/admin-contact',
  asyncHandler(async (request, response) => {
    const rows = await pool.query(
      `SELECT first_name, last_name, username, phone
         FROM users
        WHERE role = 'admin'
          AND is_active = 1
          AND phone IS NOT NULL
          AND phone <> ''
        ORDER BY username ASC
        LIMIT 1`,
    );
    const admin = rows[0];

    if (!admin) {
      throw new ApiError(404, 'ยังไม่ได้กำหนดเบอร์แอดมินในฐานข้อมูล');
    }

    const name = [admin.first_name, admin.last_name]
      .filter(Boolean)
      .join(' ')
      .trim();

    response.json({
      admin: {
        name: name || admin.username || 'ผู้ดูแลระบบ',
        phone: String(admin.phone),
      },
    });
  }),
);
