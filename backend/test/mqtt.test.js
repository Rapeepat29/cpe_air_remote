import assert from 'node:assert/strict';
import test, { after } from 'node:test';

import { pool } from '../src/db.js';
import { getMqttBridgeStatus } from '../src/services/mqtt.js';
import {
  AIR_RETAINED_SUFFIXES,
  OCCUPANCY_RETAINED_SUFFIXES,
  retainedTopics,
} from '../src/utils/mqtt-topics.js';

after(async () => {
  await pool.end();
});

test('MQTT health status never exposes credentials', () => {
  const status = getMqttBridgeStatus();

  assert.equal(typeof status.configured, 'boolean');
  assert.equal(typeof status.connected, 'boolean');
  assert.equal('username' in status, false);
  assert.equal('password' in status, false);
  assert.equal(
    JSON.stringify(status).includes('MQTT_PASSWORD'),
    false,
  );
});

test('removing a device clears every retained topic it owns', () => {
  assert.deepEqual(
    retainedTopics('rmutt/occupancy', 'OCC32-AABBCCDDEEFF',
      OCCUPANCY_RETAINED_SUFFIXES),
    [
      'rmutt/occupancy/OCC32-AABBCCDDEEFF/command',
      'rmutt/occupancy/OCC32-AABBCCDDEEFF/status',
      'rmutt/occupancy/OCC32-AABBCCDDEEFF/provision',
      'rmutt/occupancy/OCC32-AABBCCDDEEFF/provision-ack',
    ],
  );

  const airTopics = retainedTopics('rmutt/ac/', 'ESP32-705F1971FE68',
    AIR_RETAINED_SUFFIXES);
  assert.equal(airTopics.length, 6);
  assert.equal(airTopics[0], 'rmutt/ac/ESP32-705F1971FE68/command');
  assert.equal(
    airTopics.includes('rmutt/ac/ESP32-705F1971FE68/schedule-status'),
    true,
  );
});

test('retained topic list stays empty without a prefix or device id', () => {
  assert.deepEqual(retainedTopics('', 'OCC32-AABBCCDDEEFF',
    OCCUPANCY_RETAINED_SUFFIXES), []);
  assert.deepEqual(retainedTopics('rmutt/occupancy', '  ',
    OCCUPANCY_RETAINED_SUFFIXES), []);
});
