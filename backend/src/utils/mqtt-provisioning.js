import { ApiError } from './http.js';

export function resolveMqttProvisioningSettings(settings) {
  // ใช้ที่อยู่สำหรับอุปกรณ์ก่อน ถ้าไม่ได้ตั้งไว้จึงใช้ที่อยู่เดียวกับ Backend
  const source = typeof settings?.deviceUrl === 'string'
    && settings.deviceUrl.trim()
    ? settings.deviceUrl
    : settings?.url;
  const rawUrl = typeof source === 'string' ? source.trim() : '';
  if (!rawUrl) {
    throw new ApiError(
      503,
      'Backend ยังไม่ได้ตั้งค่า MQTT_URL จึงยังเพิ่ม ESP32 ไม่ได้',
    );
  }

  let url;
  try {
    url = new URL(rawUrl);
  } catch {
    throw new ApiError(500, 'ค่า MQTT_URL ของ Backend ไม่ถูกต้อง');
  }
  if (url.protocol !== 'mqtt:' && url.protocol !== 'mqtts:') {
    throw new ApiError(500, 'MQTT_URL ต้องขึ้นต้นด้วย mqtt:// หรือ mqtts://');
  }

  const secure = url.protocol === 'mqtts:';
  return {
    mqttHost: url.hostname,
    mqttPort: Number(url.port || (secure ? 8883 : 1883)),
    mqttUsername: settings.username || decodeURIComponent(url.username),
    mqttPassword: settings.password || decodeURIComponent(url.password),
    mqttTls: secure,
  };
}
