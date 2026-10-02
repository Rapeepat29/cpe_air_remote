import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/room.dart';
import '../services/room_repository.dart';

class RoomController extends ChangeNotifier {
  RoomController({
    required this.rooms,
    required this.repository,
  });

  final List<Room> rooms;
  final RoomRepository repository;

  bool isLoading = false;
  bool hasLoaded = false;
  String? errorMessage;
  Timer? _refreshTimer;
  Future<void>? _inFlight;

  List<int> get floors {
    final values = rooms.map((room) => room.floor).toSet().toList()..sort();
    return values;
  }

  Future<void> initialize() async {
    if (isLoading || hasLoaded) return;
    await reload();
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => reload(silent: true),
    );
  }

  /// หาห้องล่าสุดจากรายการที่โหลดไว้ ใช้กับหน้าจอที่เปิดค้างไว้ เพราะทุกครั้งที่
  /// reload จะสร้าง Room object ใหม่ หน้าจอที่ถือ object เดิมไว้จะเห็นค่าค้าง
  Room? roomByNumber(String number) {
    for (final room in rooms) {
      if (room.number == number) return room;
    }
    return null;
  }

  /// การกดปุ่มรีเฟรชจะได้ข้อมูลชุดใหม่เสมอ ถ้ามีรอบอัตโนมัติค้างอยู่จะรอให้จบ
  /// ก่อนแล้วค่อยดึงซ้ำ ส่วนรอบอัตโนมัติที่ชนกันเองจะข้ามไปเพื่อไม่ให้ซ้อนกัน
  Future<void> reload({bool silent = false}) async {
    final inFlight = _inFlight;
    if (inFlight != null) {
      if (silent) return;
      await inFlight;
    }
    final task = _runReload(silent);
    _inFlight = task;
    try {
      await task;
    } finally {
      if (identical(_inFlight, task)) _inFlight = null;
    }
  }

  Future<void> _runReload(bool silent) async {
    if (!silent) isLoading = true;
    errorMessage = null;
    if (!silent) notifyListeners();
    try {
      final loaded = await repository.fetchRooms();
      for (var index = 0; index < loaded.length; index++) {
        final room = loaded[index];
        final existingIndex = rooms.indexWhere(
          (existing) => existing.number == room.number,
        );
        if (existingIndex >= 0) {
          final existing = rooms[existingIndex];
          existing.isOccupied = room.isOccupied;
          existing.occupancySensorDeviceId = room.occupancySensorDeviceId;
          existing.occupancySensorBleName = room.occupancySensorBleName;
          existing.occupancySensorProvisionStatus =
              room.occupancySensorProvisionStatus;
          existing.occupancySensorOnline = room.occupancySensorOnline;
          existing.occupancySensorAvailable = room.occupancySensorAvailable;
          existing.occupancyStaticThreshold = room.occupancyStaticThreshold;
          existing.occupancyUpdatedAt = room.occupancyUpdatedAt;
          loaded[index] = room.copyWith(
            airConditioners: existing.airConditioners,
            isOnline: existing.isOnline,
          );
        }
      }
      rooms
        ..clear()
        ..addAll(loaded)
        ..sort(_compare);
      hasLoaded = true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('ApiException: ', '');
    } finally {
      if (!silent) isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<Room> createRoom(Room room) async {
    final created = await repository.createRoom(room);
    rooms
      ..add(created)
      ..sort(_compare);
    errorMessage = null;
    notifyListeners();
    return created;
  }

  Future<Room> updateRoom(Room room) async {
    final updated = await repository.updateRoom(room);
    final index = rooms.indexWhere((item) => item.number == updated.number);
    if (index >= 0) {
      final existing = rooms[index];
      rooms[index] = updated.copyWith(
        airConditioners: existing.airConditioners,
        isOccupied: existing.isOccupied,
        isOnline: existing.isOnline,
        registeredAirCount: existing.registeredAirCount,
        scheduleCount: existing.scheduleCount,
        occupancySensorDeviceId: existing.occupancySensorDeviceId,
        occupancySensorBleName: existing.occupancySensorBleName,
        occupancySensorProvisionStatus:
            existing.occupancySensorProvisionStatus,
        occupancySensorOnline: existing.occupancySensorOnline,
        occupancySensorAvailable: existing.occupancySensorAvailable,
        occupancyStaticThreshold: existing.occupancyStaticThreshold,
        occupancyUpdatedAt: existing.occupancyUpdatedAt,
      );
    } else {
      rooms.add(updated);
    }
    rooms.sort(_compare);
    errorMessage = null;
    notifyListeners();
    return rooms.firstWhere((item) => item.number == updated.number);
  }

  Future<void> deleteRoom(String roomNumber) async {
    await repository.deleteRoom(roomNumber);
    rooms.removeWhere((room) => room.number == roomNumber);
    errorMessage = null;
    notifyListeners();
  }

  static int _compare(Room first, Room second) {
    final floorComparison = first.floor.compareTo(second.floor);
    if (floorComparison != 0) return floorComparison;
    final indexComparison = first.roomIndex.compareTo(second.roomIndex);
    if (indexComparison != 0) return indexComparison;
    return first.number.compareTo(second.number);
  }
}
