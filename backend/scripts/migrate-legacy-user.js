import bcrypt from 'bcryptjs';

import { pool, withTransaction } from '../src/db.js';

const legacyTable = process.env.LEGACY_USERS_TABLE ?? 'user';
const preferredColumns = {
  username: process.env.LEGACY_USERNAME_COLUMN ?? 'Username',
  password: process.env.LEGACY_PASSWORD_COLUMN ?? 'password',
  firstName: process.env.LEGACY_FIRST_NAME_COLUMN ?? 'frist name',
  lastName: process.env.LEGACY_LAST_NAME_COLUMN ?? 'last name',
  email: process.env.LEGACY_EMAIL_COLUMN ?? 'Email',
  phone: process.env.LEGACY_PHONE_COLUMN ?? 'phone',
  role: process.env.LEGACY_ROLE_COLUMN ?? 'role',
};
const phonePrefix = process.env.LEGACY_PHONE_PREFIX ?? '';

let migrated = 0;
let skipped = 0;

try {
  const legacyRows = await pool.query(
    `SELECT * FROM ${quoteIdentifier(legacyTable)}`,
  );

  await withTransaction(async (connection) => {
    for (const row of legacyRows) {
      const username = textValue(
        pick(row, preferredColumns.username, ['username', 'user name']),
      );
      const password = textValue(
        pick(row, preferredColumns.password, ['Password', 'pass']),
      );
      const email = textValue(
        pick(row, preferredColumns.email, ['email', 'e-mail']),
      );

      if (!username || !password || !email) {
        skipped += 1;
        continue;
      }

      const passwordHash = isBcryptHash(password)
        ? password
        : await bcrypt.hash(password, 12);
      const firstName = textValue(
        pick(row, preferredColumns.firstName, [
          'first_name',
          'first name',
          'firstname',
          'frist_name',
        ]),
      );
      const lastName = textValue(
        pick(row, preferredColumns.lastName, [
          'last_name',
          'last name',
          'lastname',
        ]),
      );
      const rawPhone = textValue(
        pick(row, preferredColumns.phone, ['Phone', 'telephone']),
      );
      const phone = rawPhone && phonePrefix && !rawPhone.startsWith(phonePrefix)
        ? `${phonePrefix}${rawPhone}`
        : rawPhone;
      const role = normalizeRole(
        textValue(pick(row, preferredColumns.role, ['Role'])),
      );

      await connection.query(
        `INSERT INTO users
           (username, password_hash, first_name, last_name, email, phone, role)
         VALUES (?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE
           password_hash = VALUES(password_hash),
           first_name = VALUES(first_name),
           last_name = VALUES(last_name),
           email = VALUES(email),
           phone = VALUES(phone),
           role = VALUES(role),
           is_active = 1`,
        [username, passwordHash, firstName, lastName, email, phone, role],
      );
      migrated += 1;
    }
  });

  console.log(`Legacy migration complete: ${migrated} migrated, ${skipped} skipped.`);
  if (phonePrefix) {
    console.log(`LEGACY_PHONE_PREFIX "${phonePrefix}" was applied where needed.`);
  }
} finally {
  await pool.end();
}

function quoteIdentifier(identifier) {
  return `\`${String(identifier).replaceAll('`', '``')}\``;
}

function pick(row, preferred, aliases) {
  const candidates = [preferred, ...aliases].map(normalizeColumnName);
  const entry = Object.entries(row).find(([key]) =>
    candidates.includes(normalizeColumnName(key)),
  );
  return entry?.[1];
}

function normalizeColumnName(value) {
  return String(value).toLowerCase().replaceAll(/[\s_-]+/g, '');
}

function textValue(value) {
  return value == null ? '' : String(value).trim();
}

function isBcryptHash(value) {
  return /^\$2[aby]\$\d{2}\$/.test(value);
}

function normalizeRole(value) {
  const role = value.toLowerCase();
  if (role === 'admin' || role === 'staff') return role;
  return 'staff';
}
