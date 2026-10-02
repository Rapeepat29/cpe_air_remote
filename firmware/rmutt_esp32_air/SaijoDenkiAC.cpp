#include "SaijoDenkiAC.h"

namespace {

constexpr uint16_t kHeaderMark = 9050;
constexpr uint16_t kHeaderSpace = 4550;
constexpr uint16_t kBitMark = 650;
constexpr uint16_t kOneSpace = 1670;
constexpr uint16_t kZeroSpace = 550;
constexpr uint16_t kFooterMark = 650;
constexpr uint32_t kMessageGap = 100000;
constexpr uint16_t kFrequencyKhz = 38;
constexpr uint8_t kSaijoDutyCycle = 50;
constexpr uint16_t kSaijoNoRepeat = 0;

// Captured from the user's Saijo Denki remote. Bytes are sent LSB-first.
const uint8_t kPowerOff[] = {0x05, 0x00, 0x2D, 0x80, 0x54, 0x91, 0x54, 0xFF, 0xAD};
const uint8_t kPowerOn[] = {0x05, 0x09, 0x2D, 0x80, 0x94, 0x91, 0x94, 0xFF, 0xC4};
// Complete 72-bit mode frames from the additional capture. The isolated
// 1-bit UNKNOWN entry immediately before these frames is receiver noise.
const uint8_t kDry[] = {0x05, 0x09, 0x95, 0xC0, 0x20, 0xD1, 0x22, 0x00, 0x25};
const uint8_t kFanOnly[] = {0x05, 0x09, 0x95, 0xC0, 0x22, 0xD1, 0x20, 0x00, 0x0D};
const uint8_t kCool[] = {0x05, 0x09, 0x95, 0xC0, 0x20, 0xD1, 0x20, 0x00, 0x8F};

// Capture order was strongest down to Auto. Comparing it with the labelled
// fan 1/2/3/Auto captures identifies the extra strongest state as Turbo.
const uint8_t kFanAuto[] = {0x05, 0x09, 0x95, 0xC0, 0x40, 0xD1, 0x40, 0x00, 0xBF};
const uint8_t kFan1[] = {0x05, 0x09, 0x95, 0xC4, 0x40, 0xD1, 0x40, 0x00, 0xBA};
const uint8_t kFan2[] = {0x05, 0x09, 0x95, 0xC2, 0x40, 0xD1, 0x40, 0x00, 0xBC};
const uint8_t kFan3[] = {0x05, 0x09, 0x95, 0xC6, 0x40, 0xD1, 0x40, 0x00, 0xB9};
const uint8_t kFanTurbo[] = {0x05, 0x09, 0x95, 0xC1, 0x40, 0xD1, 0x40, 0x00, 0xBF};

// Capture order was bottom to top, followed by continuous swing.
const uint8_t kSwingAuto[] = {0x05, 0x09, 0x95, 0xC0, 0x80, 0xD0, 0x80, 0x00, 0xBE};
const uint8_t kSwing1[] = {0x05, 0x09, 0x95, 0xC0, 0x80, 0xD5, 0x80, 0x00, 0xBB};
const uint8_t kSwing2[] = {0x05, 0x09, 0x95, 0xC0, 0x80, 0xD1, 0x80, 0x00, 0xFF};
const uint8_t kSwing3[] = {0x05, 0x09, 0x95, 0xC0, 0x80, 0xD6, 0x80, 0x00, 0xB8};
const uint8_t kSwing4[] = {0x05, 0x09, 0x95, 0xC0, 0x80, 0xD2, 0x80, 0x00, 0xFC};
const uint8_t kSwing5[] = {0x05, 0x09, 0x95, 0xC0, 0x80, 0xD4, 0x80, 0x00, 0xFA};

const uint8_t kTemp18[] = {0x05, 0x09, 0x25, 0x80, 0x78, 0x95, 0x78, 0xFF, 0x65};
const uint8_t kTemp19[] = {0x05, 0x09, 0x65, 0x80, 0x78, 0x95, 0x78, 0xFF, 0x05};
const uint8_t kTemp20[] = {0x05, 0x09, 0x15, 0x80, 0x78, 0x95, 0x78, 0xFF, 0x55};
const uint8_t kTemp21[] = {0x05, 0x09, 0x55, 0x80, 0x78, 0x95, 0x78, 0xFF, 0x35};
const uint8_t kTemp22[] = {0x05, 0x09, 0x35, 0x80, 0x78, 0x95, 0x78, 0xFF, 0x55};
const uint8_t kTemp23[] = {0x05, 0x09, 0x75, 0x80, 0x78, 0x95, 0x78, 0xFF, 0x35};
const uint8_t kTemp24[] = {0x05, 0x09, 0x8D, 0x80, 0xB8, 0x95, 0xB8, 0xFF, 0xE9};
const uint8_t kTemp25[] = {0x05, 0x09, 0x4D, 0x80, 0xB8, 0x95, 0xB8, 0xFF, 0x69};
const uint8_t kTemp26[] = {0x05, 0x09, 0x2D, 0x80, 0xB8, 0x95, 0xB8, 0xFF, 0x29};
const uint8_t kTemp27[] = {0x05, 0x09, 0x6D, 0x80, 0xB8, 0x95, 0xB8, 0xFF, 0x69};
const uint8_t kTemp28[] = {0x05, 0x09, 0x1D, 0x80, 0xB8, 0x95, 0xB8, 0xFF, 0x09};
const uint8_t kTemp29[] = {0x05, 0x09, 0x5D, 0x80, 0xB8, 0x95, 0xB8, 0xFF, 0x59};

}  // namespace

SaijoDenkiAC::SaijoDenkiAC(const uint16_t irPin) : irsend_(irPin) {}

void SaijoDenkiAC::begin() { irsend_.begin(); }

void SaijoDenkiAC::sendState(const uint8_t state[kStateLength]) {
  irsend_.sendGeneric(
      kHeaderMark, kHeaderSpace,
      kBitMark, kOneSpace,
      kBitMark, kZeroSpace,
      kFooterMark, kMessageGap,
      state, kStateLength,
      kFrequencyKhz, false,
      kSaijoNoRepeat, kSaijoDutyCycle);
}

void SaijoDenkiAC::powerOn() { sendState(kPowerOn); }
void SaijoDenkiAC::powerOff() { sendState(kPowerOff); }
void SaijoDenkiAC::cool() { sendState(kCool); }
void SaijoDenkiAC::dry() { sendState(kDry); }
void SaijoDenkiAC::fanOnly() { sendState(kFanOnly); }

bool SaijoDenkiAC::setTemperature(const uint8_t celsius) {
  const uint8_t *state = nullptr;
  switch (celsius) {
    case 18: state = kTemp18; break;
    case 19: state = kTemp19; break;
    case 20: state = kTemp20; break;
    case 21: state = kTemp21; break;
    case 22: state = kTemp22; break;
    case 23: state = kTemp23; break;
    case 24: state = kTemp24; break;
    case 25: state = kTemp25; break;
    case 26: state = kTemp26; break;
    case 27: state = kTemp27; break;
    case 28: state = kTemp28; break;
    case 29: state = kTemp29; break;
    default: return false;
  }
  sendState(state);
  return true;
}

bool SaijoDenkiAC::setFan(const SaijoFan fan) {
  const uint8_t *state = nullptr;
  switch (fan) {
    case SaijoFan::kAuto: state = kFanAuto; break;
    case SaijoFan::kLevel1: state = kFan1; break;
    case SaijoFan::kLevel2: state = kFan2; break;
    case SaijoFan::kLevel3: state = kFan3; break;
    case SaijoFan::kTurbo: state = kFanTurbo; break;
    default: return false;
  }
  sendState(state);
  return true;
}

bool SaijoDenkiAC::setSwing(const SaijoSwing swing) {
  const uint8_t *state = nullptr;
  switch (swing) {
    case SaijoSwing::kAuto: state = kSwingAuto; break;
    case SaijoSwing::kPosition1: state = kSwing1; break;
    case SaijoSwing::kPosition2: state = kSwing2; break;
    case SaijoSwing::kPosition3: state = kSwing3; break;
    case SaijoSwing::kPosition4: state = kSwing4; break;
    case SaijoSwing::kPosition5: state = kSwing5; break;
    default: return false;
  }
  sendState(state);
  return true;
}
