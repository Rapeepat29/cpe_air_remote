
import 'package:flutter/foundation.dart';

import '../models/class_schedule.dart';
import '../models/schedule_import.dart';
import '../services/schedule_repository.dart';

class ScheduleController extends ChangeNotifier {
  ScheduleController(this.repository);

  final ScheduleRepository repository;

  final List<ClassSchedule> _schedules = [];
  bool _isLoading = false;
  bool _hasLoaded = false;
  String? _errorMessage;

  List<ClassSchedule> get schedules => List.unmodifiable(_schedules);

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  List<ClassSchedule> schedulesFor(String roomNumber, int dayOfWeek) {
    return _schedules
        .where(
          (schedule) =>
              schedule.roomNumber == roomNumber &&
              schedule.dayOfWeek == dayOfWeek,
        )
        .toList()
      ..sort(_compare);
  }

  Future<void> initialize() async {
    if (_hasLoaded || _isLoading) {
      return;
    }
    await reload();
  }

  Future<void> reload() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final loaded = await repository.fetchSchedules();
      _schedules
        ..clear()
        ..addAll(loaded)
        ..sort(_compare);
      _hasLoaded = true;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ClassSchedule> createSchedule(ClassSchedule schedule) async {
    final created = await repository.createSchedule(schedule);
    _schedules
      ..add(created)
      ..sort(_compare);
    _errorMessage = null;
    notifyListeners();
    return created;
  }

  Future<ClassSchedule> updateSchedule(ClassSchedule schedule) async {
    final updated = await repository.updateSchedule(schedule);
    final index = _schedules.indexWhere((item) => item.id == updated.id);
    if (index >= 0) {
      _schedules[index] = updated;
    } else {
      _schedules.add(updated);
    }
    _schedules.sort(_compare);
    _errorMessage = null;
    notifyListeners();
    return updated;
  }

  Future<void> deleteSchedule(String id) async {
    await repository.deleteSchedule(id);
    _schedules.removeWhere((schedule) => schedule.id == id);
    _errorMessage = null;
    notifyListeners();
  }

  Future<int> deleteAllSchedules() async {
    final deletedCount = await repository.deleteAllSchedules();
    _schedules.clear();
    _errorMessage = null;
    notifyListeners();
    return deletedCount;
  }

  Future<ScheduleImportPreview> previewScheduleFile({
    required String fileName,
    required Uint8List bytes,
  }) {
    return repository.previewScheduleFile(
      fileName: fileName,
      bytes: bytes,
    );
  }

  Future<ScheduleImportResult> importSchedulePreview(
    ScheduleImportPreview preview,
  ) async {
    final result = await repository.importSchedulePreview(preview);
    await reload();
    return result;
  }

  bool overlaps({
    required String roomNumber,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? ignoredId,
  }) {
    return _schedules.any(
      (schedule) =>
          schedule.id != ignoredId &&
          schedule.roomNumber == roomNumber &&
          schedule.dayOfWeek == dayOfWeek &&
          ClassSchedule.timesOverlap(
            startTime,
            endTime,
            schedule.startTime,
            schedule.endTime,
          ),
    );
  }

  static int _compare(ClassSchedule first, ClassSchedule second) {
    final dayComparison = first.dayOfWeek.compareTo(second.dayOfWeek);
    if (dayComparison != 0) return dayComparison;

    final roomComparison = first.roomNumber.compareTo(second.roomNumber);
    if (roomComparison != 0) return roomComparison;

    final timeComparison = first.startTime.compareTo(second.startTime);
    if (timeComparison != 0) return timeComparison;

    return first.subjectName.compareTo(second.subjectName);
  }
}
