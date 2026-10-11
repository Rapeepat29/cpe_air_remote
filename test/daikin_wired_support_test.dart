import 'package:cpe_air_remote/models/air_conditioner.dart';
import 'package:cpe_air_remote/models/provisioning.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Daikin wired board keeps only wall-remote functions', () {
    final air = AirConditioner(
      id: 1,
      name: 'Daikin',
      protocol: 'DAIKIN_WIRED',
      temperature: 16,
      mode: AirMode.heat,
      fanSpeed: FanSpeed.turbo,
      verticalSwing: SwingMode.middle,
      horizontalSwing: true,
      eco: true,
      turbo: true,
      sleep: true,
      quiet: true,
      clean: true,
    );

    expect(air.isWired, isTrue);
    expect(air.brand, 'Daikin');
    expect(air.controlTypeLabel, 'Wired');
    expect(air.minimumTemperature, 16);
    expect(air.maximumTemperature, 30);
    expect(air.mode, AirMode.cool);
    expect(air.fanSpeed, FanSpeed.high);
    expect(air.verticalSwing, SwingMode.auto);
    expect(air.horizontalSwing, isFalse);
    expect(air.eco, isFalse);
    expect(air.turbo, isFalse);
    expect(air.quiet, isFalse);
    expect(air.clean, isFalse);
    expect(air.sleep, isTrue);
    expect(air.supportedModes, [AirMode.cool, AirMode.dry, AirMode.fan]);
    expect(air.supportedFanSpeeds, isNot(contains(FanSpeed.turbo)));
    expect(air.supportedSwingModes, [SwingMode.auto, SwingMode.off]);
    expect(air.supportsSleep, isTrue);
    expect(air.supportsEco, isFalse);
    expect(air.supportsDisplayLight, isFalse);

    air.mode = AirMode.dry;
    expect(air.supportsSleep, isFalse);
    air.normalizeForProtocol();
    expect(air.sleep, isFalse);
  });

  test('IR boards report their brand and control type', () {
    final haier = AirConditioner(id: 1, name: 'A', protocol: 'HAIER_AC160');
    expect(haier.isWired, isFalse);
    expect(haier.brand, 'Haier');
    expect(haier.controlTypeLabel, 'IR remote');
    expect(haier.supportsEco, isTrue);
    expect(airBrandOf('DAIKIN'), 'Daikin');
    expect(airBrandOf('MITSUBISHI_AC'), 'Mitsubishi Electric');
    expect(airControlTypeOf('DAIKIN'), 'ir');
    expect(airControlTypeOf('daikin_wired'), 'wired');
  });

  test('BLE identity tells wired boards from IR boards', () {
    final wired = BleDeviceIdentity.fromJson(const {
      'deviceId': 'ESP32-705F1971FE68',
      'bleName': 'RMUTT-AC-705F1971FE68',
      'firmwareVersion': '2.5.1-slm8',
      'configured': false,
      'controlType': 'wired',
      'brand': 'Daikin',
    });
    expect(wired.isWired, isTrue);
    expect(wired.brand, 'Daikin');

    final legacy = BleDeviceIdentity.fromJson(const {
      'deviceId': 'ESP32-705F1971FE68',
      'bleName': 'RMUTT-AC-705F1971FE68',
      'firmwareVersion': '2.4.1',
      'configured': false,
    });
    expect(legacy.isWired, isFalse);
    expect(legacy.controlType, 'ir');
  });
}
