import 'dart:typed_data';

import '../models/class_schedule.dart';
import '../models/schedule_import.dart';

abstract interface class ScheduleRepository {
  Future<List<ClassSchedule>> fetchSchedules();

  Future<ClassSchedule> createSchedule(ClassSchedule schedule);

  Future<ClassSchedule> updateSchedule(ClassSchedule schedule);

  Future<void> deleteSchedule(String id);

  Future<int> deleteAllSchedules();

  Future<ScheduleImportPreview> previewScheduleFile({
    required String fileName,
    required Uint8List bytes,
  });

  Future<ScheduleImportResult> importSchedulePreview(
    ScheduleImportPreview preview,
  );
}
