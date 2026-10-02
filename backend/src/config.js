import 'dotenv/config';

import { normalizeDeviceAuthMode } from './utils/mqtt-accounts.js';

function numberFromEnv(name, fallback) {
  const value = Number.parseInt(process.env[name] ?? '', 10);
  return Number.isFinite(value) ? value : fallback;
}

// TRUST_PROXY: จำนวนชั้นของ reverse proxy ที่อยู่หน้า Backend (Caddy = 1)
// ไม่ตั้ง = false คือไม่เชื่อ X-Forwarded-For เลย เหมาะกับตอนรันตรงบนเครื่อง
function trustProxyFromEnv(name) {
  const raw = (process.env[name] ?? '').trim();
  if (raw === '' || raw.toLowerCase() === 'false') return false;
  if (/^\d+$/.test(raw)) return Number.parseInt(raw, 10);
  // ค่า true จะทำให้ใครก็ปลอม IP ได้ และ express-rate-limit จะปฏิเสธ
  if (raw.toLowerCase() === 'true') return 1;
  return raw;
}

function booleanFromEnv(name, fallback = false) {
  const value = process.env[name];
  if (value == null) return fallback;
  return value.toLowerCase() === 'true';
}

export const config = {
  env: process.env.NODE_ENV ?? 'development',
  port: numberFromEnv('PORT', 3000),
  appOrigin: process.env.APP_ORIGIN ?? '*',
  trustProxy: trustProxyFromEnv('TRUST_PROXY'),
  // โฟลเดอร์ที่เก็บไฟล์ .bin สำหรับอัปเดตบอร์ดผ่าน Wi-Fi (ใน docker = /firmware)
  firmwareDir: process.env.FIRMWARE_DIR ?? '',
  db: {
    host: process.env.DB_HOST ?? '127.0.0.1',
    port: numberFromEnv('DB_PORT', 3306),
    user: process.env.DB_USER ?? 'root',
    password: process.env.DB_PASSWORD ?? '',
    database: process.env.DB_DATABASE ?? 'test',
    connectionLimit: numberFromEnv('DB_CONNECTION_LIMIT', 5),
  },
  jwtSecret: process.env.JWT_SECRET ?? '',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '8h',
  otpPepper: process.env.OTP_PEPPER ?? '',
  otpExpiresMinutes: numberFromEnv('OTP_EXPIRES_MINUTES', 10),
  mail: {
    mode: process.env.MAIL_MODE ?? 'smtp',
    host: process.env.SMTP_HOST ?? '',
    port: numberFromEnv('SMTP_PORT', 465),
    secure: booleanFromEnv('SMTP_SECURE', true),
    user: process.env.SMTP_USER ?? '',
    pass: process.env.SMTP_PASS ?? '',
    from: process.env.SMTP_FROM ?? '',
  },
  mqtt: {
    required: booleanFromEnv('MQTT_REQUIRED', false),
    url: process.env.MQTT_URL ?? '',
    // ที่อยู่ Broker ที่ส่งให้ ESP32 ตอน provisioning
    // ต่างจาก MQTT_URL ได้ เช่น Backend คุยภายใน docker ด้วย mqtt://mqtt:1883
    // แต่ ESP32 ต้องเข้ามาจากอินเทอร์เน็ตด้วย mqtts://<โดเมน>:8883
    deviceUrl: process.env.MQTT_DEVICE_URL ?? process.env.MQTT_URL ?? '',
    username: process.env.MQTT_USERNAME ?? '',
    password: process.env.MQTT_PASSWORD ?? '',
    topicPrefix: process.env.MQTT_TOPIC_PREFIX ?? 'rmutt/ac',
    occupancyTopicPrefix:
      process.env.MQTT_OCCUPANCY_TOPIC_PREFIX ?? 'rmutt/occupancy',
    // shared = ทุกบอร์ดใช้ user เดียวกับ Backend (ใช้ตอนพัฒนาบนเครื่อง)
    // dynsec = บอร์ดแต่ละตัวมี user ของตัวเอง เห็นเฉพาะ topic ตัวเอง (ใช้จริง)
    deviceAuth: normalizeDeviceAuthMode(process.env.MQTT_DEVICE_AUTH),
    deviceSecret: process.env.MQTT_DEVICE_SECRET ?? '',
  },
};

export function assertServerConfig() {
  const missing = [];
  if (unsafeSecret(config.jwtSecret)) {
    missing.push('JWT_SECRET (generate at least 32 random characters)');
  }
  if (unsafeSecret(config.otpPepper)) {
    missing.push('OTP_PEPPER (generate a different 32-character secret)');
  }

  if (config.mail.mode === 'smtp') {
    if (!config.mail.host) missing.push('SMTP_HOST');
    if (!config.mail.user) missing.push('SMTP_USER');
    if (!config.mail.pass) missing.push('SMTP_PASS');
    if (!config.mail.from) {
      missing.push('SMTP_FROM');
    } else if (!isValidFromAddress(config.mail.from)) {
      missing.push(
        'SMTP_FROM (ต้องมีอีเมล เช่น "RMUTT Save Energy <name@gmail.com>")',
      );
    }
  }

  if (config.mqtt.required) {
    if (!config.mqtt.url) missing.push('MQTT_URL');
    if (!config.mqtt.username) missing.push('MQTT_USERNAME');
    if (!config.mqtt.password) missing.push('MQTT_PASSWORD');
  }

  if (config.mqtt.deviceAuth === 'dynsec') {
    if (unsafeSecret(config.mqtt.deviceSecret)) {
      missing.push('MQTT_DEVICE_SECRET (อย่างน้อย 32 ตัวอักษร ห้ามซ้ำกับค่าอื่น)');
    }
  } else if (config.env === 'production') {
    console.warn(
      '[config] MQTT_DEVICE_AUTH=shared: ทุกบอร์ดใช้บัญชี MQTT เดียวกัน'
        + ' ควรตั้ง MQTT_DEVICE_AUTH=dynsec เมื่อใช้งานจริง',
    );
  }

  if (missing.length > 0) {
    throw new Error(`Missing or unsafe environment settings: ${missing.join(', ')}`);
  }
}

// SMTP ส่งไม่ออกถ้าช่องผู้ส่งไม่มีที่อยู่อีเมล และ OTP จะหายเงียบ
// เพราะหน้าลืมรหัสผ่านตอบเหมือนกันทุกกรณีโดยตั้งใจ
export function isValidFromAddress(value) {
  const text = String(value ?? '').trim();
  const angle = /<([^<>\s@]+@[^<>\s@]+\.[^<>\s@]+)>\s*$/.exec(text);
  if (angle) return true;
  return /^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$/.test(text);
}

function unsafeSecret(value) {
  return value.length < 32 || /replace|change|example/i.test(value);
}
