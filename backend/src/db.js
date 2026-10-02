import mariadb from 'mariadb';

import { config } from './config.js';

// สร้าง Connection Pool ตอนมีการใช้งานจริงครั้งแรกเท่านั้น
// ไฟล์ที่ import เฉพาะฟังก์ชันช่วย เช่น unit test จะได้ไม่เปิดการเชื่อมต่อ
// ค้างไว้จนโปรเซสของ `node --test` ไม่ยอมจบ
let instance;

export function getPool() {
  if (!instance) {
    instance = mariadb.createPool({
      host: config.db.host,
      port: config.db.port,
      user: config.db.user,
      password: config.db.password,
      database: config.db.database,
      connectionLimit: config.db.connectionLimit,
      acquireTimeout: 10000,
      bigIntAsNumber: true,
      insertIdAsNumber: true,
    });
  }
  return instance;
}

export const pool = {
  query: (...args) => getPool().query(...args),
  batch: (...args) => getPool().batch(...args),
  getConnection: () => getPool().getConnection(),
  async end() {
    if (!instance) return;
    const current = instance;
    instance = undefined;
    await current.end();
  },
};

export async function withTransaction(callback) {
  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const result = await callback(connection);
    await connection.commit();
    return result;
  } catch (error) {
    if (connection) {
      await connection.rollback();
    }
    throw error;
  } finally {
    if (connection) {
      connection.release();
    }
  }
}
