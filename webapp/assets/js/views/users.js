/**
 * หน้าจัดการผู้ใช้งาน (เฉพาะแอดมิน)
 *
 * Backend ป้องกันไว้สองอย่างที่หน้าจอนี้ต้องอธิบายให้ผู้ใช้เข้าใจ:
 *   - แก้สิทธิ์หรือปิดบัญชีตัวเองไม่ได้ กันล็อกตัวเองออกจากระบบ
 *   - ปิดบัญชีแอดมินคนสุดท้ายไม่ได้ กันสถานการณ์ที่ไม่เหลือใครแก้อะไรได้เลย
 * ปุ่มจึงถูกปิดไว้ตั้งแต่ต้น แทนที่จะปล่อยให้กดแล้วเจอข้อความปฏิเสธ
 */

import { api } from '../api.js';
import { el, replace, emptyState, svg, toggle } from '../dom.js';
import { relativeTime, thaiShortDate } from '../format.js';
import { icons } from '../icons.js';
import { loaders, state } from '../store.js';
import { confirmAction, openForm, toastError, toastOk } from '../ui.js';

export default {
  title: 'ผู้ใช้งาน',
  subtitle: 'เพิ่มบัญชี กำหนดสิทธิ์ และปิดบัญชีที่ไม่ได้ใช้แล้ว',
  adminOnly: true,

  async mount(root) {
    const box = el('div', {});
    replace(root, box);

    function update() {
      const users = state.users ?? [];
      const activeAdmins = users.filter(
        (user) => user.role === 'admin' && user.isActive,
      ).length;

      replace(box, [
        el('div', { class: 'row between', style: { marginBottom: '14px' } }, [
          el('div', { class: 'pill', text: `${users.length} บัญชี · แอดมินที่ใช้งานอยู่ ${activeAdmins}` }),
          el(
            'button',
            {
              class: 'btn btn-sm btn-primary',
              type: 'button',
              onclick: () => addUser(update),
            },
            [svg(icons.plus(14)), 'เพิ่มผู้ใช้'],
          ),
        ]),
        users.length === 0
          ? emptyState('ยังไม่มีผู้ใช้ในระบบ')
          : el(
              'div',
              {},
              users.map((user) => userRow(user, activeAdmins, update)),
            ),
      ]);
    }

    update();
    await loaders.users();
    update();

    return { update };
  },
};

function userRow(user, activeAdmins, update) {
  const isSelf = user.username === state.user?.username;
  const isLastAdmin = user.role === 'admin' && user.isActive && activeAdmins <= 1;

  return el('div', { class: 'list-card' }, [
    el('div', { class: 'avatar', text: initials(user) }),
    el('div', { class: 'grow' }, [
      el('div', { class: 'list-title' }, [
        `${user.firstName} ${user.lastName}`.trim() || user.username,
        isSelf
          ? el('span', {
              class: 'status-chip done',
              style: { marginLeft: '8px' },
              text: 'บัญชีของคุณ',
            })
          : null,
      ]),
      el('div', {
        class: 'list-sub',
        text:
          `${user.username} · ${user.email || 'ไม่มีอีเมล'} · ` +
          `${user.phone || 'ไม่มีเบอร์'} · ` +
          `เข้าใช้ล่าสุด ${
            user.lastLoginAt ? relativeTime(user.lastLoginAt) : 'ยังไม่เคย'
          } · สร้างเมื่อ ${thaiShortDate(user.createdAt)}`,
      }),
    ]),
    el(
      'select',
      {
        style: { width: '120px' },
        disabled: isSelf || isLastAdmin,
        title: isSelf
          ? 'เปลี่ยนสิทธิ์ของตัวเองไม่ได้'
          : isLastAdmin
            ? 'ต้องเหลือแอดมินที่ใช้งานอยู่อย่างน้อยหนึ่งคน'
            : '',
        onchange: async (event) => {
          try {
            await api.updateUser(user.username, { role: event.target.value });
            toastOk('เปลี่ยนสิทธิ์แล้ว ผู้ใช้คนนั้นต้องเข้าสู่ระบบใหม่');
            await loaders.users();
            update();
          } catch (error) {
            toastError(error.message);
            update();
          }
        },
      },
      [
        el('option', {
          value: 'staff',
          text: 'เจ้าหน้าที่',
          selected: user.role === 'staff',
        }),
        el('option', {
          value: 'admin',
          text: 'ผู้ดูแลระบบ',
          selected: user.role === 'admin',
        }),
      ],
    ),
    el('div', { class: 'row', style: { gap: '6px' } }, [
      el('span', {
        class: 'dim',
        style: { fontSize: '11px' },
        text: 'เปิดใช้งาน',
      }),
      toggle(user.isActive, {
        disabled: isSelf || isLastAdmin,
        title: isSelf ? 'ปิดบัญชีตัวเองไม่ได้' : '',
        onclick: async () => {
          try {
            await api.updateUser(user.username, { isActive: !user.isActive });
            toastOk(user.isActive ? 'ปิดบัญชีแล้ว' : 'เปิดบัญชีแล้ว');
            await loaders.users();
            update();
          } catch (error) {
            toastError(error.message);
          }
        },
      }),
    ]),
    el('button', {
      class: 'btn btn-sm btn-danger',
      type: 'button',
      disabled: isSelf,
      text: 'ลบ',
      onclick: () => removeUser(user, update),
    }),
  ]);
}

function initials(user) {
  const first = (user.firstName || user.username || '?').trim().charAt(0);
  const last = (user.lastName || '').trim().charAt(0);
  return `${first}${last}`.toUpperCase();
}

async function addUser(update) {
  const values = await openForm({
    title: 'เพิ่มผู้ใช้ใหม่',
    subtitle: 'ผู้ใช้จะเข้าสู่ระบบด้วย Username และรหัสผ่านที่ตั้งให้ที่นี่',
    fields: [
      {
        name: 'username',
        label: 'Username',
        required: true,
        hint: 'ยาว 3–100 ตัว ใช้ได้เฉพาะ A–Z, 0–9, จุด, ขีดกลาง, ขีดล่าง',
      },
      { name: 'firstName', label: 'ชื่อ', required: true },
      { name: 'lastName', label: 'นามสกุล', required: true },
      { name: 'email', label: 'อีเมล', type: 'email', required: true },
      { name: 'phone', label: 'เบอร์โทร (ไม่บังคับ)' },
      {
        name: 'role',
        label: 'สิทธิ์',
        type: 'select',
        value: 'staff',
        options: [
          { value: 'staff', label: 'เจ้าหน้าที่' },
          { value: 'admin', label: 'ผู้ดูแลระบบ' },
        ],
      },
      {
        name: 'password',
        label: 'รหัสผ่านเริ่มต้น',
        type: 'password',
        required: true,
        hint: 'อย่างน้อย 8 ตัวอักษร',
      },
    ],
    submitLabel: 'สร้างบัญชี',
  });
  if (!values) return;
  try {
    await api.createUser(values);
    toastOk(`สร้างบัญชี ${values.username} แล้ว`);
    await loaders.users();
    update();
  } catch (error) {
    toastError(error.message);
  }
}

async function removeUser(user, update) {
  const ok = await confirmAction({
    title: `ลบบัญชี ${user.username}?`,
    subtitle:
      'ประวัติการกดรับทราบแจ้งเตือนที่ใช้ชื่อนี้จะยังอยู่ แต่บัญชีจะเข้าระบบไม่ได้อีก\n' +
      'ถ้าแค่อยากหยุดใช้ชั่วคราว ให้ปิดสวิตช์เปิดใช้งานแทน',
    confirmLabel: 'ลบบัญชี',
    danger: true,
  });
  if (!ok) return;
  try {
    await api.deleteUser(user.username);
    toastOk('ลบบัญชีแล้ว');
    await loaders.users();
    update();
  } catch (error) {
    toastError(error.message);
  }
}
