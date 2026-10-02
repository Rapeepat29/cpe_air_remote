import 'package:cpe_air_remote/models/class_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects only genuinely overlapping class times', () {
    expect(
      ClassSchedule.timesOverlap('09:00', '12:00', '11:00', '13:00'),
      isTrue,
    );
    expect(
      ClassSchedule.timesOverlap('09:00', '12:00', '12:00', '13:00'),
      isFalse,
    );
    expect(
      ClassSchedule.timesOverlap('13:00', '16:00', '09:00', '12:00'),
      isFalse,
    );
  });

  test('converts API schedule data without changing 24-hour times', () {
    final schedule = ClassSchedule.fromJson({
      'id': 'schedule-1',
      'roomNumber': '16302',
      'dayOfWeek': 1,
      'subjectName': 'Computer Network',
      'section': '(T) 68346CPE',
      'instructor': 'ดร.พชร ศรีมุกข์',
      'startTime': '09:00',
      'endTime': '12:00',
    });

    expect(schedule.roomNumber, '16302');
    expect(schedule.dayOfWeek, 1);
    expect(schedule.startTime, '09:00');
    expect(schedule.endTime, '12:00');
    expect(schedule.section, '(T) 68346CPE');
    expect(schedule.instructor, 'ดร.พชร ศรีมุกข์');
  });
}
