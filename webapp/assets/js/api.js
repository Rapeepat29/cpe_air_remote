/**
 * ชั้นเดียวที่คุยกับ Backend
 *
 * ทุกหน้าจอเรียกผ่านไฟล์นี้เท่านั้น ไม่มีที่ไหนเรียก fetch เอง เพราะ:
 *   1. โทเคนต้องแนบทุกคำขอ ถ้ากระจายไปเขียนหลายที่ จะมีสักที่ที่ลืม
 *   2. เวลาโทเคนหมดอายุ (401) ต้องเด้งกลับหน้าเข้าสู่ระบบ "ที่เดียว"
 *      ไม่ใช่ให้แต่ละหน้าจัดการกันเอง แล้วได้พฤติกรรมไม่เหมือนกัน
 *   3. ข้อความผิดพลาดจาก Backend เป็นภาษาไทยอยู่แล้ว ต้องส่งต่อให้ผู้ใช้เห็น
 *      ไม่ใช่กลืนแล้วโชว์ว่า "เกิดข้อผิดพลาด" ซึ่งไม่ช่วยอะไรเลย
 */

import { API_BASE, STORAGE } from './config.js';

/** ข้อผิดพลาดที่รู้รหัสสถานะ ใช้แยกว่าโทเคนหมดอายุหรือข้อมูลไม่ถูกต้อง */
export class ApiError extends Error {
  constructor(status, message, payload = null) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.payload = payload;
  }
}

let token = read(STORAGE.token);
const unauthorizedHandlers = new Set();

function read(key) {
  try {
    return window.localStorage.getItem(key);
  } catch {
    return null;
  }
}

function write(key, value) {
  try {
    if (value == null) window.localStorage.removeItem(key);
    else window.localStorage.setItem(key, value);
  } catch {
    // โหมดส่วนตัวเขียนไม่ได้ ก็ใช้ได้แค่ในแท็บนี้ ไม่ถือว่าเป็นข้อผิดพลาด
  }
}

export function getToken() {
  return token;
}

export function setToken(value) {
  token = value || null;
  write(STORAGE.token, token);
}

export function getCachedUser() {
  const raw = read(STORAGE.user);
  if (!raw) return null;
  try {
    return JSON.parse(raw);
  } catch {
    return null;
  }
}

export function setCachedUser(user) {
  write(STORAGE.user, user ? JSON.stringify(user) : null);
}

/** ให้แอปรู้ตัวเมื่อโทเคนใช้ไม่ได้แล้ว */
export function onUnauthorized(handler) {
  unauthorizedHandlers.add(handler);
  return () => unauthorizedHandlers.delete(handler);
}

function notifyUnauthorized(message) {
  setToken(null);
  setCachedUser(null);
  for (const handler of unauthorizedHandlers) handler(message);
}

function buildUrl(path, query) {
  const url = `${API_BASE}${path}`;
  if (!query) return url;
  const search = new URLSearchParams();
  for (const [key, value] of Object.entries(query)) {
    if (value == null || value === '') continue;
    if (Array.isArray(value)) {
      if (value.length === 0) continue;
      search.set(key, value.join(','));
    } else {
      search.set(key, String(value));
    }
  }
  const text = search.toString();
  return text ? `${url}?${text}` : url;
}

async function request(
  method,
  path,
  {
    body = null,
    query = null,
    raw = false,
    signal = null,
    // ส่งไฟล์ (Blob/File) ตรง ๆ ไม่แปลงเป็น JSON ใช้กับการอัปโหลดตารางเรียน
    upload = null,
    headers: extraHeaders = null,
  } = {},
) {
  const headers = { ...(extraHeaders ?? {}) };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body != null) headers['Content-Type'] = 'application/json';

  let response;
  try {
    response = await fetch(buildUrl(path, query), {
      method,
      headers,
      signal,
      body: upload ?? (body == null ? undefined : JSON.stringify(body)),
    });
  } catch (error) {
    if (error?.name === 'AbortError') throw error;
    // แยกกรณี "ต่อเซิร์ฟเวอร์ไม่ได้" ออกจาก "เซิร์ฟเวอร์ตอบว่าไม่ผ่าน"
    // เพราะวิธีแก้คนละเรื่องกันโดยสิ้นเชิง
    throw new ApiError(0, 'ต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจอินเทอร์เน็ต');
  }

  if (response.status === 401) {
    const payload = await safeJson(response);
    const message = payload?.message ?? 'กรุณาเข้าสู่ระบบใหม่';
    notifyUnauthorized(message);
    throw new ApiError(401, message, payload);
  }

  if (!response.ok) {
    const payload = await safeJson(response);
    throw new ApiError(
      response.status,
      payload?.message ?? `เซิร์ฟเวอร์ตอบกลับรหัส ${response.status}`,
      payload,
    );
  }

  if (raw) return response;
  if (response.status === 204) return null;
  return safeJson(response);
}

async function safeJson(response) {
  try {
    const text = await response.text();
    return text ? JSON.parse(text) : null;
  } catch {
    return null;
  }
}

const get = (path, query, options) => request('GET', path, { query, ...options });
const post = (path, body, query) => request('POST', path, { body, query });
const patch = (path, body) => request('PATCH', path, { body });
const put = (path, body) => request('PUT', path, { body });
const remove = (path) => request('DELETE', path);

export const api = {
  // ---------------------------------------------------------------- ระบบ
  health: () => get('/health'),
  adminContact: () => get('/public/admin-contact'),

  // ------------------------------------------------------------ เข้าสู่ระบบ
  async login(username, password) {
    const result = await post('/auth/login', { username, password });
    setToken(result.token);
    setCachedUser(result.user);
    return result.user;
  },
  me: () => get('/auth/me').then((result) => result.user),
  updateProfile: (input) =>
    patch('/auth/me', input).then((result) => result.user),
  changePassword: (currentPassword, newPassword) =>
    post('/auth/me/password', { currentPassword, newPassword }),
  forgotPassword: (identifier) => post('/auth/forgot-password', { identifier }),
  verifyOtp: (requestId, otp) => post('/auth/verify-otp', { requestId, otp }),
  resetPassword: (resetToken, newPassword) =>
    post('/auth/reset-password', { resetToken, newPassword }),
  logout() {
    setToken(null);
    setCachedUser(null);
  },

  // ------------------------------------------------------------------ ห้อง
  rooms: () => get('/rooms').then((result) => result.rooms),
  createRoom: (input) => post('/rooms', input).then((r) => r.room),
  updateRoom: (roomNumber, input) =>
    put(`/rooms/${encodeURIComponent(roomNumber)}`, input).then((r) => r.room),
  deleteRoom: (roomNumber) =>
    remove(`/rooms/${encodeURIComponent(roomNumber)}`),

  // --------------------------------------------------------- เครื่องปรับอากาศ
  airConditioners: () =>
    get('/air-conditioners').then((result) => result.airConditioners),
  sendCommand: (deviceId, state) =>
    post(`/air-conditioners/${encodeURIComponent(deviceId)}/command`, state),
  enterSetupMode: (deviceId) =>
    post(`/air-conditioners/${encodeURIComponent(deviceId)}/setup-mode`),
  updateAirConditioner: (deviceId, input) =>
    patch(`/air-conditioners/${encodeURIComponent(deviceId)}`, input),
  deleteAirConditioner: (deviceId) =>
    remove(`/air-conditioners/${encodeURIComponent(deviceId)}`),
  reserveAirConditioner: (input) =>
    post('/air-conditioners/reservations', input).then((r) => r.reservation),
  otaAirConditioner: (deviceId, file) =>
    post(`/air-conditioners/${encodeURIComponent(deviceId)}/ota`, { file }),

  // ------------------------------------------------------ เซ็นเซอร์ตรวจจับคน
  occupancySensors: () =>
    get('/occupancy-sensors').then((result) => result.occupancySensors),
  reserveOccupancySensor: (input) =>
    post('/occupancy-sensors/reservations', input).then((r) => r.reservation),
  occupancySetupMode: (deviceId) =>
    post(`/occupancy-sensors/${encodeURIComponent(deviceId)}/setup-mode`),
  deleteOccupancySensor: (deviceId) =>
    remove(`/occupancy-sensors/${encodeURIComponent(deviceId)}`),
  otaOccupancySensor: (deviceId, file) =>
    post(`/occupancy-sensors/${encodeURIComponent(deviceId)}/ota`, { file }),

  // ------------------------------------------------------------ เฟิร์มแวร์
  firmwareFiles: () => get('/firmware'),

  // ----------------------------------------------------------------- ค่าไฟ
  energyMetrics: () => get('/energy/metrics'),
  energyLive: (options) => get('/energy/live', null, options),
  energySources: () => get('/energy/sources'),
  energySummary: (query, options) => get('/energy/summary', query, options),
  energyHistory: (query) => get('/energy/history', query),
  /**
   * ดาวน์โหลดไฟล์ Excel
   *
   * ต้องดึงเป็น blob เองแทนที่จะชี้ <a href> ไปตรง ๆ เพราะเส้นทางนี้ต้องมี
   * หัว Authorization ซึ่งแท็ก <a> แนบให้ไม่ได้ ชื่อไฟล์ภาษาไทยอ่านจาก
   * X-Export-Filename ที่ Backend เข้ารหัส percent-encoding มาให้
   */
  async exportEnergy(query) {
    const response = await request('GET', '/energy/export', {
      query,
      raw: true,
    });
    const encoded = response.headers.get('X-Export-Filename');
    let fileName = 'energy.xlsx';
    if (encoded) {
      try {
        fileName = decodeURIComponent(encoded);
      } catch {
        fileName = 'energy.xlsx';
      }
    }
    return {
      blob: await response.blob(),
      fileName,
      rows: Number(response.headers.get('X-Export-Rows') ?? 0),
    };
  },

  // ---------------------------------------------------------- การแจ้งเตือน
  alerts: (query, options) => get('/alerts', query, options),
  acknowledgeAlert: (id) =>
    post(`/alerts/${encodeURIComponent(id)}/acknowledge`).then((r) => r.alert),

  // ------------------------------------------------------------- ตารางเรียน
  schedules: (query) => get('/schedules', query).then((r) => r.schedules),
  /**
   * ตารางเรียนพร้อมข้อมูลภาคเรียนที่ใช้อยู่ ({ schedules, timetable })
   * Backend รุ่นก่อนไม่มีช่อง timetable หน้าเว็บใช้ข้อนี้รู้ว่าทำ "เปลี่ยนภาคเรียน" ได้ไหม
   */
  schedulesWithInfo: (query) => get('/schedules', query),
  createSchedule: (input) => post('/schedules', input).then((r) => r.schedule),
  updateSchedule: (id, input) =>
    put(`/schedules/${encodeURIComponent(id)}`, input).then((r) => r.schedule),
  deleteSchedule: (id) => remove(`/schedules/${encodeURIComponent(id)}`),
  deleteAllSchedules: () => remove('/schedules').then((r) => r.result),
  /**
   * ส่งไฟล์ Excel (.xlsx) หรือ CSV ให้ Backend อ่านและตรวจ ยังไม่บันทึกอะไร
   *
   * ส่งเป็นไฟล์ดิบ (ไม่ใช่ multipart) ตามที่ Backend รับ และแนบชื่อไฟล์ไว้ใน
   * X-File-Name แบบ percent-encoding เพราะหัว HTTP ใส่อักษรไทยตรง ๆ ไม่ได้
   * — วิธีเดียวกับแอปมือถือ (schedule_service.dart)
   */
  previewScheduleImport: (file) =>
    request('POST', '/schedules/import/preview', {
      upload: file,
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-File-Name': encodeURIComponent(file.name),
      },
    }).then((r) => r.preview),
  /**
   * บันทึกตารางจากผลตรวจ
   * ปกติแทนที่ตารางเดิมเฉพาะห้องที่อยู่ในไฟล์ ส่ง replaceAll: true เมื่อเปลี่ยน
   * ภาคเรียน เพื่อล้างตารางเดิมของทุกห้องก่อน (ทำใน transaction เดียวกัน)
   */
  commitScheduleImport: (preview, { replaceAll = false } = {}) =>
    post('/schedules/import/commit', {
      createMissingRooms: (preview.newRooms ?? []).length > 0,
      replaceAll: replaceAll === true,
      schedules: preview.schedules,
    }).then((r) => r.result),

  // ------------------------------------------------------------- ผู้ใช้งาน
  users: () => get('/users').then((r) => r.users),
  createUser: (input) => post('/users', input).then((r) => r.user),
  updateUser: (username, input) =>
    patch(`/users/${encodeURIComponent(username)}`, input).then((r) => r.user),
  deleteUser: (username) => remove(`/users/${encodeURIComponent(username)}`),

  // --------------------------------------------------------------- ตั้งค่า
  settings: () => get('/settings'),
  setAutoOffEnabled: (enabled) => patch('/settings/auto-off', { enabled }),
  setElectricityRate: (rate) => patch('/settings/rate', { rate }),
};
