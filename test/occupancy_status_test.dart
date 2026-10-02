import 'package:cpe_air_remote/models/provisioning.dart';
import 'package:cpe_air_remote/models/room.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the room occupancy boolean and sensor availability', () {
    final room = Room.fromJson({
      'roomNumber': '16203',
      'floorNumber': 2,
      'roomIndex': 3,
      'roomType': 'Laboratory',
      'occupancySensorDeviceId': 'OCC32-AABBCCDDEEFF',
      'occupancySensorBleName': 'RMUTT-OCC-AABBCCDDEEFF',
      'occupancySensorProvisionStatus': 'active',
      'occupancySensorOnline': true,
      'occupancySensorAvailable': true,
      'isOccupied': true,
      'occupancyStaticThreshold': 25,
      'occupancyUpdatedAt': '2026-08-19T12:00:00.000Z',
    });

    expect(room.hasOccupancySensor, isTrue);
    expect(room.occupancySensorOnline, isTrue);
    expect(room.occupancySensorAvailable, isTrue);
    expect(room.isOccupied, isTrue);
    expect(room.occupancyStaticThreshold, 25);
  });

  test('recognizes occupancy firmware identity from BLE data', () {
    final identity = BleDeviceIdentity.fromJson({
      'deviceId': 'OCC32-AABBCCDDEEFF',
      'bleName': 'RMUTT-OCC-AABBCCDDEEFF',
      'deviceType': 'occupancy',
      'firmwareVersion': '1.0.0',
      'configured': false,
    });

    expect(identity.deviceType, 'occupancy');
    expect(identity.deviceId, startsWith('OCC32-'));
  });
}
