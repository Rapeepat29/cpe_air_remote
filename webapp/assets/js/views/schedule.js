/**
 * หน้าตารางเรียน
 *
 * ตารางเรียนไม่ได้มีไว้ดูเฉย ๆ — ระบบปิดแอร์อัตโนมัติใช้มันตัดสินว่าตอนนี้
 * เป็น "ในคาบเรียน" (รอ 15 นาที) หรือ "นอกคาบเรียน" (รอ 5 นาที) ข้อมูลผิด
 * จึงแปลว่าแอร์โดนปิดผิดจังหวะ หน้านี้เลยต้องแก้ไขได้ ไม่ใช่แค่แสดงผล
 */

import { api } from '../api.js';
import { el, replace, emptyState, svg } from '../dom.js';
import { DAY_NAMES, floorLabel, isoDate, thaiShortDate } from '../format.js';
import { icons } from '../icons.js';
import { uiIcons } from '../icons-ui.js';
import { loaders, roomsByFloor, state } from '../store.js';
import { confirmAction, openForm, toastError, toastOk } from '../ui.js';
import { openScheduleImport, schedulesToCsv, downloadText } from './schedule-import.js';
import { createTermCalendar, termStatusLine } from './term-calendar.js';

let selectedDay = new Date().getDay();

/**
 * 'all' = ทุกชั้น แสดงเฉพาะห้องที่มีคาบในวันนั้น
 * คำถามที่ถามบ่อยคือ "วันนี้ห้องไหนมีเรียนบ้าง" ไม่ใช่ "ชั้น 2 มีห้องอะไร"
 */
const ALL = 'all';
let selectedFloor = ALL;

export default {
  title: 'ตารางเรียน',
  subtitle: 'ตารางการใช้ห้องตามคาบเรียน ใช้กำหนดจังหวะปิดแอร์อัตโนมัติ',

  async mount(root) {
    const infoBar = el('div', { class: 'timetable-bar' });
    const dayTabs = el('div', { class: 'tabbar' });
    const floorTabs = el('div', { class: 'tabbar section-gap' });
    const toolbar = el('div', { class: 'sched-toolbar' });
    const note = el('div', { class: 'hidden-note' });
    const grid = el('div', { class: 'sched-grid' });

    const calendar = createTermCalendar({ onChanged: () => update() });

    replace(root, [infoBar, calendar.element, dayTabs, floorTabs, toolbar, grid, note]);

    function update() {
      renderInfoBar();
      calendar.render();
      const groups = roomsByFloor();
      if (
        selectedFloor !== ALL &&
        !groups.some((group) => group.floor === selectedFloor)
      ) {
        selectedFloor = ALL;
      }

      const todayIndex = new Date().getDay();
      replace(
        dayTabs,
        DAY_NAMES.map((name, index) =>
          el('button', {
            class:
              `tab small${index === selectedDay ? ' active' : ''}` +
              `${index === todayIndex ? ' today' : ''}`,
            type: 'button',
            text: name,
            title: index === todayIndex ? `วัน${name} (วันนี้)` : `วัน${name}`,
            'aria-pressed': index === selectedDay ? 'true' : 'false',
            onclick: () => {
              selectedDay = index;
              update();
            },
          }),
        ),
      );

      const floorTab = (key, label) =>
        el('button', {
          class: `tab${key === selectedFloor ? ' active' : ''}`,
          type: 'button',
          text: label,
          'aria-pressed': key === selectedFloor ? 'true' : 'false',
          onclick: () => {
            selectedFloor = key;
            update();
          },
        });
      replace(floorTabs, [
        floorTab(ALL, 'ทุกชั้น'),
        ...groups.map((group) => floorTab(group.floor, floorLabel(group.floor))),
      ]);

      const allRooms = groups.flatMap((group) => group.rooms);
      const floorRooms =
        selectedFloor === ALL
          ? allRooms
          : groups.find((group) => group.floor === selectedFloor)?.rooms ?? [];
      const today = new Date();
      const isToday = today.getDay() === selectedDay;
      const nowText =
        `${String(today.getHours()).padStart(2, '0')}:` +
        `${String(today.getMinutes()).padStart(2, '0')}`;

      const byRoom = new Map();
      for (const item of state.schedules) {
        if (item.dayOfWeek !== selectedDay) continue;
        if (!byRoom.has(item.roomNumber)) byRoom.set(item.roomNumber, []);
        byRoom.get(item.roomNumber).push(item);
      }

      const totalRows = [...byRoom.values()].reduce(
        (sum, list) => sum + list.length,
        0,
      );
      const floorRows = floorRooms.reduce(
        (sum, room) => sum + (byRoom.get(room.roomNumber)?.length ?? 0),
        0,
      );

      // ทุกชั้น: ซ่อนห้องที่ว่างทั้งวัน ไม่งั้นการ์ดว่าง ๆ 20 ใบจะดันห้องที่มีเรียนลงไปข้างล่าง
      const rooms =
        selectedFloor === ALL
          ? floorRooms.filter((room) => byRoom.has(room.roomNumber))
          : floorRooms;
      const hiddenCount = floorRooms.length - rooms.length;

      const summary =
        selectedFloor === ALL
          ? `วัน${DAY_NAMES[selectedDay]} · ทั้งอาคาร ${totalRows} คาบ ใน ${byRoom.size} ห้อง`
          : `วัน${DAY_NAMES[selectedDay]} · ${floorLabel(selectedFloor)} ${floorRows} คาบ ` +
            `(ทั้งอาคาร ${totalRows} คาบ)`;

      const isAdmin = state.user?.role === 'admin';
      replace(toolbar, [
        el('div', { class: 'pill', text: summary }),
        isAdmin
          ? el('div', { class: 'row', style: { gap: '8px' } }, [
              importButton('btn btn-sm'),
              el(
                'button',
                {
                  class: 'btn btn-sm btn-primary',
                  type: 'button',
                  onclick: () => addSchedule(update),
                },
                [svg(icons.plus(14)), 'เพิ่มคาบเรียน'],
              ),
            ])
          : null,
      ]);

      note.textContent =
        hiddenCount > 0
          ? `ไม่แสดง ${hiddenCount} ห้องที่ไม่มีคาบเรียนในวันนี้ · เลือกชั้นด้านบนเพื่อดูทุกห้องของชั้นนั้น`
          : '';
      note.hidden = hiddenCount === 0;

      // ยังไม่มีตารางเรียนเลยทั้งระบบ (เช่นเพิ่งตั้งระบบหรือขึ้นภาคเรียนใหม่)
      // ชี้ทางไปที่การนำเข้าจากไฟล์ ซึ่งเร็วกว่าการเพิ่มทีละคาบหลายเท่า
      if (state.schedules.length === 0 && !state.loading.schedules) {
        replace(grid, [
          el('div', { class: 'card empty-cta' }, [
            el('span', { class: 'dz-icon', html: uiIcons.sheet(26) }),
            el('div', { class: 'empty-cta-title', text: 'ยังไม่มีตารางเรียนในระบบ' }),
            el('div', {
              class: 'muted small-note',
              text: isAdmin
                ? 'นำเข้าไฟล์ Excel ตารางการใช้ห้องของคณะ หรือไฟล์ CSV ได้ในครั้งเดียว ' +
                  'ระบบปิดแอร์อัตโนมัติต้องใช้ตารางนี้แยก "ในคาบ" กับ "นอกคาบ"'
                : 'ติดต่อผู้ดูแลระบบให้นำเข้าตารางเรียน ' +
                  'ระบบปิดแอร์อัตโนมัติต้องใช้ตารางนี้แยก "ในคาบ" กับ "นอกคาบ"',
            }),
            isAdmin ? importButton('btn btn-primary') : null,
          ]),
        ]);
        note.hidden = true;
        return;
      }

      if (rooms.length === 0) {
        replace(
          grid,
          emptyState(
            selectedFloor === ALL
              ? `ไม่มีคาบเรียนในวัน${DAY_NAMES[selectedDay]}`
              : 'ยังไม่มีห้องในชั้นนี้',
          ),
        );
        return;
      }

      replace(
        grid,
        rooms.map((room) => {
          const rows = (byRoom.get(room.roomNumber) ?? []).sort((a, b) =>
            a.startTime.localeCompare(b.startTime),
          );
          return scheduleCard(room, rows, {
            isToday,
            nowText,
            onChanged: update,
          });
        }),
      );
    }

    /**
     * แถบบอกว่าตารางที่ใช้อยู่เป็นของภาคเรียนไหน ใครนำเข้าเมื่อไร
     *
     * ตารางแต่ละเทอมไม่เหมือนกัน ถ้าลืมเปลี่ยน ระบบปิดแอร์อัตโนมัติจะใช้คาบของเทอมเก่า
     * แถบนี้จึงอยู่บนสุดของหน้า ให้เห็นทันทีว่าตารางค้างของเทอมก่อนหรือเปล่า
     */
    function renderInfoBar() {
      const isAdmin = state.user?.role === 'admin';
      const schedules = state.schedules;
      if (schedules.length === 0) {
        infoBar.hidden = true;
        return;
      }
      infoBar.hidden = false;

      const roomCount = new Set(schedules.map((row) => row.roomNumber)).size;
      const info = state.timetable;
      const semester = info?.semester ?? '';
      const title = semester
        ? `ตารางเรียนภาคเรียน ${semester}`
        : 'ตารางเรียนที่ใช้อยู่';
      const details = [`${schedules.length} คาบ ใน ${roomCount} ห้อง`];
      if (info?.importedAt) {
        details.push(
          `นำเข้าเมื่อ ${thaiShortDate(info.importedAt)}` +
            (info.importedBy ? ` โดย ${info.importedBy}` : ''),
        );
      } else if (info === null) {
        details.push('ยังไม่ระบุภาคเรียน — นำเข้าจากไฟล์ครั้งถัดไประบบจะจำให้');
      }

      replace(infoBar, [
        el('span', { class: 'timetable-icon', html: uiIcons.sheet(18) }),
        el('div', { class: 'grow' }, [
          el('div', { class: 'timetable-title', text: title }),
          el('div', { class: 'timetable-sub', text: details.join(' · ') }),
          termStatusLine(semester, { onSetDates: (value) => calendar.setDatesFor(value) }),
        ]),
        el('div', { class: 'timetable-actions' }, [
          el(
            'button',
            {
              class: 'btn btn-sm',
              type: 'button',
              title: 'เก็บตารางทั้งหมดเป็นไฟล์ CSV ไว้สำรอง นำกลับเข้ามาได้ด้วยปุ่มนำเข้า',
              onclick: downloadCurrentCsv,
            },
            [svg(icons.download(14)), 'ดาวน์โหลด CSV'],
          ),
          isAdmin
            ? el(
                'button',
                {
                  class: 'btn btn-sm btn-danger',
                  type: 'button',
                  title: 'ใช้ตอนปิดภาคเรียน ข้อมูลไฟฟ้าไม่ถูกลบ',
                  onclick: (event) => clearAll(event.currentTarget),
                },
                [svg(icons.trash(14)), 'ล้างตารางทั้งหมด'],
              )
            : null,
        ]),
      ]);
    }

    function downloadCurrentCsv() {
      const semester = state.timetable?.semester ?? '';
      const label = semester ? semester.replace('/', '-') : 'ปัจจุบัน';
      downloadText(
        schedulesToCsv(state.schedules, semester),
        `ตารางเรียน-${label}-สำรอง-${isoDate()}.csv`,
        'text/csv;charset=utf-8',
      );
    }

    async function clearAll(button) {
      const count = state.schedules.length;
      const rooms = new Set(state.schedules.map((row) => row.roomNumber)).size;
      const semester = state.timetable?.semester;
      const ok = await confirmAction({
        title: 'ล้างตารางเรียนทั้งหมด?',
        subtitle:
          `ลบ ${count} คาบของ ${rooms} ห้อง${semester ? ` (ภาคเรียน ${semester})` : ''}\n\n` +
          'ข้อมูลไฟฟ้า ประวัติการแจ้งเตือน ห้อง และอุปกรณ์ ไม่ถูกลบ\n\n' +
          'ระหว่างที่ไม่มีตาราง ระบบถือว่าทุกห้องอยู่นอกคาบ: ห้องว่างเกิน 5 นาทีจะสั่งปิดแอร์ ' +
          'และแจ้งเตือนเมื่อมีคนเปิดแอร์ใช้\n\n' +
          'ถ้าตั้งวันเปิด–ปิดภาคเรียนไว้ในปฏิทินแล้ว ไม่ต้องล้างตารางตอนปิดภาค ระบบหยุดใช้ตารางเอง\n\n' +
          'ถ้ายังไม่ได้สำรอง กด "ยกเลิก" แล้วกด "ดาวน์โหลด CSV" ก่อน',
        confirmLabel: `ล้าง ${count} คาบ`,
        danger: true,
      });
      if (!ok) return;
      button.disabled = true;
      try {
        const result = await api.deleteAllSchedules();
        await Promise.all([loaders.schedules(), loaders.rooms()]);
        update();
        toastOk(`ล้างตารางเรียนแล้ว ${result?.deletedCount ?? count} คาบ`);
      } catch (error) {
        button.disabled = false;
        toastError(error.message);
      }
    }

    function importButton(className) {
      return el(
        'button',
        {
          class: className,
          type: 'button',
          title: 'นำเข้าตารางเรียนจากไฟล์ Excel (.xlsx) หรือ CSV เหมือนในแอปมือถือ',
          onclick: () =>
            openScheduleImport({
              current: {
                // undefined = Backend รุ่นเก่า ยังไม่รองรับ "เปลี่ยนภาคเรียน"
                supportsReplaceAll: state.timetable !== undefined,
                semester: state.timetable?.semester ?? '',
                schedules: state.schedules,
                terms: state.terms ?? [],
                today: state.today,
              },
              onImported: async (result) => {
                selectedFloor = ALL;
                // ดึงห้องใหม่ด้วย: จำนวนคาบของแต่ละห้องเปลี่ยน และห้องที่ถูกสร้าง
                // จากไฟล์ต้องขึ้นในแท็บชั้นและหน้าอื่นทันที
                await Promise.all([loaders.schedules(), loaders.rooms(), loaders.terms()]);
                update();
              },
            }),
        },
        [svg(uiIcons.upload(14)), 'นำเข้าจาก Excel / CSV'],
      );
    }

    update();
    await Promise.all([loaders.schedules(), loaders.terms()]);
    update();

    return { update };
  },
};

function scheduleCard(room, rows, { isToday, nowText, onChanged }) {
  const isAdmin = state.user?.role === 'admin';

  const head = el('div', { class: 'sched-card-head' }, [
    el('div', { class: 'sched-room' }, [
      svg(icons.building(15)),
      `ห้อง ${room.roomNumber}`,
    ]),
    el('span', {
      class: `badge-soft${rows.length === 0 ? ' dim' : ''}`,
      text: rows.length === 0 ? 'ว่างทั้งวัน' : `${rows.length} คาบ`,
    }),
  ]);

  if (rows.length === 0) {
    return el('div', { class: 'sched-card' }, [
      head,
      el('div', { class: 'sched-empty', text: 'ไม่มีคาบเรียนในวันนี้' }),
    ]);
  }

  return el('div', { class: 'sched-card' }, [
    head,
    ...rows.map((item) => {
      const now =
        isToday && nowText >= item.startTime && nowText < item.endTime;
      return el('div', { class: `sched-row${now ? ' now' : ''}` }, [
        el('div', {
          class: 'sched-time',
          text: `${item.startTime}-${item.endTime}`,
        }),
        el('div', { class: 'sched-info' }, [
          el('div', { class: 'course', text: item.subjectName }),
          el('div', {
            class: 'meta',
            text: [item.section, item.instructor].filter(Boolean).join(' · ') || '—',
          }),
        ]),
        isAdmin
          ? el('div', { class: 'row', style: { gap: '4px' } }, [
              iconAction(icons.edit(13), 'แก้ไข', () =>
                editSchedule(item, onChanged),
              ),
              iconAction(icons.trash(13), 'ลบ', () =>
                removeSchedule(item, onChanged),
              ),
            ])
          : null,
      ]);
    }),
  ]);
}

function iconAction(markup, title, onclick) {
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

function scheduleFields(values = {}) {
  return [
    {
      name: 'roomNumber',
      label: 'ห้อง',
      type: 'select',
      value: values.roomNumber ?? '',
      options: state.rooms.map((room) => ({
        value: room.roomNumber,
        label: `${room.roomNumber} · ${room.roomType}`,
      })),
      required: true,
    },
    {
      name: 'dayOfWeek',
      label: 'วัน',
      type: 'select',
      value: String(values.dayOfWeek ?? selectedDay),
      options: DAY_NAMES.map((name, index) => ({
        value: String(index),
        label: `วัน${name}`,
      })),
      required: true,
    },
    {
      name: 'subjectName',
      label: 'ชื่อวิชา',
      value: values.subjectName ?? '',
      required: true,
    },
    { name: 'section', label: 'กลุ่มเรียน', value: values.section ?? '' },
    { name: 'instructor', label: 'อาจารย์', value: values.instructor ?? '' },
    {
      name: 'startTime',
      label: 'เวลาเริ่ม',
      type: 'time',
      value: values.startTime ?? '08:00',
      required: true,
    },
    {
      name: 'endTime',
      label: 'เวลาเลิก',
      type: 'time',
      value: values.endTime ?? '10:00',
      required: true,
    },
  ];
}

function toPayload(values) {
  return {
    roomNumber: values.roomNumber,
    dayOfWeek: Number.parseInt(values.dayOfWeek, 10),
    subjectName: values.subjectName,
    section: values.section,
    instructor: values.instructor,
    startTime: values.startTime,
    endTime: values.endTime,
  };
}

async function addSchedule(onChanged) {
  const values = await openForm({
    title: 'เพิ่มคาบเรียน',
    subtitle: 'คาบที่ทับซ้อนกับคาบเดิมของห้องเดียวกันจะถูกปฏิเสธ',
    fields: scheduleFields(),
    submitLabel: 'เพิ่ม',
  });
  if (!values) return;
  try {
    await api.createSchedule(toPayload(values));
    toastOk('เพิ่มคาบเรียนแล้ว');
    await loaders.schedules();
    await loaders.rooms();
    onChanged();
  } catch (error) {
    toastError(error.message);
  }
}

async function editSchedule(item, onChanged) {
  const values = await openForm({
    title: 'แก้ไขคาบเรียน',
    subtitle: `${item.roomNumber} · ${item.subjectName}`,
    fields: scheduleFields(item),
  });
  if (!values) return;
  try {
    await api.updateSchedule(item.id, toPayload(values));
    toastOk('บันทึกการแก้ไขแล้ว');
    await loaders.schedules();
    onChanged();
  } catch (error) {
    toastError(error.message);
  }
}

async function removeSchedule(item, onChanged) {
  const ok = await confirmAction({
    title: 'ลบคาบเรียนนี้?',
    subtitle:
      `${item.roomNumber} · ${item.subjectName} ` +
      `${item.startTime}-${item.endTime}\n` +
      'ระบบปิดแอร์อัตโนมัติจะถือว่าช่วงเวลานี้เป็นนอกคาบเรียนทันที',
    confirmLabel: 'ลบ',
    danger: true,
  });
  if (!ok) return;
  try {
    await api.deleteSchedule(item.id);
    toastOk('ลบแล้ว');
    await loaders.schedules();
    await loaders.rooms();
    onChanged();
  } catch (error) {
    toastError(error.message);
  }
}
