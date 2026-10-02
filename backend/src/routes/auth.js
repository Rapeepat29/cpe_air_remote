import crypto from 'node:crypto';

import bcrypt from 'bcryptjs';
import express from 'express';
import rateLimit from 'express-rate-limit';
import jwt from 'jsonwebtoken';

import { config } from '../config.js';
import { pool, withTransaction } from '../db.js';
import { authenticate } from '../middleware/authenticate.js';
import { sendPasswordResetOtp } from '../services/mailer.js';
import { ApiError, asyncHandler } from '../utils/http.js';
import {
  createOtp,
  createResetToken,
  hashSecret,
  isValidNewPassword,
  safeHashEquals,
} from '../utils/security.js';
import { publicUser, validateProfileUpdate } from '../utils/user.js';

export const authRouter = express.Router();

const dummyPasswordHash =
  '$2b$12$l6JjOOe7XokI9qoxrAqZMupSpyJicZzJy1.dbUG0PjJdPk.6mk3wi';

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { message: 'ลองเข้าสู่ระบบหลายครั้งเกินไป กรุณารอ 15 นาที' },
});

const resetLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 8,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { message: 'ขอเปลี่ยนรหัสผ่านบ่อยเกินไป กรุณาลองใหม่ภายหลัง' },
});

authRouter.post(
  '/login',
  loginLimiter,
  asyncHandler(async (request, response) => {
    const username = cleanString(request.body?.username, 100);
    const password = typeof request.body?.password === 'string'
      ? request.body.password
      : '';

    if (!username || !password || password.length > 256) {
      throw new ApiError(400, 'กรุณากรอก Username และ Password');
    }

    const rows = await pool.query(
      `SELECT username, password_hash, first_name, last_name, email, phone,
              role, token_version
         FROM users
        WHERE username = ? AND is_active = 1
        LIMIT 1`,
      [username],
    );
    const user = rows[0];
    const isCorrect = user
      ? await bcrypt.compare(password, user.password_hash)
      : await bcrypt.compare(password, dummyPasswordHash);

    if (!user || !isCorrect) {
      throw new ApiError(401, 'Username หรือ Password ไม่ถูกต้อง');
    }

    await pool.query(
      'UPDATE users SET last_login_at = NOW() WHERE username = ?',
      [user.username],
    );

    const token = jwt.sign(
      {
        role: user.role,
        ver: Number(user.token_version),
      },
      config.jwtSecret,
      {
        algorithm: 'HS256',
        subject: user.username,
        expiresIn: config.jwtExpiresIn,
        issuer: 'rmutt-save-energy-api',
        audience: 'rmutt-save-energy-app',
      },
    );

    response.json({
      token,
      user: publicUser(user),
    });
  }),
);

authRouter.get(
  '/me',
  authenticate,
  asyncHandler(async (request, response) => {
    response.json({ user: request.authUser });
  }),
);

// แก้ข้อมูลบัญชีตัวเอง สิทธิ์กับสถานะบัญชีแก้ที่นี่ไม่ได้โดยตั้งใจ
authRouter.patch(
  '/me',
  authenticate,
  asyncHandler(async (request, response) => {
    const input = validateProfileUpdate(request.body);
    const username = request.authUser.username;

    try {
      await pool.query(
        `UPDATE users
            SET first_name = ?,
                last_name = ?,
                email = ?,
                phone = ?
          WHERE username = ?`,
        [input.firstName, input.lastName, input.email, input.phone, username],
      );
    } catch (error) {
      if (error?.code === 'ER_DUP_ENTRY') {
        throw new ApiError(409, 'มีอีเมลนี้ในระบบแล้ว');
      }
      throw error;
    }

    const rows = await pool.query(
      `SELECT username, first_name, last_name, email, phone, role
         FROM users
        WHERE username = ?
        LIMIT 1`,
      [username],
    );
    response.json({ user: publicUser(rows[0]) });
  }),
);

// เปลี่ยนรหัสผ่านโดยยืนยันด้วยรหัสเดิม ต่างจากการรีเซ็ตผ่าน OTP
// สำเร็จแล้วจะบวก token_version ทำให้เครื่องอื่นที่ค้างอยู่ต้องเข้าสู่ระบบใหม่
authRouter.post(
  '/me/password',
  authenticate,
  asyncHandler(async (request, response) => {
    const currentPassword = typeof request.body?.currentPassword === 'string'
      ? request.body.currentPassword
      : '';
    const newPassword = request.body?.newPassword;

    if (!currentPassword || currentPassword.length > 256) {
      throw new ApiError(400, 'กรุณากรอกรหัสผ่านปัจจุบัน');
    }
    if (!isValidNewPassword(newPassword)) {
      throw new ApiError(
        400,
        'รหัสผ่านใหม่ต้องมีอย่างน้อย 8 ตัวอักษร และไม่ยาวเกิน 72 ไบต์',
      );
    }
    if (newPassword === currentPassword) {
      throw new ApiError(400, 'รหัสผ่านใหม่ต้องไม่ซ้ำกับรหัสผ่านเดิม');
    }

    const username = request.authUser.username;
    const rows = await pool.query(
      'SELECT password_hash FROM users WHERE username = ? LIMIT 1',
      [username],
    );
    const user = rows[0];
    if (!user) {
      throw new ApiError(401, 'กรุณาเข้าสู่ระบบใหม่');
    }

    const isCorrect = await bcrypt.compare(
      currentPassword,
      user.password_hash,
    );
    if (!isCorrect) {
      throw new ApiError(400, 'รหัสผ่านปัจจุบันไม่ถูกต้อง');
    }

    await pool.query(
      `UPDATE users
          SET password_hash = ?,
              password_changed_at = NOW(),
              token_version = token_version + 1
        WHERE username = ?`,
      [await bcrypt.hash(newPassword, 12), username],
    );

    response.json({ message: 'เปลี่ยนรหัสผ่านสำเร็จ' });
  }),
);

authRouter.post(
  '/forgot-password',
  resetLimiter,
  asyncHandler(async (request, response) => {
    const identifier = cleanString(request.body?.identifier, 190);
    if (!identifier) {
      throw new ApiError(400, 'กรุณากรอก Username หรือ Email');
    }

    const requestId = crypto.randomUUID();
    const rows = await pool.query(
      `SELECT username, first_name, last_name, email
         FROM users
        WHERE (username = ? OR email = ?) AND is_active = 1
        LIMIT 1`,
      [identifier, identifier],
    );
    const user = rows[0];

    if (user?.email) {
      const otp = createOtp();
      const otpHash = hashSecret(otp);
      const expiresAt = new Date(
        Date.now() + config.otpExpiresMinutes * 60 * 1000,
      );

      await withTransaction(async (connection) => {
        await connection.query(
          `UPDATE password_reset_otps
              SET used_at = NOW()
            WHERE username = ? AND used_at IS NULL`,
          [user.username],
        );
        await connection.query(
          `INSERT INTO password_reset_otps
             (id, username, otp_hash, expires_at)
           VALUES (?, ?, ?, ?)`,
          [requestId, user.username, otpHash, expiresAt],
        );
      });

      try {
        await sendPasswordResetOtp({
          to: user.email,
          displayName: [user.first_name, user.last_name]
            .filter(Boolean)
            .join(' '),
          otp,
        });
      } catch (error) {
        await pool.query(
          'DELETE FROM password_reset_otps WHERE id = ?',
          [requestId],
        );
        console.error('Unable to send password reset email:', error);
      }
    }

    // This response is intentionally identical whether the account exists or not.
    response.json({
      requestId,
      message: 'หากข้อมูลถูกต้อง ระบบจะส่ง OTP ไปยังอีเมลในฐานข้อมูล',
    });
  }),
);

authRouter.post(
  '/verify-otp',
  resetLimiter,
  asyncHandler(async (request, response) => {
    const requestId = cleanString(request.body?.requestId, 36);
    const otp = cleanString(request.body?.otp, 6);

    if (
      !requestId ||
      !/^[0-9a-f-]{36}$/i.test(requestId) ||
      !/^\d{6}$/.test(otp)
    ) {
      throw new ApiError(400, 'OTP ไม่ถูกต้องหรือหมดอายุแล้ว');
    }

    const rows = await pool.query(
      `SELECT id, otp_hash, expires_at, attempts, used_at
         FROM password_reset_otps
        WHERE id = ?
        LIMIT 1`,
      [requestId],
    );
    const reset = rows[0];

    if (
      !reset ||
      reset.used_at ||
      Number(reset.attempts) >= 5 ||
      new Date(reset.expires_at).getTime() <= Date.now()
    ) {
      throw new ApiError(400, 'OTP ไม่ถูกต้องหรือหมดอายุแล้ว');
    }

    const submittedHash = hashSecret(otp);
    if (!safeHashEquals(reset.otp_hash, submittedHash)) {
      await pool.query(
        'UPDATE password_reset_otps SET attempts = attempts + 1 WHERE id = ?',
        [requestId],
      );
      throw new ApiError(400, 'OTP ไม่ถูกต้องหรือหมดอายุแล้ว');
    }

    const resetToken = createResetToken();
    await pool.query(
      `UPDATE password_reset_otps
          SET reset_token_hash = ?, verified_at = NOW()
        WHERE id = ?`,
      [hashSecret(resetToken), requestId],
    );

    response.json({ resetToken });
  }),
);

authRouter.post(
  '/reset-password',
  resetLimiter,
  asyncHandler(async (request, response) => {
    const resetToken = cleanString(request.body?.resetToken, 64);
    const newPassword = request.body?.newPassword;

    if (!/^[0-9a-f]{64}$/i.test(resetToken)) {
      throw new ApiError(400, 'สิทธิ์เปลี่ยนรหัสผ่านไม่ถูกต้องหรือหมดอายุแล้ว');
    }
    if (!isValidNewPassword(newPassword)) {
      throw new ApiError(
        400,
        'รหัสผ่านใหม่ต้องมีอย่างน้อย 8 ตัวอักษร และไม่ยาวเกิน 72 ไบต์',
      );
    }

    const newPasswordHash = await bcrypt.hash(newPassword, 12);
    const resetTokenHash = hashSecret(resetToken);

    await withTransaction(async (connection) => {
      const rows = await connection.query(
        `SELECT id, username, expires_at, used_at, verified_at
           FROM password_reset_otps
          WHERE reset_token_hash = ?
          LIMIT 1
          FOR UPDATE`,
        [resetTokenHash],
      );
      const reset = rows[0];

      if (
        !reset ||
        reset.used_at ||
        !reset.verified_at ||
        new Date(reset.expires_at).getTime() <= Date.now()
      ) {
        throw new ApiError(
          400,
          'สิทธิ์เปลี่ยนรหัสผ่านไม่ถูกต้องหรือหมดอายุแล้ว',
        );
      }

      await connection.query(
        `UPDATE users
            SET password_hash = ?,
                password_changed_at = NOW(),
                token_version = token_version + 1
          WHERE username = ?`,
        [newPasswordHash, reset.username],
      );
      await connection.query(
        'UPDATE password_reset_otps SET used_at = NOW() WHERE id = ?',
        [reset.id],
      );
    });

    response.json({ message: 'เปลี่ยนรหัสผ่านสำเร็จ' });
  }),
);

function cleanString(value, maxLength) {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, maxLength);
}
