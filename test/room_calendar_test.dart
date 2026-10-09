import 'package:cpe_air_remote/models/class_schedule.dart';
import 'package:cpe_air_remote/models/room_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

RoomBooking _booking({
  BookingRepeat repeat = BookingRepeat.once,
  String start = '2026-10-07',
  String end = '2026-10-07',
  List<int> days = const [],
}) {
  return RoomBooking(
    id: 'b1',
    roomNumber: '16101',
    title: 'ประชุมภาควิชา',
    category: 'meeting',
    repeat: repeat,
    daysOfWeek: days,
    startDate: start,
    endDate: end,
    startTime: '13:00',
    endTime: '15:00',
  );
}

void main() {
  group('date helpers', () {
    test('วันในสัปดาห์และต้นสัปดาห์ (อาทิตย์) ตรงกับ Backend', () {
      // 9 ต.ค. 2569 เป็นวันศุกร์
      expect(dayOfWeekOfIso('2026-10-09'), 5);
      expect(weekStartIso('2026-10-09'), '2026-10-04');
      expect(weekStartIso('2026-10-04'), '2026-10-04');
    });

    test('บวกวันข้ามเดือนและข้ามปีได้ถูก', () {
      expect(addDaysIso('2026-09-30', 1), '2026-10-01');
      expect(addDaysIso('2026-12-31', 1), '2027-01-01');
      expect(addDaysIso('2026-10-01', -1), '2026-09-30');
      expect(daysBetweenIso('2026-10-01', '2026-10-31'), 30);
    });
  });

  group('RoomBooking', () {
    test('วันเดียว มีเฉพาะวันนั้น', () {
      final booking = _booking();
      expect(booking.occursOn('2026-10-07'), isTrue);
      expect(booking.occursOn('2026-10-08'), isFalse);
      expect(booking.occurrenceCount, 1);
    });

    test('ทุกสัปดาห์ มีเฉพาะวันที่เลือกในช่วงวันที่', () {
      final booking = _booking(
        repeat: BookingRepeat.weekly,
        start: '2026-10-01',
        end: '2026-10-31',
        days: const [3],
      );
      expect(booking.occursOn('2026-10-07'), isTrue); // พุธ
      expect(booking.occursOn('2026-10-08'), isFalse);
      expect(booking.occursOn('2026-11-04'), isFalse); // เลยวันสิ้นสุด
      expect(booking.occurrenceCount, 4); // 7 14 21 28
    });

    test('ทุกวัน นับทุกวันในช่วง', () {
      final booking = _booking(
        repeat: BookingRepeat.daily,
        start: '2026-10-05',
        end: '2026-10-09',
      );
      expect(booking.occurrenceCount, 5);
      expect(booking.occursOn('2026-10-10'), isFalse);
    });

    test('ส่งไป Backend: วันเดียวใช้วันเริ่มเป็นวันสิ้นสุด และไม่ส่งวันในสัปดาห์', () {
      final json = _booking(end: '2026-12-31', days: const [1, 2]).toRequestJson();
      expect(json['repeatType'], 'once');
      expect(json['endDate'], '2026-10-07');
      expect(json['daysOfWeek'], isEmpty);
    });

    test('อ่านจาก Backend ได้ เวลาตัดวินาทีทิ้ง', () {
      final booking = RoomBooking.fromJson({
        'id': 'x',
        'roomNumber': '16101',
        'title': 'สอบ',
        'category': 'exam',
        'repeatType': 'weekly',
        'daysOfWeek': [5, 1],
        'startDate': '2026-10-01',
        'endDate': '2026-10-31',
        'startTime': '09:00:00',
        'endTime': '12:00:00',
      });
      expect(booking.repeat, BookingRepeat.weekly);
      expect(booking.daysOfWeek, [1, 5]);
      expect(booking.startTime, '09:00');
      expect(booking.endTime, '12:00');
    });
  });

  group('AcademicTerm', () {
    const term = AcademicTerm(
      semester: '1/2569',
      startDate: '2026-06-15',
      endDate: '2026-10-10',
    );

    test('รวมวันเปิดและวันปิด', () {
      expect(term.contains('2026-06-15'), isTrue);
      expect(term.contains('2026-10-10'), isTrue);
      expect(term.contains('2026-10-11'), isFalse);
    });

    test('สถานะเทียบกับวันนี้', () {
      expect(term.statusOn('2026-06-01'), TermStatus.before);
      expect(term.statusOn('2026-08-01'), TermStatus.active);
      expect(term.statusOn('2026-11-01'), TermStatus.after);
    });

    test('รูปแบบภาคเรียน เทอม/ปี', () {
      expect(AcademicTerm.semesterPattern.hasMatch('1/2569'), isTrue);
      expect(AcademicTerm.semesterPattern.hasMatch('4/2569'), isFalse);
      expect(AcademicTerm.semesterPattern.hasMatch('2569/1'), isFalse);
    });
  });

  test('CSV ของตารางเรียนนำกลับเข้ามาได้ (หัวตารางและวันแบบรหัส)', () {
    final csv = schedulesToCsv(const [
      ClassSchedule(
        id: '1',
        roomNumber: '16101',
        dayOfWeek: 3,
        subjectName: 'Network, Lab',
        startTime: '09:00',
        endTime: '12:00',
      ),
    ], '1/2569');
    final lines = csv.replaceFirst('﻿', '').trim().split('\r\n');
    expect(
      lines.first,
      'semester,room_code,day,start_time,end_time,subject,section,instructor,enabled',
    );
    expect(lines[1], '1/2569,16101,WED,09:00,12:00,"Network, Lab",,,true');
  });
}
