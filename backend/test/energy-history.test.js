import assert from 'node:assert/strict';
import test from 'node:test';

import {
  bangkokHourStart,
  buildExportSheet,
  buildHistorySql,
  buildSampleDelta,
  changePercent,
  describeBucket,
  fillSeries,
  elapsedSeconds,
  energyDelta,
  leadingColumns,
  nextDay,
  normalizeQuery,
  resolveMetrics,
  resolvePeriod,
  summarizeRows,
} from '../src/utils/energy-history.js';

test('ตัดเวลาเข้าถังรายชั่วโมงตามเวลาไทยเสมอ', () => {
  // 08:42 UTC = 15:42 ตามเวลาไทย จึงตกอยู่ในถัง 15:00
  assert.equal(
    bangkokHourStart(new Date('2026-08-21T08:42:10Z')),
    '2026-08-21 15:00:00',
  );
  // 17:30 UTC = 00:30 ของวันถัดไปตามเวลาไทย ต้องข้ามวันให้ถูก
  assert.equal(
    bangkokHourStart(new Date('2026-08-21T17:30:00Z')),
    '2026-08-22 00:00:00',
  );
  assert.equal(bangkokHourStart('ไม่ใช่เวลา'), null);
});

test('อธิบายถังเป็นวันที่กับช่วงเวลาแบบในไฟล์ตัวอย่าง', () => {
  assert.deepEqual(describeBucket('2026-08-21 15:00:00'), {
    date: '2026-08-21',
    hour: 15,
    range: '15:00-16:00',
  });
  // ชั่วโมงสุดท้ายของวันต้องวนกลับเป็น 00:00 ไม่ใช่ 24:00
  assert.equal(describeBucket('2026-08-21 23:00:00').range, '23:00-00:00');
  assert.equal(describeBucket('').range, '');
});

test('ผลต่างมิเตอร์ไม่ติดลบและไม่พุ่งเมื่ออุปกรณ์รีเซ็ต', () => {
  assert.equal(energyDelta(10.5, 10.8), 0.3);
  assert.equal(energyDelta(10.5, 0.1), 0, 'ค่าลดลง = มิเตอร์รีเซ็ต');
  assert.equal(energyDelta(null, 5), 0, 'ยังไม่มีค่าเดิม จึงยังนับไม่ได้');
  assert.equal(energyDelta(1, 999), 0, 'กระโดดผิดปกติ ถือว่าเป็นค่าเพี้ยน');
});

test('ช่วงที่อุปกรณ์เงียบนานเกินไปจะไม่ถูกนับเป็นเวลาทำงาน', () => {
  const start = new Date('2026-08-21T08:00:00Z');
  assert.equal(elapsedSeconds(start, new Date('2026-08-21T08:00:30Z')), 30);
  assert.equal(
    elapsedSeconds(start, new Date('2026-08-21T09:00:00Z')),
    300,
    'ตัดที่ 5 นาทีตามค่า MAX_SAMPLE_GAP_SECONDS',
  );
  assert.equal(elapsedSeconds(null, new Date()), 0);
});

test('สร้างค่าที่จะบวกเข้าถังจากข้อความ status หนึ่งครั้ง', () => {
  const delta = buildSampleDelta({
    previous: {
      energyKwh: 1,
      acRunning: true,
      isOnline: true,
      lastSeenAt: new Date('2026-08-21T08:41:00Z'),
    },
    status: {
      pzemAvailable: true,
      acRunning: true,
      energyKwh: 1.02,
      voltage: 225,
      current: 3.2,
      powerWatts: 700,
      powerFactor: 0.97,
      frequencyHz: 50,
    },
    now: new Date('2026-08-21T08:42:00Z'),
  });

  assert.equal(delta.bucketStart, '2026-08-21 15:00:00');
  assert.equal(delta.consumptionKwh, 0.02);
  assert.equal(delta.runtimeSeconds, 60);
  assert.equal(delta.onlineSeconds, 60);
  assert.equal(delta.pzemSamples, 1);
});

test('ไม่มี PZEM ก็ยังนับจำนวนครั้ง แต่ไม่บวกค่าไฟ', () => {
  const delta = buildSampleDelta({
    previous: { energyKwh: 5, acRunning: false, isOnline: true },
    status: { pzemAvailable: false, energyKwh: 9 },
    now: new Date('2026-08-21T08:42:00Z'),
  });

  assert.equal(delta.sampleCount, 1);
  assert.equal(delta.pzemSamples, 0);
  assert.equal(delta.consumptionKwh, 0);
  assert.equal(delta.voltage, null);
});

test('ตรวจช่วงวันที่ก่อนสร้างรายงาน', () => {
  const query = normalizeQuery({ from: '2026-08-01', to: '2026-08-03' });
  assert.equal(query.scope, 'building');
  assert.equal(query.detail, 'summary');
  assert.deepEqual(query.metrics.map((item) => item.key), ['consumption']);

  // วันเดียวก็พอ ไม่ต้องส่ง to
  assert.equal(normalizeQuery({ from: '2026-08-01' }).to, '2026-08-01');

  assert.throws(() => normalizeQuery({ from: '01/08/2026' }), RangeError);
  assert.throws(
    () => normalizeQuery({ from: '2026-08-05', to: '2026-08-01' }),
    RangeError,
  );
  assert.throws(
    () => normalizeQuery({ from: '2020-01-01', to: '2026-01-01' }),
    RangeError,
  );
});

test('โหมดสรุปเลือกค่าที่เป็นรายละเอียดสูงไม่ได้', () => {
  const summary = resolveMetrics(['consumption', 'voltageMin'], 'summary');
  assert.deepEqual(summary.map((item) => item.key), ['consumption']);

  const high = resolveMetrics(['voltageMin', 'consumption'], 'high');
  assert.deepEqual(
    high.map((item) => item.key),
    ['consumption', 'voltageMin'],
    'ลำดับคอลัมน์ยึดตามแคตตาล็อกเสมอ ไม่ใช่ลำดับที่ผู้ใช้ติ๊ก',
  );

  assert.deepEqual(
    resolveMetrics([], 'high').map((item) => item.key),
    ['consumption'],
    'ไม่ติ๊กอะไรเลยก็ยังได้พลังงานที่ใช้ติดมาด้วย',
  );
});

test('เลือกห้องและเครื่องแอร์แล้ว SQL ต้องผูกค่าเป็นพารามิเตอร์', () => {
  const query = normalizeQuery({
    scope: 'device',
    from: '2026-08-01',
    to: '2026-08-02',
    rooms: '16302,16304',
    devices: 'ESP32-AABBCCDDEEFF',
    metrics: 'consumption,powerAvg',
  });
  const { sql, params } = buildHistorySql(query);

  assert.match(sql, /GROUP BY t\.bucket_start, t\.room_number, t\.device_id/);
  assert.match(sql, /h\.room_number IN \(\?, \?\)/);
  assert.match(sql, /h\.device_id IN \(\?\)/);
  assert.equal(sql.includes('16302'), false, 'ห้ามฝังค่าลงใน SQL ตรง ๆ');
  assert.deepEqual(params, [
    '2026-08-01 00:00:00',
    '2026-08-03 00:00:00',
    '16302',
    '16304',
    'ESP32-AABBCCDDEEFF',
  ]);
});

test('ระดับการรวมข้อมูลเปลี่ยนคอลัมน์ประจำตัวของแถว', () => {
  assert.deepEqual(
    leadingColumns('building').map((item) => item.key),
    ['date', 'time'],
  );
  assert.deepEqual(
    leadingColumns('room').map((item) => item.key),
    ['date', 'time', 'roomNumber'],
  );
  assert.deepEqual(
    leadingColumns('device').map((item) => item.key),
    ['date', 'time', 'roomNumber', 'deviceName', 'deviceId'],
  );
});

test('หัวตารางของไฟล์ Excel ตรงกับไฟล์ตัวอย่าง', () => {
  const query = normalizeQuery({
    from: '2026-08-21',
    metrics: 'consumption',
  });
  const sheet = buildExportSheet({
    scope: 'building',
    metrics: query.metrics,
    rows: [
      {
        date: '2026-08-21',
        time: '15:00-16:00',
        values: { consumption: 1.2344 },
      },
    ],
  });

  assert.deepEqual(sheet.header, ['data', 'time', 'พลังงานที่ใช้/kWh']);
  assert.deepEqual(sheet.body, [['2026-08-21', '15:00-16:00', 1.234]]);
});

test('รวมยอดเฉพาะค่าที่บวกกันได้', () => {
  const query = normalizeQuery({
    from: '2026-08-21',
    detail: 'high',
    metrics: 'consumption,voltageAvg',
  });
  const totals = summarizeRows(
    [
      { values: { consumption: 1.5, voltageAvg: 220 } },
      { values: { consumption: 2.25, voltageAvg: 224 } },
    ],
    query.metrics,
  );

  assert.equal(totals.consumption, 3.75);
  assert.equal(
    'voltageAvg' in totals,
    false,
    'แรงดันเฉลี่ยเอามาบวกกันไม่ได้',
  );
});

test('ขอบเขตวันสุดท้ายครอบคลุมทั้งวัน', () => {
  assert.equal(nextDay('2026-08-31'), '2026-09-01');
  assert.equal(nextDay('2026-12-31'), '2027-01-01');
});

test('ช่วงเวลาของหน้าสรุปคิดจากวันนี้ย้อนหลัง', () => {
  const week = resolvePeriod({ period: 'week', today: '2026-08-21' });
  assert.equal(week.from, '2026-08-15');
  assert.equal(week.to, '2026-08-21');
  assert.equal(week.granularity, 'day');
  assert.equal(week.previousFrom, '2026-08-08');
  assert.equal(week.previousTo, '2026-08-14');

  const day = resolvePeriod({ period: 'day', today: '2026-08-21' });
  assert.equal(day.from, '2026-08-21');
  assert.equal(day.granularity, 'hour', 'วันเดียวดูเป็นรายชั่วโมง');

  const month = resolvePeriod({ period: 'month', today: '2026-08-21' });
  assert.equal(month.from, '2026-07-23');
  assert.equal(month.days, 30);
});

test('ช่วงกำหนดเองเทียบกับช่วงก่อนหน้าที่ยาวเท่ากัน', () => {
  const custom = resolvePeriod({
    period: 'custom',
    from: '2026-08-01',
    to: '2026-08-05',
  });
  assert.equal(custom.days, 5);
  assert.equal(custom.previousFrom, '2026-07-27');
  assert.equal(custom.previousTo, '2026-07-31');

  assert.throws(
    () => resolvePeriod({ period: 'custom', from: 'ไม่ใช่วันที่' }),
    RangeError,
  );
  assert.throws(
    () => resolvePeriod({
      period: 'custom',
      from: '2026-08-10',
      to: '2026-08-01',
    }),
    RangeError,
  );
});

test('กราฟถูกเติมช่องว่างเป็นศูนย์ จะได้ไม่ขาดเป็นช่วง', () => {
  const week = resolvePeriod({ period: 'week', today: '2026-08-21' });
  const points = fillSeries(week, new Map([['2026-08-19', 12.5]]));

  assert.equal(points.length, 7);
  assert.deepEqual(
    points.map((point) => point.kwh),
    [0, 0, 0, 0, 12.5, 0, 0],
  );

  const day = resolvePeriod({ period: 'day', today: '2026-08-21' });
  const hours = fillSeries(day, new Map([['2026-08-21 15', 1.25]]));
  assert.equal(hours.length, 24);
  assert.equal(hours[15].kwh, 1.25);
  assert.equal(hours[15].label, '15:00');
});

test('เปอร์เซ็นต์เทียบช่วงก่อนหน้า และกรณีที่เทียบไม่ได้', () => {
  assert.equal(changePercent(95, 100), -5);
  assert.equal(changePercent(120, 100), 20);
  assert.equal(changePercent(5, 0), null, 'ช่วงก่อนหน้าไม่มีข้อมูล');
  assert.equal(changePercent(null, 100), null);
});
