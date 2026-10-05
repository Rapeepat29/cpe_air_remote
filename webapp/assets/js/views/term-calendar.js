/**
 * ปฏิทินภาคเรียน: วันเปิด-ปิดของแต่ละเทอม (ใช้ในหน้าตารางเรียน)
 *
 * ตารางเรียนที่ใช้อยู่จะมีผลเฉพาะระหว่างวันเปิด-ปิดของภาคเรียนของมัน
 * ก่อนเปิดหรือหลังปิดภาค Backend ถือว่าทุกห้องอยู่นอกคาบเอง
 * (ดู backend/src/services/academic-terms.js) จึงไม่ต้องล้างตารางตอนปิดภาค
 * และนำเข้าตารางเทอมหน้าไว้ล่วงหน้าได้ พอถึงวันเปิดภาคจะเริ่มใช้เอง
 *
 * หน้านี้แค่แสดงและแก้ปฏิทิน การตัดสินว่าวันนี้อยู่ในภาคหรือไม่ทำที่ Backend
 * ตามเวลาไทย ไม่ใช่เวลาของเครื่องที่เปิดเว็บ
 */

import { api } from '../api.js';
import { el, replace, svg } from '../dom.js';
import { thaiShortDate } from '../format.js';
import { icons } from '../icons.js';
import { loaders, state } from '../store.js';
import { confirmAction, openForm, toastError, toastOk } from '../ui.js';

const STATUS_LABEL = {
  active: 'กำลังเปิดภาค',
  before: 'ยังไม่เปิดภาค',
  after: 'ปิดภาคแล้ว',
};

const STATUS_TONE = {
  active: 'done',
  before: 'info',
  after: 'off',
};

/** ปฏิทินของภาคเรียนหนึ่ง หรือ null */
export function termFor(semester) {
  if (!semester) return null;
  return (state.terms ?? []).find((term) => term.semester === semester) ?? null;
}

/** จำนวนวันจาก a ถึง b (สตริง YYYY-MM-DD) */
function daysBetween(a, b) {
  const start = Date.parse(`${a}T00:00:00Z`);
  const end = Date.parse(`${b}T00:00:00Z`);
  if (Number.isNaN(start) || Number.isNaN(end)) return null;
  return Math.round((end - start) / 86400000);
}

const range = (term) => `${thaiShortDate(term.startDate)} – ${thaiShortDate(term.endDate)}`;

/**
 * บรรทัดสถานะใต้ชื่อภาคเรียนในแถบตารางเรียน
 * บอกให้ชัดว่า "ตอนนี้ระบบใช้ตารางนี้อยู่ไหม" เพราะเป็นสิ่งที่กระทบการปิดแอร์จริง
 */
export function termStatusLine(semester, { onSetDates = null } = {}) {
  if (state.terms === undefined || !semester) return null;
  const term = termFor(semester);
  const isAdmin = state.user?.role === 'admin';

  if (!term) {
    return el('div', { class: 'term-line' }, [
      el('span', { class: 'status-chip off', text: 'ยังไม่ได้ตั้งวันเปิด–ปิดภาค' }),
      el('span', { text: 'ระบบใช้ตารางนี้ทุกวัน รวมช่วงปิดภาค' }),
      isAdmin && onSetDates
        ? el('button', {
            class: 'link-btn',
            type: 'button',
            text: 'ตั้งวันเปิด–ปิด',
            onclick: () => onSetDates(semester),
          })
        : null,
    ]);
  }

  let text = range(term);
  const today = state.today;
  if (term.status === 'active' && today) {
    const left = daysBetween(today, term.endDate);
    text += left === 0 ? ' · วันนี้วันสุดท้าย' : ` · อีก ${left} วันปิดภาค`;
  } else if (term.status === 'before') {
    const wait = today ? daysBetween(today, term.startDate) : null;
    text +=
      ` · ทุกห้องถือว่าว่างจนถึงวันเปิดภาค` + (wait != null ? ` (อีก ${wait} วัน)` : '');
  } else if (term.status === 'after') {
    text += ' · ปิดภาคแล้ว ทุกห้องถือว่าว่าง (ห้องว่าง 5 นาทีปิดแอร์)';
  }

  return el('div', { class: 'term-line' }, [
    el('span', {
      class: `status-chip ${STATUS_TONE[term.status] ?? 'off'}`,
      text: STATUS_LABEL[term.status] ?? 'ไม่ทราบสถานะ',
    }),
    el('span', { text }),
  ]);
}

/**
 * กล่องปฏิทินภาคเรียน (พับเก็บได้)
 *
 * ใช้ <details> ของเบราว์เซอร์ ไม่ต้องเขียนการเปิด-ปิดเอง และใช้คีย์บอร์ดได้เลย
 * จำสถานะเปิด/ปิดไว้ข้ามการวาดใหม่ทุก 10 วินาที
 */
export function createTermCalendar({ onChanged }) {
  const box = el('details', { class: 'term-calendar' });
  let open = false;
  box.addEventListener('toggle', () => {
    open = box.open;
  });

  async function editTerm(term = null, presetSemester = '') {
    const values = await openForm({
      title: term ? `แก้วันเปิด–ปิด ภาคเรียน ${term.semester}` : 'เพิ่มภาคเรียน',
      subtitle:
        'ตารางเรียนของภาคนี้จะมีผลเฉพาะระหว่างวันเปิดถึงวันปิด (รวมสองวันนั้น) ' +
        'นอกช่วงนี้ระบบถือว่าทุกห้องว่าง',
      fields: [
        {
          name: 'semester',
          label: 'ภาคเรียน (เทอม/ปีการศึกษา)',
          value: term?.semester ?? presetSemester,
          placeholder: 'เช่น 1/2569',
          required: true,
          hint: 'ต้องตรงกับภาคเรียนในไฟล์ตารางเรียน เช่น 1/2569, 2/2569, 3/2569 (ภาคฤดูร้อน)',
        },
        {
          name: 'startDate',
          label: 'วันเปิดภาคเรียน',
          type: 'date',
          value: term?.startDate ?? '',
          required: true,
        },
        {
          name: 'endDate',
          label: 'วันปิดภาคเรียน (วันสุดท้ายที่มีเรียน)',
          type: 'date',
          value: term?.endDate ?? '',
          required: true,
        },
      ],
      submitLabel: 'บันทึก',
    });
    if (!values) return;

    // เปลี่ยนชื่อภาคเรียนตอนแก้ = บันทึกเป็นภาคใหม่แล้วลบอันเดิม
    try {
      const saved = await api.saveAcademicTerm(values);
      if (term && term.semester !== saved.semester) {
        await api.deleteAcademicTerm(term.semester);
      }
      toastOk(`บันทึกภาคเรียน ${saved.semester} แล้ว`);
      await loaders.terms();
      open = true;
      onChanged();
    } catch (error) {
      toastError(error.message);
    }
  }

  async function removeTerm(term) {
    const inUse = state.timetable?.semester === term.semester;
    const ok = await confirmAction({
      title: `ลบภาคเรียน ${term.semester} ออกจากปฏิทิน?`,
      subtitle:
        `${range(term)}\n\n` +
        (inUse
          ? 'ตารางเรียนที่ใช้อยู่เป็นของภาคนี้ เมื่อลบแล้วระบบจะใช้ตารางทุกวัน รวมช่วงปิดภาค'
          : 'ตารางเรียนและข้อมูลไฟฟ้าไม่ถูกลบ'),
      confirmLabel: 'ลบออกจากปฏิทิน',
      danger: true,
    });
    if (!ok) return;
    try {
      await api.deleteAcademicTerm(term.semester);
      toastOk(`ลบภาคเรียน ${term.semester} แล้ว`);
      await loaders.terms();
      onChanged();
    } catch (error) {
      toastError(error.message);
    }
  }

  function render() {
    if (state.terms === undefined) {
      box.hidden = true;
      return;
    }
    box.hidden = false;
    box.open = open;
    const isAdmin = state.user?.role === 'admin';
    const terms = state.terms;
    const current = state.timetable?.semester ?? '';

    const rows = terms.map((term) =>
      el('tr', { class: term.semester === current ? 'current-term' : null }, [
        el('td', {}, [
          el('b', { text: term.semester }),
          term.semester === current
            ? el('span', { class: 'badge-soft', text: 'ตารางที่ใช้อยู่' })
            : null,
        ]),
        el('td', { text: thaiShortDate(term.startDate) }),
        el('td', { text: thaiShortDate(term.endDate) }),
        el('td', {}, [
          el('span', {
            class: `status-chip ${STATUS_TONE[term.status] ?? 'off'}`,
            text: STATUS_LABEL[term.status] ?? '—',
          }),
        ]),
        isAdmin
          ? el('td', { class: 'term-actions' }, [
              iconButton(icons.edit(13), `แก้ภาคเรียน ${term.semester}`, () => editTerm(term)),
              iconButton(icons.trash(13), `ลบภาคเรียน ${term.semester}`, () => removeTerm(term)),
            ])
          : null,
      ]),
    );

    replace(box, [
      el('summary', {}, [
        el('span', { class: 'term-summary-title', text: 'ปฏิทินภาคเรียน' }),
        el('span', {
          class: 'count-badge',
          text: terms.length === 0 ? 'ยังไม่ได้ตั้ง' : `${terms.length} ภาคเรียน`,
        }),
        el('span', { class: 'dim small-note term-summary-hint', text: 'วันเปิด–ปิดของแต่ละเทอม' }),
      ]),
      el('div', { class: 'term-body' }, [
        el('p', {
          class: 'muted small-note',
          text:
            'ตารางเรียนมีผลเฉพาะระหว่างวันเปิด–ปิดของภาคเรียนของมัน ก่อนเปิดหรือหลังปิดภาค ' +
            'ระบบถือว่าทุกห้องว่าง: ห้องว่างเกิน 5 นาทีสั่งปิดแอร์ และแจ้งเตือนเมื่อมีคนเปิดแอร์ใช้ ' +
            'จึงไม่ต้องล้างตารางตอนปิดภาค และนำเข้าตารางเทอมหน้าไว้ล่วงหน้าได้ ' +
            'ภาคเรียนที่ไม่ได้ตั้งวันไว้ ระบบใช้ตารางทุกวัน',
        }),
        terms.length > 0
          ? el('div', { class: 'table-wrap' }, [
              el('table', { class: 'data term-table' }, [
                el('thead', {}, [
                  el('tr', {}, [
                    el('th', { text: 'ภาคเรียน' }),
                    el('th', { text: 'วันเปิดภาค' }),
                    el('th', { text: 'วันปิดภาค' }),
                    el('th', { text: 'สถานะวันนี้' }),
                    isAdmin ? el('th', { text: '' }) : null,
                  ]),
                ]),
                el('tbody', {}, rows),
              ]),
            ])
          : el('div', {
              class: 'empty',
              text: isAdmin
                ? 'ยังไม่ได้ตั้งวันเปิด–ปิดภาคเรียน กด "เพิ่มภาคเรียน" เช่น 1/2569 และ 2/2569 ของปีนี้'
                : 'ผู้ดูแลระบบยังไม่ได้ตั้งวันเปิด–ปิดภาคเรียน',
            }),
        isAdmin
          ? el('div', { class: 'term-add' }, [
              el(
                'button',
                {
                  class: 'btn btn-sm btn-primary',
                  type: 'button',
                  onclick: () => editTerm(null, suggestSemester()),
                },
                [svg(icons.plus(14)), 'เพิ่มภาคเรียน'],
              ),
            ])
          : null,
      ]),
    ]);
  }

  /** เดาภาคเรียนถัดไปให้กรอกน้อยลง: ภาคของตารางปัจจุบันถ้ายังไม่มีในปฏิทิน ไม่งั้นเทอมถัดไป */
  function suggestSemester() {
    const current = state.timetable?.semester ?? '';
    if (current && !termFor(current)) return current;
    const last = [...(state.terms ?? [])].pop()?.semester ?? current;
    const match = /^([1-3])\/(\d{4})$/.exec(last);
    if (!match) return '';
    const term = Number(match[1]);
    const year = Number(match[2]);
    return term >= 2 ? `1/${year + 1}` : `2/${year}`;
  }

  return {
    element: box,
    render,
    /** เปิดฟอร์มตั้งวันของภาคเรียนหนึ่ง (ใช้จากปุ่มในแถบตารางเรียน) */
    setDatesFor(semester) {
      const term = termFor(semester);
      editTerm(term, semester);
    },
  };
}

function iconButton(markup, title, onclick) {
  const button = el('button', {
    class: 'icon-btn',
    type: 'button',
    title,
    'aria-label': title,
    onclick,
  });
  button.innerHTML = markup;
  return button;
}
