import assert from 'node:assert/strict';
import test from 'node:test';

import {
  normalizeOccupancyStatus,
  publicOccupancySensor,
  STATIC_ENERGY_THRESHOLD,
  validateOccupancyReservationInput,
} from '../src/utils/occupancy-sensor.js';

test('accepts one LD2410 occupancy sensor identity for a room', () => {
  assert.equal(STATIC_ENERGY_THRESHOLD, 25);
  assert.deepEqual(
    validateOccupancyReservationInput({
      deviceId: 'OCC32-AABBCCDDEEFF',
      bleName: 'RMUTT-OCC-AABBCCDDEEFF',
      roomNumber: '16203',
    }),
    {
      deviceId: 'OCC32-AABBCCDDEEFF',
      bleName: 'RMUTT-OCC-AABBCCDDEEFF',
      roomNumber: '16203',
    },
  );
});

test('rejects mismatched LD2410 Bluetooth identity', () => {
  assert.throws(
    () => validateOccupancyReservationInput({
      deviceId: 'OCC32-AABBCCDDEEFF',
      bleName: 'RMUTT-OCC-001122334455',
      roomNumber: '16203',
    }),
    /Bluetooth/,
  );
});

test('stores only the occupancy boolean when radar data is available', () => {
  assert.deepEqual(
    normalizeOccupancyStatus({
      online: true,
      radarAvailable: true,
      occupied: true,
      movingDistance: 540,
    }),
    { online: true, radarAvailable: true, occupied: true },
  );
  assert.deepEqual(
    normalizeOccupancyStatus({
      online: true,
      radarAvailable: false,
      occupied: true,
    }),
    { online: true, radarAvailable: false, occupied: false },
  );
  assert.deepEqual(
    normalizeOccupancyStatus({
      online: false,
      radarAvailable: true,
      occupied: true,
    }),
    { online: false, radarAvailable: false, occupied: false },
  );
});

test('public occupancy sensor keeps the row visible before activation', () => {
  const result = publicOccupancySensor({
    device_id: 'OCC32-AABBCCDDEEFF',
    room_number: '16101',
    ble_name: 'RMUTT-OCC-AABBCCDDEEFF',
    mqtt_topic: 'rmutt/occupancy/OCC32-AABBCCDDEEFF',
    provision_status: 'reserved',
    is_online: 0,
    radar_available: 0,
    is_occupied: 0,
    static_threshold: 25,
    last_seen_at: null,
  });

  assert.deepEqual(result, {
    deviceId: 'OCC32-AABBCCDDEEFF',
    roomNumber: '16101',
    bleName: 'RMUTT-OCC-AABBCCDDEEFF',
    mqttTopic: 'rmutt/occupancy/OCC32-AABBCCDDEEFF',
    provisionStatus: 'reserved',
    isOnline: false,
    radarAvailable: false,
    isOccupied: false,
    staticThreshold: 25,
    lastSeenAt: null,
    firmwareVersion: null,
    otaError: null,
  });
});

test('public occupancy sensor reports live radar values', () => {
  const result = publicOccupancySensor({
    device_id: 'OCC32-112233445566',
    room_number: '16203',
    ble_name: 'RMUTT-OCC-112233445566',
    mqtt_topic: 'rmutt/occupancy/OCC32-112233445566',
    provision_status: 'active',
    is_online: 1,
    radar_available: 1,
    is_occupied: 1,
    static_threshold: 25,
    last_seen_at: '2026-08-19T03:00:00.000Z',
  });

  assert.equal(result.provisionStatus, 'active');
  assert.equal(result.isOnline, true);
  assert.equal(result.isOccupied, true);
  assert.equal(result.lastSeenAt, '2026-08-19T03:00:00.000Z');
});
