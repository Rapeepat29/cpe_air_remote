import '../models/air_conditioner.dart';
import '../models/room.dart';

abstract final class MockData {
  static List<Room> createRooms() {
    const roomTypes = <int, List<String>>{
      1: [
        'Administration Office',
        'Meeting Room',
        'Classroom',
        'Laboratory',
        'Faculty Office',
        'Classroom',
        'Project Room',
      ],
      2: [
        'Classroom',
        'Classroom',
        'Laboratory',
        'Classroom',
        'Network Room',
        'Faculty Office',
        'Classroom',
      ],
      3: [
        'Meeting Room',
        'Storage Room',
        'Classroom',
        'Faculty Project Room',
        'Equipment Storage',
        'Faculty Office',
        'Classroom',
      ],
    };
    final rooms = <Room>[];
    for (var floor = 1; floor <= 3; floor++) {
      for (var roomIndex = 1; roomIndex <= 7; roomIndex++) {
        final roomNumber =
            '16$floor${roomIndex.toString().padLeft(2, '0')}';
        rooms.add(
          Room(
            number: roomNumber,
            floor: floor,
            roomIndex: roomIndex,
            type: roomTypes[floor]![roomIndex - 1],
            // Real ESP32 devices are loaded from MariaDB after sign-in.
            airConditioners: <AirConditioner>[],
            isOccupied: const {
              '16101',
              '16103',
              '16105',
              '16202',
              '16205',
              '16207',
              '16301',
              '16303',
              '16305',
              '16307',
            }.contains(roomNumber),
            isOnline: roomNumber != '16206',
          ),
        );
      }
    }
    return rooms;
  }
}
