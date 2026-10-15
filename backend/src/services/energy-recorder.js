import { pool, withTransaction } from '../db.js';
import {
  buildHistoryDelta,
  buildSampleDelta,
  decodeHistoryRecord,
  sampleDeltaToBucket,
} from '../utils/energy-history.js';

// บันทึกค่าไฟที่ ESP32 + PZEM ส่งเข้ามาลงถังรายชั่วโมง
//
// ข้อมูลมาได้สองทาง
//   1. status สด ทุก ~10 วินาที ตอนบอร์ดต่อเน็ตอยู่
//   2. ข้อมูลย้อนหลัง (history) ที่บอร์ดเก็บไว้ตอนเน็ตหลุด ช่วงละ 5 นาที
//
// ทั้งสองทางใช้ "จุดต่อ" ชุดเดียวกัน (คอลัมน์ energy_chain_* ของ air_conditioners)
// คือเวลา เลขมิเตอร์ และสถานะแอร์ของตัวอย่างล่าสุดที่บันทึกแล้ว พลังงานของตัวอย่าง
// ถัดไปคิดจากผลต่างกับจุดต่อนี้ จึงไม่มีช่วงไหนถูกนับซ้ำหรือหายไป
//
// ระหว่างที่บอร์ดยังส่งข้อมูลย้อนหลังไม่ครบ (historyPending > 0) status สด
// จะไม่ถูกบันทึกลงถัง ไม่งั้นพลังงานช่วงเน็ตหลุดจะไปกองอยู่ที่ชั่วโมงที่ต่อได้

// ข้อมูลย้อนหลังเก่ากว่านี้หรือเวลาอยู่ในอนาคตไม่รับ (นาฬิกาบอร์ดผิด)
const HISTORY_MAX_AGE_SECONDS = 31 * 24 * 3600;
const HISTORY_MAX_FUTURE_SECONDS = 300;
const HISTORY_MAX_RECORDS_PER_BATCH = 50;

// งานของบอร์ดเดียวกันทำทีละงาน กัน status สดกับข้อมูลย้อนหลังแย่งจุดต่อกัน
const deviceQueues = new Map();

export function runSerialForDevice(deviceId, task) {
  const previous = deviceQueues.get(deviceId) ?? Promise.resolve();
  const next = previous.catch(() => {}).then(task);
  const tail = next.catch(() => {});
  deviceQueues.set(deviceId, tail);
  tail.then(() => {
    if (deviceQueues.get(deviceId) === tail) deviceQueues.delete(deviceId);
  });
  return next;
}

/**
 * บันทึก status สดหนึ่งครั้ง
 * previous = ค่าจากแถว air_conditioners ก่อนถูกทับด้วยค่าล่าสุด
 */
export async function recordEnergySample({
  deviceId,
  roomNumber,
  deviceName = '',
  previous,
  status,
  now = new Date(),
}) {
  if (!deviceId || !roomNumber) return null;

  const chain = chainFromRow(previous);
  const delta = buildSampleDelta({
    previous: {
      energyKwh: chain.energyKwh,
      acRunning: chain.acRunning,
      isOnline: previous?.isOnline === true,
      lastSeenAt: chain.at,
    },
    status,
    now,
  });
  if (!delta.bucketStart) return null;

  await upsertBucket(pool, {
    deviceId,
    roomNumber,
    deviceName,
    delta: sampleDeltaToBucket(delta, now),
  });
  await saveChain(pool, deviceId, {
    at: now,
    // ตอน PZEM อ่านไม่ได้ (หรือข้อความ offline) ต้องจำเลขมิเตอร์เดิมไว้
    // ไม่งั้นรอบถัดไปจะหาผลต่างไม่ได้และพลังงานช่วงนั้นหายไป
    energyKwh: status?.pzemAvailable === true && status?.energyKwh != null
      ? status.energyKwh
      : chain.energyKwh,
    acRunning: status?.acRunning === true,
  });
  return delta;
}

/**
 * บันทึกข้อมูลย้อนหลังหนึ่งชุดจากบอร์ด
 *
 * คืน upTo = เวลาของรายการล่าสุดที่ "จัดการแล้ว" (บันทึก หรือข้ามเพราะซ้ำ/ผิด)
 * บอร์ดจะลบทุกรายการที่เวลาไม่เกิน upTo ถ้าบันทึกไม่สำเร็จจะโยน error
 * และไม่ตอบกลับ บอร์ดจะส่งชุดเดิมมาใหม่ภายหลัง
 * รายการที่เคยบันทึกแล้ว (เวลาไม่เกินจุดต่อ) ถูกข้าม ส่งซ้ำกี่ครั้งก็ไม่นับซ้ำ
 */
export async function recordHistoryBatch({
  deviceId,
  records,
  now = new Date(),
}) {
  const rows = Array.isArray(records)
    ? records.slice(0, HISTORY_MAX_RECORDS_PER_BATCH)
    : [];
  const decoded = [];
  let upTo = 0;
  let invalid = 0;
  for (const row of rows) {
    const record = decodeHistoryRecord(row);
    const ts = Number(Array.isArray(row) ? row[0] : 0);
    if (Number.isFinite(ts) && ts > upTo) upTo = Math.trunc(ts);
    if (record) decoded.push(record);
    else invalid += 1;
  }
  decoded.sort((a, b) => a.ts - b.ts);

  const nowSeconds = Math.floor(now.getTime() / 1000);
  return withTransaction(async (connection) => {
    const deviceRows = await connection.query(
      `SELECT room_number, name, energy_kwh, ac_running, last_seen_at,
              energy_chain_kwh, energy_chain_at, energy_chain_running
         FROM air_conditioners
        WHERE device_id = ?
        LIMIT 1
          FOR UPDATE`,
      [deviceId],
    );
    const device = deviceRows[0];
    if (!device) {
      // บอร์ดถูกถอดออกจากระบบแล้ว เก็บไม่ได้ ตอบให้บอร์ดลบทิ้งไป
      return { upTo, stored: 0, skipped: decoded.length, invalid, unknown: true };
    }

    let chain = chainFromRow({
      energyKwh: device.energy_kwh,
      acRunning: Boolean(device.ac_running),
      lastSeenAt: device.last_seen_at,
      chainEnergyKwh: device.energy_chain_kwh,
      chainAt: device.energy_chain_at,
      chainRunning: device.energy_chain_running,
    });
    let stored = 0;
    let skipped = 0;
    for (const record of decoded) {
      const chainSeconds = chain.at
        ? Math.floor(new Date(chain.at).getTime() / 1000)
        : 0;
      const tooOld = record.ts < nowSeconds - HISTORY_MAX_AGE_SECONDS;
      const inFuture = record.ts > nowSeconds + HISTORY_MAX_FUTURE_SECONDS;
      if (tooOld || inFuture || record.ts <= chainSeconds) {
        skipped += 1;
        continue;
      }
      const delta = buildHistoryDelta({ previous: chain, record });
      await upsertBucket(connection, {
        deviceId,
        roomNumber: device.room_number,
        deviceName: device.name,
        delta,
      });
      chain = {
        at: delta.sampleAt,
        energyKwh: record.energyKwh ?? chain.energyKwh,
        acRunning: record.acRunning,
      };
      stored += 1;
    }
    if (stored > 0) await saveChain(connection, deviceId, chain);
    return { upTo, stored, skipped, invalid, unknown: false };
  });
}

function chainFromRow(row) {
  // แถวที่ยังไม่เคยมีจุดต่อ (ก่อนอัปเดตรุ่นนี้) ใช้ค่าล่าสุดของแถวแทน
  if (row?.chainAt) {
    return {
      at: row.chainAt,
      energyKwh: numberOrNull(row.chainEnergyKwh),
      acRunning: Boolean(row.chainRunning),
    };
  }
  return {
    at: row?.lastSeenAt ?? null,
    energyKwh: numberOrNull(row?.energyKwh),
    acRunning: row?.acRunning === true,
  };
}

async function saveChain(database, deviceId, chain) {
  try {
    await database.query(
      `UPDATE air_conditioners
          SET energy_chain_at = ?,
              energy_chain_kwh = ?,
              energy_chain_running = ?
        WHERE device_id = ?`,
      [chain.at, chain.energyKwh, chain.acRunning ? 1 : 0, deviceId],
    );
  } catch (error) {
    // ยังไม่ได้ migrate ฐานข้อมูล ให้ทำงานแบบเดิมต่อไปก่อน
    if (error?.code !== 'ER_BAD_FIELD_ERROR') throw error;
  }
}

// ลำดับใน ON DUPLICATE KEY UPDATE สำคัญ: MariaDB ใช้ค่าที่เพิ่งอัปเดต
// ในคอลัมน์ถัดไป จึงต้องตัดสินเลขมิเตอร์ปลายชั่วโมงก่อนอัปเดต last_sample_at
async function upsertBucket(database, {
  deviceId,
  roomNumber,
  deviceName,
  delta,
}) {
  await database.query(
    `INSERT INTO energy_hourly (
        device_id, bucket_start, room_number, device_name,
        sample_count, pzem_samples, running_samples,
        first_sample_at, last_sample_at,
        energy_start_kwh, energy_end_kwh, consumption_kwh,
        voltage_sum, voltage_min, voltage_max,
        current_sum, current_min, current_max,
        power_sum, power_min, power_max,
        power_factor_sum, frequency_sum,
        runtime_seconds, online_seconds
      ) VALUES (
        ?, ?, ?, ?,
        ?, ?, ?,
        ?, ?,
        ?, ?, ?,
        ?, ?, ?,
        ?, ?, ?,
        ?, ?, ?,
        ?, ?,
        ?, ?
      )
      ON DUPLICATE KEY UPDATE
        room_number = VALUES(room_number),
        device_name = VALUES(device_name),
        sample_count = sample_count + VALUES(sample_count),
        pzem_samples = pzem_samples + VALUES(pzem_samples),
        running_samples = running_samples + VALUES(running_samples),
        energy_start_kwh = IF(
          VALUES(first_sample_at) < first_sample_at
            AND VALUES(energy_start_kwh) IS NOT NULL,
          VALUES(energy_start_kwh),
          COALESCE(energy_start_kwh, VALUES(energy_start_kwh))
        ),
        energy_end_kwh = IF(
          VALUES(last_sample_at) >= last_sample_at
            AND VALUES(energy_end_kwh) IS NOT NULL,
          VALUES(energy_end_kwh),
          COALESCE(energy_end_kwh, VALUES(energy_end_kwh))
        ),
        first_sample_at = LEAST(first_sample_at, VALUES(first_sample_at)),
        last_sample_at = GREATEST(last_sample_at, VALUES(last_sample_at)),
        consumption_kwh = consumption_kwh + VALUES(consumption_kwh),
        voltage_sum = voltage_sum + VALUES(voltage_sum),
        voltage_min = LEAST(
          COALESCE(voltage_min, VALUES(voltage_min)),
          COALESCE(VALUES(voltage_min), voltage_min)
        ),
        voltage_max = GREATEST(
          COALESCE(voltage_max, VALUES(voltage_max)),
          COALESCE(VALUES(voltage_max), voltage_max)
        ),
        current_sum = current_sum + VALUES(current_sum),
        current_min = LEAST(
          COALESCE(current_min, VALUES(current_min)),
          COALESCE(VALUES(current_min), current_min)
        ),
        current_max = GREATEST(
          COALESCE(current_max, VALUES(current_max)),
          COALESCE(VALUES(current_max), current_max)
        ),
        power_sum = power_sum + VALUES(power_sum),
        power_min = LEAST(
          COALESCE(power_min, VALUES(power_min)),
          COALESCE(VALUES(power_min), power_min)
        ),
        power_max = GREATEST(
          COALESCE(power_max, VALUES(power_max)),
          COALESCE(VALUES(power_max), power_max)
        ),
        power_factor_sum = power_factor_sum + VALUES(power_factor_sum),
        frequency_sum = frequency_sum + VALUES(frequency_sum),
        runtime_seconds = runtime_seconds + VALUES(runtime_seconds),
        online_seconds = online_seconds + VALUES(online_seconds)`,
    [
      deviceId,
      delta.bucketStart,
      roomNumber,
      String(deviceName ?? '').slice(0, 50),
      delta.sampleCount,
      delta.pzemSamples,
      delta.runningSamples,
      delta.sampleAt,
      delta.sampleAt,
      delta.energyReading,
      delta.energyReading,
      delta.consumptionKwh,
      delta.voltageSum,
      delta.voltageMin,
      delta.voltageMax,
      delta.currentSum,
      delta.currentMin,
      delta.currentMax,
      delta.powerSum,
      delta.powerMin,
      delta.powerMax,
      delta.powerFactorSum,
      delta.frequencySum,
      delta.runtimeSeconds,
      delta.onlineSeconds,
    ],
  );
}

/**
 * ลบข้อมูลที่เก่ากว่าจำนวนวันที่กำหนด ใช้ตอนอยากคุมขนาดฐานข้อมูล
 * ค่าเริ่มต้นคือเก็บไว้ทั้งหมด ไม่มีอะไรเรียกใช้อัตโนมัติ
 */
export async function purgeEnergyHistoryOlderThan(days) {
  const retention = Number(days);
  if (!Number.isFinite(retention) || retention <= 0) return 0;
  const result = await pool.query(
    `DELETE FROM energy_hourly
      WHERE bucket_start < DATE_SUB(CURRENT_DATE, INTERVAL ? DAY)`,
    [Math.floor(retention)],
  );
  return Number(result?.affectedRows ?? 0);
}

function numberOrNull(value) {
  if (value == null || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}
