/*
 * RMUTT Save Energy - ESP32 Air Conditioner Controller (WIRED / Daikin SLM8)
 *
 * รุ่นสายแอร์: ใช้แทนรีโมตติดผนัง Daikin (SLM8) ที่ถอดออก สั่งแอร์ผ่านสายแอร์แทน IR
 * แอป, Backend, BLE, MQTT, PZEM, ตารางเวลา, OTA และข้อมูลย้อนหลัง ทำงานเหมือนรุ่น IR ทุกอย่าง
 * ต่างกันแค่ช่องทางสั่งแอร์ + ได้สถานะจริงจากแอร์ + อุณหภูมิห้องจาก DHT11
 *
 * One ESP32 controls one air conditioner.
 * - First setup / reconfiguration: Bluetooth Low Energy (BLE)
 * - Normal control: MQTT over Wi-Fi
 * - Wired: Daikin SLM8 controller bus (DaikinSLM8.h + wired_bus.h, own FreeRTOS task)
 * - Room temperature: DHT11 on GPIO4 (sent to the unit like the wall panel sensor)
 * - OLED 1.3" SH1106 I2C (GPIO21 SDA / GPIO22 SCL)
 * - Power meter: PZEM-004T v3/v4 over HardwareSerial
 * - LEDs: measured operation, outside schedule, and Wi-Fi status
 * - Persistent settings: ESP32 Preferences (NVS)
 * - Firmware update over Wi-Fi (HTTPS OTA) on command from the backend
 * - Offline history: 5-minute energy records kept in flash while offline,
 *   uploaded in small acknowledged batches after reconnecting
 *
 * Hold the BOOT button (GPIO0) while resetting to reopen BLE setup mode.
 */

#include <Arduino.h>
#include <ArduinoJson.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <DHT.h>
#include <PZEM004Tv30.h>
#include <Preferences.h>
#include <PubSubClient.h>
#include "wired_bus.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>

#include "letsencrypt_ca.h"
#include "ota_update.h"
#include "history_log.h"
#include "oled_display.h"
#include <esp_partition.h>
#include <math.h>
#include <time.h>

// ---- สายแอร์ (ดูวงจรใน README_WIRED_TH.md) ----
constexpr int BUS_TX_PIN = 33;        // 1N4148: ขาไม่มีแถบ -> สายสั่งงาน, แถบ -> GPIO33
constexpr bool BUS_TX_INVERT = false; // false = ไดโอด, true = ทรานซิสเตอร์ 2N2222
constexpr int BUS_RX_PIN = 35;        // สายสถานะ ผ่าน 100k/200k
constexpr int BUS_ECHO_PIN = 34;      // สายสั่งงาน ผ่าน 100k/200k (-1 = ไม่ใช้)
constexpr int DHT_PIN = 4;            // DHT11 (Keyes KY-015)
constexpr float ROOM_TEMP_OFFSET_C = 0.0F;   // ชดเชยค่า DHT11 หลังเทียบเทอร์โมมิเตอร์
constexpr uint32_t DHT_READ_INTERVAL_MS = 5000;
constexpr uint8_t SETUP_BUTTON_PIN = 0;
constexpr uint8_t PZEM_RX_PIN = 18;
constexpr uint8_t PZEM_TX_PIN = 14;
constexpr uint8_t GREEN_LED_PIN = 25;
constexpr uint8_t RED_LED_PIN = 26;
constexpr uint8_t YELLOW_LED_PIN = 23;
constexpr uint32_t WIFI_TIMEOUT_MS = 20000;
constexpr uint32_t WIFI_PROVISION_TIMEOUT_MS = 15000;
// ระหว่างเปิด BLE เพราะ Wi-Fi ล้ม ให้ลองต่อ Wi-Fi เดิมซ้ำทุกช่วงเวลานี้
constexpr uint32_t WIFI_RECOVERY_RETRY_MS = 30UL * 1000UL;
// เวลารอต่อ Wi-Fi ของการลองเบื้องหลัง สั้นกว่าปกติเพื่อไม่ให้ค้างนาน
constexpr uint32_t WIFI_RECOVERY_ATTEMPT_MS = 8000;
constexpr uint32_t BLE_READVERTISE_DELAY_MS = 600;
constexpr uint32_t ONLINE_SETUP_WINDOW_MS = 5UL * 60UL * 1000UL;
constexpr uint32_t STATUS_INTERVAL_MS = 10000;
constexpr uint32_t PZEM_READ_INTERVAL_MS = 2000;
constexpr uint32_t YELLOW_LED_BLINK_INTERVAL_MS = 400;
constexpr uint32_t CLASS_SCHEDULE_TTL_MS = 2UL * 60UL * 1000UL;
constexpr float AC_RUNNING_ON_WATTS = 30.0F;
constexpr float AC_RUNNING_OFF_WATTS = 10.0F;
constexpr uint8_t AC_RUNNING_CONFIRM_SAMPLES = 3;
constexpr uint8_t PZEM_FAILURE_LIMIT = 3;
constexpr size_t MAX_CONFIG_BYTES = 4096;
constexpr uint32_t NTP_SYNC_TIMEOUT_MS = 15000;
constexpr char FIRMWARE_VERSION[] = "2.5.5-slm8";
// บอกแอปว่าเป็นบอร์ดสายแอร์ ยี่ห้อไหน (แอปแสดงให้ผู้ใช้เห็น ไม่ให้เลือกยี่ห้อ IR)
constexpr char CONTROL_TYPE[] = "wired";
constexpr char AIR_BRAND[] = "Daikin";
constexpr char WIRED_PROTOCOL[] = "DAIKIN_WIRED";
// ข้อมูลย้อนหลังตอนเน็ตหลุด: ส่งทีละ 10 รายการ รอ Backend ตอบก่อนส่งชุดถัดไป
constexpr uint8_t HISTORY_PARTITION_SUBTYPE = 0x40;
constexpr size_t HISTORY_BATCH_SIZE = 10;
constexpr uint32_t HISTORY_SEND_GAP_MS = 1000;
constexpr uint32_t HISTORY_ACK_TIMEOUT_MS = 20000;
constexpr uint32_t HISTORY_RETRY_DELAY_MS = 5000;
// หน่วงเวลาแบบสุ่มก่อนเริ่มส่ง กันบอร์ดทั้งตึกส่งพร้อมกันหลัง Wi-Fi กลับมา
constexpr uint32_t HISTORY_START_DELAY_MIN_MS = 5000;
constexpr uint32_t HISTORY_START_DELAY_MAX_MS = 45000;

constexpr char SERVICE_UUID[] =
    "7b570001-a243-4e5b-8f13-179af81b2457";
constexpr char CONFIG_UUID[] =
    "7b570002-a243-4e5b-8f13-179af81b2457";
constexpr char STATUS_UUID[] =
    "7b570003-a243-4e5b-8f13-179af81b2457";
constexpr char IDENTITY_UUID[] =
    "7b570004-a243-4e5b-8f13-179af81b2457";
constexpr char WIFI_SCAN_UUID[] =
    "7b570005-a243-4e5b-8f13-179af81b2457";
constexpr char SETTINGS_UUID[] =
    "7b570006-a243-4e5b-8f13-179af81b2457";

struct DeviceConfig {
  bool configured = false;
  String deviceId;
  String bleName;
  String roomNumber;
  uint8_t airNumber = 0;
  String airName;
  String airProtocol = WIRED_PROTOCOL;
  String wifiSsid;
  String wifiPassword;
  String mqttHost;
  uint16_t mqttPort = 1883;
  String mqttUsername;
  String mqttPassword;
  bool mqttTls = false;
  String mqttTopic;
  String provisioningToken;
  String dailyOn;
  String dailyOff;
};

struct AirState {
  bool power = false;
  uint8_t temperature = 25;
  String mode = "cool";
  String fanSpeed = "auto";
  String verticalSwing = "auto";
  bool horizontalSwing = false;
  bool eco = false;
  bool turbo = false;
  bool sleep = false;
  bool quiet = false;
  bool displayLight = true;
  bool clean = false;
  int timerOnMinutes = -1;
  int timerOffMinutes = -1;
};

struct PowerMeasurements {
  bool available = false;
  bool acRunning = false;
  bool outsideSchedule = false;
  float voltage = NAN;
  float current = NAN;
  float powerWatts = NAN;
  float energyKwh = NAN;
  float frequencyHz = NAN;
  float powerFactor = NAN;
  uint8_t runningSamples = 0;
  uint8_t stoppedSamples = 0;
  uint8_t failedSamples = 0;
};

Preferences preferences;
WiFiClient wifiClient;
WiFiClientSecure secureClient;
bool clockSynced = false;
PubSubClient mqttClient(wifiClient);
WiredBus wiredBus;
DHT dht(DHT_PIN, DHT11);
float roomTemperatureC = NAN;
uint32_t lastDhtReadAt = 0;
PZEM004Tv30 pzem(Serial2, PZEM_RX_PIN, PZEM_TX_PIN);

DeviceConfig config;
AirState airState;
PowerMeasurements powerMeasurements;
OledDisplay oledDisplay;
String oledReason;   // เหตุผลที่เข้าโหมดตั้งค่า แสดงบนจอ

// ตัวเก็บข้อมูลย้อนหลังบนพาร์ติชัน rmuttlog (ดู partitions.csv)
struct PartitionFlash {
  const esp_partition_t *partition = nullptr;
  size_t size() { return partition ? partition->size : 0; }
  bool read(size_t offset, void *out, size_t length) {
    return partition &&
           esp_partition_read(partition, offset, out, length) == ESP_OK;
  }
  bool write(size_t offset, const void *data, size_t length) {
    return partition &&
           esp_partition_write(partition, offset, data, length) == ESP_OK;
  }
  bool eraseSector(size_t offset) {
    return partition &&
           esp_partition_erase_range(
               partition, offset, HISTORY_SECTOR_BYTES) == ESP_OK;
  }
};

// ค่าสะสมของช่วง 5 นาทีปัจจุบัน
struct HistoryInterval {
  uint32_t endTs = 0;
  uint16_t samples = 0;
  double voltageSum = 0;
  double currentSum = 0;
  double powerSum = 0;
  double powerFactorSum = 0;
  double frequencySum = 0;
  float voltageMin = NAN;
  float voltageMax = NAN;
  float currentMax = NAN;
  float powerMin = NAN;
  float powerMax = NAN;
  float energyKwh = NAN;
  uint32_t runtimeMs = 0;
  uint32_t lastSampleMs = 0;
};

PartitionFlash historyFlash;
HistoryLog<PartitionFlash> historyLog(historyFlash);
HistoryInterval historyInterval;
bool historyAwaitingAck = false;
uint32_t historySentAt = 0;
uint32_t historyNextSendAt = 0;
uint32_t historyPendingAckTs = 0;
bool historyAckReady = false;

BLEServer *bleServer = nullptr;
BLECharacteristic *statusCharacteristic = nullptr;
String receivedConfig;
String pendingConfig;
uint16_t expectedSequence = 0;
uint16_t expectedTotal = 0;
bool configReady = false;
bool bleClientConnected = false;
bool bleProvisioningActive = false;
bool bleAdvertisingEnabled = false;
bool bleBlocksNormalOperation = false;
bool bleReadvertisePending = false;
uint32_t bleReadvertiseAt = 0;
uint32_t onlineSetupExpiresAt = 0;
// true = BLE เปิดเองเพราะ Wi-Fi หลุด ยอมให้แก้เฉพาะ Wi-Fi (ดู processPendingConfig)
bool bleWifiOnlyMode = false;
uint32_t restartAt = 0;

String pendingMqttCommand;
bool mqttCommandReady = false;
bool provisionAckClearReady = false;
bool clockStarted = false;
uint32_t lastMqttReconnectAttempt = 0;
bool wifiRecoveryActive = false;
uint32_t lastWifiRecoveryAttemptAt = 0;
uint32_t lastStatusAt = 0;
uint32_t lastProvisionAt = 0;
uint32_t lastPzemReadAt = 0;
uint32_t lastYellowLedToggleAt = 0;
uint32_t timerOnAt = 0;
uint32_t timerOffAt = 0;
int lastScheduleMinute = -1;
bool wifiConnectionInProgress = false;
bool yellowLedState = false;
bool statusPublishRequested = false;
bool classScheduleConfigured = false;
bool withinClassSchedule = true;
uint32_t classScheduleReceivedAt = 0;
String pendingOtaUrl;
bool otaRequested = false;
String lastOtaError;

String createDeviceId();
bool isValidRoomNumber(const String &value);
bool isSaijoProtocol(const String &value);
bool isSupportedAirProtocol(const String &value);
void loadConfig();
void saveConfig(const DeviceConfig &newConfig);
bool keepsServerAssignment(const DeviceConfig &incoming);
void loadAirState();
void saveAirState();
void startBleProvisioning();
void startBleAdvertising();
void enterBleRecovery(const String &reason, bool retryWifi = false);
void attemptWifiRecovery();
void enterBleReconfiguration(const String &reason);
void processPendingConfig();
void notifyBle(bool ok, const String &code, const String &message);
bool connectWifi();
bool connectWifiCredentials(
    const String &ssid,
    const String &password,
    uint32_t timeoutMs);
void connectMqtt();
void mqttCallback(char *topic, byte *payload, unsigned int length);
void processMqttCommand();
void unprovisionAndRestart(const String &reason);
void checkMqttAccountRemoved(int state);
extern uint32_t mqttAuthRejectedSince;
extern uint16_t mqttAuthRejectCount;
void performOtaUpdate();
void initHistoryLog();
void accumulateHistorySample();
void finalizeHistoryInterval();
void processHistoryUpload();
void applyHistoryAck();
void publishStatus();
void publishState(const String &commandId = "");
void publishProvisioningToken();
void sendCurrentAirState(const AirState *previousState = nullptr);
void normalizeAirState(AirState &state, const AirState &previous);
slm8::Settings toBusSettings(const AirState &state);
void readRoomTemperature();
void processTimers();
void processDailySchedule();
void readPowerMeter();
void updateStatusLeds();
void refreshOled();
bool isWithinConfiguredSchedule();
bool isWithinAllowedSchedule();
bool parseMinutesOfDay(const String &value, int &minutes);

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    bleClientConnected = true;
    bleReadvertisePending = false;
    Serial.println("BLE app connected");
  }

  void onDisconnect(BLEServer *server) override {
    bleClientConnected = false;
    // Restart advertising from loop(), not from the BLE callback task.
    // This is more reliable on Windows after a failed provisioning attempt.
    if (bleAdvertisingEnabled) {
      bleReadvertiseAt = millis() + BLE_READVERTISE_DELAY_MS;
      bleReadvertisePending = true;
      Serial.println("BLE app disconnected; advertising will restart");
    }
  }
};

class ConfigCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *characteristic) override {
    auto raw = characteristic->getValue();
    const size_t length = raw.length();
    if (length < 6) {
      notifyBle(false, "invalid_packet", "BLE packet is too short");
      return;
    }
    // ESP32 Arduino Core 3.x returns Arduino String here.
    // String has c_str(), but does not provide data() on every core version.
    const uint8_t *data =
        reinterpret_cast<const uint8_t *>(raw.c_str());
    if (data[0] != 1 || data[1] != 1) {
      notifyBle(false, "unsupported_version", "Unsupported BLE protocol");
      return;
    }

    const uint16_t sequence =
        (static_cast<uint16_t>(data[2]) << 8) | data[3];
    const uint16_t total =
        (static_cast<uint16_t>(data[4]) << 8) | data[5];
    if (total == 0 || total > 32 || sequence >= total) {
      notifyBle(false, "invalid_packet", "Invalid BLE sequence");
      return;
    }
    if (sequence == 0) {
      receivedConfig = "";
      expectedSequence = 0;
      expectedTotal = total;
      receivedConfig.reserve(MAX_CONFIG_BYTES);
    }
    if (sequence != expectedSequence || total != expectedTotal) {
      receivedConfig = "";
      expectedSequence = 0;
      expectedTotal = 0;
      notifyBle(false, "sequence_error", "BLE packets arrived out of order");
      return;
    }
    if (receivedConfig.length() + length - 6 > MAX_CONFIG_BYTES) {
      receivedConfig = "";
      notifyBle(false, "config_too_large", "Configuration is too large");
      return;
    }

    for (size_t index = 6; index < length; index++) {
      receivedConfig += static_cast<char>(data[index]);
    }
    expectedSequence++;
    if (expectedSequence == expectedTotal) {
      pendingConfig = receivedConfig;
      configReady = true;
      receivedConfig = "";
      expectedSequence = 0;
      expectedTotal = 0;
    }
  }
};

class WifiScanCallbacks : public BLECharacteristicCallbacks {
  void onRead(BLECharacteristic *characteristic) override {
    Serial.println("Scanning nearby Wi-Fi for the Flutter app...");
    WiFi.mode(WIFI_STA);
    const int found = WiFi.scanNetworks(false, true);

    DynamicJsonDocument response(1536);
    JsonArray networks = response.createNestedArray("networks");
    if (found < 0) {
      response["ok"] = false;
      response["message"] = "ESP32 could not scan Wi-Fi.";
    } else {
      response["ok"] = true;
      String includedSsids[8];
      uint8_t includedCount = 0;
      for (int index = 0; index < found && includedCount < 8; index++) {
        const String ssid = WiFi.SSID(index);
        if (ssid.isEmpty()) continue;

        bool duplicate = false;
        for (uint8_t saved = 0; saved < includedCount; saved++) {
          if (includedSsids[saved] == ssid) {
            duplicate = true;
            break;
          }
        }
        if (duplicate) continue;

        includedSsids[includedCount++] = ssid;
        JsonArray network = networks.createNestedArray();
        network.add(ssid);
        network.add(WiFi.RSSI(index));
        network.add(WiFi.encryptionType(index) != WIFI_AUTH_OPEN);

        String sizeCheck;
        serializeJson(response, sizeCheck);
        if (sizeCheck.length() > 480) {
          networks.remove(networks.size() - 1);
          includedCount--;
          break;
        }
      }
      Serial.printf(
          "Wi-Fi scan complete: %u unique networks returned\n",
          includedCount);
    }

    String payload;
    serializeJson(response, payload);
    characteristic->setValue(payload.c_str());
    WiFi.scanDelete();
  }
};

void setup() {
  Serial.begin(115200);
  pinMode(SETUP_BUTTON_PIN, INPUT_PULLUP);
  pinMode(GREEN_LED_PIN, OUTPUT);
  pinMode(RED_LED_PIN, OUTPUT);
  pinMode(YELLOW_LED_PIN, OUTPUT);
  digitalWrite(GREEN_LED_PIN, LOW);
  digitalWrite(RED_LED_PIN, LOW);
  digitalWrite(YELLOW_LED_PIN, LOW);
  delay(80);
  oledDisplay.begin();

  config.deviceId = createDeviceId();
  config.bleName = "RMUTT-AC-" + config.deviceId.substring(6);
  Serial.println();
  Serial.println("RMUTT ESP32 Air Controller");
  Serial.printf("Firmware: %s\n", FIRMWARE_VERSION);
  Serial.printf("Device ID: %s\n", config.deviceId.c_str());
  Serial.printf("Aircon bus: TX GPIO%d (%s), RX GPIO%d, echo GPIO%d\n", BUS_TX_PIN, BUS_TX_INVERT ? "2N2222" : "1N4148", BUS_RX_PIN, BUS_ECHO_PIN);
  Serial.printf("DHT11: GPIO%d\n", DHT_PIN);
  Serial.printf(
      "PZEM UART: RX GPIO%u, TX GPIO%u\n",
      PZEM_RX_PIN,
      PZEM_TX_PIN);
  Serial.printf(
      "Status LEDs: green GPIO%u, red GPIO%u, yellow GPIO%u\n",
      GREEN_LED_PIN,
      RED_LED_PIN,
      YELLOW_LED_PIN);
  initHistoryLog();
  loadConfig();
  loadAirState();
  // ค่าที่จำไว้ส่งตั้งแต่เฟรมแรก: บอร์ดรีบูตแล้วแอร์ทำงานต่อเหมือนเดิม ไม่ดับเอง
  normalizeAirState(airState, airState);
  wiredBus.begin(BUS_RX_PIN, BUS_TX_PIN, BUS_TX_INVERT, BUS_ECHO_PIN, toBusSettings(airState));
  dht.begin();
  mqttClient.setBufferSize(2048);
  mqttClient.setCallback(mqttCallback);

  const bool setupRequested = digitalRead(SETUP_BUTTON_PIN) == LOW;
  if (!config.configured || setupRequested) {
    enterBleRecovery(
        setupRequested
            ? "BOOT button requested setup"
            : "No saved configuration");
    return;
  }

  if (!connectWifi()) {
    enterBleRecovery("Stored Wi-Fi could not connect", true);
    return;
  }
  connectMqtt();
}

void loop() {
  if (millis() - lastPzemReadAt >= PZEM_READ_INTERVAL_MS) {
    lastPzemReadAt = millis();
    readPowerMeter();
  }
  readRoomTemperature();
  // ทำก่อนเช็ก Wi-Fi/BLE เพราะต้องเก็บข้อมูลต่อแม้บอร์ดอยู่ในโหมดกู้ Wi-Fi
  finalizeHistoryInterval();
  updateStatusLeds();

  if (bleAdvertisingEnabled &&
      !bleBlocksNormalOperation &&
      onlineSetupExpiresAt != 0 &&
      static_cast<int32_t>(millis() - onlineSetupExpiresAt) >= 0 &&
      !bleClientConnected) {
    bleAdvertisingEnabled = false;
    bleReadvertisePending = false;
    BLEDevice::getAdvertising()->stop();
    Serial.println(
        "BLE setup window closed; Wi-Fi and MQTT stayed connected");
  }

  if (bleReadvertisePending &&
      static_cast<int32_t>(millis() - bleReadvertiseAt) >= 0) {
    bleReadvertisePending = false;
    startBleAdvertising();
  }

  if (configReady) processPendingConfig();

  if (restartAt != 0 && static_cast<int32_t>(millis() - restartAt) >= 0) {
    ESP.restart();
  }

  if (bleBlocksNormalOperation || !config.configured) {
    attemptWifiRecovery();
    delay(10);
    return;
  }

  if (WiFi.status() != WL_CONNECTED) {
    if (!connectWifi()) {
      enterBleRecovery("Wi-Fi connection was lost", true);
      return;
    }
  }
  if (!mqttClient.connected()) {
    if (millis() - lastMqttReconnectAttempt >= 3000) {
      lastMqttReconnectAttempt = millis();
      connectMqtt();
    }
  } else {
    mqttClient.loop();
    if (provisionAckClearReady &&
        mqttClient.publish(
            (config.mqttTopic + "/provision-ack").c_str(),
            "",
            true)) {
      provisionAckClearReady = false;
    }
    if (!config.provisioningToken.isEmpty() &&
        millis() - lastProvisionAt >= 10000) {
      publishProvisioningToken();
    }
    if (historyAckReady) applyHistoryAck();
    processHistoryUpload();
  }

  if (mqttCommandReady) processMqttCommand();
  if (otaRequested) performOtaUpdate();
  processTimers();
  processDailySchedule();

  if (statusPublishRequested ||
      millis() - lastStatusAt >= STATUS_INTERVAL_MS) {
    lastStatusAt = millis();
    publishStatus();
  }
  delay(5);
}

String createDeviceId() {
  const uint64_t chipId = ESP.getEfuseMac();
  char buffer[20];
  snprintf(
      buffer,
      sizeof(buffer),
      "ESP32-%04X%08X",
      static_cast<uint16_t>(chipId >> 32),
      static_cast<uint32_t>(chipId));
  return String(buffer);
}

bool isValidRoomNumber(const String &value) {
  if (value.length() < 2 || value.length() > 20) {
    return false;
  }
  for (size_t index = 0; index < value.length(); index++) {
    const char character = value.charAt(index);
    const bool validCharacter =
        (character >= 'A' && character <= 'Z') ||
        (character >= '0' && character <= '9') ||
        character == '_' ||
        character == '-';
    if (!validCharacter) {
      return false;
    }
  }
  return true;
}

// รุ่นสายแอร์มีโปรโตคอลเดียวคือ DAIKIN_WIRED แอปรุ่นเก่าที่ยังส่งชื่อยี่ห้อ IR มา
// ก็ยังรับได้ แต่บอร์ดจะบันทึกเป็น DAIKIN_WIRED เสมอ (ดู processPendingConfig)
bool isSaijoProtocol(const String &value) {
  return false;
}

bool isSupportedAirProtocol(const String &value) {
  return !value.isEmpty();
}

void loadConfig() {
  preferences.begin("rmutt-air", true);
  config.configured = preferences.getBool("configured", false);
  config.roomNumber = preferences.getString("room", "");
  config.airNumber = preferences.getUChar("air_no", 0);
  config.airName = preferences.getString("air_name", "");
  // ค่าเดิมใน NVS อาจเป็นยี่ห้อ IR ที่เลือกจากแอปรุ่นเก่า รุ่นนี้ใช้ DAIKIN_WIRED เสมอ
  config.airProtocol = WIRED_PROTOCOL;
  config.wifiSsid = preferences.getString("wifi_ssid", "");
  config.wifiPassword = preferences.getString("wifi_pass", "");
  config.mqttHost = preferences.getString("mqtt_host", "");
  config.mqttPort = preferences.getUShort("mqtt_port", 1883);
  config.mqttUsername = preferences.getString("mqtt_user", "");
  config.mqttPassword = preferences.getString("mqtt_pass", "");
  config.mqttTls = preferences.getBool("mqtt_tls", false);
  config.mqttTopic = preferences.getString("mqtt_topic", "");
  config.provisioningToken = preferences.getString("prov_token", "");
  config.dailyOn = preferences.getString("daily_on", "");
  config.dailyOff = preferences.getString("daily_off", "");
  preferences.end();
}

void saveConfig(const DeviceConfig &newConfig) {
  preferences.begin("rmutt-air", false);
  preferences.putBool("configured", true);
  preferences.putString("room", newConfig.roomNumber);
  preferences.putUChar("air_no", newConfig.airNumber);
  preferences.putString("air_name", newConfig.airName);
  preferences.putString("protocol", newConfig.airProtocol);
  preferences.putString("wifi_ssid", newConfig.wifiSsid);
  preferences.putString("wifi_pass", newConfig.wifiPassword);
  preferences.putString("mqtt_host", newConfig.mqttHost);
  preferences.putUShort("mqtt_port", newConfig.mqttPort);
  preferences.putString("mqtt_user", newConfig.mqttUsername);
  preferences.putString("mqtt_pass", newConfig.mqttPassword);
  preferences.putBool("mqtt_tls", newConfig.mqttTls);
  preferences.putString("mqtt_topic", newConfig.mqttTopic);
  preferences.putString("prov_token", newConfig.provisioningToken);
  preferences.putString("daily_on", newConfig.dailyOn);
  preferences.putString("daily_off", newConfig.dailyOff);
  preferences.end();
}

void loadAirState() {
  preferences.begin("rmutt-state", true);
  airState.power = preferences.getBool("power", false);
  airState.temperature = preferences.getUChar("temp", 25);
  airState.mode = preferences.getString("mode", "cool");
  airState.fanSpeed = preferences.getString("fan", "auto");
  airState.verticalSwing = preferences.getString("swing_v", "auto");
  airState.horizontalSwing = preferences.getBool("swing_h", false);
  airState.eco = preferences.getBool("eco", false);
  airState.turbo = preferences.getBool("turbo", false);
  airState.sleep = preferences.getBool("sleep", false);
  airState.quiet = preferences.getBool("quiet", false);
  airState.displayLight = preferences.getBool("light", true);
  airState.clean = preferences.getBool("clean", false);
  preferences.end();
}

void saveAirState() {
  preferences.begin("rmutt-state", false);
  preferences.putBool("power", airState.power);
  preferences.putUChar("temp", airState.temperature);
  preferences.putString("mode", airState.mode);
  preferences.putString("fan", airState.fanSpeed);
  preferences.putString("swing_v", airState.verticalSwing);
  preferences.putBool("swing_h", airState.horizontalSwing);
  preferences.putBool("eco", airState.eco);
  preferences.putBool("turbo", airState.turbo);
  preferences.putBool("sleep", airState.sleep);
  preferences.putBool("quiet", airState.quiet);
  preferences.putBool("light", airState.displayLight);
  preferences.putBool("clean", airState.clean);
  preferences.end();
}

void startBleProvisioning() {
  bleAdvertisingEnabled = true;
  if (bleProvisioningActive) {
    startBleAdvertising();
    return;
  }

  bleProvisioningActive = true;
  BLEDevice::init(config.bleName.c_str());
  bleServer = BLEDevice::createServer();
  bleServer->setCallbacks(new ServerCallbacks());
  BLEService *service = bleServer->createService(SERVICE_UUID);

  BLECharacteristic *configCharacteristic =
      service->createCharacteristic(
          CONFIG_UUID,
          BLECharacteristic::PROPERTY_WRITE);
  configCharacteristic->setCallbacks(new ConfigCallbacks());

  statusCharacteristic = service->createCharacteristic(
      STATUS_UUID,
      BLECharacteristic::PROPERTY_READ |
          BLECharacteristic::PROPERTY_NOTIFY);
  statusCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic *identityCharacteristic =
      service->createCharacteristic(
          IDENTITY_UUID,
          BLECharacteristic::PROPERTY_READ);
  // Keep the first identity read short. Windows WinRT can connect to the
  // ESP32 but time out while reading one large GATT value at the default MTU.
  // Optional saved settings are exposed through SETTINGS_UUID instead.
  DynamicJsonDocument identity(256);
  identity["deviceId"] = config.deviceId;
  identity["bleName"] = config.bleName;
  identity["firmwareVersion"] = FIRMWARE_VERSION;
  identity["configured"] = config.configured;
  identity["controlType"] = CONTROL_TYPE;
  identity["brand"] = AIR_BRAND;
  if (config.configured) {
    identity["roomNumber"] = config.roomNumber;
    identity["airNumber"] = config.airNumber;
  }
  String identityJson;
  serializeJson(identity, identityJson);
  identityCharacteristic->setValue(identityJson.c_str());

  BLECharacteristic *settingsCharacteristic =
      service->createCharacteristic(
          SETTINGS_UUID,
          BLECharacteristic::PROPERTY_READ);
  DynamicJsonDocument settings(768);
  settings["roomNumber"] = config.roomNumber;
  settings["airNumber"] = config.airNumber;
  settings["name"] = config.airName;
  settings["airProtocol"] = config.airProtocol;
  settings["wifiSsid"] = config.wifiSsid;
  settings["hasWifiPassword"] = !config.wifiPassword.isEmpty();
  settings["mqttHost"] = config.mqttHost;
  settings["mqttPort"] = config.mqttPort;
  settings["mqttUsername"] = config.mqttUsername;
  settings["hasMqttPassword"] = !config.mqttPassword.isEmpty();
  settings["dailyOn"] = config.dailyOn;
  settings["dailyOff"] = config.dailyOff;
  String settingsJson;
  serializeJson(settings, settingsJson);
  settingsCharacteristic->setValue(settingsJson.c_str());

  BLECharacteristic *wifiScanCharacteristic =
      service->createCharacteristic(
          WIFI_SCAN_UUID,
          BLECharacteristic::PROPERTY_READ);
  wifiScanCharacteristic->setCallbacks(new WifiScanCallbacks());
  wifiScanCharacteristic->setValue(
      "{\"ok\":true,\"networks\":[]}");

  service->start();
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMinPreferred(0x12);
  Serial.printf("BLE name: %s\n", config.bleName.c_str());
  Serial.printf(
      "BLE identity payload: %u bytes\n",
      static_cast<unsigned>(identityJson.length()));
  startBleAdvertising();
  Serial.println("Waiting for configuration from the Flutter app...");
}

void startBleAdvertising() {
  if (!bleProvisioningActive ||
      !bleAdvertisingEnabled ||
      bleClientConnected) {
    return;
  }
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->stop();
  delay(80);
  advertising->start();
  Serial.printf(
      "BLE advertising active: %s (Firmware %s)\n",
      config.bleName.c_str(),
      FIRMWARE_VERSION);
}

// ระหว่างอยู่ในโหมด BLE recovery ที่เกิดจาก Wi-Fi ให้แอบลองต่อ Wi-Fi เดิม
// เป็นระยะ ถ้าเครือข่ายกลับมา บอร์ดจะออกจากโหมดตั้งค่าและทำงานต่อเอง
void attemptWifiRecovery() {
  if (!wifiRecoveryActive) return;
  if (bleClientConnected) return;
  if (configReady || restartAt != 0) return;
  if (config.wifiSsid.isEmpty()) return;
  if (millis() - lastWifiRecoveryAttemptAt < WIFI_RECOVERY_RETRY_MS) return;
  lastWifiRecoveryAttemptAt = millis();

  Serial.println("BLE recovery: retrying the saved Wi-Fi in the background");
  if (!connectWifiCredentials(
          config.wifiSsid,
          config.wifiPassword,
          WIFI_RECOVERY_ATTEMPT_MS)) {
    return;
  }
  if (bleClientConnected) {
    Serial.println("Wi-Fi is back but a BLE setup session is active: waiting");
    return;
  }

  Serial.println("Wi-Fi is back: leaving BLE recovery and resuming");
  wifiRecoveryActive = false;
  bleWifiOnlyMode = false;
  bleBlocksNormalOperation = false;
  bleAdvertisingEnabled = false;
  bleReadvertisePending = false;
  onlineSetupExpiresAt = 0;
  if (bleProvisioningActive) BLEDevice::getAdvertising()->stop();
  connectMqtt();
}

void enterBleRecovery(const String &reason, bool retryWifi) {
  Serial.printf("Mode: BLE recovery - %s\n", reason.c_str());
  oledReason = reason.length() > 25 ? reason.substring(0, 25) : reason;
  bleBlocksNormalOperation = true;
  onlineSetupExpiresAt = 0;
  wifiRecoveryActive = retryWifi;
  // บอร์ดที่ตั้งค่าแล้วแต่ Wi-Fi หลุด: ใครอยู่ใกล้ก็ต่อ BLE ได้ จึงล็อกห้องและเซิร์ฟเวอร์ไว้
  // ส่วนกรณียังไม่เคยตั้งค่า หรือกด BOOT ค้าง (ต้องเข้าถึงตัวบอร์ด) แก้ได้ทุกช่อง
  bleWifiOnlyMode = retryWifi && config.configured;
  lastWifiRecoveryAttemptAt = millis();
  if (mqttClient.connected()) mqttClient.disconnect();
  WiFi.disconnect(false, false);
  delay(150);
  startBleProvisioning();
}

void enterBleReconfiguration(const String &reason) {
  Serial.printf("Mode: online BLE setup - %s\n", reason.c_str());
  bleBlocksNormalOperation = false;
  onlineSetupExpiresAt = millis() + ONLINE_SETUP_WINDOW_MS;
  // เปิดจากคำสั่ง MQTT ของ Backend (เฉพาะแอดมิน) แก้ได้ทุกช่อง
  bleWifiOnlyMode = false;
  startBleProvisioning();
  Serial.println(
      "Existing Wi-Fi, MQTT, room and air settings remain active until Save");
}

// ค่าที่ห้ามเปลี่ยนในโหมดกู้ Wi-Fi: ห้อง หมายเลขแอร์ และบัญชี/เซิร์ฟเวอร์ MQTT
// ถ้าเปลี่ยนได้ คนแปลกหน้าที่อยู่ใกล้บอร์ดตอน Wi-Fi หลุดจะชี้บอร์ดไปหา
// MQTT ของตัวเองแล้วสั่งแอร์ห้องนั้นได้
bool keepsServerAssignment(const DeviceConfig &incoming) {
  return incoming.roomNumber == config.roomNumber &&
         incoming.airNumber == config.airNumber &&
         incoming.mqttHost == config.mqttHost &&
         incoming.mqttPort == config.mqttPort &&
         incoming.mqttTls == config.mqttTls &&
         incoming.mqttUsername == config.mqttUsername &&
         incoming.mqttPassword == config.mqttPassword &&
         incoming.mqttTopic == config.mqttTopic;
}

void processPendingConfig() {
  configReady = false;
  DynamicJsonDocument document(4096);
  const DeserializationError error =
      deserializeJson(document, pendingConfig);
  pendingConfig = "";
  if (error) {
    Serial.printf("BLE config JSON error: %s\n", error.c_str());
    notifyBle(false, "invalid_json", "Configuration JSON is invalid");
    return;
  }

  DeviceConfig incoming = config;
  incoming.deviceId = document["deviceId"] | "";
  incoming.roomNumber = document["roomNumber"] | "";
  incoming.airNumber = document["airNumber"] | 0;
  incoming.airName = document["name"] | "";
  incoming.airProtocol = document["airProtocol"] | WIRED_PROTOCOL;
  incoming.provisioningToken = document["token"] | "";
  incoming.wifiSsid = document["wifi"]["ssid"] | "";
  const bool keepWifiPassword =
      document["wifi"]["keepPassword"] | false;
  incoming.wifiPassword =
      keepWifiPassword &&
              incoming.wifiSsid == config.wifiSsid
          ? config.wifiPassword
          : String(document["wifi"]["password"] | "");
  incoming.mqttHost = document["mqtt"]["host"] | "";
  incoming.mqttPort = document["mqtt"]["port"] | 1883;
  incoming.mqttTls = document["mqtt"]["tls"] | false;
  incoming.mqttUsername = document["mqtt"]["username"] | "";
  const bool keepMqttPassword =
      document["mqtt"]["keepPassword"] | false;
  incoming.mqttPassword =
      keepMqttPassword &&
              incoming.mqttHost == config.mqttHost &&
              incoming.mqttPort == config.mqttPort &&
              incoming.mqttUsername == config.mqttUsername
          ? config.mqttPassword
          : String(document["mqtt"]["password"] | "");
  incoming.mqttTopic = document["mqtt"]["topic"] | "";
  incoming.dailyOn = document["schedule"]["dailyOn"] | "";
  incoming.dailyOff = document["schedule"]["dailyOff"] | "";

  const bool roomValid = isValidRoomNumber(incoming.roomNumber);
  const bool valid =
      incoming.deviceId == config.deviceId &&
      roomValid &&
      incoming.airNumber >= 1 &&
      incoming.airNumber <= 6 &&
      !incoming.airName.isEmpty() &&
      !incoming.provisioningToken.isEmpty() &&
      !incoming.wifiSsid.isEmpty() &&
      incoming.wifiPassword.length() >= 8 &&
      !incoming.mqttHost.isEmpty() &&
      !incoming.mqttTopic.isEmpty() &&
      isSupportedAirProtocol(incoming.airProtocol);
  if (!valid) {
    Serial.println("BLE config rejected: invalid or incomplete settings");
    notifyBle(false, "invalid_config", "Required settings are invalid");
    return;
  }
  if (incoming.airProtocol != WIRED_PROTOCOL) {
    Serial.printf("BLE config: protocol %s -> %s (บอร์ดสายแอร์)\n",
                  incoming.airProtocol.c_str(), WIRED_PROTOCOL);
    incoming.airProtocol = WIRED_PROTOCOL;
  }
  if (bleWifiOnlyMode && !keepsServerAssignment(incoming)) {
    Serial.println(
        "BLE config rejected: Wi-Fi recovery mode only accepts Wi-Fi changes");
    notifyBle(
        false,
        "wifi_only_mode",
        "Wi-Fi recovery: only Wi-Fi can change. Hold BOOT and reset to change room or server.");
    return;
  }

  Serial.printf(
      "Testing Wi-Fi credentials before saving: %s\n",
      incoming.wifiSsid.c_str());
  const bool onlineReconfiguration =
      config.configured && !bleBlocksNormalOperation;
  if (onlineReconfiguration && mqttClient.connected()) {
    mqttClient.disconnect();
  }
  if (!connectWifiCredentials(
          incoming.wifiSsid,
          incoming.wifiPassword,
          WIFI_PROVISION_TIMEOUT_MS)) {
    Serial.println(
        "Wi-Fi test failed. The previous NVS configuration was kept.");
    notifyBle(
        false,
        "wifi_connection_failed",
        "Unable to connect to Wi-Fi. Check the SSID and password, then try again.");
    Serial.println(
        "Keep this screen open, correct the password, and save again.");
    if (onlineReconfiguration) {
      Serial.println(
          "Restoring the previous Wi-Fi and MQTT configuration...");
      if (connectWifi()) connectMqtt();
    }
    return;
  }

  incoming.configured = true;
  incoming.bleName = config.bleName;
  saveConfig(incoming);
  config = incoming;
  Serial.println("Configuration saved to NVS");
  Serial.printf(
      "Assigned to room %s, air %u\n",
      config.roomNumber.c_str(),
      config.airNumber);
  notifyBle(
      true,
      "config_saved",
      "Wi-Fi verified and configuration saved to NVS");
  restartAt = millis() + 1500;
}

void notifyBle(bool ok, const String &code, const String &message) {
  if (statusCharacteristic == nullptr) return;
  DynamicJsonDocument response(256);
  response["ok"] = ok;
  response["code"] = code;
  response["message"] = message;
  String payload;
  serializeJson(response, payload);
  statusCharacteristic->setValue(payload.c_str());
  if (bleClientConnected) statusCharacteristic->notify();
}

bool connectWifi() {
  return connectWifiCredentials(
      config.wifiSsid,
      config.wifiPassword,
      WIFI_TIMEOUT_MS);
}

bool connectWifiCredentials(
    const String &ssid,
    const String &password,
    uint32_t timeoutMs) {
  if (ssid.isEmpty()) return false;
  Serial.printf("Connecting Wi-Fi: %s\n", ssid.c_str());
  wifiConnectionInProgress = true;
  lastYellowLedToggleAt = 0;
  yellowLedState = false;
  updateStatusLeds();
  WiFi.disconnect(false, false);
  delay(100);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), password.c_str());
  const uint32_t startedAt = millis();
  while (WiFi.status() != WL_CONNECTED &&
         millis() - startedAt < timeoutMs) {
    const wl_status_t status = WiFi.status();
    if (status == WL_CONNECT_FAILED || status == WL_NO_SSID_AVAIL) {
      break;
    }
    updateStatusLeds();
    delay(50);
  }
  wifiConnectionInProgress = false;
  if (WiFi.status() != WL_CONNECTED) {
    Serial.printf(
        "Wi-Fi connection failed, status: %d\n",
        static_cast<int>(WiFi.status()));
    WiFi.disconnect(false, false);
    updateStatusLeds();
    return false;
  }
  updateStatusLeds();
  Serial.printf("Wi-Fi connected, IP: %s\n", WiFi.localIP().toString().c_str());
  if (!clockStarted) {
    configTime(7 * 3600, 0, "pool.ntp.org", "time.nist.gov");
    clockStarted = true;
    Serial.println("NTP clock started for Asia/Bangkok (UTC+7)");
  }
  return true;
}

// TLS ตรวจอายุใบรับรองจากนาฬิกาของบอร์ด ถ้าเวลายังไม่ตรงจะเชื่อมต่อไม่ผ่าน
bool ensureClockSynced() {
  if (clockSynced) return true;
  configTime(7 * 3600, 0, "pool.ntp.org", "time.google.com");
  const uint32_t startedAt = millis();
  while (time(nullptr) < 1700000000UL &&
         millis() - startedAt < NTP_SYNC_TIMEOUT_MS) {
    delay(200);
  }
  clockSynced = time(nullptr) >= 1700000000UL;
  if (clockSynced) {
    Serial.printf("Clock synced: %lu\n",
                  static_cast<unsigned long>(time(nullptr)));
  } else {
    Serial.println("NTP sync failed; TLS certificate check will fail");
  }
  return clockSynced;
}

void connectMqtt() {
  if (WiFi.status() != WL_CONNECTED || config.mqttHost.isEmpty()) return;
  Serial.printf(
      "Connecting MQTT: %s:%u\n",
      config.mqttHost.c_str(),
      config.mqttPort);
  if (config.mqttTls) {
    if (!ensureClockSynced()) return;
    secureClient.setCACert(LETSENCRYPT_CA);
    secureClient.setTimeout(15);
    mqttClient.setClient(secureClient);
  } else {
    mqttClient.setClient(wifiClient);
  }
  mqttClient.setServer(config.mqttHost.c_str(), config.mqttPort);
  const String statusTopic = config.mqttTopic + "/status";
  const String clientId = "rmutt-" + config.deviceId;
  DynamicJsonDocument offline(96);
  offline["online"] = false;
  offline["deviceId"] = config.deviceId;
  String willPayload;
  serializeJson(offline, willPayload);

  bool connected;
  if (config.mqttUsername.isEmpty()) {
    connected = mqttClient.connect(
        clientId.c_str(),
        statusTopic.c_str(),
        1,
        true,
        willPayload.c_str());
  } else {
    connected = mqttClient.connect(
        clientId.c_str(),
        config.mqttUsername.c_str(),
        config.mqttPassword.c_str(),
        statusTopic.c_str(),
        1,
        true,
        willPayload.c_str());
  }
  if (!connected) {
    const int state = mqttClient.state();
    Serial.printf("MQTT connection failed, state: %d\n", state);
    checkMqttAccountRemoved(state);
    return;
  }
  mqttAuthRejectedSince = 0;
  mqttAuthRejectCount = 0;

  mqttClient.subscribe((config.mqttTopic + "/command").c_str(), 1);
  mqttClient.subscribe((config.mqttTopic + "/provision-ack").c_str(), 1);
  mqttClient.subscribe((config.mqttTopic + "/schedule-status").c_str(), 1);
  mqttClient.subscribe((config.mqttTopic + "/history-ack").c_str(), 1);
  // เริ่มส่งข้อมูลย้อนหลังหลังหน่วงแบบสุ่ม ไม่ส่งทันทีที่ต่อได้
  historyAwaitingAck = false;
  historyNextSendAt =
      millis() + static_cast<uint32_t>(random(
                     HISTORY_START_DELAY_MIN_MS,
                     HISTORY_START_DELAY_MAX_MS + 1));
  Serial.println("MQTT connected");
  Serial.printf(
      "Subscribed: %s/command\n",
      config.mqttTopic.c_str());
  publishStatus();
  publishState();
  publishProvisioningToken();
}

void mqttCallback(char *topic, byte *payload, unsigned int length) {
  if (length == 0 || length > 2048) return;
  const String incomingTopic(topic);
  if (incomingTopic == config.mqttTopic + "/schedule-status") {
    DynamicJsonDocument scheduleStatus(384);
    if (deserializeJson(scheduleStatus, payload, length)) return;
    classScheduleConfigured =
        scheduleStatus["classScheduleConfigured"] | false;
    withinClassSchedule =
        scheduleStatus["withinClassSchedule"] | true;
    classScheduleReceivedAt = millis();
    powerMeasurements.outsideSchedule =
        powerMeasurements.acRunning && !isWithinAllowedSchedule();
    updateStatusLeds();
    Serial.printf(
        "Class schedule: configured=%s, within=%s\n",
        classScheduleConfigured ? "yes" : "no",
        withinClassSchedule ? "yes" : "no");
    return;
  }
  if (incomingTopic == config.mqttTopic + "/history-ack") {
    // ลบข้อมูลใน flash ใช้เวลา จึงทำต่อใน loop ไม่ทำใน callback
    DynamicJsonDocument acknowledgement(256);
    if (deserializeJson(acknowledgement, payload, length)) return;
    const uint32_t upTo = acknowledgement["upTo"] | 0UL;
    if (upTo > historyPendingAckTs) historyPendingAckTs = upTo;
    historyAckReady = true;
    return;
  }
  if (incomingTopic == config.mqttTopic + "/provision-ack") {
    DynamicJsonDocument acknowledgement(512);
    if (deserializeJson(acknowledgement, payload, length)) return;
    const String acknowledgedToken = acknowledgement["token"] | "";
    if (acknowledgement["activated"] == true &&
        !config.provisioningToken.isEmpty() &&
        acknowledgedToken == config.provisioningToken) {
      preferences.begin("rmutt-air", false);
      preferences.remove("prov_token");
      preferences.end();
      config.provisioningToken = "";
      provisionAckClearReady = true;
    }
    return;
  }
  if (incomingTopic != config.mqttTopic + "/command") return;
  pendingMqttCommand = "";
  pendingMqttCommand.reserve(length);
  for (unsigned int index = 0; index < length; index++) {
    pendingMqttCommand += static_cast<char>(payload[index]);
  }
  mqttCommandReady = true;
}

// ---------------------------------------------------------------------------
// บัญชี MQTT ถูกลบไปแล้ว (เช่น กดลบอุปกรณ์ในแอปตอนบอร์ดไม่ได้รับคำสั่ง unprovision)
// Broker จะตอบว่ารหัสผิด/ไม่มีสิทธิ์ทุกครั้ง บอร์ดต่อ Wi-Fi ได้แต่ใช้งานไม่ได้และไม่เปิด BLE
// ถ้าถูกปฏิเสธติดกันนานเกิน MQTT_AUTH_REJECT_RESET_MS ให้ล้างค่าทั้งหมด (รวม Wi-Fi)
// แล้วรีบูตเข้าโหมดตั้งค่าผ่านบลูทูธ เหมือนได้รับคำสั่ง unprovision
//   state 4 = MQTT_CONNECT_BAD_CREDENTIALS, 5 = MQTT_CONNECT_UNAUTHORIZED
// เน็ตหลุด/ต่อ Broker ไม่ได้ (state ติดลบ) ไม่นับ และไม่รีเซ็ตตัวนับ
// ---------------------------------------------------------------------------
constexpr uint32_t MQTT_AUTH_REJECT_RESET_MS = 2UL * 60UL * 1000UL;
constexpr uint16_t MQTT_AUTH_REJECT_MIN_COUNT = 10;
uint32_t mqttAuthRejectedSince = 0;
uint16_t mqttAuthRejectCount = 0;

void checkMqttAccountRemoved(int state) {
  if (state != 4 && state != 5) return;
  if (mqttAuthRejectedSince == 0) mqttAuthRejectedSince = millis();
  if (mqttAuthRejectCount < 0xFFFF) mqttAuthRejectCount++;
  const uint32_t rejectedFor = millis() - mqttAuthRejectedSince;
  Serial.printf(
      "MQTT account rejected %u times for %lus (reset after %lus)\n",
      mqttAuthRejectCount,
      static_cast<unsigned long>(rejectedFor / 1000),
      static_cast<unsigned long>(MQTT_AUTH_REJECT_RESET_MS / 1000));
  if (rejectedFor >= MQTT_AUTH_REJECT_RESET_MS &&
      mqttAuthRejectCount >= MQTT_AUTH_REJECT_MIN_COUNT) {
    unprovisionAndRestart("MQTT account was removed (rejected by broker)");
  }
}

// ---------------------------------------------------------------------------
// ล้างบอร์ดเมื่อถูกลบออกจากแอป (คำสั่ง {"action":"unprovision"})
// ลบค่าทั้งหมดใน NVS (Wi-Fi, MQTT, ห้อง, สถานะแอร์) และข้อมูลย้อนหลังใน flash
// แล้วรีบูต บอร์ดกลับเป็นสภาพเหมือนใหม่ รอตั้งค่าผ่านบลูทูธ
// Device ID ไม่เปลี่ยน เพราะสร้างจาก eFuse MAC ไม่ได้เก็บใน NVS
// สถานะแอร์ที่จำไว้ถูกล้างด้วย หลังรีบูตบอร์ดจึงส่งเฟรมสั่งแอร์ "ปิด" ทางสาย
// ---------------------------------------------------------------------------
void unprovisionAndRestart(const String &reason) {
  Serial.printf("Unprovision: %s - clearing all saved settings\n", reason.c_str());
  if (mqttClient.connected()) {
    // ตอบ Backend ว่าล้างค่าแล้ว (Backend รอคำตอบนี้ก่อนลบบัญชี MQTT ของบอร์ด)
    DynamicJsonDocument ack(128);
    ack["deviceId"] = config.deviceId;
    ack["online"] = false;
    ack["unprovisioned"] = true;
    String ackPayload;
    serializeJson(ack, ackPayload);
    const String statusTopic = config.mqttTopic + "/status";
    mqttClient.publish(statusTopic.c_str(), ackPayload.c_str(), false);
    // ล้าง retained ของตัวเอง แล้วตัดการเชื่อมต่อแบบปกติ
    // (ตัดแบบปกติ Broker จะไม่ส่ง Last Will "online:false" กลับมาค้างเป็น retained)
    mqttClient.publish(statusTopic.c_str(), "", true);
    mqttClient.publish((config.mqttTopic + "/state").c_str(), "", true);
    mqttClient.loop();
    delay(300);
    mqttClient.disconnect();
  }

  preferences.begin("rmutt-air", false);
  preferences.clear();
  preferences.end();
  preferences.begin("rmutt-state", false);
  preferences.clear();   // สถานะแอร์ + hist_ack
  preferences.end();

  if (historyFlash.partition != nullptr) {
    esp_partition_erase_range(historyFlash.partition, 0, historyFlash.partition->size);
  }

  Serial.println("Unprovision: done, restarting into BLE setup mode");
  delay(300);
  ESP.restart();
}

void processMqttCommand() {
  mqttCommandReady = false;
  DynamicJsonDocument document(2048);
  const DeserializationError error =
      deserializeJson(document, pendingMqttCommand);
  if (error) {
    Serial.printf("MQTT command JSON error: %s\n", error.c_str());
    pendingMqttCommand = "";
    return;
  }
  pendingMqttCommand = "";

  const String action = document["action"] | "";
  if (action == "enter_setup") {
    Serial.println("MQTT requested BLE setup mode");
    enterBleReconfiguration("Flutter app requested reconfiguration");
    return;
  }
  if (action == "unprovision") {
    // Backend ส่งมาเมื่อแอดมินกดลบอุปกรณ์ในแอป
    // ตรวจ deviceId ซ้ำอีกชั้น กันข้อความหลงมาผิด topic
    const String target = document["deviceId"] | "";
    if (target != config.deviceId) {
      Serial.printf("Unprovision ignored: deviceId '%s' is not this board\n", target.c_str());
      return;
    }
    unprovisionAndRestart("removed from the app");
    return;
  }
  if (action == "ota") {
    const String url = document["url"] | "";
    if (!otaUrlAllowed(url, config.mqttHost)) {
      Serial.printf("OTA rejected: URL not allowed: %s\n", url.c_str());
      lastOtaError = "url_rejected";
      statusPublishRequested = true;
      return;
    }
    pendingOtaUrl = url;
    otaRequested = true;
    return;
  }

  JsonObject state = document["state"].as<JsonObject>();
  if (state.isNull()) {
    Serial.println("MQTT command rejected: state is missing");
    return;
  }
  const bool saijoProtocol = isSaijoProtocol(config.airProtocol);
  const int minimumTemperature = saijoProtocol ? 18 : 16;
  const int maximumTemperature = saijoProtocol ? 29 : 30;
  const int temperature = state["temperature"] | 25;
  if (temperature < minimumTemperature ||
      temperature > maximumTemperature) {
    Serial.printf(
        "MQTT command rejected: temperature must be %d-%d C\n",
        minimumTemperature,
        maximumTemperature);
    return;
  }

  const String mode = state["mode"] | "cool";
  const String fanSpeed = state["fanSpeed"] | "auto";
  const String verticalSwing = state["verticalSwing"] | "auto";
  if (saijoProtocol &&
      mode != "cool" &&
      mode != "dry" &&
      mode != "fan") {
    Serial.println("MQTT command rejected: unsupported Saijo Denki mode");
    return;
  }
  if (saijoProtocol &&
      fanSpeed != "auto" &&
      fanSpeed != "low" &&
      fanSpeed != "medium" &&
      fanSpeed != "high" &&
      fanSpeed != "turbo") {
    Serial.println("MQTT command rejected: unsupported Saijo Denki fan speed");
    return;
  }
  if (saijoProtocol &&
      verticalSwing != "auto" &&
      verticalSwing != "top" &&
      verticalSwing != "upper" &&
      verticalSwing != "middle" &&
      verticalSwing != "lower" &&
      verticalSwing != "bottom") {
    Serial.println("MQTT command rejected: unsupported Saijo Denki swing position");
    return;
  }

  const AirState previousState = airState;
  airState.power = state["power"] | false;
  airState.temperature = temperature;
  airState.mode = mode;
  airState.fanSpeed = fanSpeed;
  airState.verticalSwing = verticalSwing;
  airState.horizontalSwing = state["horizontalSwing"] | false;
  airState.eco = state["eco"] | false;
  airState.turbo = state["turbo"] | false;
  airState.sleep = state["sleep"] | false;
  airState.quiet = state["quiet"] | false;
  airState.displayLight = state["displayLight"] | true;
  airState.clean = state["clean"] | false;
  airState.timerOnMinutes =
      state["timerOnMinutes"].isNull()
          ? -1
          : state["timerOnMinutes"].as<int>();
  airState.timerOffMinutes =
      state["timerOffMinutes"].isNull()
          ? -1
          : state["timerOffMinutes"].as<int>();

  timerOnAt = airState.timerOnMinutes > 0
      ? millis() + static_cast<uint32_t>(airState.timerOnMinutes) * 60000UL
      : 0;
  timerOffAt = airState.timerOffMinutes > 0
      ? millis() + static_cast<uint32_t>(airState.timerOffMinutes) * 60000UL
      : 0;

  normalizeAirState(airState, previousState);
  saveAirState();
  sendCurrentAirState(&previousState);
  publishState(document["commandId"] | "");
}

// ---------------------------------------------------------------------------
// สายแอร์: แปลง AirState ของแอปเป็นเฟรม SLM8
// รีโมตติดผนังรุ่นนี้มีเฉพาะ: เปิด/ปิด, 16-30 C, Cool/Dry/Fan, พัดลม 1/2/3/Auto,
// ส่าย เปิด/ปิด, Sleep  ค่าอื่นจากแอปถูกปรับให้ตรงกับที่แอร์ทำได้จริง แล้วส่งกลับใน state
// แอปจึงแสดงสิ่งที่แอร์ทำอยู่จริงเสมอ
// ---------------------------------------------------------------------------
void normalizeAirState(AirState &state, const AirState &previous) {
  if (state.mode != "cool" && state.mode != "dry" && state.mode != "fan") {
    Serial.printf("Wired: mode '%s' is not available on this unit, keeping '%s'\n",
                  state.mode.c_str(), previous.mode.c_str());
    state.mode = (previous.mode == "dry" || previous.mode == "fan") ? previous.mode : "cool";
  }
  if (state.temperature < 16) state.temperature = 16;
  if (state.temperature > 30) state.temperature = 30;
  if (state.fanSpeed == "turbo") state.fanSpeed = "high";
  if (state.fanSpeed != "low" && state.fanSpeed != "medium" && state.fanSpeed != "high") {
    state.fanSpeed = "auto";
  }
  // มีแค่ "ส่าย" กับ "หยุด" ตำแหน่งใบพัดอื่น ๆ ถือเป็นส่าย
  state.verticalSwing = state.verticalSwing == "off" ? "off" : "auto";
  state.horizontalSwing = false;
  state.eco = false;
  state.turbo = false;
  state.quiet = false;
  state.clean = false;
  if (state.mode == "dry") state.sleep = false;   // แอร์ไม่รับ Sleep ในโหมด Dry
}

slm8::Settings toBusSettings(const AirState &state) {
  slm8::Settings s;
  s.power = state.power;
  s.setC = state.temperature;
  s.mode = state.mode == "dry" ? slm8::MODE_DRY
         : state.mode == "fan" ? slm8::MODE_FAN
                               : slm8::MODE_COOL;
  s.fan = state.fanSpeed == "low" ? slm8::FAN_1
        : state.fanSpeed == "medium" ? slm8::FAN_2
        : state.fanSpeed == "high" ? slm8::FAN_3
                                   : slm8::FAN_AUTO;
  s.swing = state.verticalSwing != "off";
  s.sleep = state.sleep;
  return s;
}

void sendCurrentAirState(const AirState *previousState) {
  wiredBus.apply(toBusSettings(airState));
  oledDisplay.poke();
  Serial.printf(
      "Wired sent: power=%s temp=%u mode=%s fan=%s swing=%s sleep=%s\n",
      airState.power ? "ON" : "OFF",
      airState.temperature,
      airState.mode.c_str(),
      airState.fanSpeed.c_str(),
      airState.verticalSwing.c_str(),
      airState.sleep ? "on" : "off");
}

// DHT11 อ่านทุก 5 วินาที ในช่วงที่สายแอร์ว่าง (ไลบรารีปิด interrupt ระหว่างอ่าน)
void readRoomTemperature() {
  if (millis() - lastDhtReadAt < DHT_READ_INTERVAL_MS) return;
  if (!wiredBus.quietWindow()) return;
  lastDhtReadAt = millis();
  const float t = dht.readTemperature();
  if (isnan(t)) {
    Serial.println("DHT11 read failed");
    return;
  }
  roomTemperatureC = t + ROOM_TEMP_OFFSET_C;
  wiredBus.setRoomTemp(roomTemperatureC);
}

void publishStatus() {
  if (!mqttClient.connected()) return;
  DynamicJsonDocument document(1024);
  document["online"] = true;
  document["deviceId"] = config.deviceId;
  document["firmwareVersion"] = FIRMWARE_VERSION;
  if (!lastOtaError.isEmpty()) document["otaError"] = lastOtaError;
  document["roomNumber"] = config.roomNumber;
  document["airNumber"] = config.airNumber;
  document["ip"] = WiFi.localIP().toString();
  document["rssi"] = WiFi.RSSI();
  document["pzemAvailable"] = powerMeasurements.available;
  document["acRunning"] = powerMeasurements.acRunning;
  document["outsideSchedule"] = powerMeasurements.outsideSchedule;
  document["scheduleConfigured"] =
      !config.dailyOn.isEmpty() && !config.dailyOff.isEmpty();
  document["classScheduleConfigured"] = classScheduleConfigured;
  // Backend จะไม่บันทึกประวัติจาก status สด จนกว่าข้อมูลย้อนหลังจะส่งครบ
  // ไม่งั้นพลังงานช่วงที่เน็ตหลุดจะถูกนับซ้ำสองครั้ง
  document["historyPending"] = historyLog.ready() ? historyLog.pending() : 0;
  // ค่าที่รุ่นสายแอร์มีเพิ่ม (Backend/แอปเดิมไม่อ่าน ไม่กระทบอะไร)
  const WiredBus::Status bus = wiredBus.status();
  document["controlMode"] = CONTROL_TYPE;
  document["airBrand"] = AIR_BRAND;
  document["busOk"] = bus.linkOk;
  document["compressorRunning"] = bus.compressor;
  if (bus.linkOk) document["unitRoomTemperature"] = bus.unitRoomC;
  if (isnan(roomTemperatureC)) document["roomTemperature"] = nullptr;
  else document["roomTemperature"] = roomTemperatureC;
  if (powerMeasurements.available) {
    document["voltage"] = powerMeasurements.voltage;
    document["current"] = powerMeasurements.current;
    document["powerWatts"] = powerMeasurements.powerWatts;
    document["energyKwh"] = powerMeasurements.energyKwh;
    document["frequencyHz"] = powerMeasurements.frequencyHz;
    document["powerFactor"] = powerMeasurements.powerFactor;
  } else {
    document["voltage"] = nullptr;
    document["current"] = nullptr;
    document["powerWatts"] = nullptr;
    document["energyKwh"] = nullptr;
    document["frequencyHz"] = nullptr;
    document["powerFactor"] = nullptr;
  }
  String payload;
  serializeJson(document, payload);
  if (mqttClient.publish(
      (config.mqttTopic + "/status").c_str(),
      payload.c_str(),
      true)) {
    statusPublishRequested = false;
  }
}

void publishState(const String &commandId) {
  oledDisplay.poke();   // ค่าที่สั่งเปลี่ยน วาดจอใหม่ทันที
  if (!mqttClient.connected()) return;
  DynamicJsonDocument document(768);
  if (!commandId.isEmpty()) document["commandId"] = commandId;
  JsonObject state = document.createNestedObject("state");
  state["power"] = airState.power;
  state["temperature"] = airState.temperature;
  state["mode"] = airState.mode;
  state["fanSpeed"] = airState.fanSpeed;
  state["verticalSwing"] = airState.verticalSwing;
  state["horizontalSwing"] = airState.horizontalSwing;
  state["eco"] = airState.eco;
  state["turbo"] = airState.turbo;
  state["sleep"] = airState.sleep;
  state["quiet"] = airState.quiet;
  state["displayLight"] = airState.displayLight;
  state["clean"] = airState.clean;
  if (airState.timerOnMinutes > 0) {
    state["timerOnMinutes"] = airState.timerOnMinutes;
  } else {
    state["timerOnMinutes"] = nullptr;
  }
  if (airState.timerOffMinutes > 0) {
    state["timerOffMinutes"] = airState.timerOffMinutes;
  } else {
    state["timerOffMinutes"] = nullptr;
  }
  String payload;
  serializeJson(document, payload);
  mqttClient.publish(
      (config.mqttTopic + "/state").c_str(),
      payload.c_str(),
      true);
}

void publishProvisioningToken() {
  if (!mqttClient.connected() || config.provisioningToken.isEmpty()) return;
  lastProvisionAt = millis();
  DynamicJsonDocument document(384);
  document["token"] = config.provisioningToken;
  document["deviceId"] = config.deviceId;
  document["roomNumber"] = config.roomNumber;
  document["airNumber"] = config.airNumber;
  String payload;
  serializeJson(document, payload);
  mqttClient.publish(
      (config.mqttTopic + "/provision").c_str(),
      payload.c_str(),
      true);
}

// ดาวน์โหลดเฟิร์มแวร์ใหม่แล้วรีบูต ถ้าไม่สำเร็จจะทำงานต่อด้วยเฟิร์มแวร์เดิม
// และรายงานสาเหตุผ่าน otaError ใน status
void performOtaUpdate() {
  otaRequested = false;
  const String url = pendingOtaUrl;
  pendingOtaUrl = "";
  Serial.printf("OTA: downloading %s\n", url.c_str());
  if (!ensureClockSynced()) {
    lastOtaError = "clock_not_synced";
    statusPublishRequested = true;
    return;
  }
  // ปิดการเชื่อมต่อ MQTT (TLS) ก่อน หน่วยความจำไม่พอเปิด TLS สองชุดพร้อมกัน
  // วงรอบ loop จะต่อ MQTT กลับเองถ้าอัปเดตไม่สำเร็จ
  if (mqttClient.connected()) mqttClient.disconnect();
  secureClient.stop();

  const String error = runHttpsOta(url, LETSENCRYPT_CA, FIRMWARE_VERSION);
  if (error.isEmpty()) {
    Serial.println("OTA: update written, restarting");
    delay(300);
    ESP.restart();
    return;
  }
  lastOtaError = error.substring(0, 100);
  Serial.printf("OTA failed: %s\n", lastOtaError.c_str());
  statusPublishRequested = true;
  lastMqttReconnectAttempt = 0;
}

void processTimers() {
  const uint32_t now = millis();
  if (timerOnAt != 0 && static_cast<int32_t>(now - timerOnAt) >= 0) {
    const AirState previousState = airState;
    timerOnAt = 0;
    airState.timerOnMinutes = -1;
    airState.power = true;
    saveAirState();
    sendCurrentAirState(&previousState);
    publishState();
  }
  if (timerOffAt != 0 && static_cast<int32_t>(now - timerOffAt) >= 0) {
    const AirState previousState = airState;
    timerOffAt = 0;
    airState.timerOffMinutes = -1;
    airState.power = false;
    saveAirState();
    sendCurrentAirState(&previousState);
    publishState();
  }
}

void processDailySchedule() {
  if (config.dailyOn.isEmpty() && config.dailyOff.isEmpty()) return;
  struct tm timeInfo;
  if (!getLocalTime(&timeInfo, 20)) return;
  const int minuteOfDay = timeInfo.tm_hour * 60 + timeInfo.tm_min;
  if (minuteOfDay == lastScheduleMinute) return;
  lastScheduleMinute = minuteOfDay;

  char current[6];
  snprintf(
      current,
      sizeof(current),
      "%02d:%02d",
      timeInfo.tm_hour,
      timeInfo.tm_min);
  bool changed = false;
  const AirState previousState = airState;
  if (config.dailyOn == current && !airState.power) {
    airState.power = true;
    changed = true;
  }
  if (config.dailyOff == current && airState.power) {
    airState.power = false;
    changed = true;
  }
  if (changed) {
    saveAirState();
    sendCurrentAirState(&previousState);
    publishState();
  }
}

void readPowerMeter() {
  const float voltage = pzem.voltage();
  const float current = pzem.current();
  const float powerWatts = pzem.power();
  const bool valid =
      !isnan(voltage) && !isnan(current) && !isnan(powerWatts);

  if (!valid) {
    if (powerMeasurements.failedSamples < UINT8_MAX) {
      powerMeasurements.failedSamples++;
    }
    if (powerMeasurements.failedSamples >= PZEM_FAILURE_LIMIT) {
      const bool wasAvailable = powerMeasurements.available;
      const bool wasRunning = powerMeasurements.acRunning;
      powerMeasurements.available = false;
      powerMeasurements.acRunning = false;
      powerMeasurements.outsideSchedule = false;
      powerMeasurements.runningSamples = 0;
      powerMeasurements.stoppedSamples = 0;
      if (wasAvailable || wasRunning) statusPublishRequested = true;
    }
    Serial.println("PZEM read failed");
    return;
  }

  const bool previousAvailable = powerMeasurements.available;
  const bool previousRunning = powerMeasurements.acRunning;
  const bool previousOutsideSchedule = powerMeasurements.outsideSchedule;
  powerMeasurements.available = true;
  powerMeasurements.failedSamples = 0;
  powerMeasurements.voltage = voltage;
  powerMeasurements.current = current;
  powerMeasurements.powerWatts = powerWatts;
  powerMeasurements.energyKwh = pzem.energy();
  powerMeasurements.frequencyHz = pzem.frequency();
  powerMeasurements.powerFactor = pzem.pf();

  if (powerWatts >= AC_RUNNING_ON_WATTS) {
    powerMeasurements.stoppedSamples = 0;
    if (powerMeasurements.runningSamples < AC_RUNNING_CONFIRM_SAMPLES) {
      powerMeasurements.runningSamples++;
    }
    if (powerMeasurements.runningSamples >= AC_RUNNING_CONFIRM_SAMPLES) {
      powerMeasurements.acRunning = true;
    }
  } else if (powerWatts <= AC_RUNNING_OFF_WATTS) {
    powerMeasurements.runningSamples = 0;
    if (powerMeasurements.stoppedSamples < AC_RUNNING_CONFIRM_SAMPLES) {
      powerMeasurements.stoppedSamples++;
    }
    if (powerMeasurements.stoppedSamples >= AC_RUNNING_CONFIRM_SAMPLES) {
      powerMeasurements.acRunning = false;
    }
  } else {
    // Values inside the hysteresis band keep the current state but do not
    // count toward either confirmation window.
    powerMeasurements.runningSamples = 0;
    powerMeasurements.stoppedSamples = 0;
  }

  powerMeasurements.outsideSchedule =
      powerMeasurements.acRunning && !isWithinAllowedSchedule();
  accumulateHistorySample();
  oledDisplay.pushPower(powerWatts);
  if (!previousAvailable ||
      previousRunning != powerMeasurements.acRunning ||
      previousOutsideSchedule != powerMeasurements.outsideSchedule) {
    statusPublishRequested = true;
  }

  Serial.printf(
      "PZEM: %.1f V, %.3f A, %.1f W, running=%s, outside_schedule=%s\n",
      powerMeasurements.voltage,
      powerMeasurements.current,
      powerMeasurements.powerWatts,
      powerMeasurements.acRunning ? "yes" : "no",
      powerMeasurements.outsideSchedule ? "yes" : "no");
}

void updateStatusLeds() {
  if (WiFi.status() == WL_CONNECTED) {
    yellowLedState = true;
  } else if (wifiConnectionInProgress) {
    if (lastYellowLedToggleAt == 0 ||
        millis() - lastYellowLedToggleAt >= YELLOW_LED_BLINK_INTERVAL_MS) {
      lastYellowLedToggleAt = millis();
      yellowLedState = !yellowLedState;
    }
  } else {
    yellowLedState = false;
  }

  const bool redOn =
      powerMeasurements.acRunning && powerMeasurements.outsideSchedule;
  // Green reports measured operation. Red is an additional schedule warning,
  // so both LEDs are on when the A/C is running outside the allowed time.
  const bool greenOn = powerMeasurements.acRunning;
  digitalWrite(GREEN_LED_PIN, greenOn ? HIGH : LOW);
  digitalWrite(RED_LED_PIN, redOn ? HIGH : LOW);
  digitalWrite(YELLOW_LED_PIN, yellowLedState ? HIGH : LOW);
  refreshOled();
}

bool isWithinConfiguredSchedule() {
  int startMinutes = 0;
  int endMinutes = 0;
  if (!parseMinutesOfDay(config.dailyOn, startMinutes) ||
      !parseMinutesOfDay(config.dailyOff, endMinutes)) {
    // Without a complete schedule, do not label normal use as a violation.
    return true;
  }

  struct tm timeInfo;
  if (!getLocalTime(&timeInfo, 20)) return true;
  const int nowMinutes = timeInfo.tm_hour * 60 + timeInfo.tm_min;
  if (startMinutes == endMinutes) return true;
  if (startMinutes < endMinutes) {
    return nowMinutes >= startMinutes && nowMinutes < endMinutes;
  }
  // A schedule such as 22:00-06:00 crosses midnight.
  return nowMinutes >= startMinutes || nowMinutes < endMinutes;
}

bool isWithinAllowedSchedule() {
  const bool classScheduleFresh =
      classScheduleReceivedAt != 0 &&
      millis() - classScheduleReceivedAt <= CLASS_SCHEDULE_TTL_MS;
  if (classScheduleFresh && classScheduleConfigured) {
    return withinClassSchedule;
  }
  return isWithinConfiguredSchedule();
}

bool parseMinutesOfDay(const String &value, int &minutes) {
  if (value.length() != 5 || value.charAt(2) != ':') return false;
  const int hour = value.substring(0, 2).toInt();
  const int minute = value.substring(3, 5).toInt();
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return false;
  minutes = hour * 60 + minute;
  return true;
}

// ---------------------------------------------------------------------------
// ข้อมูลย้อนหลังตอนเน็ตหลุด
//
// 1. ทุกครั้งที่อ่าน PZEM ได้ จะสะสมค่าไว้ในช่วง 5 นาทีปัจจุบัน
// 2. ครบ 5 นาที (ตรงนาทีที่ 0, 5, 10, ... ตามนาฬิกา) ถ้าต่อ MQTT ไม่ได้
//    หรือยังมีข้อมูลเก่าค้างส่ง จะเขียนสรุปช่วงนั้นลง flash
// 3. ต่อ MQTT ได้แล้ว ส่งทีละ 10 รายการ รอ Backend ตอบ history-ack
//    แล้วลบรายการที่ยืนยันแล้วทิ้ง จึงส่งชุดถัดไป
// ต้องรู้เวลาจริง (NTP) ก่อน ถ้าบอร์ดบูตตอนไม่มีเน็ตเลยจะยังเก็บไม่ได้
// ---------------------------------------------------------------------------

void initHistoryLog() {
  historyFlash.partition = esp_partition_find_first(
      ESP_PARTITION_TYPE_DATA,
      static_cast<esp_partition_subtype_t>(HISTORY_PARTITION_SUBTYPE),
      "rmuttlog");
  if (historyFlash.partition == nullptr) {
    Serial.println(
        "Offline history disabled: partition rmuttlog not found "
        "(flash partitions.csv via USB)");
    return;
  }
  preferences.begin("rmutt-state", true);
  const uint32_t ackedTs = preferences.getUInt("hist_ack", 0);
  preferences.end();
  if (!historyLog.begin(ackedTs)) {
    Serial.println("Offline history disabled: partition is too small");
    return;
  }
  Serial.printf(
      "Offline history: %u pending of %u slots\n",
      static_cast<unsigned>(historyLog.pending()),
      static_cast<unsigned>(historyLog.capacity()));
}

void resetHistoryInterval(uint32_t endTs) {
  historyInterval = HistoryInterval();
  historyInterval.endTs = endTs;
  historyInterval.lastSampleMs = millis();
}

void accumulateHistorySample() {
  if (historyInterval.endTs == 0) return;
  HistoryInterval &h = historyInterval;
  const uint32_t now = millis();
  const uint32_t elapsed = now - h.lastSampleMs;
  h.lastSampleMs = now;
  // นับเวลาทำงานตามจริงระหว่างสองครั้งที่อ่าน แต่ไม่เกิน 10 วินาทีต่อครั้ง
  if (powerMeasurements.acRunning) h.runtimeMs += min(elapsed, 10000UL);

  const float v = powerMeasurements.voltage;
  const float i = powerMeasurements.current;
  const float p = powerMeasurements.powerWatts;
  h.samples++;
  h.voltageSum += v;
  h.currentSum += i;
  h.powerSum += p;
  if (!isnan(powerMeasurements.powerFactor)) {
    h.powerFactorSum += powerMeasurements.powerFactor;
  }
  if (!isnan(powerMeasurements.frequencyHz)) {
    h.frequencySum += powerMeasurements.frequencyHz;
  }
  h.voltageMin = isnan(h.voltageMin) ? v : min(h.voltageMin, v);
  h.voltageMax = isnan(h.voltageMax) ? v : max(h.voltageMax, v);
  h.currentMax = isnan(h.currentMax) ? i : max(h.currentMax, i);
  h.powerMin = isnan(h.powerMin) ? p : min(h.powerMin, p);
  h.powerMax = isnan(h.powerMax) ? p : max(h.powerMax, p);
  if (!isnan(powerMeasurements.energyKwh)) {
    h.energyKwh = powerMeasurements.energyKwh;
  }
}

uint16_t scaledU16(double value, double scale) {
  if (isnan(value) || value <= 0) return 0;
  const double scaled = value * scale + 0.5;
  return scaled >= 65535.0 ? 65535 : static_cast<uint16_t>(scaled);
}

uint8_t scaledU8(double value, double offset, double scale) {
  if (isnan(value)) return 0;
  const double scaled = (value - offset) * scale + 0.5;
  if (scaled <= 0) return 0;
  return scaled >= 255.0 ? 255 : static_cast<uint8_t>(scaled);
}

void finalizeHistoryInterval() {
  if (!historyLog.ready()) return;
  const time_t now = time(nullptr);
  if (now < 1700000000) return;
  const uint32_t nowTs = static_cast<uint32_t>(now);
  const uint32_t nextBoundary =
      (nowTs / HISTORY_INTERVAL_SECONDS + 1) * HISTORY_INTERVAL_SECONDS;
  if (historyInterval.endTs == 0) {
    // ช่วงแรกหลังรู้เวลา เริ่มนับจากตอนนี้จนถึงรอบ 5 นาทีถัดไป
    resetHistoryInterval(nextBoundary);
    return;
  }
  if (nowTs < historyInterval.endTs) return;

  const HistoryInterval &h = historyInterval;
  const bool shouldStore =
      !mqttClient.connected() || historyLog.pending() > 0;
  if (shouldStore && h.samples > 0 && !isnan(h.energyKwh)) {
    HistoryRecord record;
    memset(&record, 0, sizeof(record));
    record.ts = h.endTs;
    record.energyKwh = h.energyKwh;
    record.voltageAvg10 = scaledU16(h.voltageSum / h.samples, 10);
    record.voltageMin10 = scaledU16(h.voltageMin, 10);
    record.voltageMax10 = scaledU16(h.voltageMax, 10);
    record.currentAvg1000 = scaledU16(h.currentSum / h.samples, 1000);
    record.currentMax1000 = scaledU16(h.currentMax, 1000);
    record.powerAvg10 = scaledU16(h.powerSum / h.samples, 10);
    record.powerMin10 = scaledU16(h.powerMin, 10);
    record.powerMax10 = scaledU16(h.powerMax, 10);
    record.powerFactor100 = scaledU8(h.powerFactorSum / h.samples, 0, 100);
    record.frequencyOffset10 =
        scaledU8(h.frequencySum / h.samples, 40, 10);
    record.runtimeSeconds = static_cast<uint16_t>(
        min(h.runtimeMs / 1000UL, static_cast<unsigned long>(
                                      HISTORY_INTERVAL_SECONDS)));
    record.samples = static_cast<uint8_t>(min<uint16_t>(h.samples, 255));
    record.flags = powerMeasurements.acRunning ? 1 : 0;
    if (historyLog.append(record)) {
      Serial.printf(
          "Offline history stored (%u pending)\n",
          static_cast<unsigned>(historyLog.pending()));
    } else {
      Serial.println("Offline history: could not store record");
    }
  }
  // ถ้าข้ามไปหลายรอบ (เช่นแก้เวลา) ให้เริ่มรอบถัดจากเวลาปัจจุบัน
  resetHistoryInterval(nextBoundary);
}

void processHistoryUpload() {
  if (!historyLog.ready() || historyLog.pending() == 0) return;
  const uint32_t now = millis();
  if (historyAwaitingAck) {
    if (now - historySentAt < HISTORY_ACK_TIMEOUT_MS) return;
    // ไม่ได้คำตอบ ส่งชุดเดิมใหม่ Backend ข้ามรายการที่เคยบันทึกแล้วให้เอง
    Serial.println("Offline history: no acknowledgement, will resend");
    historyAwaitingAck = false;
    historyNextSendAt = now + HISTORY_RETRY_DELAY_MS;
    return;
  }
  if (static_cast<int32_t>(now - historyNextSendAt) < 0) return;

  HistoryRecord batch[HISTORY_BATCH_SIZE];
  const size_t count = historyLog.nextBatch(batch, HISTORY_BATCH_SIZE);
  if (count == 0) return;

  DynamicJsonDocument document(4096);
  document["v"] = 1;
  document["deviceId"] = config.deviceId;
  JsonArray records = document.createNestedArray("records");
  for (size_t index = 0; index < count; index++) {
    const HistoryRecord &r = batch[index];
    JsonArray row = records.createNestedArray();
    row.add(r.ts);
    row.add(r.energyKwh);
    row.add(r.voltageAvg10);
    row.add(r.voltageMin10);
    row.add(r.voltageMax10);
    row.add(r.currentAvg1000);
    row.add(r.currentMax1000);
    row.add(r.powerAvg10);
    row.add(r.powerMin10);
    row.add(r.powerMax10);
    row.add(r.powerFactor100);
    row.add(r.frequencyOffset10);
    row.add(r.runtimeSeconds);
    row.add(r.samples);
    row.add(r.flags);
  }
  String payload;
  serializeJson(document, payload);
  if (mqttClient.publish(
          (config.mqttTopic + "/history").c_str(), payload.c_str(), false)) {
    historyAwaitingAck = true;
    historySentAt = now;
  } else {
    historyNextSendAt = now + HISTORY_RETRY_DELAY_MS;
  }
}

void applyHistoryAck() {
  historyAckReady = false;
  historyAwaitingAck = false;
  historyNextSendAt = millis() + HISTORY_SEND_GAP_MS;
  const uint32_t upTo = historyPendingAckTs;
  if (upTo == 0 || upTo <= historyLog.ackedTs()) return;
  if (!historyLog.acknowledge(upTo)) {
    Serial.println("Offline history: flash erase failed");
    return;
  }
  preferences.begin("rmutt-state", false);
  preferences.putUInt("hist_ack", historyLog.ackedTs());
  preferences.end();
  if (historyLog.pending() == 0) {
    Serial.println("Offline history: all records sent and erased");
    statusPublishRequested = true;
  }
}

// ---------------------------------------------------------------------------
// จอ OLED 1.3" (SH1106 I2C, SDA GPIO21 / SCL GPIO22) — แบบ 1 "ตัวเลขใหญ่"
// เปลี่ยนแบบได้ที่ OLED_LAYOUT ใน oled_display.h (1-5)
// ---------------------------------------------------------------------------
void refreshOled() {
  if (!oledDisplay.due()) return;
  static char clockText[6];
  static char ipText[16];
  struct tm timeInfo;
  if (getLocalTime(&timeInfo, 0)) {
    snprintf(clockText, sizeof(clockText), "%02d:%02d", timeInfo.tm_hour, timeInfo.tm_min);
  } else {
    clockText[0] = '\0';
  }
  snprintf(ipText, sizeof(ipText), "%s", WiFi.localIP().toString().c_str());

  OledData d;
  d.room = config.roomNumber.c_str();
  d.airNo = config.airNumber;
  d.power = airState.power;
  d.setC = airState.temperature;
  d.mode = airState.mode.c_str();
  d.fan = airState.fanSpeed.c_str();
  d.swing = airState.verticalSwing != "off";
  d.sleep = airState.sleep;
  d.pzemOk = powerMeasurements.available;
  d.watts = powerMeasurements.available ? powerMeasurements.powerWatts : NAN;
  d.kwh = powerMeasurements.available ? powerMeasurements.energyKwh : NAN;
  d.volts = powerMeasurements.available ? powerMeasurements.voltage : NAN;
  d.amps = powerMeasurements.available ? powerMeasurements.current : NAN;
  d.pf = powerMeasurements.available ? powerMeasurements.powerFactor : NAN;
  d.hz = powerMeasurements.available ? powerMeasurements.frequencyHz : NAN;
  d.acRunning = powerMeasurements.acRunning;
  d.outsideSchedule = powerMeasurements.outsideSchedule;
  d.wifiOk = WiFi.status() == WL_CONNECTED;
  d.mqttOk = mqttClient.connected();
  d.rssi = d.wifiOk ? WiFi.RSSI() : -100;
  d.ssid = config.wifiSsid.c_str();
  d.ip = d.wifiOk ? ipText : "";
  d.clock = clockText;
  d.fw = FIRMWARE_VERSION;
  d.deviceId = config.deviceId.c_str();
  const WiredBus::Status bus = wiredBus.status();
  d.wired = true;
  d.busOk = bus.linkOk;
  d.compressor = bus.compressor;
  d.roomC = roomTemperatureC;
  if (bleBlocksNormalOperation) {
    oledDisplay.show(OledDisplay::SETUP, d, config.bleName.c_str(), oledReason.c_str());
  } else if (wifiConnectionInProgress) {
    oledDisplay.show(OledDisplay::CONNECTING, d, config.wifiSsid.c_str());
  } else if (!bus.linkOk && millis() > 15000 && (millis() / 3000) % 2 == 0) {
    // แอร์ไม่ตอบทางสาย: สลับหน้าเตือนกับหน้าปกติทุก 3 วินาที
    oledDisplay.show(OledDisplay::ALERT, d, "AIRCON BUS", "No reply from unit", "Check bus wires");
  } else {
    oledDisplay.show(OledDisplay::NORMAL, d);
  }
}
