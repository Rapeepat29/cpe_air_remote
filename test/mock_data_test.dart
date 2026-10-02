import 'package:cpe_air_remote/data/mock_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates three floors with seven rooms each', () {
    final rooms = MockData.createRooms();

    expect(rooms, hasLength(21));
    for (var floor = 1; floor <= 3; floor++) {
      expect(
        rooms.where((room) => room.floor == floor),
        hasLength(7),
      );
    }
    expect(rooms.any((room) => room.number == '16101'), isTrue);
    expect(rooms.any((room) => room.number == '16203'), isTrue);
    expect(rooms.any((room) => room.number == '16307'), isTrue);
    expect(
      rooms.every((room) => room.airConditioners.length <= 6),
      isTrue,
    );
  });
}
