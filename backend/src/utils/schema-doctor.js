// อ่าน database/schema.sql แล้วบอกว่าฐานข้อมูลจริงขาดตาราง/คอลัมน์อะไรบ้าง
// ใช้ร่วมกับ scripts/doctor.js

const constraintKeywords = new Set([
  'PRIMARY',
  'UNIQUE',
  'KEY',
  'INDEX',
  'CONSTRAINT',
  'FOREIGN',
  'FULLTEXT',
  'CHECK',
]);

const tablePattern =
  /CREATE TABLE IF NOT EXISTS\s+(\w+)\s*\(([\s\S]*?)\n\)([^;]*);/g;

export function parseSchemaTables(sql) {
  const source = typeof sql === 'string' ? sql : '';
  const tables = new Map();
  const pattern = new RegExp(tablePattern.source, 'g');

  let match = pattern.exec(source);
  while (match !== null) {
    const [statement, tableName, body] = match;
    tables.set(tableName, {
      name: tableName,
      createStatement: statement.replace(/;\s*$/, ''),
      columns: parseColumns(body),
    });
    match = pattern.exec(source);
  }
  return tables;
}

export function parseColumns(body) {
  const columns = [];
  // ตัดคอมเมนต์ "-- ..." ออกก่อน ไม่งั้นคอมเมนต์ที่อยู่เหนือคอลัมน์ใน schema.sql
  // (เช่นใน air_conditioners) จะถูกอ่านเป็นคอลัมน์ชื่อ "--" แล้ว --fix สั่ง
  // ALTER TABLE ที่ผิดไวยากรณ์ ทำให้ doctor ล้มทุกครั้งที่ deploy
  const source = String(body ?? '').replace(/--[^\n]*/g, '');
  for (const part of splitTopLevel(source)) {
    const definition = part.trim().replace(/\s+/g, ' ');
    if (!definition) continue;

    const firstWord = definition.split(' ')[0];
    if (constraintKeywords.has(firstWord.toUpperCase())) continue;

    const name = firstWord.replace(/`/g, '');
    columns.push({
      name,
      definition: definition.slice(firstWord.length).trim(),
    });
  }
  return columns;
}

// คอลัมน์ที่เป็น NOT NULL แต่ไม่มี DEFAULT เติมทับตารางที่มีข้อมูลอยู่ไม่ได้
export function isAutoAddableColumn(definition) {
  const value = String(definition ?? '');
  if (!/NOT NULL/i.test(value)) return true;
  return /DEFAULT/i.test(value) || /AUTO_INCREMENT/i.test(value);
}

export function diffTables(expected, actual) {
  const missingTables = [];
  const missingColumns = [];

  for (const [tableName, table] of expected) {
    const actualColumns = actual.get(tableName);
    if (!actualColumns) {
      missingTables.push(table);
      continue;
    }
    for (const column of table.columns) {
      if (!actualColumns.has(column.name)) {
        missingColumns.push({ table: tableName, column });
      }
    }
  }

  return { missingTables, missingColumns };
}

function splitTopLevel(body) {
  const parts = [];
  let depth = 0;
  let quote = null;
  let current = '';

  for (const char of String(body ?? '')) {
    if (quote) {
      current += char;
      if (char === quote) quote = null;
      continue;
    }
    if (char === "'" || char === '"' || char === '`') {
      quote = char;
      current += char;
      continue;
    }
    if (char === '(') depth += 1;
    if (char === ')') depth -= 1;
    if (char === ',' && depth === 0) {
      parts.push(current);
      current = '';
      continue;
    }
    current += char;
  }
  if (current.trim()) parts.push(current);
  return parts;
}
