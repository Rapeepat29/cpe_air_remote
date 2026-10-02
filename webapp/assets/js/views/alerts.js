/**
 * หน้าการแจ้งเตือนทั้งหมด
 *
 * ต่างจากการ์ดในหน้าภาพรวมตรงที่กรองตามสถานะและห้องได้ และดูย้อนหลังได้ลึกกว่า
 * ใบที่ต้องให้คนไปจัดการ (auto_off_failed, outside_schedule_occupied) จะค้าง
 * สถานะ open ไว้จนกว่าจะมีคนกดรับทราบ จึงต้องมีที่ให้กดรับทราบเป็นชุด
 */

import { el, replace, emptyState } from '../dom.js';
import { ALERT_STATUS_LABEL } from '../format.js';
import { loaders, state } from '../store.js';
import { alertRow } from './overview.js';

const STATUS_TABS = [
  { key: '', label: 'ทั้งหมด' },
  { key: 'open', label: 'รอดำเนินการ' },
  { key: 'acknowledged', label: 'รับทราบแล้ว' },
  { key: 'resolved', label: 'จบแล้ว' },
];

let status = 'open';
let roomFilter = '';

export default {
  title: 'การแจ้งเตือน',
  subtitle: 'รายการเหตุการณ์ที่ระบบตรวจพบและต้องการการติดตาม',

  async mount(root) {
    const tabs = el('div', { class: 'tabbar' });
    const filterRow = el('div', {
      class: 'row',
      style: { marginTop: '14px' },
    });
    const list = el('div', { class: 'card', style: { marginTop: '16px' } });

    replace(root, [tabs, filterRow, list]);

    async function reload() {
      await loaders.alerts({
        limit: 200,
        status: status || undefined,
        room: roomFilter || undefined,
      });
      update();
    }

    function update() {
      replace(
        tabs,
        STATUS_TABS.map((tab) =>
          el('button', {
            class: `tab small${tab.key === status ? ' active' : ''}`,
            type: 'button',
            text:
              tab.key === ''
                ? tab.label
                : `${tab.label} (${state.alerts.counts?.[tab.key] ?? 0})`,
            onclick: () => {
              status = tab.key;
              reload();
            },
          }),
        ),
      );

      replace(filterRow, [
        el('div', { class: 'field', style: { marginBottom: '0', width: '220px' } }, [
          el('label', { text: 'กรองตามห้อง' }),
          el(
            'select',
            {
              onchange: (event) => {
                roomFilter = event.target.value;
                reload();
              },
            },
            [
              el('option', { value: '', text: 'ทุกห้อง', selected: roomFilter === '' }),
              ...state.rooms.map((room) =>
                el('option', {
                  value: room.roomNumber,
                  text: `ห้อง ${room.roomNumber}`,
                  selected: roomFilter === room.roomNumber,
                }),
              ),
            ],
          ),
        ]),
        el('div', {
          class: 'dim',
          style: { fontSize: 'var(--fs-xs)', alignSelf: 'flex-end' },
          text:
            'ใบที่ระบบปิดเองเมื่อเงื่อนไขหมดไป จะย้ายไปสถานะ ' +
            `"${ALERT_STATUS_LABEL.resolved}" โดยอัตโนมัติ`,
        }),
      ]);

      const alerts = state.alerts.alerts ?? [];
      if (alerts.length === 0) {
        replace(list, emptyState('ไม่มีการแจ้งเตือนที่ตรงกับตัวกรองนี้'));
        return;
      }
      replace(list, [
        el('div', { class: 'panel-title' }, [
          `พบ ${alerts.length} รายการ`,
          el('span', {
            class: 'count-badge',
            text: `รอดำเนินการทั้งระบบ ${state.alerts.counts?.open ?? 0}`,
          }),
        ]),
        ...alerts.map((alert) => alertRow(alert, { onChanged: update })),
      ]);
    }

    update();
    await reload();

    return { update };
  },
};
