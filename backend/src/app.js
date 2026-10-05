import cors from 'cors';
import express from 'express';
import helmet from 'helmet';

import { config } from './config.js';
import { pool } from './db.js';
import { authRouter } from './routes/auth.js';
import { bookingsRouter } from './routes/bookings.js';
import { airConditionersRouter } from './routes/air-conditioners.js';
import { alertsRouter } from './routes/alerts.js';
import { energyRouter } from './routes/energy.js';
import { firmwareRouter } from './routes/firmware.js';
import { occupancySensorsRouter } from './routes/occupancy-sensors.js';
import { publicRouter } from './routes/public.js';
import { roomsRouter } from './routes/rooms.js';
import { schedulesRouter } from './routes/schedules.js';
import { settingsRouter } from './routes/settings.js';
import { usersRouter } from './routes/users.js';
import { getMqttBridgeStatus } from './services/mqtt.js';
import {
  asyncHandler,
  errorHandler,
  notFoundHandler,
} from './utils/http.js';

export const app = express();

app.disable('x-powered-by');
// Backend อยู่หลัง Caddy เสมอเมื่อ deploy จริง ถ้าไม่บอก Express ว่าเชื่อ
// X-Forwarded-For จาก proxy หนึ่งชั้น ทุกคำขอจะดูเหมือนมาจาก IP ของ Caddy
// แล้ว rate limit ของหน้า login จะนับรวมทุกคนในตึกเป็นคนเดียว
// คนหนึ่งกรอกรหัสผิด 10 ครั้ง = ทุกคนล็อกอินไม่ได้ 15 นาที
app.set('trust proxy', config.trustProxy);
app.use(helmet());
app.use(cors(createCorsOptions()));
app.use(express.json({ limit: '256kb' }));

app.get(
  '/api/health',
  asyncHandler(async (request, response) => {
    await pool.query('SELECT 1');
    const mqtt = getMqttBridgeStatus();
    response.json({
      status: 'ok',
      service: 'rmutt-save-energy-api',
      // หน้านี้เปิดได้โดยไม่ต้องล็อกอิน บนเซิร์ฟเวอร์จริงจึงบอกแค่สถานะ
      // ไม่บอกที่อยู่ Broker หรือข้อความ error ภายในให้คนนอกเห็น
      // (deviceAuth คงไว้ให้คู่มือ deploy ใช้ตรวจว่าเปิด dynsec แล้ว)
      // ตอนพัฒนาบนเครื่องยังได้รายละเอียดครบ ให้ check_system.ps1/diagnose.ps1 ใช้
      mqtt: config.env === 'production'
        ? {
          connected: mqtt.connected,
          deviceAuth: mqtt.deviceAuth,
          topicPrefix: mqtt.topicPrefix,
        }
        : mqtt,
    });
  }),
);

app.use('/api/auth', authRouter);
app.use('/api/public', publicRouter);
app.use('/api/rooms', roomsRouter);
app.use('/api/schedules', schedulesRouter);
app.use('/api/bookings', bookingsRouter);
app.use('/api/air-conditioners', airConditionersRouter);
app.use('/api/occupancy-sensors', occupancySensorsRouter);
app.use('/api/energy', energyRouter);
app.use('/api/firmware', firmwareRouter);
app.use('/api/alerts', alertsRouter);
app.use('/api/settings', settingsRouter);
app.use('/api/users', usersRouter);

app.use(notFoundHandler);
app.use(errorHandler);

function createCorsOptions() {
  if (config.appOrigin === '*') {
    return {};
  }

  const allowed = new Set(
    config.appOrigin
      .split(',')
      .map((origin) => origin.trim())
      .filter(Boolean),
  );

  return {
    origin(origin, callback) {
      if (!origin || allowed.has(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error('Origin is not allowed by CORS'));
    },
  };
}
