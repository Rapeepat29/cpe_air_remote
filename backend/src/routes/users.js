import bcrypt from 'bcryptjs';
import express from 'express';

import { pool, withTransaction } from '../db.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireAdmin } from '../middleware/require-admin.js';
import { ApiError, asyncHandler } from '../utils/http.js';
import { isValidNewPassword } from '../utils/security.js';
import {
  managedUser,
  validateNewUserInput,
  validateUserUpdate,
  validateUsername,
} from '../utils/user.js';

export const usersRouter = express.Router();

usersRouter.use(authenticate);
usersRouter.use(requireAdmin);

const selectColumns = `username, first_name, last_name, email, phone,
                       role, is_active, last_login_at, created_at`;

usersRouter.get(
  '/',
  asyncHandler(async (request, response) => {
    const rows = await pool.query(
      `SELECT ${selectColumns}
         FROM users
        ORDER BY role = 'admin' DESC, is_active DESC, username`,
    );
    response.json({ users: rows.map(managedUser) });
  }),
);

usersRouter.post(
  '/',
  asyncHandler(async (request, response) => {
    const input = validateNewUserInput(request.body);
    if (!isValidNewPassword(input.password)) {
      throw new ApiError(
        400,
        'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร และไม่ยาวเกิน 72 ไบต์',
      );
    }

    const passwordHash = await bcrypt.hash(input.password, 12);
    try {
      await pool.query(
        `INSERT INTO users
           (username, password_hash, first_name, last_name, email, phone,
            role, is_active, password_changed_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, 1, NOW())`,
        [
          input.username,
          passwordHash,
          input.firstName,
          input.lastName,
          input.email,
          input.phone,
          input.role,
        ],
      );
    } catch (error) {
      if (error?.code === 'ER_DUP_ENTRY') {
        throw new ApiError(409, 'มี Username หรืออีเมลนี้ในระบบแล้ว');
      }
      throw error;
    }

    const rows = await pool.query(
      `SELECT ${selectColumns} FROM users WHERE username = ? LIMIT 1`,
      [input.username],
    );
    response.status(201).json({ user: managedUser(rows[0]) });
  }),
);

usersRouter.patch(
  '/:username',
  asyncHandler(async (request, response) => {
    const username = validateUsername(request.params.username);
    const update = validateUserUpdate(request.body);

    if (username === request.authUser.username) {
      throw new ApiError(
        400,
        'ไม่สามารถเปลี่ยนสิทธิ์หรือปิดบัญชีของตัวเองได้',
      );
    }

    await withTransaction(async (connection) => {
      const rows = await connection.query(
        `SELECT username, role, is_active
           FROM users
          WHERE username = ?
          LIMIT 1
          FOR UPDATE`,
        [username],
      );
      const target = rows[0];
      if (!target) {
        throw new ApiError(404, 'ไม่พบผู้ใช้นี้ในระบบ');
      }

      const nextRole = update.role ?? target.role;
      const nextActive = update.isActive ?? Boolean(target.is_active);
      const wasActiveAdmin = target.role === 'admin'
        && Boolean(target.is_active);
      const staysActiveAdmin = nextRole === 'admin' && nextActive;

      if (wasActiveAdmin && !staysActiveAdmin) {
        await assertAnotherActiveAdminExists(connection, username);
      }

      if (
        nextRole === target.role
        && nextActive === Boolean(target.is_active)
      ) {
        return;
      }

      await connection.query(
        `UPDATE users
            SET role = ?,
                is_active = ?,
                token_version = token_version + 1
          WHERE username = ?`,
        [nextRole, nextActive ? 1 : 0, username],
      );
    });

    const rows = await pool.query(
      `SELECT ${selectColumns} FROM users WHERE username = ? LIMIT 1`,
      [username],
    );
    response.json({ user: managedUser(rows[0]) });
  }),
);

usersRouter.delete(
  '/:username',
  asyncHandler(async (request, response) => {
    const username = validateUsername(request.params.username);

    if (username === request.authUser.username) {
      throw new ApiError(400, 'ไม่สามารถลบบัญชีของตัวเองได้');
    }

    await withTransaction(async (connection) => {
      const rows = await connection.query(
        `SELECT username, role, is_active
           FROM users
          WHERE username = ?
          LIMIT 1
          FOR UPDATE`,
        [username],
      );
      const target = rows[0];
      if (!target) {
        throw new ApiError(404, 'ไม่พบผู้ใช้นี้ในระบบ');
      }
      if (target.role === 'admin' && Boolean(target.is_active)) {
        await assertAnotherActiveAdminExists(connection, username);
      }

      await connection.query('DELETE FROM users WHERE username = ?', [
        username,
      ]);
    });

    response.status(204).end();
  }),
);

async function assertAnotherActiveAdminExists(connection, excludedUsername) {
  const rows = await connection.query(
    `SELECT COUNT(*) AS total
       FROM users
      WHERE role = 'admin' AND is_active = 1 AND username <> ?`,
    [excludedUsername],
  );
  if (Number(rows[0]?.total ?? 0) === 0) {
    throw new ApiError(
      409,
      'ระบบต้องมีผู้ดูแลระบบที่ใช้งานอยู่อย่างน้อย 1 บัญชี',
    );
  }
}
