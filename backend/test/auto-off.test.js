import assert from 'node:assert/strict';
import test from 'node:test';

import {
  AUTO_OFF_IDLE_SECONDS,
  AUTO_OFF_IN_CLASS_SECONDS,
  AUTO_OFF_MAX_ATTEMPTS,
  autoOffPhase,
  autoOffSecondsRemaining,
  decideAutoOff,
} from '../src/utils/auto-off.js';

const NOW = new Date('2026-08-21T08:00:00Z');

function device(overrides = {}) {
  return {
    autoOffEnabled: true,
    acRunning: true,
    pzemAvailable: true,
    autoOffDeadlineAt: null,
    autoOffAttempts: 0,
    autoOffLastAttemptAt: null,
    ...overrides,
  };
}

function sensor(overrides = {}) {
  return {
    hasSensor: true,
    online: true,
    radarAvailable: true,
    occupied: false,
    ...overrides,
  };
}

test('แอร์ทำงานแต่ห้องว่าง ให้เริ่มนับถอยหลัง 5 นาที', () => {
  const result = decideAutoOff({
    device: device(),
    occupancy: sensor(),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'start');
  assert.equal(result.graceSeconds, AUTO_OFF_IDLE_SECONDS);
  assert.equal(
    result.deadlineAt.toISOString(),
    '2026-08-21T08:05:00.000Z',
  );
});

test('ระหว่างมีคาบเรียนให้เวลานานกว่า เผื่อพักเบรกแล้วกลับเข้ามา', () => {
  const result = decideAutoOff({
    device: device(),
    occupancy: sensor(),
    withinClass: true,
    now: NOW,
  });

  assert.equal(result.action, 'start');
  assert.equal(result.graceSeconds, AUTO_OFF_IN_CLASS_SECONDS);
  assert.equal(result.withinClass, true);
});

test('ไม่มีเซ็นเซอร์หรือเซ็นเซอร์ไม่ตอบ จะไม่ปิดให้เด็ดขาด', () => {
  for (const broken of [
    { hasSensor: false },
    { online: false },
    { radarAvailable: false },
  ]) {
    const result = decideAutoOff({
      device: device(),
      occupancy: sensor(broken),
      withinClass: false,
      now: NOW,
    });
    assert.equal(result.action, 'idle', JSON.stringify(broken));
    assert.equal(result.reason, 'noSensor');
  }
});

test('เซ็นเซอร์ตายระหว่างนับถอยหลัง ให้ยกเลิกนาฬิกา', () => {
  const result = decideAutoOff({
    device: device({ autoOffDeadlineAt: new Date('2026-08-21T08:05:00Z') }),
    occupancy: sensor({ online: false }),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'cancel');
  assert.equal(result.reason, 'noSensor');
});

test('PZEM อ่านค่าไม่ได้ ก็ไม่ปิด เพราะเช็คไม่ได้ว่าแอร์หยุดจริงหรือยัง', () => {
  const result = decideAutoOff({
    device: device({ pzemAvailable: false }),
    occupancy: sensor(),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'idle');
  assert.equal(result.reason, 'noPzem');
});

test('มีคนเข้ามาระหว่างนับ ให้ยกเลิกทันที', () => {
  const result = decideAutoOff({
    device: device({ autoOffDeadlineAt: new Date('2026-08-21T08:05:00Z') }),
    occupancy: sensor({ occupied: true }),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'cancel');
  assert.equal(result.reason, 'occupied');
});

test('ยังไม่ครบเวลา ให้รอต่อและบอกวินาทีที่เหลือ', () => {
  const result = decideAutoOff({
    device: device({ autoOffDeadlineAt: new Date('2026-08-21T08:04:00Z') }),
    occupancy: sensor(),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'wait');
  assert.equal(result.secondsRemaining, 240);
});

test('ครบเวลาแล้วห้องยังว่าง ให้ยิงคำสั่งปิดครั้งแรก', () => {
  const result = decideAutoOff({
    device: device({ autoOffDeadlineAt: new Date('2026-08-21T07:59:00Z') }),
    occupancy: sensor(),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'fire');
  assert.equal(result.attempt, 1);
});

test('เพิ่งยิงไปไม่ถึง 20 วินาที ให้รอดูผลก่อน', () => {
  const result = decideAutoOff({
    device: device({
      autoOffDeadlineAt: new Date('2026-08-21T07:59:00Z'),
      autoOffAttempts: 1,
      autoOffLastAttemptAt: new Date('2026-08-21T07:59:55Z'),
    }),
    occupancy: sensor(),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'wait');
  assert.equal(result.reason, 'retryCooldown');
  assert.equal(result.secondsRemaining, 15);
});

test('ครบ 20 วินาทีแล้วแอร์ยังกินไฟ ให้ยิงซ้ำครั้งถัดไป', () => {
  const result = decideAutoOff({
    device: device({
      autoOffDeadlineAt: new Date('2026-08-21T07:59:00Z'),
      autoOffAttempts: 2,
      autoOffLastAttemptAt: new Date('2026-08-21T07:59:30Z'),
    }),
    occupancy: sensor(),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'fire');
  assert.equal(result.attempt, 3);
});

test('กำลังไฟตกลงหลังสั่งปิด ถือว่าปิดสำเร็จ', () => {
  const result = decideAutoOff({
    device: device({
      acRunning: false,
      autoOffDeadlineAt: new Date('2026-08-21T07:59:00Z'),
      autoOffAttempts: 2,
      autoOffLastAttemptAt: new Date('2026-08-21T07:59:30Z'),
    }),
    occupancy: sensor(),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'succeeded');
  assert.equal(result.attempts, 2);
});

test('แอร์หยุดเองก่อนที่เราจะยิง แค่ล้างนาฬิกา ไม่ใช่ความสำเร็จของระบบ', () => {
  const result = decideAutoOff({
    device: device({
      acRunning: false,
      autoOffDeadlineAt: new Date('2026-08-21T08:05:00Z'),
      autoOffAttempts: 0,
    }),
    occupancy: sensor(),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'cancel');
  assert.equal(result.reason, 'notRunning');
});

test('ยิงครบจำนวนแล้วแอร์ยังทำงาน ให้ยอมแพ้แล้วแจ้งคน', () => {
  const result = decideAutoOff({
    device: device({
      autoOffDeadlineAt: new Date('2026-08-21T07:55:00Z'),
      autoOffAttempts: AUTO_OFF_MAX_ATTEMPTS,
      autoOffLastAttemptAt: new Date('2026-08-21T07:59:00Z'),
    }),
    occupancy: sensor(),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'giveUp');
  assert.equal(result.attempts, AUTO_OFF_MAX_ATTEMPTS);
});

test('ปิดฟีเจอร์รายเครื่องแล้วต้องไม่ทำอะไรเลย', () => {
  const result = decideAutoOff({
    device: device({ autoOffEnabled: false }),
    occupancy: sensor(),
    withinClass: false,
    now: NOW,
  });

  assert.equal(result.action, 'idle');
  assert.equal(result.reason, 'disabled');
});

test('วินาทีที่เหลือกับสถานะที่ส่งให้แอปแสดงผล', () => {
  assert.equal(autoOffSecondsRemaining({ autoOffDeadlineAt: null }), null);
  assert.equal(
    autoOffSecondsRemaining(
      { autoOffDeadlineAt: new Date('2026-08-21T08:02:30Z') },
      NOW,
    ),
    150,
  );
  // เลยกำหนดแล้วต้องไม่ติดลบ
  assert.equal(
    autoOffSecondsRemaining(
      { autoOffDeadlineAt: new Date('2026-08-21T07:00:00Z') },
      NOW,
    ),
    0,
  );

  assert.equal(autoOffPhase({ autoOffDeadlineAt: null }), 'idle');
  assert.equal(
    autoOffPhase(
      { autoOffDeadlineAt: new Date('2026-08-21T08:02:00Z') },
      NOW,
    ),
    'counting',
  );
  assert.equal(
    autoOffPhase(
      {
        autoOffDeadlineAt: new Date('2026-08-21T07:59:00Z'),
        autoOffAttempts: 1,
      },
      NOW,
    ),
    'commanding',
  );
});
