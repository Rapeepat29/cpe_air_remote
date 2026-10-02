import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

import {
  diffTables,
  isAutoAddableColumn,
  parseColumns,
  parseSchemaTables,
} from '../src/utils/schema-doctor.js';

const here = path.dirname(fileURLToPath(import.meta.url));
const schemaSql = fs.readFileSync(
  path.join(here, '..', 'database', 'schema.sql'),
  'utf8',
);

test('every table in schema.sql is parsed with its create statement', () => {
  const tables = parseSchemaTables(schemaSql);

  assert.deepEqual(
    [...tables.keys()],
    [
      'users',
      'password_reset_otps',
      'rooms',
      'class_schedules',
      'air_conditioners',
      'occupancy_sensors',
      'system_alerts',
      'energy_hourly',
      'system_settings',
    ],
  );

  const occupancy = tables.get('occupancy_sensors');
  assert.match(
    occupancy.createStatement,
    /^CREATE TABLE IF NOT EXISTS occupancy_sensors/,
  );
  assert.equal(occupancy.createStatement.includes(';'), false);
  assert.equal(
    occupancy.columns.some((column) => column.name === 'is_occupied'),
    true,
  );
  assert.equal(
    occupancy.columns.some((column) => column.name === 'PRIMARY'),
    false,
  );
});

test('air_conditioners keeps all 43 columns including PZEM, auto-off, firmware and history', () => {
  const tables = parseSchemaTables(schemaSql);
  const names = tables
    .get('air_conditioners')
    .columns.map((column) => column.name);

  assert.equal(names.length, 43);
  for (const column of [
    'energy_kwh',
    'frequency_hz',
    'power_factor',
    'pzem_available',
    'ac_running',
    'outside_schedule',
    'auto_off_enabled',
    'auto_off_deadline_at',
    'auto_off_attempts',
    'firmware_version',
    'ota_error',
  ]) {
    assert.equal(names.includes(column), true, `missing ${column}`);
  }
});

test('multi-line and parenthesised column types are read as one column', () => {
  const columns = parseColumns(`
  device_id VARCHAR(32) NOT NULL,
  provision_status ENUM(
    'reserved',
    'active',
    'removed'
  ) NOT NULL DEFAULT 'reserved',
  power_factor DECIMAL(5,3) NULL,
  PRIMARY KEY (device_id),
  UNIQUE KEY uq_device (device_id)
`);

  assert.deepEqual(columns.map((column) => column.name), [
    'device_id',
    'provision_status',
    'power_factor',
  ]);
  assert.match(columns[1].definition, /^ENUM\( 'reserved', 'active'/);
});

test('columns that cannot be added to a filled table are detected', () => {
  assert.equal(isAutoAddableColumn('DECIMAL(12,3) NULL'), true);
  assert.equal(isAutoAddableColumn('BOOLEAN NOT NULL DEFAULT FALSE'), true);
  assert.equal(isAutoAddableColumn('VARCHAR(100) NOT NULL'), false);
});

test('diff reports missing tables and missing columns separately', () => {
  const tables = parseSchemaTables(schemaSql);
  const actual = new Map([
    ['users', new Set(tables.get('users').columns.map((c) => c.name))],
    ['rooms', new Set(tables.get('rooms').columns.map((c) => c.name))],
    ['password_reset_otps', new Set(
      tables.get('password_reset_otps').columns.map((c) => c.name),
    )],
    ['class_schedules', new Set(
      tables.get('class_schedules').columns.map((c) => c.name),
    )],
    ['air_conditioners', new Set(
      tables
        .get('air_conditioners')
        .columns.map((c) => c.name)
        .filter((name) => name !== 'energy_kwh'),
    )],
    ['energy_hourly', new Set(
      tables.get('energy_hourly').columns.map((c) => c.name),
    )],
    ['system_alerts', new Set(
      tables.get('system_alerts').columns.map((c) => c.name),
    )],
    ['system_settings', new Set(
      tables.get('system_settings').columns.map((c) => c.name),
    )],
    // occupancy_sensors หายไปทั้งตาราง เหมือนฐานข้อมูลที่ยังไม่ได้ migrate
  ]);

  const { missingTables, missingColumns } = diffTables(tables, actual);

  assert.deepEqual(missingTables.map((table) => table.name), [
    'occupancy_sensors',
  ]);
  assert.deepEqual(missingColumns, [
    {
      table: 'air_conditioners',
      column: { name: 'energy_kwh', definition: 'DECIMAL(12,3) NULL' },
    },
  ]);
});
