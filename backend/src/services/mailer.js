import nodemailer from 'nodemailer';

import { config } from '../config.js';

let transporter;

function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host: config.mail.host,
      port: config.mail.port,
      secure: config.mail.secure,
      auth: {
        user: config.mail.user,
        pass: config.mail.pass,
      },
    });
  }
  return transporter;
}

export async function sendPasswordResetOtp({ to, displayName, otp }) {
  if (config.mail.mode === 'console') {
    console.log(`[development email] Password reset OTP for ${to}: ${otp}`);
    return;
  }

  const safeName = displayName?.trim() || 'ผู้ใช้งาน';
  await getTransporter().sendMail({
    from: config.mail.from,
    to,
    subject: 'รหัส OTP สำหรับ RMUTT Save Energy',
    text: [
      `สวัสดี ${safeName}`,
      '',
      `รหัส OTP สำหรับเปลี่ยนรหัสผ่านคือ ${otp}`,
      `รหัสนี้มีอายุ ${config.otpExpiresMinutes} นาที และใช้ได้หนึ่งครั้ง`,
      '',
      'หากคุณไม่ได้เป็นผู้ขอเปลี่ยนรหัสผ่าน กรุณาไม่ต้องดำเนินการใด ๆ',
    ].join('\n'),
    html: `
      <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;padding:24px;color:#182238">
        <h2 style="color:#16834b">RMUTT Save Energy</h2>
        <p>สวัสดี ${escapeHtml(safeName)}</p>
        <p>รหัส OTP สำหรับเปลี่ยนรหัสผ่านคือ</p>
        <div style="font-size:34px;font-weight:800;letter-spacing:8px;color:#086038;
                    background:#eaf4ed;padding:18px;text-align:center;border-radius:12px">
          ${otp}
        </div>
        <p>รหัสนี้มีอายุ ${config.otpExpiresMinutes} นาที และใช้ได้หนึ่งครั้ง</p>
        <p style="color:#6c7b73">หากคุณไม่ได้เป็นผู้ขอเปลี่ยนรหัสผ่าน กรุณาไม่ต้องดำเนินการใด ๆ</p>
      </div>
    `,
  });
}

function escapeHtml(value) {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#039;');
}
