// =====================================================================
//  DaikinSLM8.h  -  talk to a Daikin unit over the SLM8 wired-controller bus
//
//  Protocol (decoded 8 Oct 2026, see claude/slm8_protocol_notes_TH.md):
//   - one frame per second per direction, line idles HIGH
//   - header LOW 2600us + HIGH 950us, then 64 bits, LSB first
//   - bit = LOW 375us + HIGH 370us (0) or HIGH 920us (1)
//   - tail: LOW 375us, HIGH 16ms, LOW 2ms
//   - checksum: sum of the 14 nibbles of bytes 0..6, mod 16 = high nibble of byte 7
//
//  Yellow wire = panel -> unit (commands + room temperature)
//  White  wire = unit  -> panel (status, compressor bit)
//
//  Two topologies:
//   REPLACE_PANEL : panel removed, ESP32 is the only controller.
//                   Room temperature must come from setRoomTemp().
//   BRIDGE        : yellow wire cut, panel -> ESP32 -> unit.
//                   Wall panel keeps working; last command wins
//                   (panel button press or app command).
// =====================================================================
#pragma once
#include <Arduino.h>
#include "esp_timer.h"

namespace slm8 {

// byte 3 (mode) and byte 4 (fan) values seen on the bus
enum : uint8_t { MODE_FAN = 0x01, MODE_COOL = 0x02, MODE_DRY = 0x20 };
enum : uint8_t { FAN_3 = 0x01, FAN_2 = 0x02, FAN_1 = 0x04, FAN_AUTO = 0x08 };

struct Settings {
  bool    power = false;
  uint8_t setC  = 25;          // set temperature, deg C
  uint8_t mode  = MODE_COOL;
  uint8_t fan   = FAN_AUTO;
  bool    swing = false;
  bool    sleep = false;
  bool operator==(const Settings& o) const {
    return power == o.power && setC == o.setC && mode == o.mode &&
           fan == o.fan && swing == o.swing && sleep == o.sleep;
  }
  bool operator!=(const Settings& o) const { return !(*this == o); }
};

inline uint8_t toBCD(uint8_t v)   { return ((v / 10) << 4) | (v % 10); }
inline uint8_t fromBCD(uint8_t b) { return (b >> 4) * 10 + (b & 0x0F); }
inline uint8_t fToC(uint8_t f)    { return (uint8_t)lroundf((f - 32) * 5.0f / 9.0f); }

inline uint8_t checksum(const uint8_t b[8]) {
  uint8_t s = 0;
  for (int i = 0; i < 7; i++) s += (b[i] >> 4) + (b[i] & 0x0F);
  return (s & 0x0F) << 4;
}
inline bool checksumOk(const uint8_t b[8]) { return checksum(b) == (b[7] & 0xF0); }

// Build a panel -> unit frame. Always sent in deg C.
inline void buildFrame(const Settings& s, uint8_t roomC, bool newCmd, uint8_t out[8]) {
  bool sleep = s.sleep && s.mode != MODE_DRY;          // the panel drops SLEEP in DRY
  out[0] = toBCD(constrain(s.setC, 16, 30));
  out[1] = 0x00;
  out[2] = toBCD(constrain(roomC, 0, 99));
  out[3] = s.mode | (s.power ? 0x00 : 0x10);
  out[4] = s.fan;
  out[5] = s.swing ? 0xF0 : 0x00;
  out[6] = (newCmd ? 0x10 : 0) | (sleep ? 0x02 : 0) | (s.swing ? 0x01 : 0);
  out[7] = checksum(out);
}

// Read a panel -> unit frame (converts deg F panels to deg C).
inline void parsePanelFrame(const uint8_t b[8], Settings& s, uint8_t& roomC) {
  bool f = (b[5] & 0x01) || (b[6] & 0x40);
  uint8_t set = fromBCD(b[0]), room = fromBCD(b[2]);
  s.setC  = f ? fToC(set) : set;
  roomC   = f ? fToC(room) : room;
  s.power = !(b[3] & 0x10);
  s.mode  = b[3] & 0x23;
  s.fan   = b[4] & 0x0F;
  s.swing = (b[5] & 0xF0) != 0;
  s.sleep = (b[6] & 0x02) != 0;
}

// ---------------------------------------------------------------------
//  Receiver: one per input pin. Interrupt timestamps edges, poll() decodes.
// ---------------------------------------------------------------------
class Rx;
// ISR อยู่นอกคลาสแบบ static (ไม่ใช่ inline) เพราะฟังก์ชัน IRAM_ATTR ที่ inline ในไฟล์ .h
// ทำให้ linker ของ ESP32 core 3.x ฟ้อง "dangerous relocation: l32r"
static void slm8RxIsr(void* arg);

class Rx {
 public:
  void begin(int pin) {
    pin_ = pin;
    pinMode(pin, INPUT);
    lastEdge_ = micros();
    attachInterruptArg(digitalPinToInterrupt(pin), slm8RxIsr, this, CHANGE);
  }

  // Returns true when a complete frame with a valid checksum is in out[].
  bool poll(uint8_t out[8]) {
    bool got = false;
    while (tail_ != head_) {
      Raw r = rb_[tail_];
      tail_ = (tail_ + 1) % RB;
      if (rawPulse(r.lvl, r.dur)) got = true;
    }
    uint32_t le = lastEdge_;                        // read before micros(), see v2 bug
    uint32_t now = micros();
    if (state_ == BITS && nbits_ > 0 && (int32_t)(now - le) > 20000 && finish()) got = true;
    if (got) memcpy(out, frame_, 8);
    return got;
  }

  uint32_t lastFrameMs() const { return lastFrameMs_; }
  uint32_t badFrames()   const { return bad_; }

 private:
  struct Raw { uint8_t lvl; uint32_t dur; };
  static const int RB = 512;
  Raw rb_[RB];
  volatile uint16_t head_ = 0;
  uint16_t tail_ = 0;
  volatile uint32_t lastEdge_ = 0;
  int pin_ = -1;

  uint8_t stLvl_ = 1; uint32_t stDur_ = 0; bool stValid_ = false; uint32_t pend_ = 0;
  enum { IDLE, HDR, BITS } state_ = IDLE;
  uint8_t bytes_[8]; int nbits_ = 0;
  uint8_t frame_[8];
  uint32_t lastFrameMs_ = 0, bad_ = 0;

  friend void slm8RxIsr(void* arg);

  // glitch filter: pulses < 80us are noise, folded into the stable level
  bool rawPulse(uint8_t lvl, uint32_t d) {
    if (d < 80) { pend_ += d; return false; }
    if (!stValid_) { stLvl_ = lvl; stDur_ = d; stValid_ = true; pend_ = 0; return false; }
    if (lvl == stLvl_) { stDur_ += pend_ + d; pend_ = 0; return false; }
    bool got = pulse(stLvl_, stDur_ + pend_);
    stLvl_ = lvl; stDur_ = d; pend_ = 0;
    return got;
  }

  bool pulse(uint8_t lvl, uint32_t d) {
    bool got = false;
    switch (state_) {
      case IDLE: break;
      case HDR:
        if (lvl == 1 && d >= 700 && d <= 1300) { state_ = BITS; nbits_ = 0; }
        else state_ = IDLE;
        break;
      case BITS:
        if (lvl == 0) { if (d < 200 || d > 550) { bad_++; state_ = IDLE; } }
        else if (d >= 200 && d <= 600)  addBit(0);
        else if (d >= 650 && d <= 1400) addBit(1);
        else if (d >= 3000) got = finish();
        else { bad_++; state_ = IDLE; }
        break;
    }
    if (state_ == IDLE && lvl == 0 && d >= 2300 && d <= 3000) state_ = HDR;
    return got;
  }

  void addBit(int bit) {
    if (nbits_ >= 64) { bad_++; state_ = IDLE; return; }
    int i = nbits_ / 8;
    if (nbits_ % 8 == 0) bytes_[i] = 0;
    if (bit) bytes_[i] |= 1 << (nbits_ % 8);
    nbits_++;
  }

  bool finish() {
    state_ = IDLE;
    if (nbits_ != 64 || !checksumOk(bytes_)) { bad_++; return false; }
    memcpy(frame_, bytes_, 8);
    lastFrameMs_ = millis();
    return true;
  }
};

static void IRAM_ATTR slm8RxIsr(void* arg) {
  Rx* self = (Rx*)arg;
  uint32_t t = micros();
  uint32_t d = t - self->lastEdge_;
  self->lastEdge_ = t;
  uint8_t now = digitalRead(self->pin_);
  uint16_t h = self->head_;
  self->rb_[h].lvl = !now;
  self->rb_[h].dur = d;
  self->head_ = (h + 1) % Rx::RB;
}

// ---------------------------------------------------------------------
//  Transmitter: bit-bangs one frame (~85 ms, blocking).
//  invert = true for an NPN transistor that pulls the line LOW
//  when the GPIO is HIGH.
// ---------------------------------------------------------------------
class Tx {
 public:
  void begin(int pin, bool invert) {
    pin_ = pin; inv_ = invert;
    line(true);                                     // set idle level first, so enabling
    pinMode(pin_, OUTPUT);                          // the output never glitches the line
    line(true);                                     // idle = line HIGH
  }
  void send(const uint8_t b[8]) {
    int64_t t = esp_timer_get_time();
    seg(t, false, 2600); seg(t, true, 950);
    for (int i = 0; i < 64; i++) {
      bool bit = (b[i / 8] >> (i % 8)) & 1;
      seg(t, false, 375); seg(t, true, bit ? 920 : 370);
    }
    seg(t, false, 375); seg(t, true, 16000); seg(t, false, 2000);
    line(true);
  }
 private:
  int pin_ = -1; bool inv_ = true;
  void line(bool high) { digitalWrite(pin_, (high != inv_) ? HIGH : LOW); }
  void seg(int64_t& t, bool high, uint32_t us) {    // absolute timing, no drift
    line(high);
    t += us;
    while (esp_timer_get_time() < t) {}
  }
};

// ---------------------------------------------------------------------
//  Controller
// ---------------------------------------------------------------------
class Controller {
 public:
  enum Topology { REPLACE_PANEL, BRIDGE };

  // panelRx = -1 in REPLACE_PANEL. txEnabled = false -> listen only.
  void begin(Topology topo, int panelRx, int unitRx, int unitTx, bool txInvert, bool txEnabled) {
    topo_ = topo; txEnabled_ = txEnabled;
    if (panelRx >= 0) panelRx_.begin(panelRx);
    if (unitRx >= 0)  unitRx_.begin(unitRx);
    if (txEnabled_)   tx_.begin(unitTx, txInvert);
  }

  void loop() {
    uint8_t f[8];
    uint32_t now = millis();

    if (unitRx_.poll(f)) {                          // unit -> panel status
      bool fahr = f[6] & 0x40;
      unitRoomC_ = fahr ? fToC(fromBCD(f[0])) : fromBCD(f[0]);
      compressor_ = f[4] & 0x01;
      memcpy(lastUnit_, f, 8);
    }

    bool sendNow = false;
    if (panelRx_.poll(f)) {                         // panel -> unit command
      Settings p; uint8_t room;
      parsePanelFrame(f, p, room);
      panelRoomC_ = room;
      memcpy(lastPanel_, f, 8);
      if (!panelSeenOnce_ || p != lastPanelSettings_) {
        // someone pressed a button on the wall panel: panel wins
        if (topo_ == BRIDGE) { settings_ = p; newCmdFrames_ = 4; }
        lastPanelSettings_ = p;
        panelSeenOnce_ = true;
      }
      if (topo_ == BRIDGE) sendNow = true;          // keep the panel's rhythm
    }

    bool panelAlive = panelSeenOnce_ && (now - panelRx_.lastFrameMs() < 3000);
    // BRIDGE: wait up to 5 s after boot for the panel, so we never send our
    // default "OFF" settings before we know what the panel wants.
    bool waitingForPanel = topo_ == BRIDGE && !panelSeenOnce_ && now < 5000;
    if (!waitingForPanel && !(topo_ == BRIDGE && panelAlive) && now - lastSendMs_ >= 1000)
      sendNow = true;

    if (sendNow) {
      buildFrame(settings_, roomForUnit(), newCmdFrames_ > 0, lastSent_);
      if (newCmdFrames_ > 0) newCmdFrames_--;
      if (txEnabled_) tx_.send(lastSent_);
      lastSendMs_ = now;
      sentCount_++;
    }
  }

  // App command. Applied on the next frame and flagged as a new command.
  void apply(const Settings& s) {
    if (s != settings_) { settings_ = s; newCmdFrames_ = 4; }
  }
  void setRoomTemp(float c) { extRoomC_ = (uint8_t)lroundf(c); extRoomValid_ = true; }

  const Settings& settings() const { return settings_; }
  bool panelAlive() const { return panelSeenOnce_ && millis() - panelRx_.lastFrameMs() < 3000; }
  bool unitAlive()  const { return unitRx_.lastFrameMs() && millis() - unitRx_.lastFrameMs() < 3000; }
  bool compressorRunning() const { return compressor_; }
  uint8_t unitRoomC() const { return unitRoomC_; }   // room temperature the unit reports back
  uint8_t roomForUnit() const {
    if (topo_ == BRIDGE && panelSeenOnce_) return panelRoomC_;
    if (extRoomValid_) return extRoomC_;
    return panelSeenOnce_ ? panelRoomC_ : 26;      // last resort
  }
  const uint8_t* lastSent()  const { return lastSent_; }
  const uint8_t* lastUnit()  const { return lastUnit_; }
  const uint8_t* lastPanel() const { return lastPanel_; }
  uint32_t badFrames() const { return panelRx_.badFrames() + unitRx_.badFrames(); }
  bool txEnabled() const { return txEnabled_; }
  uint32_t sentCount() const { return sentCount_; }   // changes right after each frame:
                                                      // a good moment for slow work (PZEM)

 private:
  Topology topo_ = BRIDGE;
  bool txEnabled_ = false;
  Rx panelRx_, unitRx_;
  Tx tx_;
  Settings settings_, lastPanelSettings_;
  bool panelSeenOnce_ = false;
  uint8_t panelRoomC_ = 26, unitRoomC_ = 0, extRoomC_ = 26;
  bool extRoomValid_ = false, compressor_ = false;
  int newCmdFrames_ = 0;
  uint32_t lastSendMs_ = 0, sentCount_ = 0;
  uint8_t lastSent_[8] = {0}, lastUnit_[8] = {0}, lastPanel_[8] = {0};
};

}  // namespace slm8
