import assert from 'node:assert/strict';
import test from 'node:test';

import {
  controlTypeOf,
  protocolFromStatus,
  publicAirConditioner,
  validateAirState,
  validateReservationInput,
} from '../src/utils/air-conditioner.js';

test('accepts one unique ESP32 reservation for a building 16 room', () => {
  assert.deepEqual(
    validateReservationInput({
      deviceId: 'ESP32-AABBCCDDEEFF',
      bleName: 'RMUTT-AC-AABBCCDDEEFF',
      roomNumber: '16203',
      airNumber: 4,
      name: 'Air 4',
      protocol: 'HAIER_AC160',
      dailyOn: '08:00',
      dailyOff: '17:00',
    }),
    {
      deviceId: 'ESP32-AABBCCDDEEFF',
      bleName: 'RMUTT-AC-AABBCCDDEEFF',
      roomNumber: '16203',
      airNumber: 4,
      name: 'Air 4',
      protocol: 'HAIER_AC160',
      dailyOn: '08:00',
      dailyOff: '17:00',
    },
  );
});

test('rejects invalid rooms, unit numbers, and BLE identity mismatches', () => {
  const base = {
    deviceId: 'ESP32-AABBCCDDEEFF',
    bleName: 'RMUTT-AC-AABBCCDDEEFF',
    roomNumber: '16203',
    airNumber: 1,
    name: 'Air 1',
    protocol: 'HAIER_AC160',
  };
  assert.throws(
    () => validateReservationInput({ ...base, roomNumber: 'bad room' }),
    /หมายเลขห้อง/,
  );
  assert.throws(
    () => validateReservationInput({ ...base, airNumber: 7 }),
    /1–6/,
  );
  assert.throws(
    () => validateReservationInput({ ...base, bleName: 'RMUTT-AC-OTHER' }),
    /Bluetooth/,
  );
});

test('normalizes a supported IRac protocol name', () => {
  const result = validateReservationInput({
    deviceId: 'ESP32-001122334455',
    bleName: 'RMUTT-AC-001122334455',
    roomNumber: '16101',
    airNumber: 2,
    name: 'Air 2',
    protocol: 'mitsubishi_ac',
  });
  assert.equal(result.protocol, 'MITSUBISHI_AC');
});

test('accepts the custom Saijo Denki protocol', () => {
  const result = validateReservationInput({
    deviceId: 'ESP32-001122334455',
    bleName: 'RMUTT-AC-001122334455',
    roomNumber: '16101',
    airNumber: 2,
    name: 'Saijo Denki 2',
    protocol: 'saijo_denki',
  });
  assert.equal(result.protocol, 'SAIJO_DENKI');
});

test('normalizes a complete MQTT air-conditioner command', () => {
  assert.deepEqual(
    validateAirState({
      power: true,
      temperature: 24,
      mode: 'cool',
      fanSpeed: 'high',
      verticalSwing: 'auto',
      horizontalSwing: false,
      eco: true,
      turbo: false,
      sleep: false,
      quiet: true,
      displayLight: true,
      clean: false,
      timerOnMinutes: null,
      timerOffMinutes: 120,
    }),
    {
      power: true,
      temperature: 24,
      mode: 'cool',
      fanSpeed: 'high',
      verticalSwing: 'auto',
      horizontalSwing: false,
      eco: true,
      turbo: false,
      sleep: false,
      quiet: true,
      displayLight: true,
      clean: false,
      timerOnMinutes: null,
      timerOffMinutes: 120,
    },
  );
});

test('validates the captured Saijo Denki capability range', () => {
  const base = {
    power: true,
    temperature: 24,
    mode: 'cool',
    fanSpeed: 'high',
    verticalSwing: 'middle',
  };
  assert.equal(
    validateAirState(base, 'SAIJO_DENKI').temperature,
    24,
  );
  assert.throws(
    () => validateAirState({ ...base, temperature: 16 }, 'SAIJO_DENKI'),
    /18–29/,
  );
  assert.equal(
    validateAirState({ ...base, mode: 'dry' }, 'SAIJO_DENKI').mode,
    'dry',
  );
  assert.equal(
    validateAirState({ ...base, mode: 'fan' }, 'SAIJO_DENKI').mode,
    'fan',
  );
  assert.equal(
    validateAirState({ ...base, fanSpeed: 'turbo' }, 'SAIJO_DENKI').fanSpeed,
    'turbo',
  );
  assert.equal(
    validateAirState({ ...base, verticalSwing: 'upper' }, 'SAIJO_DENKI')
      .verticalSwing,
    'upper',
  );
  assert.equal(
    validateAirState({ ...base, verticalSwing: 'lower' }, 'SAIJO_DENKI')
      .verticalSwing,
    'lower',
  );
  assert.throws(
    () => validateAirState({ ...base, mode: 'heat' }, 'SAIJO_DENKI'),
    /Cool, Dry และ Fan/,
  );
  assert.throws(
    () => validateAirState({ ...base, verticalSwing: 'off' }, 'SAIJO_DENKI'),
    /Swing/,
  );
});

test('accepts the Daikin wired-panel board protocol', () => {
  const result = validateReservationInput({
    deviceId: 'ESP32-001122334455',
    bleName: 'RMUTT-AC-001122334455',
    roomNumber: '16101',
    airNumber: 1,
    name: 'Air 1',
    protocol: 'daikin_wired',
  });
  assert.equal(result.protocol, 'DAIKIN_WIRED');
});

test('limits wired Daikin commands to what the wall-panel bus supports', () => {
  const base = {
    power: true,
    temperature: 25,
    mode: 'cool',
    fanSpeed: 'high',
    verticalSwing: 'auto',
    horizontalSwing: true,
    eco: true,
    turbo: true,
    sleep: true,
    quiet: true,
    displayLight: true,
    clean: true,
  };
  const cool = validateAirState(base, 'DAIKIN_WIRED');
  assert.equal(cool.sleep, true);
  assert.equal(cool.horizontalSwing, false);
  assert.equal(cool.eco, false);
  assert.equal(cool.turbo, false);
  assert.equal(cool.quiet, false);
  assert.equal(cool.clean, false);
  assert.equal(
    validateAirState({ ...base, mode: 'dry' }, 'DAIKIN_WIRED').sleep,
    false,
  );
  assert.equal(
    validateAirState({ ...base, verticalSwing: 'off' }, 'DAIKIN_WIRED')
      .verticalSwing,
    'off',
  );
  assert.throws(
    () => validateAirState({ ...base, mode: 'auto' }, 'DAIKIN_WIRED'),
    /สายแอร์/,
  );
  assert.throws(
    () => validateAirState({ ...base, mode: 'heat' }, 'DAIKIN_WIRED'),
    /สายแอร์/,
  );
  assert.throws(
    () => validateAirState({ ...base, fanSpeed: 'turbo' }, 'DAIKIN_WIRED'),
    /Turbo/,
  );
  assert.throws(
    () => validateAirState({ ...base, verticalSwing: 'middle' }, 'DAIKIN_WIRED'),
    /สายแอร์/,
  );
  // IR Daikin is unaffected
  assert.equal(validateAirState(base, 'DAIKIN').turbo, true);
});

test('reports the control type of each protocol', () => {
  assert.equal(controlTypeOf('DAIKIN_WIRED'), 'wired');
  assert.equal(controlTypeOf('daikin_wired'), 'wired');
  assert.equal(controlTypeOf('DAIKIN'), 'ir');
  assert.equal(controlTypeOf(null), 'ir');
  assert.equal(
    publicAirConditioner({ id: 1, protocol: 'DAIKIN_WIRED' }).controlType,
    'wired',
  );
});

test('detects a wired board from its MQTT status', () => {
  assert.equal(protocolFromStatus({ controlMode: 'wired' }), 'DAIKIN_WIRED');
  assert.equal(protocolFromStatus({ controlMode: ' Wired ' }), 'DAIKIN_WIRED');
  assert.equal(protocolFromStatus({ controlMode: 'ir' }), null);
  assert.equal(protocolFromStatus({ online: true }), null);
  assert.equal(protocolFromStatus(null), null);
});
