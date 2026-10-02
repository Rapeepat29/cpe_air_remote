import assert from 'node:assert/strict';
import test from 'node:test';

import {
  publicRoom,
  roomDefaultsForImport,
  validateRoomInput,
  validateRoomNumber,
} from '../src/utils/room.js';

test('accepts standard and special room codes', () => {
  assert.equal(validateRoomNumber('16203'), '16203');
  assert.equal(validateRoomNumber('cl503'), 'CL503');

  assert.deepEqual(
    validateRoomInput({
      roomNumber: 'cl503',
      floorNumber: 0,
      roomIndex: 503,
      roomType: 'Special Computer Laboratory',
    }),
    {
      roomNumber: 'CL503',
      floorNumber: 0,
      roomIndex: 503,
      roomType: 'Special Computer Laboratory',
    },
  );
});

test('rejects unsafe room codes and invalid groups', () => {
  assert.throws(
    () => validateRoomNumber('../CL503'),
    /รหัสห้องไม่ถูกต้อง/,
  );
  assert.throws(
    () => validateRoomInput({
      roomNumber: 'CL503',
      floorNumber: 100,
      roomIndex: 503,
      roomType: 'Laboratory',
    }),
    /ชั้นต้องอยู่ระหว่าง/,
  );
});

test('infers standard floors and special-room groups during import', () => {
  assert.deepEqual(roomDefaultsForImport('16203'), {
    roomNumber: '16203',
    floorNumber: 2,
    roomIndex: 3,
    roomType: 'Classroom',
  });
  assert.deepEqual(roomDefaultsForImport('cl503'), {
    roomNumber: 'CL503',
    floorNumber: 0,
    roomIndex: 503,
    roomType: 'Special',
  });
});

test('maps occupancy availability separately from a vacant room', () => {
  const room = publicRoom({
    room_number: '16203',
    floor_number: 2,
    room_index: 3,
    room_type: 'Laboratory',
    occupancy_sensor_device_id: 'OCC32-AABBCCDDEEFF',
    occupancy_sensor_ble_name: 'RMUTT-OCC-AABBCCDDEEFF',
    occupancy_sensor_provision_status: 'active',
    occupancy_sensor_online: 0,
    occupancy_sensor_available: 0,
    is_occupied: 0,
    occupancy_static_threshold: 25,
  });

  assert.equal(room.occupancySensorOnline, false);
  assert.equal(room.occupancySensorAvailable, false);
  assert.equal(room.isOccupied, false);
  assert.equal(room.occupancyStaticThreshold, 25);
});
