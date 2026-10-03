/**
 * หน้าจอเข้าสู่ระบบและขั้นตอนลืมรหัสผ่าน
 *
 * ใช้ผู้ใช้และรหัสผ่านชุดเดียวกับแอปมือถือ เพราะเป็นฐานข้อมูลเดียวกัน
 * โทเคนเก็บใน localStorage ไม่ใช่ cookie เพราะ Backend ตรวจสิทธิ์จากหัว
 * Authorization อย่างเดียว การเก็บเป็น cookie จะทำให้ต้องคิดเรื่อง CSRF เพิ่ม
 * โดยไม่ได้ประโยชน์อะไรกลับมา
 */

import { api } from './api.js';
import { el, replace, svg } from './dom.js';
import { icons } from './icons.js';
import { openForm, openModal, toastError, toastOk } from './ui.js';
import { BUILDING } from './config.js';

export function mountLoginScreen(onSuccess) {
  const screen = el('div', { class: 'login-screen' });
  const errorLine = el('div', { class: 'login-error', hidden: true });

  const username = el('input', {
    type: 'text',
    autocomplete: 'username',
    placeholder: 'เช่น admin',
  });
  const password = el('input', {
    type: 'password',
    autocomplete: 'current-password',
    placeholder: 'รหัสผ่าน',
  });

  const submit = el(
    'button',
    { class: 'btn btn-primary btn-block', type: 'submit' },
    [svg(icons.bolt(15, 2.4)), 'เข้าสู่ระบบ'],
  );

  const form = el(
    'form',
    {
      onsubmit: async (event) => {
        event.preventDefault();
        errorLine.hidden = true;
        submit.disabled = true;
        submit.textContent = 'กำลังตรวจสอบ…';
        try {
          const user = await api.login(
            username.value.trim(),
            password.value,
          );
          screen.remove();
          onSuccess(user);
        } catch (error) {
          errorLine.textContent = error.message;
          errorLine.hidden = false;
          password.value = '';
          password.focus();
        } finally {
          submit.disabled = false;
          replace(submit, [svg(icons.bolt(15, 2.4)), 'เข้าสู่ระบบ']);
        }
      },
    },
    [
      errorLine,
      el('div', { class: 'field' }, [
        el('label', { text: 'Username' }),
        username,
      ]),
      el('div', { class: 'field' }, [
        el('label', { text: 'รหัสผ่าน' }),
        password,
      ]),
      submit,
    ],
  );

  const mark = el('div', { class: 'brand-mark' });
  // โลโก้ RMUTT Save Energy (SVG เดียวกับ favicon.svg) เขียนไว้ในโค้ด ไม่ได้มาจากฐานข้อมูล
  mark.innerHTML =
    '<svg xmlns="http://www.w3.org/2000/svg" width="34" height="34" aria-hidden="true" focusable="false" viewBox="0 0 240 240"><rect width="240" height="240" rx="56" fill="#2F3438"/><g transform="translate(-2,-10)"><path d="M110 150 C150 144 184 170 184 208 C146 208 110 186 110 150 Z" fill="#2EB872"/><path d="M122 160 L172 198" stroke="#2F3438" stroke-width="4" stroke-linecap="round"/><path d="M82 184 L82 73 L126 73 A33 33 0 0 1 126 139 L82 139" fill="none" stroke="#FFFFFF" stroke-width="34" stroke-linecap="round" stroke-linejoin="round"/></g></svg>';

  replace(screen, [
    el('div', { class: 'login-card' }, [
      el('div', { class: 'login-brand' }, [
        mark,
        el('div', {}, [
          el('div', { class: 'wordmark', 'aria-label': 'RMUTT Save Energy' }, [
            el('span', { class: 'wordmark-name' }, [el('b', { text: 'R' }), 'MUTT']),
            el('span', { class: 'wordmark-tag', text: 'SAVE ENERGY' }),
          ]),
          el('div', {
            class: 'user-role',
            text: `${BUILDING.name} · ${BUILDING.subtitle}`,
          }),
        ]),
      ]),
      form,
      el('div', { class: 'login-foot' }, [
        el('button', {
          class: 'btn btn-sm',
          type: 'button',
          style: { width: '100%', marginTop: '4px' },
          text: 'ลืมรหัสผ่าน',
          onclick: () => forgotPasswordFlow(),
        }),
        el('div', {
          style: { marginTop: '10px' },
          text: 'ใช้บัญชีเดียวกับแอปบนมือถือ',
        }),
      ]),
    ]),
  ]);

  document.body.appendChild(screen);
  username.focus();
  return screen;
}

/**
 * ลืมรหัสผ่าน 3 ขั้น: ขอ OTP → ยืนยัน OTP → ตั้งรหัสใหม่
 *
 * แยกเป็นสามกล่องตามลำดับจริงของ Backend เพราะแต่ละขั้นมีอายุของตัวเอง
 * ถ้ารวมเป็นฟอร์มเดียว ผู้ใช้จะไม่รู้ว่าค้างอยู่ขั้นไหนเมื่อกรอกผิด
 */
async function forgotPasswordFlow() {
  const first = await openForm({
    title: 'ลืมรหัสผ่าน',
    subtitle: 'กรอก Username หรืออีเมลที่ลงทะเบียนไว้ ระบบจะส่งรหัส OTP ไปที่อีเมล',
    fields: [
      { name: 'identifier', label: 'Username หรืออีเมล', required: true },
    ],
    submitLabel: 'ขอรหัส OTP',
  });
  if (!first) return;

  let requestId;
  try {
    const result = await api.forgotPassword(first.identifier);
    requestId = result?.requestId ?? result?.request?.id;
    if (!requestId) {
      await openModal({
        title: 'ส่งคำขอแล้ว',
        subtitle:
          'ถ้ามีบัญชีนี้ในระบบ จะได้รับอีเมลพร้อมรหัส OTP ' +
          'กรุณาตรวจกล่องจดหมายแล้วทำตามขั้นตอนในอีเมล',
        actions: [{ label: 'ปิด', class: 'btn-primary', value: true }],
      });
      return;
    }
  } catch (error) {
    toastError(error.message);
    return;
  }

  const second = await openForm({
    title: 'กรอกรหัส OTP',
    subtitle: 'รหัสมีอายุจำกัด ถ้าหมดอายุให้เริ่มขอใหม่',
    fields: [
      { name: 'otp', label: 'รหัส OTP 6 หลัก', required: true, inputmode: 'numeric' },
    ],
    submitLabel: 'ยืนยัน',
  });
  if (!second) return;

  let resetToken;
  try {
    const result = await api.verifyOtp(requestId, second.otp);
    resetToken = result?.resetToken;
    if (!resetToken) throw new Error('ไม่ได้รับรหัสสำหรับตั้งรหัสผ่านใหม่');
  } catch (error) {
    toastError(error.message);
    return;
  }

  const third = await openForm({
    title: 'ตั้งรหัสผ่านใหม่',
    fields: [
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
    submitLabel: 'ตั้งรหัสผ่าน',
  });
  if (!third) return;
  if (third.newPassword !== third.confirmPassword) {
    toastError('รหัสผ่านทั้งสองช่องไม่ตรงกัน');
    return;
  }

  try {
    await api.resetPassword(resetToken, third.newPassword);
    toastOk('ตั้งรหัสผ่านใหม่แล้ว กรุณาเข้าสู่ระบบ');
  } catch (error) {
    toastError(error.message);
  }
}
