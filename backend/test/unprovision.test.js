import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildUnprovisionCommand,
  isUnprovisionAck,
} from '../src/utils/unprovision.js';

test('unprovision command names the target board', () => {
  assert.deepEqual(
    buildUnprovisionCommand('ESP32-AABBCCDDEEFF', {
      commandId: 'c1',
      sentAt: '2026-10-13T12:00:00.000Z',
    }),
    {
      version: 1,
      commandId: 'c1',
      sentAt: '2026-10-13T12:00:00.000Z',
      action: 'unprovision',
      deviceId: 'ESP32-AABBCCDDEEFF',
    },
  );
});

test('only an explicit acknowledgement from the same board counts', () => {
  const id = 'OCC32-AABBCCDDEEFF';
  assert.equal(isUnprovisionAck({ unprovisioned: true, deviceId: id }, id), true);
  assert.equal(
    isUnprovisionAck({ unprovisioned: true, deviceId: 'OCC32-000000000000' }, id),
    false,
  );
  // status ปกติของบอร์ดต้องไม่ถูกตีความว่าเป็นคำตอบ
  assert.equal(isUnprovisionAck({ online: true, deviceId: id }, id), false);
  assert.equal(isUnprovisionAck({ unprovisioned: 'true', deviceId: id }, id), false);
  assert.equal(isUnprovisionAck(null, id), false);
});
