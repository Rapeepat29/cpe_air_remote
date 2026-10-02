import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleDeviceCandidate {
  const BleDeviceCandidate({
    required this.device,
    required this.name,
    required this.rssi,
  });

  final BluetoothDevice device;
  final String name;
  final int rssi;
}

class WifiNetworkCandidate {
  const WifiNetworkCandidate({
    required this.ssid,
    required this.rssi,
    required this.isSecure,
  });

  factory WifiNetworkCandidate.fromCompactJson(List<dynamic> json) {
    if (json.length < 3 ||
        json[0] is! String ||
        json[1] is! num ||
        json[2] is! bool) {
      throw const FormatException('Invalid Wi-Fi network data.');
    }
    return WifiNetworkCandidate(
      ssid: json[0] as String,
      rssi: (json[1] as num).toInt(),
      isSecure: json[2] as bool,
    );
  }

  final String ssid;
  final int rssi;
  final bool isSecure;
}

class BleDeviceIdentity {
  const BleDeviceIdentity({
    required this.deviceId,
    required this.bleName,
    required this.firmwareVersion,
    required this.configured,
    required this.deviceType,
    required this.roomNumber,
    required this.airNumber,
    required this.airName,
    required this.airProtocol,
    required this.wifiSsid,
    required this.hasWifiPassword,
    required this.mqttHost,
    required this.mqttPort,
    required this.mqttUsername,
    required this.hasMqttPassword,
    required this.dailyOn,
    required this.dailyOff,
  });

  factory BleDeviceIdentity.fromJson(Map<String, dynamic> json) {
    return BleDeviceIdentity(
      deviceId: json['deviceId'] as String? ?? '',
      bleName: json['bleName'] as String? ?? '',
      firmwareVersion: json['firmwareVersion'] as String? ?? 'unknown',
      configured: json['configured'] == true,
      deviceType: json['deviceType'] as String? ?? 'air',
      roomNumber: json['roomNumber'] as String? ?? '',
      airNumber: (json['airNumber'] as num?)?.toInt(),
      airName: json['name'] as String? ?? '',
      airProtocol: json['airProtocol'] as String? ?? '',
      wifiSsid: json['wifiSsid'] as String? ?? '',
      hasWifiPassword: json['hasWifiPassword'] == true,
      mqttHost: json['mqttHost'] as String? ?? '',
      mqttPort: (json['mqttPort'] as num?)?.toInt(),
      mqttUsername: json['mqttUsername'] as String? ?? '',
      hasMqttPassword: json['hasMqttPassword'] == true,
      dailyOn: json['dailyOn'] as String?,
      dailyOff: json['dailyOff'] as String?,
    );
  }

  final String deviceId;
  final String bleName;
  final String firmwareVersion;
  final bool configured;
  final String deviceType;
  final String roomNumber;
  final int? airNumber;
  final String airName;
  final String airProtocol;
  final String wifiSsid;
  final bool hasWifiPassword;
  final String mqttHost;
  final int? mqttPort;
  final String mqttUsername;
  final bool hasMqttPassword;
  final String? dailyOn;
  final String? dailyOff;
}

class OccupancyProvisioningReservation {
  const OccupancyProvisioningReservation({
    required this.deviceId,
    required this.roomNumber,
    required this.bleName,
    required this.staticThreshold,
    required this.mqttTopic,
    required this.mqttHost,
    required this.mqttPort,
    required this.mqttUsername,
    required this.mqttPassword,
    required this.mqttTls,
    required this.provisioningToken,
  });

  factory OccupancyProvisioningReservation.fromJson(
    Map<String, dynamic> json,
  ) {
    return OccupancyProvisioningReservation(
      deviceId: json['deviceId'] as String,
      roomNumber: json['roomNumber'] as String,
      bleName: json['bleName'] as String,
      staticThreshold: (json['staticThreshold'] as num).toInt(),
      mqttTopic: json['mqttTopic'] as String,
      mqttHost: json['mqttHost'] as String,
      mqttPort: (json['mqttPort'] as num).toInt(),
      mqttUsername: json['mqttUsername'] as String? ?? '',
      mqttPassword: json['mqttPassword'] as String? ?? '',
      mqttTls: json['mqttTls'] == true,
      provisioningToken: json['provisioningToken'] as String,
    );
  }

  final String deviceId;
  final String roomNumber;
  final String bleName;
  final int staticThreshold;
  final String mqttTopic;
  final String mqttHost;
  final int mqttPort;
  final String mqttUsername;
  final String mqttPassword;

  /// true = ต่อ Broker ด้วย TLS (พอร์ต 8883) ผ่านอินเทอร์เน็ต
  final bool mqttTls;
  final String provisioningToken;
}

class OccupancyProvisioningRequest {
  const OccupancyProvisioningRequest({
    required this.identity,
    required this.roomNumber,
    required this.wifiSsid,
    required this.wifiPassword,
    this.keepWifiPassword = false,
  });

  final BleDeviceIdentity identity;
  final String roomNumber;
  final String wifiSsid;
  final String wifiPassword;
  final bool keepWifiPassword;

  Map<String, dynamic> toReservationJson() => {
    'deviceId': identity.deviceId,
    'bleName': identity.bleName,
    'roomNumber': roomNumber,
  };

  Map<String, dynamic> toBleJson(
    OccupancyProvisioningReservation reservation,
  ) => {
    'version': 1,
    'deviceId': identity.deviceId,
    'deviceType': 'occupancy',
    'token': reservation.provisioningToken,
    'roomNumber': roomNumber,
    'staticThreshold': reservation.staticThreshold,
    'wifi': {
      'ssid': wifiSsid,
      'password': wifiPassword,
      'keepPassword': keepWifiPassword,
    },
    'mqtt': {
      'host': reservation.mqttHost,
      'port': reservation.mqttPort,
      'username': reservation.mqttUsername,
      'password': reservation.mqttPassword,
      'keepPassword': false,
      'topic': reservation.mqttTopic,
      'tls': reservation.mqttTls,
    },
  };
}

class AirProvisioningReservation {
  const AirProvisioningReservation({
    required this.deviceId,
    required this.roomNumber,
    required this.airNumber,
    required this.name,
    required this.protocol,
    required this.mqttTopic,
    required this.mqttHost,
    required this.mqttPort,
    required this.mqttUsername,
    required this.mqttPassword,
    required this.mqttTls,
    required this.provisioningToken,
  });

  factory AirProvisioningReservation.fromJson(Map<String, dynamic> json) {
    return AirProvisioningReservation(
      deviceId: json['deviceId'] as String,
      roomNumber: json['roomNumber'] as String,
      airNumber: json['airNumber'] as int,
      name: json['name'] as String,
      protocol: json['protocol'] as String,
      mqttTopic: json['mqttTopic'] as String,
      mqttHost: json['mqttHost'] as String,
      mqttPort: (json['mqttPort'] as num).toInt(),
      mqttUsername: json['mqttUsername'] as String? ?? '',
      mqttPassword: json['mqttPassword'] as String? ?? '',
      mqttTls: json['mqttTls'] == true,
      provisioningToken: json['provisioningToken'] as String,
    );
  }

  final String deviceId;
  final String roomNumber;
  final int airNumber;
  final String name;
  final String protocol;
  final String mqttTopic;
  final String mqttHost;
  final int mqttPort;
  final String mqttUsername;
  final String mqttPassword;

  /// true = ต่อ Broker ด้วย TLS (พอร์ต 8883) ผ่านอินเทอร์เน็ต
  final bool mqttTls;
  final String provisioningToken;
}

class AirProvisioningRequest {
  const AirProvisioningRequest({
    required this.identity,
    required this.roomNumber,
    required this.airNumber,
    required this.name,
    required this.protocol,
    required this.wifiSsid,
    required this.wifiPassword,
    this.keepWifiPassword = false,
    this.dailyOn,
    this.dailyOff,
  });

  final BleDeviceIdentity identity;
  final String roomNumber;
  final int airNumber;
  final String name;
  final String protocol;
  final String wifiSsid;
  final String wifiPassword;
  final bool keepWifiPassword;
  final String? dailyOn;
  final String? dailyOff;

  Map<String, dynamic> toReservationJson() => {
    'deviceId': identity.deviceId,
    'bleName': identity.bleName,
    'roomNumber': roomNumber,
    'airNumber': airNumber,
    'name': name,
    'protocol': protocol,
    'dailyOn': dailyOn,
    'dailyOff': dailyOff,
  };

  Map<String, dynamic> toBleJson(AirProvisioningReservation reservation) => {
    'version': 1,
    'deviceId': identity.deviceId,
    'token': reservation.provisioningToken,
    'roomNumber': roomNumber,
    'airNumber': airNumber,
    'name': name,
    'airProtocol': protocol,
    'wifi': {
      'ssid': wifiSsid,
      'password': wifiPassword,
      'keepPassword': keepWifiPassword,
    },
    'mqtt': {
      'host': reservation.mqttHost,
      'port': reservation.mqttPort,
      'username': reservation.mqttUsername,
      'password': reservation.mqttPassword,
      'keepPassword': false,
      'topic': reservation.mqttTopic,
      'tls': reservation.mqttTls,
    },
    'schedule': {
      'dailyOn': dailyOn,
      'dailyOff': dailyOff,
      'timezone': 'Asia/Bangkok',
    },
  };
}
