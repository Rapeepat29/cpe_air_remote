import 'package:cpe_air_remote/screens/schedule_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps DateTime weekdays to the Sunday-first timetable index', () {
    final dates = [
      DateTime(2026, 7, 26),
      DateTime(2026, 7, 27),
      DateTime(2026, 7, 28),
      DateTime(2026, 7, 29),
      DateTime(2026, 7, 30),
      DateTime(2026, 7, 31),
      DateTime(2026, 8, 1),
    ];

    for (var index = 0; index < dates.length; index++) {
      expect(scheduleDayIndexForDate(dates[index]), index);
    }
  });

  test('resolves every selected day inside the anchor date current week', () {
    final thursday = DateTime(2026, 7, 30, 18, 45);

    expect(scheduleDateForDay(thursday, 0), DateTime(2026, 7, 26));
    expect(scheduleDateForDay(thursday, 1), DateTime(2026, 7, 27));
    expect(scheduleDateForDay(thursday, 2), DateTime(2026, 7, 28));
    expect(scheduleDateForDay(thursday, 3), DateTime(2026, 7, 29));
    expect(scheduleDateForDay(thursday, 4), DateTime(2026, 7, 30));
    expect(scheduleDateForDay(thursday, 5), DateTime(2026, 7, 31));
    expect(scheduleDateForDay(thursday, 6), DateTime(2026, 8, 1));
  });
}
