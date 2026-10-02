import express from 'express';

import { authenticate } from '../middleware/authenticate.js';
import { requireAdmin } from '../middleware/require-admin.js';
import {
  RATE_LIMITS,
  readPublicSettings,
  setAutoOffEnabled,
  setElectricityRate,
} from '../services/system-settings.js';
import { ApiError, asyncHandler } from '../utils/http.js';

export const settingsRouter = express.Router();

settingsRouter.use(authenticate);

// อ่านได้ทุกคนที่ล็อกอินแล้ว
//
// คนที่ไม่ใช่แอดมินก็ควรเห็นว่าระบบปิดแอร์อัตโนมัติถูกปิดอยู่ ไม่งั้นจะงง
// ว่าทำไมนับถอยหลังไม่ขึ้นสักที แล้วไปแจ้งว่าเซ็นเซอร์พัง
// อัตราค่าไฟก็ต้องอ่านได้ทุกคน เพราะทุกหน้าจอเอาไปคูณกับ kWh
settingsRouter.get(
  '/',
  asyncHandler(async (_request, response) => {
    response.json(await readPublicSettings());
  }),
);

// แก้ได้เฉพาะแอดมิน เพราะกดทีเดียวหยุดทั้งอาคาร
settingsRouter.patch(
  '/auto-off',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const { enabled } = request.body ?? {};
    if (typeof enabled !== 'boolean') {
      throw new ApiError(400, 'ต้องส่ง enabled เป็น true หรือ false');
    }

    const settings = await setAutoOffEnabled(
      enabled,
      request.authUser?.username,
    );
    response.json(settings);
  }),
);

// อัตราค่าไฟก็ให้แก้ได้เฉพาะแอดมิน เพราะตัวเลขค่าใช้จ่ายทุกหน้าจอและทุกไฟล์
// รายงานอ้างอิงค่านี้ ถ้าใครก็แก้ได้ รายงานที่พิมพ์ออกไปคนละวันจะไม่ตรงกัน
settingsRouter.patch(
  '/rate',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const { rate } = request.body ?? {};
    const value = typeof rate === 'number' ? rate : Number.parseFloat(rate);
    if (!Number.isFinite(value)) {
      throw new ApiError(400, 'ต้องส่ง rate เป็นตัวเลข');
    }
    if (value < RATE_LIMITS.min || value > RATE_LIMITS.max) {
      throw new ApiError(
        400,
        `อัตราค่าไฟต้องอยู่ระหว่าง ${RATE_LIMITS.min} ถึง `
          + `${RATE_LIMITS.max} บาทต่อ kWh`,
      );
    }

    const settings = await setElectricityRate(
      value,
      request.authUser?.username,
    );
    response.json(settings);
  }),
);
