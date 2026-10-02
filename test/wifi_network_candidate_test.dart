import 'package:cpe_air_remote/models/provisioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses compact ESP32 Wi-Fi scan data', () {
    final network = WifiNetworkCandidate.fromCompactJson([
      'RMUTT-WiFi',
      -42,
      true,
    ]);

    expect(network.ssid, 'RMUTT-WiFi');
    expect(network.rssi, -42);
    expect(network.isSecure, isTrue);
  });

  test('rejects malformed compact ESP32 Wi-Fi scan data', () {
    expect(
      () => WifiNetworkCandidate.fromCompactJson(['RMUTT-WiFi', 'strong']),
      throwsFormatException,
    );
  });

  test('reads the saved non-secret settings returned by ESP32', () {
    final identity = BleDeviceIdentity.fromJson({
      'deviceId': 'ESP32-705F1971FE68',
      'bleName': 'RMUTT-AC-705F1971FE68',
      'firmwareVersion': '1.5.0',
      'configured': true,
      'roomNumber': '16101',
      'airNumber': 1,
      'name': 'Air 1',
      'airProtocol': 'HAIER_AC160',
      'wifiSsid': 'RMUTT-WiFi',
      'hasWifiPassword': true,
      'mqttHost': '192.168.1.153',
      'mqttPort': 1883,
      'mqttUsername': 'rmutt',
      'hasMqttPassword': true,
      'dailyOn': '08:00',
      'dailyOff': '17:00',
    });

    expect(identity.configured, isTrue);
    expect(identity.wifiSsid, 'RMUTT-WiFi');
    expect(identity.mqttHost, '192.168.1.153');
    expect(identity.hasWifiPassword, isTrue);
    expect(identity.dailyOff, '17:00');
  });

  test('uses server MQTT settings and keeps saved Wi-Fi password', () {
    final identity = BleDeviceIdentity.fromJson({
      'deviceId': 'ESP32-705F1971FE68',
      'bleName': 'RMUTT-AC-705F1971FE68',
      'firmwareVersion': '1.5.0',
      'configured': true,
    });
    final request = AirProvisioningRequest(
      identity: identity,
      roomNumber: '16101',
      airNumber: 1,
      name: 'Air 1',
      protocol: 'HAIER_AC160',
      wifiSsid: 'RMUTT-WiFi',
      wifiPassword: '',
      keepWifiPassword: true,
    );
    const reservation = AirProvisioningReservation(
      deviceId: 'ESP32-705F1971FE68',
      roomNumber: '16101',
      airNumber: 1,
      name: 'Air 1',
      protocol: 'HAIER_AC160',
      mqttTopic: 'rmutt/air/ESP32-705F1971FE68',
      mqttHost: '192.168.1.153',
      mqttPort: 1883,
      mqttUsername: 'rmutt',
      mqttPassword: 'broker-password',
      mqttTls: false,
      provisioningToken: 'test-token',
    );

    final json = request.toBleJson(reservation);
    final mqtt = json['mqtt'] as Map<String, dynamic>;

    expect((json['wifi'] as Map<String, dynamic>)['keepPassword'], isTrue);
    expect(mqtt['host'], '192.168.1.153');
    expect(mqtt['port'], 1883);
    expect(mqtt['username'], 'rmutt');
    expect(mqtt['password'], 'broker-password');
    expect(mqtt['keepPassword'], isFalse);
  });
}
