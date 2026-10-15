import crypto from 'node:crypto';

import { pool } from '../db.js';

// ชนิดของการแจ้งเตือนที่ระบบสร้างเอง
//
// เก็บเป็นรหัสไม่ใช่ข้อความสำเร็จรูป แอปจึงแปลเป็นภาษาไหนก็ได้
// และเปลี่ยนถ้อยคำได้โดยไม่ต้องแก้ข้อมูลเก่าในฐานข้อมูล
export const ALERT_KINDS = {
  /** ไม่มีคาบเรียน แต่แอร์ทำงานอยู่และมีคนอยู่ในห้อง */
  OUTSIDE_SCHEDULE_OCCUPIED: 'outside_schedule_occupied',
  /** ระบบสั่งปิดแอร์อัตโนมัติแล้วแอร์หยุดจริง */
  AUTO_OFF_SUCCEEDED: 'auto_off_succeeded',
  /** สั่งปิดครบจำนวนครั้งแล้วแอร์ยังทำงานอยู่ */
  AUTO_OFF_FAILED: 'auto_off_failed',
};

const OPEN_KINDS = new Set([
  ALERT_KINDS.OUTSIDE_SCHEDULE_OCCUPIED,
  ALERT_KINDS.AUTO_OFF_FAILED,
]);

/**
 * สร้างการแจ้งเตือน
 *
 * ชนิดที่ต้องให้คนมาจัดการ (`open`) จะไม่สร้างซ้ำถ้ายังมีใบเดิมค้างอยู่
 * ส่วนชนิดที่เป็นแค่การรายงานผล จะบันทึกเป็น `resolved` ตั้งแต่แรก
 *
 * @returns {Promise<string|null>} id ของใบที่สร้าง หรือ null ถ้าไม่ได้สร้าง
 */
export async function raiseAlert({
  kind,
  roomNumber,
  deviceId = null,
  deviceName = '',
  detail = '',
}) {
  if (!kind || !roomNumber) return null;

  const needsAction = OPEN_KINDS.has(kind);
  if (needsAction) {
    const existing = await pool.query(
      `SELECT id
         FROM system_alerts
        WHERE kind = ?
          AND room_number = ?
          AND (device_id <=> ?)
          AND status = 'open'
        LIMIT 1`,
      [kind, roomNumber, deviceId],
    );
    if (existing[0]) return null;
  }

  const id = crypto.randomUUID();
  await pool.query(
    `INSERT INTO system_alerts
       (id, kind, room_number, device_id, device_name, detail, status)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
    [
      id,
      kind,
      roomNumber,
      deviceId,
      String(deviceName ?? '').slice(0, 50),
      String(detail ?? '').slice(0, 255),
      needsAction ? 'open' : 'resolved',
    ],
  );
  return id;
}

/**
 * ปิดใบที่ค้างอยู่เมื่อเงื่อนไขหมดไปเอง เช่น ปิดแอร์แล้วหรือคนออกไปแล้ว
 */
export async function resolveOpenAlerts({ kind, roomNumber, deviceId = null }) {
  if (!kind || !roomNumber) return 0;
  const result = await pool.query(
    `UPDATE system_alerts
        SET status = 'resolved',
            resolved_at = CURRENT_TIMESTAMP
      WHERE kind = ?
        AND room_number = ?
        AND (device_id <=> ?)
        AND status = 'open'`,
    [kind, roomNumber, deviceId],
  );
  return Number(result?.affectedRows ?? 0);
}

export function publicAlert(row) {
  return {
    id: row.id,
    kind: row.kind,
    roomNumber: row.room_number,
    deviceId: row.device_id ?? null,
    deviceName: row.device_name ?? '',
    detail: row.detail ?? '',
    status: row.status,
    createdAt: toIsoString(row.created_at),
    resolvedAt: toIsoString(row.resolved_at),
    acknowledgedAt: toIsoString(row.acknowledged_at),
    acknowledgedBy: row.acknowledged_by ?? null,
  };
}

function toIsoString(value) {
  if (value == null) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}
