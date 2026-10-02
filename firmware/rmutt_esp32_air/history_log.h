// คลังเก็บข้อมูลไฟฟ้าตอนเน็ตหลุด (offline history)
//
// ตอนบอร์ดต่อ MQTT ไม่ได้ ค่าไฟที่วัดได้จะถูกสรุปทุก 5 นาทีแล้วเขียนลง flash
// พอต่อได้อีกครั้ง บอร์ดจะทยอยส่งทีละชุดเล็ก ๆ รอให้ Backend ตอบว่าบันทึกแล้ว
// จึงลบข้อมูลชุดนั้นทิ้ง ข้อมูลอยู่ใน flash จึงไม่หายแม้บอร์ดรีบูตหรือไฟดับ
// และยังส่งได้ตามปกติแม้เปลี่ยน Wi-Fi ใหม่ผ่านบลูทูธ
//
// รูปแบบการเก็บ: ring buffer บนพาร์ติชัน "rmuttlog" (64 KB = 16 sector)
// หนึ่งรายการ 32 ไบต์ -> 2,048 รายการ = ประมาณ 7 วันที่ 5 นาทีต่อรายการ
// ถ้าเต็มจะทับรายการที่เก่าที่สุดทีละ sector (128 รายการ)
//
// ไฟล์นี้ไม่ผูกกับ ESP32 โดยตรง ตัวเก็บข้อมูลส่งเข้ามาเป็นพารามิเตอร์
// จึงทดสอบบนคอมพิวเตอร์ได้ (firmware/tests/history_log_test.cpp)
#pragma once

#include <stddef.h>
#include <stdint.h>
#include <string.h>

constexpr uint8_t HISTORY_MAGIC = 0xA5;
constexpr uint32_t HISTORY_INTERVAL_SECONDS = 300;
constexpr size_t HISTORY_SECTOR_BYTES = 4096;

// ข้อมูลหนึ่งช่วง 5 นาที ค่าที่เป็นทศนิยมเก็บเป็นจำนวนเต็มคูณสเกล
#pragma pack(push, 1)
struct HistoryRecord {
  uint32_t ts;           // วินาที epoch ของ "ปลาย" ช่วง (ช่วงคือ ts-300 ถึง ts)
  float energyKwh;       // เลขมิเตอร์สะสมของ PZEM ตอนปลายช่วง
  uint16_t voltageAvg10; // โวลต์ x10
  uint16_t voltageMin10;
  uint16_t voltageMax10;
  uint16_t currentAvg1000;  // แอมป์ x1000
  uint16_t currentMax1000;
  uint16_t powerAvg10;   // วัตต์ x10 (สูงสุด 6,553.5 W)
  uint16_t powerMin10;
  uint16_t powerMax10;
  uint8_t powerFactor100;   // x100
  uint8_t frequencyOffset10;  // (Hz - 40) x10
  uint16_t runtimeSeconds;  // เวลาที่แอร์ทำงานในช่วงนี้
  uint8_t samples;       // จำนวนครั้งที่อ่าน PZEM ได้ในช่วงนี้
  uint8_t flags;         // bit0 = แอร์ทำงานตอนปลายช่วง
  uint8_t magic;
  uint8_t checksum;
};
#pragma pack(pop)

static_assert(sizeof(HistoryRecord) == 32, "HistoryRecord must be 32 bytes");

constexpr size_t HISTORY_RECORDS_PER_SECTOR =
    HISTORY_SECTOR_BYTES / sizeof(HistoryRecord);

inline uint8_t historyChecksum(const HistoryRecord &record) {
  const uint8_t *bytes = reinterpret_cast<const uint8_t *>(&record);
  uint8_t sum = 0x5A;
  for (size_t index = 0; index < sizeof(HistoryRecord) - 1; index++) {
    sum = static_cast<uint8_t>((sum << 1) | (sum >> 7)) ^ bytes[index];
  }
  return sum;
}

inline bool historyRecordValid(const HistoryRecord &record) {
  return record.magic == HISTORY_MAGIC &&
         record.ts != 0xFFFFFFFFUL &&
         record.ts != 0 &&
         record.checksum == historyChecksum(record);
}

inline bool historyRecordBlank(const HistoryRecord &record) {
  const uint8_t *bytes = reinterpret_cast<const uint8_t *>(&record);
  for (size_t index = 0; index < sizeof(HistoryRecord); index++) {
    if (bytes[index] != 0xFF) return false;
  }
  return true;
}

// Storage ต้องมี: size_t size(); bool read(size_t, void*, size_t);
// bool write(size_t, const void*, size_t); bool eraseSector(size_t offset);
template <typename Storage>
class HistoryLog {
 public:
  explicit HistoryLog(Storage &storage) : storage_(storage) {}

  // อ่านทั้งพาร์ติชันหนึ่งรอบตอนบูต หาตำแหน่งเขียนต่อและนับรายการที่ยังไม่ได้ส่ง
  bool begin(uint32_t ackedTs) {
    ackedTs_ = ackedTs;
    const size_t bytes = storage_.size();
    sectors_ = bytes / HISTORY_SECTOR_BYTES;
    slots_ = sectors_ * HISTORY_RECORDS_PER_SECTOR;
    if (slots_ == 0) {
      ready_ = false;
      return false;
    }

    uint32_t newestTs = 0;
    size_t newestSlot = 0;
    bool found = false;
    pending_ = 0;
    forEachSlot([&](size_t slot, const HistoryRecord &record) {
      if (!historyRecordValid(record)) return;
      if (record.ts > ackedTs_) pending_++;
      if (!found || record.ts > newestTs) {
        newestTs = record.ts;
        newestSlot = slot;
        found = true;
      }
    });
    newestTs_ = found ? newestTs : 0;
    writeSlot_ = found ? (newestSlot + 1) % slots_ : 0;
    ready_ = true;
    return true;
  }

  bool ready() const { return ready_; }
  uint32_t pending() const { return pending_; }
  uint32_t ackedTs() const { return ackedTs_; }
  uint32_t lostRecords() const { return lost_; }
  size_t capacity() const { return slots_; }

  bool append(HistoryRecord record) {
    if (!ready_) return false;
    // เวลาถอยหลัง (เช่น NTP แก้เวลา) ไม่เก็บ เพราะจะส่งผิดลำดับ
    if (record.ts <= newestTs_ || record.ts <= ackedTs_) return false;
    record.magic = HISTORY_MAGIC;
    record.checksum = historyChecksum(record);

    size_t slot = writeSlot_;
    if (slot % HISTORY_RECORDS_PER_SECTOR == 0) {
      if (!prepareSector(slot / HISTORY_RECORDS_PER_SECTOR)) return false;
    } else {
      HistoryRecord existing;
      if (!readSlot(slot, existing)) return false;
      if (!historyRecordBlank(existing)) {
        // ช่องถัดไปไม่ว่าง (เช่นมีขยะจากพาร์ติชันเดิม) ข้ามไปต้น sector ถัดไป
        const size_t nextSector =
            (slot / HISTORY_RECORDS_PER_SECTOR + 1) % sectors_;
        slot = nextSector * HISTORY_RECORDS_PER_SECTOR;
        if (!prepareSector(nextSector)) return false;
      }
    }

    if (!storage_.write(slot * sizeof(HistoryRecord), &record,
                        sizeof(HistoryRecord))) {
      return false;
    }
    writeSlot_ = (slot + 1) % slots_;
    newestTs_ = record.ts;
    pending_++;
    return true;
  }

  // รายการที่ยังไม่ได้ส่ง เรียงจากเก่าไปใหม่ ไม่เกิน max รายการ
  size_t nextBatch(HistoryRecord *out, size_t max) {
    if (!ready_ || max == 0) return 0;
    size_t count = 0;
    forEachSlot([&](size_t, const HistoryRecord &record) {
      if (!historyRecordValid(record) || record.ts <= ackedTs_) return;
      if (count < max) {
        out[count++] = record;
      } else if (record.ts < out[count - 1].ts) {
        out[count - 1] = record;
      } else {
        return;
      }
      // insertion sort ตัวล่าสุดเข้าที่
      for (size_t index = count - 1;
           index > 0 && out[index].ts < out[index - 1].ts; index--) {
        const HistoryRecord swap = out[index];
        out[index] = out[index - 1];
        out[index - 1] = swap;
      }
    });
    return count;
  }

  // Backend ยืนยันว่าบันทึกถึงเวลา upToTs แล้ว: ลบ sector ที่ส่งครบทั้งหมด
  // ถ้าไม่เหลือรายการค้างเลย ทุก sector ที่มีข้อมูลจะถูกลบจนว่าง
  bool acknowledge(uint32_t upToTs) {
    if (!ready_) return false;
    if (upToTs > ackedTs_) ackedTs_ = upToTs;

    pending_ = 0;
    for (size_t sector = 0; sector < sectors_; sector++) {
      bool hasData = false;
      bool allAcked = true;
      if (!readSector(sector)) return false;
      for (size_t index = 0; index < HISTORY_RECORDS_PER_SECTOR; index++) {
        const HistoryRecord &record = buffer_[index];
        if (historyRecordBlank(record)) continue;
        hasData = true;
        if (historyRecordValid(record) && record.ts > ackedTs_) {
          allAcked = false;
          pending_++;
        }
      }
      if (hasData && allAcked) {
        if (!storage_.eraseSector(sector * HISTORY_SECTOR_BYTES)) return false;
        erasedSectors_++;
      }
    }
    return true;
  }

  uint32_t erasedSectors() const { return erasedSectors_; }

 private:
  template <typename Fn>
  void forEachSlot(Fn fn) {
    for (size_t sector = 0; sector < sectors_; sector++) {
      if (!readSector(sector)) continue;
      for (size_t index = 0; index < HISTORY_RECORDS_PER_SECTOR; index++) {
        fn(sector * HISTORY_RECORDS_PER_SECTOR + index, buffer_[index]);
      }
    }
  }

  bool readSector(size_t sector) {
    return storage_.read(sector * HISTORY_SECTOR_BYTES, buffer_,
                         HISTORY_SECTOR_BYTES);
  }

  bool readSlot(size_t slot, HistoryRecord &record) {
    return storage_.read(slot * sizeof(HistoryRecord), &record,
                         sizeof(HistoryRecord));
  }

  // ลบ sector ก่อนเขียนรายการแรก ถ้ามีรายการที่ยังไม่ได้ส่งอยู่ ถือว่าสูญหาย
  bool prepareSector(size_t sector) {
    if (!readSector(sector)) return false;
    bool dirty = false;
    for (size_t index = 0; index < HISTORY_RECORDS_PER_SECTOR; index++) {
      const HistoryRecord &record = buffer_[index];
      if (!historyRecordBlank(record)) dirty = true;
      if (historyRecordValid(record) && record.ts > ackedTs_) {
        lost_++;
        if (pending_ > 0) pending_--;
      }
    }
    if (!dirty) return true;
    return storage_.eraseSector(sector * HISTORY_SECTOR_BYTES);
  }

  Storage &storage_;
  HistoryRecord buffer_[HISTORY_RECORDS_PER_SECTOR];
  size_t sectors_ = 0;
  size_t slots_ = 0;
  size_t writeSlot_ = 0;
  uint32_t pending_ = 0;
  uint32_t ackedTs_ = 0;
  uint32_t newestTs_ = 0;
  uint32_t lost_ = 0;
  uint32_t erasedSectors_ = 0;
  bool ready_ = false;
};
