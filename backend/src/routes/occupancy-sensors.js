import crypto from 'node:crypto';

import express from 'express';

import { config } from '../config.js';
import { pool } from '../db.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireAdmin } from '../middleware/require-admin.js';
import {
  clearRetainedOccupancyTopics,
  publishEnterOccupancySetupMode,
  publishOtaCommand,
  unprovisionDevice,
} from '../services/mqtt.js';
import { ApiError, asyncHandler } from '../utils/http.js';
import { assertFirmwareFileExists } from './firmware.js';
import {
  assertFirmwareKind,
  firmwareUrl,
  validateFirmwareFileName,
} from '../utils/firmware.js';
import { resolveMqttProvisioningSettings } from '../utils/mqtt-provisioning.js';
import {
  publicOccupancySensor,
  STATIC_ENERGY_THRESHOLD,
  validateOccupancyDeviceId,
  validateOccupancyReservationInput,
} from '../utils/occupancy-sensor.js';
import { hashSecret } from '../utils/security.js';
import {
  prepareDeviceCredentials,
  removeDeviceAccount,
} from '../services/mqtt-accounts.js';

export const occupancySensorsRouter = express.Router();

occupancySensorsRouter.use(authenticate);

occupancySensorsRouter.get(
  '/',
  asyncHandler(async (request, response) => {
    const rows = await pool.query(
      `SELECT device_id, room_number, ble_name, mqtt_topic,
              provision_status, is_online, radar_available, is_occupied,
              static_threshold, last_seen_at, firmware_version, ota_error
         FROM occupancy_sensors
        ORDER BY room_number, device_id`,
    );
    response.json({
      occupancySensors: rows.map(publicOccupancySensor),
    });
  }),
);

occupancySensorsRouter.post(
  '/reservations',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const input = validateOccupancyReservationInput(request.body);
    const mqttSettings = resolveMqttProvisioningSettings(config.mqtt);
    const roomRows = await pool.query(
      `SELECT room_number
         FROM rooms
        WHERE room_number = ?
        LIMIT 1`,
      [input.roomNumber],
    );
    if (!roomRows[0]) {
      throw new ApiError(
        400,
        `ยังไม่มีห้อง ${input.roomNumber} ในระบบ กรุณาให้ Admin เพิ่มห้องก่อน`,
      );
    }

    await pool.query(
      `DELETE FROM occupancy_sensors
        WHERE provision_status = 'reserved'
          AND provisioning_expires_at <= CURRENT_TIMESTAMP`,
    );
    await pool.query(
      `UPDATE occupancy_sensors
          SET provisioning_token_hash = NULL,
              provisioning_expires_at = NULL
        WHERE provision_status = 'active'
          AND provisioning_expires_at <= CURRENT_TIMESTAMP`,
    );

    const duplicateRows = await pool.query(
      `SELECT device_id, room_number, provision_status
         FROM occupancy_sensors
        WHERE device_id = ? OR room_number = ?
        ORDER BY device_id = ? DESC
        LIMIT 2`,
      [input.deviceId, input.roomNumber, input.deviceId],
    );
    const sameDevice = duplicateRows.find(
      (row) => row.device_id === input.deviceId,
    );
    const occupiedRoom = duplicateRows.find(
      (row) => row.room_number === input.roomNumber
        && row.device_id !== input.deviceId,
    );
    if (occupiedRoom) {
      throw new ApiError(
        409,
        `ห้อง ${input.roomNumber} มีเซ็นเซอร์ตรวจจับคนอยู่แล้ว`,
      );
    }
    if (sameDevice && sameDevice.room_number !== input.roomNumber) {
      throw new ApiError(
        409,
        `ESP32 เครื่องนี้ลงทะเบียนอยู่ที่ห้อง ${sameDevice.room_number} แล้ว`,
      );
    }
    if (sameDevice?.provision_status === 'reserved') {
      await pool.query(
        `DELETE FROM occupancy_sensors
          WHERE device_id = ? AND provision_status = 'reserved'`,
        [input.deviceId],
      );
    }

    const token = crypto.randomBytes(24).toString('base64url');
    const mqttTopic =
      `${config.mqtt.occupancyTopicPrefix}/${input.deviceId}`;
    const tokenHash = hashSecret(token, config.otpPepper);
    // บัญชี MQTT ของบอร์ดตัวนี้ (โหมด dynsec สร้างบน Broker ให้เลย)
    // ทำก่อนเขียนฐานข้อมูล ถ้า Broker ไม่พร้อมจะได้ไม่เหลือแถวจองค้าง
    let deviceCredentials;
    try {
      deviceCredentials = await prepareDeviceCredentials(
        input.deviceId,
        mqttSettings,
      );
    } catch (error) {
      console.error('เตรียมบัญชี MQTT ของอุปกรณ์ไม่สำเร็จ', error.message);
      throw new ApiError(
        503,
        'ยังสร้างบัญชี MQTT ของอุปกรณ์ไม่ได้ ตรวจว่า Backend ต่อ MQTT Broker อยู่',
      );
    }
    const deviceMqtt = { ...mqttSettings, ...deviceCredentials };
    if (sameDevice?.provision_status === 'active') {
      await pool.query(
        `UPDATE occupancy_sensors
            SET ble_name = ?,
                mqtt_topic = ?,
                provisioning_token_hash = ?,
                provisioning_expires_at =
                  DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 15 MINUTE),
                mqtt_host = ?,
                mqtt_port = ?,
                mqtt_username = ?,
                static_threshold = ?,
                updated_by = ?
          WHERE device_id = ?`,
        [
          input.bleName,
          mqttTopic,
          tokenHash,
          mqttSettings.mqttHost,
          mqttSettings.mqttPort,
          deviceMqtt.mqttUsername || null,
          STATIC_ENERGY_THRESHOLD,
          request.authUser.username,
          input.deviceId,
        ],
      );
    } else {
      await pool.query(
        `INSERT INTO occupancy_sensors
           (device_id, room_number, ble_name, mqtt_topic,
            provision_status, provisioning_token_hash,
            provisioning_expires_at, mqtt_host, mqtt_port, mqtt_username,
            static_threshold, created_by, updated_by)
         VALUES (?, ?, ?, ?, 'reserved', ?,
                 DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 15 MINUTE),
                 ?, ?, ?, ?, ?, ?)`,
        [
          input.deviceId,
          input.roomNumber,
          input.bleName,
          mqttTopic,
          tokenHash,
          mqttSettings.mqttHost,
          mqttSettings.mqttPort,
          deviceMqtt.mqttUsername || null,
          STATIC_ENERGY_THRESHOLD,
          request.authUser.username,
          request.authUser.username,
        ],
      );
    }

    response.status(sameDevice?.provision_status === 'active' ? 200 : 201)
      .json({
        reservation: {
          ...input,
          staticThreshold: STATIC_ENERGY_THRESHOLD,
          mqttTopic,
          ...deviceMqtt,
          provisioningToken: token,
          expiresInSeconds: 900,
        },
      });
  }),
);

occupancySensorsRouter.post(
  '/:deviceId/setup-mode',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const deviceId = validateOccupancyDeviceId(request.params.deviceId);
    const rows = await pool.query(
      `SELECT provision_status
         FROM occupancy_sensors
        WHERE device_id = ?
        LIMIT 1`,
      [deviceId],
    );
    if (!rows[0]) throw new ApiError(404, 'ไม่พบเซ็นเซอร์ตรวจจับคนนี้');
    if (rows[0].provision_status !== 'active') {
      throw new ApiError(409, 'เซ็นเซอร์ยังตั้งค่า MQTT ไม่สำเร็จ');
    }

    // ล้างผลรอบก่อน ให้หน้าเว็บแยกได้ว่า otaError ที่มาหลังจากนี้เป็นของรอบใหม่
    await pool.query(
      'UPDATE occupancy_sensors SET ota_error = NULL WHERE device_id = ?',
      [deviceId],
    );

    let published;
    try {
      published = await publishEnterOccupancySetupMode(deviceId);
    } catch (error) {
      if (error?.statusCode === 503) {
        throw new ApiError(503, 'Backend ยังไม่เชื่อมต่อ MQTT Broker');
      }
      throw error;
    }
    response.status(202).json({
      accepted: true,
      commandId: published.payload.commandId,
      action: published.payload.action,
    });
  }),
);

// สั่งให้บอร์ดอัปเดตเฟิร์มแวร์ผ่าน Wi-Fi จากไฟล์ใน /firmware ของเซิร์ฟเวอร์
// บอร์ดจะรีบูตเองเมื่อสำเร็จ ดูผลได้จาก firmwareVersion / otaError
occupancySensorsRouter.post(
  '/:deviceId/ota',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const deviceId = validateOccupancyDeviceId(request.params.deviceId);
    const fileName = validateFirmwareFileName(request.body?.file);
    assertFirmwareKind(fileName, 'occupancy');
    await assertFirmwareFileExists(fileName);
    const rows = await pool.query(
      `SELECT provision_status, is_online, mqtt_host
         FROM occupancy_sensors
        WHERE device_id = ?
        LIMIT 1`,
      [deviceId],
    );
    const row = rows[0];
    if (!row) throw new ApiError(404, 'ไม่พบเซ็นเซอร์ตรวจจับคนนี้');
    if (row.provision_status !== 'active') {
      throw new ApiError(409, 'บอร์ดยังตั้งค่าและยืนยันผ่าน MQTT ไม่สำเร็จ');
    }
    if (!row.is_online) {
      throw new ApiError(409, 'บอร์ดออฟไลน์อยู่ สั่งอัปเดตได้เมื่อบอร์ดออนไลน์');
    }
    const url = firmwareUrl(row.mqtt_host, fileName);

    let published;
    try {
      published = await publishOtaCommand('occupancy', deviceId, url);
    } catch (error) {
      if (error?.statusCode === 503) {
        throw new ApiError(503, 'Backend ยังไม่เชื่อมต่อ MQTT Broker');
      }
      throw error;
    }
    console.log(
      `[ota] ${deviceId} <- ${url} โดย ${request.authUser.username}`,
    );
    response.status(202).json({
      accepted: true,
      commandId: published.payload.commandId,
      url,
    });
  }),
);

occupancySensorsRouter.delete(
  '/:deviceId',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const deviceId = validateOccupancyDeviceId(request.params.deviceId);
    const result = await pool.query(
      'DELETE FROM occupancy_sensors WHERE device_id = ?',
      [deviceId],
    );
    const deletedRows = Number(result.affectedRows ?? 0);
    // สั่งบอร์ดล้างค่าในตัวเองก่อนลบบัญชี MQTT (ลบบัญชีแล้วคำสั่งจะไปไม่ถึง)
    const board = await unprovisionDevice('occupancy', deviceId);
    const retainedTopicsCleared = await clearRetainedOccupancyTopics(deviceId);
    const mqttAccountRemoved = await removeDeviceAccount(deviceId);

    console.log(
      `[occupancy] ลบ ${deviceId} โดย ${request.authUser.username}: `
        + `deletedRows=${deletedRows} `
        + `retainedTopicsCleared=${retainedTopicsCleared} `
        + `mqttAccountRemoved=${mqttAccountRemoved} `
        + `boardCleared=${board.acknowledged}`,
    );

    // ลบซ้ำถือว่าสำเร็จ เพื่อไม่ให้แอปค้างกับแถวที่หายไปแล้ว
    response.json({
      removed: true,
      deviceId,
      deletedRows,
      retainedTopicsCleared,
      mqttAccountRemoved,
      // true = บอร์ดยืนยันว่าล้างค่าแล้ว, false = บอร์ดออฟไลน์หรือไม่ตอบ
      // (ต้องล้างที่ตัวบอร์ดเอง: อัปโหลด firmware/reset หรือตั้งค่าใหม่ผ่านบลูทูธ)
      boardCleared: board.acknowledged,
    });
  }),
);
