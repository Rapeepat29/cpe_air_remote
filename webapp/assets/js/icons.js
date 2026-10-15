/**
 * ไอคอนทั้งหมดเป็น SVG เขียนเอง ไม่ดึงจากอินเทอร์เน็ต
 *
 * เหตุผลคือเว็บนี้อยู่หลัง Caddy ของเราเอง ถ้าไปพึ่งไลบรารีไอคอนจาก CDN
 * เวลาเน็ตมหาวิทยาลัยบล็อกโดเมนนั้น ไอคอนจะหายทั้งหน้าโดยไม่มีข้อความบอก
 */

const stroke = (path, size = 16, width = 2) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" ` +
  `stroke="currentColor" stroke-width="${width}" stroke-linecap="round" ` +
  `stroke-linejoin="round">${path}</svg>`;

export const icons = {
  bolt: (size = 16, width = 2.4) =>
    stroke('<path d="M13 2 4 14h6l-1 8 9-12h-6l1-8Z"/>', size, width),

  grid: (size = 16) =>
    stroke(
      '<rect x="3" y="3" width="7" height="9" rx="1.5"/>' +
        '<rect x="14" y="3" width="7" height="5" rx="1.5"/>' +
        '<rect x="14" y="12" width="7" height="9" rx="1.5"/>' +
        '<rect x="3" y="16" width="7" height="5" rx="1.5"/>',
      size,
    ),

  building: (size = 16) =>
    stroke(
      '<path d="M9 21V9a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v12"/>' +
        '<path d="M3 21h18"/><path d="M5 21V5a1 1 0 0 1 1-1h3"/>' +
        '<path d="M15 4h3a1 1 0 0 1 1 1v16"/>',
      size,
    ),

  calendar: (size = 16) =>
    stroke(
      '<rect x="3" y="4" width="18" height="17" rx="2"/>' +
        '<path d="M3 9h18M8 2v4M16 2v4"/>',
      size,
    ),

  compare: (size = 16) =>
    stroke(
      '<path d="M8 3 4 7l4 4"/><path d="M4 7h16"/>' +
        '<path d="m16 21 4-4-4-4"/><path d="M20 17H4"/>',
      size,
    ),

  coin: (size = 16) =>
    stroke(
      '<circle cx="12" cy="12" r="9"/><path d="M12 7v10"/>' +
        '<path d="M9 9.5c0-1.4 1.3-2.5 3-2.5s3 .9 3 2.2c0 1.6-1.4 2-3 2.3' +
        '-1.8.3-3 1-3 2.5S10.5 16.5 12 16.5s3-.7 3-2"/>',
      size,
    ),

  chart: (size = 16) =>
    stroke(
      '<path d="M3 3v18h18"/><path d="M7 15l3.5-4 3 2.5L20 7"/>',
      size,
    ),

  bell: (size = 16) =>
    stroke(
      '<path d="M18 8a6 6 0 1 0-12 0c0 7-3 8-3 8h18s-3-1-3-8"/>' +
        '<path d="M13.7 21a2 2 0 0 1-3.4 0"/>',
      size,
    ),

  // ชิปกับลูกศรขึ้น = อัปเดตเฟิร์มแวร์
  firmware: (size = 16) =>
    stroke(
      '<rect x="4" y="9" width="12" height="12" rx="2"/>' +
        '<path d="M7 9V6M13 9V6M4 13H1M4 17H1"/>' +
        '<path d="M19 13V3M15.5 6.5 19 3l3.5 3.5"/>',
      size,
    ),

  chip: (size = 16) =>
    stroke(
      '<rect x="7" y="7" width="10" height="10" rx="2"/>' +
        '<path d="M10 3v4M14 3v4M10 17v4M14 17v4M3 10h4M3 14h4M17 10h4' +
        'M17 14h4"/>',
      size,
    ),

  users: (size = 16) =>
    stroke(
      '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/>' +
        '<circle cx="9" cy="7" r="4"/>' +
        '<path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/>',
      size,
    ),

  gear: (size = 16) =>
    stroke(
      '<circle cx="12" cy="12" r="3"/>' +
        '<path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1' +
        'a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.6V21a2 2 0 1 1-4 0v-.1' +
        'a1.7 1.7 0 0 0-1-1.6 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1' +
        'a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.6-1H3a2 2 0 1 1 0-4h.1' +
        'a1.7 1.7 0 0 0 1.6-1 1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.8-2.8' +
        'l.1.1a1.7 1.7 0 0 0 1.9.3H9a1.7 1.7 0 0 0 1-1.6V3a2 2 0 1 1 4 0v.1' +
        'a1.7 1.7 0 0 0 1 1.6 1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8' +
        'l-.1.1a1.7 1.7 0 0 0-.3 1.9V9a1.7 1.7 0 0 0 1.6 1H21a2 2 0 1 1 0 4h-.1' +
        'a1.7 1.7 0 0 0-1.6 1Z"/>',
      size,
    ),

  warning: (size = 16, width = 2.4) =>
    stroke(
      '<path d="M10.3 3.9 2.6 18a1.7 1.7 0 0 0 1.5 2.6h15.8a1.7 1.7 0 0 0 ' +
        '1.5-2.6L13.7 3.9a1.7 1.7 0 0 0-3.4 0Z"/><path d="M12 9v4M12 17h.01"/>',
      size,
      width,
    ),

  pulseLine: (size = 16, width = 2.4) =>
    stroke('<path d="M2 12h6l3-9 4 18 3-9h4"/>', size, width),

  board: (size = 16, width = 2.4) =>
    stroke(
      '<rect x="2" y="7" width="16" height="10" rx="2"/>' +
        '<path d="M22 10v4M6 11v2"/>',
      size,
      width,
    ),

  clock: (size = 16, width = 2.4) =>
    stroke('<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>', size, width),

  close: (size = 14) => stroke('<path d="M18 6 6 18M6 6l12 12"/>', size, 2.3),

  menu: (size = 16) => stroke('<path d="M3 6h18M3 12h18M3 18h18"/>', size),

  refresh: (size = 15) =>
    stroke(
      '<path d="M4 12a8 8 0 0 1 14.9-4M20 12a8 8 0 0 1-14.9 4"/>' +
        '<path d="M18 4v4h-4M6 20v-4h4"/>',
      size,
      2.2,
    ),

  save: (size = 15) =>
    stroke(
      '<path d="M19 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11l5 5v11a2 2 0 0 1-2 2Z"/>' +
        '<path d="M17 21v-8H7v8M7 3v5h8"/>',
      size,
      2.4,
    ),

  download: (size = 15) =>
    stroke(
      '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>' +
        '<path d="M7 10l5 5 5-5M12 15V3"/>',
      size,
      2.2,
    ),

  meter: (size = 20) =>
    stroke(
      '<rect x="3" y="6" width="18" height="12" rx="2"/>' +
        '<path d="M7 6V4h10v2M7 18v2h10v-2"/>',
      size,
      2.2,
    ),

  person: (size = 15) =>
    stroke(
      '<circle cx="12" cy="8" r="4"/>' +
        '<path d="M4 21a8 8 0 0 1 16 0"/>',
      size,
    ),

  logout: (size = 15) =>
    stroke(
      '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>' +
        '<path d="M16 17l5-5-5-5M21 12H9"/>',
      size,
    ),

  plus: (size = 15) => stroke('<path d="M12 5v14M5 12h14"/>', size, 2.3),

  trash: (size = 14) =>
    stroke(
      '<path d="M3 6h18M8 6V4h8v2M19 6l-1 14H6L5 6"/>' +
        '<path d="M10 11v6M14 11v6"/>',
      size,
    ),

  edit: (size = 14) =>
    stroke(
      '<path d="M12 20h9"/>' +
        '<path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4Z"/>',
      size,
    ),

  check: (size = 14) => stroke('<path d="M20 6 9 17l-5-5"/>', size, 2.6),

  wifi: (size = 15) =>
    stroke(
      '<path d="M5 12.5a10 10 0 0 1 14 0M8.5 16a5 5 0 0 1 7 0"/>' +
        '<path d="M12 20h.01"/>',
      size,
      2.2,
    ),

  radar: (size = 15) =>
    stroke(
      '<circle cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="4.5"/>' +
        '<path d="M12 12 19 7"/>',
      size,
    ),
};
