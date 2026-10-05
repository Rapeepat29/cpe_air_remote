import 'package:cpe_air_remote/utils/thai_date.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('วันที่ พ.ศ.', () {
    test('ภาษาไทยแสดงปี พ.ศ. ภาษาอังกฤษแสดง ค.ศ.', () {
      final date = DateTime(2026, 6, 9);
      expect(formatDisplayDate(date, true), '9 มิ.ย. 2569');
      expect(formatDisplayDate(date, false), '9 Jun 2026');
      expect(formatNumericDate(date, true), '09/06/2569');
      expect(formatMonthYear(date, true), 'มิถุนายน 2569');
    });

    test('พิมพ์ปี พ.ศ. หรือ ค.ศ. ก็ได้วันเดียวกัน', () {
      expect(parseNumericDate('01/02/2569'), DateTime(2026, 2, 1));
      expect(parseNumericDate('1-2-2026'), DateTime(2026, 2, 1));
      expect(parseNumericDate('08.11.2569'), DateTime(2026, 11, 8));
    });

    test('วันที่ไม่มีจริงหรือรูปแบบผิดคืน null', () {
      expect(parseNumericDate('31/02/2569'), isNull);
      expect(parseNumericDate('2569-02-01'), isNull);
      expect(parseNumericDate(''), isNull);
    });

    test('วันที่จาก Backend (yyyy-MM-dd) แปลงมาแสดงได้', () {
      expect(formatIsoDateText('2026-08-20', true), '20 ส.ค. 2569');
      expect(formatIsoDateText('ไม่ใช่วันที่', true), 'ไม่ใช่วันที่');
    });
  });
}
