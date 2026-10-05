/**
 * ธีมสีของเว็บ: เทา (ค่าเริ่มต้น) ขาว ดำ เขียว และ "ตามเครื่อง"
 *
 * แยกจาก prefs.js เป็นไฟล์ใหม่เพราะไฟล์ใน /assets ถูกแคชหนึ่งชั่วโมง
 * ถ้าเพิ่ม export ใหม่ลงไฟล์เดิม เบราว์เซอร์ที่ยังถือไฟล์เก่าจะหา export ไม่เจอ
 * แล้วทั้งเว็บจะขึ้นจอขาว
 *
 * ค่าที่เลือกถูกใส่เป็น data-palette บน <html> (ไม่ใช่ data-theme) เพื่อให้
 * prefs.js รุ่นเก่าที่อาจค้างในแคชและยังเขียน data-theme="dark" อยู่
 * ไม่ไปทับธีมใหม่ สีจริงทั้งหมดอยู่ใน tokens.css
 *
 * เก็บใน localStorage ของเครื่องนี้ ไม่ส่งขึ้นเซิร์ฟเวอร์
 */

import { el } from './dom.js';

const STORAGE_KEY = 'rmutt.palette';
const LEGACY_KEY = 'rmutt.theme';

/** สีของตัวอย่างในปุ่มเลือก และสีแถบเบราว์เซอร์บนมือถือของแต่ละธีม */
export const THEMES = [
  { key: 'gray', label: 'เทา', swatch: '#2f3438', meta: '#2a2f33', desc: 'โทนเดียวกับพื้นโลโก้ สบายตาทั้งวัน' },
  { key: 'white', label: 'ขาว', swatch: '#ffffff', meta: '#f3f5f6', desc: 'สว่าง อ่านง่ายในห้องที่แสงจ้า' },
  { key: 'black', label: 'ดำ', swatch: '#0b0d0e', meta: '#0b0d0e', desc: 'มืดสนิท สำหรับจอที่เปิดค้างตอนกลางคืน' },
  { key: 'green', label: 'เขียว', swatch: '#0e5a34', meta: '#0e5a34', desc: 'เมนูเขียวเข้ม เนื้อหาพื้นสว่าง' },
];

/** ตามเครื่อง: เครื่องตั้งโหมดสว่างใช้ขาว โหมดมืดใช้เทา */
export const AUTO = { key: 'auto', label: 'ตามเครื่อง', desc: 'เครื่องโหมดสว่างใช้ ขาว โหมดมืดใช้ เทา' };

export const THEME_CHOICES = [...THEMES, AUTO];

const listeners = new Set();
const darkQuery =
  typeof window.matchMedia === 'function'
    ? window.matchMedia('(prefers-color-scheme: dark)')
    : null;

function isChoice(value) {
  return THEME_CHOICES.some((item) => item.key === value);
}

function readStored() {
  try {
    const value = window.localStorage.getItem(STORAGE_KEY);
    if (isChoice(value)) return value;
    // ค่าจากรุ่นก่อน: มืด → เทา, สว่าง → ขาว
    const legacy = window.localStorage.getItem(LEGACY_KEY);
    if (legacy === 'light') return 'white';
    if (legacy === 'dark') return 'gray';
  } catch {
    // อ่าน localStorage ไม่ได้ (โหมดส่วนตัวบางแบบ) ใช้ค่าเริ่มต้น
  }
  return 'gray';
}

let choice = readStored();

/** ค่าที่ผู้ใช้เลือก (อาจเป็น auto) */
export function themeChoice() {
  return choice;
}

/** ธีมที่ใช้อยู่จริงตอนนี้ (auto ถูกแปลงเป็นธีมจริงแล้ว) */
export function activeTheme() {
  if (choice !== 'auto') return choice;
  return darkQuery?.matches === false ? 'white' : 'gray';
}

export function applyTheme() {
  const key = activeTheme();
  document.documentElement.dataset.palette = key;
  const meta = document.querySelector('meta[name="theme-color"]');
  const theme = THEMES.find((item) => item.key === key);
  if (meta && theme) meta.setAttribute('content', theme.meta);
}

export function setTheme(key) {
  if (!isChoice(key)) return;
  choice = key;
  try {
    window.localStorage.setItem(STORAGE_KEY, key);
  } catch {
    // เขียนไม่ได้ก็ใช้ได้แค่ในแท็บนี้
  }
  applyTheme();
  notify();
}

/** แจ้งเมื่อธีมเปลี่ยน (ปุ่มบนแถบบนกับหน้าตั้งค่าต้องเห็นตรงกัน) */
export function onThemeChange(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

function notify() {
  for (const listener of listeners) listener(choice);
}

// ผู้ใช้เลือก "ตามเครื่อง" แล้วเครื่องสลับโหมดมืด/สว่างเอง (เช่นตอนค่ำ)
darkQuery?.addEventListener?.('change', () => {
  if (choice !== 'auto') return;
  applyTheme();
  notify();
});

/**
 * จุดสีสี่จุดสำหรับเลือกธีม ใช้บนแถบบน
 * กดจุดที่เลือกอยู่แล้วไม่มีผลอะไร ส่วน "ตามเครื่อง" อยู่ในหน้าตั้งค่า
 */
export function themeDots() {
  const current = activeTheme();
  return el(
    'div',
    { class: 'theme-dots', role: 'radiogroup', 'aria-label': 'ธีมสี' },
    THEMES.map((theme) =>
      el(
        'button',
        {
          class: `theme-dot${theme.key === current ? ' sel' : ''}`,
          type: 'button',
          role: 'radio',
          'aria-checked': theme.key === current ? 'true' : 'false',
          'aria-label': `ธีม${theme.label}`,
          title: `ธีม${theme.label}`,
          onclick: () => setTheme(theme.key),
        },
        [el('span', { style: { background: theme.swatch } })],
      ),
    ),
  );
}
