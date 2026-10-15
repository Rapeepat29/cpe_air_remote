/**
 * หน้าเฟิร์มแวร์ (เฉพาะแอดมิน) — อัปเดตบอร์ดผ่าน Wi-Fi แยกตามชนิดบอร์ด
 *
 * แยกเป็นสามแท็บ: แอร์ IR / สายแอร์ Daikin / เซ็นเซอร์ LD2410 เพราะไฟล์ของแต่ละชนิด
 * ใช้ข้ามกันไม่ได้ ถ้าสั่งไฟล์ผิดชนิด บอร์ดจะรีบูตเข้าโปรแกรมของบอร์ดอีกแบบ
 * แต่ละแท็บจึงเห็นเฉพาะไฟล์และบอร์ดของชนิดนั้น และช่องอัปโหลดในแท็บรับเฉพาะ
 * ไฟล์ของชนิดนั้น (Backend ตรวจซ้ำอีกชั้นทั้งตอนอัปโหลดและตอนสั่งบอร์ด)
 *
 * ชนิดของไฟล์ดูจากชื่อ: มี occ = เซ็นเซอร์, มี wired/slm8 = สายแอร์, นอกนั้น = แอร์ IR
 * รุ่นดูจากท้ายชื่อ เช่น rmutt_esp32_air_wired-2.5.2-slm8.bin -> 2.5.2-slm8
 */

import { api } from '../api.js';
import { el, replace, emptyState } from '../dom.js';
import { isWiredProtocol, relativeTime } from '../format.js';
import { uiIcons } from '../icons-ui.js';
import { state } from '../store.js';
import {
  confirmAction,
  openForm,
  toastError,
  toastInfo,
  toastOk,
} from '../ui.js';

const KINDS = [
  {
    key: 'air',
    label: 'แอร์ IR',
    sketch: 'rmutt_esp32_air',
  },
  {
    key: 'wired',
    label: 'สายแอร์ Daikin',
    sketch: 'rmutt_esp32_air_wired',
  },
  {
    key: 'occupancy',
    label: 'เซ็นเซอร์ LD2410',
    sketch: 'rmutt_esp32_occupancy',
  },
];

// หลังสั่งอัปเดต รอบอร์ดรายงานรุ่นใหม่ได้นานเท่านี้ เกินแล้วถือว่าไม่สำเร็จ
// (บอร์ดใช้ประมาณ 1–2 นาที เผื่อ Wi-Fi ช้าและบอร์ดต่อ MQTT ใหม่)
const PENDING_MS = 5 * 60 * 1000;

let activeKind = null;
const selected = { air: new Set(), wired: new Set(), occupancy: new Set() };
// deviceId -> { target, startedAt } บอร์ดที่สั่งไปแล้ว รอรายงานรุ่นใหม่
const pending = new Map();

let files = null;
let filesError = '';
let configured = true;
let maxBytes = 0x1f0000;
let uploading = false;

export default {
  title: 'เฟิร์มแวร์',
  subtitle: 'อัปเดตบอร์ดผ่าน Wi-Fi โดยไม่ต้องถอดมาเสียบ USB',
  adminOnly: true,

  async mount(root) {
    const head = el('div', { class: 'row between fw-head' });
    const tabBar = el('div', { class: 'tabbar', role: 'tablist', 'aria-label': 'ชนิดบอร์ด' });
    const panel = el('div', { class: 'fw-panel', role: 'tabpanel' });
    replace(root, [head, tabBar, panel]);

    const update = () => render({ head, tabBar, panel, update });
    update();
    await loadFiles();
    update();
    return { update };
  },
};

async function loadFiles() {
  try {
    const result = await api.firmwareFiles();
    files = result?.files ?? [];
    configured = result?.configured !== false;
    if (result?.maxBytes) maxBytes = result.maxBytes;
    filesError = '';
  } catch (error) {
    files = files ?? [];
    filesError = error.message;
  }
}

// --------------------------------------------------------------- ข้อมูล

/** ชนิดไฟล์จากชื่อ ต้องตรงกับ firmwareKindOf ใน backend/src/utils/firmware.js */
function kindOfFileName(name) {
  if (/occ/i.test(name)) return 'occupancy';
  if (/wired|slm8/i.test(name)) return 'wired';
  return 'air';
}

function versionOfFileName(name) {
  const match = String(name ?? '').match(
    /-(\d+\.\d+(?:\.\d+)?(?:-[A-Za-z0-9]+)*)\.bin$/,
  );
  return match ? match[1] : null;
}

/** เทียบเลขรุ่นข้างหน้า (2.5.10 > 2.5.9) ส่วนท้ายอย่าง -slm8 ไม่นับ */
function compareVersions(a, b) {
  const parts = (value) => {
    const match = String(value ?? '').match(/^(\d+)\.(\d+)(?:\.(\d+))?/);
    return match ? [match[1], match[2], match[3] ?? '0'].map(Number) : null;
  };
  const left = parts(a);
  const right = parts(b);
  if (!left && !right) return 0;
  if (!left) return -1;
  if (!right) return 1;
  for (let index = 0; index < 3; index += 1) {
    if (left[index] !== right[index]) return left[index] - right[index];
  }
  return 0;
}

function devicesOf(kind) {
  if (kind === 'occupancy') return state.occupancySensors ?? [];
  const wired = kind === 'wired';
  return (state.airConditioners ?? []).filter(
    (unit) => isWiredProtocol(unit.protocol) === wired,
  );
}

/** ไฟล์ของชนิดนี้ รุ่นใหม่สุดก่อน (รุ่นเท่ากัน ไฟล์ที่อัปโหลดทีหลังก่อน) */
function filesOf(kind) {
  return (files ?? [])
    .filter((file) => file.kind === kind)
    .map((file) => ({ ...file, version: file.version ?? versionOfFileName(file.name) }))
    .sort(
      (a, b) =>
        compareVersions(b.version, a.version) ||
        String(b.modifiedAt).localeCompare(String(a.modifiedAt)),
    );
}

const latestFileOf = (kind) => filesOf(kind)[0] ?? null;

function deviceTitle(device, kind) {
  if (kind === 'occupancy') return `เซ็นเซอร์ · ห้อง ${device.roomNumber}`;
  return `${device.name || 'แอร์'} · ห้อง ${device.roomNumber} เครื่องที่ ${device.airNumber}`;
}

/**
 * สถานะของบอร์ดเทียบกับไฟล์ล่าสุด
 * code: updating | uptodate | outdated | offline | notready | nofile
 */
function statusOf(device, latest) {
  const job = pending.get(device.deviceId);
  if (job) return { code: 'updating', target: job.target, startedAt: job.startedAt };
  if (device.provisionStatus && device.provisionStatus !== 'active') {
    return { code: 'notready' };
  }
  if (!device.isOnline) return { code: 'offline' };
  if (!latest) return { code: 'nofile' };
  if (
    device.firmwareVersion &&
    compareVersions(device.firmwareVersion, latest.version) >= 0
  ) {
    return { code: 'uptodate' };
  }
  return { code: 'outdated' };
}

/**
 * ปิดงานที่รอ: บอร์ดรายงานรุ่นเป้าหมายแล้ว = สำเร็จ, รายงาน otaError ใหม่ = ไม่สำเร็จ
 * หรือรอเกิน PENDING_MS = ถือว่าไม่สำเร็จ (บอร์ดใช้รุ่นเดิมต่อ)
 */
function settlePending() {
  if (pending.size === 0) return;
  const devices = [...(state.airConditioners ?? []), ...(state.occupancySensors ?? [])];
  for (const [deviceId, job] of pending) {
    const device = devices.find((item) => item.deviceId === deviceId);
    if (!device) {
      pending.delete(deviceId);
    } else if (device.firmwareVersion && device.firmwareVersion === job.target) {
      pending.delete(deviceId);
      toastOk(`${deviceId} เป็นรุ่น ${job.target} แล้ว`);
    } else if (device.otaError && device.otaError !== job.previousError) {
      pending.delete(deviceId);
      toastError(`${deviceId} อัปเดตไม่สำเร็จ: ${device.otaError}`);
    } else if (Date.now() - job.startedAt >= PENDING_MS) {
      pending.delete(deviceId);
      toastError(
        device.otaError
          ? `${deviceId} อัปเดตไม่สำเร็จ: ${device.otaError}`
          : `${deviceId} ยังไม่รายงานรุ่น ${job.target} ภายใน 5 นาที `
            + `(รุ่นตอนนี้ ${device.firmwareVersion || 'ไม่ทราบ'})`,
      );
    }
  }
}

function outdatedCount(kind) {
  const latest = latestFileOf(kind);
  return devicesOf(kind).filter(
    (device) => statusOf(device, latest).code === 'outdated',
  ).length;
}

// ------------------------------------------------------------- หน้าจอ

function render(ctx) {
  const { head, tabBar, panel } = ctx;
  settlePending();

  if (!activeKind && files) {
    activeKind =
      KINDS.find((kind) => outdatedCount(kind.key) > 0)?.key ??
      KINDS.find((kind) => devicesOf(kind.key).length > 0)?.key ??
      'air';
  }
  const kind = activeKind ?? 'air';

  const all = KINDS.flatMap((item) => devicesOf(item.key));
  replace(head, [
    el('div', {
      class: 'dim',
      text: 'เลือกชนิดบอร์ด อัปโหลดไฟล์ .bin แล้วสั่งบอร์ดที่ยังเป็นรุ่นเก่า',
    }),
    el('div', {
      class: 'pill',
      text: `ออนไลน์ ${all.filter((device) => device.isOnline).length} / ${all.length} บอร์ด`,
    }),
  ]);

  replace(
    tabBar,
    KINDS.map((item) => {
      const count = files ? outdatedCount(item.key) : 0;
      const total = devicesOf(item.key).length;
      let badge = null;
      if (!files) badge = null;
      else if (count > 0) badge = el('span', { class: 'fw-badge warn', text: `${count} ต้องอัปเดต` });
      else if (total > 0 && latestFileOf(item.key)) badge = el('span', { class: 'fw-badge ok', text: 'ล่าสุดครบ' });
      else if (total === 0) badge = el('span', { class: 'tab-count', text: 'ไม่มีบอร์ด' });
      return el(
        'button',
        {
          class: `tab${item.key === kind ? ' active' : ''}`,
          type: 'button',
          role: 'tab',
          'aria-selected': item.key === kind ? 'true' : 'false',
          onclick: () => {
            activeKind = item.key;
            ctx.update();
          },
        },
        [item.label, badge],
      );
    }),
  );

  const meta = KINDS.find((item) => item.key === kind);
  panel.setAttribute('aria-label', meta.label);
  replace(panel, [
    el('div', { class: 'fw-grid' }, [
      filesCard(meta, ctx),
      dropZone(meta, ctx),
    ]),
    devicesCard(meta, ctx),
    bulkBar(meta, ctx),
  ]);
}

function filesCard(meta, ctx) {
  const list = filesOf(meta.key);
  let content;
  if (files == null) {
    content = el('div', { class: 'dim', text: 'กำลังโหลดรายการไฟล์…' });
  } else if (filesError) {
    content = el('div', { class: 'bad', text: `โหลดรายการไฟล์ไม่ได้: ${filesError}` });
  } else if (!configured) {
    content = el('div', {
      class: 'warn',
      text: 'เซิร์ฟเวอร์ยังไม่ได้ตั้ง FIRMWARE_DIR จึงยังเก็บไฟล์เฟิร์มแวร์ไม่ได้',
    });
  } else if (list.length === 0) {
    content = emptyState(`ยังไม่มีไฟล์ของ${meta.label} อัปโหลดไฟล์ .bin ทางขวา`);
  } else {
    content = el(
      'div',
      { class: 'fw-files' },
      list.map((file, index) =>
        el('div', { class: `fw-file${index === 0 ? ' latest' : ''}` }, [
          el('div', { class: 'grow' }, [
            el('div', { class: 'fw-version mono', text: file.version ?? 'ไม่ทราบรุ่น' }),
            el('div', {
              class: 'list-sub',
              text:
                `${file.name} · ${formatSize(file.size)} · ` +
                `อัปโหลด ${relativeTime(file.modifiedAt)}` +
                (index === 0 ? '' : ' · รุ่นเก่า'),
            }),
          ]),
          index === 0 ? el('span', { class: 'fw-badge ok', text: 'ล่าสุด' }) : null,
          el('button', {
            class: 'btn btn-sm',
            type: 'button',
            text: 'ลบ',
            'aria-label': `ลบไฟล์ ${file.name}`,
            onclick: () => removeFile(file, ctx),
          }),
        ]),
      ),
    );
  }

  return el('section', { class: 'card' }, [
    el('div', { class: 'panel-title' }, [
      el('span', { text: `ไฟล์ของ${meta.label}` }),
      el('span', { class: 'count-badge', text: `สเก็ตช์ ${meta.sketch}` }),
    ]),
    content,
  ]);
}

function dropZone(meta, ctx) {
  const input = el('input', {
    type: 'file',
    accept: '.bin',
    class: 'sr-only',
    disabled: uploading || !configured,
    onchange: (event) => {
      const file = event.target.files?.[0];
      event.target.value = '';
      if (file) handleFile(file, meta, ctx);
    },
  });

  const zone = el('label', { class: `drop-zone${uploading ? ' busy' : ''}` }, [
    input,
    el('span', { class: 'dz-icon', html: uiIcons.upload(26) }),
    el('span', {
      class: 'dz-title',
      text: uploading ? 'กำลังอัปโหลด…' : `อัปโหลดรุ่นใหม่ของ${meta.label}`,
    }),
    el('span', {
      class: 'dz-sub',
      text:
        `ลากไฟล์มาวาง หรือกดเพื่อเลือก · ไฟล์ .ino.bin จาก Arduino IDE ` +
        `(Sketch → Export Compiled Binary) ของสเก็ตช์ ${meta.sketch}`,
    }),
  ]);

  const stop = (event) => {
    event.preventDefault();
    event.stopPropagation();
  };
  zone.addEventListener('dragenter', (event) => {
    stop(event);
    zone.classList.add('dragging');
  });
  zone.addEventListener('dragover', (event) => {
    stop(event);
    zone.classList.add('dragging');
  });
  zone.addEventListener('dragleave', (event) => {
    stop(event);
    if (!zone.contains(event.relatedTarget)) zone.classList.remove('dragging');
  });
  zone.addEventListener('drop', (event) => {
    stop(event);
    zone.classList.remove('dragging');
    const file = event.dataTransfer?.files?.[0];
    if (file && !uploading) handleFile(file, meta, ctx);
  });
  return zone;
}

function devicesCard(meta, ctx) {
  const latest = latestFileOf(meta.key);
  const devices = devicesOf(meta.key);
  const chosen = selected[meta.key];
  const rows = devices.map((device) => ({ device, status: statusOf(device, latest) }));

  // บอร์ดที่เลือกไว้แต่ไม่ต้องอัปเดตแล้ว (เช่นเพิ่งอัปเดตเสร็จ) เอาออกจากที่เลือก
  for (const { device, status } of rows) {
    if (status.code !== 'outdated') chosen.delete(device.deviceId);
  }
  const outdated = rows.filter((row) => row.status.code === 'outdated');

  const header = el('div', { class: 'panel-title' }, [
    el('span', { text: `บอร์ด${meta.label} · ${devices.length} ตัว` }),
    outdated.length > 0
      ? el('button', {
          class: 'btn btn-sm',
          type: 'button',
          text: `เลือกทุกตัวที่ยังเก่า (${outdated.length})`,
          onclick: () => {
            for (const row of outdated) chosen.add(row.device.deviceId);
            ctx.update();
          },
        })
      : null,
  ]);

  if (devices.length === 0) {
    return el('section', { class: 'card' }, [
      header,
      emptyState(`ยังไม่มีบอร์ด${meta.label}ในระบบ`),
    ]);
  }

  const allChecked =
    outdated.length > 0 && outdated.every((row) => chosen.has(row.device.deviceId));

  const table = el('table', { class: 'data fw-table' }, [
    el('thead', {}, [
      el('tr', {}, [
        el('th', { class: 'fw-check' }, [
          el('input', {
            type: 'checkbox',
            'aria-label': 'เลือกทุกบอร์ดที่ยังเก่า',
            checked: allChecked,
            disabled: outdated.length === 0,
            onchange: (event) => {
              for (const row of outdated) {
                if (event.target.checked) chosen.add(row.device.deviceId);
                else chosen.delete(row.device.deviceId);
              }
              ctx.update();
            },
          }),
        ]),
        el('th', { text: 'บอร์ด' }),
        el('th', { text: 'รุ่นตอนนี้' }),
        el('th', { text: 'สถานะ' }),
        el('th', { class: 'fw-act', text: 'คำสั่ง' }),
      ]),
    ]),
    el(
      'tbody',
      {},
      rows.map(({ device, status }) => deviceRow(device, status, latest, meta, ctx)),
    ),
  ]);

  return el('section', { class: 'card' }, [
    header,
    el('div', { class: 'table-wrap' }, [table]),
  ]);
}

function deviceRow(device, status, latest, meta, ctx) {
  const chosen = selected[meta.key];
  const canUpdate = status.code === 'outdated';
  const current = device.firmwareVersion ?? 'ไม่ทราบรุ่น';

  let versionCell;
  if (status.code === 'outdated') {
    versionCell = [
      el('span', { class: 'mono', text: current }),
      el('span', { class: 'warn', text: ` → ${latest.version ?? latest.name}` }),
    ];
  } else if (status.code === 'uptodate') {
    versionCell = [el('span', { class: 'mono', text: current }), el('span', { class: 'dim', text: ' · ล่าสุดแล้ว' })];
  } else {
    versionCell = [el('span', { class: 'mono', text: current })];
  }

  return el('tr', {}, [
    el('td', { class: 'fw-check' }, [
      el('input', {
        type: 'checkbox',
        'aria-label': `เลือก ${deviceTitle(device, meta.key)}`,
        checked: chosen.has(device.deviceId),
        disabled: !canUpdate,
        onchange: (event) => {
          if (event.target.checked) chosen.add(device.deviceId);
          else chosen.delete(device.deviceId);
          ctx.update();
        },
      }),
    ]),
    el('td', {}, [
      el('div', { class: 'fw-name', text: deviceTitle(device, meta.key) }),
      el('div', { class: 'list-sub mono', text: device.deviceId }),
    ]),
    el('td', {}, versionCell),
    el('td', {}, [statusBadge(device, status)]),
    el('td', { class: 'fw-act' }, [
      canUpdate
        ? el('button', {
            class: 'btn btn-sm',
            type: 'button',
            text: 'อัปเดต',
            onclick: () => startUpdates([device], meta, ctx),
          })
        : el('span', { class: 'dim', text: '—' }),
    ]),
  ]);
}

function statusBadge(device, status) {
  switch (status.code) {
    case 'updating': {
      const seconds = Math.round((Date.now() - status.startedAt) / 1000);
      return el('div', { class: 'fw-updating' }, [
        el('span', { class: 'fw-spinner', 'aria-hidden': 'true' }),
        el('span', {
          text: `กำลังอัปเดตเป็น ${status.target} · ${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`,
        }),
      ]);
    }
    case 'offline':
      return el('span', {
        class: 'fw-state off',
        text: `ออฟไลน์ · เห็นล่าสุด ${relativeTime(device.lastSeenAt)}`,
      });
    case 'notready':
      return el('span', { class: 'fw-state off', text: 'ยังตั้งค่าไม่เสร็จ' });
    default:
      return el('div', {}, [
        el('span', { class: 'fw-state on', text: 'ออนไลน์' }),
        device.otaError
          ? el('div', { class: 'list-sub bad', text: `อัปเดตครั้งก่อนไม่สำเร็จ: ${device.otaError}` })
          : null,
      ]);
  }
}

function bulkBar(meta, ctx) {
  const chosen = selected[meta.key];
  if (chosen.size === 0) return null;
  const latest = latestFileOf(meta.key);
  const devices = devicesOf(meta.key).filter((device) => chosen.has(device.deviceId));
  return el('div', { class: 'fw-bar', role: 'region', 'aria-label': 'อัปเดตหลายบอร์ด' }, [
    el('span', {}, [
      'เลือก ',
      el('b', { text: String(chosen.size) }),
      ` บอร์ด${meta.label} · ใช้ไฟล์ `,
      el('span', { class: 'mono', text: latest?.version ?? latest?.name ?? '—' }),
    ]),
    el('div', { class: 'row', style: { gap: '8px' } }, [
      el('button', {
        class: 'btn',
        type: 'button',
        text: 'ยกเลิกการเลือก',
        onclick: () => {
          chosen.clear();
          ctx.update();
        },
      }),
      el('button', {
        class: 'btn btn-primary',
        type: 'button',
        text: `อัปเดต ${chosen.size} บอร์ดที่เลือก`,
        onclick: () => startUpdates(devices, meta, ctx),
      }),
    ]),
  ]);
}

// -------------------------------------------------------------- การกระทำ

async function startUpdates(devices, meta, ctx) {
  const latest = latestFileOf(meta.key);
  if (!latest) {
    toastInfo(`ยังไม่มีไฟล์ของ${meta.label} อัปโหลดไฟล์ก่อน`);
    return;
  }
  const target = latest.version ?? latest.name;
  const ok = await confirmAction({
    title:
      devices.length === 1
        ? `อัปเดต ${deviceTitle(devices[0], meta.key)}`
        : `อัปเดต ${devices.length} บอร์ด${meta.label}`,
    subtitle:
      `บอร์ดจะดาวน์โหลด ${latest.name} แล้วรีบูตเอง ใช้เวลาประมาณ 1–2 นาที ` +
      'ระหว่างนั้นสั่งงานบอร์ดจากแอปไม่ได้ ถ้าไม่สำเร็จบอร์ดจะใช้รุ่นเดิมต่อ ' +
      'แนะนำให้อัปเดตนอกเวลาเรียน',
    confirmLabel: `เริ่มอัปเดตเป็น ${target}`,
  });
  if (!ok) return;

  let sent = 0;
  const failures = [];
  for (const device of devices) {
    try {
      if (meta.key === 'occupancy') {
        await api.otaOccupancySensor(device.deviceId, latest.name);
      } else {
        await api.otaAirConditioner(device.deviceId, latest.name);
      }
      pending.set(device.deviceId, {
        target,
        startedAt: Date.now(),
        // Backend ล้าง otaError ตอนส่งคำสั่ง error ที่ตามมาจึงเป็นของรอบนี้เสมอ
        // (แม้ข้อความจะซ้ำกับรอบก่อน เช่นดาวน์โหลดไม่ได้ด้วยสาเหตุเดิม)
        previousError: null,
      });
      selected[meta.key].delete(device.deviceId);
      sent += 1;
    } catch (error) {
      failures.push(`${device.deviceId}: ${error.message}`);
    }
  }
  if (sent > 0) {
    toastOk(`ส่งคำสั่งแล้ว ${sent} บอร์ด รอบอร์ดรีบูตและรายงานรุ่นใหม่`);
  }
  for (const message of failures) toastError(message);
  ctx.update();
}

async function handleFile(file, meta, ctx) {
  if (!/\.bin$/i.test(file.name)) {
    toastError('เลือกไฟล์ .bin ที่ได้จาก Sketch → Export Compiled Binary');
    return;
  }
  if (file.size > maxBytes) {
    toastError(`ไฟล์ใหญ่เกินช่องโปรแกรมของบอร์ด (สูงสุด ${formatSize(maxBytes)})`);
    return;
  }
  if (/\.(merged|bootloader|partitions)\.bin$/i.test(file.name)) {
    toastError('ใช้ไฟล์ .ino.bin เท่านั้น ไม่ใช่ .merged.bin หรือ .bootloader.bin');
    return;
  }

  // ชื่อไฟล์บนเซิร์ฟเวอร์ต้องมีชื่อสเก็ตช์และรุ่น
  // Arduino IDE ตั้งชื่อเป็น <สเก็ตช์>.ino.bin จึงถามรุ่นเพิ่ม
  let fileName = file.name.replace(/\s+/g, '_');
  if (!versionOfFileName(fileName)) {
    const base = fileName.replace(/(\.ino)?\.bin$/i, '');
    const values = await openForm({
      title: 'ระบุรุ่นของไฟล์นี้',
      subtitle:
        `${file.name} ยังไม่มีเลขรุ่นในชื่อ ` +
        'ดูเลขรุ่นได้จาก FIRMWARE_VERSION ในโค้ด หรือบรรทัด "Firmware:" ใน Serial Monitor',
      submitLabel: 'อัปโหลด',
      fields: [
        {
          name: 'version',
          label: 'รุ่น',
          placeholder: meta.key === 'wired' ? 'เช่น 2.5.2-slm8' : 'เช่น 2.5.1',
          required: true,
        },
      ],
    });
    if (!values) return;
    const version = values.version.replace(/^v/i, '');
    if (!/^\d+\.\d+(\.\d+)?(-[A-Za-z0-9]+)*$/.test(version)) {
      toastError('รุ่นต้องเป็นตัวเลขแบบ 2.5.1 หรือ 2.5.2-slm8');
      return;
    }
    fileName = `${base}-${version}.bin`;
  }

  const kind = kindOfFileName(fileName);
  if (kind !== meta.key) {
    const other = KINDS.find((item) => item.key === kind);
    toastError(
      `ชื่อไฟล์ ${fileName} เป็นของ${other.label} ไม่ใช่${meta.label} ` +
        `ให้อัปโหลดในแท็บ ${other.label} หรือใช้ไฟล์จากสเก็ตช์ ${meta.sketch}`,
    );
    return;
  }

  uploading = true;
  ctx.update();
  try {
    await uploadWithReplace(file, fileName, meta.key);
    await loadFiles();
  } finally {
    uploading = false;
    ctx.update();
  }
}

async function uploadWithReplace(file, fileName, kind) {
  try {
    await api.uploadFirmware(file, fileName, kind);
    toastOk(`อัปโหลด ${fileName} แล้ว`);
  } catch (error) {
    if (error.status !== 409) {
      toastError(error.message);
      return;
    }
    const replaceIt = await confirmAction({
      title: `มีไฟล์ ${fileName} อยู่แล้ว`,
      subtitle: 'เขียนทับด้วยไฟล์ใหม่ไหม บอร์ดที่สั่งด้วยชื่อนี้หลังจากนี้จะได้ไฟล์ใหม่',
      confirmLabel: 'เขียนทับ',
      danger: true,
    });
    if (!replaceIt) return;
    try {
      await api.uploadFirmware(file, fileName, kind, true);
      toastOk(`เขียนทับ ${fileName} แล้ว`);
    } catch (retryError) {
      toastError(retryError.message);
    }
  }
}

async function removeFile(file, ctx) {
  const ok = await confirmAction({
    title: `ลบ ${file.name}`,
    subtitle: 'บอร์ดที่อัปเดตไปแล้วไม่ได้รับผลกระทบ แต่จะสั่งอัปเดตด้วยไฟล์นี้อีกไม่ได้',
    confirmLabel: 'ลบไฟล์',
    danger: true,
  });
  if (!ok) return;
  try {
    await api.deleteFirmware(file.name);
    toastOk(`ลบ ${file.name} แล้ว`);
    await loadFiles();
    ctx.update();
  } catch (error) {
    toastError(error.message);
  }
}

function formatSize(bytes) {
  const value = Number(bytes) || 0;
  if (value >= 1024 * 1024) return `${(value / 1024 / 1024).toFixed(2)} MB`;
  return `${Math.round(value / 1024)} KB`;
}

