import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';

// เปลี่ยนอีเมลต้องยืนยันด้วยรหัสผ่านปัจจุบัน (OTP ลืมรหัสผ่านถูกส่งไปที่อีเมลนี้)
// เทสต์นี้ไม่ต่อฐานข้อมูลจริง แต่แทน pool.query ด้วยตัวปลอมที่จำผู้ใช้หนึ่งคนไว้

process.env.JWT_SECRET = 'test-jwt-secret-'.padEnd(48, 'x');
process.env.OTP_PEPPER = 'test-otp-pepper-'.padEnd(48, 'y');

const bcrypt = (await import('bcryptjs')).default;
const jwt = (await import('jsonwebtoken')).default;
const { pool } = await import('../src/db.js');
const { app } = await import('../src/app.js');

const passwordHash = await bcrypt.hash('correct-password', 4);
let user;
let server;
let baseUrl;
let token;

before(async () => {
  user = {
    username: 'alice',
    first_name: 'Alice',
    last_name: 'Example',
    email: 'alice@example.com',
    phone: null,
    role: 'staff',
    token_version: 1,
    password_hash: passwordHash,
  };

  pool.query = async (sql, params = []) => {
    if (/UPDATE users/.test(sql)) {
      user = {
        ...user,
        first_name: params[0],
        last_name: params[1],
        email: params[2],
        phone: params[3],
      };
      return { affectedRows: 1 };
    }
    if (/FROM users/.test(sql)) return [user];
    throw new Error(`unexpected SQL: ${sql}`);
  };

  server = app.listen(0, '127.0.0.1');
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
  token = jwt.sign({ role: 'staff', ver: 1 }, process.env.JWT_SECRET, {
    algorithm: 'HS256',
    subject: 'alice',
    expiresIn: '1h',
    issuer: 'rmutt-save-energy-api',
    audience: 'rmutt-save-energy-app',
  });
});

after(() => {
  server?.close();
});

async function patchProfile(body) {
  const response = await fetch(`${baseUrl}/api/auth/me`, {
    method: 'PATCH',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${token}`,
    },
    body: JSON.stringify({
      firstName: 'Alice',
      lastName: 'Example',
      phone: '',
      ...body,
    }),
  });
  return { status: response.status, body: await response.json() };
}

test('แก้ชื่อโดยไม่เปลี่ยนอีเมล ไม่ต้องใส่รหัสผ่าน', async () => {
  const result = await patchProfile({
    firstName: 'Alicia',
    email: 'ALICE@example.com',
  });
  assert.equal(result.status, 200);
  assert.equal(result.body.user.firstName, 'Alicia');
});

test('เปลี่ยนอีเมลโดยไม่ใส่รหัสผ่าน ถูกปฏิเสธ', async () => {
  const result = await patchProfile({ email: 'attacker@example.com' });
  assert.equal(result.status, 400);
  assert.equal(user.email, 'alice@example.com');
});

test('เปลี่ยนอีเมลด้วยรหัสผ่านผิด ถูกปฏิเสธ', async () => {
  const result = await patchProfile({
    email: 'attacker@example.com',
    currentPassword: 'wrong-password',
  });
  assert.equal(result.status, 400);
  assert.equal(user.email, 'alice@example.com');
});

test('เปลี่ยนอีเมลด้วยรหัสผ่านถูกต้อง สำเร็จ', async () => {
  const result = await patchProfile({
    email: 'alice.new@example.com',
    currentPassword: 'correct-password',
  });
  assert.equal(result.status, 200);
  assert.equal(user.email, 'alice.new@example.com');
});
