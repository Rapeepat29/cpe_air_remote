#include <nvs_flash.h>
#include <WiFi.h>


void setup() {
  Serial.begin(115200);
  delay(1000); // รอให้ Serial Monitor พร้อมทำงาน
  
  Serial.println("\n--- Starting Factory Reset ---");

  // 1. สั่งลบข้อมูลทั้งหมดใน NVS
  esp_err_t err = nvs_flash_erase();
  if (err == ESP_OK) {
    Serial.println("NVS Erased Successfully! (Cleared Preferences/Saved Data)");
  } else {
    Serial.printf("Error erasing NVS: %s\n", esp_err_to_name(err));
  }

  // 2. เคลียร์ค่า Wi-Fi ที่อาจฝังค้างอยู่
  WiFi.disconnect(true, true);
  Serial.println("WiFi credentials cleared!");

  // 3. เริ่มต้นการทำงานของ NVS ใหม่เพื่อให้บอร์ดพร้อมรับข้อมูลใหม่ในอนาคต
  err = nvs_flash_init();
  if (err == ESP_OK) {
    Serial.println("NVS Initialized Successfully.");
  }

  Serial.println("--- Reset Complete! ---");
  Serial.println("You can now upload your new sketch.");
}

void loop() {
  // ไม่ต้องทำอะไรในลูป
}