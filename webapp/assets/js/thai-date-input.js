/**
 * ช่องวันที่แบบ พ.ศ.
 *
 * ใช้แทน <input type="date"> ของเบราว์เซอร์ ซึ่งแสดงปี ค.ศ. ตามเครื่อง
 * (คนพิมพ์ 2569 แล้วได้ปี ค.ศ. 2569 จริง ๆ) ช่องนี้พิมพ์ได้ทั้ง วว/ดด/ปปปป พ.ศ.
 * หรือกดปุ่มปฏิทินเพื่อแตะเลือกก็ได้
 *
 * ค่าที่อ่านและเขียนผ่าน `.value` เป็น YYYY-MM-DD (ค.ศ.) เหมือน input เดิมทุกอย่าง
 * โค้ดส่วนอื่นและ API จึงไม่ต้องเปลี่ยน
 */

import { el, replace } from './dom.js';

const BE_OFFSET = 543;
const MONTHS = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];
const WEEKDAYS = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

const two = (n) => String(n).padStart(2, '0');

function isoOf(year, month, day) {
  return `${year}-${two(month)}-${two(day)}`;
}

function partsOf(iso) {
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(iso ?? ''));
  if (!match) return null;
  return { year: Number(match[1]), month: Number(match[2]), day: Number(match[3]) };
}

/** YYYY-MM-DD (ค.ศ.) → วว/ดด/ปปปป (พ.ศ.) */
export function isoToThaiText(iso) {
  const parts = partsOf(iso);
  if (!parts) return '';
  return `${two(parts.day)}/${two(parts.month)}/${parts.year + BE_OFFSET}`;
}

/**
 * วว/ดด/ปปปป → YYYY-MM-DD (ค.ศ.) คืน null ถ้าผิดรูปแบบหรือไม่มีวันนั้นจริง
 * ปีตั้งแต่ 2400 ถือเป็น พ.ศ. คนพิมพ์ ค.ศ. ก็ยังใช้ได้
 */
export function thaiTextToIso(text) {
  const match = /^\s*(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})\s*$/.exec(String(text ?? ''));
  if (!match) return null;
  const day = Number(match[1]);
  const month = Number(match[2]);
  let year = Number(match[3]);
  if (year >= 2400) year -= BE_OFFSET;
  const date = new Date(year, month - 1, day);
  if (
    date.getFullYear() !== year ||
    date.getMonth() !== month - 1 ||
    date.getDate() !== day
  ) {
    return null;
  }
  return isoOf(year, month, day);
}

let openPopover = null;

/**
 * สร้างช่องวันที่
 *
 * @param {object} options
 * @param {string} [options.name]       ชื่อช่อง (ใช้กับ label for=)
 * @param {string} [options.value]      ค่าเริ่มต้น YYYY-MM-DD
 * @param {string} [options.min]        วันแรกที่เลือกได้ YYYY-MM-DD
 * @param {string} [options.max]        วันสุดท้ายที่เลือกได้ YYYY-MM-DD
 * @param {(iso: string) => void} [options.onChange] เรียกเมื่อได้วันที่ที่ถูกต้อง
 * @returns {HTMLElement} อิลิเมนต์ที่มี .value (YYYY-MM-DD หรือ '' ถ้ายังไม่ถูกต้อง)
 */
export function thaiDateInput({ name, value = '', min = '', max = '', onChange } = {}) {
  let current = partsOf(value) ? value : '';

  const text = el('input', {
    id: name,
    type: 'text',
    inputmode: 'numeric',
    autocomplete: 'off',
    placeholder: 'วว/ดด/ปปปป',
    'aria-label': 'วันที่ (พ.ศ.)',
    value: isoToThaiText(current),
  });

  const button = el('button', {
    class: 'thai-date-btn',
    type: 'button',
    title: 'เลือกจากปฏิทิน',
    'aria-label': 'เลือกจากปฏิทิน',
    html:
      '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" ' +
      'stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' +
      '<rect x="3" y="5" width="18" height="16" rx="2"/><path d="M3 10h18M8 3v4M16 3v4"/></svg>',
  });

  const popover = el('div', { class: 'thai-date-pop', hidden: true, role: 'dialog' });
  const wrapper = el('div', { class: 'thai-date' }, [text, button, popover]);

  const inRange = (iso) => (!min || iso >= min) && (!max || iso <= max);

  function commit(iso, { fromCalendar = false } = {}) {
    current = iso;
    text.value = isoToThaiText(iso);
    wrapper.classList.remove('invalid');
    text.removeAttribute('aria-invalid');
    if (fromCalendar) closePopover();
    onChange?.(iso);
  }

  function readTyped() {
    const raw = text.value.trim();
    if (!raw) {
      current = '';
      wrapper.classList.remove('invalid');
      return;
    }
    const iso = thaiTextToIso(raw);
    if (!iso || !inRange(iso)) {
      current = '';
      wrapper.classList.add('invalid');
      text.setAttribute('aria-invalid', 'true');
      text.title = iso
        ? 'วันที่อยู่นอกช่วงที่เลือกได้'
        : 'ใช้รูปแบบ วว/ดด/ปปปป เช่น 01/06/2569';
      return;
    }
    text.title = '';
    if (iso !== current) commit(iso);
    else text.value = isoToThaiText(iso);
  }

  text.addEventListener('change', readTyped);
  text.addEventListener('blur', readTyped);
  text.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') {
      event.preventDefault();
      readTyped();
    }
  });

  // ---------------------------------------------------------------- ปฏิทิน
  let shownYear;
  let shownMonth; // 1-12

  function closePopover() {
    popover.hidden = true;
    if (openPopover === popover) openPopover = null;
  }

  function paintCalendar() {
    const first = new Date(shownYear, shownMonth - 1, 1);
    const daysInMonth = new Date(shownYear, shownMonth, 0).getDate();
    const today = new Date();
    const todayIso = isoOf(today.getFullYear(), today.getMonth() + 1, today.getDate());

    const move = (delta) => {
      const next = new Date(shownYear, shownMonth - 1 + delta, 1);
      shownYear = next.getFullYear();
      shownMonth = next.getMonth() + 1;
      paintCalendar();
    };

    const cells = [];
    for (let i = 0; i < first.getDay(); i += 1) cells.push(el('span'));
    for (let day = 1; day <= daysInMonth; day += 1) {
      const iso = isoOf(shownYear, shownMonth, day);
      const classes = ['thai-date-day'];
      if (iso === current) classes.push('selected');
      if (iso === todayIso) classes.push('today');
      cells.push(
        el('button', {
          class: classes.join(' '),
          type: 'button',
          text: String(day),
          disabled: !inRange(iso),
          'aria-label': `${day} ${MONTHS[shownMonth - 1]} ${shownYear + BE_OFFSET}`,
          onclick: () => commit(iso, { fromCalendar: true }),
        }),
      );
    }

    replace(popover, [
      el('div', { class: 'thai-date-head' }, [
        el('button', {
          class: 'thai-date-nav',
          type: 'button',
          'aria-label': 'เดือนก่อนหน้า',
          text: '‹',
          onclick: () => move(-1),
        }),
        el('div', {
          class: 'thai-date-title',
          text: `${MONTHS[shownMonth - 1]} ${shownYear + BE_OFFSET}`,
        }),
        el('button', {
          class: 'thai-date-nav',
          type: 'button',
          'aria-label': 'เดือนถัดไป',
          text: '›',
          onclick: () => move(1),
        }),
      ]),
      el(
        'div',
        { class: 'thai-date-grid weekdays' },
        WEEKDAYS.map((name) => el('span', { text: name })),
      ),
      el('div', { class: 'thai-date-grid' }, cells),
    ]);
  }

  button.addEventListener('click', () => {
    if (!popover.hidden) {
      closePopover();
      return;
    }
    if (openPopover) openPopover.hidden = true;
    const now = new Date();
    const base = partsOf(current) ?? partsOf(min > isoOf(now.getFullYear(), now.getMonth() + 1, now.getDate()) ? min : '') ?? {
      year: now.getFullYear(),
      month: now.getMonth() + 1,
    };
    shownYear = base.year;
    shownMonth = base.month;
    paintCalendar();
    popover.hidden = false;
    openPopover = popover;
  });

  // คลิกนอกปฏิทิน หรือกด Esc = ปิด
  document.addEventListener('mousedown', (event) => {
    if (!popover.hidden && !wrapper.contains(event.target)) closePopover();
  });
  wrapper.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !popover.hidden) {
      event.stopPropagation();
      closePopover();
      text.focus();
    }
  });

  // ให้ใช้แทน <input> เดิมได้ทันที: อ่าน/เขียน .value เป็น YYYY-MM-DD และ focus() ได้
  Object.defineProperty(wrapper, 'value', {
    get() {
      readTyped();
      return current;
    },
    set(iso) {
      current = partsOf(iso) ? iso : '';
      text.value = isoToThaiText(current);
      wrapper.classList.remove('invalid');
    },
  });
  wrapper.focus = () => text.focus();

  return wrapper;
}
