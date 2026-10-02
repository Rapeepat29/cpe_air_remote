import '../models/room.dart';

abstract interface class RoomRepository {
  Future<List<Room>> fetchRooms();

  Future<Room> createRoom(Room room);

  Future<Room> updateRoom(Room room);

  Future<void> deleteRoom(String roomNumber);
}
