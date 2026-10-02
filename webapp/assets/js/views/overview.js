/**
 * หน้าภาพรวม
 *
 * ประกอบด้วย 4 ส่วนที่ตอบคำถามต่างกัน:
 *   1. การ์ดใหญ่ — ช่วงนี้ทั้งอาคารใช้ไฟไปเท่าไร คิดเป็นเงินเท่าไร ขึ้นหรือลง
 *   2. ตัวเลขสี่ช่อง — ตอนนี้มีอะไรที่ต้องสนใจทันทีบ้าง
 *   3. Building Pulse — ไฟหมดไปกับห้องไหน และตอนนี้ห้องไหนกำลังเปิดแอร์อยู่
 *   4. แจ้งเตือน + อันดับ — มีอะไรค้างให้คนไปจัดการ
 */

import { api } from '../api.js';
import { areaChart, heatColor, rankBars } from '../charts.js';
import { el, replace, emptyState, svg } from '../dom.js';
import {
  ALERT_STATUS_LABEL,
  baht,
  decimal,
  describeAlert,
  energy,
  floorLabel,
  integer,
  relativeTime,
  scaleReference,
} from '../format.js';
import { icons } from '../icons.js';
import {
  airConditionersOf,
  loaders,
  roomEnergyMap,
  roomsByFloor,
  state,
} from '../store.js';
import { toastError, toastOk } from '../ui.js';

const PERIODS = [
  { key: 'day', label: 'วันนี้' },
  { key: 'week', label: '7 วัน' },
  { key: 'month', label: '30 วัน' },
];

export default {
  title: 'ภาพรวม',
  subtitle: 'สรุปการใช้ไฟและสถานะของทั้งอาคารในหน้าจอเดียว',

  mount(root, context) {
    const heroBox = el('div', { class: 'card hero-card' });
    const statBox = el('div', { class: 'stat-mini-grid' });
    const pulseBox = el('div', { class: 'card pulse-card' });
    const alertBox = el('div', { class: 'card' });
    const rankBox = el('div', { class: 'card' });

    replace(root, [
      el('div', { class: 'hero-row' }, [heroBox, statBox]),
      pulseBox,
      el('div', { class: 'two-col' }, [alertBox, rankBox]),
    ]);

    function update() {
      renderHero(heroBox);
      renderStats(statBox);
      renderPulse(pulseBox, context);
      renderAlerts(alertBox);
      renderRank(rankBox);
    }

    update();
    return { update };
  },
};

// ---------------------------------------------------------------- การ์ดใหญ่

function renderHero(box) {
  const summary = state.summary;
  const period = state.summaryQuery.period ?? 'week';

  const tabs = el(
    'div',
    { class: 'tabbar', style: { marginTop: '14px' } },
    PERIODS.map((item) =>
      el('button', {
        class: `tab small${item.key === period ? ' active' : ''}`,
        type: 'button',
        text: item.label,
        onclick: () => loaders.summary({ period: item.key }),
      }),
    ),
  );

  if (!summary) {
    replace(box, [
      el('div', { class: 'eyebrow' }, [
        svg(icons.bolt(13)),
        'พลังงานที่ใช้ · ทั้งอาคาร',
      ]),
      el('div', { class: 'empty', text: 'กำลังโหลดข้อมูลค่าไฟ…' }),
      tabs,
    ]);
    return;
  }

  const kwh = Number(summary.totals.kwh) || 0;
  const rate = state.settings.electricityRate;
  const change = summary.totals.changePercent;

  let trendClass = 'flat';
  let trendText = 'ยังไม่มีข้อมูลช่วงก่อนหน้าให้เทียบ';
  if (change != null) {
    const dropped = change <= 0;
    trendClass = dropped ? '' : 'up';
    trendText =
      `${dropped ? '↓ ลดลง' : '↑ เพิ่มขึ้น'} ` +
      `${decimal(Math.abs(change), 1)}% จากช่วงก่อนหน้า`;
  }

  const points = (summary.series ?? []).map((point) => ({
    label: point.label,
    value: point.kwh,
  }));

  replace(box, [
    el('div', { class: 'eyebrow' }, [
      svg(icons.bolt(13)),
      `พลังงานที่ใช้ · ${summary.period.from} ถึง ${summary.period.to}`,
    ]),
    el('div', { class: 'hero-figure' }, [
      // ตัวเลขใหญ่ตัวนี้แสดงทศนิยมหนึ่งตำแหน่งเสมอ ต่างจากที่อื่นที่ปัดตามขนาด
      // เพราะเป็นตัวเลขที่คนเอาไปพูดต่อ การเห็น 271 แทน 270.5 ทำให้เข้าใจผิดว่า
      // ระบบวัดหยาบกว่าความจริง
      el('div', { class: 'hero-num', text: decimal(kwh, 1) }),
      el('div', { class: 'hero-unit', text: 'kWh' }),
    ]),
    el('div', { class: 'hero-meta' }, [
      el('div', {
        class: 'cost-chip',
        text: `≈ ${baht(kwh * rate)} (อัตรา ${decimal(rate, 2)} บาท/kWh)`,
      }),
      el('div', { class: `trend-chip ${trendClass}`, text: trendText }),
    ]),
    areaChart(points, { height: 150 }),
    el('div', { class: 'row', style: { marginTop: '10px', gap: '16px' } }, [
      el('span', {
        class: 'dim',
        style: { fontSize: '11.5px' },
        text: `เวลาทำงานรวม ${integer(summary.totals.runtimeMinutes)} นาที`,
      }),
      el('span', {
        class: 'dim',
        style: { fontSize: '11.5px' },
        text: `กำลังไฟสูงสุด ${decimal(summary.totals.peakPowerWatts, 1)} W`,
      }),
      el('span', {
        class: 'dim',
        style: { fontSize: '11.5px' },
        text: `มีข้อมูลจาก ${integer(summary.totals.deviceCount)} เครื่อง`,
      }),
    ]),
    tabs,
  ]);
}

// ------------------------------------------------------------ ตัวเลขสี่ช่อง

function statMini(iconMarkup, tone, value, suffix, label) {
  const iconBox = el('div', {
    class: 'stat-mini-icon',
    style: { background: tone.background, color: tone.color },
  });
  iconBox.innerHTML = iconMarkup;
  const valueNode = el('div', { class: 'stat-mini-val', text: value });
  if (suffix) valueNode.appendChild(el('small', { text: ` ${suffix}` }));
  return el('div', { class: 'stat-mini' }, [
    iconBox,
    valueNode,
    el('div', { class: 'stat-mini-label', text: label }),
  ]);
}

function renderStats(box) {
  const totals = state.live.totals;
  const openAlerts = Number(state.alerts.counts?.open ?? 0);
  const accent = { background: 'var(--accent-soft)', color: 'var(--accent)' };
  const warn = { background: 'var(--warn-soft)', color: 'var(--warn)' };
  const neutral = {
    background: 'rgba(143,179,158,.14)',
    color: 'var(--text-hi)',
  };

  replace(box, [
    statMini(
      icons.pulseLine(15),
      accent,
      totals ? String(totals.running) : '—',
      totals ? `/ ${totals.devices}` : '',
      'เครื่องปรับอากาศทำงานอยู่',
    ),
    statMini(
      icons.warning(15),
      openAlerts > 0 ? warn : neutral,
      String(openAlerts),
      '',
      'แจ้งเตือนรอดำเนินการ',
    ),
    statMini(
      icons.board(15),
      accent,
      totals ? String(totals.online) : '—',
      totals ? `/ ${totals.devices}` : '',
      'ESP32 ออนไลน์',
    ),
    statMini(
      icons.clock(15),
      neutral,
      decimal(state.settings.electricityRate, 2),
      '',
      'อัตราปัจจุบัน (บาท/kWh)',
    ),
  ]);
}

// ---------------------------------------------------------- Building Pulse

function renderPulse(box, context) {
  const energyByRoom = roomEnergyMap();
  const groups = roomsByFloor();
  const max = Math.max(0, ...[...energyByRoom.values()].map(Number));

  const head = el('div', { class: 'pulse-head' }, [
    el('div', {}, [
      el('div', { class: 'pulse-title', text: 'Building Pulse — อาคาร 16' }),
      el('div', {
        class: 'pulse-desc',
        text:
          'ความกว้างและสีของแต่ละช่องคือปริมาณไฟที่ห้องนั้นใช้ในช่วงที่เลือก ' +
          'จุดกะพริบคือห้องที่มีแอร์ทำงานอยู่ตอนนี้ กดที่ช่องเพื่อเปิดรีโมต',
      }),
    ]),
    el('div', { class: 'legend' }, [
      'ใช้น้อย',
      el('span', { class: 'legend-bar' }),
      'ใช้มาก',
    ]),
  ]);

  if (groups.length === 0) {
    replace(box, [head, emptyState('ยังไม่มีห้องในระบบ')]);
    return;
  }

  const floors = groups.map((group) =>
    el('div', { class: 'pulse-floor' }, [
      el('div', {
        class: 'pulse-floor-label',
        text: floorLabel(group.floor),
      }),
      el(
        'div',
        { class: 'pulse-cells' },
        group.rooms.map((room) => {
          const kwh = Number(energyByRoom.get(room.roomNumber) ?? 0);
          const units = airConditionersOf(room.roomNumber);
          const running = units.filter((unit) => unit.acRunning).length;
          const counting = room.autoOffSecondsRemaining != null;
          const hasUnits = units.length > 0;

          const cell = el(
            'button',
            {
              class: 'pulse-cell',
              type: 'button',
              style: {
                background: heatColor(kwh, max),
                flex: `${1 + (max > 0 ? (kwh / max) * 2.4 : 0)}`,
              },
              title:
                `ห้อง ${room.roomNumber} · ${room.roomType}\n` +
                `${energy(kwh)} ในช่วงที่เลือก\n` +
                `แอร์ ${units.length} เครื่อง · ทำงานอยู่ ${running}`,
              onclick: () => context.openRoom(room.roomNumber),
            },
            [
              el('div', { class: 'room', text: room.roomNumber }),
              el('div', {
                class: 'kwh',
                text: hasUnits ? energy(kwh) : 'ยังไม่ติดตั้ง',
              }),
            ],
          );

          if (running > 0) {
            cell.appendChild(
              el('span', {
                class: `pulse-live${counting ? ' warn' : ''}`,
                title: counting ? 'กำลังนับถอยหลังปิดอัตโนมัติ' : 'แอร์ทำงานอยู่',
              }),
            );
          }
          return cell;
        }),
      ),
    ]),
  );

  replace(box, [head, ...floors]);
}

// ------------------------------------------------------------- แจ้งเตือน

function renderAlerts(box) {
  const alerts = state.alerts.alerts ?? [];
  const open = alerts.filter((alert) => alert.status === 'open');
  const shown = [...open, ...alerts.filter((a) => a.status !== 'open')].slice(
    0,
    6,
  );

  const head = el('div', { class: 'panel-title' }, [
    'การแจ้งเตือนของระบบ',
    el('span', {
      class: 'count-badge',
      text: `รอดำเนินการ ${open.length}`,
    }),
  ]);

  if (shown.length === 0) {
    replace(box, [head, emptyState('ยังไม่มีการแจ้งเตือน ระบบทำงานปกติ')]);
    return;
  }

  replace(box, [head, ...shown.map(alertRow)]);
}

export function alertRow(alert, { onChanged = null } = {}) {
  const described = describeAlert(alert);
  const tone =
    alert.status === 'open'
      ? 'pending'
      : alert.status === 'acknowledged'
        ? 'ack'
        : 'done';

  const actions = el('div', { class: 'row', style: { gap: '8px' } }, [
    el('span', {
      class: `status-chip ${tone === 'ack' ? 'done' : tone}`,
      text: ALERT_STATUS_LABEL[alert.status] ?? alert.status,
    }),
    alert.status === 'open'
      ? el('button', {
          class: 'btn btn-sm',
          type: 'button',
          text: 'รับทราบ',
          onclick: async (event) => {
            const button = event.currentTarget;
            button.disabled = true;
            try {
              await api.acknowledgeAlert(alert.id);
              toastOk(`รับทราบการแจ้งเตือนของห้อง ${alert.roomNumber} แล้ว`);
              await loaders.alerts();
              if (onChanged) onChanged();
            } catch (error) {
              button.disabled = false;
              toastError(error.message);
            }
          },
        })
      : null,
    alert.acknowledgedBy
      ? el('span', {
          class: 'dim',
          style: { fontSize: '11px' },
          text: `โดย ${alert.acknowledgedBy}`,
        })
      : null,
  ]);

  return el('div', { class: 'alert-item' }, [
    el('div', { class: `alert-bar ${tone}` }),
    el('div', { class: 'alert-body' }, [
      el('div', { class: 'alert-top' }, [
        el('div', { class: 'alert-room', text: described.title }),
        el('div', { class: 'alert-time', text: relativeTime(alert.createdAt) }),
      ]),
      el('div', { class: 'alert-desc', text: described.body }),
      actions,
    ]),
  ]);
}

// ---------------------------------------------------------- อันดับการใช้ไฟ

function renderRank(box) {
  const rooms = (state.summary?.rooms ?? []).filter((row) => row.kwh > 0);
  const head = el('div', { class: 'panel-title' }, [
    'ห้องที่ใช้ไฟมากที่สุด',
    el('span', {
      class: 'count-badge',
      text: `${rooms.length} ห้องมีข้อมูล`,
    }),
  ]);

  if (rooms.length === 0) {
    replace(box, [
      head,
      emptyState(
        'ยังไม่มีข้อมูลค่าไฟในช่วงนี้\nตัวเลขจะขึ้นเมื่อบอร์ดส่งค่าจาก PZEM เข้ามา',
      ),
    ]);
    return;
  }

  const top = rooms.slice(0, 5);
  const totalKwh = rooms.reduce((sum, row) => sum + Number(row.kwh || 0), 0);
  const reference = scaleReference(top.map((row) => row.kwh));

  replace(box, [
    head,
    ...rankBars(
      top.map((row) => ({
        label: `ห้อง ${row.roomNumber}`,
        sub:
          `${floorLabel(row.floorNumber)} · ${row.deviceCount} เครื่อง · ` +
          `${baht(Number(row.kwh) * state.settings.electricityRate)}`,
        value: row.kwh,
      })),
      icons.building(17),
    ),
    el('div', {
      class: 'dim',
      style: { fontSize: '11.5px', marginTop: '12px' },
      text:
        `5 ห้องนี้กินไฟรวม ${energy(
          top.reduce((sum, row) => sum + Number(row.kwh || 0), 0),
          { scaleReference: reference },
        )} ` +
        `จากทั้งหมด ${energy(totalKwh)}`,
    }),
  ]);
}
