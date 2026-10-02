import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildHistoryDelta,
  decodeHistoryRecord,
} from '../src/utils/energy-history.js';

const TS = Date.parse('2026-09-30T04:00:00Z') / 1000;  // 11:00 เวลาไทย

function row(overrides = {}) {
  const base = {
    ts: TS, kwh: 12.5, vAvg: 2300, vMin: 2280, vMax: 2330,
    iAvg: 3000, iMax: 3200, pAvg: 7000, pMin: 6800, pMax: 7200,
    pf: 95, f: 100, run: 300, n: 150, flags: 1,
  };
  const v = { ...base, ...overrides };
  return [v.ts, v.kwh, v.vAvg, v.vMin, v.vMax, v.iAvg, v.iMax, v.pAvg,
    v.pMin, v.pMax, v.pf, v.f, v.run, v.n, v.flags];
}

test('แปลงข้อมูลย้อนหลังจากบอร์ดกลับเป็นหน่วยจริง', () => {
  const record = decodeHistoryRecord(row());
  assert.equal(record.ts, TS);
  assert.equal(record.voltageAvg, 230);
  assert.equal(record.currentMax, 3.2);
  assert.equal(record.powerAvg, 700);
  assert.equal(record.powerFactor, 0.95);
  assert.equal(record.frequency, 50);
  assert.equal(record.acRunning, true);
});

test('รายการผิดรูปแบบหรือไม่มีตัวอย่างถูกปฏิเสธ', () => {
  assert.equal(decodeHistoryRecord(row({ n: 0 })), null);
  assert.equal(decodeHistoryRecord([1, 2, 3]), null);
  assert.equal(decodeHistoryRecord(row({ ts: 'x' })), null);
  assert.equal(decodeHistoryRecord('nope'), null);
});

test('ช่วง 10:55–11:00 ลงถังชั่วโมง 10:00 ตามเวลาไทย', () => {
  const delta = buildHistoryDelta({
    previous: { at: new Date((TS - 300) * 1000), energyKwh: 12.4 },
    record: decodeHistoryRecord(row()),
  });
  assert.equal(delta.bucketStart, '2026-09-30 10:00:00');
  assert.equal(delta.consumptionKwh, 0.1);
  assert.equal(delta.runtimeSeconds, 300);
  assert.equal(delta.voltageSum, 230 * 150);
  assert.equal(delta.onlineSeconds, 0);
});

test('เวลาทำงานไม่เกินช่วงตั้งแต่จุดต่อ กันนับซ้อนกับข้อมูลสด', () => {
  const delta = buildHistoryDelta({
    previous: { at: new Date((TS - 90) * 1000), energyKwh: 12.45 },
    record: decodeHistoryRecord(row()),
  });
  assert.equal(delta.runtimeSeconds, 90);
  assert.equal(delta.consumptionKwh, 0.05);
});
