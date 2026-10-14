import { config } from '../config.js';
import { pool } from '../db.js';
import {
  deriveDevicePassword,
  deviceKindOf,
  ensureBackendCommands,
  ensureDeviceCommands,
  isHarmlessDynsecError,
  removeDeviceCommands,
  repairDeviceCommands,
} from '../utils/mqtt-accounts.js';
import { dynsecRequest, onMqttConnected } from './mqtt.js';

// จัดการบัญชี MQTT ของบอร์ดบน Mosquitto Dynamic Security
// ทำงานเฉพาะเมื่อ MQTT_DEVICE_AUTH=dynsec ถ้าเป็น shared ทุกฟังก์ชันไม่ทำอะไร

let unsubscribe;

export function isPerDeviceAuth() {
  return config.mqtt.deviceAuth === 'dynsec';
}

export function startMqttAccounts() {
  if (!isPerDeviceAuth() || unsubscribe) return;
  unsubscribe = onMqttConnected(() => {
    reconcileAccounts().catch((error) => {
      console.error('ตั้งค่าบัญชี MQTT ของอุปกรณ์ไม่สำเร็จ', error.message);
    });
  });
}

export function stopMqttAccounts() {
  unsubscribe?.();
  unsubscribe = undefined;
}

/**
 * ข้อมูล MQTT ที่ส่งให้บอร์ดตอน provisioning
 *
 * โหมด dynsec: username = Device ID, password = HMAC ของ Device ID
 * และสร้างบัญชีบน Broker ให้เสร็จก่อนตอบ แอปจะได้ส่งเข้าบอร์ดได้ทันที
 * โหมด shared: ส่งบัญชีเดียวกับ Backend แบบเดิม (ใช้ตอนพัฒนาเท่านั้น)
 */
export async function prepareDeviceCredentials(deviceId, mqttSettings) {
  if (!isPerDeviceAuth()) {
    return {
      mqttUsername: mqttSettings.mqttUsername,
      mqttPassword: mqttSettings.mqttPassword,
    };
  }
  const password = deriveDevicePassword(config.mqtt.deviceSecret, deviceId);
  // repair: บัญชีเก่าอาจตั้งรหัสจาก MQTT_DEVICE_SECRET ชุดก่อน ทำให้ตรงก่อน
  // ส่งให้บอร์ด (บอร์ดที่ออนไลน์อยู่จะหลุดหนึ่งครั้งแล้วต่อกลับเองใน 3 วินาที)
  await ensureDeviceAccount(deviceId, { password, repair: true });
  return { mqttUsername: deviceId, mqttPassword: password };
}

export async function ensureDeviceAccount(
  deviceId,
  {
    password = deriveDevicePassword(config.mqtt.deviceSecret, deviceId),
    repair = false,
  } = {},
) {
  const kind = deviceKindOf(deviceId);
  if (!kind) throw new Error(`Unknown device id: ${deviceId}`);
  const topicPrefix = kind === 'air'
    ? config.mqtt.topicPrefix
    : config.mqtt.occupancyTopicPrefix;
  await runCommands(
    ensureDeviceCommands({ kind, topicPrefix, deviceId, password }),
  );
  if (repair) {
    await runCommands(repairDeviceCommands({ kind, deviceId, password }));
  }
}

/** ลบบัญชีของบอร์ดที่ถูกถอดออก คืน true ถ้าลบได้หรือไม่มีอยู่แล้ว */
export async function removeDeviceAccount(deviceId) {
  if (!isPerDeviceAuth()) return true;
  try {
    await runCommands(removeDeviceCommands(deviceId));
    return true;
  } catch (error) {
    console.error(`ลบบัญชี MQTT ของ ${deviceId} ไม่สำเร็จ`, error.message);
    return false;
  }
}

/**
 * ทุกครั้งที่ต่อ Broker ได้: ให้สิทธิ์ Backend เอง แล้วสร้างบัญชีของบอร์ด
 * ทุกตัวในฐานข้อมูลที่ยังไม่ถูกถอด ถ้าไฟล์ dynamic-security.json หายหรือ
 * ย้ายเซิร์ฟเวอร์ บอร์ดเดิมจะกลับมาต่อได้เองโดยไม่ต้องตั้งค่าใหม่
 */
export async function reconcileAccounts() {
  await runCommands(
    ensureBackendCommands({
      username: config.mqtt.username,
      prefixes: [config.mqtt.topicPrefix, config.mqtt.occupancyTopicPrefix],
    }),
  );

  const rows = await pool.query(
    `SELECT device_id FROM air_conditioners
     UNION
     SELECT device_id FROM occupancy_sensors`,
  );
  let ok = 0;
  for (const row of rows) {
    try {
      await ensureDeviceAccount(row.device_id);
      ok += 1;
    } catch (error) {
      console.error(`บัญชี MQTT ของ ${row.device_id} ไม่สำเร็จ`, error.message);
    }
  }
  console.log(`MQTT per-device accounts ready: ${ok}/${rows.length} devices`);
}

async function runCommands(commands) {
  const results = await dynsecRequest(commands);
  const failures = results.filter(
    (result, index) => !isHarmlessDynsecError(
      commands[index].command,
      result?.error,
    ),
  );
  if (failures.length > 0) {
    const detail = failures
      .map((item) => `${item.command}: ${item.error}`)
      .join('; ');
    const error = new Error(`Mosquitto Dynamic Security: ${detail}`);
    error.statusCode = 502;
    throw error;
  }
  return results;
}
