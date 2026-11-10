import 'package:cpe_air_remote/models/air_conditioner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Star Aire uses only the functions captured from the DT-03 remote', () {
    final air = AirConditioner(
      id: 1,
      name: 'Star Aire',
      protocol: 'STAR_AIRE',
      temperature: 24,
      mode: AirMode.heat,
      fanSpeed: FanSpeed.turbo,
      verticalSwing: SwingMode.top,
      eco: true,
    );

    expect(air.brand, 'Star Aire');
    expect(air.minimumTemperature, 16);
    expect(air.maximumTemperature, 30);
    expect(air.mode, AirMode.cool);
    expect(air.fanSpeed, FanSpeed.high);
    expect(air.verticalSwing, SwingMode.auto);
    expect(air.eco, isFalse);
    expect(air.supportedModes, [AirMode.cool, AirMode.dry, AirMode.fan]);
    expect(air.supportedFanSpeeds, isNot(contains(FanSpeed.turbo)));
    expect(air.supportedSwingModes, [SwingMode.auto]);
    expect(air.supportsSleep, isTrue);
    expect(air.supportsEco, isFalse);
    expect(air.supportsTurbo, isFalse);
  });
}
