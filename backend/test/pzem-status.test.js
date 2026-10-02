import assert from 'node:assert/strict';
import test from 'node:test';

import {
  evaluateClassSchedule,
  normalizePowerStatus,
} from '../src/services/mqtt.js';

test('normalizes PZEM measurements and measured running status', () => {
  assert.deepEqual(
    normalizePowerStatus({
      online: true,
      pzemAvailable: true,
      acRunning: true,
      outsideSchedule: true,
      voltage: 229.8,
      current: 2.145,
      powerWatts: 465.2,
      energyKwh: 12.345,
      frequencyHz: 50.0,
      powerFactor: 0.94,
    }),
    {
      online: true,
      pzemAvailable: true,
      acRunning: true,
      outsideSchedule: true,
      voltage: 229.8,
      current: 2.145,
      powerWatts: 465.2,
      energyKwh: 12.345,
      frequencyHz: 50,
      powerFactor: 0.94,
      firmwareVersion: null,
      otaError: null,
      historyPending: 0,
    },
  );
});

test('reads firmware version and OTA error from status', () => {
  const status = normalizePowerStatus({
    online: true,
    firmwareVersion: '2.3.0',
    otaError: 'failed(-1): connection refused',
  });
  assert.equal(status.firmwareVersion, '2.3.0');
  assert.equal(status.otaError, 'failed(-1): connection refused');
  // Last Will ไม่มีรุ่นเฟิร์มแวร์ ต้องได้ null เพื่อไม่ไปทับค่าเดิม
  assert.equal(normalizePowerStatus({ online: false }).firmwareVersion, null);
});

test('evaluates room class schedules using Asia/Bangkok time', () => {
  const schedules = [
    { day_of_week: 1, start_time: '08:00:00', end_time: '10:00:00' },
  ];
  // Monday 01:30 UTC is Monday 08:30 in Bangkok.
  const inside = evaluateClassSchedule(
    schedules,
    new Date('2026-08-17T01:30:00.000Z'),
  );
  const outside = evaluateClassSchedule(
    schedules,
    new Date('2026-08-17T04:00:00.000Z'),
  );
  assert.equal(inside.configured, true);
  assert.equal(inside.withinSchedule, true);
  assert.equal(outside.withinSchedule, false);
});

test('does not report running data when PZEM is unavailable', () => {
  const status = normalizePowerStatus({
    pzemAvailable: false,
    acRunning: true,
    outsideSchedule: true,
    powerWatts: 500,
  });
  assert.equal(status.pzemAvailable, false);
  assert.equal(status.acRunning, false);
  assert.equal(status.outsideSchedule, false);
  assert.equal(status.powerWatts, null);
});
