#!/usr/bin/env node
// ปรับชนิดข้อมูลของคอลัมน์ให้พอดีกับข้อมูลจริง ตาม database/schema.sql
//
// เช่น phone VARCHAR(20) -> VARCHAR(10), username VARCHAR(100) -> VARCHAR(30),
// device_id VARCHAR(64) -> CHAR(18), ค่าไฟฟ้า DECIMAL -> ขนาดตามช่วงของ PZEM
//
// - อ่านชนิดที่ต้องการจาก schema.sql เอง จึงไม่มีรายการซ้ำให้ลืมแก้
// - รันซ้ำได้ ถ้าคอลัมน์ตรงกับ schema แล้วจะข้ามให้เอง
// - ก่อนแก้จะเช็กว่ามีข้อมูลเดิมที่ยาวเกินขนาดใหม่หรือไม่
//   ถ้ามี จะหยุดทั้งหมดโดยไม่แก้อะไรเลย พร้อมบอกว่าแถวไหน
// - เบอร์โทรเดิมที่มีขีด/เว้นวรรค เช่น 081-234-5678 จะถูกแปลงเป็นตัวเลขล้วนก่อน
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { config } from '../src/config.js';
import { pool } from '../src/db.js';
import { parseSchemaTables } from '../src/utils/schema-doctor.js';

const dryRun = process.argv.includes('--dry-run');
const here = path.dirname(fileURLToPath(import.meta.url));
const schemaSql = await fs.readFile(
  path.join(here, '..', 'database', 'schema.sql'),
  'utf8',
);
const expected = parseSchemaTables(schemaSql);

// ชนิดข้อมูลที่ขึ้นต้นนิยามคอลัมน์ เช่น "VARCHAR(30) NOT NULL" -> "varchar(30)"
function typeOf(definition) {
  const match = String(definition).match(
    /^(\w+(?:\([^)]*\))?)(\s+UNSIGNED)?/i,
  );
  if (!match) return '';
  return `${match[1]}${match[2] ?? ''}`.toLowerCase().replace(/\s+/g, ' ');
}

// ชนิดที่ MariaDB รายงานจะมีรูปแบบต่างจากที่เขียนเล็กน้อย
// (ENUM ใส่ช่องว่าง, TIMESTAMP/DATETIME ไม่มีวงเล็บ ฯลฯ) ให้ทำให้เทียบกันได้
function normalise(type) {
  return String(type).toLowerCase().replace(/\s+/g, '').replace(/"/g, "'");
}

// เฉพาะชนิดที่ตั้งใจเปลี่ยนเท่านั้น ไม่ยุ่งกับ INT/BIGINT/อื่น ๆ
const managed = /^(varchar|char|decimal|enum|datetime|timestamp)\b/i;

async function main() {
  console.log(`ฐานข้อมูล: ${config.db.database} @ ${config.db.host}:${config.db.port}`);
  const rows = await pool.query(
    `SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE
       FROM information_schema.COLUMNS
      WHERE TABLE_SCHEMA = DATABASE()`,
  );
  const actual = new Map();
  for (const row of rows) {
    actual.set(`${row.TABLE_NAME}.${row.COLUMN_NAME}`, row.COLUMN_TYPE);
  }

  const changes = [];
  for (const [tableName, table] of expected) {
    for (const column of table.columns) {
      const key = `${tableName}.${column.name}`;
      if (!actual.has(key)) continue; // ขาดคอลัมน์ให้ db:doctor --fix จัดการ
      const wanted = typeOf(column.definition);
      if (!managed.test(wanted)) continue;
      if (normalise(actual.get(key)) === normalise(wanted)) continue;
      changes.push({ tableName, column, from: actual.get(key), to: wanted });
    }
  }

  if (changes.length === 0) {
    console.log('ชนิดข้อมูลทุกคอลัมน์ตรงกับ schema แล้ว ไม่มีอะไรต้องแก้');
    return;
  }

  console.log(`พบ ${changes.length} คอลัมน์ที่ชนิดต่างจาก schema:`);
  for (const c of changes) {
    console.log(`  ${c.tableName}.${c.column.name}: ${c.from} -> ${c.to}`);
  }

  if (!dryRun) await normalisePhones();

  const problems = await findOversize(changes);
  if (problems.length > 0) {
    console.error('\nหยุดการ migrate: มีข้อมูลเดิมที่ยาวเกินขนาดใหม่ ยังไม่ได้แก้อะไรเลย');
    for (const p of problems) {
      console.error(
        `  ${p.table}.${p.column} (ขนาดใหม่ ${p.limit}): ${p.count} แถว`
          + ` ตัวอย่าง "${p.sample}"`,
      );
    }
    console.error('แก้หรือลบข้อมูลเหล่านี้ก่อน แล้วรันใหม่');
    process.exitCode = 1;
    return;
  }

  if (dryRun) {
    console.log('\n--dry-run: ไม่ได้แก้อะไร');
    return;
  }

  // MariaDB ไม่ยอมเปลี่ยนชนิดคอลัมน์ที่อยู่ใน FOREIGN KEY แม้ปิด FOREIGN_KEY_CHECKS
  // จึงต้องลบ FK ที่เกี่ยวข้อง -> เปลี่ยนชนิดทั้งสองฝั่ง -> สร้าง FK กลับด้วยกติกาเดิม
  const touched = new Set(changes.map((c) => `${c.tableName}.${c.column.name}`));
  const foreignKeys = (await readForeignKeys()).filter(
    (fk) => touched.has(`${fk.table}.${fk.column}`)
      || touched.has(`${fk.refTable}.${fk.refColumn}`),
  );

  const conn = await pool.getConnection();
  try {
    await conn.query('SET FOREIGN_KEY_CHECKS = 0');
    for (const fk of foreignKeys) {
      await conn.query(`ALTER TABLE ${fk.table} DROP FOREIGN KEY ${fk.name}`);
      console.log(`ถอด FK ${fk.name} ชั่วคราว`);
    }
    for (const c of changes) {
      await conn.query(
        `ALTER TABLE ${c.tableName} MODIFY COLUMN ${c.column.name} ${c.column.definition}`,
      );
      console.log(`แก้ ${c.tableName}.${c.column.name} -> ${c.to}`);
    }
    for (const fk of foreignKeys) {
      await conn.query(
        `ALTER TABLE ${fk.table} ADD CONSTRAINT ${fk.name}
           FOREIGN KEY (${fk.column}) REFERENCES ${fk.refTable} (${fk.refColumn})
           ON UPDATE ${fk.updateRule} ON DELETE ${fk.deleteRule}`,
      );
      console.log(`ใส่ FK ${fk.name} กลับแล้ว`);
    }
  } finally {
    await conn.query('SET FOREIGN_KEY_CHECKS = 1');
    conn.release();
  }
  console.log(`\nเสร็จ แก้ ${changes.length} คอลัมน์`);
}

// 081-234-5678 / 081 234 5678 / +66812345678 -> 0812345678
async function normalisePhones() {
  const result = await pool.query(
    `UPDATE users
        SET phone = CASE
          WHEN REGEXP_REPLACE(phone, '[ ().-]', '') REGEXP '^[+]?66[0-9]{8,9}$'
            THEN CONCAT('0', REGEXP_REPLACE(REGEXP_REPLACE(phone, '[ ().-]', ''), '^[+]?66', ''))
          ELSE REGEXP_REPLACE(phone, '[ ().-]', '')
        END
      WHERE phone IS NOT NULL AND phone <> ''
        AND phone REGEXP '[ ().+-]'`,
  );
  const n = Number(result?.affectedRows ?? 0);
  if (n > 0) console.log(`จัดรูปแบบเบอร์โทรเดิม ${n} แถว`);
}

async function readForeignKeys() {
  const rows = await pool.query(
    `SELECT k.TABLE_NAME AS tbl, k.CONSTRAINT_NAME AS name,
            k.COLUMN_NAME AS col, k.REFERENCED_TABLE_NAME AS refTbl,
            k.REFERENCED_COLUMN_NAME AS refCol,
            r.UPDATE_RULE AS upd, r.DELETE_RULE AS del
       FROM information_schema.KEY_COLUMN_USAGE k
       JOIN information_schema.REFERENTIAL_CONSTRAINTS r
         ON r.CONSTRAINT_SCHEMA = k.TABLE_SCHEMA
        AND r.CONSTRAINT_NAME = k.CONSTRAINT_NAME
        AND r.TABLE_NAME = k.TABLE_NAME
      WHERE k.TABLE_SCHEMA = DATABASE() AND k.REFERENCED_TABLE_NAME IS NOT NULL`,
  );
  return rows.map((r) => ({
    table: r.tbl,
    name: r.name,
    column: r.col,
    refTable: r.refTbl,
    refColumn: r.refCol,
    updateRule: r.upd,
    deleteRule: r.del,
  }));
}

async function findOversize(changes) {
  const problems = [];
  for (const c of changes) {
    const col = `\`${c.column.name}\``;
    const dec = c.to.match(/^decimal\((\d+),(\d+)\)/);
    if (dec) {
      const max = 10 ** (Number(dec[1]) - Number(dec[2]));
      const [stat] = await pool.query(
        `SELECT COUNT(*) AS n, MAX(ABS(${col})) AS sample FROM ${c.tableName}
          WHERE ABS(${col}) >= ?`,
        [max],
      );
      if (Number(stat.n) > 0) {
        problems.push({
          table: c.tableName, column: c.column.name,
          limit: `ค่าต้องน้อยกว่า ${max}`, count: Number(stat.n), sample: stat.sample,
        });
      }
      continue;
    }
    const en = c.to.match(/^enum\((.*)\)$/);
    if (en) {
      const values = en[1].split(',').map((v) => v.trim());
      const [stat] = await pool.query(
        `SELECT COUNT(*) AS n, MIN(${col}) AS sample FROM ${c.tableName}
          WHERE ${col} IS NOT NULL AND ${col} NOT IN (${values.join(',')})`,
      );
      if (Number(stat.n) > 0) {
        problems.push({
          table: c.tableName, column: c.column.name,
          limit: `ต้องเป็น ${values.join('/')}`, count: Number(stat.n), sample: stat.sample,
        });
      }
      continue;
    }
    const match = c.to.match(/^(varchar|char)\((\d+)\)/);
    if (!match) continue;
    const limit = Number(match[2]);
    if (dryRun && c.tableName === 'users' && c.column.name === 'phone') continue;
    const [stat] = await pool.query(
      `SELECT COUNT(*) AS n, MIN(\`${c.column.name}\`) AS sample
         FROM ${c.tableName}
        WHERE CHAR_LENGTH(\`${c.column.name}\`) > ?`,
      [limit],
    );
    if (Number(stat.n) > 0) {
      problems.push({
        table: c.tableName,
        column: c.column.name,
        limit,
        count: Number(stat.n),
        sample: stat.sample,
      });
    }
  }
  return problems;
}

try {
  await main();
} catch (error) {
  console.error('migrate ไม่สำเร็จ:', error.message);
  process.exitCode = 1;
} finally {
  await pool.end();
}
