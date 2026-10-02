// ตัวช่วยของระบบจัดเก็บข้อมูลไฟฟ้ารายชั่วโมง
//
// ไฟล์นี้ตั้งใจให้เป็นฟังก์ชันบริสุทธิ์ทั้งหมด ไม่แตะฐานข้อมูลและไม่แตะ MQTT
// จึงเขียนเทสต์ได้ตรง ๆ ด้วย `node --test`

export const BANGKOK_TIMEZONE = 'Asia/Bangkok';

// ถ้าอุปกรณ์เงียบไปนานกว่านี้ ถือว่าขาดช่วง ไม่นับเวลาที่หายไปเป็นเวลาทำงาน
export const MAX_SAMPLE_GAP_SECONDS = 300;

// PZEM-004T v3.0 ส่งค่าพื้นฐานทางไฟฟ้ามา 6 ค่า
// แรงดัน กระแส กำลังไฟจริง พลังงานสะสม ความถี่ และตัวประกอบกำลัง
// ค่าที่เหลือในตารางข้างล่างคำนวณต่อจาก 6 ค่านี้
export const METRIC_CATALOG = [
  {
    key: 'consumption',
    labelTh: 'พลังงานที่ใช้',
    labelEn: 'Consumption',
    unit: 'kWh',
    decimals: 3,
    inner: 'consumption_kwh',
    group: 'SUM',
    detailOnly: false,
    default: true,
  },
  {
    key: 'cost',
    labelTh: 'ค่าไฟโดยประมาณ',
    labelEn: 'Estimated cost',
    unit: 'THB',
    decimals: 2,
    inner: 'consumption_kwh',
    group: 'SUM',
    detailOnly: false,
    default: false,
    costFactor: true,
  },
  {
    key: 'powerAvg',
    labelTh: 'กำลังไฟเฉลี่ย',
    labelEn: 'Average power',
    unit: 'W',
    decimals: 1,
    inner: 'CASE WHEN pzem_samples > 0 THEN power_sum / pzem_samples END',
    group: 'SUM',
    detailOnly: false,
    default: false,
  },
  {
    key: 'powerMax',
    labelTh: 'กำลังไฟสูงสุด',
    labelEn: 'Peak power',
    unit: 'W',
    decimals: 1,
    inner: 'power_max',
    group: 'SUM',
    detailOnly: true,
    default: false,
  },
  {
    key: 'powerMin',
    labelTh: 'กำลังไฟต่ำสุด',
    labelEn: 'Lowest power',
    unit: 'W',
    decimals: 1,
    inner: 'power_min',
    group: 'SUM',
    detailOnly: true,
    default: false,
  },
  {
    key: 'voltageAvg',
    labelTh: 'แรงดันเฉลี่ย',
    labelEn: 'Average voltage',
    unit: 'V',
    decimals: 1,
    inner: 'CASE WHEN pzem_samples > 0 THEN voltage_sum / pzem_samples END',
    group: 'AVG',
    detailOnly: false,
    default: false,
  },
  {
    key: 'voltageMin',
    labelTh: 'แรงดันต่ำสุด',
    labelEn: 'Lowest voltage',
    unit: 'V',
    decimals: 1,
    inner: 'voltage_min',
    group: 'MIN',
    detailOnly: true,
    default: false,
  },
  {
    key: 'voltageMax',
    labelTh: 'แรงดันสูงสุด',
    labelEn: 'Highest voltage',
    unit: 'V',
    decimals: 1,
    inner: 'voltage_max',
    group: 'MAX',
    detailOnly: true,
    default: false,
  },
  {
    key: 'currentAvg',
    labelTh: 'กระแสเฉลี่ย',
    labelEn: 'Average current',
    unit: 'A',
    decimals: 3,
    inner: 'CASE WHEN pzem_samples > 0 THEN current_sum / pzem_samples END',
    group: 'SUM',
    detailOnly: false,
    default: false,
  },
  {
    key: 'currentMax',
    labelTh: 'กระแสสูงสุด',
    labelEn: 'Peak current',
    unit: 'A',
    decimals: 3,
    inner: 'current_max',
    group: 'SUM',
    detailOnly: true,
    default: false,
  },
  {
    key: 'powerFactorAvg',
    labelTh: 'ตัวประกอบกำลังเฉลี่ย',
    labelEn: 'Average power factor',
    unit: '',
    decimals: 3,
    inner:
      'CASE WHEN pzem_samples > 0 THEN power_factor_sum / pzem_samples END',
    group: 'AVG',
    detailOnly: true,
    default: false,
  },
  {
    key: 'frequencyAvg',
    labelTh: 'ความถี่เฉลี่ย',
    labelEn: 'Average frequency',
    unit: 'Hz',
    decimals: 2,
    inner: 'CASE WHEN pzem_samples > 0 THEN frequency_sum / pzem_samples END',
    group: 'AVG',
    detailOnly: true,
    default: false,
  },
  {
    key: 'energyMeter',
    labelTh: 'เลขมิเตอร์สะสม',
    labelEn: 'Meter reading',
    unit: 'kWh',
    decimals: 3,
    inner: 'energy_end_kwh',
    group: 'SUM',
    detailOnly: true,
    default: false,
  },
  {
    key: 'runtimeMinutes',
    labelTh: 'เวลาที่แอร์ทำงาน',
    labelEn: 'Compressor runtime',
    unit: 'min',
    decimals: 1,
    inner: 'runtime_seconds / 60',
    group: 'SUM',
    detailOnly: false,
    default: false,
  },
  {
    key: 'onlineMinutes',
    labelTh: 'เวลาที่อุปกรณ์ออนไลน์',
    labelEn: 'Device online time',
    unit: 'min',
    decimals: 1,
    inner: 'online_seconds / 60',
    group: 'SUM',
    detailOnly: true,
    default: false,
  },
  {
    key: 'sampleCount',
    labelTh: 'จำนวนครั้งที่บันทึก',
    labelEn: 'Samples recorded',
    unit: '',
    decimals: 0,
    inner: 'sample_count',
    group: 'SUM',
    detailOnly: true,
    default: false,
  },
];

export const DEFAULT_METRIC_KEYS = METRIC_CATALOG
  .filter((metric) => metric.default)
  .map((metric) => metric.key);

const METRIC_BY_KEY = new Map(
  METRIC_CATALOG.map((metric) => [metric.key, metric]),
);

export const SCOPES = ['building', 'room', 'device'];
export const DETAIL_LEVELS = ['summary', 'high'];

/**
 * แปลงเวลาเป็นชิ้นส่วนตามเวลาไทย ไม่ขึ้นกับ TZ ของเครื่อง
 */
export function bangkokParts(value) {
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  const parts = new Intl.DateTimeFormat('en-CA', {
    timeZone: BANGKOK_TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const pick = (type) => parts.find((item) => item.type === type)?.value ?? '';
  return {
    year: pick('year'),
    month: pick('month'),
    day: pick('day'),
    hour: pick('hour'),
    minute: pick('minute'),
    second: pick('second'),
  };
}

/**
 * ต้นชั่วโมงตามเวลาไทย ในรูปแบบที่ MariaDB รับได้ตรง ๆ
 * 2026-08-21T15:42:10+07:00 -> '2026-08-21 15:00:00'
 */
export function bangkokHourStart(value) {
  const parts = bangkokParts(value);
  if (!parts) return null;
  return `${parts.year}-${parts.month}-${parts.day} ${parts.hour}:00:00`;
}

/**
 * '2026-08-21 15:00:00' -> { date: '2026-08-21', range: '15:00-16:00' }
 */
export function describeBucket(bucketStart) {
  const text = toDateTimeText(bucketStart);
  const match = /^(\d{4}-\d{2}-\d{2})[ T](\d{2})/.exec(text);
  if (!match) return { date: '', hour: 0, range: '' };
  const hour = Number(match[2]);
  const next = (hour + 1) % 24;
  return {
    date: match[1],
    hour,
    range: `${pad2(hour)}:00-${pad2(next)}:00`,
  };
}

export function toDateTimeText(value) {
  if (value instanceof Date) {
    const parts = bangkokParts(value);
    if (!parts) return '';
    return `${parts.year}-${parts.month}-${parts.day} `
      + `${parts.hour}:${parts.minute}:${parts.second}`;
  }
  return String(value ?? '').trim();
}

/**
 * ผลต่างของเลขมิเตอร์สะสม
 *
 * PZEM นับพลังงานสะสมขึ้นเรื่อย ๆ ถ้าค่าลดลงแปลว่าอุปกรณ์รีเซ็ตมิเตอร์
 * หรือเพิ่งบูตใหม่ กรณีนั้นจะไม่เดาย้อนหลัง คืน 0 เพื่อไม่ให้ยอดพุ่ง
 */
export function energyDelta(previousKwh, currentKwh) {
  const previous = toNumber(previousKwh);
  const current = toNumber(currentKwh);
  if (current == null) return 0;
  if (previous == null) return 0;
  const delta = current - previous;
  if (!Number.isFinite(delta) || delta < 0) return 0;
  // ป้องกันค่าเพี้ยนจากสัญญาณรบกวน ไม่มีแอร์เครื่องเดียวกินเกิน 50 kWh ต่อรอบ
  if (delta > 50) return 0;
  return round(delta, 3);
}

/**
 * เวลาที่ผ่านไประหว่างสองครั้งที่ได้ข้อมูล หน่วยวินาที
 * ถ้าเงียบนานเกิน MAX_SAMPLE_GAP_SECONDS ถือว่าขาดช่วง ไม่นับให้
 */
export function elapsedSeconds(previousAt, now, cap = MAX_SAMPLE_GAP_SECONDS) {
  if (!previousAt) return 0;
  const previous = previousAt instanceof Date
    ? previousAt
    : new Date(previousAt);
  const current = now instanceof Date ? now : new Date(now);
  if (Number.isNaN(previous.getTime()) || Number.isNaN(current.getTime())) {
    return 0;
  }
  const seconds = (current.getTime() - previous.getTime()) / 1000;
  if (!Number.isFinite(seconds) || seconds <= 0) return 0;
  return Math.min(Math.round(seconds), cap);
}

/**
 * สร้างชุดค่าที่จะบวกเข้าไปในถังของชั่วโมงนั้น
 */
export function buildSampleDelta({ previous, status, now }) {
  const pzemAvailable = status?.pzemAvailable === true;
  const reading = pzemAvailable ? toNumber(status?.energyKwh) : null;
  const gap = elapsedSeconds(previous?.lastSeenAt, now);
  const wasRunning = previous?.acRunning === true;

  return {
    bucketStart: bangkokHourStart(now),
    sampleCount: 1,
    pzemSamples: pzemAvailable ? 1 : 0,
    runningSamples: status?.acRunning === true ? 1 : 0,
    consumptionKwh: pzemAvailable
      ? energyDelta(previous?.energyKwh, reading)
      : 0,
    energyReading: reading,
    voltage: pzemAvailable ? toNumber(status?.voltage) : null,
    current: pzemAvailable ? toNumber(status?.current) : null,
    power: pzemAvailable ? toNumber(status?.powerWatts) : null,
    powerFactor: pzemAvailable ? toNumber(status?.powerFactor) : null,
    frequency: pzemAvailable ? toNumber(status?.frequencyHz) : null,
    runtimeSeconds: wasRunning ? gap : 0,
    onlineSeconds: previous?.isOnline === true ? gap : 0,
  };
}

/**
 * ข้อมูลย้อนหลังที่บอร์ดเก็บไว้ตอนเน็ตหลุด หนึ่งรายการ = หนึ่งช่วง 5 นาที
 * บอร์ดส่งมาเป็น array ของตัวเลขตามลำดับนี้ (ดู firmware/history_log.h)
 * [ts, energyKwh, vAvg×10, vMin×10, vMax×10, iAvg×1000, iMax×1000,
 *  pAvg×10, pMin×10, pMax×10, pf×100, (Hz-40)×10, runtimeSec, samples, flags]
 */
export const HISTORY_INTERVAL_SECONDS = 300;

export function decodeHistoryRecord(row) {
  if (!Array.isArray(row) || row.length < 15) return null;
  const n = row.map((value) => Number(value));
  if (n.some((value) => !Number.isFinite(value))) return null;
  const ts = Math.trunc(n[0]);
  const samples = Math.max(0, Math.trunc(n[13]));
  if (ts <= 0 || samples === 0) return null;
  const scaled = (value, scale) => (value > 0 ? value / scale : null);
  return {
    ts,
    energyKwh: n[1] >= 0 ? n[1] : null,
    voltageAvg: scaled(n[2], 10),
    voltageMin: scaled(n[3], 10),
    voltageMax: scaled(n[4], 10),
    currentAvg: n[5] >= 0 ? n[5] / 1000 : null,
    currentMax: n[6] >= 0 ? n[6] / 1000 : null,
    powerAvg: n[7] >= 0 ? n[7] / 10 : null,
    powerMin: n[8] >= 0 ? n[8] / 10 : null,
    powerMax: n[9] >= 0 ? n[9] / 10 : null,
    powerFactor: n[10] > 0 ? n[10] / 100 : null,
    frequency: n[11] > 0 ? 40 + n[11] / 10 : null,
    runtimeSeconds: Math.min(
      Math.max(0, Math.trunc(n[12])),
      HISTORY_INTERVAL_SECONDS,
    ),
    samples,
    acRunning: (Math.trunc(n[14]) & 1) === 1,
  };
}

/**
 * ค่าที่จะบวกเข้าถังรายชั่วโมงจากข้อมูลย้อนหลังหนึ่งรายการ
 *
 * previous คือ "จุดต่อ" ล่าสุดที่บันทึกไว้แล้ว (เวลา เลขมิเตอร์ สถานะแอร์)
 * พลังงานคิดจากผลต่างของเลขมิเตอร์เหมือนข้อมูลสด เวลาทำงานใช้ค่าที่บอร์ดนับเอง
 * แต่ไม่ให้เกินช่วงเวลาตั้งแต่จุดต่อ กันนับซ้อนกับข้อมูลสดก่อนเน็ตหลุด
 * ช่วงปลายเปิด: รายการที่ ts = 11:00 เป็นของช่วง 10:55–11:00 จึงลงถัง 10:00
 */
export function buildHistoryDelta({ previous, record }) {
  const sampleAt = new Date(record.ts * 1000);
  const previousAt = toDateOrNull(previous?.at);
  let runtimeSeconds = record.runtimeSeconds;
  if (previousAt) {
    const since = Math.floor((sampleAt.getTime() - previousAt.getTime()) / 1000);
    runtimeSeconds = Math.max(0, Math.min(runtimeSeconds, since));
  }
  const samples = record.samples;
  const runningSamples = Math.round(
    samples * (record.runtimeSeconds / HISTORY_INTERVAL_SECONDS),
  );
  const sum = (value) => (value == null ? 0 : round(value * samples, 3));
  return {
    bucketStart: bangkokHourStart(new Date(sampleAt.getTime() - 1000)),
    sampleAt,
    sampleCount: samples,
    pzemSamples: samples,
    runningSamples: Math.min(samples, runningSamples),
    consumptionKwh: energyDelta(previous?.energyKwh, record.energyKwh),
    energyReading: record.energyKwh,
    voltageSum: sum(record.voltageAvg),
    voltageMin: record.voltageMin,
    voltageMax: record.voltageMax,
    currentSum: sum(record.currentAvg),
    currentMin: null,
    currentMax: record.currentMax,
    powerSum: sum(record.powerAvg),
    powerMin: record.powerMin,
    powerMax: record.powerMax,
    powerFactorSum: sum(record.powerFactor),
    frequencySum: sum(record.frequency),
    runtimeSeconds,
    // ช่วงนี้บอร์ดต่อเซิร์ฟเวอร์ไม่ได้ จึงไม่นับเป็นเวลาออนไลน์
    onlineSeconds: 0,
  };
}

/**
 * แปลงผลของ buildSampleDelta (ข้อมูลสดหนึ่งครั้ง) ให้อยู่ในรูปผลรวม
 * แบบเดียวกับข้อมูลย้อนหลัง ตัวบันทึกจะได้ใช้คำสั่ง SQL ชุดเดียว
 */
export function sampleDeltaToBucket(delta, sampleAt) {
  const one = (value) => (value == null ? 0 : value);
  return {
    ...delta,
    sampleAt,
    voltageSum: one(delta.voltage),
    voltageMin: delta.voltage,
    voltageMax: delta.voltage,
    currentSum: one(delta.current),
    currentMin: delta.current,
    currentMax: delta.current,
    powerSum: one(delta.power),
    powerMin: delta.power,
    powerMax: delta.power,
    powerFactorSum: one(delta.powerFactor),
    frequencySum: one(delta.frequency),
  };
}

function toDateOrNull(value) {
  if (value == null) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

/**
 * ตรวจและปรับค่าที่ผู้ใช้ส่งมาจากหน้าจอ ก่อนเอาไปประกอบ SQL
 */
export function normalizeQuery(input = {}) {
  const scope = SCOPES.includes(input.scope) ? input.scope : 'building';
  const detail = DETAIL_LEVELS.includes(input.detail)
    ? input.detail
    : (scope === 'building' ? 'summary' : 'high');

  const from = normalizeDate(input.from);
  const to = normalizeDate(input.to) ?? from;
  if (!from || !to) {
    throw new RangeError('ต้องระบุวันที่เริ่มต้นในรูปแบบ YYYY-MM-DD');
  }
  if (from > to) {
    throw new RangeError('วันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด');
  }
  if (daysBetween(from, to) > 366) {
    throw new RangeError('เลือกช่วงวันได้สูงสุด 366 วันต่อครั้ง');
  }

  return {
    scope,
    detail,
    from,
    to,
    rooms: normalizeList(input.rooms, 200),
    devices: normalizeList(input.devices, 200),
    metrics: resolveMetrics(input.metrics, detail),
    rate: normalizeRate(input.rate),
  };
}

export function resolveMetrics(value, detail = 'high') {
  const requested = normalizeList(value, METRIC_CATALOG.length);
  const allowed = METRIC_CATALOG.filter(
    (metric) => detail === 'high' || !metric.detailOnly,
  );
  const picked = requested
    .map((key) => allowed.find((metric) => metric.key === key))
    .filter(Boolean);

  if (picked.length === 0) {
    return allowed.filter((metric) => metric.default);
  }
  // ทำให้ลำดับคอลัมน์คงที่ตามลำดับในแคตตาล็อกเสมอ
  const keys = new Set(picked.map((metric) => metric.key));
  return allowed.filter((metric) => keys.has(metric.key));
}

export function metricByKey(key) {
  return METRIC_BY_KEY.get(key) ?? null;
}

/**
 * คอลัมน์ประจำตัวของแต่ละแถว ก่อนถึงคอลัมน์ค่าไฟ
 * ชุดแรกตรงกับไฟล์ตัวอย่างที่ใช้กันอยู่ คือ data / time
 */
export function leadingColumns(scope) {
  const base = [
    { key: 'date', labelTh: 'data', labelEn: 'data' },
    { key: 'time', labelTh: 'time', labelEn: 'time' },
  ];
  if (scope === 'room') {
    return [...base, { key: 'roomNumber', labelTh: 'ห้อง', labelEn: 'Room' }];
  }
  if (scope === 'device') {
    return [
      ...base,
      { key: 'roomNumber', labelTh: 'ห้อง', labelEn: 'Room' },
      { key: 'deviceName', labelTh: 'เครื่องปรับอากาศ', labelEn: 'Air unit' },
      { key: 'deviceId', labelTh: 'Device ID', labelEn: 'Device ID' },
    ];
  }
  return base;
}

/**
 * ประกอบหัวตารางและเนื้อตารางสำหรับไฟล์ Excel
 */
export function buildExportSheet({ scope, metrics, rows, language = 'th' }) {
  const leading = leadingColumns(scope);
  const label = (item) => (language === 'en'
    ? item.labelEn ?? item.labelTh
    : item.labelTh ?? item.labelEn);

  const header = [
    ...leading.map((column) => label(column)),
    ...metrics.map((metric) => (metric.unit
      ? `${label(metric)}/${metric.unit}`
      : label(metric))),
  ];

  const body = rows.map((row) => [
    ...leading.map((column) => row[column.key] ?? ''),
    ...metrics.map((metric) => {
      const value = row.values?.[metric.key];
      return value == null ? '' : round(value, metric.decimals);
    }),
  ]);

  return { header, body };
}

export function summarizeRows(rows, metrics) {
  const totals = {};
  for (const metric of metrics) {
    if (metric.group !== 'SUM') continue;
    let total = 0;
    let seen = false;
    for (const row of rows) {
      const value = row.values?.[metric.key];
      if (value == null) continue;
      total += Number(value);
      seen = true;
    }
    if (seen) totals[metric.key] = round(total, metric.decimals);
  }
  return totals;
}

const GROUP_COLUMNS = {
  building: ['bucket_start'],
  room: ['bucket_start', 'room_number'],
  device: ['bucket_start', 'room_number', 'device_id', 'device_name'],
};

/**
 * ประกอบคำสั่ง SQL ของรายงาน แยกออกมาเป็นฟังก์ชันบริสุทธิ์เพื่อให้เทสต์ได้
 *
 * ทำงานสองชั้น ชั้นในสรุปต่ออุปกรณ์ต่อชั่วโมงก่อน ชั้นนอกจึงรวมตามระดับ
 * ที่ผู้ใช้เลือก ถ้ารวมทีเดียวค่าเฉลี่ยของหลายเครื่องจะเพี้ยน
 *
 * ชื่อคอลัมน์ทุกตัวมาจากแคตตาล็อกในไฟล์นี้ ไม่ได้มาจากผู้ใช้
 * ส่วนค่าที่ผู้ใช้กรอกถูกส่งเป็นพารามิเตอร์ทั้งหมด
 */
export function buildHistorySql(query) {
  const filters = ['h.bucket_start >= ?', 'h.bucket_start < ?'];
  const params = [`${query.from} 00:00:00`, `${nextDay(query.to)} 00:00:00`];

  if (query.rooms.length > 0) {
    filters.push(`h.room_number IN (${placeholders(query.rooms.length)})`);
    params.push(...query.rooms);
  }
  if (query.devices.length > 0) {
    filters.push(`h.device_id IN (${placeholders(query.devices.length)})`);
    params.push(...query.devices);
  }

  const groupColumns = GROUP_COLUMNS[query.scope] ?? GROUP_COLUMNS.building;
  const groupList = groupColumns.map((column) => `t.${column}`).join(', ');

  // ส่งเวลาออกมาเป็นข้อความตรง ๆ จากฐานข้อมูล ไม่ให้ไดรเวอร์แปลงเป็น Date
  // มิฉะนั้นถ้า Node กับ MariaDB ตั้ง TZ ไม่ตรงกัน ช่วงชั่วโมงจะเพี้ยน
  const selectList = groupColumns
    .map((column) => (column === 'bucket_start'
      ? "DATE_FORMAT(t.bucket_start, '%Y-%m-%d %H:%i:%s') AS bucket_start"
      : `t.${column}`))
    .join(', ');

  const innerMetrics = query.metrics
    .map((metric) => `${metric.inner} AS ${metric.key}`)
    .join(',\n                ');
  const outerMetrics = query.metrics
    .map((metric) => `${metric.group}(t.${metric.key}) AS ${metric.key}`)
    .join(',\n           ');

  const sql = `SELECT ${selectList},
           ${outerMetrics}
      FROM (
        SELECT h.bucket_start,
                h.room_number,
                h.device_id,
                h.device_name,
                ${innerMetrics}
          FROM energy_hourly h
         WHERE ${filters.join('\n           AND ')}
      ) AS t
     GROUP BY ${groupList}
     ORDER BY ${groupList}
     LIMIT 20000`;

  return { sql, params };
}

export function nextDay(date) {
  const time = Date.parse(`${date}T00:00:00Z`) + 86400000;
  if (Number.isNaN(time)) return date;
  return new Date(time).toISOString().slice(0, 10);
}

function placeholders(count) {
  return new Array(count).fill('?').join(', ');
}

export const SUMMARY_PERIODS = ['day', 'week', 'month', 'custom'];

/**
 * แปลงตัวเลือกช่วงเวลาจากหน้าจอเป็นวันเริ่ม–วันจบจริง
 *
 * `day` = วันนี้, `week` = 7 วันล่าสุดรวมวันนี้, `month` = 30 วันล่าสุด
 * `custom` = ช่วงที่ผู้ใช้เลือกเอง
 *
 * คืนช่วงก่อนหน้าที่ยาวเท่ากันมาด้วย ใช้คำนวณว่าเพิ่มขึ้นหรือลดลงกี่เปอร์เซ็นต์
 */
export function resolvePeriod({ period, from, to, today } = {}) {
  const anchor = normalizeDate(today) ?? bangkokToday();
  const kind = SUMMARY_PERIODS.includes(period) ? period : 'week';

  let start;
  let end;
  if (kind === 'custom') {
    start = normalizeDate(from);
    end = normalizeDate(to) ?? start;
    if (!start || !end) {
      throw new RangeError('ต้องระบุวันที่เริ่มต้นในรูปแบบ YYYY-MM-DD');
    }
    if (start > end) {
      throw new RangeError('วันที่เริ่มต้นต้องไม่เกินวันที่สิ้นสุด');
    }
    if (daysBetween(start, end) > 366) {
      throw new RangeError('เลือกช่วงวันได้สูงสุด 366 วันต่อครั้ง');
    }
  } else {
    const span = kind === 'day' ? 1 : (kind === 'week' ? 7 : 30);
    end = normalizeDate(from) ?? anchor;
    start = shiftDate(end, -(span - 1));
  }

  const length = daysBetween(start, end) + 1;
  return {
    period: kind,
    from: start,
    to: end,
    days: length,
    // ช่วงเดียววันเดียวดูเป็นรายชั่วโมง ยาวกว่านั้นดูเป็นรายวัน
    granularity: length === 1 ? 'hour' : 'day',
    previousFrom: shiftDate(start, -length),
    previousTo: shiftDate(start, -1),
  };
}

/**
 * เติมช่องที่ไม่มีข้อมูลให้เป็นศูนย์ กราฟจะได้ไม่ขาดเป็นช่วง ๆ
 *
 * @param {{granularity:string,from:string,to:string}} resolved
 * @param {Map<string, number>} totals คีย์คือ 'YYYY-MM-DD' หรือ 'YYYY-MM-DD HH'
 */
export function fillSeries(resolved, totals) {
  const points = [];
  if (resolved.granularity === 'hour') {
    for (let hour = 0; hour < 24; hour += 1) {
      const key = `${resolved.from} ${pad2(hour)}`;
      points.push({
        key,
        date: resolved.from,
        hour,
        label: `${pad2(hour)}:00`,
        kwh: round(totals.get(key) ?? 0, 3),
      });
    }
    return points;
  }

  let cursor = resolved.from;
  while (cursor <= resolved.to) {
    points.push({
      key: cursor,
      date: cursor,
      hour: null,
      label: cursor.slice(5),
      kwh: round(totals.get(cursor) ?? 0, 3),
    });
    cursor = shiftDate(cursor, 1);
  }
  return points;
}

/**
 * เปลี่ยนแปลงกี่เปอร์เซ็นต์เทียบกับช่วงก่อนหน้า
 * คืน null เมื่อช่วงก่อนหน้าไม่มีข้อมูลเลย เพราะเทียบไม่ได้
 */
export function changePercent(current, previous) {
  if (current == null || previous == null) return null;
  const now = Number(current);
  const before = Number(previous);
  if (!Number.isFinite(now) || !Number.isFinite(before) || before <= 0) {
    return null;
  }
  return round(((now - before) / before) * 100, 1);
}

export function bangkokToday(now = new Date()) {
  const parts = bangkokParts(now);
  if (!parts) return null;
  return `${parts.year}-${parts.month}-${parts.day}`;
}

export function shiftDate(date, days) {
  const time = Date.parse(`${date}T00:00:00Z`) + days * 86400000;
  if (Number.isNaN(time)) return date;
  return new Date(time).toISOString().slice(0, 10);
}

export function round(value, decimals = 3) {
  const number = Number(value);
  if (!Number.isFinite(number)) return null;
  const factor = 10 ** decimals;
  return Math.round((number + Number.EPSILON) * factor) / factor;
}

function normalizeDate(value) {
  const text = String(value ?? '').trim();
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(text);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return text;
}

function daysBetween(from, to) {
  const start = Date.parse(`${from}T00:00:00Z`);
  const end = Date.parse(`${to}T00:00:00Z`);
  if (Number.isNaN(start) || Number.isNaN(end)) return 0;
  return Math.round((end - start) / 86400000);
}

function normalizeList(value, limit) {
  const source = Array.isArray(value)
    ? value
    : String(value ?? '').split(',');
  const seen = new Set();
  for (const item of source) {
    const text = String(item ?? '').trim();
    if (!text) continue;
    if (text.length > 64) continue;
    seen.add(text);
    if (seen.size >= limit) break;
  }
  return [...seen];
}

function normalizeRate(value) {
  const rate = Number(value);
  if (!Number.isFinite(rate) || rate <= 0 || rate > 100) return 0;
  return round(rate, 4);
}

function toNumber(value) {
  if (value == null || value === '') return null;
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

function pad2(value) {
  return String(value).padStart(2, '0');
}
