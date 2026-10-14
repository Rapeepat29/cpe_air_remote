/*
 * RMUTT Save Energy - ESP32 + HLK-LD2410 room occupancy sensor
 *
 * One board is assigned to one room. The only radar measurement used for the
 * application decision is stationary energy in engineering-mode gates 0..8.
 * If any gate is greater than 25, occupied=true; otherwise occupied=false.
 * Moving energy, target distance and all other LD2410 measurements are ignored.
 *
 * First setup/reconfiguration uses BLE. Normal reporting uses MQTT over Wi-Fi.
 * Firmware can be updated over Wi-Fi (HTTPS OTA) on command from the backend.
 * Hold BOOT (GPIO0) while resetting to reopen BLE setup mode.
 */

#include <Arduino.h>
#include <ArduinoJson.h>
#include <BLE2902.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <Preferences.h>
#include <PubSubClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>

#include "letsencrypt_ca.h"
#include "ota_update.h"
#include <ld2410.h>
#include <time.h>

constexpr uint8_t SETUP_BUTTON_PIN = 0;
constexpr uint8_t RADAR_RX_PIN = 32;  // ESP32 RX <- LD2410 TX
constexpr uint8_t RADAR_TX_PIN = 33;  // ESP32 TX -> LD2410 RX
constexpr uint32_t RADAR_BAUD = 256000;
constexpr uint8_t STATIC_ENERGY_THRESHOLD = 25;
constexpr uint8_t FIRST_GATE = 0;
constexpr uint8_t LAST_GATE = 8;
constexpr uint32_t PRESENCE_READ_INTERVAL_MS = 250;
constexpr uint32_t STATUS_INTERVAL_MS = 10000;
constexpr uint32_t WIFI_TIMEOUT_MS = 20000;
constexpr uint32_t WIFI_PROVISION_TIMEOUT_MS = 15000;
// ระหว่างเปิด BLE เพราะ Wi-Fi ล้ม ให้ลองต่อ Wi-Fi เดิมซ้ำทุกช่วงเวลานี้
constexpr uint32_t WIFI_RECOVERY_RETRY_MS = 30UL * 1000UL;
// เวลารอต่อ Wi-Fi ของการลองเบื้องหลัง สั้นกว่าปกติเพื่อไม่ให้ค้างนาน
constexpr uint32_t WIFI_RECOVERY_ATTEMPT_MS = 8000;
// ถ้าเริ่มต้น LD2410 ไม่สำเร็จ ให้ลองใหม่เป็นระยะ ไม่ต้องรีบูตบอร์ด
constexpr uint32_t RADAR_RETRY_INTERVAL_MS = 10000;
// พิมพ์สรุปสถานะทุกค่าที่มักเป็นต้นเหตุปัญหา ทุก ๆ ช่วงเวลานี้
constexpr uint32_t DIAGNOSTIC_INTERVAL_MS = 10000;
constexpr size_t RADAR_RAW_PREVIEW_BYTES = 16;
// ถือว่าเรดาร์ยังใช้งานได้ ถ้าเพิ่งได้ข้อมูลชุดใหม่ภายในเวลานี้
// กันไม่ให้สถานะกระพริบเมื่อเฟรมใดเฟรมหนึ่งมาช้าหรือถูกอ่านไปแล้ว
constexpr uint32_t RADAR_DATA_TIMEOUT_MS = 3000;
constexpr uint32_t BLE_READVERTISE_DELAY_MS = 600;
constexpr uint32_t ONLINE_SETUP_WINDOW_MS = 5UL * 60UL * 1000UL;
constexpr size_t MAX_CONFIG_BYTES = 3072;
constexpr uint32_t NTP_SYNC_TIMEOUT_MS = 15000;
constexpr char FIRMWARE_VERSION[] = "1.3.2";

// The service layout is shared with the A/C board, while the advertised name
// and identity clearly distinguish RMUTT-OCC devices.
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
  String wifiSsid;
  String wifiPassword;
  String mqttHost;
  uint16_t mqttPort = 1883;
  String mqttUsername;
  String mqttPassword;
  bool mqttTls = false;
  String mqttTopic;
  String provisioningToken;
};

Preferences preferences;
WiFiClient wifiClient;
WiFiClientSecure secureClient;
bool clockSynced = false;
PubSubClient mqttClient(wifiClient);
HardwareSerial radarSerial(1);
ld2410 radar;
DeviceConfig config;

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

bool radarInitialised = false;
bool radarEngineeringEnabled = false;
bool radarAvailable = false;
bool occupied = false;
bool statusPublishRequested = true;
bool provisionAckClearReady = false;
uint32_t lastPresenceReadAt = 0;
uint32_t lastStatusAt = 0;
uint32_t lastProvisionAt = 0;
uint32_t lastMqttReconnectAttempt = 0;
uint32_t lastRadarRetryAt = 0;
bool radarFailureReported = false;
uint32_t lastDiagnosticAt = 0;
uint32_t lastRadarDataAt = 0;
bool lastRadarDetected = false;
uint32_t radarRawByteCount = 0;
uint8_t radarRawPreview[RADAR_RAW_PREVIEW_BYTES];
uint8_t radarRawPreviewLength = 0;
bool wifiRecoveryActive = false;
uint32_t lastWifiRecoveryAttemptAt = 0;
String pendingOtaUrl;
bool otaRequested = false;
bool unprovisionRequested = false;
String lastOtaError;

String createDeviceId();
bool isValidRoomNumber(const String &value);
void loadConfig();
void saveConfig(const DeviceConfig &newConfig);
bool keepsServerAssignment(const DeviceConfig &incoming);
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
void unprovisionAndRestart(const String &reason);
void initialiseRadar();
void updateOccupancy();
void captureRadarRawBytes();
void printDiagnostics();
void publishStatus();
void publishProvisioningToken();
void performOtaUpdate();

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *server) override {
    bleClientConnected = true;
    bleReadvertisePending = false;
  }

  void onDisconnect(BLEServer *server) override {
    bleClientConnected = false;
    if (bleAdvertisingEnabled) {
      bleReadvertiseAt = millis() + BLE_READVERTISE_DELAY_MS;
      bleReadvertisePending = true;
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
  delay(80);

  config.deviceId = createDeviceId();
  config.bleName = "RMUTT-OCC-" + config.deviceId.substring(6);
  Serial.println();
  Serial.println("RMUTT ESP32 LD2410 Occupancy Sensor");
  Serial.printf("Firmware: %s\n", FIRMWARE_VERSION);
  Serial.printf("Device ID: %s\n", config.deviceId.c_str());
  Serial.printf(
      "Rule: occupied when any static gate 0-8 is greater than %u\n",
      STATIC_ENERGY_THRESHOLD);

  radarSerial.begin(
      RADAR_BAUD,
      SERIAL_8N1,
      RADAR_RX_PIN,
      RADAR_TX_PIN);
  initialiseRadar();
  loadConfig();
  mqttClient.setBufferSize(1024);
  mqttClient.setCallback(mqttCallback);

  const bool setupRequested = digitalRead(SETUP_BUTTON_PIN) == LOW;
  if (!config.configured || setupRequested) {
    enterBleRecovery(
        setupRequested ? "BOOT button requested setup" : "No saved configuration");
    return;
  }
  if (!connectWifi()) {
    enterBleRecovery("Stored Wi-Fi could not connect", true);
    return;
  }
  connectMqtt();
}

void loop() {
  if ((!radarInitialised || !radarEngineeringEnabled) &&
      millis() - lastRadarRetryAt >= RADAR_RETRY_INTERVAL_MS) {
    lastRadarRetryAt = millis();
    initialiseRadar();
  }
  if (!radarInitialised) {
    captureRadarRawBytes();
  } else if (!radar.isAutoReadTaskRunning()) {
    radar.read();
  }
  if (millis() - lastDiagnosticAt >= DIAGNOSTIC_INTERVAL_MS) {
    lastDiagnosticAt = millis();
    printDiagnostics();
  }
  if (millis() - lastPresenceReadAt >= PRESENCE_READ_INTERVAL_MS) {
    lastPresenceReadAt = millis();
    updateOccupancy();
  }

  if (bleAdvertisingEnabled &&
      !bleBlocksNormalOperation &&
      onlineSetupExpiresAt != 0 &&
      static_cast<int32_t>(millis() - onlineSetupExpiresAt) >= 0 &&
      !bleClientConnected) {
    bleAdvertisingEnabled = false;
    bleReadvertisePending = false;
    BLEDevice::getAdvertising()->stop();
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
    delay(5);
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
            (config.mqttTopic + "/provision-ack").c_str(), "", true)) {
      provisionAckClearReady = false;
    }
    if (!config.provisioningToken.isEmpty() &&
        millis() - lastProvisionAt >= 10000) {
      publishProvisioningToken();
    }
    if (statusPublishRequested ||
        millis() - lastStatusAt >= STATUS_INTERVAL_MS) {
      lastStatusAt = millis();
      publishStatus();
    }
  }
  if (unprovisionRequested) unprovisionAndRestart("removed from the app");
  if (otaRequested) performOtaUpdate();
  delay(5);
}

String createDeviceId() {
  const uint64_t chipId = ESP.getEfuseMac();
  char buffer[20];
  snprintf(
      buffer,
      sizeof(buffer),
      "OCC32-%04X%08X",
      static_cast<uint16_t>(chipId >> 32),
      static_cast<uint32_t>(chipId));
  return String(buffer);
}

bool isValidRoomNumber(const String &value) {
  if (value.length() < 2 || value.length() > 20) return false;
  for (size_t index = 0; index < value.length(); index++) {
    const char character = value.charAt(index);
    const bool valid =
        (character >= 'A' && character <= 'Z') ||
        (character >= '0' && character <= '9') ||
        character == '_' || character == '-';
    if (!valid) return false;
  }
  return true;
}

void loadConfig() {
  preferences.begin("rmutt-occ", true);
  config.configured = preferences.getBool("configured", false);
  config.roomNumber = preferences.getString("room", "");
  config.wifiSsid = preferences.getString("wifi_ssid", "");
  config.wifiPassword = preferences.getString("wifi_pass", "");
  config.mqttHost = preferences.getString("mqtt_host", "");
  config.mqttPort = preferences.getUShort("mqtt_port", 1883);
  config.mqttUsername = preferences.getString("mqtt_user", "");
  config.mqttPassword = preferences.getString("mqtt_pass", "");
  config.mqttTls = preferences.getBool("mqtt_tls", false);
  config.mqttTopic = preferences.getString("mqtt_topic", "");
  config.provisioningToken = preferences.getString("prov_token", "");
  preferences.end();
}

void saveConfig(const DeviceConfig &incoming) {
  preferences.begin("rmutt-occ", false);
  preferences.putBool("configured", true);
  preferences.putString("room", incoming.roomNumber);
  preferences.putString("wifi_ssid", incoming.wifiSsid);
  preferences.putString("wifi_pass", incoming.wifiPassword);
  preferences.putString("mqtt_host", incoming.mqttHost);
  preferences.putUShort("mqtt_port", incoming.mqttPort);
  preferences.putString("mqtt_user", incoming.mqttUsername);
  preferences.putString("mqtt_pass", incoming.mqttPassword);
  preferences.putBool("mqtt_tls", incoming.mqttTls);
  preferences.putString("mqtt_topic", incoming.mqttTopic);
  preferences.putString("prov_token", incoming.provisioningToken);
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

  BLECharacteristic *configCharacteristic = service->createCharacteristic(
      CONFIG_UUID, BLECharacteristic::PROPERTY_WRITE);
  configCharacteristic->setCallbacks(new ConfigCallbacks());
  statusCharacteristic = service->createCharacteristic(
      STATUS_UUID,
      BLECharacteristic::PROPERTY_READ |
          BLECharacteristic::PROPERTY_NOTIFY);
  statusCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic *identityCharacteristic = service->createCharacteristic(
      IDENTITY_UUID, BLECharacteristic::PROPERTY_READ);
  DynamicJsonDocument identity(256);
  identity["deviceId"] = config.deviceId;
  identity["bleName"] = config.bleName;
  identity["deviceType"] = "occupancy";
  identity["firmwareVersion"] = FIRMWARE_VERSION;
  identity["configured"] = config.configured;
  if (config.configured) identity["roomNumber"] = config.roomNumber;
  String identityJson;
  serializeJson(identity, identityJson);
  identityCharacteristic->setValue(identityJson.c_str());

  BLECharacteristic *settingsCharacteristic = service->createCharacteristic(
      SETTINGS_UUID, BLECharacteristic::PROPERTY_READ);
  DynamicJsonDocument settings(512);
  settings["roomNumber"] = config.roomNumber;
  settings["wifiSsid"] = config.wifiSsid;
  settings["hasWifiPassword"] = !config.wifiPassword.isEmpty();
  settings["mqttHost"] = config.mqttHost;
  settings["mqttPort"] = config.mqttPort;
  settings["mqttUsername"] = config.mqttUsername;
  settings["hasMqttPassword"] = !config.mqttPassword.isEmpty();
  String settingsJson;
  serializeJson(settings, settingsJson);
  settingsCharacteristic->setValue(settingsJson.c_str());

  BLECharacteristic *wifiScanCharacteristic = service->createCharacteristic(
      WIFI_SCAN_UUID, BLECharacteristic::PROPERTY_READ);
  wifiScanCharacteristic->setCallbacks(new WifiScanCallbacks());
  wifiScanCharacteristic->setValue("{\"ok\":true,\"networks\":[]}");

  service->start();
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->addServiceUUID(SERVICE_UUID);
  advertising->setScanResponse(true);
  advertising->setMinPreferred(0x06);
  advertising->setMinPreferred(0x12);
  startBleAdvertising();
}

void startBleAdvertising() {
  if (!bleProvisioningActive || !bleAdvertisingEnabled || bleClientConnected) {
    return;
  }
  BLEAdvertising *advertising = BLEDevice::getAdvertising();
  advertising->stop();
  delay(80);
  advertising->start();
  Serial.printf("BLE setup active: %s\n", config.bleName.c_str());
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
  Serial.printf("BLE recovery: %s\n", reason.c_str());
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
  Serial.printf("Online BLE setup: %s\n", reason.c_str());
  bleBlocksNormalOperation = false;
  onlineSetupExpiresAt = millis() + ONLINE_SETUP_WINDOW_MS;
  // เปิดจากคำสั่ง MQTT ของ Backend (เฉพาะแอดมิน) แก้ได้ทุกช่อง
  bleWifiOnlyMode = false;
  startBleProvisioning();
}

// ค่าที่ห้ามเปลี่ยนในโหมดกู้ Wi-Fi: ห้อง และบัญชี/เซิร์ฟเวอร์ MQTT
// ถ้าเปลี่ยนได้ คนแปลกหน้าที่อยู่ใกล้บอร์ดตอน Wi-Fi หลุดจะชี้บอร์ดไปหา
// MQTT ของตัวเองแล้วส่งสถานะห้องปลอมได้
bool keepsServerAssignment(const DeviceConfig &incoming) {
  return incoming.roomNumber == config.roomNumber &&
         incoming.mqttHost == config.mqttHost &&
         incoming.mqttPort == config.mqttPort &&
         incoming.mqttTls == config.mqttTls &&
         incoming.mqttUsername == config.mqttUsername &&
         incoming.mqttPassword == config.mqttPassword &&
         incoming.mqttTopic == config.mqttTopic;
}

void processPendingConfig() {
  configReady = false;
  DynamicJsonDocument document(3072);
  const DeserializationError error =
      deserializeJson(document, pendingConfig);
  pendingConfig = "";
  if (error) {
    notifyBle(false, "invalid_json", "Configuration JSON is invalid");
    return;
  }

  DeviceConfig incoming = config;
  incoming.deviceId = document["deviceId"] | "";
  incoming.roomNumber = document["roomNumber"] | "";
  incoming.provisioningToken = document["token"] | "";
  incoming.wifiSsid = document["wifi"]["ssid"] | "";
  const bool keepWifiPassword =
      document["wifi"]["keepPassword"] | false;
  incoming.wifiPassword =
      keepWifiPassword && incoming.wifiSsid == config.wifiSsid
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

  const bool valid =
      incoming.deviceId == config.deviceId &&
      isValidRoomNumber(incoming.roomNumber) &&
      !incoming.provisioningToken.isEmpty() &&
      !incoming.wifiSsid.isEmpty() &&
      incoming.wifiPassword.length() >= 8 &&
      !incoming.mqttHost.isEmpty() &&
      !incoming.mqttTopic.isEmpty();
  if (!valid) {
    notifyBle(false, "invalid_config", "Required settings are invalid");
    return;
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

  const bool onlineReconfiguration =
      config.configured && !bleBlocksNormalOperation;
  if (onlineReconfiguration && mqttClient.connected()) mqttClient.disconnect();
  if (!connectWifiCredentials(
          incoming.wifiSsid,
          incoming.wifiPassword,
          WIFI_PROVISION_TIMEOUT_MS)) {
    notifyBle(
        false,
        "wifi_connection_failed",
        "Unable to connect to Wi-Fi. Check the SSID and password.");
    if (onlineReconfiguration && connectWifi()) connectMqtt();
    return;
  }

  incoming.configured = true;
  incoming.bleName = config.bleName;
  saveConfig(incoming);
  config = incoming;
  notifyBle(
      true,
      "config_saved",
      "Wi-Fi verified and occupancy sensor configuration saved");
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
      config.wifiSsid, config.wifiPassword, WIFI_TIMEOUT_MS);
}

bool connectWifiCredentials(
    const String &ssid,
    const String &password,
    uint32_t timeoutMs) {
  if (ssid.isEmpty()) return false;
  WiFi.disconnect(false, false);
  delay(100);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), password.c_str());
  const uint32_t startedAt = millis();
  while (WiFi.status() != WL_CONNECTED &&
         millis() - startedAt < timeoutMs) {
    if (!radar.isAutoReadTaskRunning()) radar.read();
    const wl_status_t status = WiFi.status();
    if (status == WL_CONNECT_FAILED || status == WL_NO_SSID_AVAIL) break;
    delay(20);
  }
  if (WiFi.status() != WL_CONNECTED) {
    WiFi.disconnect(false, false);
    return false;
  }
  Serial.printf("Wi-Fi connected: %s\n", WiFi.localIP().toString().c_str());
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
      "Connecting MQTT: %s:%u as %s\n",
      config.mqttHost.c_str(),
      config.mqttPort,
      config.mqttUsername.isEmpty() ? "(no user)" : config.mqttUsername.c_str());
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
  const String clientId = "rmutt-occ-" + config.deviceId;
  DynamicJsonDocument offline(160);
  offline["online"] = false;
  offline["deviceId"] = config.deviceId;
  offline["radarAvailable"] = false;
  offline["occupied"] = false;
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
    Serial.printf("MQTT connection failed, state: %d\n", mqttClient.state());
    return;
  }
  mqttClient.subscribe((config.mqttTopic + "/command").c_str(), 1);
  mqttClient.subscribe((config.mqttTopic + "/provision-ack").c_str(), 1);
  Serial.println("MQTT connected");
  Serial.printf("Subscribed: %s/command\n", config.mqttTopic.c_str());
  publishStatus();
  publishProvisioningToken();
}

void mqttCallback(char *topic, byte *payload, unsigned int length) {
  if (length == 0 || length > 1024) return;
  const String incomingTopic(topic);
  DynamicJsonDocument document(768);
  if (deserializeJson(document, payload, length)) return;

  if (incomingTopic == config.mqttTopic + "/provision-ack") {
    const String acknowledgedToken = document["token"] | "";
    if (document["activated"] == true &&
        !config.provisioningToken.isEmpty() &&
        acknowledgedToken == config.provisioningToken) {
      preferences.begin("rmutt-occ", false);
      preferences.remove("prov_token");
      preferences.end();
      config.provisioningToken = "";
      provisionAckClearReady = true;
    }
    return;
  }
  if (incomingTopic != config.mqttTopic + "/command") return;
  const String action = document["action"] | "";
  if (action == "enter_setup") {
    enterBleReconfiguration("Flutter app requested reconfiguration");
    return;
  }
  if (action == "unprovision") {
    // Backend ส่งมาเมื่อแอดมินกดนำเซ็นเซอร์ออกในแอป
    // ตรวจ deviceId ซ้ำอีกชั้น กันข้อความหลงมาผิด topic
    // ทำต่อใน loop ไม่ใช่ใน callback เพราะต้อง publish และตัด MQTT
    const String target = document["deviceId"] | "";
    if (target != config.deviceId) {
      Serial.printf("Unprovision ignored: deviceId '%s' is not this board\n", target.c_str());
      return;
    }
    unprovisionRequested = true;
    return;
  }
  if (action == "ota") {
    // ทำใน loop ไม่ใช่ใน callback เพราะต้องตัดการเชื่อมต่อ MQTT ก่อนดาวน์โหลด
    const String url = document["url"] | "";
    if (!otaUrlAllowed(url, config.mqttHost)) {
      Serial.printf("OTA rejected: URL not allowed: %s\n", url.c_str());
      lastOtaError = "url_rejected";
      statusPublishRequested = true;
      return;
    }
    pendingOtaUrl = url;
    otaRequested = true;
  }
}

// ---------------------------------------------------------------------------
// ล้างบอร์ดเมื่อถูกนำออกจากแอป (คำสั่ง {"action":"unprovision"})
// ลบค่าทั้งหมดใน NVS (Wi-Fi, MQTT, ห้อง) แล้วรีบูต บอร์ดกลับเป็นสภาพเหมือนใหม่
// รอตั้งค่าผ่านบลูทูธ  Device ID ไม่เปลี่ยน เพราะสร้างจาก eFuse MAC
// ---------------------------------------------------------------------------
void unprovisionAndRestart(const String &reason) {
  unprovisionRequested = false;
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
    mqttClient.loop();
    delay(300);
    mqttClient.disconnect();
  }

  preferences.begin("rmutt-occ", false);
  preferences.clear();
  preferences.end();

  Serial.println("Unprovision: done, restarting into BLE setup mode");
  delay(300);
  ESP.restart();
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
  // หน่วยความจำไม่พอเปิด TLS สองชุดพร้อมกัน ปิด MQTT ก่อน loop จะต่อกลับเอง
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

void initialiseRadar() {
  radarInitialised = radar.begin(radarSerial);
  if (!radarInitialised) {
    if (!radarFailureReported) {
      Serial.printf(
          "LD2410 not detected on UART1 %u baud "
          "(module TX -> GPIO%u, module RX -> GPIO%u, VCC 5V, GND shared)\n",
          RADAR_BAUD,
          RADAR_RX_PIN,
          RADAR_TX_PIN);
      Serial.println("LD2410 retry every 10s; no reboot needed once wired");
      radarFailureReported = true;
    }
    return;
  }
  lastRadarDataAt = 0;
  lastRadarDetected = false;
  radarEngineeringEnabled = radar.requestStartEngineeringMode();
  if (!radarEngineeringEnabled) {
    if (!radarFailureReported) {
      Serial.println("LD2410 engineering mode could not be enabled");
      radarFailureReported = true;
    }
    return;
  }
  radarFailureReported = false;
  if (!radar.autoReadTask()) {
    Serial.println("LD2410 background reader unavailable; using loop reader");
  }
  Serial.println("LD2410 engineering mode ready");
}

void updateOccupancy() {
  const bool previousAvailable = radarAvailable;
  const bool previousOccupied = occupied;

  // engineeringRetrieved() คืนค่า true ครั้งเดียวต่อหนึ่งเฟรมที่อ่านได้
  // จึงใช้เป็นเงื่อนไข "พร้อมใช้งาน" ตรง ๆ ไม่ได้ ต้องจำเวลาที่ได้ข้อมูลล่าสุด
  const bool freshFrame =
      radarInitialised &&
      radarEngineeringEnabled &&
      radar.isConnected() &&
      radar.engineeringRetrieved();
  if (freshFrame) {
    lastRadarDataAt = millis();
    bool detected = false;
    for (uint8_t gate = FIRST_GATE; gate <= LAST_GATE; gate++) {
      if (radar.stationaryEnergyAtGate(gate) > STATIC_ENERGY_THRESHOLD) {
        detected = true;
        break;
      }
    }
    lastRadarDetected = detected;
  }

  radarAvailable =
      radarInitialised &&
      radarEngineeringEnabled &&
      lastRadarDataAt != 0 &&
      millis() - lastRadarDataAt < RADAR_DATA_TIMEOUT_MS;
  occupied = radarAvailable && lastRadarDetected;
  if (previousAvailable != radarAvailable || previousOccupied != occupied) {
    statusPublishRequested = true;
    Serial.printf(
        "Room occupancy: %s (radar %s)\n",
        occupied ? "occupied" : "vacant",
        radarAvailable ? "available" : "unavailable");
  }
}

void publishStatus() {
  if (!mqttClient.connected()) return;
  DynamicJsonDocument document(512);
  document["online"] = true;
  document["deviceId"] = config.deviceId;
  document["firmwareVersion"] = FIRMWARE_VERSION;
  if (!lastOtaError.isEmpty()) document["otaError"] = lastOtaError;
  document["roomNumber"] = config.roomNumber;
  document["radarAvailable"] = radarAvailable;
  document["occupied"] = occupied;
  document["staticThreshold"] = STATIC_ENERGY_THRESHOLD;
  String payload;
  serializeJson(document, payload);
  if (mqttClient.publish(
          (config.mqttTopic + "/status").c_str(), payload.c_str(), true)) {
    statusPublishRequested = false;
    Serial.printf(
        "Status -> %s/status %s\n",
        config.mqttTopic.c_str(),
        payload.c_str());
  } else {
    Serial.printf(
        "Status publish FAILED (mqtt state %d, payload %u bytes)\n",
        mqttClient.state(),
        static_cast<unsigned>(payload.length()));
  }
}

// เก็บไบต์ดิบที่เข้ามาทางขา RX ตอนที่ยังเริ่มต้นเรดาร์ไม่สำเร็จ
// ใช้แยกว่า "ไม่มีสัญญาณเลย" (สายผิด/ไม่มีไฟ) กับ "มีสัญญาณแต่อ่านไม่ออก" (baud ผิด)
void captureRadarRawBytes() {
  while (radarSerial.available() > 0) {
    const int value = radarSerial.read();
    if (value < 0) break;
    if (radarRawPreviewLength < RADAR_RAW_PREVIEW_BYTES) {
      radarRawPreview[radarRawPreviewLength] = static_cast<uint8_t>(value);
      radarRawPreviewLength += 1;
    }
    radarRawByteCount += 1;
  }
}

void printDiagnostics() {
  const bool wifiUp = WiFi.status() == WL_CONNECTED;
  const String ip = wifiUp ? WiFi.localIP().toString() : String("-");

  Serial.printf(
      "[diag] wifi=%s ip=%s rssi=%d | mqtt=%s state=%d target=%s:%u | "
      "ble=%s | room=%s topic=%s\n",
      wifiUp ? "yes" : "no",
      ip.c_str(),
      wifiUp ? WiFi.RSSI() : 0,
      mqttClient.connected() ? "yes" : "no",
      mqttClient.state(),
      config.mqttHost.isEmpty() ? "(empty)" : config.mqttHost.c_str(),
      config.mqttPort,
      bleAdvertisingEnabled ? "advertising" : "off",
      config.roomNumber.isEmpty() ? "(empty)" : config.roomNumber.c_str(),
      config.mqttTopic.isEmpty() ? "(empty)" : config.mqttTopic.c_str());

  // ห้ามเรียก radar.engineeringRetrieved() ตรงนี้ เพราะมันเคลียร์ธงของเฟรม
  // ทำให้ updateOccupancy() รอบถัดไปคิดว่าเรดาร์หลุด
  Serial.printf(
      "[diag] radar init=%d engineeringEnabled=%d isConnected=%d "
      "dataAge=%lums available=%d occupied=%d\n",
      radarInitialised ? 1 : 0,
      radarEngineeringEnabled ? 1 : 0,
      radar.isConnected() ? 1 : 0,
      lastRadarDataAt == 0
          ? 0UL
          : static_cast<unsigned long>(millis() - lastRadarDataAt),
      radarAvailable ? 1 : 0,
      occupied ? 1 : 0);

  if (!radarInitialised) {
    Serial.printf(
        "[diag] UART1 rx bytes in the last %lus: %lu\n",
        static_cast<unsigned long>(DIAGNOSTIC_INTERVAL_MS / 1000UL),
        static_cast<unsigned long>(radarRawByteCount));
    if (radarRawByteCount == 0) {
      Serial.println(
          "[diag] nothing arrives on GPIO32. Check module TX -> GPIO32 "
          "(crossed, not straight), VCC on 5V and a shared GND. "
          "Swapped TX/RX gives exactly 0 bytes.");
    } else {
      Serial.print("[diag] first bytes:");
      for (uint8_t index = 0; index < radarRawPreviewLength; index++) {
        Serial.printf(" %02X", radarRawPreview[index]);
      }
      Serial.println();
      Serial.println(
          "[diag] a healthy LD2410C frame starts with F4 F3 F2 F1. "
          "Random-looking bytes mean the module baud rate is not 256000.");
    }
  } else if (radarAvailable) {
    uint8_t maxEnergy = 0;
    Serial.print("[gates]");
    for (uint8_t gate = FIRST_GATE; gate <= LAST_GATE; gate++) {
      const uint8_t energy = radar.stationaryEnergyAtGate(gate);
      if (energy > maxEnergy) maxEnergy = energy;
      Serial.printf(
          " %u:%u",
          static_cast<unsigned>(gate),
          static_cast<unsigned>(energy));
    }
    Serial.printf(
        " | max=%u threshold=%u -> %s\n",
        static_cast<unsigned>(maxEnergy),
        static_cast<unsigned>(STATIC_ENERGY_THRESHOLD),
        occupied ? "OCCUPIED" : "vacant");
  } else {
    Serial.println(
        "[diag] radar started but engineering data is not arriving yet");
  }

  radarRawByteCount = 0;
  radarRawPreviewLength = 0;
}

void publishProvisioningToken() {
  if (!mqttClient.connected() || config.provisioningToken.isEmpty()) return;
  lastProvisionAt = millis();
  DynamicJsonDocument document(320);
  document["token"] = config.provisioningToken;
  document["deviceId"] = config.deviceId;
  document["roomNumber"] = config.roomNumber;
  String payload;
  serializeJson(document, payload);
  mqttClient.publish(
      (config.mqttTopic + "/provision").c_str(), payload.c_str(), true);
}
