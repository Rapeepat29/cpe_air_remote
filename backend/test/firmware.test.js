import assert from 'node:assert/strict';
import test from 'node:test';

import {
  firmwareKindOf,
  firmwareUrl,
  validateFirmwareFileName,
} from '../src/utils/firmware.js';

test('ยอมรับเฉพาะชื่อไฟล์ .bin ที่ปลอดภัย', () => {
  assert.equal(
    validateFirmwareFileName('rmutt_esp32_air-2.3.0.bin'),
    'rmutt_esp32_air-2.3.0.bin',
  );
  for (const bad of ['../etc/passwd.bin', 'a/b.bin', 'x.exe', '', 'a b.bin', '.hidden.bin', 'a..b.bin']) {
    assert.throws(() => validateFirmwareFileName(bad), bad);
  }
});

test('URL ดาวน์โหลดใช้โฮสต์เดียวกับ MQTT host ของบอร์ด', () => {
  assert.equal(
    firmwareUrl('energy.rmutt.ac.th', 'air-2.3.0.bin'),
    'https://energy.rmutt.ac.th/firmware/air-2.3.0.bin',
  );
  assert.throws(() => firmwareUrl('', 'air.bin'));
  assert.throws(() => firmwareUrl('evil.com/x', 'air.bin'));
});

test('เดาชนิดบอร์ดจากชื่อไฟล์', () => {
  assert.equal(firmwareKindOf('rmutt_esp32_occupancy-1.3.0.bin'), 'occupancy');
  assert.equal(firmwareKindOf('rmutt_esp32_air-2.3.0.bin'), 'air');
});
