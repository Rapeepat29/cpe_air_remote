import 'class_schedule.dart';

/// ปฏิทินการใช้ห้อง: การจองห้องที่มีวันที่กำกับ ภาคเรียน และข้อมูลตารางที่ใช้อยู่
///
/// ตรรกะวันที่ทั้งหมดเหมือนกับ Backend (`backend/src/utils/room-booking.js`)
/// และเว็บแอป (`webapp/assets/js/views/booking-form.js`) ผลสามฝั่งจึงตรงกัน
/// วันที่ทุกตัวเป็นข้อความ `yyyy-MM-dd` เรียงแบบข้อความได้ตรงกับเรียงตามวัน

/// วันที่ปฏิทินเป็นข้อความ `yyyy-MM-dd` (ไม่สนเวลาและเขตเวลา)
String isoDateOf(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}

/// แปลง `yyyy-MM-dd` เป็น DateTime ตอนเที่ยงคืนตามเวลาเครื่อง
DateTime dateOfIso(String value) {
  final parts = value.split('-');
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// วันในสัปดาห์ของวันที่ (0 = อาทิตย์ ตรงกับ Backend และตารางเรียน)
int dayOfWeekOfIso(String value) => dateOfIso(value).weekday % 7;

/// บวกวัน ใช้ DateTime(y, m, d + n) เพราะไม่โดนผลของเวลาออมแสง
String addDaysIso(String value, int days) {
  final date = dateOfIso(value);
  return isoDateOf(DateTime(date.year, date.month, date.day + days));
}

/// จำนวนวันจาก [from] ถึง [to]
int daysBetweenIso(String from, String to) {
  final start = dateOfIso(from);
  final end = dateOfIso(to);
  return DateTime.utc(end.year, end.month, end.day)
      .difference(DateTime.utc(start.year, start.month, start.day))
      .inDays;
}

/// วันอาทิตย์ของสัปดาห์ที่มีวันนั้น (สัปดาห์เรียงอาทิตย์–เสาร์ เหมือนเว็บ)
String weekStartIso(String value) => addDaysIso(value, -dayOfWeekOfIso(value));

enum BookingRepeat { once, daily, weekly }

/// ประเภทการใช้ห้อง ตรงกับ `BOOKING_CATEGORIES` ของ Backend
const bookingCategories = ['meeting', 'class', 'exam', 'event', 'other'];

String bookingCategoryLabel(String category, bool isThai) {
  return switch (category) {
    'meeting' => isThai ? 'ประชุม' : 'Meeting',
    'class' => isThai ? 'คาบเรียน' : 'Class',
    'exam' => isThai ? 'สอบ' : 'Exam',
    'event' => isThai ? 'กิจกรรม' : 'Event',
    _ => isThai ? 'อื่น ๆ' : 'Other',
  };
}

/// การใช้ห้องนอกตารางเรียน (ประชุม สอบ กิจกรรม คาบชดเชย)
class RoomBooking {
  const RoomBooking({
    required this.id,
    required this.roomNumber,
    required this.title,
    required this.category,
    required this.repeat,
    required this.startDate,
    required this.endDate,
    required this.startTime,
    required this.endTime,
    this.note = '',
    this.daysOfWeek = const [],
  });

  final String id;
  final String roomNumber;
  final String title;
  final String category;
  final String note;
  final BookingRepeat repeat;

  /// ใช้เมื่อ [repeat] เป็น weekly (0 = อาทิตย์)
  final List<int> daysOfWeek;
  final String startDate;
  final String endDate;
  final String startTime;
  final String endTime;

  factory RoomBooking.fromJson(Map<String, dynamic> json) {
    final days = json['daysOfWeek'];
    return RoomBooking(
      id: json['id'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? 'other',
      note: json['note'] as String? ?? '',
      repeat: switch (json['repeatType']) {
        'daily' => BookingRepeat.daily,
        'weekly' => BookingRepeat.weekly,
        _ => BookingRepeat.once,
      },
      daysOfWeek: days is List
          ? (days.whereType<num>().map((day) => day.toInt()).toList()..sort())
          : const [],
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      startTime: _hhmm(json['startTime']),
      endTime: _hhmm(json['endTime']),
    );
  }

  Map<String, dynamic> toRequestJson() {
    return {
      'roomNumber': roomNumber,
      'title': title,
      'category': category,
      'note': note,
      'repeatType': repeat.name,
      'daysOfWeek': repeat == BookingRepeat.weekly ? daysOfWeek : const <int>[],
      'startDate': startDate,
      'endDate': repeat == BookingRepeat.once ? startDate : endDate,
      'startTime': startTime,
      'endTime': endTime,
    };
  }

  RoomBooking copyWith({String? endDate}) {
    return RoomBooking(
      id: id,
      roomNumber: roomNumber,
      title: title,
      category: category,
      note: note,
      repeat: repeat,
      daysOfWeek: daysOfWeek,
      startDate: startDate,
      endDate: endDate ?? this.endDate,
      startTime: startTime,
      endTime: endTime,
    );
  }

  /// การจองนี้มีในวันที่ [date] หรือไม่ (ตรรกะเดียวกับ Backend)
  bool occursOn(String date) {
    if (date.compareTo(startDate) < 0) return false;
    final last = repeat == BookingRepeat.once ? startDate : endDate;
    if (date.compareTo(last) > 0) return false;
    if (repeat == BookingRepeat.weekly) {
      return daysOfWeek.contains(dayOfWeekOfIso(date));
    }
    return true;
  }

  /// ทับช่วงวันที่ [from]–[to] อย่างน้อยหนึ่งวันหรือไม่ (ไม่ได้ดูวันในสัปดาห์)
  bool overlapsRange(String from, String to) {
    final last = repeat == BookingRepeat.once ? startDate : endDate;
    return startDate.compareTo(to) <= 0 && last.compareTo(from) >= 0;
  }

  /// จำนวนครั้งทั้งหมด ใช้สรุปให้ผู้ใช้เห็นก่อนบันทึก
  int get occurrenceCount => countBookingOccurrences(
    repeat: repeat,
    startDate: startDate,
    endDate: endDate,
    daysOfWeek: daysOfWeek,
  );
}

/// เวลา `HH:mm` (ฐานข้อมูลบางรุ่นส่ง `HH:mm:ss` มา)
String _hhmm(Object? value) {
  final text = value is String ? value.trim() : '';
  return text.length > 5 ? text.substring(0, 5) : text;
}

int countBookingOccurrences({
  required BookingRepeat repeat,
  required String startDate,
  required String endDate,
  List<int> daysOfWeek = const [],
}) {
  if (repeat == BookingRepeat.once) return 1;
  final span = daysBetweenIso(startDate, endDate);
  if (span < 0) return 0;
  if (repeat == BookingRepeat.daily) return span + 1;
  final days = daysOfWeek.toSet();
  if (days.isEmpty) return 0;
  var count = 0;
  final first = dayOfWeekOfIso(startDate);
  for (var index = 0; index <= span; index++) {
    if (days.contains((first + index) % 7)) count++;
  }
  return count;
}

/// สถานะของภาคเรียน ณ วันนี้ ตาม Backend: before / active / after
enum TermStatus { before, active, after, unknown }

/// วันเปิด–ปิดของหนึ่งภาคเรียน
class AcademicTerm {
  const AcademicTerm({
    required this.semester,
    required this.startDate,
    required this.endDate,
    this.status = TermStatus.unknown,
  });

  final String semester;
  final String startDate;
  final String endDate;
  final TermStatus status;

  factory AcademicTerm.fromJson(Map<String, dynamic> json) {
    return AcademicTerm(
      semester: json['semester'] as String? ?? '',
      startDate: json['startDate'] as String? ?? '',
      endDate: json['endDate'] as String? ?? '',
      status: switch (json['status']) {
        'before' => TermStatus.before,
        'active' => TermStatus.active,
        'after' => TermStatus.after,
        _ => TermStatus.unknown,
      },
    );
  }

  Map<String, dynamic> toRequestJson() => {
    'semester': semester,
    'startDate': startDate,
    'endDate': endDate,
  };

  /// วันที่ [date] อยู่ในภาคเรียนนี้หรือไม่ (รวมวันเปิดและวันปิด)
  bool contains(String date) =>
      date.compareTo(startDate) >= 0 && date.compareTo(endDate) <= 0;

  /// สถานะเทียบกับวัน [today] ใช้แทนค่าจาก Backend เมื่อข้ามวันระหว่างเปิดแอปค้าง
  TermStatus statusOn(String today) {
    if (today.compareTo(startDate) < 0) return TermStatus.before;
    if (today.compareTo(endDate) > 0) return TermStatus.after;
    return TermStatus.active;
  }

  static final semesterPattern = RegExp(r'^[1-3]/\d{4}$');
}

/// ปฏิทินภาคเรียนทั้งหมด พร้อม "วันนี้" ตามเวลาไทยจากเซิร์ฟเวอร์
class AcademicCalendar {
  const AcademicCalendar({required this.today, required this.terms});

  /// `yyyy-MM-dd` ตามเวลาไทย หรือว่างถ้าเซิร์ฟเวอร์ไม่ได้ส่งมา
  final String today;
  final List<AcademicTerm> terms;

  factory AcademicCalendar.fromJson(Map<String, dynamic> json) {
    final terms = json['terms'];
    return AcademicCalendar(
      today: json['today'] as String? ?? '',
      terms: terms is List
          ? terms
                .whereType<Map<String, dynamic>>()
                .map(AcademicTerm.fromJson)
                .toList()
          : const [],
    );
  }
}

/// ตารางเรียนที่ใช้อยู่เป็นของภาคเรียนไหน ใครนำเข้าเมื่อไร
class TimetableInfo {
  const TimetableInfo({
    required this.semester,
    this.importedBy,
    this.importedAt,
  });

  final String semester;
  final String? importedBy;
  final DateTime? importedAt;

  static TimetableInfo? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    return TimetableInfo(
      semester: json['semester'] as String? ?? '',
      importedBy: json['importedBy'] as String?,
      importedAt: DateTime.tryParse(json['importedAt'] as String? ?? ''),
    );
  }
}

/// ผลของ GET /schedules: ตารางเรียน และภาคเรียนของตาราง
class ScheduleBundle {
  const ScheduleBundle({
    required this.schedules,
    this.timetable,
    this.supportsTimetable = false,
  });

  final List<ClassSchedule> schedules;
  final TimetableInfo? timetable;

  /// Backend รุ่นนี้ส่งช่อง `timetable` มาหรือไม่ (รุ่นเก่าไม่รองรับเปลี่ยนภาคเรียน)
  final bool supportsTimetable;
}

const _dayCodes = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];

/// ตารางเรียนเป็น CSV รูปแบบเดียวกับที่ Backend และเว็บส่งออก
/// จึงนำกลับเข้ามาด้วยปุ่มนำเข้าได้ทันที
String schedulesToCsv(List<ClassSchedule> schedules, String semester) {
  const header = [
    'semester',
    'room_code',
    'day',
    'start_time',
    'end_time',
    'subject',
    'section',
    'instructor',
    'enabled',
  ];
  final sorted = [...schedules]
    ..sort((a, b) {
      final room = a.roomNumber.compareTo(b.roomNumber);
      if (room != 0) return room;
      final day = a.dayOfWeek.compareTo(b.dayOfWeek);
      if (day != 0) return day;
      return a.startTime.compareTo(b.startTime);
    });
  String escape(String value) {
    if (!RegExp(r'[",\r\n]').hasMatch(value)) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  final lines = [
    header.join(','),
    for (final row in sorted)
      [
        semester,
        row.roomNumber,
        row.dayOfWeek >= 0 && row.dayOfWeek < 7 ? _dayCodes[row.dayOfWeek] : '',
        row.startTime,
        row.endTime,
        row.subjectName,
        row.section,
        row.instructor,
        'true',
      ].map(escape).join(','),
  ];
  return '﻿${lines.join('\r\n')}\r\n';
}
