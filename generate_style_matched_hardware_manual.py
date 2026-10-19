import os
import base64

img_wired = r"C:\Users\rapee\.gemini\antigravity\brain\d65e9246-7513-4315-acfd-6984cf5f79f3\.user_uploaded\media_1792318100591_3eedc695.jpg"
img_ir = r"C:\Users\rapee\.gemini\antigravity\brain\d65e9246-7513-4315-acfd-6984cf5f79f3\.user_uploaded\media_1792318114604_a2b2cddc.png"
img_occ = r"C:\Users\rapee\.gemini\antigravity\brain\d65e9246-7513-4315-acfd-6984cf5f79f3\.user_uploaded\media_1792318121777_db0131cd.png"

def to_b64(path, mime="image/png"):
    with open(path, "rb") as f:
        return f"data:{mime};base64," + base64.b64encode(f.read()).decode("utf-8")

b64_wired = to_b64(img_wired, "image/jpeg")
b64_ir = to_b64(img_ir, "image/png")
b64_occ = to_b64(img_occ, "image/png")

TOTAL_PAGES = 13

def make_footer(page_num, is_cover=False):
    if is_cover:
        return f"""
        <div class="footer cover-footer">
          <span>RMUTT Save Energy · คู่มือการประกอบและติดตั้งฮาร์ดแวร์</span>
          <span>{page_num} / {TOTAL_PAGES}</span>
        </div>
        """
    return f"""
    <div class="footer">
      <span>RMUTT Save Energy · คู่มือการประกอบและติดตั้งฮาร์ดแวร์</span>
      <span>{page_num} / {TOTAL_PAGES}</span>
    </div>
    """

html_content = f"""<!DOCTYPE html>
<html lang="th">
<head>
<meta charset="UTF-8">
<title>คู่มือการประกอบและติดตั้งฮาร์ดแวร์ ระบบ RMUTT Save Energy</title>
<link href="https://fonts.googleapis.com/css2?family=Sarabun:wght@300;400;500;600;700;800&family=Kanit:wght@400;500;600;700&family=JetBrains+Mono:wght@400;600;700&display=swap" rel="stylesheet">
<style>
  @page {{
    size: A4 portrait;
    margin: 0;
  }}
  * {{
    box-sizing: border-box;
    margin: 0;
    padding: 0;
  }}
  body {{
    font-family: 'Sarabun', sans-serif;
    color: #1f2937;
    background: #e5e7eb;
    font-size: 13.2px;
    line-height: 1.56;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
  }}
  .page {{
    width: 210mm;
    height: 297mm;
    background: #ffffff;
    position: relative;
    padding: 18mm 20mm 22mm 20mm;
    page-break-after: always;
    overflow: hidden;
    margin: 0 auto;
  }}
  .page:last-child {{
    page-break-after: auto;
  }}

  /* Cover Page (Page 1) */
  .page.cover {{
    background: linear-gradient(150deg, #272c33 0%, #272c33 52%, #1d3b2a 78%, #156534 100%);
    color: #ffffff;
    padding: 36mm 24mm 22mm 24mm;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
  }}
  .cover-logo {{
    margin-bottom: 28px;
  }}
  .cover-title {{
    font-family: 'Kanit', sans-serif;
    font-size: 38px;
    font-weight: 700;
    line-height: 1.22;
    color: #ffffff;
    margin-bottom: 18px;
  }}
  .cover-tag {{
    font-family: 'Kanit', sans-serif;
    font-size: 15px;
    font-weight: 600;
    color: #34d399;
    letter-spacing: 5px;
    margin-bottom: 24px;
  }}
  .cover-desc {{
    font-size: 16.5px;
    line-height: 1.65;
    color: #f3f4f6;
    font-weight: 400;
  }}
  .cover-bottom {{
    margin-top: auto;
    margin-bottom: 18px;
  }}
  .cover-divider {{
    height: 2px;
    background: #22c55e;
    margin-bottom: 16px;
  }}
  .cover-meta {{
    font-size: 13px;
    line-height: 1.7;
    color: #d1d5db;
  }}

  /* Running Footer */
  .footer {{
    position: absolute;
    bottom: 10mm;
    left: 20mm;
    right: 20mm;
    display: flex;
    justify-content: space-between;
    font-size: 11px;
    color: #6b7280;
  }}
  .footer.cover-footer {{
    left: 24mm;
    right: 24mm;
    color: #9ca3af;
  }}

  /* Chapter & Section Headings */
  .ch-header {{
    font-family: 'Kanit', sans-serif;
    font-size: 25px;
    font-weight: 700;
    color: #1f2937;
    padding-bottom: 6px;
    border-bottom: 2.5px solid #16a34a;
    margin-bottom: 14px;
    display: flex;
    align-items: baseline;
    gap: 10px;
  }}
  .ch-header .ch-num {{
    color: #16a34a;
  }}

  .sec-header {{
    font-family: 'Kanit', sans-serif;
    font-size: 16px;
    font-weight: 600;
    color: #15803d;
    margin-top: 12px;
    margin-bottom: 5px;
  }}
  .sub-header {{
    font-family: 'Kanit', sans-serif;
    font-size: 14px;
    font-weight: 600;
    color: #111827;
    margin-top: 8px;
    margin-bottom: 4px;
  }}

  p {{
    margin-bottom: 7px;
  }}

  /* TOC Styling (Page 2) */
  .toc-list {{
    display: flex;
    flex-direction: column;
    margin-top: 6px;
  }}
  .toc-item {{
    padding: 11px 0;
    border-bottom: 1px solid #e5e7eb;
  }}
  .toc-title {{
    font-family: 'Kanit', sans-serif;
    font-size: 15.5px;
    font-weight: 600;
    color: #15803d;
    margin-bottom: 3px;
    display: flex;
    justify-content: space-between;
  }}
  .toc-title .toc-page {{
    color: #6b7280;
    font-weight: 500;
    font-size: 13.5px;
  }}
  .toc-sub {{
    font-size: 13.5px;
    color: #374151;
  }}

  /* Bullets */
  ul.clean-list {{
    padding-left: 20px;
    margin-bottom: 8px;
  }}
  ul.clean-list li {{
    margin-bottom: 4px;
  }}

  /* Numbered Green Step List */
  .step-row {{
    display: flex;
    align-items: flex-start;
    gap: 10px;
    margin-bottom: 6.5px;
  }}
  .step-circle {{
    background: #15803d;
    color: #ffffff;
    font-family: 'Kanit', sans-serif;
    font-size: 12px;
    font-weight: 700;
    min-width: 22px;
    height: 22px;
    border-radius: 50%;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    margin-top: 2px;
  }}
  .step-text {{
    flex: 1;
    font-size: 13px;
    line-height: 1.5;
  }}

  /* Tables */
  table.clean-table {{
    width: 100%;
    border-collapse: collapse;
    margin: 6px 0 10px 0;
    font-size: 12.2px;
  }}
  table.clean-table th {{
    background: #27272a;
    color: #ffffff;
    font-family: 'Kanit', sans-serif;
    font-weight: 600;
    text-align: left;
    padding: 6px 9px;
  }}
  table.clean-table td {{
    padding: 5.5px 9px;
    border-bottom: 1px solid #e5e7eb;
    vertical-align: top;
    line-height: 1.45;
  }}

  /* Callout Boxes */
  .callout {{
    background: #f1f5f9;
    border-left: 4px solid #0284c7;
    border-radius: 0 8px 8px 0;
    padding: 9px 14px;
    margin: 8px 0;
    font-size: 12.5px;
    line-height: 1.5;
  }}
  .callout-title {{
    font-family: 'Kanit', sans-serif;
    font-weight: 600;
    color: #0f172a;
    margin-bottom: 2px;
    font-size: 13.2px;
  }}
  .callout.warn {{
    background: #fffbeb;
    border-left-color: #d97706;
  }}
  .callout.danger {{
    background: #fef2f2;
    border-left-color: #dc2626;
  }}

  /* Annotated Figure Container */
  .fig-box {{
    margin: 6px 0 8px 0;
    text-align: center;
  }}
  .fig-frame {{
    position: relative;
    display: inline-block;
    border-radius: 10px;
    overflow: hidden;
    border: 1.5px solid #cbd5e1;
    background: #18181b;
    padding: 6px;
  }}
  .fig-frame img {{
    display: block;
    border-radius: 6px;
  }}
  .fig-caption {{
    font-size: 12.2px;
    color: #4b5563;
    margin-top: 4px;
    text-align: center;
  }}

  /* Orange Numbered Callout Marker on Photos */
  .marker {{
    position: absolute;
    width: 24px;
    height: 24px;
    border-radius: 50%;
    background: #f97316;
    border: 2px solid #ffffff;
    color: #ffffff;
    font-family: 'Kanit', sans-serif;
    font-size: 12.5px;
    font-weight: 700;
    display: flex;
    align-items: center;
    justify-content: center;
    box-shadow: 0 2px 6px rgba(0,0,0,0.45);
  }}

  /* Architecture Flow Boxes */
  .arch-flow {{
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 6px;
    margin: 10px 0 14px 0;
  }}
  .arch-node {{
    flex: 1;
    background: #f8fafc;
    border: 1.5px solid #cbd5e1;
    border-radius: 10px;
    padding: 10px 8px;
    text-align: center;
    font-size: 12px;
    line-height: 1.4;
  }}
  .arch-node.highlight {{
    background: #f0fdf4;
    border-color: #16a34a;
  }}
  .arch-node b {{
    font-family: 'Kanit', sans-serif;
    display: block;
    font-size: 13px;
    color: #111827;
    margin-bottom: 3px;
  }}
  .arch-arrow {{
    font-size: 16px;
    color: #64748b;
    font-weight: 700;
  }}

  code {{
    font-family: 'JetBrains Mono', monospace;
    font-size: 11px;
    background: #f1f5f9;
    border: 1px solid #e2e8f0;
    padding: 1px 5px;
    border-radius: 4px;
    color: #0f172a;
  }}

  .led-dot {{
    display: inline-block;
    width: 10px;
    height: 10px;
    border-radius: 50%;
    margin-right: 5px;
  }}
</style>
</head>
<body>

<!-- ===================================================================== -->
<!-- PAGE 1: COVER PAGE                                                    -->
<!-- ===================================================================== -->
<div class="page cover">
  <div>
    <div class="cover-logo">
      <svg width="78" height="82" viewBox="0 0 78 82" fill="none">
        <path d="M12 10H38C50 10 58 17 58 28C58 36 53 42 44 44L56 66H41L30 45H25V66H12V10ZM25 21V34H37C42 34 45 31.5 45 27.5C45 23.5 42 21 37 21H25Z" fill="#FFFFFF"/>
        <path d="M40 48C48 48 62 53 66 70C52 70 42 62 40 48Z" fill="#22C55E"/>
        <path d="M42 51C49 56 55 61 62 68" stroke="#14532D" stroke-width="2" stroke-linecap="round"/>
      </svg>
    </div>

    <div class="cover-title">
      คู่มือการประกอบฮาร์ดแวร์<br>
      ระบบ RMUTT Save Energy
    </div>

    <div class="cover-tag">S A V E &nbsp; E N E R G Y</div>

    <div class="cover-desc">
      การเตรียมอุปกรณ์ การบัดกรีวงจร การเดินสายในกล่อง และการอัปโหลดเฟิร์มแวร์ ESP32<br>
      สำหรับบอร์ดควบคุมแอร์ (รีโมต IR และสายแอร์ Daikin SLM8) และเซ็นเซอร์ตรวจจับคน<br>
      อาคาร 16 · คณะวิศวกรรมศาสตร์ มหาวิทยาลัยเทคโนโลยีราชมงคลธัญบุรี
    </div>
  </div>

  <div class="cover-bottom">
    <div class="cover-divider"></div>
    <div class="cover-meta">
      เอกสารฉบับวิศวกรรมและผู้ดูแลระบบ · จัดทำเมื่อวันที่ 18 ตุลาคม 2569<br>
      อ้างอิงเฟิร์มแวร์บอร์ดแอร์ IR รุ่น 2.5.2 · บอร์ดสายแอร์รุ่น 2.5.5-slm8 · บอร์ดตรวจจับคนรุ่น 1.3.9<br>
      ครอบคลุมรายการวัสดุอุปกรณ์ ขั้นตอนการประกอบทีละขั้น ผังขาพิน และการตั้งค่าเข้าสู่ระบบ
    </div>
  </div>

  {make_footer(1, is_cover=True)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 2: TABLE OF CONTENTS (สารบัญ)                                    -->
<!-- ===================================================================== -->
<div class="page">
  <div class="ch-header">สารบัญ</div>

  <div class="toc-list">
    <div class="toc-item">
      <div class="toc-title"><span>1 · ภาพรวมชุดฮาร์ดแวร์ในระบบ</span><span class="toc-page">หน้า 3</span></div>
      <div class="toc-sub">หน้าที่ของกล่องทั้ง 3 แบบ · ความเชื่อมโยงในระบบ · ตารางเปรียบเทียบสเปกแต่ละบอร์ด</div>
    </div>

    <div class="toc-item">
      <div class="toc-title"><span>2 · อุปกรณ์เสริม สายไฟ และเครื่องมือช่างที่ต้องเตรียม</span><span class="toc-page">หน้า 4</span></div>
      <div class="toc-sub">สายไฟบ้าน AC 220V · ขั้วต่อแยกสายไฟ Wago · สายสัญญาณ · แผ่นปริ้นท์ไข่ปลา · เครื่องมือช่าง</div>
    </div>

    <div class="toc-item">
      <div class="toc-title"><span>3 · การประกอบบอร์ดควบคุมแอร์แบบอินฟราเรด (IR)</span><span class="toc-page">หน้า 5 – 6</span></div>
      <div class="toc-sub">รายการอุปกรณ์ · ตำแหน่งภายในกล่อง · การบัดกรีวงจร 2N2222 และไฟ LED · การเดินสายไฟ · ตารางขาพิน</div>
    </div>

    <div class="toc-item">
      <div class="toc-title"><span>4 · การประกอบบอร์ดควบคุมแอร์แบบสายแอร์ (Daikin SLM8)</span><span class="toc-page">หน้า 7 – 8</span></div>
      <div class="toc-sub">รายการอุปกรณ์เพิ่มเติม · วงจรไดโอด 1N4148 และตัวแบ่งแรงดัน 100k/200k · การต่อ DHT11 · การต่อสายแอร์บนผนัง</div>
    </div>

    <div class="toc-item">
      <div class="toc-title"><span>5 · การประกอบกล่องเซ็นเซอร์ตรวจจับคน (HLK-LD2410)</span><span class="toc-page">หน้า 9</span></div>
      <div class="toc-sub">รายการอุปกรณ์ · การบัดกรีไฟ LED ฝาหน้า · การติดตั้งเรดาร์คลื่นมิลลิเมตร LD2410 · ตารางขาพิน</div>
    </div>

    <div class="toc-item">
      <div class="toc-title"><span>6 · การติดตั้งโปรแกรมและอัปโหลดเฟิร์มแวร์ลง ESP32</span><span class="toc-page">หน้า 10</span></div>
      <div class="toc-sub">การเช็ควงจรด้วยมัลติมิเตอร์ · การตั้งค่า Arduino IDE และไลบรารี · การเลือก Partition · การอัปโหลดผ่านสาย USB</div>
    </div>

    <div class="toc-item">
      <div class="toc-title"><span>7 · การตั้งค่าบอร์ดผ่านบลูทูธและการติดตั้งหน้างาน</span><span class="toc-page">หน้า 11</span></div>
      <div class="toc-sub">การจองช่องและสร้างโทเคน · การจับคู่บลูทูธในแอปมือถือ · การคล้องห่วง CT และการตรวจหน้าจอ OLED</div>
    </div>

    <div class="toc-item">
      <div class="toc-title"><span>ภาคผนวก ก · ความหมายไฟแสดงสถานะ LED และหน้าจอ OLED</span><span class="toc-page">หน้า 12</span></div>
      <div class="toc-sub">ไฟสถานะ 3 สีบนบอร์ดแอร์ · ไฟสถานะ 2 สีบนเซ็นเซอร์ตรวจจับคน · สัญลักษณ์บนจอ OLED 1.3 นิ้ว</div>
    </div>

    <div class="toc-item">
      <div class="toc-title"><span>ภาคผนวก ข · การแก้ปัญหาฮาร์ดแวร์และการอัปโหลดโค้ดเบื้องต้น</span><span class="toc-page">หน้า 13</span></div>
      <div class="toc-sub">อาการที่พบบ่อย · สาเหตุ · วิธีตรวจสอบและแก้ไขหน้างาน</div>
    </div>
  </div>

  {make_footer(2)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 3: บทที่ 1 ภาพรวมชุดฮาร์ดแวร์ในระบบ                              -->
<!-- ===================================================================== -->
<div class="page">
  <div class="ch-header"><span class="ch-num">1</span> ภาพรวมชุดฮาร์ดแวร์ในระบบ</div>

  <div class="sec-header">ฮาร์ดแวร์ทั้ง 3 แบบทำหน้าที่อะไร</div>
  <p>
    ระบบ RMUTT Save Energy ใช้บอร์ดไมโครคอนโทรลเลอร์ <b>ESP32</b> เป็นหัวใจหลักของอุปกรณ์หน้าห้องเรียน แบ่งออกเป็น <b>3 รูปแบบ</b> ตามลักษณะของเครื่องปรับอากาศและหน้าที่ในห้องเรียน โดยทุกกล่องใช้บลูทูธ (BLE) สำหรับตั้งค่าครั้งแรก และสื่อสารกับเซิร์ฟเวอร์ผ่านโปรโตคอล MQTT บนเครือข่าย Wi-Fi ของอาคาร
  </p>
  <ul class="clean-list">
    <li><b>บอร์ดควบคุมแอร์แบบอินฟราเรด (IR):</b> ใช้กับแอร์ทั่วไปที่สั่งงานด้วยรีโมตไร้สาย (เช่น ห้อง 16303 และ 16307) โดยยิงแสงอินฟราเรด 38 kHz ไปที่หน้าแอร์ และใช้มิเตอร์ PZEM-004T วัดค่าไฟเพื่อยืนยันว่าแอร์ทำงานจริง</li>
    <li><b>บอร์ดควบคุมแอร์แบบสายแอร์ (Daikin SLM8):</b> ใช้แทนรีโมตติดผนังแบบมีสายของแอร์ Daikin โดยรับและส่งเฟรมข้อมูลผ่านสายแอร์โดยตรงทุก 1 วินาที รู้สถานะคอมเพรสเซอร์จริงจากแอร์ และใช้ DHT11 วัดอุณหภูมิห้อง</li>
    <li><b>กล่องเซ็นเซอร์ตรวจจับคน (HLK-LD2410):</b> ติดตั้งห้องละ 1 กล่อง ใช้เรดาร์คลื่นมิลลิเมตร 24 GHz ตรวจจับทั้งคนที่กำลังเดินและคนที่นั่งเรียนนิ่งๆ เพื่อส่งให้เซิร์ฟเวอร์ตัดสินใจปิดแอร์อัตโนมัติเมื่อห้องว่าง</li>
  </ul>

  <div class="sec-header">ความเชื่อมโยงของฮาร์ดแวร์ในระบบ</div>
  <div class="arch-flow">
    <div class="arch-node highlight">
      <b>กล่องที่ 1 · บอร์ดแอร์ IR</b>
      ยิงแสงอินฟราเรดสั่งแอร์<br>วัดไฟด้วย PZEM + จอ OLED
    </div>
    <div class="arch-arrow">⇕</div>
    <div class="arch-node highlight">
      <b>กล่องที่ 2 · บอร์ดสายแอร์</b>
      คุยผ่านสายรีโมตผนัง Daikin<br>วัดอุณหภูมิ DHT11 + PZEM
    </div>
    <div class="arch-arrow">⇕</div>
    <div class="arch-node highlight">
      <b>กล่องที่ 3 · เซ็นเซอร์ตรวจจับคน</b>
      เรดาร์ HLK-LD2410 (24GHz)<br>ตรวจคนนั่งนิ่งและเคลื่อนไหว
    </div>
    <div class="arch-arrow">⇄</div>
    <div class="arch-node">
      <b>เซิร์ฟเวอร์ส่วนกลาง</b>
      MQTT Broker · Backend<br>เว็บแอป & แอปมือถือ
    </div>
  </div>

  <div class="sec-header">ตารางเปรียบเทียบสเปกของฮาร์ดแวร์ทั้ง 3 กล่อง</div>
  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 22%;">ชนิดกล่องฮาร์ดแวร์</th>
        <th style="width: 26%;">ไฟล์เฟิร์มแวร์ (รุ่นล่าสุด)</th>
        <th style="width: 30%;">อุปกรณ์ที่ต่อพ่วงกับ ESP32</th>
        <th style="width: 22%;">แหล่งจ่ายไฟเลี้ยง</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>1. บอร์ดแอร์แบบ IR</b><br>(1 กล่อง ต่อแอร์ 1 เครื่อง)</td>
        <td><code>rmutt_esp32_air.ino</code><br>(รุ่น <b>2.5.2</b>)</td>
        <td>• วงจร 2N2222 + หลอด IR LED<br>• มิเตอร์ PZEM-004T + ห่วง CT<br>• จอ OLED 1.3" + ไฟ LED 3 สี</td>
        <td>ไฟบ้าน AC 220V ผ่านโมดูล HDR-15-5 (แปลงเป็น 5V DC)</td>
      </tr>
      <tr>
        <td><b>2. บอร์ดสายแอร์ Daikin</b><br>(1 กล่อง ต่อแอร์ 1 เครื่อง)</td>
        <td><code>rmutt_esp32_air_wired.ino</code><br>(รุ่น <b>2.5.5-slm8</b>)</td>
        <td>• ไดโอด 1N4148 + ตัวแบ่ง 100k/200k<br>• เซ็นเซอร์อุณหภูมิ DHT11<br>• มิเตอร์ PZEM-004T + จอ OLED + LED</td>
        <td>ไฟบ้าน AC 220V ผ่านโมดูล HDR-15-5 (แปลงเป็น 5V DC)</td>
      </tr>
      <tr>
        <td><b>3. เซ็นเซอร์ตรวจจับคน</b><br>(1 กล่อง ต่อ 1 ห้องเรียน)</td>
        <td><code>rmutt_esp32_occupancy.ino</code><br>(รุ่น <b>1.3.9</b>)</td>
        <td>• เรดาร์ HLK-LD2410 (UART)<br>• ไฟแสดงสถานะ LED 2 สี (เขียว/แดง)</td>
        <td>อะแดปเตอร์ USB 5V เสียบพอร์ต USB Type-C ของบอร์ด</td>
      </tr>
    </tbody>
  </table>

  <div class="callout">
    <div class="callout-title">เหตุผลที่ใช้ระบบวัดไฟแอร์ 1 เฟส (220V) ร่วมกับ PZEM-004T</div>
    โมดูลวัดพลังงาน PZEM-004T ออกแบบมาสำหรับระบบไฟฟ้า 1 เฟส (220V) โดยเฉพาะ ซึ่งสอดคล้องกับเครื่องปรับอากาศในห้องเรียนที่ทดสอบ (16303 และ 16307) ทำให้ใช้ PZEM-004T เพียง 1 ชุดต่อเครื่อง ติดตั้งง่าย ปลอดภัย และไม่ต้องดัดแปลงตู้ไฟ 3 เฟสของอาคาร
  </div>

  {make_footer(3)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 4: บทที่ 2 อุปกรณ์เสริม สายไฟ และเครื่องมือช่างที่ต้องเตรียม     -->
<!-- ===================================================================== -->
<div class="page">
  <div class="ch-header"><span class="ch-num">2</span> อุปกรณ์เสริม สายไฟ และเครื่องมือช่างที่ต้องเตรียม</div>
  <p>
    ในการประกอบฮาร์ดแวร์ทั้ง 3 กล่องให้แข็งแรง ปลอดภัย และพร้อมติดตั้งใช้งานจริง นอกจากบอร์ดไมโครคอนโทรลเลอร์และโมดูลเซ็นเซอร์แล้ว ต้องเตรียมสายไฟ ขั้วต่อ แผ่นวงจร และเครื่องมือช่างดังตารางต่อไปนี้
  </p>

  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 25%;">หมวดอุปกรณ์เสริม</th>
        <th style="width: 38%;">รายการและขนาดที่ใช้จริง</th>
        <th style="width: 37%;">ใช้ทำอะไรในขั้นตอนการประกอบ</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>1. สายไฟแรงดันสูง (AC 220V)</b><br><i>(ใช้ในกล่องแอร์ 1 และ 2)</i></td>
        <td>
          • สายไฟพร้อมปลั๊กตัวผู้ มอก. ชนิด VCT ขนาด 2×0.75 หรือ 2×1.0 ตร.มม. (ยาว 1.5–2 ม.)<br>
          • สายไฟแกนเดี่ยว/สายอ่อนหุ้มฉนวน PVC (THW หรือ VSF) ขนาด 1.0–1.5 ตร.มม. แยกสีน้ำตาล (Line: L) และสีฟ้า (Neutral: N)
        </td>
        <td>
          • นำไฟบ้าน 220V เข้าสู่ตัวกล่องควบคุม<br>
          • ใช้เดินสายพ่วงจากตัวแยกสายไฟไปยังช่องอินพุต AC ของภาคจ่ายไฟ HDR-15-5 และขั้ววัดแรงดันของมิเตอร์ PZEM-004T
        </td>
      </tr>
      <tr>
        <td><b>2. ขั้วต่อแยกสายไฟ AC</b><br><i>(ใช้ในกล่องแอร์ 1 และ 2)</i></td>
        <td>
          • ขั้วต่อสายไฟแบบคันโยก (Wago / Lever-Nut Connector) ชนิด 2 เข้า 2 ออก จำนวน 2 ตัว (สีส้ม-เทา ทนกระแส 32A/250V)
        </td>
        <td>
          • ใช้เป็นจุดพักและแยกสายไฟ 220V ขั้ว L (1 ตัว) และขั้ว N (1 ตัว) ไปจ่ายให้ Power Supply และ PZEM โดยแน่นหนา ไม่ต้องพันเทปดำ และไม่เกิดประกายไฟ
        </td>
      </tr>
      <tr>
        <td><b>3. สายไฟแรงดันต่ำและสายสัญญาณ (DC)</b></td>
        <td>
          • สายไฟอ่อนตัวนำทองแดงขนาด 22–24 AWG หลากสี (แดง, ดำ, เหลือง, เขียว, ขาว, น้ำเงิน)<br>
          • สายแพรจัมเปอร์ (Dupont Wire)<br>
          • สายไฟคู่ แดง-ดำ (ยาว 1.5–3 ม.)
        </td>
        <td>
          • สายสีแดงและดำใช้เดินไฟเลี้ยงกระแสตรง (+5V, +3.3V และ GND)<br>
          • สายสีอื่นๆ ใช้เดินสัญญาณ UART, I2C และ GPIO ขันเข้าฐานสกรูของ ESP32<br>
          • สายคู่แดง-ดำใช้ต่อหลอด IR LED ออกไปติดหน้าแอร์
        </td>
      </tr>
      <tr>
        <td><b>4. แผ่นวงจรและอะไหล่อิเล็กทรอนิกส์ย่อย</b></td>
        <td>
          • แผ่นปริ้นท์ไข่ปลา (Perfboard / Prototype PCB) ขนาด 4×6 ซม. และ 2×3 ซม.<br>
          • ตัวต้านทานขนาด 1/4W ค่า <code>220Ω–330Ω</code> และ <code>100kΩ</code><br>
          • ขั้วต่อสาย JST XH 2.54 มม. และท่อหดหุ้มฉนวน
        </td>
        <td>
          • ใช้เป็นฐานบัดกรีวงจรทรานซิสเตอร์ 2N2222 ขับหลอด IR, วงจรไดโอด 1N4148, วงจรแบ่งแรงดันสายแอร์ และตัวต้านทานจำกัดกระแสของไฟ LED<br>
          • ใช้ท่อหดหุ้มจุดบัดกรีป้องกันสายช็อตกัน
        </td>
      </tr>
      <tr>
        <td><b>5. กล่องบรรจุและเครื่องมือช่าง</b></td>
        <td>
          • กล่องพิมพ์ 3 มิติ (3D Print PLA/PETG) พร้อมฝาหน้าและกรอบยึดจอ OLED<br>
          • หัวแร้งบัดกรี + ตะกั่ว, คีมตัด/ปอกสายไฟ, ไขควงปากแบนขนาดเล็ก (2.0 มม.), มัลติมิเตอร์ดิจิทัล และสายข้อมูล USB Type-C
        </td>
        <td>
          • ใช้ยึดอุปกรณ์ทั้งหมดลงในกล่องให้เป็นระเบียบ<br>
          • ใช้ไขควงปากแบนขันสกรูบนฐานขยายขา ESP32<br>
          • ใช้มัลติมิเตอร์วัดเช็คการลัดวงจรก่อนจ่ายไฟ และใช้สาย USB Type-C อัปโหลดโค้ดจากคอมพิวเตอร์
        </td>
      </tr>
    </tbody>
  </table>

  <div class="callout danger">
    <div class="callout-title">กฎความปลอดภัยสำคัญที่สุดก่อนเริ่มประกอบ</div>
    1) กล่องบอร์ดแอร์แบบที่ 1 และ 2 มีไฟบ้าน <b>AC 220V</b> เข้าที่ตัวแยกสาย Wago, ช่องด้านล่างของภาคจ่ายไฟ HDR-15-5 และขั้วฝั่งซ้ายของ PZEM-004T <b>ห้ามเสียบปลั๊กไฟ 220V ขณะกำลังขันสายไฟหรือบัดกรีเด็ดขาด</b><br>
    2) ทุกครั้งที่จะเสียบสาย USB Type-C จากคอมพิวเตอร์เพื่ออัปโหลดโค้ดหรือดู Serial Monitor <b>ต้องถอดปลั๊กไฟบ้าน 220V ออกก่อนเสมอ</b>
  </div>

  {make_footer(4)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 5: บทที่ 3 การประกอบบอร์ดแอร์แบบ IR (ส่วนประกอบและภาพถ่ายจริง)   -->
<!-- ===================================================================== -->
<div class="page">
  <div class="ch-header"><span class="ch-num">3</span> การประกอบบอร์ดควบคุมแอร์แบบอินฟราเรด (IR)</div>

  <div class="sec-header">3.1 รายการอุปกรณ์และตำแหน่งภายในกล่องบอร์ดแอร์ IR</div>
  <p>บอร์ดแอร์ IR ใช้สำหรับแอร์ทั่วไปที่สั่งงานด้วยรีโมตอินฟราเรด หนึ่งกล่องใช้ควบคุมแอร์ 1 เครื่อง โดยมีตำแหน่งการจัดวางอุปกรณ์ภายในกล่องดังนี้</p>

  <div class="fig-box">
    <div class="fig-frame">
      <img src="{b64_ir}" style="width: 480px; height: 330px; object-fit: cover;">
      <div class="marker" style="top: 46px; left: 115px;">1</div>
      <div class="marker" style="top: 76px; left: 295px;">2</div>
      <div class="marker" style="top: 10px; left: 310px;">3</div>
      <div class="marker" style="top: 50px; left: 398px;">4</div>
      <div class="marker" style="top: 142px; left: 295px;">5</div>
      <div class="marker" style="top: 142px; left: 418px;">6</div>
      <div class="marker" style="top: 188px; left: 275px;">7</div>
      <div class="marker" style="top: 248px; left: 92px;">8</div>
    </div>
    <div class="fig-caption">รูปที่ 3-1 ตำแหน่งอุปกรณ์และการเดินสายภายในกล่องบอร์ดควบคุมแอร์แบบอินฟราเรด (IR)</div>
  </div>

  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 7%;">#</th>
        <th style="width: 33%;">ส่วนประกอบในรูปที่ 3-1</th>
        <th style="width: 60%;">หน้าที่และการติดตั้ง</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>1</b></td>
        <td><b>จอ OLED 1.3 นิ้ว (I2C SH1106)</b></td>
        <td>ขันสกรูยึดกับกรอบด้านในฝาหน้า แสดงสถานะแอร์ อุณหภูมิ กำลังไฟ (W) และสถานะ Wi-Fi</td>
      </tr>
      <tr>
        <td><b>2</b></td>
        <td><b>ESP32 + ฐานขยายขาขันสกรู</b></td>
        <td>บอร์ดประมวลผลหลัก เสียบลงบนฐาน ESP32 Terminal Adapter เพื่อขันสกรูสายไฟให้แน่นหนา</td>
      </tr>
      <tr>
        <td><b>3</b></td>
        <td><b>ไฟสถานะ LED 3 สี (แดง/เหลือง/เขียว)</b></td>
        <td>ยื่นหัวหลอดออกด้านบนกล่อง แสดงสถานะแอร์ทำงาน (เขียว), นอกคาบ (แดง), และ Wi-Fi (เหลือง)</td>
      </tr>
      <tr>
        <td><b>4</b></td>
        <td><b>แผงวงจรย่อย (ทรานซิสเตอร์ 2N2222)</b></td>
        <td>แผ่นปริ้นท์ไข่ปลาขนาด 4×6 ซม. บัดกรีทรานซิสเตอร์ 2N2222 + ตัวต้านทาน 220Ω สำหรับขยายกระแสขับหลอด IR LED</td>
      </tr>
      <tr>
        <td><b>5</b></td>
        <td><b>มิเตอร์วัดไฟ PZEM-004T v3.0</b></td>
        <td>วัดแรงดัน (V), กระแส (A), กำลังไฟ (W) และหน่วยไฟสะสม (kWh) ส่งเข้า ESP32 ทาง UART</td>
      </tr>
      <tr>
        <td><b>6</b></td>
        <td><b>ภาคจ่ายไฟ MeanWell HDR-15-5</b></td>
        <td>แปลงไฟบ้าน AC 220V เป็นไฟเลี้ยงกระแสตรง DC 5V (2.4A) จ่ายให้บอร์ด ESP32 และโมดูลทั้งหมด</td>
      </tr>
      <tr>
        <td><b>7</b></td>
        <td><b>ขั้วต่อแยกสายไฟ Wago (สีส้ม)</b></td>
        <td>รับไฟ 220V (สายสีน้ำตาล L และสีฟ้า N) จากสายปลั๊กหลัก แล้วแยกจ่ายไปให้ HDR-15-5 และ PZEM</td>
      </tr>
      <tr>
        <td><b>8</b></td>
        <td><b>ห่วงคล้อง CT Sensor + สายหลอด IR</b></td>
        <td>ห่วง CT สีดำนำไปคล้องสายเมนไฟแอร์ 1 เส้น ส่วนสายคู่แดง-ดำต่อหลอด IR LED ไปติดหน้าแอร์</td>
      </tr>
    </tbody>
  </table>

  {make_footer(5)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 6: บทที่ 3 (ต่อ) ขั้นตอนการประกอบกล่องแอร์ IR ทีละขั้น + Pinout   -->
<!-- ===================================================================== -->
<div class="page">
  <div class="sec-header" style="margin-top: 0;">3.2 ขั้นตอนการประกอบบอร์ดแอร์ IR ทีละขั้น (เริ่มจากศูนย์จนครบกล่อง)</div>

  <div class="sub-header">ขั้นที่ 1 · บัดกรีแผงวงจรย่อยบนแผ่นปริ้นท์ไข่ปลา (ทำนอกกล่องก่อน)</div>
  <div class="step-row">
    <div class="step-circle">1</div>
    <div class="step-text"><b>บัดกรีหลอดไฟสถานะ LED 3 สี:</b> เสียบหลอด LED สีแดง เหลือง เขียว เรียงที่ขอบบนของแผ่นปริ้นท์ไข่ปลา ดัด <b>ขาสั้น (ขาลบ)</b> ของทั้ง 3 หลอดเชื่อมรวมกันเป็นสาย <code>GND</code> เส้นเดียว ส่วน <b>ขายาว (ขาบวก)</b> ของแต่ละหลอดให้บัดกรีต่ออนุกรมกับตัวต้านทาน <code>220Ω–330Ω</code> แยกสายออกเป็น 3 เส้น</div>
  </div>
  <div class="step-row">
    <div class="step-circle">2</div>
    <div class="step-text"><b>บัดกรีวงจรทรานซิสเตอร์ 2N2222 ขับหลอด IR:</b> หันด้านหน้าตัดแบนของ <code>2N2222</code> เข้าหาตัว ขาเรียงจากซ้ายไปขวาคือ <b>ขา 1 (ซ้าย = Emitter)</b> ต่อลง <code>GND</code> · <b>ขา 2 (กลาง = Base)</b> ต่อผ่านตัวต้านทาน <code>220Ω</code> ไปรอเข้า <code>GPIO 17</code> · <b>ขา 3 (ขวา = Collector)</b> ต่อกับขั้วลบของหลอด <b>IR LED (940nm)</b> ส่วนขั้วบวกของหลอด IR LED ต่อเข้าไฟเลี้ยง <code>+5V</code></div>
  </div>

  <!-- Clean SVG Schematic for IR Driver -->
  <div style="margin: 4px 0 8px 0; text-align: center;">
    <svg width="640" height="82" viewBox="0 0 640 82" style="background:#f8fafc; border:1px solid #cbd5e1; border-radius:8px;">
      <text x="16" y="20" font-family="Kanit" font-size="12" font-weight="600" fill="#15803d">ผังการต่อวงจรทรานซิสเตอร์ 2N2222 ขับหลอด IR LED บนแผ่นปริ้นท์ไข่ปลา</text>
      <rect x="16" y="30" width="90" height="36" rx="5" fill="#dcfce7" stroke="#16a34a"/>
      <text x="61" y="52" text-anchor="middle" font-family="JetBrains Mono" font-size="12" font-weight="700" fill="#14532d">GPIO 17</text>
      <line x1="106" y1="48" x2="140" y2="48" stroke="#374151" stroke-width="2"/>
      <rect x="140" y="34" width="75" height="28" rx="4" fill="#fef3c7" stroke="#d97706"/>
      <text x="177" y="52" text-anchor="middle" font-family="JetBrains Mono" font-size="11.5" font-weight="700" fill="#92400e">R 220Ω</text>
      <line x1="215" y1="48" x2="250" y2="48" stroke="#374151" stroke-width="2"/>
      <rect x="250" y="26" width="175" height="46" rx="6" fill="#1f2937"/>
      <text x="337" y="45" text-anchor="middle" font-family="Kanit" font-size="12" font-weight="600" fill="#ffffff">Transistor 2N2222</text>
      <text x="337" y="62" text-anchor="middle" font-family="Sarabun" font-size="11" fill="#6ee7b7">ขา 1(E)=GND · ขา 2(B)=รับสัญญาณ</text>
      <line x1="425" y1="48" x2="460" y2="48" stroke="#dc2626" stroke-width="2"/>
      <rect x="460" y="26" width="165" height="46" rx="5" fill="#fee2e2" stroke="#dc2626"/>
      <text x="542" y="45" text-anchor="middle" font-family="Kanit" font-size="12" font-weight="600" fill="#991b1b">ขา 3(C) ➔ ขั้วลบ IR LED</text>
      <text x="542" y="62" text-anchor="middle" font-family="Sarabun" font-size="11" fill="#7f1d1d">(ส่วนขั้วบวก IR LED ต่อไฟ +5V)</text>
    </svg>
  </div>

  <div class="sub-header">ขั้นที่ 2 · ยึดอุปกรณ์ลงกล่องและเดินสายไฟแรงดันต่ำ + สายไฟบ้าน 220V</div>
  <div class="step-row">
    <div class="step-circle">3</div>
    <div class="step-text"><b>ยึดโมดูลลงกล่อง 3D Print:</b> กดบอร์ด ESP32 ลงบนฐานขยายขาขันสกรูแล้วยึดไว้มุมซ้ายบน · ยึดแผ่นปริ้นท์ไข่ปลามุมขวาบน (ให้หัวไฟ LED โผล่พ้นรูด้านบน) · วาง HDR-15-5 ด้านขวาล่าง · วาง PZEM-004T ตรงกลางซ้าย · วางขั้ว Wago มุมซ้ายล่าง · ขันจอ OLED ติดด้านในฝาหน้า</div>
  </div>
  <div class="step-row">
    <div class="step-circle">4</div>
    <div class="step-text"><b>ขันสกรูสายไฟแรงดันต่ำเข้าฐาน ESP32:</b> ต่อไฟเลี้ยงจาก HDR-15-5 ช่อง <code>+V</code> เข้า <code>5V/VIN</code> และช่อง <code>-V</code> เข้า <code>GND</code> จากนั้นต่อสาย PZEM, จอ OLED และแผ่นปริ้นท์ไข่ปลาตามตารางขาพินด้านล่าง</div>
  </div>
  <div class="step-row">
    <div class="step-circle">5</div>
    <div class="step-text"><b>เข้าสายไฟบ้าน AC 220V และห่วงคล้อง CT:</b> สอดสายปลั๊ก AC 220V เข้าด้านล่างกล่อง แยกสายสีน้ำตาล (<code>L</code>) เข้า Wago ตัวที่ 1 และสายสีฟ้า (<code>N</code>) เข้า Wago ตัวที่ 2 แล้วพ่วงไฟ <code>L / N</code> ไปเข้าช่อง <code>L / N</code> ด้านล่างของ HDR-15-5 และขั้วที่ 1–2 ของ PZEM-004T ส่วนสายห่วงคล้อง CT ต่อเข้าขั้วที่ 3–4 ของ PZEM-004T</div>
  </div>

  <div class="sec-header">3.3 ตารางขาพินของบอร์ดแอร์ IR (อ้างอิงโค้ด <code>rmutt_esp32_air.ino</code> รุ่น 2.5.2)</div>
  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 18%;">ขาพิน ESP32</th>
        <th style="width: 24%;">ชื่อในโค้ด</th>
        <th style="width: 26%;">ต่อเข้ากับ</th>
        <th style="width: 32%;">หมายเหตุ</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><code>5V (VIN)</code>, <code>GND</code></td>
        <td>—</td>
        <td>HDR-15-5 ช่อง <code>+V</code> และ <code>-V</code></td>
        <td>ไฟเลี้ยงหลัก 5V DC และกราวด์ร่วมของทั้งวงจร</td>
      </tr>
      <tr>
        <td><code>GPIO 17</code></td>
        <td><code>IR_LED_PIN</code></td>
        <td>ขา Base ของ 2N2222 (ผ่าน R 220Ω)</td>
        <td>ส่งสัญญาณพัลส์ความถี่ 38 kHz ขับหลอดส่งแสง IR LED</td>
      </tr>
      <tr>
        <td><code>GPIO 16</code> / <code>18</code></td>
        <td><code>PZEM_RX / TX</code></td>
        <td><code>16 ➔ TX ของ PZEM</code> · <code>18 ➔ RX ของ PZEM</code></td>
        <td>ต่อไขว้ (ESP32 อ่านค่าไฟจาก PZEM ทุก 2 วินาที)</td>
      </tr>
      <tr>
        <td><code>GPIO 21</code> / <code>22</code></td>
        <td><code>kSda</code> / <code>kScl</code></td>
        <td>ขา <code>SDA</code> / <code>SCL</code> ของจอ OLED 1.3"</td>
        <td>จอใช้ไฟเลี้ยงจากขา <code>3V3</code> และ <code>GND</code></td>
      </tr>
      <tr>
        <td><code>GPIO 25 / 26 / 27</code></td>
        <td><code>GREEN / RED / YELLOW</code></td>
        <td>LED เขียว (25), แดง (26), เหลือง (27)</td>
        <td>ต่อผ่านตัวต้านทาน 220Ω–330Ω ลง GND ทุกหลอด</td>
      </tr>
      <tr>
        <td><code>GPIO 0</code></td>
        <td><code>SETUP_BUTTON_PIN</code></td>
        <td>ปุ่ม <code>BOOT</code> บนบอร์ด ESP32</td>
        <td>กดค้างตอนรีเซ็ตเพื่อบังคับเปิดโหมดตั้งค่าบลูทูธ</td>
      </tr>
    </tbody>
  </table>

  {make_footer(6)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 7: บทที่ 4 การประกอบบอร์ดสายแอร์ Daikin SLM8 (ภาพรวมและรูปจริง)   -->
<!-- ===================================================================== -->
<div class="page">
  <div class="ch-header"><span class="ch-num">4</span> การประกอบบอร์ดควบคุมแอร์แบบสายแอร์ (Daikin SLM8)</div>

  <div class="sec-header">4.1 บอร์ดสายแอร์ต่างจากบอร์ด IR อย่างไร</div>
  <p>
    แอร์บางห้องใช้ <b>รีโมตติดผนังแบบมีสาย (รุ่น Daikin SLM8)</b> บอร์ดรุ่นนี้จึงถูกออกแบบมาให้ติดตั้ง <b>แทนที่รีโมตติดผนังเดิม</b> โดยคุยกับแอร์ผ่านสายสัญญาณเดิมโดยตรง (ส่งเฟรมคำสั่งทุก 1 วินาที และรับเฟรมสถานะกลับมาจากแอร์ ทำให้รู้ว่าคอมเพรสเซอร์ทำงานจริงหรือไม่) พร้อมใช้เซ็นเซอร์ <b>DHT11</b> วัดอุณหภูมิห้องส่งให้แอร์แทนเทอร์มิสเตอร์ในรีโมตผนังเดิม
  </p>

  <div class="fig-box">
    <div class="fig-frame">
      <img src="{b64_wired}" style="width: 470px; height: 325px; object-fit: cover;">
      <div class="marker" style="top: 65px; left: 215px;">1</div>
      <div class="marker" style="top: 175px; left: 280px;">2</div>
      <div class="marker" style="top: 155px; left: 195px;">3</div>
      <div class="marker" style="top: 195px; left: 145px;">4</div>
      <div class="marker" style="top: 235px; left: 245px;">5</div>
      <div class="marker" style="top: 215px; left: 95px;">6</div>
      <div class="marker" style="top: 145px; left: 305px;">7</div>
    </div>
    <div class="fig-caption">รูปที่ 4-1 กล่องบอร์ดควบคุมแอร์แบบสายแอร์ (Daikin SLM8) และการเดินสายขึ้นไปยังแป้นรีโมตติดผนังเดิม</div>
  </div>

  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 7%;">#</th>
        <th style="width: 33%;">ส่วนประกอบในรูปที่ 4-1</th>
        <th style="width: 60%;">หน้าที่และการเชื่อมต่อ</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>1</b></td>
        <td><b>สายสัญญาณแอร์สีขาว (ไปแป้นผนัง)</b></td>
        <td>เดินสายจากขั้วต่อ JST ในกล่องขึ้นไปต่อกับสายแอร์เดิมบนผนัง 3 เส้น (สายสั่งงาน TX, สายสถานะ RX, และ GND)</td>
      </tr>
      <tr>
        <td><b>2</b></td>
        <td><b>แผงวงจรสายแอร์ SLM8 (ปริ้นท์ไข่ปลา)</b></td>
        <td>บัดกรีไดโอด <code>1N4148</code> (สำหรับส่งคำสั่ง) และตัวต้านทาน <code>100kΩ</code> จำนวน 6 ตัว (ทำวงจรแบ่งแรงดัน 100k/200kΩ 2 ชุด)</td>
      </tr>
      <tr>
        <td><b>3</b></td>
        <td><b>ESP32 + ฐานขยายขาขันสกรู</b></td>
        <td>รันเฟิร์มแวร์ <code>rmutt_esp32_air_wired.ino</code> (รุ่น 2.5.5-slm8) แยก FreeRTOS Task ส่งเฟรมสายแอร์ทุก 1 วินาที</td>
      </tr>
      <tr>
        <td><b>4</b></td>
        <td><b>มิเตอร์วัดไฟ PZEM-004T v3.0</b></td>
        <td>วัดกำลังไฟแอร์ 1 เฟสเหมือนรุ่น IR <b>(แต่รุ่นสายแอร์ย้ายไปต่อที่ขา GPIO 18 และ GPIO 14)</b></td>
      </tr>
      <tr>
        <td><b>5</b></td>
        <td><b>ภาคจ่ายไฟ MeanWell HDR-15-5</b></td>
        <td>จ่ายไฟเลี้ยง DC 5V ให้บอร์ด (จึงไม่ต้องดึงไฟ +5V จากสายแอร์มาใช้)</td>
      </tr>
      <tr>
        <td><b>6</b></td>
        <td><b>ขั้วต่อแยกสายไฟ Wago (สีส้ม)</b></td>
        <td>แยกไฟบ้าน AC 220V จ่ายให้ HDR-15-5 และขั้ววัดแรงดันของ PZEM-004T</td>
      </tr>
      <tr>
        <td><b>7</b></td>
        <td><b>ไฟสถานะ LED + เซ็นเซอร์ DHT11</b></td>
        <td>แสดงสถานะหน้ากล่อง และใช้ DHT11 (ขา GPIO 4) วัดอุณหภูมิห้องส่งให้แอร์ใช้ตัดคอมเพรสเซอร์</td>
      </tr>
    </tbody>
  </table>

  {make_footer(7)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 8: บทที่ 4 (ต่อ) วงจร SLM8, ขั้นตอนการประกอบ และตารางขาพิน        -->
<!-- ===================================================================== -->
<div class="page">
  <div class="sec-header" style="margin-top: 0;">4.2 ขั้นตอนการบัดกรีวงจรสายแอร์และการต่อสายเข้ากับแอร์ Daikin</div>

  <div class="sub-header">ขั้นที่ 1 · บัดกรีวงจรไดโอด 1N4148 และตัวแบ่งแรงดัน 100kΩ / 200kΩ บนแผ่นปริ้นท์ไข่ปลา</div>
  <p>สายสัญญาณของแอร์ Daikin มีแรงดันค้างอยู่ราว 4.8–5.0V และมีตัวดึงขึ้น (Pull-up) อ่อนมาก จึงห้ามต่อตรงเข้าขา 3.3V ของ ESP32 ให้บัดกรีวงจรคั่นกลางบนแผ่นปริ้นท์ไข่ปลาตามผังด้านล่าง</p>

  <!-- Clean SVG Schematic for Daikin SLM8 Bus Interface -->
  <div style="margin: 4px 0 8px 0; text-align: center;">
    <svg width="640" height="118" viewBox="0 0 640 118" style="background:#f8fafc; border:1px solid #cbd5e1; border-radius:8px;">
      <text x="15" y="20" font-family="Kanit" font-size="12" font-weight="600" fill="#15803d">ผังวงจรเชื่อมต่อสายแอร์ Daikin SLM8 บนแผ่นปริ้นท์ไข่ปลา (ใช้ไดโอด 1N4148 + ตัวต้านทาน 100kΩ 6 ตัว)</text>
      <!-- TX Line -->
      <rect x="15" y="30" width="95" height="26" rx="4" fill="#dcfce7" stroke="#16a34a"/>
      <text x="62" y="47" text-anchor="middle" font-family="JetBrains Mono" font-size="11" font-weight="700" fill="#14532d">GPIO 33 (TX)</text>
      <line x1="110" y1="43" x2="145" y2="43" stroke="#1f2937" stroke-width="2"/>
      <rect x="145" y="30" width="245" height="26" rx="4" fill="#fef3c7" stroke="#d97706"/>
      <text x="267" y="47" text-anchor="middle" font-family="Kanit" font-size="11.5" font-weight="600" fill="#92400e">◄─▎ ไดโอด 1N4148 (หันแถบดำเข้า GPIO 33)</text>
      <line x1="390" y1="43" x2="430" y2="43" stroke="#1f2937" stroke-width="2"/>
      <rect x="430" y="30" width="195" height="26" rx="4" fill="#dbeafe" stroke="#2563eb"/>
      <text x="527" y="47" text-anchor="middle" font-family="Kanit" font-size="11.5" font-weight="600" fill="#1e3a8a">สายสั่งงานแอร์ (ขาว · TX)</text>

      <!-- RX Line -->
      <rect x="15" y="66" width="95" height="26" rx="4" fill="#dcfce7" stroke="#16a34a"/>
      <text x="62" y="83" text-anchor="middle" font-family="JetBrains Mono" font-size="11" font-weight="700" fill="#14532d">GPIO 35 (RX)</text>
      <line x1="110" y1="79" x2="145" y2="79" stroke="#1f2937" stroke-width="2"/>
      <rect x="145" y="66" width="125" height="26" rx="4" fill="#f1f5f9" stroke="#64748b"/>
      <text x="207" y="83" text-anchor="middle" font-family="Sarabun" font-size="11" font-weight="700" fill="#1f2937">แยกต่อ 200kΩ ลง GND</text>
      <line x1="270" y1="79" x2="295" y2="79" stroke="#1f2937" stroke-width="2"/>
      <rect x="295" y="66" width="95" height="26" rx="4" fill="#ede9fe" stroke="#7c3aed"/>
      <text x="342" y="83" text-anchor="middle" font-family="JetBrains Mono" font-size="11" font-weight="700" fill="#5b21b6">ผ่าน R 100kΩ</text>
      <line x1="390" y1="79" x2="430" y2="79" stroke="#1f2937" stroke-width="2"/>
      <rect x="430" y="66" width="195" height="26" rx="4" fill="#dbeafe" stroke="#2563eb"/>
      <text x="527" y="83" text-anchor="middle" font-family="Kanit" font-size="11.5" font-weight="600" fill="#1e3a8a">สายสถานะแอร์ (เหลือง · TX/RCV)</text>

      <!-- Note inside SVG -->
      <text x="15" y="109" font-family="Sarabun" font-size="11" fill="#374151">* <tspan font-weight="700">ขาตรวจสัญญาณตัวเอง (GPIO 34):</tspan> ต่อวงจรแบ่งแรงดัน 100kΩ / 200kΩ ลง GND เหมือน GPIO 35 อีก 1 ชุดจากสายสั่งงานแอร์ (200kΩ ทำจาก 100kΩ 2 ตัวอนุกรมกัน)</text>
    </svg>
  </div>

  <div class="step-row">
    <div class="step-circle">1</div>
    <div class="step-text"><b>ต่อเซ็นเซอร์วัดอุณหภูมิห้อง DHT11 (โมดูล KY-015):</b> ขันสกรูต่อขา <code>DATA</code> เข้าที่ <b><code>GPIO 4</code></b>, ขา <code>+ (VCC)</code> เข้า <code>3V3</code> และขา <code>- (GND)</code> เข้า <code>GND</code> ของฐาน ESP32</div>
  </div>
  <div class="step-row">
    <div class="step-circle">2</div>
    <div class="step-text"><b>ต่อสายมิเตอร์ PZEM-004T และไฟ LED (ระวังขาต่างจากรุ่น IR!):</b> ในบอร์ดสายแอร์ ให้ต่อขา <code>TX</code> ของ PZEM เข้าที่ <b><code>GPIO 18</code></b>, ขา <code>RX</code> ของ PZEM เข้าที่ <b><code>GPIO 14</code></b> และสายไฟ LED สีเหลืองเข้าที่ <b><code>GPIO 23</code></b> (ส่วนไฟเขียว=25, แดง=26 และจอ OLED=21/22 เหมือนเดิม)</div>
  </div>
  <div class="step-row">
    <div class="step-circle">3</div>
    <div class="step-text"><b>การต่อเข้ากับสายแอร์บนผนังห้องเรียน:</b> ถอดรีโมตติดผนัง Daikin SLM8 เดิมออก แล้วต่อสายจากกล่องของเราเข้ากับสายแอร์เพียง <b>3 เส้น</b> คือ <b>1) สายสั่งงาน (ขาว TX)</b>, <b>2) สายสถานะ (เหลือง TX/RCV)</b> และ <b>3) สายกราวด์ (ดำ GND — ต้องต่อร่วมกับ GND ของ ESP32)</b> ส่วนสายไฟ <code>+5V (สีแดง)</code> ของแอร์ <b>ห้ามต่อเด็ดขาด</b> ให้พันเทปเก็บไว้</div>
  </div>

  <div class="sec-header">4.3 ตารางขาพินของบอร์ดสายแอร์ (อ้างอิงโค้ด <code>rmutt_esp32_air_wired.ino</code> รุ่น 2.5.5-slm8)</div>
  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 18%;">ขาพิน ESP32</th>
        <th style="width: 22%;">ชื่อในโค้ด</th>
        <th style="width: 28%;">ต่อเข้ากับ</th>
        <th style="width: 32%;">ความแตกต่างจากรุ่น IR</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><code>GPIO 33</code></td>
        <td><code>BUS_TX_PIN</code></td>
        <td>ไดโอด 1N4148 (หันแถบดำเข้า GPIO 33) ➔ สายสั่งงานแอร์</td>
        <td>ดึงสายลง LOW ส่งเฟรมคำสั่ง 8 ไบต์ทุก 1 วินาที</td>
      </tr>
      <tr>
        <td><code>GPIO 35</code></td>
        <td><code>BUS_RX_PIN</code></td>
        <td>สายสถานะแอร์ ผ่านตัวแบ่งแรงดัน 100kΩ / 200kΩ ลง GND</td>
        <td>รับเฟรมสถานะจากแอร์ (รู้ว่าสายตอบและคอมเพรสเซอร์ติดหรือไม่)</td>
      </tr>
      <tr>
        <td><code>GPIO 34</code></td>
        <td><code>BUS_ECHO_PIN</code></td>
        <td>สายสั่งงานแอร์ ผ่านตัวแบ่งแรงดัน 100kΩ / 200kΩ ลง GND</td>
        <td>อ่านสัญญาณที่ตัวเองส่งออกไปเพื่อตรวจสอบความถูกต้อง</td>
      </tr>
      <tr>
        <td><code>GPIO 4</code></td>
        <td><code>DHT_PIN</code></td>
        <td>ขา DATA ของโมดูล DHT11 (ไฟเลี้ยง 3V3 / GND)</td>
        <td>วัดอุณหภูมิห้องส่งให้แอร์แทนเทอร์มิสเตอร์ในรีโมตผนัง</td>
      </tr>
      <tr>
        <td><code>GPIO 18</code> / <code>14</code></td>
        <td><code>PZEM_RX / TX</code></td>
        <td><code>18 ➔ TX ของ PZEM</code> · <code>14 ➔ RX ของ PZEM</code></td>
        <td><b>ย้ายขามาที่ 18 และ 14</b> (รุ่น IR ใช้ 16 และ 18)</td>
      </tr>
      <tr>
        <td><code>GPIO 25 / 26 / 23</code></td>
        <td><code>GREEN / RED / YELLOW</code></td>
        <td>LED เขียว (25), แดง (26), <b>เหลือง (23)</b></td>
        <td><b>ไฟเหลืองย้ายมาที่ GPIO 23</b> (รุ่น IR ใช้ 27)</td>
      </tr>
      <tr>
        <td><code>GPIO 21 / 22</code></td>
        <td><code>kSda / kScl</code></td>
        <td>จอ OLED 1.3" SH1106 (SDA=21, SCL=22)</td>
        <td>แสดงป้าย <code>BUS</code> และ <code>COMP ON</code> (หมุนจอ 180° ให้เอง)</td>
      </tr>
    </tbody>
  </table>

  {make_footer(8)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 9: บทที่ 5 การประกอบกล่องเซ็นเซอร์ตรวจจับคน (HLK-LD2410)          -->
<!-- ===================================================================== -->
<div class="page">
  <div class="ch-header"><span class="ch-num">5</span> การประกอบกล่องเซ็นเซอร์ตรวจจับคน (HLK-LD2410)</div>

  <div class="sec-header">5.1 ส่วนประกอบภายในกล่องเซ็นเซอร์ตรวจจับคน</div>
  <p>
    กล่องเซ็นเซอร์ตรวจจับคนติดตั้งห้องละ 1 กล่อง ใช้เรดาร์คลื่นมิลลิเมตร <b>HLK-LD2410 (24 GHz)</b> อ่านค่าพลังงานนิ่ง (Static Energy) รายระยะ (Gate 0–8) จึงตรวจจับคนนั่งเรียนนิ่งๆ ได้แม่นยำ และใช้ไฟเลี้ยง 5V จากสาย USB Type-C โดยไม่มีไฟบ้าน 220V ในกล่อง
  </p>

  <div class="fig-box">
    <div class="fig-frame">
      <img src="{b64_occ}" style="width: 340px; height: 265px; object-fit: cover;">
      <div class="marker" style="top: 34px; left: 232px;">1</div>
      <div class="marker" style="top: 145px; left: 232px;">2</div>
      <div class="marker" style="top: 162px; left: 178px;">3</div>
      <div class="marker" style="top: 178px; left: 72px;">4</div>
      <div class="marker" style="top: 32px; left: 76px;">5</div>
      <div class="marker" style="top: 238px; left: 232px;">6</div>
    </div>
    <div class="fig-caption">รูปที่ 5-1 การจัดวางอุปกรณ์และการเดินสายภายในกล่องเซ็นเซอร์ตรวจจับคน (HLK-LD2410)</div>
  </div>

  <div class="sec-header">5.2 ขั้นตอนการประกอบและเดินสายทีละขั้น</div>
  <div class="step-row">
    <div class="step-circle">1</div>
    <div class="step-text"><b>บัดกรีแผงไฟสถานะ LED 2 สี ที่ฝาหน้า (หมายเลข 4):</b> ตัดแผ่นปริ้นท์ไข่ปลาขนาด 2×3 ซม. เสียบหลอด <b>LED สีเขียว</b> และ <b>LED สีแดง</b> ให้หัวหลอดโผล่ออกช่องฝาหน้า บัดกรีขาลบ (ขาสั้น) รวมกันเป็นสายสีน้ำตาลต่อเข้า <code>GND</code> ส่วนขาบวก (ขายาว) ต่อผ่านตัวต้านทาน <code>220Ω–330Ω</code> แยกเป็นสายสีเขียว (เข้า <code>GPIO 25</code>) และสายสีแดง (เข้า <code>GPIO 26</code>)</div>
  </div>
  <div class="step-row">
    <div class="step-circle">2</div>
    <div class="step-text"><b>ต่อสายโมดูลเรดาร์ HLK-LD2410 (หมายเลข 1):</b> ที่ขอบบนของบอร์ดเรดาร์สีน้ำเงินมี 5 รูพิน เรียงจากซ้ายไปขวาคือ <code>TX, RX, OUT, GND, VCC</code> ให้ต่อสายเพียง 4 เส้น (เว้นขา <code>OUT</code> ไว้ไม่ต้องต่อ) แล้ววางลงในช่องล็อกด้านบนสุดของกล่องโดยหันด้านสายอากาศสีทองออกด้านหน้า (ตรงกับหน้าต่างฝาหน้าหมายเลข 5)</div>
  </div>
  <div class="step-row">
    <div class="step-circle">3</div>
    <div class="step-text"><b>ยึดบอร์ด ESP32 และขันสกรูสายไฟ (หมายเลข 2, 3, 6):</b> เสียบบอร์ด ESP32 ลงบนฐานขยายขาขันสกรู ยึดลงกล่องโดยหันพอร์ต USB Type-C ออกช่องด้านล่างสุด แล้วขันสกรูสายไฟตามตารางด้านล่าง</div>
  </div>

  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 18%;">ขาพิน ESP32</th>
        <th style="width: 24%;">ชื่อในโค้ด</th>
        <th style="width: 28%;">ต่อเข้ากับ</th>
        <th style="width: 30%;">สีสายในรูปที่ 5-1 และหน้าที่</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><code>5V (VIN)</code></td>
        <td>—</td>
        <td>ขา <b>VCC</b> ของเรดาร์ HLK-LD2410</td>
        <td>สายสีแดง (จ่ายไฟ 5V จากพอร์ต USB ให้เรดาร์)</td>
      </tr>
      <tr>
        <td><code>GND</code></td>
        <td>—</td>
        <td>ขา <b>GND</b> เรดาร์ + ขาลบร่วมไฟ LED</td>
        <td>สายสีดำ (จากเรดาร์) และสายสีน้ำตาล (จากไฟ LED)</td>
      </tr>
      <tr>
        <td><code>GPIO 32</code></td>
        <td><code>RADAR_RX_PIN</code></td>
        <td>ขา <b>TX</b> ของเรดาร์ HLK-LD2410</td>
        <td>ต่อไขว้ · รับข้อมูลเรดาร์ที่ความเร็ว 256,000 baud</td>
      </tr>
      <tr>
        <td><code>GPIO 33</code></td>
        <td><code>RADAR_TX_PIN</code></td>
        <td>ขา <b>RX</b> ของเรดาร์ HLK-LD2410</td>
        <td>ต่อไขว้ · ส่งคำสั่งเปิดโหมด Engineering รายเกต</td>
      </tr>
      <tr>
        <td><code>GPIO 25</code> / <code>26</code></td>
        <td><code>GREEN / RED_LED</code></td>
        <td>LED เขียว (25) และ LED แดง (26)</td>
        <td>เขียว = สถานะเชื่อมต่อเน็ต · แดง = มีคนอยู่ในห้อง</td>
      </tr>
    </tbody>
  </table>

  {make_footer(9)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 10: บทที่ 6 การติดตั้งโปรแกรมและอัปโหลดเฟิร์มแวร์ลง ESP32         -->
<!-- ===================================================================== -->
<div class="page">
  <div class="ch-header"><span class="ch-num">6</span> การติดตั้งโปรแกรมและอัปโหลดเฟิร์มแวร์ลง ESP32</div>

  <div class="sec-header">6.1 การตรวจเช็ควงจรด้วยมัลติมิเตอร์ก่อนเสียบสายไฟ</div>
  <p>ก่อนเสียบสาย USB เข้าคอมพิวเตอร์หรือเสียบปลั๊กไฟ 220V ให้ปรับมัลติมิเตอร์ไปที่โหมดวัดความต่อเนื่อง (เสียงร้องเตือน) แล้วตรวจเช็ค 2 จุดเสมอ:</p>
  <ul class="clean-list">
    <li><b>เช็คฝั่งไฟเลี้ยง DC:</b> วัดระหว่างขั้ว <code>5V</code> กับ <code>GND</code> และระหว่าง <code>3V3</code> กับ <code>GND</code> บนฐาน ESP32 ต้องไม่มีเสียงร้องเตือนลัดวงจร</li>
    <li><b>เช็คฝั่งไฟบ้าน AC 220V (เฉพาะกล่องแอร์ 1 และ 2):</b> วัดระหว่างขาปลั๊กไฟ <code>L</code> กับ <code>N</code> ต้องไม่ช็อตถึงกัน และต้องไม่รั่วข้ามมายังขั้ว <code>GND</code> ของบอร์ด ESP32</li>
  </ul>

  <div class="sec-header">6.2 การเตรียม Arduino IDE และติดตั้งไลบรารี</div>
  <p>เปิดโปรแกรม <b>Arduino IDE (รุ่น 2.x)</b> ติดตั้งบอร์ดแพ็กเกจ <b>esp32 by Espressif Systems (รุ่น 3.x)</b> ในเมนู Boards Manager จากนั้นไปที่เมนู <b>Library Manager</b> เพื่อติดตั้งไลบรารีให้ครบตามชนิดกล่องดังตารางด้านล่าง</p>

  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 23%;">ชนิดกล่องที่จะอัปโหลด</th>
        <th style="width: 34%;">ไฟล์สเก็ตช์ (<code>.ino</code>) ที่ต้องเปิด</th>
        <th style="width: 43%;">ไลบรารีที่ต้องติดตั้งใน Arduino IDE</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>1. บอร์ดแอร์แบบ IR</b></td>
        <td><code>firmware/rmutt_esp32_air/<br>rmutt_esp32_air.ino</code> (รุ่น <b>2.5.2</b>)</td>
        <td>
          • <code>ArduinoJson</code> (ต้องใช้รุ่น <b>6.x</b> เท่านั้น เช่น 6.21.5)<br>
          • <code>PubSubClient</code> · <code>PZEM004Tv30</code> · <code>U8g2</code><br>
          • <code>IRremoteESP8266</code> (รุ่น <b>2.9.0</b>)
        </td>
      </tr>
      <tr>
        <td><b>2. บอร์ดสายแอร์ Daikin</b></td>
        <td><code>firmware/rmutt_esp32_air_wired/<br>rmutt_esp32_air_wired.ino</code> (รุ่น <b>2.5.5-slm8</b>)</td>
        <td>
          • <code>ArduinoJson (6.x)</code> · <code>PubSubClient</code> · <code>PZEM004Tv30</code> · <code>U8g2</code><br>
          • <code>DHT sensor library</code> (by Adafruit) + <code>Adafruit Unified Sensor</code>
        </td>
      </tr>
      <tr>
        <td><b>3. เซ็นเซอร์ตรวจจับคน</b></td>
        <td><code>firmware/rmutt_esp32_occupancy/<br>rmutt_esp32_occupancy.ino</code> (รุ่น <b>1.3.9</b>)</td>
        <td>
          • <code>ArduinoJson (6.x)</code> · <code>PubSubClient</code><br>
          • <code>ld2410</code> (by Nick Reynolds — ต้องเป็นรุ่น <b>0.2.2 ขึ้นไป</b>)
        </td>
      </tr>
    </tbody>
  </table>

  <div class="callout warn">
    <div class="callout-title">ห้ามลบไฟล์ประกอบในโฟลเดอร์สเก็ตช์</div>
    ในโฟลเดอร์ของแต่ละสเก็ตช์มีไฟล์สำคัญวางอยู่คู่กับไฟล์ <code>.ino</code> ได้แก่ <code>build_opt.h</code> (ช่วยลดขนาดโค้ดให้พอดีแฟลช), <code>partitions.csv</code>, <code>letsencrypt_ca.h</code>, <code>oled_display.h</code>, <code>SaijoDenkiAC.h/.cpp</code> และ <code>DaikinSLM8.h</code> ต้องเก็บไว้ในโฟลเดอร์เดิมครบทุกไฟล์
  </div>

  <div class="sec-header">6.3 ขั้นตอนการตั้งค่าและกด Upload โค้ดลงบอร์ด ESP32</div>
  <div class="step-row">
    <div class="step-circle">1</div>
    <div class="step-text">เปิดไฟล์สเก็ตช์ <code>.ino</code> ของกล่องที่ต้องการใน Arduino IDE</div>
  </div>
  <div class="step-row">
    <div class="step-circle">2</div>
    <div class="step-text">ไปที่เมนู <b>Tools → Board → esp32</b> เลือกเป็น <b><code>ESP32 Dev Module</code></b></div>
  </div>
  <div class="step-row">
    <div class="step-circle">3</div>
    <div class="step-text">ไปที่เมนู <b>Tools → Partition Scheme</b> เลือกเป็น <b><code>No FS 4MB (2MB APP x2)</code></b> (เพื่อให้โปรแกรมจัดแบ่งพื้นที่แฟลชตามไฟล์ <code>partitions.csv</code> สำหรับรองรับการอัปเดต OTA และเก็บข้อมูลย้อนหลังตอนเน็ตหลุด)</div>
  </div>
  <div class="step-row">
    <div class="step-circle">4</div>
    <div class="step-text"><b>ถอดปลั๊กไฟบ้าน 220V ออกก่อนเสมอ</b> แล้วเสียบสาย USB Type-C จากคอมพิวเตอร์เข้าที่บอร์ด ESP32 เลือกพอร์ตในเมนู <b>Tools → Port</b> (เช่น <code>COM3</code>) แล้วกดปุ่ม <b>Upload (ลูกศรชี้ขวา)</b> รอจนขึ้นข้อความ <code>Done uploading.</code></div>
  </div>
  <div class="step-row">
    <div class="step-circle">5</div>
    <div class="step-text">กดเปิด <b>Serial Monitor</b> มุมขวาบน ตั้งค่าความเร็วเป็น <b><code>115200 baud</code></b> จะเห็นข้อความบูตระบบและชื่อบลูทูธของบอร์ด เช่น <code>RMUTT-AC-XXXXXXXXXXXX</code> หรือ <code>RMUTT-OCC-XXXXXXXXXXXX</code> แปลว่าบอร์ดพร้อมนำไปตั้งค่าใช้งานแล้ว</div>
  </div>

  {make_footer(10)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 11: บทที่ 7 การตั้งค่าบอร์ดผ่านบลูทูธและการติดตั้งหน้างาน         -->
<!-- ===================================================================== -->
<div class="page">
  <div class="ch-header"><span class="ch-num">7</span> การตั้งค่าบอร์ดผ่านบลูทูธและการติดตั้งหน้างาน</div>

  <div class="sec-header">7.1 ขั้นตอนการจับคู่บอร์ดเข้ากับห้องเรียนผ่านบลูทูธ (BLE Provisioning)</div>
  <p>เมื่ออัปโหลดโค้ดเสร็จและนำกล่องไปติดตั้งจ่ายไฟที่ห้องเรียนแล้ว ให้ใช้แอปมือถือ <b>RMUTT Save Energy</b> (เข้าสู่ระบบด้วยบัญชีผู้ดูแลระบบ) เพื่อส่งค่า Wi-Fi และผูกบอร์ดเข้ากับห้องเรียนตามขั้นตอนดังนี้</p>

  <div class="step-row">
    <div class="step-circle">1</div>
    <div class="step-text">ในแอปมือถือ ไปที่แท็บ <b>ควบคุม</b> เลือกห้องเรียนที่ติดตั้งกล่อง แล้วกดปุ่ม <b>เพิ่มอุปกรณ์ ESP32</b> (สำหรับบอร์ดแอร์ทั้งรุ่น IR และสายแอร์) หรือกด <b>เพิ่มเซ็นเซอร์</b> (สำหรับกล่องตรวจจับคน) <i>— หรือจองช่องสร้างโทเคน 15 นาทีจากหน้าเว็บแอปก่อนก็ได้</i></div>
  </div>
  <div class="step-row">
    <div class="step-circle">2</div>
    <div class="step-text">เปิดบลูทูธบนมือถือแล้วกด <b>ค้นหาบลูทูธ</b> เลือกชื่อบอร์ดที่ตรวจพบ (บอร์ดแอร์ขึ้นต้นด้วย <code>RMUTT-AC-...</code> ส่วนเซ็นเซอร์ตรวจจับคนขึ้นต้นด้วย <code>RMUTT-OCC-...</code>)</div>
  </div>
  <div class="step-row">
    <div class="step-circle">3</div>
    <div class="step-text">เลือกชื่อเครือข่าย <b>Wi-Fi (2.4 GHz)</b> ที่บอร์ดสแกนพบ แล้วกรอกรหัสผ่าน Wi-Fi</div>
  </div>
  <div class="step-row">
    <div class="step-circle">4</div>
    <div class="step-text">เลือกหมายเลขแอร์ในห้อง ตั้งชื่อ และเลือก <b>ยี่ห้อ/โปรโตคอลของแอร์</b> (สำหรับบอร์ดแอร์ IR ให้เลือกให้ตรงกับรีโมตจริง เช่น Daikin, Mitsubishi, Haier, Saijo Denki ส่วน <b>บอร์ดสายแอร์จะถูกล็อกเป็น "Daikin · สายแอร์" ให้อัตโนมัติ</b>)</div>
  </div>
  <div class="step-row">
    <div class="step-circle">5</div>
    <div class="step-text">กดปุ่ม <b>ตั้งค่าและเชื่อมต่อ</b> แอปจะส่งค่า Wi-Fi, ที่อยู่เซิร์ฟเวอร์ MQTT และโทเคนยืนยันตัวตนไปเก็บในหน่วยความจำถาวร (NVS) ของบอร์ด จากนั้นบอร์ดจะรีสตาร์ท ต่อ Wi-Fi ซิงก์เวลา NTP และขึ้นสถานะ <b>ออนไลน์</b> ในระบบทันที</div>
  </div>

  <div class="callout warn">
    <div class="callout-title">การกดปุ่มบังคับเข้าโหมดตั้งค่าบลูทูธใหม่ (Reconfigure)</div>
    หากต้องการเปลี่ยนรหัส Wi-Fi หรือย้ายกล่องไปห้องอื่นขณะที่บอร์ดไม่ได้เปิดบลูทูธอยู่ ให้เปิดฝากล่องแล้ว <b>กดปุ่ม <code>BOOT</code> บนบอร์ด ESP32 ค้างไว้ แล้วกดปุ่ม <code>RESET</code> (หรือถอดเสียบไฟใหม่ขณะกด BOOT ค้างไว้ประมาณ 2 วินาที)</b> บอร์ดจะเปิดสัญญาณบลูทูธให้ตั้งค่าใหม่ทันที
  </div>

  <div class="sec-header">7.2 ข้อกำหนดการติดตั้งหน้างานจริง</div>
  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 28%;">จุดติดตั้งหน้างาน</th>
        <th style="width: 72%;">วิธีติดตั้งที่ถูกต้อง</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>การคล้องห่วงวัดกระแส (CT Sensor)</b></td>
        <td>ง้างตัวล็อกห่วง CT สีดำออก แล้วนำไปคล้องรอบ <b>สายไฟเส้นที่มีไฟ (Line: L) ของแอร์เพียงเส้นเดียว</b> แล้วกดล็อกให้สนิท <i>(ห้ามคล้องรวบทั้งสาย L และ N คู่กันเด็ดขาด เพราะกระแสไป-กลับจะหักล้างกันจนอ่านค่าวัตต์ได้ 0 W)</i></td>
      </tr>
      <tr>
        <td><b>การวางหลอดยิงแสง IR LED</b><br><i>(เฉพาะบอร์ดแอร์ IR)</i></td>
        <td>นำปลายสายหลอด IR LED ไปติดในตำแหน่งที่หันชี้เข้าหาช่องรับสัญญาณรีโมตของตัวแอร์โดยไม่มีสิ่งกีดขวาง</td>
      </tr>
      <tr>
        <td><b>การติดกล่องเซ็นเซอร์ตรวจจับคน</b><br><i>(เรดาร์ HLK-LD2410)</i></td>
        <td>ติดตั้งบนผนังห้องเรียนในมุมที่หันหน้ากล่องส่องไปยังบริเวณที่นั่งเรียนทั้งหมด หลีกเลี่ยงการหันหน้าเรดาร์เข้าหาพัดลมเพดานหรือม่านที่ปลิวลมแรง</td>
      </tr>
    </tbody>
  </table>

  {make_footer(11)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 12: ภาคผนวก ก ความหมายไฟแสดงสถานะ LED และหน้าจอ OLED             -->
<!-- ===================================================================== -->
<div class="page">
  <div class="ch-header"><span class="ch-num">ก</span> ภาคผนวก · ไฟแสดงสถานะและหน้าจอ OLED</div>

  <div class="sec-header">ก.1 ไฟแสดงสถานะ LED 3 สี บนบอร์ดแอร์ (ทั้งรุ่น IR และรุ่นสายแอร์)</div>
  <p>ด้านบนของกล่องบอร์ดแอร์มีหลอดไฟ LED 3 ดวง ช่วยให้ผู้ดูแลและช่างตรวจสอบการทำงานหน้าห้องได้ทันทีโดยไม่ต้องเปิดแอป</p>

  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 24%;">สีไฟ LED</th>
        <th style="width: 18%;">ขาพิน ESP32</th>
        <th style="width: 58%;">ความหมายของการแสดงผล</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><span class="led-dot" style="background:#16a34a;"></span><b>สีเขียว (สถานะแอร์)</b></td>
        <td><code>GPIO 25</code></td>
        <td><b>ติดค้าง</b> = มิเตอร์ PZEM ตรวจพบว่าแอร์กำลังกินไฟทำงานอยู่ (กำลังไฟเกินเกณฑ์ 50 W ติดต่อกัน) · <b>ดับ</b> = แอร์ปิดอยู่</td>
      </tr>
      <tr>
        <td><span class="led-dot" style="background:#dc2626;"></span><b>สีแดง (นอกตารางเรียน)</b></td>
        <td><code>GPIO 26</code></td>
        <td><b>ติดค้าง</b> = แอร์กำลังเปิดทำงานอยู่ในช่วงเวลาที่ไม่มีคาบเรียนหรือการจองห้อง · <b>ดับ</b> = ปกติ (อยู่ในคาบเรียน หรือแอร์ปิดอยู่)</td>
      </tr>
      <tr>
        <td><span class="led-dot" style="background:#eab308;"></span><b>สีเหลือง (สถานะเครือข่าย)</b></td>
        <td><code>GPIO 27</code> (รุ่น IR)<br><code>GPIO 23</code> (รุ่นสายแอร์)</td>
        <td><b>กะพริบทุก 400 ms</b> = กำลังเชื่อมต่อ Wi-Fi หรืออยู่ในโหมดตั้งค่าบลูทูธ · <b>ติดค้าง</b> = เชื่อมต่อ Wi-Fi สำเร็จแล้ว</td>
      </tr>
    </tbody>
  </table>

  <div class="sec-header">ก.2 ไฟแสดงสถานะ LED 2 สี บนกล่องเซ็นเซอร์ตรวจจับคน (HLK-LD2410)</div>
  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 24%;">สีไฟ LED</th>
        <th style="width: 18%;">ขาพิน ESP32</th>
        <th style="width: 58%;">ความหมายของการแสดงผล</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><span class="led-dot" style="background:#16a34a;"></span><b>สีเขียว (สถานะระบบ)</b></td>
        <td><code>GPIO 25</code></td>
        <td><b>ติดค้าง</b> = เชื่อมต่อ Wi-Fi และ MQTT ปกติ · <b>กะพริบ</b> = กำลังเชื่อมต่อ Wi-Fi/NTP หรือกำลังลองต่อใหม่ · <b>ดับ</b> = ยังไม่ได้ตั้งค่า หรืออยู่ในโหมดบลูทูธ</td>
      </tr>
      <tr>
        <td><span class="led-dot" style="background:#dc2626;"></span><b>สีแดง (ตรวจจับคน)</b></td>
        <td><code>GPIO 26</code></td>
        <td><b>ติดค้าง</b> = ตรวจพบคนอยู่ในห้องเรียน (Occupied) · <b>ดับ</b> = ไม่มีคนในห้อง หรือเรดาร์ไม่ส่งข้อมูล</td>
      </tr>
    </tbody>
  </table>

  <div class="sec-header">ก.3 ข้อมูลที่แสดงบนหน้าจอ OLED 1.3 นิ้ว (ฝาหน้ากล่องบอร์ดแอร์)</div>
  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 28%;">ข้อความ / สัญลักษณ์บนจอ</th>
        <th style="width: 72%;">ความหมาย</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>ตัวเลขอุณหภูมิขนาดใหญ่ (เช่น <code>25°C</code>)</b></td>
        <td>อุณหภูมิเป้าหมายที่สั่งตั้งค่าแอร์ไว้ล่าสุด (หรือแสดงคำว่า <code>OFF</code> เมื่อสั่งปิดแอร์)</td>
      </tr>
      <tr>
        <td><b>ค่ากำลังไฟและกระแส (<code>W / V / A</code>)</b></td>
        <td>ค่ากำลังไฟฟ้า (วัตต์), แรงดัน (โวลต์) และกระแส (แอมแปร์) ที่อ่านได้สดจากมิเตอร์ PZEM-004T</td>
      </tr>
      <tr>
        <td><b>ป้าย <code>BUS</code> และ <code>COMP ON</code></b><br><i>(เฉพาะบอร์ดสายแอร์ Daikin)</i></td>
        <td><code>BUS</code> ทึบ = สายแอร์สื่อสารสองทางปกติ (ถ้าสายหลุดเกิน 15 วินาที จอจะสลับขึ้นหน้าเตือน) · <code>COMP ON</code> = แอร์รายงานว่าคอมเพรสเซอร์กำลังทำงานทำความเย็น</td>
      </tr>
      <tr>
        <td><b>โหมดพักหน้าจออัตโนมัติ (Screen Saver)</b></td>
        <td>เมื่อแอร์ปิดติดต่อกันเกิน 10 นาที หน้าจอจะดับพักเองอัตโนมัติเพื่อป้องกันพิกเซลจอ OLED เสื่อม (Burn-in) และจะติดขึ้นมาใหม่ทันทีที่มีการสั่งงาน</td>
      </tr>
    </tbody>
  </table>

  {make_footer(12)}
</div>


<!-- ===================================================================== -->
<!-- PAGE 13: ภาคผนวก ข การแก้ปัญหาฮาร์ดแวร์และการอัปโหลดโค้ดเบื้องต้น     -->
<!-- ===================================================================== -->
<div class="page">
  <div class="ch-header"><span class="ch-num">ข</span> ภาคผนวก · การแก้ปัญหาฮาร์ดแวร์เบื้องต้น</div>

  <table class="clean-table">
    <thead>
      <tr>
        <th style="width: 26%;">อาการที่พบ</th>
        <th style="width: 30%;">สาเหตุที่พบบ่อย</th>
        <th style="width: 44%;">วิธีตรวจสอบและแก้ไข</th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td><b>คอมไพล์โค้ดไม่ผ่าน แจ้งว่า Sketch too big (พื้นที่แฟลชไม่พอ)</b></td>
        <td>เลือก Partition Scheme ไม่ตรง หรือไฟล์ <code>build_opt.h</code> หายไปจากโฟลเดอร์</td>
        <td>ตรวจว่ามีไฟล์ <code>build_opt.h</code> อยู่ในโฟลเดอร์เดียวกับ <code>.ino</code> และตั้งค่า <b>Tools → Partition Scheme</b> เป็น <code>No FS 4MB (2MB APP x2)</code></td>
      </tr>
      <tr>
        <td><b>เสียบสาย USB แล้วมองไม่เห็น Port ใน Arduino IDE</b></td>
        <td>สาย USB Type-C ที่ใช้เป็นสายชาร์จอย่างเดียว (ไม่มีสายข้อมูล Data) หรือยังไม่ได้ลงไดรเวอร์ชิป USB</td>
        <td>เปลี่ยนเป็นสาย USB Type-C ที่รองรับการโอนข้อมูล และติดตั้งไดรเวอร์ CP210x หรือ CH340 ตามชิปบนบอร์ด ESP32</td>
      </tr>
      <tr>
        <td><b>แอร์เปิดทำงานแล้ว แต่ค่ากำลังไฟในแอปขึ้น 0 W ตลอด</b></td>
        <td>คล้องห่วง CT รวบสายไฟทั้ง 2 เส้น (L+N) หรือต่อสาย TX/RX ของ PZEM สลับขา หรือไม่ได้ต่อไฟ 220V เข้าฝั่งซ้ายของ PZEM</td>
        <td>ตรวจว่าห่วง CT คล้องสาย <code>L</code> เพียงเส้นเดียว · ตรวจไฟ 220V ที่ขั้ว 1–2 ของ PZEM · ตรวจสาย UART (รุ่น IR ใช้ขา <code>16/18</code> ส่วนรุ่นสายแอร์ใช้ขา <code>18/14</code>)</td>
      </tr>
      <tr>
        <td><b>สั่งเปิดแอร์รุ่น IR จากแอปแล้ว แอร์ไม่ดังติ๊ด</b></td>
        <td>หลอด IR LED หันไม่ตรงช่องรับของแอร์ หรือต่อขาทรานซิสเตอร์ 2N2222 สลับด้าน</td>
        <td>ใช้กล้องมือถือส่องดูหลอด IR LED ขณะกดสั่งงาน (กล้องมือถือจะมองเห็นแสงสีม่วงกะพริบ) หากไม่กะพริบให้เช็คสายขา <code>GPIO 17</code> และขา E/B/C ของ 2N2222</td>
      </tr>
      <tr>
        <td><b>บอร์ดสายแอร์ Daikin หน้าจอขึ้นเตือนว่าสายไม่ตอบสนอง</b></td>
        <td>หันขั้วแถบดำของไดโอด 1N4148 ผิดด้าน หรือสลับสายสั่งงาน (ขาว) กับสายสถานะ (เหลือง) หรือลืมต่อ GND ร่วม</td>
        <td>เปิด Serial Monitor ที่ 115200 baud ตรวจค่า echo และเช็คว่าต่อสาย <code>GND</code> ของแอร์เข้ากับ <code>GND</code> ของ ESP32 แล้ว และแถบดำของ 1N4148 หันเข้าขา <code>GPIO 33</code></td>
      </tr>
      <tr>
        <td><b>เซ็นเซอร์ตรวจจับคนขึ้นว่า “เซ็นเซอร์ไม่พร้อมใช้งาน”</b></td>
        <td>สาย TX/RX ของเรดาร์ LD2410 หลวม หรือต่อไม่ไขว้กัน หรือจ่ายไฟเข้าขา 3.3V แทนที่จะเป็น 5V</td>
        <td>เรดาร์ LD2410 ต้องใช้ไฟเลี้ยงจากขั้ว <b><code>5V (VIN)</code></b> เท่านั้น และตรวจว่าขา <code>TX</code> เรดาร์ต่อเข้า <code>GPIO 32</code> ส่วนขา <code>RX</code> เรดาร์ต่อเข้า <code>GPIO 33</code></td>
      </tr>
      <tr>
        <td><b>หน้าจอ OLED 1.3 นิ้ว มืดสนิท แต่บอร์ดทำงานปกติ</b></td>
        <td>สาย SDA/SCL หลวม หรือสลับขากัน</td>
        <td>ตรวจสายจอ OLED ให้ตรงคือ <code>VCC → 3V3</code>, <code>GND → GND</code>, <code>SDA → GPIO 21</code>, <code>SCL → GPIO 22</code> แล้วกดปุ่ม RESET บอร์ดใหม่</td>
      </tr>
    </tbody>
  </table>

  <div class="callout">
    <div class="callout-title">การตรวจสอบผ่าน Serial Monitor เมื่อต้องการหาสาเหตุเชิงลึก</div>
    บอร์ดทั้ง 3 รูปแบบพิมพ์ข้อความสถานะการทำงานอย่างละเอียดออกทางพอร์ต USB ที่ความเร็ว <b>115200 baud</b> เสมอ (เช่น สถานะการสแกนเจอจอ OLED, ค่าวัตต์ที่อ่านจาก PZEM, เฟรมสายแอร์ที่ส่ง-รับ และค่าพลังงานเรดาร์รายเกต Gate 0–8) หากพบปัญหาหน้างาน สามารถนำโน้ตบุ๊กไปเสียบสาย USB เพื่ออ่านข้อความวินิจฉัยได้ทันที
  </div>

  {make_footer(13)}
</div>

</body>
</html>
"""

out_dir = r"C:\Users\rapee\Documents\GitHub\cpe_air_remote"
html_ascii = os.path.join(out_dir, "RMUTT_Hardware_Assembly_Guide.html")
html_thai = os.path.join(out_dir, "คู่มือศึกษาโปรเจค", "คู่มือการประกอบและติดตั้งฮาร์ดแวร์_RMUTT_Save_Energy.html")

with open(html_ascii, "w", encoding="utf-8") as f:
    f.write(html_content)
with open(html_thai, "w", encoding="utf-8") as f:
    f.write(html_content)

print("Generated 13-page style-matched Hardware Manual HTML successfully!")
