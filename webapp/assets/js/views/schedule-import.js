/**
 * นำเข้าตารางเรียนจากไฟล์ Excel (.xlsx) หรือ CSV
 *
 * ทำงานแบบเดียวกับหน้าจอนำเข้าของแอปมือถือ (schedule_import_screen.dart)
 * และใช้ Backend ชุดเดียวกัน มีสามขั้น:
 *   1. เลือกไฟล์ (กดเลือกหรือลากมาวาง)
 *   2. Backend อ่านไฟล์และส่งผลตรวจกลับมา (/schedules/import/preview)
 *      ยังไม่บันทึกอะไรลงฐานข้อมูล — ผู้ใช้เห็นจำนวนห้อง จำนวนคาบ คำเตือน
 *      ห้องใหม่ที่จะถูกสร้าง และตัวอย่างทุกแถวก่อนตัดสินใจ
 *   3. ยืนยันแล้วจึงบันทึก (/schedules/import/commit) ซึ่งแทนที่ตารางเดิม
 *      "เฉพาะห้องที่อยู่ในไฟล์" ใน transaction เดียว ห้องอื่นไม่ถูกแตะ
 *
 * การอ่าน Excel ทำที่ Backend ไม่ใช่ในเบราว์เซอร์ เพราะไฟล์ตารางของคณะใช้
 * เซลล์ผสาน (merge) หลายชั้น ตัวอ่านใน backend/src/utils/xlsx-reader.js
 * จัดการไว้แล้วและมีชุดทดสอบ ถ้าเขียนซ้ำบนเว็บ ผลสองฝั่งจะเพี้ยนกันได้
 *
 * ขั้นยืนยันวางไว้ในกล่องเดียวกัน ไม่เปิดกล่องยืนยันซ้อนอีกชั้น
 * เพราะกด Esc แล้วกล่องซ้อนจะปิดพร้อมกันทั้งสองชั้น
 *
 * เรื่องเปลี่ยนภาคเรียน: ไฟล์ของเทอมใหม่มักไม่มีชีตของห้องที่เทอมนี้ไม่มีเรียน
 * ถ้านำเข้าแบบ "แทนที่เฉพาะห้องในไฟล์" ห้องพวกนั้นจะค้างตารางเทอมเก่า และระบบปิด
 * แอร์อัตโนมัติจะคิดว่ายังมีคาบ (รอ 15 นาทีแทน 5 และไม่แจ้งเตือน) จึงให้เลือก
 * ชัด ๆ ว่าจะ "ล้างตารางเดิมทุกห้อง" หรือไม่ เมื่อมีห้องแบบนั้นอยู่จริง
 */

import { api } from '../api.js';
import { el, replace, svg } from '../dom.js';
import { DAY_NAMES, floorLabel } from '../format.js';
import { uiIcons } from '../icons-ui.js';

/** ตรงกับ express.raw({ limit: '8mb' }) ใน backend/src/routes/schedules.js */
const MAX_BYTES = 8 * 1024 * 1024;

const ACCEPT =
  '.xlsx,.csv,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet,text/csv';

/** ตัวอย่างในตารางแสดงไม่เกินเท่านี้เมื่อดู "ทุกห้อง" เลือกห้องเดียวจะเห็นครบ */
const PREVIEW_LIMIT = 150;

/**
 * แบบฟอร์ม CSV — หัวคอลัมน์ชุดเดียวกับที่ระบบส่งออก (schedulesToCsv)
 * ใส่ BOM ไว้หน้าไฟล์ Excel จึงเปิดแล้วอ่านภาษาไทยได้ไม่เพี้ยน
 * คอลัมน์ day ใช้ได้ทั้ง MON / จันทร์ / 1
 */
const TEMPLATE_CSV =
  '﻿' +
  [
    'semester,room_code,day,start_time,end_time,subject,section,instructor,enabled',
    '1/2569,16201,MON,09:00,12:00,Computer Network,(T) 69346CPE1,อ.ตัวอย่าง ใจดี,true',
    '1/2569,16201,จันทร์,13:00,16:00,Embedded Systems,(P) 69346CPE1,อ.ตัวอย่าง ใจดี,true',
  ].join('\r\n') +
  '\r\n';

const STEPS = ['เลือกไฟล์', 'ตรวจตัวอย่าง', 'นำเข้า'];

/**
 * เปิดกล่องนำเข้า
 *
 * @param {{ onImported?: (result: object) => (void|Promise<void>) }} options
 *   onImported ถูกเรียกหลังบันทึกสำเร็จ ให้หน้าที่เปิดไว้ดึงตารางใหม่
 */
export function openScheduleImport({ onImported = null, current = null } = {}) {
  let busy = false;
  let closed = false;
  /** 'rooms' = แทนที่เฉพาะห้องในไฟล์, 'all' = ล้างทุกห้อง (เปลี่ยนภาคเรียน), null = ยังไม่เลือก */
  let mode = 'rooms';

  const currentSchedules = current?.schedules ?? [];
  const currentSemester = current?.semester ?? '';

  /** ห้องที่ตอนนี้มีตารางอยู่ แต่ไม่มีในไฟล์ที่กำลังนำเข้า พร้อมจำนวนคาบ */
  function roomsOutsideFile(preview) {
    const inFile = new Set(preview.roomNumbers ?? []);
    const counts = new Map();
    for (const row of currentSchedules) {
      if (inFile.has(row.roomNumber)) continue;
      counts.set(row.roomNumber, (counts.get(row.roomNumber) ?? 0) + 1);
    }
    return [...counts.entries()]
      .map(([roomNumber, count]) => ({ roomNumber, count }))
      .sort((a, b) => a.roomNumber.localeCompare(b.roomNumber));
  }

  function needsModeChoice(preview) {
    return current?.supportsReplaceAll === true && roomsOutsideFile(preview).length > 0;
  }

  /**
   * ค่าเริ่มต้นของวิธีนำเข้า
   * ภาคเรียนในไฟล์ต่างจากในระบบ = น่าจะเปลี่ยนเทอม เลือก "ล้างทุกห้อง" ไว้ให้
   * ภาคเรียนเดียวกัน = แก้บางห้อง, ไม่รู้ภาคเรียนฝั่งใดฝั่งหนึ่ง = ให้ผู้ใช้เลือกเอง
   */
  function defaultMode(preview) {
    if (!needsModeChoice(preview)) return 'rooms';
    if (preview.semester && currentSemester) {
      return preview.semester === currentSemester ? 'rooms' : 'all';
    }
    return null;
  }

  const overlay = el('div', { class: 'modal-overlay' });
  const modal = el('div', {
    class: 'modal wide import-modal',
    role: 'dialog',
    'aria-modal': 'true',
    'aria-labelledby': 'scheduleImportTitle',
  });
  const steps = el('div', { class: 'import-steps' });
  const closeButton = el('button', {
    class: 'icon-btn',
    type: 'button',
    title: 'ปิด (Esc)',
    'aria-label': 'ปิด',
    html: '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" aria-hidden="true"><path d="M18 6 6 18M6 6l12 12"/></svg>',
    onclick: () => close(),
  });
  const body = el('div', { class: 'import-body' });
  const actions = el('div', { class: 'modal-actions import-actions' });

  modal.append(
    el('div', { class: 'import-head' }, [
      el('div', { class: 'grow' }, [
        el('h3', {
          id: 'scheduleImportTitle',
          text: 'นำเข้าตารางเรียนจาก Excel / CSV',
        }),
        steps,
      ]),
      closeButton,
    ]),
    body,
    actions,
  );

  function close() {
    if (busy) return;
    closed = true;
    document.removeEventListener('keydown', onKey);
    overlay.remove();
  }

  function onKey(event) {
    if (event.key === 'Escape') close();
  }

  overlay.addEventListener('click', (event) => {
    if (event.target === overlay) close();
  });
  document.addEventListener('keydown', onKey);
  overlay.appendChild(modal);
  document.body.appendChild(overlay);

  function setStep(index) {
    replace(
      steps,
      STEPS.map((label, position) =>
        el('span', {
          class: position === index ? 'on' : position < index ? 'done' : '',
          text: `${position + 1}. ${label}`,
        }),
      ),
    );
  }

  // ------------------------------------------------------------ 1. เลือกไฟล์

  function renderPick(errorMessage = '') {
    setStep(0);
    const input = el('input', {
      type: 'file',
      accept: ACCEPT,
      class: 'sr-only',
      onchange: (event) => {
        const file = event.target.files?.[0];
        if (file) handleFile(file);
      },
    });

    const zone = el('label', { class: 'drop-zone' }, [
      input,
      el('span', { class: 'dz-icon', html: uiIcons.upload(26) }),
      el('span', { class: 'dz-title', text: 'กดเพื่อเลือกไฟล์ หรือลากไฟล์มาวางที่นี่' }),
      el('span', { class: 'dz-sub', text: 'Excel (.xlsx) หรือ CSV · ไม่เกิน 8 MB' }),
    ]);

    // ลากไฟล์มาวาง: ต้องกัน dragover ไว้ ไม่งั้นเบราว์เซอร์จะเปิดไฟล์แทนหน้าเว็บ
    const stop = (event) => {
      event.preventDefault();
      event.stopPropagation();
    };
    zone.addEventListener('dragenter', (event) => {
      stop(event);
      zone.classList.add('dragging');
    });
    zone.addEventListener('dragover', (event) => {
      stop(event);
      zone.classList.add('dragging');
    });
    zone.addEventListener('dragleave', (event) => {
      stop(event);
      if (!zone.contains(event.relatedTarget)) zone.classList.remove('dragging');
    });
    zone.addEventListener('drop', (event) => {
      stop(event);
      zone.classList.remove('dragging');
      const file = event.dataTransfer?.files?.[0];
      if (file) handleFile(file);
    });

    replace(body, [
      errorMessage ? el('div', { class: 'login-error', role: 'alert', text: errorMessage }) : null,
      zone,
      el('div', { class: 'import-formats' }, [
        el('div', { class: 'format-card' }, [
          el('b', { text: 'Excel ตารางการใช้ห้อง (.xlsx)' }),
          el('span', {
            text:
              'ไฟล์ต้นฉบับจากคณะได้เลย หนึ่งชีตต่อหนึ่งห้อง ชื่อชีตคือรหัสห้อง ' +
              'ระบบอ่านเซลล์ที่ผสานไว้ (merge) เองทั้งวิชา กลุ่มเรียน และอาจารย์',
          }),
        ]),
        el('div', { class: 'format-card' }, [
          el('b', { text: 'CSV (.csv)' }),
          el('span', {
            text:
              'คอลัมน์ที่ต้องมี: room_code, day, start_time, end_time, subject ' +
              '(section, instructor, semester ใส่หรือไม่ก็ได้) · ' +
              'ใช้ไฟล์ที่บันทึกจากแอปหรือจากหน้านี้ได้',
          }),
          el('button', {
            class: 'link-btn',
            type: 'button',
            text: 'ดาวน์โหลดแบบฟอร์ม CSV',
            onclick: () =>
              downloadText(TEMPLATE_CSV, 'แบบฟอร์มตารางเรียน.csv', 'text/csv;charset=utf-8'),
          }),
        ]),
      ]),
      el('div', {
        class: 'import-note info',
        text:
          'ยังไม่มีอะไรถูกบันทึกจนกว่าจะกดยืนยันในขั้นสุดท้าย · ' +
          'เมื่อนำเข้า ตารางเดิมจะถูกแทนที่เฉพาะห้องที่อยู่ในไฟล์ ห้องอื่นไม่เปลี่ยน',
      }),
    ]);

    replace(actions, [
      el('button', { class: 'btn', type: 'button', text: 'ยกเลิก', onclick: close }),
    ]);
  }

  async function handleFile(file) {
    const extension = /\.([^.]+)$/.exec(file.name)?.[1]?.toLowerCase() ?? '';
    if (extension === 'xls') {
      renderPick(
        'ไฟล์ .xls เป็น Excel รุ่นเก่าที่ระบบอ่านไม่ได้ ' +
          'ให้เปิดใน Excel แล้วเลือก "บันทึกเป็น" ชนิด .xlsx ก่อน',
      );
      return;
    }
    if (extension !== 'xlsx' && extension !== 'csv') {
      renderPick(`ไฟล์ "${file.name}" ไม่ใช่ .xlsx หรือ .csv`);
      return;
    }
    if (file.size === 0) {
      renderPick('ไฟล์ว่างเปล่า');
      return;
    }
    if (file.size > MAX_BYTES) {
      renderPick(
        `ไฟล์ใหญ่ ${(file.size / 1024 / 1024).toFixed(1)} MB เกินขีดจำกัด 8 MB`,
      );
      return;
    }

    // ไฟล์ใน /assets ถูกแคชหนึ่งชั่วโมง ช่วงหลัง deploy เบราว์เซอร์อาจยังถือ api.js
    // ตัวเก่าที่ไม่มีคำสั่งนำเข้า บอกให้รีเฟรชแทนที่จะพังเงียบ ๆ
    if (typeof api.previewScheduleImport !== 'function') {
      renderPick('เว็บเพิ่งอัปเดต กรุณากด Ctrl + F5 (หรือรีเฟรชหน้า) แล้วลองใหม่');
      return;
    }

    renderReading(file);
    try {
      const preview = await api.previewScheduleImport(file);
      mode = defaultMode(preview);
      if (!closed) renderPreview(preview);
    } catch (error) {
      if (!closed) renderPick(error.message);
    }
  }

  function renderReading(file) {
    setStep(1);
    replace(body, [
      el('div', { class: 'import-loading', role: 'status' }, [
        el('span', { class: 'spinner', 'aria-hidden': 'true' }),
        el('div', { text: `กำลังอ่านและตรวจตารางเรียนใน ${file.name}…` }),
      ]),
    ]);
    replace(actions, [
      el('button', { class: 'btn', type: 'button', text: 'ยกเลิก', onclick: close }),
    ]);
  }

  // ---------------------------------------------------------- 2. ตรวจตัวอย่าง

  function renderPreview(preview, errorMessage = '') {
    setStep(1);
    const schedules = [...(preview.schedules ?? [])].sort(compareSchedules);
    const warnings = preview.warnings ?? [];
    const newRooms = preview.newRooms ?? [];
    const replacedRooms = preview.existingRoomNumbers ?? [];

    let roomFilter = '';
    const tableBox = el('div', {});
    const countLine = el('span', { class: 'dim small-note' });

    const roomSelect = el(
      'select',
      {
        class: 'inline-select',
        'aria-label': 'ดูตัวอย่างของห้อง',
        onchange: (event) => {
          roomFilter = event.target.value;
          paintTable();
        },
      },
      [
        el('option', { value: '', text: `ทุกห้อง (${preview.roomCount})` }),
        ...(preview.roomNumbers ?? []).map((room) =>
          el('option', {
            value: room,
            text: `ห้อง ${room} (${schedules.filter((row) => row.roomNumber === room).length} คาบ)`,
          }),
        ),
      ],
    );

    function paintTable() {
      const rows = roomFilter
        ? schedules.filter((row) => row.roomNumber === roomFilter)
        : schedules;
      const shown = roomFilter ? rows : rows.slice(0, PREVIEW_LIMIT);
      countLine.textContent =
        shown.length < rows.length
          ? `แสดง ${shown.length} จาก ${rows.length} รายการ · เลือกห้องเพื่อดูครบ`
          : `${rows.length} รายการ`;

      let previousRoom = null;
      replace(
        tableBox,
        el('div', { class: 'table-wrap scroll-y import-table' }, [
          el('table', { class: 'data' }, [
            el('thead', {}, [
              el('tr', {}, [
                el('th', { text: 'ห้อง' }),
                el('th', { text: 'วัน' }),
                el('th', { text: 'เวลา' }),
                el('th', { text: 'วิชา' }),
                el('th', { text: 'กลุ่มเรียน' }),
                el('th', { text: 'อาจารย์' }),
              ]),
            ]),
            el(
              'tbody',
              {},
              shown.map((row) => {
                const newRoom = row.roomNumber !== previousRoom;
                previousRoom = row.roomNumber;
                return el('tr', { class: newRoom ? 'day-start' : null }, [
                  el('td', {
                    class: newRoom ? 'date-cell' : 'date-cell repeat',
                    text: row.roomNumber,
                  }),
                  el('td', { text: DAY_NAMES[row.dayOfWeek] ?? '—' }),
                  el('td', { class: 'mono', text: `${row.startTime}-${row.endTime}` }),
                  el('td', { class: 'wrap', text: row.subjectName }),
                  el('td', { text: row.section || '—' }),
                  el('td', { class: 'wrap', text: row.instructor || '—' }),
                ]);
              }),
            ),
          ]),
        ]),
      );
    }

    const primaryButton = el('button', {
      class: 'btn btn-primary',
      type: 'button',
      onclick: () => renderConfirm(preview),
    });

    const stat = (value, label, tone = '') =>
      el('div', { class: `import-stat${tone ? ` ${tone}` : ''}` }, [
        el('b', { text: String(value) }),
        el('span', { text: label }),
      ]);

    replace(body, [
      errorMessage ? el('div', { class: 'login-error', role: 'alert', text: errorMessage }) : null,
      el('div', { class: 'import-file' }, [
        el('span', { class: 'import-file-icon', html: uiIcons.sheet(18) }),
        el('div', { class: 'grow' }, [
          el('div', { class: 'import-file-name', text: preview.fileName }),
          el('div', {
            class: 'dim small-note',
            text: preview.semester ? `ภาคเรียน ${preview.semester}` : 'ไม่ระบุภาคเรียนในไฟล์',
          }),
        ]),
      ]),
      el('div', { class: 'import-stats' }, [
        stat(preview.roomCount, 'ห้องในไฟล์'),
        stat(preview.scheduleCount, 'คาบเรียน'),
        stat(newRooms.length, 'ห้องใหม่', newRooms.length > 0 ? 'info' : ''),
        stat(warnings.length, 'ข้อสังเกต', warnings.length > 0 ? 'warn' : ''),
      ]),
      warnings.length > 0 ? warningNote(warnings) : null,
      newRooms.length > 0
        ? el('div', { class: 'import-note info' }, [
            el('div', { class: 'note-title', text: `จะสร้างห้องใหม่ ${newRooms.length} ห้อง` }),
            el('div', {
              text:
                newRooms
                  .map((room) => `${room.roomNumber} (${floorLabel(room.floorNumber)})`)
                  .join(' · ') + ' — ห้องจะถูกสร้างเมื่อกดยืนยันนำเข้าเท่านั้น',
            }),
          ])
        : null,
      replacedRooms.length > 0
        ? el('div', { class: 'import-note' }, [
            el('div', {
              class: 'note-title',
              text: `ตารางเดิมของ ${replacedRooms.length} ห้องนี้จะถูกแทนที่`,
            }),
            el(
              'div',
              { class: 'import-rooms' },
              replacedRooms.map((room) => el('span', { class: 'count-badge', text: room })),
            ),
            needsModeChoice(preview)
              ? null
              : el('div', { class: 'dim small-note', text: 'ห้องที่ไม่อยู่ในไฟล์จะไม่ถูกแตะ' }),
          ])
        : null,
      needsModeChoice(preview) ? modeChooser(preview, () => paintPrimary()) : null,
      el('div', { class: 'import-table-head' }, [
        el('div', { class: 'row', style: { gap: '8px' } }, [
          el('b', { class: 'small-note', text: 'ตัวอย่างรายการ' }),
          countLine,
        ]),
        roomSelect,
      ]),
      tableBox,
    ]);
    paintTable();

    replace(actions, [
      el('button', {
        class: 'btn',
        type: 'button',
        text: 'เลือกไฟล์อื่น',
        onclick: () => renderPick(),
      }),
      el(
        'button',
        {
          class: 'btn',
          type: 'button',
          title: 'บันทึกผลที่แปลงแล้วเป็น CSV (UTF-8) เก็บไว้หรือแก้ใน Excel แล้วนำกลับเข้ามาได้',
          onclick: () =>
            downloadText(
              preview.csv,
              `${baseName(preview.fileName)}.csv`,
              'text/csv;charset=utf-8',
            ),
        },
        [svg(uiIcons.sheet(15)), 'บันทึก CSV'],
      ),
      el('span', { class: 'actions-spacer' }),
      primaryButton,
    ]);
    paintPrimary();

    function paintPrimary() {
      primaryButton.disabled = schedules.length === 0 || mode == null;
      primaryButton.textContent =
        mode == null
          ? 'เลือกวิธีนำเข้าด้านบนก่อน'
          : mode === 'all'
            ? `เปลี่ยนภาคเรียน · นำเข้า ${preview.scheduleCount} รายการ`
            : `นำเข้า ${preview.scheduleCount} รายการ`;
    }
  }

  /**
   * ตัวเลือกว่าห้องที่มีตารางอยู่แต่ไม่อยู่ในไฟล์ จะเก็บตารางเดิมไว้หรือล้างทิ้ง
   * ใช้ radio จริง (ไม่ใช่ปุ่มหน้าตาเหมือน radio) กด Tab และลูกศรเลือกได้
   */
  function modeChooser(preview, onChange) {
    const outside = roomsOutsideFile(preview);
    const outsideClasses = outside.reduce((sum, room) => sum + room.count, 0);
    const sample = outside.slice(0, 8).map((room) => room.roomNumber).join(', ') +
      (outside.length > 8 ? ` และอีก ${outside.length - 8} ห้อง` : '');
    const semesterDiffers =
      preview.semester && currentSemester && preview.semester !== currentSemester;

    const option = (value, title, detail) => {
      const input = el('input', {
        type: 'radio',
        name: 'importMode',
        value,
        checked: mode === value,
        onchange: () => {
          mode = value;
          for (const card of box.querySelectorAll('.mode-option')) {
            card.classList.toggle('sel', card.dataset.value === value);
          }
          onChange();
        },
      });
      return el(
        'label',
        { class: `mode-option${mode === value ? ' sel' : ''}`, dataset: { value } },
        [
          input,
          el('span', { class: 'mode-text' }, [
            el('b', { text: title }),
            el('span', { text: detail }),
          ]),
        ],
      );
    };

    const box = el('fieldset', { class: 'import-mode' }, [
      el('legend', {
        text: `อีก ${outside.length} ห้องมีตารางอยู่ในระบบแต่ไม่อยู่ในไฟล์นี้ ให้ทำอย่างไร?`,
      }),
      semesterDiffers
        ? el('div', {
            class: 'mode-hint',
            text:
              `ไฟล์นี้เป็นภาคเรียน ${preview.semester} แต่ตารางในระบบเป็น ${currentSemester} ` +
              'จึงเลือก "เปลี่ยนภาคเรียน" ไว้ให้',
          })
        : !preview.semester || !currentSemester
          ? el('div', {
              class: 'mode-hint',
              text: 'ระบบไม่รู้ว่าไฟล์นี้เป็นภาคเรียนเดียวกับตารางที่ใช้อยู่หรือไม่ กรุณาเลือก',
            })
          : null,
      option(
        'all',
        'เปลี่ยนภาคเรียน — ล้างตารางเดิมของทุกห้อง',
        `${sample} จะไม่มีคาบเรียนเหลือ (${outsideClasses} คาบ) · ใช้ตอนขึ้นภาคเรียนใหม่`,
      ),
      option(
        'rooms',
        'เก็บตารางเดิมของห้องเหล่านั้นไว้',
        `แทนที่เฉพาะ ${preview.roomCount} ห้องที่อยู่ในไฟล์ · ใช้เมื่อแก้ตารางบางห้องระหว่างภาคเรียน`,
      ),
    ]);
    return box;
  }

  // --------------------------------------------------------------- 3. ยืนยัน

  function renderConfirm(preview) {
    setStep(2);
    const newRooms = preview.newRooms ?? [];
    const replaced = (preview.existingRoomNumbers ?? []).length;
    const parts = [];
    if (replaced > 0) parts.push(`แทนที่ตารางเดิมของ ${replaced} ห้อง`);
    if (newRooms.length > 0) parts.push(`สร้างห้องใหม่ ${newRooms.length} ห้อง`);
    let message =
      `นำเข้า ${preview.scheduleCount} รายการให้ ${preview.roomCount} ห้อง` +
      (parts.length > 0 ? ` (${parts.join(' และ')})` : '') +
      ' ยืนยันไหม?';
    if (mode === 'all') {
      const rooms = new Set(currentSchedules.map((row) => row.roomNumber)).size;
      message =
        `เปลี่ยนเป็นตาราง${preview.semester ? `ภาคเรียน ${preview.semester}` : 'ชุดใหม่'}: ` +
        `ล้างตารางเดิมทุกห้อง (${currentSchedules.length} คาบ ใน ${rooms} ห้อง) ` +
        `แล้วนำเข้า ${preview.scheduleCount} รายการให้ ${preview.roomCount} ห้อง` +
        (newRooms.length > 0 ? ` และสร้างห้องใหม่ ${newRooms.length} ห้อง` : '') +
        ' ยืนยันไหม?';
    }

    const confirmButton = el('button', {
      class: 'btn btn-primary',
      type: 'button',
      text: 'ยืนยันนำเข้า',
      onclick: () => commit(preview, confirmButton, backButton),
    });
    const backButton = el('button', {
      class: 'btn',
      type: 'button',
      text: 'กลับไปตรวจ',
      onclick: () => renderPreview(preview),
    });

    replace(actions, [
      el('div', { class: 'import-confirm', role: 'alert' }, [
        el('span', { class: 'note-icon', html: uiIcons.alert(18) }),
        el('span', { class: 'grow', text: message }),
      ]),
      backButton,
      confirmButton,
    ]);
    confirmButton.focus();
  }

  async function commit(preview, confirmButton, backButton) {
    busy = true;
    confirmButton.disabled = true;
    backButton.disabled = true;
    closeButton.disabled = true;
    confirmButton.textContent = 'กำลังนำเข้า…';
    try {
      const result = await api.commitScheduleImport(preview, {
        replaceAll: mode === 'all',
      });
      busy = false;
      closeButton.disabled = false;
      renderDone(result);
      if (onImported) await onImported(result);
    } catch (error) {
      busy = false;
      closeButton.disabled = false;
      // ไม่มีอะไรถูกบันทึก (Backend ทำทั้งชุดใน transaction) กลับไปหน้าตรวจพร้อมข้อความ
      renderPreview(preview, `นำเข้าไม่สำเร็จ ตารางเดิมยังอยู่ครบ: ${error.message}`);
    }
  }

  function renderDone(result) {
    setStep(3);
    const created = result.createdRooms ?? [];
    replace(body, [
      el('div', { class: 'import-done', role: 'status' }, [
        el('span', { class: 'done-icon', html: uiIcons.checkCircle(44) }),
        el('h4', { text: 'นำเข้าตารางเรียนเรียบร้อย' }),
        el('p', {
          text:
            `นำเข้า ${result.importedCount} รายการ สำหรับ ${result.replacedRooms?.length ?? 0} ห้อง` +
            (created.length > 0 ? ` · สร้างห้องใหม่ ${created.length} ห้อง` : ''),
        }),
        result.replacedAll
          ? el('p', {
              text:
                `ล้างตารางเดิมของทุกห้องแล้ว (${result.removedCount ?? 0} คาบ)` +
                (result.semester ? ` · ตอนนี้ใช้ตารางภาคเรียน ${result.semester}` : ''),
            })
          : null,
        el('p', {
          class: 'dim small-note',
          text: 'ระบบปิดแอร์อัตโนมัติใช้ตารางใหม่นี้ตัดสินว่า "ในคาบ" หรือ "นอกคาบ" ทันที',
        }),
      ]),
    ]);
    replace(actions, [
      el('span', { class: 'actions-spacer' }),
      el('button', { class: 'btn btn-primary', type: 'button', text: 'เสร็จ', onclick: close }),
    ]);
  }

  renderPick();
}

// ------------------------------------------------------------------ ตัวช่วย

function warningNote(warnings) {
  const limit = 5;
  const list = el('ul', {});
  const paint = (all) =>
    replace(
      list,
      (all ? warnings : warnings.slice(0, limit)).map((text) => el('li', { text })),
    );
  paint(false);
  return el('div', { class: 'import-note warn' }, [
    el('div', { class: 'note-title', text: `ข้อสังเกตจากการตรวจไฟล์ ${warnings.length} ข้อ` }),
    list,
    warnings.length > limit
      ? el('button', {
          class: 'link-btn',
          type: 'button',
          text: `ดูทั้งหมด (อีก ${warnings.length - limit} ข้อ)`,
          onclick: (event) => {
            paint(true);
            event.currentTarget.remove();
          },
        })
      : null,
  ]);
}

function compareSchedules(a, b) {
  return (
    a.roomNumber.localeCompare(b.roomNumber) ||
    a.dayOfWeek - b.dayOfWeek ||
    a.startTime.localeCompare(b.startTime)
  );
}

function baseName(fileName) {
  return String(fileName ?? 'ตารางเรียน').replace(/\.[^.]+$/, '') || 'ตารางเรียน';
}

const DAY_CODES = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

/**
 * ตารางเรียนเป็น CSV รูปแบบเดียวกับที่ Backend ส่งออก (schedulesToCsv ใน
 * backend/src/utils/schedule-import.js) จึงนำกลับเข้ามาด้วยปุ่มนำเข้าได้ทันที
 * ใช้สำรองตารางที่ใช้อยู่ก่อนล้างหรือเปลี่ยนภาคเรียน
 */
export function schedulesToCsv(schedules, semester = '') {
  const header = [
    'semester',
    'room_code',
    'day',
    'start_time',
    'end_time',
    'subject',
    'section',
    'instructor',
    'enabled',
  ];
  const rows = [...schedules].sort(compareSchedules).map((row) => [
    semester,
    row.roomNumber,
    DAY_CODES[row.dayOfWeek] ?? '',
    row.startTime,
    row.endTime,
    row.subjectName,
    row.section ?? '',
    row.instructor ?? '',
    'true',
  ]);
  const escape = (value) => {
    const text = String(value ?? '');
    return /[",\r\n]/.test(text) ? `"${text.replace(/"/g, '""')}"` : text;
  };
  return '\uFEFF' + [header, ...rows].map((row) => row.map(escape).join(',')).join('\r\n') + '\r\n';
}

/** ให้เบราว์เซอร์บันทึกข้อความเป็นไฟล์ (ใช้กับ CSV) */
export function downloadText(text, fileName, type) {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const link = el('a', { href: url, download: fileName });
  document.body.appendChild(link);
  link.click();
  link.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 4000);
}
