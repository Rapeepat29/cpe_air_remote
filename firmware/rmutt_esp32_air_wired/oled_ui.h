// =====================================================================
//  oled_ui.h  -  หน้าจอ OLED 1.3" 128x64 (SH1106, I2C) สำหรับตัวควบคุมแอร์ RMUTT
//  ใช้ได้ทั้งเฟิร์มแวร์ IR และเฟิร์มแวร์สายแอร์ (SLM8)
//  ทุกฟังก์ชันวาดลงบัฟเฟอร์ของ U8G2 อย่างเดียว ผู้เรียกเป็นคน clearBuffer()/sendBuffer()
// =====================================================================
#pragma once
#include <math.h>
#include <stdio.h>
#include <string.h>

struct OledData {
  // ห้อง/เครื่อง
  const char* room = "";
  int airNo = 0;
  // สถานะที่สั่ง
  bool power = false;
  int setC = 25;
  const char* mode = "cool";        // cool | dry | fan | auto | heat
  const char* fan = "auto";         // auto | low | medium | high | turbo
  bool swing = false;
  bool sleep = false;
  // วัดได้
  float roomC = NAN;                // DHT11 (NAN = ไม่มีเซนเซอร์)
  bool pzemOk = false;
  float watts = NAN, kwh = NAN, volts = NAN, amps = NAN, pf = NAN, hz = NAN;
  bool acRunning = false;           // จาก PZEM
  bool outsideSchedule = false;
  // เครือข่าย
  bool wifiOk = false, mqttOk = false;
  int rssi = -100;
  const char* ssid = "";
  const char* ip = "";
  const char* clock = "";           // "14:32" หรือ "" ถ้ายังไม่รู้เวลา
  const char* fw = "";
  const char* deviceId = "";
  // สายแอร์ (เฉพาะเฟิร์มแวร์ SLM8)
  bool wired = false;
  bool busOk = false;
  bool compressor = false;
  // กราฟกำลังไฟ (ค่า W ย้อนหลัง เก่า -> ใหม่)
  const float* history = nullptr;
  int historyLen = 0;
};

namespace oled {

// ---------------------------------------------------------------- helpers
inline const char* modeLabel(const char* m) {
  if (!strcmp(m, "dry")) return "DRY";
  if (!strcmp(m, "fan")) return "FAN";
  if (!strcmp(m, "auto")) return "AUTO";
  if (!strcmp(m, "heat")) return "HEAT";
  return "COOL";
}
inline int fanLevel(const char* f) {   // 0 = auto
  if (!strcmp(f, "low")) return 1;
  if (!strcmp(f, "medium")) return 2;
  if (!strcmp(f, "high")) return 3;
  if (!strcmp(f, "turbo")) return 4;
  return 0;
}
inline const char* fanLabel(const char* f) {
  int l = fanLevel(f);
  return l == 0 ? "AUTO" : l == 1 ? "LOW" : l == 2 ? "MED" : l == 3 ? "HIGH" : "TURBO";
}
inline int wifiBars(int rssi) { return rssi >= -55 ? 4 : rssi >= -65 ? 3 : rssi >= -75 ? 2 : rssi >= -85 ? 1 : 0; }

// สัญญาณ Wi-Fi 4 ขีด กว้าง 11 สูง 8 (มุมซ้ายล่าง x,y)
inline void iconWifi(U8G2& d, int x, int y, const OledData& s) {
  int bars = s.wifiOk ? wifiBars(s.rssi) : 0;
  for (int i = 0; i < 4; i++) {
    int h = 2 + i * 2;
    if (i < bars) d.drawBox(x + i * 3, y - h, 2, h);
    else d.drawPixel(x + i * 3, y - 1);
  }
  if (!s.wifiOk) { d.drawLine(x, y - 8, x + 10, y); }
}
// กล่อง "M" = MQTT, ทึบเมื่อเชื่อมต่อ
inline void iconTag(U8G2& d, int x, int y, const char* t, bool on) {
  d.setFont(u8g2_font_4x6_tr);
  int w = d.getStrWidth(t) + 3;
  if (on) { d.drawRBox(x, y - 7, w, 8, 1); d.setDrawColor(0); d.drawStr(x + 2, y - 1, t); d.setDrawColor(1); }
  else    { d.drawRFrame(x, y - 7, w, 8, 1); d.drawStr(x + 2, y - 1, t); }
}
inline int tagWidth(U8G2& d, const char* t) { d.setFont(u8g2_font_4x6_tr); return d.getStrWidth(t) + 3; }

// ไอคอนโหมด 16x16 (มุมซ้ายบน)
inline void iconMode(U8G2& d, int x, int y, const char* m) {
  int cx = x + 8, cy = y + 8;
  if (!strcmp(m, "dry")) {                       // หยดน้ำ
    d.drawDisc(cx, cy + 3, 5);
    d.drawTriangle(cx - 5, cy + 2, cx + 5, cy + 2, cx, cy - 8);
    d.setDrawColor(0); d.drawPixel(cx - 2, cy + 3); d.drawPixel(cx - 2, cy + 4); d.setDrawColor(1);
  } else if (!strcmp(m, "fan")) {                // ใบพัด
    d.drawCircle(cx, cy, 7);
    d.drawDisc(cx, cy, 1);
    d.drawDisc(cx, cy - 4, 2); d.drawDisc(cx + 4, cy + 2, 2); d.drawDisc(cx - 4, cy + 2, 2);
  } else if (!strcmp(m, "heat")) {               // พระอาทิตย์
    d.drawDisc(cx, cy, 3);
    for (int i = 0; i < 8; i++) {
      float a = i * 0.785f;
      d.drawLine(cx + (int)lroundf(cosf(a) * 5), cy + (int)lroundf(sinf(a) * 5), cx + (int)lroundf(cosf(a) * 7), cy + (int)lroundf(sinf(a) * 7));
    }
  } else if (!strcmp(m, "auto")) {               // A ในวงกลม
    d.drawCircle(cx, cy, 7);
    d.setFont(u8g2_font_helvB08_tr); d.drawStr(cx - 3, cy + 4, "A");
  } else {                                       // เกล็ดหิมะ
    d.drawLine(cx, y + 1, cx, y + 15);
    d.drawLine(x + 2, cy - 4, x + 14, cy + 4);
    d.drawLine(x + 2, cy + 4, x + 14, cy - 4);
    d.drawLine(cx - 2, y + 2, cx, y + 4); d.drawLine(cx + 2, y + 2, cx, y + 4);
    d.drawLine(cx - 2, y + 14, cx, y + 12); d.drawLine(cx + 2, y + 14, cx, y + 12);
  }
}
// แท่งพัดลม 4 ระดับ (มุมซ้ายล่าง)  auto = กรอบทุกแท่ง + ตัว A
inline void iconFan(U8G2& d, int x, int y, const char* f) {
  int l = fanLevel(f);
  for (int i = 0; i < 4; i++) {
    int h = 3 + i * 3;
    if (l > i) d.drawBox(x + i * 4, y - h, 3, h);
    else d.drawFrame(x + i * 4, y - h, 3, h);
  }
}
inline void degree(U8G2& d, int x, int y, int r = 1) { d.drawCircle(x + r, y + r, r); }

inline void fmt(char* b, size_t n, const char* f, float v) { if (isnan(v)) snprintf(b, n, "--"); else snprintf(b, n, f, v); }
inline void fmtWatts(char* b, size_t n, float w) {
  if (isnan(w)) snprintf(b, n, "-- W");
  else if (w >= 10000) snprintf(b, n, "%.1fkW", w / 1000.0f);
  else snprintf(b, n, "%.0f W", w);
}
inline void roomLine(char* b, size_t n, const OledData& s) {
  if (s.airNo > 0) snprintf(b, n, "%s #%d", s.room, s.airNo); else snprintf(b, n, "%s", s.room);
}

// แถบบนร่วม: ห้อง ซ้าย · ไอคอน ขวา  (สูง 9 พิกเซล)
inline void topBar(U8G2& d, const OledData& s, bool showClock = true) {
  char b[24]; roomLine(b, sizeof b, s);
  d.setFont(u8g2_font_5x7_tr);
  d.drawStr(0, 7, b);
  int x = 128 - 11;
  iconWifi(d, x, 8, s);
  x -= tagWidth(d, "M") + 2; iconTag(d, x, 8, "M", s.mqttOk);
  if (s.wired) { x -= tagWidth(d, "BUS") + 2; iconTag(d, x, 8, "BUS", s.busOk); }
  if (showClock && s.clock[0]) {
    d.setFont(u8g2_font_5x7_tr);
    int w = d.getStrWidth(s.clock);
    int left = d.getStrWidth(b) + 4;
    int cx = (left + x - 2) / 2 - w / 2;
    if (cx > left) d.drawStr(cx, 7, s.clock);
  }
}

// ====================================================================
//  แบบ 1  "ตัวเลขใหญ่"  อุณหภูมิที่ตั้งตัวโต ตรงกลาง เหมือนรีโมตแอร์
// ====================================================================
inline void screenBig(U8G2& d, const OledData& s) {
  topBar(d, s);
  d.drawHLine(0, 10, 128);
  char b[24];
  if (s.power) {
    iconMode(d, 2, 15, s.mode);
    d.setFont(u8g2_font_5x7_tr);
    d.drawStr(10 - d.getStrWidth(modeLabel(s.mode)) / 2, 41, modeLabel(s.mode));
    d.setFont(u8g2_font_logisoso32_tn);
    snprintf(b, sizeof b, "%d", s.setC);
    int w = d.getStrWidth(b);
    int x = 64 - (w + 8) / 2;
    d.drawStr(x, 47, b);
    degree(d, x + w + 2, 15, 2);
    d.setFont(u8g2_font_helvB08_tr); d.drawStr(x + w + 2, 27, "C");
    iconFan(d, 106, 33, s.fan);
    d.setFont(u8g2_font_5x7_tr);
    d.drawStr(113 - d.getStrWidth(fanLabel(s.fan)) / 2, 41, fanLabel(s.fan));
    if (s.swing) iconTag(d, 103, 51, "SW", true);
    if (s.sleep) iconTag(d, 2, 51, "ZZ", true);
  } else {
    d.setFont(u8g2_font_helvB18_tr);
    d.drawStr(64 - d.getStrWidth("OFF") / 2, 40, "OFF");
  }
  d.drawHLine(0, 53, 128);
  d.setFont(u8g2_font_5x7_tr);
  fmtWatts(b, sizeof b, s.watts); d.drawStr(0, 63, b);
  if (s.outsideSchedule) iconTag(d, 46, 63, "OUT OF CLASS", true);
  else if (s.wired && s.power) { d.drawStr(46, 63, s.compressor ? "COMP ON" : "COMP --"); }
  if (!isnan(s.roomC)) { snprintf(b, sizeof b, "RM %.0f", s.roomC); int w = d.getStrWidth(b); d.drawStr(122 - w, 63, b); degree(d, 123, 57); }
}

// ====================================================================
//  แบบ 2  "4 ช่อง"  ตั้ง / ห้อง / กำลังไฟ / พลังงาน
// ====================================================================
inline void tile(U8G2& d, int x, int y, int w, int h, const char* label, const char* value, const char* unit, bool inverse) {
  if (inverse) d.drawRBox(x, y, w, h, 3); else d.drawRFrame(x, y, w, h, 3);
  d.setDrawColor(inverse ? 0 : 1);
  d.setFont(u8g2_font_4x6_tr); d.drawStr(x + 4, y + 8, label);
  d.setFont(u8g2_font_helvB12_tr);
  int vw = d.getStrWidth(value);
  d.setFont(u8g2_font_5x7_tr);
  int uw = d.getStrWidth(unit);
  int vx = x + (w - vw - uw - 2) / 2;
  d.setFont(u8g2_font_helvB12_tr); d.drawStr(vx, y + h - 4, value);
  d.setFont(u8g2_font_5x7_tr); d.drawStr(vx + vw + 2, y + h - 4, unit);
  d.setDrawColor(1);
}
inline void screenTiles(U8G2& d, const OledData& s) {
  char b[40], v[16];
  d.setFont(u8g2_font_4x6_tr);
  roomLine(v, sizeof v, s);
  snprintf(b, sizeof b, "%s  %s %s %s", v, s.power ? "ON" : "OFF", s.power ? modeLabel(s.mode) : "", s.power ? fanLabel(s.fan) : "");
  d.drawStr(0, 6, b);
  iconWifi(d, 117, 7, s);
  iconTag(d, 103, 7, "M", s.mqttOk);
  if (s.power) snprintf(v, sizeof v, "%d", s.setC); else snprintf(v, sizeof v, "OFF");
  tile(d, 0, 9, 63, 27, "SET", v, s.power ? "C" : "", false);
  fmt(v, sizeof v, "%.1f", s.roomC);
  tile(d, 65, 9, 63, 27, "ROOM", v, "C", false);
  if (isnan(s.watts)) snprintf(v, sizeof v, "--"); else snprintf(v, sizeof v, "%.0f", s.watts);
  tile(d, 0, 37, 63, 27, s.outsideSchedule ? "POWER  !" : "POWER", v, "W", s.outsideSchedule);
  fmt(v, sizeof v, "%.2f", s.kwh);
  tile(d, 65, 37, 63, 27, "ENERGY", v, "kWh", false);
}

// ====================================================================
//  แบบ 3  "รายการ"  ตัวหนังสือล้วน 6 บรรทัด อ่านครบในหน้าเดียว
// ====================================================================
inline void screenList(U8G2& d, const OledData& s) {
  char b[40], r[16];
  d.drawBox(0, 0, 128, 10);
  d.setDrawColor(0);
  d.setFont(u8g2_font_6x10_tr);
  roomLine(r, sizeof r, s);
  d.drawStr(2, 8, r);
  if (s.clock[0]) d.drawStr(126 - d.getStrWidth(s.clock), 8, s.clock);
  d.setDrawColor(1);
  if (s.power) snprintf(b, sizeof b, "ON  %-4s %2dC %s", modeLabel(s.mode), s.setC, s.swing ? "SW" : "");
  else snprintf(b, sizeof b, "OFF");
  d.drawStr(0, 20, b);
  snprintf(b, sizeof b, "FAN %-5s%s", fanLabel(s.fan), s.sleep ? " SLEEP" : "");
  d.drawStr(0, 30, b);
  if (isnan(s.roomC)) snprintf(r, sizeof r, "--"); else snprintf(r, sizeof r, "%.1fC", s.roomC);
  if (s.wired) snprintf(b, sizeof b, "ROOM %s COMP %s", r, s.compressor ? "ON" : "--");
  else snprintf(b, sizeof b, "ROOM %s", r);
  d.drawStr(0, 40, b);
  if (s.pzemOk) snprintf(b, sizeof b, "%.0fW %.2fA %.0fV", s.watts, s.amps, s.volts);
  else snprintf(b, sizeof b, "METER --");
  d.drawStr(0, 50, b);
  d.drawHLine(0, 53, 128);
  d.setFont(u8g2_font_5x7_tr);
  snprintf(b, sizeof b, "WiFi%s", s.wifiOk ? "" : " X");
  d.drawStr(0, 63, b);
  iconWifi(d, 22, 63, s);
  iconTag(d, 40, 63, "MQTT", s.mqttOk);
  if (s.wired) iconTag(d, 63, 63, "BUS", s.busOk);
  if (s.outsideSchedule) iconTag(d, 86, 63, "OUTSIDE", true);
}

// ====================================================================
//  แบบ 4  "พลังงาน"  กำลังไฟตัวโต + กราฟย้อนหลัง
// ====================================================================
inline void screenEnergy(U8G2& d, const OledData& s) {
  char b[24];
  d.setFont(u8g2_font_logisoso20_tn);
  if (isnan(s.watts)) snprintf(b, sizeof b, "0"); else snprintf(b, sizeof b, "%.0f", s.watts);
  d.drawStr(0, 21, b);
  int w = d.getStrWidth(b);
  d.setFont(u8g2_font_helvB08_tr); d.drawStr(w + 2, 21, "W");
  d.setFont(u8g2_font_helvB10_tr);
  fmt(b, sizeof b, "%.2f", s.kwh);
  int kw = d.getStrWidth(b);
  d.drawStr(127 - kw, 12, b);
  d.setFont(u8g2_font_4x6_tr); d.drawStr(127 - d.getStrWidth("kWh"), 20, "kWh");
  iconWifi(d, 117 - kw - 6, 9, s);
  d.setFont(u8g2_font_5x7_tr);
  char r[16]; roomLine(r, sizeof r, s);
  if (s.power) snprintf(b, sizeof b, "%s %s %dC %s", r, modeLabel(s.mode), s.setC, fanLabel(s.fan));
  else snprintf(b, sizeof b, "%s  OFF", r);
  d.drawStr(0, 31, b);
  // กราฟ
  const int gx = 0, gy = 34, gw = 128, gh = 30;
  d.drawHLine(gx, gy + gh - 1, gw);
  float mx = 100;
  for (int i = 0; i < s.historyLen; i++) if (!isnan(s.history[i]) && s.history[i] > mx) mx = s.history[i];
  int n = s.historyLen < gw / 2 ? s.historyLen : gw / 2;
  for (int i = 0; i < n; i++) {
    float v = s.history[s.historyLen - n + i];
    if (isnan(v)) continue;
    int h = (int)lroundf(v / mx * (gh - 3));
    if (h > 0) d.drawBox(gx + gw - (n - i) * 2, gy + gh - 1 - h, 1, h);
  }
  d.setFont(u8g2_font_4x6_tr);
  snprintf(b, sizeof b, "%.0fW", mx);
  d.drawStr(0, gy + 6, b);
  if (s.outsideSchedule) iconTag(d, 80, gy + 7, "OUTSIDE", true);
}

// ====================================================================
//  แบบ 5  "สลับหน้า"  3 หน้า เปลี่ยนเองทุก 5 วินาที  (page = 0..2)
// ====================================================================
inline void pageDots(U8G2& d, int page, int pages) {
  for (int i = 0; i < pages; i++) {
    int x = 128 - (pages - i) * 6;
    if (i == page) d.drawDisc(x + 2, 61, 2); else d.drawCircle(x + 2, 61, 1);
  }
}
inline void screenPages(U8G2& d, const OledData& s, int page) {
  char b[40];
  if (page == 0) {
    topBar(d, s, false);
    d.drawHLine(0, 10, 128);
    if (s.power) {
      iconMode(d, 4, 18, s.mode);
      d.setFont(u8g2_font_logisoso26_tn);
      snprintf(b, sizeof b, "%d", s.setC);
      int w = d.getStrWidth(b);
      d.drawStr(30, 44, b);
      degree(d, 32 + w, 17, 2);
      d.setFont(u8g2_font_6x10_tr);
      d.drawStr(76, 24, modeLabel(s.mode));
      d.drawStr(76, 35, fanLabel(s.fan));
      if (!isnan(s.roomC)) { snprintf(b, sizeof b, "RM %.0f", s.roomC); d.drawStr(76, 46, b); }
    } else {
      d.setFont(u8g2_font_helvB18_tr); d.drawStr(64 - d.getStrWidth("OFF") / 2, 42, "OFF");
    }
    d.setFont(u8g2_font_5x7_tr);
    d.drawStr(0, 63, s.power ? (s.acRunning ? "RUNNING" : "STARTING") : "STANDBY");
  } else if (page == 1) {
    d.setFont(u8g2_font_6x10_tr);
    d.drawStr(0, 8, "POWER METER");
    d.drawHLine(0, 10, 128);
    char v[16];
    fmt(v, sizeof v, "%.1f V", s.volts);  d.drawStr(0, 22, v);
    fmt(v, sizeof v, "%.2f A", s.amps);   d.drawStr(66, 22, v);
    fmtWatts(v, sizeof v, s.watts);       d.drawStr(0, 34, v);
    fmt(v, sizeof v, "%.2f kWh", s.kwh);  d.drawStr(66, 34, v);
    fmt(v, sizeof v, "PF %.2f", s.pf);    d.drawStr(0, 46, v);
    fmt(v, sizeof v, "%.1f Hz", s.hz);    d.drawStr(66, 46, v);
    d.setFont(u8g2_font_5x7_tr);
    d.drawStr(0, 63, s.pzemOk ? (s.outsideSchedule ? "OUTSIDE CLASS TIME" : "PZEM OK") : "PZEM NOT FOUND");
  } else {
    d.setFont(u8g2_font_6x10_tr);
    d.drawStr(0, 8, "NETWORK");
    iconWifi(d, 117, 9, s);
    d.drawHLine(0, 10, 128);
    d.setFont(u8g2_font_5x7_tr);
    snprintf(b, sizeof b, "WiFi %s %ddBm", s.ssid, s.rssi); d.drawStr(0, 20, b);
    snprintf(b, sizeof b, "IP   %s", s.ip[0] ? s.ip : "--");  d.drawStr(0, 29, b);
    snprintf(b, sizeof b, "MQTT %s", s.mqttOk ? "CONNECTED" : "OFFLINE"); d.drawStr(0, 38, b);
    if (s.wired) { snprintf(b, sizeof b, "BUS  %s", s.busOk ? "OK" : "NO REPLY"); d.drawStr(0, 47, b); }
    snprintf(b, sizeof b, "FW %s", s.fw); d.drawStr(0, 63, b);
  }
  pageDots(d, page, 3);
}

// ====================================================================
//  หน้าพิเศษ (ใช้ร่วมกับทุกแบบ)
// ====================================================================
inline void screenSetup(U8G2& d, const char* bleName, const char* reason) {
  d.drawRBox(0, 0, 128, 13, 2);
  d.setDrawColor(0); d.setFont(u8g2_font_helvB08_tr); d.drawStr(64 - d.getStrWidth("SETUP MODE") / 2, 10, "SETUP MODE"); d.setDrawColor(1);
  // ไอคอนบลูทูธ
  int x = 6, y = 18;
  d.drawLine(x + 4, y, x + 4, y + 16); d.drawLine(x + 4, y, x + 8, y + 4); d.drawLine(x + 8, y + 4, x, y + 12);
  d.drawLine(x + 4, y + 16, x + 8, y + 12); d.drawLine(x + 8, y + 12, x, y + 4);
  d.setFont(u8g2_font_5x7_tr); d.drawStr(20, 23, "Bluetooth name:");
  d.setFont(u8g2_font_6x10_tr); d.drawStr(20, 34, bleName);
  d.setFont(u8g2_font_5x7_tr);
  d.drawStr(0, 50, "Open RMUTT app > Add AC");
  d.drawStr(0, 60, reason);
}
inline void screenConnecting(U8G2& d, const char* ssid, int step) {
  d.setFont(u8g2_font_helvB08_tr); d.drawStr(64 - d.getStrWidth("Connecting Wi-Fi") / 2, 18, "Connecting Wi-Fi");
  d.setFont(u8g2_font_6x10_tr); d.drawStr(64 - d.getStrWidth(ssid) / 2, 34, ssid);
  for (int i = 0; i < 5; i++) { if (i == step % 5) d.drawDisc(40 + i * 12, 48, 3); else d.drawCircle(40 + i * 12, 48, 2); }
}
inline void screenAlert(U8G2& d, const char* title, const char* line1, const char* line2) {
  d.drawTriangle(14, 4, 2, 26, 26, 26);
  d.setDrawColor(0); d.drawBox(13, 11, 3, 8); d.drawBox(13, 21, 3, 3); d.setDrawColor(1);
  d.setFont(u8g2_font_helvB08_tr); d.drawStr(32, 19, title);
  d.setFont(u8g2_font_6x10_tr); d.drawStr(0, 44, line1); d.drawStr(0, 58, line2);
}

}  // namespace oled
