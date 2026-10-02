import { app } from './app.js';
import { assertServerConfig, config } from './config.js';
import { pool } from './db.js';
import { startAutoOffService, stopAutoOffService } from './services/auto-off.js';
import { startMqttBridge, stopMqttBridge } from './services/mqtt.js';
import {
  startMqttAccounts,
  stopMqttAccounts,
} from './services/mqtt-accounts.js';

assertServerConfig();
// ต้องลงทะเบียนก่อนต่อ Broker เพื่อให้ทันรอบ connect แรก
startMqttAccounts();
startMqttBridge();
startAutoOffService();

const server = app.listen(config.port, '0.0.0.0', () => {
  console.log(`RMUTT Save Energy API listening on port ${config.port}`);
});

async function shutdown(signal) {
  console.log(`${signal} received, shutting down...`);
  server.close(async () => {
    stopAutoOffService();
    stopMqttAccounts();
    await stopMqttBridge();
    await pool.end();
    process.exit(0);
  });
}

process.on('SIGINT', () => shutdown('SIGINT'));
process.on('SIGTERM', () => shutdown('SIGTERM'));
