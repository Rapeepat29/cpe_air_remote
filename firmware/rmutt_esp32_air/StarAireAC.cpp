#include "StarAireAC.h"

namespace {

constexpr uint16_t kHeaderMark = 9000;
constexpr uint16_t kHeaderSpace = 4500;
constexpr uint16_t kBitMark = 590;
constexpr uint16_t kOneSpace = 1650;
constexpr uint16_t kZeroSpace = 540;
constexpr uint16_t kFrequencyKhz = 38;
// header 2 + (11 นิบเบิล x 4 บิต x mark/space) + mark ปิดท้าย
constexpr uint16_t kRawLength = 2 + StarAireAC::kNibbleCount * 4 * 2 + 1;

}  // namespace

StarAireAC::StarAireAC(const uint16_t irPin) : irsend_(irPin) {}

void StarAireAC::begin() { irsend_.begin(); }

void StarAireAC::buildNibbles(const bool power, const StarAireMode mode,
                              const StarAireFan fan, const uint8_t celsius,
                              const bool sleep,
                              uint8_t nibbles[kNibbleCount]) {
  for (uint8_t i = 0; i < kNibbleCount; i++) nibbles[i] = 0;

  const uint8_t temperature =
      celsius < kMinTemperature ? kMinTemperature
      : celsius > kMaxTemperature ? kMaxTemperature
                                  : celsius;
  nibbles[0] = 0x2;
  nibbles[1] = (power ? 0x8 : 0x0) | (sleep ? 0x4 : 0x0);
  nibbles[2] = ((static_cast<uint8_t>(mode) & 0x3) << 2) |
               (static_cast<uint8_t>(fan) & 0x3);
  nibbles[3] = temperature - kMinTemperature;

  uint8_t sum = 0;
  for (uint8_t i = 0; i < kNibbleCount - 1; i++) sum += nibbles[i];
  nibbles[kNibbleCount - 1] = (~sum) & 0x0F;
}

void StarAireAC::send(const bool power, const StarAireMode mode,
                      const StarAireFan fan, const uint8_t celsius,
                      const bool sleep) {
  uint8_t nibbles[kNibbleCount];
  buildNibbles(power, mode, fan, celsius, sleep, nibbles);

  uint16_t raw[kRawLength];
  uint16_t length = 0;
  raw[length++] = kHeaderMark;
  raw[length++] = kHeaderSpace;
  for (uint8_t i = 0; i < kNibbleCount; i++) {
    for (int8_t bit = 3; bit >= 0; bit--) {
      raw[length++] = kBitMark;
      raw[length++] = ((nibbles[i] >> bit) & 1) ? kOneSpace : kZeroSpace;
    }
  }
  raw[length++] = kBitMark;

  irsend_.sendRaw(raw, length, kFrequencyKhz);
}
