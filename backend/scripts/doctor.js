// ตรวจ (และซ่อม) โครงสร้างฐานข้อมูลให้ตรงกับ database/schema.sql
// ใช้งาน:  npm run db:doctor              -> ตรวจอย่างเดียว
//          node scripts/doctor.js --fix   -> สร้างตาราง/เติมคอลัมน์ที่ขาดให้ด้วย
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { config } from '../src/config.js';
import { pool } from '../src/db.js';
import {
  diffTables,
  isAutoAddableColumn,
  parseSchemaTables,
} from '../src/utils/schema-doctor.js';

const shouldFix = process.argv.includes('--fix');
const here = path.dirname(fileURLToPath(import.meta.url));
const schemaPath = path.join(here, '..', 'database', 'schema.sql');
const schemaSql = await fs.readFile(schemaPath, 'utf8');
const expected = parseSchemaTables(schemaSql);

let created = 0;
let added = 0;
let skipped = 0;

try {
  console.log(
    `ฐานข้อมูล: ${config.db.database} @ ${config.db.host}:${config.db.port}`,
  );
  console.log('');

  const actual = await readActualSchema();
  const { missingTables, missingColumns } = diffTables(expected, actual);

  for (const [tableName] of expected) {
    if (actual.has(tableName)) {
      const missingHere = missingColumns
        .filter((item) => item.table === tableName)
        .map((item) => item.column.name);
      if (missingHere.length === 0) {
        console.log(`[ครบ] ${tableName} (${actual.get(tableName).size} คอลัมน์)`);
      } else {
        console.log(`[ขาดคอลัมน์] ${tableName}: ${missingHere.join(', ')}`);
      }
    } else {
      console.log(`[ขาดตาราง] ${tableName}`);
    }
  }

  if (shouldFix && missingTables.length > 0) {
    console.log('');
    for (const table of missingTables) {
      await pool.query(table.createStatement);
      created += 1;
      console.log(`สร้างตาราง ${table.name} แล้ว`);
    }
  }

  if (shouldFix && missingColumns.length > 0) {
    console.log('');
    for (const { table, column } of missingColumns) {
      if (!expected.has(table)) continue;
      if (missingTables.some((item) => item.name === table)) continue;
      if (!isAutoAddableColumn(column.definition)) {
        skipped += 1;
        console.log(
          `ข้าม ${table}.${column.name}: NOT NULL แต่ไม่มี DEFAULT ต้องเติมเอง`,
        );
        continue;
      }
      await pool.query(
        `ALTER TABLE ${table} ADD COLUMN ${column.name} ${column.definition}`,
      );
      added += 1;
      console.log(`เพิ่ม ${table}.${column.name} แล้ว`);
    }
  }

  const afterFix = shouldFix ? await readActualSchema() : actual;
  await reportDevices('air_conditioners', afterFix);
  await reportDevices('occupancy_sensors', afterFix);
  await reportEnergyHistory(afterFix);

  console.log('');
  if (missingTables.length === 0 && missingColumns.length === 0) {
    console.log('โครงสร้างฐานข้อมูลครบถ้วน');
  } else if (shouldFix) {
    console.log(
      `สร้างตาราง ${created} ตาราง เพิ่มคอลัมน์ ${added} คอลัมน์`
        + (skipped > 0 ? ` ข้าม ${skipped} คอลัมน์` : ''),
    );
    if (created > 0) {
      console.log(
        'ตารางที่เพิ่งสร้างยังไม่มีข้อมูลตัวอย่าง หากต้องการ seed ห้อง'
          + ' ให้รัน npm run db:init (ใช้ INSERT IGNORE ไม่ทับข้อมูลเดิม)',
      );
    }
  } else {
    console.log(
      `พบปัญหา ${missingTables.length} ตาราง และ ${missingColumns.length}`
        + ' คอลัมน์ รันซ้ำด้วย --fix เพื่อซ่อมอัตโนมัติ',
    );
  }
} finally {
  await pool.end();
}

async function readActualSchema() {
  const rows = await pool.query(
    `SELECT TABLE_NAME, COLUMN_NAME
       FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()`,
  );
  const tables = new Map();
  for (const row of rows) {
    if (!tables.has(row.TABLE_NAME)) tables.set(row.TABLE_NAME, new Set());
    tables.get(row.TABLE_NAME).add(row.COLUMN_NAME);
  }
  return tables;
}

async function reportEnergyHistory(actual) {
  console.log('');
  console.log('--- ประวัติค่าไฟรายชั่วโมง (energy_hourly) ---');
  if (!actual.has('energy_hourly')) {
    console.log('ยังไม่มีตาราง ให้รัน npm run db:migrate:energy');
    return;
  }

  const rows = await pool.query(
    `SELECT COUNT(*) AS buckets,
            COUNT(DISTINCT device_id) AS devices,
            MIN(bucket_start) AS oldest,
            MAX(bucket_start) AS newest,
            ROUND(SUM(consumption_kwh), 3) AS total_kwh
       FROM energy_hourly`,
  );
  const summary = rows[0] ?? {};
  const buckets = Number(summary.buckets ?? 0);
  if (buckets === 0) {
    console.log(
      '(ยังไม่มีข้อมูล จะเริ่มบันทึกเองเมื่อ ESP32 + PZEM ส่งค่าเข้ามา)',
    );
    return;
  }

  console.log(
    `${buckets} ช่วงเวลา จาก ${Number(summary.devices ?? 0)} อุปกรณ์`,
  );
  console.log(`ช่วงข้อมูล: ${summary.oldest} ถึง ${summary.newest}`);
  console.log(`พลังงานรวมที่บันทึกไว้: ${summary.total_kwh ?? 0} kWh`);
}

async function reportDevices(tableName, actual) {
  if (!actual.has(tableName)) return;

  const isAir = tableName === 'air_conditioners';
  const label = isAir ? 'เครื่องปรับอากาศ (ESP32 + PZEM)' : 'เซ็นเซอร์ตรวจจับคน (ESP32 + LD2410)';
  const rows = await pool.query(
    `SELECT device_id, room_number, provision_status, is_online,
            provisioning_expires_at, last_seen_at
       FROM ${tableName}
      ORDER BY room_number, device_id`,
  );

  console.log('');
  console.log(`--- ${label} ---`);
  if (rows.length === 0) {
    console.log('(ยังไม่มีอุปกรณ์ในตารางนี้)');
    return;
  }

  for (const row of rows) {
    const expiry = row.provisioning_expires_at
      ? new Date(row.provisioning_expires_at)
      : null;
    const tokenState = expiry == null
      ? '-'
      : (expiry.getTime() < Date.now() ? 'หมดอายุ' : 'ยังใช้ได้');
    console.log(
      `${row.device_id}  ห้อง ${row.room_number}  `
        + `status=${row.provision_status}  `
        + `online=${row.is_online ? 'yes' : 'no'}  token=${tokenState}`,
    );
    if (row.provision_status === 'reserved') {
      console.log(
        '   ^ ยังไม่ active: ESP32 ยังไม่ยืนยันตัวเองผ่าน MQTT'
          + ' (ข้อมูลยังอยู่ในฐานข้อมูล แต่สั่งงานไม่ได้'
          + ' ให้ตั้งค่าผ่าน Bluetooth อีกครั้ง)',
      );
    }
  }
}
