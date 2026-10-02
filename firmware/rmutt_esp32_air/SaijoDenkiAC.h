#ifndef SAIJO_DENKI_AC_H_
#define SAIJO_DENKI_AC_H_

#include <Arduino.h>
#include <IRsend.h>

enum class SaijoFan : uint8_t {
  kAuto = 0,
  kLevel1 = 1,
  kLevel2 = 2,
  kLevel3 = 3,
  kTurbo = 4,
};

enum class SaijoSwing : uint8_t {
  kAuto = 0,
  kPosition1 = 1,
  kPosition2 = 2,
  kPosition3 = 3,
  kPosition4 = 4,
  kPosition5 = 5,
};

class SaijoDenkiAC {
 public:
  explicit SaijoDenkiAC(uint16_t irPin);

  void begin();
  void powerOn();
  void powerOff();
  void cool();
  void dry();
  void fanOnly();
  bool setTemperature(uint8_t celsius);
  bool setFan(SaijoFan fan);
  bool setSwing(SaijoSwing swing);

 private:
  static const uint8_t kStateLength = 9;
  void sendState(const uint8_t state[kStateLength]);

  IRsend irsend_;
};

#endif  // SAIJO_DENKI_AC_H_
