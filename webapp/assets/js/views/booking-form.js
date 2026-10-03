/**
 * ฟอร์ม "เพิ่มการใช้ห้อง" แบบปฏิทิน
 *
 * ใช้เพิ่มทั้งการใช้ห้องที่มีวันที่กำกับ (ประชุม สอบ กิจกรรม คาบชดเชย) และคาบเรียน
 * ประจำของภาคเรียน เลือกการทำซ้ำได้สี่แบบ:
 *   วันเดียว            → room_bookings repeat_type = once
 *   ทุกวัน (ช่วงวันที่)   → room_bookings repeat_type = daily
 *   ทุกสัปดาห์ (เลือกวัน) → room_bookings repeat_type = weekly
 *   ในตารางเรียนภาคนี้   → class_schedules (ทุกสัปดาห์ตลอดภาค แอปมือถือเห็นด้วย)
 *
 * ระหว่างเวลาที่จองไว้ ระบบปิดแอร์อัตโนมัติถือว่าห้องอยู่ในคาบ (รอ 15 นาที
 * ไม่แจ้งเตือน) แม้อยู่นอกภาคเรียน — ตัดสินที่ Backend (utils/room-booking.js)
 *
 * เขียนกล่องเอง ไม่ใช้ openForm เพราะช่องที่แสดงเปลี่ยนตามแบบการทำซ้ำ และต้อง
 * เปิดค้างไว้เมื่อบันทึกไม่ผ่าน ผู้ใช้จะได้ไม่ต้องกรอกใหม่ทั้งหมด
 */

import { api } from '../api.js';
import { el, replace } from '../dom.js';
import { DAY_NAMES, thaiShortDate } from '../format.js';
import { state } from '../store.js';
import { termFor } from './term-calendar.js';

export const CATEGORY_LABEL = {
  meeting: 'ประชุม',
  class: 'คาบเรียน',
  exam: 'สอบ',
  event: 'กิจกรรม',
  other: 'อื่น ๆ',
};

const DAY_SHORT = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];

// ------------------------------------------------------- ตัวช่วยเรื่องวันที่

export function dayOfWeekOf(date) {
  return new Date(`${date}T00:00:00Z`).getUTCDay();
}

export function addDays(date, days) {
  const value = new Date(`${date}T00:00:00Z`);
  value.setUTCDate(value.getUTCDate() + days);
  return value.toISOString().slice(0, 10);
}

function daysBetween(from, to) {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000);
}

/** การจองนี้มีในวันที่นี้หรือไม่ (ตรรกะเดียวกับ Backend) */
export function bookingOccursOn(booking, date) {
  if (date < booking.startDate || date > booking.endDate) return false;
  if (booking.repeatType === 'weekly') {
    return (booking.daysOfWeek ?? []).includes(dayOfWeekOf(date));
  }
  return true;
}

function countOccurrences(input) {
  const span = daysBetween(input.startDate, input.endDate);
  if (!(span >= 0)) return 0;
  if (input.repeatType === 'once') return 1;
  if (input.repeatType === 'daily') return span + 1;
  const days = new Set(input.daysOfWeek);
  let count = 0;
  for (let index = 0; index <= span; index += 1) {
    if (days.has(dayOfWeekOf(addDays(input.startDate, index)))) count += 1;
  }
  return count;
}

/** ข้อความสั้นอธิบายการทำซ้ำ เช่น "ทุกวันพุธ · 7 ต.ค. – 31 ธ.ค. 69" */
export function describeRepeat(booking) {
  const range = `${thaiShortDate(booking.startDate)} – ${thaiShortDate(booking.endDate)}`;
  if (booking.repeatType === 'once') return `วันเดียว · ${thaiShortDate(booking.startDate)}`;
  if (booking.repeatType === 'daily') return `ทุกวัน · ${range}`;
  const days = (booking.daysOfWeek ?? []).map((day) => DAY_NAMES[day]);
  return `ทุกวัน${days.join(' ')} · ${range}`;
}

// ------------------------------------------------------------------ ฟอร์ม

/**
 * เปิดฟอร์ม
 * @param {object} options
 * @param {object|null} options.booking   แก้รายการเดิม (null = เพิ่มใหม่)
 * @param {string} options.date           วันที่ตั้งต้น (YYYY-MM-DD)
 * @param {string} options.roomNumber     ห้องตั้งต้น
 * @returns {Promise<boolean>} true เมื่อบันทึกสำเร็จ
 */
export function openBookingForm({ booking = null, date, roomNumber = '' } = {}) {
  return new Promise((resolve) => {
    const editing = booking != null;
    const timetableSemester = state.timetable?.semester ?? '';
    const term = termFor(timetableSemester);
    const canUseTimetable = !editing && state.timetable !== undefined;

    const values = {
      roomNumber: booking?.roomNumber ?? roomNumber,
      title: booking?.title ?? '',
      category: booking?.category ?? 'meeting',
      note: booking?.note ?? '',
      startTime: booking?.startTime ?? '13:00',
      endTime: booking?.endTime ?? '15:00',
      repeatType: booking?.repeatType ?? 'once',
      startDate: booking?.startDate ?? date,
      endDate: booking?.endDate ?? addDays(date, 6 - dayOfWeekOf(date)),
      daysOfWeek: booking?.daysOfWeek?.length ? [...booking.daysOfWeek] : [dayOfWeekOf(date)],
    };

    let busy = false;
    const overlay = el('div', { class: 'modal-overlay' });
    const modal = el('div', {
      class: 'modal booking-modal',
      role: 'dialog',
      'aria-modal': 'true',
      'aria-labelledby': 'bookingTitle',
    });
    const errorLine = el('div', { class: 'login-error', role: 'alert', hidden: true });
    const repeatBox = el('div', { class: 'repeat-detail' });
    const summary = el('div', { class: 'booking-summary', role: 'status' });

    const close = (result) => {
      if (busy) return;
      document.removeEventListener('keydown', onKey);
      overlay.remove();
      resolve(result);
    };
    const onKey = (event) => {
      if (event.key === 'Escape') close(false);
    };

    // ---- ช่องพื้นฐาน
    const roomSelect = el(
      'select',
      {
        name: 'roomNumber',
        onchange: (event) => {
          values.roomNumber = event.target.value;
        },
      },
      [
        el('option', { value: '', text: '— เลือกห้อง —' }),
        ...state.rooms.map((room) =>
          el('option', {
            value: room.roomNumber,
            text: `${room.roomNumber} · ${room.roomType}`,
            selected: room.roomNumber === values.roomNumber,
          }),
        ),
      ],
    );
    const titleInput = el('input', {
      name: 'title',
      value: values.title,
      placeholder: 'เช่น ประชุมภาควิชา, สอบกลางภาค, Computer Network',
      maxlength: '150',
      oninput: (event) => {
        values.title = event.target.value;
      },
    });
    const noteInput = el('input', {
      name: 'note',
      value: values.note,
      placeholder: 'ผู้รับผิดชอบ / อาจารย์ / กลุ่มเรียน (ไม่ใส่ก็ได้)',
      maxlength: '255',
      oninput: (event) => {
        values.note = event.target.value;
      },
    });
    const timeInput = (key) =>
      el('input', {
        type: 'time',
        name: key,
        value: values[key],
        oninput: (event) => {
          values[key] = event.target.value;
          paintSummary();
        },
      });

    const categoryChips = el(
      'div',
      { class: 'chip-row compact' },
      Object.entries(CATEGORY_LABEL).map(([key, label]) =>
        el('button', {
          class: `mode-chip${values.category === key ? ' sel' : ''}`,
          type: 'button',
          text: label,
          'aria-pressed': values.category === key ? 'true' : 'false',
          onclick: (event) => {
            values.category = key;
            for (const chip of categoryChips.children) {
              const on = chip === event.currentTarget;
              chip.classList.toggle('sel', on);
              chip.setAttribute('aria-pressed', on ? 'true' : 'false');
            }
            paintRepeatOptions();
          },
        }),
      ),
    );

    // ---- การทำซ้ำ
    const REPEATS = [
      { key: 'once', label: 'วันเดียว', hint: 'ใช้ห้องครั้งเดียว' },
      { key: 'daily', label: 'ทุกวัน', hint: 'ทุกวันในช่วงวันที่ เช่น ทั้งสัปดาห์นี้' },
      { key: 'weekly', label: 'ทุกสัปดาห์', hint: 'วันเดิมของทุกสัปดาห์ เช่น ทุกวันพุธ' },
    ];
    if (canUseTimetable) {
      REPEATS.push({
        key: 'timetable',
        label: 'ในตารางเรียน',
        hint: timetableSemester
          ? `ทุกสัปดาห์ตลอดภาคเรียน ${timetableSemester} · แอปมือถือเห็นด้วย`
          : 'ทุกสัปดาห์ตลอดภาคเรียน · แอปมือถือเห็นด้วย',
      });
    }
    const repeatOptions = el('div', { class: 'repeat-options', role: 'radiogroup' });

    function paintRepeatOptions() {
      // "ในตารางเรียน" เหมาะกับคาบเรียนประจำ ให้เห็นเฉพาะเมื่อเลือกประเภทคาบเรียน
      const options = REPEATS.filter(
        (item) => item.key !== 'timetable' || values.category === 'class',
      );
      if (values.repeatType === 'timetable' && values.category !== 'class') {
        values.repeatType = 'weekly';
      }
      replace(
        repeatOptions,
        options.map((item) =>
          el('label', { class: `repeat-option${values.repeatType === item.key ? ' sel' : ''}` }, [
            el('input', {
              type: 'radio',
              name: 'repeatType',
              value: item.key,
              checked: values.repeatType === item.key,
              onchange: () => {
                values.repeatType = item.key;
                if (item.key === 'weekly' && values.endDate <= values.startDate) {
                  values.endDate = term?.endDate && term.endDate > values.startDate
                    ? term.endDate
                    : addDays(values.startDate, 27);
                }
                paintRepeatOptions();
              },
            }),
            el('b', { text: item.label }),
            el('span', { text: item.hint }),
          ]),
        ),
      );
      paintRepeatDetail();
    }

    const dateInput = (key, label) =>
      el('div', { class: 'field' }, [
        el('label', { text: label }),
        el('input', {
          type: 'date',
          name: key,
          value: values[key],
          oninput: (event) => {
            values[key] = event.target.value;
            if (key === 'startDate' && values.repeatType !== 'once' && values.endDate < values.startDate) {
              values.endDate = values.startDate;
              paintRepeatDetail();
              return;
            }
            paintSummary();
          },
        }),
      ]);

    const quickEnd = (label, endDate) =>
      el('button', {
        class: 'link-btn',
        type: 'button',
        text: label,
        onclick: () => {
          values.endDate = endDate;
          paintRepeatDetail();
        },
      });

    function paintRepeatDetail() {
      const type = values.repeatType;
      const parts = [];
      if (type === 'once') {
        parts.push(dateInput('startDate', 'วันที่'));
      } else if (type === 'timetable') {
        parts.push(
          el('div', { class: 'field' }, [
            el('label', { text: 'วันในสัปดาห์' }),
            dayPicker(),
          ]),
          el('div', {
            class: 'muted small-note',
            text: term
              ? `มีผลทุกสัปดาห์ระหว่างวันเปิด–ปิดภาค ${thaiShortDate(term.startDate)} – ${thaiShortDate(term.endDate)}`
              : 'มีผลทุกสัปดาห์ จนกว่าจะเปลี่ยนตารางเรียน (ตั้งวันเปิด–ปิดภาคได้ที่ปฏิทินภาคเรียน)',
          }),
        );
      } else {
        if (type === 'weekly') {
          parts.push(
            el('div', { class: 'field' }, [
              el('label', { text: 'วันในสัปดาห์' }),
              dayPicker(),
            ]),
          );
        }
        parts.push(
          el('div', { class: 'field-row' }, [
            dateInput('startDate', 'ตั้งแต่วันที่'),
            dateInput('endDate', 'ถึงวันที่'),
          ]),
        );
        const quick = [];
        if (type === 'daily') {
          quick.push(
            quickEnd('ถึงสิ้นสัปดาห์นี้', addDays(values.startDate, 6 - dayOfWeekOf(values.startDate))),
            quickEnd('5 วัน', addDays(values.startDate, 4)),
          );
        } else {
          if (term && term.endDate > values.startDate) {
            quick.push(quickEnd(`ถึงวันปิดภาค (${thaiShortDate(term.endDate)})`, term.endDate));
          }
          quick.push(
            quickEnd('4 สัปดาห์', addDays(values.startDate, 27)),
            quickEnd('3 เดือน', addDays(values.startDate, 90)),
          );
        }
        parts.push(el('div', { class: 'quick-row' }, [el('span', { class: 'dim small-note', text: 'สิ้นสุดเร็ว:' }), ...quick]));
      }
      replace(repeatBox, parts);
      paintSummary();
    }

    function dayPicker() {
      return el(
        'div',
        { class: 'day-picker', role: 'group', 'aria-label': 'เลือกวันในสัปดาห์' },
        DAY_SHORT.map((label, day) =>
          el('button', {
            class: `day-toggle${values.daysOfWeek.includes(day) ? ' sel' : ''}`,
            type: 'button',
            text: label,
            title: `วัน${DAY_NAMES[day]}`,
            'aria-pressed': values.daysOfWeek.includes(day) ? 'true' : 'false',
            onclick: (event) => {
              const set = new Set(values.daysOfWeek);
              if (set.has(day)) set.delete(day);
              else set.add(day);
              values.daysOfWeek = [...set].sort();
              event.currentTarget.classList.toggle('sel', set.has(day));
              event.currentTarget.setAttribute('aria-pressed', set.has(day) ? 'true' : 'false');
              paintSummary();
            },
          }),
        ),
      );
    }

    function paintSummary() {
      const time = `${values.startTime || '--:--'}–${values.endTime || '--:--'}`;
      let text;
      if (values.repeatType === 'timetable') {
        const days = values.daysOfWeek.map((day) => DAY_NAMES[day]).join(' ');
        text = days
          ? `ทุกวัน${days} ${time} · ในตารางเรียน${timetableSemester ? ` ภาคเรียน ${timetableSemester}` : ''}`
          : 'เลือกวันในสัปดาห์อย่างน้อยหนึ่งวัน';
      } else {
        const input = { ...values, endDate: values.repeatType === 'once' ? values.startDate : values.endDate };
        const count = countOccurrences(input);
        text =
          count > 0
            ? `${describeRepeat(input)} · ${time} · รวม ${count} ครั้ง`
            : values.repeatType === 'weekly' && values.daysOfWeek.length === 0
              ? 'เลือกวันในสัปดาห์อย่างน้อยหนึ่งวัน'
              : 'ช่วงวันที่ไม่มีวันที่ตรงกับที่เลือก';
      }
      summary.textContent = text;
    }

    // ---- บันทึก
    const saveButton = el('button', {
      class: 'btn btn-primary',
      type: 'button',
      text: editing ? 'บันทึกการแก้ไข' : 'เพิ่มการใช้ห้อง',
      onclick: save,
    });

    async function save() {
      errorLine.hidden = true;
      const fail = (message) => {
        errorLine.textContent = message;
        errorLine.hidden = false;
        errorLine.scrollIntoView({ block: 'nearest' });
      };
      if (!values.roomNumber) return fail('กรุณาเลือกห้อง');
      if (!values.title.trim()) return fail('กรุณากรอกชื่อการใช้ห้อง');
      if (!values.startTime || !values.endTime || values.endTime <= values.startTime) {
        return fail('เวลาสิ้นสุดต้องหลังเวลาเริ่ม');
      }

      busy = true;
      saveButton.disabled = true;
      saveButton.textContent = 'กำลังบันทึก…';
      try {
        if (values.repeatType === 'timetable') {
          if (values.daysOfWeek.length === 0) throw new Error('กรุณาเลือกวันในสัปดาห์อย่างน้อยหนึ่งวัน');
          // คาบเรียนประจำ: หนึ่งแถวต่อหนึ่งวัน ใช้ API เดิมของตารางเรียน (ตรวจเวลาทับให้ด้วย)
          for (const day of values.daysOfWeek) {
            await api.createSchedule({
              roomNumber: values.roomNumber,
              dayOfWeek: day,
              subjectName: values.title.trim(),
              section: values.note.trim(),
              instructor: '',
              startTime: values.startTime,
              endTime: values.endTime,
            });
          }
        } else {
          const payload = {
            roomNumber: values.roomNumber,
            title: values.title.trim(),
            category: values.category,
            note: values.note.trim(),
            repeatType: values.repeatType,
            daysOfWeek: values.daysOfWeek,
            startDate: values.startDate,
            endDate: values.repeatType === 'once' ? values.startDate : values.endDate,
            startTime: values.startTime,
            endTime: values.endTime,
          };
          if (editing) await api.updateBooking(booking.id, payload);
          else await api.createBooking(payload);
        }
        busy = false;
        close(values.repeatType === 'timetable' ? 'timetable' : true);
      } catch (error) {
        busy = false;
        saveButton.disabled = false;
        saveButton.textContent = editing ? 'บันทึกการแก้ไข' : 'เพิ่มการใช้ห้อง';
        fail(error.message);
      }
    }

    modal.append(
      el('h3', { id: 'bookingTitle', text: editing ? 'แก้ไขการใช้ห้อง' : 'เพิ่มการใช้ห้อง' }),
      el('div', {
        class: 'modal-sub',
        text:
          'ระหว่างเวลาที่ใช้ห้อง ระบบจะถือว่าห้องอยู่ในคาบ: ห้องว่างจะรอ 15 นาทีก่อนปิดแอร์ ' +
          'และไม่แจ้งเตือนว่าใช้แอร์นอกคาบ',
      }),
      errorLine,
      el('div', { class: 'field-row' }, [
        el('div', { class: 'field' }, [el('label', { text: 'ห้อง' }), roomSelect]),
        el('div', { class: 'field' }, [el('label', { text: 'ประเภท' }), categoryChips]),
      ]),
      el('div', { class: 'field' }, [el('label', { text: 'ใช้ห้องเพื่อ' }), titleInput]),
      el('div', { class: 'field' }, [el('label', { text: 'รายละเอียด' }), noteInput]),
      el('div', { class: 'field-row' }, [
        el('div', { class: 'field' }, [el('label', { text: 'เวลาเริ่ม' }), timeInput('startTime')]),
        el('div', { class: 'field' }, [el('label', { text: 'เวลาสิ้นสุด' }), timeInput('endTime')]),
      ]),
      el('div', { class: 'field' }, [el('label', { text: 'ทำซ้ำ' }), repeatOptions]),
      repeatBox,
      summary,
      el('div', { class: 'modal-actions' }, [
        el('button', { class: 'btn', type: 'button', text: 'ยกเลิก', onclick: () => close(false) }),
        saveButton,
      ]),
    );

    overlay.addEventListener('click', (event) => {
      if (event.target === overlay) close(false);
    });
    document.addEventListener('keydown', onKey);
    overlay.appendChild(modal);
    document.body.appendChild(overlay);
    paintRepeatOptions();
    (values.roomNumber ? titleInput : roomSelect).focus();
  });
}
