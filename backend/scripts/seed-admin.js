import bcrypt from 'bcryptjs';

import { pool } from '../src/db.js';
import { isValidNewPassword } from '../src/utils/security.js';

// บนเซิร์ฟเวอร์ deploy/seed-admin.sh ส่งรหัสผ่านเข้ามาทาง stdin (--password-stdin)
// รหัสแอดมินจึงไม่ต้องค้างอยู่ใน environment ของ container หรือใน .env
const passwordFromStdin = process.argv.includes('--password-stdin');

const admin = {
  username: required('SEED_ADMIN_USERNAME'),
  password: passwordFromStdin
    ? await readPasswordFromStdin()
    : required('SEED_ADMIN_PASSWORD'),
  firstName: process.env.SEED_ADMIN_FIRST_NAME ?? '',
  lastName: process.env.SEED_ADMIN_LAST_NAME ?? '',
  email: required('SEED_ADMIN_EMAIL'),
  phone: required('SEED_ADMIN_PHONE'),
};

if (!isValidNewPassword(admin.password)) {
  throw new Error('SEED_ADMIN_PASSWORD must contain 8-72 UTF-8 bytes.');
}

try {
  const passwordHash = await bcrypt.hash(admin.password, 12);
  await pool.query(
    `INSERT INTO users
       (username, password_hash, first_name, last_name, email, phone, role)
     VALUES (?, ?, ?, ?, ?, ?, 'admin')
     ON DUPLICATE KEY UPDATE
       password_hash = VALUES(password_hash),
       first_name = VALUES(first_name),
       last_name = VALUES(last_name),
       email = VALUES(email),
       phone = VALUES(phone),
       role = 'admin',
       is_active = 1,
       token_version = token_version + 1`,
    [
      admin.username,
      passwordHash,
      admin.firstName,
      admin.lastName,
      admin.email,
      admin.phone,
    ],
  );
  console.log(`Admin account "${admin.username}" is ready.`);
} finally {
  await pool.end();
}

async function readPasswordFromStdin() {
  const chunks = [];
  for await (const chunk of process.stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf8').replace(/\r?\n$/, '');
}

function required(name) {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`${name} is required in .env`);
  }
  return value;
}
