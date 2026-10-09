import 'dart:typed_data';

import '../models/class_schedule.dart';
import '../models/room_calendar.dart';
import '../models/schedule_import.dart';

abstract interface class ScheduleRepository {
  Future<List<ClassSchedule>> fetchSchedules();

  /// ตารางเรียนพร้อมภาคเรียนของตาราง (ช่อง `timetable` ของ GET /schedules)
  Future<ScheduleBundle> fetchScheduleBundle();

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

  /// ปฏิทินภาคเรียน (วันเปิด–ปิดของแต่ละเทอม) และวันนี้ตามเวลาไทย
  Future<AcademicCalendar> fetchAcademicCalendar();

  Future<AcademicTerm> saveAcademicTerm(AcademicTerm term);

  Future<void> deleteAcademicTerm(String semester);

  /// การใช้ห้องที่ทับช่วงวันที่ [from]–[to] (`yyyy-MM-dd`)
  Future<List<RoomBooking>> fetchBookings({
    required String from,
    required String to,
  });

  Future<void> createBooking(RoomBooking booking);

  Future<void> updateBooking(RoomBooking booking);

  Future<void> deleteBooking(String id);
}
