// ล้างค่าในบอร์ดเมื่อแอดมินลบอุปกรณ์ออกจากแอป
//
// ลำดับที่ Backend ทำตอนลบ (routes/air-conditioners.js, routes/occupancy-sensors.js)
//   1. ลบแถวในฐานข้อมูล
//   2. ส่ง {"action":"unprovision"} ไปที่ topic command ของบอร์ด
//      แล้วรอให้บอร์ดตอบกลับทาง topic status ว่า {"unprovisioned":true}
//   3. ล้างข้อความ retain ของบอร์ดบน Broker
//   4. ลบบัญชี MQTT ของบอร์ด
// ต้องส่งคำสั่งก่อนลบบัญชี เพราะลบบัญชีแล้ว Broker ตัดบอร์ดออกทันที คำสั่งจะไปไม่ถึง
//
// บอร์ดที่ได้รับคำสั่งจะล้าง Wi-Fi, MQTT, ห้อง, สถานะแอร์ ใน NVS แล้วรีบูตเข้าโหมด
// ตั้งค่าบลูทูธ ถ้าบอร์ดออฟไลน์อยู่ตอนกดลบ คำสั่งจะไปไม่ถึง (ไม่ได้ส่งแบบ retain
// เพราะถ้าเพิ่มบอร์ดตัวเดิมกลับเข้ามาภายหลัง คำสั่งค้างจะล้างบอร์ดทิ้งอีกรอบ)

export const UNPROVISION_ACK_TIMEOUT_MS = 4000;

export function buildUnprovisionCommand(deviceId, { commandId, sentAt }) {
  return {
    version: 1,
    commandId,
    sentAt,
    action: 'unprovision',
    // บอร์ดตรวจซ้ำว่าตรงกับตัวเอง กันข้อความหลงมาผิด topic
    deviceId,
  };
}

/** ข้อความ status ที่บอร์ดส่งกลับมายืนยันว่าล้างค่าแล้ว */
export function isUnprovisionAck(message, deviceId) {
  return Boolean(
    message
      && typeof message === 'object'
      && message.unprovisioned === true
      && message.deviceId === deviceId,
  );
}
