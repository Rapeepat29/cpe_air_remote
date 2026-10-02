import assert from 'node:assert/strict';
import test from 'node:test';

import {
  managedUser,
  validateNewUserInput,
  validateRole,
  validateUserUpdate,
  validateUsername,
} from '../src/utils/user.js';

test('managed user exposes account status without the password hash', () => {
  const result = managedUser({
    username: 'somchai',
    password_hash: '$2b$12$secret',
    first_name: 'Somchai',
    last_name: 'Jaidee',
    email: 'somchai@example.com',
    phone: '0800000000',
    role: 'staff',
    is_active: 1,
    last_login_at: '2026-08-19T03:00:00.000Z',
    created_at: '2026-08-01T03:00:00.000Z',
  });

  assert.equal(result.username, 'somchai');
  assert.equal(result.role, 'staff');
  assert.equal(result.isActive, true);
  assert.equal(result.phone, '0800000000');
  assert.equal(result.lastLoginAt, '2026-08-19T03:00:00.000Z');
  assert.equal('password_hash' in result, false);
  assert.equal('passwordHash' in result, false);
});

test('managed user keeps null dates as null instead of Invalid Date', () => {
  const result = managedUser({
    username: 'staff01',
    email: 'staff01@example.com',
    role: 'staff',
    is_active: 0,
    last_login_at: null,
    created_at: null,
  });

  assert.equal(result.lastLoginAt, null);
  assert.equal(result.createdAt, null);
  assert.equal(result.isActive, false);
});

test('only admin and staff are accepted as roles', () => {
  assert.equal(validateRole('ADMIN'), 'admin');
  assert.equal(validateRole(' staff '), 'staff');
  assert.throws(() => validateRole('superuser'), /admin หรือ staff/);
  assert.throws(() => validateRole(''), /admin หรือ staff/);
});

test('username rejects path traversal and short values', () => {
  assert.equal(validateUsername('rapeepat.s'), 'rapeepat.s');
  assert.throws(() => validateUsername('../admin'), /Username/);
  assert.throws(() => validateUsername('ab'), /Username/);
  assert.throws(() => validateUsername('user name'), /Username/);
});

test('new user input is normalised and validated', () => {
  const result = validateNewUserInput({
    username: 'Somsri_K',
    password: 'strongpassword',
    firstName: ' Somsri ',
    lastName: 'Kaewta',
    email: ' Somsri@Example.COM ',
    phone: '081-234-5678',
    role: 'ADMIN',
  });

  assert.deepEqual(result, {
    username: 'Somsri_K',
    role: 'admin',
    firstName: 'Somsri',
    lastName: 'Kaewta',
    email: 'somsri@example.com',
    phone: '081-234-5678',
    password: 'strongpassword',
  });
});

test('new user input defaults to staff and rejects bad email', () => {
  const result = validateNewUserInput({
    username: 'staff02',
    password: 'strongpassword',
    firstName: 'Staff',
    lastName: 'Two',
    email: 'staff02@example.com',
  });
  assert.equal(result.role, 'staff');
  assert.equal(result.phone, null);

  assert.throws(
    () => validateNewUserInput({
      username: 'staff03',
      password: 'strongpassword',
      firstName: 'Staff',
      lastName: 'Three',
      email: 'not-an-email',
    }),
    /อีเมล/,
  );
});

test('user update accepts role, status, or both, but never nothing', () => {
  assert.deepEqual(validateUserUpdate({ role: 'staff' }), { role: 'staff' });
  assert.deepEqual(validateUserUpdate({ isActive: false }), {
    isActive: false,
  });
  assert.deepEqual(
    validateUserUpdate({ role: 'admin', isActive: true }),
    { role: 'admin', isActive: true },
  );
  assert.throws(() => validateUserUpdate({}), /ไม่มีข้อมูลที่ต้องแก้ไข/);
  assert.throws(
    () => validateUserUpdate({ isActive: 'yes' }),
    /true หรือ false/,
  );
});
