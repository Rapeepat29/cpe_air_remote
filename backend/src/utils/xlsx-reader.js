import { strFromU8, unzipSync } from 'fflate';
import { XMLParser } from 'fast-xml-parser';

import { ApiError } from './http.js';

const MAX_UNCOMPRESSED_BYTES = 32 * 1024 * 1024;
const MAX_ZIP_ENTRIES = 2000;
const MAX_MERGED_CELLS = 10000;
const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '',
  removeNSPrefix: true,
  parseTagValue: false,
  trimValues: false,
  processEntities: false,
});

export function readXlsxWorksheets(buffer) {
  assertSafeZipDirectory(buffer);

  let archive;
  try {
    archive = unzipSync(new Uint8Array(buffer), {
      filter(file) {
        const name = normalizeArchivePath(file.name);
        return name === 'xl/workbook.xml'
          || name === 'xl/_rels/workbook.xml.rels'
          || name === 'xl/sharedStrings.xml'
          || /^xl\/worksheets\/[^/]+\.xml$/i.test(name);
      },
    });
  } catch {
    throw invalidWorkbookError();
  }

  const workbookDocument = parseXmlFile(archive, 'xl/workbook.xml');
  const relationshipDocument = parseXmlFile(
    archive,
    'xl/_rels/workbook.xml.rels',
  );
  const sharedStrings = archive['xl/sharedStrings.xml']
    ? readSharedStrings(archive['xl/sharedStrings.xml'])
    : [];
  const relationships = readRelationships(relationshipDocument);
  const sheetNodes = asArray(workbookDocument.workbook?.sheets?.sheet);

  if (sheetNodes.length === 0) {
    throw invalidWorkbookError();
  }

  const worksheets = [];
  for (const sheetNode of sheetNodes) {
    const name = String(sheetNode?.name ?? '').trim();
    const relationshipId = String(sheetNode?.id ?? '').trim();
    const target = relationships.get(relationshipId);
    const archivePath = resolveWorksheetPath(target);
    if (!name || !archivePath || !archive[archivePath]) {
      throw invalidWorkbookError();
    }

    worksheets.push(
      readWorksheet(name, archive[archivePath], sharedStrings),
    );
  }
  return worksheets;
}

function readWorksheet(name, bytes, sharedStrings) {
  const document = parseXmlBytes(bytes);
  const worksheetNode = document.worksheet;
  const cells = new Map();
  const merges = new Map();
  let rowCount = 0;
  let columnCount = 0;

  for (const rowNode of asArray(worksheetNode?.sheetData?.row)) {
    for (const cellNode of asArray(rowNode?.c)) {
      const address = normalizeCellAddress(cellNode?.r);
      if (!address) continue;

      const position = parseCellAddress(address);
      if (!position) continue;
      rowCount = Math.max(rowCount, position.row);
      columnCount = Math.max(columnCount, position.column);
      cells.set(address, readCellValue(cellNode, sharedStrings));
    }
  }

  for (const mergeNode of asArray(worksheetNode?.mergeCells?.mergeCell)) {
    const range = parseCellRange(mergeNode?.ref);
    if (!range) continue;
    const area =
      (range.endRow - range.startRow + 1)
      * (range.endColumn - range.startColumn + 1);
    if (area > MAX_MERGED_CELLS) {
      throw invalidWorkbookError();
    }

    rowCount = Math.max(rowCount, range.endRow);
    columnCount = Math.max(columnCount, range.endColumn);
    for (let row = range.startRow; row <= range.endRow; row += 1) {
      for (
        let column = range.startColumn;
        column <= range.endColumn;
        column += 1
      ) {
        merges.set(cellAddress(row, column), range);
      }
    }
  }

  return {
    name,
    cells,
    merges,
    rowCount,
    columnCount,
  };
}

function readRelationships(document) {
  const relationships = new Map();
  for (
    const relationship of asArray(
      document.Relationships?.Relationship,
    )
  ) {
    const id = String(relationship?.Id ?? '').trim();
    const target = String(relationship?.Target ?? '').trim();
    if (id && target) {
      relationships.set(id, target);
    }
  }
  return relationships;
}

function readSharedStrings(bytes) {
  const document = parseXmlBytes(bytes);
  return asArray(document.sst?.si).map(readTextNode);
}

function readCellValue(cellNode, sharedStrings) {
  const type = String(cellNode?.t ?? '');
  if (type === 'inlineStr') {
    return readTextNode(cellNode?.is);
  }

  const rawValue = readTextNode(cellNode?.v);
  if (type === 's') {
    const index = Number.parseInt(rawValue, 10);
    return Number.isInteger(index) ? sharedStrings[index] ?? '' : '';
  }
  if (type === 'b') {
    return rawValue === '1' ? 'TRUE' : 'FALSE';
  }
  return rawValue;
}

function readTextNode(node) {
  if (node == null) return '';
  if (typeof node === 'string' || typeof node === 'number') {
    return String(node);
  }
  if (Array.isArray(node)) {
    return node.map(readTextNode).join('');
  }
  if (typeof node !== 'object') return '';
  if (node['#text'] != null) {
    return String(node['#text']);
  }
  if (node.t != null) {
    return readTextNode(node.t);
  }
  if (node.r != null) {
    return asArray(node.r).map(readTextNode).join('');
  }
  return '';
}

function parseXmlFile(archive, name) {
  const bytes = archive[name];
  if (!bytes) throw invalidWorkbookError();
  return parseXmlBytes(bytes);
}

function parseXmlBytes(bytes) {
  try {
    return parser.parse(strFromU8(bytes));
  } catch {
    throw invalidWorkbookError();
  }
}

function resolveWorksheetPath(target) {
  if (!target) return '';
  const normalized = normalizeArchivePath(target).replace(/^\/+/, '');
  const path = normalized.startsWith('xl/')
    ? normalized
    : `xl/${normalized.replace(/^(\.\.\/)+/, '')}`;
  if (!/^xl\/worksheets\/[^/]+\.xml$/i.test(path)) {
    return '';
  }
  return path;
}

function normalizeArchivePath(value) {
  return String(value ?? '').replaceAll('\\', '/').replace(/^\/+/, '');
}

function normalizeCellAddress(value) {
  const address = String(value ?? '').replaceAll('$', '').toUpperCase();
  return /^[A-Z]{1,3}[1-9]\d*$/.test(address) ? address : '';
}

function parseCellRange(value) {
  const [startText, endText = startText] = String(value ?? '').split(':');
  const start = parseCellAddress(normalizeCellAddress(startText));
  const end = parseCellAddress(normalizeCellAddress(endText));
  if (!start || !end) return null;
  if (end.row < start.row || end.column < start.column) return null;
  return {
    startRow: start.row,
    startColumn: start.column,
    endRow: end.row,
    endColumn: end.column,
    masterAddress: cellAddress(start.row, start.column),
  };
}

function parseCellAddress(address) {
  const match = String(address ?? '').match(/^([A-Z]{1,3})([1-9]\d*)$/);
  if (!match) return null;
  let column = 0;
  for (const character of match[1]) {
    column = column * 26 + character.charCodeAt(0) - 64;
  }
  return {
    row: Number.parseInt(match[2], 10),
    column,
  };
}

export function cellAddress(row, column) {
  let letters = '';
  let value = column;
  while (value > 0) {
    value -= 1;
    letters = String.fromCharCode(65 + (value % 26)) + letters;
    value = Math.floor(value / 26);
  }
  return `${letters}${row}`;
}

function assertSafeZipDirectory(buffer) {
  const view = new DataView(
    buffer.buffer,
    buffer.byteOffset,
    buffer.byteLength,
  );
  const minimumOffset = Math.max(0, buffer.byteLength - 65557);
  let endOffset = -1;
  for (
    let offset = buffer.byteLength - 22;
    offset >= minimumOffset;
    offset -= 1
  ) {
    if (view.getUint32(offset, true) === 0x06054b50) {
      endOffset = offset;
      break;
    }
  }
  if (endOffset < 0) throw invalidWorkbookError();

  const entryCount = view.getUint16(endOffset + 10, true);
  const directorySize = view.getUint32(endOffset + 12, true);
  const directoryOffset = view.getUint32(endOffset + 16, true);
  if (
    entryCount > MAX_ZIP_ENTRIES
    || directoryOffset + directorySize > buffer.byteLength
  ) {
    throw invalidWorkbookError();
  }

  let offset = directoryOffset;
  let totalUncompressed = 0;
  for (let index = 0; index < entryCount; index += 1) {
    if (
      offset + 46 > buffer.byteLength
      || view.getUint32(offset, true) !== 0x02014b50
    ) {
      throw invalidWorkbookError();
    }
    totalUncompressed += view.getUint32(offset + 24, true);
    if (totalUncompressed > MAX_UNCOMPRESSED_BYTES) {
      throw new ApiError(400, 'ไฟล์ Excel มีข้อมูลภายในมากเกินไป');
    }

    const fileNameLength = view.getUint16(offset + 28, true);
    const extraLength = view.getUint16(offset + 30, true);
    const commentLength = view.getUint16(offset + 32, true);
    offset += 46 + fileNameLength + extraLength + commentLength;
  }
}

function asArray(value) {
  if (value == null) return [];
  return Array.isArray(value) ? value : [value];
}

function invalidWorkbookError() {
  return new ApiError(
    400,
    'เปิดไฟล์ Excel ไม่สำเร็จ กรุณาตรวจว่าเป็นไฟล์ .xlsx ที่ไม่เสียหาย',
  );
}
