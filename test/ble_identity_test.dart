import 'package:cpe_air_remote/models/provisioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('firmware 1.6 compact identity opens first-time provisioning', () {
    final identity = BleDeviceIdentity.fromJson(const {
      'deviceId': 'ESP32-705F1971FE68',
      'bleName': 'RMUTT-AC-705F1971FE68',
      'firmwareVersion': '1.6.0',
      'configured': false,
    });

    expect(identity.deviceId, 'ESP32-705F1971FE68');
    expect(identity.bleName, 'RMUTT-AC-705F1971FE68');
    expect(identity.configured, isFalse);
    expect(identity.roomNumber, isEmpty);
    expect(identity.airNumber, isNull);
  });

  test('core identity and optional settings merge for reconfiguration', () {
    final merged = <String, dynamic>{
      'deviceId': 'ESP32-705F1971FE68',
      'bleName': 'RMUTT-AC-705F1971FE68',
      'firmwareVersion': '1.6.0',
      'configured': true,
      'roomNumber': '16101',
      'airNumber': 2,
    }..addAll({
      'name': 'Air 2',
      'airProtocol': 'HAIER_AC160',
      'wifiSsid': 'RMUTT-WiFi',
      'hasWifiPassword': true,
      'mqttHost': '192.168.1.153',
      'mqttPort': 1883,
      'mqttUsername': 'rmutt_app',
      'hasMqttPassword': true,
      'dailyOn': '08:00',
      'dailyOff': '17:00',
    });

    final identity = BleDeviceIdentity.fromJson(merged);

    expect(identity.roomNumber, '16101');
    expect(identity.airNumber, 2);
    expect(identity.airName, 'Air 2');
    expect(identity.wifiSsid, 'RMUTT-WiFi');
    expect(identity.hasWifiPassword, isTrue);
    expect(identity.mqttHost, '192.168.1.153');
  });
}
