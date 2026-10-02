/**
 * ค่าการแสดงผลของผู้ใช้แต่ละเครื่อง: ธีม (มืด/สว่าง) และขนาดตัวอักษร
 *
 * เก็บใน localStorage ของเบราว์เซอร์ ไม่ส่งขึ้นเซิร์ฟเวอร์ เพราะเป็นเรื่องของ
 * "จอเครื่องนี้" ไม่ใช่ของบัญชี — คนเดียวกันอาจอยากได้ธีมสว่างบนคอมในห้องทำงาน
 * แต่ธีมมืดบนมือถือตอนกลางคืน
 *
 * ค่าถูกใส่เป็น data-theme / data-text บน <html> แล้ว tokens.css จัดการต่อ
 * ไม่มีหน้าไหนต้องรู้ว่าตอนนี้ธีมอะไร เพราะทุกสีอ่านจากตัวแปร CSS
 *
 * คีย์ localStorage ประกาศไว้ในไฟล์นี้เอง ไม่ฝากไว้ใน config.js เพราะไฟล์ใน
 * /assets ถูกแคชหนึ่งชั่วโมง ถ้าเบราว์เซอร์ยังถือ config.js ตัวเก่าอยู่
 * จะไม่มีคีย์ใหม่ให้อ่าน
 */

const STORAGE = {
  theme: 'rmutt.theme',
  textSize: 'rmutt.textSize',
};

export const THEMES = [
  { key: 'dark', label: 'มืด' },
  { key: 'light', label: 'สว่าง' },
];

export const TEXT_SIZES = [
  { key: 'normal', label: 'ปกติ' },
  { key: 'large', label: 'ใหญ่' },
  { key: 'xlarge', label: 'ใหญ่มาก' },
];

const listeners = new Set();

function read(key, allowed, fallback) {
  try {
    const value = window.localStorage.getItem(key);
    return allowed.some((item) => item.key === value) ? value : fallback;
  } catch {
    return fallback;
  }
}

function write(key, value) {
  try {
    window.localStorage.setItem(key, value);
  } catch {
    // โหมดส่วนตัวเขียนไม่ได้ ก็ใช้ได้แค่ในแท็บนี้
  }
}

export const prefs = {
  theme: read(STORAGE.theme, THEMES, 'dark'),
  textSize: read(STORAGE.textSize, TEXT_SIZES, 'normal'),
};

/** ใส่ค่าลง <html> เรียกครั้งแรกก่อนวาดหน้าจอ และทุกครั้งที่ค่าเปลี่ยน */
export function applyPrefs() {
  const root = document.documentElement;
  root.dataset.theme = prefs.theme;
  if (prefs.textSize === 'normal') delete root.dataset.text;
  else root.dataset.text = prefs.textSize;

  // สีของแถบเบราว์เซอร์บนมือถือให้กลืนกับหัวเว็บ
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', prefs.theme === 'light' ? '#f2f5f3' : '#060d09');
}

export function setTheme(theme) {
  if (!THEMES.some((item) => item.key === theme)) return;
  prefs.theme = theme;
  write(STORAGE.theme, theme);
  applyPrefs();
  notify();
}

export function toggleTheme() {
  setTheme(prefs.theme === 'light' ? 'dark' : 'light');
}

export function setTextSize(size) {
  if (!TEXT_SIZES.some((item) => item.key === size)) return;
  prefs.textSize = size;
  write(STORAGE.textSize, size);
  applyPrefs();
  notify();
}

/** แจ้งเมื่อค่าเปลี่ยน (ปุ่มบนแถบบนกับหน้าตั้งค่าต้องเห็นตรงกัน) */
export function onPrefsChange(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function notify() {
  for (const listener of listeners) listener(prefs);
}
