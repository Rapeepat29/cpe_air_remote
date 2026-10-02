import crypto from 'node:crypto';

import mqtt from 'mqtt';

import { config } from '../config.js';
import { pool } from '../db.js';
import {
  AIR_RETAINED_SUFFIXES,
  OCCUPANCY_RETAINED_SUFFIXES,
  retainedTopics,
} from '../utils/mqtt-topics.js';
import { evaluateClassSchedule } from '../utils/class-schedule.js';
import { readActiveTermGate } from './academic-terms.js';
import { normalizeOccupancyStatus } from '../utils/occupancy-sensor.js';
import { hashSecret, safeHashEquals } from '../utils/security.js';
import {
  recordEnergySample,
  recordHistoryBatch,
  runSerialForDevice,
} from './energy-recorder.js';

export { evaluateClassSchedule };

// ผู้ฟังเหตุการณ์ ใช้ให้ระบบปิดแอร์อัตโนมัติรู้ทันทีที่มีข้อมูลใหม่เข้ามา
// ทำแบบนี้เพื่อไม่ให้ services/auto-off.js กับไฟล์นี้ import วนกันเอง
const airStatusListeners = new Set();
const occupancyStatusListeners = new Set();

export function onAirStatus(listener) {
  airStatusListeners.add(listener);
  return () => airStatusListeners.delete(listener);
}

export function onOccupancyStatus(listener) {
  occupancyStatusListeners.add(listener);
  return () => occupancyStatusListeners.delete(listener);
}

function notify(listeners, payload) {
  for (const listener of listeners) {
    try {
      const result = listener(payload);
      if (result && typeof result.catch === 'function') {
        result.catch((error) => {
          console.error('MQTT listener failed', error.message);
        });
      }
    } catch (error) {
      console.error('MQTT listener failed', error.message);
    }
  }
}

// ผู้ฟังตอนต่อ Broker สำเร็จ ใช้ให้ services/mqtt-accounts.js สร้าง/ซ่อม
// บัญชีของ Backend และบอร์ดทุกครั้งที่ต่อติด (รวมตอนต่อใหม่หลังหลุด)
const connectedListeners = new Set();

export function onMqttConnected(listener) {
  connectedListeners.add(listener);
  return () => connectedListeners.delete(listener);
}

const DYNSEC_TOPIC = '$CONTROL/dynamic-security/v1';
const DYNSEC_RESPONSE_TOPIC = `${DYNSEC_TOPIC}/response`;
const DYNSEC_TIMEOUT_MS = 8000;
const pendingDynsec = new Map();
let dynsecSequence = 0;

let client;
const bridgeStatus = {
  configured: Boolean(config.mqtt.url),
  connected: false,
  connectedAt: null,
  lastDisconnectedAt: null,
  lastError: null,
};

export function startMqttBridge() {
  if (!config.mqtt.url) {
    console.warn('MQTT bridge disabled: MQTT_URL is empty');
    return;
  }

  client = mqtt.connect(config.mqtt.url, {
    username: config.mqtt.username || undefined,
    password: config.mqtt.password || undefined,
    reconnectPeriod: 3000,
    clean: true,
    clientId: `rmutt-api-${process.pid}`,
  });

  client.on('connect', () => {
    bridgeStatus.connected = true;
    bridgeStatus.connectedAt = new Date().toISOString();
    bridgeStatus.lastError = null;
    client.subscribe([
      `${config.mqtt.topicPrefix}/+/state`,
      `${config.mqtt.topicPrefix}/+/status`,
      `${config.mqtt.topicPrefix}/+/provision`,
      `${config.mqtt.topicPrefix}/+/history`,
      `${config.mqtt.occupancyTopicPrefix}/+/status`,
      `${config.mqtt.occupancyTopicPrefix}/+/provision`,
    ], { qos: 1 });
    if (config.mqtt.deviceAuth === 'dynsec') {
      client.subscribe(DYNSEC_RESPONSE_TOPIC, { qos: 1 });
    }
    console.log('MQTT bridge connected');
    notify(connectedListeners, {});
  });
  client.on('message', (topic, payload) => {
    if (topic === DYNSEC_RESPONSE_TOPIC) {
      handleDynsecResponse(payload);
      return;
    }
    handleIncomingMessage(topic, payload).catch((error) => {
      console.error('MQTT message failed', error);
    });
  });
  client.on('error', (error) => {
    bridgeStatus.lastError = error.message;
    console.error('MQTT bridge error', error.message);
  });
  client.on('offline', markDisconnected);
  client.on('close', markDisconnected);
}

export async function stopMqttBridge() {
  if (!client) return;
  await new Promise((resolve) => client.end(false, {}, resolve));
  client = undefined;
  markDisconnected();
}

/**
 * ส่งคำสั่งไปที่ Mosquitto Dynamic Security แล้วรอคำตอบของทุกคำสั่ง
 * คืน array ของ { command, error } เรียงตามลำดับที่ส่ง
 */
export async function dynsecRequest(commands) {
  if (!client?.connected) {
    const error = new Error('MQTT broker is not connected');
    error.statusCode = 503;
    throw error;
  }
  if (!Array.isArray(commands) || commands.length === 0) return [];

  const batch = `b${Date.now().toString(36)}${(dynsecSequence += 1)}`;
  const tagged = commands.map((command, index) => ({
    ...command,
    correlationData: `${batch}:${index}`,
  }));
  const waiting = new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      pendingDynsec.delete(batch);
      const error = new Error('Mosquitto Dynamic Security did not respond');
      error.statusCode = 503;
      reject(error);
    }, DYNSEC_TIMEOUT_MS);
    pendingDynsec.set(batch, {
      expected: tagged.length,
      results: new Array(tagged.length),
      received: 0,
      resolve: (value) => {
        clearTimeout(timer);
        resolve(value);
      },
    });
  });
  await publish(
    DYNSEC_TOPIC,
    JSON.stringify({ commands: tagged }),
    { qos: 1, retain: false },
  );
  return waiting;
}

function handleDynsecResponse(payload) {
  let message;
  try {
    message = JSON.parse(payload.toString('utf8'));
  } catch {
    return;
  }
  for (const response of message?.responses ?? []) {
    const [batch, indexText] = String(response?.correlationData ?? '').split(':');
    const entry = pendingDynsec.get(batch);
    if (!entry) continue;
    const index = Number(indexText);
    if (!Number.isInteger(index) || entry.results[index]) continue;
    entry.results[index] = {
      command: response.command,
      error: response.error ?? null,
    };
    entry.received += 1;
    if (entry.received >= entry.expected) {
      pendingDynsec.delete(batch);
      entry.resolve(entry.results);
    }
  }
}

export function getMqttBridgeStatus() {
  return {
    ...bridgeStatus,
    deviceAuth: config.mqtt.deviceAuth,
    topicPrefix: config.mqtt.topicPrefix,
    occupancyTopicPrefix: config.mqtt.occupancyTopicPrefix,
    broker: publicBrokerAddress(config.mqtt.url),
  };
}

export async function publishAirCommand(deviceId, state) {
  if (!client?.connected) {
    const error = new Error('MQTT broker is not connected');
    error.statusCode = 503;
    throw error;
  }
  const topic = `${config.mqtt.topicPrefix}/${deviceId}/command`;
  const payload = JSON.stringify({
    version: 1,
    commandId: crypto.randomUUID(),
    sentAt: new Date().toISOString(),
    state,
  });
  await publish(topic, payload, { qos: 1, retain: false });
  return { topic, payload: JSON.parse(payload) };
}

export async function publishEnterSetupMode(deviceId) {
  if (!client?.connected) {
    const error = new Error('MQTT broker is not connected');
    error.statusCode = 503;
    throw error;
  }
  const topic = `${config.mqtt.topicPrefix}/${deviceId}/command`;
  const payload = JSON.stringify({
    version: 1,
    commandId: crypto.randomUUID(),
    sentAt: new Date().toISOString(),
    action: 'enter_setup',
  });
  await publish(topic, payload, { qos: 1, retain: false });
  return { topic, payload: JSON.parse(payload) };
}

/**
 * สั่งให้บอร์ดดาวน์โหลดเฟิร์มแวร์ใหม่ผ่าน HTTPS แล้วรีบูต
 * kind = 'air' | 'occupancy'
 */
export async function publishOtaCommand(kind, deviceId, url) {
  if (!client?.connected) {
    const error = new Error('MQTT broker is not connected');
    error.statusCode = 503;
    throw error;
  }
  const prefix = kind === 'occupancy'
    ? config.mqtt.occupancyTopicPrefix
    : config.mqtt.topicPrefix;
  const topic = `${prefix}/${deviceId}/command`;
  const payload = JSON.stringify({
    version: 1,
    commandId: crypto.randomUUID(),
    sentAt: new Date().toISOString(),
    action: 'ota',
    url,
  });
  await publish(topic, payload, { qos: 1, retain: false });
  return { topic, payload: JSON.parse(payload) };
}

export async function publishEnterOccupancySetupMode(deviceId) {
  if (!client?.connected) {
    const error = new Error('MQTT broker is not connected');
    error.statusCode = 503;
    throw error;
  }
  const topic =
    `${config.mqtt.occupancyTopicPrefix}/${deviceId}/command`;
  const payload = JSON.stringify({
    version: 1,
    commandId: crypto.randomUUID(),
    sentAt: new Date().toISOString(),
    action: 'enter_setup',
  });
  await publish(topic, payload, { qos: 1, retain: false });
  return { topic, payload: JSON.parse(payload) };
}

// ล้างข้อความ retain ทั้งหมดของอุปกรณ์ ใช้ตอนนำอุปกรณ์ออกจากระบบ
// คืนค่าจำนวน topic ที่ล้างสำเร็จ (0 = Broker ยังไม่เชื่อมต่อ จึงยังล้างไม่ได้)
export async function clearRetainedAirTopics(deviceId) {
  return clearRetained(
    retainedTopics(config.mqtt.topicPrefix, deviceId, AIR_RETAINED_SUFFIXES),
  );
}

export async function clearRetainedOccupancyTopics(deviceId) {
  return clearRetained(
    retainedTopics(
      config.mqtt.occupancyTopicPrefix,
      deviceId,
      OCCUPANCY_RETAINED_SUFFIXES,
    ),
  );
}

async function clearRetained(topics) {
  if (!client?.connected) return 0;
  let cleared = 0;
  for (const topic of topics) {
    try {
      await publish(topic, '', { qos: 1, retain: true });
      cleared += 1;
    } catch (error) {
      console.error(`Unable to clear retained topic ${topic}`, error.message);
    }
  }
  return cleared;
}

async function handleIncomingMessage(topic, payloadBuffer) {
  const occupancyMatch = topic.match(
    new RegExp(
      `^${escapeRegExp(config.mqtt.occupancyTopicPrefix)}`
        + '/(OCC32-[0-9A-F]{12})/(status|provision)$',
    ),
  );
  if (occupancyMatch) {
    await handleOccupancyMessage(occupancyMatch, payloadBuffer);
    return;
  }
  const match = topic.match(
    new RegExp(`^${escapeRegExp(config.mqtt.topicPrefix)}/(ESP32-[0-9A-F]{12})/(state|status|provision|history)$`),
  );
  if (!match) return;

  let message;
  try {
    message = JSON.parse(payloadBuffer.toString('utf8'));
  } catch {
    return;
  }

  const [, deviceId, type] = match;
  if (type === 'provision') {
    await activateProvisioning(deviceId, message);
    return;
  }
  if (type === 'state') {
    await pool.query(
      `UPDATE air_conditioners
          SET state_json = ?,
              is_online = 1,
              last_seen_at = CURRENT_TIMESTAMP
        WHERE device_id = ?`,
      [JSON.stringify(message.state ?? message), deviceId],
    );
    return;
  }

  if (type === 'history') {
    await runSerialForDevice(
      deviceId,
      () => handleAirHistory(deviceId, message),
    );
    return;
  }

  await runSerialForDevice(
    deviceId,
    () => handleAirStatus(deviceId, normalizePowerStatus(message)),
  );
}

async function handleAirStatus(deviceId, status) {
  // อ่านค่าเดิมก่อนทับ เพื่อหาผลต่างของเลขมิเตอร์กับเวลาที่แอร์ทำงานจริง
  // แล้วค่อยบันทึกลงถังรายชั่วโมง ถ้าขั้นตอนนี้พังจะไม่ทำให้ค่าล่าสุดหาย
  const previous = await readPreviousAirRow(deviceId);
  // บอร์ดยังส่งข้อมูลช่วงเน็ตหลุดไม่ครบ ห้ามบันทึกค่าสด ไม่งั้นนับซ้ำ
  if (previous && status.historyPending === 0) {
    try {
      await recordEnergySample({
        deviceId,
        roomNumber: previous.room_number,
        deviceName: previous.name,
        previous: {
          energyKwh: previous.energy_kwh,
          acRunning: Boolean(previous.ac_running),
          isOnline: Boolean(previous.is_online),
          lastSeenAt: previous.last_seen_at,
          chainEnergyKwh: previous.energy_chain_kwh,
          chainAt: previous.energy_chain_at,
          chainRunning: previous.energy_chain_running,
        },
        status,
        now: new Date(),
      });
    } catch (error) {
      console.error('บันทึกค่าไฟรายชั่วโมงไม่สำเร็จ', error.message);
    }
  }

  await pool.query(
    `UPDATE air_conditioners
        SET is_online = ?,
            voltage = ?,
            current_amp = ?,
            power_watts = ?,
            energy_kwh = ?,
            frequency_hz = ?,
            power_factor = ?,
            pzem_available = ?,
            ac_running = ?,
            outside_schedule = ?,
            last_seen_at = CURRENT_TIMESTAMP
      WHERE device_id = ?`,
    [
      status.online ? 1 : 0,
      status.voltage,
      status.current,
      status.powerWatts,
      status.energyKwh,
      status.frequencyHz,
      status.powerFactor,
      status.pzemAvailable ? 1 : 0,
      status.acRunning ? 1 : 0,
      status.outsideSchedule ? 1 : 0,
      deviceId,
    ],
  );
  await recordFirmwareStatus('air_conditioners', deviceId, status);
  await recordHistoryPending(deviceId, status);
  if (status.online) await publishScheduleEvaluation(deviceId);
  notify(airStatusListeners, {
    deviceId,
    roomNumber: previous?.room_number ?? null,
    status,
  });
}

// คอลัมน์ energy_chain_* มาในรุ่น 3.15 ถ้ายังไม่ได้ migrate ให้อ่านแบบเดิม
async function readPreviousAirRow(deviceId) {
  try {
    const rows = await pool.query(
      `SELECT room_number, name, energy_kwh, ac_running, is_online,
              last_seen_at, energy_chain_kwh, energy_chain_at,
              energy_chain_running
         FROM air_conditioners
        WHERE device_id = ?
        LIMIT 1`,
      [deviceId],
    );
    return rows[0];
  } catch (error) {
    if (error?.code !== 'ER_BAD_FIELD_ERROR') throw error;
    const rows = await pool.query(
      `SELECT room_number, name, energy_kwh, ac_running, is_online,
              last_seen_at
         FROM air_conditioners
        WHERE device_id = ?
        LIMIT 1`,
      [deviceId],
    );
    return rows[0];
  }
}

async function recordHistoryPending(deviceId, status) {
  if (!status.online) return;
  try {
    await pool.query(
      'UPDATE air_conditioners SET history_pending = ? WHERE device_id = ?',
      [status.historyPending, deviceId],
    );
  } catch (error) {
    if (error?.code !== 'ER_BAD_FIELD_ERROR') throw error;
  }
}

/**
 * ข้อมูลที่บอร์ดเก็บไว้ตอนเน็ตหลุด บันทึกแล้วตอบ history-ack
 * บอร์ดจะลบรายการที่ยืนยันแล้วทิ้ง และส่งชุดถัดไปหลังได้คำตอบเท่านั้น
 * ถ้าบันทึกไม่สำเร็จจะไม่ตอบ บอร์ดจะส่งชุดเดิมซ้ำเองภายหลัง
 */
async function handleAirHistory(deviceId, message) {
  const result = await recordHistoryBatch({
    deviceId,
    records: message?.records,
    now: new Date(),
  });
  if (!client?.connected) return;
  await publish(
    `${config.mqtt.topicPrefix}/${deviceId}/history-ack`,
    JSON.stringify({
      version: 1,
      upTo: result.upTo,
      stored: result.stored,
      skipped: result.skipped,
    }),
    { qos: 1, retain: false },
  );
  if (result.stored > 0 || result.invalid > 0) {
    console.log(
      `[history] ${deviceId}: บันทึก ${result.stored} ข้าม ${result.skipped}`
        + ` ผิดรูปแบบ ${result.invalid} (ถึง ${result.upTo})`,
    );
  }
}

async function handleOccupancyMessage(match, payloadBuffer) {
  let message;
  try {
    message = JSON.parse(payloadBuffer.toString('utf8'));
  } catch {
    return;
  }

  const [, deviceId, type] = match;
  if (type === 'provision') {
    await activateOccupancyProvisioning(deviceId, message);
    return;
  }

  const status = {
    ...normalizeOccupancyStatus(message),
    ...firmwareFields(message),
  };
  await pool.query(
    `UPDATE occupancy_sensors
        SET is_online = ?,
            radar_available = ?,
            is_occupied = ?,
            last_seen_at = CURRENT_TIMESTAMP
      WHERE device_id = ?`,
    [
      status.online ? 1 : 0,
      status.radarAvailable ? 1 : 0,
      status.occupied ? 1 : 0,
      deviceId,
    ],
  );

  await recordFirmwareStatus('occupancy_sensors', deviceId, status);

  // บอกห้องไปด้วย ระบบปิดแอร์อัตโนมัติจะได้ประเมินเฉพาะแอร์ในห้องนั้น
  const roomRows = await pool.query(
    'SELECT room_number FROM occupancy_sensors WHERE device_id = ? LIMIT 1',
    [deviceId],
  );
  notify(occupancyStatusListeners, {
    deviceId,
    roomNumber: roomRows[0]?.room_number ?? null,
    status,
  });
}

/**
 * บันทึกรุ่นเฟิร์มแวร์และผล OTA ล่าสุด แยกคำสั่งออกมาเพื่อไม่ให้สถานะหลัก
 * บันทึกไม่ได้ ในช่วงสั้น ๆ ที่ Backend ใหม่ขึ้นแล้วแต่ยังไม่ได้ migrate ฐานข้อมูล
 * ข้อความ offline (Last Will) ไม่มีรุ่นเฟิร์มแวร์ จึงไม่ทับค่าเดิม
 */
async function recordFirmwareStatus(table, deviceId, status) {
  if (!status.firmwareVersion) return;
  try {
    await pool.query(
      `UPDATE ${table}
          SET firmware_version = ?,
              ota_error = ?
        WHERE device_id = ?`,
      [status.firmwareVersion, status.otaError, deviceId],
    );
  } catch (error) {
    if (error?.code !== 'ER_BAD_FIELD_ERROR') throw error;
  }
}

export function firmwareFields(source) {
  const version = typeof source?.firmwareVersion === 'string'
    ? source.firmwareVersion.trim().slice(0, 20)
    : '';
  const otaError = typeof source?.otaError === 'string'
    ? source.otaError.trim().slice(0, 120)
    : '';
  return {
    firmwareVersion: version || null,
    otaError: otaError || null,
  };
}

export function normalizePowerStatus(message) {
  const source = message && typeof message === 'object' ? message : {};
  const pzemAvailable = source.pzemAvailable === true;
  const acRunning = pzemAvailable && source.acRunning === true;
  return {
    online: source.online !== false,
    pzemAvailable,
    acRunning,
    outsideSchedule: acRunning && source.outsideSchedule === true,
    voltage: pzemAvailable ? numberOrNull(source.voltage) : null,
    current: pzemAvailable ? numberOrNull(source.current) : null,
    powerWatts: pzemAvailable ? numberOrNull(source.powerWatts) : null,
    energyKwh: pzemAvailable ? numberOrNull(source.energyKwh) : null,
    frequencyHz: pzemAvailable ? numberOrNull(source.frequencyHz) : null,
    powerFactor: pzemAvailable ? numberOrNull(source.powerFactor) : null,
    ...firmwareFields(source),
    // จำนวนรายการย้อนหลังที่บอร์ดยังส่งไม่ครบ (บอร์ดรุ่นก่อน 2.4.0 ไม่มี = 0)
    historyPending: nonNegativeInteger(source.historyPending),
  };
}

function nonNegativeInteger(value) {
  const number = Number(value);
  return Number.isFinite(number) && number > 0 ? Math.trunc(number) : 0;
}

async function publishScheduleEvaluation(deviceId) {
  if (!client?.connected) return;
  const deviceRows = await pool.query(
    `SELECT room_number
       FROM air_conditioners
      WHERE device_id = ?
        AND provision_status = 'active'
      LIMIT 1`,
    [deviceId],
  );
  if (!deviceRows[0]) return;

  const schedules = await pool.query(
    `SELECT day_of_week, start_time, end_time
       FROM class_schedules
      WHERE room_number = ?
      ORDER BY day_of_week, start_time`,
    [deviceRows[0].room_number],
  );
  const evaluation = evaluateClassSchedule(schedules, new Date(), {
    term: await readActiveTermGate(),
  });
  await publish(
    `${config.mqtt.topicPrefix}/${deviceId}/schedule-status`,
    JSON.stringify({
      version: 1,
      classScheduleConfigured: evaluation.configured,
      withinClassSchedule: evaluation.withinSchedule,
      evaluatedAt: new Date().toISOString(),
      timezone: 'Asia/Bangkok',
    }),
    { qos: 1, retain: true },
  );
}

async function activateProvisioning(deviceId, message) {
  const token = typeof message.token === 'string' ? message.token : '';
  if (!token) return;

  const rows = await pool.query(
    `SELECT provisioning_token_hash
      FROM air_conditioners
      WHERE device_id = ?
        AND provision_status IN ('reserved', 'active')
        AND provisioning_token_hash IS NOT NULL
        AND provisioning_expires_at > CURRENT_TIMESTAMP
      LIMIT 1`,
    [deviceId],
  );
  const row = rows[0];
  if (!row) return;

  const suppliedHash = hashSecret(token, config.otpPepper);
  if (!safeHashEquals(row.provisioning_token_hash, suppliedHash)) return;

  await pool.query(
    `UPDATE air_conditioners
        SET provision_status = 'active',
            is_online = 1,
            last_seen_at = CURRENT_TIMESTAMP
      WHERE device_id = ?`,
    [deviceId],
  );
  await publish(
    `${config.mqtt.topicPrefix}/${deviceId}/provision-ack`,
    JSON.stringify({
      version: 1,
      activated: true,
      deviceId,
      token,
    }),
    { qos: 1, retain: true },
  );
  await pool.query(
    `UPDATE air_conditioners
        SET provisioning_token_hash = NULL,
            provisioning_expires_at = NULL
      WHERE device_id = ?`,
    [deviceId],
  );
  await publish(
    `${config.mqtt.topicPrefix}/${deviceId}/provision`,
    '',
    { qos: 1, retain: true },
  );
}

async function activateOccupancyProvisioning(deviceId, message) {
  const token = typeof message.token === 'string' ? message.token : '';
  if (!token) return;

  const rows = await pool.query(
    `SELECT provisioning_token_hash
       FROM occupancy_sensors
      WHERE device_id = ?
        AND provision_status IN ('reserved', 'active')
        AND provisioning_token_hash IS NOT NULL
        AND provisioning_expires_at > CURRENT_TIMESTAMP
      LIMIT 1`,
    [deviceId],
  );
  const row = rows[0];
  if (!row) return;
  const suppliedHash = hashSecret(token, config.otpPepper);
  if (!safeHashEquals(row.provisioning_token_hash, suppliedHash)) return;

  await pool.query(
    `UPDATE occupancy_sensors
        SET provision_status = 'active',
            is_online = 1,
            last_seen_at = CURRENT_TIMESTAMP
      WHERE device_id = ?`,
    [deviceId],
  );
  await publish(
    `${config.mqtt.occupancyTopicPrefix}/${deviceId}/provision-ack`,
    JSON.stringify({
      version: 1,
      activated: true,
      deviceId,
      token,
    }),
    { qos: 1, retain: true },
  );
  await pool.query(
    `UPDATE occupancy_sensors
        SET provisioning_token_hash = NULL,
            provisioning_expires_at = NULL
      WHERE device_id = ?`,
    [deviceId],
  );
  await publish(
    `${config.mqtt.occupancyTopicPrefix}/${deviceId}/provision`,
    '',
    { qos: 1, retain: true },
  );
}

function publish(topic, payload, options) {
  return new Promise((resolve, reject) => {
    client.publish(topic, payload, options, (error) => {
      if (error) reject(error);
      else resolve();
    });
  });
}

function numberOrNull(value) {
  if (value == null || value === '') return null;
  const result = Number(value);
  return Number.isFinite(result) ? result : null;
}

function escapeRegExp(value) {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

function markDisconnected() {
  if (bridgeStatus.connected) {
    bridgeStatus.lastDisconnectedAt = new Date().toISOString();
  }
  bridgeStatus.connected = false;
}

function publicBrokerAddress(value) {
  if (!value) return null;
  try {
    const url = new URL(value);
    const port = url.port || (url.protocol === 'mqtts:' ? '8883' : '1883');
    return `${url.protocol}//${url.hostname}:${port}`;
  } catch {
    return 'invalid';
  }
}
