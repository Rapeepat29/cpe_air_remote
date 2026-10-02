/**
 * ค่าตั้งของเว็บแอป
 *
 * `API_BASE` เป็น '/api' เพราะเว็บกับ API อยู่โดเมนเดียวกัน (Caddy ส่ง /api/*
 * ต่อไปให้ backend ส่วนที่เหลือเสิร์ฟไฟล์นี้) พอเป็นโดเมนเดียวกันจึงไม่ติด CORS
 * และไม่ต้องฝังที่อยู่เซิร์ฟเวอร์ไว้ในโค้ด ย้ายโดเมนก็ไม่ต้องแก้ไฟล์
 *
 * ตอนพัฒนาบนเครื่องตัวเอง ให้เปิดหน้าเว็บด้วย `?api=http://127.0.0.1:3000/api`
 * ครั้งเดียว ค่าจะถูกจำไว้ใน localStorage จนกว่าจะสั่งล้าง
 */

const STORAGE_API = 'rmutt.apiBase';

function resolveApiBase() {
  try {
    const fromQuery = new URLSearchParams(window.location.search).get('api');
    if (fromQuery) {
      window.localStorage.setItem(STORAGE_API, fromQuery);
      return fromQuery.replace(/\/+$/, '');
    }
    const saved = window.localStorage.getItem(STORAGE_API);
    if (saved) return saved.replace(/\/+$/, '');
  } catch {
    // เบราว์เซอร์บล็อก localStorage (โหมดส่วนตัว) ใช้ค่าเริ่มต้นต่อไปได้
  }
  return '/api';
}

export const API_BASE = resolveApiBase();

/** คีย์ที่ใช้เก็บของในเครื่องผู้ใช้ รวมไว้ที่เดียวกันเพื่อกันตั้งชื่อชนกัน */
export const STORAGE = {
  token: 'rmutt.token',
  user: 'rmutt.user',
  lastView: 'rmutt.view',
  apiBase: STORAGE_API,
};

/** จังหวะดึงข้อมูลใหม่ (มิลลิวินาที) */
export const POLL = {
  /** ค่าไฟและสถานะเครื่อง ต้องสดพอจะเห็นแอร์เปิด-ปิด */
  live: 10000,
  /** ห้อง เซ็นเซอร์ และนาฬิกาปิดอัตโนมัติ */
  rooms: 10000,
  /** การแจ้งเตือน ไม่ต้องถี่เท่า */
  alerts: 30000,
  /** สรุปค่าไฟรายช่วง เปลี่ยนช้ามาก */
  summary: 120000,
};

export const BUILDING = {
  name: 'อาคาร 16',
  subtitle: 'คณะวิศวกรรมศาสตร์ · มทร.ธัญบุรี',
};
