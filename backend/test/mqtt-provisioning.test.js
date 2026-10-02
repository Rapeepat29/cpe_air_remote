import assert from 'node:assert/strict';
import test from 'node:test';

import { resolveMqttProvisioningSettings } from '../src/utils/mqtt-provisioning.js';

test('ใช้ที่อยู่สำหรับอุปกรณ์ก่อนที่อยู่ภายในของ Backend', () => {
  const result = resolveMqttProvisioningSettings({
    url: 'mqtt://mqtt:1883',
    deviceUrl: 'mqtts://rmutt-energy.duckdns.org:8883',
    username: 'rmutt_air',
    password: 'secret',
  });

  assert.deepEqual(result, {
    mqttHost: 'rmutt-energy.duckdns.org',
    mqttPort: 8883,
    mqttUsername: 'rmutt_air',
    mqttPassword: 'secret',
    mqttTls: true,
  });
});

test('ไม่ตั้ง MQTT_DEVICE_URL ให้ใช้ MQTT_URL เหมือนเดิม', () => {
  const result = resolveMqttProvisioningSettings({
    url: 'mqtt://192.168.1.110:1883',
    deviceUrl: '',
    username: 'rmutt_air',
    password: 'secret',
  });

  assert.equal(result.mqttHost, '192.168.1.110');
  assert.equal(result.mqttPort, 1883);
  assert.equal(result.mqttTls, false);
});

test('mqtts ไม่ระบุพอร์ตให้ใช้ 8883 เป็นค่าเริ่มต้น', () => {
  const result = resolveMqttProvisioningSettings({
    deviceUrl: 'mqtts://broker.example.com',
    username: 'u',
    password: 'p',
  });

  assert.equal(result.mqttPort, 8883);
  assert.equal(result.mqttTls, true);
});

test('รับชื่อโดเมนได้ ไม่ได้บังคับว่าต้องเป็น IP', () => {
  const result = resolveMqttProvisioningSettings({
    deviceUrl: 'mqtts://rmutt-energy.duckdns.org:8883',
  });
  assert.equal(result.mqttHost, 'rmutt-energy.duckdns.org');
});

test('ปฏิเสธ URL ที่ไม่ใช่ mqtt/mqtts และที่ว่างเปล่า', () => {
  assert.throws(
    () => resolveMqttProvisioningSettings({ deviceUrl: 'https://example.com' }),
    /mqtt:\/\/ หรือ mqtts:\/\//,
  );
  assert.throws(
    () => resolveMqttProvisioningSettings({ url: '', deviceUrl: '' }),
    /MQTT_URL/,
  );
});
