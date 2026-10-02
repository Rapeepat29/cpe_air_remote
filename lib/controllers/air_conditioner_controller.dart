import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/air_conditioner.dart';
import '../models/room.dart';
import '../services/air_conditioner_repository.dart';

class AirConditionerController extends ChangeNotifier {
  AirConditionerController({
    required this.rooms,
    required this.repository,
  });

  final List<Room> rooms;
  final AirConditionerRepository repository;

  bool isLoading = false;
  String? errorMessage;
  Timer? _refreshTimer;
  Future<void>? _inFlight;

  Future<void> initialize() async {
    await refresh();
    _refreshTimer ??= Timer.periodic(
      const Duration(seconds: 10),
      (_) => refresh(silent: true),
    );
  }

  /// การกดปุ่มรีเฟรชจะได้ข้อมูลชุดใหม่เสมอ ถ้ามีรอบอัตโนมัติค้างอยู่จะรอให้จบ
  /// ก่อนแล้วค่อยดึงซ้ำ ส่วนรอบอัตโนมัติที่ชนกันเองจะข้ามไปเพื่อไม่ให้ซ้อนกัน
  Future<void> refresh({bool silent = false}) async {
    final inFlight = _inFlight;
    if (inFlight != null) {
      if (silent) return;
      await inFlight;
    }
    final task = _runRefresh(silent);
    _inFlight = task;
    try {
      await task;
    } finally {
      if (identical(_inFlight, task)) _inFlight = null;
    }
  }

  Future<void> _runRefresh(bool silent) async {
    if (!silent) isLoading = true;
    errorMessage = null;
    if (!silent) notifyListeners();
    try {
      final devices = await repository.fetchAll();
      for (final room in rooms) {
        room.airConditioners
          ..clear()
          ..addAll(
            devices.where((air) => air.roomNumber == room.number),
          );
        room.isOnline = room.airConditioners.isEmpty
            || room.airConditioners.any((air) => air.isOnline);
      }
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

  Future<void> sendCommand(AirConditioner air) async {
    await repository.sendCommand(air);
    notifyListeners();
  }

  Future<void> rename(AirConditioner air, String name) async {
    final deviceId = air.deviceId;
    if (deviceId == null) return;
    await repository.rename(deviceId, name);
    air.name = name;
    notifyListeners();
  }

  Future<void> remove(AirConditioner air) async {
    final deviceId = air.deviceId;
    if (deviceId == null) return;
    await repository.remove(deviceId);
    await refresh();
  }
}
