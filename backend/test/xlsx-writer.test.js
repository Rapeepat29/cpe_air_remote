import assert from 'node:assert/strict';
import test from 'node:test';

import { strFromU8, unzipSync } from 'fflate';

import { buildXlsx, columnName, safeSheetName } from '../src/utils/xlsx-writer.js';

function openWorkbook(bytes) {
  const archive = unzipSync(bytes);
  return {
    names: Object.keys(archive).sort(),
    sheet: strFromU8(archive['xl/worksheets/sheet1.xml']),
    workbook: strFromU8(archive['xl/workbook.xml']),
  };
}

test('ไฟล์ที่ได้มีชิ้นส่วนครบตามที่ Excel ต้องการ', () => {
  const bytes = buildXlsx({
    header: ['data', 'time'],
    body: [['2026-08-21', '15:00-16:00']],
  });
  const { names } = openWorkbook(bytes);

  assert.deepEqual(names, [
    '[Content_Types].xml',
    '_rels/.rels',
    'xl/_rels/workbook.xml.rels',
    'xl/styles.xml',
    'xl/workbook.xml',
    'xl/worksheets/sheet1.xml',
  ]);
});

test('ข้อความไทยและตัวเลขถูกเขียนคนละชนิดกัน', () => {
  const bytes = buildXlsx({
    sheetName: 'ข้อมูลไฟฟ้า',
    header: ['พลังงานที่ใช้/kWh'],
    body: [[1.234]],
  });
  const { sheet, workbook } = openWorkbook(bytes);

  assert.match(workbook, /name="ข้อมูลไฟฟ้า"/);
  assert.match(sheet, /t="inlineStr"/, 'ข้อความใช้ inlineStr');
  assert.match(sheet, /<v>1\.234<\/v>/, 'ตัวเลขเก็บเป็นตัวเลขจริง');
  assert.equal(
    sheet.includes('<v>1.234</v></c><c'),
    false,
    'ตัวเลขไม่ควรถูกใส่เป็นข้อความ',
  );
});

test('อักขระพิเศษใน XML ถูก escape', () => {
  const bytes = buildXlsx({
    header: ['ห้อง & แอร์ <1>'],
    body: [['ปกติ']],
  });
  const { sheet } = openWorkbook(bytes);

  assert.match(sheet, /ห้อง &amp; แอร์ &lt;1&gt;/);
});

test('ช่องว่างกลายเป็นเซลล์ว่าง ไม่ใช่คำว่า null', () => {
  const bytes = buildXlsx({ header: ['a', 'b'], body: [[null, '']] });
  const { sheet } = openWorkbook(bytes);

  assert.equal(sheet.includes('null'), false);
  assert.match(sheet, /<c r="A2"\/>/);
});

test('ชื่อแท็บถูกตัดให้อยู่ในกติกาของ Excel', () => {
  assert.equal(safeSheetName('a/b:c*d?e[f]g'), 'a b c d e f g');
  assert.equal(safeSheetName('x'.repeat(50)).length, 31);
  assert.equal(safeSheetName(''), 'Sheet1');
  assert.equal(safeSheetName(null), 'Sheet1');
});

test('ชื่อคอลัมน์ไล่ต่อจาก Z ไป AA ได้ถูกต้อง', () => {
  assert.equal(columnName(0), 'A');
  assert.equal(columnName(25), 'Z');
  assert.equal(columnName(26), 'AA');
  assert.equal(columnName(27), 'AB');
  assert.equal(columnName(51), 'AZ');
  assert.equal(columnName(52), 'BA');
});
