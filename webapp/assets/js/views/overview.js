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
  isoDate,
  relativeTime,
  scaleReference,
  thaiDate,
} from '../format.js';
import { icons } from '../icons.js';
import { thaiDateInput } from '../thai-date-input.js';
import {
  airConditionersOf,
  loaders,
  roomEnergyMap,
  roomsByFloor,
  state,
} from '../store.js';
import { toastError, toastOk } from '../ui.js';
import { createCompare } from './overview-compare.js';

const PERIODS = [
  { key: 'day', label: 'วันนี้' },
  { key: 'week', label: '7 วัน' },
  { key: 'month', label: '30 วัน' },
];

/** คำอธิบายจุดบนกราฟของแต่ละช่วง (วันนี้ = รายชั่วโมง ที่เหลือ = รายวัน) */
const PERIOD_LABEL = {
  day: 'ชั่วโมงนี้',
  week: 'ทั้งวัน',
  month: 'ทั้งวัน',
};

/** Backend ยอมให้เลือกช่วงเองได้ไม่เกินเท่านี้ (resolvePeriod) */
const MAX_CUSTOM_DAYS = 366;

export default {
  title: 'ภาพรวม',
  subtitle: 'สรุปการใช้ไฟและสถานะของทั้งอาคารในหน้าจอเดียว',

  mount(root, context) {
    // การ์ดใหญ่แยกเป็นสองชั้น: เนื้อหาที่วาดใหม่ทุกครั้งที่ข้อมูลอัปเดต
    // กับแผงเลือกวันที่สร้างครั้งเดียว ระหว่างที่ผู้ใช้กำลังพิมพ์วันที่
    // การดึงข้อมูลรอบถัดไปจะได้ไม่ลบช่องที่พิมพ์ค้างอยู่ทิ้ง
    const heroContent = el('div');
    const heroTabs = el('div', { class: 'tabbar', style: { marginTop: '14px' } });
    // ปุ่มช่วงเวลากับแผงเลือกวันต้องรู้จักกัน (เปิดอันหนึ่งต้องปิดอีกอัน)
    // จึงประกาศ compare ไว้ก่อนแล้วให้ทั้งสองอ้างถึงกันผ่านฟังก์ชัน
    const redrawHero = () => {
      renderHero(heroContent, compare);
      renderHeroTabs(heroTabs, rangePanel, compare);
    };
    const rangePanel = createRangePanel(
      () => renderHeroTabs(heroTabs, rangePanel, compare),
      () => compare.leave(),
    );
    const compare = createCompare({
      onChange: redrawHero,
      onOpen: () => rangePanel.close(),
    });
    const heroBox = el('div', { class: 'card hero-card' }, [
      heroContent,
      heroTabs,
      rangePanel.node,
      compare.node,
    ]);
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
      renderHero(heroContent, compare);
      renderHeroTabs(heroTabs, rangePanel, compare);
      compare.refreshIfStale();
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

/**
 * ปุ่มช่วงเวลา: วันนี้ / 7 วัน / 30 วัน / เลือกวัน
 * ถ้ากำลังดูช่วงที่เลือกเอง ปุ่มสุดท้ายจะบอกช่วงนั้นแทนคำว่า "เลือกวัน"
 */
function renderHeroTabs(box, rangePanel, compare) {
  const query = state.summaryQuery;
  const period = query.period ?? 'week';
  const comparing = compare.active;
  const isCustom = !comparing && period === 'custom' && query.from;

  const presets = PERIODS.map((item) =>
    el('button', {
      class: `tab small${!comparing && item.key === period ? ' active' : ''}`,
      type: 'button',
      text: item.label,
      onclick: () => {
        rangePanel.close();
        // กดช่วงสำเร็จรูป = กลับมาดูกราฟเดิม
        compare.leave();
        // ช่วงสำเร็จรูปใช้ from เป็น "วันสุดท้าย" ของช่วง ต้องล้างค่าที่เลือกเองไว้ก่อน
        loaders.summary({ period: item.key, from: null, to: null });
      },
    }),
  );

  const customLabel = isCustom
    ? query.from === query.to
      ? thaiDate(query.from)
      : `${thaiDate(query.from)} – ${thaiDate(query.to)}`
    : 'เลือกวัน';

  const customTab = el(
    'button',
    {
      class:
        `tab small${isCustom ? ' active' : ''}` +
        `${rangePanel.isOpen() ? ' open' : ''}`,
      type: 'button',
      title: 'เลือกช่วงวันที่ต้องการดูเอง',
      'aria-expanded': rangePanel.isOpen() ? 'true' : 'false',
      onclick: () => {
        compare.close();
        rangePanel.toggle();
      },
    },
    [svg(icons.calendar(14)), customLabel],
  );

  const compareTab = el(
    'button',
    {
      class:
        `tab small${comparing ? ' active' : ''}` +
        `${compare.isOpen() ? ' open' : ''}`,
      type: 'button',
      title: 'เปรียบเทียบกราฟสองวัน หรือสองช่วงวัน',
      'aria-expanded': compare.isOpen() ? 'true' : 'false',
      onclick: () => compare.toggle(),
    },
    [svg(icons.compare(14)), 'เปรียบเทียบ'],
  );

  replace(box, [...presets, customTab, compareTab]);
}

/**
 * แผงเลือกช่วงวันเอง (สร้างครั้งเดียวต่อการเปิดหน้า)
 * ช่องวันที่เป็น พ.ศ. พิมพ์ วว/ดด/ปปปป หรือกดปฏิทินก็ได้
 */
function createRangePanel(onToggle, onApply = () => {}) {
  const today = isoDate();
  const fromInput = thaiDateInput({ name: 'overview-from', max: today });
  const toInput = thaiDateInput({ name: 'overview-to', max: today });
  const message = el('div', { class: 'hero-range-msg' });

  const showError = (text) => {
    message.textContent = text;
    message.classList.add('error');
  };
  const showHint = () => {
    message.textContent =
      'พิมพ์ วว/ดด/ปปปป (พ.ศ.) หรือกดไอคอนปฏิทิน · เลือกได้สูงสุด 366 วัน';
    message.classList.remove('error');
  };

  const node = el('div', { class: 'hero-range', hidden: true }, [
    el('div', { class: 'hero-range-fields' }, [
      el('div', { class: 'hero-range-field' }, [
        el('span', { text: 'ตั้งแต่วันที่' }),
        fromInput,
      ]),
      el('div', { class: 'hero-range-field' }, [
        el('span', { text: 'ถึงวันที่' }),
        toInput,
      ]),
      el('div', { class: 'hero-range-actions' }, [
        el('button', {
          class: 'btn btn-sm',
          type: 'button',
          text: 'ยกเลิก',
          onclick: () => close(),
        }),
        el('button', {
          class: 'btn btn-sm btn-primary',
          type: 'button',
          text: 'แสดงผล',
          onclick: () => apply(),
        }),
      ]),
    ]),
    message,
  ]);

  node.addEventListener('keydown', (event) => {
    // Enter ในช่องวันที่ = กดแสดงผล (ปุ่มยังทำงานตามปกติของมัน)
    if (event.key === 'Enter' && event.target.tagName === 'INPUT') {
      event.preventDefault();
      apply();
    }
  });

  function isOpen() {
    return !node.hidden;
  }

  function open() {
    // เติมช่วงที่ดูอยู่ตอนนี้ให้ก่อน แก้แค่วันเดียวก็กดแสดงผลได้เลย
    const query = state.summaryQuery;
    const current = state.summary?.period;
    fromInput.value =
      query.period === 'custom' && query.from ? query.from : (current?.from ?? today);
    toInput.value =
      query.period === 'custom' && query.to ? query.to : (current?.to ?? today);
    showHint();
    node.hidden = false;
    onToggle();
    fromInput.focus();
  }

  function close() {
    if (node.hidden) return;
    node.hidden = true;
    onToggle();
  }

  function toggle() {
    if (isOpen()) close();
    else open();
  }

  async function apply() {
    const from = fromInput.value;
    const to = toInput.value || from;
    if (!from) {
      showError('กรุณาระบุวันที่เริ่มต้นให้ถูกต้อง เช่น 01/09/2569');
      fromInput.focus();
      return;
    }
    if (!to) {
      showError('กรุณาระบุวันที่สิ้นสุดให้ถูกต้อง');
      toInput.focus();
      return;
    }
    if (from > to) {
      showError('วันที่เริ่มต้นต้องไม่อยู่หลังวันที่สิ้นสุด');
      return;
    }
    const days =
      Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000) + 1;
    if (days > MAX_CUSTOM_DAYS) {
      showError(`เลือกได้สูงสุด ${MAX_CUSTOM_DAYS} วันต่อครั้ง (ตอนนี้เลือกไว้ ${days} วัน)`);
      return;
    }
    close();
    onApply();
    await loaders.summary({ period: 'custom', from, to });
    if (state.errors?.summary) toastError(state.errors.summary);
  }

  return { node, isOpen, open, close, toggle };
}

function renderHero(box, compare) {
  if (compare.active) {
    compare.renderHero(box);
    return;
  }
  const summary = state.summary;
  const period = state.summaryQuery.period ?? 'week';

  if (!summary) {
    replace(box, [
      el('div', { class: 'eyebrow' }, [
        svg(icons.bolt(13)),
        'พลังงานที่ใช้ · ทั้งอาคาร',
      ]),
      el('div', { class: 'empty', text: 'กำลังโหลดข้อมูลค่าไฟ…' }),
    ]);
    return;
  }

  const sameDay = summary.period.from === summary.period.to;
  const pointLabel =
    period === 'custom'
      ? (sameDay ? 'ทั้งชั่วโมง' : 'ทั้งวัน')
      : (PERIOD_LABEL[period] ?? '');

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
      sameDay
        ? `พลังงานที่ใช้ · ${thaiDate(summary.period.from)}`
        : `พลังงานที่ใช้ · ${thaiDate(summary.period.from)} ถึง ${thaiDate(summary.period.to)}`,
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
    areaChart(points, {
      height: 150,
      tipLabel: (point) => `${point.label} · ${pointLabel}`,
    }),
    el('div', { class: 'hero-facts' }, [
      el('span', {}, [
        'เวลาทำงานรวม ',
        el('b', { text: integer(summary.totals.runtimeMinutes) }),
        ' นาที',
      ]),
      el('span', {}, [
        'กำลังไฟสูงสุด ',
        el('b', { text: decimal(summary.totals.peakPowerWatts, 1) }),
        ' W',
      ]),
      el('span', {}, [
        'มีข้อมูลจาก ',
        el('b', { text: integer(summary.totals.deviceCount) }),
        ' เครื่อง',
      ]),
    ]),
  ]);
}

// ------------------------------------------------------------ ตัวเลขสี่ช่อง

/**
 * การ์ดตัวเลขเล็ก กดแล้วพาไปหน้าที่ดูรายละเอียดของตัวเลขนั้นได้
 * ป้ายชื่ออยู่บนสุดคู่กับไอคอน คนจะรู้ก่อนว่ากำลังดูอะไร แล้วค่อยเห็นตัวเลข
 */
function statMini(iconMarkup, tone, value, suffix, label, target) {
  const iconBox = el('div', {
    class: 'stat-mini-icon',
    style: { background: tone.background, color: tone.color },
  });
  iconBox.innerHTML = iconMarkup;
  const valueNode = el('div', { class: 'stat-mini-val', text: value });
  if (suffix) valueNode.appendChild(el('small', { text: ` ${suffix}` }));
  return el(
    target ? 'button' : 'div',
    {
      class: 'stat-mini',
      type: target ? 'button' : null,
      title: target ? 'ดูรายละเอียด' : null,
      onclick: target
        ? () => {
            window.location.hash = `#/${target}`;
          }
        : null,
    },
    [
      el('div', { class: 'stat-mini-head' }, [
        iconBox,
        el('div', { class: 'stat-mini-label', text: label }),
      ]),
      valueNode,
      target ? el('div', { class: 'stat-mini-foot', text: 'ดูรายละเอียด ›' }) : null,
    ],
  );
}

function renderStats(box) {
  const totals = state.live.totals;
  const openAlerts = Number(state.alerts.counts?.open ?? 0);
  const accent = { background: 'var(--accent-soft)', color: 'var(--accent)' };
  const warn = { background: 'var(--warn-soft)', color: 'var(--warn)' };
  const neutral = {
    background: 'var(--neutral-soft)',
    color: 'var(--text-hi)',
  };
  const isAdmin = state.user?.role === 'admin';

  replace(box, [
    statMini(
      icons.pulseLine(15),
      accent,
      totals ? String(totals.running) : '—',
      totals ? `/ ${totals.devices}` : '',
      'เครื่องปรับอากาศทำงานอยู่',
      'rooms',
    ),
    statMini(
      icons.warning(15),
      openAlerts > 0 ? warn : neutral,
      String(openAlerts),
      '',
      'แจ้งเตือนรอดำเนินการ',
      'alerts',
    ),
    statMini(
      icons.board(15),
      accent,
      totals ? String(totals.online) : '—',
      totals ? `/ ${totals.devices}` : '',
      'ESP32 ออนไลน์',
      isAdmin ? 'devices' : null,
    ),
    statMini(
      icons.clock(15),
      neutral,
      decimal(state.settings.electricityRate, 2),
      '',
      'อัตราค่าไฟ (บาท/kWh)',
      'rates',
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
      el('span', { class: 'legend-live', text: 'แอร์ทำงานอยู่' }),
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
              class: `pulse-cell${hasUnits ? '' : ' vacant'}`,
              type: 'button',
              style: {
                background: hasUnits ? heatColor(kwh, max) : null,
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

  const more = alerts.length - shown.length;
  replace(box, [
    head,
    ...shown.map((alert) => alertRow(alert)),
    el('div', { class: 'card-link' }, [
      el('button', {
        class: 'btn btn-sm',
        type: 'button',
        text: more > 0 ? `ดูทั้งหมด (อีก ${more} รายการ)` : 'ไปหน้าการแจ้งเตือน',
        onclick: () => {
          window.location.hash = '#/alerts';
        },
      }),
    ]),
  ]);
}

export function alertRow(alert, { onChanged = null } = {}) {
  const described = describeAlert(alert);
  const tone =
    alert.status === 'open'
      ? 'pending'
      : alert.status === 'acknowledged'
        ? 'ack'
        : 'done';

  const actions = el('div', { class: 'row alert-actions', style: { gap: '8px' } }, [
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
          class: 'who',
          text: `โดย ${alert.acknowledgedBy}`,
        })
      : null,
  ]);

  return el('div', { class: 'alert-item' }, [
    el('div', { class: `alert-bar ${tone}` }),
    el('div', { class: 'alert-body' }, [
      el('div', { class: 'alert-top' }, [
        el('div', { class: 'alert-room', text: described.title }),
        el('div', {
          class: 'alert-time',
          text: relativeTime(alert.createdAt),
          title: alert.createdAt ? new Date(alert.createdAt).toLocaleString('th-TH') : null,
        }),
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
      class: 'rank-foot',
      text:
        `5 ห้องนี้กินไฟรวม ${energy(
          top.reduce((sum, row) => sum + Number(row.kwh || 0), 0),
          { scaleReference: reference },
        )} ` +
        `จากทั้งหมด ${energy(totalKwh)}`,
    }),
  ]);
}
