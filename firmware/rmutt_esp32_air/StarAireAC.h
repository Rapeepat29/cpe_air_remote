#ifndef STAR_AIRE_AC_H_
#define STAR_AIRE_AC_H_

#include <Arduino.h>
#include <IRsend.h>

// Star Aire (รีโมต DT-03) ถอดจากรีโมตจริง 33 เฟรม ทุกเฟรมตรงกับกฎด้านล่าง
//
// header 9000/4500 us, mark 590, space "0" 540, space "1" 1650, 44 บิต ปิดท้ายด้วย mark
// ส่งครั้งเดียว ไม่มีเฟรมซ้ำ แบ่งเป็น 11 นิบเบิล (4 บิต ส่งบิตสูงก่อน)
//   [0]    = 2 คงที่
//   [1]    = เปิดเครื่อง (8) + sleep (4)
//   [2]    = โหมด (2 บิตบน) + พัดลม (2 บิตล่าง)
//   [3]    = อุณหภูมิ - 15 (15-30 C)
//   [4..9] = 0 (ยังไม่ได้เก็บปุ่ม swing / timer)
//   [10]   = checksum = กลับบิตของผลรวมนิบเบิล 0-9 เอา 4 บิตล่าง
enum class StarAireMode : uint8_t {
  kFan = 0,
  kCool = 1,
  kDry = 2,
};

enum class StarAireFan : uint8_t {
  kAuto = 0,
  kHigh = 1,
  kMedium = 2,
  kLow = 3,
};

class StarAireAC {
 public:
  static const uint8_t kNibbleCount = 11;
  static const uint8_t kMinTemperature = 15;
  static const uint8_t kMaxTemperature = 30;

  explicit StarAireAC(uint16_t irPin);

  void begin();
  // รีโมตรุ่นนี้ส่งสถานะทั้งชุดทุกครั้ง จึงส่งครั้งเดียวได้ทุกค่า
  void send(bool power, StarAireMode mode, StarAireFan fan, uint8_t celsius,
            bool sleep);

  static void buildNibbles(bool power, StarAireMode mode, StarAireFan fan,
                           uint8_t celsius, bool sleep,
                           uint8_t nibbles[kNibbleCount]);

 private:
  IRsend irsend_;
};

#endif  // STAR_AIRE_AC_H_
