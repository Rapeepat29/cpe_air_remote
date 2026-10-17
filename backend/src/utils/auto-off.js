// กติกาปิดแอร์อัตโนมัติเมื่อไม่มีคนอยู่ในห้อง
//
// ไฟล์นี้เป็นฟังก์ชันบริสุทธิ์ล้วน ไม่แตะฐานข้อมูลและไม่แตะ MQTT
// ตัวที่ลงมือทำจริงคือ services/auto-off.js ซึ่งเรียกฟังก์ชันในนี้เพื่อตัดสินใจ

/** ไม่มีคนนานเท่านี้นอกคาบเรียน = สั่งปิด */
export const AUTO_OFF_IDLE_SECONDS = 300;

/** ระหว่างมีคาบเรียนให้เวลานานกว่า เผื่อพักเบรกแล้วกลับเข้ามา */
export const AUTO_OFF_IN_CLASS_SECONDS = 900;

/** โหมดทดสอบ: ไม่มีคนนานเท่านี้นอกคาบเรียน (30 วินาที) = สั่งปิด */
export const AUTO_OFF_TEST_IDLE_SECONDS = 30;

/** โหมดทดสอบ: ระหว่างมีคาบเรียน (1 นาที) = สั่งปิด */
export const AUTO_OFF_TEST_IN_CLASS_SECONDS = 60;

/** ยิง IR ซ้ำทุกกี่วินาที ถ้าแอร์ยังกินไฟอยู่ */
export const AUTO_OFF_RETRY_SECONDS = 20;

/** ยิงซ้ำได้สูงสุดกี่ครั้งก่อนยอมแพ้แล้วแจ้งเตือน */
export const AUTO_OFF_MAX_ATTEMPTS = 5;

/**
 * ผลการตัดสินใจที่เป็นไปได้
 *
 * - `idle`      ไม่มีอะไรต้องทำ และไม่มีนาฬิกาเดินอยู่
 * - `start`     เริ่มนับถอยหลัง
 * - `wait`      นับถอยหลังอยู่ ยังไม่ถึงเวลา หรือเพิ่งยิงไปแล้วรอดูผล
 * - `fire`      ถึงเวลาแล้ว ให้ยิง IR ปิดแอร์
 * - `succeeded` แอร์หยุดกินไฟหลังจากที่เราสั่งปิด ถือว่าสำเร็จ
 * - `giveUp`    ยิงครบจำนวนแล้วแอร์ยังทำงาน ต้องแจ้งคน
 * - `cancel`    เงื่อนไขหมดไป (มีคนเข้ามา / เซ็นเซอร์ตาย / ปิดฟีเจอร์)
 */
export function decideAutoOff({
  device,
  occupancy,
  withinClass,
  testMode = false,
  now,
}) {
  const current = now instanceof Date ? now : new Date(now);
  const counting = device?.autoOffDeadlineAt != null;
  const attempts = Number(device?.autoOffAttempts ?? 0);

  const sensorUsable = occupancy?.hasSensor === true
    && occupancy?.online === true
    && occupancy?.radarAvailable === true;

  // ไม่มีเซ็นเซอร์ที่เชื่อถือได้ = ไม่รู้ว่ามีคนไหม จึงไม่ปิดให้เด็ดขาด
  if (device?.autoOffEnabled !== true || !sensorUsable) {
    return counting
      ? { action: 'cancel', reason: sensorUsable ? 'disabled' : 'noSensor' }
      : { action: 'idle', reason: sensorUsable ? 'disabled' : 'noSensor' };
  }

  // PZEM ต้องอ่านค่าได้ ไม่งั้นเราตรวจไม่ได้ว่าแอร์หยุดจริงหรือยัง
  if (device?.pzemAvailable !== true) {
    return counting
      ? { action: 'cancel', reason: 'noPzem' }
      : { action: 'idle', reason: 'noPzem' };
  }

  if (occupancy.occupied === true) {
    return counting
      ? { action: 'cancel', reason: 'occupied' }
      : { action: 'idle', reason: 'occupied' };
  }

  if (device?.acRunning !== true) {
    if (counting && attempts > 0) {
      return { action: 'succeeded', reason: 'powerDropped', attempts };
    }
    return counting
      ? { action: 'cancel', reason: 'notRunning' }
      : { action: 'idle', reason: 'notRunning' };
  }

  // ถึงตรงนี้: แอร์ทำงานอยู่ ห้องว่าง เซ็นเซอร์เชื่อถือได้
  if (!counting) {
    const isTest = testMode === true;
    const graceSeconds = withinClass === true
      ? (isTest ? AUTO_OFF_TEST_IN_CLASS_SECONDS : AUTO_OFF_IN_CLASS_SECONDS)
      : (isTest ? AUTO_OFF_TEST_IDLE_SECONDS : AUTO_OFF_IDLE_SECONDS);
    return {
      action: 'start',
      reason: 'emptyRoom',
      graceSeconds,
      withinClass: withinClass === true,
      testMode: isTest,
      deadlineAt: new Date(current.getTime() + graceSeconds * 1000),
    };
  }

  const deadline = toDate(device.autoOffDeadlineAt);
  if (deadline == null) {
    return { action: 'cancel', reason: 'badDeadline' };
  }

  if (current.getTime() < deadline.getTime()) {
    return {
      action: 'wait',
      reason: 'countdown',
      secondsRemaining: secondsBetween(current, deadline),
    };
  }

  if (attempts >= AUTO_OFF_MAX_ATTEMPTS) {
    return { action: 'giveUp', reason: 'stillRunning', attempts };
  }

  const lastAttempt = toDate(device.autoOffLastAttemptAt);
  if (lastAttempt != null) {
    const elapsed = (current.getTime() - lastAttempt.getTime()) / 1000;
    if (elapsed < AUTO_OFF_RETRY_SECONDS) {
      return {
        action: 'wait',
        reason: 'retryCooldown',
        secondsRemaining: Math.ceil(AUTO_OFF_RETRY_SECONDS - elapsed),
      };
    }
  }

  return { action: 'fire', reason: 'deadlinePassed', attempt: attempts + 1 };
}

/**
 * วินาทีที่เหลือก่อนระบบจะสั่งปิด ใช้แสดงนาฬิกานับถอยหลังในแอป
 * คืน null เมื่อไม่มีนาฬิกาเดินอยู่
 */
export function autoOffSecondsRemaining(device, now = new Date()) {
  const deadline = toDate(device?.autoOffDeadlineAt);
  if (deadline == null) return null;
  const current = now instanceof Date ? now : new Date(now);
  return Math.max(0, secondsBetween(current, deadline));
}

/**
 * สถานะที่ส่งให้แอปแสดงผล
 */
export function autoOffPhase(device, now = new Date()) {
  if (device?.autoOffDeadlineAt == null) return 'idle';
  if (Number(device?.autoOffAttempts ?? 0) > 0) return 'commanding';
  const remaining = autoOffSecondsRemaining(device, now);
  return remaining != null && remaining > 0 ? 'counting' : 'commanding';
}

function secondsBetween(from, to) {
  return Math.ceil((to.getTime() - from.getTime()) / 1000);
}

function toDate(value) {
  if (value == null) return null;
  const date = value instanceof Date ? value : new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}
