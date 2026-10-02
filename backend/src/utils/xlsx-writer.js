import { strToU8, zipSync } from 'fflate';

// ตัวเขียนไฟล์ .xlsx แบบเล็กที่สุดเท่าที่ Excel เปิดได้จริง
//
// ใช้ fflate ที่โปรเจกต์มีอยู่แล้ว จึงไม่ต้องเพิ่ม dependency ใหม่
// เขียนข้อความแบบ inlineStr ทำให้ไม่ต้องมี sharedStrings.xml
// รองรับภาษาไทยเพราะทุกไฟล์ในแพ็กเกจเป็น UTF-8

const MAX_COLUMNS = 64;
const MAX_ROWS = 200000;

/**
 * @param {object} options
 * @param {string} options.sheetName ชื่อแท็บในไฟล์
 * @param {string[]} options.header แถวหัวตาราง
 * @param {Array<Array<string|number|null>>} options.body เนื้อตาราง
 * @param {Array<{key:string,label:string}>} [options.info] แถวสรุปด้านบน
 * @returns {Uint8Array} ไบต์ของไฟล์ .xlsx
 */
export function buildXlsx({ sheetName = 'Sheet1', header = [], body = [] }) {
  if (body.length > MAX_ROWS) {
    throw new RangeError('ข้อมูลเกินขนาดที่ส่งออกได้ในครั้งเดียว');
  }

  const rows = [header, ...body];
  const columnCount = Math.min(
    MAX_COLUMNS,
    rows.reduce((max, row) => Math.max(max, row.length), 0),
  );

  const sheetRows = rows
    .map((row, index) => renderRow(row, index + 1, columnCount, index === 0))
    .join('');

  const widths = columnWidths(rows, columnCount);

  const sheetXml = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`
    + `<worksheet xmlns="http://schemas.openxmlformats.org/`
    + `spreadsheetml/2006/main">`
    + `<sheetViews><sheetView workbookViewId="0">`
    + `<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" `
    + `state="frozen"/></sheetView></sheetViews>`
    + (widths ? `<cols>${widths}</cols>` : '')
    + `<sheetData>${sheetRows}</sheetData>`
    + `</worksheet>`;

  const files = {
    '[Content_Types].xml': strToU8(CONTENT_TYPES),
    '_rels/.rels': strToU8(ROOT_RELS),
    'xl/workbook.xml': strToU8(workbookXml(sheetName)),
    'xl/_rels/workbook.xml.rels': strToU8(WORKBOOK_RELS),
    'xl/styles.xml': strToU8(STYLES),
    'xl/worksheets/sheet1.xml': strToU8(sheetXml),
  };

  return zipSync(files, { level: 6 });
}

function renderRow(row, rowNumber, columnCount, isHeader) {
  let cells = '';
  for (let index = 0; index < columnCount; index += 1) {
    const reference = `${columnName(index)}${rowNumber}`;
    cells += renderCell(reference, row[index], isHeader);
  }
  return `<row r="${rowNumber}">${cells}</row>`;
}

function renderCell(reference, value, isHeader) {
  const style = isHeader ? ' s="1"' : '';
  if (value == null || value === '') {
    return `<c r="${reference}"${style}/>`;
  }
  if (typeof value === 'number' && Number.isFinite(value)) {
    return `<c r="${reference}"${style}><v>${value}</v></c>`;
  }
  return `<c r="${reference}"${style} t="inlineStr">`
    + `<is><t xml:space="preserve">${escapeXml(value)}</t></is></c>`;
}

function columnWidths(rows, columnCount) {
  let xml = '';
  for (let index = 0; index < columnCount; index += 1) {
    let longest = 8;
    for (const row of rows) {
      const text = row[index] == null ? '' : String(row[index]);
      if (text.length > longest) longest = text.length;
    }
    const width = Math.min(42, Math.max(10, longest + 3));
    xml += `<col min="${index + 1}" max="${index + 1}" `
      + `width="${width}" customWidth="1"/>`;
  }
  return xml;
}

export function columnName(index) {
  let value = index;
  let name = '';
  do {
    name = String.fromCharCode(65 + (value % 26)) + name;
    value = Math.floor(value / 26) - 1;
  } while (value >= 0);
  return name;
}

function escapeXml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;')
    // อักขระควบคุมทำให้ Excel ฟ้องว่าไฟล์เสีย จึงตัดทิ้ง
    .replace(/[\u0000-\u0008\u000B\u000C\u000E-\u001F]/g, '');
}

function workbookXml(sheetName) {
  return `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`
    + `<workbook xmlns="http://schemas.openxmlformats.org/`
    + `spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/`
    + `officeDocument/2006/relationships">`
    + `<sheets><sheet name="${escapeXml(safeSheetName(sheetName))}" `
    + `sheetId="1" r:id="rId1"/></sheets>`
    + `</workbook>`;
}

export function safeSheetName(value) {
  const text = String(value ?? 'Sheet1')
    .replace(/[\\/*?:[\]]/g, ' ')
    .trim();
  return (text || 'Sheet1').slice(0, 31);
}

const CONTENT_TYPES = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`
  + `<Types xmlns="http://schemas.openxmlformats.org/package/2006/`
  + `content-types">`
  + `<Default Extension="rels" ContentType="application/vnd.openxmlformats-`
  + `package.relationships+xml"/>`
  + `<Default Extension="xml" ContentType="application/xml"/>`
  + `<Override PartName="/xl/workbook.xml" ContentType="application/`
  + `vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>`
  + `<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/`
  + `vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>`
  + `<Override PartName="/xl/styles.xml" ContentType="application/`
  + `vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>`
  + `</Types>`;

const ROOT_RELS = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`
  + `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/`
  + `relationships">`
  + `<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/`
  + `officeDocument/2006/relationships/officeDocument" Target="xl/`
  + `workbook.xml"/>`
  + `</Relationships>`;

const WORKBOOK_RELS = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`
  + `<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/`
  + `relationships">`
  + `<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/`
  + `officeDocument/2006/relationships/worksheet" Target="worksheets/`
  + `sheet1.xml"/>`
  + `<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/`
  + `officeDocument/2006/relationships/styles" Target="styles.xml"/>`
  + `</Relationships>`;

// สไตล์ 0 คือปกติ สไตล์ 1 คือหัวตารางตัวหนาพื้นเทา
const STYLES = `<?xml version="1.0" encoding="UTF-8" standalone="yes"?>`
  + `<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/`
  + `2006/main">`
  + `<fonts count="2">`
  + `<font><sz val="11"/><name val="Tahoma"/></font>`
  + `<font><b/><sz val="11"/><name val="Tahoma"/></font>`
  + `</fonts>`
  + `<fills count="3">`
  + `<fill><patternFill patternType="none"/></fill>`
  + `<fill><patternFill patternType="gray125"/></fill>`
  + `<fill><patternFill patternType="solid">`
  + `<fgColor rgb="FFDCE9DC"/><bgColor indexed="64"/></patternFill></fill>`
  + `</fills>`
  + `<borders count="1"><border><left/><right/><top/><bottom/>`
  + `<diagonal/></border></borders>`
  + `<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" `
  + `borderId="0"/></cellStyleXfs>`
  + `<cellXfs count="2">`
  + `<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>`
  + `<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" `
  + `applyFont="1" applyFill="1"/>`
  + `</cellXfs>`
  + `<cellStyles count="1"><cellStyle name="Normal" xfId="0" `
  + `builtinId="0"/></cellStyles>`
  + `<dxfs count="0"/>`
  + `</styleSheet>`;
