/** กล่องข้อความ กล่องยืนยัน และกล่องกรอกข้อมูล ที่ใช้ร่วมกันทุกหน้า */

import { el, replace, append } from './dom.js';
import { icons } from './icons.js';

let stack = null;

function toastStack() {
  if (!stack) {
    stack = el('div', { class: 'toast-stack' });
    document.body.appendChild(stack);
  }
  return stack;
}

/**
 * แจ้งผลการกระทำ
 *
 * ใช้แทน alert() เพราะ alert() บล็อกทั้งหน้าและกดปิดไม่ทัน เวลามีคำสั่ง
 * หลายอันวิ่งพร้อมกัน (เช่นสั่งปิดแอร์ทั้งห้อง) จะเด้งซ้อนกันจนกดไม่หยุด
 */
export function toast(message, kind = 'ok', ms = 4200) {
  const node = el('div', { class: `toast ${kind}`, text: message });
  toastStack().appendChild(node);
  window.setTimeout(() => {
    node.style.opacity = '0';
    node.style.transition = 'opacity .2s';
    window.setTimeout(() => node.remove(), 220);
  }, ms);
  return node;
}

export const toastOk = (message) => toast(message, 'ok');
export const toastError = (message) => toast(message, 'err', 6000);
export const toastInfo = (message) => toast(message, 'info');

/**
 * เปิดกล่องโต้ตอบ
 *
 * คืน Promise ที่จบเมื่อผู้ใช้กดปุ่มใดปุ่มหนึ่ง เขียนแบบนี้เพื่อให้ผู้เรียก
 * `await` ได้เหมือน confirm() เดิม แต่ไม่บล็อกเบราว์เซอร์
 */
export function openModal({ title, subtitle = '', body = null, actions }) {
  return new Promise((resolve) => {
    const overlay = el('div', { class: 'modal-overlay' });
    const modal = el('div', {
      class: 'modal',
      role: 'dialog',
      'aria-modal': 'true',
    });

    const close = (value) => {
      document.removeEventListener('keydown', onKey);
      overlay.remove();
      resolve(value);
    };

    const onKey = (event) => {
      if (event.key === 'Escape') close(null);
    };

    append(modal, [
      el('h3', { text: title }),
      subtitle ? el('div', { class: 'modal-sub', text: subtitle }) : null,
      body,
      el(
        'div',
        { class: 'modal-actions' },
        actions.map((action) =>
          el('button', {
            class: `btn ${action.class ?? ''}`,
            type: 'button',
            text: action.label,
            onclick: () => {
              if (action.onclick) {
                const result = action.onclick(modal);
                if (result === false) return;
                close(result === undefined ? action.value ?? true : result);
                return;
              }
              close(action.value ?? null);
            },
          }),
        ),
      ),
    ]);

    overlay.addEventListener('click', (event) => {
      if (event.target === overlay) close(null);
    });
    document.addEventListener('keydown', onKey);

    overlay.appendChild(modal);
    document.body.appendChild(overlay);
    const firstInput = modal.querySelector('input, select, textarea');
    if (firstInput) firstInput.focus();
  });
}

/** กล่องยืนยันการกระทำที่ย้อนกลับไม่ได้ */
export function confirmAction({
  title,
  subtitle = '',
  confirmLabel = 'ยืนยัน',
  danger = false,
}) {
  return openModal({
    title,
    subtitle,
    actions: [
      { label: 'ยกเลิก', value: false },
      {
        label: confirmLabel,
        value: true,
        class: danger ? 'btn-danger' : 'btn-primary',
      },
    ],
  });
}

/**
 * กล่องกรอกข้อมูลจากรายการช่อง
 *
 * `fields` = [{ name, label, value, type, options, hint, required }]
 * คืนอ็อบเจกต์ค่าที่กรอก หรือ null ถ้ายกเลิก
 */
export function openForm({
  title,
  subtitle = '',
  fields,
  submitLabel = 'บันทึก',
}) {
  const inputs = new Map();
  const errorLine = el('div', { class: 'login-error', hidden: true });

  const body = el('div', {}, [
    errorLine,
    ...fields.map((field) => {
      let input;
      if (field.type === 'select') {
        input = el(
          'select',
          { name: field.name },
          (field.options ?? []).map((option) =>
            el('option', {
              value: option.value,
              text: option.label,
              selected: String(option.value) === String(field.value ?? ''),
            }),
          ),
        );
      } else if (field.type === 'textarea') {
        input = el('textarea', { name: field.name, rows: field.rows ?? 3 });
        input.value = field.value ?? '';
      } else {
        input = el('input', {
          name: field.name,
          type: field.type ?? 'text',
          value: field.value ?? '',
          placeholder: field.placeholder ?? '',
          inputmode: field.inputmode,
          autocomplete: field.autocomplete ?? 'off',
        });
      }
      inputs.set(field.name, input);
      return el('div', { class: 'field' }, [
        el('label', { text: field.label, for: field.name }),
        input,
        field.hint ? el('div', { class: 'hint', text: field.hint }) : null,
      ]);
    }),
  ]);

  return openModal({
    title,
    subtitle,
    body,
    actions: [
      { label: 'ยกเลิก', value: null },
      {
        label: submitLabel,
        class: 'btn-primary',
        onclick: () => {
          const values = {};
          for (const field of fields) {
            const raw = inputs.get(field.name).value;
            const value = typeof raw === 'string' ? raw.trim() : raw;
            if (field.required && !value) {
              errorLine.textContent = `กรุณากรอก${field.label}`;
              errorLine.hidden = false;
              inputs.get(field.name).focus();
              return false;
            }
            values[field.name] = value;
          }
          return values;
        },
      },
    ],
  });
}

/** ปุ่มไอคอนพร้อมคำอธิบายเวลาชี้ค้าง */
export function iconButton(name, title, onclick, extraClass = '') {
  const button = el('button', {
    class: `icon-btn ${extraClass}`,
    type: 'button',
    title,
    'aria-label': title,
    onclick,
  });
  button.innerHTML = icons[name] ? icons[name]() : '';
  return button;
}

/** ตั้งเนื้อหาของกล่องใหม่ทั้งหมด */
export const render = replace;

/**
 * ทำให้ปุ่มแสดงสถานะกำลังทำงาน
 *
 * ปิดปุ่มระหว่างรอคำตอบ เพราะคำสั่งอย่าง "ส่งคำสั่งปิดแอร์" ถ้ากดรัว ๆ
 * จะยิง MQTT ซ้ำหลายครั้ง แล้วแอร์บางรุ่นตีความเป็นกดปุ่มสลับเปิด-ปิด
 */
export async function withBusy(button, task, busyLabel = 'กำลังทำงาน…') {
  if (!button) return task();
  const original = button.textContent;
  const wasDisabled = button.disabled;
  button.disabled = true;
  button.textContent = busyLabel;
  try {
    return await task();
  } finally {
    button.disabled = wasDisabled;
    button.textContent = original;
  }
}
