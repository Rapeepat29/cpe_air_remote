/**
 * หน้าตารางเรียน
 *
 * ตารางเรียนไม่ได้มีไว้ดูเฉย ๆ — ระบบปิดแอร์อัตโนมัติใช้มันตัดสินว่าตอนนี้
 * เป็น "ในคาบเรียน" (รอ 15 นาที) หรือ "นอกคาบเรียน" (รอ 5 นาที) ข้อมูลผิด
 * จึงแปลว่าแอร์โดนปิดผิดจังหวะ หน้านี้เลยต้องแก้ไขได้ ไม่ใช่แค่แสดงผล
 */

import { api } from '../api.js';
import { el, replace, emptyState, svg } from '../dom.js';
import { DAY_NAMES, DAY_NAMES_SHORT, floorLabel } from '../format.js';
import { icons } from '../icons.js';
import { loaders, roomsByFloor, state } from '../store.js';
import { confirmAction, openForm, toastError, toastOk } from '../ui.js';

let selectedDay = new Date().getDay();
let selectedFloor = null;

export default {
  title: 'ตารางเรียน',
  subtitle: 'ตารางการใช้ห้องตามคาบเรียน ใช้กำหนดจังหวะปิดแอร์อัตโนมัติ',

  async mount(root) {
    const dayTabs = el('div', { class: 'tabbar' });
    const floorTabs = el('div', { class: 'tabbar section-gap' });
    const toolbar = el('div', {
      class: 'row between',
      style: { marginTop: '16px' },
    });
    const grid = el('div', { class: 'sched-grid' });

    replace(root, [dayTabs, floorTabs, toolbar, grid]);

    function update() {
      const groups = roomsByFloor();
      if (
        selectedFloor == null ||
        !groups.some((group) => group.floor === selectedFloor)
      ) {
        selectedFloor = groups[0]?.floor ?? null;
      }

      replace(
        dayTabs,
        DAY_NAMES.map((name, index) =>
          el('button', {
            class: `tab small${index === selectedDay ? ' active' : ''}`,
            type: 'button',
            text: `${DAY_NAMES_SHORT[index]}.`,
            title: `วัน${name}`,
            onclick: () => {
              selectedDay = index;
              update();
            },
          }),
        ),
      );

      replace(
        floorTabs,
        groups.map((group) =>
          el('button', {
            class: `tab${group.floor === selectedFloor ? ' active' : ''}`,
            type: 'button',
            text: floorLabel(group.floor),
            onclick: () => {
              selectedFloor = group.floor;
              update();
            },
          }),
        ),
      );

      const rooms =
        groups.find((group) => group.floor === selectedFloor)?.rooms ?? [];
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

      replace(toolbar, [
        el('div', { class: 'pill', text: `วัน${DAY_NAMES[selectedDay]} · ${totalRows} คาบในชั้นนี้และชั้นอื่น` }),
        state.user?.role === 'admin'
          ? el(
              'button',
              {
                class: 'btn btn-sm btn-primary',
                type: 'button',
                onclick: () => addSchedule(update),
              },
              [svg(icons.plus(14)), 'เพิ่มคาบเรียน'],
            )
          : null,
      ]);

      if (rooms.length === 0) {
        replace(grid, emptyState('ยังไม่มีห้องในชั้นนี้'));
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

    update();
    await loaders.schedules();
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
    style: { width: '26px', height: '26px' },
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
