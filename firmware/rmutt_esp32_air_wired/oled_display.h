// =====================================================================
//  oled_display.h  -  ตัวขับจอ OLED 1.3" SH1106 I2C สำหรับเฟิร์มแวร์แอร์ RMUTT
//  วาดด้วย oled_ui.h (5 แบบ) · ไลบรารี: U8g2 by olikraus
//
//  ต่อสาย:  VCC -> 3V3   GND -> GND   SDA -> GPIO21   SCL -> GPIO22
//  ไม่มีจอต่ออยู่ก็ไม่เป็นไร: begin() ตรวจ pull-up ของจอ ไม่เจอจะปิดตัวเอง เฟิร์มแวร์ทำงานต่อปกติ
// =====================================================================
#pragma once
#include <Arduino.h>
#include <U8g2lib.h>
#include "oled_ui.h"

// ===== ตั้งค่าจอ =====
#ifndef OLED_LAYOUT
#define OLED_LAYOUT 1          // 1 ตัวเลขใหญ่ · 2 สี่ช่อง · 3 รายการ · 4 พลังงาน+กราฟ · 5 สลับหน้า
#endif
#ifndef OLED_ROTATE_180
#define OLED_ROTATE_180 true   // true ถ้าติดจอกลับหัว (ขาเสียบอยู่ด้านล่าง)
#endif
#ifndef OLED_CONTRAST
#define OLED_CONTRAST 160      // 0-255 ยิ่งต่ำยิ่งถนอมจอ
#endif
#ifndef OLED_SAVER_AFTER_MS
#define OLED_SAVER_AFTER_MS (10UL * 60UL * 1000UL)   // แอร์ปิดนานเกินนี้ -> โหมดพักจอ กันจอเบิร์น
#endif

class OledDisplay {
 public:
  enum Screen { NORMAL, SETUP, CONNECTING, ALERT };

  bool begin() {
    // ตรวจว่ามีจอ: โมดูลจอมีตัวต้านทาน pull-up ที่ SDA/SCL ถ้าไม่มีจอ ขาจะถูก pull-down ภายในดึงลง
    pinMode(kSda, INPUT_PULLDOWN);
    pinMode(kScl, INPUT_PULLDOWN);
    delay(2);
    present_ = digitalRead(kSda) == HIGH && digitalRead(kScl) == HIGH;
    pinMode(kSda, INPUT);
    pinMode(kScl, INPUT);
    if (!present_) {
      Serial.println("OLED: not found on GPIO21/22 (display disabled)");
      return false;
    }
    u8g2_.begin();
    u8g2_.setDisplayRotation(OLED_ROTATE_180 ? U8G2_R2 : U8G2_R0);
    u8g2_.setContrast(OLED_CONTRAST);
    for (int i = 0; i < kHist; i++) hist_[i] = NAN;
    Serial.printf("OLED: SH1106 128x64 ready, layout %d\n", OLED_LAYOUT);
    return true;
  }
  bool present() const { return present_; }

  // เก็บค่ากำลังไฟลงกราฟ (ทุก 5 วินาที ไม่ว่าเรียกถี่แค่ไหน)
  void pushPower(float watts) {
    if (millis() - lastHistAt_ < 5000 && lastHistAt_ != 0) return;
    lastHistAt_ = millis();
    memmove(hist_, hist_ + 1, sizeof(float) * (kHist - 1));
    hist_[kHist - 1] = watts;
  }

  // บังคับวาดใหม่รอบถัดไปทันที (เช่น เพิ่งรับคำสั่งจากแอป)
  void poke() { dirty_ = true; }
  // ถึงรอบวาดหรือยัง (ให้ผู้เรียกข้ามการเตรียมข้อมูลได้ถ้ายังไม่ถึง)
  bool due() const { return present_ && (dirty_ || millis() - lastDrawAt_ >= 400); }

  // เรียกได้ถี่ ๆ  วาดจริงทุก 400 ms หรือเมื่อ poke()
  void show(Screen screen, OledData& d, const char* a = "", const char* b = "", const char* c = "") {
    if (!present_) return;
    const uint32_t now = millis();
    if (!dirty_ && now - lastDrawAt_ < 400) return;
    dirty_ = false;
    lastDrawAt_ = now;

    if (d.power) offSince_ = 0; else if (offSince_ == 0) offSince_ = now;
    d.history = hist_;
    d.historyLen = kHist;

    u8g2_.clearBuffer();
    switch (screen) {
      case SETUP:      oled::screenSetup(u8g2_, a, b); break;
      case CONNECTING: oled::screenConnecting(u8g2_, a, (now / 400) % 5); break;
      case ALERT:      oled::screenAlert(u8g2_, a, b, c); break;
      default:
        if (screen == NORMAL && offSince_ != 0 && now - offSince_ > OLED_SAVER_AFTER_MS) saver(d, now);
        else drawLayout(d, now);
        break;
    }
    u8g2_.sendBuffer();
  }

 private:
  static const int kHist = 64;
  static const int kSda = 21, kScl = 22;
  // I2C แบบซอฟต์แวร์: ไม่ต้องดึงไดรเวอร์ I2C ของ ESP-IDF เข้ามา (ประหยัดแฟลช ~14 KB)
  U8G2_SH1106_128X64_NONAME_F_SW_I2C u8g2_{U8G2_R0, /*clock=*/kScl, /*data=*/kSda, U8X8_PIN_NONE};
  bool present_ = false, dirty_ = true;
  uint32_t lastDrawAt_ = 0, lastHistAt_ = 0, offSince_ = 0;
  float hist_[kHist];

  void drawLayout(OledData& d, uint32_t now) {
#if OLED_LAYOUT == 2
    oled::screenTiles(u8g2_, d);
#elif OLED_LAYOUT == 3
    oled::screenList(u8g2_, d);
#elif OLED_LAYOUT == 4
    oled::screenEnergy(u8g2_, d);
#elif OLED_LAYOUT == 5
    oled::screenPages(u8g2_, d, (now / 5000) % 3);
#else
    oled::screenBig(u8g2_, d);
#endif
  }

  // พักจอ: แอร์ปิดนาน ตัวหนังสือเล็ก ๆ ย้ายตำแหน่งทุกนาที กันจุดเดิมติดค้างบนจอ OLED
  void saver(const OledData& d, uint32_t now) {
    char b[32];
    if (d.airNo > 0) snprintf(b, sizeof b, "%s #%d OFF", d.room, d.airNo);
    else snprintf(b, sizeof b, "%s OFF", d.room);
    u8g2_.setFont(u8g2_font_5x7_tr);
    int w = u8g2_.getStrWidth(b);
    uint32_t m = now / 60000UL;
    int x = (int)((m * 37) % (uint32_t)(128 - w));
    int y = 8 + (int)((m * 23) % 50);
    u8g2_.drawStr(x, y, b);
    if (d.clock[0]) u8g2_.drawStr(x, y + 9, d.clock);
  }
};
