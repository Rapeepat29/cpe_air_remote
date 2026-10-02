// จุดเริ่มของเว็บแอป
//
// แยกออกมาจาก index.html เพราะเซิร์ฟเวอร์ตั้ง Content-Security-Policy
// ให้รันได้เฉพาะสคริปต์ที่เป็นไฟล์บนโดเมนเดียวกัน (script-src 'self')
// สคริปต์ที่ฝังในหน้า HTML จะถูกเบราว์เซอร์บล็อก ซึ่งช่วยกันการฝังโค้ดแปลกปลอม

import { startApp, startClock } from './app.js';

startClock();
startApp();
