// ทดสอบ history_log.h บนคอมพิวเตอร์ (ไม่ต้องใช้บอร์ด)
//   g++ -std=c++17 -I../rmutt_esp32_air history_log_test.cpp -o t && ./t
// จำลอง flash แบบ NOR: เขียนได้เฉพาะเปลี่ยนบิต 1 -> 0 ต้อง erase ก่อนจึงกลับเป็น 1
#include <cassert>
#include <cstdio>
#include <cstdlib>
#include <vector>

#include "history_log.h"

struct FakeFlash {
  std::vector<uint8_t> bytes;
  int erases = 0;
  explicit FakeFlash(size_t size, uint8_t fill = 0xFF) : bytes(size, fill) {}
  size_t size() { return bytes.size(); }
  bool read(size_t offset, void *out, size_t len) {
    if (offset + len > bytes.size()) return false;
    memcpy(out, &bytes[offset], len);
    return true;
  }
  bool write(size_t offset, const void *data, size_t len) {
    if (offset + len > bytes.size()) return false;
    const uint8_t *in = static_cast<const uint8_t *>(data);
    for (size_t i = 0; i < len; i++) bytes[offset + i] &= in[i];
    return true;
  }
  bool eraseSector(size_t offset) {
    if (offset % HISTORY_SECTOR_BYTES) return false;
    for (size_t i = 0; i < HISTORY_SECTOR_BYTES; i++) bytes[offset + i] = 0xFF;
    erases++;
    return true;
  }
  bool allBlank() {
    for (uint8_t b : bytes) if (b != 0xFF) return false;
    return true;
  }
};

static HistoryRecord makeRecord(uint32_t ts, float kwh) {
  HistoryRecord r;
  memset(&r, 0, sizeof(r));
  r.ts = ts;
  r.energyKwh = kwh;
  r.voltageAvg10 = 2300;
  r.powerAvg10 = 7000;
  r.runtimeSeconds = 300;
  r.samples = 150;
  r.flags = 1;
  return r;
}

static int passed = 0;
#define CHECK(cond) do { if (!(cond)) { printf("FAIL line %d: %s\n", __LINE__, #cond); exit(1); } passed++; } while (0)

int main() {
  const uint32_t base = 1790000000;

  {  // เก็บ ส่งตามลำดับ ยืนยันแล้วลบทิ้งหมด
    FakeFlash flash(64 * 1024);
    HistoryLog<FakeFlash> log(flash);
    CHECK(log.begin(0));
    CHECK(log.capacity() == 2048);
    for (int i = 1; i <= 5; i++) CHECK(log.append(makeRecord(base + i * 300, i)));
    CHECK(log.pending() == 5);
    HistoryRecord batch[3];
    CHECK(log.nextBatch(batch, 3) == 3);
    CHECK(batch[0].ts == base + 300 && batch[2].ts == base + 900);
    CHECK(log.acknowledge(batch[2].ts));
    CHECK(log.pending() == 2);
    CHECK(!flash.allBlank());  // sector ยังมีรายการค้าง ห้ามลบ
    CHECK(log.nextBatch(batch, 3) == 2 && batch[0].ts == base + 1200);
    CHECK(log.acknowledge(batch[1].ts));
    CHECK(log.pending() == 0);
    CHECK(flash.allBlank());   // ส่งครบแล้ว ข้อมูลถูกลบทิ้งหมด
    CHECK(log.nextBatch(batch, 3) == 0);
    // เขียนต่อได้หลังลบ
    CHECK(log.append(makeRecord(base + 3000, 9)));
    CHECK(log.pending() == 1);
  }

  {  // รีบูตกลางทาง ข้อมูลยังอยู่ และเขียนต่อจากตำแหน่งเดิม
    FakeFlash flash(64 * 1024);
    {
      HistoryLog<FakeFlash> log(flash);
      log.begin(0);
      for (int i = 1; i <= 200; i++) log.append(makeRecord(base + i * 300, i));
      HistoryRecord batch[10];
      log.nextBatch(batch, 10);
      log.acknowledge(batch[9].ts);
    }
    HistoryLog<FakeFlash> after(flash);
    CHECK(after.begin(base + 10 * 300));   // ackedTs มาจาก NVS
    CHECK(after.pending() == 190);
    CHECK(after.append(makeRecord(base + 201 * 300, 201)));
    CHECK(after.pending() == 191);
    CHECK(!after.append(makeRecord(base + 150 * 300, 1)));   // เวลาถอยหลังไม่รับ
    HistoryRecord batch[1];
    CHECK(after.nextBatch(batch, 1) == 1 && batch[0].ts == base + 11 * 300);
  }

  {  // เต็มแล้ววนทับ sector ที่เก่าที่สุด
    FakeFlash flash(64 * 1024);
    HistoryLog<FakeFlash> log(flash);
    log.begin(0);
    const int total = 2048 + 10;
    for (int i = 1; i <= total; i++) CHECK(log.append(makeRecord(base + i * 300, i)));
    CHECK(log.lostRecords() == 128);
    CHECK(log.pending() == 2048 - 128 + 10);
    HistoryRecord batch[2];
    CHECK(log.nextBatch(batch, 2) == 2);
    CHECK(batch[0].ts == base + 129 * 300);   // 128 รายการแรกถูกทับ
    // บูตใหม่หลังวนรอบ ต้องหาตำแหน่งเขียนถัดไปถูก
    HistoryLog<FakeFlash> again(flash);
    CHECK(again.begin(0));
    CHECK(again.pending() == 2048 - 128 + 10);
    CHECK(again.append(makeRecord(base + (total + 1) * 300, 0)));
    CHECK(again.nextBatch(batch, 1) == 1 && batch[0].ts == base + 129 * 300);
  }

  {  // พาร์ติชันมีขยะเดิม (เช่นข้อมูล coredump เก่า)
    FakeFlash flash(64 * 1024, 0x00);
    for (size_t i = 0; i < flash.bytes.size(); i++) flash.bytes[i] = (uint8_t)(i * 37 + 11);
    HistoryLog<FakeFlash> log(flash);
    CHECK(log.begin(0));
    CHECK(log.pending() == 0);
    for (int i = 1; i <= 3; i++) CHECK(log.append(makeRecord(base + i * 300, i)));
    HistoryRecord batch[5];
    CHECK(log.nextBatch(batch, 5) == 3);
    CHECK(batch[0].energyKwh == 1.0f && batch[2].ts == base + 900);
  }

  printf("history_log: %d checks passed\n", passed);
  return 0;
}
