import assert from 'node:assert/strict';
import test from 'node:test';

import {
  createOtp,
  hashSecret,
  isValidNewPassword,
  safeHashEquals,
} from '../src/utils/security.js';

test('OTP always contains exactly six digits', () => {
  for (let index = 0; index < 100; index += 1) {
    assert.match(createOtp(), /^\d{6}$/);
  }
});

test('secret hashes compare without exposing the original value', () => {
  const pepper = 'test-pepper-that-is-long-enough-for-tests';
  const first = hashSecret('123456', pepper);
  const same = hashSecret('123456', pepper);
  const other = hashSecret('654321', pepper);

  assert.equal(safeHashEquals(first, same), true);
  assert.equal(safeHashEquals(first, other), false);
  assert.notEqual(first, '123456');
});

test('new passwords respect the bcrypt byte limit', () => {
  assert.equal(isValidNewPassword('short'), false);
  assert.equal(isValidNewPassword('long-enough-password'), true);
  assert.equal(isValidNewPassword('ก'.repeat(30)), false);
});
