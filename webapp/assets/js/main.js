// จุดเริ่มของเว็บแอป
//
// แยกออกมาจาก index.html เพราะเซิร์ฟเวอร์ตั้ง Content-Security-Policy
// ให้รันได้เฉพาะสคริปต์ที่เป็นไฟล์บนโดเมนเดียวกัน (script-src 'self')
// สคริปต์ที่ฝังในหน้า HTML จะถูกเบราว์เซอร์บล็อก ซึ่งช่วยกันการฝังโค้ดแปลกปลอม

import { applyPrefs } from './prefs.js';
import { startApp, startClock } from './app.js';

// ใส่ธีมและขนาดตัวอักษรก่อนวาดอะไรทั้งนั้น หน้าจอจะได้ไม่กะพริบเปลี่ยนสี
applyPrefs();
startClock();
startApp();
