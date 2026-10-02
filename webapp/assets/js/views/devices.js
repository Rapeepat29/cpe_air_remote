/**
 * หน้าจัดการห้องและอุปกรณ์ (เฉพาะแอดมิน)
 *
 * สิ่งที่เว็บทำแทนแอปมือถือไม่ได้คือขั้นตอน Bluetooth — ต้องยืนใกล้บอร์ดและ
 * ใช้บลูทูธของโทรศัพท์ส่งค่า Wi-Fi/MQTT เข้าไป เว็บจึงทำได้ถึงแค่ "จองช่อง"
 * คือสร้างแถวในฐานข้อมูลพร้อมโทเคนชั่วคราว แล้วให้คนถือโทรศัพท์ไปต่อให้จบ
 *
 * ทำแบบนี้ยังมีประโยชน์ เพราะงานกรอกข้อมูล (ห้อง หมายเลขแอร์ ยี่ห้อ เวลาเปิด-ปิด)
 * พิมพ์บนคอมพิวเตอร์เร็วกว่ามาก เหลือให้คนหน้างานแค่กดยืนยัน
 */

import { api } from '../api.js';
import { el, replace, emptyState, svg, toggle } from '../dom.js';
import { decimal, floorLabel, relativeTime } from '../format.js';
import { icons } from '../icons.js';
import {
  airConditionersOf,
  liveReading,
  loaders,
  roomsByFloor,
  state,
} from '../store.js';
import {
  confirmAction,
  openForm,
  openModal,
  toastError,
  toastInfo,
  toastOk,
} from '../ui.js';

const PROTOCOLS = [
  'DAIKIN',
  'ELECTRA_AC',
  'FUJITSU_AC',
  'GREE',
  'HAIER_AC',
  'HAIER_AC160',
  'HAIER_AC176',
  'HAIER_AC_YRW02',
  'HITACHI_AC',
  'KELVINATOR',
  'LG',
  'MIDEA',
  'MITSUBISHI_AC',
  'PANASONIC_AC',
  'SAIJO_DENKI',
  'SAMSUNG_AC',
  'SHARP_AC',
  'TOSHIBA_AC',
];

const TABS = [
  { key: 'rooms', label: 'ห้อง' },
  { key: 'air', label: 'เครื่องปรับอากาศ' },
  { key: 'occupancy', label: 'เซ็นเซอร์ตรวจจับคน' },
];

let tab = 'rooms';

export default {
  title: 'ห้องและอุปกรณ์',
  subtitle: 'เพิ่ม แก้ไข และถอดห้อง บอร์ดแอร์ และเซ็นเซอร์ตรวจจับคน',
  adminOnly: true,

  mount(root) {
    const tabBar = el('div', { class: 'tabbar' });
    const panel = el('div', { style: { marginTop: '16px' } });
    replace(root, [tabBar, panel]);

    function update() {
      replace(
        tabBar,
        TABS.map((item) =>
          el('button', {
            class: `tab${item.key === tab ? ' active' : ''}`,
            type: 'button',
            text: item.label,
            onclick: () => {
              tab = item.key;
              update();
            },
          }),
        ),
      );

      if (tab === 'rooms') renderRooms(panel, update);
      else if (tab === 'air') renderAirConditioners(panel, update);
      else renderOccupancy(panel, update);
    }

    update();
    return { update };
  },
};

// ------------------------------------------------------------------- ห้อง

function renderRooms(panel, update) {
  const groups = roomsByFloor();

  replace(panel, [
    el('div', { class: 'row between', style: { marginBottom: '14px' } }, [
      el('div', {
        class: 'pill',
        text: `ทั้งหมด ${state.rooms.length} ห้อง`,
      }),
      el(
        'button',
        {
          class: 'btn btn-sm btn-primary',
          type: 'button',
          onclick: () => addRoom(update),
        },
        [svg(icons.plus(14)), 'เพิ่มห้อง'],
      ),
    ]),
    ...(groups.length === 0
      ? [emptyState('ยังไม่มีห้องในระบบ')]
      : groups.flatMap((group) => [
          el('div', {
            class: 'nav-label',
            style: { paddingLeft: '2px' },
            text: floorLabel(group.floor),
          }),
          ...group.rooms.map((room) => roomRow(room, update)),
        ])),
  ]);
}

function roomRow(room, update) {
  const sensor = state.occupancySensors.find(
    (item) => item.roomNumber === room.roomNumber,
  );
  return el('div', { class: 'list-card' }, [
    el('div', { class: 'grow' }, [
      el('div', { class: 'list-title', text: `ห้อง ${room.roomNumber}` }),
      el('div', {
        class: 'list-sub',
        text:
          `${room.roomType} · ลำดับที่ ${room.roomIndex} · ` +
          `แอร์ ${room.airConditionerCount} เครื่อง · ` +
          `ตารางเรียน ${room.scheduleCount} รายการ · ` +
          `เซ็นเซอร์ ${sensor ? sensor.deviceId : 'ยังไม่ติดตั้ง'}`,
      }),
    ]),
    el('button', {
      class: 'btn btn-sm',
      type: 'button',
      text: 'แก้ไข',
      onclick: () => editRoom(room, update),
    }),
    el('button', {
      class: 'btn btn-sm btn-danger',
      type: 'button',
      text: 'ลบ',
      onclick: () => removeRoom(room, update),
    }),
  ]);
}

function roomFields(values = {}) {
  return [
    {
      name: 'roomNumber',
      label: 'รหัสห้อง',
      value: values.roomNumber ?? '',
      required: true,
      hint: 'A–Z, 0–9, _ หรือ - ยาว 2–20 ตัว เช่น 16303',
    },
    {
      name: 'floorNumber',
      label: 'ชั้น',
      type: 'number',
      value: String(values.floorNumber ?? 1),
      required: true,
      hint: 'ใช้ 0 สำหรับห้องพิเศษที่ไม่อยู่ในชั้นปกติ',
    },
    {
      name: 'roomIndex',
      label: 'ลำดับในชั้น',
      type: 'number',
      value: String(values.roomIndex ?? 1),
      required: true,
      hint: 'ใช้จัดลำดับการแสดงผลเท่านั้น',
    },
    {
      name: 'roomType',
      label: 'ประเภทหรือชื่อห้อง',
      value: values.roomType ?? 'ห้องเรียน',
      required: true,
    },
  ];
}

function roomPayload(values, { withNumber = true } = {}) {
  const payload = {
    floorNumber: Number.parseInt(values.floorNumber, 10),
    roomIndex: Number.parseInt(values.roomIndex, 10),
    roomType: values.roomType,
  };
  if (withNumber) payload.roomNumber = values.roomNumber.toUpperCase();
  return payload;
}

async function addRoom(update) {
  const values = await openForm({
    title: 'เพิ่มห้องใหม่',
    fields: roomFields(),
    submitLabel: 'เพิ่มห้อง',
  });
  if (!values) return;
  try {
    await api.createRoom(roomPayload(values));
    toastOk(`เพิ่มห้อง ${values.roomNumber} แล้ว`);
    await loaders.rooms();
    update();
  } catch (error) {
    toastError(error.message);
  }
}

async function editRoom(room, update) {
  const fields = roomFields(room).filter(
    (field) => field.name !== 'roomNumber',
  );
  const values = await openForm({
    title: `แก้ไขห้อง ${room.roomNumber}`,
    subtitle: 'รหัสห้องเปลี่ยนไม่ได้ เพราะเป็นตัวผูกกับแอร์และตารางเรียน',
    fields,
  });
  if (!values) return;
  try {
    await api.updateRoom(room.roomNumber, roomPayload(values, { withNumber: false }));
    toastOk('บันทึกแล้ว');
    await loaders.rooms();
    update();
  } catch (error) {
    toastError(error.message);
  }
}

async function removeRoom(room, update) {
  const ok = await confirmAction({
    title: `ลบห้อง ${room.roomNumber}?`,
    subtitle:
      'ลบได้เฉพาะห้องที่ไม่มีแอร์ ตารางเรียน และเซ็นเซอร์ผูกอยู่แล้วเท่านั้น\n' +
      'ประวัติค่าไฟของห้องนี้จะยังอยู่ในฐานข้อมูล',
    confirmLabel: 'ลบห้อง',
    danger: true,
  });
  if (!ok) return;
  try {
    await api.deleteRoom(room.roomNumber);
    toastOk('ลบห้องแล้ว');
    await loaders.rooms();
    update();
  } catch (error) {
    toastError(error.message);
  }
}

// ------------------------------------------------------- เครื่องปรับอากาศ

function renderAirConditioners(panel, update) {
  const units = [...state.airConditioners].sort(
    (a, b) =>
      a.roomNumber.localeCompare(b.roomNumber) || a.airNumber - b.airNumber,
  );

  replace(panel, [
    el('div', { class: 'row between', style: { marginBottom: '14px' } }, [
      el('div', {
        class: 'pill',
        text: `${units.length} เครื่อง · ออนไลน์ ${
          units.filter((unit) => unit.isOnline).length
        }`,
      }),
      el(
        'button',
        {
          class: 'btn btn-sm btn-primary',
          type: 'button',
          onclick: () => reserveAir(update),
        },
        [svg(icons.plus(14)), 'จองช่องติดตั้งบอร์ดใหม่'],
      ),
    ]),
    units.length === 0
      ? emptyState('ยังไม่มีบอร์ดแอร์ในระบบ')
      : el(
          'div',
          {},
          units.map((unit) => airRow(unit, update)),
        ),
  ]);
}

function airRow(unit, update) {
  const reading = liveReading(unit.deviceId) ?? unit;
  return el('div', { class: 'list-card' }, [
    el('div', { class: 'grow' }, [
      el('div', { class: 'list-title' }, [
        `${unit.name} · ห้อง ${unit.roomNumber} เครื่องที่ ${unit.airNumber}`,
      ]),
      el('div', {
        class: 'list-sub',
        text:
          `${unit.deviceId} · ${unit.protocol} · ` +
          `${unit.provisionStatus} · ` +
          `${unit.isOnline ? 'ออนไลน์' : 'ออฟไลน์'} · ` +
          `${decimal(reading.powerWatts ?? 0, 1)} W · ` +
          `อัปเดต ${relativeTime(unit.lastSeenAt)}`,
      }),
      firmwareLine(unit),
    ]),
    el('div', { class: 'row', style: { gap: '6px' } }, [
      el('span', {
        class: 'dim',
        style: { fontSize: '11px' },
        text: 'ปิดอัตโนมัติ',
      }),
      toggle(unit.autoOffEnabled !== false, {
        onclick: async () => {
          try {
            await api.updateAirConditioner(unit.deviceId, {
              autoOffEnabled: unit.autoOffEnabled === false,
            });
            await loaders.airConditioners();
            update();
          } catch (error) {
            toastError(error.message);
          }
        },
      }),
    ]),
    el('button', {
      class: 'btn btn-sm',
      type: 'button',
      text: 'เปลี่ยนชื่อ',
      onclick: async () => {
        const values = await openForm({
          title: 'เปลี่ยนชื่อเครื่องปรับอากาศ',
          subtitle: unit.deviceId,
          fields: [
            { name: 'name', label: 'ชื่อ', value: unit.name, required: true },
          ],
        });
        if (!values) return;
        try {
          await api.updateAirConditioner(unit.deviceId, { name: values.name });
          toastOk('เปลี่ยนชื่อแล้ว');
          await loaders.airConditioners();
          update();
        } catch (error) {
          toastError(error.message);
        }
      },
    }),
    el('button', {
      class: 'btn btn-sm',
      type: 'button',
      text: 'อัปเดตเฟิร์มแวร์',
      onclick: () => startOta(unit, 'air', update),
    }),
    el('button', {
      class: 'btn btn-sm btn-danger',
      type: 'button',
      text: 'ถอดออก',
      onclick: () => removeAir(unit, update),
    }),
  ]);
}

/** รุ่นเฟิร์มแวร์ที่บอร์ดรายงานมา และผลการอัปเดตผ่าน Wi-Fi ครั้งล่าสุด */
function firmwareLine(device) {
  const version = device.firmwareVersion
    ? `เฟิร์มแวร์ ${device.firmwareVersion}`
    : 'เฟิร์มแวร์: ยังไม่รายงาน (รุ่นเก่ากว่า 2.3.0 / 1.3.0)';
  return el('div', { class: 'list-sub' }, [
    version,
    device.otaError
      ? el('span', {
          class: 'bad',
          text: ` · อัปเดตครั้งล่าสุดไม่สำเร็จ: ${device.otaError}`,
        })
      : null,
    Number(device.historyPending) > 0
      ? el('span', {
          text:
            ` · กำลังส่งข้อมูลช่วงเน็ตหลุด ${device.historyPending} รายการ` +
            ` (ประมาณ ${Math.round(device.historyPending * 5 / 60)} ชม.)`,
        })
      : null,
  ]);
}

/**
 * สั่งบอร์ดอัปเดตเฟิร์มแวร์ผ่าน Wi-Fi
 *
 * ไฟล์ .bin ต้องวางไว้ที่ /opt/rmutt/firmware บนเซิร์ฟเวอร์ก่อน
 * บอร์ดจะดาวน์โหลดเอง รีบูต แล้วรายงานรุ่นใหม่กลับมาภายในไม่กี่นาที
 */
async function startOta(device, kind, update) {
  let listing;
  try {
    listing = await api.firmwareFiles();
  } catch (error) {
    toastError(error.message);
    return;
  }
  const files = (listing?.files ?? []).filter((file) => file.kind === kind);
  if (files.length === 0) {
    toastInfo(
      'ยังไม่มีไฟล์เฟิร์มแวร์บนเซิร์ฟเวอร์ ให้วางไฟล์ .bin ไว้ที่ /opt/rmutt/firmware ก่อน',
    );
    return;
  }
  const values = await openForm({
    title: `อัปเดตเฟิร์มแวร์ ${device.deviceId}`,
    subtitle:
      'บอร์ดจะดาวน์โหลดไฟล์แล้วรีบูตเอง ใช้เวลาประมาณ 1–2 นาที ' +
      'ระหว่างนั้นสั่งงานบอร์ดไม่ได้ ถ้าไม่สำเร็จบอร์ดจะใช้เฟิร์มแวร์เดิมต่อ',
    submitLabel: 'เริ่มอัปเดต',
    fields: [
      {
        name: 'file',
        label: 'ไฟล์เฟิร์มแวร์',
        type: 'select',
        value: files[0].name,
        options: files.map((file) => ({
          value: file.name,
          label: `${file.name} (${Math.round(file.size / 1024)} KB)`,
        })),
      },
    ],
  });
  if (!values) return;
  try {
    if (kind === 'occupancy') {
      await api.otaOccupancySensor(device.deviceId, values.file);
    } else {
      await api.otaAirConditioner(device.deviceId, values.file);
    }
    toastOk('ส่งคำสั่งแล้ว รอบอร์ดรีบูตแล้วดูรุ่นเฟิร์มแวร์ในรายการนี้');
    update();
  } catch (error) {
    toastError(error.message);
  }
}

async function reserveAir(update) {
  const values = await openForm({
    title: 'จองช่องติดตั้งบอร์ดแอร์',
    subtitle:
      'กรอกข้อมูลที่นี่ให้ครบ แล้วนำโทเคนที่ได้ไปตั้งค่าบอร์ดผ่านแอปมือถือ ' +
      'ภายใน 15 นาที',
    fields: [
      {
        name: 'deviceId',
        label: 'รหัส ESP32',
        value: 'ESP32-',
        required: true,
        hint: 'รูปแบบ ESP32- ตามด้วยเลขฐานสิบหก 12 ตัว (อ่านได้จากจอบอร์ด)',
      },
      {
        name: 'roomNumber',
        label: 'ห้อง',
        type: 'select',
        options: state.rooms.map((room) => ({
          value: room.roomNumber,
          label: `${room.roomNumber} · ${room.roomType}`,
        })),
        required: true,
      },
      {
        name: 'airNumber',
        label: 'หมายเลขแอร์ในห้อง',
        type: 'number',
        value: '1',
        required: true,
        hint: '1–6',
      },
      { name: 'name', label: 'ชื่อที่จะแสดง', value: 'แอร์ 1', required: true },
      {
        name: 'protocol',
        label: 'โปรโตคอลรีโมต',
        type: 'select',
        value: 'SAIJO_DENKI',
        options: PROTOCOLS.map((item) => ({ value: item, label: item })),
        required: true,
      },
      { name: 'dailyOn', label: 'เวลาเปิดประจำวัน (ไม่บังคับ)', type: 'time' },
      { name: 'dailyOff', label: 'เวลาปิดประจำวัน (ไม่บังคับ)', type: 'time' },
    ],
    submitLabel: 'สร้างโทเคน',
  });
  if (!values) return;

  const deviceId = values.deviceId.trim().toUpperCase();
  try {
    const reservation = await api.reserveAirConditioner({
      deviceId,
      roomNumber: values.roomNumber,
      airNumber: Number.parseInt(values.airNumber, 10),
      name: values.name,
      // ชื่อ Bluetooth ต้องตรงกับรหัสบอร์ดเป๊ะ ๆ ไม่งั้น Backend ปฏิเสธ
      // คำนวณให้เลยดีกว่าให้คนพิมพ์เอง เพราะพิมพ์ผิดแล้วงงว่าทำไมไม่ผ่าน
      bleName: `RMUTT-AC-${deviceId.slice(6)}`,
      protocol: values.protocol,
      dailyOn: values.dailyOn || null,
      dailyOff: values.dailyOff || null,
    });
    await loaders.airConditioners();
    update();
    showReservation(reservation, 'บอร์ดแอร์');
  } catch (error) {
    toastError(error.message);
  }
}

function showReservation(reservation, kind) {
  const lines = [
    ['ชื่อ Bluetooth ที่ต้องมองหา', reservation.bleName],
    ['MQTT Host', reservation.mqttHost ?? '—'],
    ['MQTT Port', String(reservation.mqttPort ?? '—')],
    ['MQTT Username', reservation.mqttUsername || '—'],
    ['Topic', reservation.mqttTopic ?? '—'],
  ];

  openModal({
    title: `จองช่อง${kind}สำเร็จ`,
    subtitle:
      'โทเคนนี้ใช้ได้ 15 นาที และใช้ได้ครั้งเดียว ' +
      'เปิดแอปมือถือ เลือกอุปกรณ์ตามชื่อ Bluetooth ข้างล่าง แล้วกรอกโทเคน',
    body: el('div', {}, [
      el('div', { class: 'token-box', text: reservation.provisioningToken }),
      ...lines.map(([label, value]) =>
        el('div', { class: 'rate-example-row', style: { fontSize: '12px' } }, [
          el('span', { class: 'muted', text: label }),
          el('span', { class: 'mono', text: value }),
        ]),
      ),
    ]),
    actions: [
      {
        label: 'คัดลอกโทเคน',
        onclick: () => {
          navigator.clipboard
            ?.writeText(reservation.provisioningToken)
            .then(() => toastOk('คัดลอกแล้ว'))
            .catch(() => toastError('คัดลอกไม่สำเร็จ ให้เลือกข้อความแล้วคัดลอกเอง'));
          return false;
        },
      },
      { label: 'ปิด', class: 'btn-primary', value: true },
    ],
  });
}

async function removeAir(unit, update) {
  const ok = await confirmAction({
    title: `ถอด ${unit.name} ออกจากระบบ?`,
    subtitle:
      `${unit.deviceId} · ห้อง ${unit.roomNumber}\n` +
      'ประวัติค่าไฟยังอยู่ แต่บอร์ดจะไม่ถูกควบคุมและไม่ถูกปิดอัตโนมัติอีก ' +
      'ถ้าจะใช้บอร์ดนี้ต่อ ต้องจองช่องและตั้งค่าผ่าน Bluetooth ใหม่',
    confirmLabel: 'ถอดออก',
    danger: true,
  });
  if (!ok) return;
  try {
    const result = await api.deleteAirConditioner(unit.deviceId);
    toastOk(
      `ถอดออกแล้ว · ล้างข้อความค้างบน MQTT ${result.retainedTopicsCleared} หัวข้อ`,
    );
    await loaders.airConditioners();
    await loaders.rooms();
    update();
  } catch (error) {
    toastError(error.message);
  }
}

// -------------------------------------------------- เซ็นเซอร์ตรวจจับคน

function renderOccupancy(panel, update) {
  const sensors = [...state.occupancySensors].sort((a, b) =>
    a.roomNumber.localeCompare(b.roomNumber),
  );

  replace(panel, [
    el('div', { class: 'row between', style: { marginBottom: '14px' } }, [
      el('div', {
        class: 'pill',
        text: `${sensors.length} ตัว · เรดาร์พร้อม ${
          sensors.filter((sensor) => sensor.radarAvailable).length
        }`,
      }),
      el(
        'button',
        {
          class: 'btn btn-sm btn-primary',
          type: 'button',
          onclick: () => reserveOccupancy(update),
        },
        [svg(icons.plus(14)), 'จองช่องติดตั้งเซ็นเซอร์'],
      ),
    ]),
    el('div', {
      class: 'dim',
      style: { fontSize: '11.5px', marginBottom: '12px' },
      text:
        'ระบบปิดแอร์อัตโนมัติจะไม่ทำงานกับห้องที่เซ็นเซอร์ออฟไลน์หรือเรดาร์ยังไม่พร้อม ' +
        'เพราะถ้าไม่รู้ว่ามีคนอยู่หรือไม่ การเดาแล้วปิดคือความเสียหายที่แก้ยากกว่า',
    }),
    sensors.length === 0
      ? emptyState('ยังไม่มีเซ็นเซอร์ตรวจจับคนในระบบ')
      : el(
          'div',
          {},
          sensors.map((sensor) => occupancyRow(sensor, update)),
        ),
  ]);
}

function occupancyRow(sensor, update) {
  return el('div', { class: 'list-card' }, [
    el('div', { class: 'grow' }, [
      el('div', {
        class: 'list-title',
        text: `ห้อง ${sensor.roomNumber} · ${sensor.deviceId}`,
      }),
      el('div', {
        class: 'list-sub',
        text:
          `${sensor.provisionStatus} · ` +
          `${sensor.isOnline ? 'ออนไลน์' : 'ออฟไลน์'} · ` +
          `${sensor.radarAvailable ? 'เรดาร์พร้อม' : 'เรดาร์ยังไม่พร้อม'} · ` +
          `${sensor.isOccupied ? 'มีคนอยู่' : 'ไม่มีคน'} · ` +
          `เกณฑ์พลังงานนิ่ง ${sensor.staticThreshold} · ` +
          `อัปเดต ${relativeTime(sensor.lastSeenAt)}`,
      }),
      firmwareLine(sensor),
    ]),
    el('button', {
      class: 'btn btn-sm',
      type: 'button',
      text: 'สั่งเข้าโหมดตั้งค่า',
      onclick: async () => {
        const ok = await confirmAction({
          title: 'สั่งให้เซ็นเซอร์เข้าโหมดตั้งค่า?',
          subtitle: 'ต้องใช้แอปมือถือตั้งค่าต่อจึงจะกลับมาออนไลน์',
          confirmLabel: 'สั่ง',
          danger: true,
        });
        if (!ok) return;
        try {
          await api.occupancySetupMode(sensor.deviceId);
          toastInfo('ส่งคำสั่งแล้ว');
        } catch (error) {
          toastError(error.message);
        }
      },
    }),
    el('button', {
      class: 'btn btn-sm',
      type: 'button',
      text: 'อัปเดตเฟิร์มแวร์',
      onclick: () => startOta(sensor, 'occupancy', update),
    }),
    el('button', {
      class: 'btn btn-sm btn-danger',
      type: 'button',
      text: 'ถอดออก',
      onclick: async () => {
        const ok = await confirmAction({
          title: `ถอดเซ็นเซอร์ของห้อง ${sensor.roomNumber}?`,
          subtitle: 'ระบบปิดแอร์อัตโนมัติของห้องนี้จะหยุดทำงานทันที',
          confirmLabel: 'ถอดออก',
          danger: true,
        });
        if (!ok) return;
        try {
          await api.deleteOccupancySensor(sensor.deviceId);
          toastOk('ถอดออกแล้ว');
          await loaders.occupancySensors();
          await loaders.rooms();
          update();
        } catch (error) {
          toastError(error.message);
        }
      },
    }),
  ]);
}

async function reserveOccupancy(update) {
  const values = await openForm({
    title: 'จองช่องติดตั้งเซ็นเซอร์ตรวจจับคน',
    subtitle: 'หนึ่งห้องมีเซ็นเซอร์ได้หนึ่งตัว',
    fields: [
      {
        name: 'deviceId',
        label: 'รหัสเซ็นเซอร์',
        value: 'OCC32-',
        required: true,
        hint: 'รูปแบบ OCC32- ตามด้วยเลขฐานสิบหก 12 ตัว',
      },
      {
        name: 'roomNumber',
        label: 'ห้อง',
        type: 'select',
        options: state.rooms.map((room) => ({
          value: room.roomNumber,
          label: `${room.roomNumber} · ${room.roomType}`,
        })),
        required: true,
      },
    ],
    submitLabel: 'สร้างโทเคน',
  });
  if (!values) return;

  const deviceId = values.deviceId.trim().toUpperCase();
  try {
    const reservation = await api.reserveOccupancySensor({
      deviceId,
      roomNumber: values.roomNumber,
      bleName: `RMUTT-OCC-${deviceId.slice(6)}`,
    });
    await loaders.occupancySensors();
    update();
    showReservation(reservation, 'เซ็นเซอร์');
  } catch (error) {
    toastError(error.message);
  }
}

/** ใช้โดยหน้าอื่นเพื่อหาว่าห้องหนึ่งมีแอร์กี่เครื่อง */
export const countUnits = (roomNumber) => airConditionersOf(roomNumber).length;
