/**
 * โหมดเปรียบเทียบของการ์ดใหญ่ในหน้าภาพรวม
 *
 * เทียบได้สองแบบ
 *   - วันชนวัน    เช่น วันนี้กับเมื่อวาน เทียบทีละชั่วโมง
 *   - ช่วงชนช่วง  เช่น 7 วันนี้กับ 7 วันก่อน เทียบทีละวัน (วันที่ 1 กับวันที่ 1)
 *
 * ใช้ /energy/summary เดิมของ Backend เรียกสองครั้งคู่ขนาน ชุดละหนึ่งช่วง
 * จึงไม่ต้องแก้ Backend ผลลัพธ์เก็บไว้ในไฟล์นี้เอง ไม่ปนกับ state.summary
 * ที่หน้าอื่นและ Building Pulse ใช้ ออกจากโหมดนี้แล้วกราฟเดิมกลับมาทันที
 *
 * ชุด A คือช่วงหลัก (เส้นทึบสีเขียว) ชุด B คือช่วงที่เอามาเทียบ (เส้นประสีฟ้า)
 */

import { api } from '../api.js';
import { compareChart } from '../charts.js';
import { el, replace, svg } from '../dom.js';
import { baht, decimal, energy, integer, isoDate, shiftDays, thaiDate } from '../format.js';
import { icons } from '../icons.js';
import { thaiDateInput } from '../thai-date-input.js';
import { state } from '../store.js';

const MAX_DAYS = 366;
const STALE_MS = 60_000;

const COLOR_A = 'var(--accent)';
const COLOR_B = 'var(--info)';

const pad2 = (value) => String(value).padStart(2, '0');

function daysBetween(from, to) {
  return Math.round((Date.parse(`${to}T00:00:00Z`) - Date.parse(`${from}T00:00:00Z`)) / 86400000) + 1;
}

function describeRange(range) {
  return range.from === range.to
    ? thaiDate(range.from)
    : `${thaiDate(range.from)} – ${thaiDate(range.to)}`;
}

/**
 * @param {{ onChange: () => void, onOpen?: () => void }} options
 *   onChange  เรียกเมื่อต้องวาดการ์ดใหม่ (เริ่มโหลด โหลดเสร็จ ออกจากโหมด)
 *   onOpen    เรียกก่อนเปิดแผงเลือก ให้แผงอื่นปิดตัวเอง
 */
export function createCompare({ onChange, onOpen = () => {} }) {
  const today = () => state.today ?? isoDate();

  let active = false;
  let mode = 'day';
  let rangeA = null;
  let rangeB = null;
  let data = null;
  let loading = false;
  let error = '';
  let fetchedAt = 0;
  let fetchSeq = 0;

  // ---------------------------------------------------------------- แผงเลือก

  const max = isoDate();
  const inputs = {
    dayA: thaiDateInput({ name: 'cmp-day-a', max }),
    dayB: thaiDateInput({ name: 'cmp-day-b', max }),
    aFrom: thaiDateInput({ name: 'cmp-a-from', max }),
    aTo: thaiDateInput({ name: 'cmp-a-to', max }),
    bFrom: thaiDateInput({ name: 'cmp-b-from', max }),
    bTo: thaiDateInput({ name: 'cmp-b-to', max }),
  };
  const message = el('div', { class: 'hero-range-msg' });
  const modeTabs = el('div', { class: 'tabbar compare-modes' });
  const quick = el('div', { class: 'compare-quick' });

  const field = (label, input, color) =>
    el('div', { class: 'hero-range-field' }, [
      el('span', {}, [el('i', { class: 'cmp-swatch', style: { background: color } }), label]),
      input,
    ]);

  const dayFields = el('div', { class: 'hero-range-fields' }, [
    field('วัน A (หลัก)', inputs.dayA, COLOR_A),
    field('วัน B (ที่เอามาเทียบ)', inputs.dayB, COLOR_B),
  ]);
  const rangeFields = el('div', { class: 'compare-range-groups' }, [
    el('div', { class: 'hero-range-fields' }, [
      field('ช่วง A ตั้งแต่', inputs.aFrom, COLOR_A),
      field('ถึง', inputs.aTo, COLOR_A),
    ]),
    el('div', { class: 'hero-range-fields' }, [
      field('ช่วง B ตั้งแต่', inputs.bFrom, COLOR_B),
      field('ถึง', inputs.bTo, COLOR_B),
    ]),
  ]);

  const panel = el('div', { class: 'hero-range compare-panel', hidden: true }, [
    modeTabs,
    quick,
    dayFields,
    rangeFields,
    el('div', { class: 'hero-range-actions compare-actions' }, [
      el('button', {
        class: 'btn btn-sm',
        type: 'button',
        text: 'ยกเลิก',
        onclick: () => close(),
      }),
      el('button', {
        class: 'btn btn-sm btn-primary',
        type: 'button',
        text: 'เปรียบเทียบ',
        onclick: () => apply(),
      }),
    ]),
    message,
  ]);

  panel.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && event.target.tagName === 'INPUT') {
      event.preventDefault();
      apply();
    }
  });

  const hint = () => {
    message.textContent =
      mode === 'day'
        ? 'เลือกสองวันที่ต้องการเทียบ ระบบเทียบทีละชั่วโมง'
        : `เลือกสองช่วงวันที่ เทียบทีละวัน (วันที่ 1 กับวันที่ 1) · ช่วงละไม่เกิน ${MAX_DAYS} วัน`;
    message.classList.remove('error');
  };
  const fail = (text) => {
    message.textContent = text;
    message.classList.add('error');
  };

  function setMode(next) {
    mode = next;
    dayFields.hidden = next !== 'day';
    rangeFields.hidden = next !== 'range';
    drawModeTabs();
    drawQuick();
    hint();
  }

  function drawModeTabs() {
    replace(
      modeTabs,
      [
        ['day', 'วันชนวัน'],
        ['range', 'ช่วงชนช่วง'],
      ].map(([key, label]) =>
        el('button', {
          class: `tab small${mode === key ? ' active' : ''}`,
          type: 'button',
          text: label,
          onclick: () => setMode(key),
        }),
      ),
    );
  }

  /** ปุ่มลัด: กดแล้วเติมวันที่และเปรียบเทียบเลย */
  function drawQuick() {
    const now = today();
    const presets =
      mode === 'day'
        ? [
            ['วันนี้ เทียบ เมื่อวาน', { a: [now, now], b: [shiftDays(now, -1), shiftDays(now, -1)] }],
            ['วันนี้ เทียบ วันเดียวกันของสัปดาห์ก่อน', { a: [now, now], b: [shiftDays(now, -7), shiftDays(now, -7)] }],
          ]
        : [
            ['7 วันล่าสุด เทียบ 7 วันก่อนหน้า', { a: [shiftDays(now, -6), now], b: [shiftDays(now, -13), shiftDays(now, -7)] }],
            ['30 วันล่าสุด เทียบ 30 วันก่อนหน้า', { a: [shiftDays(now, -29), now], b: [shiftDays(now, -59), shiftDays(now, -30)] }],
          ];
    replace(
      quick,
      [
        el('span', { class: 'compare-quick-label', text: 'ทางลัด' }),
        ...presets.map(([label, value]) =>
          el('button', {
            class: 'btn btn-sm',
            type: 'button',
            text: label,
            onclick: () => {
              fillInputs(value.a, value.b);
              apply();
            },
          }),
        ),
      ],
    );
  }

  function fillInputs(a, b) {
    inputs.dayA.value = a[0];
    inputs.dayB.value = b[0];
    inputs.aFrom.value = a[0];
    inputs.aTo.value = a[1];
    inputs.bFrom.value = b[0];
    inputs.bTo.value = b[1];
  }

  /** เปิดแผง: ถ้ากำลังเทียบอยู่ เติมค่าที่ใช้อยู่ให้แก้ต่อได้ ไม่งั้นเริ่มจากวันนี้กับเมื่อวาน */
  function open() {
    onOpen();
    if (active && rangeA && rangeB) {
      fillInputs([rangeA.from, rangeA.to], [rangeB.from, rangeB.to]);
      setMode(mode);
    } else {
      const now = today();
      fillInputs([now, now], [shiftDays(now, -1), shiftDays(now, -1)]);
      setMode(mode);
    }
    panel.hidden = false;
    onChange();
  }

  function close() {
    if (panel.hidden) return;
    panel.hidden = true;
    onChange();
  }

  const isOpen = () => !panel.hidden;
  const toggle = () => (isOpen() ? close() : open());

  function readRanges() {
    if (mode === 'day') {
      return {
        a: { from: inputs.dayA.value, to: inputs.dayA.value },
        b: { from: inputs.dayB.value, to: inputs.dayB.value },
      };
    }
    return {
      a: { from: inputs.aFrom.value, to: inputs.aTo.value || inputs.aFrom.value },
      b: { from: inputs.bFrom.value, to: inputs.bTo.value || inputs.bFrom.value },
    };
  }

  function validate({ a, b }) {
    const names = mode === 'day' ? [['วัน A', a], ['วัน B', b]] : [['ช่วง A', a], ['ช่วง B', b]];
    for (const [name, range] of names) {
      if (!range.from || !range.to) return `กรุณาระบุวันที่ของ${name}ให้ถูกต้อง เช่น 01/09/2569`;
      if (range.from > range.to) return `${name}: วันที่เริ่มต้นต้องไม่อยู่หลังวันที่สิ้นสุด`;
      if (range.to > max) return `${name}: เลือกวันในอนาคตไม่ได้`;
      const days = daysBetween(range.from, range.to);
      if (days > MAX_DAYS) return `${name}: เลือกได้สูงสุด ${MAX_DAYS} วัน (ตอนนี้ ${days} วัน)`;
    }
    if (mode === 'range') {
      const la = daysBetween(a.from, a.to);
      const lb = daysBetween(b.from, b.to);
      // วันเดียวแสดงเป็นรายชั่วโมง หลายวันแสดงเป็นรายวัน สองแบบซ้อนกันไม่ได้
      if ((la === 1) !== (lb === 1)) {
        return 'ช่วง A และ B ต้องยาวมากกว่า 1 วันทั้งคู่ หรือเป็น 1 วันทั้งคู่ (ถ้าเทียบวันเดียวให้ใช้ "วันชนวัน")';
      }
    }
    return '';
  }

  function apply() {
    const ranges = readRanges();
    const problem = validate(ranges);
    if (problem) {
      fail(problem);
      return;
    }
    rangeA = ranges.a;
    rangeB = ranges.b;
    active = true;
    data = null;
    panel.hidden = true;
    fetchBoth();
  }

  // ------------------------------------------------------------- ดึงข้อมูล

  async function fetchBoth({ silent = false } = {}) {
    const seq = (fetchSeq += 1);
    if (!silent) {
      loading = true;
      error = '';
      onChange();
    }
    try {
      const floor = state.summaryQuery?.floor ?? null;
      const [a, b] = await Promise.all(
        [rangeA, rangeB].map((range) =>
          api.energySummary({ period: 'custom', from: range.from, to: range.to, floor }),
        ),
      );
      if (seq !== fetchSeq || !active) return;
      data = { a, b };
      error = '';
      fetchedAt = Date.now();
    } catch (failure) {
      if (seq !== fetchSeq || !active) return;
      if (!silent || !data) error = failure?.message || 'โหลดข้อมูลเปรียบเทียบไม่สำเร็จ';
    } finally {
      if (seq === fetchSeq) {
        loading = false;
        onChange();
      }
    }
  }

  /** ช่วงที่รวมวันนี้ยังเปลี่ยนอยู่ ดึงใหม่เป็นระยะ ช่วงที่จบไปแล้วไม่ต้อง */
  function refreshIfStale() {
    if (!active || loading || !rangeA || !rangeB || !data) return;
    if (Date.now() - fetchedAt < STALE_MS) return;
    const now = today();
    if (rangeA.to < now && rangeB.to < now) return;
    fetchBoth({ silent: true });
  }

  /** กลับไปกราฟเดิม (ไม่วาดซ้ำ ผู้เรียกวาดเอง) */
  function leave() {
    active = false;
    data = null;
    error = '';
    loading = false;
    fetchSeq += 1;
    if (!panel.hidden) panel.hidden = true;
  }

  function exit() {
    leave();
    onChange();
  }

  // ----------------------------------------------------------------- วาดการ์ด

  function renderHero(box) {
    const exitButton = el(
      'button',
      {
        class: 'btn btn-sm compare-exit',
        type: 'button',
        title: 'ปิดโหมดเปรียบเทียบ กลับไปดูกราฟเดิม',
        onclick: () => exit(),
      },
      ['← กลับกราฟเดิม'],
    );
    const eyebrow = el('div', { class: 'compare-head' }, [
      el('div', { class: 'eyebrow' }, [
        svg(icons.compare(13)),
        `เปรียบเทียบการใช้ไฟ · ${mode === 'day' ? 'วันชนวัน' : 'ช่วงชนช่วง'}`,
      ]),
      exitButton,
    ]);

    if (error) {
      replace(box, [
        eyebrow,
        el('div', { class: 'empty', text: error }),
        el('div', { class: 'compare-retry' }, [
          el('button', {
            class: 'btn btn-sm btn-primary',
            type: 'button',
            text: 'ลองใหม่',
            onclick: () => fetchBoth(),
          }),
        ]),
      ]);
      return;
    }
    if (!data) {
      replace(box, [eyebrow, el('div', { class: 'empty', text: 'กำลังโหลดข้อมูลเปรียบเทียบ…' })]);
      return;
    }

    const rate = state.settings.electricityRate;
    const { a, b } = data;
    const kwhA = Number(a.totals.kwh) || 0;
    const kwhB = Number(b.totals.kwh) || 0;
    const hourly = a.period.granularity === 'hour';
    const daysA = a.period.days;
    const daysB = b.period.days;

    const figure = (key, color, summary, kwh) =>
      el('div', { class: 'cmp-figure' }, [
        el('div', { class: 'cmp-figure-head' }, [
          el('i', { class: 'cmp-swatch', style: { background: color } }),
          el('b', { text: key }),
          el('span', { text: describeRange(summary.period) }),
        ]),
        el('div', { class: 'cmp-figure-num' }, [
          el('span', { class: 'cmp-num', text: decimal(kwh, 1) }),
          el('span', { class: 'cmp-unit', text: 'kWh' }),
        ]),
        el('div', { class: 'cmp-figure-cost', text: `≈ ${baht(kwh * rate)}` }),
      ]);

    // A เทียบกับ B: ลบแล้วหารด้วย B ถ้า B ไม่มีข้อมูลเลยเทียบเป็นเปอร์เซ็นต์ไม่ได้
    let diffClass = 'flat';
    let diffText = 'B ไม่มีข้อมูลการใช้ไฟ จึงเทียบเป็นเปอร์เซ็นต์ไม่ได้';
    if (kwhB > 0 && Math.abs(kwhA - kwhB) / kwhB < 0.0005) {
      diffText = 'A และ B ใช้ไฟเท่ากัน';
    } else if (kwhB > 0) {
      const delta = kwhA - kwhB;
      const percent = (delta / kwhB) * 100;
      const lower = delta <= 0;
      diffClass = lower ? '' : 'up';
      diffText =
        `${lower ? '↓ A ใช้น้อยกว่า B' : '↑ A ใช้มากกว่า B'} ${decimal(Math.abs(percent), 1)}% ` +
        `(ต่างกัน ${energy(Math.abs(delta))} ≈ ${baht(Math.abs(delta) * rate)})`;
    }

    const pointsOf = (summary) =>
      (summary.series ?? []).map((point) => ({
        label: point.label,
        value: point.kwh,
        tip: thaiDate(point.date),
      }));
    const seriesA = pointsOf(a);
    const seriesB = pointsOf(b);
    const axisLabels = hourly
      ? seriesA.map((point) => point.label)
      : Array.from({ length: Math.max(seriesA.length, seriesB.length) }, (_, index) => `วันที่ ${index + 1}`);

    const chart = compareChart(
      [
        { name: 'A', color: COLOR_A, fill: true, points: seriesA },
        { name: 'B', color: COLOR_B, dashed: true, points: seriesB },
      ],
      {
        height: 190,
        axisLabels,
        headOf: (index) => (hourly ? `${pad2(index)}:00 น.` : `วันที่ ${index + 1} ของแต่ละช่วง`),
      },
    );

    // ชื่อชุดในกล่องค่าที่ชี้ ใส่วันที่จริงเข้าไปด้วย จะได้ไม่ต้องจำว่า A คือวันไหน
    for (const [series, label] of [[seriesA, 'A'], [seriesB, 'B']]) {
      for (const point of series) point.tip = `${label} · ${point.tip}`;
    }

    const row = (label, valueA, valueB) =>
      el('div', { class: 'cmp-row' }, [
        el('span', { class: 'cmp-row-label', text: label }),
        el('b', { text: valueA }),
        el('b', { text: valueB }),
      ]);
    const rows = [
      row('เวลาทำงานรวม', `${integer(a.totals.runtimeMinutes)} นาที`, `${integer(b.totals.runtimeMinutes)} นาที`),
      row('กำลังไฟสูงสุด', `${decimal(a.totals.peakPowerWatts, 1)} W`, `${decimal(b.totals.peakPowerWatts, 1)} W`),
      row('เครื่องที่มีข้อมูล', `${integer(a.totals.deviceCount)} เครื่อง`, `${integer(b.totals.deviceCount)} เครื่อง`),
    ];
    if (!hourly) {
      rows.unshift(
        row('ความยาวช่วง', `${integer(daysA)} วัน`, `${integer(daysB)} วัน`),
        row('เฉลี่ยต่อวัน', energy(kwhA / daysA), energy(kwhB / daysB)),
      );
    }

    replace(box, [
      eyebrow,
      el('div', { class: 'cmp-figures' }, [
        figure('A', COLOR_A, a, kwhA),
        figure('B', COLOR_B, b, kwhB),
      ]),
      el('div', { class: 'hero-meta' }, [
        el('div', { class: `trend-chip ${diffClass}`, text: diffText }),
        el('div', { class: 'cost-chip', text: `อัตรา ${decimal(rate, 2)} บาท/kWh` }),
      ]),
      !hourly && daysA !== daysB
        ? el('div', {
            class: 'compare-note',
            text: `สองช่วงยาวไม่เท่ากัน (A ${daysA} วัน · B ${daysB} วัน) ยอดรวมจึงไม่ยุติธรรมนัก ดูแถว "เฉลี่ยต่อวัน" ประกอบ`,
          })
        : null,
      chart,
      el('div', { class: 'cmp-table' }, [
        el('div', { class: 'cmp-row cmp-row-head' }, [
          el('span'),
          el('b', { text: 'A', style: { color: COLOR_A } }),
          el('b', { text: 'B', style: { color: COLOR_B } }),
        ]),
        ...rows,
      ]),
    ]);
  }

  setMode('day');

  return {
    node: panel,
    get active() {
      return active;
    },
    isOpen,
    open,
    close,
    toggle,
    leave,
    exit,
    renderHero,
    refreshIfStale,
  };
}
