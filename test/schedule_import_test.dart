import 'package:cpe_air_remote/models/schedule_import.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads new room suggestions and confirms room creation on commit', () {
    final preview = ScheduleImportPreview.fromJson({
      'fileName': 'ตาราง.xlsx',
      'semester': '1/2569',
      'roomNumbers': ['16202', 'CL503'],
      'existingRoomNumbers': ['16202'],
      'newRooms': [
        {
          'roomNumber': 'CL503',
          'floorNumber': 0,
          'roomIndex': 503,
          'roomType': 'Special',
        },
      ],
      'schedules': [
        {
          'semester': '1/2569',
          'roomNumber': 'CL503',
          'dayOfWeek': 1,
          'subjectName': 'Operating System',
          'startTime': '09:00',
          'endTime': '12:00',
          'section': '(T) 68346CPE',
          'instructor': 'Teacher A',
        },
      ],
      'warnings': <String>[],
      'skippedSheets': <String>[],
      'csv': '',
    });

    expect(preview.newRoomCount, 1);
    expect(preview.newRooms.single.roomNumber, 'CL503');
    expect(preview.newRooms.single.floorNumber, 0);
    expect(preview.toCommitJson()['createMissingRooms'], isTrue);
    // ยังไม่ได้เลือกช่วงวัน = ไม่ส่งวันที่ไป (ทำงานแบบเดิม)
    expect(preview.toCommitJson().containsKey('startDate'), isFalse);

    final withTerm = preview.withTerm(
      semester: '2/2569',
      startDate: DateTime(2026, 11, 2),
      endDate: DateTime(2027, 3, 5),
    );
    final json = withTerm.toCommitJson();
    expect(json['semester'], '2/2569');
    expect(json['startDate'], '2026-11-02');
    expect(json['endDate'], '2027-03-05');
    expect(json['createMissingRooms'], isTrue);
  });

  test('reads created rooms from a successful import result', () {
    final result = ScheduleImportResult.fromJson({
      'importedCount': 151,
      'replacedRooms': ['16202', 'CL503'],
      'createdRooms': [
        {
          'roomNumber': 'CL503',
          'floorNumber': 0,
          'roomIndex': 503,
          'roomType': 'Special',
        },
      ],
    });

    expect(result.importedCount, 151);
    expect(result.createdRooms.single.roomNumber, 'CL503');
  });
}
