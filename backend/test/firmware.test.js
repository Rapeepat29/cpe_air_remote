import assert from 'node:assert/strict';
import test from 'node:test';

import {
  FIRMWARE_MAX_BYTES,
  airFirmwareKind,
  assertFirmwareKind,
  compareFirmwareVersions,
  firmwareKindOf,
  firmwareUrl,
  firmwareVersionOf,
  validateFirmwareFileName,
  validateFirmwareImage,
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

test('แยกไฟล์สายแอร์ออกจากแอร์ IR', () => {
  assert.equal(firmwareKindOf('rmutt_esp32_air_wired-2.5.2-slm8.bin'), 'wired');
  assert.equal(firmwareKindOf('rmutt_esp32_air-2.5.1.bin'), 'air');
  assert.equal(firmwareKindOf('rmutt_esp32_occ-1.3.2.bin'), 'occupancy');
  assert.equal(airFirmwareKind('DAIKIN_WIRED'), 'wired');
  assert.equal(airFirmwareKind('HAIER_AC160'), 'air');
});

test('ห้ามสั่งไฟล์ผิดชนิดให้บอร์ด', () => {
  assert.doesNotThrow(() => assertFirmwareKind('x_wired-2.5.2-slm8.bin', 'wired'));
  assert.throws(() => assertFirmwareKind('rmutt_esp32_air-2.5.1.bin', 'wired'), /สายแอร์/);
  assert.throws(() => assertFirmwareKind('rmutt_esp32_occ-1.3.2.bin', 'air'), /เซ็นเซอร์/);
});

test('อ่านรุ่นจากชื่อไฟล์และเทียบรุ่น', () => {
  assert.equal(firmwareVersionOf('rmutt_esp32_air_wired-2.5.2-slm8.bin'), '2.5.2-slm8');
  assert.equal(firmwareVersionOf('rmutt_esp32_air-2.5.1.bin'), '2.5.1');
  assert.equal(firmwareVersionOf('air.bin'), null);
  assert.ok(compareFirmwareVersions('2.5.2-slm8', '2.5.1-slm8') > 0);
  assert.ok(compareFirmwareVersions('2.5.10', '2.5.9') > 0);
  assert.equal(compareFirmwareVersions('1.3.2', '1.3.2'), 0);
  assert.ok(compareFirmwareVersions(null, '1.0.0') < 0);
});

test('รับเฉพาะไฟล์โปรแกรม ESP32 ที่ขนาดพอดีช่อง', () => {
  const image = Buffer.alloc(4096);
  image[0] = 0xe9;
  assert.doesNotThrow(() => validateFirmwareImage(image));
  assert.throws(() => validateFirmwareImage(Buffer.alloc(4096)), /ไม่ใช่โปรแกรม ESP32/);
  const huge = Buffer.alloc(FIRMWARE_MAX_BYTES + 1);
  huge[0] = 0xe9;
  assert.throws(() => validateFirmwareImage(huge), /ใหญ่เกิน/);
  assert.throws(() => validateFirmwareImage(Buffer.alloc(0)), /ไม่ได้แนบ/);
});
