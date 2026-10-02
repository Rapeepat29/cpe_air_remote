// Topic ที่ Backend/ESP32 ส่งแบบ retain ไว้บน Broker
// ต้องล้างทั้งหมดเมื่อนำอุปกรณ์ออกจากระบบ ไม่งั้นข้อความเก่าจะค้างอยู่บน
// Broker และย้อนกลับมาเมื่อเพิ่มอุปกรณ์รหัสเดิมอีกครั้ง

export const AIR_RETAINED_SUFFIXES = Object.freeze([
  'command',
  'state',
  'status',
  'provision',
  'provision-ack',
  'schedule-status',
]);

export const OCCUPANCY_RETAINED_SUFFIXES = Object.freeze([
  'command',
  'status',
  'provision',
  'provision-ack',
]);

export function retainedTopics(prefix, deviceId, suffixes) {
  const base = String(prefix ?? '').replace(/\/+$/, '');
  const device = String(deviceId ?? '').trim();
  if (!base || !device) return [];
  return suffixes.map((suffix) => `${base}/${device}/${suffix}`);
}
