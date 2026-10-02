// บัญชี MQTT แยกรายอุปกรณ์ (Mosquitto Dynamic Security)
//
// เดิมทุกบอร์ดใช้ user เดียวกันที่มีสิทธิ์ rmutt/# ทั้งหมด ถ้าใครถอดบอร์ด
// ตัวหนึ่งออกจากฝ้าแล้วอ่านรหัสใน flash ได้ ก็สั่งแอร์ได้ทั้งอาคาร
//
// แบบใหม่ บอร์ดแต่ละตัวมี username = Device ID และมีสิทธิ์เฉพาะ topic ของ
// ตัวเองเท่านั้น รหัสผ่านคำนวณจาก HMAC(MQTT_DEVICE_SECRET, Device ID)
// จึงไม่ต้องเก็บรหัสไว้ในฐานข้อมูล และตั้งค่าบอร์ดซ้ำกี่ครั้งก็ได้รหัสเดิม
// (บอร์ดที่ออนไลน์อยู่จะไม่หลุดเพราะรหัสถูกเปลี่ยนกลางทาง)
//
// ไฟล์นี้เป็นฟังก์ชันบริสุทธิ์ทั้งหมด ตัวที่คุยกับ Broker จริงอยู่ที่
// services/mqtt-accounts.js

import crypto from 'node:crypto';

export const DEVICE_AUTH_MODES = ['shared', 'dynsec'];

export const BACKEND_ROLE = 'rmutt-backend';

export const DEVICE_KINDS = {
  air: {
    pattern: /^ESP32-[0-9A-F]{12}$/,
    clientIdPrefix: 'rmutt-',
    publish: ['state', 'status', 'provision', 'provision-ack', 'history'],
    subscribe: ['command', 'provision-ack', 'schedule-status', 'history-ack'],
  },
  occupancy: {
    pattern: /^OCC32-[0-9A-F]{12}$/,
    clientIdPrefix: 'rmutt-occ-',
    publish: ['status', 'provision', 'provision-ack'],
    subscribe: ['command', 'provision-ack'],
  },
};

export function normalizeDeviceAuthMode(value) {
  const mode = String(value ?? '').trim().toLowerCase();
  return DEVICE_AUTH_MODES.includes(mode) ? mode : 'shared';
}

/**
 * รหัสผ่าน MQTT ของบอร์ดหนึ่งตัว คำนวณซ้ำได้เสมอจากความลับของเซิร์ฟเวอร์
 * ยาว 32 ตัว (ตัวอักษร base64url) พอดีกับที่ NVS ของ ESP32 เก็บได้สบาย ๆ
 */
export function deriveDevicePassword(secret, deviceId) {
  if (!secret) throw new Error('MQTT_DEVICE_SECRET is required');
  return crypto
    .createHmac('sha256', secret)
    .update(`mqtt-device:${String(deviceId).trim().toUpperCase()}`)
    .digest('base64url')
    .slice(0, 32);
}

export function deviceKindOf(deviceId) {
  const id = String(deviceId ?? '').trim().toUpperCase();
  for (const [kind, spec] of Object.entries(DEVICE_KINDS)) {
    if (spec.pattern.test(id)) return kind;
  }
  return null;
}

export function deviceRoleName(deviceId) {
  return `device-${String(deviceId).trim().toUpperCase()}`;
}

/**
 * ACL ของบอร์ดหนึ่งตัว: publish ได้เฉพาะ topic ที่บอร์ดส่งเอง
 * และ subscribe ได้เฉพาะ topic ที่ Backend ส่งหาบอร์ดนั้น
 * topic อื่นทั้งหมดถูกปฏิเสธโดยค่าเริ่มต้นของ Dynamic Security
 */
export function deviceAcls({ kind, topicPrefix, deviceId }) {
  const spec = DEVICE_KINDS[kind];
  if (!spec) throw new Error(`Unknown device kind: ${kind}`);
  const base = `${String(topicPrefix).replace(/\/+$/, '')}/${deviceId}`;
  return [
    ...spec.publish.map((suffix) => ({
      acltype: 'publishClientSend',
      topic: `${base}/${suffix}`,
      allow: true,
    })),
    ...spec.subscribe.map((suffix) => ({
      acltype: 'subscribeLiteral',
      topic: `${base}/${suffix}`,
      allow: true,
    })),
  ];
}

export function backendAcls(prefixes) {
  const acls = [];
  for (const prefix of prefixes) {
    const topic = `${String(prefix).replace(/\/+$/, '')}/#`;
    acls.push(
      { acltype: 'publishClientSend', topic, allow: true },
      { acltype: 'subscribePattern', topic, allow: true },
    );
  }
  return acls;
}

/**
 * ชุดคำสั่งสร้างบัญชีของบอร์ด ส่งซ้ำได้ ถ้ามีอยู่แล้วจะได้ error
 * "already exists" กลับมา ซึ่งฝั่ง service ถือว่าไม่เป็นไร
 *
 * ชุดนี้ไม่แตะบัญชีที่มีอยู่แล้ว เพราะ Dynamic Security จะเตะบอร์ดที่ออนไลน์
 * อยู่ให้หลุดทันทีเมื่อมีการ setClientPassword / setClientId
 */
export function ensureDeviceCommands({
  kind,
  topicPrefix,
  deviceId,
  password,
}) {
  const spec = DEVICE_KINDS[kind];
  const rolename = deviceRoleName(deviceId);
  const acls = deviceAcls({ kind, topicPrefix, deviceId });
  return [
    {
      command: 'createRole',
      rolename,
      textname: `${kind} ${deviceId}`,
      acls,
    },
    // role ที่มีอยู่แล้วจาก Backend รุ่นก่อนอาจมี ACL ไม่ครบ เติมให้ครบทุกครั้ง
    // (ACL ที่มีอยู่แล้วตอบ error "already exists" และไม่เตะใครหลุด)
    ...acls.map((acl) => ({
      command: 'addRoleACL',
      rolename,
      ...acl,
    })),
    {
      command: 'createClient',
      username: deviceId,
      password,
      clientid: `${spec.clientIdPrefix}${deviceId}`,
      textname: `${kind} ${deviceId}`,
      roles: [{ rolename }],
    },
  ];
}

/**
 * ซ่อมบัญชีที่มีอยู่แล้วให้ตรงกับที่ควรเป็น (รหัสผ่าน client id และ role)
 * ใช้ตอนจองช่องตั้งค่าบอร์ดเท่านั้น เพราะบอร์ดจะถูกเตะให้ต่อใหม่หนึ่งครั้ง
 */
export function repairDeviceCommands({ kind, deviceId, password }) {
  const spec = DEVICE_KINDS[kind];
  return [
    { command: 'setClientPassword', username: deviceId, password },
    {
      command: 'setClientId',
      username: deviceId,
      clientid: `${spec.clientIdPrefix}${deviceId}`,
    },
    {
      command: 'addClientRole',
      username: deviceId,
      rolename: deviceRoleName(deviceId),
    },
    { command: 'enableClient', username: deviceId },
  ];
}

export function removeDeviceCommands(deviceId) {
  return [
    { command: 'deleteClient', username: deviceId },
    { command: 'deleteRole', rolename: deviceRoleName(deviceId) },
  ];
}

export function ensureBackendCommands({ username, prefixes }) {
  const acls = backendAcls(prefixes);
  return [
    {
      command: 'createRole',
      rolename: BACKEND_ROLE,
      textname: 'RMUTT backend',
      acls,
    },
    ...acls.map((acl) => ({
      command: 'addRoleACL',
      rolename: BACKEND_ROLE,
      ...acl,
    })),
    { command: 'addClientRole', username, rolename: BACKEND_ROLE },
  ];
}

/** error ที่ถือว่าสำเร็จ เพราะสิ่งที่ต้องการมีอยู่แล้วหรือไม่มีอยู่แล้ว */
export function isHarmlessDynsecError(command, error) {
  if (!error) return true;
  const text = String(error).toLowerCase();
  if (text.includes('already exists')) return true;
  if (text.includes('already has') || text.includes('already in')) return true;
  // Mosquitto 2.0.x ตอบ addClientRole ที่ผูกไว้แล้วว่า "Internal error"
  // (ทดสอบกับ 2.0.18) คำสั่งนี้ไม่มีผลข้างเคียงอื่น จึงถือว่าผูกอยู่แล้ว
  if (command === 'addClientRole' && text === 'internal error') return true;
  if (
    (command === 'deleteClient' || command === 'deleteRole')
    && text.includes('not found')
  ) {
    return true;
  }
  return false;
}
