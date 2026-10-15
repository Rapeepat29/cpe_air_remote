import { ApiError } from './http.js';

const usernamePattern = /^[A-Za-z0-9][A-Za-z0-9._-]{2,29}$/;
const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
// เบอร์ไทย: มือถือ 10 หลัก (06/08/09) หรือเบอร์บ้าน 9 หลัก (02, 03x ...)
const phonePattern = /^0\d{8,9}$/;
const roles = new Set(['admin', 'staff']);

export function publicUser(row) {
  return {
    username: row.username,
    firstName: row.first_name ?? '',
    lastName: row.last_name ?? '',
    email: row.email ?? '',
    phone: row.phone ?? '',
    role: row.role ?? 'staff',
  };
}

export function managedUser(row) {
  return {
    ...publicUser(row),
    isActive: Boolean(row.is_active),
    lastLoginAt: toIsoString(row.last_login_at),
    createdAt: toIsoString(row.created_at),
  };
}

export function validateUsername(value) {
  const username = cleanString(value, 30);
  if (!usernamePattern.test(username)) {
    throw new ApiError(
      400,
      'Username ต้องยาว 3–30 ตัว ใช้ได้เฉพาะ A–Z, 0–9, จุด, ขีดกลางและขีดล่าง',
    );
  }
  return username;
}

export function validateRole(value) {
  const role = cleanString(value, 20).toLowerCase();
  if (!roles.has(role)) {
    throw new ApiError(400, 'สิทธิ์ต้องเป็น admin หรือ staff เท่านั้น');
  }
  return role;
}

export function validateNewUserInput(body) {
  const source = body && typeof body === 'object' ? body : {};
  const username = validateUsername(source.username);
  const role = validateRole(source.role ?? 'staff');
  const firstName = cleanString(source.firstName, 30);
  const lastName = cleanString(source.lastName, 30);
  const email = cleanString(source.email, 100).toLowerCase();
  const phone = normalizePhone(source.phone);
  const password = typeof source.password === 'string' ? source.password : '';

  if (firstName.length < 1) {
    throw new ApiError(400, 'กรุณากรอกชื่อ');
  }
  if (lastName.length < 1) {
    throw new ApiError(400, 'กรุณากรอกนามสกุล');
  }
  if (!emailPattern.test(email)) {
    throw new ApiError(400, 'รูปแบบอีเมลไม่ถูกต้อง');
  }
  if (phone && !phonePattern.test(phone)) {
    throw new ApiError(400, 'เบอร์โทรต้องเป็นตัวเลข 9–10 หลัก ขึ้นต้นด้วย 0');
  }

  return {
    username,
    role,
    firstName,
    lastName,
    email,
    phone: phone || null,
    password,
  };
}

export function validateUserUpdate(body) {
  const source = body && typeof body === 'object' ? body : {};
  const update = {};

  if (source.role !== undefined) {
    update.role = validateRole(source.role);
  }
  if (source.isActive !== undefined) {
    if (typeof source.isActive !== 'boolean') {
      throw new ApiError(400, 'สถานะบัญชีต้องเป็น true หรือ false');
    }
    update.isActive = source.isActive;
  }

  if (Object.keys(update).length === 0) {
    throw new ApiError(400, 'ไม่มีข้อมูลที่ต้องแก้ไข');
  }
  return update;
}

/**
 * ข้อมูลที่เจ้าของบัญชีแก้ไขเองได้จากหน้า `ตั้งค่าบัญชีผู้ใช้`
 * ตั้งใจไม่ให้แก้ `role` หรือ `isActive` ที่นี่ ต้องผ่านหน้าจัดการสิทธิ์เท่านั้น
 */
export function validateProfileUpdate(body) {
  const source = body && typeof body === 'object' ? body : {};
  const firstName = cleanString(source.firstName, 30);
  const lastName = cleanString(source.lastName, 30);
  const email = cleanString(source.email, 100).toLowerCase();
  const phone = normalizePhone(source.phone);

  if (firstName.length < 1) {
    throw new ApiError(400, 'กรุณากรอกชื่อ');
  }
  if (lastName.length < 1) {
    throw new ApiError(400, 'กรุณากรอกนามสกุล');
  }
  if (!emailPattern.test(email)) {
    throw new ApiError(400, 'รูปแบบอีเมลไม่ถูกต้อง');
  }
  if (phone && !phonePattern.test(phone)) {
    throw new ApiError(400, 'เบอร์โทรต้องเป็นตัวเลข 9–10 หลัก ขึ้นต้นด้วย 0');
  }

  return { firstName, lastName, email, phone: phone || null };
}

/**
 * แปลงเบอร์ที่พิมพ์มาให้เหลือแต่ตัวเลข เพื่อเก็บใน VARCHAR(10)
 * เช่น `081-234-5678`, `081 234 5678`, `+66 81 234 5678` -> `0812345678`
 */
export function normalizePhone(value) {
  if (typeof value !== 'string') return '';
  const digits = value.replace(/[\s\-().]/g, '');
  if (/^\+?66\d{8,9}$/.test(digits)) {
    return `0${digits.replace(/^\+?66/, '')}`;
  }
  return digits.slice(0, 20);
}

function toIsoString(value) {
  if (value == null) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date.toISOString();
}

function cleanString(value, maxLength) {
  if (typeof value !== 'string') return '';
  return value.trim().slice(0, maxLength);
}
