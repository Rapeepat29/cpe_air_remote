import 'package:cpe_air_remote/models/air_conditioner.dart';
import 'package:cpe_air_remote/models/room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses measured PZEM and running status separately from IR command', () {
    final air = AirConditioner.fromJson({
      'deviceId': 'ESP32-AABBCCDDEEFF',
      'roomNumber': '16203',
      'airNumber': 1,
      'name': 'Air 1',
      'state': {'power': false},
      'pzemAvailable': true,
      'acRunning': true,
      'outsideSchedule': true,
      'voltage': 229.8,
      'current': 2.14,
      'powerWatts': 465.2,
      'energyKwh': 12.345,
      'frequencyHz': 50.0,
      'powerFactor': 0.94,
    });

    expect(air.isOn, isFalse);
    expect(air.isRunning, isTrue);
    expect(air.outsideSchedule, isTrue);
    expect(air.pzemAvailable, isTrue);
    expect(air.energyKwh, 12.345);
  });

  test('room running count uses PZEM status instead of the IR command', () {
    final room = Room(
      number: '16203',
      floor: 2,
      roomIndex: 3,
      type: 'Laboratory',
      airConditioners: [
        AirConditioner(
          id: 1,
          name: 'Air 1',
          isOn: false,
          isRunning: true,
          pzemAvailable: true,
          power: 450,
        ),
      ],
    );

    expect(room.runningAirCount, 1);
    expect(room.totalPower, 450);
  });
}
