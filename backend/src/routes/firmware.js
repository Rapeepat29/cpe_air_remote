import fs from 'node:fs/promises';
import path from 'node:path';

import express from 'express';

import { config } from '../config.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireAdmin } from '../middleware/require-admin.js';
import { ApiError, asyncHandler } from '../utils/http.js';
import {
  FIRMWARE_KIND_LABELS,
  FIRMWARE_MAX_BYTES,
  firmwareKindOf,
  firmwareVersionOf,
  validateFirmwareFileName,
  validateFirmwareImage,
} from '../utils/firmware.js';

// รายการไฟล์เฟิร์มแวร์ที่วางไว้บนเซิร์ฟเวอร์ (/opt/rmutt/firmware)
// Caddy เสิร์ฟโฟลเดอร์เดียวกันที่ https://<โดเมน>/firmware/<ไฟล์>
export const firmwareRouter = express.Router();

firmwareRouter.use(authenticate, requireAdmin);

firmwareRouter.get(
  '/',
  asyncHandler(async (_request, response) => {
    response.json({
      configured: Boolean(config.firmwareDir),
      maxBytes: FIRMWARE_MAX_BYTES,
      files: await listFirmwareFiles(),
    });
  }),
);

/**
 * อัปโหลดไฟล์ .bin จากหน้าเว็บ แทนการ scp เข้าเซิร์ฟเวอร์เอง
 *
 * ส่งเป็นไฟล์ดิบ (application/octet-stream) ชื่อไฟล์อยู่ใน X-File-Name
 * แบบ percent-encoding เหมือนการนำเข้าตารางเรียน
 * ?kind=air|wired|occupancy = แท็บที่ผู้ใช้อยู่ ถ้าชื่อไฟล์บอกชนิดอื่นจะปฏิเสธ
 * กันอัปโหลดไฟล์เซ็นเซอร์เข้าไปในหมวดแอร์โดยไม่ตั้งใจ
 * ?replace=1 = ยอมเขียนทับไฟล์ชื่อเดิม
 */
firmwareRouter.post(
  '/',
  express.raw({ type: () => true, limit: FIRMWARE_MAX_BYTES + 1024 }),
  asyncHandler(async (request, response) => {
    if (!config.firmwareDir) {
      throw new ApiError(
        503,
        'เซิร์ฟเวอร์ยังไม่ได้ตั้ง FIRMWARE_DIR จึงเก็บไฟล์เฟิร์มแวร์ไม่ได้',
      );
    }
    const fileName = validateFirmwareFileName(
      decodeHeader(request.get('x-file-name')),
    );
    const kind = firmwareKindOf(fileName);
    const expected = String(request.query.kind ?? '').trim();
    if (expected && expected !== kind) {
      throw new ApiError(
        400,
        `ชื่อไฟล์บอกว่าเป็นของ${FIRMWARE_KIND_LABELS[kind]} `
          + `แต่กำลังอัปโหลดในหมวด${FIRMWARE_KIND_LABELS[expected] ?? expected} `
          + '(ไฟล์เซ็นเซอร์ต้องมีคำว่า occ ไฟล์สายแอร์ต้องมีคำว่า wired)',
      );
    }
    validateFirmwareImage(request.body);

    const target = path.join(config.firmwareDir, fileName);
    if (request.query.replace !== '1' && await fileExists(target)) {
      throw new ApiError(
        409,
        `มีไฟล์ ${fileName} อยู่แล้ว ถ้าต้องการแทนที่ให้ยืนยันการเขียนทับ`,
      );
    }

    // เขียนลงไฟล์ชั่วคราวก่อนแล้วค่อยเปลี่ยนชื่อ บอร์ดที่กำลังดาวน์โหลด
    // ไฟล์ชื่อเดิมอยู่จะไม่ได้ไฟล์ที่เขียนไปครึ่งเดียว
    // (ชื่อชั่วคราวไม่ลงท้าย .bin จึงไม่โผล่ในรายการไฟล์)
    const temporary = `${target}.${process.pid}.part`;
    try {
      await fs.writeFile(temporary, request.body, { mode: 0o644 });
      await fs.rename(temporary, target);
    } catch (error) {
      await fs.rm(temporary, { force: true }).catch(() => {});
      if (error?.code === 'EACCES' || error?.code === 'EROFS') {
        throw new ApiError(
          500,
          'Backend เขียนโฟลเดอร์ firmware ไม่ได้ (ตรวจว่า mount แบบอ่านอย่างเดียว '
            + 'หรือสิทธิ์ของโฟลเดอร์ /opt/rmutt/firmware)',
        );
      }
      throw error;
    }

    console.log(
      `[firmware] อัปโหลด ${fileName} (${request.body.length} bytes) `
        + `โดย ${request.authUser.username}`,
    );
    const file = (await listFirmwareFiles()).find((item) => item.name === fileName);
    response.status(201).json({ file });
  }),
);

firmwareRouter.delete(
  '/:fileName',
  asyncHandler(async (request, response) => {
    if (!config.firmwareDir) {
      throw new ApiError(503, 'เซิร์ฟเวอร์ยังไม่ได้ตั้ง FIRMWARE_DIR');
    }
    const fileName = validateFirmwareFileName(request.params.fileName);
    try {
      await fs.unlink(path.join(config.firmwareDir, fileName));
    } catch (error) {
      if (error?.code === 'ENOENT') {
        response.json({ removed: false, fileName });
        return;
      }
      if (error?.code === 'EACCES' || error?.code === 'EROFS') {
        throw new ApiError(500, 'Backend ลบไฟล์ในโฟลเดอร์ firmware ไม่ได้');
      }
      throw error;
    }
    console.log(`[firmware] ลบ ${fileName} โดย ${request.authUser.username}`);
    response.json({ removed: true, fileName });
  }),
);

function decodeHeader(value) {
  try {
    return decodeURIComponent(String(value ?? ''));
  } catch {
    return '';
  }
}

async function fileExists(target) {
  try {
    await fs.access(target);
    return true;
  } catch {
    return false;
  }
}

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
      version: firmwareVersionOf(name),
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
