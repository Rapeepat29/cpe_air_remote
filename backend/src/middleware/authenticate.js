import jwt from 'jsonwebtoken';

import { config } from '../config.js';
import { pool } from '../db.js';
import { ApiError, asyncHandler } from '../utils/http.js';
import { publicUser } from '../utils/user.js';

export const authenticate = asyncHandler(async (request, response, next) => {
  const authorization = request.get('authorization') ?? '';
  const [scheme, token] = authorization.split(' ');

  if (scheme !== 'Bearer' || !token) {
    throw new ApiError(401, 'กรุณาเข้าสู่ระบบ');
  }

  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret, {
      algorithms: ['HS256'],
      issuer: 'rmutt-save-energy-api',
      audience: 'rmutt-save-energy-app',
    });
  } catch {
    throw new ApiError(401, 'รหัสเข้าสู่ระบบหมดอายุหรือไม่ถูกต้อง');
  }

  const rows = await pool.query(
    `SELECT username, first_name, last_name, email, phone, role,
            token_version
       FROM users
      WHERE username = ? AND is_active = 1
      LIMIT 1`,
    [payload.sub],
  );
  const user = rows[0];

  if (!user || Number(user.token_version) !== Number(payload.ver)) {
    throw new ApiError(401, 'กรุณาเข้าสู่ระบบใหม่');
  }

  request.authUser = publicUser(user);
  next();
});
