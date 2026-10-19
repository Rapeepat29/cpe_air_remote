import os
import base64

img_dir = r"C:\Users\rapee\Documents\GitHub\cpe_air_remote\คู่มือศึกษาโปรเจค\assets\slide_parts"
b64_dict = {}
for f in sorted(os.listdir(img_dir)):
    if f.endswith('.png'):
        name = f.replace('.png', '')
        with open(os.path.join(img_dir, f), 'rb') as fp:
            b64_dict[name] = 'data:image/png;base64,' + base64.b64encode(fp.read()).decode('utf-8')

html_content = f"""<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<title>สไลด์งบประมาณและการต่อวงจร - ออกแบบสำหรับ Canva</title>
<link href="https://fonts.googleapis.com/css2?family=Kanit:wght@300;400;500;600;700&family=Sarabun:wght@400;500;600;700&family=JetBrains+Mono:wght@500;700&display=swap" rel="stylesheet">
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    background: #0b0f19;
    font-family: 'Kanit', sans-serif;
    color: #1e293b;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 30px;
    gap: 40px;
  }}
  .slide {{
    width: 1920px;
    height: 1080px;
    background: #ffffff;
    position: relative;
    overflow: hidden;
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
    page-break-after: always;
  }}

  /* Decorative Background accents */
  .deco-lines {{
    position: absolute;
    top: 30px;
    right: 40px;
    display: flex;
    flex-direction: column;
    gap: 7px;
    align-items: flex-end;
  }}
  .deco-line {{
    height: 6px;
    background: #2563eb;
    border-radius: 3px;
  }}
  .deco-bottom-left {{
    position: absolute;
    bottom: 0;
    left: 0;
    width: 150px;
    height: 55px;
    background: #1e3a8a;
    clip-path: polygon(0 100%, 100% 100%, 70% 0, 0 0);
  }}
  .deco-bottom-bar {{
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 14px;
    background: #2563eb;
  }}
  .page-num {{
    position: absolute;
    bottom: 25px;
    right: 45px;
    background: #1e3a8a;
    color: white;
    padding: 6px 22px;
    border-radius: 6px;
    font-weight: 700;
    font-size: 22px;
    transform: skewX(-12deg);
  }}

  /* Header */
  .slide-header {{
    text-align: center;
    margin-top: 50px;
    margin-bottom: 25px;
  }}
  .slide-title {{
    font-size: 52px;
    font-weight: 700;
    color: #1e3a8a;
    line-height: 1.2;
    letter-spacing: -0.5px;
  }}
  .slide-subtitle {{
    font-size: 34px;
    font-weight: 600;
    color: #2563eb;
    margin-top: 6px;
  }}

  /* Grid of 8 items */
  .grid-container {{
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    grid-template-rows: repeat(2, 1fr);
    gap: 24px 24px;
    padding: 5px 80px 0 80px;
    height: 740px;
  }}
  .card-item {{
    background: #f8fafc;
    border: 2px solid #e2e8f0;
    border-radius: 20px;
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 16px 20px;
    position: relative;
    box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.04);
  }}
  .badge-tag {{
    position: absolute;
    top: 14px;
    left: 16px;
    background: #dbeafe;
    color: #1d4ed8;
    font-size: 13px;
    font-weight: 700;
    padding: 3px 10px;
    border-radius: 12px;
  }}
  .img-box {{
    height: 165px;
    width: 100%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-top: 14px;
    margin-bottom: 10px;
  }}
  .img-box img {{
    max-height: 150px;
    max-width: 85%;
    object-fit: contain;
    filter: drop-shadow(0 6px 8px rgba(0,0,0,0.12));
  }}
  .item-name {{
    font-size: 21px;
    font-weight: 700;
    color: #1e293b;
    text-align: center;
    margin-bottom: 4px;
    line-height: 1.25;
  }}
  .item-desc {{
    font-size: 14.5px;
    color: #64748b;
    text-align: center;
    line-height: 1.35;
    margin-bottom: 12px;
    flex-grow: 1;
    font-family: 'Sarabun', sans-serif;
  }}
  .price-pill {{
    background: #ffffff;
    color: #1e3a8a;
    border: 2px dashed #3b82f6;
    font-size: 19px;
    font-weight: 700;
    padding: 5px 26px;
    border-radius: 25px;
    display: inline-flex;
    align-items: center;
    gap: 6px;
    box-shadow: 0 2px 4px rgba(59, 130, 246, 0.08);
  }}

  /* Slide 2: Diagram */
  .diagram-area {{
    padding: 10px 70px;
    height: 820px;
    position: relative;
  }}
</style>
</head>
<body>

<!-- ========================================== -->
<!-- SLIDE 1: งบประมาณรายการอุปกรณ์ (8 อุปกรณ์) -->
<!-- ========================================== -->
<div class="slide" id="slide1">
  <div class="deco-lines">
    <div class="deco-line" style="width: 150px;"></div>
    <div class="deco-line" style="width: 110px;"></div>
    <div class="deco-line" style="width: 70px;"></div>
  </div>
  <div class="deco-bottom-bar"></div>
  <div class="deco-bottom-left"></div>
  <div class="page-num">22</div>

  <div class="slide-header">
    <h1 class="slide-title">งบประมาณในการทำอุปกรณ์</h1>
    <h2 class="slide-subtitle">ควบคุมเครื่องปรับอากาศแบบ IR</h2>
  </div>

  <div class="grid-container">
    <!-- 1. Enclosure -->
    <div class="card-item">
      <span class="badge-tag">1. กล่องใส่วงจร</span>
      <div class="img-box">
        <img src="{b64_dict['enclosure']}" alt="Enclosure Box">
      </div>
      <div class="item-name">กล่องควบคุมวงจร (Enclosure)</div>
      <div class="item-desc">กล่องพลาสติก ABS สำหรับประกอบชุดอุปกรณ์ ป้องกันฝุ่นและความชื้น</div>
      <div class="price-pill">___ บาท</div>
    </div>

    <!-- 2. Power Supply -->
    <div class="card-item">
      <span class="badge-tag">2. จ่ายไฟระบบ</span>
      <div class="img-box">
        <img src="{b64_dict['power_supply']}" alt="Power Supply">
      </div>
      <div class="item-name">Power Supply 5V (DIN Rail)</div>
      <div class="item-desc">สวิตชิ่งแปลงไฟ AC 220V เป็น DC 5V สำหรับจ่ายไฟเลี้ยงบอร์ดและโมดูล</div>
      <div class="price-pill">___ บาท</div>
    </div>

    <!-- 3. ESP32 -->
    <div class="card-item" style="border-color: #3b82f6; background: #eff6ff;">
      <span class="badge-tag" style="background: #2563eb; color: white;">3. บอร์ดควบคุมหลัก</span>
      <div class="img-box">
        <img src="{b64_dict['esp32']}" alt="ESP32">
      </div>
      <div class="item-name" style="color: #1e3a8a;">ESP32 NodeMCU-32S</div>
      <div class="item-desc">ไมโครคอนโทรลเลอร์ประมวลผลหลัก รองรับการเชื่อมต่อ Wi-Fi และ Bluetooth</div>
      <div class="price-pill" style="border-color: #2563eb; color: #1e3a8a; font-weight: 700;">___ บาท</div>
    </div>

    <!-- 4. PZEM-004T -->
    <div class="card-item">
      <span class="badge-tag">4. ตรวจวัดพลังงาน</span>
      <div class="img-box">
        <img src="{b64_dict['pzem_ct']}" alt="PZEM-004T">
      </div>
      <div class="item-name">PZEM-004T + CT Sensor</div>
      <div class="item-desc">โมดูลตรวจวัดแรงดัน กระแส กำลังไฟฟ้า และพลังงานสะสม (kWh) ของแอร์ 1 เฟส</div>
      <div class="price-pill">___ บาท</div>
    </div>

    <!-- 5. Terminal Board -->
    <div class="card-item">
      <span class="badge-tag">5. ฐานขยายขาพิน</span>
      <div class="img-box">
        <img src="{b64_dict['terminal_adapter']}" alt="Terminal Board">
      </div>
      <div class="item-name">ESP32 Terminal Adapter</div>
      <div class="item-desc">บอร์ดขยายขาพินเป็นขันน็อต ช่วยให้ต่อสายไฟแน่นหนา ไม่หลุดง่าย ปลอดภัย</div>
      <div class="price-pill">___ บาท</div>
    </div>

    <!-- 6. Transistor 2N2222 -->
    <div class="card-item">
      <span class="badge-tag">6. วงจรขับสัญญาณ</span>
      <div class="img-box">
        <img src="{b64_dict['transistor_2n2222']}" alt="Transistor 2N2222">
      </div>
      <div class="item-name">Transistor 2N2222 + Resistor</div>
      <div class="item-desc">ทรานซิสเตอร์ทำหน้าที่เป็นสวิตช์และขยายกระแสขับหลอดอินฟราเรด (IR LED)</div>
      <div class="price-pill">___ บาท</div>
    </div>

    <!-- 7. IR LED -->
    <div class="card-item">
      <span class="badge-tag">7. หลอดส่งอินฟราเรด</span>
      <div class="img-box">
        <img src="{b64_dict['ir_led']}" alt="IR LED">
      </div>
      <div class="item-name">Infrared LED (940nm)</div>
      <div class="item-desc">หลอดเปล่งแสงอินฟราเรดความถี่ 38 kHz ส่งรหัสควบคุมไปยังเครื่องปรับอากาศ</div>
      <div class="price-pill">___ บาท</div>
    </div>

    <!-- 8. Status LEDs -->
    <div class="card-item">
      <span class="badge-tag">8. แสดงสถานะ</span>
      <div class="img-box">
        <img src="{b64_dict['led_3colors']}" alt="LEDs">
      </div>
      <div class="item-name">หลอด LED แสดงสถานะ (3 สี)</div>
      <div class="item-desc">ไฟแสดงสถานะการทำงานหน้าเครื่อง (ไฟเลี้ยงระบบ, สถานะ Wi-Fi, สถานะแอร์)</div>
      <div class="price-pill">___ บาท</div>
    </div>
  </div>
</div>


<!-- ======================================================== -->
<!-- SLIDE 2: แผนผังการเชื่อมต่อวงจรควบคุมแอร์แบบ IR (Wiring) -->
<!-- ======================================================== -->
<div class="slide" id="slide2">
  <div class="deco-lines">
    <div class="deco-line" style="width: 150px;"></div>
    <div class="deco-line" style="width: 110px;"></div>
    <div class="deco-line" style="width: 70px;"></div>
  </div>
  <div class="deco-bottom-bar"></div>
  <div class="deco-bottom-left"></div>
  <div class="page-num">23</div>

  <div class="slide-header" style="margin-top: 40px; margin-bottom: 12px;">
    <h1 class="slide-title" style="font-size: 46px;">แผนผังการเชื่อมต่อวงจรควบคุมแอร์แบบ IR</h1>
    <h2 class="slide-subtitle" style="font-size: 28px;">การเชื่อมต่อระหว่าง ESP32, Power Supply, PZEM-004T และวงจรขับ IR LED</h2>
  </div>

  <div class="diagram-area">
    <svg width="1780" height="800" viewBox="0 0 1780 800" style="background: #f8fafc; border: 2px solid #e2e8f0; border-radius: 24px;">
      <defs>
        <linearGradient id="gradBlue" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#1e3a8a"/>
          <stop offset="100%" stop-color="#3b82f6"/>
        </linearGradient>
        <filter id="cardShadow" x="-5%" y="-5%" width="110%" height="115%">
          <feDropShadow dx="0" dy="6" stdDeviation="6" flood-color="#0f172a" flood-opacity="0.08"/>
        </filter>
        <marker id="arrow-red" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto">
          <path d="M 0 0 L 8 4 L 0 8 z" fill="#ef4444" />
        </marker>
        <marker id="arrow-blue" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto">
          <path d="M 0 0 L 8 4 L 0 8 z" fill="#0284c7" />
        </marker>
        <marker id="arrow-orange" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto">
          <path d="M 0 0 L 8 4 L 0 8 z" fill="#f97316" />
        </marker>
        <marker id="arrow-purple" markerWidth="8" markerHeight="8" refX="6" refY="4" orient="auto">
          <path d="M 0 0 L 8 4 L 0 8 z" fill="#8b5cf6" />
        </marker>
      </defs>

      <!-- 1. Enclosure Box Boundary -->
      <rect x="40" y="30" width="1260" height="730" rx="24" fill="#ffffff" stroke="#94a3b8" stroke-width="2.5" stroke-dasharray="8 8"/>
      <text x="65" y="65" font-family="Kanit" font-size="20" font-weight="700" fill="#64748b">📦 ภายในกล่องควบคุมอุปกรณ์ (Enclosure Box ติดตั้งข้างตู้ไฟ / ผนังห้อง)</text>

      <!-- 2. Power Supply Unit (ซ้าย) -->
      <g transform="translate(80, 100)" filter="url(#cardShadow)">
        <rect width="240" height="320" rx="18" fill="#ffffff" stroke="#cbd5e1" stroke-width="2"/>
        <rect width="240" height="48" rx="18" fill="#334155"/>
        <rect y="24" width="240" height="24" fill="#334155"/>
        <text x="120" y="32" text-anchor="middle" font-family="Kanit" font-size="19" font-weight="700" fill="#ffffff">Power Supply 5V</text>
        <image href="{b64_dict['power_supply']}" x="65" y="65" width="110" height="135"/>
        <text x="120" y="230" text-anchor="middle" font-family="Kanit" font-size="16" font-weight="600" fill="#1e293b">DIN-Rail 220V ➔ 5V</text>
        <rect x="30" y="255" width="180" height="40" rx="8" fill="#fef3c7" stroke="#f59e0b" stroke-width="1.5"/>
        <text x="120" y="280" text-anchor="middle" font-family="Sarabun" font-size="14" font-weight="700" fill="#b45309">จ่ายไฟ DC 5V / 2A</text>
      </g>

      <!-- 3. Central Controller: ESP32 + Terminal Shield (กลาง) -->
      <g transform="translate(480, 85)" filter="url(#cardShadow)">
        <rect width="450" height="635" rx="22" fill="#ffffff" stroke="#2563eb" stroke-width="3"/>
        <rect width="450" height="65" rx="22" fill="url(#gradBlue)"/>
        <rect y="35" width="450" height="30" fill="url(#gradBlue)"/>
        <text x="225" y="42" text-anchor="middle" font-family="Kanit" font-size="24" font-weight="700" fill="#ffffff">ESP32 + Terminal Shield</text>
        <image href="{b64_dict['esp32']}" x="115" y="80" width="220" height="135"/>
        
        <!-- Pin Connection Table -->
        <rect x="30" y="235" width="390" height="370" rx="14" fill="#f8fafc" stroke="#e2e8f0" stroke-width="1.5"/>
        <text x="225" y="265" text-anchor="middle" font-family="Kanit" font-size="17" font-weight="700" fill="#1e3a8a">จุดเชื่อมต่อขาพินใช้งาน (GPIO Pinout)</text>
        
        <g transform="translate(45, 285)" font-family="JetBrains Mono" font-size="14">
          <!-- VIN & GND -->
          <rect x="0" y="0" width="70" height="30" rx="6" fill="#fee2e2"/>
          <text x="35" y="20" text-anchor="middle" fill="#b91c1c" font-weight="700">VIN / 5V</text>
          <text x="85" y="20" font-family="Kanit" font-size="14.5" fill="#334155">รับไฟเลี้ยง DC 5V จาก Power Supply</text>

          <rect x="0" y="42" width="70" height="30" rx="6" fill="#f1f5f9"/>
          <text x="35" y="62" text-anchor="middle" fill="#0f172a" font-weight="700">GND</text>
          <text x="85" y="62" font-family="Kanit" font-size="14.5" fill="#334155">กราวด์ร่วมระบบทั้งหมด</text>

          <!-- GPIO 25 (IR TX) -->
          <rect x="0" y="84" width="70" height="30" rx="6" fill="#ffedd5"/>
          <text x="35" y="104" text-anchor="middle" fill="#c2410c" font-weight="700">GPIO 25</text>
          <text x="85" y="104" font-family="Kanit" font-size="14.5" fill="#334155">ส่งสัญญาณ IR 38kHz ไปขยาย (Base 2N2222)</text>

          <!-- GPIO 16, 17 (PZEM UART) -->
          <rect x="0" y="126" width="70" height="30" rx="6" fill="#ede9fe"/>
          <text x="35" y="146" text-anchor="middle" fill="#6d28d9" font-weight="700">GPIO 16</text>
          <text x="85" y="146" font-family="Kanit" font-size="14.5" fill="#334155">ESP32 RX2 ➔ รับข้อมูลจาก TX ของ PZEM</text>

          <rect x="0" y="168" width="70" height="30" rx="6" fill="#ede9fe"/>
          <text x="35" y="188" text-anchor="middle" fill="#6d28d9" font-weight="700">GPIO 17</text>
          <text x="85" y="188" font-family="Kanit" font-size="14.5" fill="#334155">ESP32 TX2 ➔ ส่งคำสั่งไปยัง RX ของ PZEM</text>

          <!-- Status LEDs -->
          <rect x="0" y="210" width="70" height="30" rx="6" fill="#dcfce7"/>
          <text x="35" y="230" text-anchor="middle" fill="#15803d" font-weight="700">GPIO 2</text>
          <text x="85" y="230" font-family="Kanit" font-size="14.5" fill="#334155">LED สีน้ำเงิน/เขียว: สถานะ Wi-Fi & MQTT</text>

          <rect x="0" y="252" width="70" height="30" rx="6" fill="#dcfce7"/>
          <text x="35" y="272" text-anchor="middle" fill="#15803d" font-weight="700">GPIO 4</text>
          <text x="85" y="272" font-family="Kanit" font-size="14.5" fill="#334155">LED สีแดง: สถานะการทำงานของแอร์ (On/Off)</text>

          <!-- Status Note -->
          <rect x="0" y="294" width="360" height="24" rx="5" fill="#e2e8f0"/>
          <text x="180" y="311" text-anchor="middle" font-family="Sarabun" font-size="13" font-weight="600" fill="#475569">* ขันน็อตเชื่อมต่อผ่านบอร์ด Terminal แน่นหนา ไม่หลุดง่าย *</text>
        </g>
      </g>

      <!-- 4. PZEM-004T + CT Sensor (ขวาบน) -->
      <g transform=\"translate(1010, 100)\" filter=\"url(#cardShadow)\">
        <rect width=\"260\" height=\"285\" rx=\"18\" fill=\"#ffffff\" stroke=\"#8b5cf6\" stroke-width=\"2\"/>
        <rect width=\"260\" height=\"45\" rx=\"18\" fill=\"#7c3aed\"/>
        <rect y=\"25\" width=\"260\" height=\"20\" fill=\"#7c3aed\"/>
        <text x=\"130\" y=\"30\" text-anchor=\"middle\" font-family=\"Kanit\" font-size=\"18\" font-weight=\"700\" fill=\"#ffffff\">PZEM-004T (Power Meter)</text>
        <image href=\"{b64_dict['pzem_ct']}\" x=\"70\" y=\"55\" width=\"120\" height=\"125\"/>
        <text x=\"130\" y=\"200\" text-anchor=\"middle\" font-family=\"Kanit\" font-size=\"15\" font-weight=\"700\" fill=\"#4c1d95\">วัดไฟแอร์ 1 เฟส (AC 220V)</text>
        <text x=\"130\" y=\"225\" text-anchor=\"middle\" font-family=\"Sarabun\" font-size=\"13.5\" fill=\"#6b21a8\">สื่อสารผ่าน UART (TX/RX)</text>
        <rect x=\"25\" y=\"240\" width=\"210\" height=\"30\" rx=\"6\" fill=\"#ede9fe\"/>
        <text x=\"130\" y=\"260\" text-anchor=\"middle\" font-family=\"JetBrains Mono\" font-size=\"13\" font-weight=\"700\" fill=\"#6d28d9\">V / A / W / kWh / PF</text>
      </g>

      <!-- 5. วงจรขับ IR LED (ขวาล่าง) -->
      <g transform=\"translate(1010, 435)\" filter=\"url(#cardShadow)\">
        <rect width=\"260\" height=\"285\" rx=\"18\" fill=\"#ffffff\" stroke=\"#f97316\" stroke-width=\"2\"/>
        <rect width=\"260\" height=\"45\" rx=\"18\" fill=\"#ea580c\"/>
        <rect y=\"25\" width=\"260\" height=\"20\" fill=\"#ea580c\"/>
        <text x=\"130\" y=\"30\" text-anchor=\"middle\" font-family=\"Kanit\" font-size=\"18\" font-weight=\"700\" fill=\"#ffffff\">วงจรขับหลอด IR LED</text>
        <image href=\"{b64_dict['transistor_2n2222']}\" x=\"30\" y=\"65\" width=\"90\" height=\"110\"/>
        <image href=\"{b64_dict['ir_led']}\" x=\"145\" y=\"65\" width=\"85\" height=\"110\"/>
        <text x=\"130\" y=\"200\" text-anchor=\"middle\" font-family=\"Kanit\" font-size=\"15\" font-weight=\"700\" fill=\"#9a3412\">Transistor 2N2222 + IR LED</text>
        <text x=\"130\" y=\"225\" text-anchor=\"middle\" font-family=\"Sarabun\" font-size=\"13.5\" fill=\"#7c2d12\">ขยายกระแสยิงสัญญาณ 38 kHz</text>
        <rect x=\"25\" y=\"240\" width=\"210\" height=\"30\" rx=\"6\" fill=\"#ffedd5\"/>
        <text x=\"130\" y=\"260\" text-anchor=\"middle\" font-family=\"Kanit\" font-size=\"13\" font-weight=\"700\" fill=\"#c2410c\">ยิงคลื่น IR สั่งงานเครื่องปรับอากาศ</text>
      </g>

      <!-- 6. อุปกรณ์เป้าหมาย: เครื่องปรับอากาศ (ขวาสุด นอกกล่อง) -->
      <g transform=\"translate(1380, 180)\" filter=\"url(#cardShadow)\">
        <rect width=\"340\" height=\"410\" rx=\"24\" fill=\"#ffffff\" stroke=\"#0284c7\" stroke-width=\"3\"/>
        <rect width=\"340\" height=\"60\" rx=\"24\" fill=\"#0284c7\"/>
        <rect y=\"30\" width=\"340\" height=\"30\" fill=\"#0284c7\"/>
        <text x=\"170\" y=\"40\" text-anchor=\"middle\" font-family=\"Kanit\" font-size=\"22\" font-weight=\"700\" fill=\"#ffffff\">❄️ เครื่องปรับอากาศ (ในห้องเรียน)</text>
        
        <rect x=\"30\" y=\"90\" width=\"280\" height=\"110\" rx=\"14\" fill=\"#f0f9ff\" stroke=\"#bae6fd\" stroke-width=\"1.5\"/>
        <text x=\"170\" y=\"125\" text-anchor=\"middle\" font-family=\"Kanit\" font-size=\"18\" font-weight=\"700\" fill=\"#0369a1\">จุดรับสัญญาณ IR (IR Receiver)</text>
        <text x=\"170\" y=\"155\" text-anchor=\"middle\" font-family=\"Sarabun\" font-size=\"14.5\" fill=\"#0284c7\">รับคำสั่ง เปิด / ปิด / ปรับอุณหภูมิ</text>
        <text x=\"170\" y=\"180\" text-anchor=\"middle\" font-family=\"Sarabun\" font-size=\"13\" font-weight=\"600\" fill=\"#0284c7\">(ไม่ต้องรื้อสายไฟภายในตัวแอร์)</text>

        <rect x=\"30\" y=\"230\" width=\"280\" height=\"150\" rx=\"14\" fill=\"#fef2f2\" stroke=\"#fecaca\" stroke-width=\"1.5\"/>
        <text x=\"170\" y=\"265\" text-anchor=\"middle\" font-family=\"Kanit\" font-size=\"17\" font-weight=\"700\" fill=\"#991b1b\">สายไฟเมนแอร์ 220V AC (1 เฟส)</text>
        <text x=\"170\" y=\"295\" text-anchor=\"middle\" font-family=\"Sarabun\" font-size=\"14.5\" fill=\"#7f1d1d\">คล้องหม้อแปลง CT Sensor รอบสาย Line (L)</text>
        <text x=\"170\" y=\"325\" text-anchor=\"middle\" font-family=\"Sarabun\" font-size=\"13.5\" font-weight=\"700\" fill=\"#dc2626\">* ตรวจจับกระแสไฟ & กำลังวัตต์ *</text>
        <text x=\"170\" y=\"350\" text-anchor=\"middle\" font-family=\"Sarabun\" font-size=\"13\" fill=\"#b91c1c\">รู้ทันทีว่าแอร์เปิดหรือปิดจริง</text>
      </g>

      <!-- เส้นโยงสายสัญญาณ (WIRING LINES) -->

      <!-- ไฟเลี้ยง Power Supply 5V ➔ ESP32 VIN -->
      <path d=\"M 320 220 L 400 220 L 400 380 L 480 380\" fill=\"none\" stroke=\"#ef4444\" stroke-width=\"4\" marker-end=\"url(#arrow-red)\"/>
      <rect x=\"345\" y=\"205\" width=\"65\" height=\"24\" rx=\"4\" fill=\"#fee2e2\" stroke=\"#ef4444\" stroke-width=\"1\"/>
      <text x=\"377\" y=\"222\" text-anchor=\"middle\" font-family=\"JetBrains Mono\" font-size=\"12.5\" font-weight=\"700\" fill=\"#b91c1c\">+5V DC</text>

      <!-- สายกราวด์ร่วม GND -->
      <path d=\"M 320 265 L 415 265 L 415 425 L 480 425\" fill=\"none\" stroke=\"#0f172a\" stroke-width=\"4\" stroke-dasharray=\"6 4\"/>
      <rect x=\"350\" y=\"253\" width=\"55\" height=\"24\" rx=\"4\" fill=\"#f1f5f9\" stroke=\"#334155\" stroke-width=\"1\"/>
      <text x=\"377\" y=\"270\" text-anchor=\"middle\" font-family=\"JetBrains Mono\" font-size=\"12.5\" font-weight=\"700\" fill=\"#0f172a\">GND</text>

      <!-- ESP32 ➔ วงจรขับ IR LED (GPIO 25) -->
      <path d=\"M 930 460 L 970 460 L 970 510 L 1010 510\" fill=\"none\" stroke=\"#f97316\" stroke-width=\"4\" marker-end=\"url(#arrow-orange)\"/>
      <rect x=\"935\" y=\"440\" width=\"70\" height=\"24\" rx=\"4\" fill=\"#ffedd5\" stroke=\"#f97316\" stroke-width=\"1\"/>
      <text x=\"970\" y=\"457\" text-anchor=\"middle\" font-family=\"JetBrains Mono\" font-size=\"12\" font-weight=\"700\" fill=\"#c2410c\">GPIO 25</text>

      <!-- ESP32 ⇄ PZEM-004T (UART RX2/TX2) -->
      <path d=\"M 930 520 L 970 520 L 970 270 L 1010 270\" fill=\"none\" stroke=\"#8b5cf6\" stroke-width=\"3.5\" marker-end=\"url(#arrow-purple)\"/>
      <path d=\"M 1010 240 L 950 240 L 950 500 L 930 500\" fill=\"none\" stroke=\"#6366f1\" stroke-width=\"3.5\" stroke-dasharray=\"5 4\"/>
      <rect x=\"935\" y=\"335\" width=\"85\" height=\"42\" rx=\"6\" fill=\"#ede9fe\" stroke=\"#8b5cf6\" stroke-width=\"1\"/>
      <text x=\"977\" y=\"353\" text-anchor=\"middle\" font-family=\"JetBrains Mono\" font-size=\"12\" font-weight=\"700\" fill=\"#6d28d9\">TX2 / RX2</text>
      <text x=\"977\" y=\"368\" text-anchor=\"middle\" font-family=\"Kanit\" font-size=\"11\" fill=\"#5b21b6\">UART (16/17)</text>

      <!-- ลำแสงอินฟราเรดยิงไปยังแอร์ -->
      <path d=\"M 1270 530 L 1335 530 L 1335 145 L 1380 145\" fill=\"none\" stroke=\"#f59e0b\" stroke-width=\"4.5\" stroke-dasharray=\"8 6\" marker-end=\"url(#arrow-orange)\"/>
      <rect x=\"1275\" y=\"310\" width=\"105\" height=\"46\" rx=\"8\" fill=\"#fef3c7\" stroke=\"#f59e0b\" stroke-width=\"1.5\"/>
      <text x=\"1327\" y=\"330\" text-anchor=\"middle\" font-family=\"Kanit\" font-size=\"13\" font-weight=\"700\" fill=\"#b45309\">📡 ลำแสง IR</text>
      <text x=\"1327\" y=\"346\" text-anchor=\"middle\" font-family=\"Sarabun\" font-size=\"11.5\" fill=\"#92400e\">ความถี่ 38 kHz</text>

      <!-- ห่วงคล้อง CT ไปคล้องสายเมนแอร์ -->
      <path d=\"M 1270 260 L 1340 260 L 1340 295 L 1380 295\" fill=\"none\" stroke=\"#0284c7\" stroke-width=\"4\" marker-end=\"url(#arrow-blue)\"/>
      <rect x=\"1280\" y=\"230\" width=\"95\" height=\"26\" rx=\"6\" fill=\"#e0f2fe\" stroke=\"#0284c7\" stroke-width=\"1\"/>
      <text x=\"1327\" y=\"248\" text-anchor=\"middle\" font-family=\"Kanit\" font-size=\"12.5\" font-weight=\"700\" fill=\"#0369a1\">🧲 ห่วงคล้อง CT</text>
    </svg>
  </div>
</div>

</body>
</html>
"""

target_path = r"C:\Users\rapee\Documents\GitHub\cpe_air_remote\คู่มือศึกษาโปรเจค\สไลด์_งบประมาณและการต่อวงจร_Canva.html"
with open(target_path, "w", encoding="utf-8") as f:
    f.write(html_content)
print("Generated Canva Slide HTML successfully!")
