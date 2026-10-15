// อัปเดตเฟิร์มแวร์ผ่าน Wi-Fi (OTA) แบบดึงไฟล์จากเซิร์ฟเวอร์ของเราเอง
//
// ขั้นตอน: แอดมินกดอัปเดตในเว็บ -> Backend ส่งคำสั่ง {"action":"ota","url":...}
// ทาง MQTT -> บอร์ดดาวน์โหลดไฟล์ .bin ผ่าน HTTPS แล้วรีบูตเข้าเฟิร์มแวร์ใหม่
//
// กันของปลอมสามชั้น
//   1. คำสั่งมาทาง MQTT topic command ซึ่งมีแต่ Backend ที่ส่งได้
//      (บอร์ดตัวอื่นส่งไม่ได้เพราะ ACL ของ Dynamic Security)
//   2. URL ต้องขึ้นต้นด้วย https://<MQTT host เดิมของบอร์ด>/firmware/
//      ชี้ไปเซิร์ฟเวอร์อื่นไม่ได้
//   3. ตรวจใบรับรอง HTTPS กับใบรากใน letsencrypt_ca.h เหมือนตอนต่อ MQTTS
// ถ้าไฟล์เสียระหว่างดาวน์โหลด บอร์ดจะไม่สลับไปใช้ และทำงานด้วยเฟิร์มแวร์เดิมต่อ
//
// ต้องใช้ตารางพาร์ติชันที่มีช่องแอปสองช่อง (partitions.csv ในโฟลเดอร์นี้)
// ไฟล์ .bin สำหรับอัปโหลดขึ้นเซิร์ฟเวอร์ได้จาก Arduino IDE:
//   Sketch > Export Compiled Binary  (ใช้ไฟล์ <ชื่อสเก็ตช์>.ino.bin)
#pragma once

#include <Arduino.h>
#include <HTTPUpdate.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <esp_ota_ops.h>

constexpr size_t OTA_MAX_URL_LENGTH = 300;

inline bool otaUrlAllowed(const String &url, const String &host) {
  if (host.isEmpty() || url.length() > OTA_MAX_URL_LENGTH) return false;
  const String prefix = "https://" + host + "/firmware/";
  if (!url.startsWith(prefix) || !url.endsWith(".bin")) return false;
  if (url.indexOf("..") >= 0) return false;
  for (size_t index = prefix.length(); index < url.length(); index++) {
    const char c = url.charAt(index);
    const bool ok = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') ||
                    (c >= '0' && c <= '9') || c == '.' || c == '_' ||
                    c == '-';
    if (!ok) return false;
  }
  return true;
}

inline bool otaPartitionAvailable() {
  return esp_ota_get_next_update_partition(nullptr) != nullptr;
}

// ล้มเหลวเพราะเครือข่าย (หลุดกลางทาง, อ่านไม่ทัน, ต่อเซิร์ฟเวอร์ไม่ได้) ลองใหม่ได้
// ส่วนไฟล์ไม่มี/ผิดชนิด/ที่ไม่พอ ลองกี่ครั้งก็ไม่ผ่าน ไม่ต้องลองซ้ำ
//   6         = UPDATE_ERROR_STREAM ("Stream Read Timeout") อ่านข้อมูลไม่ได้ 30 วินาที
//   -1 ถึง -11 = HTTPClient ต่อไม่ได้ / การเชื่อมต่อหลุด / อ่านหมดเวลา
inline bool otaErrorIsTransient(int code) {
  return code == 6 || (code <= -1 && code >= -11);
}

constexpr uint8_t OTA_MAX_ATTEMPTS = 3;
constexpr uint32_t OTA_RETRY_DELAY_MS = 5000;
// เวลารอข้อมูลแต่ละช่วง (ค่าเดิมของไลบรารี 8 วินาที) เผื่อเน็ตผ่าน Tailscale สะดุด
constexpr int OTA_HTTP_TIMEOUT_MS = 20000;

// คืนข้อความว่างเมื่อสำเร็จ (ผู้เรียกต้องรีบูตเอง) หรือข้อความบอกสาเหตุที่ล้มเหลว
// ถ้าล้มเหลวเพราะเครือข่าย จะดาวน์โหลดใหม่ตั้งแต่ต้องสูงสุด OTA_MAX_ATTEMPTS ครั้ง
// (ไฟล์ที่ดาวน์โหลดไม่ครบจะไม่ถูกใช้ บอร์ดยังรันเฟิร์มแวร์เดิมจนกว่าจะครบ)
inline String runHttpsOta(
    const String &url,
    const char *caCert,
    const char *currentVersion) {
  if (!otaPartitionAvailable()) {
    return "no_ota_partition: flash partitions.csv via USB once";
  }
  String lastError;
  for (uint8_t attempt = 1; attempt <= OTA_MAX_ATTEMPTS; attempt++) {
    if (WiFi.status() != WL_CONNECTED) {
      lastError = "wifi_lost";
      break;
    }
    WiFiClientSecure client;
    client.setCACert(caCert);
    HTTPUpdate updater(OTA_HTTP_TIMEOUT_MS);
    updater.rebootOnUpdate(false);
    updater.setFollowRedirects(HTTPC_DISABLE_FOLLOW_REDIRECTS);
    Serial.printf("OTA: attempt %u/%u\n", attempt, OTA_MAX_ATTEMPTS);
    const t_httpUpdate_return result =
        updater.update(client, url, currentVersion);
    if (result == HTTP_UPDATE_OK) return "";
    if (result == HTTP_UPDATE_NO_UPDATES) return "no_updates";

    const int code = updater.getLastError();
    lastError = String("failed(") + code + "): " +
                updater.getLastErrorString();
    Serial.printf("OTA: attempt %u failed: %s\n", attempt, lastError.c_str());
    if (!otaErrorIsTransient(code)) break;
    if (attempt < OTA_MAX_ATTEMPTS) {
      client.stop();
      delay(OTA_RETRY_DELAY_MS);
    } else {
      lastError += " (x" + String(OTA_MAX_ATTEMPTS) + ")";
    }
  }
  return lastError;
}
