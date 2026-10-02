import 'package:cpe_air_remote/models/air_conditioner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Saijo Denki uses only captured capabilities', () {
    final air = AirConditioner(
      id: 1,
      name: 'Saijo',
      protocol: 'SAIJO_DENKI',
      temperature: 16,
      mode: AirMode.dry,
      fanSpeed: FanSpeed.turbo,
      verticalSwing: SwingMode.off,
      eco: true,
    );

    expect(air.minimumTemperature, 18);
    expect(air.maximumTemperature, 29);
    expect(air.temperature, 18);
    expect(air.mode, AirMode.dry);
    expect(air.fanSpeed, FanSpeed.turbo);
    expect(air.verticalSwing, SwingMode.auto);
    expect(air.eco, isFalse);
    expect(
      air.supportedModes,
      [AirMode.cool, AirMode.dry, AirMode.fan],
    );
    expect(air.supportedFanSpeeds, contains(FanSpeed.turbo));
    expect(air.fanSpeedLabel(FanSpeed.turbo), 'Turbo');
    expect(air.supportedSwingModes, contains(SwingMode.upper));
    expect(air.supportedSwingModes, contains(SwingMode.lower));
    expect(air.supportedSwingModes, isNot(contains(SwingMode.off)));
  });

  test('existing IRac protocols keep the generic capability range', () {
    final air = AirConditioner(
      id: 1,
      name: 'Haier',
      protocol: 'HAIER_AC160',
      temperature: 16,
      mode: AirMode.dry,
      fanSpeed: FanSpeed.turbo,
      verticalSwing: SwingMode.off,
      eco: true,
    );

    expect(air.minimumTemperature, 16);
    expect(air.maximumTemperature, 30);
    expect(air.mode, AirMode.dry);
    expect(air.fanSpeed, FanSpeed.turbo);
    expect(air.verticalSwing, SwingMode.off);
    expect(air.eco, isTrue);
    expect(air.supportedSwingModes, isNot(contains(SwingMode.upper)));
    expect(air.supportedSwingModes, isNot(contains(SwingMode.lower)));
  });
}
