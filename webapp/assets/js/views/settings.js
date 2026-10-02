/**
 * หน้าตั้งค่าระบบและบัญชี
 *
 * สวิตช์รวมของระบบปิดแอร์อัตโนมัติอยู่ที่นี่ และตั้งใจให้เป็นของแอดมินเท่านั้น
 * เพราะกดทีเดียวหยุดทั้งอาคาร แต่คนทั่วไปต้อง "เห็น" ว่ามันถูกปิดอยู่ ไม่งั้น
 * จะงงว่าทำไมนาฬิกานับถอยหลังไม่ขึ้นสักที แล้วไปแจ้งว่าเซ็นเซอร์พัง
 */

import { api } from '../api.js';
import { el, replace, svg, toggle } from '../dom.js';
import { relativeTime, time } from '../format.js';
import { icons } from '../icons.js';
import { THEMES, TEXT_SIZES, prefs, setTextSize, setTheme } from '../prefs.js';
import { loaders, refreshAll, state } from '../store.js';
import { confirmAction, openForm, toastError, toastOk } from '../ui.js';

export default {
  title: 'ตั้งค่า',
  subtitle: 'ระบบปิดแอร์อัตโนมัติ ข้อมูลบัญชี และสถานะการเชื่อมต่อ',

  mount(root, context) {
    const box = el('div', {});
    replace(root, box);

    function update() {
      const isAdmin = state.user?.role === 'admin';
      replace(box, [
        displayCard(update),
        autoOffCard(isAdmin),
        profileCard(update),
        healthCard(),
        sessionCard(context),
      ]);
    }

    update();
    return { update };
  },
};

/**
 * การแสดงผลของเครื่องนี้: ธีมและขนาดตัวอักษร
 * อยู่บนสุดเพราะเป็นสิ่งเดียวในหน้านี้ที่ทุกคนเปลี่ยนได้และมีผลทันที
 */
function displayCard(onChanged) {
  const segmented = (items, current, onPick) =>
    el(
      'div',
      { class: 'segmented', role: 'group' },
      items.map((item) =>
        el('button', {
          class: item.key === current ? 'sel' : '',
          type: 'button',
          text: item.label,
          'aria-pressed': item.key === current ? 'true' : 'false',
          onclick: () => {
            onPick(item.key);
            onChanged();
          },
        }),
      ),
    );

  return el('div', { class: 'card', style: { marginBottom: '16px' } }, [
    el('div', { class: 'panel-title' }, [
      'การแสดงผล',
      el('span', { class: 'count-badge', text: 'มีผลเฉพาะเครื่องนี้' }),
    ]),
    el('div', { class: 'pref-row' }, [
      el('div', {}, [
        el('div', { class: 'label', text: 'ธีมสี' }),
        el('div', {
          class: 'sub',
          text: 'ธีมสว่างอ่านง่ายกว่าในห้องที่แสงจ้า ธีมมืดสบายตากว่าตอนกลางคืน',
        }),
      ]),
      segmented(THEMES, prefs.theme, setTheme),
    ]),
    el('div', { class: 'pref-row' }, [
      el('div', {}, [
        el('div', { class: 'label', text: 'ขนาดตัวอักษร' }),
        el('div', {
          class: 'sub',
          text: 'ขยายตัวหนังสือทั้งเว็บ ตารางและตัวเลขจะใหญ่ขึ้นตามกัน',
        }),
      ]),
      segmented(TEXT_SIZES, prefs.textSize, setTextSize),
    ]),
  ]);
}

function autoOffCard(isAdmin) {
  const enabled = state.settings.autoOffEnabled;
  const counting = state.rooms.filter(
    (room) => room.autoOffSecondsRemaining != null,
  ).length;

  return el('div', { class: 'card', style: { marginBottom: '16px' } }, [
    el('div', { class: 'panel-title' }, [
      'ระบบปิดแอร์อัตโนมัติ',
      el('span', {
        class: `status-chip ${enabled ? 'done' : 'off'}`,
        text: enabled ? 'เปิดอยู่' : 'ปิดอยู่',
      }),
    ]),
    el('div', { class: 'switch-row' }, [
      el('div', { class: 'grow' }, [
        el('div', { class: 'label', text: 'สวิตช์รวมของทั้งอาคาร' }),
        el('div', {
          class: 'sub',
          text: enabled
            ? 'เมื่อห้องว่างและแอร์ยังทำงาน ระบบจะนับถอยหลังแล้วส่งคำสั่งปิดเอง ' +
              '(นอกคาบเรียน 5 นาที · ในคาบเรียน 15 นาที)'
            : 'ปิดอยู่ ระบบจะไม่ส่งคำสั่งปิดแอร์เอง และนาฬิกาที่ค้างอยู่ถูกล้างแล้ว',
        }),
        !isAdmin
          ? el('div', {
              class: 'sub warn',
              text: 'เฉพาะผู้ดูแลระบบเท่านั้นที่เปลี่ยนค่านี้ได้',
            })
          : null,
      ]),
      toggle(enabled, {
        disabled: !isAdmin,
        onclick: async (event) => {
          const button = event.currentTarget;
          if (enabled) {
            const ok = await confirmAction({
              title: 'ปิดระบบปิดแอร์อัตโนมัติทั้งอาคาร?',
              subtitle:
                'นาฬิกานับถอยหลังของทุกห้องจะถูกล้างทันที ' +
                'และแอร์ที่เปิดค้างไว้จะไม่ถูกปิดเองอีก จนกว่าจะเปิดสวิตช์นี้ใหม่',
              confirmLabel: 'ปิดระบบ',
              danger: true,
            });
            if (!ok) return;
          }
          button.disabled = true;
          try {
            await api.setAutoOffEnabled(!enabled);
            await loaders.settings();
            await loaders.rooms();
            toastOk(enabled ? 'ปิดระบบแล้ว' : 'เปิดระบบแล้ว');
          } catch (error) {
            if (error.status === 404) {
              toastError(
                'เซิร์ฟเวอร์ยังไม่มีเส้นทาง /api/settings ' +
                  'ให้รัน deploy\\update-server.ps1 เพื่ออัปเดต Backend ก่อน',
              );
            } else {
              toastError(error.message);
            }
          } finally {
            button.disabled = false;
          }
        },
      }),
    ]),
    el('div', {
      class: 'dim',
      style: { fontSize: 'var(--fs-xs)', marginTop: '10px' },
      text: `ตอนนี้มี ${counting} ห้องที่กำลังนับถอยหลังอยู่`,
    }),
  ]);
}

function profileCard(update) {
  const user = state.user;
  if (!user) return null;

  return el('div', { class: 'card', style: { marginBottom: '16px' } }, [
    el('div', { class: 'panel-title', text: 'บัญชีของฉัน' }),
    ...[
      ['Username', user.username],
      ['ชื่อ–นามสกุล', `${user.firstName} ${user.lastName}`.trim() || '—'],
      ['อีเมล', user.email || '—'],
      ['เบอร์โทร', user.phone || '—'],
      ['สิทธิ์', user.role === 'admin' ? 'ผู้ดูแลระบบ' : 'เจ้าหน้าที่'],
    ].map(([label, value]) =>
      el('div', { class: 'rate-example-row', style: { fontSize: 'var(--fs-sm)' } }, [
        el('span', { class: 'muted', text: label }),
        el('span', { text: value }),
      ]),
    ),
    el('div', { class: 'row', style: { marginTop: '14px' } }, [
      el('button', {
        class: 'btn btn-sm',
        type: 'button',
        text: 'แก้ไขข้อมูลส่วนตัว',
        onclick: () => editProfile(update),
      }),
      el('button', {
        class: 'btn btn-sm',
        type: 'button',
        text: 'เปลี่ยนรหัสผ่าน',
        onclick: () => changePassword(),
      }),
    ]),
  ]);
}

async function editProfile(update) {
  const user = state.user;
  const values = await openForm({
    title: 'แก้ไขข้อมูลส่วนตัว',
    subtitle: 'สิทธิ์และสถานะบัญชีเปลี่ยนที่นี่ไม่ได้ ต้องให้แอดมินเปลี่ยนให้',
    fields: [
      { name: 'firstName', label: 'ชื่อ', value: user.firstName, required: true },
      { name: 'lastName', label: 'นามสกุล', value: user.lastName, required: true },
      {
        name: 'email',
        label: 'อีเมล',
        type: 'email',
        value: user.email,
        required: true,
      },
      { name: 'phone', label: 'เบอร์โทร', value: user.phone },
    ],
  });
  if (!values) return;
  try {
    const updated = await api.updateProfile(values);
    state.user = updated;
    toastOk('บันทึกข้อมูลแล้ว');
    update();
  } catch (error) {
    toastError(error.message);
  }
}

async function changePassword() {
  const values = await openForm({
    title: 'เปลี่ยนรหัสผ่าน',
    subtitle:
      'เมื่อเปลี่ยนสำเร็จ อุปกรณ์อื่นที่ค้างอยู่จะถูกให้เข้าสู่ระบบใหม่ทั้งหมด',
    fields: [
      {
        name: 'currentPassword',
        label: 'รหัสผ่านปัจจุบัน',
        type: 'password',
        required: true,
      },
      {
        name: 'newPassword',
        label: 'รหัสผ่านใหม่',
        type: 'password',
        required: true,
        hint: 'อย่างน้อย 8 ตัวอักษร',
      },
      {
        name: 'confirmPassword',
        label: 'ยืนยันรหัสผ่านใหม่',
        type: 'password',
        required: true,
      },
    ],
    submitLabel: 'เปลี่ยนรหัสผ่าน',
  });
  if (!values) return;
  if (values.newPassword !== values.confirmPassword) {
    toastError('รหัสผ่านใหม่ทั้งสองช่องไม่ตรงกัน');
    return;
  }
  try {
    await api.changePassword(values.currentPassword, values.newPassword);
    toastOk('เปลี่ยนรหัสผ่านแล้ว กรุณาเข้าสู่ระบบใหม่');
  } catch (error) {
    toastError(error.message);
  }
}

function healthCard() {
  const health = state.health;
  const mqtt = health?.mqtt;

  return el('div', { class: 'card', style: { marginBottom: '16px' } }, [
    el('div', { class: 'panel-title' }, [
      'สถานะการเชื่อมต่อ',
      el(
        'button',
        {
          class: 'btn btn-sm',
          type: 'button',
          onclick: async (event) => {
            event.currentTarget.disabled = true;
            await refreshAll();
            toastOk('ดึงข้อมูลใหม่แล้ว');
          },
        },
        [svg(icons.refresh(14)), 'ดึงข้อมูลใหม่'],
      ),
    ]),
    ...[
      ['API', health?.status === 'ok' ? 'ตอบปกติ' : 'ยังไม่ตอบ'],
      [
        'MQTT Broker',
        mqtt == null
          ? '—'
          : mqtt.connected
            ? 'เชื่อมต่ออยู่'
            : 'ยังไม่เชื่อมต่อ — บอร์ดจะสั่งงานไม่ได้',
      ],
      ['เวลาเซิร์ฟเวอร์ล่าสุด', time(state.live.serverTime)],
      [
        'ข้อมูลสดอัปเดตเมื่อ',
        state.live.serverTime ? relativeTime(state.live.serverTime) : '—',
      ],
    ].map(([label, value]) =>
      el('div', { class: 'rate-example-row', style: { fontSize: 'var(--fs-sm)' } }, [
        el('span', { class: 'muted', text: label }),
        el('span', { text: value }),
      ]),
    ),
    Object.entries(state.errors).some(([, message]) => message)
      ? el('div', {
          class: 'bad',
          style: { fontSize: 'var(--fs-xs)', marginTop: '10px', lineHeight: '1.7' },
          text:
            'โหลดข้อมูลบางส่วนไม่สำเร็จ: ' +
            Object.entries(state.errors)
              .filter(([, message]) => message)
              .map(([key, message]) => `${key} (${message})`)
              .join(' · '),
        })
      : null,
  ]);
}

function sessionCard(context) {
  return el('div', { class: 'card' }, [
    el('div', { class: 'panel-title', text: 'ออกจากระบบ' }),
    el('div', {
      class: 'dim',
      style: { fontSize: 'var(--fs-xs)', marginBottom: '12px', lineHeight: '1.7' },
      text:
        'ออกจากระบบจะลบโทเคนออกจากเบราว์เซอร์เครื่องนี้เท่านั้น ' +
        'ไม่กระทบอุปกรณ์อื่นที่เข้าอยู่',
    }),
    el(
      'button',
      {
        class: 'btn btn-danger',
        type: 'button',
        onclick: () => context.logout(),
      },
      [svg(icons.logout(15)), 'ออกจากระบบ'],
    ),
  ]);
}
