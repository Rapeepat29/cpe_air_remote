import assert from 'node:assert/strict';
import test from 'node:test';

import { publicUser } from '../src/utils/user.js';

test('public user uses username without exposing an internal numeric id', () => {
  const result = publicUser({
    id: 42,
    username: 'Rapeepat',
    first_name: 'Rapeepat',
    last_name: 'Sangklueab',
    email: 'user@example.com',
    phone: '0812345678',
    role: 'admin',
  });

  assert.deepEqual(result, {
    username: 'Rapeepat',
    firstName: 'Rapeepat',
    lastName: 'Sangklueab',
    email: 'user@example.com',
    phone: '0812345678',
    role: 'admin',
  });
  assert.equal('id' in result, false);
});

test('เบอร์โทรที่ยังไม่ได้กรอกกลายเป็นข้อความว่าง ไม่ใช่ null', () => {
  const result = publicUser({
    username: 'staff01',
    first_name: 'Staff',
    last_name: 'One',
    email: 'staff@example.com',
    phone: null,
    role: 'staff',
  });

  assert.equal(result.phone, '');
});
