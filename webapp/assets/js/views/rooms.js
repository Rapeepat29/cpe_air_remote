/**
 * หน้าห้องและการควบคุมเครื่องปรับอากาศ
 *
 * การ์ดห้องแสดงสามอย่างที่คนดูแลอาคารต้องรู้ก่อนเดินไปถึงห้อง:
 * มีคนอยู่ไหม แอร์ทำงานอยู่กี่เครื่อง และกำลังนับถอยหลังจะปิดอัตโนมัติหรือยัง
 *
 * นาฬิกานับถอยหลังเดินในเบราว์เซอร์เอง โดยนับจาก `autoOffDeadlineAt` ที่
 * เซิร์ฟเวอร์ส่งมา ไม่ได้ถามเซิร์ฟเวอร์ทุกวินาที เพราะเวลาเส้นตายเป็นค่าคงที่
 * ถามซ้ำก็ได้คำตอบเดิม — หลักการเดียวกับที่แอปมือถือใช้
 */

import { api } from '../api.js';
import { metricBox } from '../charts.js';
import { el, replace, emptyState, svg, toggle } from '../dom.js';
import {
  FAN_LABEL,
  MODE_LABEL,
  SWING_LABEL,
  clock,
  decimal,
  energy,
  floorLabel,
  relativeTime,
  time,
} from '../format.js';
import { icons } from '../icons.js';
import { uiIcons } from '../icons-ui.js';
import {
  airConditionersOf,
  liveReading,
  loaders,
  roomEnergyMap,
  roomsByFloor,
  sensorOf,
  state,
} from '../store.js';
import { confirmAction, toastError, toastInfo, toastOk } from '../ui.js';

const MODES = ['auto', 'cool', 'dry', 'fan', 'heat'];
const FANS = ['auto', 'low', 'medium', 'high', 'turbo'];
const SWINGS = ['off', 'top', 'upper', 'middle', 'lower', 'bottom', 'auto'];

const EXTRA_TOGGLES = [
  { key: 'eco', label: 'ประหยัดไฟ (Eco)' },
  { key: 'turbo', label: 'เทอร์โบ' },
  { key: 'sleep', label: 'โหมดนอน' },
  { key: 'quiet', label: 'เงียบ' },
  { key: 'displayLight', label: 'ไฟหน้าจอ' },
  { key: 'clean', label: 'ทำความสะอาด' },
  { key: 'horizontalSwing', label: 'ส่ายซ้าย–ขวา' },
];

/** ข้อจำกัดเฉพาะรุ่น ตรงกับที่ Backend ตรวจใน utils/air-conditioner.js */
function limitsFor(protocol) {
  if (String(protocol).toUpperCase() === 'SAIJO_DENKI') {
    return {
      minTemp: 18,
      maxTemp: 29,
      modes: ['cool', 'dry', 'fan'],
      swings: SWINGS.filter((value) => value !== 'off'),
      note: 'Saijo Denki: 18–29°C · ไม่มีคำสั่งปิด Swing',
    };
  }
  return {
    minTemp: 16,
    maxTemp: 30,
    modes: MODES,
    swings: SWINGS,
    note: '',
  };
}

/**
 * ตัวกรองของหน้านี้ จำไว้ข้ามการสลับหน้า
 *
 * ค่าเริ่มต้นคือ "ทุกชั้น" — รุ่นก่อนเปิดมาเห็นทีละชั้น คนที่อยากรู้ว่า
 * "ตอนนี้ห้องไหนเปิดแอร์อยู่บ้าง" ต้องกดไล่ทีละแท็บ ซึ่งเป็นคำถามที่ถามบ่อยที่สุด
 */
const ALL = 'all';

const view = {
  floor: ALL,
  search: '',
  runningOnly: false,
};

const hasRunningUnit = (room) =>
  airConditionersOf(room.roomNumber).some((unit) => unit.acRunning);

export default {
  title: 'ห้องและควบคุม',
  subtitle: 'เลือกห้องเพื่อดูสถานะและสั่งงานเครื่องปรับอากาศผ่าน MQTT',

  mount(root, context) {
    const tabBar = el('div', { class: 'tabbar' });
    const runningChip = el('button', { class: 'tab small', type: 'button' });
    const grid = el('div', {});

    // ช่องค้นหาสร้างครั้งเดียวตอน mount ไม่สร้างใหม่ทุกรอบที่ข้อมูลเข้า
    // (ทุก 10 วินาที) ไม่งั้นเคอร์เซอร์จะหลุดระหว่างพิมพ์
    const searchInput = el('input', {
      class: 'search-input',
      type: 'search',
      placeholder: 'ค้นหาห้อง เช่น 16203 หรือ Lab',
      'aria-label': 'ค้นหาห้อง',
      value: view.search,
      oninput: (event) => {
        view.search = event.target.value;
        update();
      },
    });
    const searchBox = el('div', { class: 'search-box' }, [
      svg(uiIcons.search(16)),
      searchInput,
    ]);

    runningChip.addEventListener('click', () => {
      view.runningOnly = !view.runningOnly;
      update();
    });

    replace(root, [
      el('div', { class: 'rooms-toolbar' }, [tabBar, searchBox]),
      el('div', { class: 'rooms-filters' }, [
        runningChip,
        el('span', {
          class: 'dim small-note',
          text: 'กดที่การ์ดห้องเพื่อเปิดรีโมต',
        }),
      ]),
      grid,
    ]);

    function floorTab(key, label, count) {
      return el(
        'button',
        {
          class: `tab${key === view.floor ? ' active' : ''}`,
          type: 'button',
          'aria-pressed': key === view.floor ? 'true' : 'false',
          onclick: () => {
            view.floor = key;
            update();
          },
        },
        [label, el('span', { class: 'tab-count', text: String(count) })],
      );
    }

    function update() {
      const groups = roomsByFloor();
      if (
        view.floor !== ALL &&
        !groups.some((group) => group.floor === view.floor)
      ) {
        view.floor = ALL;
      }

      const total = groups.reduce((sum, group) => sum + group.rooms.length, 0);
      replace(tabBar, [
        floorTab(ALL, 'ทุกชั้น', total),
        ...groups.map((group) =>
          floorTab(group.floor, floorLabel(group.floor), group.rooms.length),
        ),
      ]);

      const runningRooms = state.rooms.filter(hasRunningUnit).length;
      runningChip.className = `tab small${view.runningOnly ? ' active' : ''}`;
      runningChip.setAttribute('aria-pressed', view.runningOnly ? 'true' : 'false');
      replace(runningChip, [
        el('span', { class: 'status-dot on' }),
        `เฉพาะห้องที่แอร์ทำงาน (${runningRooms})`,
      ]);

      const query = view.search.trim().toLowerCase();
      const matches = (room) => {
        if (view.runningOnly && !hasRunningUnit(room)) return false;
        if (!query) return true;
        return `${room.roomNumber} ${room.roomType ?? ''}`
          .toLowerCase()
          .includes(query);
      };

      const visible = groups
        .filter((group) => view.floor === ALL || group.floor === view.floor)
        .map((group) => ({ ...group, rooms: group.rooms.filter(matches) }))
        .filter((group) => group.rooms.length > 0);

      if (visible.length === 0) {
        replace(
          grid,
          emptyState(
            query || view.runningOnly
              ? 'ไม่พบห้องที่ตรงกับตัวกรอง\nลองล้างคำค้นหา หรือปิดตัวกรอง "เฉพาะห้องที่แอร์ทำงาน"'
              : 'ยังไม่มีห้องในชั้นนี้',
          ),
        );
        return;
      }

      const energyByRoom = roomEnergyMap();
      const cards = (rooms) =>
        el(
          'div',
          { class: 'room-grid' },
          rooms.map((room) => roomCard(room, energyByRoom, context)),
        );

      // ดูทีละชั้นไม่ต้องมีหัวข้อ ดูทุกชั้นแบ่งหัวข้อตามชั้นให้กวาดตาง่าย
      if (view.floor !== ALL) {
        replace(grid, cards(visible[0].rooms));
        return;
      }
      replace(
        grid,
        visible.flatMap((group) => {
          const running = group.rooms.filter(hasRunningUnit).length;
          return [
            el('h2', { class: 'floor-heading' }, [
              floorLabel(group.floor),
              el('span', {
                class: 'count-badge',
                text: `${group.rooms.length} ห้อง · แอร์ทำงาน ${running} ห้อง`,
              }),
            ]),
            cards(group.rooms),
          ];
        }),
      );
    }

    update();
    return { update };
  },
};

// ------------------------------------------------------------ การ์ดห้อง

function roomCard(room, energyByRoom, context) {
  const units = airConditionersOf(room.roomNumber);
  const running = units.filter((unit) => unit.acRunning).length;
  const online = units.filter((unit) => unit.isOnline).length;
  const sensor = sensorOf(room.roomNumber);
  const counting = room.autoOffSecondsRemaining != null;

  const icon = el('div', { class: 'room-icon' });
  icon.innerHTML = icons.building(17);

  const occupancyText = !sensor
    ? 'ยังไม่ติดตั้งเซ็นเซอร์'
    : !sensor.isOnline
      ? 'เซ็นเซอร์ออฟไลน์'
      : !sensor.radarAvailable
        ? 'เซ็นเซอร์ยังไม่พร้อม'
        : sensor.isOccupied
          ? 'มีคนอยู่ในห้อง'
          : 'ไม่มีคนอยู่ในห้อง';

  const occupancyTone =
    sensor?.isOnline && sensor?.radarAvailable && sensor?.isOccupied ? 'info' : 'off';

  const stateClass = counting
    ? ' counting'
    : running > 0
      ? ' running'
      : units.length === 0
        ? ' idle vacant'
        : ' idle';

  // ห้องที่ยังไม่ติดตั้งแอร์ ไม่มีอะไรให้ควบคุมหรือวัด แสดงแค่ชื่อกับป้ายเดียวพอ
  // ไม่งั้นการ์ดจะเต็มไปด้วย "0 kWh · 0/0 · ยังไม่มี..." จนกลบห้องที่ใช้งานจริง
  if (units.length === 0) {
    return el(
      'button',
      {
        class: `room-card${stateClass}`,
        type: 'button',
        'aria-label': `ห้อง ${room.roomNumber} ยังไม่ติดตั้งแอร์`,
        onclick: () => context.openRoom(room.roomNumber),
      },
      [
        el('div', { class: 'room-card-top' }, [
          el('div', { class: 'grow' }, [
            el('div', { class: 'room-card-name', text: `ห้อง ${room.roomNumber}` }),
            el('div', { class: 'room-card-desc', text: room.roomType || '—' }),
          ]),
        ]),
        el('div', { class: 'room-card-chips' }, [
          el('span', { class: 'status-chip off', text: 'ยังไม่ติดตั้งแอร์' }),
          sensor
            ? el('span', { class: `status-chip ${occupancyTone}`, text: occupancyText })
            : null,
        ]),
      ],
    );
  }

  const card = el(
    'button',
    {
      class: `room-card${stateClass}`,
      type: 'button',
      'aria-label': `ห้อง ${room.roomNumber} เปิดรีโมต`,
      onclick: () => context.openRoom(room.roomNumber),
    },
    [
      el('div', { class: 'room-card-top' }, [
        el('div', { class: 'grow' }, [
          el('div', { class: 'room-card-name', text: `ห้อง ${room.roomNumber}` }),
          el('div', { class: 'room-card-desc', text: room.roomType || '—' }),
        ]),
        icon,
      ]),
      el('div', { class: 'room-card-chips' }, [
        el('span', {
          class: `status-chip ${running > 0 ? 'done' : 'off'}`,
          text:
            running > 0 ? `แอร์เปิด ${running}/${units.length}` : 'แอร์ปิดทั้งหมด',
        }),
        el('span', { class: `status-chip ${occupancyTone}`, text: occupancyText }),
      ]),
      counting
        ? countdownStrip(room)
        : el('div', { class: 'room-card-energy' }, [
            'ใช้ไฟ ',
            el('b', { text: energy(energyByRoom.get(room.roomNumber) ?? 0) }),
            ' ในช่วงที่เลือก',
          ]),
      el('div', { class: 'room-card-foot' }, [
        el('div', { class: 'status-dot-row' }, [
          el('span', {
            class: `status-dot${online === units.length ? ' on' : ' warn'}`,
          }),
          el('span', {
            class: online === units.length ? null : 'warn',
            text:
              online === units.length
                ? 'บอร์ดออนไลน์ครบ'
                : `บอร์ดออฟไลน์ ${units.length - online} ตัว`,
          }),
        ]),
        el('span', {
          class: 'devices-chip',
          text: `${online}/${units.length}`,
          title: 'บอร์ด ESP32 ที่ออนไลน์ / ทั้งหมด',
        }),
      ]),
    ],
  );

  return card;
}

/**
 * แถบนับถอยหลัง
 *
 * ตัวเลขเดินเองทุกวินาทีจากเส้นตายที่เซิร์ฟเวอร์ให้มา ถ้าเลยเส้นตายแล้ว
 * แปลว่ากำลังยิงคำสั่งปิดอยู่ จึงเปลี่ยนข้อความแทนที่จะโชว์ 00:00 ค้างไว้
 */
function countdownStrip(room) {
  const strip = el('div', { class: 'countdown-strip' }, [
    svg(icons.clock(14, 2.2)),
    el('span', { text: 'กำลังนับถอยหลังปิดแอร์' }),
    el('span', { class: 'clock', text: '--:--' }),
  ]);
  const clockNode = strip.querySelector('.clock');
  const labelNode = strip.querySelector('span');

  const deadline = room.autoOffDeadlineAt
    ? new Date(room.autoOffDeadlineAt).getTime()
    : null;

  // ตอนเรียก tick() ครั้งแรกแถบยังไม่ได้ถูกใส่ลงหน้า (isConnected = false)
  // รุ่นก่อนจึงไปเรียก clearInterval(handle) ก่อนประกาศ handle แล้วพังทั้งหน้า
  // ทุกครั้งที่มีห้องกำลังนับถอยหลัง จึงหยุดนาฬิกาเฉพาะเมื่อแถบ "เคยอยู่ในหน้า
  // แล้วถูกเอาออก" (หน้าวาดใหม่หรือเปลี่ยนหน้า) หรือไม่เคยถูกใส่ลงหน้าเลยเกิน 5 วินาที
  let handle = null;
  let mounted = false;
  const createdAt = Date.now();
  const tick = () => {
    if (strip.isConnected) {
      mounted = true;
    } else if (mounted || Date.now() - createdAt > 5000) {
      if (handle != null) window.clearInterval(handle);
      return;
    }
    if (deadline == null) return;
    const remaining = Math.round((deadline - Date.now()) / 1000);
    if (remaining <= 0) {
      labelNode.textContent = 'กำลังส่งคำสั่งปิด';
      clockNode.textContent =
        room.autoOffAttempts > 0 ? `ครั้งที่ ${room.autoOffAttempts}` : '00:00';
      return;
    }
    labelNode.textContent = room.autoOffInClass
      ? 'ในคาบเรียน · จะปิดใน'
      : 'ห้องว่าง · จะปิดใน';
    clockNode.textContent = clock(remaining);
  };

  tick();
  handle = window.setInterval(tick, 1000);
  return strip;
}

// -------------------------------------------------------- ลิ้นชักรีโมตแอร์

/** ร่างคำสั่งที่ผู้ใช้กำลังแก้อยู่ แยกจากสถานะจริงบนบอร์ด */
const drafts = new Map();

function draftFor(unit) {
  if (!drafts.has(unit.deviceId)) {
    // state.power คือคำสั่งล่าสุดที่ระบบส่ง ถ้ามีคนเปิดด้วยรีโมตจริง ค่านี้ยังเป็น false
    // จึงถือว่าเปิดอยู่ด้วยถ้า PZEM ยืนยันแล้วว่าแอร์กินไฟ (เหมือนแอปมือถือ)
    const running = unit.pzemAvailable === true && unit.acRunning === true;
    drafts.set(unit.deviceId, {
      ...unit.state,
      power: Boolean(unit.state?.power) || running,
    });
  }
  return drafts.get(unit.deviceId);
}

/** ลืมร่างทิ้งเมื่อปิดลิ้นชัก เปิดใหม่จะได้เห็นสถานะจริงล่าสุด */
export function clearDrafts() {
  drafts.clear();
}

/**
 * เนื้อหาของลิ้นชักห้องหนึ่ง
 *
 * คืนอิลิเมนต์ให้ app.js เอาไปใส่ ลิ้นชักถูกวาดใหม่ทุกครั้งที่ข้อมูลเปลี่ยน
 * จึงไม่มีสถานะซ่อนอยู่ในนั้นนอกจาก `drafts` ที่ตั้งใจให้อยู่ข้ามรอบ
 */
export function roomDrawerContent(roomNumber, context) {
  const room = state.rooms.find((item) => item.roomNumber === roomNumber);
  if (!room) return emptyState('ไม่พบห้องนี้แล้ว อาจถูกลบไประหว่างเปิดหน้าอยู่');

  const units = airConditionersOf(roomNumber);
  const sensor = sensorOf(roomNumber);
  const isAdmin = state.user?.role === 'admin';

  const blocks = [roomSummaryCard(room, sensor)];

  if (units.length === 0) {
    blocks.push(
      emptyState(
        'ห้องนี้ยังไม่มีเครื่องปรับอากาศที่ลงทะเบียนไว้\n' +
          'ต้องตั้งค่าบอร์ดผ่าน Bluetooth ในแอปมือถือก่อน',
      ),
    );
  } else {
    for (const unit of units) blocks.push(acCard(unit, isAdmin, context));
  }

  return blocks;
}

function roomSummaryCard(room, sensor) {
  const rows = [
    ['ประเภทห้อง', room.roomType || '—'],
    ['ชั้น', floorLabel(room.floorNumber)],
    [
      'เซ็นเซอร์ตรวจจับคน',
      !sensor
        ? 'ยังไม่ติดตั้ง'
        : `${sensor.deviceId} · ${
            sensor.isOnline ? 'ออนไลน์' : 'ออฟไลน์'
          } · ${sensor.radarAvailable ? 'เรดาร์พร้อม' : 'เรดาร์ยังไม่พร้อม'}`,
    ],
    [
      'สถานะห้องล่าสุด',
      sensor?.radarAvailable
        ? `${sensor.isOccupied ? 'มีคนอยู่' : 'ไม่มีคน'} (${relativeTime(
            sensor.lastSeenAt,
          )})`
        : '—',
    ],
    ['ตารางเรียนที่ผูกไว้', `${room.scheduleCount} รายการ`],
  ];

  return el('div', { class: 'ac-card' }, [
    el('div', { class: 'ac-head' }, [
      el('div', {}, [
        el('div', { class: 'ac-name', text: 'ข้อมูลห้อง' }),
        el('div', {
          class: 'ac-sub',
          text: `แอร์ ${room.airConditionerCount} เครื่อง`,
        }),
      ]),
      room.autoOffSecondsRemaining != null
        ? el('span', {
            class: 'status-chip pending',
            text: `ปิดอัตโนมัติใน ${clock(room.autoOffSecondsRemaining)}`,
          })
        : null,
    ]),
    ...rows.map(([label, value]) =>
      el('div', { class: 'info-row' }, [
        el('span', { class: 'muted', text: label }),
        el('span', { text: value }),
      ]),
    ),
  ]);
}

function acCard(unit, isAdmin, context) {
  const draft = draftFor(unit);
  const limits = limitsFor(unit.protocol);
  const reading = liveReading(unit.deviceId) ?? unit;
  const active = unit.provisionStatus === 'active';

  const rerender = () => context.refreshDrawer();

  const card = el('div', { class: 'ac-card' });

  // --- หัวการ์ด: ชื่อ สถานะ และสวิตช์เปิด-ปิดที่ส่งคำสั่งทันที
  const powerSwitch = toggle(draft.power, {
    disabled: !active,
    title: active ? 'เปิด/ปิดเครื่อง' : 'บอร์ดยังไม่พร้อมรับคำสั่ง',
    onclick: async () => {
      draft.power = !draft.power;
      rerender();
      await sendCommand(unit, draft, context);
    },
  });

  card.appendChild(
    el('div', { class: 'ac-head' }, [
      el('div', { class: 'grow' }, [
        el('div', {
          class: 'ac-name',
          text: `${unit.name} · แอร์เครื่องที่ ${unit.airNumber}`,
        }),
        el('div', {
          class: 'ac-sub',
          text: `${unit.deviceId} · ${unit.protocol}`,
        }),
      ]),
      powerSwitch,
    ]),
  );

  card.appendChild(
    el('div', { class: 'row', style: { gap: '6px', marginBottom: '10px' } }, [
      el('span', {
        class: `status-chip ${unit.isOnline ? 'done' : 'off'}`,
        text: unit.isOnline ? 'ออนไลน์' : 'ออฟไลน์',
      }),
      el('span', {
        class: `status-chip ${unit.acRunning ? 'done' : 'off'}`,
        text: unit.acRunning ? 'แอร์ทำงานอยู่' : 'แอร์ไม่ทำงาน',
      }),
      !active
        ? el('span', {
            class: 'status-chip bad',
            text: `สถานะบอร์ด: ${unit.provisionStatus}`,
          })
        : null,
      unit.outsideSchedule
        ? el('span', { class: 'status-chip pending', text: 'นอกคาบเรียน' })
        : null,
    ]),
  );

  // --- อุณหภูมิ
  const clampTemp = (value) =>
    Math.min(limits.maxTemp, Math.max(limits.minTemp, value));
  const stepTemp = (delta) => {
    draft.temperature = clampTemp((Number(draft.temperature) || 25) + delta);
    rerender();
  };

  card.appendChild(
    el('div', { class: 'temp-row' }, [
      el('button', {
        class: 'temp-btn',
        type: 'button',
        text: '−',
        title: 'ลดอุณหภูมิ',
        'aria-label': 'ลดอุณหภูมิ',
        disabled: !active,
        onclick: () => stepTemp(-1),
      }),
      el('div', {
        class: 'temp-val',
        text: `${clampTemp(Number(draft.temperature) || 25)}°C`,
      }),
      el('button', {
        class: 'temp-btn',
        type: 'button',
        text: '+',
        title: 'เพิ่มอุณหภูมิ',
        'aria-label': 'เพิ่มอุณหภูมิ',
        disabled: !active,
        onclick: () => stepTemp(1),
      }),
    ]),
  );

  // --- ชิปเลือกโหมด พัดลม และ Swing
  const chipGroup = (label, values, current, labels, onPick) =>
    el('div', { class: 'chip-row' }, [
      el('div', { class: 'chip-label', text: label }),
      ...values.map((value) =>
        el('button', {
          class: `mode-chip${value === current ? ' sel' : ''}`,
          type: 'button',
          disabled: !active,
          text: labels[value] ?? value,
          onclick: () => {
            onPick(value);
            rerender();
          },
        }),
      ),
    ]);

  card.appendChild(
    chipGroup('โหมด', limits.modes, draft.mode, MODE_LABEL, (value) => {
      draft.mode = value;
    }),
  );
  card.appendChild(
    chipGroup('พัดลม', FANS, draft.fanSpeed, FAN_LABEL, (value) => {
      draft.fanSpeed = value;
    }),
  );
  card.appendChild(
    chipGroup(
      'ทิศลม',
      limits.swings,
      draft.verticalSwing,
      SWING_LABEL,
      (value) => {
        draft.verticalSwing = value;
      },
    ),
  );

  card.appendChild(
    el('div', { class: 'chip-row' }, [
      el('div', { class: 'chip-label', text: 'ฟังก์ชันเสริม' }),
      ...EXTRA_TOGGLES.map((item) =>
        el('button', {
          class: `mode-chip${draft[item.key] ? ' sel' : ''}`,
          type: 'button',
          disabled: !active,
          text: item.label,
          onclick: () => {
            draft[item.key] = !draft[item.key];
            rerender();
          },
        }),
      ),
    ]),
  );

  if (limits.note) {
    card.appendChild(
      el('div', {
        class: 'dim small-note',
        style: { marginTop: '8px' },
        text: limits.note,
      }),
    );
  }

  // --- ค่าที่อ่านได้จริงจาก PZEM
  card.appendChild(
    el('div', { class: 'ac-metrics' }, [
      metricBox(reading.voltage, 'V', 'แรงดัน', 1),
      metricBox(reading.current, 'A', 'กระแส', 2),
      metricBox(reading.powerWatts, 'W', 'กำลังไฟ', 1),
    ]),
  );
  card.appendChild(
    el('div', { class: 'ac-metrics' }, [
      metricBox(reading.energyKwh, 'kWh', 'มิเตอร์สะสม', 3),
      metricBox(reading.powerFactor, '', 'ตัวประกอบกำลัง', 2),
      metricBox(reading.frequencyHz, 'Hz', 'ความถี่', 1),
    ]),
  );

  if (!unit.pzemAvailable) {
    card.appendChild(
      el('div', {
        class: 'warn small-note',
        style: { marginTop: '8px' },
        text:
          'อ่านค่าจาก PZEM ไม่ได้ ระบบปิดอัตโนมัติจะไม่ทำงานกับเครื่องนี้ ' +
          'เพราะยืนยันไม่ได้ว่าปิดสำเร็จหรือไม่',
      }),
    );
  }

  card.appendChild(
    el('div', {
      class: 'dim small-note',
      style: { marginTop: '8px' },
      text: `อัปเดตล่าสุด ${relativeTime(unit.lastSeenAt)} · เวลาเปิดอัตโนมัติประจำวัน ${
        unit.dailyOn ?? '—'
      } / ปิด ${unit.dailyOff ?? '—'}`,
    }),
  );

  // --- ปิดอัตโนมัติรายเครื่อง (เฉพาะแอดมิน)
  if (isAdmin) {
    card.appendChild(
      el('div', { class: 'switch-row' }, [
        el('div', { class: 'grow' }, [
          el('div', { class: 'label', text: 'ปิดอัตโนมัติเครื่องนี้' }),
          el('div', {
            class: 'sub',
            text: state.settings.autoOffEnabled
              ? 'ปิดสวิตช์นี้ถ้าห้องนี้ต้องเปิดแอร์ค้างไว้'
              : 'สวิตช์รวมของระบบถูกปิดอยู่ ตั้งค่านี้จะยังไม่มีผล',
          }),
        ]),
        toggle(unit.autoOffEnabled !== false, {
          onclick: async () => {
            try {
              await api.updateAirConditioner(unit.deviceId, {
                autoOffEnabled: unit.autoOffEnabled === false,
              });
              toastOk('บันทึกการตั้งค่าปิดอัตโนมัติแล้ว');
              await loaders.airConditioners();
              await loaders.rooms();
            } catch (error) {
              toastError(error.message);
            }
          },
        }),
      ]),
    );
  }

  // --- ปุ่มส่งคำสั่ง
  card.appendChild(
    el('div', { class: 'row', style: { marginTop: '14px', gap: '8px' } }, [
      el(
        'button',
        {
          class: 'btn btn-primary grow',
          type: 'button',
          disabled: !active,
          onclick: (event) => sendCommand(unit, draft, context, event.currentTarget),
        },
        [svg(icons.refresh(15)), 'ส่งคำสั่งผ่าน MQTT'],
      ),
      el('button', {
        class: 'btn btn-sm',
        type: 'button',
        text: 'คืนค่าเดิม',
        onclick: () => {
          drafts.set(unit.deviceId, { ...unit.state });
          context.refreshDrawer();
        },
      }),
    ]),
  );

  if (isAdmin) {
    card.appendChild(
      el('div', { class: 'row', style: { marginTop: '8px', gap: '8px' } }, [
        el('button', {
          class: 'btn btn-sm',
          type: 'button',
          text: 'เปลี่ยนชื่อ',
          onclick: () => renameUnit(unit, context),
        }),
        el('button', {
          class: 'btn btn-sm',
          type: 'button',
          disabled: !active,
          text: 'สั่งเข้าโหมดตั้งค่า',
          onclick: () => enterSetup(unit),
        }),
      ]),
    );
  }

  return card;
}

async function sendCommand(unit, draft, context, button = null) {
  const payload = {
    power: Boolean(draft.power),
    temperature: Number(draft.temperature) || 25,
    mode: draft.mode ?? 'cool',
    fanSpeed: draft.fanSpeed ?? 'auto',
    verticalSwing: draft.verticalSwing ?? 'auto',
    horizontalSwing: Boolean(draft.horizontalSwing),
    eco: Boolean(draft.eco),
    turbo: Boolean(draft.turbo),
    sleep: Boolean(draft.sleep),
    quiet: Boolean(draft.quiet),
    displayLight: draft.displayLight !== false,
    clean: Boolean(draft.clean),
    timerOnMinutes: draft.timerOnMinutes ?? null,
    timerOffMinutes: draft.timerOffMinutes ?? null,
  };

  if (button) button.disabled = true;
  try {
    await api.sendCommand(unit.deviceId, payload);
    toastOk(
      `ส่งคำสั่งไปที่ ${unit.name} แล้ว · ` +
        'IR ไม่มีสัญญาณตอบกลับ ให้ดูค่ากำลังไฟว่าเปลี่ยนตามหรือไม่',
    );
    // ค่าสถานะจริงจะกลับมาทาง MQTT ภายในไม่กี่วินาที ดึงใหม่ให้เห็นเร็วขึ้น
    window.setTimeout(() => {
      loaders.airConditioners();
      loaders.live();
    }, 2500);
  } catch (error) {
    // คำสั่งไม่ผ่าน ต้องดึงร่างกลับไปตรงกับของจริง ไม่งั้นหน้าจอจะโกหก
    drafts.set(unit.deviceId, { ...unit.state });
    context.refreshDrawer();
    toastError(error.message);
  } finally {
    if (button) button.disabled = false;
  }
}

async function renameUnit(unit, context) {
  const { openForm } = await import('../ui.js');
  const values = await openForm({
    title: 'เปลี่ยนชื่อเครื่องปรับอากาศ',
    subtitle: `${unit.deviceId} · ห้อง ${unit.roomNumber}`,
    fields: [
      {
        name: 'name',
        label: 'ชื่อที่จะแสดง',
        value: unit.name,
        required: true,
        hint: 'ยาว 1–60 ตัวอักษร',
      },
    ],
  });
  if (!values) return;
  try {
    await api.updateAirConditioner(unit.deviceId, { name: values.name });
    toastOk('เปลี่ยนชื่อแล้ว');
    await loaders.airConditioners();
    context.refreshDrawer();
  } catch (error) {
    toastError(error.message);
  }
}

async function enterSetup(unit) {
  const ok = await confirmAction({
    title: 'สั่งให้บอร์ดเข้าโหมดตั้งค่า?',
    subtitle:
      `${unit.name} จะหลุดจาก Wi-Fi และเปิด Bluetooth รอรับการตั้งค่าใหม่ ` +
      'ต้องใช้แอปมือถือไปตั้งค่าต่อจึงจะกลับมาออนไลน์',
    confirmLabel: 'สั่งเข้าโหมดตั้งค่า',
    danger: true,
  });
  if (!ok) return;
  try {
    await api.enterSetupMode(unit.deviceId);
    toastInfo('ส่งคำสั่งแล้ว ให้เปิดแอปมือถือเพื่อตั้งค่าบอร์ดต่อ');
  } catch (error) {
    toastError(error.message);
  }
}

/** สรุปหัวลิ้นชัก ใช้โดย app.js */
export function roomDrawerTitle(roomNumber) {
  const room = state.rooms.find((item) => item.roomNumber === roomNumber);
  const units = airConditionersOf(roomNumber);
  const running = units.filter((unit) => unit.acRunning).length;
  const totalWatts = units.reduce((sum, unit) => {
    const reading = liveReading(unit.deviceId);
    return sum + (Number(reading?.powerWatts) || 0);
  }, 0);

  return {
    title: `ห้อง ${roomNumber}`,
    subtitle:
      `${room?.roomType ?? '—'} · ทำงาน ${running}/${units.length} เครื่อง · ` +
      `รวม ${decimal(totalWatts, 0)} W · เวลาเซิร์ฟเวอร์ ${time(
        state.live.serverTime,
      )}`,
  };
}
