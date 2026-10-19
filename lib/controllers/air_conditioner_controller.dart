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
  Timer? _graceTimer;
  Future<void>? _inFlight;
  final Map<String, ({bool isOn, DateTime commandedAt})> _recentCommands = {};

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
      final now = DateTime.now();
      for (final air in devices) {
        final deviceId = air.deviceId;
        if (deviceId == null) continue;
        final recent = _recentCommands[deviceId];
        if (recent == null) continue;
        final elapsed = now.difference(recent.commandedAt);
        if (!elapsed.isNegative &&
            elapsed < AirConditioner.commandGracePeriod) {
          if (air.pzemAvailable && air.isRunning == recent.isOn) {
            _recentCommands.remove(deviceId);
          } else {
            air.isOn = recent.isOn;
            air.commandedAt = recent.commandedAt;
            if (!recent.isOn) air.isRunning = false;
          }
        } else {
          _recentCommands.remove(deviceId);
        }
      }
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
    _graceTimer?.cancel();
    super.dispose();
  }

  Future<void> sendCommand(AirConditioner air) async {
    await repository.sendCommand(air);
    final now = DateTime.now();
    air.commandedAt = now;
    final deviceId = air.deviceId;
    if (deviceId != null) {
      _recentCommands[deviceId] = (isOn: air.isOn, commandedAt: now);
      _graceTimer?.cancel();
      _graceTimer = Timer(AirConditioner.commandGracePeriod, () {
        refresh(silent: true);
      });
    }
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
