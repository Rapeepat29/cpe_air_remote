import crypto from 'node:crypto';

import { config } from '../config.js';

export function createOtp() {
  return crypto.randomInt(100000, 1000000).toString();
}

export function createResetToken() {
  return crypto.randomBytes(32).toString('hex');
}

export function hashSecret(value, pepper = config.otpPepper) {
  return crypto.createHmac('sha256', pepper).update(value).digest('hex');
}

export function safeHashEquals(leftHash, rightHash) {
  const left = Buffer.from(leftHash, 'hex');
  const right = Buffer.from(rightHash, 'hex');
  return left.length === right.length && crypto.timingSafeEqual(left, right);
}

export function isValidNewPassword(password) {
  return (
    typeof password === 'string' &&
    password.length >= 8 &&
    Buffer.byteLength(password, 'utf8') <= 72
  );
}
