import { pool } from '../db.js';
import {
  AUTO_OFF_MAX_ATTEMPTS,
  decideAutoOff,
} from '../utils/auto-off.js';
import { bangkokDate, evaluateClassSchedule } from '../utils/class-schedule.js';
import { readActiveTermGate } from './academic-terms.js';
import { readTodayBookings } from './room-bookings.js';
import { withBookings } from '../utils/room-booking.js';
import { ALERT_KINDS, raiseAlert, resolveOpenAlerts } from './alerts.js';
import { onAirStatus, onOccupancyStatus, publishAirCommand } from './mqtt.js';
import { isAutoOffEnabled } from './system-settings.js';

// ระบบปิดแอร์อัตโนมัติเมื่อห้องว่าง
//
// ทำงานที่ Backend ไม่ใช่ที่บอร์ด เพราะเซ็นเซอร์ตรวจคน (OCC32) กับบอร์ดแอร์
// (ESP32) เป็นคนละตัวและคุยกันเองไม่ได้ Backend เป็นที่เดียวที่เห็นทั้งสองฝั่ง
//
// ลำดับการทำงาน
// 1. แอร์กินไฟอยู่ + ห้องว่าง        -> เริ่มนับถอยหลัง (5 นาที, 15 นาทีถ้ามีคาบเรียน)
// 2. ครบเวลาแล้วยังว่าง             -> ยิงคำสั่งปิดผ่าน MQTT ให้บอร์ดส่ง IR
// 3. ยังกินไฟอยู่                    -> ยิงซ้ำทุก 20 วินาที สูงสุด 5 ครั้ง
// 4. กำลังไฟตกลงจนถือว่าแอร์หยุด    -> แจ้งเตือนว่าปิดสำเร็จ แล้วล้างนาฬิกา
// 5. มีคนเข้ามาระหว่างนับ            -> ยกเลิกทันที

const TICK_INTERVAL_MS = 10_000;

let timer;
let unsubscribeAir;
let unsubscribeOccupancy;
let running = false;

export function startAutoOffService() {
  if (timer) return;
  unsubscribeAir = onAirStatus(({ deviceId }) => runEvaluation(deviceId));
  unsubscribeOccupancy = onOccupancyStatus(({ roomNumber }) => {
    if (roomNumber) runEvaluation(null, roomNumber);
  });
  // จับเวลาเองด้วย เพราะถ้าอุปกรณ์เงียบไปเฉย ๆ ก็ยังต้องยิงเมื่อครบกำหนด
  timer = setInterval(() => runEvaluation(), TICK_INTERVAL_MS);
  if (typeof timer.unref === 'function') timer.unref();
  console.log('Auto-off service started');
}

export function stopAutoOffService() {
  if (timer) clearInterval(timer);
  timer = undefined;
  unsubscribeAir?.();
  unsubscribeOccupancy?.();
  unsubscribeAir = undefined;
  unsubscribeOccupancy = undefined;
}

function runEvaluation(deviceId, roomNumber) {
  evaluateAutoOff({ deviceId, roomNumber }).catch((error) => {
    console.error('ประเมินการปิดแอร์อัตโนมัติไม่สำเร็จ', error.message);
  });
}

/**
 * ประเมินแอร์ทุกเครื่อง หรือเฉพาะเครื่อง/ห้องที่ระบุ
 * กันไม่ให้ทำงานซ้อนกัน เพราะรอบหนึ่งอาจยิงคำสั่งหลายเครื่อง
 */
export async function evaluateAutoOff({
  deviceId = null,
  roomNumber = null,
  now = new Date(),
} = {}) {
  if (running) return [];
  running = true;
  let lockConnection = null;
  try {
    // กันกรณีมี Backend รันพร้อมกันเกินหนึ่งตัว (เช่นเผลอ scale หรือรันทดสอบ
    // บนเครื่องเดียวกับของจริง) ถ้าไม่กัน ทั้งสองตัวจะยิงคำสั่งปิดแอร์ซ้ำกัน
    // และนับจำนวนครั้งเพี้ยน ใช้ named lock ของ MariaDB ซึ่งผูกกับ connection
    lockConnection = await acquireRunnerLock();
    if (!lockConnection) return [];

    // สวิตช์รวมของแอดมิน ปิดแล้วต้องหยุดทั้งอาคารทันที
    // และต้องล้างนาฬิกาที่ค้างอยู่ด้วย ไม่งั้นแอปจะโชว์เวลานับถอยหลัง
    // ที่ไม่มีวันยิงจริง ซึ่งหลอกตาคนใช้
    if (!(await isAutoOffEnabled())) {
      await clearAllCountdowns();
      return [];
    }

    const devices = await readDevices({ deviceId, roomNumber });
    const results = [];
    for (const device of devices) {
      results.push(await evaluateDevice(device, now));
    }
    return results;
  } finally {
    await releaseRunnerLock(lockConnection);
    running = false;
  }
}

const RUNNER_LOCK_NAME = 'rmutt_auto_off_runner';

async function acquireRunnerLock() {
  let connection;
  try {
    connection = await pool.getConnection();
    const rows = await connection.query('SELECT GET_LOCK(?, 0) AS got', [
      RUNNER_LOCK_NAME,
    ]);
    if (Number(rows[0]?.got) === 1) return connection;
    connection.release();
    return null;
  } catch (error) {
    connection?.release();
    throw error;
  }
}

async function releaseRunnerLock(connection) {
  if (!connection) return;
  try {
    await connection.query('SELECT RELEASE_LOCK(?)', [RUNNER_LOCK_NAME]);
  } catch (error) {
    console.error('ปลด lock ของระบบปิดแอร์อัตโนมัติไม่สำเร็จ', error.message);
  } finally {
    connection.release();
  }
}

async function readDevices({ deviceId, roomNumber }) {
  const filters = ["a.provision_status = 'active'"];
  const params = [];
  if (deviceId) {
    filters.push('a.device_id = ?');
    params.push(deviceId);
  }
  if (roomNumber) {
    filters.push('a.room_number = ?');
    params.push(roomNumber);
  }

  return pool.query(
    `SELECT a.device_id, a.room_number, a.name, a.state_json,
            a.ac_running, a.pzem_available, a.power_watts,
            a.auto_off_enabled, a.auto_off_started_at, a.auto_off_deadline_at,
            a.auto_off_attempts, a.auto_off_last_attempt_at,
            a.auto_off_in_class,
            o.device_id AS sensor_device_id,
            o.is_online AS sensor_online,
            o.radar_available AS sensor_radar_available,
            o.is_occupied AS sensor_occupied
       FROM air_conditioners a
       LEFT JOIN occupancy_sensors o
         ON o.room_number = a.room_number
      WHERE ${filters.join('\n        AND ')}`,
    params,
  );
}

async function evaluateDevice(row, now) {
  const device = {
    deviceId: row.device_id,
    roomNumber: row.room_number,
    name: row.name,
    autoOffEnabled: Boolean(row.auto_off_enabled),
    acRunning: Boolean(row.ac_running),
    pzemAvailable: Boolean(row.pzem_available),
    autoOffDeadlineAt: row.auto_off_deadline_at,
    autoOffAttempts: Number(row.auto_off_attempts ?? 0),
    autoOffLastAttemptAt: row.auto_off_last_attempt_at,
  };
  const occupancy = {
    hasSensor: row.sensor_device_id != null,
    online: Boolean(row.sensor_online),
    radarAvailable: Boolean(row.sensor_radar_available),
    occupied: Boolean(row.sensor_occupied),
  };

  const schedule = await readSchedule(row.room_number, now);
  const decision = decideAutoOff({
    device,
    occupancy,
    withinClass: schedule.withinSchedule,
    now,
  });

  await applyNotificationRules({ row, occupancy, schedule });

  switch (decision.action) {
    case 'start':
      await pool.query(
        `UPDATE air_conditioners
            SET auto_off_started_at = CURRENT_TIMESTAMP,
                auto_off_deadline_at = DATE_ADD(CURRENT_TIMESTAMP,
                                                INTERVAL ? SECOND),
                auto_off_attempts = 0,
                auto_off_last_attempt_at = NULL,
                auto_off_in_class = ?
          WHERE device_id = ?`,
        [decision.graceSeconds, decision.withinClass ? 1 : 0, row.device_id],
      );
      break;

    case 'fire':
      await fireOffCommand(row, decision.attempt);
      break;

    case 'succeeded':
      await clearCountdown(row.device_id);
      await raiseAlert({
        kind: ALERT_KINDS.AUTO_OFF_SUCCEEDED,
        roomNumber: row.room_number,
        deviceId: row.device_id,
        deviceName: row.name,
        detail: `attempts=${decision.attempts}`,
      });
      await resolveOpenAlerts({
        kind: ALERT_KINDS.AUTO_OFF_FAILED,
        roomNumber: row.room_number,
        deviceId: row.device_id,
      });
      break;

    case 'giveUp':
      await clearCountdown(row.device_id);
      await raiseAlert({
        kind: ALERT_KINDS.AUTO_OFF_FAILED,
        roomNumber: row.room_number,
        deviceId: row.device_id,
        deviceName: row.name,
        detail: `attempts=${AUTO_OFF_MAX_ATTEMPTS}`,
      });
      break;

    case 'cancel':
      await clearCountdown(row.device_id);
      break;

    default:
      break;
  }

  return { deviceId: row.device_id, ...decision };
}

async function fireOffCommand(row, attempt) {
  const state = { ...parseState(row.state_json), power: false };
  try {
    await publishAirCommand(row.device_id, state);
  } catch (error) {
    // Broker ยังไม่พร้อม ไม่นับเป็นครั้ง จะได้ลองใหม่รอบหน้า
    console.error(
      `สั่งปิดแอร์ ${row.device_id} ไม่สำเร็จ`,
      error.message,
    );
    return;
  }

  await pool.query(
    `UPDATE air_conditioners
        SET auto_off_attempts = ?,
            auto_off_last_attempt_at = CURRENT_TIMESTAMP,
            state_json = ?
      WHERE device_id = ?`,
    [attempt, JSON.stringify(state), row.device_id],
  );
  console.log(
    `ปิดแอร์อัตโนมัติ ${row.device_id} ห้อง ${row.room_number} `
    + `ครั้งที่ ${attempt}/${AUTO_OFF_MAX_ATTEMPTS}`,
  );
}

/**
 * ล้างนาฬิกาที่ค้างอยู่ทุกเครื่อง ใช้ตอนแอดมินปิดสวิตช์รวม
 *
 * เงื่อนไข `IS NOT NULL` ทำให้รอบที่ไม่มีอะไรค้างไม่ต้องเขียนฐานข้อมูลเลย
 * ตัวคุมจังหวะเรียกทุก 10 วินาที ถ้าเขียนทุกรอบจะกวนฐานข้อมูลเปล่า ๆ
 */
function clearAllCountdowns() {
  return pool.query(
    `UPDATE air_conditioners
        SET auto_off_started_at = NULL,
            auto_off_deadline_at = NULL,
            auto_off_attempts = 0,
            auto_off_last_attempt_at = NULL,
            auto_off_in_class = 0
      WHERE auto_off_deadline_at IS NOT NULL`,
  );
}

function clearCountdown(deviceId) {
  return pool.query(
    `UPDATE air_conditioners
        SET auto_off_started_at = NULL,
            auto_off_deadline_at = NULL,
            auto_off_attempts = 0,
            auto_off_last_attempt_at = NULL,
            auto_off_in_class = 0
      WHERE device_id = ?
        AND auto_off_deadline_at IS NOT NULL`,
    [deviceId],
  );
}

/**
 * กติกาแจ้งเตือนข้อ 1: ไม่มีคาบเรียน + แอร์ทำงาน + มีคนอยู่ในห้อง
 * พอเงื่อนไขหมดไปก็ปิดใบเดิมให้เอง ไม่ต้องรอคนมากด
 */
async function applyNotificationRules({ row, occupancy, schedule }) {
  const shouldWarn = Boolean(row.ac_running)
    && occupancy.hasSensor
    && occupancy.online
    && occupancy.radarAvailable
    && occupancy.occupied
    && !schedule.withinSchedule;

  if (shouldWarn) {
    await raiseAlert({
      kind: ALERT_KINDS.OUTSIDE_SCHEDULE_OCCUPIED,
      roomNumber: row.room_number,
      deviceId: row.device_id,
      deviceName: row.name,
      detail: schedule.termStatus === 'before' || schedule.termStatus === 'after'
        ? 'outsideTerm'
        : schedule.configured ? 'noClassNow' : 'noScheduleAtAll',
    });
    return;
  }

  await resolveOpenAlerts({
    kind: ALERT_KINDS.OUTSIDE_SCHEDULE_OCCUPIED,
    roomNumber: row.room_number,
    deviceId: row.device_id,
  });
}

async function readSchedule(roomNumber, now) {
  const rows = await pool.query(
    `SELECT day_of_week, start_time, end_time
       FROM class_schedules
      WHERE room_number = ?`,
    [roomNumber],
  );
  // นอกวันเปิด-ปิดภาคเรียน ทุกห้องถือว่าอยู่นอกคาบ (ดู services/academic-terms.js)
  const term = await readActiveTermGate();
  // การจองห้อง (ประชุม สอบ กิจกรรม) ที่กำลังเกิดขึ้น ถือว่าห้องอยู่ในคาบด้วย
  const bookings = await readTodayBookings(roomNumber, bangkokDate(now));
  return withBookings(evaluateClassSchedule(rows, now, { term }), bookings, now);
}

function parseState(value) {
  const fallback = {
    power: false,
    temperature: 25,
    mode: 'cool',
    fanSpeed: 'auto',
    verticalSwing: 'auto',
    horizontalSwing: false,
    eco: false,
    turbo: false,
    sleep: false,
    quiet: false,
    displayLight: true,
    clean: false,
    timerOnMinutes: null,
    timerOffMinutes: null,
  };
  if (!value) return fallback;
  try {
    return { ...fallback, ...JSON.parse(String(value)) };
  } catch {
    return fallback;
  }
}
