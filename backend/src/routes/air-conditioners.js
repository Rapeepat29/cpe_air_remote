import crypto from 'node:crypto';

import express from 'express';

import { config } from '../config.js';
import { pool } from '../db.js';
import { authenticate } from '../middleware/authenticate.js';
import { requireAdmin } from '../middleware/require-admin.js';
import {
  clearRetainedAirTopics,
  publishAirCommand,
  publishEnterSetupMode,
  publishOtaCommand,
  unprovisionDevice,
} from '../services/mqtt.js';
import {
  publicAirConditioner,
  validateAirState,
  validateDeviceId,
  validateReservationInput,
} from '../utils/air-conditioner.js';
import { ApiError, asyncHandler } from '../utils/http.js';
import { assertFirmwareFileExists } from './firmware.js';
import {
  airFirmwareKind,
  assertFirmwareKind,
  firmwareUrl,
  validateFirmwareFileName,
} from '../utils/firmware.js';
import { hashSecret } from '../utils/security.js';
import {
  prepareDeviceCredentials,
  removeDeviceAccount,
} from '../services/mqtt-accounts.js';
import { resolveMqttProvisioningSettings } from '../utils/mqtt-provisioning.js';

export const airConditionersRouter = express.Router();

airConditionersRouter.use(authenticate);

airConditionersRouter.get(
  '/',
  asyncHandler(async (request, response) => {
    const rows = await pool.query(
      `SELECT device_id, room_number, air_number, name, ble_name,
              protocol, provision_status, is_online, mqtt_topic,
              daily_on, daily_off, last_seen_at, voltage,
              current_amp, power_watts, energy_kwh, frequency_hz,
              power_factor, pzem_available, ac_running,
              outside_schedule, state_json,
              auto_off_enabled, auto_off_deadline_at, auto_off_attempts,
              auto_off_in_class, firmware_version, ota_error,
              history_pending
         FROM air_conditioners
        ORDER BY room_number, air_number`,
    );
    response.json({
      airConditioners: rows.map(publicAirConditioner),
    });
  }),
);

airConditionersRouter.post(
  '/reservations',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const input = validateReservationInput(request.body);
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
      `DELETE FROM air_conditioners
        WHERE provision_status = 'reserved'
          AND provisioning_expires_at <= CURRENT_TIMESTAMP`,
    );
    await pool.query(
      `UPDATE air_conditioners
          SET provisioning_token_hash = NULL,
              provisioning_expires_at = NULL
        WHERE provision_status = 'active'
          AND provisioning_expires_at <= CURRENT_TIMESTAMP`,
    );

    const duplicateRows = await pool.query(
      `SELECT device_id, room_number, air_number, provision_status
         FROM air_conditioners
        WHERE device_id = ?
           OR (room_number = ? AND air_number = ?)
        ORDER BY device_id = ? DESC
        LIMIT 2`,
      [
        input.deviceId,
        input.roomNumber,
        input.airNumber,
        input.deviceId,
      ],
    );
    const sameDevice = duplicateRows.find(
      (row) => row.device_id === input.deviceId,
    );
    const occupiedSlot = duplicateRows.find(
      (row) => row.room_number === input.roomNumber
        && Number(row.air_number) === input.airNumber
        && row.device_id !== input.deviceId,
    );
    if (occupiedSlot) {
      throw new ApiError(
        409,
        `ห้อง ${input.roomNumber} มีแอร์หมายเลข ${input.airNumber} แล้ว`,
      );
    }
    if (
      sameDevice
      && (
        sameDevice.room_number !== input.roomNumber
        || Number(sameDevice.air_number) !== input.airNumber
      )
    ) {
      throw new ApiError(
        409,
        `ESP32 เครื่องนี้ลงทะเบียนอยู่ที่ห้อง ${sameDevice.room_number} `
          + `แอร์หมายเลข ${sameDevice.air_number} แล้ว`,
      );
    }
    if (sameDevice?.provision_status === 'reserved') {
      await pool.query(
        `DELETE FROM air_conditioners
          WHERE device_id = ? AND provision_status = 'reserved'`,
        [input.deviceId],
      );
    }

    const token = crypto.randomBytes(24).toString('base64url');
    const mqttTopic = `${config.mqtt.topicPrefix}/${input.deviceId}`;
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
        `UPDATE air_conditioners
            SET name = ?,
                ble_name = ?,
                protocol = ?,
                mqtt_topic = ?,
                provisioning_token_hash = ?,
                provisioning_expires_at =
                  DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 15 MINUTE),
                mqtt_host = ?,
                mqtt_port = ?,
                mqtt_username = ?,
                daily_on = ?,
                daily_off = ?,
                updated_by = ?
          WHERE device_id = ?`,
        [
          input.name,
          input.bleName,
          input.protocol,
          mqttTopic,
          tokenHash,
          mqttSettings.mqttHost,
          mqttSettings.mqttPort,
          deviceMqtt.mqttUsername || null,
          input.dailyOn,
          input.dailyOff,
          request.authUser.username,
          input.deviceId,
        ],
      );
    } else {
      await pool.query(
        `INSERT INTO air_conditioners
           (device_id, room_number, air_number, name, ble_name, protocol,
            mqtt_topic, provision_status, provisioning_token_hash,
            provisioning_expires_at, mqtt_host, mqtt_port, mqtt_username,
            daily_on, daily_off, created_by, updated_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, 'reserved', ?,
                 DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 15 MINUTE),
                 ?, ?, ?, ?, ?, ?, ?)`,
        [
          input.deviceId,
          input.roomNumber,
          input.airNumber,
          input.name,
          input.bleName,
          input.protocol,
          mqttTopic,
          tokenHash,
          mqttSettings.mqttHost,
          mqttSettings.mqttPort,
          deviceMqtt.mqttUsername || null,
          input.dailyOn,
          input.dailyOff,
          request.authUser.username,
          request.authUser.username,
        ],
      );
    }

    response.status(sameDevice?.provision_status === 'active' ? 200 : 201).json({
      reservation: {
        ...input,
        mqttTopic,
        ...deviceMqtt,
        provisioningToken: token,
        expiresInSeconds: 900,
      },
    });
  }),
);

airConditionersRouter.post(
  '/:deviceId/command',
  asyncHandler(async (request, response) => {
    const deviceId = validateDeviceId(request.params.deviceId);
    const rows = await pool.query(
      `SELECT provision_status, protocol
         FROM air_conditioners
        WHERE device_id = ?
        LIMIT 1`,
      [deviceId],
    );
    if (!rows[0]) {
      throw new ApiError(404, 'ไม่พบเครื่องปรับอากาศนี้');
    }
    if (rows[0].provision_status !== 'active') {
      throw new ApiError(409, 'ESP32 ยังเชื่อมต่อ MQTT เพื่อยืนยันการคอนฟิกไม่สำเร็จ');
    }
    const state = validateAirState(request.body, rows[0].protocol);

    let published;
    try {
      published = await publishAirCommand(deviceId, state);
    } catch (error) {
      if (error?.statusCode === 503) {
        throw new ApiError(503, 'Backend ยังไม่เชื่อมต่อ MQTT Broker');
      }
      throw error;
    }

    response.status(202).json({
      accepted: true,
      commandId: published.payload.commandId,
      state,
    });
  }),
);

airConditionersRouter.post(
  '/:deviceId/setup-mode',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const deviceId = validateDeviceId(request.params.deviceId);
    const rows = await pool.query(
      `SELECT provision_status
         FROM air_conditioners
        WHERE device_id = ?
        LIMIT 1`,
      [deviceId],
    );
    if (!rows[0]) {
      throw new ApiError(404, 'ไม่พบเครื่องปรับอากาศนี้');
    }
    if (rows[0].provision_status !== 'active') {
      throw new ApiError(409, 'ESP32 ยังตั้งค่าและยืนยันผ่าน MQTT ไม่สำเร็จ');
    }

    let published;
    try {
      published = await publishEnterSetupMode(deviceId);
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

airConditionersRouter.patch(
  '/:deviceId',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const deviceId = validateDeviceId(request.params.deviceId);
    const fields = [];
    const params = [];

    if (request.body?.name !== undefined) {
      const name = typeof request.body.name === 'string'
        ? request.body.name.trim()
        : '';
      if (name.length < 1 || name.length > 50) {
        throw new ApiError(400, 'ชื่อแอร์ต้องมีความยาว 1–50 ตัวอักษร');
      }
      fields.push('name = ?');
      params.push(name);
    }

    // ปิดฟีเจอร์ปิดอัตโนมัติรายเครื่องได้ เผื่อห้องที่ต้องเปิดแอร์ค้างไว้
    if (request.body?.autoOffEnabled !== undefined) {
      if (typeof request.body.autoOffEnabled !== 'boolean') {
        throw new ApiError(400, 'ค่าปิดอัตโนมัติต้องเป็น true หรือ false');
      }
      fields.push('auto_off_enabled = ?');
      params.push(request.body.autoOffEnabled ? 1 : 0);
      if (!request.body.autoOffEnabled) {
        fields.push('auto_off_started_at = NULL');
        fields.push('auto_off_deadline_at = NULL');
        fields.push('auto_off_attempts = 0');
        fields.push('auto_off_last_attempt_at = NULL');
      }
    }

    if (fields.length === 0) {
      throw new ApiError(400, 'ไม่มีข้อมูลที่ต้องแก้ไข');
    }

    fields.push('updated_by = ?');
    params.push(request.authUser.username, deviceId);

    const result = await pool.query(
      `UPDATE air_conditioners
          SET ${fields.join(', ')}
        WHERE device_id = ?`,
      params,
    );
    if (Number(result.affectedRows) === 0) {
      throw new ApiError(404, 'ไม่พบเครื่องปรับอากาศนี้');
    }
    response.json({ updated: true });
  }),
);

// สั่งให้บอร์ดอัปเดตเฟิร์มแวร์ผ่าน Wi-Fi จากไฟล์ใน /firmware ของเซิร์ฟเวอร์
// บอร์ดจะรีบูตเองเมื่อสำเร็จ ดูผลได้จาก firmwareVersion / otaError
airConditionersRouter.post(
  '/:deviceId/ota',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const deviceId = validateDeviceId(request.params.deviceId);
    const fileName = validateFirmwareFileName(request.body?.file);
    await assertFirmwareFileExists(fileName);
    const rows = await pool.query(
      `SELECT provision_status, is_online, mqtt_host, protocol
         FROM air_conditioners
        WHERE device_id = ?
        LIMIT 1`,
      [deviceId],
    );
    const row = rows[0];
    if (!row) throw new ApiError(404, 'ไม่พบเครื่องปรับอากาศนี้');
    assertFirmwareKind(fileName, airFirmwareKind(row.protocol));
    if (row.provision_status !== 'active') {
      throw new ApiError(409, 'บอร์ดยังตั้งค่าและยืนยันผ่าน MQTT ไม่สำเร็จ');
    }
    if (!row.is_online) {
      throw new ApiError(409, 'บอร์ดออฟไลน์อยู่ สั่งอัปเดตได้เมื่อบอร์ดออนไลน์');
    }
    const url = firmwareUrl(row.mqtt_host, fileName);

    // ล้างผลรอบก่อน ให้หน้าเว็บแยกได้ว่า otaError ที่มาหลังจากนี้เป็นของรอบใหม่
    await pool.query(
      'UPDATE air_conditioners SET ota_error = NULL WHERE device_id = ?',
      [deviceId],
    );

    let published;
    try {
      published = await publishOtaCommand('air', deviceId, url);
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

airConditionersRouter.delete(
  '/:deviceId',
  requireAdmin,
  asyncHandler(async (request, response) => {
    const deviceId = validateDeviceId(request.params.deviceId);
    const result = await pool.query(
      'DELETE FROM air_conditioners WHERE device_id = ?',
      [deviceId],
    );
    const deletedRows = Number(result.affectedRows ?? 0);
    // สั่งบอร์ดล้างค่าในตัวเองก่อนลบบัญชี MQTT (ลบบัญชีแล้วคำสั่งจะไปไม่ถึง)
    const board = await unprovisionDevice('air', deviceId);
    const retainedTopicsCleared = await clearRetainedAirTopics(deviceId);
    const mqttAccountRemoved = await removeDeviceAccount(deviceId);

    console.log(
      `[air] ลบ ${deviceId} โดย ${request.authUser.username}: `
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
