/**
 * หน้าอัตราค่าไฟ
 *
 * อัตราถูกเก็บไว้ที่เซิร์ฟเวอร์ (ตาราง system_settings) ไม่ใช่ในเบราว์เซอร์
 * เพราะตัวเลขค่าใช้จ่ายต้องตรงกันทุกเครื่องที่เปิดดู ถ้าเก็บในเครื่องใครเครื่องมัน
 * คนสองคนดูหน้าเดียวกันจะเห็นค่าไฟไม่เท่ากัน แล้วเถียงกันว่าใครถูก
 */

import { api } from '../api.js';
import { el, replace, svg } from '../dom.js';
import { baht, decimal, energy } from '../format.js';
import { icons } from '../icons.js';
import { loaders, state } from '../store.js';
import { toastError, toastOk } from '../ui.js';

export default {
  title: 'อัตราค่าไฟฟ้า',
  subtitle: 'กำหนดอัตราต่อ kWh ที่ใช้คำนวณค่าใช้จ่ายโดยประมาณทั้งระบบ',

  mount(root) {
    const wrap = el('div', { class: 'rate-wrap' });
    replace(root, wrap);

    function update() {
      const rate = Number(state.settings.electricityRate) || 0;
      const isAdmin = state.user?.role === 'admin';
      const sampleKwh = Number(state.summary?.totals?.kwh ?? 0);

      const input = el('input', {
        type: 'text',
        inputmode: 'decimal',
        value: decimal(rate, 2),
        disabled: !isAdmin,
      });

      const preview = el('div', { class: 'rate-example' });

      const drawPreview = () => {
        const typed = Number.parseFloat(String(input.value).replace(/,/g, ''));
        const usable = Number.isFinite(typed) ? typed : rate;
        replace(preview, [
          el('div', {
            class: 'panel-title',
            style: { fontSize: 'var(--fs-sm)', marginBottom: '4px' },
            text: 'ตัวอย่างการคำนวณจากข้อมูลจริงของช่วงที่เลือกอยู่',
          }),
          row('พลังงานที่ใช้', energy(sampleKwh)),
          row('อัตราค่าไฟฟ้า', `${decimal(usable, 2)} บาท/kWh`),
          el('div', { class: 'rate-example-row total' }, [
            el('span', { text: 'ค่าไฟโดยประมาณ' }),
            el('span', { class: 'mono', text: baht(sampleKwh * usable) }),
          ]),
        ]);
      };

      input.addEventListener('input', drawPreview);

      const iconBox = el('div', { class: 'rate-icon-box' });
      iconBox.innerHTML = icons.meter(20);

      replace(wrap, [
        el('div', { class: 'rate-current' }, [
          iconBox,
          el('div', {}, [
            el('div', {
              class: 'eyebrow',
              style: { color: 'var(--text-mid)' },
              text: 'อัตราปัจจุบัน',
            }),
            el('div', { class: 'rate-value' }, [
              decimal(rate, 2),
              el('small', { text: ' บาท / kWh' }),
            ]),
          ]),
        ]),
        el('div', { class: 'card' }, [
          el('div', {
            class: 'panel-title',
            style: { marginBottom: '8px' },
            text: 'แก้ไขอัตราต่อ kWh',
          }),
          el('div', { class: 'rate-input-row' }, [
            svg(icons.coin(16)),
            input,
            el('span', {
              style: {
                fontSize: 'var(--fs-sm)',
                color: 'var(--text-mid)',
                flex: 'none',
              },
              text: 'บาท/kWh',
            }),
          ]),
          el('div', {
            class: 'rate-hint',
            text: isAdmin
              ? 'กรอกได้ตั้งแต่ 0.01 ถึง 100.00 บาทต่อ kWh'
              : 'เฉพาะผู้ดูแลระบบเท่านั้นที่แก้อัตราได้',
          }),
          preview,
          isAdmin
            ? el(
                'button',
                {
                  class: 'btn btn-primary btn-block',
                  style: { marginTop: '18px' },
                  type: 'button',
                  onclick: (event) => save(input, event.currentTarget, update),
                },
                [svg(icons.save(15)), 'บันทึกอัตราค่าไฟ'],
              )
            : null,
        ]),
        el('div', {
          class: 'card dim',
          style: { marginTop: '16px', fontSize: 'var(--fs-xs)', lineHeight: '1.8' },
          text:
            'อัตรานี้ใช้คำนวณเฉพาะตัวเลข "โดยประมาณ" ที่แสดงในหน้าภาพรวม ' +
            'หน้าข้อมูลไฟฟ้า และคอลัมน์ค่าไฟในไฟล์ Excel เท่านั้น ' +
            'ระบบไม่ได้เก็บค่าเงินลงฐานข้อมูล เก็บแต่หน่วย kWh ' +
            'เปลี่ยนอัตราเมื่อไรตัวเลขเก่าจึงคิดใหม่ตามอัตราล่าสุดทั้งหมด',
        }),
      ]);

      drawPreview();
    }

    update();
    return { update };
  },
};

function row(label, value) {
  return el('div', { class: 'rate-example-row' }, [
    el('span', { class: 'muted', text: label }),
    el('span', { class: 'mono', text: value }),
  ]);
}

async function save(input, button, update) {
  const value = Number.parseFloat(String(input.value).replace(/,/g, ''));
  if (!Number.isFinite(value) || value < 0.01 || value > 100) {
    toastError('อัตราต้องอยู่ระหว่าง 0.01 ถึง 100.00 บาทต่อ kWh');
    return;
  }
  button.disabled = true;
  try {
    await api.setElectricityRate(value);
    await loaders.settings();
    toastOk(`บันทึกอัตรา ${decimal(value, 2)} บาท/kWh แล้ว`);
    update();
  } catch (error) {
    // Backend รุ่นก่อน v3.13.0 ยังไม่มีเส้นทางนี้ บอกให้ชัดว่าต้องอัปเดตอะไร
    if (error.status === 404) {
      toastError(
        'เซิร์ฟเวอร์ยังไม่รองรับการตั้งอัตราค่าไฟ ' +
          'ให้รัน deploy\\update-server.ps1 เพื่ออัปเดต Backend ก่อน',
      );
    } else {
      toastError(error.message);
    }
  } finally {
    button.disabled = false;
  }
}
