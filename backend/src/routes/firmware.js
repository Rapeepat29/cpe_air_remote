import fs from 'node:fs/promises';
import path from 'node:path';

import express from 'express';

import { config } from '../config.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireAdmin } from '../middleware/require-admin.js';
import { ApiError, asyncHandler } from '../utils/http.js';
import { firmwareKindOf } from '../utils/firmware.js';

// รายการไฟล์เฟิร์มแวร์ที่วางไว้บนเซิร์ฟเวอร์ (/opt/rmutt/firmware)
// Caddy เสิร์ฟโฟลเดอร์เดียวกันที่ https://<โดเมน>/firmware/<ไฟล์>
export const firmwareRouter = express.Router();

firmwareRouter.use(authenticate, requireAdmin);

firmwareRouter.get(
  '/',
  asyncHandler(async (_request, response) => {
    response.json({
      configured: Boolean(config.firmwareDir),
      files: await listFirmwareFiles(),
    });
  }),
);

export async function listFirmwareFiles() {
  if (!config.firmwareDir) return [];
  let names;
  try {
    names = await fs.readdir(config.firmwareDir);
  } catch (error) {
    if (error?.code === 'ENOENT') return [];
    throw error;
  }
  const files = [];
  for (const name of names) {
    if (!name.endsWith('.bin')) continue;
    const stat = await fs.stat(path.join(config.firmwareDir, name));
    if (!stat.isFile()) continue;
    files.push({
      name,
      size: stat.size,
      modifiedAt: stat.mtime.toISOString(),
      kind: firmwareKindOf(name),
    });
  }
  return files.sort((a, b) => b.modifiedAt.localeCompare(a.modifiedAt));
}

/** ถ้าตั้ง FIRMWARE_DIR ไว้ ตรวจว่ามีไฟล์จริงก่อนสั่งบอร์ด */
export async function assertFirmwareFileExists(fileName) {
  if (!config.firmwareDir) return;
  try {
    const stat = await fs.stat(path.join(config.firmwareDir, fileName));
    if (stat.isFile() && stat.size > 0) return;
  } catch {
    // ตกไปแจ้งข้อผิดพลาดข้างล่าง
  }
  throw new ApiError(
    404,
    `ไม่พบไฟล์ ${fileName} ในโฟลเดอร์ firmware ของเซิร์ฟเวอร์`,
  );
}
