
import 'package:flutter/foundation.dart';

import '../models/class_schedule.dart';
import '../models/room_calendar.dart';
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

  TimetableInfo? _timetable;
  bool _supportsTimetable = false;
  List<AcademicTerm> _terms = const [];
  String _serverToday = '';
  final List<RoomBooking> _bookings = [];
  String? _bookingsFrom;
  String? _bookingsTo;
  bool _bookingsLoading = false;
  String? _calendarError;

  /// ภาคเรียนของตารางที่ใช้อยู่ (null = ยังไม่เคยนำเข้าจากไฟล์ หรือ Backend รุ่นเก่า)
  TimetableInfo? get timetable => _timetable;

  /// Backend รองรับ "เปลี่ยนภาคเรียน" ตอนนำเข้า (ล้างตารางเดิมทุกห้อง) หรือไม่
  bool get supportsReplaceAll => _supportsTimetable;

  List<AcademicTerm> get terms => List.unmodifiable(_terms);

  List<RoomBooking> get bookings => List.unmodifiable(_bookings);

  bool get bookingsLoading => _bookingsLoading;

  /// ข้อความผิดพลาดของปฏิทิน/การใช้ห้อง (ตารางเรียนหลักยังใช้ได้)
  String? get calendarError => _calendarError;

  /// วันนี้ตามเวลาไทยจากเซิร์ฟเวอร์ ถ้ายังไม่รู้ใช้วันที่ของเครื่อง
  String get today =>
      _serverToday.isNotEmpty ? _serverToday : isoDateOf(DateTime.now());

  /// ปฏิทินของภาคเรียนหนึ่ง หรือ null
  AcademicTerm? termFor(String? semester) {
    if (semester == null || semester.isEmpty) return null;
    for (final term in _terms) {
      if (term.semester == semester) return term;
    }
    return null;
  }

  /// ภาคเรียนของตารางที่ใช้อยู่ ถ้าตั้งวันเปิด–ปิดไว้
  AcademicTerm? get activeTimetableTerm => termFor(_timetable?.semester);

  /// วันที่นี้ตารางเรียนไม่มีผล เพราะอยู่นอกวันเปิด–ปิดของภาคเรียน
  bool isOutsideTerm(String date) {
    final term = activeTimetableTerm;
    return term != null && !term.contains(date);
  }

  /// การใช้ห้องของห้องหนึ่งในวันที่หนึ่ง
  List<RoomBooking> bookingsOn(String roomNumber, String date) {
    return _bookings
        .where(
          (booking) =>
              booking.roomNumber == roomNumber && booking.occursOn(date),
        )
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// คาบเรียนที่มีผลจริงในวันที่หนึ่ง (นอกภาคเรียน = ไม่มี)
  List<ClassSchedule> classesOn(String roomNumber, String date) {
    if (isOutsideTerm(date)) return const [];
    return schedulesFor(roomNumber, dayOfWeekOfIso(date));
  }

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
      final loaded = await repository.fetchScheduleBundle();
      _schedules
        ..clear()
        ..addAll(loaded.schedules)
        ..sort(_compare);
      _timetable = loaded.timetable;
      _supportsTimetable = loaded.supportsTimetable;
      _hasLoaded = true;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    await reloadCalendar();
  }

  /// ดึงปฏิทินภาคเรียนใหม่ ถ้าพลาดไม่ทำให้ตารางเรียนใช้ไม่ได้
  Future<void> reloadCalendar() async {
    try {
      final calendar = await repository.fetchAcademicCalendar();
      _terms = calendar.terms;
      _serverToday = calendar.today;
      _calendarError = null;
    } catch (error) {
      _calendarError = error.toString();
    }
    notifyListeners();
  }

  /// ดึงการใช้ห้องของช่วงวันที่ (ปกติคือหนึ่งสัปดาห์ที่กำลังดู)
  ///
  /// ช่วงเดิมที่ดึงไว้แล้วไม่ดึงซ้ำ เว้นแต่ [force]
  Future<void> loadBookings({
    required String from,
    required String to,
    bool force = false,
  }) async {
    if (!force && _bookingsFrom == from && _bookingsTo == to) return;
    _bookingsLoading = true;
    notifyListeners();
    try {
      final loaded = await repository.fetchBookings(from: from, to: to);
      _bookings
        ..clear()
        ..addAll(loaded);
      _bookingsFrom = from;
      _bookingsTo = to;
      _calendarError = null;
    } catch (error) {
      _calendarError = error.toString();
    } finally {
      _bookingsLoading = false;
      notifyListeners();
    }
  }

  Future<void> _refreshBookings() async {
    final from = _bookingsFrom;
    final to = _bookingsTo;
    if (from == null || to == null) return;
    await loadBookings(from: from, to: to, force: true);
  }

  Future<void> createBooking(RoomBooking booking) async {
    await repository.createBooking(booking);
    await _refreshBookings();
  }

  Future<void> updateBooking(RoomBooking booking) async {
    await repository.updateBooking(booking);
    await _refreshBookings();
  }

  Future<void> deleteBooking(String id) async {
    await repository.deleteBooking(id);
    await _refreshBookings();
  }

  /// บันทึกวันเปิด–ปิดภาคเรียน ถ้าเปลี่ยนชื่อภาคเรียนตอนแก้ ลบอันเดิมทิ้ง
  Future<AcademicTerm> saveAcademicTerm(
    AcademicTerm term, {
    String? previousSemester,
  }) async {
    final saved = await repository.saveAcademicTerm(term);
    if (previousSemester != null &&
        previousSemester.isNotEmpty &&
        previousSemester != saved.semester) {
      await repository.deleteAcademicTerm(previousSemester);
    }
    await reloadCalendar();
    return saved;
  }

  Future<void> deleteAcademicTerm(String semester) async {
    await repository.deleteAcademicTerm(semester);
    await reloadCalendar();
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
    // Backend ล้างภาคเรียนของตารางไปพร้อมกัน
    _timetable = null;
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
