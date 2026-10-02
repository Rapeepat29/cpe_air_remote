import assert from 'node:assert/strict';
import test from 'node:test';

import { isValidFromAddress } from '../src/config.js';
import {
  deriveDevicePassword,
  deviceAcls,
  deviceKindOf,
  ensureDeviceCommands,
  isHarmlessDynsecError,
  normalizeDeviceAuthMode,
  repairDeviceCommands,
} from '../src/utils/mqtt-accounts.js';

const SECRET = 'x'.repeat(40);

test('รหัสผ่าน MQTT ของบอร์ดคำนวณซ้ำได้ค่าเดิม และต่างกันในแต่ละบอร์ด', () => {
  const first = deriveDevicePassword(SECRET, 'ESP32-A1B2C3D4E5F6');
  assert.equal(first, deriveDevicePassword(SECRET, 'esp32-a1b2c3d4e5f6'));
  assert.equal(first.length, 32);
  assert.notEqual(first, deriveDevicePassword(SECRET, 'ESP32-A1B2C3D4E5F7'));
  assert.notEqual(first, deriveDevicePassword('y'.repeat(40), 'ESP32-A1B2C3D4E5F6'));
  assert.throws(() => deriveDevicePassword('', 'ESP32-A1B2C3D4E5F6'));
});

test('แยกชนิดบอร์ดจาก Device ID ได้', () => {
  assert.equal(deviceKindOf('ESP32-A1B2C3D4E5F6'), 'air');
  assert.equal(deviceKindOf('OCC32-A1B2C3D4E5F6'), 'occupancy');
  assert.equal(deviceKindOf('ESP32-XYZ'), null);
});

test('ACL ของบอร์ดแอร์จำกัดอยู่ใน topic ของตัวเองเท่านั้น', () => {
  const acls = deviceAcls({
    kind: 'air',
    topicPrefix: 'rmutt/ac/',
    deviceId: 'ESP32-A1B2C3D4E5F6',
  });
  for (const acl of acls) {
    assert.ok(acl.topic.startsWith('rmutt/ac/ESP32-A1B2C3D4E5F6/'), acl.topic);
    assert.ok(!acl.topic.includes('#') && !acl.topic.includes('+'));
  }
  const publishes = acls
    .filter((acl) => acl.acltype === 'publishClientSend')
    .map((acl) => acl.topic.split('/').pop());
  // บอร์ดต้องไม่มีสิทธิ์ publish ไปที่ command ของตัวเองหรือของใคร
  assert.ok(!publishes.includes('command'));
  assert.deepEqual(publishes.sort(), ['history', 'provision', 'provision-ack', 'state', 'status']);
});

test('คำสั่งสร้างบัญชีไม่แตะบัญชีเดิม ส่วนคำสั่งซ่อมตั้งรหัสใหม่', () => {
  const ensure = ensureDeviceCommands({
    kind: 'occupancy',
    topicPrefix: 'rmutt/occupancy',
    deviceId: 'OCC32-A1B2C3D4E5F6',
    password: 'p',
  });
  const names = ensure.map((item) => item.command);
  assert.ok(!names.includes('setClientPassword'));
  const client = ensure.find((item) => item.command === 'createClient');
  assert.equal(client.clientid, 'rmutt-occ-OCC32-A1B2C3D4E5F6');

  const repair = repairDeviceCommands({
    kind: 'air',
    deviceId: 'ESP32-A1B2C3D4E5F6',
    password: 'p',
  });
  assert.equal(repair[0].command, 'setClientPassword');
});

test('error ที่แปลว่า "มีอยู่แล้ว" ไม่ถือว่าล้มเหลว', () => {
  assert.ok(isHarmlessDynsecError('createClient', 'Client already exists'));
  assert.ok(isHarmlessDynsecError('addRoleACL', 'ACL with this topic already exists'));
  assert.ok(isHarmlessDynsecError('addClientRole', 'Internal error'));
  assert.ok(isHarmlessDynsecError('deleteClient', 'Client not found'));
  assert.ok(!isHarmlessDynsecError('createClient', 'Internal error'));
  assert.ok(!isHarmlessDynsecError('setClientPassword', 'Client not found'));
});

test('โหมดยืนยันตัวตนของบอร์ดถอยไปใช้ shared เมื่อค่าไม่ถูกต้อง', () => {
  assert.equal(normalizeDeviceAuthMode('DYNSEC'), 'dynsec');
  assert.equal(normalizeDeviceAuthMode(''), 'shared');
  assert.equal(normalizeDeviceAuthMode('other'), 'shared');
});

test('SMTP_FROM ต้องมีที่อยู่อีเมล', () => {
  assert.ok(isValidFromAddress('RMUTT Save Energy <energy@rmutt.ac.th>'));
  assert.ok(isValidFromAddress('"RMUTT Save Energy" <a.b@gmail.com>'));
  assert.ok(isValidFromAddress('energy@rmutt.ac.th'));
  assert.ok(!isValidFromAddress('RMUTT Save Energy'));
  assert.ok(!isValidFromAddress(''));
});
