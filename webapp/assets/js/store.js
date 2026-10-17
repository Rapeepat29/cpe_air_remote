/**
 * ที่เก็บสถานะกลางของเว็บแอป
 *
 * ทุกหน้าจออ่านข้อมูลจากที่นี่ที่เดียว และสมัครรับแจ้งเมื่อข้อมูลเปลี่ยน
 * เหตุผลที่ไม่ให้แต่ละหน้าดึงข้อมูลเอง:
 *   - หน้าภาพรวมกับหน้าห้องใช้ /rooms ชุดเดียวกัน ถ้าต่างคนต่างดึง
 *     เซิร์ฟเวอร์จะโดนถามซ้ำสองเท่าโดยไม่ได้อะไรเพิ่ม
 *   - เวลาสั่งเปิด-ปิดแอร์แล้วข้อมูลเปลี่ยน ทุกหน้าที่เปิดค้างอยู่ควรเห็นตรงกัน
 *
 * การดึงซ้ำเป็นรอบ (polling) ไม่ใช่ WebSocket เพราะ Backend ปัจจุบันไม่มีช่อง
 * ให้ผลักข้อมูลออกมา และการเพิ่ม WebSocket หมายถึงต้องแก้ทั้ง Express, Caddy
 * และ Docker ซึ่งเสี่ยงกว่าประโยชน์ที่ได้ในระบบขนาด 15 บอร์ด
 */

import { api, ApiError } from './api.js';
import { POLL } from './config.js';
import { isoDate, shiftDays } from './format.js';

/** ค่าเริ่มต้นของทุกอย่าง หน้าจอจึงวาดได้ตั้งแต่ก่อนข้อมูลชุดแรกมาถึง */
const initialState = {
  user: null,
  settings: { autoOffEnabled: true, autoOffTestMode: false, electricityRate: 4.5 },
  health: null,
  rooms: [],
  airConditioners: [],
  occupancySensors: [],
  live: { readings: [], totals: null, serverTime: null },
  alerts: { alerts: [], counts: {} },
  summary: null,
  summaryQuery: { period: 'week', floor: null },
  schedules: [],
  /**
   * ภาคเรียนของตารางที่ใช้อยู่ { semester, importedBy, importedAt }
   * null = ยังไม่เคยนำเข้าจากไฟล์, undefined = Backend รุ่นเก่าที่ยังไม่รองรับ
   */
  timetable: undefined,
  /** ปฏิทินภาคเรียน undefined = Backend รุ่นเก่าที่ยังไม่รองรับ */
  terms: undefined,
  /** วันนี้ตามเวลาไทยจาก Backend (YYYY-MM-DD) */
  today: null,
  /** การใช้ห้องในช่วงที่หน้าตารางเรียนกำลังดู undefined = Backend รุ่นเก่า */
  bookings: undefined,
  bookingsRange: null,
  users: [],
  metricCatalog: null,
  loading: {},
  errors: {},
};

export const state = { ...initialState };

const listeners = new Set();

/** สมัครรับแจ้งเมื่อสถานะเปลี่ยน คืนฟังก์ชันสำหรับยกเลิก */
export function subscribe(listener) {
  listeners.add(listener);
  return () => listeners.delete(listener);
}

let emitQueued = false;

/**
 * แจ้งผู้ติดตาม
 *
 * รวบหลายการเปลี่ยนแปลงในรอบเดียวกันให้แจ้งครั้งเดียว เพราะการโหลดข้อมูล
 * ชุดหนึ่งมักเขียนสถานะหลายก้อนติดกัน ถ้าแจ้งทุกก้อนหน้าจอจะวาดใหม่ซ้ำ ๆ
 */
export function emit() {
  if (emitQueued) return;
  emitQueued = true;
  queueMicrotask(() => {
    emitQueued = false;
    for (const listener of listeners) listener(state);
  });
}

export function patchState(partial) {
  Object.assign(state, partial);
  emit();
}

function setLoading(key, value) {
  state.loading = { ...state.loading, [key]: value };
}

function setError(key, error) {
  const message = error instanceof ApiError ? error.message : error?.message;
  state.errors = { ...state.errors, [key]: message ?? null };
}

/**
 * ห่อการโหลดหนึ่งชุดให้บันทึกสถานะกำลังโหลดและข้อผิดพลาดเสมอ
 *
 * ข้อผิดพลาด 401 ปล่อยผ่านไปเงียบ ๆ เพราะ api.js จัดการเด้งออกให้แล้ว
 * ถ้าโชว์ข้อความซ้ำอีกรอบจะกลายเป็นป้ายแดงค้างบนหน้าเข้าสู่ระบบ
 */
async function load(key, task) {
  setLoading(key, true);
  emit();
  try {
    const result = await task();
    setError(key, null);
    return result;
  } catch (error) {
    if (error?.status !== 401 && error?.name !== 'AbortError') {
      setError(key, error);
      console.warn(`[store] โหลด ${key} ไม่สำเร็จ:`, error?.message ?? error);
    }
    return null;
  } finally {
    setLoading(key, false);
    emit();
  }
}

// --------------------------------------------------------------- ตัวโหลด

export const loaders = {
  async settings() {
    const result = await load('settings', () => api.settings());
    if (result) {
      state.settings = {
        autoOffEnabled: result.autoOffEnabled !== false,
        autoOffTestMode: result.autoOffTestMode === true,
        // Backend รุ่นเก่ายังไม่มีอัตราค่าไฟ ให้ถอยไปใช้ค่าเดิมของแอปมือถือ
        electricityRate: Number.isFinite(Number(result.electricityRate))
          ? Number(result.electricityRate)
          : state.settings.electricityRate,
      };
      emit();
    }
    return state.settings;
  },

  async health() {
    const result = await load('health', () => api.health());
    state.health = result;
    emit();
    return result;
  },

  async rooms() {
    const result = await load('rooms', () => api.rooms());
    if (result) {
      state.rooms = result;
      emit();
    }
    return state.rooms;
  },

  async airConditioners() {
    const result = await load('airConditioners', () => api.airConditioners());
    if (result) {
      state.airConditioners = result;
      emit();
    }
    return state.airConditioners;
  },

  async occupancySensors() {
    const result = await load('occupancySensors', () => api.occupancySensors());
    if (result) {
      state.occupancySensors = result;
      emit();
    }
    return state.occupancySensors;
  },

  async live() {
    const result = await load('live', () => api.energyLive());
    if (result) {
      state.live = result;
      emit();
    }
    return state.live;
  },

  async alerts(query = { limit: 50 }) {
    const result = await load('alerts', () => api.alerts(query));
    if (result) {
      state.alerts = result;
      emit();
    }
    return state.alerts;
  },

  async summary(query = state.summaryQuery) {
    state.summaryQuery = { ...state.summaryQuery, ...query };
    const request = { ...state.summaryQuery };
    const result = await load('summary', () => api.energySummary(request));
    if (result) {
      state.summary = result;
      emit();
    }
    return state.summary;
  },

  async schedules(query) {
    // เผื่อเบราว์เซอร์ยังถือ api.js ตัวเก่าในแคช (ช่วงหนึ่งชั่วโมงหลัง deploy)
    const fetchSchedules = api.schedulesWithInfo
      ?? ((q) => api.schedules(q).then((schedules) => ({ schedules })));
    const result = await load('schedules', () => fetchSchedules(query));
    if (result) {
      state.schedules = result.schedules ?? [];
      state.timetable = 'timetable' in result ? result.timetable : undefined;
      emit();
    }
    return state.schedules;
  },

  async terms() {
    if (typeof api.academicTerms !== 'function') return state.terms;
    const result = await load('terms', () => api.academicTerms());
    if (result) {
      state.terms = result.terms ?? [];
      state.today = result.today ?? null;
      emit();
    }
    return state.terms;
  },

  async bookings(range = state.bookingsRange) {
    if (!range || typeof api.bookings !== 'function') return state.bookings;
    state.bookingsRange = range;
    const result = await load('bookings', () => api.bookings(range));
    if (result) {
      state.bookings = result;
      emit();
    }
    return state.bookings;
  },

  async users() {
    const result = await load('users', () => api.users());
    if (result) {
      state.users = result;
      emit();
    }
    return state.users;
  },

  async metricCatalog() {
    if (state.metricCatalog) return state.metricCatalog;
    const result = await load('metricCatalog', () => api.energyMetrics());
    if (result) {
      state.metricCatalog = result;
      emit();
    }
    return state.metricCatalog;
  },
};

// ------------------------------------------------------- การดึงซ้ำเป็นรอบ

const tasks = [
  { key: 'live', every: POLL.live, run: () => loaders.live() },
  { key: 'rooms', every: POLL.rooms, run: () => loaders.rooms() },
  {
    key: 'airConditioners',
    every: POLL.rooms,
    run: () => loaders.airConditioners(),
  },
  {
    // สถานะออนไลน์ รุ่นเฟิร์มแวร์ และผล OTA ของเซ็นเซอร์ (หน้าเฟิร์มแวร์ใช้ตัดสินผลอัปเดต)
    key: 'occupancySensors',
    every: POLL.rooms,
    run: () => loaders.occupancySensors(),
  },
  { key: 'alerts', every: POLL.alerts, run: () => loaders.alerts() },
  { key: 'summary', every: POLL.summary, run: () => loaders.summary() },
  { key: 'health', every: POLL.summary, run: () => loaders.health() },
];

const lastRun = new Map();
let timer = null;
let running = false;

async function tick(force = false) {
  if (running) return;
  // แท็บที่ถูกซ่อนไว้ไม่ต้องถามเซิร์ฟเวอร์ ประหยัดทั้งแบตและโควตาเน็ต
  // แล้วค่อยดึงใหม่ทันทีตอนกลับมาดู (ดูตัวจัดการ visibilitychange ข้างล่าง)
  if (!force && document.hidden) return;

  running = true;
  const now = Date.now();
  try {
    for (const task of tasks) {
      const previous = lastRun.get(task.key) ?? 0;
      if (!force && now - previous < task.every) continue;
      lastRun.set(task.key, now);
      await task.run();
    }
  } finally {
    running = false;
  }
}

/** เริ่มดึงข้อมูลเป็นรอบ เรียกหลังเข้าสู่ระบบสำเร็จ */
export function startPolling() {
  stopPolling();
  tick(true);
  timer = window.setInterval(() => tick(false), 5000);
}

export function stopPolling() {
  if (timer != null) {
    window.clearInterval(timer);
    timer = null;
  }
  lastRun.clear();
}

/** บังคับดึงใหม่ทั้งหมดเดี๋ยวนี้ ใช้กับปุ่มรีเฟรช */
export function refreshAll() {
  return tick(true);
}

document.addEventListener('visibilitychange', () => {
  if (!document.hidden && timer != null) tick(true);
});

/** โหลดข้อมูลชุดแรกหลังเข้าสู่ระบบ */
export async function bootstrap() {
  await Promise.all([
    loaders.settings(),
    loaders.rooms(),
    loaders.airConditioners(),
    loaders.occupancySensors(),
    loaders.live(),
    loaders.alerts(),
    loaders.health(),
  ]);
  await loaders.summary({ period: 'week', floor: null });
}

/** ล้างสถานะทั้งหมดตอนออกจากระบบ ไม่ให้ข้อมูลของคนเก่าค้างให้คนใหม่เห็น */
export function resetState() {
  stopPolling();
  Object.assign(state, {
    ...initialState,
    settings: { ...initialState.settings },
    live: { readings: [], totals: null, serverTime: null },
    alerts: { alerts: [], counts: {} },
    summaryQuery: { period: 'week', floor: null },
    loading: {},
    errors: {},
  });
  emit();
}

// ------------------------------------------------------- ตัวช่วยอ่านข้อมูล

/** แอร์ทั้งหมดของห้องหนึ่ง เรียงตามหมายเลขเครื่อง */
export function airConditionersOf(roomNumber) {
  return state.airConditioners
    .filter((unit) => unit.roomNumber === roomNumber)
    .sort((a, b) => a.airNumber - b.airNumber);
}

/** ค่าที่อ่านสดล่าสุดของเครื่องหนึ่ง */
export function liveReading(deviceId) {
  return state.live.readings.find((row) => row.deviceId === deviceId) ?? null;
}

/** เซ็นเซอร์ตรวจจับคนของห้องหนึ่ง */
export function sensorOf(roomNumber) {
  return (
    state.occupancySensors.find((row) => row.roomNumber === roomNumber) ?? null
  );
}

/** จัดห้องเป็นกลุ่มตามชั้น เรียงชั้นน้อยไปมาก โดยให้ห้องพิเศษอยู่แรกสุด */
export function roomsByFloor(rooms = state.rooms) {
  const groups = new Map();
  for (const room of rooms) {
    const floor = Number(room.floorNumber) || 0;
    if (!groups.has(floor)) groups.set(floor, []);
    groups.get(floor).push(room);
  }
  return [...groups.entries()]
    .map(([floor, list]) => ({
      floor,
      rooms: list.sort((a, b) => a.roomIndex - b.roomIndex),
    }))
    .sort((a, b) => a.floor - b.floor);
}

/** ค่าไฟรายห้องของช่วงที่เลือกอยู่ แปลงเป็นแผนที่เพื่อค้นหาเร็ว */
export function roomEnergyMap() {
  const map = new Map();
  for (const row of state.summary?.rooms ?? []) {
    map.set(row.roomNumber, row.kwh);
  }
  return map;
}

/** ช่วงวันที่เริ่มต้นของหน้าข้อมูลไฟฟ้า: ย้อนหลัง 7 วันรวมวันนี้ */
export function defaultHistoryRange() {
  const today = isoDate();
  return { from: shiftDays(today, -6), to: today };
}
