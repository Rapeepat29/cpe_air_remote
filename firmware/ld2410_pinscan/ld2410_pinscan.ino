/*
 * ld2410_pinscan - สแกนขา ESP32 ทีละขา เพื่อหาว่าขาไหนรับสัญญาณจาก LD2410C
 *
 * ใช้เมื่อ: ต่อ LD2410C แล้ว ESP32 ไม่ได้รับข้อมูลเลย (0 ไบต์)
 *           แต่เช็คผ่านบลูทูธแล้วโมดูลทำงานปกติ
 *
 * เมื่อโมดูลปกติแล้ว ปัญหาเหลือแค่ 2 อย่าง
 *   ก. ขา ESP32 ที่ใช้อยู่ เสียหรือใช้เป็น GPIO ไม่ได้
 *   ข. สายเสียบผิดแพด (แพดที่เขียนว่า TX บนบอร์ดอาจไม่ใช่ TX จริง)
 *
 * สเก็ตช์นี้หาให้ทั้งสองอย่าง โดยไม่ต้องเดา
 *
 * ---------------------------------------------------------------
 * วิธีใช้ (สำคัญ อ่านก่อน)
 * ---------------------------------------------------------------
 *   1. ต่อไฟให้โมดูลไว้ตามปกติ  VCC -> 5V,  GND -> GND
 *      *** GND ต้องต่อถึงกันเสมอ ไม่งั้นสแกนไม่เจออะไรเลย ***
 *   2. เอาสายเส้นเดียว จากแพดที่คิดว่าเป็น TX ของโมดูล
 *      ไปจิ้มขา ESP32 ทีละขา
 *   3. อัปโหลดสเก็ตช์นี้ เปิด Serial Monitor ที่ 115200
 *   4. สเก็ตช์จะสแกนซ้ำทุก 2 วินาทีไม่หยุด
 *      ขยับสายไปมาแล้วดูหน้าจอสด ๆ ได้เลย
 *   5. ขาไหนขึ้นว่า  <<< UART  คือขาที่ใช้ได้
 *      ถ้าไล่ครบทุกขาแล้วไม่เจอ ให้ย้ายสายไปแพดอื่นของโมดูลแล้วไล่ใหม่
 *      (LD2410C มี 5 แพด ตัวที่เป็น TX จริงอาจไม่ใช่ตัวที่เขียนว่า TX)
 *
 * ข้อควรระวัง
 *   - ห้ามคาสายไว้ที่ GPIO12 ตอนกดปุ่มรีเซ็ต ถ้า GPIO12 ถูกดันเป็น HIGH
 *     ตอนบูต บอร์ดจะตั้งไฟแฟลชผิดแล้วบูตไม่ขึ้น ถอดสายก่อนรีเซ็ตทุกครั้ง
 *
 * การอัปโหลดสเก็ตช์นี้ไม่ลบค่าที่ตั้งไว้ใน NVS
 * ห้องกับค่า MQTT ยังอยู่ครบ แฟลชสเก็ตช์หลักกลับไปก็ใช้ได้เลย
 */

#include <Arduino.h>

/*
 * ขาที่สแกนได้ ต้องเป็นขาที่มีตัวต้านทาน pull ภายใน จึงจะแยกได้ว่า
 * "ไม่มีอะไรต่อ" กับ "มีสายต่อแต่เงียบ"
 *
 * ตัดออกโดยตั้งใจ
 *   GPIO 6-11   ต่อกับชิปแฟลชภายใน แตะแล้วบอร์ดค้าง
 *   GPIO 1, 3   เป็น Serial ที่ใช้คุยกับคอมอยู่
 *   GPIO 0      ปุ่ม BOOT
 *   GPIO 34-39  เป็นขาอ่านอย่างเดียว ไม่มี pull ภายใน สแกนแล้วได้แต่สัญญาณรบกวน
 *               (ใช้เป็น RX ได้นะ แต่ต้องเสียบแล้วลองเลย สแกนอัตโนมัติไม่ได้)
 */
const uint8_t PINS[] = {
  2, 4, 5, 12, 13, 14, 16, 17, 18, 19, 21, 22, 23, 25, 26, 27, 32, 33
};
constexpr size_t PIN_COUNT = sizeof(PINS) / sizeof(PINS[0]);

// อ่านขานานเท่านี้เพื่อนับการเปลี่ยนสถานะ
// LD2410 ส่งเฟรมทุก ~100ms ดังนั้น 250ms ครอบคลุมได้อย่างน้อย 2 เฟรม
constexpr uint32_t SAMPLE_MS = 250;

/*
 * เกณฑ์แยกว่าอะไรคือ UART จริง
 *
 * LD2410 ส่งเฟรมละ ~30 ไบต์ ทุก 100ms => ใน 250ms ได้ราว 2-3 เฟรม
 * คิดเป็นบิตที่พลิกจริงหลักร้อย ไม่ถึงพัน
 *
 * ส่วนคริสตัล 32.768kHz ที่บางบอร์ดติดมาที่ GPIO32/33 จะพลิก
 * 65536 ครั้งต่อวินาที = ราว 16000 ครั้งใน 250ms
 *
 * ตัวเลขห่างกันสิบเท่า เลยแยกด้วยช่วงได้ชัดเจน
 */
constexpr uint32_t ACTIVITY_MIN = 20;      // ต่ำกว่านี้ = เงียบ ไม่มีข้อมูล
constexpr uint32_t ACTIVITY_MAX = 8000;    // สูงกว่านี้ = ไม่ใช่ UART แล้ว

enum PinVerdict {
  VERDICT_FREE,        // ไม่มีอะไรต่ออยู่
  VERDICT_UART,        // เจอสัญญาณ UART
  VERDICT_HIGH,        // มีสายต่อ ถูกดันเป็น HIGH ค้าง
  VERDICT_LOW,         // ถูกดันเป็น LOW ค้าง
  VERDICT_UNSTABLE,    // แกว่งเร็วสม่ำเสมอ น่าจะเป็นคริสตัล ไม่ใช่ข้อมูล
};

struct PinReport {
  uint8_t pin;
  bool pullUpRead;
  bool pullDownRead;
  uint32_t transitions;
  PinVerdict verdict;
};

// ประกาศล่วงหน้าเอง ไม่พึ่งตัวสร้าง prototype ของ Arduino
// เพราะฟังก์ชันพวกนี้รับ/คืนชนิดข้อมูลที่เรานิยามเอง
void scanAll(bool verbose);
PinReport inspectPin(uint8_t pin);
uint32_t countTransitions(uint8_t pin);
PinVerdict judge(const PinReport& report);
void printFullTable(const PinReport* reports);
void printLiveLine(const PinReport* reports, uint8_t connectedCount);
bool confirmWithUart(uint8_t rxPin);
const char* verdictText(PinVerdict verdict);
const char* verdictShort(PinVerdict verdict);

void setup() {
  Serial.begin(115200);
  delay(1500);

  Serial.println();
  Serial.println(F("================================================"));
  Serial.println(F("  ld2410_pinscan - สแกนหาขาที่รับสัญญาณจากโมดูล"));
  Serial.println(F("================================================"));
  Serial.println();
  Serial.println(F("โมดูลของคุณเช็คผ่านบลูทูธแล้วปกติ แปลว่า"));
  Serial.println(F("  - โมดูลมีไฟเลี้ยงพอ ไม่เสีย เรดาร์ทำงานอยู่"));
  Serial.println(F("  - ปัญหาเหลือแค่ 'สายเส้นที่ส่งข้อมูลออกมา' เท่านั้น"));
  Serial.println();
  Serial.println(F("*** ต้องต่อ GND ของโมดูลกับ GND ของ ESP32 ให้ถึงกัน ***"));
  Serial.println(F("ถ้าไม่ต่อ GND ร่วม สแกนยังไงก็ไม่เจอ"));
  Serial.println();
  Serial.println(F("เอาสายจากแพด TX ของโมดูล จิ้มขา ESP32 ทีละขา"));
  Serial.println(F("แล้วดูผลสด ๆ ด้านล่าง สแกนซ้ำทุก 2 วินาที"));
  Serial.println();

  scanAll(true);
}

void loop() {
  delay(2000);
  scanAll(false);
}

void scanAll(bool verbose) {
  PinReport reports[PIN_COUNT];
  int16_t uartPin = -1;
  uint8_t connectedCount = 0;

  for (size_t i = 0; i < PIN_COUNT; i++) {
    reports[i] = inspectPin(PINS[i]);
    if (reports[i].verdict == VERDICT_UART && uartPin < 0) {
      uartPin = (int16_t)reports[i].pin;
    }
    if (reports[i].verdict != VERDICT_FREE) connectedCount++;
  }

  if (verbose) {
    printFullTable(reports);
  } else {
    printLiveLine(reports, connectedCount);
  }

  if (uartPin >= 0) {
    Serial.println();
    Serial.println(F("  ================================"));
    Serial.printf("   เจอแล้ว! สัญญาณ UART อยู่ที่ GPIO%u\n", (unsigned)uartPin);
    Serial.println(F("  ================================"));
    confirmWithUart((uint8_t)uartPin);
  }
}

/*
 * ตรวจขาหนึ่งขา 3 ขั้น
 *
 * 1. เปิด pull-up ภายในแล้วอ่าน
 * 2. เปิด pull-down ภายในแล้วอ่าน
 *    - ถ้าค่าเปลี่ยนตาม pull ที่เปิด = ไม่มีอะไรต่ออยู่ ขาว่างและปกติดี
 *    - ถ้าค่าไม่เปลี่ยนตาม = มีอะไรบางอย่างขับไฟอยู่ภายนอก
 * 3. นับจำนวนครั้งที่สถานะพลิกใน 250ms
 *    - สาย UART ที่มีข้อมูลวิ่ง จะพลิกหลักร้อยครั้ง
 *    - สายที่ต่อแต่เงียบ จะไม่พลิกเลย
 *    - คริสตัลจะพลิกหลักหมื่น มากจนรู้ได้ว่าไม่ใช่ข้อมูล
 */
PinReport inspectPin(uint8_t pin) {
  PinReport report;
  report.pin = pin;

  pinMode(pin, INPUT_PULLUP);
  delayMicroseconds(600);
  report.pullUpRead = digitalRead(pin) == HIGH;

  pinMode(pin, INPUT_PULLDOWN);
  delayMicroseconds(600);
  report.pullDownRead = digitalRead(pin) == HIGH;

  report.transitions = countTransitions(pin);
  report.verdict = judge(report);
  return report;
}

uint32_t countTransitions(uint8_t pin) {
  uint32_t transitions = 0;
  int last = digitalRead(pin);
  const uint32_t started = millis();

  while ((millis() - started) < SAMPLE_MS) {
    const int now = digitalRead(pin);
    if (now != last) {
      transitions++;
      last = now;
    }
  }
  return transitions;
}

PinVerdict judge(const PinReport& report) {
  // พลิกถี่เกินกว่าที่ข้อมูลจริงจะทำได้ = นาฬิกา/คริสตัล ไม่ใช่ UART
  if (report.transitions > ACTIVITY_MAX) {
    return VERDICT_UNSTABLE;
  }

  // พลิกในช่วงที่สมเหตุสมผลกับเฟรม LD2410
  if (report.transitions >= ACTIVITY_MIN) {
    return VERDICT_UART;
  }

  // ค่าตามที่ pull ภายในสั่ง = ไม่มีอะไรต่ออยู่
  if (report.pullUpRead && !report.pullDownRead) return VERDICT_FREE;

  // ฝืน pull-down ขึ้นมาเป็น HIGH ได้ = มีอะไรขับไฟเข้ามา
  if (report.pullDownRead) return VERDICT_HIGH;

  // ฝืน pull-up ลงมาเป็น LOW ได้ = ถูกดึงลง GND
  return VERDICT_LOW;
}

void printFullTable(const PinReport* reports) {
  Serial.println(F("--- ผลสแกนเต็มรูปแบบ ---"));
  Serial.println();
  Serial.println(F("GPIO   pull-up  pull-down  พลิก/250ms   ผล"));
  Serial.println(F("-----  -------  ---------  ----------   ------------------"));

  for (size_t i = 0; i < PIN_COUNT; i++) {
    const PinReport& r = reports[i];
    Serial.printf("%-5u  %-7s  %-9s  %-10lu   %s\n",
                  (unsigned)r.pin,
                  r.pullUpRead ? "HIGH" : "LOW",
                  r.pullDownRead ? "HIGH" : "LOW",
                  (unsigned long)r.transitions,
                  verdictText(r.verdict));
  }

  Serial.println();
  Serial.println(F("อ่านผลยังไง"));
  Serial.println(F("  ว่าง            = ไม่มีอะไรต่ออยู่ ขานี้ปกติดี ใช้ได้"));
  Serial.println(F("  <<< UART        = ขาที่รับข้อมูลอยู่จริง เอาขานี้ไปใช้"));
  Serial.println(F("  ต่ออยู่ HIGH ค้าง = มีสายต่อ แต่โมดูลไม่ได้ส่งอะไรออกมา"));
  Serial.println(F("                    แปลว่าจิ้มผิดแพด ลองย้ายไปแพดอื่น"));
  Serial.println(F("  ต่ออยู่ LOW ค้าง  = ขานี้ถูกดึงลง GND อยู่ อย่าใช้"));
  Serial.println(F("  แกว่งเร็ว        = พลิกเป็นหมื่นครั้ง เร็วเกินกว่าจะเป็นข้อมูล"));
  Serial.println(F("                    บอร์ดน่าจะติดคริสตัล 32.768kHz ที่ขานี้"));
  Serial.println(F("                    (มักเป็น GPIO32/33) ให้เลี่ยงไปใช้ขาอื่น"));
  Serial.println();
  Serial.println(F("--- จากนี้จะสแกนซ้ำทุก 2 วินาที ขยับสายได้เลย ---"));
  Serial.println();
}

/*
 * โหมดสด พิมพ์เฉพาะขาที่มีอะไรผิดจาก "ว่าง" จะได้อ่านง่ายตอนขยับสาย
 */
void printLiveLine(const PinReport* reports, uint8_t connectedCount) {
  if (connectedCount == 0) {
    Serial.println(F("[สแกน] ทุกขาว่างหมด ยังไม่เจอสายที่ต่ออยู่"));
    Serial.println(F("        ตรวจว่า GND ต่อร่วมกันแล้วหรือยัง"));
    return;
  }

  Serial.print(F("[สแกน] "));
  for (size_t i = 0; i < PIN_COUNT; i++) {
    const PinReport& r = reports[i];
    if (r.verdict == VERDICT_FREE) continue;
    Serial.printf("GPIO%u=%s(%lu)  ",
                  (unsigned)r.pin,
                  verdictShort(r.verdict),
                  (unsigned long)r.transitions);
  }
  Serial.println();
}

/*
 * ยืนยันอีกชั้นด้วย UART จริง ไล่ baud ที่ LD2410 ใช้กัน
 * เพื่อให้ได้ค่าที่เอาไปใส่สเก็ตช์หลักได้เลย
 *
 * คืน true เมื่อจับหัวเฟรมของ LD2410 ได้
 */
bool confirmWithUart(uint8_t rxPin) {
  const uint32_t bauds[] = {256000, 115200, 57600};
  HardwareSerial probe(1);

  for (size_t i = 0; i < 3; i++) {
    probe.begin(bauds[i], SERIAL_8N1, rxPin, -1);
    delay(60);
    while (probe.available()) probe.read();

    uint32_t total = 0;
    bool sawFrame = false;
    uint8_t window[4] = {0, 0, 0, 0};

    const uint32_t started = millis();
    while ((millis() - started) < 800) {
      while (probe.available()) {
        const uint8_t value = (uint8_t)probe.read();
        total++;
        window[0] = window[1];
        window[1] = window[2];
        window[2] = window[3];
        window[3] = value;
        // F4 F3 F2 F1 = เฟรมข้อมูลปกติ, FD FC FB FA = เฟรมตอบคำสั่ง
        const bool dataHeader = window[0] == 0xF4 && window[1] == 0xF3 &&
                                window[2] == 0xF2 && window[3] == 0xF1;
        const bool ackHeader  = window[0] == 0xFD && window[1] == 0xFC &&
                                window[2] == 0xFB && window[3] == 0xFA;
        if (dataHeader || ackHeader) {
          sawFrame = true;
        }
      }
    }
    probe.end();

    Serial.printf("   baud %-7lu -> %lu ไบต์%s\n",
                  (unsigned long)bauds[i],
                  (unsigned long)total,
                  sawFrame ? "  << หัวเฟรม LD2410 ถูกต้อง" : "");

    if (sawFrame) {
      Serial.println();
      Serial.println(F("   เอาค่านี้ไปใส่ rmutt_esp32_occupancy.ino"));
      Serial.printf("     constexpr uint8_t  RADAR_RX_PIN = %u;\n", (unsigned)rxPin);
      Serial.println(F("     constexpr uint8_t  RADAR_TX_PIN = <ขาว่างขาไหนก็ได้>;"));
      Serial.printf("     constexpr uint32_t RADAR_BAUD   = %lu;\n",
                    (unsigned long)bauds[i]);
      Serial.println();
      Serial.println(F("   หมายเหตุ: ถ้าจะแค่อ่านค่ามีคน/ไม่มีคน ต่อสาย TX"));
      Serial.println(F("   ของโมดูลเข้า RADAR_RX_PIN เส้นเดียวก็พอ"));
      Serial.println(F("   สาย RX ของโมดูลใช้ตอนสั่งเปิด Engineering mode"));
      Serial.println();
      return true;
    }
  }

  Serial.println(F("   มีสัญญาณแต่ยังจับเฟรมไม่ได้"));
  Serial.println(F("   ถ้าได้ไบต์มาแต่หัวเฟรมไม่ตรง แปลว่า baud ไม่ใช่ 3 ค่านี้"));
  Serial.println(F("   ถ้าได้ 0 ไบต์ทุก baud ให้ขยับสายให้แน่นแล้วรอรอบถัดไป"));
  Serial.println();
  return false;
}

const char* verdictText(PinVerdict verdict) {
  switch (verdict) {
    case VERDICT_FREE:     return "ว่าง";
    case VERDICT_UART:     return "<<< UART เจอสัญญาณ";
    case VERDICT_HIGH:     return "ต่ออยู่ HIGH ค้าง";
    case VERDICT_LOW:      return "ต่ออยู่ LOW ค้าง";
    case VERDICT_UNSTABLE: return "แกว่งเร็ว ไม่ใช่ข้อมูล";
  }
  return "?";
}

const char* verdictShort(PinVerdict verdict) {
  switch (verdict) {
    case VERDICT_FREE:     return "ว่าง";
    case VERDICT_UART:     return "UART";
    case VERDICT_HIGH:     return "HIGH";
    case VERDICT_LOW:      return "LOW";
    case VERDICT_UNSTABLE: return "แกว่ง";
  }
  return "?";
}
