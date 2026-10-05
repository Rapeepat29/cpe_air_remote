/**
 * ค่าตั้งของเว็บแอป
 *
 * `API_BASE` เป็น '/api' เพราะเว็บกับ API อยู่โดเมนเดียวกัน (Caddy ส่ง /api/*
 * ต่อไปให้ backend ส่วนที่เหลือเสิร์ฟไฟล์นี้) พอเป็นโดเมนเดียวกันจึงไม่ติด CORS
 * และไม่ต้องฝังที่อยู่เซิร์ฟเวอร์ไว้ในโค้ด ย้ายโดเมนก็ไม่ต้องแก้ไฟล์
 *
 * ตอนพัฒนาบนเครื่องตัวเอง ให้เปิดหน้าเว็บด้วย `?api=http://127.0.0.1:3000/api`
 * ครั้งเดียว ค่าจะถูกจำไว้ใน localStorage จนกว่าจะสั่งล้าง
 *
 * ค่า `?api=` ใช้ได้เฉพาะตอนเปิดหน้าเว็บจากเครื่องตัวเอง (localhost/127.0.0.1)
 * ถ้าเปิดจากโดเมนจริงแล้วยอมรับค่านี้ ใครส่งลิงก์ที่ต่อท้าย `?api=<เว็บอื่น>` มา
 * เบราว์เซอร์จะจำไว้และส่ง Username/Password ไปที่อื่นทุกครั้งที่เข้าสู่ระบบ
 */

const STORAGE_API = 'rmutt.apiBase';

const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '[::1]', '::1']);

function isLocalPage() {
  return LOCAL_HOSTS.has(window.location.hostname);
}

/** รับเฉพาะ path บนโดเมนเดียวกัน หรือ URL แบบ http/https เท่านั้น */
function normalizeApiBase(value) {
  const text = String(value ?? '').trim();
  if (!text) return null;
  if (text.startsWith('/') && !text.startsWith('//')) {
    return text.replace(/\/+$/, '') || '/api';
  }
  try {
    const url = new URL(text);
    if (url.protocol !== 'http:' && url.protocol !== 'https:') return null;
    return url.href.replace(/\/+$/, '');
  } catch {
    return null;
  }
}

function resolveApiBase() {
  try {
    if (!isLocalPage()) {
      // ล้างค่าที่อาจถูกฝังไว้จากลิงก์แปลก ๆ ก่อนหน้านี้ แล้วใช้ API ของโดเมนนี้เสมอ
      window.localStorage.removeItem(STORAGE_API);
      return '/api';
    }
    const fromQuery = normalizeApiBase(
      new URLSearchParams(window.location.search).get('api'),
    );
    if (fromQuery) {
      window.localStorage.setItem(STORAGE_API, fromQuery);
      return fromQuery;
    }
    const saved = normalizeApiBase(window.localStorage.getItem(STORAGE_API));
    if (saved) return saved;
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
