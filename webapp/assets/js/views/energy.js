/**
 * หน้าข้อมูลไฟฟ้าแบบละเอียด
 *
 * นี่คือหน้าที่เว็บทำได้ดีกว่าแอปมือถืออย่างชัดเจน เพราะจอกว้างพอจะวางตาราง
 * ที่มีสิบกว่าคอลัมน์พร้อมกัน และเลือกเครื่องทีละหลายตัวได้โดยไม่ต้องเลื่อน
 *
 * รายการค่าไฟที่เลือกได้ (METRIC_CATALOG) ดึงมาจาก Backend ไม่ได้เขียนตายไว้
 * ในหน้านี้ เพิ่มค่าใหม่ที่ Backend ที่เดียวแล้วช่องติ๊กจะขึ้นเองทั้งบนเว็บ
 * และบนแอป
 */

import { api } from '../api.js';
import { areaChart } from '../charts.js';
import { el, replace, svg } from '../dom.js';
import {
  baht,
  decimal,
  energy,
  floorLabel,
  integer,
  isoDate,
  shiftDays,
} from '../format.js';
import { icons } from '../icons.js';
import { defaultHistoryRange, loaders, state } from '../store.js';
import { toastError, toastInfo, toastOk } from '../ui.js';

const SCOPES = [
  { key: 'building', label: 'รวมทั้งอาคาร' },
  { key: 'room', label: 'แยกรายห้อง' },
  { key: 'device', label: 'แยกรายเครื่อง' },
];

const PRESETS = [
  { label: 'วันนี้', days: 0 },
  { label: '7 วัน', days: 6 },
  { label: '30 วัน', days: 29 },
  { label: '90 วัน', days: 89 },
];

/** เก็บค่าที่ผู้ใช้เลือกไว้ข้ามการสลับหน้า จะได้ไม่ต้องตั้งใหม่ทุกครั้ง */
const filters = {
  scope: 'building',
  detail: 'high',
  ...defaultHistoryRange(),
  rooms: [],
  devices: [],
  metrics: null,
  language: 'th',
};

let sources = null;
let result = null;
let busy = false;

export default {
  title: 'ข้อมูลไฟฟ้า',
  subtitle: 'ดูย้อนหลังรายชั่วโมง เลือกค่าที่ต้องการ แล้วส่งออกเป็น Excel',

  async mount(root) {
    const filterBox = el('div', { class: 'card' });
    const chartBox = el('div', { class: 'card', style: { marginTop: '16px' } });
    const tableBox = el('div', { style: { marginTop: '16px' } });

    replace(root, [filterBox, chartBox, tableBox]);

    const drawAll = () => {
      renderFilters(filterBox, run);
      renderChart(chartBox);
      renderTable(tableBox);
    };

    async function run() {
      if (busy) return;
      busy = true;
      drawAll();
      try {
        result = await api.energyHistory(queryFromFilters());
      } catch (error) {
        result = null;
        toastError(error.message);
      } finally {
        busy = false;
        drawAll();
      }
    }

    drawAll();

    // โหลดรายการค่าไฟและรายชื่ออุปกรณ์ควบคู่กัน แล้วค่อยดึงข้อมูลชุดแรก
    const [catalog, sourceList] = await Promise.all([
      loaders.metricCatalog(),
      api.energySources().catch(() => null),
    ]);
    if (catalog && filters.metrics == null) {
      filters.metrics = [...catalog.defaults];
    }
    sources = sourceList;
    drawAll();
    await run();

    return { update: () => renderFilters(filterBox, run) };
  },
};

function queryFromFilters() {
  return {
    scope: filters.scope,
    detail: filters.detail,
    from: filters.from,
    to: filters.to,
    rooms: filters.scope === 'building' ? null : filters.rooms,
    devices: filters.scope === 'device' ? filters.devices : null,
    metrics: filters.metrics ?? null,
    rate: state.settings.electricityRate,
  };
}

// ------------------------------------------------------------ ส่วนตัวกรอง

function renderFilters(box, run) {
  const catalog = state.metricCatalog;
  const allowed = (catalog?.metrics ?? []).filter(
    (metric) => filters.detail === 'high' || !metric.detailOnly,
  );

  const scopeTabs = el(
    'div',
    { class: 'tabbar' },
    SCOPES.map((scope) =>
      el('button', {
        class: `tab small${scope.key === filters.scope ? ' active' : ''}`,
        type: 'button',
        text: scope.label,
        onclick: () => {
          filters.scope = scope.key;
          run();
        },
      }),
    ),
  );

  const presetTabs = el(
    'div',
    { class: 'tabbar' },
    PRESETS.map((preset) =>
      el('button', {
        class: 'tab small',
        type: 'button',
        text: preset.label,
        onclick: () => {
          const today = isoDate();
          filters.to = today;
          filters.from = shiftDays(today, -preset.days);
          run();
        },
      }),
    ),
  );

  const fromInput = el('input', {
    type: 'date',
    value: filters.from,
    onchange: (event) => {
      filters.from = event.target.value;
    },
  });
  const toInput = el('input', {
    type: 'date',
    value: filters.to,
    onchange: (event) => {
      filters.to = event.target.value;
    },
  });

  const roomSelect = multiSelect(
    'เลือกห้อง (ว่าง = ทุกห้อง)',
    (sources?.rooms ?? []).map((room) => ({
      value: room.roomNumber,
      label: `${room.roomNumber} · ${floorLabel(room.floorNumber)}`,
    })),
    filters.rooms,
    (values) => {
      filters.rooms = values;
    },
  );

  const deviceSelect = multiSelect(
    'เลือกเครื่อง (ว่าง = ทุกเครื่อง)',
    (sources?.devices ?? []).map((device) => ({
      value: device.deviceId,
      label:
        `${device.roomNumber} · ${device.name}` +
        (device.archived ? ' (ถอดออกแล้ว)' : ''),
    })),
    filters.devices,
    (values) => {
      filters.devices = values;
    },
  );

  const metricChips = el(
    'div',
    { class: 'metric-picker' },
    allowed.map((metric) => {
      const selected = (filters.metrics ?? []).includes(metric.key);
      const label = el('label', {
        class: `checkbox-chip${selected ? ' sel' : ''}`,
        title: metric.unit ? `หน่วย: ${metric.unit}` : '',
      });
      const input = el('input', {
        type: 'checkbox',
        checked: selected,
        onchange: () => {
          const current = new Set(filters.metrics ?? []);
          if (current.has(metric.key)) current.delete(metric.key);
          else current.add(metric.key);
          // เรียงตามลำดับแคตตาล็อกเสมอ คอลัมน์จะได้ไม่สลับที่ทุกครั้งที่ติ๊ก
          filters.metrics = (catalog?.metrics ?? [])
            .map((item) => item.key)
            .filter((key) => current.has(key));
          run();
        },
      });
      label.appendChild(input);
      label.appendChild(
        document.createTextNode(
          metric.unit ? `${metric.labelTh} (${metric.unit})` : metric.labelTh,
        ),
      );
      return label;
    }),
  );

  const coverage = sources?.coverage;

  replace(box, [
    el('div', { class: 'panel-title' }, [
      'ตัวกรองข้อมูล',
      coverage?.oldest
        ? el('span', {
            class: 'count-badge',
            text: `มีข้อมูล ${coverage.oldest} ถึง ${coverage.newest}`,
          })
        : null,
    ]),
    el('div', { class: 'filter-grid' }, [
      el('div', { class: 'field' }, [
        el('label', { text: 'ระดับการแยกข้อมูล' }),
        scopeTabs,
      ]),
      el('div', { class: 'field' }, [
        el('label', { text: 'ช่วงวันสำเร็จรูป' }),
        presetTabs,
      ]),
      el('div', { class: 'field' }, [
        el('label', { text: 'ตั้งแต่วันที่' }),
        fromInput,
      ]),
      el('div', { class: 'field' }, [el('label', { text: 'ถึงวันที่' }), toInput]),
      el('div', { class: 'field' }, [
        el('label', { text: 'ความละเอียดของค่า' }),
        el(
          'select',
          {
            onchange: (event) => {
              filters.detail = event.target.value;
              run();
            },
          },
          [
            el('option', {
              value: 'summary',
              text: 'ย่อ — เฉพาะค่าหลัก',
              selected: filters.detail === 'summary',
            }),
            el('option', {
              value: 'high',
              text: 'ละเอียด — ทุกค่าที่มี',
              selected: filters.detail === 'high',
            }),
          ],
        ),
      ]),
      el('div', { class: 'field' }, [
        el('label', { text: 'ภาษาของไฟล์ Excel' }),
        el(
          'select',
          {
            onchange: (event) => {
              filters.language = event.target.value;
            },
          },
          [
            el('option', {
              value: 'th',
              text: 'ไทย',
              selected: filters.language === 'th',
            }),
            el('option', {
              value: 'en',
              text: 'English',
              selected: filters.language === 'en',
            }),
          ],
        ),
      ]),
    ]),
    filters.scope !== 'building' ? roomSelect : null,
    filters.scope === 'device' ? deviceSelect : null,
    el('div', { class: 'field' }, [
      el('label', { text: 'ค่าที่ต้องการดู' }),
      metricChips,
      el('div', {
        class: 'hint',
        text:
          'ค่าที่มีเครื่องหมายว่า "เฉพาะแบบละเอียด" จะถูกซ่อนในโหมดย่อ ' +
          'เพราะค่าอย่างแรงดันต่ำสุดของทั้งอาคารไม่ได้บอกว่าเป็นของเครื่องไหน',
      }),
    ]),
    el('div', { class: 'row', style: { marginTop: '6px' } }, [
      el(
        'button',
        {
          class: 'btn btn-primary',
          type: 'button',
          disabled: busy,
          onclick: run,
        },
        [svg(icons.refresh(15)), busy ? 'กำลังดึงข้อมูล…' : 'แสดงข้อมูล'],
      ),
      el(
        'button',
        {
          class: 'btn',
          type: 'button',
          onclick: (event) => downloadExcel(event.currentTarget),
        },
        [svg(icons.download(15)), 'ส่งออกเป็น Excel'],
      ),
      el('span', {
        class: 'dim',
        style: { fontSize: '11.5px' },
        text: `คิดค่าไฟที่อัตรา ${decimal(
          state.settings.electricityRate,
          2,
        )} บาท/kWh (แก้ได้ที่หน้าอัตราค่าไฟ)`,
      }),
    ]),
  ]);
}

function multiSelect(label, options, selected, onChange) {
  const box = el('select', {
    multiple: true,
    size: Math.min(8, Math.max(3, options.length)),
    style: { minHeight: '92px' },
    onchange: (event) => {
      onChange(
        [...event.target.selectedOptions].map((option) => option.value),
      );
    },
  });
  for (const option of options) {
    box.appendChild(
      el('option', {
        value: option.value,
        text: option.label,
        selected: selected.includes(option.value),
      }),
    );
  }
  return el('div', { class: 'field' }, [
    el('label', { text: label }),
    options.length === 0
      ? el('div', { class: 'hint', text: 'ยังไม่มีข้อมูลให้เลือก' })
      : box,
    el('div', {
      class: 'hint',
      text: 'กด Ctrl หรือ Shift ค้างไว้เพื่อเลือกหลายรายการ',
    }),
  ]);
}

// -------------------------------------------------------------- กราฟและตาราง

function renderChart(box) {
  if (!result || result.rows.length === 0) {
    box.hidden = true;
    return;
  }
  const firstMetric = result.query.metrics[0];
  const column = result.columns.find((item) => item.key === firstMetric);
  if (!column) {
    box.hidden = true;
    return;
  }

  // โหมดรายห้อง/รายเครื่องมีหลายแถวต่อหนึ่งช่วงเวลา ต้องยุบให้เหลือจุดเดียว
  // แต่ยุบด้วยวิธีไหนขึ้นกับว่าค่านั้นเป็น "ปริมาณ" หรือ "สภาพของระบบไฟ"
  const mode = combineMode(column);
  const byBucket = new Map();
  for (const row of result.rows) {
    const key = `${row.date} ${row.time}`;
    const value = Number(row.values[firstMetric]);
    if (!Number.isFinite(value)) continue;
    if (!byBucket.has(key)) byBucket.set(key, []);
    byBucket.get(key).push(value);
  }

  // เรียงตามเวลาเสมอ ไม่เชื่อลำดับที่ฐานข้อมูลส่งมา
  // คีย์เป็น 'YYYY-MM-DD HH:mm-HH:mm' จึงเรียงแบบข้อความได้ตรงกับเรียงตามเวลา
  const points = [...byBucket.entries()]
    .sort((a, b) => a[0].localeCompare(b[0]))
    .map(([key, values]) => ({
      label: key.slice(5, 10),
      value: combine(values, mode),
    }));

  box.hidden = false;
  replace(box, [
    el('div', { class: 'panel-title' }, [
      `กราฟ${column.labelTh}${column.unit ? ` (${column.unit})` : ''}`,
      el('span', {
        class: 'count-badge',
        text: `${points.length} ช่วงเวลา · ${COMBINE_LABEL[mode]}`,
      }),
    ]),
    areaChart(points, {
      height: 200,
      unitOverride: column.unit || '',
    }),
  ]);
}

const COMBINE_LABEL = {
  sum: 'รวมทุกห้อง',
  avg: 'เฉลี่ยทุกห้อง',
  min: 'ต่ำสุดของทุกห้อง',
  max: 'สูงสุดของทุกห้อง',
};

/**
 * ยุบหลายแถวในช่วงเวลาเดียวกันให้เหลือจุดเดียวบนกราฟอย่างไร
 *
 * กติกาเดียวกับที่ Backend ใช้คิดยอดรวม (ดู utils/energy-history.js):
 * ค่าที่เป็นปริมาณ (kWh, W, A, บาท, นาที) บวกกันได้ ส่วนค่าที่เป็นสภาพของ
 * ระบบไฟ (แรงดัน ความถี่ ตัวประกอบกำลัง) บวกกันไม่ได้ — 220V กับ 221V
 * รวมกันไม่ใช่ 441V ต้องเฉลี่ย
 *
 * ค่าที่ลงท้ายด้วย Min/Max ใช้ค่าต่ำสุด/สูงสุดของทั้งชุด เพราะ "แรงดันต่ำสุด
 * ของอาคาร" คือค่าที่ต่ำที่สุดในบรรดาทุกห้อง ไม่ใช่ผลบวกของค่าต่ำสุดรายห้อง
 */
function combineMode(column) {
  if (column.key.endsWith('Min')) return 'min';
  if (column.key.endsWith('Max')) return 'max';
  if (column.unit === 'V' || column.unit === 'Hz') return 'avg';
  if (column.key === 'powerFactorAvg') return 'avg';
  return 'sum';
}

function combine(values, mode) {
  if (values.length === 0) return 0;
  if (mode === 'min') return Math.min(...values);
  if (mode === 'max') return Math.max(...values);
  const total = values.reduce((sum, value) => sum + value, 0);
  return mode === 'avg' ? total / values.length : total;
}

function renderTable(box) {
  if (busy && !result) {
    replace(box, el('div', { class: 'card empty', text: 'กำลังดึงข้อมูล…' }));
    return;
  }
  if (!result) {
    replace(
      box,
      el('div', {
        class: 'card empty',
        text: 'เลือกช่วงวันและค่าที่ต้องการ แล้วกดแสดงข้อมูล',
      }),
    );
    return;
  }
  if (result.rows.length === 0) {
    replace(
      box,
      el('div', {
        class: 'card empty',
        text:
          'ไม่พบข้อมูลในช่วงที่เลือก\n' +
          'ลองขยายช่วงวัน หรือตรวจว่าบอร์ดส่งค่าเข้ามาแล้วหรือยัง',
      }),
    );
    return;
  }

  const metricColumns = result.columns.filter((column) =>
    result.query.metrics.includes(column.key),
  );
  const leadColumns = result.columns.filter(
    (column) => !result.query.metrics.includes(column.key),
  );

  const head = el('tr', {}, [
    ...leadColumns.map((column) => el('th', { text: column.labelTh })),
    ...metricColumns.map((column) =>
      el('th', {
        class: 'num',
        text: column.unit ? `${column.labelTh} (${column.unit})` : column.labelTh,
      }),
    ),
  ]);

  const body = result.rows.map((row) =>
    el('tr', {}, [
      ...leadColumns.map((column) =>
        el('td', { text: String(row[column.key] ?? '—') }),
      ),
      ...metricColumns.map((column) =>
        el('td', {
          class: 'num',
          text:
            row.values[column.key] == null
              ? '—'
              : decimal(row.values[column.key], column.decimals ?? 2),
        }),
      ),
    ]),
  );

  const totals = result.totals ?? {};
  const foot = el('tr', {}, [
    el('td', {
      text: 'รวม / เฉลี่ยทั้งช่วง',
      colspan: String(leadColumns.length),
    }),
    ...metricColumns.map((column) =>
      el('td', {
        class: 'num',
        text:
          totals[column.key] == null
            ? '—'
            : decimal(totals[column.key], column.decimals ?? 2),
      }),
    ),
  ]);

  const consumption = Number(totals.consumption ?? 0);

  replace(box, [
    el('div', { class: 'row between', style: { marginBottom: '10px' } }, [
      el('div', { class: 'panel-title', style: { margin: '0' } }, [
        `ตารางข้อมูล ${result.rows.length} แถว`,
      ]),
      consumption > 0
        ? el('span', {
            class: 'cost-chip',
            text: `${energy(consumption)} ≈ ${baht(
              consumption * state.settings.electricityRate,
            )}`,
          })
        : null,
    ]),
    el('div', { class: 'table-wrap' }, [
      el('table', { class: 'data' }, [
        el('thead', {}, [head]),
        el('tbody', {}, body),
        el('tfoot', {}, [foot]),
      ]),
    ]),
    el('div', {
      class: 'dim',
      style: { fontSize: '11px', marginTop: '8px' },
      text:
        'ค่าเฉลี่ยของแรงดัน ตัวประกอบกำลัง และความถี่ คำนวณแบบถ่วงน้ำหนัก ' +
        'ตามจำนวนครั้งที่อ่านได้จริง ไม่ใช่เฉลี่ยของค่าเฉลี่ย',
    }),
  ]);
}

// ------------------------------------------------------------ ส่งออก Excel

async function downloadExcel(button) {
  button.disabled = true;
  toastInfo('กำลังสร้างไฟล์ Excel…');
  try {
    const { blob, fileName, rows } = await api.exportEnergy({
      ...queryFromFilters(),
      language: filters.language,
    });
    // สร้างลิงก์ชั่วคราวแล้วกดให้เอง เพราะต้องแนบโทเคนตอนดึงไฟล์
    const url = URL.createObjectURL(blob);
    const link = el('a', { href: url, download: fileName });
    document.body.appendChild(link);
    link.click();
    link.remove();
    // ปล่อยหน่วยความจำคืนหลังเบราว์เซอร์เริ่มบันทึกไฟล์แล้ว
    window.setTimeout(() => URL.revokeObjectURL(url), 4000);
    toastOk(`บันทึกไฟล์ ${fileName} แล้ว (${integer(rows)} แถว)`);
  } catch (error) {
    toastError(error.message);
  } finally {
    button.disabled = false;
  }
}
