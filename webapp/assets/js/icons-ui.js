/**
 * ไอคอนชุดเพิ่มเติมสำหรับปุ่มสลับธีม ช่องค้นหา และแถบเมนูล่างบนมือถือ
 *
 * แยกจาก icons.js โดยตั้งใจ: Caddy ให้เบราว์เซอร์แคชไฟล์ใน /assets ไว้หนึ่งชั่วโมง
 * ถ้าเพิ่มไอคอนลงไฟล์เดิม คนที่เปิดเว็บไว้ก่อน deploy อาจได้ app.js ตัวใหม่
 * คู่กับ icons.js ตัวเก่าที่ยังไม่มีไอคอนนี้ แล้วหน้าเว็บพังทั้งหน้า
 * ไฟล์ใหม่ไม่เคยถูกแคช จึงได้ของใหม่เสมอ
 */

const stroke = (path, size = 16, width = 2) =>
  `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" ` +
  `stroke="currentColor" stroke-width="${width}" stroke-linecap="round" ` +
  `stroke-linejoin="round" aria-hidden="true">${path}</svg>`;

export const uiIcons = {
  sun: (size = 16) =>
    stroke(
      '<circle cx="12" cy="12" r="4"/>' +
        '<path d="M12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4' +
        'M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
      size,
    ),

  moon: (size = 16) =>
    stroke('<path d="M20.5 14.5A8.5 8.5 0 1 1 9.5 3.5a7 7 0 0 0 11 11Z"/>', size),

  search: (size = 16) =>
    stroke('<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>', size),

  more: (size = 16) =>
    stroke(
      '<rect x="3" y="3" width="7" height="7" rx="1.5"/>' +
        '<rect x="14" y="3" width="7" height="7" rx="1.5"/>' +
        '<rect x="3" y="14" width="7" height="7" rx="1.5"/>' +
        '<rect x="14" y="14" width="7" height="7" rx="1.5"/>',
      size,
    ),

  textSize: (size = 16) =>
    stroke('<path d="M4 7V5h10v2M9 5v14M7 19h4M14 12v-1h6v1M17 11v8M15.5 19h3"/>', size),
};
