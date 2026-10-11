// =====================================================================
//  wired_bus.h  -  ขับสายแอร์ Daikin SLM8 ใน task แยก (ใช้ DaikinSLM8.h)
//
//  ทำไมต้องแยก task: สายแอร์ต้องได้เฟรมทุก 1 วินาทีตลอดเวลา แต่ loop() หลักของเฟิร์มแวร์
//  มีช่วงที่ค้างนาน (ต่อ Wi-Fi 20 วิ, ต่อ MQTT/TLS, OTA, อ่าน PZEM)
//  task นี้รันบน core 1 priority สูงกว่า loop() จึงส่งเฟรมตรงเวลาเสมอ
// =====================================================================
#pragma once
#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <freertos/task.h>
#include "DaikinSLM8.h"

class WiredBus {
 public:
  struct Status {
    bool linkOk = false;          // แอร์ตอบกลับทางสายสถานะภายใน 3 วินาที
    bool compressor = false;      // บิตคอมเพรสเซอร์จากแอร์
    int unitRoomC = 0;            // อุณหภูมิที่แอร์รายงาน
    uint32_t framesSent = 0;
    uint32_t echoOk = 0, echoBad = 0;
    uint8_t lastSent[8] = {0};
    uint8_t lastUnit[8] = {0};
  };

  // initial = ค่าที่จะส่งตั้งแต่เฟรมแรก (โหลดจาก NVS ก่อน แอร์จะได้ไม่ดับตอนบอร์ดรีบูต)
  void begin(int rxPin, int txPin, bool txInvert, int echoPin, const slm8::Settings& initial) {
    rxPin_ = rxPin; txPin_ = txPin; txInvert_ = txInvert; echoPin_ = echoPin;
    mutex_ = xSemaphoreCreateMutex();
    ctl_.apply(initial);
    // core 1 (เดียวกับ loop) priority 3 > loop (1): ระหว่างส่งเฟรม 85 ms loop จะรอ
    xTaskCreatePinnedToCore(taskFn, "slm8bus", 4096, this, 3, nullptr, 1);
  }

  void apply(const slm8::Settings& s) {
    lock();
    ctl_.apply(s);
    unlock();
  }

  void setRoomTemp(float c) {
    if (isnan(c)) return;
    lock();
    ctl_.setRoomTemp(c);
    unlock();
  }

  Status status() {
    Status st;
    lock();
    st.linkOk = ctl_.unitAlive();
    st.compressor = ctl_.compressorRunning();
    st.unitRoomC = ctl_.unitRoomC();
    st.framesSent = ctl_.sentCount();
    st.echoOk = echoOk_;
    st.echoBad = echoBad_;
    memcpy(st.lastSent, ctl_.lastSent(), 8);
    memcpy(st.lastUnit, ctl_.lastUnit(), 8);
    unlock();
    return st;
  }

  // ช่วงหลังส่งเฟรมเสร็จ ~0.3 วินาที: สายว่าง เหมาะจะอ่าน DHT11 (ซึ่งปิด interrupt ชั่วครู่)
  bool quietWindow() {
    uint32_t n;
    lock(); n = ctl_.sentCount(); unlock();
    if (n != seenSent_) { seenSent_ = n; quietUntil_ = millis() + 300; }
    return static_cast<int32_t>(quietUntil_ - millis()) > 0;
  }

 private:
  slm8::Controller ctl_;
  slm8::Rx echo_;
  SemaphoreHandle_t mutex_ = nullptr;
  int rxPin_ = 35, txPin_ = 33, echoPin_ = 34;
  bool txInvert_ = false;
  uint32_t echoOk_ = 0, echoBad_ = 0;   // อ่าน/เขียนภายใต้ mutex
  uint32_t seenSent_ = 0, quietUntil_ = 0;

  void lock()   { if (mutex_) xSemaphoreTake(mutex_, portMAX_DELAY); }
  void unlock() { if (mutex_) xSemaphoreGive(mutex_); }

  static void taskFn(void* arg) {
    WiredBus* self = static_cast<WiredBus*>(arg);
    // ติด interrupt ของขารับใน task นี้ (core 1)
    self->lock();
    self->ctl_.begin(slm8::Controller::REPLACE_PANEL, -1, self->rxPin_, self->txPin_, self->txInvert_, true);
    if (self->echoPin_ >= 0) self->echo_.begin(self->echoPin_);
    self->unlock();
    for (;;) {
      self->lock();
      self->ctl_.loop();
      uint8_t e[8];
      if (self->echoPin_ >= 0 && self->echo_.poll(e)) {
        if (memcmp(e, self->ctl_.lastSent(), 8) == 0) self->echoOk_++; else self->echoBad_++;
      }
      self->unlock();
      vTaskDelay(pdMS_TO_TICKS(5));
    }
  }
};
