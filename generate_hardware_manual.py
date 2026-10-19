import os
import base64

# Paths to the 3 uploaded photos
img_wired = r"C:\Users\rapee\.gemini\antigravity\brain\d65e9246-7513-4315-acfd-6984cf5f79f3\.user_uploaded\media_1792318100591_3eedc695.jpg"
img_ir = r"C:\Users\rapee\.gemini\antigravity\brain\d65e9246-7513-4315-acfd-6984cf5f79f3\.user_uploaded\media_1792318114604_a2b2cddc.png"
img_occ = r"C:\Users\rapee\.gemini\antigravity\brain\d65e9246-7513-4315-acfd-6984cf5f79f3\.user_uploaded\media_1792318121777_db0131cd.png"

def to_b64(path, mime="image/png"):
    with open(path, "rb") as f:
        return f"data:{mime};base64," + base64.b64encode(f.read()).decode("utf-8")

b64_wired = to_b64(img_wired, "image/jpeg")
b64_ir = to_b64(img_ir, "image/png")
b64_occ = to_b64(img_occ, "image/png")

html_doc = f"""<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<title>คู่มือการประกอบฮาร์ดแวร์ทั้ง 3 แบบ และการอัปโหลดเฟิร์มแวร์ (RMUTT Save Energy)</title>
<link href="https://fonts.googleapis.com/css2?family=Kanit:wght@400;500;600;700&family=Sarabun:wght@400;500;600;700&family=JetBrains+Mono:wght@500;700&display=swap" rel="stylesheet">
<style>
  @page {{
    size: A4 portrait;
    margin: 12mm 14mm;
  }}
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  body {{
    font-family: 'Sarabun', sans-serif;
    color: #1e293b;
    background: #ffffff;
    line-height: 1.55;
    font-size: 13.5px;
  }}
  h1, h2, h3, h4, .font-head {{
    font-family: 'Kanit', sans-serif;
  }}
  code, pre, .mono {{
    font-family: 'JetBrains Mono', monospace;
  }}
  .page {{
    page-break-after: always;
    padding-bottom: 10px;
  }}
  .page:last-child {{
    page-break-after: auto;
  }}

  /* Header Banner */
  .banner {{
    background: linear-gradient(135deg, #0f172a 0%, #1e3a8a 60%, #2563eb 100%);
    color: white;
    padding: 20px 24px;
    border-radius: 14px;
    margin-bottom: 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;
  }}
  .banner h1 {{
    font-size: 22px;
    font-weight: 700;
    margin-bottom: 4px;
  }}
  .banner p {{
    font-size: 13px;
    color: #dbeafe;
  }}
  .banner-badge {{
    background: rgba(255,255,255,0.15);
    border: 1px solid rgba(255,255,255,0.3);
    padding: 6px 14px;
    border-radius: 20px;
    font-family: 'Kanit', sans-serif;
    font-size: 12px;
    font-weight: 600;
    white-space: nowrap;
  }}

  /* Section Headings */
  .sec-title {{
    display: flex;
    align-items: center;
    gap: 10px;
    background: #f1f5f9;
    border-left: 5px solid #2563eb;
    padding: 8px 14px;
    border-radius: 0 8px 8px 0;
    margin: 14px 0 10px 0;
    font-size: 16px;
    font-weight: 700;
    color: #0f172a;
  }}
  .sec-title.green {{ border-left-color: #10b981; background: #ecfdf5; color: #065f46; }}
  .sec-title.orange {{ border-left-color: #f97316; background: #fff7ed; color: #9a3412; }}
  .sec-title.purple {{ border-left-color: #8b5cf6; background: #f5f3ff; color: #5b21b6; }}

  /* Grid & Cards */
  .grid-2 {{
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }}
  .grid-3 {{
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 12px;
  }}
  .card {{
    border: 1.5px solid #e2e8f0;
    border-radius: 10px;
    padding: 12px 14px;
    background: #ffffff;
  }}
  .card-title {{
    font-family: 'Kanit', sans-serif;
    font-size: 14.5px;
    font-weight: 700;
    color: #1e3a8a;
    margin-bottom: 6px;
    display: flex;
    align-items: center;
    gap: 6px;
  }}

  /* Photo Showcase */
  .photo-box {{
    display: flex;
    gap: 14px;
    background: #f8fafc;
    border: 1.5px solid #cbd5e1;
    border-radius: 12px;
    padding: 12px;
    margin-bottom: 12px;
    align-items: center;
  }}
  .photo-box img {{
    width: 230px;
    height: 175px;
    object-fit: cover;
    border-radius: 8px;
    border: 1px solid #94a3b8;
  }}
  .photo-info {{
    flex: 1;
  }}

  /* Tables */
  table {{
    width: 100%;
    border-collapse: collapse;
    margin: 8px 0 12px 0;
    font-size: 12.5px;
  }}
  th {{
    background: #1e3a8a;
    color: white;
    font-family: 'Kanit', sans-serif;
    font-weight: 600;
    text-align: left;
    padding: 6px 10px;
    border: 1px solid #1e3a8a;
  }}
  td {{
    padding: 5px 10px;
    border: 1px solid #cbd5e1;
    vertical-align: top;
  }}
  tr:nth-child(even) td {{
    background: #f8fafc;
  }}

  /* Step List */
  .step-list {{
    list-style: none;
    display: flex;
    flex-direction: column;
    gap: 7px;
  }}
  .step-item {{
    display: flex;
    gap: 10px;
    align-items: flex-start;
    background: #f8fafc;
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    padding: 7px 11px;
  }}
  .step-num {{
    background: #2563eb;
    color: white;
    font-family: 'Kanit', sans-serif;
    font-weight: 700;
    font-size: 12px;
    min-width: 24px;
    height: 24px;
    border-radius: 50%;
    display: flex;
    align-items: center;
    justify-content: center;
    margin-top: 1px;
  }}
  .step-num.orange {{ background: #ea580c; }}
  .step-num.green {{ background: #059669; }}
  .step-num.purple {{ background: #7c3aed; }}

  .pin-pill {{
    background: #eff6ff;
    color: #1d4ed8;
    border: 1px solid #bfdbfe;
    padding: 1px 6px;
    border-radius: 4px;
    font-family: 'JetBrains Mono', monospace;
    font-size: 11.5px;
    font-weight: 700;
  }}
  .warn-box {{
    background: #fef2f2;
    border: 1.5px solid #fecaca;
    border-left: 5px solid #ef4444;
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 12.5px;
    color: #991b1b;
    margin: 8px 0;
  }}
  .tip-box {{
    background: #eff6ff;
    border: 1.5px solid #bfdbfe;
    border-left: 5px solid #3b82f6;
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 12.5px;
    color: #1e40af;
    margin: 8px 0;
  }}
  ul.bullet {{
    padding-left: 18px;
  }}
  ul.bullet li {{
    margin-bottom: 3px;
  }}
</style>
</head>
<body>

<!-- ===================================================================== -->
<!-- PAGE 1: ภาพรวมทั้ง 3 กล่อง + เครื่องมือช่างและอุปกรณ์เสริม (สายไฟ/หัวต่อ) -->
<!-- ===================================================================== -->
<div class="page">
  <div class="banner">
    <div>
      <h1>🛠️ คู่มือการประกอบฮาร์ดแวร์ทั้ง 3 แบบ และการอัปโหลดเฟิร์มแวร์</h1>
      <p>โครงการระบบจัดการพลังงานเครื่องปรับอากาศอัจฉริยะ (RMUTT Save Energy) — ตั้งแต่เตรียมของ ประกอบลงกล่อง จนถึงแฟลชโค้ดใช้งานจริง</p>
    </div>
    <div class="banner-badge">Hardware Assembly Guide</div>
  </div>

  <div class="sec-title">1. ภาพรวมกล่องฮาร์ดแวร์ทั้ง 3 แบบในโปรเจกต์</div>
  <div class="grid-3">
    <div class="card" style="border-top: 4px solid #2563eb;">
      <div class="card-title">❄️ แบบที่ 1: กล่องควบคุมแอร์แบบ IR</div>
      <p style="font-size:12px; color:#475569; margin-bottom:6px;"><b>เฟิร์มแวร์:</b> <code>rmutt_esp32_air.ino</code> (v2.5.2)</p>
      <ul class="bullet" style="font-size:12px;">
        <li>ใช้กับแอร์ทั่วไปที่ใช้รีโมทอินฟราเรด (เช่น ห้อง 16303 / 16307)</li>
        <li>ยิงแสง IR 38kHz ผ่านวงจรขยายกระแส <code>2N2222</code></li>
        <li>วัดกระแส/กำลังไฟด้วย <code>PZEM-004T + CT</code></li>
        <li>มีจอ <code>OLED 1.3"</code> ที่ฝาหน้า + ไฟ LED 3 สี</li>
      </ul>
    </div>
    <div class="card" style="border-top: 4px solid #ea580c;">
      <div class="card-title" style="color:#9a3412;">🔌 แบบที่ 2: กล่องควบคุมแอร์แบบสาย Panel</div>
      <p style="font-size:12px; color:#475569; margin-bottom:6px;"><b>เฟิร์มแวร์:</b> <code>rmutt_esp32_air_wired.ino</code> (v2.5.5-slm8)</p>
      <ul class="bullet" style="font-size:12px;">
        <li>ใช้แทนรีโมทติดผนัง <b>Daikin SLM8</b> แบบมีสาย</li>
        <li>รับ-ส่งข้อมูลสองทางผ่านสายแอร์ (รู้สถานะคอมเพรสเซอร์จริง)</li>
        <li>ใช้วงจรไดโอด <code>1N4148</code> + ตัวแบ่งแรงดัน <code>100k/200kΩ</code></li>
        <li>มีเซนเซอร์วัดอุณหภูมิห้อง <code>DHT11</code> + <code>PZEM-004T</code> + จอ <code>OLED</code></li>
      </ul>
    </div>
    <div class="card" style="border-top: 4px solid #059669;">
      <div class="card-title" style="color:#065f46;">📡 แบบที่ 3: กล่องตรวจจับคน (Occupancy)</div>
      <p style="font-size:12px; color:#475569; margin-bottom:6px;"><b>เฟิร์มแวร์:</b> <code>rmutt_esp32_occupancy.ino</code> (v1.3.9)</p>
      <ul class="bullet" style="font-size:12px;">
        <li>ติดตั้งห้องละ 1 กล่อง เพื่อตรวจว่ามีคนนั่งเรียนหรือไม่</li>
        <li>ใช้เรดาร์คลื่นมิลลิเมตร <code>HLK-LD2410</code> (ตรวจจับคนนั่งนิ่งๆ ได้)</li>
        <li>ขนาดกะทัดรัด จ่ายไฟผ่านพอร์ต <code>USB Type-C 5V</code></li>
        <li>มีไฟ LED 2 สีที่ฝาหน้า (เขียว = เน็ตพร้อม, แดง = มีคน)</li>
      </ul>
    </div>
  </div>

  <div class="sec-title">2. อุปกรณ์เสริม สายไฟ และเครื่องมือช่างที่ต้องเตรียม (ใช้ร่วมกันทุกกล่อง)</div>
  <table>
    <thead>
      <tr>
        <th style="width: 24%;">หมวดหมู่</th>
        <th style="width: 38%;">รายการอุปกรณ์เสริม / ชนิดสายไฟ</th>
        <th style="width: 38%;">ใช้ทำอะไรในกล่อง</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>1. สายไฟแรงดันสูง (AC 220V)</b><br><i>(เฉพาะกล่องแอร์แบบที่ 1 และ 2)</i></td>
        <td>
          • <b>สายไฟปลั๊ก AC 220V (VCT 2x0.75 หรือ 2x1.0 sq.mm.)</b><br>
          • <b>สายไฟแกนเดี่ยว/สายอ่อน THW/VSF ขนาด 1.0–1.5 sq.mm.</b><br>
          &nbsp;&nbsp;(สีน้ำตาล = Line `L`, สีฟ้า = Neutral `N`)
        </td>
        <td>
          • นำไฟบ้าน 220V เข้ากล่อง<br>
          • แยกจ่ายไฟเข้า <b>Power Supply HDR-15-5</b> และขั้ววัดแรงดันของ <b>PZEM-004T</b>
        </td>
      </tr>
      <tr>
        <td><b>2. ขั้วต่อแยกสายไฟ AC</b><br><i>(เห็นในรูปมุมซ้ายล่างของกล่อง)</i></td>
        <td>
          • <b>ขั้วต่อสายไฟแบบคันโยก (Wago / Lever Terminal Block 2 เข้า 4 ออก หรือ 2 ออก)</b> สีส้ม-เทา
        </td>
        <td>
          • ใช้เป็นจุดพักและแยกสายไฟ 220V (L และ N) จากสายปลั๊กหลัก ไปยัง Power Supply และ PZEM-004T โดยไม่ต้องพันเทปดำ ลดการสปาร์ค
        </td>
      </tr>
      <tr>
        <td><b>3. สายสัญญาณแรงดันต่ำ (DC 5V / 3.3V)</b></td>
        <td>
          • <b>สายแพรจัมเปอร์ (Dupont Wire)</b> หรือ <b>สายไฟอ่อน AWG 22–24</b> หลากสี (แดง=ไฟบวก, ดำ=GND, เหลือง/เขียว/ขาว=สัญญาณ)<br>
          • <b>สายไฟคู่ แดง-ดำ (ยาว 1.5–3 เมตร)</b> สำหรับต่อหลอด IR LED หรือต่อสายเรดาร์/สายแอร์
        </td>
        <td>
          • ขันน็อตเข้ากับฐาน <b>ESP32 Terminal Adapter</b> ไปยัง PZEM, แผ่นปริ้นท์ไข่ปลา (Perfboard), จอ OLED และโมดูลเรดาร์
        </td>
      </tr>
      <tr>
        <td><b>4. แผ่นวงจรและอะไหล่อิเล็กทรอนิกส์ย่อย</b></td>
        <td>
          • <b>แผ่นปริ้นท์ไข่ปลา (Perfboard / Prototype PCB)</b> ขนาด 4x6 cm และ 2x3 cm<br>
          • <b>ตัวต้านทาน (Resistor):</b> <code>220Ω–330Ω</code> (ต่อไฟ LED และขา Base 2N2222), <code>100kΩ</code> (6 ตัว สำหรับกล่องสายแอร์)<br>
          • <b>ขั้วต่อ JST XH 2.54mm (ตัวผู้-ตัวเมีย)</b> และ <b>ท่อหด (Heat Shrink Tube)</b>
        </td>
        <td>
          • ใช้บัดกรีวงจรขับ IR, วงจรไฟสถานะ LED 3 สี และวงจรแบ่งแรงดันสายแอร์ให้เป็นระเบียบ แข็งแรง ไม่ช็อตกันในกล่อง
        </td>
      </tr>
      <tr>
        <td><b>5. โครงสร้างกล่องและเครื่องมือช่าง</b></td>
        <td>
          • <b>กล่อง 3D Print (PLA/PETG)</b> พร้อมกรอบยึดจอ OLED และฐานล็อกโมดูล<br>
          • หัวแร้งบัดกรี + ตะกั่ว, ไขควงปากแบนขนาดเล็ก (ขัน Terminal), คีมปอกสายไฟ, ปืนกาวร้อน, มัลติมิเตอร์, สาย <b>USB Type-C (รองรับ Data)</b>
        </td>
        <td>
          • ยึดบอร์ดเข้ากับเสาในกล่อง ขันน็อตขั้วสายไฟ หุ้มท่อหดกันช็อต และเสียบสาย USB อัปโหลดโค้ดจากคอมพิวเตอร์
        </td>
      </tr>
    </tbody>
  </table>

  <div class="warn-box">
    <b>⚠️ กฎความปลอดภัยสำคัญที่สุด:</b> กล่องแบบที่ 1 และ 2 มีไฟบ้าน <b>AC 220V</b> เข้าที่ตัวขั้วต่อ Wago, Power Supply และฝั่งซ้ายของ PZEM-004T <b>ห้ามเสียบปลั๊กไฟ 220V ขณะกำลังขันสายหรือบัดกรีเด็ดขาด!</b> และตอนเสียบสาย USB อัปโหลดโค้ดจากคอมพิวเตอร์ ให้ถอดปลั๊ก 220V ออกก่อนทุกครั้ง
  </div>
</div>


<!-- ===================================================================== -->
<!-- PAGE 2: คู่มือการประกอบ แบบที่ 1 — กล่องควบคุมแอร์แบบอินฟราเรด (IR)    -->
<!-- ===================================================================== -->
<div class="page">
  <div class="sec-title">3. คู่มือการประกอบแบบที่ 1: กล่องควบคุมแอร์แบบอินฟราเรด (IR Air Controller)</div>

  <div class="photo-box">
    <img src="{b64_ir}" alt="กล่องควบคุมแอร์แบบ IR">
    <div class="photo-info">
      <h3 style="font-size:15px; color:#1e3a8a; margin-bottom:4px;">📦 รายการอุปกรณ์เฉพาะของกล่องแบบที่ 1 (IR)</h3>
      <div class="grid-2" style="font-size:12px; gap:6px;">
        <div>
          1. <b>ESP32 DevKit / IOXESP32</b> (1 บอร์ด)<br>
          2. <b>ฐานขยายขา ESP32 Terminal Adapter</b> (1 ชิ้น)<br>
          3. <b>Power Supply MeanWell HDR-15-5</b> (220VAC ➔ 5VDC)<br>
          4. <b>PZEM-004T v3.0 + ห่วงคล้อง CT Sensor</b> (1 ชุด)<br>
          5. <b>จอ OLED 1.3 นิ้ว I2C (ชิป SH1106)</b> (1 จอ)
        </div>
        <div>
          6. <b>Transistor 2N2222</b> (1 ตัว) + <b>R 220Ω–330Ω</b> (1 ตัว)<br>
          7. <b>หลอดส่งคลื่น Infrared LED 940nm</b> (1 หลอด + สายไฟคู่ยาว)<br>
          8. <b>หลอดไฟ LED 3 สี (เขียว, แดง, เหลือง)</b> + <b>R 220Ω–330Ω</b> (3 ตัว)<br>
          9. <b>ขั้วต่อไฟ Wago (สีส้ม)</b> + <b>สายปลั๊ก AC 220V</b><br>
          10. <b>แผ่นปริ้นท์ไข่ปลา 4x6 cm</b> + <b>กล่อง 3D Print พร้อมฝา</b>
        </div>
      </div>
    </div>
  </div>

  <h4 style="font-size:14px; color:#1e3a8a; margin: 8px 0 6px 0;">🔧 ลำดับขั้นตอนการประกอบ (เริ่มจากอะไรก่อน ➔ ไปจบที่ตรงไหน)</h4>
  <div class="step-list">
    <div class="step-item">
      <div class="step-num">1</div>
      <div>
        <b>บัดกรีแผ่นวงจรย่อยบนปริ้นท์ไข่ปลา (ทำนอกกล่องก่อน):</b>
        <ul class="bullet" style="font-size:12px; margin-top:2px;">
          <li><b>ชุดไฟสถานะ LED 3 สี:</b> วางหลอด LED สีแดง เหลือง เขียว เรียงกันที่ขอบแผ่นปริ้นท์ให้หัวหลอดยื่นพ้นรูด้านบนกล่อง บัดกรีขาบวก (ขายาว) ของแต่ละหลอดผ่านตัวต้านทาน <code>220Ω–330Ω</code> แยกสายออกเป็น 3 เส้น ส่วนขาลบ (ขาสั้น) ของทั้ง 3 หลอดบัดกรีรวมกันเป็นสาย <code>GND</code> เส้นเดียว</li>
          <li><b>ชุดวงจรขับหลอด IR (Transistor 2N2222):</b> บัดกรีทรานซิสเตอร์ <code>2N2222</code> ลงแผ่นปริ้นท์ โดยให้ <b>ขา Emitter (E - ขาซ้าย)</b> ต่อลง <code>GND</code>, <b>ขา Base (B - ขากลาง)</b> ต่อตัวต้านทาน <code>220Ω</code> แล้วโยงสายไปเข้า <code>GPIO 17</code>, และ <b>ขา Collector (C - ขาขวา)</b> ต่อกับขาลบของ <b>หลอด IR LED</b> ส่วนขาบวกของหลอด IR LED ต่อเข้าไฟเลี้ยง <code>+5V (หรือ 3.3V ผ่าน R 10Ω-22Ω)</code></li>
        </ul>
      </div>
    </div>

    <div class="step-item">
      <div class="step-num">2</div>
      <div>
        <b>ประกอบบอร์ดหลักและยึดอุปกรณ์ลงฐานกล่อง 3D Print:</b>
        <ul class="bullet" style="font-size:12px; margin-top:2px;">
          <li>กดบอร์ด <b>ESP32</b> ลงบน <b>ฐานขยายขา Terminal Adapter</b> ให้ตรงขา (หันพอร์ต USB Type-C ไปทางขวาตามรูป) แล้วขันน็อตยึดเข้ามุมซ้ายบนของกล่อง</li>
          <li>วาง <b>Power Supply (HDR-15-5)</b> ลงช่องขวาของกล่อง, วาง <b>PZEM-004T</b> ตรงกลางซ้าย, ยึด <b>ขั้วต่อ Wago สีส้ม</b> ที่มุมซ้ายล่าง และยึด <b>แผ่นปริ้นท์ไข่ปลา</b> ที่มุมขวาบน</li>
          <li>ขันน็อตยึด <b>จอ OLED 1.3"</b> เข้ากับกรอบพลาสติกด้านในของ <b>ฝาหน้าสีดำ</b></li>
        </ul>
      </div>
    </div>

    <div class="step-item">
      <div class="step-num">3</div>
      <div>
        <b>เดินสายไฟแรงดันต่ำ (DC 5V & สายสัญญาณ GPIO) บนขั้วขันน็อต ESP32:</b>
        <ul class="bullet" style="font-size:12px; margin-top:2px;">
          <li><b>ไฟเลี้ยงบอร์ด:</b> ต่อสายสีแดงจากช่อง <code>+V (5V)</code> ของ Power Supply เข้าขั้ว <code>5V / VIN</code> ของฐาน ESP32 และสายสีดำจาก <code>-V</code> เข้าขั้ว <code>GND</code></li>
          <li><b>สายสื่อสาร PZEM-004T (ฝั่ง 4 ขาแรงดันต่ำ):</b> ต่อ <code>5V</code> เข้า <code>5V</code>, <code>GND</code> เข้า <code>GND</code>, ขา <code>TX</code> ของ PZEM เข้า <code>GPIO 16</code> และขา <code>RX</code> ของ PZEM เข้า <code>GPIO 18</code> (ต่อไขว้)</li>
          <li><b>สายจอ OLED (4 เส้น):</b> ต่อ <code>VCC ➔ 3V3</code>, <code>GND ➔ GND</code>, <code>SDA ➔ GPIO 21</code>, <code>SCL ➔ GPIO 22</code></li>
          <li><b>สายแผ่นปริ้นท์ไข่ปลา:</b> ต่อสายขับ IR เข้า <code>GPIO 17</code>, ไฟ LED เขียวเข้า <code>GPIO 25</code>, LED แดงเข้า <code>GPIO 26</code>, LED เหลืองเข้า <code>GPIO 27</code> และสายกราวด์เข้า <code>GND</code></li>
        </ul>
      </div>
    </div>

    <div class="step-item">
      <div class="step-num">4</div>
      <div>
        <b>เดินสายไฟแรงดันสูง AC 220V และสายคล้อง CT (ทำเป็นขั้นตอนสุดท้าย):</b>
        <ul class="bullet" style="font-size:12px; margin-top:2px;">
          <li>สอดสายปลั๊กไฟ AC 220V เข้าทางรูด้านล่างกล่อง เข้าสู่ <b>ขั้วต่อ Wago สีส้ม</b> (แยกฝั่งสายสีน้ำตาล <code>L</code> และสีฟ้า <code>N</code> ออกจากกันชัดเจน)</li>
          <li>พ่วงสาย <code>L</code> และ <code>N</code> จาก Wago ชุดที่ 1 ไปเข้าช่อง <code>L / N</code> ด้านล่างของ <b>Power Supply HDR-15-5</b></li>
          <li>พ่วงสาย <code>L</code> และ <code>N</code> จาก Wago ชุดที่ 2 ไปเข้าขั้วขันน็อตฝั่งไฟบ้าน (ช่องที่ 1 และ 2) ของ <b>PZEM-004T</b></li>
          <li>นำสายคู่สีแดง-ดำของ <b>ห่วงคล้อง CT Sensor</b> ขันเข้าขั้วที่ 3 และ 4 ของ PZEM-004T (เวลาติดตั้งจริง ให้นำห่วง CT ไปคล้องสายเมน <code>L</code> ของแอร์เพียงเส้นเดียว)</li>
        </ul>
      </div>
    </div>
  </div>

  <h4 style="font-size:13.5px; color:#1e3a8a; margin: 8px 0 4px 0;">📌 ตารางสรุปขาพิน (Pinout) ของกล่องแบบที่ 1 (IR)</h4>
  <table>
    <thead>
      <tr>
        <th>ขาพิน ESP32</th>
        <th>ต่อเข้ากับอุปกรณ์</th>
        <th>ขั้ว/ขาที่ต่อ</th>
        <th>หน้าที่การทำงาน</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><span class="pin-pill">5V (VIN)</span> / <span class="pin-pill">GND</span></td>
        <td>Power Supply HDR-15-5</td>
        <td><code>+V (5V)</code> และ <code>-V (GND)</code></td>
        <td>จ่ายไฟเลี้ยงหลัก DC 5V ให้บอร์ด ESP32 และโมดูลทั้งหมด</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 17</span></td>
        <td>วงจรขับหลอด IR (บนแผ่นไข่ปลา)</td>
        <td>ผ่าน R 220Ω เข้าขา <code>Base (2N2222)</code></td>
        <td>ส่งสัญญาณพัลส์ความถี่ 38 kHz ขับหลอด IR LED ยิงสั่งแอร์</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 16 (RX2)</span></td>
        <td>โมดูลวัดไฟ PZEM-004T</td>
        <td>ต่อเข้าขา <code>TX</code> ของ PZEM</td>
        <td>รับค่าแรงดัน กระแส กำลังวัตต์ และหน่วยไฟสะสมจาก PZEM</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 18 (TX2)</span></td>
        <td>โมดูลวัดไฟ PZEM-004T</td>
        <td>ต่อเข้าขา <code>RX</code> ของ PZEM</td>
        <td>ส่งคำสั่งขออ่านค่าไปยังโมดูล PZEM-004T</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 21</span> / <span class="pin-pill">GPIO 22</span></td>
        <td>จอแสดงผล OLED 1.3" (SH1106)</td>
        <td><code>21 ➔ SDA</code>, <code>22 ➔ SCL</code> (ไฟ <code>3V3</code>)</td>
        <td>แสดงอุณหภูมิ สถานะแอร์ กำลังวัตต์ และสถานะ Wi-Fi บนฝาหน้า</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 25, 26, 27</span></td>
        <td>หลอด LED 3 สี (ผ่าน R 220Ω)</td>
        <td><code>25=เขียว</code>, <code>26=แดง</code>, <code>27=เหลือง</code></td>
        <td>เขียว=แอร์ทำงาน, แดง=เปิดแอร์นอกตารางเรียน, เหลือง=สถานะ Wi-Fi</td>
      </tr>
    </tbody>
  </table>
</div>


<!-- ===================================================================== -->
<!-- PAGE 3: คู่มือการประกอบ แบบที่ 2 — กล่องควบคุมแอร์แบบสาย Panel (SLM8)  -->
<!-- ===================================================================== -->
<div class="page">
  <div class="sec-title orange">4. คู่มือการประกอบแบบที่ 2: กล่องควบคุมแอร์แบบสาย Panel (Daikin Wired SLM8)</div>

  <div class="photo-box" style="border-color:#fed7aa; background:#fff7ed;">
    <img src="{b64_wired}" alt="กล่องควบคุมแอร์แบบสายแอร์ Daikin SLM8">
    <div class="photo-info">
      <h3 style="font-size:15px; color:#9a3412; margin-bottom:4px;">📦 รายการอุปกรณ์เฉพาะของกล่องแบบที่ 2 (สายแอร์ Panel)</h3>
      <p style="font-size:12px; color:#7c2d12; margin-bottom:6px;"><i>* อุปกรณ์หลักในกล่อง (ESP32, ฐานขันน็อต, Power Supply HDR-15-5, PZEM-004T, Wago, จอ OLED, LED 3 สี) เหมือนกล่องที่ 1 แต่เปลี่ยนส่วนส่งสัญญาณจาก IR เป็นชุดสายแอร์ดังนี้: *</i></p>
      <div class="grid-2" style="font-size:12px; gap:6px;">
        <div>
          1. <b>ไดโอด 1N4148</b> (1 ตัว - สำหรับดึงสายส่งคำสั่งลง LOW)<br>
          2. <b>ตัวต้านทาน 100kΩ</b> (6 ตัว - ทำวงจรแบ่งแรงดัน 100k/200kΩ 2 ชุด)<br>
          3. <b>เซนเซอร์วัดอุณหภูมิ DHT11 (โมดูล KY-015)</b> (1 ตัว)
        </div>
        <div>
          4. <b>ขั้วต่อสาย JST 3–4 พิน</b> + <b>สายสัญญาณสีขาว 4 เส้น</b> (ต่อไปยังจุดรีโมตผนังเดิมของแอร์ Daikin)<br>
          5. <b>แผ่นปริ้นท์ไข่ปลา 4x6 cm</b> (สำหรับบัดกรีวงจรแบ่งแรงดัน + ไดโอด)
        </div>
      </div>
    </div>
  </div>

  <h4 style="font-size:14px; color:#9a3412; margin: 8px 0 6px 0;">🔧 ลำดับขั้นตอนการประกอบ (จุดที่แตกต่างและต้องระวังเป็นพิเศษ)</h4>
  <div class="step-list">
    <div class="step-item">
      <div class="step-num orange">1</div>
      <div>
        <b>บัดกรีวงจรเชื่อมต่อสายแอร์ (SLM8 Interface) บนแผ่นปริ้นท์ไข่ปลา:</b>
        <ul class="bullet" style="font-size:12px; margin-top:2px;">
          <li><b>ขาส่งคำสั่งไปแอร์ (TX Bus):</b> บัดกรีไดโอด <code>1N4148</code> โดยหัน <b>ด้านที่มีแถบคาดสีดำ (Cathode)</b> ไปต่อเข้า <code>GPIO 33</code> ของ ESP32 และหันด้านไม่มีแถบ (Anode) ไปออกขั้วสายสั่งงานแอร์ (ขาว <code>TX</code>) เพื่อให้ ESP32 ดึงสัญญาณลง 0V ได้อย่างเดียวโดยไม่จ่ายไฟย้อนเข้าสายแอร์</li>
          <li><b>ขารับสถานะจากแอร์ (RX Bus):</b> สายแอร์มีแรงดันประมาณ 5V จึงต้องทำ <b>วงจรแบ่งแรงดัน (Voltage Divider 100kΩ / 200kΩ)</b> โดยต่อตัวต้านทาน <code>100kΩ</code> จากสายสถานะแอร์ (เหลือง <code>TX/RCV</code>) เข้าจุดแยกไปหา <code>GPIO 35</code> และจากจุดแยกนั้นต่อตัวต้านทาน <code>200kΩ</code> (ใช้ 100kΩ 2 ตัวต่ออนุกรมกัน) ลง <code>GND</code> เพื่อลดแรงดันเหลือ ~3.2V</li>
          <li><b>ขาตรวจสัญญาณตัวเอง (Echo - เสริม):</b> ทำวงจรแบ่งแรงดัน <code>100kΩ / 200kΩ</code> อีก 1 ชุดจากสายสั่งงานแอร์เข้าขา <code>GPIO 34</code></li>
        </ul>
      </div>
    </div>

    <div class="step-item">
      <div class="step-num orange">2</div>
      <div>
        <b>ติดตั้งเซนเซอร์วัดอุณหภูมิห้อง DHT11 และการเดินสายภายในกล่อง:</b>
        <ul class="bullet" style="font-size:12px; margin-top:2px;">
          <li>เนื่องจากเราถอดรีโมทติดผนังเดิมออก (ซึ่งมีเทอร์มิสเตอร์วัดอุณหภูมิห้องในตัว) เราจึงต้องต่อโมดูล <b>DHT11</b> เข้ากับ ESP32 (ขา <code>DATA ➔ GPIO 4</code>, <code>VCC ➔ 3V3</code>, <code>GND ➔ GND</code>) เพื่อส่งค่าอุณหภูมิห้องไปให้แอร์ใช้ตัดสินใจตัดคอมเพรสเซอร์</li>
          <li><b>⚠️ ข้อควรระวังสำคัญมาก (ดูโค้ด <code>rmutt_esp32_air_wired.ino</code>):</b> ในโค้ดรุ่นสายแอร์ ขาของ PZEM และ LED สีเหลืองถูกย้ายตำแหน่งต่างจากรุ่น IR! ให้ขันน็อตตามตารางด้านล่างให้ตรงเป๊ะ</li>
        </ul>
      </div>
    </div>

    <div class="step-item">
      <div class="step-num orange">3</div>
      <div>
        <b>การเชื่อมต่อสายสีขาวเข้ากับสายรีโมตติดผนังบนกำแพง (ตามรูปที่ 1):</b>
        <ul class="bullet" style="font-size:12px; margin-top:2px;">
          <li>ถอดแผงควบคุมติดผนัง Daikin SLM8 เดิมออก จะพบสายไฟ 4 เส้นที่มาจากตัวแอร์</li>
          <li>ต่อสายจากขั้ว JST บนแผ่นปริ้นท์ไข่ปลาขึ้นไปเชื่อมกับสายแอร์บนผนัง 3 เส้น ได้แก่: <b>1) สายสั่งงาน (TX - สีขาว)</b>, <b>2) สายสถานะ (TX/RCV - สีเหลือง)</b>, และ <b>3) สายกราวด์ (GND - สีดำ — บังคับต้องต่อร่วมกับ GND ของ ESP32)</b></li>
          <li><b>ห้ามต่อสายไฟ +5V (สีแดง) จากสายแอร์เข้าบอร์ดเด็ดขาด!</b> ให้ปล่อยลอยและหุ้มท่อหดไว้ เพราะกล่องของเราใช้ไฟเลี้ยงจาก Power Supply HDR-15-5 ในกล่องอยู่แล้ว</li>
        </ul>
      </div>
    </div>
  </div>

  <h4 style="font-size:13.5px; color:#9a3412; margin: 8px 0 4px 0;">📌 ตารางสรุปขาพิน (Pinout) ของกล่องแบบที่ 2 (สายแอร์ Daikin SLM8 — อ้างอิงโค้ดจริง v2.5.5-slm8)</h4>
  <table>
    <thead>
      <tr>
        <th style="background:#9a3412; border-color:#9a3412;">ขาพิน ESP32</th>
        <th style="background:#9a3412; border-color:#9a3412;">ต่อเข้ากับอุปกรณ์</th>
        <th style="background:#9a3412; border-color:#9a3412;">วงจรคั่นกลาง / ขั้วที่ต่อ</th>
        <th style="background:#9a3412; border-color:#9a3412;">หมายเหตุความต่างจากรุ่น IR</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><span class="pin-pill">GPIO 33</span></td>
        <td>สายสั่งงานแอร์ (Command Wire)</td>
        <td>ผ่านไดโอด <code>1N4148</code> (หันแถบคาดเข้า GPIO 33)</td>
        <td>ส่งเฟรมคำสั่ง SLM8 ทุก 1 วินาทีไปสั่งแอร์</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 35</span></td>
        <td>สายสถานะแอร์ (Status Wire)</td>
        <td>ผ่านตัวแบ่งแรงดัน <code>100kΩ / 200kΩ</code> ลง GND</td>
        <td>รับเฟรมสถานะตอบกลับจากแอร์ (รู้ว่าคอมเพรสเซอร์ทำงานหรือไม่)</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 34</span></td>
        <td>สายสั่งงานแอร์ (Echo Check)</td>
        <td>ผ่านตัวแบ่งแรงดัน <code>100kΩ / 200kΩ</code> ลง GND</td>
        <td>อ่านสัญญาณที่ตัวเองส่งออกไปเพื่อตรวจสอบความถูกต้อง</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 4</span></td>
        <td>เซนเซอร์วัดอุณหภูมิ <b>DHT11</b></td>
        <td>ขา <code>DATA</code> (ส่วนไฟเลี้ยงต่อ <code>3V3</code> และ <code>GND</code>)</td>
        <td>วัดอุณหภูมิห้องส่งไปในเฟรมสายแอร์แทนเทอร์มิสเตอร์ของ Panel</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 18 (RX2)</span></td>
        <td>โมดูลวัดไฟ <b>PZEM-004T</b></td>
        <td>ต่อเข้าขา <code>TX</code> ของ PZEM</td>
        <td><b>⚠️ ต่างจากรุ่น IR!</b> (รุ่นสายแอร์ใช้ RX=18)</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 14 (TX2)</span></td>
        <td>โมดูลวัดไฟ <b>PZEM-004T</b></td>
        <td>ต่อเข้าขา <code>RX</code> ของ PZEM</td>
        <td><b>⚠️ ต่างจากรุ่น IR!</b> (รุ่นสายแอร์ใช้ TX=14)</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 25, 26, 23</span></td>
        <td>หลอด LED เขียว / แดง / เหลือง</td>
        <td>ผ่าน R 220Ω ลง GND</td>
        <td><b>⚠️ LED เหลืองย้ายมา GPIO 23</b> (ส่วนเขียว=25, แดง=26 เหมือนเดิม)</td>
      </tr>
      <tr>
        <td><span class="pin-pill">GPIO 21 / 22</span></td>
        <td>จอแสดงผล OLED 1.3" (SH1106)</td>
        <td><code>21 ➔ SDA</code>, <code>22 ➔ SCL</code></td>
        <td>แสดงป้ายพิเศษ <code>BUS</code> และ <code>COMP ON</code> (ตั้งหมุนจอ 180° ในโค้ด)</td>
      </tr>
    </tbody>
  </table>
</div>


<!-- ===================================================================== -->
<!-- PAGE 4: คู่มือการประกอบ แบบที่ 3 (Occupancy) + การอัปโหลดโค้ดใช้งานจริง -->
<!-- ===================================================================== -->
<div class="page">
  <div class="sec-title green">5. คู่มือการประกอบแบบที่ 3: กล่องตรวจจับคนในห้อง (Occupancy Radar Box)</div>

  <div class="photo-box" style="border-color:#a7f3d0; background:#ecfdf5;">
    <img src="{b64_occ}" alt="กล่องตรวจจับคน HLK-LD2410">
    <div class="photo-info">
      <h3 style="font-size:15px; color:#065f46; margin-bottom:4px;">📦 รายการอุปกรณ์เฉพาะของกล่องแบบที่ 3 (ตรวจจับคน)</h3>
      <p style="font-size:12px; color:#047857; margin-bottom:6px;"><i>* กล่องนี้ไม่มีไฟบ้าน 220V ใช้ไฟเลี้ยง 5V จากสาย USB Type-C เสียบเข้าบอร์ด ESP32 โดยตรง ปลอดภัยและประกอบง่ายที่สุด *</i></p>
      <div class="grid-2" style="font-size:12px; gap:6px;">
        <div>
          1. <b>ESP32 (IOXESP32 พอร์ต USB Type-C)</b> (1 บอร์ด)<br>
          2. <b>ฐานขยายขา ESP32 Terminal Adapter</b> (1 ชิ้น)<br>
          3. <b>เซนเซอร์เรดาร์ HLK-LD2410 (24GHz mmWave)</b> (1 โมดูล)<br>
          4. <b>สายแพรจัมเปอร์ / สายไฟอ่อน 4 เส้น</b> (แดง, ดำ, เขียว, น้ำตาล)
        </div>
        <div>
          5. <b>แผ่นปริ้นท์ไข่ปลาขนาดเล็ก (2x3 cm)</b> (ติดที่ฝาหน้า)<br>
          6. <b>หลอดไฟ LED 2 สี (สีเขียว 1 ดวง, สีแดง 1 ดวง)</b><br>
          7. <b>ตัวต้านทาน 220Ω–330Ω</b> (2 ตัว สำหรับดรอปกระแสไฟ LED)<br>
          8. <b>กล่อง 3D Print ทรงผืนผ้า</b> + <b>อะแดปเตอร์และสาย USB Type-C</b>
        </div>
      </div>
    </div>
  </div>

  <div class="grid-2" style="margin-bottom: 10px;">
    <div>
      <h4 style="font-size:13.5px; color:#065f46; margin-bottom: 6px;">🔧 ลำดับขั้นตอนการประกอบ (กล่องตรวจจับคน)</h4>
      <div class="step-list">
        <div class="step-item">
          <div class="step-num green">1</div>
          <div style="font-size:12px;">
            <b>บัดกรีชุดไฟ LED 2 ดวงที่ฝาหน้า (ซ้ายมือของรูป):</b><br>
            ตัดแผ่นปริ้นท์ไข่ปลาขนาดพอดีกรอบฝาหน้า บัดกรีหลอด <b>LED สีเขียว</b> และ <b>LED สีแดง</b> ให้หัวหลอดโผล่ออกช่องหน้าต่างฝาหน้า ต่อขาบวกแต่ละหลอดผ่านตัวต้านทาน <code>220Ω–330Ω</code> (สายสีเขียวและสีแดง) และรวมขาลบเข้าด้วยกันเป็นสาย <code>GND</code> (สายสีน้ำตาล)
          </div>
        </div>
        <div class="step-item">
          <div class="step-num green">2</div>
          <div style="font-size:12px;">
            <b>ติดตั้งเรดาร์ HLK-LD2410 ลงบล็อกด้านบนของกล่อง:</b><br>
            บัดกรีหรือเสียบสายไฟ 4 เส้นเข้าที่รูพินด้านหลังของโมดูลเรดาร์ <code>HLK-LD2410</code> (เรียงจากซ้ายไปขวาตามรูป: <code>TX, RX, OUT, GND, VCC</code> โดยขา <code>OUT</code> ไม่ต้องต่อ) แล้วกดโมดูลลงในบล็อกล็อกด้านบนของกล่อง ลอดสายผ่านร่องกั้นกลางลงมาหาบอร์ด ESP32
          </div>
        </div>
        <div class="step-item">
          <div class="step-num green">3</div>
          <div style="font-size:12px;">
            <b>เสียบ ESP32 ลงฐาน Terminal และขันน็อตสายไฟ:</b><br>
            วางฐาน Terminal ลงกล่องโดยหันช่องเสียบ <b>USB Type-C ลงด้านล่าง</b> ให้ตรงกับรูเปิดของกล่อง จากนั้นขันน็อตสายไฟทั้งจากเรดาร์และจากแผ่น LED ฝาหน้าตามตารางด้านขวา
          </div>
        </div>
      </div>
    </div>

    <div>
      <h4 style="font-size:13.5px; color:#065f46; margin-bottom: 6px;">📌 ตารางการต่อสายกล่องที่ 3 (Occupancy)</h4>
      <table>
        <thead>
          <tr>
            <th style="background:#059669; border-color:#059669;">ขาพิน ESP32</th>
            <th style="background:#059669; border-color:#059669;">ต่อเข้ากับขาของอุปกรณ์</th>
            <th style="background:#059669; border-color:#059669;">สีสายในรูป / หน้าที่</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td><span class="pin-pill">5V (VIN)</span></td>
            <td>ขา <code>VCC</code> ของเรดาร์ LD2410</td>
            <td>สายสีแดง (เรดาร์ต้องการไฟ 5V)</td>
          </tr>
          <tr>
            <td><span class="pin-pill">GND</span></td>
            <td>ขา <code>GND</code> ของเรดาร์ + ขาลบร่วม LED</td>
            <td>สายสีดำ (เรดาร์) & สายสีน้ำตาล (LED)</td>
          </tr>
          <tr>
            <td><span class="pin-pill">GPIO 32 (RX1)</span></td>
            <td>ขา <code>TX</code> ของเรดาร์ LD2410</td>
            <td>รับข้อมูลพลังงานรายเกต (256000 baud)</td>
          </tr>
          <tr>
            <td><span class="pin-pill">GPIO 33 (TX1)</span></td>
            <td>ขา <code>RX</code> ของเรดาร์ LD2410</td>
            <td>ส่งคำสั่งเปิด Engineering Mode</td>
          </tr>
          <tr>
            <td><span class="pin-pill">GPIO 25</span></td>
            <td>ขาบวก <b>LED สีเขียว</b> (ผ่าน R 220Ω)</td>
            <td>กระพริบ=กำลังต่อเน็ต, ติดค้าง=ออนไลน์</td>
          </tr>
          <tr>
            <td><span class="pin-pill">GPIO 26</span></td>
            <td>ขาบวก <b>LED สีแดง</b> (ผ่าน R 220Ω)</td>
            <td>ติดสว่าง=ตรวจพบคนในห้อง, ดับ=ห้องว่าง</td>
          </tr>
        </tbody>
      </table>
      <div class="tip-box" style="margin-top:4px; font-size:11.5px;">
        💡 <b>เคล็ดลับการติดตั้งหน้างาน:</b> หันด้านหน้าแผ่นทองแดงสายอากาศของเรดาร์ LD2410 ออกสู่พื้นที่นั่งเรียน และเสียบสาย USB Type-C เข้ากับหัวชาร์จ 5V/1A มาตรฐาน
      </div>
    </div>
  </div>

  <div class="sec-title purple">6. ขั้นตอนการอัปโหลดโค้ด (Flash Firmware) และการลงทะเบียนเข้าแอปใช้งานจริง</div>
  <div class="step-list">
    <div class="step-item">
      <div class="step-num purple">1</div>
      <div style="font-size:12px;">
        <b>ติดตั้งโปรแกรม Arduino IDE และชุดไลบรารีที่จำเป็นบนคอมพิวเตอร์:</b><br>
        • ติดตั้ง <b>ESP32 Board Package (เวอร์ชัน 3.x)</b> ใน Boards Manager<br>
        • เข้า Library Manager ติดตั้งไลบรารี: <code>ArduinoJson (เวอร์ชัน 6.x เท่านั้น)</code>, <code>PubSubClient</code>, <code>PZEM004Tv30</code>, <code>U8g2</code> (สำหรับจอ OLED)<br>
        • ติดตั้งเพิ่มตามชนิดกล่อง: กล่องที่ 1 ติดตั้ง <code>IRremoteESP8266 (v2.9.0)</code> | กล่องที่ 2 ติดตั้ง <code>DHT sensor library (Adafruit)</code> | กล่องที่ 3 ติดตั้ง <code>ld2410 (v0.2.2 ขึ้นไป)</code>
      </div>
    </div>

    <div class="step-item">
      <div class="step-num purple">2</div>
      <div style="font-size:12px;">
        <b>ตั้งค่าบอร์ดในเมนู Tools และเลือกไฟล์โค้ดให้ตรงกับกล่อง:</b><br>
        • เปิดไฟล์สเก็ตช์ในโฟลเดอร์ <code>firmware/</code> ให้ตรงกล่อง: กล่อง 1 = <code>rmutt_esp32_air/rmutt_esp32_air.ino</code> | กล่อง 2 = <code>rmutt_esp32_air_wired/rmutt_esp32_air_wired.ino</code> | กล่อง 3 = <code>rmutt_esp32_occupancy/rmutt_esp32_occupancy.ino</code><br>
        • ไปที่เมนู <b>Tools ➔ Board:</b> เลือก <code>ESP32 Dev Module</code> | <b>Tools ➔ Partition Scheme:</b> เลือก <code>No FS 4MB (2MB APP x2)</code> (เพื่อให้ใช้ตาราง <code>partitions.csv</code> ในโฟลเดอร์ได้พอดีแฟลช)
      </div>
    </div>

    <div class="step-item">
      <div class="step-num purple">3</div>
      <div style="font-size:12px;">
        <b>เสียบสาย USB Type-C อัปโหลดโค้ด และตรวจสอบผ่าน Serial Monitor:</b><br>
        • <b>(สำคัญ: ถอดปลั๊ก 220V ออกก่อนเสียบ USB!)</b> เสียบสาย USB Type-C จากคอมพิวเตอร์เข้าบอร์ด ESP32 เลือกพอร์ต <code>COM</code> ให้ถูกต้อง แล้วกดปุ่ม <b>Upload (ลูกศรชี้ขวา)</b><br>
        • เมื่อขึ้น <code>Done uploading.</code> ให้เปิด <b>Serial Monitor (ตั้งความเร็ว <code>115200 baud</code>)</b> จะเห็นข้อความบูตระบบและชื่อสัญญาณบลูทูธ เช่น <code>RMUTT-AC-xxxxxxxxxxxx</code> หรือ <code>RMUTT-OCC-xxxxxxxxxxxx</code>
      </div>
    </div>

    <div class="step-item">
      <div class="step-num purple">4</div>
      <div style="font-size:12px;">
        <b>การตั้งค่าจับคู่ผ่าน Bluetooth BLE ด้วยแอปมือถือ (Provisioning):</b><br>
        • ปิดฝากล่อง นำไปติดตั้งหน้างานและจ่ายไฟ เปิดแอปพลิเคชัน <b>RMUTT Save Energy</b> (ล็อกอินบัญชี Admin) เข้าไปที่ห้องเรียนที่ต้องการ<br>
        • กดปุ่ม <b>เพิ่มเครื่องปรับอากาศ ESP32</b> (สำหรับกล่อง 1 และ 2) หรือ <b>ตั้งค่าเซนเซอร์ตรวจจับคน</b> (สำหรับกล่อง 3)<br>
        • เลือกชื่อบอร์ดที่ค้นพบทาง Bluetooth ➔ เลือกชื่อ Wi-Fi และกรอกรหัสผ่าน ➔ เลือกยี่ห้อแอร์ (สำหรับกล่อง 1 ส่วนกล่อง 2 จะล็อกเป็น <code>Daikin · สายแอร์</code> อัตโนมัติ) ➔ กดบันทึก บอร์ดจะรีสตาร์ท ต่อ Wi-Fi/MQTT และพร้อมใช้งานทันที! <i>(หากต้องการตั้งค่าใหม่ภายหลัง ให้กดปุ่ม <code>BOOT</code> บนบอร์ดค้างไว้ขณะเสียบไฟหรือกด Reset)</i>
      </div>
    </div>
  </div>
</div>

</body>
</html>
"""

out_dir = r"C:\Users\rapee\Documents\GitHub\cpe_air_remote"
html_path_ascii = os.path.join(out_dir, "Hardware_Assembly_Manual_3_Types.html")
html_path_thai = os.path.join(out_dir, "คู่มือศึกษาโปรเจค", "คู่มือการประกอบฮาร์ดแวร์ทั้ง_3_แบบ_ฉบับสมบูรณ์.html")

with open(html_path_ascii, "w", encoding="utf-8") as f:
    f.write(html_doc)
with open(html_path_thai, "w", encoding="utf-8") as f:
    f.write(html_doc)

print("Generated Hardware Assembly Manual HTML successfully!")
