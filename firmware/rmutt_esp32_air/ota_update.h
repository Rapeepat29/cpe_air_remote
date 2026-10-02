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

// คืนข้อความว่างเมื่อสำเร็จ (ผู้เรียกต้องรีบูตเอง) หรือข้อความบอกสาเหตุที่ล้มเหลว
inline String runHttpsOta(
    const String &url,
    const char *caCert,
    const char *currentVersion) {
  if (!otaPartitionAvailable()) {
    return "no_ota_partition: flash partitions.csv via USB once";
  }
  WiFiClientSecure client;
  client.setCACert(caCert);
  httpUpdate.rebootOnUpdate(false);
  httpUpdate.setFollowRedirects(HTTPC_DISABLE_FOLLOW_REDIRECTS);
  const t_httpUpdate_return result =
      httpUpdate.update(client, url, currentVersion);
  switch (result) {
    case HTTP_UPDATE_OK:
      return "";
    case HTTP_UPDATE_NO_UPDATES:
      return "no_updates";
    default:
      return String("failed(") + httpUpdate.getLastError() + "): " +
             httpUpdate.getLastErrorString();
  }
}
