import express from 'express';

import { pool } from '../db.js';
import { authenticate } from '../middleware/authenticate.js';
import {
  DEFAULT_METRIC_KEYS,
  METRIC_CATALOG,
  buildHistorySql,
  changePercent,
  describeBucket,
  fillSeries,
  nextDay,
  resolvePeriod,
  leadingColumns,
  buildExportSheet,
  normalizeQuery,
  round,
  summarizeRows,
} from '../utils/energy-history.js';
import { ApiError, asyncHandler } from '../utils/http.js';
import { buildXlsx } from '../utils/xlsx-writer.js';

export const energyRouter = express.Router();

energyRouter.use(authenticate);

// รายชื่อค่าไฟที่เลือกส่งออกได้ หน้าจอใช้ค่านี้สร้างช่องติ๊กเอง
// จึงเพิ่มค่าใหม่ที่ Backend ที่เดียว แล้วแอปเห็นทันทีโดยไม่ต้องอัปเดตแอป
energyRouter.get(
  '/metrics',
  asyncHandler(async (request, response) => {
    response.json({
      metrics: METRIC_CATALOG.map((metric) => ({
        key: metric.key,
        labelTh: metric.labelTh,
        labelEn: metric.labelEn,
        unit: metric.unit,
        decimals: metric.decimals,
        detailOnly: metric.detailOnly === true,
        isDefault: metric.default === true,
      })),
      defaults: DEFAULT_METRIC_KEYS,
    });
  }),
);

// ค่าล่าสุดของทุกเครื่อง ใช้กับหน้าจอที่อัปเดตแบบต่อเนื่อง
energyRouter.get(
  '/live',
  asyncHandler(async (request, response) => {
    const rows = await pool.query(
      `SELECT a.device_id, a.room_number, a.name, a.air_number,
              a.is_online, a.pzem_available, a.ac_running,
              a.voltage, a.current_amp, a.power_watts, a.energy_kwh,
              a.frequency_hz, a.power_factor, a.last_seen_at,
              r.floor_number
         FROM air_conditioners a
         LEFT JOIN rooms r ON r.room_number = a.room_number
        WHERE a.provision_status <> 'removed'
        ORDER BY a.room_number, a.air_number`,
    );

    const readings = rows.map((row) => ({
      deviceId: row.device_id,
      roomNumber: row.room_number,
      floorNumber: Number(row.floor_number ?? 0),
      name: row.name,
      airNumber: Number(row.air_number ?? 0),
      isOnline: Boolean(row.is_online),
      pzemAvailable: Boolean(row.pzem_available),
      acRunning: Boolean(row.ac_running),
      voltage: numberOrNull(row.voltage),
      current: numberOrNull(row.current_amp),
      powerWatts: numberOrNull(row.power_watts),
      energyKwh: numberOrNull(row.energy_kwh),
      frequencyHz: numberOrNull(row.frequency_hz),
      powerFactor: numberOrNull(row.power_factor),
      lastSeenAt: toIso(row.last_seen_at),
    }));

    const running = readings.filter((item) => item.acRunning);
    response.json({
      readings,
      totals: {
        devices: readings.length,
        online: readings.filter((item) => item.isOnline).length,
        running: running.length,
        powerWatts: round(
          running.reduce((sum, item) => sum + (item.powerWatts ?? 0), 0),
          1,
        ),
      },
      serverTime: new Date().toISOString(),
    });
  }),
);

// รายการห้องและเครื่องแอร์ที่มีข้อมูลให้เลือก ใช้กับโหมดรายละเอียดสูง
energyRouter.get(
  '/sources',
  asyncHandler(async (request, response) => {
    const rows = await pool.query(
      `SELECT a.device_id, a.room_number, a.name, a.air_number,
              r.floor_number,
              (SELECT COUNT(*) FROM energy_hourly h
                WHERE h.device_id = a.device_id) AS bucket_count
         FROM air_conditioners a
         LEFT JOIN rooms r ON r.room_number = a.room_number
        WHERE a.provision_status <> 'removed'
        ORDER BY r.floor_number, a.room_number, a.air_number`,
    );

    // เครื่องที่ถูกนำออกไปแล้วแต่ยังมีประวัติค้างอยู่ ต้องเลือกได้เหมือนกัน
    const archived = await pool.query(
      `SELECT h.device_id, h.room_number,
              MAX(h.device_name) AS device_name,
              COUNT(*) AS bucket_count
         FROM energy_hourly h
         LEFT JOIN air_conditioners a ON a.device_id = h.device_id
        WHERE a.device_id IS NULL
        GROUP BY h.device_id, h.room_number
        ORDER BY h.room_number`,
    );

    const devices = [
      ...rows.map((row) => ({
        deviceId: row.device_id,
        roomNumber: row.room_number,
        floorNumber: Number(row.floor_number ?? 0),
        name: row.name,
        airNumber: Number(row.air_number ?? 0),
        bucketCount: Number(row.bucket_count ?? 0),
        archived: false,
      })),
      ...archived.map((row) => ({
        deviceId: row.device_id,
        roomNumber: row.room_number,
        floorNumber: 0,
        name: row.device_name || row.device_id,
        airNumber: 0,
        bucketCount: Number(row.bucket_count ?? 0),
        archived: true,
      })),
    ];

    const roomMap = new Map();
    for (const device of devices) {
      const entry = roomMap.get(device.roomNumber) ?? {
        roomNumber: device.roomNumber,
        floorNumber: device.floorNumber,
        deviceCount: 0,
        bucketCount: 0,
      };
      entry.deviceCount += 1;
      entry.bucketCount += device.bucketCount;
      if (device.floorNumber) entry.floorNumber = device.floorNumber;
      roomMap.set(device.roomNumber, entry);
    }

    const coverage = await pool.query(
      `SELECT DATE_FORMAT(MIN(bucket_start), '%Y-%m-%d') AS oldest,
              DATE_FORMAT(MAX(bucket_start), '%Y-%m-%d') AS newest
         FROM energy_hourly`,
    );

    response.json({
      devices,
      rooms: [...roomMap.values()].sort(
        (a, b) => a.roomNumber.localeCompare(b.roomNumber),
      ),
      coverage: {
        oldest: bucketDate(coverage[0]?.oldest),
        newest: bucketDate(coverage[0]?.newest),
      },
    });
  }),
);

// สรุปสำหรับหน้าหลักและหน้าสถิติ เลือกช่วงได้เป็นวัน สัปดาห์ เดือน หรือกำหนดเอง
energyRouter.get(
  '/summary',
  asyncHandler(async (request, response) => {
    let resolved;
    try {
      resolved = resolvePeriod({
        period: request.query.period,
        from: request.query.from,
        to: request.query.to,
      });
    } catch (error) {
      throw new ApiError(400, error.message);
    }

    const floor = parseFloorFilter(request.query.floor);
    const [current, previous, series, rooms, devices] = await Promise.all([
      readTotals(resolved.from, resolved.to, floor),
      readTotals(resolved.previousFrom, resolved.previousTo, floor),
      readSeries(resolved, floor),
      readRoomBreakdown(resolved.from, resolved.to, floor),
      readDeviceBreakdown(resolved.from, resolved.to, floor),
    ]);

    response.json({
      period: {
        period: resolved.period,
        from: resolved.from,
        to: resolved.to,
        days: resolved.days,
        granularity: resolved.granularity,
        previousFrom: resolved.previousFrom,
        previousTo: resolved.previousTo,
        floor,
      },
      totals: {
        kwh: current.kwh,
        previousKwh: previous.kwh,
        changePercent: changePercent(current.kwh, previous.kwh),
        runtimeMinutes: current.runtimeMinutes,
        peakPowerWatts: current.peakPowerWatts,
        deviceCount: current.deviceCount,
      },
      series,
      rooms,
      devices,
    });
  }),
);

async function readTotals(from, to, floor) {
  const { join, where, params } = floorFilter(floor, from, to);
  const rows = await pool.query(
    `SELECT ROUND(SUM(h.consumption_kwh), 3) AS kwh,
            ROUND(SUM(h.runtime_seconds) / 60, 1) AS runtime_minutes,
            MAX(h.power_max) AS peak_power,
            COUNT(DISTINCT h.device_id) AS device_count
       FROM energy_hourly h${join}
      WHERE ${where}`,
    params,
  );
  const row = rows[0] ?? {};
  return {
    kwh: round(row.kwh ?? 0, 3),
    runtimeMinutes: round(row.runtime_minutes ?? 0, 1),
    peakPowerWatts: round(row.peak_power ?? 0, 1),
    deviceCount: Number(row.device_count ?? 0),
  };
}

async function readSeries(resolved, floor) {
  const { join, where, params } = floorFilter(
    floor,
    resolved.from,
    resolved.to,
  );
  const byHour = resolved.granularity === 'hour';
  const keyExpression = byHour
    ? "DATE_FORMAT(h.bucket_start, '%Y-%m-%d %H')"
    : "DATE_FORMAT(h.bucket_start, '%Y-%m-%d')";

  const rows = await pool.query(
    `SELECT ${keyExpression} AS bucket_key,
            SUM(h.consumption_kwh) AS kwh
       FROM energy_hourly h${join}
      WHERE ${where}
      GROUP BY bucket_key`,
    params,
  );

  return fillSeries(
    resolved,
    new Map(rows.map((row) => [row.bucket_key, Number(row.kwh ?? 0)])),
  );
}

async function readRoomBreakdown(from, to, floor) {
  const { where, params } = floorFilter(floor, from, to, 'r');
  const rows = await pool.query(
    `SELECT h.room_number,
            r.floor_number,
            r.room_type,
            ROUND(SUM(h.consumption_kwh), 3) AS kwh,
            ROUND(SUM(h.runtime_seconds) / 60, 1) AS runtime_minutes,
            COUNT(DISTINCT h.device_id) AS device_count
       FROM energy_hourly h
       LEFT JOIN rooms r ON r.room_number = h.room_number
      WHERE ${where}
      GROUP BY h.room_number, r.floor_number, r.room_type
      ORDER BY kwh DESC`,
    params,
  );
  return rows.map((row) => ({
    roomNumber: row.room_number,
    floorNumber: Number(row.floor_number ?? 0),
    roomType: row.room_type ?? '',
    kwh: round(row.kwh ?? 0, 3),
    runtimeMinutes: round(row.runtime_minutes ?? 0, 1),
    deviceCount: Number(row.device_count ?? 0),
  }));
}

async function readDeviceBreakdown(from, to, floor) {
  const { where, params } = floorFilter(floor, from, to, 'r');
  const rows = await pool.query(
    `SELECT h.device_id,
            h.room_number,
            r.floor_number,
            MAX(h.device_name) AS device_name,
            ROUND(SUM(h.consumption_kwh), 3) AS kwh,
            ROUND(SUM(h.runtime_seconds) / 60, 1) AS runtime_minutes
       FROM energy_hourly h
       LEFT JOIN rooms r ON r.room_number = h.room_number
      WHERE ${where}
      GROUP BY h.device_id, h.room_number, r.floor_number
      ORDER BY kwh DESC
      LIMIT 200`,
    params,
  );
  const names = await pool.query(
    'SELECT device_id, name FROM air_conditioners',
  );
  const nameByDevice = new Map(
    names.map((row) => [row.device_id, row.name]),
  );
  return rows.map((row) => ({
    deviceId: row.device_id,
    roomNumber: row.room_number,
    floorNumber: Number(row.floor_number ?? 0),
    name: nameByDevice.get(row.device_id)
      || row.device_name
      || row.device_id,
    kwh: round(row.kwh ?? 0, 3),
    runtimeMinutes: round(row.runtime_minutes ?? 0, 1),
  }));
}

/**
 * เงื่อนไขช่วงเวลา (+ ชั้น ถ้าเลือก) ใช้ร่วมกันทุกคำสั่งของหน้าสรุป
 * ค่าที่ผู้ใช้กรอกถูกส่งเป็นพารามิเตอร์เสมอ ไม่ต่อสตริงเข้า SQL
 */
function floorFilter(floor, from, to, roomsAlias = null) {
  const params = [`${from} 00:00:00`, `${nextDay(to)} 00:00:00`];
  let join = '';
  let where = 'h.bucket_start >= ? AND h.bucket_start < ?';
  if (floor != null) {
    // ถ้าคำสั่งนั้น JOIN ตาราง rooms ไว้อยู่แล้ว ให้ใช้ตัวเดิม อย่า JOIN ซ้ำ
    const alias = roomsAlias ?? 'rf';
    if (roomsAlias == null) {
      join = `\n       LEFT JOIN rooms ${alias} `
        + `ON ${alias}.room_number = h.room_number`;
    }
    where += ` AND ${alias}.floor_number = ?`;
    params.push(floor);
  }
  return { join, where, params };
}

function parseFloorFilter(value) {
  const text = String(value ?? '').trim();
  if (text === '') return null;
  if (!/^\d{1,2}$/.test(text)) {
    throw new ApiError(400, 'ชั้นต้องเป็นตัวเลข 0–99');
  }
  return Number.parseInt(text, 10);
}

energyRouter.get(
  '/history',
  asyncHandler(async (request, response) => {
    const query = parseQuery(request.query);
    const rows = await runHistoryQuery(query);
    response.json({
      query: describeQuery(query),
      columns: [
        ...leadingColumns(query.scope),
        ...query.metrics.map((metric) => ({
          key: metric.key,
          labelTh: metric.labelTh,
          labelEn: metric.labelEn,
          unit: metric.unit,
          decimals: metric.decimals,
        })),
      ],
      rows,
      totals: summarizeRows(rows, query.metrics),
    });
  }),
);

energyRouter.get(
  '/export',
  asyncHandler(async (request, response) => {
    const query = parseQuery(request.query);
    const language = request.query.language === 'en' ? 'en' : 'th';
    const rows = await runHistoryQuery(query);
    if (rows.length === 0) {
      throw new ApiError(
        404,
        'ไม่พบข้อมูลในช่วงเวลาที่เลือก ลองขยายช่วงวันหรือเลือกอุปกรณ์อื่น',
      );
    }

    const { header, body } = buildExportSheet({
      scope: query.scope,
      metrics: query.metrics,
      rows,
      language,
    });

    const workbook = buildXlsx({
      sheetName: language === 'en' ? 'Energy' : 'ข้อมูลไฟฟ้า',
      header,
      body,
    });

    const fileName = exportFileName(query, language);
    const asciiName = asciiFileName(query);
    response.setHeader(
      'Content-Type',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );
    // หัวข้อ HTTP รับได้เฉพาะอักษรละติน ชื่อไทยจึงส่งผ่าน filename* ที่เข้ารหัส
    response.setHeader(
      'Content-Disposition',
      `attachment; filename="${asciiName}"; `
      + `filename*=UTF-8''${encodeURIComponent(fileName)}`,
    );
    response.setHeader('X-Export-Rows', String(rows.length));
    response.setHeader('X-Export-Filename', encodeURIComponent(fileName));
    response.send(Buffer.from(workbook));
  }),
);

function parseQuery(source) {
  try {
    return normalizeQuery({
      scope: source.scope,
      detail: source.detail,
      from: source.from,
      to: source.to,
      rooms: source.rooms,
      devices: source.devices,
      metrics: source.metrics,
      rate: source.rate,
    });
  } catch (error) {
    throw new ApiError(400, error.message);
  }
}

function describeQuery(query) {
  return {
    scope: query.scope,
    detail: query.detail,
    from: query.from,
    to: query.to,
    rooms: query.rooms,
    devices: query.devices,
    metrics: query.metrics.map((metric) => metric.key),
    rate: query.rate,
  };
}

/**
 * ดึงข้อมูลสองชั้น ชั้นในสรุปต่ออุปกรณ์ต่อชั่วโมงก่อน
 * แล้วชั้นนอกค่อยรวมตามระดับที่ผู้ใช้เลือก
 * ทำแบบนี้เพื่อให้ค่าเฉลี่ยของหลายเครื่องถูกต้อง ไม่ใช่เฉลี่ยรวมมั่ว
 */
async function runHistoryQuery(query) {
  const { sql, params } = buildHistorySql(query);
  const rows = await pool.query(sql, params);
  const nameByDevice = query.scope === 'device'
    ? await readDeviceNames()
    : null;

  return rows.map((row) => {
    const bucket = describeBucket(row.bucket_start);
    const values = {};
    for (const metric of query.metrics) {
      const raw = row[metric.key];
      if (raw == null) {
        values[metric.key] = null;
        continue;
      }
      const scaled = metric.costFactor
        ? Number(raw) * query.rate
        : Number(raw);
      values[metric.key] = round(scaled, metric.decimals);
    }

    const record = {
      date: bucket.date,
      time: bucket.range,
      hour: bucket.hour,
      values,
    };
    if (query.scope !== 'building') record.roomNumber = row.room_number;
    if (query.scope === 'device') {
      record.deviceId = row.device_id;
      record.deviceName = nameByDevice?.get(row.device_id)
        || row.device_name
        || row.device_id;
    }
    return record;
  });
}

async function readDeviceNames() {
  const rows = await pool.query(
    'SELECT device_id, name FROM air_conditioners',
  );
  return new Map(rows.map((row) => [row.device_id, row.name]));
}

function exportFileName(query, language = 'th') {
  const scopeLabel = language === 'en'
    ? { building: 'building16', room: 'by-room', device: 'by-unit' }[query.scope]
    : { building: 'อาคาร16', room: 'รายห้อง', device: 'รายเครื่อง' }[query.scope];
  const range = query.from === query.to
    ? query.from
    : `${query.from}_${query.to}`;
  const prefix = language === 'en' ? 'energy' : 'ข้อมูลไฟฟ้า';
  return `${prefix}_${scopeLabel}_${range}.xlsx`;
}

function asciiFileName(query) {
  const scopeLabel = {
    building: 'building16',
    room: 'by-room',
    device: 'by-unit',
  }[query.scope];
  const range = query.from === query.to
    ? query.from
    : `${query.from}_${query.to}`;
  return `energy_${scopeLabel}_${range}.xlsx`;
}



function bucketDate(value) {
  if (!value) return null;
  const text = String(value).slice(0, 10);
  return /^\d{4}-\d{2}-\d{2}$/.test(text) ? text : null;
}

function numberOrNull(value) {
  if (value == null) return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function toIso(value) {
  if (!value) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}
